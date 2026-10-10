import SwiftUI

struct WallpaperRowView: View {
    let item: WallpaperItem

    var body: some View {
        HStack(spacing: 8) {
            icon
            Text(item.name)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            if case .failed(let message) = item.status {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var icon: some View {
        switch item.status {
        case .pending:
            Image(systemName: "photo").foregroundStyle(.secondary)
        case .done:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
        }
    }
}
