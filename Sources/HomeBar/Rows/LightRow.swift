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
                                HASlider(value: Double(b), in: 1...100) { v in
                                    model.perform(HACommand.setLight(entityID, on: true,
                                        brightnessPercent: Int(v), rgb: nil, colorTempKelvin: nil))
                                }
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
                                    model.perform(HACommand.setLight(entityID, on: true,
                                        brightnessPercent: light.brightnessPercent, rgb: nil, colorTempKelvin: Int(k)))
                                }
                                Image(systemName: "thermometer.snowflake").font(.caption).foregroundStyle(.blue).frame(width: 16)
                            }
                        }
                        if light.supportsColor {
                            HStack(spacing: 8) {
                                Image(systemName: "paintpalette.fill").font(.caption).foregroundStyle(.secondary).frame(width: 16)
                                ColorPicker(selection: Binding(
                                    get: { light.rgb.map { Color(.sRGB, red: Double($0.r)/255,
                                           green: Double($0.g)/255, blue: Double($0.b)/255) } ?? .white },
                                    set: { c in
                                        model.perform(HACommand.setLight(entityID, on: true,
                                            brightnessPercent: light.brightnessPercent, rgb: c.toRGB(), colorTempKelvin: nil))
                                    }
                                )) { Text("Color").font(.caption).foregroundStyle(.secondary) }
                                Spacer()
                            }
                        }
                    }
                    .padding(.leading, 4)
                }
            }
        }
    }
}

extension Color {
    func toRGB() -> RGB {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? .white
        return RGB(r: Int(ns.redComponent * 255), g: Int(ns.greenComponent * 255), b: Int(ns.blueComponent * 255))
    }
}
