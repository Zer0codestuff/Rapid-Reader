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
}
