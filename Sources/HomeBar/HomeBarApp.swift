import SwiftUI
import HomeBarCore

@main
struct HomeBarApp: App {
    var body: some Scene {
        MenuBarExtra("HomeBar", systemImage: "house") {
            Text("HomeBar \(HomeBarCore.version)")
        }
    }
}
