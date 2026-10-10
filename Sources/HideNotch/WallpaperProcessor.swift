import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum WallpaperError: LocalizedError {
    case unreadable
    case contextFailed
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .unreadable: return "The image could not be read."
        case .contextFailed: return "The image could not be rendered."
        case .writeFailed: return "The result could not be saved."
        }
    }
}

enum WallpaperProcessor {
    static let supportedExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "tif", "tiff", "bmp", "gif", "webp"]

    /// Draws the black bar and corner fillers onto `source` and writes the result into `folder`.
    static func process(source: URL, into folder: URL, options: ProcessingOptions) throws -> URL {
        try write(render(source: source, options: options), source: source, into: folder)
    }

    /// Returns `source` with the black bar and corner fillers drawn on it.
    static func render(source: URL, options: ProcessingOptions) throws -> CGImage {
        let image = try loadImage(source)
        let width = image.width
        let height = image.height

        // macOS fills the screen: the image is scaled to cover it and the overflow is cropped evenly. Wallpapers
        // taller than the screen lose rows at the top and bottom, so the bar starts below that crop; wider ones lose
        // columns at the sides, so the corner fillers sit at the visible edges.
        let visibleHeight = min(Double(height), Double(width) / options.screenAspect)
        let visibleWidth = min(Double(width), Double(height) * options.screenAspect)
        let topOffset = ((Double(height) - visibleHeight) / 2).rounded()
        let sideOffset = ((Double(width) - visibleWidth) / 2).rounded()
        let barHeight = topOffset + (visibleHeight * options.barRatio).rounded()

        let colorSpace = image.colorSpace.flatMap { $0.supportsOutput ? $0 : nil } ?? CGColorSpace(name: CGColorSpace.sRGB)!

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            throw WallpaperError.contextFailed
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Switch to top-down coordinates for the bar and fillers.
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: Double(width), height: barHeight))

        let pointsToPixels = visibleHeight / options.screenSize.height
        let radius = (options.cornerRadiusPoints * pointsToPixels).rounded()

        if radius > 0 {
            let margin = max(1, (ProcessingOptions.cornerMarginPoints * pointsToPixels).rounded())
            drawCornerFillers(
                in: context,
                width: Double(width),
                barHeight: barHeight,
                sideOffset: sideOffset,
                radius: radius,
                margin: margin
            )
        }

        guard let result = context.makeImage() else {
            throw WallpaperError.contextFailed
        }

        return result
    }

    /// Decodes a small, correctly rotated thumbnail without loading the full image.
    static func thumbnail(for url: URL, maxPixelSize: Int) -> CGImage? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]

        return CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary)
    }

    // Each filler is a rectangle minus an ellipse that stays tangent to the bar, so the black follows the arc of a
    // window's rounded corner and a window sitting a hair low still leaves no wallpaper showing.
    private static func drawCornerFillers(
        in context: CGContext,
        width: Double,
        barHeight: Double,
        sideOffset: Double,
        radius: Double,
        margin: Double
    ) {
        let fillerWidth = radius + margin
        let fillerHeight = radius + 2 * margin
        let ellipseHeight = 2 * (radius + margin)

        let leftX = sideOffset
        let rightX = width - sideOffset - fillerWidth

        let fillers: [(rect: CGRect, ellipse: CGRect)] = [
            (
                CGRect(x: leftX, y: barHeight, width: fillerWidth, height: fillerHeight),
                CGRect(x: leftX, y: barHeight, width: 2 * radius, height: ellipseHeight)
            ),
            (
                CGRect(x: rightX, y: barHeight, width: fillerWidth, height: fillerHeight),
                CGRect(x: rightX + fillerWidth - 2 * radius, y: barHeight, width: 2 * radius, height: ellipseHeight)
            ),
        ]

        for filler in fillers {
            context.saveGState()
            context.clip(to: filler.rect)
            context.addRect(filler.rect)
            context.addEllipse(in: filler.ellipse)
            context.drawPath(using: .eoFill)
            context.restoreGState()
        }
    }

    private static func loadImage(_ url: URL) throws -> CGImage {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw WallpaperError.unreadable
        }

        let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any]
        let orientation = (properties?[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1

        if orientation == 1, let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {
            return image
        }

        // Letting ImageIO build a full-size "thumbnail" applies the EXIF rotation.
        let pixelWidth = (properties?[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue ?? 0
        let pixelHeight = (properties?[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue ?? 0
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(pixelWidth, pixelHeight),
        ]

        guard let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            throw WallpaperError.unreadable
        }

        return image
    }

    private static func write(_ image: CGImage, source: URL, into folder: URL) throws -> URL {
        let ext = source.pathExtension.lowercased()
        let isJPEG = ext == "jpg" || ext == "jpeg"
        let type = isJPEG ? UTType.jpeg : UTType.png
        let name = isJPEG || ext == "png" ? source.lastPathComponent : source.deletingPathExtension().lastPathComponent + ".png"
        let destination = folder.appendingPathComponent(name)

        guard let target = CGImageDestinationCreateWithURL(destination as CFURL, type.identifier as CFString, 1, nil) else {
            throw WallpaperError.writeFailed
        }

        let properties: [CFString: Any] = isJPEG ? [kCGImageDestinationLossyCompressionQuality: 0.95] : [:]
        CGImageDestinationAddImage(target, image, properties as CFDictionary)

        guard CGImageDestinationFinalize(target) else {
            throw WallpaperError.writeFailed
        }

        return destination
    }
}

private extension CGColorSpace {
    /// Whether a bitmap context can be created in this color space.
    var supportsOutput: Bool {
        model == .rgb
    }
}
