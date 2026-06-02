import SwiftUI

struct MenuBarLabel: View {
    let offlineCount: Int
    let connected: Bool

    var body: some View {
        Image(systemName: offlineCount > 0 ? "house.fill" : "house")
            .symbolRenderingMode(.palette)
            .foregroundStyle(offlineCount > 0 ? .red : (connected ? .primary : .secondary))
    }
}
