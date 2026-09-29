import RapidReaderCore
import SwiftUI

struct ReadingOptionsView: View {
    @Binding var preferences: ReadingPreferences
    @AppStorage(ReaderTheme.storageKey) private var theme: ReaderTheme = .system

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            OptionSection("Appearance") {
                Picker("Theme", selection: $theme) {
                    ForEach(ReaderTheme.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                HStack(spacing: 10) {
                    Image(systemName: "textformat.size.smaller")
                    Slider(value: $preferences.fontSize, in: 42...110)
                        .accessibilityLabel("Word size")
                    Image(systemName: "textformat.size.larger")
                }
                .foregroundStyle(.secondary)

                HStack {
                    Text("Words at a time")
                    Spacer()
                    Picker("Words at a time", selection: $preferences.chunkSize) {
                        ForEach(1...4, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }
            }

            OptionSection("Reading") {
                ToggleRow("Show surrounding words", isOn: $preferences.showContext)
                ToggleRow("Hide them while playing", isOn: $preferences.focusMode)
                    .disabled(!preferences.showContext)
                ToggleRow("Pause at punctuation", isOn: $preferences.pauseOnPunctuation)
                ToggleRow("Slow down on long words", isOn: $preferences.pauseOnLongWords)
            }

            OptionSection("Pacing") {
                StepperRow(
                    title: "Warm-up",
                    value: preferences.rampUpSeconds == 0 ? "Off" : "\(Int(preferences.rampUpSeconds)) s"
                ) {
                    Stepper("Warm-up", value: $preferences.rampUpSeconds, in: 0...10, step: 1)
                }
                StepperRow(
                    title: "Rewind on resume",
                    value: preferences.resumeRewindWords == 0 ? "Off" : "\(preferences.resumeRewindWords) words"
                ) {
                    Stepper("Rewind on resume", value: $preferences.resumeRewindWords, in: 0...20)
                }
                Text("Warm-up starts at half speed. Long words stay on screen up to 60% longer.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .tint(.readerAmber)
        .frame(width: 290, alignment: .leading)
        .padding(18)
    }
}

private struct OptionSection<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder var content: Content

    init(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            content
        }
    }
}

private struct StepperRow<Control: View>: View {
    let title: LocalizedStringKey
    let value: String
    @ViewBuilder var control: Control

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            control.labelsHidden()
        }
    }
}

private struct ToggleRow: View {
    let title: LocalizedStringKey
    @Binding var isOn: Bool

    init(_ title: LocalizedStringKey, isOn: Binding<Bool>) {
        self.title = title
        _isOn = isOn
    }

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
