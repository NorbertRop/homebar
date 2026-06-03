import SwiftUI
import HomeBarCore

/// One deliberately-chosen accent for every sensor chart/sparkline — distinct from the gray
/// chrome, applied consistently. Change this single value to restyle all charts at once.
let chartTint: Color = .teal

/// SF Symbol for a sensor's device class — shared by the sensor row and the menu-bar label.
func sensorSymbol(_ deviceClass: String?) -> String {
    switch deviceClass {
    case "temperature": "thermometer"
    case "humidity": "humidity.fill"
    case "carbon_dioxide": "aqi.medium"
    case "pressure", "atmospheric_pressure": "barometer"
    case "illuminance": "sun.max.fill"
    case "power", "energy": "bolt.fill"
    case "battery": "battery.50"
    case "timestamp": "clock"
    case "door", "window", "opening": "door.left.hand.closed"
    case "motion": "figure.walk"
    case "moisture": "drop.fill"
    case "connectivity": "wifi"
    default: "circle.dotted"
    }
}

/// Compact numeric formatting shared by the menu-bar label and the sensor detail stats:
/// "21°", "47%", "612 ppm".
func compactValue(_ v: Double, unit: String?) -> String {
    let n = v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
    guard let u = unit else { return n }
    switch u {
    case "°C", "°F": return "\(n)°"
    case "%": return "\(n)%"
    default: return "\(n) \(u)"
    }
}

extension EntityState {
    /// A compact value suited to the menu bar: "21°", "47%", "612 ppm".
    var menuBarValue: String { Double(state).map { compactValue($0, unit: unit) } ?? state.capitalized }
}
