import SwiftUI
import HomeBarCore

struct AutomationRow: View {
    let model: AppModel
    let entityID: String
    var body: some View {
        if let s = model.entity(entityID) {
            HStack {
                Text(s.friendlyName).lineLimit(1)
                Spacer()
                Button("Run") { model.perform(HACommand.runAutomation(entityID)) }
                    .buttonStyle(.bordered).controlSize(.small)
                Toggle("", isOn: Binding(get: { s.state == "on" },
                    set: { model.perform(HACommand.armAutomation(entityID, armed: $0)) }))
                    .toggleStyle(.switch).labelsHidden()
            }
        }
    }
}
