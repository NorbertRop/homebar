import SwiftUI
import HomeBarCore

struct ClimateRow: View {
    let model: AppModel
    let entityID: String
    var nameOverride: String? = nil

    var body: some View {
        if let s = model.entity(entityID) {
            let c = ClimateState(from: s)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "snowflake").frame(width: 18)
                        .foregroundStyle(c.hvacMode == "off" ? Color.secondary : Color.blue)
                    Text(nameOverride ?? s.friendlyName).lineLimit(1)
                    if let cur = c.currentTemperature {
                        Text("· \(cur, specifier: "%.0f")°").font(.caption).foregroundStyle(.secondary).monospacedDigit()
                    }
                    Spacer()
                    Picker("", selection: Binding(get: { c.hvacMode },
                        set: { model.perform(HACommand.setClimateMode(entityID, $0)) })) {
                        ForEach(c.hvacModes, id: \.self) { Text($0.capitalized).tag($0) }
                    }
                    .labelsHidden().fixedSize().controlSize(.small)
                }

                HStack(spacing: 14) {
                    if let tgt = c.targetTemperature {
                        HStack(spacing: 8) {
                            Text("\(tgt, specifier: "%.0f")°").font(.title3).fontWeight(.semibold).monospacedDigit()
                            Stepper("", value: Binding(
                                get: { tgt },
                                set: { model.perform(HACommand.setClimateTemperature(entityID, $0)) }
                            ), in: c.minTemp...c.maxTemp, step: c.targetTempStep)
                            .labelsHidden().fixedSize()
                        }
                    }
                    if !c.fanModes.isEmpty {
                        HStack(spacing: 5) {
                            Image(systemName: "fan.fill").font(.caption).foregroundStyle(.secondary)
                            Picker("", selection: Binding(get: { c.fanMode ?? "" },
                                set: { model.perform(HACommand.setClimateFan(entityID, $0)) })) {
                                ForEach(c.fanModes, id: \.self) { Text($0).tag($0) }
                            }
                            .labelsHidden().fixedSize().controlSize(.small)
                        }
                    }
                    Spacer()
                }
            }
        }
    }
}
