import SwiftUI

enum Metrics {
    static let popoverSize = CGSize(width: 360, height: 281)
    static let padH: CGFloat = 14
    static let barWidth: CGFloat = 312
    static let barHeight: CGFloat = 96
    static let shellInset: CGFloat = 6 // gap between the battery's outline and its cells
    static let shellRadius: CGFloat = 28
    static var innerWidth: CGFloat { barWidth - 2 * shellInset }
    static let sliceArea: Double = 156
    static let sliceMinWidth: Double = 12
    static let labelMinWidth: Double = 28
    static let maxSlices = 5
    static let ghostSize: CGFloat = 64
    static let ghostRadius: CGFloat = 16
    static let tagRadius: CGFloat = 8
    static let tagAngle: Double = -4
    static let nubSize = CGSize(width: 8, height: 34)
}

enum Palette {
    static let barText = Color(white: 0.07)
    static let sliceDivider = Color(red: 0.07, green: 0.09, blue: 0.25).opacity(0.6)
    static let quitRed = Color(red: 0.933, green: 0.294, blue: 0.294)
    static let gain = Color(red: 0.204, green: 0.78, blue: 0.349)
    static let other = Color(red: 0.478, green: 0.498, blue: 0.62)
    static let slices: [Color] = [
        Color(red: 0.357, green: 0.553, blue: 0.878), // blue
        Color(red: 0.647, green: 0.420, blue: 0.882), // purple
        Color(red: 0.298, green: 0.608, blue: 0.875), // light blue
        Color(red: 0.800, green: 0.227, blue: 0.424), // dark pink
        Color(red: 0.894, green: 0.314, blue: 0.420), // red-pink
        Color(red: 0.929, green: 0.576, blue: 0.259), // orange
        Color(red: 0.298, green: 0.733, blue: 0.467), // green
        Color(red: 0.239, green: 0.722, blue: 0.741), // teal
    ]

    /// nil index = the gray "Other" slice
    static func slice(_ index: Int?) -> Color {
        index.map { slices[$0 % slices.count] } ?? other
    }

    /// Stable across launches (String.hashValue is not).
    static func colorIndex(for bundleID: String) -> Int {
        Int(bundleID.utf8.reduce(UInt(5381)) { ($0 &* 33) &+ UInt($1) } % UInt(slices.count))
    }
}

extension View {
    /// Liquid Glass on macOS 26+, plain material before that.
    @ViewBuilder func glass(in shape: some Shape) -> some View {
        if #available(macOS 26, *) {
            glassEffect(.regular, in: shape)
        } else {
            background(.ultraThinMaterial, in: shape)
        }
    }
}

func formatTime(_ minutes: Int) -> String {
    "\(minutes / 60):" + String(format: "%02d", minutes % 60)
}
