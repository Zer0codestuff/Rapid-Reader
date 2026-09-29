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
}
