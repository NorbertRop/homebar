import Testing
import Foundation
@testable import HomeBarCore

private final class SpyNotifier: Notifier, @unchecked Sendable {
    var offline: [String] = []
    var recovered: [String] = []
    func deviceWentOffline(name: String, entityID: String) { offline.append(entityID) }
    func deviceRecovered(name: String, entityID: String) { recovered.append(entityID) }
}

private func entity(_ id: String, state: String = "on", updated: Date) -> EntityState {
    EntityState(entityID: id, state: state, attributes: [:], lastChanged: updated, lastUpdated: updated)
}

@Test func notifiesOnTransitionOnlyAndRecovers() {
    let spy = SpyNotifier()
    let monitor = StalenessMonitor(notifier: spy)
    let t0 = Date(timeIntervalSince1970: 0)

    _ = monitor.evaluate([entity("sensor.x", updated: t0)], now: t0, window: 900)
    #expect(spy.offline.isEmpty)

    let t1 = t0.addingTimeInterval(1200)
    _ = monitor.evaluate([entity("sensor.x", updated: t0)], now: t1, window: 900)
    _ = monitor.evaluate([entity("sensor.x", updated: t0)], now: t1, window: 900)  // still stale
    #expect(spy.offline == ["sensor.x"])   // not duplicated

    _ = monitor.evaluate([entity("sensor.x", updated: t1)], now: t1, window: 900)
    #expect(spy.recovered == ["sensor.x"])
}

@Test func unavailableCountsAsOffline() {
    let spy = SpyNotifier()
    let monitor = StalenessMonitor(notifier: spy)
    let now = Date(timeIntervalSince1970: 0)
    _ = monitor.evaluate([entity("sensor.x", updated: now)], now: now, window: 900)
    _ = monitor.evaluate([entity("sensor.x", state: "unavailable", updated: now)], now: now, window: 900)
    #expect(spy.offline == ["sensor.x"])
}

@Test func firstEvaluateBaselinesWithoutNotifying() {
    let spy = SpyNotifier()
    let monitor = StalenessMonitor(notifier: spy)
    let now = Date(timeIntervalSince1970: 0)
    // Already offline on the very first evaluate → silent baseline, no notification storm.
    _ = monitor.evaluate([entity("sensor.x", state: "unavailable", updated: now)], now: now, window: 900)
    #expect(spy.offline.isEmpty)
    _ = monitor.evaluate([entity("sensor.x", state: "unavailable", updated: now)], now: now, window: 900)
    #expect(spy.offline.isEmpty)   // still no transition
}
