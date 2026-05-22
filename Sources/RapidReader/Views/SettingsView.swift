import SwiftUI

struct SettingsView: View {
    @AppStorage("readerDefaultWPM") private var defaultWPM = 350
    @AppStorage("readerDefaultFontSize") private var defaultFontSize = 72.0

    var body: some View {
        Form {
            Section("Reading Defaults") {
                Stepper("Default speed: \(defaultWPM) WPM", value: $defaultWPM, in: 100...900, step: 25)
                Slider(value: $defaultFontSize, in: 42...104, step: 2) {
                    Text("Default word size")
                } minimumValueLabel: {
                    Text("42")
                } maximumValueLabel: {
                    Text("104")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .padding()
    }
}
