import Foundation
import SwiftSoup

/// Parses text without WebKit, remote resource loading, or main-thread AppKit calls.
public enum HTMLTextExtractor {
    public static func plainText(from data: Data, baseURL: URL? = nil) -> String {
        strippedHTML(decode(data))
    }

    public static func decode(_ data: Data) -> String {
        String(data: data, encoding: .utf8) ?? String(data: data, encoding: .windowsCP1252)
            ?? String(data: data, encoding: .isoLatin1) ?? ""
    }

    public static func title(fromHTML html: String) -> String? {
        guard let document = try? SwiftSoup.parse(html) else { return nil }
        let title = (try? document.title()) ?? ""
        return title.isEmpty ? try? document.select("h1").first()?.text() : title
    }

    public static func strippedHTML(_ html: String) -> String {
        guard let document = try? SwiftSoup.parse(html) else { return "" }
        clean(document, article: false)
        return text(from: document.body() ?? document)
    }

    public static func articleText(_ html: String) -> String {
        guard let document = try? SwiftSoup.parse(html) else { return "" }
        clean(document, article: true)
        for selector in ["#mw-content-text .mw-parser-output", "article", "main", "[role=main]"] {
            if let candidates = try? document.select(selector),
               let best = candidates.array().max(by: { score($0) < score($1) }), score(best) > 0 {
                return text(from: best)
            }
        }
        // Prefer the container with the most prose and the lowest link density.
        if let containers = try? document.select("div, section"),
           let best = containers.array().max(by: { score($0) < score($1) }), score(best) > 200 {
            return text(from: best)
        }
        return text(from: document.body() ?? document)
    }

    private static func score(_ element: Element) -> Int {
        let prose = (try? element.select("p").array().reduce(0) { $0 + (try $1.text()).count }) ?? 0
        let links = (try? element.select("a").text().count) ?? 0
        let all = (try? element.text().count) ?? 0
        return max(prose, all / 3) - links * 2
    }

    private static func clean(_ document: Document, article: Bool) {
        _ = try? document.select("script, style, noscript, template, svg, [hidden], [aria-hidden=true]").remove()
        if article {
            _ = try? document.select("nav, footer, aside, form, button, [role=navigation], .mw-editsection, .reference, .navbox, .reflist, .sidebar, .advertisement, .cookie-banner").remove()
        }
    }

    static func text(from node: Node) -> String {
        var output = ""
        appendText(node, to: &output)
        return TextProcessor.normalizedText(output)
    }

    private static func appendText(_ node: Node, to output: inout String) {
        if let text = node as? TextNode {
            output += text.getWholeText()
            return
        }
        let name = (node as? Element)?.tagName() ?? ""
        let isBlock = ["p", "div", "section", "article", "li", "tr", "h1", "h2", "h3", "h4", "h5", "h6", "blockquote", "pre", "br", "hr"].contains(name)
        if isBlock { output += "\n" }
        for child in node.getChildNodes() { appendText(child, to: &output) }
        if isBlock { output += "\n" }
        if name == "td" || name == "th" { output += " " }
    }
}
