import Foundation

public struct ReadingPreferences: Codable, Equatable, Sendable {
    public var wordsPerMinute: Int
    public var fontSize: Double
    public var chunkSize: Int
    public var showContext: Bool
    public var pauseOnPunctuation: Bool
    public var focusMode: Bool

    public init(
        wordsPerMinute: Int = 350,
        fontSize: Double = 72,
        chunkSize: Int = 1,
        showContext: Bool = true,
        pauseOnPunctuation: Bool = true,
        focusMode: Bool = false
    ) {
        self.wordsPerMinute = wordsPerMinute
        self.fontSize = fontSize
        self.chunkSize = chunkSize
        self.showContext = showContext
        self.pauseOnPunctuation = pauseOnPunctuation
        self.focusMode = focusMode
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = ReadingPreferences()
        self.init(
            wordsPerMinute: try container.decodeIfPresent(Int.self, forKey: .wordsPerMinute) ?? defaults.wordsPerMinute,
            fontSize: try container.decodeIfPresent(Double.self, forKey: .fontSize) ?? defaults.fontSize,
            chunkSize: try container.decodeIfPresent(Int.self, forKey: .chunkSize) ?? defaults.chunkSize,
            showContext: try container.decodeIfPresent(Bool.self, forKey: .showContext) ?? defaults.showContext,
            pauseOnPunctuation: try container.decodeIfPresent(Bool.self, forKey: .pauseOnPunctuation) ?? defaults.pauseOnPunctuation,
            focusMode: try container.decodeIfPresent(Bool.self, forKey: .focusMode) ?? defaults.focusMode
        )
    }
}
