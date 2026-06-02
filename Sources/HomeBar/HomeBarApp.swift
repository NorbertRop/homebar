import SwiftUI

@main
struct HomeBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            if let model = delegate.model {
                MenuContentView(model: model)
            } else {
                Text("Starting…").padding()
            }
        } label: {
            MenuBarLabel(model: delegate.model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            if let model = delegate.model {
                SettingsView(model: model)
            }
        }
    }
}

/// Owns the AppModel and starts the HA connection at launch — a MenuBarExtra's
/// `@State` content is created lazily on first open, so background work must be
/// kicked off here instead.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    @Published private(set) var model: AppModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let m = AppModel()
        model = m
        m.start()
    }
}
