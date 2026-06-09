import Testing
import Foundation
@testable import HomeBarCore

private func pt(_ secs: TimeInterval, _ value: Double) -> HistoryPoint {
    HistoryPoint(date: Date(timeIntervalSince1970: secs), value: value)
}

@Test func appendingLiveAddsNewerReading() {
    let series = [pt(0, 1), pt(60, 2)]
    let out = series.appendingLive(pt(120, 3), window: 86_400, cap: 1000)
    #expect(out.map(\.value) == [1, 2, 3])
}

@Test func appendingLiveIgnoresNonNewerReading() {
    let series = [pt(0, 1), pt(60, 2)]
    #expect(series.appendingLive(pt(60, 9), window: 86_400, cap: 1000) == series)   // same timestamp
    #expect(series.appendingLive(pt(30, 9), window: 86_400, cap: 1000) == series)   // older (out of order)
}

@Test func appendingLiveTrimsPointsOlderThanWindow() {
    let series = [pt(0, 1), pt(100, 2), pt(200, 3)]
    // From the new point at 300 and a 150s window, the cutoff is 150 → drop points at 0 and 100.
    let out = series.appendingLive(pt(300, 4), window: 150, cap: 1000)
    #expect(out.map(\.value) == [3, 4])
}

@Test func appendingLiveCapsLengthDroppingOldest() {
    let series = (0..<5).map { pt(Double($0) * 60, Double($0)) }   // values 0,1,2,3,4
    let out = series.appendingLive(pt(600, 5), window: 86_400, cap: 3)
    #expect(out.map(\.value) == [3, 4, 5])
}

@Test func appendingLiveToEmptyStartsSeries() {
    let out = [HistoryPoint]().appendingLive(pt(10, 1), window: 86_400, cap: 1000)
    #expect(out == [pt(10, 1)])
}
