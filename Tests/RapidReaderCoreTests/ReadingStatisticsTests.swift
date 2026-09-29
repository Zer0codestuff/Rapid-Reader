import XCTest
@testable import RapidReaderCore

final class ReadingStatisticsTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Rome")!
        return calendar
    }()

    private func date(_ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour))!
    }

    func testRecordsPerLocalDayAndSummarizes() {
        var statistics = ReadingStatistics()
        statistics.record(words: 300, seconds: 60, endingAt: date(28), calendar: calendar)
        statistics.record(words: 150, seconds: 30, endingAt: date(29, hour: 0), calendar: calendar)
        statistics.record(words: 100, seconds: 30, endingAt: date(29, hour: 23), calendar: calendar)
        statistics.record(words: 0, seconds: 50, endingAt: date(29), calendar: calendar)
        statistics.record(words: 5, seconds: 0.5, endingAt: date(29), calendar: calendar)

        XCTAssertEqual(statistics.days.map(\.day), ["2026-09-28", "2026-09-29"])
        let today = statistics.summary(lastDays: 1, endingAt: date(29), calendar: calendar)
        XCTAssertEqual(today.words, 250)
        XCTAssertEqual(today.seconds, 60)
        XCTAssertEqual(today.wordsPerMinute, 250)
        XCTAssertEqual(statistics.total.wordsPerMinute, 275)
        XCTAssertNil(ReadingStatistics().total.wordsPerMinute)

        let recent = statistics.recentDays(3, endingAt: date(29), calendar: calendar)
        XCTAssertEqual(recent.map(\.words), [0, 300, 250])
        XCTAssertEqual(recent.first?.date, calendar.startOfDay(for: date(27)))
    }

    @MainActor
    func testStatisticsPersistAndUnreadableFileIsKept() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LibraryStore(rootURL: root)
        store.recordReading(words: 120, seconds: 30)
        XCTAssertEqual(LibraryStore(rootURL: root).statistics.total.words, 120)

        let url = root.appendingPathComponent("statistics.json")
        try Data("not json".utf8).write(to: url)
        let reloaded = LibraryStore(rootURL: root)
        XCTAssertEqual(reloaded.statistics.total.words, 0)
        XCTAssertEqual(reloaded.lastFailures.count, 1)
        let backups = try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("Backups").path)
        XCTAssertTrue(backups.contains { $0.hasPrefix("statistics-unreadable") })
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    @MainActor
    func testSessionReportsWordsShownDuringPlayback() async throws {
        let session = ReaderSession(
            sections: [BookSection(title: "One", text: Array(repeating: "word", count: 100).joined(separator: " "))],
            preferences: ReadingPreferences(wordsPerMinute: 600, pauseOnPunctuation: false)
        )
        var segments: [(Int, TimeInterval)] = []
        session.onReadingSegment = { segments.append(($0, $1)) }
        session.play()
        try await Task.sleep(for: .milliseconds(550))
        session.pause()
        session.pause()
        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments[0].0, session.wordIndex)
        XCTAssertEqual(segments[0].1, 0.55, accuracy: 0.1)
        session.forward()
        XCTAssertEqual(segments.count, 1)
    }
}
