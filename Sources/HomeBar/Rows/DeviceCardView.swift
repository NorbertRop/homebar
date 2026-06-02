import SwiftUI
import HomeBarCore

struct DeviceCardView: View {
    let model: AppModel
    let card: DeviceCard
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(card.name).font(.caption).foregroundStyle(.secondary)
            ForEach(card.entityIDs, id: \.self) { EntityRow(model: model, entityID: $0) }
                .padding(.leading, 8)
        }
    }
}
