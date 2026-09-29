import Foundation

public enum TextProcessor {
    public static func normalizedText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{00a0}", with: " ")
            .replacingOccurrences(of: "\u{fffc}", with: " ")
            .replacingOccurrences(of: "\u{200b}", with: " ")
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .joined(separator: "\n")
            .replacingOccurrences(of: #"[ \t]{2,}"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func tokenize(_ text: String) -> [String] {
        tokenizedText(text).tokens.map(\.text)
    }

    /// Ranges use UTF-16 offsets in the returned normalized text, as required by AppKit.
    public static func tokenizedText(_ text: String) -> TokenizedText {
        let normalized = normalizedText(text)
        let source = normalized as NSString
        let regex = try! NSRegularExpression(pattern: #"\S+"#)
        let tokens = regex.matches(in: normalized, range: NSRange(location: 0, length: source.length)).compactMap { match -> TextToken? in
            let word = source.substring(with: match.range)
            return containsReadableScalar(word) ? TextToken(text: word, range: match.range) : nil
        }
        return TokenizedText(text: normalized, tokens: tokens)
    }

    public static func sections(from text: String, fallbackTitle: String) -> [BookSection] {
        let normalized = normalizedText(text)
        guard !normalized.isEmpty else {
            return [BookSection(title: fallbackTitle, text: "")]
        }

        let headingSections = splitByHeadings(normalized)
        if headingSections.count > 1 {
            return headingSections
        }

        let words = tokenize(normalized)
        guard words.count > 1_600 else {
            return [BookSection(title: fallbackTitle, text: normalized)]
        }

        var sections: [BookSection] = []
        var cursor = 0
        var part = 1
        while cursor < words.count {
            let end = min(cursor + 1_200, words.count)
            let chunk = words[cursor..<end].joined(separator: " ")
            sections.append(BookSection(title: "Part \(part)", text: chunk, wordCount: end - cursor))
            cursor = end
            part += 1
        }
        return sections
    }

    public static func cleanedTitle(_ title: String?, fallback: String) -> String {
        let candidate = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let candidate, !candidate.isEmpty else { return fallback }
        return candidate
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func splitByHeadings(_ text: String) -> [BookSection] {
        let lines = text.components(separatedBy: .newlines)
        var currentTitle: String?
        var currentLines: [String] = []
        var sections: [BookSection] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if isHeading(trimmed) {
                if let title = currentTitle, !currentLines.isEmpty {
                    sections.append(BookSection(title: title, text: currentLines.joined(separator: "\n")))
                }
                currentTitle = headingTitle(from: trimmed)
                currentLines = []
            } else {
                currentLines.append(line)
            }
        }

        if let title = currentTitle, !currentLines.isEmpty {
            sections.append(BookSection(title: title, text: currentLines.joined(separator: "\n")))
        }

        return sections.filter { $0.wordCount > 0 }
    }

    private static func containsReadableScalar(_ token: String) -> Bool {
        token.unicodeScalars.contains { CharacterSet.alphanumerics.contains($0) }
    }

    private static func isHeading(_ line: String) -> Bool {
        guard !line.isEmpty, line.count <= 90 else { return false }
        if line.hasPrefix("# ") || line.hasPrefix("## ") || line.hasPrefix("### ") {
            return true
        }
        let pattern = #"^(chapter|section|part|book)\s+([0-9ivxlcdm]+|[a-z])[:\.\-\s]?.*$"#
        return line.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func headingTitle(from line: String) -> String {
        line
            .replacingOccurrences(of: #"^#{1,6}\s*"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public struct RSVPWord: Equatable, Sendable {
    public var raw: String

    public init(_ raw: String) {
        self.raw = raw
    }

    public var pivotIndex: Int {
        let count = raw.count
        switch count {
        case 0...1: return 0
        case 2...5: return 1
        case 6...9: return 2
        case 10...13: return 3
        default: return 4
        }
    }

    public var splitForDisplay: (prefix: String, pivot: String, suffix: String) {
        guard !raw.isEmpty else { return ("", "", "") }
        let safePivot = min(pivotIndex, raw.count - 1)
        let pivot = raw.index(raw.startIndex, offsetBy: safePivot)
        let afterPivot = raw.index(after: pivot)
        return (
            String(raw[..<pivot]),
            String(raw[pivot]),
            String(raw[afterPivot...])
        )
    }

    public var punctuationDelayMultiplier: Double {
        let ending = raw.trimmingCharacters(in: CharacterSet(charactersIn: "\"'”’)]}"))
        if ending.hasSuffix(".") || ending.hasSuffix("!") || ending.hasSuffix("?") {
            return 1.8
        }
        if ending.hasSuffix(",") || ending.hasSuffix(";") || ending.hasSuffix(":") {
            return 1.35
        }
        return 1
    }
}

public struct TextToken: Equatable, Sendable {
    public let text: String
    public let range: NSRange
}

public struct TokenizedText: Equatable, Sendable {
    public let text: String
    public let tokens: [TextToken]
}
