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

// Real-world: some climate integrations report fan_mode as an integer while
// fan_modes are strings (observed on a live A/C). fanMode must coerce to String.
@Test func climateFanModeCoercesIntegerToString() {
    let s = EntityState(entityID: "climate.ac", state: "cool",
        attributes: ["fan_mode": .int(3),
                     "fan_modes": .array([.string("1"), .string("2"), .string("3")])],
        lastChanged: .now, lastUpdated: .now)
    let cs = ClimateState(from: s)
    #expect(cs.fanMode == "3")
    #expect(cs.fanModes == ["1", "2", "3"])
}

// The quick-toggle's optimistic "on" mode: which hvac mode to show the instant the user taps
// power, before HA confirms what `climate.turn_on` actually restored.
private func climate(modes: [String], state: String = "off") -> ClimateState {
    ClimateState(from: EntityState(entityID: "climate.ac", state: state,
        attributes: ["hvac_modes": .array(modes.map { .string($0) })],
        lastChanged: .now, lastUpdated: .now))
}

@Test func defaultOnModePrefersCool() {
    #expect(climate(modes: ["off", "heat", "cool", "auto"]).defaultOnMode == "cool")
}

@Test func defaultOnModeFollowsPreferenceOrder() {
    #expect(climate(modes: ["off", "heat", "auto"]).defaultOnMode == "auto")   // auto before heat
    #expect(climate(modes: ["off", "heat", "dry"]).defaultOnMode == "heat")    // heat before dry
}

@Test func defaultOnModeFallsBackToFirstNonOff() {
    #expect(climate(modes: ["off", "boost", "eco"]).defaultOnMode == "boost")  // none preferred → first non-off
}

@Test func defaultOnModeNilWhenNoOnMode() {
    #expect(climate(modes: ["off"]).defaultOnMode == nil)
    #expect(climate(modes: []).defaultOnMode == nil)
}

// Temperature stepping for the +/- buttons. `base` is the currently displayed target (an
// optimistic pending value while the user is nudging, else HA's confirmed target), so repeated
// taps must accumulate and stay within the unit's range.
private func climateWithTemps(step: Double = 1.0, min: Double = 16, max: Double = 30,
                              target: Double = 24) -> ClimateState {
    ClimateState(from: EntityState(entityID: "climate.ac", state: "cool",
        attributes: ["temperature": .double(target), "min_temp": .double(min),
                     "max_temp": .double(max), "target_temp_step": .double(step)],
        lastChanged: .now, lastUpdated: .now))
}

@Test func climateSteppedTargetNudgesByStep() {
    let c = climateWithTemps(step: 0.5, target: 24)
    #expect(c.steppedTarget(from: 24, up: true) == 24.5)
    #expect(c.steppedTarget(from: 24, up: false) == 23.5)
}

@Test func climateSteppedTargetClampsToRange() {
    let c = climateWithTemps(step: 1, min: 16, max: 30)
    #expect(c.steppedTarget(from: 30, up: true) == 30)    // already at max
    #expect(c.steppedTarget(from: 16, up: false) == 16)   // already at min
}

@Test func climateSteppedTargetAccumulates() {
    let c = climateWithTemps(step: 0.5, target: 24)
    let once = c.steppedTarget(from: 24, up: true)
    #expect(c.steppedTarget(from: once, up: true) == 25.0)   // two taps build on each other
}

// Some integrations report target_temp_step: 0 (or omit it), which would make +/- a no-op.
@Test func climateStepFallsBackWhenNonPositive() {
    #expect(climateWithTemps(step: 0).targetTempStep == 0.5)
    #expect(climateWithTemps(step: -1).targetTempStep == 0.5)
}

// Setpoint display keeps half-degree steps visible without an ugly ".0" on whole degrees.
@Test func setpointFormatDropsTrailingZero() {
    #expect(formatSetpoint(24) == "24")
    #expect(formatSetpoint(21.0) == "21")
    #expect(formatSetpoint(23.5) == "23.5")
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
