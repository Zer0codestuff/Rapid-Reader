import Foundation

public struct BookSection: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var text: String
    public var wordCount: Int

    public init(id: UUID = UUID(), title: String, text: String, wordCount: Int? = nil) {
        self.id = id
        self.title = title
        self.text = text
        self.wordCount = wordCount ?? TextProcessor.tokenize(text).count
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        self.init(
            id: try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
            title: try container.decodeIfPresent(String.self, forKey: .title) ?? "",
            text: text,
            wordCount: try container.decodeIfPresent(Int.self, forKey: .wordCount)
        )
    }
}
