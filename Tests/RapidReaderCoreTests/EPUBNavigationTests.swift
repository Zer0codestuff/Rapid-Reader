import XCTest
import ZIPFoundation
@testable import RapidReaderCore

final class EPUBNavigationTests: XCTestCase {
    func testEPUB3NavigationSplitsAnchorsWithinOneSpineFile() throws {
        let document = try fixture(ncx: false)
        XCTAssertEqual(document.sections.map(\.title), ["First chapter", "Second chapter"])
        XCTAssertTrue(document.sections[0].text.contains("Alpha beta"))
        XCTAssertFalse(document.sections[0].text.contains("Gamma delta"))
        XCTAssertTrue(document.sections[1].text.contains("Gamma delta"))
        XCTAssertFalse(document.sections.contains { $0.text.contains("Nonlinear appendix") })
    }

    func testEPUB2NCXUsesTheSameChapterBoundaries() throws {
        let document = try fixture(ncx: true)
        XCTAssertEqual(document.sections.map(\.title), ["First chapter", "Second chapter"])
    }

    private func fixture(ncx: Bool) throws -> ImportedDocument {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("chapters.epub")
        let archive = try Archive(url: url, accessMode: .create)
        let navName = ncx ? "toc.ncx" : "nav.xhtml"
        let navType = ncx ? "application/x-dtbncx+xml" : "application/xhtml+xml"
        let property = ncx ? "" : "properties='nav'"
        let navigation = ncx
            ? "<ncx><navMap><navPoint><navLabel><text>First chapter</text></navLabel><content src='Text/book.xhtml#one'/></navPoint><navPoint><navLabel><text>Second chapter</text></navLabel><content src='Text/book.xhtml#two'/></navPoint></navMap></ncx>"
            : "<html xmlns:epub='http://www.idpf.org/2007/ops'><body><nav epub:type='toc'><ol><li><a href='Text/book.xhtml#one'>First chapter</a></li><li><a href='Text/book.xhtml#two'>Second chapter</a></li></ol></nav></body></html>"
        let entries = [
            "META-INF/container.xml": "<container><rootfiles><rootfile full-path='OPS/package.opf'/></rootfiles></container>",
            "OPS/package.opf": "<package><metadata><title>Navigation</title></metadata><manifest><item id='book' href='Text/book.xhtml' media-type='application/xhtml+xml'/><item id='nav' href='\(navName)' media-type='\(navType)' \(property)/><item id='appendix' href='appendix.xhtml' media-type='application/xhtml+xml'/></manifest><spine><itemref idref='book'/><itemref idref='appendix' linear='no'/></spine></package>",
            "OPS/\(navName)": navigation,
            "OPS/Text/book.xhtml": "<html><head><title>Whole file</title></head><body><section id='one'><h1>One</h1><p>Alpha beta.</p></section><h1 id='two'>Two</h1><p>Gamma delta.</p><div id='pg-footer'>Project Gutenberg license</div></body></html>",
            "OPS/appendix.xhtml": "<p>Nonlinear appendix</p>"
        ]
        for (path, text) in entries {
            let data = Data(text.utf8)
            try archive.addEntry(with: path, type: .file, uncompressedSize: Int64(data.count)) { position, size in
                data.subdata(in: Int(position)..<Int(position) + size)
            }
        }
        return try EPUBParser.importEPUB(at: url)
    }
}
