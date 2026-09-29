import Foundation
import PDFKit

public enum PDFTextExtractor {
    public static func importPDF(at url: URL) throws -> ImportedDocument {
        guard let document = PDFDocument(url: url) else {
            throw DocumentImportError.unreadableFile(url.lastPathComponent)
        }
        let pages = cleanedPages((0..<document.pageCount).map { document.page(at: $0)?.string ?? "" })
        var chapters: [(page: Int, title: String)] = []
        func visit(_ outline: PDFOutline) {
            if let destination = outline.destination, let page = destination.page,
               let title = outline.label, !title.isEmpty {
                let index = document.index(for: page)
                if index != NSNotFound { chapters.append((index, title)) }
            }
            for index in 0..<outline.numberOfChildren {
                if let child = outline.child(at: index) { visit(child) }
            }
        }
        if let outline = document.outlineRoot { visit(outline) }
        chapters.sort { $0.page < $1.page }
        var seen = Set<Int>()
        chapters = chapters.filter { seen.insert($0.page).inserted }
        if let first = chapters.first, first.page > 0 { chapters.insert((0, "Opening"), at: 0) }

        let sections: [BookSection]
        if chapters.isEmpty {
            sections = pages.enumerated().map { BookSection(title: "Page \($0.offset + 1)", text: $0.element) }
        } else {
            sections = chapters.enumerated().map { index, chapter in
                let end = index + 1 < chapters.count ? chapters[index + 1].page : pages.count
                return BookSection(title: chapter.title, text: pages[chapter.page..<end].joined(separator: "\n\n"))
            }
        }
        let readable = sections.filter { $0.wordCount > 0 }
        guard !readable.isEmpty else { throw DocumentImportError.emptyDocument(url.lastPathComponent) }
        return ImportedDocument(
            title: TextProcessor.cleanedTitle(document.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String, fallback: url.deletingPathExtension().lastPathComponent),
            author: document.documentAttributes?[PDFDocumentAttribute.authorAttribute] as? String,
            sourceName: url.lastPathComponent,
            sourceURL: url.absoluteString,
            format: .pdf,
            sections: readable
        )
    }

    static func cleanedPages(_ pages: [String]) -> [String] {
        let lines = pages.map { $0.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
        var counts: [String: Int] = [:]
        for page in lines {
            for edge in Set(Array(page.prefix(1)) + Array(page.suffix(1))) where edge.count <= 100 {
                counts[edge, default: 0] += 1
            }
        }
        let threshold = max(3, Int(ceil(Double(pages.count) * 0.7)))
        return lines.map { page in
            var cleaned = page
            func isMargin(_ value: String) -> Bool {
                counts[value, default: 0] >= threshold || value.range(of: #"^(?:Page\s+)?\d+(?:\s+(?:of|/)\s*\d+)?$"#, options: .regularExpression) != nil
            }
            if let first = cleaned.first, isMargin(first) { cleaned.removeFirst() }
            if let last = cleaned.last, isMargin(last) { cleaned.removeLast() }
            let joined = cleaned.joined(separator: "\n")
                .replacingOccurrences(of: "\u{00ad}\n", with: "")
                .replacingOccurrences(of: "\u{00ad}", with: "")
                .replacingOccurrences(of: #"(\p{Ll})-\n(?=\p{Ll})"#, with: "$1", options: .regularExpression)
            return TextProcessor.normalizedText(joined)
        }
    }
}
