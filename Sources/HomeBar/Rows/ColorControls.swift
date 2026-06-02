import SwiftUI
import AppKit
import HomeBarCore

/// In-menu hue scrubber. SwiftUI's `ColorPicker` can't be used inside a `MenuBarExtra`
/// window — opening its `NSColorPanel` steals key focus and dismisses the menu — so we
/// roll a lightweight rainbow track that sets a fully-saturated colour live (throttled,
/// like `HASlider`): updates while dragging, plus the exact final value on release.
struct HueSlider: View {
    let hue: Double                       // 0...360, current colour from HA
    let onChange: (Double) -> Void

    @State private var local: Double
    @State private var editing = false
    @State private var lastSent = Date.distantPast
    private let throttle: TimeInterval = 0.2
    private let knob: CGFloat = 16

    init(hue: Double, onChange: @escaping (Double) -> Void) {
        self.hue = hue
        self.onChange = onChange
        _local = State(initialValue: hue)
    }

    var body: some View {
        GeometryReader { geo in
            let h = editing ? local : hue
            let usable = max(geo.size.width - knob, 1)
            ZStack(alignment: .leading) {
                LinearGradient(stops: (0...6).map {
                    let loc = Double($0) / 6
                    return .init(color: Color(hue: loc, saturation: 0.9, brightness: 1), location: loc)
                }, startPoint: .leading, endPoint: .trailing)
                    .clipShape(Capsule())
                    .frame(height: 6)
                Circle()
                    .fill(Color(hue: h / 360, saturation: 1, brightness: 1))
                    .frame(width: knob, height: knob)
                    .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                    .shadow(color: .black.opacity(0.2), radius: 1, y: 0.5)
                    .offset(x: CGFloat(h / 360) * usable)
            }
            .frame(height: knob)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { v in
                    editing = true
                    let frac = min(max(0, (v.location.x - knob / 2) / usable), 1)
                    local = frac * 360
                    send(local, force: false)
                }
                .onEnded { _ in send(local, force: true); editing = false })
        }
        .frame(height: knob)
    }

    private func send(_ v: Double, force: Bool) {
        let now = Date()
        if force || now.timeIntervalSince(lastSent) >= throttle {
            lastSent = now
            onChange(v)
        }
    }
}

/// Quick-pick light colours — covers the whites a fully-saturated hue scrubber can't reach.
struct ColorSwatch: Identifiable {
    let id = UUID()
    let name: String
    let rgb: RGB
    var color: Color { Color(.sRGB, red: Double(rgb.r) / 255, green: Double(rgb.g) / 255, blue: Double(rgb.b) / 255) }
}

let lightPresets: [ColorSwatch] = [
    .init(name: "Warm White", rgb: RGB(r: 255, g: 197, b: 143)),
    .init(name: "White",      rgb: RGB(r: 255, g: 244, b: 229)),
    .init(name: "Red",        rgb: RGB(r: 255, g: 38,  b: 28)),
    .init(name: "Orange",     rgb: RGB(r: 255, g: 137, b: 4)),
    .init(name: "Yellow",     rgb: RGB(r: 255, g: 214, b: 10)),
    .init(name: "Green",      rgb: RGB(r: 52,  g: 199, b: 89)),
    .init(name: "Cyan",       rgb: RGB(r: 50,  g: 200, b: 220)),
    .init(name: "Blue",       rgb: RGB(r: 10,  g: 110, b: 255)),
    .init(name: "Purple",     rgb: RGB(r: 150, g: 70,  b: 255)),
    .init(name: "Pink",       rgb: RGB(r: 255, g: 65,  b: 180)),
]

/// Fully-saturated RGB for a hue angle (0...360) — sent straight to HA, no colour-space round-trip.
func rgbFromHue(_ h: Double) -> RGB {
    let hp = ((h.truncatingRemainder(dividingBy: 360)) + 360).truncatingRemainder(dividingBy: 360) / 60
    let x = 1 - abs(hp.truncatingRemainder(dividingBy: 2) - 1)
    let (r, g, b): (Double, Double, Double)
    switch hp {
    case 0..<1: (r, g, b) = (1, x, 0)
    case 1..<2: (r, g, b) = (x, 1, 0)
    case 2..<3: (r, g, b) = (0, 1, x)
    case 3..<4: (r, g, b) = (0, x, 1)
    case 4..<5: (r, g, b) = (x, 0, 1)
    default:    (r, g, b) = (1, 0, x)
    }
    return RGB(r: Int((r * 255).rounded()), g: Int((g * 255).rounded()), b: Int((b * 255).rounded()))
}

/// Hue angle (0...360) of an RGB colour, for positioning the scrubber thumb.
func rgbToHue(_ rgb: RGB) -> Double {
    let ns = NSColor(srgbRed: CGFloat(rgb.r) / 255, green: CGFloat(rgb.g) / 255, blue: CGFloat(rgb.b) / 255, alpha: 1)
    return Double(ns.hueComponent) * 360
}
