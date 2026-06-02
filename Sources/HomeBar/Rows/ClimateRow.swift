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
                HStack(spacing: 6) {
                    Image(systemName: "snowflake").frame(width: 18)
                        .foregroundStyle(c.hvacMode == "off" ? Color.secondary : Color.blue)
                    Text(nameOverride ?? s.friendlyName).lineLimit(1)
                    if let cur = c.currentTemperature {
                        Text("· \(cur, specifier: "%.0f")°").foregroundStyle(.secondary).monospacedDigit()
                    }
                    Spacer()
                    Picker("", selection: Binding(get: { c.hvacMode },
                        set: { model.perform(HACommand.setClimateMode(entityID, $0)) })) {
                        ForEach(c.hvacModes, id: \.self) { Text($0.capitalized).tag($0) }
                    }
                    .labelsHidden().fixedSize()
                }

                if let tgt = c.targetTemperature {
                    HStack(spacing: 10) {
                        Button {
                            model.perform(HACommand.setClimateTemperature(entityID, max(c.minTemp, tgt - c.targetTempStep)))
                        } label: { Image(systemName: "minus.circle.fill").font(.title3) }
                        Text("\(tgt, specifier: "%.0f")°").font(.title3.weight(.medium)).monospacedDigit().frame(minWidth: 42)
                        Button {
                            model.perform(HACommand.setClimateTemperature(entityID, min(c.maxTemp, tgt + c.targetTempStep)))
                        } label: { Image(systemName: "plus.circle.fill").font(.title3) }

                        Spacer()

                        if !c.fanModes.isEmpty {
                            Image(systemName: "fan").foregroundStyle(.secondary)
                            Picker("", selection: Binding(get: { c.fanMode ?? "" },
                                set: { model.perform(HACommand.setClimateFan(entityID, $0)) })) {
                                ForEach(c.fanModes, id: \.self) { Text($0).tag($0) }
                            }
                            .labelsHidden().fixedSize()
                        }
                    }
                    .buttonStyle(.plain)
                    .tint(.accentColor)
                }
            }
        }
    }
}
