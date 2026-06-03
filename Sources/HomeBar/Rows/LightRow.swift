import SwiftUI
import HomeBarCore

struct LightRow: View {
    let model: AppModel
    let entityID: String
    var nameOverride: String? = nil

    var body: some View {
        if let s = model.entity(entityID) {
            let light = LightState(from: s)
            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: Binding(get: { light.isOn }, set: { on in
                    model.perform(HACommand.setLight(entityID, on: on,
                        brightnessPercent: nil, rgb: nil, colorTempKelvin: nil))
                })) {
                    HStack {
                        Image(systemName: light.isOn ? "lightbulb.fill" : "lightbulb")
                            .frame(width: 18).foregroundStyle(light.isOn ? .yellow : .secondary)
                        Text(nameOverride ?? s.friendlyName)
                    }
                }.toggleStyle(.switch)

                if light.isOn {
                    VStack(alignment: .leading, spacing: 8) {
                        if let b = light.brightnessPercent {
                            HStack(spacing: 8) {
                                Image(systemName: "sun.max.fill").font(.caption).foregroundStyle(.secondary).frame(width: 16)
                                HASlider(value: Double(b), in: 1...100) { v in adjust(Int(v)) }
                                Text("\(b)%").font(.caption).foregroundStyle(.secondary)
                                    .monospacedDigit().frame(width: 34, alignment: .trailing)
                            }
                        }
                        if light.supportsColorTemp {
                            let minK = light.minColorTempKelvin ?? 2000
                            let maxK = light.maxColorTempKelvin ?? 6500
                            HStack(spacing: 8) {
                                Image(systemName: "thermometer.sun").font(.caption).foregroundStyle(.orange).frame(width: 16)
                                HASlider(value: Double(light.colorTempKelvin ?? minK), in: Double(minK)...Double(maxK)) { k in
                                    adjust(light.brightnessPercent, colorTemp: Int(k))
                                }
                                Image(systemName: "thermometer.snowflake").font(.caption).foregroundStyle(.blue).frame(width: 16)
                            }
                        }
                        if light.supportsColor {
                            HStack(spacing: 8) {
                                Image(systemName: "paintpalette.fill").font(.caption).foregroundStyle(.secondary).frame(width: 16)
                                HueSlider(hue: light.rgb.map(rgbToHue) ?? 0) { h in
                                    adjust(light.brightnessPercent, rgb: rgbFromHue(h))
                                }
                            }
                            HStack(spacing: 7) {
                                ForEach(lightPresets) { p in
                                    Button {
                                        adjust(light.brightnessPercent, rgb: p.rgb)
                                    } label: {
                                        Circle().fill(p.color).frame(width: 18, height: 18)
                                            .overlay(Circle().strokeBorder(.primary.opacity(0.15), lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                    .help(p.name)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.leading, 24)
                        }
                    }
                    .padding(.leading, 4)
                }
            }
        }
    }

    /// Turn the light on and apply a change, preserving whatever isn't being set.
    private func adjust(_ brightnessPercent: Int?, rgb: RGB? = nil, colorTemp: Int? = nil) {
        model.perform(HACommand.setLight(entityID, on: true,
            brightnessPercent: brightnessPercent, rgb: rgb, colorTempKelvin: colorTemp))
    }
}
