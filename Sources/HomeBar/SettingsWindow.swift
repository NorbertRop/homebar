import AppKit
import SwiftUI

/// Hosts `SettingsView` in a window we fully control, so its placement is set **before** it's ever
/// shown. The SwiftUI `Settings` scene orders its window on screen first — on the app's desktop
/// Space, switching you off a full-screen app — before any view modifier can reach it. Owning the
/// window lets us configure the Space/level up front, so it lands where the user actually is.
@MainActor
final class SettingsWindow {
    private let model: AppModel
    private var window: NSWindow?

    init(model: AppModel) { self.model = model }

    func show() {
        let window = self.window ?? makeWindow()
        self.window = window
        // Re-assert before showing: present on the *current* Space (full-screen included) and above
        // other apps' windows.
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate()   // cooperative — the window is already on this Space, so no Space switch
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 420),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "HomeBar Settings"
        window.isReleasedWhenClosed = false               // reuse across opens
        window.contentViewController = NSHostingController(rootView: SettingsView(model: model))
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.level = .floating
        window.center()
        return window
    }
}
