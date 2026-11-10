import AppKit
import IOKit.ps
import SwiftUI
import UniformTypeIdentifiers

/// App state: battery, slices, drag, and the apps closed in this popover session.
@MainActor
final class Store: ObservableObject {
    static let shared = Store()

    /// `-demo` launch argument: the reference data (64 %, 3:40, five fake apps), quits are simulated.
    let demo = CommandLine.arguments.contains("-demo")

    @Published private(set) var battery = BatteryInfo()
    @Published private(set) var segments: [Segment] = []
    @Published private(set) var drag = DragCoordinator()
    @Published private(set) var dragOffset = CGSize.zero

    private var apps: [Segment] = []
    private var quitApps: [Segment] = [] // apps quit in this popover session
    private var base = 0.0 // minutes left before any app was closed
    // Usage is measured from `baseline` to now. Short windows are useless: billed energy is
    // reported in bursts, so idle-looking apps vanish and slices jump on every sample.
    // Empty baseline = since each process started; replaced by a snapshot once it is 10 min old.
    // shortcut: until the first promotion, a just-launched app is under-weighted against
    // long-running ones; sample in the background if that ever matters.
    private var baseline: Snapshot = [:]
    private var nextBaseline: (taken: Date, snapshot: Snapshot)?
    private var sampler: Task<Void, Never>?
    private let ghost = GhostPanel()

    private init() {
        refreshBattery()
        guard !demo else { return }
        let source = IOPSNotificationCreateRunLoopSource({ _ in
            Task { @MainActor in Store.shared.refreshBattery() }
        }, nil).takeRetainedValue()
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
    }

    // MARK: Derived state

    private var closedShare: Double { quitApps.reduce(0) { $0 + $1.share } }

    /// On battery with a readable power draw: slices are colored and draggable.
    var interactive: Bool {
        if case .onBattery = battery.state { battery.watts != nil } else { false }
    }

    var showSlices: Bool {
        if case .pluggedIn = battery.state { true } else { interactive }
    }

    /// Minutes left, including closed apps and the one being previewed as closed.
    var minutes: Int? {
        guard case .onBattery = battery.state else { return nil }
        let preview = segments.first { $0.id == drag.previewID }?.share ?? 0
        return Int(SegmentModel.remaining(base: base, closedShare: closedShare + preview,
                                          watts: battery.watts ?? 0).rounded())
    }

    /// Minutes won so far in this session.
    var gain: Int {
        minutes.map { $0 - Int(base.rounded()) } ?? 0
    }

    // MARK: Popover lifecycle (sampling only runs while it is open)

    func opened() {
        quitApps = []
        refreshBattery()
        sampler?.cancel()
        sampler = Task {
            while !Task.isCancelled {
                sample()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    func closed() {
        sampler?.cancel()
        sampler = nil
    }

    func refreshBattery() {
        battery = demo ? BatteryInfo(percent: 64, state: .onBattery(minutes: 220), watts: 10) : .read()
        // shortcut: after a quit the base stays frozen until the popover reopens,
        // otherwise the system's own rising estimate would be counted twice.
        if quitApps.isEmpty, case let .onBattery(minutes) = battery.state { base = minutes }
        if drag.phase == .idle { rebuild() }
    }

    private func sample() {
        if demo {
            apps = Self.demoApps
        } else {
            let now = ProcessEnergy.snapshot()
            if let next = nextBaseline, Date().timeIntervalSince(next.taken) > 600 {
                baseline = next.snapshot
                nextBaseline = nil
            }
            if nextBaseline == nil { nextBaseline = (Date(), now) }
            let own = Bundle.main.bundleIdentifier
            let running = NSWorkspace.shared.runningApplications.filter {
                $0.activationPolicy == .regular && $0.bundleIdentifier != own
                    && $0.bundleIdentifier != "com.apple.finder"
            }
            let usage = ProcessEnergy.usage(from: baseline, to: now,
                                            apps: Set(running.map(\.processIdentifier)))
            guard usage.total > 0 else { return }
            apps = running.map { app in
                Segment(id: String(app.processIdentifier), name: app.localizedName ?? "App",
                        pid: app.processIdentifier, icon: app.icon,
                        colorIndex: Palette.colorIndex(for: app.bundleIdentifier ?? ""),
                        share: (usage.perApp[app.processIdentifier] ?? 0) / usage.total)
            }
        }
        if drag.phase == .idle { rebuild() } // never reshuffle slices under the cursor
    }

    private func rebuild() {
        // Closed apps keep their place in the layout math so the remaining slices never move.
        let gone = Set(quitApps.map(\.id))
        segments = SegmentModel.segments(apps.filter { !gone.contains($0.id) } + quitApps, base: base,
                                         closedShare: closedShare, watts: interactive ? battery.watts ?? 0 : 0,
                                         area: Metrics.sliceArea)
            .filter { !gone.contains($0.id) }
    }

    // MARK: Drag and quit

    func dragChanged(start id: String?, translation: CGSize) {
        switch drag.phase {
        case .idle:
            guard interactive, let id else { return }
            drag.begin(id)
        case .pending:
            return
        default:
            break
        }
        drag.move(inside: !ghost.mouseIsOutsideApp())
        dragOffset = translation
        NSCursor.closedHand.set()
        if case let .outside(id) = drag.phase, let s = segments.first(where: { $0.id == id }) {
            ghost.show(color: Palette.slice(s.colorIndex), icon: s.icon, text: "Quit \(s.name) · +\(s.gain) min")
        } else {
            ghost.hide()
        }
    }

    func dragEnded() {
        NSCursor.arrow.set()
        dragOffset = .zero
        commitDrop()
    }

    /// Keyboard / context menu / VoiceOver alternative to dragging.
    func quit(_ id: String) {
        guard interactive, drag.phase == .idle else { return }
        drag.begin(id)
        drag.move(inside: false)
        commitDrop()
    }

    private func commitDrop() {
        ghost.hide(dropped: true)
        guard let id = drag.drop(), let s = segments.first(where: { $0.id == id }) else { return }
        Task {
            let quit = demo ? true : await QuitService.quit(pid: s.pid)
            if quit {
                quitApps.append(s)
            } else {
                ghost.show(color: .clear, icon: nil, text: "\(s.name) did not quit", tile: false)
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    if drag.phase == .idle { ghost.hide() }
                }
            }
            drag.resolve()
            rebuild()
        }
    }

    // MARK: Demo data (reference recording)

    private static let demoApps: [Segment] = [
        ("Google Chrome", "com.google.Chrome", 0.2414), // +70 min
        ("Figma", "com.figma.Desktop", 0.1791), // +48 min
        ("Xcode", "com.apple.dt.Xcode", 0.1538), // +40 min
        ("Slack", "com.tinyspeck.slackmacgap", 0.0624), // +26 min after Chrome
        ("Music", "com.apple.Music", 0.03),
    ].enumerated().map { index, app in
        let icon = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.1)
            .map { NSWorkspace.shared.icon(forFile: $0.path) } ?? NSWorkspace.shared.icon(for: .application)
        return Segment(id: app.1, name: app.0, pid: 0, icon: icon, colorIndex: index, share: app.2)
    }
}
