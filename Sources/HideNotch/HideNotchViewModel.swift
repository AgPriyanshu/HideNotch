import AppKit
import Foundation
import SwiftUI

@MainActor
final class HideNotchViewModel: ObservableObject {
    @Published var items: [WallpaperItem] = []
    @Published var outputFolder: URL
    @Published var barPercent: Double
    @Published var cornerRadius = 14.0
    @Published var isProcessing = false
    @Published var completed = 0
    @Published var isDropTargeted = false
    @Published var selection: URL?
    @Published var appliedName: String?
    @Published var applyError: String?

    let geometry: DisplayGeometry
    private let detectedBarPercent: Double

    init() {
        let geometry = DisplayGeometry.detect()
        self.geometry = geometry
        self.detectedBarPercent = geometry.barRatio * 100
        self.barPercent = geometry.barRatio * 100

        let pictures = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        self.outputFolder = pictures.appendingPathComponent("HideNotch", isDirectory: true)
    }

    var finished: Bool { !items.isEmpty && !isProcessing && completed == items.count }
    var failureCount: Int { items.filter { if case .failed = $0.status { return true } else { return false } }.count }
    var barPoints: Double { barPercent / 100 * geometry.screenSize.height }
    var isCustomized: Bool { abs(barPercent - detectedBarPercent) > 0.001 || cornerRadius != 14 }

    func resetSettings() {
        barPercent = detectedBarPercent
        cornerRadius = 14
    }

    func add(urls: [URL]) {
        guard !isProcessing else { return }

        var known = Set(items.map(\.url))
        var added: [WallpaperItem] = []

        for url in urls.flatMap(Self.expand) where !known.contains(url) {
            known.insert(url)
            added.append(WallpaperItem(url: url))
        }

        items = (items + added).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        completed = 0
        resetStatuses()
    }

    func clear() {
        guard !isProcessing else { return }

        items = []
        completed = 0
        selection = nil
    }

    func remove(_ item: WallpaperItem) {
        guard !isProcessing else { return }

        items.removeAll { $0.id == item.id }

        if selection == item.id {
            selection = nil
        }
    }

    func chooseWallpapers() {
        let panel = NSOpenPanel()
        panel.title = "Choose wallpapers or folders"
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true

        guard panel.runModal() == .OK else { return }

        add(urls: panel.urls)
    }

    func chooseOutputFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose where to save the new wallpapers"
        panel.prompt = "Choose"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        outputFolder = url
    }

    var selectedOutput: URL? {
        items.first(where: { $0.url == selection })?.output
    }

    /// Applies the selected processed wallpaper to the notched display, or to every display when none has a notch.
    func applySelection() {
        guard let output = selectedOutput else { return }

        let screens = NSScreen.screens
        let notched = screens.filter { $0.safeAreaInsets.top > 0 }
        let options: [NSWorkspace.DesktopImageOptionKey: Any] = [
            .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
            .allowClipping: true,
        ]

        applyError = nil
        appliedName = nil

        do {
            for screen in notched.isEmpty ? screens : notched {
                try NSWorkspace.shared.setDesktopImageURL(output, for: screen, options: options)
            }

            appliedName = output.lastPathComponent
        } catch {
            applyError = error.localizedDescription
        }
    }

    func revealOutput() {
        NSWorkspace.shared.activateFileViewerSelecting([outputFolder])
    }

    func process() {
        guard !isProcessing, !items.isEmpty else { return }

        resetStatuses()
        completed = 0
        isProcessing = true
        appliedName = nil
        applyError = nil

        let options = ProcessingOptions(
            barRatio: barPercent / 100,
            cornerRadiusPoints: cornerRadius,
            screenSize: geometry.screenSize
        )
        let folder = outputFolder
        let urls = items.map(\.url)

        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            } catch {
                await self?.finishAll(message: error.localizedDescription, urls: urls)
                return
            }

            for url in urls {
                let result: WallpaperItem.Status
                let output: URL?

                do {
                    output = try WallpaperProcessor.process(source: url, into: folder, options: options)
                    result = .done
                } catch {
                    output = nil
                    result = .failed(error.localizedDescription)
                }

                await self?.record(result, output: output, for: url)
            }

            await self?.finishProcessing()
        }
    }

    private func record(_ status: WallpaperItem.Status, output: URL? = nil, for url: URL) {
        if let index = items.firstIndex(where: { $0.url == url }) {
            items[index].status = status
            items[index].output = output
        }

        completed += 1
    }

    private func finishAll(message: String, urls: [URL]) {
        for url in urls {
            record(.failed(message), for: url)
        }

        isProcessing = false
    }

    private func finishProcessing() {
        isProcessing = false

        // Preselect the first result so the wallpaper can be applied straight away.
        if selectedOutput == nil {
            selection = items.first(where: { $0.output != nil })?.url
        }
    }

    private func resetStatuses() {
        for index in items.indices {
            items[index].status = .pending
            items[index].output = nil
        }
    }

    private static func expand(_ url: URL) -> [URL] {
        var isDirectory: ObjCBool = false

        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return [] }

        guard isDirectory.boolValue else {
            return WallpaperProcessor.supportedExtensions.contains(url.pathExtension.lowercased()) ? [url] : []
        }

        let contents = (try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []

        return contents.filter { WallpaperProcessor.supportedExtensions.contains($0.pathExtension.lowercased()) }
    }
}
