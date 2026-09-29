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

    public init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        self = ReadingFormat(rawValue: rawValue) ?? .unknown
    }

    public var displayName: String {
        switch self {
        case .epub: "EPUB"
        case .pdf: "PDF"
        case .docx: "DOCX"
        case .rtf: "RTF"
        case .html: "HTML"
        case .markdown: "Markdown"
        case .plainText: String(localized: "Text", bundle: .module)
        case .webArticle: String(localized: "Article", bundle: .module)
        case .unknown: String(localized: "Document", bundle: .module)
        }
    }
}
