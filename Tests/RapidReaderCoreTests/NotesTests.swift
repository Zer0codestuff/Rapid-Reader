import XCTest
@testable import RapidReaderCore

final class NotesTests: XCTestCase {
    @MainActor
    func testNotesRetainPositionAcrossEditsAndReloads() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LibraryStore(rootURL: root)
        store.importClipboardText("One two three four five.")
        let id = try XCTUnwrap(store.selectedID)
        store.updateProgress(for: id, sectionIndex: 0, wordIndex: 2)
        store.addNote(for: id, text: "Original")
        let note = try XCTUnwrap(store.selectedItem?.notes.first)
        store.updateNote(for: id, noteID: note.id, text: "Edited")
        let reloaded = LibraryStore(rootURL: root)
        XCTAssertEqual(reloaded.selectedItem?.notes.first?.text, "Edited")
        XCTAssertEqual(reloaded.selectedItem?.notes.first?.wordIndex, 2)
        reloaded.deleteNote(for: id, noteID: note.id)
        XCTAssertEqual(LibraryStore(rootURL: root).selectedItem?.notes, [])
    }
}
