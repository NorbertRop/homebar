import SwiftUI
import HomeBarCore

struct EntityRow: View {
    let model: AppModel
    let entityID: String
    var body: some View {
        switch Domain(entityID: entityID) {
        case .switchType: SwitchRow(model: model, entityID: entityID)
        case .light: LightRow(model: model, entityID: entityID)
        case .climate: ClimateRow(model: model, entityID: entityID)
        case .automation: AutomationRow(model: model, entityID: entityID)
        default: SensorRow(model: model, entityID: entityID)
        }
    }
}
