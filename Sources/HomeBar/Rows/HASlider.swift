import SwiftUI

/// Min seconds between live updates pushed while dragging a control — fast enough to feel live,
/// slow enough not to flood the device. Shared by HASlider and HueSlider.
let liveControlThrottle: TimeInterval = 0.2

/// A Slider for a value that is also driven by live Home Assistant state.
///
/// Drags a local copy so HA's echoed state never snaps the thumb. Sends **throttled**
/// updates *during* the drag (so the device changes live, ~5×/sec to avoid flooding the
/// device) plus the exact final value on release. Re-syncs from the live value only when
/// the user isn't actively dragging.
struct HASlider: View {
    let value: Double
    let range: ClosedRange<Double>
    let onCommit: (Double) -> Void

    @State private var local: Double
    @State private var editing = false
    @State private var lastSent = Date.distantPast

    init(value: Double, in range: ClosedRange<Double>, onCommit: @escaping (Double) -> Void) {
        self.value = value
        self.range = range
        self.onCommit = onCommit
        _local = State(initialValue: value.clamped(to: range))
    }

    var body: some View {
        Slider(value: $local, in: range) { isEditing in
            editing = isEditing
            if !isEditing { send(local, force: true) }   // exact final value on release
        }
        .onChange(of: local) { _, newValue in
            if editing { send(newValue, force: false) }  // live, throttled, while dragging
        }
        .onChange(of: value) { _, newValue in
            if !editing { local = newValue.clamped(to: range) }  // sync from HA only when not dragging
        }
    }

    private func send(_ v: Double, force: Bool) {
        let now = Date()
        if force || now.timeIntervalSince(lastSent) >= liveControlThrottle {
            lastSent = now
            onCommit(v)
        }
    }
}

private extension Double {
    func clamped(to r: ClosedRange<Double>) -> Double { min(max(self, r.lowerBound), r.upperBound) }
}
