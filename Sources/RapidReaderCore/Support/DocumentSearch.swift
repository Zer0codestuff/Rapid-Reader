import Foundation

public struct SearchMatch: Identifiable, Equatable, Sendable {
    public var id: String { "\(sectionIndex)-\(location)" }
    public let sectionIndex: Int
    /// Index of the first word of the match, in the same token space as `ReaderSession`.
    public let wordIndex: Int
    /// UTF-16 location of the match in the section's normalized text.
    public let location: Int
    public let before: String
    public let match: String
    public let after: String
}

/// Case- and diacritic-insensitive search over a document's sections.
///
/// Sections are tokenized once when the index is built, so repeated queries only scan text.
public struct DocumentSearchIndex: Sendable {
    private struct IndexedSection: Sendable {
        let text: String
        let tokenEnds: [Int]
    }

    private let sections: [IndexedSection]

    public init(sections: [BookSection]) {
        self.sections = sections.map { section in
            let tokenized = TextProcessor.tokenizedText(section.text)
            return IndexedSection(text: tokenized.text, tokenEnds: tokenized.tokens.map { NSMaxRange($0.range) })
        }
    }

    /// Returns matches in reading order, up to `limit`.
    public func matches(for query: String, limit: Int = 500, contextLength: Int = 48) -> [SearchMatch] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty, limit > 0 else { return [] }
        var results: [SearchMatch] = []
        for (sectionIndex, section) in sections.enumerated() {
            let text = section.text as NSString
            var searchRange = NSRange(location: 0, length: text.length)
            while searchRange.length > 0 {
                let found = text.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive], range: searchRange)
                guard found.location != NSNotFound else { break }
                guard let wordIndex = wordIndex(at: found.location, in: section.tokenEnds) else { break }
                results.append(SearchMatch(
                    sectionIndex: sectionIndex,
                    wordIndex: wordIndex,
                    location: found.location,
                    before: context(in: text, before: found.location, length: contextLength),
                    match: flattened(text.substring(with: found)),
                    after: context(in: text, after: NSMaxRange(found), length: contextLength)
                ))
                if results.count >= limit { return results }
                let next = NSMaxRange(found)
                searchRange = NSRange(location: next, length: text.length - next)
            }
        }
        return results
    }

    /// First word whose range ends after `location`.
    private func wordIndex(at location: Int, in tokenEnds: [Int]) -> Int? {
        var low = 0
        var high = tokenEnds.count
        while low < high {
            let mid = (low + high) / 2
            if tokenEnds[mid] <= location { low = mid + 1 } else { high = mid }
        }
        return low < tokenEnds.count ? low : nil
    }

    private func context(in text: NSString, before location: Int, length: Int) -> String {
        let start = max(0, location - length)
        var snippet = text.substring(with: NSRange(location: start, length: location - start))
        if start > 0, let space = snippet.firstIndex(where: \.isWhitespace) {
            snippet = "…" + snippet[snippet.index(after: space)...]
        }
        return flattened(snippet)
    }

    private func context(in text: NSString, after location: Int, length: Int) -> String {
        let end = min(text.length, location + length)
        var snippet = text.substring(with: NSRange(location: location, length: end - location))
        if end < text.length, let space = snippet.lastIndex(where: \.isWhitespace) {
            snippet = snippet[..<space] + "…"
        }
        return flattened(snippet)
    }

    private func flattened(_ text: String) -> String {
        text.replacingOccurrences(of: "\n", with: " ")
    }
}
