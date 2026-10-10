import SwiftUI

@main
struct HideNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var controller = NotchController.shared
    @ObservedObject private var loginItem = LoginItemController.shared

    var body: some Scene {
        // A single window, so files opened from the Dock or Finder land in the existing gallery.
        Window("HideNotch", id: "main") {
            ContentView()
        }
        .windowResizability(.contentMinSize)

        MenuBarExtra("HideNotch", systemImage: controller.isEnabled ? "rectangle.topthird.inset.filled" : "rectangle.tophalf.inset.filled") {
            MenuBarMenuView(controller: controller, loginItem: loginItem)
        }
    }
}
