import Foundation
import RapidReaderCore

enum ReadingDefaults {
    static func preferences(_ defaults: UserDefaults = .standard) -> ReadingPreferences {
        let fallback = ReadingPreferences()
        return ReadingPreferences(
            wordsPerMinute: defaults.object(forKey: "readerDefaultWPM") as? Int ?? fallback.wordsPerMinute,
            fontSize: defaults.object(forKey: "readerDefaultFontSize") as? Double ?? fallback.fontSize,
            chunkSize: defaults.object(forKey: "readerDefaultChunkSize") as? Int ?? fallback.chunkSize,
            showContext: defaults.object(forKey: "readerDefaultContext") as? Bool ?? fallback.showContext,
            pauseOnPunctuation: defaults.object(forKey: "readerDefaultPauses") as? Bool ?? fallback.pauseOnPunctuation,
            focusMode: defaults.object(forKey: "readerDefaultFocus") as? Bool ?? fallback.focusMode,
            rampUpSeconds: defaults.object(forKey: "readerDefaultRamp") as? Double ?? fallback.rampUpSeconds,
            pauseOnLongWords: defaults.object(forKey: "readerDefaultLongWords") as? Bool ?? fallback.pauseOnLongWords,
            resumeRewindWords: defaults.object(forKey: "readerDefaultRewind") as? Int ?? fallback.resumeRewindWords
        ).clamped()
    }
}
