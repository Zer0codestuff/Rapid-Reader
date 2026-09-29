import SwiftUI

struct SettingsView: View {
    @ObservedObject var updater: AppUpdater

    var body: some View {
        TabView {
            GeneralSettings(updater: updater)
                .tabItem { Label("General", systemImage: "gearshape") }
            ReadingDefaultsSettings()
                .tabItem { Label("Reading", systemImage: "text.book.closed") }
        }
        .tint(.readerAmber)
    }
}

private struct GeneralSettings: View {
    @ObservedObject var updater: AppUpdater
    @AppStorage(ReaderTheme.storageKey) private var theme: ReaderTheme = .system

    var body: some View {
        Form {
            Section {
                Picker("Reader theme", selection: $theme) {
                    ForEach(ReaderTheme.allCases) { Text($0.title).tag($0) }
                }
            } footer: {
                Text("Light, Dark, and Sepia also set the window appearance. System follows macOS.")
            }

            if updater.isAvailable {
                Section("Updates") {
                    Toggle("Automatically check for updates", isOn: $updater.automaticallyChecksForUpdates)
                    LabeledContent("Check for a new version") {
                        Button("Check Now", action: updater.checkForUpdates)
                            .disabled(!updater.canCheckForUpdates)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: updater.isAvailable ? 280 : 170)
    }
}

/// Defaults for newly imported documents. Keys are unchanged from earlier versions.
private struct ReadingDefaultsSettings: View {
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
            Section {
                LabeledContent("Speed") {
                    Stepper("\(defaultWPM) WPM", value: $defaultWPM, in: 100...900, step: 25)
                        .monospacedDigit()
                }
                LabeledContent("Word size") {
                    Slider(value: $defaultFontSize, in: 42...110) {
                        Text("Word size")
                    } minimumValueLabel: {
                        Image(systemName: "textformat.size.smaller")
                    } maximumValueLabel: {
                        Image(systemName: "textformat.size.larger")
                    }
                    .labelsHidden()
                    .frame(width: 200)
                }
                Picker("Words at a time", selection: $chunkSize) {
                    ForEach(1...4, id: \.self) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("New documents")
            } footer: {
                Text("Defaults apply to newly imported documents. Each open document keeps its own settings.")
            }

            Section("Reading") {
                Toggle("Show surrounding words", isOn: $showContext)
                Toggle("Hide them while playing", isOn: $focus)
                    .disabled(!showContext)
                Toggle("Pause at punctuation", isOn: $pauses)
                Toggle("Slow down on long words", isOn: $longWords)
            }

            Section("Pacing") {
                LabeledContent("Warm-up") {
                    Stepper(ramp == 0 ? "Off" : "\(Int(ramp)) s", value: $ramp, in: 0...10, step: 1)
                        .monospacedDigit()
                }
                LabeledContent("Rewind on resume") {
                    Stepper(rewind == 0 ? "Off" : "\(rewind) words", value: $rewind, in: 0...20)
                        .monospacedDigit()
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 560)
    }
}
