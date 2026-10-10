import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: HideNotchViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Bar height")
                Slider(value: $model.barPercent, in: 2...8)
                Text(String(format: "%.0f pt", model.barPoints))
                    .monospacedDigit()
                    .frame(width: 48, alignment: .trailing)
            }

            HStack {
                Text("Window corner radius")
                Slider(value: $model.cornerRadius, in: 0...30, step: 1)
                Text(String(format: "%.0f pt", model.cornerRadius))
                    .monospacedDigit()
                    .frame(width: 48, alignment: .trailing)
            }

            HStack {
                Text(detectedDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Reset", action: model.resetSettings)
                    .disabled(!model.isCustomized)
            }
        }
        .padding(.top, 6)
    }

    private var detectedDescription: String {
        let size = model.geometry.screenSize

        return String(format: "%@ · %.0f × %.0f pt%@", model.geometry.name, size.width, size.height, model.geometry.hasNotch ? "" : " · no notch detected")
    }
}
