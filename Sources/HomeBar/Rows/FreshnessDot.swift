import SwiftUI
import HomeBarCore

struct FreshnessDot: View {
    let freshness: Freshness
    var body: some View {
        Circle().frame(width: 6, height: 6).foregroundStyle(color)
    }
    private var color: Color {
        switch freshness { case .fresh: .green; case .stale: .orange; case .offline: .red }
    }
}
