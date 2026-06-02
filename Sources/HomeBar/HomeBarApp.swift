import SwiftUI

@main
struct HomeBarApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(model: model)
                .task { model.start() }
        } label: {
            MenuBarLabel(offlineCount: model.offlineCount,
                         connected: model.connection == .authenticated)
        }
        .menuBarExtraStyle(.window)

        Settings { SettingsView(model: model) }
    }
}
