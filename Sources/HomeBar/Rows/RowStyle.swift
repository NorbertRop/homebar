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

    /// Right-click curation: pin, hide, or hide the whole device.
    func entityContextMenu(_ model: AppModel, _ id: String) -> some View {
        contextMenu {
            Button(model.isPinned(id) ? "Unpin" : "Pin",
                   systemImage: model.isPinned(id) ? "pin.slash" : "pin") { model.togglePin(id) }
            Button("Hide", systemImage: "eye.slash") { model.hide(id) }
            if model.hasDevice(id) {
                Button("Hide whole device", systemImage: "eye.slash.fill") { model.hideDevice(of: id) }
            }
        }
    }
}
