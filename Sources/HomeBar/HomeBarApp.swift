import SwiftUI

@main
struct HomeBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(model: delegate.model)
        } label: {
            MenuBarLabel(model: delegate.model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: delegate.model)
        }
    }
}

/// Owns the AppModel (created eagerly so the menu never shows a "starting" placeholder)
/// and kicks off the HA connection once the app finishes launching.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        model.start()
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(systemDidWake), name: NSWorkspace.didWakeNotification, object: nil)
    }

    /// Force a fresh WebSocket after the Mac wakes — the old socket is usually half-dead,
    /// which otherwise leaves requests hanging until the OS finally tears it down.
    @objc private func systemDidWake() { model.restart() }
}
