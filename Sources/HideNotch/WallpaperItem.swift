import Foundation

struct WallpaperItem: Identifiable {
    enum Status: Equatable {
        case pending
        case done
        case failed(String)
    }

    let url: URL
    var status: Status = .pending
    /// The processed copy, once it has been written.
    var output: URL?

    var id: URL { url }
    var name: String { url.lastPathComponent }
}
