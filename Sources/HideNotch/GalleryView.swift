import SwiftUI

struct GalleryView: View {
    @ObservedObject var model: HideNotchViewModel

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 220), spacing: 14)]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(model.items.count) wallpaper\(model.items.count == 1 ? "" : "s")")
                    .font(.headline)

                Text("Click one to preview")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Add…", action: model.chooseWallpapers)
                Button("Clear", action: model.clear)
            }
            .disabled(model.isProcessing)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(model.items) { item in
                        ThumbnailView(item: item, isSelected: model.selection == item.url, aspect: model.geometry.aspect)
                            .onTapGesture { model.openPreview(item.url) }
                            .contextMenu {
                                Button("Preview") { model.openPreview(item.url) }
                                Button("Remove") { model.remove(item) }
                            }
                    }
                }
                .padding(10)
            }
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.accentColor, lineWidth: model.isDropTargeted ? 2 : 0)
            )
            .frame(minHeight: 220)
        }
    }
}
