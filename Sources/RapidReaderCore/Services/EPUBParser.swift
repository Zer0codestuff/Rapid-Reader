import Foundation
import ZIPFoundation

public enum EPUBParser {
    public static func importEPUB(at url: URL) throws -> ImportedDocument {
        let archive = try Archive(url: url, accessMode: .read)

        let containerData = try dataFromArchive(archive, path: "META-INF/container.xml")
        let container = ContainerXMLParser.parse(containerData)
        guard let opfPath = container.rootFilePath else {
            throw DocumentImportError.unreadableFile(url.lastPathComponent)
        }

        let opfData = try dataFromArchive(archive, path: opfPath)
        let package = OPFXMLParser.parse(opfData)
        let opfDirectory = (opfPath as NSString).deletingLastPathComponent

        let spineItems = package.spine.compactMap { idRef -> OPFManifestItem? in
            package.manifest[idRef]
        }

        var sections: [BookSection] = []
        for (index, item) in spineItems.enumerated() {
            guard item.mediaType.contains("html") || item.href.lowercased().hasSuffix(".xhtml") || item.href.lowercased().hasSuffix(".html") else {
                continue
            }

            let itemPath = resolvedArchivePath(baseDirectory: opfDirectory, href: item.href)
            guard let htmlData = try? dataFromArchive(archive, path: itemPath) else {
                continue
            }

            let html = String(data: htmlData, encoding: .utf8) ?? ""
            let title = TextProcessor.cleanedTitle(
                HTMLTextExtractor.title(fromHTML: html),
                fallback: item.title ?? "Section \(index + 1)"
            )
            let text = HTMLTextExtractor.plainText(from: htmlData)
            let section = BookSection(title: title, text: text)
            if section.wordCount > 0 {
                sections.append(section)
            }
        }

        guard !sections.isEmpty else {
            throw DocumentImportError.emptyDocument(url.lastPathComponent)
        }

        let coverImageData = coverData(from: package, archive: archive, opfDirectory: opfDirectory)
        let fallbackTitle = url.deletingPathExtension().lastPathComponent
        return ImportedDocument(
            title: TextProcessor.cleanedTitle(package.title, fallback: fallbackTitle),
            author: package.creator,
            sourceName: url.lastPathComponent,
            sourceURL: url.absoluteString,
            format: .epub,
            sections: sections,
            coverImageData: coverImageData
        )
    }

    private static func dataFromArchive(_ archive: Archive, path: String) throws -> Data {
        let normalizedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let entry = archive[normalizedPath] else {
            throw DocumentImportError.unreadableFile(path)
        }

        var data = Data()
        _ = try archive.extract(entry) { chunk in
            data.append(chunk)
        }
        return data
    }

    private static func resolvedArchivePath(baseDirectory: String, href: String) -> String {
        let decodedHref = href.removingPercentEncoding ?? href
        let joined: String
        if baseDirectory.isEmpty || baseDirectory == "." {
            joined = decodedHref
        } else {
            joined = "\(baseDirectory)/\(decodedHref)"
        }

        let parts = joined.split(separator: "/").reduce(into: [String]()) { result, part in
            if part == "." {
                return
            }
            if part == ".." {
                _ = result.popLast()
            } else {
                result.append(String(part))
            }
        }
        return parts.joined(separator: "/")
    }

    private static func coverData(from package: OPFPackage, archive: Archive, opfDirectory: String) -> Data? {
        let explicitCover = package.coverID.flatMap { package.manifest[$0] }
        let propertyCover = package.manifest.values.first { item in
            item.properties.contains("cover-image")
        }
        let namedCover = package.manifest.values.first { item in
            let lowercasedID = item.id.lowercased()
            let lowercasedHref = item.href.lowercased()
            return item.mediaType.lowercased().hasPrefix("image/")
                && (lowercasedID.contains("cover") || lowercasedHref.contains("cover"))
        }

        guard let item = explicitCover ?? propertyCover ?? namedCover else {
            return nil
        }

        let itemPath = resolvedArchivePath(baseDirectory: opfDirectory, href: item.href)
        return try? dataFromArchive(archive, path: itemPath)
    }
}

private struct EPUBContainer {
    var rootFilePath: String?
}

private enum ContainerXMLParser {
    static func parse(_ data: Data) -> EPUBContainer {
        let delegate = ContainerDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        _ = parser.parse()
        return EPUBContainer(rootFilePath: delegate.rootFilePath)
    }
}

private final class ContainerDelegate: NSObject, XMLParserDelegate {
    var rootFilePath: String?

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        if elementName == "rootfile" {
            rootFilePath = attributeDict["full-path"]
        }
    }
}

private struct OPFManifestItem {
    var id: String
    var href: String
    var mediaType: String
    var title: String?
    var properties: Set<String>
}

private struct OPFPackage {
    var title: String?
    var creator: String?
    var coverID: String?
    var manifest: [String: OPFManifestItem]
    var spine: [String]
}

private enum OPFXMLParser {
    static func parse(_ data: Data) -> OPFPackage {
        let delegate = OPFDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        _ = parser.parse()
        return OPFPackage(
            title: delegate.title,
            creator: delegate.creator,
            coverID: delegate.coverID,
            manifest: delegate.manifest,
            spine: delegate.spine
        )
    }
}

private final class OPFDelegate: NSObject, XMLParserDelegate {
    var title: String?
    var creator: String?
    var coverID: String?
    var manifest: [String: OPFManifestItem] = [:]
    var spine: [String] = []

    private var currentElement: String?
    private var buffer = ""

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let localName = elementName.components(separatedBy: ":").last ?? elementName
        currentElement = localName
        buffer = ""

        if localName == "item",
           let id = attributeDict["id"],
           let href = attributeDict["href"] {
            manifest[id] = OPFManifestItem(
                id: id,
                href: href,
                mediaType: attributeDict["media-type"] ?? "",
                title: attributeDict["title"],
                properties: Set((attributeDict["properties"] ?? "").split(separator: " ").map(String.init))
            )
        }

        if localName == "itemref", let idRef = attributeDict["idref"] {
            spine.append(idRef)
        }

        if localName == "meta",
           attributeDict["name"] == "cover",
           let content = attributeDict["content"] {
            coverID = content
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        buffer.append(string)
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let localName = elementName.components(separatedBy: ":").last ?? elementName
        let cleaned = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        if localName == "title", title == nil, !cleaned.isEmpty {
            title = cleaned
        } else if localName == "creator", creator == nil, !cleaned.isEmpty {
            creator = cleaned
        }
        currentElement = nil
        buffer = ""
    }
}
