import Foundation
import HomeBarCore
import Observation

@MainActor @Observable final class AppModel {
    let store = StateStore()
    var settings: Settings
    var connection: HAClient.ConnectionState = .disconnected
    var offlineEntityIDs: Set<String> = []
    var offlineCount: Int { offlineEntityIDs.count }

    let tokenStore: TokenStore
    private let notifier: UserNotificationNotifier
    private let monitor: StalenessMonitor
    private var client: HAClient?
    private var connectTask: Task<Void, Never>?

    static let cacheURL = Settings.defaultURL().deletingLastPathComponent()
        .appendingPathComponent("state-cache.json")

    init(tokenStore: TokenStore = KeychainTokenStore()) {
        self.tokenStore = tokenStore
        let n = UserNotificationNotifier()
        self.notifier = n
        self.monitor = StalenessMonitor(notifier: n)
        self.settings = Settings.load(from: Settings.defaultURL())
        notifier.enabled = settings.notifyOffline
        store.loadCache(from: Self.cacheURL)
    }

    var isConfigured: Bool { settings.serverURL != nil && tokenStore.read() != nil }

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
        guard let base = settings.serverURL, let token = tokenStore.read(),
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
                store.applySnapshot(try await client.getStates())
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
                    try? store.saveCache(to: Self.cacheURL)
                    evaluateStaleness()
                }
                ticker.cancel()
            } catch { /* fall through to reconnect */ }
            await client.disconnect()
            connection = .disconnected
            attempt += 1
            try? await Task.sleep(for: .seconds(min(30, pow(2, Double(min(attempt, 5))))))
        }
    }

    private func evaluateStaleness() {
        let fresh = monitor.evaluate(Array(store.entities.values), now: Date(),
                                     window: settings.stalenessWindow,
                                     perEntityWindow: settings.perEntityWindow)
        offlineEntityIDs = Set(fresh.filter { $0.value != .fresh }.map(\.key))
    }

    func perform(_ call: ServiceCall) { Task { try? await client?.send(call) } }
    func toggle(_ id: String) { perform(HACommand.toggle(id)) }

    func freshness(of id: String) -> Freshness {
        guard let s = store.entities[id] else { return .offline }
        return HomeBarCore.freshness(of: s, now: Date(),
                                     window: settings.perEntityWindow[id] ?? settings.stalenessWindow)
    }
    func entity(_ id: String) -> EntityState? { store.entities[id] }
}
