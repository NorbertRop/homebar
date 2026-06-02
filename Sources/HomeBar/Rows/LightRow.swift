import SwiftUI
import HomeBarCore

struct LightRow: View {
    let model: AppModel
    let entityID: String

    var body: some View {
        if let s = model.entity(entityID) {
            let light = LightState(from: s)
            VStack(alignment: .leading, spacing: 4) {
                Toggle(isOn: Binding(get: { light.isOn }, set: { on in
                    model.perform(HACommand.setLight(entityID, on: on,
                        brightnessPercent: nil, rgb: nil, colorTempKelvin: nil))
                })) {
                    HStack { Image(systemName: "lightbulb").frame(width: 18); Text(s.friendlyName) }
                }.toggleStyle(.switch)

                if light.isOn {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            if let b = light.brightnessPercent {
                                Slider(value: Binding(
                                    get: { Double(b) },
                                    set: { v in model.perform(HACommand.setLight(entityID, on: true,
                                        brightnessPercent: Int(v), rgb: nil, colorTempKelvin: nil)) }
                                ), in: 1...100)
                            }
                            if light.supportsColor {
                                ColorPicker("", selection: Binding(
                                    get: { light.rgb.map { Color(.sRGB, red: Double($0.r)/255,
                                           green: Double($0.g)/255, blue: Double($0.b)/255) } ?? .white },
                                    set: { c in
                                        let rgb = c.toRGB()
                                        model.perform(HACommand.setLight(entityID, on: true,
                                            brightnessPercent: light.brightnessPercent, rgb: rgb, colorTempKelvin: nil))
                                    }
                                )).labelsHidden().frame(width: 28)
                            }
                        }
                        if light.supportsColorTemp {
                            let minK = light.minColorTempKelvin ?? 2000
                            let maxK = light.maxColorTempKelvin ?? 6500
                            HStack(spacing: 4) {
                                Image(systemName: "thermometer.sun").font(.caption2).foregroundStyle(.orange)
                                Slider(value: Binding(
                                    get: { Double(light.colorTempKelvin ?? minK) },
                                    set: { k in model.perform(HACommand.setLight(entityID, on: true,
                                        brightnessPercent: light.brightnessPercent, rgb: nil, colorTempKelvin: Int(k))) }
                                ), in: Double(minK)...Double(maxK))
                                Image(systemName: "thermometer.snowflake").font(.caption2).foregroundStyle(.blue)
                            }
                        }
                    }
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
