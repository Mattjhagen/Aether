import Foundation
import SwiftData

@Model
public final class Document {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var author: String
    @Attribute(.externalStorage) public var rawText: String
    public var fileType: String
    public var dateImported: Date
    public var dateLastRead: Date?
    public var isFavorite: Bool
    public var durationSeconds: Double
    
    @Relationship(deleteRule: .cascade, inverse: \Highlight.document)
    public var highlights: [Highlight]
    
    @Relationship(deleteRule: .cascade, inverse: \ReadingProgress.document)
    public var readingProgress: ReadingProgress?
    
    public init(id: UUID = UUID(), title: String, author: String, rawText: String, fileType: String, dateImported: Date = Date(), isFavorite: Bool = false) {
        self.id = id
        self.title = title.isEmpty ? "Untitled Document" : title
        self.author = author.isEmpty ? "Unknown Author" : author
        self.rawText = rawText
        self.fileType = fileType
        self.dateImported = dateImported
        self.dateLastRead = nil
        self.isFavorite = isFavorite
        self.highlights = []
        self.readingProgress = nil
        
        // Estimate reading time: ~200 words per minute (average reading speed).
        // 200 WPM / 60 seconds = 3.33 words per second.
        let words = rawText.split { $0.isWhitespace }
        let wordCount = words.isEmpty ? 1 : words.count
        self.durationSeconds = Double(wordCount) / (200.0 / 60.0)
    }
}

@Model
public final class Highlight {
    @Attribute(.unique) public var id: UUID
    public var sentenceIndex: Int
    public var startOffset: Int
    public var endOffset: Int
    public var text: String
    public var colorCode: String
    public var dateCreated: Date
    public var document: Document?
    
    public init(id: UUID = UUID(), sentenceIndex: Int, startOffset: Int, endOffset: Int, text: String, colorCode: String = "gray", dateCreated: Date = Date()) {
        self.id = id
        self.sentenceIndex = sentenceIndex
        self.startOffset = startOffset
        self.endOffset = endOffset
        self.text = text
        self.colorCode = colorCode
        self.dateCreated = dateCreated
    }
}
