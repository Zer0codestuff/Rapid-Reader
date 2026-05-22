import Foundation
import XCTest
import ZIPFoundation
@testable import RapidReaderCore

final class DocumentImportTests: XCTestCase {
    func testMarkdownFileImportCreatesReadableSections() async throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        let file = temp.appendingPathComponent("sample.md")
        try """
        # First
        Alpha beta gamma.

        # Second
        Delta epsilon zeta.
        """.write(to: file, atomically: true, encoding: .utf8)

        let imported = try await DocumentImportService().importFile(at: file)

        XCTAssertEqual(imported.format, .markdown)
        XCTAssertEqual(imported.title, "sample")
        XCTAssertEqual(imported.sections.map(\.title), ["First", "Second"])
    }

    func testEPUBImportExtractsCoverImage() async throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        let epubURL = temp.appendingPathComponent("covered.epub")
        try makeMinimalEPUB(at: epubURL)

        let imported = try await DocumentImportService().importFile(at: epubURL)

        XCTAssertEqual(imported.format, .epub)
        XCTAssertEqual(imported.title, "Covered Book")
        XCTAssertEqual(imported.author, "Reader Test")
        XCTAssertEqual(imported.sections.count, 1)
        XCTAssertEqual(imported.coverImageData, Self.coverPNG)
    }

    @MainActor
    func testLibraryStorePersistsProgressAndPreferences() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = LibraryStore(rootURL: temp)

        store.setDefaultPreferences(ReadingPreferences(wordsPerMinute: 425, fontSize: 80))
        store.importClipboardText("One two three four five.")

        let id = try XCTUnwrap(store.items.first?.id)
        store.updateProgress(for: id, sectionIndex: 0, wordIndex: 3)

        let reloaded = LibraryStore(rootURL: temp)
        let item = try XCTUnwrap(reloaded.items.first)

        XCTAssertEqual(item.progress.wordIndex, 3)
        XCTAssertEqual(item.preferences.wordsPerMinute, 425)
        XCTAssertEqual(item.preferences.fontSize, 80)
    }

    @MainActor
    func testLibraryStoreRepairsImageOnlyEPUBSectionsOnLoad() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)

        let legacyItem = LibraryItem(
            title: "Legacy EPUB",
            sourceName: "legacy.epub",
            format: .epub,
            sections: [
                BookSection(title: "Cover", text: "\u{fffc}", wordCount: 1),
                BookSection(title: "Chapter", text: "Alpha beta gamma.")
            ],
            progress: ReadingProgress(sectionIndex: 0, wordIndex: 0),
            preferences: ReadingPreferences(wordsPerMinute: 20, fontSize: 500, chunkSize: 12)
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let libraryURL = temp.appendingPathComponent("library.json")
        try encoder.encode([legacyItem]).write(to: libraryURL)

        let store = LibraryStore(rootURL: temp)
        let item = try XCTUnwrap(store.items.first)

        XCTAssertEqual(item.sections.map(\.title), ["Chapter"])
        XCTAssertEqual(item.progress.sectionIndex, 0)
        XCTAssertEqual(item.progress.wordIndex, 0)
        XCTAssertEqual(item.preferences.wordsPerMinute, 100)
        XCTAssertEqual(item.preferences.fontSize, 110)
        XCTAssertEqual(item.preferences.chunkSize, 4)
    }

    private func makeMinimalEPUB(at url: URL) throws {
        let archive = try Archive(url: url, accessMode: .create)

        try addEntry("mimetype", data: Data("application/epub+zip".utf8), to: archive)
        try addEntry(
            "META-INF/container.xml",
            data: Data("""
            <?xml version="1.0" encoding="UTF-8"?>
            <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
              <rootfiles>
                <rootfile full-path="OEBPS/package.opf" media-type="application/oebps-package+xml"/>
              </rootfiles>
            </container>
            """.utf8),
            to: archive
        )
        try addEntry(
            "OEBPS/package.opf",
            data: Data("""
            <?xml version="1.0" encoding="UTF-8"?>
            <package version="3.0" xmlns="http://www.idpf.org/2007/opf">
              <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
                <dc:title>Covered Book</dc:title>
                <dc:creator>Reader Test</dc:creator>
                <meta name="cover" content="cover-image"/>
              </metadata>
              <manifest>
                <item id="cover-image" href="Images/cover.png" media-type="image/png" properties="cover-image"/>
                <item id="cover-page" href="Text/cover.xhtml" media-type="application/xhtml+xml"/>
                <item id="chapter" href="Text/chapter.xhtml" media-type="application/xhtml+xml"/>
              </manifest>
              <spine>
                <itemref idref="cover-page"/>
                <itemref idref="chapter"/>
              </spine>
            </package>
            """.utf8),
            to: archive
        )
        try addEntry(
            "OEBPS/Text/cover.xhtml",
            data: Data("""
            <!doctype html>
            <html xmlns="http://www.w3.org/1999/xhtml">
              <head><title>Cover</title></head>
              <body><img src="../Images/cover.png" alt=""/></body>
            </html>
            """.utf8),
            to: archive
        )
        try addEntry(
            "OEBPS/Text/chapter.xhtml",
            data: Data("""
            <!doctype html>
            <html xmlns="http://www.w3.org/1999/xhtml">
              <head><title>Chapter One</title></head>
              <body><h1>Chapter One</h1><p>Alpha beta gamma delta.</p></body>
            </html>
            """.utf8),
            to: archive
        )
        try addEntry("OEBPS/Images/cover.png", data: Self.coverPNG, to: archive)
    }

    private func addEntry(_ path: String, data: Data, to archive: Archive) throws {
        try archive.addEntry(
            with: path,
            type: .file,
            uncompressedSize: Int64(data.count),
            provider: { position, size in
                data.subdata(in: Int(position)..<Int(position) + size)
            }
        )
    }

    private static let coverPNG = Data([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
        0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
        0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
        0x00, 0x03, 0x01, 0x01, 0x00, 0x18, 0xDD, 0x8D,
        0xB0, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E,
        0x44, 0xAE, 0x42, 0x60, 0x82
    ])
}
