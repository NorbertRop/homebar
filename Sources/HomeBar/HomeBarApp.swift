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
    }
}

/// Owns the AppModel (created eagerly so the menu never shows a "starting" placeholder)
/// and kicks off the HA connection once the app finishes launching.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private lazy var settingsWindow = SettingsWindow(model: model)

    func applicationDidFinishLaunching(_ notification: Notification) {
        model.start()
        model.presentSettings = { [weak self] in self?.settingsWindow.show() }
    }
}
