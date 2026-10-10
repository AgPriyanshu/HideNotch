import SwiftUI

@main
struct HideNotchApp: App {
    @ObservedObject private var controller = NotchController.shared

    var body: some Scene {
        // A single window, so files opened from the Dock or Finder land in the existing gallery.
        Window("HideNotch", id: "main") {
            ContentView()
        }
        .windowResizability(.contentMinSize)

        MenuBarExtra("HideNotch", systemImage: controller.isEnabled ? "rectangle.topthird.inset.filled" : "rectangle.tophalf.inset.filled") {
            MenuBarMenuView(controller: controller)
        }
    }
}
