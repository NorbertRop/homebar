import Testing
import Foundation
@testable import HomeBarCore

private func decode(_ s: String) -> JSONValue {
    try! HAJSON.makeDecoder().decode(JSONValue.self, from: s.data(using: .utf8)!)
}

@Test func authAndSimpleFrames() {
    #expect(decode(authFrame(token: "abc"))["type"]?.stringValue == "auth")
    #expect(decode(authFrame(token: "abc"))["access_token"]?.stringValue == "abc")
    let gs = decode(simpleFrame(id: 1, type: "get_states"))
    #expect(gs["id"]?.intValue == 1 && gs["type"]?.stringValue == "get_states")
    let sub = decode(subscribeFrame(id: 2, eventType: "state_changed"))
    #expect(sub["type"]?.stringValue == "subscribe_events")
    #expect(sub["event_type"]?.stringValue == "state_changed")
}

@Test func toggleBuildsDomainFromEntity() {
    let call = HACommand.toggle("switch.coffee")
    #expect(call == ServiceCall(domain: "switch", service: "toggle", data: [:], target: "switch.coffee"))
    #expect(HACommand.toggle("light.x").domain == "light")
    #expect(HACommand.toggle("automation.x").domain == "automation")
}

@Test func setLightBuildsColorAndBrightness() {
    let on = HACommand.setLight("light.x", on: true, brightnessPercent: 80,
                                rgb: RGB(r: 255, g: 0, b: 0), colorTempKelvin: nil)
    #expect(on.domain == "light" && on.service == "turn_on")
    #expect(on.data["brightness_pct"]?.intValue == 80)
    #expect(on.data["rgb_color"]?.arrayValue?.compactMap(\.intValue) == [255, 0, 0])
    let off = HACommand.setLight("light.x", on: false, brightnessPercent: nil, rgb: nil, colorTempKelvin: nil)
    #expect(off.service == "turn_off")
}

@Test func climateBuilders() {
    #expect(HACommand.setClimateTemperature("climate.ac", 23).data["temperature"]?.doubleValue == 23)
    #expect(HACommand.setClimateMode("climate.ac", "heat").data["hvac_mode"]?.stringValue == "heat")
    #expect(HACommand.setClimateFan("climate.ac", "low").service == "set_fan_mode")
}

@Test func automationBuilders() {
    #expect(HACommand.runAutomation("automation.m") == ServiceCall(domain: "automation", service: "trigger", data: [:], target: "automation.m"))
    #expect(HACommand.armAutomation("automation.m", armed: false).service == "turn_off")
}

@Test func callServiceFrameRoundTrips() throws {
    let frame = try callServiceFrame(id: 7, HACommand.setLight("light.x", on: true,
                  brightnessPercent: 50, rgb: nil, colorTempKelvin: nil))
    let obj = decode(frame)
    #expect(obj["id"]?.intValue == 7)
    #expect(obj["type"]?.stringValue == "call_service")
    #expect(obj["domain"]?.stringValue == "light")
    #expect(obj["service"]?.stringValue == "turn_on")
    #expect(obj["target"]?["entity_id"]?.stringValue == "light.x")
    #expect(obj["service_data"]?["brightness_pct"]?.intValue == 50)
}
