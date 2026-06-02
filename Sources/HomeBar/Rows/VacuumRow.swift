import SwiftUI
import HomeBarCore

struct VacuumRow: View {
    let model: AppModel
    let entityID: String
    var nameOverride: String? = nil

    private func isCleaning(_ s: EntityState) -> Bool { s.state == "cleaning" || s.state == "on" }

    var body: some View {
        if let s = model.entity(entityID) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles").frame(width: 18)
                    .foregroundStyle(isCleaning(s) ? Color.blue : .secondary)
                Text(nameOverride ?? s.friendlyName).lineLimit(1)
                Text(s.state.capitalized).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                Spacer()
                Button {
                    model.perform(ServiceCall(domain: "vacuum",
                        service: isCleaning(s) ? "pause" : "start", data: [:], target: entityID))
                } label: {
                    Image(systemName: isCleaning(s) ? "pause.fill" : "play.fill")
                }
                Button {
                    model.perform(ServiceCall(domain: "vacuum", service: "return_to_base", data: [:], target: entityID))
                } label: {
                    Image(systemName: "house.fill")
                }
            }
            .buttonStyle(.bordered).controlSize(.small)
        }
    }
}
