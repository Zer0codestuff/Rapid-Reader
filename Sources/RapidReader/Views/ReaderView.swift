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

    @StateObject private var session: ReaderSession
    @State private var showingNotes = false
    @State private var noteText = ""
    @State private var readerMode: ReaderMode = .rsvp

    init(item: RapidReaderCore.LibraryItem, library: LibraryStore) {
        self.item = item
        self.library = library
        _session = StateObject(wrappedValue: ReaderSession(
            sections: item.sections,
            sectionIndex: item.progress.sectionIndex,
            wordIndex: item.progress.wordIndex,
            preferences: item.preferences
        ))
    }

    private var currentSection: BookSection {
        session.currentSection ?? BookSection(title: item.title, text: "")
    }

    var body: some View {
        VStack(spacing: 0) {
            ReaderHeader(
                item: item,
                section: currentSection,
                sectionIndex: session.sectionIndex,
                totalSections: item.sections.count,
                readerMode: Binding(
                    get: { readerMode },
                    set: { mode in
                        session.pause()
                        readerMode = mode
                    }
                ),
                onToggleFavorite: { library.toggleFavorite(item.id) },
                onShowNotes: { session.pause(); showingNotes = true }
            )

            Divider()

            VStack(spacing: 24) {
                if readerMode == .rsvp {
                    Spacer(minLength: 20)

                    RSVPDisplay(words: session.displayWords, fontSize: session.preferences.fontSize)
                        .accessibilityIdentifier("rsvp-word-display")

                    if session.preferences.showContext {
                        ContextStrip(words: session.words, index: session.displayIndex)
                            .transition(.opacity)
                    }

                    Spacer(minLength: 18)
                } else {
                    FullTextReaderView(
                        sections: item.sections,
                        currentSectionIndex: session.sectionIndex,
                        currentWordIndex: session.wordIndex,
                        onSelectWord: chooseWord
                    )
                    .padding(.top, 18)
                    .accessibilityIdentifier("full-text-reader")
                }

                ReaderControls(
                    isPlaying: session.isPlaying,
                    sectionIndex: Binding(
                        get: { session.sectionIndex },
                        set: { session.goToSection($0) }
                    ),
                    wordIndex: Binding(
                        get: { Double(session.displayIndex) },
                        set: { session.setWordIndex(Int($0.rounded())) }
                    ),
                    preferences: $session.preferences,
                    sections: item.sections,
                    maxWordIndex: session.maxWordIndex,
                    onPlayPause: togglePlayback,
                    onBack: session.back,
                    onForward: session.forward
                )
            }
            .padding(.horizontal, session.preferences.focusMode ? 56 : 34)
            .padding(.bottom, 26)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(readerBackground)
        .background(ReaderKeyboardHandler(onPlayPause: togglePlayback, onBack: session.back, onForward: session.forward))
        .onAppear {
            session.onProgressChange = { section, word in
                library.updateProgress(for: item.id, sectionIndex: section, wordIndex: word)
            }
        }
        .onDisappear {
            session.pause()
            library.flushPendingChanges()
        }
        .onChange(of: session.isPlaying) { _, playing in
            if !playing { library.flushPendingChanges() }
        }
        .onChange(of: session.preferences) { _, preferences in
            library.updatePreferences(for: item.id, preferences)
        }
        .sheet(isPresented: $showingNotes) {
            NotesSheet(
                notes: item.notes,
                noteText: $noteText,
                onAdd: {
                    library.addNote(for: item.id, text: noteText)
                    noteText = ""
                },
                onUpdate: { library.updateNote(for: item.id, noteID: $0, text: $1) },
                onDelete: { library.deleteNote(for: item.id, noteID: $0) },
                onJump: { note in
                    session.jump(toSection: note.sectionIndex, word: note.wordIndex)
                    showingNotes = false
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

    private func togglePlayback() {
        readerMode = .rsvp
        session.togglePlayback()
    }

    private func chooseWord(sectionIndex: Int, wordIndex: Int) {
        session.jump(toSection: sectionIndex, word: wordIndex)
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
            .accessibilityLabel(item.isFavorite ? "Unfavorite" : "Favorite")

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
    let isPlaying: Bool
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
                .help("Back")
                .accessibilityLabel("Back")

                Button(action: onPlayPause) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .frame(width: 20)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .help(isPlaying ? "Pause" : "Play")
                .accessibilityLabel(isPlaying ? "Pause" : "Play")

                Button(action: onForward) {
                    Image(systemName: "forward.fill")
                }
                .help("Forward")
                .accessibilityLabel("Forward")

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

