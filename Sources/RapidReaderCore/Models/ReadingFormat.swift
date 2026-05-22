import Foundation

public enum ReadingFormat: String, Codable, CaseIterable, Sendable {
    case epub
    case pdf
    case docx
    case rtf
    case html
    case markdown
    case plainText
    case webArticle
    case unknown

    public var displayName: String {
        switch self {
        case .epub: "EPUB"
        case .pdf: "PDF"
        case .docx: "DOCX"
        case .rtf: "RTF"
        case .html: "HTML"
        case .markdown: "Markdown"
        case .plainText: "Text"
        case .webArticle: "Article"
        case .unknown: "Document"
        }
    }
}
