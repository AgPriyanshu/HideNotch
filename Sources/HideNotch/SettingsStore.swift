import Foundation

/// Bar and corner settings shared by the window and the menu bar item.
enum SettingsStore {
    static let defaultCornerRadius = 14.0

    private static let barPercentKey = "barPercent"
    private static let cornerRadiusKey = "cornerRadius"

    static func barPercent(default fallback: Double) -> Double {
        UserDefaults.standard.object(forKey: barPercentKey) as? Double ?? fallback
    }

    static var cornerRadius: Double {
        UserDefaults.standard.object(forKey: cornerRadiusKey) as? Double ?? defaultCornerRadius
    }

    static func save(barPercent: Double, cornerRadius: Double) {
        UserDefaults.standard.set(barPercent, forKey: barPercentKey)
        UserDefaults.standard.set(cornerRadius, forKey: cornerRadiusKey)
    }

    static func options(for geometry: DisplayGeometry) -> ProcessingOptions {
        // The saved bar height is tuned for the notch; other displays keep their own menu bar height.
        let barPercent = geometry.hasNotch ? barPercent(default: geometry.barRatio * 100) : geometry.barRatio * 100

        return ProcessingOptions(
            barRatio: barPercent / 100,
            cornerRadiusPoints: cornerRadius,
            screenSize: geometry.screenSize
        )
    }
}
