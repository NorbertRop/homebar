import Testing
import Foundation
@testable import HomeBarCore

@Test func settingsRoundTripToDisk() throws {
    var s = Settings()
    s.serverURL = URL(string: "http://homeassistant.local:8123")
    s.stalenessWindow = 600
    s.pinned = ["light.desk_lamp"]
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let url = dir.appendingPathComponent("settings.json")
    try s.save(to: url)
    #expect(Settings.load(from: url) == s)
}

@Test func inMemoryTokenStore() {
    let store = InMemoryTokenStore()
    #expect(store.read() == nil)
    try? store.write("secret")
    #expect(store.read() == "secret")
    try? store.delete()
    #expect(store.read() == nil)
}
