import SwiftUI
import HomeBarCore

/// A small status dot — shown ONLY when something needs attention (stale or offline).
/// Fresh entities render nothing, keeping the common case clean.
struct FreshnessDot: View {
    let freshness: Freshness
    var body: some View {
        if freshness != .fresh {
            Circle().frame(width: 6, height: 6)
                .foregroundStyle(freshness == .offline ? .red : .orange)
        }
    }
}
