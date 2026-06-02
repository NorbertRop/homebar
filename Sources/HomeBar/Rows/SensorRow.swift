import SwiftUI
import HomeBarCore

struct SensorRow: View {
    let model: AppModel
    let entityID: String
    var body: some View {
        if let s = model.entity(entityID) {
            HStack {
                Image(systemName: icon(for: s.deviceClass)).frame(width: 18)
                Text(s.friendlyName).lineLimit(1)
                Spacer()
                Text(displayValue(s)).foregroundStyle(.secondary).monospacedDigit()
                FreshnessDot(freshness: model.freshness(of: entityID))
            }
        }
    }
    private func displayValue(_ s: EntityState) -> String {
        if s.domain == .binarySensor { return binaryLabel(s) }
        return "\(s.state)\(s.unit.map { " \($0)" } ?? "")"
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
