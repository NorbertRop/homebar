import SwiftUI
import HomeBarCore

struct EntityRow: View {
    let model: AppModel
    let entityID: String
    var nameOverride: String? = nil

    var body: some View {
        dispatched.rowStyle().entityContextMenu(model, entityID)
    }

    @ViewBuilder private var dispatched: some View {
        switch Domain(entityID: entityID) {
        case .switchType: SwitchRow(model: model, entityID: entityID, nameOverride: nameOverride)
        case .light: LightRow(model: model, entityID: entityID, nameOverride: nameOverride)
        case .climate: ClimateRow(model: model, entityID: entityID, nameOverride: nameOverride)
        default: SensorRow(model: model, entityID: entityID, nameOverride: nameOverride)
        }
    }
}
