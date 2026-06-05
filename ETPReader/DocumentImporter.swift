import Foundation
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - UTType Extensions
extension UTType {
    public static var epub: UTType {
        UTType("org.idpf.epub-container") ?? UTType(filenameExtension: "epub") ?? .data
    }
    
    public static var docx: UTType {
        UTType("org.openxmlformats.wordprocessingml.document") ?? UTType(filenameExtension: "docx") ?? .data
    }
    
    public static var markdown: UTType {
        UTType("net.daringfireball.markdown") ?? UTType(filenameExtension: "md") ?? .plainText
    }
}

public class DocumentImporter {
    
    public static let allowedContentTypes: [UTType] = [
        .pdf,
        .plainText,
        .epub,
        .docx,
        .markdown
    ]
    
    @MainActor
    public static func importFile(from url: URL, into modelContext: ModelContext) async throws -> Document {
        // Security-scoped access is required for files imported via UIDocumentPickerViewController / fileImporter
        guard url.startAccessingSecurityScopedResource() else {
            throw TextExtractorError.parsingFailed("Failed to access security-scoped URL resource.")
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        // Read file contents on a background Task to prevent blocking the UI
        let fileExtension = url.pathExtension.lowercased()
        
        // We copy the file to a temporary local workspace directory to perform secure extraction
        let tempDir = FileManager.default.temporaryDirectory
        let tempFileUrl = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension(fileExtension)
        
        try FileManager.default.copyItem(at: url, to: tempFileUrl)
        
        defer {
            try? FileManager.default.removeItem(at: tempFileUrl)
        }
        
        // Extract the content
        let extractedBook = try await Task.detached(priority: .userInitiated) {
            return try TextExtractor.extract(url: tempFileUrl)
        }.value
        
        // Create the SwiftData entities on the MainActor
        let document = Document(
            title: extractedBook.title,
            author: extractedBook.author,
            rawText: extractedBook.content,
            fileType: fileExtension
        )
        
        let progress = ReadingProgress(
            currentSentenceIndex: 0,
            currentWordIndex: 0,
            scrollOffset: 0.0
        )
        
        modelContext.insert(document)
        modelContext.insert(progress)
        
        document.readingProgress = progress
        progress.document = document
        
        try modelContext.save()
        return document
    }
}
