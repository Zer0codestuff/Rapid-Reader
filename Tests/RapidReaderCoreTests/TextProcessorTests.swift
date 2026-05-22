import XCTest
@testable import RapidReaderCore

final class TextProcessorTests: XCTestCase {
    func testSectionsSplitMarkdownHeadings() {
        let text = """
        # Opening
        One two three.

        ## Middle
        Four five six.
        """

        let sections = TextProcessor.sections(from: text, fallbackTitle: "Fallback")

        XCTAssertEqual(sections.count, 2)
        XCTAssertEqual(sections[0].title, "Opening")
        XCTAssertEqual(sections[1].title, "Middle")
        XCTAssertEqual(sections[0].wordCount, 3)
    }

    func testRSVPPivot() {
        let word = RSVPWord("reading")
        let split = word.splitForDisplay

        XCTAssertEqual(split.prefix, "re")
        XCTAssertEqual(split.pivot, "a")
        XCTAssertEqual(split.suffix, "ding")
    }

    func testObjectReplacementCharactersAreNotReadableWords() {
        XCTAssertEqual(TextProcessor.tokenize("\u{fffc}"), [])
        XCTAssertEqual(TextProcessor.normalizedText("Alpha \u{fffc} beta"), "Alpha beta")
        XCTAssertEqual(TextProcessor.tokenize("Alpha \u{fffc} beta"), ["Alpha", "beta"])
    }
}
