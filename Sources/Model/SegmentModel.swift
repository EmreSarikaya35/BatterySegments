import AppKit

struct Segment: Identifiable {
    let id: String
    let name: String
    let pid: pid_t
    let icon: NSImage?
    let colorIndex: Int? // nil = "Other"
    let share: Double // share of total system power, 0...1
    var width: Double = 0
    var gain = 0 // minutes won by quitting this app now

    var isOther: Bool { colorIndex == nil }
}

/// Pure math: usage shares -> slices and time gains.
enum SegmentModel {
    /// Minutes left once apps drawing `closedShare` of total power are gone.
    /// minutes = E / P, so removing a share s of P gives base / (1 - s).
    static func remaining(base: Double, closedShare: Double, watts: Double) -> Double {
        // Never let the remaining draw fall under 0.5 W; cap the gain at 24 h.
        let keep = min(1, max(1 - closedShare, 0.5 / watts))
        return min(base / keep, base + 1440)
    }

    /// Widths proportional to shares, each >= minimum, summing to `area` when possible.
    static func widths(_ shares: [Double], area: Double, minimum: Double = Metrics.sliceMinWidth) -> [Double] {
        let sum = shares.reduce(0, +)
        guard sum > 0 else { return shares.map { _ in minimum } }
        let raw = shares.map { max(minimum, area * $0 / sum) }
        let over = raw.reduce(0, +) - area
        let slack = raw.reduce(0) { $0 + $1 - minimum }
        guard over > 0, slack > 0 else { return raw }
        return raw.map { $0 - ($0 - minimum) * min(1, over / slack) }
    }

    /// Top apps by share (rest folded into "Other"), with widths and gains filled in.
    static func segments(_ apps: [Segment], base: Double, closedShare: Double, watts: Double, area: Double) -> [Segment] {
        let sorted = apps.filter { $0.share > 0 }.sorted { $0.share > $1.share }
        var out = Array(sorted.prefix(Metrics.maxSlices))
        let rest = sorted.dropFirst(Metrics.maxSlices).reduce(0) { $0 + $1.share }
        if rest > 0 {
            out.append(Segment(id: "other", name: "Other", pid: 0, icon: nil, colorIndex: nil, share: rest))
        }
        let w = widths(out.map(\.share), area: area)
        let now = remaining(base: base, closedShare: closedShare, watts: watts)
        for i in out.indices {
            out[i].width = w[i]
            let after = remaining(base: base, closedShare: closedShare + out[i].share, watts: watts)
            out[i].gain = Int((after - now).rounded())
        }
        return out
    }
}
