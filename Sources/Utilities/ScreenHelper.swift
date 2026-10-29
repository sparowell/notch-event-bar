import AppKit

enum ScreenHelper {
    // Deployed (hover-expanded) panel size, 25% smaller than the original 640×190.
    static let panelWidth: CGFloat = 480
    /// Space above the content on a screen without a camera cut-out.
    static let plainContentTopInset: CGFloat = 28
    /// Clearance kept under the cut-out before the content starts.
    static let notchContentGap: CGFloat = 8
    static let panelTopBleed: CGFloat = 2
    private static let closedNotchFallbackSize = CGSize(width: 185, height: 32)

    /// Where the content starts: below the camera cut-out when there is one.
    static func contentTopInset() -> CGFloat {
        contentTopInset(safeAreaTop: preferredScreen().safeAreaInsets.top)
    }

    static func contentTopInset(safeAreaTop: CGFloat) -> CGFloat {
        safeAreaTop > 0 ? safeAreaTop + notchContentGap : plainContentTopInset
    }

    static func panelHeight(for snapshot: EventProgressSnapshot) -> CGFloat {
        PanelLayout.height(for: snapshot, topInset: contentTopInset())
    }

    static func panelRect(height panelHeight: CGFloat) -> NSRect {
        let screenFrame = preferredScreen().frame
        return NSRect(
            x: screenFrame.midX - panelWidth / 2,
            y: screenFrame.maxY - panelHeight + panelTopBleed,
            width: panelWidth,
            height: panelHeight
        )
    }

    static func sensorRect() -> NSRect {
        let closedRect = closedNotchRect()

        return NSRect(
            x: closedRect.minX,
            y: closedRect.minY,
            width: closedRect.width,
            height: closedRect.height
        )
    }

    static func collapsedWidth() -> CGFloat {
        closedNotchSize().width
    }

    static func closedHeight() -> CGFloat {
        closedNotchSize().height
    }

    private static func closedNotchRect() -> NSRect {
        let screen = preferredScreen()
        let closedSize = closedNotchSize(for: screen)

        return NSRect(
            x: screen.frame.midX - closedSize.width / 2,
            y: screen.frame.maxY - closedSize.height,
            width: closedSize.width,
            height: closedSize.height
        )
    }

    private static func closedNotchSize(for screen: NSScreen = preferredScreen()) -> CGSize {
        var width = closedNotchFallbackSize.width
        var height = closedNotchFallbackSize.height

        if let topLeftArea = screen.auxiliaryTopLeftArea,
           let topRightArea = screen.auxiliaryTopRightArea {
            width = screen.frame.width - topLeftArea.width - topRightArea.width
        }

        if screen.safeAreaInsets.top > 0 {
            height = screen.safeAreaInsets.top
        } else {
            height = max(closedNotchFallbackSize.height, screen.frame.maxY - screen.visibleFrame.maxY)
        }

        return CGSize(
            width: max(width, closedNotchFallbackSize.width),
            height: max(height, closedNotchFallbackSize.height)
        )
    }

    private static func preferredScreen() -> NSScreen {
        NSScreen.screens.first(where: isBuiltInDisplay) ?? NSScreen.main ?? NSScreen.screens[0]
    }

    private static func isBuiltInDisplay(screen: NSScreen) -> Bool {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        guard let displayID = screen.deviceDescription[key] as? CGDirectDisplayID else {
            return false
        }
        return CGDisplayIsBuiltin(displayID) != 0
    }
}
