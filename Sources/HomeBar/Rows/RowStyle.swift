import SwiftUI

/// Consistent row rhythm + a subtle native hover highlight (like a macOS menu row).
private struct RowStyle: ViewModifier {
    @State private var hovering = false
    func body(content: Content) -> some View {
        content
            .padding(.vertical, 3)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(hovering ? Color.primary.opacity(0.06) : Color.clear)
            )
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
    }
}

extension View {
    func rowStyle() -> some View { modifier(RowStyle()) }
}
