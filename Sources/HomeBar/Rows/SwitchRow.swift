import SwiftUI
import HomeBarCore

struct SwitchRow: View {
    let model: AppModel
    let entityID: String
    var body: some View {
        if let s = model.entity(entityID) {
            Toggle(isOn: Binding(
                get: { s.state == "on" },
                set: { _ in model.toggle(entityID) }
            )) {
                HStack { Image(systemName: "power").frame(width: 18); Text(s.friendlyName) }
            }
            .toggleStyle(.switch)
        }
    }
}
