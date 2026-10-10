import SwiftUI

struct ThumbnailView: View {
    let item: WallpaperItem
    let isSelected: Bool
    let aspect: Double

    @StateObject private var thumbnail: ThumbnailModel

    init(item: WallpaperItem, isSelected: Bool, aspect: Double) {
        self.item = item
        self.isSelected = isSelected
        self.aspect = aspect
        _thumbnail = StateObject(wrappedValue: ThumbnailModel(url: item.url))
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .bottomTrailing) {
                Color.secondary.opacity(0.15)
                    .aspectRatio(aspect, contentMode: .fit)
                    .overlay(image)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
                    )

                badge
                    .padding(6)
            }

            Text(item.name)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .contentShape(Rectangle())
        .help(helpText)
        .onAppear { thumbnail.load() }
    }

    @ViewBuilder
    private var image: some View {
        if let image = thumbnail.image {
            // Fill the screen's aspect ratio, the way macOS crops a wallpaper.
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ProgressView().controlSize(.small)
        }
    }

    @ViewBuilder
    private var badge: some View {
        switch item.status {
        case .pending:
            EmptyView()
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.white, .green)
                .font(.title3)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.white, .red)
                .font(.title3)
        }
    }

    private var helpText: String {
        if case .failed(let message) = item.status {
            return "\(item.name): \(message)"
        }

        return item.name
    }
}
