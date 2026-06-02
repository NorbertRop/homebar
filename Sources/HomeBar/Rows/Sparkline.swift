import SwiftUI

/// A tiny line chart of recent values, drawn in the current foreground style.
struct Sparkline: View {
    let values: [Double]

    var body: some View {
        GeometryReader { geo in
            Path { p in
                let pts = points(in: geo.size)
                guard let first = pts.first else { return }
                p.move(to: first)
                for pt in pts.dropFirst() { p.addLine(to: pt) }
            }
            .stroke(style: StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round))
        }
    }

    private func points(in size: CGSize) -> [CGPoint] {
        guard values.count > 1 else { return [] }
        let lo = values.min() ?? 0, hi = values.max() ?? 1
        let range = hi - lo
        let stepX = size.width / CGFloat(values.count - 1)
        return values.enumerated().map { i, v in
            let y = range > 0 ? (1 - CGFloat((v - lo) / range)) * size.height : size.height / 2
            return CGPoint(x: CGFloat(i) * stepX, y: y)
        }
    }
}
