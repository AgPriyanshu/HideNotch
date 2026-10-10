import AppKit
import CoreGraphics

/// Describes the notched display the wallpapers are meant for.
struct DisplayGeometry {
    /// Menu bar height in points when a notched MacBook runs its default resolution.
    private static let defaultMenuBarPoints = 37.0
    private static let fallbackBarRatio = 74.0 / 1964.0
    private static let fallbackSize = CGSize(width: 1512, height: 982)

    /// Screen size in points for the current scaling mode.
    let screenSize: CGSize
    /// Menu bar height as a fraction of the screen height.
    let barRatio: Double
    let name: String
    let hasNotch: Bool

    var aspect: Double { screenSize.width / screenSize.height }

    static func detect() -> DisplayGeometry {
        let screens = NSScreen.screens

        guard let screen = screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main ?? screens.first else {
            return DisplayGeometry(screenSize: fallbackSize, barRatio: fallbackBarRatio, name: "Unknown display", hasNotch: false)
        }

        return geometry(for: screen)
    }

    /// Geometry of one specific display; used when every connected screen gets its own wallpaper.
    static func geometry(for screen: NSScreen) -> DisplayGeometry {
        DisplayGeometry(
            screenSize: screen.frame.size,
            barRatio: barRatio(for: screen),
            name: screen.localizedName,
            hasNotch: screen.safeAreaInsets.top > 0
        )
    }

    // The menu bar that hides the notch keeps a fixed share of the panel, so it is measured against the display's
    // default resolution instead of the (possibly scaled) mode that is active right now.
    private static func barRatio(for screen: NSScreen) -> Double {
        // A display without a notch just gets a black bar as tall as its menu bar.
        if screen.safeAreaInsets.top == 0 {
            return NSStatusBar.system.thickness / screen.frame.height
        }

        guard
            let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
            let modes = CGDisplayCopyAllDisplayModes(
                CGDirectDisplayID(number.uint32Value),
                [kCGDisplayShowDuplicateLowResolutionModes: true] as CFDictionary
            ) as? [CGDisplayMode],
            let defaultMode = modes.first(where: { $0.ioFlags & 0x4 != 0 }),
            defaultMode.height > 0
        else {
            return fallbackBarRatio
        }

        return defaultMenuBarPoints / Double(defaultMode.height)
    }
}
