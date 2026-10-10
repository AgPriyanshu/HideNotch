import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let event = NSAppleEventManager.shared().currentAppleEvent
        let reason = event?.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))?.enumCodeValue
        let launchedAtLogin = reason == AEKeyword(keyAELaunchedAsLogInItem)

        // When macOS starts the app at login it should sit quietly in the menu bar instead of opening its window.
        guard launchedAtLogin else { return }

        DispatchQueue.main.async {
            NSApp.windows.filter { $0.canBecomeMain }.forEach { $0.close() }
        }
    }
}
