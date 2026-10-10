import Foundation

struct WallpaperItem: Identifiable {
    enum Status: Equatable {
        case pending
        case done
        case failed(String)
    }

    let url: URL
    var status: Status = .pending

    var id: URL { url }
    var name: String { url.lastPathComponent }
}
