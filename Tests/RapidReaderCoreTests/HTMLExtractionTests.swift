import XCTest
@testable import RapidReaderCore

final class HTMLExtractionTests: XCTestCase {
    func testArticleKeepsNestedProseAndRemovesNavigation() {
        let html = "<nav>Search Donate</nav><main><article><h1>Title</h1><p>First <b>bold</b> paragraph &amp; café.</p><aside>Buy now</aside><div><p>Second paragraph.</p></div><script>bad()</script></article></main><footer>Account</footer>"
        XCTAssertEqual(HTMLTextExtractor.articleText(html), "Title\n\nFirst bold paragraph & café.\n\nSecond paragraph.")
    }

    func testHTMLPreservesInlineWordsEntitiesAndParagraphs() {
        XCTAssertEqual(HTMLTextExtractor.strippedHTML("<p>inter<b>national</b> &#x6771;&#20140;</p><p>Next&nbsp;line</p>"), "international 東京\n\nNext line")
    }

    func testWikipediaContentSkipsChrome() {
        let html = "<header>Login</header><div id='mw-content-text'><div class='mw-parser-output'><p>The article text.</p><span class='mw-editsection'>Edit</span><table class='navbox'><tr><td>Navigation</td></tr></table></div></div>"
        XCTAssertEqual(HTMLTextExtractor.articleText(html), "The article text.")
    }
}
