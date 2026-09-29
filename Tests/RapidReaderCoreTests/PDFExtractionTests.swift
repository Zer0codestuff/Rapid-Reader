import AppKit
import PDFKit
import XCTest
@testable import RapidReaderCore

final class PDFExtractionTests: XCTestCase {
    func testRepeatedMarginsAndBrokenWords() {
        let result = PDFTextExtractor.cleanedPages([
            "Running title\nA para-\ngraph.\n1", "Running title\nDifferent prose.\n2", "Running title\nLast passage.\n3"
        ])
        XCTAssertEqual(result, ["A paragraph.", "Different prose.", "Last passage."])
    }

    @MainActor
    func testPDFOutlineBecomesSections() throws {
        let data = NSMutableData()
        var box = CGRect(x: 0, y: 0, width: 400, height: 500)
        let consumer = try XCTUnwrap(CGDataConsumer(data: data))
        let context = try XCTUnwrap(CGContext(consumer: consumer, mediaBox: &box, nil))
        for text in ["First chapter text.", "Second chapter text."] {
            context.beginPDFPage(nil)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
            (text as NSString).draw(at: CGPoint(x: 40, y: 400), withAttributes: [.font: NSFont.systemFont(ofSize: 18)])
            NSGraphicsContext.restoreGraphicsState()
            context.endPDFPage()
        }
        context.closePDF()
        let document = try XCTUnwrap(PDFDocument(data: data as Data))
        let outline = PDFOutline()
        for index in 0..<2 {
            let child = PDFOutline()
            child.label = "Chapter \(index + 1)"
            child.destination = PDFDestination(page: try XCTUnwrap(document.page(at: index)), at: .zero)
            outline.insertChild(child, at: index)
        }
        document.outlineRoot = outline
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertTrue(document.write(to: url))
        let imported = try PDFTextExtractor.importPDF(at: url)
        XCTAssertEqual(imported.sections.map(\.title), ["Chapter 1", "Chapter 2"])
        XCTAssertTrue(imported.sections[1].text.contains("Second chapter"))
    }
}
