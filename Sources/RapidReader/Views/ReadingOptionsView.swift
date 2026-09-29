import RapidReaderCore
import SwiftUI

struct ReadingOptionsView: View {
    @Binding var preferences: ReadingPreferences
    @AppStorage(ReaderTheme.storageKey) private var theme: ReaderTheme = .system

    var body: some View {
        Form {
            Picker("Theme", selection: $theme) {
                ForEach(ReaderTheme.allCases) { Text($0.title).tag($0) }
            }
            Stepper("Warm-up: \(Int(preferences.rampUpSeconds)) s", value: $preferences.rampUpSeconds, in: 0...10, step: 1)
            Toggle("Pause on long words", isOn: $preferences.pauseOnLongWords)
            Stepper("Rewind on resume: \(preferences.resumeRewindWords) words", value: $preferences.resumeRewindWords, in: 0...20)
            Text("Warm-up starts at half speed. Long words stay on screen up to 60% longer.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .frame(width: 320, height: 250)
    }
}
