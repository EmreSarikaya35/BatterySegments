import SwiftUI

/// A battery: glass shell with an outline and a terminal; inside, the white "time left" cell
/// on the left and one slice per app on the right.
struct BatteryBar: View {
    @ObservedObject var store: Store
    @State private var hovered: String?

    var body: some View {
        let all = store.showSlices ? store.segments : []
        let visible = all.filter { $0.id != store.drag.previewID }
        let shell = RoundedRectangle(cornerRadius: Metrics.shellRadius, style: .continuous)
        let cells = RoundedRectangle(cornerRadius: Metrics.shellRadius - Metrics.shellInset, style: .continuous)
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                centerText.frame(maxWidth: .infinity, maxHeight: .infinity)
                ForEach(visible) { slice($0) }
            }
            .frame(width: Metrics.innerWidth, height: Metrics.barHeight - 2 * Metrics.shellInset)
            .background(.white)
            .clipShape(cells)
            .contentShape(cells)
            // One gesture on the bar (not per slice) so it survives its slice leaving the bar.
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { store.dragChanged(start: hit($0.startLocation.x, in: all), translation: $0.translation) }
                    .onEnded { _ in store.dragEnded() }
            )
            .overlay(alignment: .leading) { liftedCapsule(in: all) }
            .padding(Metrics.shellInset)
            .background { Color.clear.glass(in: shell) } // behind, so the cells never depend on it
            .overlay { shell.strokeBorder(.primary.opacity(0.35), lineWidth: 1.5) }
            .overlay(alignment: .trailing) { // battery terminal
                UnevenRoundedRectangle(bottomTrailingRadius: 4, topTrailingRadius: 4)
                    .fill(.primary.opacity(0.35))
                    .frame(width: Metrics.nubSize.width, height: Metrics.nubSize.height)
                    .offset(x: 3 + Metrics.nubSize.width)
            }
            .animation(.easeOut(duration: 0.15), value: store.drag.liftedID)

            HStack(spacing: 0) {
                Spacer(minLength: 0)
                ForEach(visible) { s in
                    Text("−\(s.gain)m")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7) // stays inside its slice, so neighbours never overlap
                        .frame(width: s.width)
                        .opacity(store.interactive && !s.isOther && s.width >= Metrics.labelMinWidth ? 1 : 0)
                        .transition(.opacity.animation(.easeOut(duration: 0.2)))
                        .accessibilityHidden(true)
                }
            }
            .frame(width: Metrics.innerWidth, height: 12)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private var centerText: some View {
        switch store.battery.state {
        case .onBattery where store.minutes != nil:
            Text(formatTime(store.minutes ?? 0))
                .font(.system(size: 21, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Palette.barText)
                .contentTransition(.numericText())
        case let .pluggedIn(charging):
            Label(charging ? "Charging" : "Plugged in", systemImage: "bolt.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.barText)
        case .noBattery:
            Text("No battery").foregroundStyle(.gray)
        default:
            Text("Calculating…").foregroundStyle(.gray)
        }
    }

    private func color(_ s: Segment) -> Color {
        store.interactive ? Palette.slice(s.colorIndex) : Palette.other
    }

    @ViewBuilder private func icon(_ s: Segment) -> some View {
        let size = max(8, min(28, s.width * 0.65))
        if let icon = s.icon {
            Image(nsImage: icon).resizable()
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.15), radius: 1, y: 0.5)
        } else {
            Text("…").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
        }
    }

    private func slice(_ s: Segment) -> some View {
        let draggable = store.interactive && !s.isOther
        let lifted = store.drag.liftedID == s.id
        return color(s).opacity(lifted ? 0.3 : 1) // lifted: only a faint trace stays behind
            .overlay { if !lifted { icon(s) } }
            .overlay { if draggable, hovered == s.id { Color.white.opacity(0.08) } }
            .overlay(alignment: .leading) { Palette.sliceDivider.frame(width: 1) }
            .frame(width: s.width)
            .onHover { inside in
                hovered = inside ? s.id : (hovered == s.id ? nil : hovered)
                if draggable { (inside ? NSCursor.openHand : NSCursor.arrow).set() }
            }
            .contextMenu { if draggable { Button("Quit \(s.name)") { store.quit(s.id) } } }
            .focusable(draggable)
            .onKeyPress(.delete) {
                store.quit(s.id)
                return .handled
            }
            .accessibilityElement()
            .accessibilityLabel(draggable ? "\(s.name), \(s.gain) minutes, quit" : s.name)
            .accessibilityAction(named: "Quit") { store.quit(s.id) }
    }

    /// Slices are right-aligned, so walk from the bar's right edge.
    private func originX(of id: String, in segments: [Segment]) -> CGFloat? {
        var x = Metrics.innerWidth
        for s in segments.reversed() {
            x -= s.width
            if s.id == id { return x }
        }
        return nil
    }

    private func hit(_ x: CGFloat, in segments: [Segment]) -> String? {
        segments.first { s in
            !s.isOther && originX(of: s.id, in: segments).map { x >= $0 && x < $0 + s.width } == true
        }?.id
    }

    /// The dragged slice as a capsule taller than the bar, following the cursor.
    @ViewBuilder private func liftedCapsule(in segments: [Segment]) -> some View {
        if let s = segments.first(where: { $0.id == store.drag.liftedID }), let x = originX(of: s.id, in: segments) {
            Capsule().fill(color(s))
                .frame(width: s.width, height: Metrics.barHeight + 16)
                .overlay { icon(s) }
                .offset(x: x + store.dragOffset.width, y: store.dragOffset.height)
                .transition(.scale(scale: 0.86).combined(with: .opacity))
                .allowsHitTesting(false)
        }
    }
}
