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
        func stream(_ text: String) -> String {
            let content = "BT /F1 18 Tf 40 400 Td (\(text)) Tj ET"
            return "<< /Length \(content.utf8.count) >>\nstream\n\(content)\nendstream"
        }
        // A real PDF fixture with an explicit outline, independent of PDFKit's writer.
        let objects = [
            "<< /Type /Catalog /Pages 2 0 R /Outlines 8 0 R >>",
            "<< /Type /Pages /Kids [3 0 R 5 0 R] /Count 2 >>",
            "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 400 500] /Resources << /Font << /F1 7 0 R >> >> /Contents 4 0 R >>",
            stream("First chapter text."),
            "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 400 500] /Resources << /Font << /F1 7 0 R >> >> /Contents 6 0 R >>",
            stream("Second chapter text."),
            "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
            "<< /Type /Outlines /First 9 0 R /Last 10 0 R /Count 2 >>",
            "<< /Title (Chapter 1) /Parent 8 0 R /Dest [3 0 R /Fit] /Next 10 0 R >>",
            "<< /Title (Chapter 2) /Parent 8 0 R /Dest [5 0 R /Fit] /Prev 9 0 R >>"
        ]
        var pdf = "%PDF-1.4\n"
        var offsets: [Int] = []
        for (index, object) in objects.enumerated() {
            offsets.append(pdf.utf8.count)
            pdf += "\(index + 1) 0 obj\n\(object)\nendobj\n"
        }
        let xref = pdf.utf8.count
        pdf += "xref\n0 11\n0000000000 65535 f \n"
        for offset in offsets { pdf += String(format: "%010d 00000 n \n", offset) }
        pdf += "trailer\n<< /Size 11 /Root 1 0 R >>\nstartxref\n\(xref)\n%%EOF"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data(pdf.utf8).write(to: url)
        let imported = try PDFTextExtractor.importPDF(at: url)
        XCTAssertEqual(imported.sections.map(\.title), ["Chapter 1", "Chapter 2"])
        XCTAssertTrue(imported.sections[1].text.contains("Second chapter"))
    }
}
