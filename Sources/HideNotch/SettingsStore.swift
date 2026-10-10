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
        ProcessingOptions(
            barRatio: barPercent(default: geometry.barRatio * 100) / 100,
            cornerRadiusPoints: cornerRadius,
            screenSize: geometry.screenSize
        )
    }
}
