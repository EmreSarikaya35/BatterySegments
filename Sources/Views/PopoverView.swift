import ServiceManagement
import SwiftUI

struct PopoverView: View {
    @ObservedObject var store: Store
    @State private var hoverSettings = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Battery").fontWeight(.semibold)
                Spacer()
                Text(store.battery.state == .noBattery ? "—" : "\(store.battery.percent) %")
                    .foregroundStyle(.secondary)
            }
            .frame(height: 16)

            Text("Power Source: \(onBattery ? "Battery" : "Power Adapter")")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(height: 14)
                .padding(.top, 8)

            BatteryBar(store: store).padding(.top, 16)

            HStack(spacing: 6) {
                Text("Time left").foregroundStyle(.secondary)
                Spacer()
                Text(store.minutes.map(formatTime) ?? "—")
                    .monospacedDigit()
                    .contentTransition(.numericText())
                if store.gain > 0 {
                    Text("+" + formatTime(store.gain))
                        .fontWeight(.semibold)
                        .monospacedDigit()
                        .foregroundStyle(Palette.gain)
                        .contentTransition(.numericText())
                        .transition(.opacity.combined(with: .offset(x: 4)).animation(.easeOut(duration: 0.25)))
                }
            }
            .frame(height: 18)
            .padding(.top, 12)

            Color.primary.opacity(0.12).frame(height: 1).padding(.top, 6)

            HStack {
                Text("Low Power Mode")
                Spacer()
                // The switch only follows the system: it flips once macOS reports the change,
                // so cancelling the one-time password prompt leaves it where it was.
                Toggle("Low Power Mode", isOn: Binding(get: { lowPower }, set: LowPowerMode.set))
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .labelsHidden()
            }
            .frame(height: 24)
            .padding(.top, 6)
            .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)
                .receive(on: RunLoop.main)) { _ in
                    lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
            }

            HStack(spacing: 4) {
                Button {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Battery-Settings.extension")!)
                } label: {
                    Text("Battery Settings…")
                        .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
                        .padding(.horizontal, 8)
                        .background(.primary.opacity(hoverSettings ? 0.08 : 0), in: RoundedRectangle(cornerRadius: 6))
                        .contentShape(Rectangle())
                }
                .onHover { hoverSettings = $0 }
                .padding(.leading, -8)

                Button { NSApp.terminate(nil) } label: {
                    Image(systemName: "power")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .help("Quit BatterySegments")
                .accessibilityLabel("Quit BatterySegments")
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .font(.system(size: 13))
        .padding(.horizontal, Metrics.padH)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .frame(width: Metrics.popoverSize.width, height: Metrics.popoverSize.height, alignment: .top)
        // No fill of our own: the system's glass window shows through and text adapts to it.
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: store.minutes)
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: store.segments.map(\.width))
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: store.drag.previewID)
        // The only setting; right-click the popover (no settings window by design).
        .contextMenu {
            Toggle("Launch at Login", isOn: Binding(get: { launchAtLogin }, set: { on in
                try? (on ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister())
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }))
        }
    }

    private var onBattery: Bool {
        switch store.battery.state {
        case .onBattery, .calculating: true
        default: false
        }
    }
}
