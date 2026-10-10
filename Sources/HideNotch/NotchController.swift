import AppKit
import Foundation

/// Drives the menu bar item: hides the notch on the current wallpaper and can put the original back.
@MainActor
final class NotchController: ObservableObject {
    static let shared = NotchController()

    @Published private(set) var isEnabled: Bool
    @Published private(set) var isBusy = false
    @Published private(set) var message: String?

    private static let enabledKey = "notchHidden"
    private static let originalsKey = "originalWallpapers"

    private var originals: [String: String]

    private init() {
        isEnabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
        originals = UserDefaults.standard.dictionary(forKey: Self.originalsKey) as? [String: String] ?? [:]
    }

    private static var generatedFolder: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HideNotch", isDirectory: true)
            .appendingPathComponent("Wallpapers", isDirectory: true)
    }

    func setEnabled(_ enabled: Bool) {
        guard !isBusy, enabled != isEnabled else { return }

        enabled ? enable() : disable()
    }

    /// Regenerates the wallpaper, for example after the user picked a new one in System Settings.
    func refresh() {
        guard isEnabled, !isBusy else { return }

        enable()
    }

    private static func key(for screen: NSScreen) -> String {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.stringValue ?? "main"
    }

    private func enable() {
        isBusy = true
        message = nil

        let folder = Self.generatedFolder
        var originals = self.originals

        // Everything that touches NSScreen is read here, on the main actor.
        var jobs: [(screen: NSScreen, key: String, source: URL, options: ProcessingOptions)] = []

        for screen in NSScreen.screens {
            let key = Self.key(for: screen)

            guard let current = NSWorkspace.shared.desktopImageURL(for: screen) else { continue }

            // The current wallpaper may already be one of ours; the original is what has to be processed again.
            let isGenerated = current.path.hasPrefix(folder.path)
            let source = isGenerated ? originals[key].flatMap(URL.init(string:)) ?? current : current

            if !isGenerated {
                originals[key] = current.absoluteString
            }

            let options = SettingsStore.options(for: DisplayGeometry.geometry(for: screen))

            jobs.append((screen, key, source, options))
        }

        let stored = originals

        Task.detached(priority: .userInitiated) { [weak self] in
            var results: [(screen: NSScreen, output: URL)] = []
            var failure: String?

            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

                for job in jobs {
                    var isDirectory: ObjCBool = false
                    FileManager.default.fileExists(atPath: job.source.path, isDirectory: &isDirectory)

                    if isDirectory.boolValue {
                        failure = "The current wallpaper is a folder of images. Pick a single image first."
                        break
                    }

                    Self.removeGenerated(for: job.source, key: job.key, in: folder)

                    let stamp = String(Int(Date().timeIntervalSince1970))
                    let output = try WallpaperProcessor.process(
                        source: job.source,
                        into: folder,
                        options: job.options,
                        nameSuffix: "-HideNotch-\(job.key)-\(stamp)"
                    )

                    results.append((job.screen, output))
                }
            } catch {
                failure = error.localizedDescription
            }

            await self?.finishEnable(results: results, originals: stored, failure: failure)
        }
    }

    private func finishEnable(results: [(screen: NSScreen, output: URL)], originals: [String: String], failure: String?) {
        defer { isBusy = false }

        if let failure {
            message = failure
            return
        }

        guard !results.isEmpty else {
            message = "No wallpaper was found to process."
            return
        }

        do {
            for result in results {
                try Self.apply(result.output, to: result.screen)
            }
        } catch {
            message = error.localizedDescription
            return
        }

        self.originals = originals
        isEnabled = true
        message = nil
        persist()
    }

    private func disable() {
        isBusy = true
        message = nil

        defer { isBusy = false }

        do {
            for screen in NSScreen.screens {
                guard let original = originals[Self.key(for: screen)].flatMap(URL.init(string:)) else { continue }

                try Self.apply(original, to: screen)
            }
        } catch {
            message = error.localizedDescription
            return
        }

        originals = [:]
        isEnabled = false
        persist()
        try? FileManager.default.removeItem(at: Self.generatedFolder)
    }

    private func persist() {
        UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey)
        UserDefaults.standard.set(originals, forKey: Self.originalsKey)
    }

    private static func apply(_ url: URL, to screen: NSScreen) throws {
        try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [
            .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
            .allowClipping: true,
        ])
    }

    // macOS caches a wallpaper by its URL, so every run writes a new file name and drops the previous ones of the
    // same screen. Each screen has its own file because their aspect ratios, and so their crops, can differ.
    private nonisolated static func removeGenerated(for source: URL, key: String, in folder: URL) {
        let prefix = source.deletingPathExtension().lastPathComponent + "-HideNotch-\(key)-"
        let files = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []

        for file in files where file.hasPrefix(prefix) {
            try? FileManager.default.removeItem(at: folder.appendingPathComponent(file))
        }
    }
}
