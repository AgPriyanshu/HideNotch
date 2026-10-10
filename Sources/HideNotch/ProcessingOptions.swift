import Foundation

struct ProcessingOptions {
    /// Bar height as a fraction of the visible screen height.
    var barRatio: Double
    /// Window corner radius in points; the corner fillers hide wallpaper leaking around it.
    var cornerRadiusPoints: Double
    var screenSize: CGSize

    /// Extra points the fillers extend below the bar and past the arc.
    static let cornerMarginPoints = 2.0

    var screenAspect: Double { screenSize.width / screenSize.height }
}
