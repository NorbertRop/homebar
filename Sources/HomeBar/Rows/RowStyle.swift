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

    /// A subtle card for multi-control rows (light/climate/vacuum) so their controls
    /// read as a contained tile rather than floating among the flat sensor rows.
    func controlTile() -> some View {
        padding(.vertical, 6)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.05)))
    }

    /// Right-click curation: pin, hide, or hide the whole device.
    func entityContextMenu(_ model: AppModel, _ id: String) -> some View {
        contextMenu {
            Button(model.isPinned(id) ? "Unpin" : "Pin",
                   systemImage: model.isPinned(id) ? "pin.slash" : "pin") { model.togglePin(id) }
            if model.isPinned(id) {
                Button("Move Up", systemImage: "arrow.up") { model.moveFavorite(id, up: true) }
                    .disabled(!model.canMoveFavorite(id, up: true))
                Button("Move Down", systemImage: "arrow.down") { model.moveFavorite(id, up: false) }
                    .disabled(!model.canMoveFavorite(id, up: false))
            }
            Divider()
            Button("Hide", systemImage: "eye.slash") { model.hide(id) }
            if model.hasDevice(id) {
                Button("Hide whole device", systemImage: "eye.slash.fill") { model.hideDevice(of: id) }
            }
        }
    }
}
