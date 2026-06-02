import Testing
import Foundation
@testable import HomeBarCore

private func entity(_ id: String, _ state: String) -> EntityState {
    EntityState(entityID: id, state: state, attributes: [:], lastChanged: .now, lastUpdated: .now)
}

@MainActor @Test func snapshotThenDeltaUpdatesAndRemoves() {
    let store = StateStore()
    store.applySnapshot([entity("light.x", "off"), entity("sensor.y", "5")])
    #expect(store.entities.count == 2)
    store.apply(StateChange(entityID: "light.x", newState: entity("light.x", "on")))
    #expect(store.entities["light.x"]?.state == "on")
    store.apply(StateChange(entityID: "sensor.y", newState: nil))   // removed
    #expect(store.entities["sensor.y"] == nil)
}

@MainActor @Test func cacheRoundTrips() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let url = dir.appendingPathComponent("cache.json")
    let store = StateStore()
    store.applySnapshot([entity("light.x", "on")])
    try store.saveCache(to: url)

    let restored = StateStore()
    restored.loadCache(from: url)
    #expect(restored.entities["light.x"]?.state == "on")
}
