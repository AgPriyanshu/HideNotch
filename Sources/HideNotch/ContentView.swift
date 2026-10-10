import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var model = HideNotchViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if model.items.isEmpty {
                DropZoneView(isTargeted: model.isDropTargeted, onChoose: model.chooseWallpapers)
            } else {
                GalleryView(model: model)
            }

            outputRow

            DisclosureGroup("Options") {
                SettingsView(model: model)
            }

            footer
        }
        .padding(20)
        .frame(minWidth: 620, minHeight: 640, alignment: .top)
        .sheet(isPresented: Binding(
            get: { model.previewURL != nil },
            set: { if !$0 { model.closePreview() } }
        )) {
            PreviewView(model: model)
        }
        .onOpenURL { model.add(urls: [$0]) }
        .onDrop(of: [UTType.fileURL], isTargeted: Binding(get: { model.isDropTargeted }, set: { model.isDropTargeted = $0 }), perform: handleDrop)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("HideNotch")
                .font(.title.bold())
            Text("Adds a black menu bar to your wallpapers so the notch disappears.")
                .foregroundStyle(.secondary)
        }
    }

    private var outputRow: some View {
        HStack {
            Text("Save to")
            Text(model.outputFolder.path(percentEncoded: false))
                .lineLimit(1)
                .truncationMode(.head)
                .foregroundStyle(.secondary)

            Spacer()

            Button("Change…", action: model.chooseOutputFolder)
                .disabled(model.isProcessing)
        }
    }

    private var footer: some View {
        HStack {
            if model.isProcessing {
                ProgressView(value: Double(model.completed), total: Double(max(model.items.count, 1)))
                    .frame(maxWidth: 200)
                Text("\(model.completed) of \(model.items.count)")
                    .foregroundStyle(.secondary)
            } else if let applied = model.appliedName {
                Label("Wallpaper set: \(applied)", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Color.green)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else if let error = model.applyError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.orange)
            } else if model.finished {
                Label(finishedText, systemImage: model.failureCount == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(model.failureCount == 0 ? Color.green : Color.orange)
            }

            Spacer()

            if model.finished {
                Button("Show in Finder", action: model.revealOutput)

                Button("Set as Wallpaper") {
                    if let url = model.selection { model.setAsWallpaper(url) }
                }
                .disabled(model.selection == nil || model.isApplying)
                .help(model.selection == nil ? "Click a wallpaper in the gallery first." : "Apply the selected wallpaper to your display.")
            }

            Button("Add Black Bar", action: model.process)
                .keyboardShortcut(.defaultAction)
                .disabled(model.items.isEmpty || model.isProcessing)
        }
    }

    private var finishedText: String {
        let done = model.items.count - model.failureCount

        return model.failureCount == 0 ? "Saved \(done) wallpapers" : "Saved \(done), \(model.failureCount) failed"
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var urls: [URL] = []
        let group = DispatchGroup()

        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    DispatchQueue.main.async { urls.append(url) }
                }

                group.leave()
            }
        }

        group.notify(queue: .main) { model.add(urls: urls) }

        return true
    }
}
