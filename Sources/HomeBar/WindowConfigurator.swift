import SwiftUI
import AppKit

/// Makes a window opened from a menu-bar (`.accessory`) app surface on the user's **current** Space
/// (full-screen included) and above other apps' windows — re-applied every time it's shown, because
/// SwiftUI may hand the Settings scene a fresh `NSWindow` on each open.
///
/// - `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]` — present on the current Space,
///   so showing it never switches Spaces (works over a full-screen app too).
/// - `level = .floating` — above other apps' normal windows (Discord, Tether, …) and full-screen
///   content, so an accessory app's window can't lose the z-order fight and get buried.
///
/// Apply to a window's root content via `.followsActiveSpace()`.
struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { SurfacingView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

/// Re-applies the window placement whenever it attaches to a window — including the *new* window
/// SwiftUI hands the Settings scene on a re-open, which `makeNSView`/`updateNSView` don't catch.
private final class SurfacingView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.level = .floating
        DispatchQueue.main.async { [weak self] in
            guard let window = self?.window else { return }
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
    }
}

extension View {
    /// Make the hosting window surface on the current Space (full-screen included) and float above
    /// other apps' windows each time it's shown.
    func followsActiveSpace() -> some View { background(WindowConfigurator()) }
}
