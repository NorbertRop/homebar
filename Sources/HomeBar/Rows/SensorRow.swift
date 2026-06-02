import SwiftUI
import HomeBarCore

struct SensorRow: View {
    let model: AppModel
    let entityID: String
    var body: some View {
        if let s = model.entity(entityID) {
            HStack {
                Image(systemName: icon(for: s.deviceClass)).frame(width: 18).foregroundStyle(.secondary)
                Text(s.friendlyName).lineLimit(1)
                Spacer()
                Text(displayValue(s)).foregroundStyle(.secondary).monospacedDigit()
                FreshnessDot(freshness: model.freshness(of: entityID))
            }
        }
    }
    private func displayValue(_ s: EntityState) -> String {
        if s.domain == .binarySensor { return binaryLabel(s) }
        let value = roundedNumber(s.state) ?? s.state
        return "\(value)\(s.unit.map { " \($0)" } ?? "")"
    }
    /// Trim noisy float precision from numeric sensor states (e.g. 25.0534 -> 25.1,
    /// 581.0 -> 581); leaves non-numeric states ("on", "home") untouched.
    private func roundedNumber(_ raw: String) -> String? {
        guard let d = Double(raw) else { return nil }
        if d == d.rounded() { return String(Int(d)) }
        return String(format: "%.1f", d)
    }
    private func binaryLabel(_ s: EntityState) -> String {
        switch s.deviceClass {
        case "door", "window", "opening": s.state == "on" ? "Open" : "Closed"
        case "motion": s.state == "on" ? "Motion" : "Clear"
        case "moisture": s.state == "on" ? "Wet" : "Dry"
        default: s.state == "on" ? "On" : "Off"
        }
    }
    private func icon(for deviceClass: String?) -> String {
        switch deviceClass {
        case "temperature": "thermometer"; case "humidity": "humidity"
        case "carbon_dioxide": "carbon.dioxide.cloud"; case "pressure", "atmospheric_pressure": "gauge"
        case "power", "energy": "bolt"; case "door", "window": "door.left.hand.closed"
        case "motion": "figure.walk"; default: "sensor"
        }
    }
}
