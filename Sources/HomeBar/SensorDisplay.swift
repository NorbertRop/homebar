import Foundation
import HomeBarCore

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

extension EntityState {
    /// A compact value suited to the menu bar: "21°", "47%", "612 ppm".
    var menuBarValue: String {
        guard let d = Double(state) else { return state.capitalized }
        let n = d == d.rounded() ? String(Int(d)) : String(format: "%.1f", d)
        guard let u = unit else { return n }
        switch u {
        case "°C", "°F": return "\(n)°"
        case "%": return "\(n)%"
        default: return "\(n) \(u)"
        }
    }
}
