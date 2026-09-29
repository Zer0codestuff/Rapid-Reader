import Foundation

public struct ReadingProgress: Codable, Equatable, Sendable {
    public var sectionIndex: Int
    public var wordIndex: Int
    public var completedAt: Date?

    public init(sectionIndex: Int = 0, wordIndex: Int = 0, completedAt: Date? = nil) {
        self.sectionIndex = sectionIndex
        self.wordIndex = wordIndex
        self.completedAt = completedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            sectionIndex: try container.decodeIfPresent(Int.self, forKey: .sectionIndex) ?? 0,
            wordIndex: try container.decodeIfPresent(Int.self, forKey: .wordIndex) ?? 0,
            completedAt: try container.decodeIfPresent(Date.self, forKey: .completedAt)
        )
    }
}
