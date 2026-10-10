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
                wallpaperList
            }

            outputRow

            DisclosureGroup("Options") {
                SettingsView(model: model)
            }

            footer
        }
        .padding(20)
        .frame(minWidth: 520, minHeight: 560, alignment: .top)
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

    private var wallpaperList: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(model.items.count) wallpaper\(model.items.count == 1 ? "" : "s")")
                    .font(.headline)

                Spacer()

                Button("Add…", action: model.chooseWallpapers)
                Button("Clear", action: model.clear)
            }
            .disabled(model.isProcessing)

            List {
                ForEach(model.items) { item in
                    WallpaperRowView(item: item)
                        .contextMenu {
                            Button("Remove") { model.remove(item) }
                        }
                }
            }
            .listStyle(.bordered)
            .frame(minHeight: 150)
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
            } else if model.finished {
                Label(finishedText, systemImage: model.failureCount == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(model.failureCount == 0 ? Color.green : Color.orange)
            }

            Spacer()

            if model.finished {
                Button("Show in Finder", action: model.revealOutput)
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
