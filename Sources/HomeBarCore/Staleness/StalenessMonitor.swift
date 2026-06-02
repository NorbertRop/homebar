import Foundation

/// Tracks per-entity freshness and fires the notifier only on transitions
/// into "down" (stale or offline) and back to fresh.
public final class StalenessMonitor {
    private var previous: [String: Freshness] = [:]
    private let notifier: Notifier

    public init(notifier: Notifier) { self.notifier = notifier }

    @discardableResult
    public func evaluate(_ entities: [EntityState], now: Date, window: TimeInterval,
                         perEntityWindow: [String: TimeInterval] = [:]) -> [String: Freshness] {
        var current: [String: Freshness] = [:]
        for e in entities {
            let w = perEntityWindow[e.entityID] ?? window
            let f = freshness(of: e, now: now, window: w)
            current[e.entityID] = f
            let wasDown = (previous[e.entityID] ?? .fresh) != .fresh
            let isDown = f != .fresh
            if isDown && !wasDown { notifier.deviceWentOffline(name: e.friendlyName, entityID: e.entityID) }
            else if !isDown && wasDown { notifier.deviceRecovered(name: e.friendlyName, entityID: e.entityID) }
        }
        previous = current
        return current
    }
}
