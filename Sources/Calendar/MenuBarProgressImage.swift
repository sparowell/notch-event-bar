import AppKit
import SwiftUI

/// Mini progress bar drawn in the menu bar in place of the capsule icon while an
/// event or a break is running. A `MenuBarExtra` label only renders `Image` and
/// `Text`, so the bar is drawn into an `NSImage` rather than built from shapes.
enum MenuBarProgressImage {
    static let size = CGSize(width: 28, height: 6)

    /// Progress and colour of the bar, or `nil` when the plain icon should show.
    static func fill(
        for snapshot: EventProgressSnapshot,
        enabled: Bool
    ) -> (progress: Double, tint: Color)? {
        guard enabled else { return nil }
        switch snapshot.state {
        case .inProgress, .onBreak:
            return (min(max(snapshot.progress, 0), 1), snapshot.tint)
        default:
            return nil
        }
    }

    /// Whole-point filled width (the bar is 28 pt wide), so the image only needs
    /// rebuilding when this value changes rather than on every 30 s tick.
    static func filledWidth(for progress: Double, trackWidth: Int = Int(size.width)) -> Int {
        let clamped = min(max(progress, 0), 1)
        return min(trackWidth, max(0, Int((clamped * Double(trackWidth)).rounded())))
    }

    /// Non-template image: the fill keeps the event colour, the track follows the
    /// menu bar via `labelColor` (resolved when drawn, so light and dark both work).
    static func image(filledWidth: Int, tint: Color) -> NSImage {
        let fillColor = NSColor(tint)
        let image = NSImage(size: size, flipped: false) { rect in
            let radius = rect.height / 2
            let track = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
            NSColor.labelColor.withAlphaComponent(0.25).setFill()
            track.fill()

            guard filledWidth > 0 else { return true }
            NSGraphicsContext.saveGraphicsState()
            track.addClip()
            fillColor.setFill()
            let fillRect = NSRect(x: 0, y: 0, width: CGFloat(filledWidth), height: rect.height)
            NSBezierPath(roundedRect: fillRect, xRadius: radius, yRadius: radius).fill()
            NSGraphicsContext.restoreGraphicsState()
            return true
        }
        image.isTemplate = false
        return image
    }
}
