import SwiftUI
import HomeBarCore

struct ClimateRow: View {
    let model: AppModel
    let entityID: String

    private func tempSummary(current: Double?, target: Double) -> String {
        if let cur = current { return String(format: "%.0f°→%.0f°", cur, target) }
        return String(format: "→%.0f°", target)
    }

    var body: some View {
        if let s = model.entity(entityID) {
            let c = ClimateState(from: s)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "snowflake").frame(width: 18)
                    Text(s.friendlyName)
                    Spacer()
                    if let tgt = c.targetTemperature {
                        Text(tempSummary(current: c.currentTemperature, target: tgt))
                            .foregroundStyle(.secondary).monospacedDigit()
                    }
                }
                HStack {
                    Picker("", selection: Binding(get: { c.hvacMode },
                        set: { model.perform(HACommand.setClimateMode(entityID, $0)) })) {
                        ForEach(c.hvacModes, id: \.self) { Text($0).tag($0) }
                    }.labelsHidden().frame(width: 90)

                    if let tgt = c.targetTemperature {
                        Stepper("\(tgt, specifier: "%.0f")°", onIncrement: {
                            model.perform(HACommand.setClimateTemperature(entityID, min(c.maxTemp, tgt + c.targetTempStep)))
                        }, onDecrement: {
                            model.perform(HACommand.setClimateTemperature(entityID, max(c.minTemp, tgt - c.targetTempStep)))
                        })
                    }
                    if !c.fanModes.isEmpty {
                        Picker("Fan", selection: Binding(get: { c.fanMode ?? "" },
                            set: { model.perform(HACommand.setClimateFan(entityID, $0)) })) {
                            ForEach(c.fanModes, id: \.self) { Text($0).tag($0) }
                        }.frame(width: 110)
                    }
                }
            }
        }
    }
}
