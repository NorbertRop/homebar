import SwiftUI
import HomeBarCore

struct SwitchRow: View {
    let model: AppModel
    let entityID: String
    var nameOverride: String? = nil

    var body: some View {
        if let s = model.entity(entityID) {
            Toggle(isOn: Binding(
                get: { s.isOn },
                set: { _ in model.toggle(entityID) }
            )) {
                HStack {
                    Image(systemName: "power").frame(width: 18).foregroundStyle(.secondary)
                    Text(nameOverride ?? s.friendlyName)
                }
            }
            .toggleStyle(.switch)
        }
    }
}
