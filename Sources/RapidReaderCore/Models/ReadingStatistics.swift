import Foundation

/// Reading time and words shown during RSVP playback, per local calendar day.
public struct ReadingStatistics: Codable, Equatable, Sendable {
    public struct Day: Codable, Equatable, Sendable {
        /// Local calendar day, `yyyy-MM-dd`.
        public var day: String
        public var seconds: Double
        public var words: Int

        public init(day: String, seconds: Double, words: Int) {
            self.day = day
            self.seconds = seconds
            self.words = words
        }
    }

    public struct Summary: Equatable, Sendable {
        public var seconds: Double
        public var words: Int

        /// Words per minute over the period, including punctuation pauses; `nil` without data.
        public var wordsPerMinute: Int? {
            seconds >= 1 ? Int((Double(words) * 60 / seconds).rounded()) : nil
        }
    }

    public private(set) var days: [Day]

    public init(days: [Day] = []) {
        self.days = days.sorted { $0.day < $1.day }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(days: try container.decodeIfPresent([Day].self, forKey: .days) ?? [])
    }

    /// Adds a playback segment to the day it ended on. Segments under a second or without words are ignored.
    public mutating func record(words: Int, seconds: TimeInterval, endingAt date: Date = Date(), calendar: Calendar = .current) {
        guard words > 0, seconds.isFinite, seconds >= 1 else { return }
        let key = Self.key(for: date, calendar: calendar)
        if let index = days.firstIndex(where: { $0.day == key }) {
            days[index].seconds += seconds
            days[index].words += words
        } else {
            days.append(Day(day: key, seconds: seconds, words: words))
            days.sort { $0.day < $1.day }
        }
    }

    public var total: Summary {
        Summary(seconds: days.reduce(0) { $0 + $1.seconds }, words: days.reduce(0) { $0 + $1.words })
    }

    /// Totals for the `count` days ending on `date`, including it.
    public func summary(lastDays count: Int, endingAt date: Date = Date(), calendar: Calendar = .current) -> Summary {
        recentDays(count, endingAt: date, calendar: calendar).reduce(Summary(seconds: 0, words: 0)) {
            Summary(seconds: $0.seconds + $1.seconds, words: $0.words + $1.words)
        }
    }

    /// One entry per day for the `count` days ending on `date`, oldest first, with empty days filled in.
    public func recentDays(_ count: Int, endingAt date: Date = Date(), calendar: Calendar = .current) -> [(date: Date, seconds: Double, words: Int)] {
        let today = calendar.startOfDay(for: date)
        return (0..<max(count, 0)).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let entry = days.first { $0.day == Self.key(for: day, calendar: calendar) }
            return (day, entry?.seconds ?? 0, entry?.words ?? 0)
        }
    }

    static func key(for date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
