import Combine
import Foundation

/// Reading state and RSVP playback for one document.
///
/// Tokens are computed once per section and cached, and playback waits on absolute
/// deadlines so rounding errors never accumulate into a slower real speed.
@MainActor
public final class ReaderSession: ObservableObject {
    public let sections: [BookSection]

    @Published public private(set) var sectionIndex: Int
    @Published public private(set) var wordIndex: Int
    @Published public private(set) var isPlaying = false
    @Published public var preferences: ReadingPreferences {
        didSet {
            let clamped = preferences.clamped()
            if clamped != preferences {
                preferences = clamped
            }
        }
    }

    /// Words of the current section.
    public private(set) var words: [String] = []

    /// Called with `(sectionIndex, wordIndex)` whenever progress should be persisted.
    public var onProgressChange: ((Int, Int) -> Void)?

    /// Called with `(words, seconds)` for each playback run when it stops.
    /// Words count once their display time has fully elapsed.
    public var onReadingSegment: ((Int, TimeInterval) -> Void)?

    private var playbackStartedAt: ContinuousClock.Instant?
    private var shouldRewindOnResume = false
    private var segmentWords = 0
    private var tokenCache: [Int: [String]] = [:]
    private var playbackTask: Task<Void, Never>?
    private var lastProgressReport = ContinuousClock.now
    private let progressReportInterval: Duration
    private let clock = ContinuousClock()

    public init(
        sections: [BookSection],
        sectionIndex: Int = 0,
        wordIndex: Int = 0,
        preferences: ReadingPreferences = ReadingPreferences(),
        progressReportInterval: Duration = .seconds(1)
    ) {
        self.sections = sections
        self.preferences = preferences.clamped()
        self.progressReportInterval = progressReportInterval
        self.sectionIndex = min(max(sectionIndex, 0), max(sections.count - 1, 0))
        self.wordIndex = 0
        self.words = tokens(forSection: self.sectionIndex)
        self.wordIndex = min(max(wordIndex, 0), words.count)
    }

    deinit {
        playbackTask?.cancel()
    }

    public var currentSection: BookSection? {
        sections.indices.contains(sectionIndex) ? sections[sectionIndex] : nil
    }

    public var maxWordIndex: Int {
        max(words.count - 1, 0)
    }

    /// Index of the displayed word, clamped to the section.
    public var displayIndex: Int {
        min(max(wordIndex, 0), maxWordIndex)
    }

    public var displayWords: [String] {
        guard !words.isEmpty else { return [] }
        let start = displayIndex
        let end = min(start + preferences.chunkSize, words.count)
        return Array(words[start..<end])
    }

    public var remainingSectionSeconds: TimeInterval {
        Double(max(0, words.count - wordIndex)) * 60 / Double(preferences.wordsPerMinute)
    }

    public var remainingBookSeconds: TimeInterval {
        let laterWords = sections.dropFirst(sectionIndex + 1).reduce(0) { $0 + $1.wordCount }
        return remainingSectionSeconds + Double(laterWords) * 60 / Double(preferences.wordsPerMinute)
    }

    public var isAtEnd: Bool {
        sectionIndex >= sections.count - 1 && wordIndex >= words.count
    }

    public func tokens(forSection index: Int) -> [String] {
        if let cached = tokenCache[index] {
            return cached
        }
        guard sections.indices.contains(index) else { return [] }
        let tokens = TextProcessor.tokenize(sections[index].text)
        tokenCache[index] = tokens
        return tokens
    }

    // MARK: Playback

    public func togglePlayback() {
        isPlaying ? pause() : play()
    }

    public func play() {
        guard !isPlaying else { return }
        if isAtEnd {
            jump(toSection: 0, word: 0)
        } else if shouldRewindOnResume {
            wordIndex = max(0, wordIndex - preferences.resumeRewindWords)
        }
        shouldRewindOnResume = false
        while words.isEmpty, sectionIndex + 1 < sections.count {
            moveToSection(sectionIndex + 1)
            wordIndex = 0
        }
        guard !words.isEmpty else { return }
        playbackStartedAt = clock.now
        segmentWords = 0
        isPlaying = true
        playbackTask?.cancel()
        let clock = self.clock
        playbackTask = Task { [weak self] in
            var deadline = clock.now
            while !Task.isCancelled {
                guard let duration = self?.currentDisplayDuration(), self?.isPlaying == true else { return }
                deadline = deadline.advanced(by: .seconds(duration))
                if clock.now - deadline > .seconds(1) {
                    deadline = clock.now.advanced(by: .seconds(duration))
                }
                do {
                    try await clock.sleep(until: deadline, tolerance: .milliseconds(2))
                } catch { return }
                guard !Task.isCancelled, let self, self.isPlaying else { return }
                self.segmentWords += self.displayWords.count
                if !self.step(forward: true) { self.pause() }
            }
        }
    }

    public func pause() {
        if isPlaying {
            shouldRewindOnResume = true
            if let start = playbackStartedAt {
                onReadingSegment?(segmentWords, start.duration(to: clock.now).secondsValue)
            }
            segmentWords = 0
        }
        isPlaying = false
        playbackTask?.cancel()
        playbackTask = nil
        reportProgress(force: true)
    }

    /// How long the currently displayed chunk stays on screen.
    public func currentDisplayDuration() -> TimeInterval {
        let elapsed = playbackStartedAt.map { $0.duration(to: clock.now).secondsValue } ?? 0
        return RSVPTiming.displayDuration(for: displayWords, preferences: preferences, elapsed: elapsed)
    }

    // MARK: Navigation

    public func forward() {
        pause()
        shouldRewindOnResume = false
        step(forward: true)
        reportProgress(force: true)
    }

    public func back() {
        pause()
        shouldRewindOnResume = false
        step(forward: false)
        reportProgress(force: true)
    }

    public func goToSection(_ index: Int) {
        pause()
        jump(toSection: index, word: 0)
    }

    public func setWordIndex(_ index: Int) {
        pause()
        shouldRewindOnResume = false
        wordIndex = min(max(index, 0), maxWordIndex)
        reportProgress(force: true)
    }

    public func jump(toSection section: Int, word: Int) {
        pause()
        shouldRewindOnResume = false
        moveToSection(section)
        wordIndex = min(max(word, 0), maxWordIndex)
        reportProgress(force: true)
    }

    /// Moves one chunk forward or backward. Returns `false` when the end of the document was reached.
    @discardableResult
    private func step(forward: Bool) -> Bool {
        let step = preferences.chunkSize
        if forward {
            if wordIndex + step < words.count {
                wordIndex += step
            } else if sectionIndex + 1 < sections.count {
                moveToSection(sectionIndex + 1)
                wordIndex = 0
            } else {
                wordIndex = words.count
                reportProgress(force: true)
                return false
            }
        } else {
            if wordIndex - step >= 0 {
                wordIndex = min(wordIndex - step, maxWordIndex)
            } else if sectionIndex > 0 {
                moveToSection(sectionIndex - 1)
                wordIndex = maxWordIndex
            } else {
                wordIndex = 0
            }
        }
        reportProgress(force: false)
        return true
    }

    private func moveToSection(_ index: Int) {
        let clamped = min(max(index, 0), max(sections.count - 1, 0))
        if clamped != sectionIndex || words.isEmpty {
            sectionIndex = clamped
            words = tokens(forSection: clamped)
        }
    }

    private func reportProgress(force: Bool) {
        let now = clock.now
        guard force || now - lastProgressReport >= progressReportInterval else { return }
        lastProgressReport = now
        onProgressChange?(sectionIndex, wordIndex)
    }
}

public enum RSVPTiming {
    /// Seconds a chunk of words stays on screen at the given preferences.
    public static func displayDuration(for words: [String], preferences: ReadingPreferences, elapsed: TimeInterval = .infinity) -> TimeInterval {
        let preferences = preferences.clamped()
        let chunk = max(words.count, 1)
        var duration = 60.0 * Double(chunk) / Double(preferences.wordsPerMinute)
        if preferences.pauseOnPunctuation, let last = words.last {
            duration *= RSVPWord(last).punctuationDelayMultiplier
        }
        if preferences.pauseOnLongWords {
            let length = words.map { $0.count }.max() ?? 0
            duration *= 1 + min(0.6, Double(max(0, length - 8)) * 0.05)
        }
        if preferences.rampUpSeconds > 0 {
            let fraction = min(1, max(0, elapsed / preferences.rampUpSeconds))
            duration /= 0.5 + 0.5 * fraction
        }
        return duration
    }
}

extension Duration {
    var secondsValue: Double {
        Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
