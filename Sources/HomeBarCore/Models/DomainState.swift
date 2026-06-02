import Foundation

public struct RGB: Sendable, Equatable { public var r, g, b: Int
    public init(r: Int, g: Int, b: Int) { self.r = r; self.g = g; self.b = b } }

public struct LightState: Sendable, Equatable {
    public let isOn: Bool
    public let brightnessPercent: Int?
    public let rgb: RGB?
    public let colorTempKelvin: Int?
    public let supportsColor: Bool
    public let supportsColorTemp: Bool
    public let minColorTempKelvin: Int?
    public let maxColorTempKelvin: Int?

    public init(from s: EntityState) {
        isOn = s.state == "on"
        if let b = s.attributes["brightness"]?.intValue {
            brightnessPercent = Int((Double(b) / 255.0 * 100).rounded())
        } else { brightnessPercent = nil }
        if let arr = s.attributes["rgb_color"]?.arrayValue, arr.count == 3 {
            rgb = RGB(r: arr[0].intValue ?? 0, g: arr[1].intValue ?? 0, b: arr[2].intValue ?? 0)
        } else { rgb = nil }
        colorTempKelvin = s.attributes["color_temp_kelvin"]?.intValue
        let modes = s.attributes["supported_color_modes"]?.stringArray ?? []
        supportsColor = !modes.filter { ["rgb", "rgbw", "rgbww", "hs", "xy"].contains($0) }.isEmpty
        supportsColorTemp = modes.contains("color_temp")
        minColorTempKelvin = s.attributes["min_color_temp_kelvin"]?.intValue
        maxColorTempKelvin = s.attributes["max_color_temp_kelvin"]?.intValue
    }
}

public struct ClimateState: Sendable, Equatable {
    public let hvacMode: String
    public let hvacModes: [String]
    public let currentTemperature: Double?
    public let targetTemperature: Double?
    public let minTemp: Double
    public let maxTemp: Double
    public let targetTempStep: Double
    public let fanMode: String?
    public let fanModes: [String]

    public init(from s: EntityState) {
        hvacMode = s.state
        hvacModes = s.attributes["hvac_modes"]?.stringArray ?? []
        currentTemperature = s.attributes["current_temperature"]?.doubleValue
        targetTemperature = s.attributes["temperature"]?.doubleValue
        minTemp = s.attributes["min_temp"]?.doubleValue ?? 7
        maxTemp = s.attributes["max_temp"]?.doubleValue ?? 35
        targetTempStep = s.attributes["target_temp_step"]?.doubleValue ?? 0.5
        fanMode = s.attributes["fan_mode"]?.coercedString
        fanModes = s.attributes["fan_modes"]?.stringArray ?? []
    }
}

public enum Freshness: Sendable, Equatable { case fresh, stale, offline }

public func freshness(of s: EntityState, now: Date, window: TimeInterval) -> Freshness {
    if !s.isAvailable { return .offline }
    return now.timeIntervalSince(s.lastUpdated) > window ? .stale : .fresh
}
