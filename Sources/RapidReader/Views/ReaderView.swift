import RapidReaderCore
import SwiftUI

struct ReaderView: View {
    let item: RapidReaderCore.LibraryItem
    @ObservedObject var library: LibraryStore

    enum ReaderMode: String, CaseIterable, Identifiable {
        case rsvp = "RSVP"
        case text = "Text"

        var id: String { rawValue }
    }

    @State private var sectionIndex: Int
    @State private var wordIndex: Int
    @State private var preferences: ReadingPreferences
    @State private var isPlaying = false
    @State private var nextAdvanceAt = Date()
    @State private var showingNotes = false
    @State private var noteText = ""
    @State private var readerMode: ReaderMode = .rsvp

    private let ticker = Timer.publish(every: 0.04, on: .main, in: .common).autoconnect()

    init(item: RapidReaderCore.LibraryItem, library: LibraryStore) {
        self.item = item
        self.library = library
        _sectionIndex = State(initialValue: item.progress.sectionIndex)
        _wordIndex = State(initialValue: item.progress.wordIndex)
        _preferences = State(initialValue: Self.clampedPreferences(item.preferences))
    }

    private var safeSectionIndex: Int {
        min(max(sectionIndex, 0), max(item.sections.count - 1, 0))
    }

    private var currentSection: BookSection {
        guard item.sections.indices.contains(safeSectionIndex) else {
            return BookSection(title: item.title, text: "")
        }
        return item.sections[safeSectionIndex]
    }

    private var words: [String] {
        TextProcessor.tokenize(currentSection.text)
    }

    private var displayWords: [String] {
        guard !words.isEmpty else { return [] }
        let start = min(max(wordIndex, 0), words.count - 1)
        let end = min(start + max(preferences.chunkSize, 1), words.count)
        return Array(words[start..<end])
    }

    var body: some View {
        VStack(spacing: 0) {
            ReaderHeader(
                item: item,
                section: currentSection,
                sectionIndex: safeSectionIndex,
                totalSections: item.sections.count,
                readerMode: Binding(
                    get: { readerMode },
                    set: { mode in
                        isPlaying = false
                        readerMode = mode
                    }
                ),
                onToggleFavorite: { library.toggleFavorite(item.id) },
                onShowNotes: { showingNotes = true }
            )

            Divider()

            VStack(spacing: 24) {
                if readerMode == .rsvp {
                    Spacer(minLength: 20)

                    RSVPDisplay(words: displayWords, fontSize: preferences.fontSize)
                        .accessibilityIdentifier("rsvp-word-display")

                    if preferences.showContext {
                        ContextStrip(words: words, index: wordIndex)
                            .transition(.opacity)
                    }

                    Spacer(minLength: 18)
                } else {
                    FullTextReaderView(
                        sections: item.sections,
                        currentSectionIndex: safeSectionIndex,
                        currentWordIndex: wordIndex,
                        onSelectWord: chooseWord
                    )
                    .padding(.top, 18)
                    .accessibilityIdentifier("full-text-reader")
                }

                ReaderControls(
                    isPlaying: $isPlaying,
                    sectionIndex: Binding(
                        get: { safeSectionIndex },
                        set: { goToSection($0) }
                    ),
                    wordIndex: Binding(
                        get: { Double(min(max(wordIndex, 0), max(words.count - 1, 0))) },
                        set: { setWordIndex(Int($0.rounded())) }
                    ),
                    preferences: $preferences,
                    sections: item.sections,
                    maxWordIndex: max(words.count - 1, 0),
                    onPlayPause: togglePlayback,
                    onBack: rewind,
                    onForward: advance
                )
            }
            .padding(.horizontal, preferences.focusMode ? 56 : 34)
            .padding(.bottom, 26)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(readerBackground)
        .onReceive(ticker) { now in
            guard isPlaying, now >= nextAdvanceAt else { return }
            let delay = intervalForCurrentWord()
            advance()
            nextAdvanceAt = Date(timeIntervalSinceNow: delay)
        }
        .onChange(of: isPlaying) { _, playing in
            nextAdvanceAt = Date(timeIntervalSinceNow: playing ? intervalForCurrentWord() : 0)
        }
        .onChange(of: preferences) { _, _ in
            savePreferences()
        }
        .sheet(isPresented: $showingNotes) {
            NotesSheet(
                notes: item.notes,
                noteText: $noteText,
                onAdd: {
                    library.addNote(for: item.id, text: noteText)
                    noteText = ""
                }
            )
        }
    }

    private var readerBackground: some View {
        ZStack {
            Color(nsColor: .textBackgroundColor)
            LinearGradient(
                colors: [
                    Color.readerAmber.opacity(0.10),
                    Color.clear,
                    Color.readerMist.opacity(0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func advance() {
        guard !words.isEmpty else {
            isPlaying = false
            return
        }

        let step = max(preferences.chunkSize, 1)
        if wordIndex + step < words.count {
            wordIndex += step
        } else if safeSectionIndex + 1 < item.sections.count {
            sectionIndex = safeSectionIndex + 1
            wordIndex = 0
        } else {
            wordIndex = words.count
            isPlaying = false
        }
        persistProgress()
    }

    private func togglePlayback() {
        if readerMode == .text {
            readerMode = .rsvp
        }
        isPlaying.toggle()
    }

    private func rewind() {
        isPlaying = false
        let step = max(preferences.chunkSize, 1)
        if wordIndex - step >= 0 {
            wordIndex -= step
        } else if safeSectionIndex > 0 {
            sectionIndex = safeSectionIndex - 1
            let previousWords = TextProcessor.tokenize(item.sections[sectionIndex].text)
            wordIndex = max(previousWords.count - 1, 0)
        } else {
            wordIndex = 0
        }
        persistProgress()
    }

    private func goToSection(_ index: Int) {
        isPlaying = false
        sectionIndex = min(max(index, 0), max(item.sections.count - 1, 0))
        wordIndex = 0
        persistProgress()
    }

    private func setWordIndex(_ index: Int) {
        isPlaying = false
        wordIndex = min(max(index, 0), max(words.count - 1, 0))
        persistProgress()
    }

    private func chooseWord(sectionIndex: Int, wordIndex: Int) {
        isPlaying = false
        self.sectionIndex = min(max(sectionIndex, 0), max(item.sections.count - 1, 0))
        let sectionWords = TextProcessor.tokenize(item.sections[self.sectionIndex].text)
        self.wordIndex = min(max(wordIndex, 0), max(sectionWords.count - 1, 0))
        persistProgress()
    }

    private func persistProgress() {
        library.updateProgress(for: item.id, sectionIndex: safeSectionIndex, wordIndex: wordIndex)
    }

    private func savePreferences() {
        let clamped = Self.clampedPreferences(preferences)
        if clamped != preferences {
            preferences = clamped
        }
        library.updatePreferences(for: item.id, clamped)
    }

    private static func clampedPreferences(_ preferences: ReadingPreferences) -> ReadingPreferences {
        ReadingPreferences(
            wordsPerMinute: min(max(preferences.wordsPerMinute, 100), 900),
            fontSize: min(max(preferences.fontSize, 42), 110),
            chunkSize: min(max(preferences.chunkSize, 1), 4),
            showContext: preferences.showContext,
            pauseOnPunctuation: preferences.pauseOnPunctuation,
            focusMode: preferences.focusMode
        )
    }

    private func intervalForCurrentWord() -> TimeInterval {
        let base = 60.0 * Double(max(preferences.chunkSize, 1)) / Double(max(preferences.wordsPerMinute, 1))
        guard preferences.pauseOnPunctuation, let word = displayWords.last else {
            return base
        }
        return base * RSVPWord(word).punctuationDelayMultiplier
    }
}

private struct ReaderHeader: View {
    let item: RapidReaderCore.LibraryItem
    let section: BookSection
    let sectionIndex: Int
    let totalSections: Int
    @Binding var readerMode: ReaderView.ReaderMode
    let onToggleFavorite: () -> Void
    let onShowNotes: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            BookCoverThumbnail(
                imageData: item.coverImageData,
                width: 40,
                height: 56,
                fallbackSystemImage: fallbackSystemImage
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(section.title)
                        .lineLimit(1)
                    Text("\(sectionIndex + 1)/\(max(totalSections, 1))")
                    Text(item.fractionComplete.percentString)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Picker("Mode", selection: $readerMode) {
                ForEach(ReaderView.ReaderMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 124)
            .help("Reader mode")

            Button(action: onToggleFavorite) {
                Image(systemName: item.isFavorite ? "star.fill" : "star")
            }
            .help(item.isFavorite ? "Unfavorite" : "Favorite")

            Button(action: onShowNotes) {
                Label("Notes", systemImage: "note.text")
            }
            .help("Notes")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(.regularMaterial)
    }

    private var fallbackSystemImage: String {
        switch item.format {
        case .epub: "books.vertical"
        case .pdf: "doc.richtext"
        case .docx, .rtf: "doc.text"
        case .html, .webArticle: "safari"
        case .markdown, .plainText, .unknown: "text.alignleft"
        }
    }
}

private struct RSVPDisplay: View {
    let words: [String]
    let fontSize: Double

    var body: some View {
        ZStack {
            alignmentGuides

            if words.count == 1, let word = words.first {
                pivotText(for: word)
                    .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.42)
                    .monospacedDigit()
            } else {
                Text(words.joined(separator: " "))
                    .font(.system(size: max(38, fontSize * 0.72), weight: .semibold, design: .rounded))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: max(140, fontSize * 2.2))
        .padding(.horizontal, 24)
    }

    private var alignmentGuides: some View {
        VStack(spacing: 12) {
            Rectangle()
                .fill(Color.readerAmber.opacity(0.58))
                .frame(width: 2, height: 20)
            Spacer()
            Rectangle()
                .fill(Color.readerAmber.opacity(0.58))
                .frame(width: 2, height: 20)
        }
        .frame(height: max(132, fontSize * 1.8))
    }

    private func pivotText(for word: String) -> Text {
        let split = RSVPWord(word).splitForDisplay
        return Text(split.prefix)
            + Text(split.pivot).foregroundColor(.readerAmber)
            + Text(split.suffix)
    }
}

private struct ContextStrip: View {
    let words: [String]
    let index: Int

    var body: some View {
        HStack(spacing: 10) {
            Text(contextBefore)
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text(current)
                .foregroundStyle(Color.readerAmber)
                .frame(minWidth: 80)
            Text(contextAfter)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(.callout, design: .rounded))
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .padding(.horizontal, 20)
        .frame(height: 28)
    }

    private var contextBefore: String {
        guard !words.isEmpty else { return "" }
        let start = max(0, index - 5)
        let end = min(max(index, 0), words.count)
        return words[start..<end].joined(separator: " ")
    }

    private var current: String {
        guard words.indices.contains(index) else { return "" }
        return words[index]
    }

    private var contextAfter: String {
        guard !words.isEmpty else { return "" }
        let start = min(index + 1, words.count)
        let end = min(start + 5, words.count)
        return words[start..<end].joined(separator: " ")
    }
}

private struct ReaderControls: View {
    @Binding var isPlaying: Bool
    @Binding var sectionIndex: Int
    @Binding var wordIndex: Double
    @Binding var preferences: ReadingPreferences

    let sections: [BookSection]
    let maxWordIndex: Int
    let onPlayPause: () -> Void
    let onBack: () -> Void
    let onForward: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 12) {
                Button(action: onBack) {
                    Image(systemName: "backward.fill")
                }
                .keyboardShortcut(.leftArrow, modifiers: [])
                .help("Back")

                Button(action: onPlayPause) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .frame(width: 20)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.space, modifiers: [])
                .help(isPlaying ? "Pause" : "Play")

                Button(action: onForward) {
                    Image(systemName: "forward.fill")
                }
                .keyboardShortcut(.rightArrow, modifiers: [])
                .help("Forward")

                Divider()
                    .frame(height: 26)

                Picker("Section", selection: $sectionIndex) {
                    ForEach(sections.indices, id: \.self) { index in
                        Text(sections[index].title).tag(index)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 260)
                .help("Section")
            }

            VStack(spacing: 12) {
                Slider(value: progressBinding, in: progressRange, step: 1)
                    .accessibilityIdentifier("progress-slider")
                    .disabled(maxWordIndex <= 0)

                HStack(spacing: 18) {
                    ControlCluster(title: "Speed") {
                        Stepper("\(preferences.wordsPerMinute) WPM", value: $preferences.wordsPerMinute, in: 100...900, step: 25)
                            .frame(width: 132)
                    }

                    ControlCluster(title: "Size") {
                        Slider(value: $preferences.fontSize, in: 42...110, step: 2)
                            .frame(width: 132)
                    }

                    ControlCluster(title: "Words") {
                        Picker("", selection: $preferences.chunkSize) {
                            ForEach(1...4, id: \.self) { value in
                                Text("\(value)").tag(value)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 128)
                    }

                    ControlCluster(title: "Mode") {
                        HStack(spacing: 12) {
                            Toggle("Context", isOn: $preferences.showContext)
                                .help("Context")
                            Toggle("Pauses", isOn: $preferences.pauseOnPunctuation)
                                .help("Punctuation pauses")
                            Toggle("Focus", isOn: $preferences.focusMode)
                                .help("Focus")
                        }
                        .fixedSize()
                    }
                }
                .font(.callout)
            }
        }
        .padding(18)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var progressRange: ClosedRange<Double> {
        0...Double(max(maxWordIndex, 1))
    }

    private var progressBinding: Binding<Double> {
        Binding(
            get: {
                min(max(wordIndex, 0), Double(max(maxWordIndex, 0)))
            },
            set: { newValue in
                wordIndex = min(max(newValue, 0), Double(max(maxWordIndex, 0)))
            }
        )
    }
}

private struct ControlCluster<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            content
                .frame(height: 24, alignment: .leading)
        }
        .fixedSize(horizontal: true, vertical: true)
    }
}

private struct NotesSheet: View {
    let notes: [ReaderNote]
    @Binding var noteText: String
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Notes")
                .font(.title3.weight(.semibold))

            TextEditor(text: $noteText)
                .frame(width: 460, height: 96)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.22))
                )

            HStack {
                Spacer()
                Button("Add Note", action: onAdd)
                    .buttonStyle(.borderedProminent)
                    .disabled(noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Divider()

            List(notes) { note in
                VStack(alignment: .leading, spacing: 4) {
                    Text(note.text)
                        .lineLimit(3)
                    Text("Section \(note.sectionIndex + 1), word \(note.wordIndex + 1)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            .frame(width: 460, height: 240)
        }
        .padding(24)
    }
}
