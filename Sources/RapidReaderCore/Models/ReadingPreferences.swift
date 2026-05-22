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
}
