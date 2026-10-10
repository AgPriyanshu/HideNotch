import SwiftUI

struct PreviewView: View {
    @ObservedObject var model: HideNotchViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(model.previewURL?.lastPathComponent ?? "")
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Text("Preview with the black bar applied")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ZStack {
                Color.black.opacity(0.85)

                if let image = model.previewImage {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                } else if let message = model.previewError {
                    Text(message).foregroundStyle(.white)
                } else {
                    ProgressView()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .frame(minHeight: 340)

            HStack {
                if let applied = model.appliedName {
                    Label("Wallpaper set: \(applied)", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Color.green)
                        .lineLimit(1)
                } else if let error = model.applyError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.orange)
                }

                Spacer()

                Button("Close", action: model.closePreview)
                    .keyboardShortcut(.cancelAction)

                Button("Set as Wallpaper") {
                    if let url = model.previewURL { model.setAsWallpaper(url) }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(model.previewImage == nil || model.isApplying)
            }
        }
        .padding(20)
        .frame(minWidth: 680, minHeight: 480)
    }
}
