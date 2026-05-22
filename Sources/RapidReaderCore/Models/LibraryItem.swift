import Foundation

public struct LibraryItem: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var author: String?
    public var sourceName: String
    public var sourceURL: String?
    public var format: ReadingFormat
    public var importedAt: Date
    public var lastReadAt: Date?
    public var sections: [BookSection]
    public var progress: ReadingProgress
    public var preferences: ReadingPreferences
    public var isFavorite: Bool
    public var notes: [ReaderNote]
    public var coverImageData: Data?

    public init(
        id: UUID = UUID(),
        title: String,
        author: String? = nil,
        sourceName: String,
        sourceURL: String? = nil,
        format: ReadingFormat,
        importedAt: Date = Date(),
        lastReadAt: Date? = nil,
        sections: [BookSection],
        progress: ReadingProgress = ReadingProgress(),
        preferences: ReadingPreferences = ReadingPreferences(),
        isFavorite: Bool = false,
        notes: [ReaderNote] = [],
        coverImageData: Data? = nil
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.sourceName = sourceName
        self.sourceURL = sourceURL
        self.format = format
        self.importedAt = importedAt
        self.lastReadAt = lastReadAt
        self.sections = sections
        self.progress = progress
        self.preferences = preferences
        self.isFavorite = isFavorite
        self.notes = notes
        self.coverImageData = coverImageData
    }

    public var totalWordCount: Int {
        sections.reduce(0) { $0 + $1.wordCount }
    }

    public var completedWordCount: Int {
        let safeSection = min(max(progress.sectionIndex, 0), max(sections.count - 1, 0))
        let previous = sections.prefix(safeSection).reduce(0) { $0 + $1.wordCount }
        let current = sections.indices.contains(safeSection) ? min(progress.wordIndex, sections[safeSection].wordCount) : 0
        return previous + current
    }

    public var fractionComplete: Double {
        guard totalWordCount > 0 else { return 0 }
        return min(1, max(0, Double(completedWordCount) / Double(totalWordCount)))
    }

    public var currentSection: BookSection? {
        guard sections.indices.contains(progress.sectionIndex) else { return sections.first }
        return sections[progress.sectionIndex]
    }
}

public struct ReaderNote: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var sectionIndex: Int
    public var wordIndex: Int
    public var text: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        sectionIndex: Int,
        wordIndex: Int,
        text: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sectionIndex = sectionIndex
        self.wordIndex = wordIndex
        self.text = text
        self.createdAt = createdAt
    }
}
