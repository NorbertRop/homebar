import SwiftUI
import Charts
import HomeBarCore

/// Expanded inline detail for a numeric sensor: a larger ~24h chart (with a hover crosshair)
/// plus min / max / avg.
struct SensorDetailView: View {
    let model: AppModel
    let entityID: String
    @State private var hover: HistoryPoint?

    var body: some View {
        let pts = model.detail(for: entityID) ?? []
        let unit = model.entity(entityID)?.unit
        let color = sensorColor(model.entity(entityID)?.deviceClass)
        Group {
            if pts.count > 1 {
                let vals = pts.map(\.value)
                let lo = vals.min() ?? 0, hi = vals.max() ?? 1
                let pad = max((hi - lo) * 0.12, 0.5)
                VStack(alignment: .leading, spacing: 6) {
                    chart(pts, lo: lo, hi: hi, pad: pad, color: color, unit: unit).frame(height: 116)
                    stats(vals, lo: lo, hi: hi, unit: unit)
                }
            } else {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Loading history…").font(.caption).foregroundStyle(.secondary)
                }
                .frame(height: 80).frame(maxWidth: .infinity)
            }
        }
        .padding(.leading, 26).padding(.trailing, 6).padding(.bottom, 4)
    }

    private func chart(_ pts: [HistoryPoint], lo: Double, hi: Double, pad: Double,
                       color: Color, unit: String?) -> some View {
        Chart {
            ForEach(pts, id: \.date) { pt in
                LineMark(x: .value("Time", pt.date), y: .value("Value", pt.value))
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
            }
            if let h = hover {
                RuleMark(x: .value("Time", h.date))
                    .foregroundStyle(.secondary.opacity(0.4))
                    .annotation(position: .top, spacing: 2,
                                overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(compactValue(h.value, unit: unit)).font(.caption).bold().monospacedDigit()
                            Text(h.date.formatted(date: .omitted, time: .shortened))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                    }
                PointMark(x: .value("Time", h.date), y: .value("Value", h.value))
                    .foregroundStyle(color).symbolSize(60)
            }
        }
        .chartYScale(domain: (lo - pad)...(hi + pad))
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 6)) { _ in
                AxisGridLine().foregroundStyle(.quaternary)
                AxisValueLabel(format: .dateTime.hour())
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: [lo, (lo + hi) / 2, hi]) { _ in
                AxisGridLine().foregroundStyle(.quaternary)
                AxisValueLabel()
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let loc):
                            guard let plot = proxy.plotFrame else { return }
                            let x = loc.x - geo[plot].origin.x
                            guard let date: Date = proxy.value(atX: x) else { return }
                            hover = pts.min {
                                abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
                            }
                        case .ended:
                            hover = nil
                        }
                    }
            }
        }
    }

    private func stats(_ vals: [Double], lo: Double, hi: Double, unit: String?) -> some View {
        HStack(spacing: 16) {
            stat("Now", vals.last ?? 0, unit)
            stat("Min", lo, unit)
            stat("Max", hi, unit)
            stat("Avg", vals.reduce(0, +) / Double(vals.count), unit)
            Spacer()
            Text("last 24h").font(.caption2).foregroundStyle(.tertiary)
        }
    }

    private func stat(_ label: String, _ v: Double, _ unit: String?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label).font(.caption2).foregroundStyle(.tertiary)
            Text(compactValue(v, unit: unit)).font(.caption).monospacedDigit()
        }
    }
}
