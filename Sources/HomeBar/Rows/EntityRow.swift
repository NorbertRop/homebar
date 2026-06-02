import SwiftUI
import HomeBarCore

struct EntityRow: View {
    let model: AppModel
    let entityID: String
    var nameOverride: String? = nil

    var body: some View {
        styled.entityContextMenu(model, entityID)
    }

    // Rich multi-control entities get a contained "tile"; simple readings/toggles stay flat.
    @ViewBuilder private var styled: some View {
        switch Domain(entityID: entityID) {
        case .light:   LightRow(model: model, entityID: entityID, nameOverride: nameOverride).controlTile()
        case .climate: ClimateRow(model: model, entityID: entityID, nameOverride: nameOverride).controlTile()
        case .vacuum:  VacuumRow(model: model, entityID: entityID, nameOverride: nameOverride).controlTile()
        case .switchType: SwitchRow(model: model, entityID: entityID, nameOverride: nameOverride).rowStyle()
        default: SensorRow(model: model, entityID: entityID, nameOverride: nameOverride).rowStyle()
        }
    }
}
