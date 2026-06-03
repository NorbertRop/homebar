import SwiftUI
import AppKit

/// Makes a window opened from a menu-bar (`.accessory`) app appear on the user's **current** Space
/// and come to the front — instead of opening on some other Space and leaving the user behind.
///
/// Apply to a window's root content via `.followsActiveSpace()`.
struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async { [weak view] in
            guard let window = view?.window else { return }
            window.collectionBehavior.formUnion([.moveToActiveSpace, .fullScreenAuxiliary])
            NSApp.activate()
            window.makeKeyAndOrderFront(nil)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Re-assert the space-following behavior cheaply; don't steal focus on every update.
        DispatchQueue.main.async { [weak nsView] in
            nsView?.window?.collectionBehavior.formUnion([.moveToActiveSpace, .fullScreenAuxiliary])
        }
    }
}

extension View {
    /// Make the hosting window activate and follow the user to their current Space when shown.
    func followsActiveSpace() -> some View { background(WindowConfigurator()) }
}
