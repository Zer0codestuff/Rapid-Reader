import Foundation
import PDFKit

public enum PDFTextExtractor {
    public static func importPDF(at url: URL) throws -> ImportedDocument {
        guard let document = PDFDocument(url: url) else {
            throw DocumentImportError.unreadableFile(url.lastPathComponent)
        }

        var sections: [BookSection] = []
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let text = TextProcessor.normalizedText(page.string ?? "")
            if !text.isEmpty {
                sections.append(BookSection(title: "Page \(index + 1)", text: text))
            }
        }

        guard !sections.isEmpty else {
            throw DocumentImportError.emptyDocument(url.lastPathComponent)
        }

        let title = TextProcessor.cleanedTitle(document.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String, fallback: url.deletingPathExtension().lastPathComponent)
        let author = document.documentAttributes?[PDFDocumentAttribute.authorAttribute] as? String

        return ImportedDocument(
            title: title,
            author: author,
            sourceName: url.lastPathComponent,
            sourceURL: url.absoluteString,
            format: .pdf,
            sections: sections
        )
    }
}
