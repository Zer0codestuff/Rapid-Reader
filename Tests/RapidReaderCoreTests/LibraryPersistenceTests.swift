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
