import SwiftUI

struct SettingsView: View {
    @AppStorage("readerDefaultWPM") private var defaultWPM = 350
    @AppStorage("readerDefaultFontSize") private var defaultFontSize = 72.0

    @AppStorage("readerDefaultChunkSize") private var chunkSize = 1
    @AppStorage("readerDefaultContext") private var showContext = true
    @AppStorage("readerDefaultPauses") private var pauses = true
    @AppStorage("readerDefaultFocus") private var focus = false

    @AppStorage("readerDefaultRamp") private var ramp = 0.0
    @AppStorage("readerDefaultLongWords") private var longWords = false
    @AppStorage("readerDefaultRewind") private var rewind = 0

    var body: some View {
        Form {
            Section("Reading Defaults") {
                Stepper("Default speed: \(defaultWPM) WPM", value: $defaultWPM, in: 100...900, step: 25)
                Slider(value: $defaultFontSize, in: 42...110, step: 2) {
                    Text("Default word size")
                } minimumValueLabel: {
                    Text("42")
                } maximumValueLabel: {
                    Text("110")
                }
                Picker("Words at a time", selection: $chunkSize) {
                    ForEach(1...4, id: \.self) { Text("\($0)").tag($0) }
                }
                Toggle("Context", isOn: $showContext)
                Toggle("Punctuation pauses", isOn: $pauses)
                Toggle("Focus", isOn: $focus)
                Stepper("Warm-up: \(Int(ramp)) s", value: $ramp, in: 0...10, step: 1)
                Toggle("Pause on long words", isOn: $longWords)
                Stepper("Rewind on resume: \(rewind) words", value: $rewind, in: 0...20)
                Text("Defaults apply to newly imported documents.").font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .padding()
    }
}
