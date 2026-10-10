import AppKit
import ServiceManagement

/// Wraps the system login item so the menu can show and change "Launch at Login".
@MainActor
final class LoginItemController: ObservableObject {
    static let shared = LoginItemController()

    @Published private(set) var isEnabled = false
    @Published private(set) var message: String?

    private init() {
        refresh()

        // The user can also change this in System Settings, so re-read it when the app comes forward.
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        let status = SMAppService.mainApp.status

        isEnabled = status == .enabled || status == .requiresApproval

        message = status == .requiresApproval
            ? "Approve HideNotch in System Settings → General → Login Items."
            : nil
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }

            refresh()
        } catch {
            message = error.localizedDescription
            refresh()
        }
    }
}
