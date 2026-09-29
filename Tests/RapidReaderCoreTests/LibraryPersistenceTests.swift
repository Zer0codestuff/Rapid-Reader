import Foundation
import XCTest
@testable import RapidReaderCore

@MainActor
final class LibraryPersistenceTests: XCTestCase {
    private var root: URL!

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: root)
    }

    private var libraryURL: URL { root.appendingPathComponent("library.json") }

    func testMissingFieldsFromOtherVersionsDecodeWithDefaults() throws {
        let store = LibraryStore(rootURL: root)
        store.importClipboardText("Alpha beta gamma delta.")
        store.flushPendingChanges()

        var json = try String(contentsOf: libraryURL, encoding: .utf8)
        json = json.replacingOccurrences(of: "\"focusMode\" : false,", with: "")
        json = json.replacingOccurrences(of: "\"isFavorite\" : false,", with: "")
        json = json.replacingOccurrences(of: "\"format\" : \"plainText\"", with: "\"format\" : \"futureFormat\"")
        try json.write(to: libraryURL, atomically: true, encoding: .utf8)

        let reloaded = LibraryStore(rootURL: root)
        let item = try XCTUnwrap(reloaded.items.first)
        XCTAssertEqual(reloaded.items.count, 1)
        XCTAssertEqual(item.format, .unknown)
        XCTAssertFalse(item.isFavorite)
        XCTAssertFalse(item.preferences.focusMode)
        XCTAssertEqual(item.preferences.rampUpSeconds, 0)
        XCTAssertFalse(item.preferences.pauseOnLongWords)
        XCTAssertEqual(item.preferences.resumeRewindWords, 0)
        XCTAssertTrue(reloaded.lastFailures.isEmpty)
    }

    func testUnreadableLibraryIsMovedAsideInsteadOfOverwritten() throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let garbage = Data("{ this is not a library".utf8)
        try garbage.write(to: libraryURL)

        let store = LibraryStore(rootURL: root)
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertEqual(store.lastFailures.count, 1)

        store.importClipboardText("New text after a failed load.")
        store.flushPendingChanges()

        let backups = try FileManager.default.contentsOfDirectory(at: store.backupsURL, includingPropertiesForKeys: nil)
        let unreadable = try XCTUnwrap(backups.first { $0.lastPathComponent.hasPrefix("library-unreadable") })
        XCTAssertEqual(try Data(contentsOf: unreadable), garbage)
    }

    func testBrokenItemIsSkippedAndOriginalIsBackedUp() throws {
        let store = LibraryStore(rootURL: root)
        store.importClipboardText("First document text.")
        store.importClipboardText("Second document text.")
        store.flushPendingChanges()

        var json = try String(contentsOf: libraryURL, encoding: .utf8)
        let firstID = try XCTUnwrap(store.items.first?.id.uuidString)
        json = json.replacingOccurrences(of: "\"id\" : \"\(firstID)\"", with: "\"id\" : 42")
        try json.write(to: libraryURL, atomically: true, encoding: .utf8)

        let reloaded = LibraryStore(rootURL: root)
        XCTAssertEqual(reloaded.items.count, 1)
        XCTAssertEqual(reloaded.lastFailures.count, 1)

        let backups = try FileManager.default.contentsOfDirectory(at: reloaded.backupsURL, includingPropertiesForKeys: nil)
        let partial = try XCTUnwrap(backups.first { $0.lastPathComponent.hasPrefix("library-partial") })
        XCTAssertTrue(try String(contentsOf: partial, encoding: .utf8).contains("\"id\" : 42"))
    }

    func testSuccessfulLoadKeepsPreviousCopy() throws {
        let store = LibraryStore(rootURL: root)
        store.importClipboardText("Keep me safe.")
        store.flushPendingChanges()

        let reloaded = LibraryStore(rootURL: root)
        let previous = reloaded.backupsURL.appendingPathComponent("library-previous.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: previous.path))
    }
}

@MainActor
final class LibraryStorageLayoutTests: XCTestCase {
    private var root: URL!

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testIndexDoesNotContainDocumentTextOrCovers() throws {
        let store = LibraryStore(rootURL: root)
        store.importClipboardText("A title\nA very distinctive sentence lives only in the content file.")

        let index = try String(contentsOf: root.appendingPathComponent("library.json"), encoding: .utf8)
        XCTAssertTrue(index.contains("\"schemaVersion\" : 2"))
        XCTAssertFalse(index.contains("distinctive sentence"))

        let reloaded = LibraryStore(rootURL: root)
        XCTAssertEqual(
            reloaded.items.first?.sections.first?.text,
            "A title\nA very distinctive sentence lives only in the content file."
        )
    }

    func testProgressUpdatesAreDebouncedAndFlushed() throws {
        let store = LibraryStore(rootURL: root, saveDelay: .seconds(60))
        store.importClipboardText("One two three four five six.")
        let id = try XCTUnwrap(store.items.first?.id)
        let indexURL = root.appendingPathComponent("library.json")
        let before = try Data(contentsOf: indexURL)

        for word in 1...5 {
            store.updateProgress(for: id, sectionIndex: 0, wordIndex: word)
        }
        XCTAssertEqual(try Data(contentsOf: indexURL), before, "progress should not hit the disk on every word")

        store.flushPendingChanges()
        XCTAssertEqual(LibraryStore(rootURL: root).items.first?.progress.wordIndex, 5)
    }

    func testLegacySingleFileLibraryIsMigrated() throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let legacy = LibraryItem(
            title: "Legacy",
            sourceName: "legacy.txt",
            format: .plainText,
            sections: [BookSection(title: "Legacy", text: "Old style library text.")],
            progress: ReadingProgress(sectionIndex: 0, wordIndex: 2),
            coverImageData: Data([1, 2, 3])
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode([legacy]).write(to: root.appendingPathComponent("library.json"))

        let migrated = LibraryStore(rootURL: root)
        XCTAssertEqual(migrated.items.first?.progress.wordIndex, 2)

        let backups = try FileManager.default.contentsOfDirectory(atPath: migrated.backupsURL.path)
        XCTAssertTrue(backups.contains { $0.hasPrefix("library-v1") })

        let reloaded = LibraryStore(rootURL: root)
        let item = try XCTUnwrap(reloaded.items.first)
        XCTAssertEqual(item.sections.first?.text, "Old style library text.")
        XCTAssertEqual(item.coverImageData, Data([1, 2, 3]))
        XCTAssertEqual(item.progress.wordIndex, 2)
    }

    func testDeletingRemovesContentFiles() throws {
        let store = LibraryStore(rootURL: root)
        store.importClipboardText("Delete me please.")
        let documents = root.appendingPathComponent("Documents")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: documents.path).count, 1)

        store.deleteItems(at: IndexSet(integer: 0), from: store.items)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: documents.path).count, 0)
    }
}
