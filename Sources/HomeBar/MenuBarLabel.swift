import SwiftUI

struct MenuBarLabel: View {
    let model: AppModel?

    var body: some View {
        let offline = model?.offlineCount ?? 0
        let connected = model?.connection == .authenticated
        Image(systemName: offline > 0 ? "house.fill" : "house")
            .symbolRenderingMode(.palette)
            .foregroundStyle(offline > 0 ? .red : (connected ? .primary : .secondary))
    }
}
