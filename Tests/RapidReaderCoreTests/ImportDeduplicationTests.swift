import XCTest
@testable import RapidReaderCore

final class ImportDeduplicationTests: XCTestCase {
    @MainActor
    func testReimportSelectsExistingBookAndKeepsProgress() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LibraryStore(rootURL: root)
        store.importClipboardText("A useful title\nThis is the body.")
        let id = try XCTUnwrap(store.selectedID)
        store.updateProgress(for: id, sectionIndex: 0, wordIndex: 3)
        store.importClipboardText("A useful title\nThis is the body.")
        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.selectedID, id)
        XCTAssertEqual(store.selectedItem?.progress.wordIndex, 3)
        XCTAssertEqual(store.selectedItem?.title, "A useful title")
        store.flushPendingChanges()
    }

    func testPunctuationOnlyClipboardIsRejected() {
        XCTAssertThrowsError(try DocumentImportService().importClipboardText("*** …"))
    }
}
