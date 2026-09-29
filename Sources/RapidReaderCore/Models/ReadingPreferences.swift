import Foundation

public struct ReadingPreferences: Codable, Equatable, Sendable {
    public var wordsPerMinute: Int
    public var fontSize: Double
    public var chunkSize: Int
    public var showContext: Bool
    public var pauseOnPunctuation: Bool
    public var focusMode: Bool
    public var rampUpSeconds: Double
    public var pauseOnLongWords: Bool
    public var resumeRewindWords: Int

    public init(
        wordsPerMinute: Int = 350,
        fontSize: Double = 72,
        chunkSize: Int = 1,
        showContext: Bool = true,
        pauseOnPunctuation: Bool = true,
        focusMode: Bool = false,
        rampUpSeconds: Double = 0,
        pauseOnLongWords: Bool = false,
        resumeRewindWords: Int = 0
    ) {
        self.wordsPerMinute = wordsPerMinute
        self.fontSize = fontSize
        self.chunkSize = chunkSize
        self.showContext = showContext
        self.pauseOnPunctuation = pauseOnPunctuation
        self.focusMode = focusMode
        self.rampUpSeconds = rampUpSeconds
        self.pauseOnLongWords = pauseOnLongWords
        self.resumeRewindWords = resumeRewindWords
    }

    public func clamped() -> ReadingPreferences {
        var result = self
        result.wordsPerMinute = min(max(wordsPerMinute, 100), 900)
        result.fontSize = fontSize.isFinite ? min(max(fontSize, 42), 110) : 72
        result.chunkSize = min(max(chunkSize, 1), 4)
        result.rampUpSeconds = rampUpSeconds.isFinite ? min(max(rampUpSeconds, 0), 10) : 0
        result.resumeRewindWords = min(max(resumeRewindWords, 0), 20)
        return result
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
            focusMode: try container.decodeIfPresent(Bool.self, forKey: .focusMode) ?? defaults.focusMode,
            rampUpSeconds: try container.decodeIfPresent(Double.self, forKey: .rampUpSeconds) ?? defaults.rampUpSeconds,
            pauseOnLongWords: try container.decodeIfPresent(Bool.self, forKey: .pauseOnLongWords) ?? defaults.pauseOnLongWords,
            resumeRewindWords: try container.decodeIfPresent(Int.self, forKey: .resumeRewindWords) ?? defaults.resumeRewindWords
        )
    }
}
