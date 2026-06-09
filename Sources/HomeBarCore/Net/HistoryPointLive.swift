import Foundation

public extension Array where Element == HistoryPoint {
    /// Extend a fetched history series with a live reading so an open chart updates in real time.
    ///
    /// HomeBar fetches a detail chart's 24h history once when its row is expanded; without this the
    /// chart would show that frozen snapshot until it's closed and reopened. Live `state_changed`
    /// events feed new readings through here, keeping the series a strictly-newer, bounded, rolling
    /// `window`-second view:
    /// - ignores a point not newer than the last sample (HA re-emits state on attribute-only
    ///   changes, and an out-of-order/duplicate timestamp would kink the line),
    /// - drops samples older than `window` before the new point (rolling window),
    /// - caps the total count, dropping the oldest, so a fast sensor can't grow it without bound.
    func appendingLive(_ point: HistoryPoint, window: TimeInterval, cap: Int) -> [HistoryPoint] {
        guard last.map({ point.date > $0.date }) ?? true else { return self }
        let cutoff = point.date.addingTimeInterval(-window)
        var pts = Array(drop { $0.date < cutoff })
        pts.append(point)
        if pts.count > cap { pts.removeFirst(pts.count - cap) }
        return pts
    }
}
