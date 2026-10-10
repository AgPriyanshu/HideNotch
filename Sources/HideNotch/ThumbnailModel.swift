import AppKit
import Foundation

@MainActor
final class ThumbnailModel: ObservableObject {
    private static let cache = NSCache<NSURL, NSImage>()

    @Published var image: NSImage?

    private let url: URL

    init(url: URL) {
        self.url = url
        self.image = Self.cache.object(forKey: url as NSURL)
    }

    func load() {
        guard image == nil else { return }

        let url = url

        Task.detached(priority: .utility) {
            guard let cgImage = WallpaperProcessor.thumbnail(for: url, maxPixelSize: 480) else { return }

            let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))

            await MainActor.run {
                Self.cache.setObject(image, forKey: url as NSURL)
                self.image = image
            }
        }
    }
}
