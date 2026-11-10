import SwiftUI

@main
struct BatterySegmentsApp: App {
    @StateObject private var store = Store.shared

    var body: some Scene {
        MenuBarExtra {
            PopoverView(store: store)
                .onAppear { store.opened() }
                .onDisappear { store.closed() }
        } label: {
            Image(nsImage: menuBarIcon(store.battery))
        }
        .menuBarExtraStyle(.window)
    }
}

/// Drawn to match the system battery item (measured from a screenshot of macOS 27):
/// 23x12 pt body, charged part solid, the rest dimmed, percentage knocked out, small terminal.
// shortcut: always shows the percentage; the system hides it when "Show Percentage" is off.
func menuBarIcon(_ battery: BatteryInfo) -> NSImage {
    if battery.state == .noBattery {
        return NSImage(systemSymbolName: "minus.plus.batteryblock", accessibilityDescription: "No battery") ?? NSImage()
    }
    var charging = false
    if case .pluggedIn = battery.state { charging = true }
    let image = NSImage(size: NSSize(width: 26, height: 12), flipped: false) { _ in
        guard let context = NSGraphicsContext.current?.cgContext else { return false }
        let body = CGRect(x: 0, y: 0, width: 23, height: 12)
        let dim = CGColor(gray: 0, alpha: 0.45)

        context.setFillColor(dim)
        context.addPath(CGPath(roundedRect: CGRect(x: 24, y: 4, width: 1.5, height: 4),
                               cornerWidth: 0.75, cornerHeight: 0.75, transform: nil))
        context.fillPath()

        context.saveGState()
        context.addPath(CGPath(roundedRect: body, cornerWidth: 3.5, cornerHeight: 3.5, transform: nil))
        context.clip()
        context.fill(body)
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: body.width * CGFloat(battery.percent) / 100, height: body.height))
        context.restoreGState()

        // Knock the number (and bolt when plugged in) out of the body.
        context.setBlendMode(.destinationOut)
        let text = NSAttributedString(string: "\(battery.percent)", attributes: [
            .font: NSFont.systemFont(ofSize: 10, weight: .medium), .foregroundColor: NSColor.black,
        ])
        let bolt = charging ? NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 6.5, weight: .bold)) : nil
        let textSize = text.size(), boltWidth = bolt.map { $0.size.width + 0.5 } ?? 0
        let x = (body.width - textSize.width - boltWidth) / 2
        text.draw(at: CGPoint(x: x, y: (body.height - textSize.height) / 2))
        if let bolt {
            bolt.draw(in: CGRect(x: x + textSize.width + 0.5, y: (body.height - bolt.size.height) / 2,
                                 width: bolt.size.width, height: bolt.size.height),
                      from: .zero, operation: .destinationOut, fraction: 1)
        }
        return true
    }
    image.isTemplate = true // follows the menu bar's light/dark appearance like the system item
    image.accessibilityDescription = "Battery \(battery.percent) %"
    return image
}
