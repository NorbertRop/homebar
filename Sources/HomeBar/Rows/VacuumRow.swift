import SwiftUI
import HomeBarCore

struct VacuumRow: View {
    let model: AppModel
    let entityID: String
    var nameOverride: String? = nil

    // viomi exposes the cleaning type as separate button entities on the same device.
    private var sweep: String? { model.deviceEntityID(of: entityID, suffix: "_start_sweep") }
    private var sweepMop: String? { model.deviceEntityID(of: entityID, suffix: "_start_sweep_mop") }
    private var mop: String? { model.deviceEntityID(of: entityID, suffix: "_start_mop") }
    private var hasModes: Bool { sweep != nil || sweepMop != nil || mop != nil }

    var body: some View {
        if let s = model.entity(entityID) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles").frame(width: 18)
                    .foregroundStyle(isCleaning(s) ? Color.blue : .secondary)
                Text(nameOverride ?? s.friendlyName).lineLimit(1)
                Spacer()
                if hasModes {
                    Menu {
                        if let id = sweep { Button("Vacuum") { press(id) } }
                        if let id = sweepMop { Button("Vacuum + Mop") { press(id) } }
                        if let id = mop { Button("Mop") { press(id) } }
                    } label: {
                        Label("Start", systemImage: "play.fill")
                    }
                    .fixedSize().controlSize(.small)
                } else {
                    Button { vacuum("start") } label: { Image(systemName: "play.fill") }
                        .buttonStyle(.bordered).controlSize(.small)
                }
                if isCleaning(s) {
                    Button { vacuum("pause") } label: { Image(systemName: "pause.fill") }
                        .buttonStyle(.bordered).controlSize(.small)
                }
                Button { vacuum("return_to_base") } label: { Image(systemName: "house.fill") }
                    .buttonStyle(.bordered).controlSize(.small)
            }
        }
    }

    private func isCleaning(_ s: EntityState) -> Bool { s.state == "cleaning" }
    private func press(_ id: String) {
        model.perform(ServiceCall(domain: "button", service: "press", data: [:], target: id))
    }
    private func vacuum(_ service: String) {
        model.perform(ServiceCall(domain: "vacuum", service: service, data: [:], target: entityID))
    }
}
