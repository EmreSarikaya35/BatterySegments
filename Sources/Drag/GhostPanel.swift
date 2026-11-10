import AppKit
import SwiftUI

/// Transparent, click-through panel that floats the drag ghost outside the popover.
@MainActor
final class GhostPanel {
    final class Model: ObservableObject {
        @Published var color = Color.clear
        @Published var icon: NSImage?
        @Published var text = ""
        @Published var showTile = true
        @Published var visible = false
        @Published var dropped = false
    }

    private static let size = CGSize(width: 460, height: 190)
    static let tileCenterY: CGFloat = 12 + Metrics.ghostSize / 2

    private let model = Model()
    private lazy var panel: NSPanel = {
        let panel = NSPanel(contentRect: CGRect(origin: .zero, size: Self.size),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.popUpMenu.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: GhostView(model: model))
        return panel
    }()

    /// True when the mouse is over none of our windows (popover, menu bar item).
    func mouseIsOutsideApp() -> Bool {
        let mouse = NSEvent.mouseLocation
        return !NSApp.windows.contains { $0.isVisible && $0 !== panel && $0.frame.contains(mouse) }
    }

    /// Shows the ghost with its tile centered on the cursor.
    func show(color: Color, icon: NSImage?, text: String, tile: Bool = true) {
        model.color = color
        model.icon = icon
        model.text = text
        model.showTile = tile
        let mouse = NSEvent.mouseLocation
        panel.setFrameOrigin(CGPoint(x: mouse.x - Self.size.width / 2,
                                     y: mouse.y + Self.tileCenterY - Self.size.height))
        panel.orderFrontRegardless()
        model.visible = true
    }

    func hide(dropped: Bool = false) {
        guard model.visible else { return }
        model.dropped = dropped
        model.visible = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [self] in
            if !model.visible { panel.orderOut(nil) }
        }
    }
}

private struct GhostView: View {
    @ObservedObject var model: GhostPanel.Model

    var body: some View {
        VStack(spacing: 14) {
            RoundedRectangle(cornerRadius: Metrics.ghostRadius)
                .fill(model.color)
                .frame(width: Metrics.ghostSize, height: Metrics.ghostSize)
                .overlay {
                    if let icon = model.icon {
                        Image(nsImage: icon).resizable().frame(width: 36, height: 36)
                    }
                }
                .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
                .opacity(model.showTile ? 1 : 0)
            Text(model.text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .fixedSize()
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Palette.quitRed, in: RoundedRectangle(cornerRadius: Metrics.tagRadius))
                .rotationEffect(.degrees(Metrics.tagAngle))
                .offset(x: -6)
        }
        .padding(.top, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .scaleEffect(model.visible ? 1 : (model.dropped ? 0.6 : 0.8),
                     anchor: UnitPoint(x: 0.5, y: GhostPanel.tileCenterY / 190))
        .opacity(model.visible ? 1 : 0)
        .animation(.easeOut(duration: model.visible ? 0.15 : 0.2), value: model.visible)
    }
}
