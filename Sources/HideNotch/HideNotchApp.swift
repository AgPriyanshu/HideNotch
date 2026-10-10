import SwiftUI

@main
struct HideNotchApp: App {
    var body: some Scene {
        // A single window, so files opened from the Dock or Finder land in the existing gallery.
        Window("HideNotch", id: "main") {
            ContentView()
        }
        .windowResizability(.contentMinSize)
    }
}
