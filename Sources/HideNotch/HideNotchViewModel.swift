import AppKit
import Foundation
import SwiftUI

@MainActor
final class HideNotchViewModel: ObservableObject {
    @Published var items: [WallpaperItem] = []
    @Published var outputFolder: URL
    @Published var barPercent: Double {
        didSet { SettingsStore.save(barPercent: barPercent, cornerRadius: cornerRadius) }
    }

    @Published var cornerRadius: Double {
        didSet { SettingsStore.save(barPercent: barPercent, cornerRadius: cornerRadius) }
    }
    @Published var isProcessing = false
    @Published var completed = 0
    @Published var isDropTargeted = false
    @Published var selection: URL?
    @Published var appliedName: String?
    @Published var applyError: String?
    @Published var isApplying = false
    @Published var previewURL: URL?
    @Published var previewImage: NSImage?
    @Published var previewError: String?

    let geometry: DisplayGeometry
    private let detectedBarPercent: Double

    init() {
        let geometry = DisplayGeometry.detect()
        self.geometry = geometry
        self.detectedBarPercent = geometry.barRatio * 100
        self.barPercent = SettingsStore.barPercent(default: geometry.barRatio * 100)
        self.cornerRadius = SettingsStore.cornerRadius

        let pictures = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        self.outputFolder = pictures.appendingPathComponent("HideNotch", isDirectory: true)
    }

    var finished: Bool { !items.isEmpty && !isProcessing && completed == items.count }
    var failureCount: Int { items.filter { if case .failed = $0.status { return true } else { return false } }.count }
    var barPoints: Double { barPercent / 100 * geometry.screenSize.height }
    var isCustomized: Bool { abs(barPercent - detectedBarPercent) > 0.001 || cornerRadius != SettingsStore.defaultCornerRadius }

    func resetSettings() {
        barPercent = detectedBarPercent
        cornerRadius = SettingsStore.defaultCornerRadius
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

    private var options: ProcessingOptions {
        ProcessingOptions(barRatio: barPercent / 100, cornerRadiusPoints: cornerRadius, screenSize: geometry.screenSize)
    }

    func openPreview(_ url: URL) {
        selection = url
        previewURL = url
        previewImage = nil
        previewError = nil
        appliedName = nil
        applyError = nil

        let options = options

        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let cgImage = try WallpaperProcessor.render(source: url, options: options)
                let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))

                await self?.finishPreview(image: image, error: nil, for: url)
            } catch {
                await self?.finishPreview(image: nil, error: error.localizedDescription, for: url)
            }
        }
    }

    func closePreview() {
        previewURL = nil
        previewImage = nil
        previewError = nil
    }

    private func finishPreview(image: NSImage?, error: String?, for url: URL) {
        // Ignore a render that finished after another wallpaper was opened.
        guard previewURL == url else { return }

        previewImage = image
        previewError = error
    }

    /// Writes the processed copy if it doesn't exist yet and applies it to the notched display, or to every
    /// display when none has a notch.
    func setAsWallpaper(_ url: URL) {
        guard !isApplying else { return }

        isApplying = true
        appliedName = nil
        applyError = nil

        let options = options
        let folder = outputFolder
        let existing = items.first(where: { $0.url == url })?.output

        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let output: URL

                if let existing {
                    output = existing
                } else {
                    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                    output = try WallpaperProcessor.process(source: url, into: folder, options: options)
                }

                await self?.apply(output, source: url)
            } catch {
                await self?.failApply(error.localizedDescription)
            }
        }
    }

    private func apply(_ output: URL, source: URL) {
        let screens = NSScreen.screens
        let notched = screens.filter { $0.safeAreaInsets.top > 0 }
        let options: [NSWorkspace.DesktopImageOptionKey: Any] = [
            .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
            .allowClipping: true,
        ]

        do {
            for screen in notched.isEmpty ? screens : notched {
                try NSWorkspace.shared.setDesktopImageURL(output, for: screen, options: options)
            }

            if let index = items.firstIndex(where: { $0.url == source }) {
                items[index].output = output
                items[index].status = .done
            }

            appliedName = output.lastPathComponent
        } catch {
            applyError = error.localizedDescription
        }

        isApplying = false
    }

    private func failApply(_ message: String) {
        applyError = message
        isApplying = false
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
        if selection == nil {
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
