import SwiftUI
import HomeBarCore

struct DeviceCardView: View {
    let model: AppModel
    let card: DeviceCard
    var body: some View {
        let ids = ordered(card.entityIDs, by: model.settings.order)
        return VStack(alignment: .leading, spacing: 2) {
            Text(card.name).font(.caption).fontWeight(.medium).foregroundStyle(.secondary)
                .padding(.horizontal, 6)
            ForEach(ids, id: \.self) { id in
                EntityRow(model: model, entityID: id, nameOverride: shortName(id), siblings: ids)
            }
            .padding(.leading, 10)
        }
    }

    /// Drop the device name from an entity's label inside its own card
    /// ("C6-Sensors Temperature" -> "Temperature").
    private func shortName(_ id: String) -> String? {
        guard let full = model.entity(id)?.friendlyName, full.hasPrefix(card.name) else { return nil }
        let rest = full.dropFirst(card.name.count).drop(while: { $0 == " " || $0 == "-" })
        return rest.isEmpty ? nil : String(rest)
    }
}
