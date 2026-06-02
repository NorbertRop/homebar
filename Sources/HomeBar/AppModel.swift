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

    let tokenStore: TokenStore
    private let notifier: UserNotificationNotifier
    private let monitor: StalenessMonitor
    private var client: HAClient?
    private var connectTask: Task<Void, Never>?

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
        connectTask?.cancel(); connectTask = nil
        Task { await client?.disconnect(); client = nil; start() }
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
                try? store.saveCache(to: Self.cacheURL)
                evaluateStaleness()
                try await client.subscribeStateChanges()
                let ticker = Task { [weak self] in
                    while !Task.isCancelled {
                        try? await Task.sleep(for: .seconds(30))
                        self?.evaluateStaleness()
                    }
                }
                for await change in client.events {
                    store.apply(change)
                    dataVersion &+= 1
                    try? store.saveCache(to: Self.cacheURL)
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

    func freshness(of id: String) -> Freshness {
        guard let s = store.entities[id] else { return .offline }
        return HomeBarCore.freshness(of: s, now: Date(),
                                     window: settings.perEntityWindow[id] ?? settings.stalenessWindow)
    }
    func entity(_ id: String) -> EntityState? { store.entities[id] }
}
