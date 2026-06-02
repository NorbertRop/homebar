import Testing
import Foundation
@testable import HomeBarCore

private func loadStates() throws -> [EntityState] {
    let url = Bundle.module.url(forResource: "Fixtures/states", withExtension: "json")!
    return try HAJSON.makeDecoder().decode([EntityState].self, from: Data(contentsOf: url))
}

@Test func lightStateReadsBrightnessColorAndCaps() throws {
    let light = try loadStates().first { $0.entityID == "light.desk_lamp" }!
    let ls = LightState(from: light)
    #expect(ls.isOn == true)
    #expect(ls.brightnessPercent == 80)               // 204/255 ≈ 80%
    #expect(ls.rgb == RGB(r: 255, g: 128, b: 0))
    #expect(ls.supportsColor == true)
    #expect(ls.supportsColorTemp == true)
    #expect(ls.maxColorTempKelvin == 6500)
}

@Test func climateStateReadsTempsModesAndFan() throws {
    let ac = try loadStates().first { $0.entityID == "climate.living_room_ac" }!
    let cs = ClimateState(from: ac)
    #expect(cs.hvacMode == "cool")
    #expect(cs.currentTemperature == 22.0)
    #expect(cs.targetTemperature == 24.0)
    #expect(cs.minTemp == 16.0 && cs.maxTemp == 30.0 && cs.targetTempStep == 1.0)
    #expect(cs.hvacModes.contains("dry"))
    #expect(cs.fanMode == "auto")
    #expect(cs.fanModes == ["auto", "low", "high"])
}

@Test func freshnessClassifies() {
    let now = Date(timeIntervalSince1970: 1000)
    func mk(_ state: String, ageSeconds: TimeInterval) -> EntityState {
        EntityState(entityID: "sensor.x", state: state, attributes: [:],
                    lastChanged: now, lastUpdated: now.addingTimeInterval(-ageSeconds))
    }
    #expect(freshness(of: mk("21", ageSeconds: 10), now: now, window: 900) == .fresh)
    #expect(freshness(of: mk("21", ageSeconds: 1000), now: now, window: 900) == .stale)
    #expect(freshness(of: mk("unavailable", ageSeconds: 1), now: now, window: 900) == .offline)
}
