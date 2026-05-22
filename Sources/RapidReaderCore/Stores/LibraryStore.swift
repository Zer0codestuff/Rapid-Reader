import Combine
import Foundation

public struct ImportFailure: Identifiable, Equatable, Sendable {
    public var id = UUID()
    public var sourceName: String
    public var message: String
}

@MainActor
public final class LibraryStore: ObservableObject {
    @Published public private(set) var items: [LibraryItem] = []
    @Published public var selectedID: UUID?
    @Published public private(set) var lastFailures: [ImportFailure] = []

    public let rootURL: URL
    private let libraryURL: URL
    private let importer: DocumentImportService
    private let fileManager: FileManager
    private var defaultPreferences: ReadingPreferences

    public init(
        rootURL: URL = LibraryStore.defaultRootURL(),
        importer: DocumentImportService = DocumentImportService(),
        fileManager: FileManager = .default,
        defaultPreferences: ReadingPreferences = ReadingPreferences()
    ) {
        self.rootURL = rootURL
        self.libraryURL = rootURL.appendingPathComponent("library.json")
        self.importer = importer
        self.fileManager = fileManager
        self.defaultPreferences = defaultPreferences
        load()
    }

    public static func defaultRootURL() -> URL {
        if let overridePath = ProcessInfo.processInfo.environment["RAPID_READER_LIBRARY_DIR"],
           !overridePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let expandedPath = (overridePath as NSString).expandingTildeInPath
            return URL(fileURLWithPath: expandedPath, isDirectory: true)
        }

        return FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("Rapid Reader", isDirectory: true)
    }

    public var selectedItem: LibraryItem? {
        guard let selectedID else { return nil }
        return items.first { $0.id == selectedID }
    }

    public func load() {
        do {
            try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
            guard fileManager.fileExists(atPath: libraryURL.path) else {
                items = []
                return
            }
            let data = try Data(contentsOf: libraryURL)
            let decodedItems = try JSONDecoder.readerDecoder.decode([LibraryItem].self, from: data)
            let repairedItems = decodedItems.map(repairedItem)
            items = repairedItems
            selectedID = items.sortedForLibrary.first?.id
            if repairedItems != decodedItems {
                save()
            }
        } catch {
            items = []
            lastFailures = [ImportFailure(sourceName: "Library", message: error.localizedDescription)]
        }
    }

    public func importFiles(_ urls: [URL]) async {
        var importedItems: [LibraryItem] = []
        var failures: [ImportFailure] = []

        for url in urls {
            do {
                let document = try await importer.importFile(at: url)
                importedItems.append(item(from: document))
            } catch {
                failures.append(ImportFailure(sourceName: url.lastPathComponent, message: error.localizedDescription))
            }
        }

        if !importedItems.isEmpty {
            items.insert(contentsOf: importedItems, at: 0)
            selectedID = importedItems.first?.id
            save()
        }
        lastFailures = failures
    }

    public func setDefaultPreferences(_ preferences: ReadingPreferences) {
        defaultPreferences = preferences
    }

    public func importArticle(from url: URL) async {
        do {
            let document = try await importer.importArticle(from: url)
            let newItem = item(from: document)
            items.insert(newItem, at: 0)
            selectedID = newItem.id
            lastFailures = []
            save()
        } catch {
            lastFailures = [ImportFailure(sourceName: url.absoluteString, message: error.localizedDescription)]
        }
    }

    public func importClipboardText(_ text: String) {
        do {
            let document = try importer.importClipboardText(text)
            let newItem = item(from: document)
            items.insert(newItem, at: 0)
            selectedID = newItem.id
            lastFailures = []
            save()
        } catch {
            lastFailures = [ImportFailure(sourceName: "Clipboard", message: error.localizedDescription)]
        }
    }

    public func updateProgress(for id: UUID, sectionIndex: Int, wordIndex: Int) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let sectionIndex = min(max(sectionIndex, 0), max(items[index].sections.count - 1, 0))
        let maxWords = items[index].sections.indices.contains(sectionIndex) ? items[index].sections[sectionIndex].wordCount : 0
        items[index].progress.sectionIndex = sectionIndex
        items[index].progress.wordIndex = min(max(wordIndex, 0), maxWords)
        items[index].progress.completedAt = items[index].fractionComplete >= 0.999 ? Date() : nil
        items[index].lastReadAt = Date()
        save()
    }

    public func updatePreferences(for id: UUID, _ preferences: ReadingPreferences) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].preferences = preferences
        save()
    }

    public func toggleFavorite(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isFavorite.toggle()
        save()
    }

    public func addNote(for id: UUID, text: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let progress = items[index].progress
        items[index].notes.insert(
            ReaderNote(sectionIndex: progress.sectionIndex, wordIndex: progress.wordIndex, text: trimmed),
            at: 0
        )
        save()
    }

    public func deleteItems(at offsets: IndexSet, from visibleItems: [LibraryItem]) {
        let ids = offsets.map { visibleItems[$0].id }
        items.removeAll { ids.contains($0.id) }
        if let selectedID, ids.contains(selectedID) {
            self.selectedID = items.sortedForLibrary.first?.id
        }
        save()
    }

    public func select(_ id: UUID?) {
        selectedID = id
    }

    public func clearFailures() {
        lastFailures = []
    }

    public func recordFailure(sourceName: String, message: String) {
        lastFailures = [ImportFailure(sourceName: sourceName, message: message)]
    }

    private func item(from document: ImportedDocument) -> LibraryItem {
        LibraryItem(
            title: document.title,
            author: document.author,
            sourceName: document.sourceName,
            sourceURL: document.sourceURL,
            format: document.format,
            sections: document.sections.isEmpty ? [BookSection(title: document.title, text: "")] : document.sections,
            preferences: defaultPreferences,
            coverImageData: document.coverImageData
        )
    }

    private func repairedItem(_ item: LibraryItem) -> LibraryItem {
        var repaired = item
        repaired.preferences = repairedPreferences(item.preferences)
        repaired.sections = item.sections.compactMap { section in
            let title = TextProcessor.cleanedTitle(section.title, fallback: item.title)
            let repairedSection = BookSection(
                id: section.id,
                title: title,
                text: TextProcessor.normalizedText(section.text)
            )
            return repairedSection.wordCount > 0 ? repairedSection : nil
        }

        if repaired.sections.isEmpty {
            repaired.sections = [BookSection(title: item.title, text: "")]
        }

        repaired.progress = repairedProgress(item.progress, sections: repaired.sections)
        return repaired
    }

    private func repairedProgress(_ progress: ReadingProgress, sections: [BookSection]) -> ReadingProgress {
        let sectionIndex = min(max(progress.sectionIndex, 0), max(sections.count - 1, 0))
        let maxWords = sections.indices.contains(sectionIndex) ? max(sections[sectionIndex].wordCount - 1, 0) : 0
        return ReadingProgress(
            sectionIndex: sectionIndex,
            wordIndex: min(max(progress.wordIndex, 0), maxWords),
            completedAt: progress.completedAt
        )
    }

    private func repairedPreferences(_ preferences: ReadingPreferences) -> ReadingPreferences {
        ReadingPreferences(
            wordsPerMinute: min(max(preferences.wordsPerMinute, 100), 900),
            fontSize: min(max(preferences.fontSize, 42), 110),
            chunkSize: min(max(preferences.chunkSize, 1), 4),
            showContext: preferences.showContext,
            pauseOnPunctuation: preferences.pauseOnPunctuation,
            focusMode: preferences.focusMode
        )
    }

    private func save() {
        do {
            try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
            let data = try JSONEncoder.readerEncoder.encode(items)
            try data.write(to: libraryURL, options: [.atomic])
        } catch {
            lastFailures = [ImportFailure(sourceName: "Library", message: error.localizedDescription)]
        }
    }
}

public extension Array where Element == LibraryItem {
    var sortedForLibrary: [LibraryItem] {
        sorted {
            let left = $0.lastReadAt ?? $0.importedAt
            let right = $1.lastReadAt ?? $1.importedAt
            return left > right
        }
    }
}

private extension JSONEncoder {
    static var readerEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var readerDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
