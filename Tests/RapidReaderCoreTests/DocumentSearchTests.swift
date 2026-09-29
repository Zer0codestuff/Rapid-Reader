import XCTest
@testable import RapidReaderCore

final class DocumentSearchTests: XCTestCase {
    private let sections = [
        BookSection(title: "One", text: "The café opened early.\nNobody — not even Alice — came."),
        BookSection(title: "Two", text: "Alice returned to the CAFE at noon.")
    ]

    func testMatchesMapToReaderWordIndices() {
        let index = DocumentSearchIndex(sections: sections)
        let matches = index.matches(for: "alice")
        XCTAssertEqual(matches.map(\.sectionIndex), [0, 1])
        let tokens = TextProcessor.tokenize(sections[0].text)
        XCTAssertEqual(tokens[matches[0].wordIndex], "Alice")
        XCTAssertEqual(matches[1].wordIndex, 0)
        XCTAssertEqual(matches[0].match, "Alice")
    }

    func testSearchIgnoresCaseAndDiacriticsAndSpansWords() {
        let index = DocumentSearchIndex(sections: sections)
        XCTAssertEqual(index.matches(for: "cafe").map(\.sectionIndex), [0, 1])
        let phrase = index.matches(for: "opened early")
        XCTAssertEqual(phrase.count, 1)
        XCTAssertEqual(phrase[0].wordIndex, 2)
        XCTAssertEqual(phrase[0].before, "The café ")
        XCTAssertEqual(phrase[0].after, ". Nobody — not even Alice — came.")
    }

    func testEmptyQueryAndLimit() {
        let index = DocumentSearchIndex(sections: sections)
        XCTAssertTrue(index.matches(for: "   ").isEmpty)
        XCTAssertEqual(index.matches(for: "e", limit: 3).count, 3)
    }

    func testLongContextIsTrimmedAtWordBoundaries() {
        let text = Array(repeating: "filler", count: 30).joined(separator: " ") + " target " + Array(repeating: "tail", count: 30).joined(separator: " ")
        let match = DocumentSearchIndex(sections: [BookSection(title: "Long", text: text)]).matches(for: "target", contextLength: 20)[0]
        XCTAssertTrue(match.before.hasPrefix("…filler"))
        XCTAssertTrue(match.after.hasSuffix("tail…"))
        XCTAssertEqual(match.wordIndex, 30)
    }
}
