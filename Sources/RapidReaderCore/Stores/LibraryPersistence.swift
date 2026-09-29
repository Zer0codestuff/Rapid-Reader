import Foundation

/// On-disk layout of the library.
///
/// - `library.json` is a small index with metadata, progress, preferences and notes.
///   It is rewritten often, so it never contains document text or cover art.
/// - `Documents/<id>.json` holds the sections of one document and is written once.
/// - `Documents/<id>.cover` holds the raw cover image bytes.
/// - `statistics.json` holds reading time and words per day.
///
/// Version 1 libraries stored everything inside a single `library.json` array and are
/// migrated transparently by `LibraryStore`.
struct LibraryPersistence {
    static let currentSchemaVersion = 2

    let rootURL: URL
    let fileManager: FileManager

    var indexURL: URL { rootURL.appendingPathComponent("library.json") }
    var documentsURL: URL { rootURL.appendingPathComponent("Documents", isDirectory: true) }
    var backupsURL: URL { rootURL.appendingPathComponent("Backups", isDirectory: true) }
    var statisticsURL: URL { rootURL.appendingPathComponent("statistics.json") }

    enum LoadedIndex {
        case missing
        case legacy([LossyLibraryItem])
        case current([LossyLibraryItem])
    }

    func createDirectories() throws {
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: documentsURL, withIntermediateDirectories: true)
    }

    func readIndex() throws -> LoadedIndex {
        guard fileManager.fileExists(atPath: indexURL.path) else {
            return .missing
        }
        let data = try Data(contentsOf: indexURL)
        if let index = try? JSONDecoder.readerDecoder.decode(LibraryIndex.self, from: data) {
            return .current(index.items)
        }
        return .legacy(try JSONDecoder.readerDecoder.decode([LossyLibraryItem].self, from: data))
    }

    func writeIndex(_ items: [LibraryItem]) throws {
        let entries = items.map { item -> LibraryItem in
            var entry = item
            entry.sections = []
            entry.coverImageData = nil
            return entry
        }
        let data = try JSONEncoder.readerEncoder.encode(
            LibraryIndexOutput(schemaVersion: Self.currentSchemaVersion, items: entries)
        )
        try data.write(to: indexURL, options: [.atomic])
    }

    func writeContent(of item: LibraryItem) throws {
        try fileManager.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        let data = try JSONEncoder.compactReaderEncoder.encode(StoredDocumentContent(sections: item.sections))
        try data.write(to: contentURL(for: item.id), options: [.atomic])

        let coverURL = coverURL(for: item.id)
        if let cover = item.coverImageData {
            try cover.write(to: coverURL, options: [.atomic])
        } else if fileManager.fileExists(atPath: coverURL.path) {
            try fileManager.removeItem(at: coverURL)
        }
    }

    /// Returns `nil` when the content file is missing or unreadable.
    func readContent(for id: UUID) -> (sections: [BookSection], cover: Data?)? {
        guard
            let data = try? Data(contentsOf: contentURL(for: id)),
            let content = try? JSONDecoder.readerDecoder.decode(StoredDocumentContent.self, from: data)
        else {
            return nil
        }
        return (content.sections, try? Data(contentsOf: coverURL(for: id)))
    }

    /// Returns empty statistics when the file does not exist yet.
    func readStatistics() throws -> ReadingStatistics {
        guard fileManager.fileExists(atPath: statisticsURL.path) else { return ReadingStatistics() }
        return try JSONDecoder.readerDecoder.decode(ReadingStatistics.self, from: Data(contentsOf: statisticsURL))
    }

    func writeStatistics(_ statistics: ReadingStatistics) throws {
        try JSONEncoder.readerEncoder.encode(statistics).write(to: statisticsURL, options: [.atomic])
    }

    func deleteContent(for id: UUID) {
        try? fileManager.removeItem(at: contentURL(for: id))
        try? fileManager.removeItem(at: coverURL(for: id))
    }

    @discardableResult
    func backupIndex(named name: String, move: Bool, timestamped: Bool = true, source: URL? = nil) -> URL? {
        let source = source ?? indexURL
        do {
            try fileManager.createDirectory(at: backupsURL, withIntermediateDirectories: true)
            let suffix = timestamped ? "-" + Self.backupTimestamp() : ""
            let destination = backupsURL.appendingPathComponent("\(name)\(suffix).json")
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            if move {
                try fileManager.moveItem(at: source, to: destination)
            } else {
                try fileManager.copyItem(at: source, to: destination)
            }
            return destination
        } catch {
            return nil
        }
    }

    private func contentURL(for id: UUID) -> URL {
        documentsURL.appendingPathComponent("\(id.uuidString).json")
    }

    private func coverURL(for id: UUID) -> URL {
        documentsURL.appendingPathComponent("\(id.uuidString).cover")
    }

    private static func backupTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}

struct LossyLibraryItem: Decodable {
    let item: LibraryItem?

    init(from decoder: Decoder) throws {
        item = try? LibraryItem(from: decoder)
    }
}

private struct LibraryIndex: Decodable {
    var schemaVersion: Int
    var items: [LossyLibraryItem]
}

private struct LibraryIndexOutput: Encodable {
    var schemaVersion: Int
    var items: [LibraryItem]
}

private struct StoredDocumentContent: Codable {
    var sections: [BookSection]
}

extension JSONEncoder {
    static var readerEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    static var compactReaderEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var readerDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
