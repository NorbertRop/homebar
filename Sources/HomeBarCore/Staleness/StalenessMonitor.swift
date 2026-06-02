import Foundation

/// Tracks per-entity freshness and fires the notifier only on transitions
/// into "down" (stale or offline) and back to fresh. The very first evaluation
/// establishes a silent baseline — otherwise every already-offline device would
/// fire a notification on launch.
public final class StalenessMonitor {
    private var previous: [String: Freshness] = [:]
    private var hasBaseline = false
    private let notifier: Notifier

    public init(notifier: Notifier) { self.notifier = notifier }

    @discardableResult
    public func evaluate(_ entities: [EntityState], now: Date, window: TimeInterval,
                         perEntityWindow: [String: TimeInterval] = [:]) -> [String: Freshness] {
        var current: [String: Freshness] = [:]
        for e in entities {
            let w = perEntityWindow[e.entityID] ?? window
            current[e.entityID] = freshness(of: e, now: now, window: w)
        }

        if !hasBaseline {
            hasBaseline = true
            previous = current
            return current
        }

        for e in entities {
            let f = current[e.entityID] ?? .fresh
            let wasDown = (previous[e.entityID] ?? .fresh) != .fresh
            let isDown = f != .fresh
            if isDown && !wasDown { notifier.deviceWentOffline(name: e.friendlyName, entityID: e.entityID) }
            else if !isDown && wasDown { notifier.deviceRecovered(name: e.friendlyName, entityID: e.entityID) }
        }
        previous = current
        return current
    }
}
