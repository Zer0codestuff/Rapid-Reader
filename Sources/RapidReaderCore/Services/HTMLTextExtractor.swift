import AppKit
import Foundation

public enum HTMLTextExtractor {
    public static func plainText(from data: Data, baseURL: URL? = nil) -> String {
        var options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        if let baseURL {
            options[.baseURL] = baseURL
        }

        if let attributed = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
            return TextProcessor.normalizedText(attributed.string)
        }

        let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
        return strippedHTML(html)
    }

    public static func title(fromHTML html: String) -> String? {
        firstMatch(in: html, pattern: #"<title[^>]*>(.*?)</title>"#)
            ?? firstMatch(in: html, pattern: #"<h1[^>]*>(.*?)</h1>"#)
    }

    public static func strippedHTML(_ html: String) -> String {
        var output = html
            .replacingOccurrences(of: #"<script[\s\S]*?</script>"#, with: " ", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"<style[\s\S]*?</style>"#, with: " ", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"<br\s*/?>"#, with: "\n", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"</p>"#, with: "\n\n", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"</h[1-6]>"#, with: "\n\n", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)

        let entities: [(String, String)] = [
            ("&nbsp;", " "),
            ("&amp;", "&"),
            ("&quot;", "\""),
            ("&#39;", "'"),
            ("&lt;", "<"),
            ("&gt;", ">")
        ]
        for (entity, replacement) in entities {
            output = output.replacingOccurrences(of: entity, with: replacement)
        }
        return TextProcessor.normalizedText(output)
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges > 1 else {
            return nil
        }
        guard let swiftRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return strippedHTML(String(text[swiftRange]))
    }
}
