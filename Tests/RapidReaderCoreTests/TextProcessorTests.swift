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

    func testTokenRangesMatchRSVPWithUnicodeAndSeparators() {
        let input = "Alpha \u{2014} *** … café 👩🏽‍💻 東京\u{00a0}beta\u{200b}gamma"
        let tokenized = TextProcessor.tokenizedText(input)
        XCTAssertEqual(tokenized.tokens.map(\.text), TextProcessor.tokenize(input))
        XCTAssertEqual(tokenized.tokens.map(\.text), ["Alpha", "café", "東京", "beta", "gamma"])
        let source = tokenized.text as NSString
        for token in tokenized.tokens {
            XCTAssertEqual(source.substring(with: token.range), token.text)
        }
        XCTAssertEqual(RSVPWord("Hello!\"").punctuationDelayMultiplier, 1.8)
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
