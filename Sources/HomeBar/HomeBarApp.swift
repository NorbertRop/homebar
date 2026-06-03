import SwiftUI
import Sparkle

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
    // Sparkle drives auto-updates: background checks per Info.plist (SUEnableAutomaticChecks),
    // plus the manual "Check for Updates…" menu item. Updates are EdDSA-verified, no Apple account.
    private let updater = SPUStandardUpdaterController(startingUpdater: true,
                                                       updaterDelegate: nil, userDriverDelegate: nil)

    func applicationDidFinishLaunching(_ notification: Notification) {
        model.start()
        model.presentSettings = { [weak self] in self?.settingsWindow.show() }
        model.checkForUpdates = { [weak self] in self?.updater.checkForUpdates(nil) }
    }
}
