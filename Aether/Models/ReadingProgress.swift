import Foundation
import SwiftData

@Model
public final class ReadingProgress {
    @Attribute(.unique) public var id: UUID
    public var currentSentenceIndex: Int
    public var currentWordIndex: Int
    public var scrollOffset: Double
    public var document: Document?
    
    public init(id: UUID = UUID(), currentSentenceIndex: Int = 0, currentWordIndex: Int = 0, scrollOffset: Double = 0.0) {
        self.id = id
        self.currentSentenceIndex = currentSentenceIndex
        self.currentWordIndex = currentWordIndex
        self.scrollOffset = scrollOffset
    }
}
