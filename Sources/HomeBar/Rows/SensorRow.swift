import SwiftUI
import HomeBarCore

struct SensorRow: View {
    let model: AppModel
    let entityID: String
    var nameOverride: String? = nil
    @State private var expanded = false

    var body: some View {
        if let s = model.entity(entityID) {
            let numeric = Double(s.state) != nil
            VStack(alignment: .leading, spacing: 6) {
                if numeric {
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) { expanded.toggle() }
                        if expanded { model.loadDetail(entityID) }
                    } label: { header(s, expandable: true) }
                    .buttonStyle(.plain)
                } else {
                    header(s, expandable: false)
                }
                if expanded, numeric {
                    SensorDetailView(model: model, entityID: entityID)
                }
            }
            .onAppear { if numeric { model.loadHistory(entityID) } }
        }
    }

    private func header(_ s: EntityState, expandable: Bool) -> some View {
        let value = displayValue(s)
        // A long, non-numeric value (e.g. a status message) reads as a subtitle under the name
        // instead of squeezing the name to fit a full-width right-aligned sentence.
        let longText = Double(s.state) == nil && s.deviceClass != "timestamp" && value.count > 18
        return HStack(alignment: longText ? .top : .center, spacing: 8) {
            Image(systemName: sensorSymbol(s.deviceClass)).frame(width: 18).foregroundStyle(.secondary)
            if longText {
                VStack(alignment: .leading, spacing: 1) {
                    Text(nameOverride ?? s.friendlyName).lineLimit(1)
                    Text(value).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer(minLength: 0)
            } else {
                Text(nameOverride ?? s.friendlyName).lineLimit(1).truncationMode(.tail)
                Spacer(minLength: 6)
                if let pts = model.sparkline(for: entityID), pts.count > 1 {
                    Sparkline(values: pts, fill: true, dot: true)
                        .frame(width: 40, height: 16).foregroundStyle(chartTint)
                }
                // Value keeps full width; the name truncates instead so digits never get cramped.
                Text(value).foregroundStyle(.secondary).monospacedDigit()
                    .lineLimit(1).fixedSize(horizontal: true, vertical: false)
            }
            if expandable {
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(expanded ? 90 : 0))
            }
        }
        .contentShape(Rectangle())
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
