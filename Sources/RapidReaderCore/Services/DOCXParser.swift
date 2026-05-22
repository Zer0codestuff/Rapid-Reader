import Foundation
import ZIPFoundation

public enum DOCXParser {
    public static func importDOCX(at url: URL) throws -> ImportedDocument {
        let archive = try Archive(url: url, accessMode: .read)
        guard let entry = archive["word/document.xml"] else {
            throw DocumentImportError.unreadableFile(url.lastPathComponent)
        }

        var data = Data()
        _ = try archive.extract(entry) { chunk in
            data.append(chunk)
        }

        let parserDelegate = WordDocumentXMLParser()
        let parser = XMLParser(data: data)
        parser.delegate = parserDelegate
        guard parser.parse() else {
            throw DocumentImportError.unreadableFile(url.lastPathComponent)
        }

        let text = TextProcessor.normalizedText(parserDelegate.output)
        guard !text.isEmpty else {
            throw DocumentImportError.emptyDocument(url.lastPathComponent)
        }

        let fallbackTitle = url.deletingPathExtension().lastPathComponent
        return ImportedDocument(
            title: fallbackTitle,
            sourceName: url.lastPathComponent,
            sourceURL: url.absoluteString,
            format: .docx,
            sections: TextProcessor.sections(from: text, fallbackTitle: fallbackTitle)
        )
    }
}

private final class WordDocumentXMLParser: NSObject, XMLParserDelegate {
    private(set) var output = ""
    private var isReadingText = false

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch elementName {
        case "w:t", "t":
            isReadingText = true
        case "w:tab", "tab":
            output.append(" ")
        case "w:br", "br":
            output.append("\n")
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard isReadingText else { return }
        output.append(string)
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        switch elementName {
        case "w:t", "t":
            isReadingText = false
        case "w:p", "p":
            output.append("\n\n")
        default:
            break
        }
    }
}
