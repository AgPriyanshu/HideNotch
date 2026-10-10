import SwiftUI

struct MenuBarMenuView: View {
    @ObservedObject var controller: NotchController
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Toggle(
            "Hide Notch",
            isOn: Binding(get: { controller.isEnabled }, set: { controller.setEnabled($0) })
        )
        .disabled(controller.isBusy)

        if controller.isBusy {
            Text("Working…")
        } else if let message = controller.message {
            Text(message)
        }

        if controller.isEnabled {
            Button("Apply to Current Wallpaper Again") { controller.refresh() }
                .disabled(controller.isBusy)
        }

        Divider()

        Button("Open HideNotch…") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }

        Button("Quit HideNotch") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
