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
    @Published public private(set) var statistics = ReadingStatistics()

    public let rootURL: URL
    private let persistence: LibraryPersistence
    private let importer: DocumentImportService
    private let fileManager: FileManager
    private var defaultPreferences: ReadingPreferences
    private var isPersistenceBlocked = false
    private var isStatisticsBlocked = false
    private var pendingSave: Task<Void, Never>?
    private let saveDelay: Duration

    public init(
        rootURL: URL = LibraryStore.defaultRootURL(),
        importer: DocumentImportService = DocumentImportService(),
        fileManager: FileManager = .default,
        defaultPreferences: ReadingPreferences = ReadingPreferences(),
        saveDelay: Duration = .seconds(2)
    ) {
        self.rootURL = rootURL
        self.persistence = LibraryPersistence(rootURL: rootURL, fileManager: fileManager)
        self.importer = importer
        self.fileManager = fileManager
        self.defaultPreferences = defaultPreferences
        self.saveDelay = saveDelay
        load()
        loadStatistics()
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

    public var backupsURL: URL {
        persistence.backupsURL
    }

    public func load() {
        items = []
        pendingSave?.cancel()
        pendingSave = nil

        do {
            try persistence.createDirectories()
        } catch {
            blockPersistence(message: error.localizedDescription)
            return
        }

        let loaded: LibraryPersistence.LoadedIndex
        do {
            loaded = try persistence.readIndex()
        } catch {
            // Never overwrite a library we could not read: move it aside first.
            if let backup = persistence.backupIndex(named: "library-unreadable", move: true) {
                lastFailures = [ImportFailure(
                    sourceName: "Library",
                    message: "The library could not be read (\(error.localizedDescription)). The original file was kept at \(backup.path)."
                )]
            } else {
                blockPersistence(message: error.localizedDescription)
            }
            return
        }

        let decoded: [LossyLibraryItem]
        let isLegacy: Bool
        switch loaded {
        case .missing:
            return
        case .legacy(let entries):
            decoded = entries
            isLegacy = true
        case .current(let entries):
            decoded = entries
            isLegacy = false
        }

        var failures: [ImportFailure] = []
        let decodedItems = decoded.compactMap(\.item)
        let skippedCount = decoded.count - decodedItems.count
        if skippedCount > 0 {
            let backup = persistence.backupIndex(named: "library-partial", move: false)
            failures.append(ImportFailure(
                sourceName: "Library",
                message: "\(skippedCount) item(s) could not be read and were skipped. The original file was kept at \(backup?.path ?? persistence.indexURL.path)."
            ))
            if backup == nil {
                isPersistenceBlocked = true
            }
        } else if isLegacy {
            persistence.backupIndex(named: "library-v1", move: false)
        } else {
            persistence.backupIndex(named: "library-previous", move: false, timestamped: false)
        }

        var contentToWrite: Set<UUID> = []
        var needsIndexSave = isLegacy || skippedCount > 0
        var loadedItems: [LibraryItem] = []
        for var item in decodedItems {
            if isLegacy {
                contentToWrite.insert(item.id)
            } else if let content = persistence.readContent(for: item.id) {
                item.sections = content.sections
                item.coverImageData = content.cover
            } else {
                failures.append(ImportFailure(
                    sourceName: item.title,
                    message: "The text of this document is missing from the library folder."
                ))
            }

            let repaired = repairedItem(item)
            if repaired.sections != item.sections, !item.sections.isEmpty {
                contentToWrite.insert(item.id)
            }
            if repaired.progress != item.progress || repaired.preferences != item.preferences {
                needsIndexSave = true
            }
            loadedItems.append(repaired)
        }

        items = loadedItems
        selectedID = items.sortedForLibrary.first?.id
        lastFailures = failures

        guard !isPersistenceBlocked else { return }
        for item in items where contentToWrite.contains(item.id) {
            writeContent(of: item)
        }
        if needsIndexSave {
            saveIndex()
        }
    }

    /// Adds a playback segment to the reading statistics and saves them.
    public func recordReading(words: Int, seconds: TimeInterval, endingAt date: Date = Date()) {
        let before = statistics
        statistics.record(words: words, seconds: seconds, endingAt: date)
        guard statistics != before, !isPersistenceBlocked, !isStatisticsBlocked else { return }
        do {
            try persistence.writeStatistics(statistics)
        } catch {
            lastFailures = [ImportFailure(sourceName: "Statistics", message: error.localizedDescription)]
        }
    }

    private func loadStatistics() {
        do {
            statistics = try persistence.readStatistics()
        } catch {
            // Keep unreadable statistics aside instead of overwriting them.
            if let backup = persistence.backupIndex(named: "statistics-unreadable", move: true, source: persistence.statisticsURL) {
                lastFailures.append(ImportFailure(
                    sourceName: "Statistics",
                    message: "Reading statistics could not be read. The original file was kept at \(backup.path)."
                ))
            } else {
                isStatisticsBlocked = true
            }
        }
    }

    public func importFiles(_ urls: [URL]) async {
        var failures: [ImportFailure] = []
        for url in urls {
            do {
                let document = try await importer.importFile(at: url)
                try insertDocument(document)
            } catch {
                failures.append(ImportFailure(sourceName: url.lastPathComponent, message: error.localizedDescription))
            }
        }
        lastFailures = failures
    }

    public func setDefaultPreferences(_ preferences: ReadingPreferences) {
        defaultPreferences = preferences.clamped()
    }

    public func importArticle(from url: URL) async {
        do {
            let document = try await importer.importArticle(from: url)
            try insertDocument(document)
            lastFailures = []
        } catch {
            lastFailures = [ImportFailure(sourceName: url.absoluteString, message: error.localizedDescription)]
        }
    }

    public func importClipboardText(_ text: String) {
        do {
            try insertDocument(importer.importClipboardText(text))
            lastFailures = []
        } catch {
            lastFailures = [ImportFailure(sourceName: "Clipboard", message: error.localizedDescription)]
        }
    }

    private func insertDocument(_ document: ImportedDocument) throws {
        let text = document.sections.map(\.text)
        if let existing = items.first(where: { $0.sections.map(\.text) == text }) {
            selectedID = existing.id
            return
        }
        guard !isPersistenceBlocked else { throw CocoaError(.fileWriteNoPermission) }
        let newItem = item(from: document)
        try persistence.writeContent(of: newItem)
        let updated = [newItem] + items
        try persistence.writeIndex(updated)
        items = updated
        selectedID = newItem.id
    }

    public func updateProgress(for id: UUID, sectionIndex: Int, wordIndex: Int) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let sectionIndex = min(max(sectionIndex, 0), max(items[index].sections.count - 1, 0))
        let maxWords = items[index].sections.indices.contains(sectionIndex) ? items[index].sections[sectionIndex].wordCount : 0
        items[index].progress.sectionIndex = sectionIndex
        items[index].progress.wordIndex = min(max(wordIndex, 0), maxWords)
        items[index].progress.completedAt = items[index].fractionComplete >= 0.999 ? Date() : nil
        items[index].lastReadAt = Date()
        scheduleSave()
    }

    public func updatePreferences(for id: UUID, _ preferences: ReadingPreferences) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].preferences = preferences
        scheduleSave()
    }

    public func toggleFavorite(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isFavorite.toggle()
        saveIndex()
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
        saveIndex()
    }

    public func updateNote(for id: UUID, noteID: UUID, text: String) {
        guard let index = items.firstIndex(where: { $0.id == id }),
              let noteIndex = items[index].notes.firstIndex(where: { $0.id == noteID }) else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        items[index].notes[noteIndex].text = trimmed
        saveIndex()
    }

    public func deleteNote(for id: UUID, noteID: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].notes.removeAll { $0.id == noteID }
        saveIndex()
    }

    public func deleteItems(at offsets: IndexSet, from visibleItems: [LibraryItem]) {
        guard !isPersistenceBlocked else { return }
        let ids = Set(offsets.compactMap { visibleItems.indices.contains($0) ? visibleItems[$0].id : nil })
        let remaining = items.filter { !ids.contains($0.id) }
        // Commit the index before removing content, so a failed save cannot orphan books.
        do {
            try persistence.writeIndex(remaining)
        } catch {
            recordFailure(sourceName: "Library", message: error.localizedDescription)
            return
        }
        pendingSave?.cancel()
        pendingSave = nil
        items = remaining
        if let selectedID, ids.contains(selectedID) {
            self.selectedID = items.sortedForLibrary.first?.id
        }
        ids.forEach(persistence.deleteContent)
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
        let maxWords = sections.indices.contains(sectionIndex) ? sections[sectionIndex].wordCount : 0
        return ReadingProgress(
            sectionIndex: sectionIndex,
            wordIndex: min(max(progress.wordIndex, 0), maxWords),
            completedAt: progress.completedAt
        )
    }

    private func repairedPreferences(_ preferences: ReadingPreferences) -> ReadingPreferences {
        preferences.clamped()
    }

    /// Writes any pending changes to disk immediately.
    public func flushPendingChanges() {
        guard pendingSave != nil else { return }
        saveIndex()
    }

    /// Coalesces frequent updates such as reading progress into a single write.
    private func scheduleSave() {
        guard pendingSave == nil else { return }
        let delay = saveDelay
        pendingSave = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.saveIndex()
        }
    }

    private func saveIndex() {
        pendingSave?.cancel()
        pendingSave = nil
        guard !isPersistenceBlocked else { return }
        do {
            try persistence.writeIndex(items)
        } catch {
            lastFailures = [ImportFailure(sourceName: "Library", message: error.localizedDescription)]
        }
    }

    private func writeContent(of item: LibraryItem) {
        guard !isPersistenceBlocked else { return }
        do {
            try persistence.writeContent(of: item)
        } catch {
            lastFailures = [ImportFailure(sourceName: item.title, message: error.localizedDescription)]
        }
    }

    private func blockPersistence(message: String) {
        isPersistenceBlocked = true
        lastFailures = [ImportFailure(
            sourceName: "Library",
            message: "The library could not be opened (\(message)). Changes will not be saved until the problem is fixed."
        )]
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
