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
}
