import SwiftUI
import HomeBarCore

struct SensorRow: View {
    let model: AppModel
    let entityID: String
    var nameOverride: String? = nil

    var body: some View {
        if let s = model.entity(entityID) {
            HStack {
                Image(systemName: sensorSymbol(s.deviceClass)).frame(width: 18).foregroundStyle(.secondary)
                Text(nameOverride ?? s.friendlyName).lineLimit(1)
                Spacer()
                Text(displayValue(s)).foregroundStyle(.secondary).monospacedDigit().lineLimit(1)
            }
        }
    }

    private func displayValue(_ s: EntityState) -> String {
        if s.domain == .binarySensor { return binaryLabel(s) }
        if let t = timestamp(s) { return t }
        let value = roundedNumber(s.state) ?? s.state
        return "\(value)\(s.unit.map { " \($0)" } ?? "")"
    }

    /// Render a `timestamp` sensor as a friendly relative time ("in 8h") instead of a raw
    /// ISO-8601 string.
    private func timestamp(_ s: EntityState) -> String? {
        guard s.deviceClass == "timestamp" else { return nil }
        let iso = ISO8601DateFormatter(); iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter(); plain.formatOptions = [.withInternetDateTime]
        guard let date = iso.date(from: s.state) ?? plain.date(from: s.state) else { return nil }
        let rel = RelativeDateTimeFormatter(); rel.unitsStyle = .abbreviated
        let relative = rel.localizedString(for: date, relativeTo: Date())
        let clock = date.formatted(date: .omitted, time: .shortened)
        return "\(relative) · \(clock)"
    }

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
        case "connectivity": s.state == "on" ? "Connected" : "Disconnected"
        default: s.state == "on" ? "On" : "Off"
        }
    }
}
