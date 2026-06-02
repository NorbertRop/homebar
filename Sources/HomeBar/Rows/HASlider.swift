import SwiftUI

/// A Slider for a value that is also driven by live Home Assistant state.
///
/// Binding a Slider directly to the live value fights the user: every drag tick sends a
/// service call, and HA echoes the state back, snapping the thumb around. Instead this
/// drags a local copy, commits ONE command on release, and only re-syncs from the live
/// value when the user isn't actively dragging.
struct HASlider: View {
    let value: Double
    let range: ClosedRange<Double>
    let onCommit: (Double) -> Void

    @State private var local: Double
    @State private var editing = false

    init(value: Double, in range: ClosedRange<Double>, onCommit: @escaping (Double) -> Void) {
        self.value = value
        self.range = range
        self.onCommit = onCommit
        _local = State(initialValue: value.clamped(to: range))
    }

    var body: some View {
        Slider(value: $local, in: range) { isEditing in
            editing = isEditing
            if !isEditing { onCommit(local) }   // commit once, on release
        }
        .onChange(of: value) { _, newValue in
            if !editing { local = newValue.clamped(to: range) }  // sync from HA only when not dragging
        }
    }
}

private extension Double {
    func clamped(to r: ClosedRange<Double>) -> Double { min(max(self, r.lowerBound), r.upperBound) }
}
