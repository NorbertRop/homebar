import Foundation
import HomeBarCore
import Observation

@MainActor @Observable final class AppModel {
    let store = StateStore()
    var settings: Settings
    var connection: HAClient.ConnectionState = .disconnected
    var offlineEntityIDs: Set<String> = []
    var offlineCount: Int { offlineEntityIDs.count }
    /// Bumped on every snapshot/delta. A direct observable property the menu reads so it
    /// re-renders on data changes — MenuBarExtra content doesn't reliably track the nested
    /// @Observable `store.entities`.
    var dataVersion = 0
    /// Recent (~6h) sparkline values per sensor, fetched lightly when a row appears.
    var histories: [String: [Double]] = [:]
    private var historyFetchedAt: [String: Date] = [:]
    /// Full (~24h) timestamped history for the expanded detail chart, fetched on click.
    var detailHistory: [String: [HistoryPoint]] = [:]
    private var detailFetchedAt: [String: Date] = [:]
    private(set) var detailLoaded: Set<String> = []

    let tokenStore: TokenStore
    private let notifier: UserNotificationNotifier
    private let monitor: StalenessMonitor
    private var client: HAClient?
    private var connectTask: Task<Void, Never>?
    private var lastCacheSave = Date.distantPast

    static let cacheURL = Settings.defaultURL().deletingLastPathComponent()
        .appendingPathComponent("state-cache.json")

    init(tokenStore: TokenStore = FileTokenStore()) {
        self.tokenStore = tokenStore
        let n = UserNotificationNotifier()
        self.notifier = n
        self.monitor = StalenessMonitor(notifier: n)
        self.settings = Settings.load(from: Settings.defaultURL())
        notifier.enabled = settings.notifyOffline
        store.loadCache(from: Self.cacheURL)
    }

    /// URL/token resolve from env vars first (handy for headless testing/automation),
    /// then the saved settings + Keychain.
    private var effectiveURL: URL? {
        if let s = ProcessInfo.processInfo.environment["HOMEBAR_URL"], let u = URL(string: s) { return u }
        return settings.serverURL
    }
    private var effectiveToken: String? {
        ProcessInfo.processInfo.environment["HOMEBAR_TOKEN"] ?? tokenStore.read()
    }

    var isConfigured: Bool { effectiveURL != nil && effectiveToken != nil }

    func start() {
        guard connectTask == nil, isConfigured else { return }
        connectTask = Task { await self.connectLoop() }
    }

    func restart() {
        let old = connectTask
        connectTask = nil
        old?.cancel()
        Task {
            await old?.value          // let the old loop fully unwind before starting a new one
            await client?.disconnect()
            client = nil
            start()
        }
    }

    func saveSettings() {
        try? settings.save(to: Settings.defaultURL())
        notifier.enabled = settings.notifyOffline
    }

    private func connectLoop() async {
        guard let base = effectiveURL, let token = effectiveToken,
              let ws = haWebSocketURL(from: base) else { return }
        var attempt = 0
        while !Task.isCancelled {
            let client = HAClient(url: ws, token: token, transport: URLSessionWebSocketTransport(url: ws))
            self.client = client
            do {
                try await client.connect()
                connection = .authenticated
                attempt = 0
                store.registry = (try? await client.fetchRegistry()) ?? store.registry
                let snapshot = try await client.getStates()
                if !snapshot.isEmpty { store.applySnapshot(snapshot); dataVersion &+= 1 }
                try? store.saveCache(to: Self.cacheURL); lastCacheSave = Date()
                evaluateStaleness()
                try await client.subscribeStateChanges()
                let ticker = Task { [weak self] in
                    while !Task.isCancelled {
                        try? await Task.sleep(for: .seconds(30))
                        self?.evaluateStaleness()
                        do { try await client.ping() }   // dead socket → teardown → reconnect
                        catch { return }
                    }
                }
                for await change in client.events {
                    store.apply(change)
                    dataVersion &+= 1
                    if Date().timeIntervalSince(lastCacheSave) > 5 {   // throttle disk writes off the main thread's hot path
                        try? store.saveCache(to: Self.cacheURL); lastCacheSave = Date()
                    }
                    evaluateStaleness()
                }
                ticker.cancel()
            } catch { /* connection failed — retry with backoff below */ }
            await client.disconnect()
            connection = .disconnected
            attempt += 1
            try? await Task.sleep(for: .seconds(min(30, pow(2, Double(min(attempt, 5))))))
        }
    }

    private func evaluateStaleness() {
        // Only watch entities the user explicitly PINNED, so a sea of offline
        // integration/diagnostic entities never lights up the menu-bar dot. Pinning a
        // device opts it into the offline indicator + notification.
        let relevant = store.entities.values.filter { settings.pinned.contains($0.entityID) }
        let fresh = monitor.evaluate(Array(relevant), now: Date(),
                                     window: settings.stalenessWindow,
                                     perEntityWindow: settings.perEntityWindow)
        offlineEntityIDs = Set(fresh.filter { $0.value != .fresh }.map(\.key))
    }

    func perform(_ call: ServiceCall) { Task { try? await client?.send(call) } }
    func toggle(_ id: String) { perform(HACommand.toggle(id)) }

    // Curation from the menu's right-click context menu.
    func isPinned(_ id: String) -> Bool { settings.pinned.contains(id) }
    func hasDevice(_ id: String) -> Bool { store.registry.deviceID(for: id) != nil }
    /// Find a sibling entity on the same device whose id ends with `suffix`
    /// (e.g. a vacuum's `button.…_start_sweep_mop`).
    func deviceEntityID(of id: String, suffix: String) -> String? {
        guard let did = store.registry.deviceID(for: id) else { return nil }
        return store.entities.keys.first { $0.hasSuffix(suffix) && store.registry.deviceID(for: $0) == did }
    }
    func togglePin(_ id: String) {
        if let i = settings.pinned.firstIndex(of: id) { settings.pinned.remove(at: i) }
        else { settings.pinned.append(id); settings.hidden.remove(id) }
        saveSettings(); dataVersion &+= 1
    }
    func hide(_ id: String) {
        settings.hidden.insert(id); settings.pinned.removeAll { $0 == id }
        saveSettings(); dataVersion &+= 1
    }
    func hideDevice(of id: String) {
        guard let did = store.registry.deviceID(for: id) else { return hide(id) }
        for e in store.entities.keys where store.registry.deviceID(for: e) == did {
            settings.hidden.insert(e)
        }
        settings.pinned.removeAll { store.registry.deviceID(for: $0) == did }
        saveSettings(); dataVersion &+= 1
    }

    // Favorites reordering. Move Up/Down (menu, accessible) + .onMove (Settings list).
    func canMoveFavorite(_ id: String, up: Bool) -> Bool {
        guard let i = settings.pinned.firstIndex(of: id) else { return false }
        return up ? i > 0 : i < settings.pinned.count - 1
    }
    func moveFavorite(_ id: String, up: Bool) {
        guard let i = settings.pinned.firstIndex(of: id) else { return }
        let j = up ? i - 1 : i + 1
        guard settings.pinned.indices.contains(j) else { return }
        settings.pinned.swapAt(i, j); saveSettings(); dataVersion &+= 1
    }
    func moveFavorites(from: IndexSet, to: Int) {
        settings.pinned.move(fromOffsets: from, toOffset: to); saveSettings(); dataVersion &+= 1
    }
    /// Reorder a non-pinned entity within its displayed list, recording the new order.
    func reorder(_ displayed: [String], moving id: String, up: Bool) {
        guard let i = displayed.firstIndex(of: id) else { return }
        let j = up ? i - 1 : i + 1
        guard displayed.indices.contains(j) else { return }
        var list = displayed; list.swapAt(i, j)
        settings.order = settings.order.filter { !list.contains($0) } + list
        saveSettings(); dataVersion &+= 1
    }

    /// Light ~6h fetch for the inline sparkline when a numeric sensor's row appears (cached ~5 min).
    func loadHistory(_ id: String) {
        if let t = historyFetchedAt[id], Date().timeIntervalSince(t) < 300 { return }
        guard let client else { return }
        historyFetchedAt[id] = Date()
        Task {
            do {
                let pts = try await client.history(entityID: id, hours: 6)
                if pts.count > 1 { histories[id] = Self.downsample(pts.map(\.value), to: 48); dataVersion &+= 1 }
            } catch {
                historyFetchedAt[id] = .distantPast   // failed fetch → allow retry
            }
        }
    }
    func sparkline(for id: String) -> [Double]? { histories[id] }

    /// Full ~24h fetch for the expanded detail chart, on demand when a sensor is clicked (cached
    /// ~2 min). It's fast (<0.2s), so there's no need to prefetch it for every row.
    func loadDetail(_ id: String) {
        if let t = detailFetchedAt[id], Date().timeIntervalSince(t) < 120 { return }
        guard let client else { return }
        detailFetchedAt[id] = Date()
        Task {
            do {
                let pts = try await client.history(entityID: id, hours: 24)
                if pts.count > 1 { detailHistory[id] = Self.downsample(pts, to: 240) }
                detailLoaded.insert(id)
            } catch {
                detailFetchedAt[id] = .distantPast   // failed/timed-out fetch → retry, don't stick
            }
            dataVersion &+= 1
        }
    }
    func detail(for id: String) -> [HistoryPoint]? { detailHistory[id] }
    func isDetailLoaded(_ id: String) -> Bool { detailLoaded.contains(id) }

    /// Evenly thin a series to at most `n` points so the chart stays cheap.
    private static func downsample<T>(_ xs: [T], to n: Int) -> [T] {
        guard xs.count > n, n > 1 else { return xs }
        let step = Double(xs.count - 1) / Double(n - 1)
        return (0..<n).map { xs[Int((Double($0) * step).rounded())] }
    }

    func freshness(of id: String) -> Freshness {
        guard let s = store.entities[id] else { return .offline }
        return HomeBarCore.freshness(of: s, now: Date(),
                                     window: settings.perEntityWindow[id] ?? settings.stalenessWindow)
    }
    func entity(_ id: String) -> EntityState? { store.entities[id] }
}
