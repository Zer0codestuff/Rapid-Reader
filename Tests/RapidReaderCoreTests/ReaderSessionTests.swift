import XCTest
@testable import RapidReaderCore

final class ReaderSessionTests: XCTestCase {
    @MainActor
    func testNavigationClampsAndRestartsCompletedDocument() {
        let session = ReaderSession(sections: [
            BookSection(title: "One", text: "Alpha beta"),
            BookSection(title: "Two", text: "Gamma delta epsilon")
        ])
        session.back()
        XCTAssertEqual(session.wordIndex, 0)
        session.forward()
        session.forward()
        XCTAssertEqual(session.sectionIndex, 1)
        session.back()
        XCTAssertEqual(session.sectionIndex, 0)
        XCTAssertEqual(session.wordIndex, 1)
        session.jump(toSection: 1, word: 200)
        session.forward()
        XCTAssertTrue(session.isAtEnd)
        session.play()
        XCTAssertEqual(session.sectionIndex, 0)
        XCTAssertEqual(session.wordIndex, 0)
        session.pause()
    }

    @MainActor
    func testRemainingTimeUpdatesAfterSeekAndSpeedChange() {
        let session = ReaderSession(sections: [BookSection(title: "One", text: "A B C D"), BookSection(title: "Two", text: "E F")], preferences: ReadingPreferences(wordsPerMinute: 600))
        session.setWordIndex(2)
        XCTAssertEqual(session.remainingSectionSeconds, 0.2, accuracy: 0.001)
        XCTAssertEqual(session.remainingBookSeconds, 0.4, accuracy: 0.001)
        session.preferences.wordsPerMinute = 300
        XCTAssertEqual(session.remainingBookSeconds, 0.8, accuracy: 0.001)
    }

    func testTimingUsesDisplayedChunkAndItsPunctuation() {
        let preferences = ReadingPreferences(wordsPerMinute: 600, chunkSize: 4)
        XCTAssertEqual(RSVPTiming.displayDuration(for: ["last."], preferences: preferences), 0.18, accuracy: 0.0001)
        XCTAssertEqual(RSVPTiming.displayDuration(for: ["one", "two"], preferences: preferences), 0.2, accuracy: 0.0001)
    }

    @MainActor
    func testPlaybackKeepsRequestedSpeedAndStopsWhenPaused() async throws {
        let session = ReaderSession(
            sections: [BookSection(title: "Timing", text: Array(repeating: "word", count: 100).joined(separator: " "))],
            preferences: ReadingPreferences(wordsPerMinute: 900, pauseOnPunctuation: false)
        )
        var reportedWord = -1
        session.onProgressChange = { _, word in reportedWord = word }
        let start = ContinuousClock.now
        session.play()
        try await Task.sleep(for: .milliseconds(1020))
        session.pause()
        let elapsed = start.duration(to: .now)
        let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
        XCTAssertEqual(Double(session.wordIndex) * 60 / seconds, 900, accuracy: 100)
        XCTAssertEqual(reportedWord, session.wordIndex)
        let pausedIndex = session.wordIndex
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(session.wordIndex, pausedIndex)
    }

    @MainActor
    func testPlaybackDoesNotRetainAbandonedSession() async throws {
        var session: ReaderSession? = ReaderSession(sections: [BookSection(title: "One", text: "Alpha beta gamma")])
        weak var weakSession = session
        session?.play()
        await Task.yield()
        session = nil
        XCTAssertNil(weakSession)
    }

    @MainActor
    func testTokenCacheOnLongSection() {
        let text = Array(repeating: "A reasonably long chapter with several words.", count: 4000).joined(separator: " ")
        let section = BookSection(title: "Long", text: text)
        let clock = ContinuousClock()
        var start = clock.now
        for _ in 0..<20 { _ = TextProcessor.tokenize(text) }
        let repeated = start.duration(to: clock.now)
        let session = ReaderSession(sections: [section])
        start = clock.now
        for _ in 0..<20 { XCTAssertEqual(session.tokens(forSection: 0).count, section.wordCount) }
        let cached = start.duration(to: clock.now)
        print("Token lookup, 20 iterations, \(section.wordCount) words: repeated=\(repeated), cached=\(cached)")
        XCTAssertLessThan(cached, repeated)
    }

    func testOptionalPacingIsOffByDefaultAndScalesDuration() {
        let base = ReadingPreferences(wordsPerMinute: 600, pauseOnPunctuation: false)
        XCTAssertEqual(RSVPTiming.displayDuration(for: ["extraordinarily"], preferences: base, elapsed: 0), 0.1, accuracy: 0.0001)

        var longWords = base
        longWords.pauseOnLongWords = true
        XCTAssertEqual(RSVPTiming.displayDuration(for: ["short"], preferences: longWords), 0.1, accuracy: 0.0001)
        XCTAssertEqual(RSVPTiming.displayDuration(for: ["extraordinary"], preferences: longWords), 0.125, accuracy: 0.0001)
        XCTAssertEqual(RSVPTiming.displayDuration(for: ["incomprehensibilities"], preferences: longWords), 0.16, accuracy: 0.0001)

        var warmUp = base
        warmUp.rampUpSeconds = 4
        XCTAssertEqual(RSVPTiming.displayDuration(for: ["word"], preferences: warmUp, elapsed: 0), 0.2, accuracy: 0.0001)
        XCTAssertEqual(RSVPTiming.displayDuration(for: ["word"], preferences: warmUp, elapsed: 2), 0.1 / 0.75, accuracy: 0.0001)
        XCTAssertEqual(RSVPTiming.displayDuration(for: ["word"], preferences: warmUp, elapsed: 10), 0.1, accuracy: 0.0001)
    }

    @MainActor
    func testResumeRewindsOnlyAfterPlaybackPause() {
        let text = Array(repeating: "word", count: 50).joined(separator: " ")
        var preferences = ReadingPreferences()
        preferences.resumeRewindWords = 5
        let session = ReaderSession(sections: [BookSection(title: "One", text: text)], wordIndex: 20, preferences: preferences)
        session.play()
        session.pause()
        XCTAssertEqual(session.wordIndex, 20)
        session.play()
        XCTAssertEqual(session.wordIndex, 15)
        session.pause()
        session.setWordIndex(30)
        session.play()
        XCTAssertEqual(session.wordIndex, 30)
        session.pause()
        session.jump(toSection: 0, word: 3)
        session.play()
        XCTAssertEqual(session.wordIndex, 3)
        session.pause()
        session.play()
        XCTAssertEqual(session.wordIndex, 0)
        session.pause()
    }
}
