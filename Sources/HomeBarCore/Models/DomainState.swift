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
        isOn = s.isOn
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
        let step = s.attributes["target_temp_step"]?.doubleValue ?? 0.5
        targetTempStep = step > 0 ? step : 0.5   // some integrations report 0 → keep +/- usable
        fanMode = s.attributes["fan_mode"]?.coercedString
        fanModes = s.attributes["fan_modes"]?.stringArray ?? []
    }

    /// The mode to optimistically show when the quick power toggle turns the unit on, before HA
    /// reports what `climate.turn_on` actually restored. Prefers common active modes (an AC lands
    /// on Cool), else the first available non-off mode; `nil` if the unit has no on mode.
    public var defaultOnMode: String? {
        let preferred = ["cool", "heat_cool", "auto", "heat", "dry", "fan_only"]
        return preferred.first { hvacModes.contains($0) } ?? hvacModes.first { $0 != "off" }
    }

    /// The target to send when the user nudges the setpoint one step, clamped to the unit's range.
    /// `base` is the currently displayed target — an optimistic pending value while the user is
    /// nudging, else HA's confirmed target — so repeated taps accumulate instead of snapping back
    /// to HA's (possibly lagging) confirmed value.
    public func steppedTarget(from base: Double, up: Bool) -> Double {
        let next = up ? base + targetTempStep : base - targetTempStep
        return Swift.min(maxTemp, Swift.max(minTemp, next))
    }
}

/// Format a climate setpoint: whole values show no decimal ("24"), fractional values show one
/// ("23.5"). Keeps half-degree steps visible without an ugly ".0" on whole degrees.
public func formatSetpoint(_ value: Double) -> String {
    value.rounded() == value ? String(format: "%.0f", value) : String(format: "%.1f", value)
}

public enum Freshness: Sendable, Equatable { case fresh, stale, offline }

public func freshness(of s: EntityState, now: Date, window: TimeInterval) -> Freshness {
    if !s.isAvailable { return .offline }
    return now.timeIntervalSince(s.lastUpdated) > window ? .stale : .fresh
}
