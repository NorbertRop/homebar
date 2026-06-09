import SwiftUI
import HomeBarCore

struct ClimateRow: View {
    let model: AppModel
    let entityID: String
    var nameOverride: String? = nil

    // Optimistic selections: show the user's pick instantly and keep it until HA's real state
    // catches up. Some climate integrations confirm a mode/fan change only after a long lag (or
    // report no change feedback at all), which would otherwise snap the picker back and make it
    // look like the tap did nothing. Mirrors HASlider's local-value approach.
    @State private var pendingMode: String?
    @State private var pendingFan: String?

    var body: some View {
        let _ = model.dataVersion   // re-render when HA confirms a mode/temp change (see AppModel.dataVersion)
        if let s = model.entity(entityID) {
            let c = ClimateState(from: s)
            let mode = pendingMode ?? c.hvacMode
            let isOn = mode != "off"
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "snowflake").frame(width: 18)
                        .foregroundStyle(isOn ? Color.blue : Color.secondary)
                    Text(nameOverride ?? s.friendlyName).lineLimit(1)
                    Spacer()
                    // Quick power toggle: flip on/off without opening the mode menu. Optimistic so
                    // the row reacts instantly; `climate.turn_on` lets HA restore its own mode, and
                    // the Picker's onChange below clears the optimistic guess once HA confirms.
                    if c.hvacModes.contains("off"), let onMode = c.defaultOnMode {
                        Button {
                            if isOn {
                                pendingMode = "off"
                                model.perform(HACommand.turnOff(entityID))
                            } else {
                                pendingMode = onMode
                                model.perform(HACommand.turnOn(entityID))
                            }
                        } label: {
                            Image(systemName: "power").font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(isOn ? Color.green : Color.secondary)
                        }
                        .buttonStyle(.plain)
                        .help(isOn ? "Turn off" : "Turn on")
                    }
                    Picker("", selection: Binding(get: { mode }, set: { newMode in
                        pendingMode = newMode
                        model.perform(HACommand.setClimateMode(entityID, newMode))
                    })) {
                        ForEach(c.hvacModes, id: \.self) { Text($0.capitalized).tag($0) }
                    }
                    .labelsHidden().fixedSize().controlSize(.small)
                    // Trust HA once it reports a (new) confirmed mode; drop the optimistic override.
                    .onChange(of: c.hvacMode) { _, _ in pendingMode = nil }
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
                            Picker("", selection: Binding(get: { pendingFan ?? c.fanMode ?? "" }, set: { newFan in
                                pendingFan = newFan
                                model.perform(HACommand.setClimateFan(entityID, newFan))
                            })) {
                                ForEach(c.fanModes, id: \.self) { Text($0).tag($0) }
                            }
                            .labelsHidden().fixedSize().controlSize(.small)
                            .onChange(of: c.fanMode) { _, _ in pendingFan = nil }
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }
}
