import SwiftUI
import AppKit

/// Makes a window opened from a menu-bar (`.accessory`) app surface on the user's **current** Space
/// — including a full-screen app's Space — and above other apps' windows, instead of opening on the
/// desktop Space behind whatever's there.
///
/// Two window properties do the work:
/// - `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]` — the window is present on the
///   current Space (full-screen included), so showing it never switches Spaces.
/// - `level = .floating` — it sits above other apps' normal windows (e.g. a native app like Tether)
///   and above full-screen content, so it can't be buried. An `.accessory` app's normal-level window
///   otherwise loses the z-order fight with a regular app even when activated.
///
/// Apply to a window's root content via `.followsActiveSpace()`.
struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async { [weak view] in configure(view?.window, activate: true) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Re-assert the placement cheaply; don't steal focus on every update.
        DispatchQueue.main.async { [weak nsView] in configure(nsView?.window, activate: false) }
    }

    private func configure(_ window: NSWindow?, activate: Bool) {
        guard let window else { return }
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.level = .floating
        guard activate else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }
}

extension View {
    /// Make the hosting window surface on the current Space (full-screen included) and float above
    /// other apps' windows when shown.
    func followsActiveSpace() -> some View { background(WindowConfigurator()) }
}
