import Foundation
import PDFKit
import UIKit

public enum TextExtractorError: Error {
    case fileNotFound
    case parsingFailed(String)
}

public struct ExtractedBook {
    public let title: String
    public let author: String
    public let content: String
}

public class TextExtractor {
    
    public static func extract(url: URL) throws -> ExtractedBook {
        let extensionLower = url.pathExtension.lowercased()
        
        switch extensionLower {
        case "txt":
            return try extractTxt(url: url)
        case "md", "markdown":
            return try extractMarkdown(url: url)
        case "pdf":
            return try extractPdf(url: url)
        case "docx":
            return try extractDocx(url: url)
        case "epub":
            return try extractEpub(url: url)
        case "rtf":
            return try extractRtf(url: url)
        default:
            throw TextExtractorError.parsingFailed("Unsupported file extension: \(extensionLower)")
        }
    }
    
    private static func extractTxt(url: URL) throws -> ExtractedBook {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let title = url.deletingPathExtension().lastPathComponent
            return ExtractedBook(title: title, author: "Unknown Author", content: content)
        } catch {
            do {
                let content = try String(contentsOf: url, encoding: .ascii)
                let title = url.deletingPathExtension().lastPathComponent
                return ExtractedBook(title: title, author: "Unknown Author", content: content)
            } catch {
                throw TextExtractorError.parsingFailed("Failed to read text file: \(error.localizedDescription)")
            }
        }
    }
    
    private static func extractMarkdown(url: URL) throws -> ExtractedBook {
        let book = try extractTxt(url: url)
        var title = book.title
        var author = "Unknown Author"
        var content = book.content
        
        if content.hasPrefix("---") {
            let lines = content.components(separatedBy: .newlines)
            var yamlEndIndex = -1
            for i in 1..<lines.count {
                if lines[i].hasPrefix("---") {
                    yamlEndIndex = i
                    break
                }
            }
            if yamlEndIndex > 0 {
                for i in 1..<yamlEndIndex {
                    let line = lines[i]
                    if let colonIndex = line.firstIndex(of: ":") {
                        let key = line[..<colonIndex].trimmingCharacters(in: .whitespaces)
                        let val = line[line.index(after: colonIndex)...].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\"", with: "").replacingOccurrences(of: "'", with: "")
                        if key.lowercased() == "title" {
                            title = val
                        } else if key.lowercased() == "author" {
                            author = val
                        }
                    }
                }
                content = lines[(yamlEndIndex + 1)...].joined(separator: "\n")
            }
        }
        
        return ExtractedBook(title: title, author: author, content: content)
    }
    
    private static func extractPdf(url: URL) throws -> ExtractedBook {
        guard let pdfDocument = PDFDocument(url: url) else {
            throw TextExtractorError.parsingFailed("Failed to open PDF document")
        }
        
        var title = url.deletingPathExtension().lastPathComponent
        var author = "Unknown Author"
        
        if let attributes = pdfDocument.documentAttributes {
            if let pdfTitle = attributes[PDFDocumentAttribute.titleAttribute] as? String, !pdfTitle.isEmpty {
                title = pdfTitle
            }
            if let pdfAuthor = attributes[PDFDocumentAttribute.authorAttribute] as? String, !pdfAuthor.isEmpty {
                author = pdfAuthor
            }
        }
        
        var content = ""
        for i in 0..<pdfDocument.pageCount {
            if let page = pdfDocument.page(at: i), let pageText = page.string {
                content += pageText + "\n"
            }
        }
        
        return ExtractedBook(
            title: title,
            author: author,
            content: content.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
    
    private static func extractRtf(url: URL) throws -> ExtractedBook {
        let title = url.deletingPathExtension().lastPathComponent
        guard let data = try? Data(contentsOf: url) else {
            throw TextExtractorError.parsingFailed("Failed to read RTF file data")
        }
        
        let options = [NSAttributedString.DocumentReadingOptionKey.documentType: NSAttributedString.DocumentType.rtf]
        do {
            let attributedString = try NSAttributedString(data: data, options: options, documentAttributes: nil)
            return ExtractedBook(title: title, author: "Unknown Author", content: attributedString.string)
        } catch {
            throw TextExtractorError.parsingFailed("Failed to parse RTF content: \(error.localizedDescription)")
        }
    }
    
    private static func extractDocx(url: URL) throws -> ExtractedBook {
        guard let zip = ZipArchive(url: url) else {
            throw TextExtractorError.parsingFailed("Failed to open DOCX zip container")
        }
        
        guard let documentXmlData = zip.extract(fileName: "word/document.xml") else {
            throw TextExtractorError.parsingFailed("Missing word/document.xml in DOCX")
        }
        
        let title = url.deletingPathExtension().lastPathComponent
        let xmlString = String(data: documentXmlData, encoding: .utf8) ?? ""
        let content = parseDocxXML(xmlString)
        
        return ExtractedBook(title: title, author: "Unknown Author", content: content)
    }
    
    private static func extractEpub(url: URL) throws -> ExtractedBook {
        guard let zip = ZipArchive(url: url) else {
            throw TextExtractorError.parsingFailed("Failed to open EPUB zip container")
        }
        
        guard let containerData = zip.extract(fileName: "META-INF/container.xml") else {
            throw TextExtractorError.parsingFailed("Invalid EPUB: META-INF/container.xml not found")
        }
        
        let containerXml = String(data: containerData, encoding: .utf8) ?? ""
        guard let opfPath = scanAttribute(in: containerXml, tagName: "rootfile", attributeName: "full-path") else {
            throw TextExtractorError.parsingFailed("Could not locate root OPF file in container.xml")
        }
        
        guard let opfData = zip.extract(fileName: opfPath) else {
            throw TextExtractorError.parsingFailed("OPF file not found at path: \(opfPath)")
        }
        
        let opfXml = String(data: opfData, encoding: .utf8) ?? ""
        let title = scanTagContent(in: opfXml, tagName: "dc:title") ?? url.deletingPathExtension().lastPathComponent
        let author = scanTagContent(in: opfXml, tagName: "dc:creator") ?? "Unknown Author"
        
        var manifest: [String: String] = [:]
        var index = opfXml.startIndex
        while let itemRange = opfXml.range(of: "<item ", options: [], range: index..<opfXml.endIndex) {
            guard let closeBracket = opfXml.range(of: ">", range: itemRange.upperBound..<opfXml.endIndex) else { break }
            let itemStr = String(opfXml[itemRange.upperBound..<closeBracket.lowerBound])
            if let id = scanAttributeFromString(itemStr, attributeName: "id"),
               let href = scanAttributeFromString(itemStr, attributeName: "href") {
                manifest[id] = href
            }
            index = closeBracket.upperBound
        }
        
        var spineIds: [String] = []
        index = opfXml.startIndex
        while let itemRefRange = opfXml.range(of: "<itemref ", options: [], range: index..<opfXml.endIndex) {
            guard let closeBracket = opfXml.range(of: ">", range: itemRefRange.upperBound..<opfXml.endIndex) else { break }
            let itemRefStr = String(opfXml[itemRefRange.upperBound..<closeBracket.lowerBound])
            if let idref = scanAttributeFromString(itemRefStr, attributeName: "idref") {
                spineIds.append(idref)
            }
            index = closeBracket.upperBound
        }
        
        let opfDir: String
        if let lastSlash = opfPath.firstIndex(of: "/") {
            opfDir = String(opfPath[..<opfPath.index(after: lastSlash)])
        } else {
            opfDir = ""
        }
        
        var fullText = ""
        for spineId in spineIds {
            guard let relHref = manifest[spineId] else { continue }
            let cleanRelHref = relHref.components(separatedBy: "#")[0].components(separatedBy: "?")[0]
            let decodedRelHref = cleanRelHref.removingPercentEncoding ?? cleanRelHref
            let fullHref = opfDir + decodedRelHref
            
            if let chapterData = zip.extract(fileName: fullHref) {
                let chapterHtml = String(data: chapterData, encoding: .utf8) ?? ""
                let chapterText = cleanHTML(chapterHtml)
                if !chapterText.isEmpty {
                    fullText += chapterText + "\n\n"
                }
            }
        }
        
        if fullText.isEmpty {
            for fileName in zip.fileNames.sorted() {
                let lower = fileName.lowercased()
                if lower.hasSuffix(".xhtml") || lower.hasSuffix(".html") {
                    if let chapterData = zip.extract(fileName: fileName) {
                        let html = String(data: chapterData, encoding: .utf8) ?? ""
                        fullText += cleanHTML(html) + "\n\n"
                    }
                }
            }
        }
        
        return ExtractedBook(
            title: title,
            author: author,
            content: fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
    
    private static func cleanHTML(_ html: String) -> String {
        var bodyContent = html
        if let bodyStart = html.range(of: "<body", options: .caseInsensitive),
           let bodyStartClose = html.range(of: ">", range: bodyStart.upperBound..<html.endIndex),
           let bodyEnd = html.range(of: "</body>", options: .caseInsensitive) {
            bodyContent = String(html[bodyStartClose.upperBound..<bodyEnd.lowerBound])
        }
        
        var text = bodyContent
        text = replaceTag(text, tag: "h1", replacementStart: "\n# ", replacementEnd: "\n")
        text = replaceTag(text, tag: "h2", replacementStart: "\n## ", replacementEnd: "\n")
        text = replaceTag(text, tag: "h3", replacementStart: "\n### ", replacementEnd: "\n")
        text = replaceTag(text, tag: "h4", replacementStart: "\n#### ", replacementEnd: "\n")
        text = replaceTag(text, tag: "p", replacementStart: "", replacementEnd: "\n\n")
        text = replaceTag(text, tag: "div", replacementStart: "", replacementEnd: "\n")
        text = text.replacingOccurrences(of: "<br/>", with: "\n", options: .caseInsensitive)
        text = text.replacingOccurrences(of: "<br />", with: "\n", options: .caseInsensitive)
        text = text.replacingOccurrences(of: "<br>", with: "\n", options: .caseInsensitive)
        text = replaceTag(text, tag: "em", replacementStart: "*", replacementEnd: "*")
        text = replaceTag(text, tag: "i", replacementStart: "*", replacementEnd: "*")
        text = replaceTag(text, tag: "strong", replacementStart: "**", replacementEnd: "**")
        text = replaceTag(text, tag: "b", replacementStart: "**", replacementEnd: "**")
        
        var cleanText = ""
        var inTag = false
        for char in text {
            if char == "<" {
                inTag = true
            } else if char == ">" && inTag {
                inTag = false
            } else if !inTag {
                cleanText.append(char)
            }
        }
        
        cleanText = decodeHTMLEntities(cleanText)
        var formattedLines: [String] = []
        let lines = cleanText.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                formattedLines.append(trimmed)
            } else if formattedLines.last != "" {
                formattedLines.append("")
            }
        }
        
        return formattedLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private static func replaceTag(_ text: String, tag: String, replacementStart: String, replacementEnd: String) -> String {
        var result = text
        let openTag = "<\(tag)"
        let closeTag = "</\(tag)>"
        
        var index = result.startIndex
        while let openRange = result.range(of: openTag, options: .caseInsensitive, range: index..<result.endIndex) {
            guard let bracketRange = result.range(of: ">", range: openRange.upperBound..<result.endIndex) else { break }
            guard let closeRange = result.range(of: closeTag, options: .caseInsensitive, range: bracketRange.upperBound..<result.endIndex) else {
                index = bracketRange.upperBound
                continue
            }
            
            let tagContent = result[bracketRange.upperBound..<closeRange.lowerBound]
            let replaced = replacementStart + tagContent + replacementEnd
            result.replaceSubrange(openRange.lowerBound..<closeRange.upperBound, with: replaced)
            index = result.index(openRange.lowerBound, offsetBy: replaced.count, limitedBy: result.endIndex) ?? result.endIndex
        }
        return result
    }
    
    private static func decodeHTMLEntities(_ text: String) -> String {
        var result = text
        let entities = [
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&apos;": "'",
            "&#39;": "'",
            "&nbsp;": " ",
            "&ldquo;": "\"",
            "&rdquo;": "\"",
            "&lsquo;": "'",
            "&rsquo;": "'",
            "&mdash;": "—",
            "&ndash;": "–",
            "&middot;": "·"
        ]
        for (entity, char) in entities {
            result = result.replacingOccurrences(of: entity, with: char)
        }
        
        var index = result.startIndex
        while let ampRange = result.range(of: "&#x", range: index..<result.endIndex) {
            if let semiRange = result.range(of: ";", range: ampRange.upperBound..<result.endIndex) {
                let hexStr = String(result[ampRange.upperBound..<semiRange.lowerBound])
                if let hexVal = UInt32(hexStr, radix: 16), let unicodeChar = UnicodeScalar(hexVal) {
                    result.replaceSubrange(ampRange.lowerBound..<semiRange.upperBound, with: String(unicodeChar))
                    index = ampRange.lowerBound
                    continue
                }
            }
            index = ampRange.upperBound
        }
        
        index = result.startIndex
        while let ampRange = result.range(of: "&#", range: index..<result.endIndex) {
            if let semiRange = result.range(of: ";", range: ampRange.upperBound..<result.endIndex) {
                let decStr = String(result[ampRange.upperBound..<semiRange.lowerBound])
                if let decVal = UInt32(decStr), let unicodeChar = UnicodeScalar(decVal) {
                    result.replaceSubrange(ampRange.lowerBound..<semiRange.upperBound, with: String(unicodeChar))
                    index = ampRange.lowerBound
                    continue
                }
            }
            index = ampRange.upperBound
        }
        
        return result
    }
    
    private static func parseDocxXML(_ xmlString: String) -> String {
        var result = ""
        var pIndex = xmlString.startIndex
        while let pStartRange = xmlString.range(of: "<w:p", range: pIndex..<xmlString.endIndex) {
            guard let pCloseBracket = xmlString.range(of: ">", range: pStartRange.upperBound..<xmlString.endIndex) else { break }
            guard let pEndRange = xmlString.range(of: "</w:p>", range: pCloseBracket.upperBound..<xmlString.endIndex) else { break }
            
            let paragraphXml = String(xmlString[pCloseBracket.upperBound..<pEndRange.lowerBound])
            let pText = parseDocxParagraph(paragraphXml)
            if !pText.isEmpty {
                result += pText + "\n\n"
            }
            pIndex = pEndRange.upperBound
        }
        return decodeHTMLEntities(result).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private static func parseDocxParagraph(_ pXml: String) -> String {
        var paragraphText = ""
        var rIndex = pXml.startIndex
        while let rStartRange = pXml.range(of: "<w:r", range: rIndex..<pXml.endIndex) {
            guard let rCloseBracket = pXml.range(of: ">", range: rStartRange.upperBound..<pXml.endIndex) else { break }
            guard let rEndRange = pXml.range(of: "</w:r>", range: rCloseBracket.upperBound..<pXml.endIndex) else { break }
            
            let runXml = String(pXml[rCloseBracket.upperBound..<rEndRange.lowerBound])
            var isBold = false
            var isItalic = false
            if let rPrStart = runXml.range(of: "<w:rPr") {
                if let rPrEnd = runXml.range(of: "</w:rPr>", range: rPrStart.upperBound..<runXml.endIndex) {
                    let rPrContent = runXml[rPrStart.upperBound..<rPrEnd.lowerBound]
                    isBold = rPrContent.contains("<w:b/>") || rPrContent.contains("<w:b ")
                    isItalic = rPrContent.contains("<w:i/>") || rPrContent.contains("<w:i ")
                } else if let rPrSelfClose = runXml.range(of: "/>", range: rPrStart.upperBound..<runXml.endIndex) {
                    let rPrContent = runXml[rPrStart.upperBound..<rPrSelfClose.lowerBound]
                    isBold = rPrContent.contains("<w:b/>") || rPrContent.contains("<w:b ")
                    isItalic = rPrContent.contains("<w:i/>") || rPrContent.contains("<w:i ")
                }
            }
            
            var runText = ""
            var tIndex = runXml.startIndex
            while let tStartRange = runXml.range(of: "<w:t", range: tIndex..<runXml.endIndex) {
                guard let tCloseBracket = runXml.range(of: ">", range: tStartRange.upperBound..<runXml.endIndex) else { break }
                guard let tEndRange = runXml.range(of: "</w:t>", range: tCloseBracket.upperBound..<runXml.endIndex) else { break }
                
                runText += String(runXml[tCloseBracket.upperBound..<tEndRange.lowerBound])
                tIndex = tEndRange.upperBound
            }
            
            if !runText.isEmpty {
                if isBold && isItalic {
                    paragraphText += "***" + runText + "***"
                } else if isBold {
                    paragraphText += "**" + runText + "**"
                } else if isItalic {
                    paragraphText += "*" + runText + "*"
                } else {
                    paragraphText += runText
                }
            }
            rIndex = rEndRange.upperBound
        }
        return paragraphText.trimmingCharacters(in: .whitespaces)
    }
    
    private static func scanTagContent(in xml: String, tagName: String) -> String? {
        let openTag = "<\(tagName)"
        let closeTag = "</\(tagName)>"
        guard let openRange = xml.range(of: openTag) else { return nil }
        guard let closeBracket = xml.range(of: ">", range: openRange.upperBound..<xml.endIndex) else { return nil }
        guard let closeRange = xml.range(of: closeTag, range: closeBracket.upperBound..<xml.endIndex) else { return nil }
        return String(xml[closeBracket.upperBound..<closeRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private static func scanAttribute(in xml: String, tagName: String, attributeName: String) -> String? {
        let openTag = "<\(tagName) "
        guard let openRange = xml.range(of: openTag) else { return nil }
        guard let closeBracket = xml.range(of: ">", range: openRange.upperBound..<xml.endIndex) else { return nil }
        let tagContents = String(xml[openRange.upperBound..<closeBracket.lowerBound])
        return scanAttributeFromString(tagContents, attributeName: attributeName)
    }
    
    private static func scanAttributeFromString(_ attributesStr: String, attributeName: String) -> String? {
        let search = "\(attributeName)="
        guard let nameRange = attributesStr.range(of: search) else { return nil }
        
        let afterName = attributesStr[nameRange.upperBound...]
        guard afterName.count >= 2 else { return nil }
        
        let quote = afterName.first!
        guard quote == "\"" || quote == "'" else { return nil }
        
        let valueStart = afterName.index(afterName.startIndex, offsetBy: 1)
        guard let valueEnd = afterName[valueStart...].firstIndex(of: quote) else { return nil }
        
        return String(afterName[valueStart..<valueEnd])
    }
}
