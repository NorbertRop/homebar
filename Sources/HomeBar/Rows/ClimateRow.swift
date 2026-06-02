import SwiftUI
import HomeBarCore

struct ClimateRow: View {
    let model: AppModel
    let entityID: String
    var nameOverride: String? = nil

    var body: some View {
        if let s = model.entity(entityID) {
            let c = ClimateState(from: s)
            let isOn = c.hvacMode != "off"
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "snowflake").frame(width: 18)
                        .foregroundStyle(isOn ? Color.blue : Color.secondary)
                    Text(nameOverride ?? s.friendlyName).lineLimit(1)
                    Spacer()
                    Picker("", selection: Binding(get: { c.hvacMode },
                        set: { model.perform(HACommand.setClimateMode(entityID, $0)) })) {
                        ForEach(c.hvacModes, id: \.self) { Text($0.capitalized).tag($0) }
                    }
                    .labelsHidden().fixedSize().controlSize(.small)
                }

                if isOn, let tgt = c.targetTemperature {
                    HStack {
                        Button {
                            model.perform(HACommand.setClimateTemperature(entityID, max(c.minTemp, tgt - c.targetTempStep)))
                        } label: { Image(systemName: "minus.circle.fill").font(.title2) }
                        Spacer()
                        VStack(spacing: 0) {
                            Text("\(tgt, specifier: "%.0f")°").font(.title2).fontWeight(.semibold).monospacedDigit()
                            if let cur = c.currentTemperature {
                                Text("now \(cur, specifier: "%.0f")°").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button {
                            model.perform(HACommand.setClimateTemperature(entityID, min(c.maxTemp, tgt + c.targetTempStep)))
                        } label: { Image(systemName: "plus.circle.fill").font(.title2) }
                    }
                    .buttonStyle(.plain).foregroundStyle(.tint)

                    if !c.fanModes.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "fan.fill").font(.caption).foregroundStyle(.secondary)
                            Text("Fan").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Picker("", selection: Binding(get: { c.fanMode ?? "" },
                                set: { model.perform(HACommand.setClimateFan(entityID, $0)) })) {
                                ForEach(c.fanModes, id: \.self) { Text($0).tag($0) }
                            }
                            .labelsHidden().fixedSize().controlSize(.small)
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }
}
