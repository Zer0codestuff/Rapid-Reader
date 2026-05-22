import Foundation

public struct ImportedDocument: Sendable {
    public var title: String
    public var author: String?
    public var sourceName: String
    public var sourceURL: String?
    public var format: ReadingFormat
    public var sections: [BookSection]
    public var coverImageData: Data?

    public init(
        title: String,
        author: String? = nil,
        sourceName: String,
        sourceURL: String? = nil,
        format: ReadingFormat,
        sections: [BookSection],
        coverImageData: Data? = nil
    ) {
        self.title = title
        self.author = author
        self.sourceName = sourceName
        self.sourceURL = sourceURL
        self.format = format
        self.sections = sections
        self.coverImageData = coverImageData
    }
}
