import SwiftUI
import Charts
import HomeBarCore

/// Expanded inline detail for a numeric sensor: a larger ~24h chart plus min / max / avg.
struct SensorDetailView: View {
    let model: AppModel
    let entityID: String

    var body: some View {
        let pts = model.detail(for: entityID) ?? []
        Group {
            if pts.count > 1 {
                let vals = pts.map(\.value)
                let lo = vals.min() ?? 0, hi = vals.max() ?? 1
                let pad = max((hi - lo) * 0.12, 0.5)
                VStack(alignment: .leading, spacing: 6) {
                    Chart(pts, id: \.date) { pt in
                        AreaMark(x: .value("Time", pt.date), y: .value("Value", pt.value))
                            .foregroundStyle(LinearGradient(colors: [.accentColor.opacity(0.22), .clear],
                                                            startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("Time", pt.date), y: .value("Value", pt.value))
                            .foregroundStyle(.tint)
                            .interpolationMethod(.catmullRom)
                    }
                    .chartYScale(domain: (lo - pad)...(hi + pad))
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .hour, count: 6)) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.hour())
                        }
                    }
                    .chartYAxis { AxisMarks(position: .trailing, values: [lo, (lo + hi) / 2, hi]) }
                    .frame(height: 116)

                    HStack(spacing: 16) {
                        stat("Now", vals.last ?? 0)
                        stat("Min", lo)
                        stat("Max", hi)
                        stat("Avg", vals.reduce(0, +) / Double(vals.count))
                        Spacer()
                        Text("last 24h").font(.caption2).foregroundStyle(.tertiary)
                    }
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

    private func stat(_ label: String, _ v: Double) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label).font(.caption2).foregroundStyle(.tertiary)
            Text(compactValue(v, unit: model.entity(entityID)?.unit)).font(.caption).monospacedDigit()
        }
    }
}
