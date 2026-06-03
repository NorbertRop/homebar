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
        let color = chartTint
        Group {
            if pts.count > 1 {
                let vals = pts.map(\.value)
                let lo = vals.min() ?? 0, hi = vals.max() ?? 1
                VStack(alignment: .leading, spacing: 6) {
                    chart(pts, color: color, unit: unit).frame(height: 116)
                    stats(vals, lo: lo, hi: hi, unit: unit)
                }
            } else if model.isDetailLoaded(entityID) {
                Text("No history available").font(.caption).foregroundStyle(.secondary)
                    .frame(height: 80).frame(maxWidth: .infinity)
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

    private func chart(_ pts: [HistoryPoint], color: Color, unit: String?) -> some View {
        Chart {
            ForEach(pts, id: \.date) { pt in
                LineMark(x: .value("Time", pt.date), y: .value("Value", pt.value))
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.linear)
            }
            if let h = hover {
                RuleMark(x: .value("Time", h.date)).foregroundStyle(.secondary.opacity(0.4))
                PointMark(x: .value("Time", h.date), y: .value("Value", h.value))
                    .foregroundStyle(color).symbolSize(60)
            }
        }
        .chartYScale(domain: yDomain(pts))
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 6)) { _ in
                AxisGridLine().foregroundStyle(.quaternary)
                AxisValueLabel(format: .dateTime.hour())
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { _ in
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
        // Readout pinned inside the chart's own bounds, so it can never spill into the header above.
        .overlay(alignment: .topLeading) {
            if let h = hover {
                HStack(spacing: 5) {
                    Text(compactValue(h.value, unit: unit)).fontWeight(.semibold).monospacedDigit()
                    Text(h.date.formatted(date: .omitted, time: .shortened)).foregroundStyle(.secondary)
                }
                .font(.caption2)
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(.regularMaterial, in: Capsule())
                .padding(6)
            }
        }
    }

    /// A focused y-range from robust 2nd–98th percentile bounds, so a lone outlier (e.g. a 2000 lx
    /// blip) doesn't squash the rest of the series. Proportional headroom with a magnitude-aware
    /// floor keeps ordinary and flat ranges sane. The spike still shows (clipped at the edge) and
    /// the Min/Max stats report the true extremes.
    private func yDomain(_ pts: [HistoryPoint]) -> ClosedRange<Double> {
        let vals = pts.map(\.value).sorted()
        guard !vals.isEmpty else { return 0...1 }
        let lo = percentile(vals, 0.02), hi = percentile(vals, 0.98)
        let span = hi - lo
        let margin = span > 0 ? span * 0.15 : max(abs(hi), 1) * 0.1
        return (lo - margin)...(hi + margin)
    }
    private func percentile(_ sorted: [Double], _ p: Double) -> Double {
        let i = Int((Double(sorted.count - 1) * p).rounded())
        return sorted[min(max(i, 0), sorted.count - 1)]
    }

    private func stats(_ vals: [Double], lo: Double, hi: Double, unit: String?) -> some View {
        // Bare numbers + the unit shown once, so four stats fit one row even for wide units (ppm/hPa).
        HStack(spacing: 14) {
            stat("Now", vals.last ?? 0)
            stat("Min", lo)
            stat("Max", hi)
            stat("Avg", vals.reduce(0, +) / Double(vals.count))
            Spacer(minLength: 4)
            Text(unit.map { "\($0) · 24h" } ?? "24h")
                .font(.caption2).foregroundStyle(.tertiary).fixedSize()
        }
    }

    private func stat(_ label: String, _ v: Double) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label).font(.caption2).foregroundStyle(.tertiary)
            Text(compactValue(v, unit: nil)).font(.caption).monospacedDigit().fixedSize()
        }
    }
}
