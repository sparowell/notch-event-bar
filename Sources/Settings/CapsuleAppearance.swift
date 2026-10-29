import AppKit
import SwiftUI

/// A colour kept as plain numbers so it survives UserDefaults.
struct RGBAColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init(_ color: Color) {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(red: 1, green: 1, blue: 1, alpha: 1)
        self.init(
            red: Double(ns.redComponent),
            green: Double(ns.greenComponent),
            blue: Double(ns.blueComponent),
            alpha: Double(ns.alphaComponent)
        )
    }

    func with(alpha: Double) -> RGBAColor {
        RGBAColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}

/// How one kind of nested-meeting capsule looks. Defaults reproduce the
/// original design: amber for upcoming, a muted sand for past.
struct CapsuleAppearance: Codable, Equatable {
    static let heightRange: ClosedRange<Double> = 13...30
    /// Opacity of the border when it follows the fill colour.
    static let automaticBorderAlpha = 0.9

    var fill: RGBAColor
    /// Total height in points; the bar is 13, the rest sticks out evenly.
    var height: Double
    var usesCustomBorder = false
    var border: RGBAColor
    /// Upcoming capsules only: whether the caption takes the fill's colour.
    var labelFollowsFill = true
    var label: RGBAColor

    static let upcomingDefault = CapsuleAppearance(
        fill: RGBAColor(red: 0xF0 / 255, green: 0xA2 / 255, blue: 0x3C / 255, alpha: 0.32),
        height: 23,
        border: RGBAColor(red: 0xF0 / 255, green: 0xA2 / 255, blue: 0x3C / 255),
        label: RGBAColor(red: 0xF0 / 255, green: 0xA2 / 255, blue: 0x3C / 255)
    )

    static let pastDefault = CapsuleAppearance(
        fill: RGBAColor(red: 214 / 255, green: 178 / 255, blue: 128 / 255, alpha: 0.62),
        height: 17,
        border: RGBAColor(red: 214 / 255, green: 178 / 255, blue: 128 / 255),
        label: RGBAColor(red: 214 / 255, green: 178 / 255, blue: 128 / 255)
    )

    var clampedHeight: Double {
        min(max(height, Self.heightRange.lowerBound), Self.heightRange.upperBound)
    }

    var borderColor: Color {
        (usesCustomBorder ? border : fill.with(alpha: Self.automaticBorderAlpha)).color
    }

    /// The caption is always drawn opaque: only the fill is meant to be see-through.
    var labelColor: Color {
        (labelFollowsFill ? fill.with(alpha: 1) : label.with(alpha: 1)).color
    }
}
