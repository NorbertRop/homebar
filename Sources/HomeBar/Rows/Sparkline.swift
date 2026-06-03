import SwiftUI

/// A tiny line chart of recent values, drawn in the current foreground style.
/// Optional soft area fill and a dot on the latest point improve legibility at small sizes.
struct Sparkline: View {
    let values: [Double]
    var fill: Bool = false
    var dot: Bool = false

    var body: some View {
        GeometryReader { geo in
            let pts = points(in: geo.size)
            ZStack(alignment: .topLeading) {
                if fill, pts.count > 1 {
                    Path { p in
                        p.move(to: CGPoint(x: pts[0].x, y: geo.size.height))
                        for pt in pts { p.addLine(to: pt) }
                        p.addLine(to: CGPoint(x: pts[pts.count - 1].x, y: geo.size.height))
                        p.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [.primary.opacity(0.16), .primary.opacity(0.01)],
                                         startPoint: .top, endPoint: .bottom))
                }
                Path { p in
                    guard let first = pts.first else { return }
                    p.move(to: first)
                    for pt in pts.dropFirst() { p.addLine(to: pt) }
                }
                .stroke(style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
                if dot, let last = pts.last {
                    Circle().frame(width: 3.5, height: 3.5).position(last)
                }
            }
        }
    }

    private func points(in size: CGSize) -> [CGPoint] {
        guard values.count > 1 else { return [] }
        let lo = values.min() ?? 0, hi = values.max() ?? 1
        let range = hi - lo
        let inset: CGFloat = 2.5          // keep the line/dot off the top & bottom edges
        let h = size.height - inset * 2
        let stepX = size.width / CGFloat(values.count - 1)
        return values.enumerated().map { i, v in
            let y = inset + (range > 0 ? (1 - CGFloat((v - lo) / range)) * h : h / 2)
            return CGPoint(x: CGFloat(i) * stepX, y: y)
        }
    }
}
