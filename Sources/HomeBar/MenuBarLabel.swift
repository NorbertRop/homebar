import SwiftUI
import HomeBarCore

struct MenuBarLabel: View {
    let model: AppModel

    var body: some View {
        let _ = model.dataVersion   // re-render on data changes (MenuBarExtra won't track the nested store)
        let offline = model.offlineCount
        let connected = model.connection == .authenticated
        let tint: Color = offline > 0 ? .red : (connected ? .primary : .secondary)

        if let id = model.settings.menuBarEntityID, let s = model.entity(id) {
            HStack(spacing: 3) {
                Image(systemName: sensorSymbol(s.deviceClass))
                Text(s.menuBarValue)
            }
            .foregroundStyle(tint)
            .padding(.trailing, -3)
        } else {
            Image(systemName: offline > 0 ? "house.fill" : "house")
                .symbolRenderingMode(.palette)
                .foregroundStyle(tint)
        }
    }
}
