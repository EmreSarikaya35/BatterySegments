@testable import BatterySegments
import SwiftUI
import XCTest

private func app(_ id: String, _ share: Double) -> Segment {
    Segment(id: id, name: id, pid: 0, icon: nil, colorIndex: 0, share: share)
}

final class SegmentModelTests: XCTestCase {
    func testWidthsFillAreaAndRespectMinimum() {
        let w = SegmentModel.widths([0.5, 0.3, 0.15, 0.04, 0.01], area: 156)
        XCTAssertEqual(w.reduce(0, +), 156, accuracy: 0.001)
        XCTAssertTrue(w.allSatisfy { $0 >= 12 })
        XCTAssertEqual(w, w.sorted(by: >))
    }

    func testTopFivePlusOther() {
        let apps = (1 ... 8).map { app("a\($0)", Double($0) / 100) }
        let s = SegmentModel.segments(apps, base: 200, closedShare: 0, watts: 10, area: 156)
        XCTAssertEqual(s.map(\.id), ["a8", "a7", "a6", "a5", "a4", "other"])
        XCTAssertEqual(s.last!.share, 0.06, accuracy: 1e-9)
        XCTAssertEqual(s.reduce(0) { $0 + $1.share }, 0.36, accuracy: 1e-9) // nothing lost
        XCTAssertTrue(s.allSatisfy { $0.gain > 0 })
    }

    func testReferenceScenario() { // 3:40 -> quit Chrome -> 4:50 -> quit Slack -> 5:16
        XCTAssertEqual(SegmentModel.remaining(base: 220, closedShare: 0, watts: 10), 220)
        XCTAssertEqual(SegmentModel.remaining(base: 220, closedShare: 0.2414, watts: 10), 290, accuracy: 0.5)
        XCTAssertEqual(SegmentModel.remaining(base: 220, closedShare: 0.2414 + 0.0624, watts: 10), 316, accuracy: 0.5)
    }

    func testClosingSeveralAppsBeatsSumOfSingleGains() {
        let r = { SegmentModel.remaining(base: 200, closedShare: $0, watts: 10) }
        XCTAssertGreaterThan(r(0.5) - 200, (r(0.2) - 200) + (r(0.3) - 200))
    }

    func testGuards() {
        // 5 W system: remaining draw never below 0.5 W -> at most 10x
        XCTAssertEqual(SegmentModel.remaining(base: 60, closedShare: 1, watts: 5), 600, accuracy: 0.001)
        // gain capped at 24 h
        XCTAssertEqual(SegmentModel.remaining(base: 600, closedShare: 0.99, watts: 1000), 600 + 1440)
        // unreadable / tiny power: no gain, no division by zero
        XCTAssertEqual(SegmentModel.remaining(base: 60, closedShare: 0.5, watts: 0), 60)
        XCTAssertEqual(SegmentModel.remaining(base: 60, closedShare: 0.5, watts: 0.3), 60)
    }
}

final class ProcessEnergyTests: XCTestCase {
    private func s(_ ppid: pid_t, energy: UInt64 = 0, cpu: UInt64 = 0) -> ProcSample {
        ProcSample(ppid: ppid, energy: energy, cpu: cpu)
    }

    func testChildrenFoldIntoAppAndDeltasOnly() {
        let old: Snapshot = [10: s(1, energy: 100), 11: s(10, energy: 50), 20: s(1, energy: 500), 30: s(1, energy: 10)]
        let new: Snapshot = [10: s(1, energy: 130), 11: s(10, energy: 90), 12: s(11, energy: 5), // 12: new grandchild
                             20: s(1, energy: 500), 30: s(1, energy: 35)]
        let u = ProcessEnergy.usage(from: old, to: new, apps: [10, 20])
        XCTAssertEqual(u.perApp[10], 75) // 30 + 40 + 5
        XCTAssertNil(u.perApp[20]) // idle
        XCTAssertEqual(u.total, 100) // includes non-app pid 30
    }

    func testFallsBackToCPUTimeWithoutEnergy() {
        let u = ProcessEnergy.usage(from: [10: s(1, cpu: 10)], to: [10: s(1, cpu: 30)], apps: [10])
        XCTAssertEqual(u.perApp[10], 20)
        XCTAssertEqual(u.total, 20)
    }
}

final class DragCoordinatorTests: XCTestCase {
    func testDropOutsideQuits() {
        var d = DragCoordinator()
        d.begin("a")
        XCTAssertEqual(d.liftedID, "a")
        XCTAssertNil(d.previewID)
        d.move(inside: false)
        XCTAssertEqual(d.previewID, "a")
        XCTAssertEqual(d.drop(), "a")
        XCTAssertEqual(d.phase, .pending("a"))
        d.begin("b") // ignored while a quit is pending
        XCTAssertEqual(d.previewID, "a")
        d.resolve()
        XCTAssertEqual(d.phase, .idle)
    }

    func testBackInsideCancels() {
        var d = DragCoordinator()
        d.begin("a")
        d.move(inside: false)
        d.move(inside: true)
        XCTAssertEqual(d.phase, .lifted("a"))
        XCTAssertNil(d.drop())
        XCTAssertEqual(d.phase, .idle)
    }
}

/// Runs the reference scenario through the real Store in demo mode (the scheme passes `-demo`)
/// and writes popover snapshots to build/snapshots for visual comparison with the reference design.
@MainActor
final class DemoFlowTests: XCTestCase {
    private let store = Store.shared

    private func settle() async throws { try await Task.sleep(for: .milliseconds(100)) }

    private func snapshot(_ name: String) throws {
        let renderer = ImageRenderer(content: PopoverView(store: store).background(Color(red: 0.1, green: 0.16, blue: 0.42))
            .environment(\.colorScheme, .dark))
        renderer.scale = 2
        let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("build/snapshots")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // App icons make the renderer emit HDR (PQ); convert to sRGB or white comes out gray.
        let image = CIImage(cgImage: try XCTUnwrap(renderer.cgImage))
        let png = try XCTUnwrap(CIContext().pngRepresentation(of: image, format: .RGBA8,
                                                              colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!))
        try png.write(to: dir.appendingPathComponent("\(name).png"))
    }

    func testReferenceScenario() async throws {
        try XCTSkipUnless(store.demo, "needs the -demo launch argument")
        store.opened()
        defer { store.closed() }
        try await settle()
        XCTAssertEqual(store.minutes, 220)
        XCTAssertEqual(store.gain, 0)
        XCTAssertEqual(store.segments.map(\.gain).prefix(3), [70, 48, 40])
        XCTAssertEqual(store.segments.reduce(0) { $0 + $1.width }, Metrics.sliceArea, accuracy: 0.01)
        try snapshot("1-open")
        let widths = store.segments.map(\.width)

        store.quit("com.google.Chrome")
        XCTAssertEqual(store.minutes, 290) // previewed immediately
        try await settle()
        XCTAssertEqual(store.minutes, 290)
        XCTAssertEqual(store.gain, 70)
        XCTAssertEqual(store.segments.map(\.name), ["Figma", "Xcode", "Slack", "Music"])
        for (now, before) in zip(store.segments.map(\.width), widths.dropFirst()) {
            XCTAssertEqual(now, before, accuracy: 0.01) // other slices do not move
        }
        try snapshot("2-chrome-closed")

        store.quit("com.tinyspeck.slackmacgap")
        try await settle()
        XCTAssertEqual(store.minutes, 316)
        XCTAssertEqual(store.gain, 96)
        try snapshot("3-slack-closed")

        store.opened() // reopening resets the session
        try await settle()
        XCTAssertEqual(store.minutes, 220)
        XCTAssertEqual(store.segments.count, 5)
    }
}
