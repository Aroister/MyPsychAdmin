//
//  DOCXExporter.swift
//  MyPsychAdmin
//
//  Template-based DOCX Export Service for statutory forms
//  Modifies official form templates by paragraph index to ensure authenticity
//

import Foundation
import UIKit
import Compression

// MARK: - Template-Based DOCX Exporter

/// Constants for bracket styling (matches desktop gold brackets)
private let kGoldBracketColor = "918C0D"  // Gold color for brackets
private let kCreamHighlightColor = "FFFED5"  // Cream background color

class TemplateDOCXExporter {

    private var documentXML: String = ""

    // MARK: - Bracket Styling Helpers

    /// Get Arial font XML element
    private var arialFont: String {
        "<w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\" w:cs=\"Arial\"/>"
    }

    /// Get run properties for gold bold brackets with cream background
    private var bracketRPr: String {
        "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:b/><w:color w:val=\"\(kGoldBracketColor)\"/><w:sz w:val=\"28\"/><w:szCs w:val=\"28\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"
    }

    /// Get run properties for content with cream background (no bold, no gold)
    private var contentRPr: String {
        "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"
    }

    /// Get run properties for plain text (no highlight)
    private var plainRPr: String {
        "<w:rPr>\(arialFont)</w:rPr>"
    }

    /// Create a bracketed run with gold brackets and cream-highlighted content
    /// - Parameter content: The content to place between brackets
    /// - Returns: XML string with three runs: gold "[", content, gold "]"
    private func bracketedRun(_ content: String) -> String {
        let escapedContent = escapeXML(content)
        return "<w:r>\(bracketRPr)<w:t>[</w:t></w:r><w:r>\(contentRPr)<w:t xml:space=\"preserve\">\(escapedContent)</w:t></w:r><w:r>\(bracketRPr)<w:t>]</w:t></w:r>"
    }
    private var zipEntries: [(name: String, data: Data)] = []
    private let templateName: String

    init(templateName: String) {
        self.templateName = templateName
    }

    // MARK: - Load Template

    func loadTemplate() -> Bool {
        guard let templateURL = Bundle.main.url(forResource: templateName, withExtension: "docx", subdirectory: "Templates") else {
            print("Template not found: \(templateName).docx")
            return false
        }

        guard let templateData = try? Data(contentsOf: templateURL) else {
            print("Failed to read template data")
            return false
        }

        // Parse ZIP and extract all entries
        guard let entries = extractZipEntries(from: templateData) else {
            print("Failed to extract ZIP entries")
            return false
        }

        zipEntries = entries

        // Find and store document.xml
        if let docEntry = entries.first(where: { $0.name == "word/document.xml" }),
           let xmlString = String(data: docEntry.data, encoding: .utf8) {
            documentXML = xmlString
            return true
        }

        print("document.xml not found in template")
        return false
    }

    // MARK: - Paragraph Operations

    /// Get all paragraph elements from document.xml
    func getParagraphs() -> [(range: Range<String.Index>, content: String)] {
        var paragraphs: [(range: Range<String.Index>, content: String)] = []
        var searchStart = documentXML.startIndex

        // Find paragraph starts - must be <w:p> or <w:p followed by space (for attributes)
        // This avoids matching <w:pPr>, <w:permStart>, etc.
        while searchStart < documentXML.endIndex {
            // Find next potential paragraph start
            guard let potentialStart = documentXML.range(of: "<w:p", range: searchStart..<documentXML.endIndex) else {
                break
            }

            // Check if this is actually a paragraph tag (not <w:pPr>, <w:permStart>, etc.)
            let afterTag = potentialStart.upperBound
            guard afterTag < documentXML.endIndex else { break }

            let nextChar = documentXML[afterTag]

            // Valid paragraph starts are <w:p> or <w:p (with space for attributes)
            if nextChar != ">" && nextChar != " " {
                // This is <w:pPr>, <w:permStart>, etc. - skip it
                searchStart = afterTag
                continue
            }

            // Check if this is a self-closing paragraph <w:p/>
            if nextChar == "/" {
                searchStart = afterTag
                continue
            }

            // Find the closing </w:p> - simple approach since templates don't have deeply nested paragraphs
            if let endRange = documentXML.range(of: "</w:p>", range: afterTag..<documentXML.endIndex) {
                let fullRange = potentialStart.lowerBound..<endRange.upperBound
                let content = String(documentXML[fullRange])
                paragraphs.append((range: fullRange, content: content))
                searchStart = endRange.upperBound
            } else {
                break
            }
        }

        return paragraphs
    }

    /// Set text of a paragraph at given index (replaces all text runs)
    /// When highlight=true, uses gold brackets with cream highlight (matches desktop styling)
    /// - Parameters:
    ///   - index: Paragraph index
    ///   - text: Text to set
    ///   - highlight: Whether to apply gold brackets with cream highlight (default: false - set to true for form fields)
    func setParagraphText(at index: Int, text: String, highlight: Bool = false, spacingAfter: Int = 0) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        var modifiedContent = para.content

        // Use 40 spaces for empty placeholder
        let displayText = text.isEmpty ? "                                        " : text

        // Extract pPr if exists, or create one with spacing
        var pPrContent = ""
        if let pPrStart = modifiedContent.range(of: "<w:pPr>"),
           let pPrEnd = modifiedContent.range(of: "</w:pPr>", range: pPrStart.upperBound..<modifiedContent.endIndex) {
            pPrContent = String(modifiedContent[pPrStart.lowerBound..<pPrEnd.upperBound])
            // Add spacing if requested
            if spacingAfter > 0 {
                pPrContent = pPrContent.replacingOccurrences(of: "</w:pPr>", with: "<w:spacing w:after=\"\(spacingAfter)\"/></w:pPr>")
            }
        } else if spacingAfter > 0 {
            // Create pPr with spacing
            pPrContent = "<w:pPr><w:spacing w:after=\"\(spacingAfter)\"/></w:pPr>"
        }

        // Build runs with gold brackets and cream highlighted content
        let goldBracketRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:b/><w:color w:val=\"\(kGoldBracketColor)\"/><w:sz w:val=\"28\"/><w:szCs w:val=\"28\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"
        let contentRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"

        // Split text by newlines and create runs with line breaks
        let lines = displayText.components(separatedBy: "\n")
        var contentRuns = ""
        for (idx, line) in lines.enumerated() {
            let escapedLine = escapeXML(line)
            contentRuns += "<w:t xml:space=\"preserve\">\(escapedLine)</w:t>"
            if idx < lines.count - 1 {
                contentRuns += "<w:br/>"
            }
        }

        var newRuns: String
        if highlight {
            // Gold brackets with cream highlighted content (line breaks inside)
            newRuns = "<w:r>\(goldBracketRPr)<w:t>[</w:t></w:r><w:r>\(contentRPr)\(contentRuns)</w:r><w:r>\(goldBracketRPr)<w:t>]</w:t></w:r>"
        } else {
            // Plain text without brackets or highlighting
            let plainRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/></w:rPr>"
            newRuns = "<w:r>\(plainRPr)\(contentRuns)</w:r>"
        }

        let finalContent = "<w:p>\(pPrContent)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Set paragraph text with cream highlighting but NO gold brackets
    func setParagraphTextHighlightOnly(at index: Int, text: String, spacingAfter: Int = 0) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        var modifiedContent = para.content

        // Use 40 spaces for empty placeholder
        let displayText = text.isEmpty ? "                                        " : text

        // Extract pPr if exists, or create one with spacing
        var pPrContent = ""
        if let pPrStart = modifiedContent.range(of: "<w:pPr>"),
           let pPrEnd = modifiedContent.range(of: "</w:pPr>", range: pPrStart.upperBound..<modifiedContent.endIndex) {
            pPrContent = String(modifiedContent[pPrStart.lowerBound..<pPrEnd.upperBound])
            // Add spacing if requested
            if spacingAfter > 0 {
                pPrContent = pPrContent.replacingOccurrences(of: "</w:pPr>", with: "<w:spacing w:after=\"\(spacingAfter)\"/></w:pPr>")
            }
        } else if spacingAfter > 0 {
            // Create pPr with spacing
            pPrContent = "<w:pPr><w:spacing w:after=\"\(spacingAfter)\"/></w:pPr>"
        }

        // Content with cream highlighting but NO gold brackets
        let contentRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"

        // Split text by newlines and create runs with line breaks
        let lines = displayText.components(separatedBy: "\n")
        var contentRuns = ""
        for (idx, line) in lines.enumerated() {
            let escapedLine = escapeXML(line)
            contentRuns += "<w:t xml:space=\"preserve\">\(escapedLine)</w:t>"
            if idx < lines.count - 1 {
                contentRuns += "<w:br/>"
            }
        }

        let newRuns = "<w:r>\(contentRPr)\(contentRuns)</w:r>"
        let finalContent = "<w:p>\(pPrContent)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Apply cream highlight with gold brackets to detention reason line
    /// Format: "(i)    [in the interests of...]" - prefix not bracketed, rest is bracketed
    /// Apply detention reason formatting with bracket position control
    /// bracketPosition: "start" = opening bracket, "end" = closing bracket, "none" = no brackets
    func applyDetentionReasonLine(at index: Int, prefixNum: String, bracketPosition: String) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]

        // Define the static content for each detention reason
        let contentMap: [String: String] = [
            "(i)": "in the interests of the patient's own health",
            "(ii)": "in the interests of the patient's own safety",
            "(iii)": "with a view to the protection of other persons."
        ]

        let content = contentMap[prefixNum] ?? ""

        let prefixRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/></w:rPr>"
        let goldBracketRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:b/><w:color w:val=\"\(kGoldBracketColor)\"/><w:sz w:val=\"28\"/><w:szCs w:val=\"28\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"
        let contentRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"

        let escapedContent = escapeXML(content)

        // No indentation - align with (b) at left margin
        // Add blank line after each (i), (ii), (iii)
        let pPr = "<w:pPr><w:spacing w:after=\"240\" w:line=\"240\" w:lineRule=\"auto\"/></w:pPr>"

        // Build paragraph: (i) followed by tab, then content
        var runs = "<w:r>\(prefixRPr)<w:t xml:space=\"preserve\">\(prefixNum)\t</w:t></w:r>"

        if bracketPosition == "start" {
            runs += "<w:r>\(goldBracketRPr)<w:t>[</w:t></w:r>"
        }

        runs += "<w:r>\(contentRPr)<w:t xml:space=\"preserve\">\(escapedContent)</w:t></w:r>"

        if bracketPosition == "end" {
            runs += "<w:r>\(goldBracketRPr)<w:t>]</w:t></w:r>"
        }

        let finalContent = "<w:p>\(pPr)\(runs)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Apply spanning bracket - opening bracket at start of content (with blank line after)
    func applySpanningBracketStart(at index: Int, content: String) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]

        let goldBracketRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:b/><w:color w:val=\"\(kGoldBracketColor)\"/><w:sz w:val=\"28\"/><w:szCs w:val=\"28\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"
        let contentRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"

        let escapedContent = escapeXML(content)
        // Add spacing after for blank line
        let pPr = "<w:pPr><w:spacing w:after=\"240\"/></w:pPr>"
        let runs = "<w:r>\(goldBracketRPr)<w:t>[</w:t></w:r><w:r>\(contentRPr)<w:t xml:space=\"preserve\">\(escapedContent)</w:t></w:r>"

        let finalContent = "<w:p>\(pPr)\(runs)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Apply spanning bracket - closing bracket at end of content (with blank line after)
    func applySpanningBracketEnd(at index: Int, content: String) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]

        let goldBracketRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:b/><w:color w:val=\"\(kGoldBracketColor)\"/><w:sz w:val=\"28\"/><w:szCs w:val=\"28\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"
        let contentRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"

        let escapedContent = escapeXML(content)
        // Add spacing after for blank line
        let pPr = "<w:pPr><w:spacing w:after=\"240\"/></w:pPr>"
        let runs = "<w:r>\(contentRPr)<w:t xml:space=\"preserve\">\(escapedContent)</w:t></w:r><w:r>\(goldBracketRPr)<w:t>]</w:t></w:r>"

        let finalContent = "<w:p>\(pPr)\(runs)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Apply cream highlight with gold brackets to a paragraph (call after removePermissionMarkers)
    func applyCreamHighlight(at index: Int) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        var modifiedContent = para.content

        // Extract all text content
        let textPattern = #"<w:t[^>]*>([^<]*)</w:t>"#
        guard let regex = try? NSRegularExpression(pattern: textPattern) else { return }

        let range = NSRange(modifiedContent.startIndex..., in: modifiedContent)
        let matches = regex.matches(in: modifiedContent, range: range)

        var fullText = ""
        for match in matches {
            if match.numberOfRanges > 1,
               let textRange = Range(match.range(at: 1), in: modifiedContent) {
                fullText += String(modifiedContent[textRange])
            }
        }

        // Strip any existing brackets from the text
        var cleanText = fullText
        if cleanText.hasPrefix("[") {
            cleanText = String(cleanText.dropFirst())
        }
        if cleanText.hasSuffix("]") {
            cleanText = String(cleanText.dropLast())
        }

        // Extract pPr if exists
        var pPrContent = ""
        if let pPrStart = modifiedContent.range(of: "<w:pPr>"),
           let pPrEnd = modifiedContent.range(of: "</w:pPr>", range: pPrStart.upperBound..<modifiedContent.endIndex) {
            pPrContent = String(modifiedContent[pPrStart.lowerBound..<pPrEnd.upperBound])
        }

        // Build runs with gold brackets and cream highlighted content
        let goldBracketRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:b/><w:color w:val=\"\(kGoldBracketColor)\"/><w:sz w:val=\"28\"/><w:szCs w:val=\"28\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"
        let contentRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"

        let escapedText = escapeXML(cleanText)
        let newRuns = "<w:r>\(goldBracketRPr)<w:t>[</w:t></w:r><w:r>\(contentRPr)<w:t xml:space=\"preserve\">\(escapedText)</w:t></w:r><w:r>\(goldBracketRPr)<w:t>]</w:t></w:r>"

        let finalContent = "<w:p>\(pPrContent)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Apply strikethrough to a paragraph while preserving structure
    func safeStrikethrough(at index: Int) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        var modifiedContent = para.content

        // Remove permission markers that cause grey highlighting
        let permStartPattern = #"<w:permStart[^/]*/>"#
        if let permStartRegex = try? NSRegularExpression(pattern: permStartPattern) {
            let permRange = NSRange(modifiedContent.startIndex..., in: modifiedContent)
            modifiedContent = permStartRegex.stringByReplacingMatches(in: modifiedContent, range: permRange, withTemplate: "")
        }
        let permEndPattern = #"<w:permEnd[^/]*/>"#
        if let permEndRegex = try? NSRegularExpression(pattern: permEndPattern) {
            let permRange = NSRange(modifiedContent.startIndex..., in: modifiedContent)
            modifiedContent = permEndRegex.stringByReplacingMatches(in: modifiedContent, range: permRange, withTemplate: "")
        }

        // Add strikethrough by inserting <w:strike/> before </w:rPr>
        modifiedContent = modifiedContent.replacingOccurrences(of: "</w:rPr>", with: "<w:strike/></w:rPr>")

        documentXML.replaceSubrange(para.range, with: modifiedContent)
    }

    /// Fill signature line with selective highlighting: "Signed [HIGHLIGHTED] Date [HIGHLIGHTED]"
    func fillSignatureLine(at index: Int, dateContent: String) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        var modifiedContent = para.content

        // Remove permission markers
        let permStartPattern = #"<w:permStart[^/]*/>"#
        if let permStartRegex = try? NSRegularExpression(pattern: permStartPattern) {
            let permRange = NSRange(modifiedContent.startIndex..., in: modifiedContent)
            modifiedContent = permStartRegex.stringByReplacingMatches(in: modifiedContent, range: permRange, withTemplate: "")
        }
        let permEndPattern = #"<w:permEnd[^/]*/>"#
        if let permEndRegex = try? NSRegularExpression(pattern: permEndPattern) {
            let permRange = NSRange(modifiedContent.startIndex..., in: modifiedContent)
            modifiedContent = permEndRegex.stringByReplacingMatches(in: modifiedContent, range: permRange, withTemplate: "")
        }

        // Build the signature line with proper formatting - gold brackets, cream content
        let sigSpaces = "                                        "
        let plainRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/></w:rPr>"
        let goldBracketRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:b/><w:color w:val=\"\(kGoldBracketColor)\"/><w:sz w:val=\"28\"/><w:szCs w:val=\"28\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"
        let contentRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"

        // Create runs: "Signed " + gold "[" + spaces + gold "]" + "  Date " + gold "[" + date + gold "]"
        let newRuns = "<w:r>\(plainRPr)<w:t xml:space=\"preserve\">Signed </w:t></w:r><w:r>\(goldBracketRPr)<w:t>[</w:t></w:r><w:r>\(contentRPr)<w:t xml:space=\"preserve\">\(sigSpaces)</w:t></w:r><w:r>\(goldBracketRPr)<w:t>]</w:t></w:r><w:r>\(plainRPr)<w:t xml:space=\"preserve\">                    Date </w:t></w:r><w:r>\(goldBracketRPr)<w:t>[</w:t></w:r><w:r>\(contentRPr)<w:t xml:space=\"preserve\">\(dateContent)</w:t></w:r><w:r>\(goldBracketRPr)<w:t>]</w:t></w:r>"

        // Extract pPr if exists
        var pPrContent = ""
        if let pPrStart = modifiedContent.range(of: "<w:pPr>"),
           let pPrEnd = modifiedContent.range(of: "</w:pPr>", range: pPrStart.upperBound..<modifiedContent.endIndex) {
            pPrContent = String(modifiedContent[pPrStart.lowerBound..<pPrEnd.upperBound])
        }

        let finalContent = "<w:p>\(pPrContent)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Fill signature line without bold brackets
    /// - Parameters:
    ///   - index: Paragraph index
    ///   - dateContent: Date text to fill in the date bracket
    ///   - spacingAfter: Spacing after the paragraph in twips (480 = ~1 line). Default is 120.
    func fillSignatureLineNoBold(at index: Int, dateContent: String, spacingAfter: Int = 120) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]

        // Build completely fresh signature line - NO BOLD anywhere, no pPr preservation
        let sigSpaces = "                                        "
        let plainRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/></w:rPr>"
        let goldBracketRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:b/><w:color w:val=\"\(kGoldBracketColor)\"/><w:sz w:val=\"28\"/><w:szCs w:val=\"28\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"
        let contentRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"

        let newRuns = "<w:r>\(plainRPr)<w:t xml:space=\"preserve\">Signed </w:t></w:r><w:r>\(goldBracketRPr)<w:t>[</w:t></w:r><w:r>\(contentRPr)<w:t xml:space=\"preserve\">\(sigSpaces)</w:t></w:r><w:r>\(goldBracketRPr)<w:t>]</w:t></w:r><w:r>\(plainRPr)<w:t xml:space=\"preserve\">                    Date </w:t></w:r><w:r>\(goldBracketRPr)<w:t>[</w:t></w:r><w:r>\(contentRPr)<w:t xml:space=\"preserve\">\(dateContent)</w:t></w:r><w:r>\(goldBracketRPr)<w:t>]</w:t></w:r>"

        // Create fresh paragraph with spacing after
        let pPr = "<w:pPr><w:spacing w:after=\"\(spacingAfter)\"/></w:pPr>"
        let finalContent = "<w:p>\(pPr)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Add Section 12 note at the bottom of the form (bold, Arial 14.5)
    func addSection12Note(at index: Int) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]

        // Bold Arial 14.5pt (29 half-points)
        let noteRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:b/><w:sz w:val=\"29\"/><w:szCs w:val=\"29\"/></w:rPr>"
        let noteText = "NOTE: AT LEAST ONE OF THE PRACTITIONERS SIGNING THIS FORM MUST BE APPROVED UNDER SECTION 12 OF THE ACT."

        let pPr = "<w:pPr><w:spacing w:before=\"240\"/></w:pPr>"
        let runs = "<w:r>\(noteRPr)<w:t xml:space=\"preserve\">\(noteText)</w:t></w:r>"

        let finalContent = "<w:p>\(pPr)\(runs)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Format the "[If you need to continue on a separate sheet...]" line with gold brackets
    func formatContinueOnSeparateSheet(at index: Int) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]

        let plainRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/></w:rPr>"
        let goldBracketRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:b/><w:color w:val=\"\(kGoldBracketColor)\"/><w:sz w:val=\"28\"/><w:szCs w:val=\"28\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"
        let contentRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"

        let runs = "<w:r>\(plainRPr)<w:t>[If you need to continue on a separate sheet please indicate here </w:t></w:r><w:r>\(goldBracketRPr)<w:t>[</w:t></w:r><w:r>\(contentRPr)<w:t xml:space=\"preserve\"> </w:t></w:r><w:r>\(goldBracketRPr)<w:t>]</w:t></w:r><w:r>\(plainRPr)<w:t> and attach that sheet to this form]</w:t></w:r>"

        let finalContent = "<w:p>\(runs)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Fill "Signed [...] on behalf of..." line with cream highlight and gold brackets
    func fillSignedWithSuffixLineHighlighted(at index: Int, signatureContent: String, suffix: String) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]

        let sigSpaces = "                                        "
        let sigContent = signatureContent.isEmpty ? sigSpaces : signatureContent
        let plainRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/></w:rPr>"
        let goldBracketRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:b/><w:color w:val=\"\(kGoldBracketColor)\"/><w:sz w:val=\"28\"/><w:szCs w:val=\"28\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"
        let contentRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"

        let escapedSuffix = escapeXML(suffix)

        let newRuns = "<w:r>\(plainRPr)<w:t xml:space=\"preserve\">Signed </w:t></w:r><w:r>\(goldBracketRPr)<w:t>[</w:t></w:r><w:r>\(contentRPr)<w:t xml:space=\"preserve\">\(sigContent)</w:t></w:r><w:r>\(goldBracketRPr)<w:t>]</w:t></w:r><w:r>\(plainRPr)<w:t xml:space=\"preserve\"> \(escapedSuffix)</w:t></w:r>"

        let pPr = "<w:pPr><w:spacing w:after=\"120\"/></w:pPr>"
        let finalContent = "<w:p>\(pPr)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Fill "PRINT NAME [...] Date [...]" line with cream highlight and gold brackets
    func fillPrintNameDateLineHighlighted(at index: Int, nameContent: String, dateContent: String) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]

        let nameSpaces = "                              "
        let dateSpaces = "                    "
        let nmContent = nameContent.isEmpty ? nameSpaces : nameContent
        let dtContent = dateContent.isEmpty ? dateSpaces : dateContent

        let plainRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/></w:rPr>"
        let goldBracketRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:b/><w:color w:val=\"\(kGoldBracketColor)\"/><w:sz w:val=\"28\"/><w:szCs w:val=\"28\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"
        let contentRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"

        let newRuns = "<w:r>\(plainRPr)<w:t xml:space=\"preserve\">PRINT NAME </w:t></w:r><w:r>\(goldBracketRPr)<w:t>[</w:t></w:r><w:r>\(contentRPr)<w:t xml:space=\"preserve\">\(nmContent)</w:t></w:r><w:r>\(goldBracketRPr)<w:t>]</w:t></w:r><w:r>\(plainRPr)<w:t xml:space=\"preserve\">                             Date </w:t></w:r><w:r>\(goldBracketRPr)<w:t>[</w:t></w:r><w:r>\(contentRPr)<w:t xml:space=\"preserve\">\(dtContent)</w:t></w:r><w:r>\(goldBracketRPr)<w:t>]</w:t></w:r>"

        let pPr = "<w:pPr><w:spacing w:after=\"120\"/></w:pPr>"
        let finalContent = "<w:p>\(pPr)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Fill "LABEL [content]" line with cream highlight and gold brackets (for PRINT NAME, Email, etc.)
    func fillLabelBracketLineHighlighted(at index: Int, label: String, content: String) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]

        let spaces = "                                        "
        let displayContent = content.isEmpty ? spaces : content

        let plainRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/></w:rPr>"
        let goldBracketRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:b/><w:color w:val=\"\(kGoldBracketColor)\"/><w:sz w:val=\"28\"/><w:szCs w:val=\"28\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"
        let contentRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"

        let newRuns = "<w:r>\(plainRPr)<w:t xml:space=\"preserve\">\(label) </w:t></w:r><w:r>\(goldBracketRPr)<w:t>[</w:t></w:r><w:r>\(contentRPr)<w:t xml:space=\"preserve\">\(displayContent)</w:t></w:r><w:r>\(goldBracketRPr)<w:t>]</w:t></w:r>"

        let pPr = "<w:pPr><w:spacing w:after=\"120\"/></w:pPr>"
        let finalContent = "<w:p>\(pPr)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Fill "Date [...] Time [...]" line with cream highlight and gold brackets (for M2 Part 1)
    func fillDateTimeLineHighlighted(at index: Int, dateContent: String, timeContent: String) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]

        let dateSpaces = "                              "
        let timeSpaces = "            "
        let dtContent = dateContent.isEmpty ? dateSpaces : dateContent
        let tmContent = timeContent.isEmpty ? timeSpaces : timeContent

        let plainRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/></w:rPr>"
        let goldBracketRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:b/><w:color w:val=\"\(kGoldBracketColor)\"/><w:sz w:val=\"28\"/><w:szCs w:val=\"28\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"
        let contentRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"

        let newRuns = "<w:r>\(plainRPr)<w:t xml:space=\"preserve\">Date </w:t></w:r><w:r>\(goldBracketRPr)<w:t>[</w:t></w:r><w:r>\(contentRPr)<w:t xml:space=\"preserve\">\(dtContent)</w:t></w:r><w:r>\(goldBracketRPr)<w:t>]</w:t></w:r><w:r>\(plainRPr)<w:t xml:space=\"preserve\">                    Time </w:t></w:r><w:r>\(goldBracketRPr)<w:t>[</w:t></w:r><w:r>\(contentRPr)<w:t xml:space=\"preserve\">\(tmContent)</w:t></w:r><w:r>\(goldBracketRPr)<w:t>]</w:t></w:r>"

        let pPr = "<w:pPr><w:spacing w:after=\"120\"/></w:pPr>"
        let finalContent = "<w:p>\(pPr)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Set just "[content]" with gold brackets and cream highlight (no label)
    func setBracketLineHighlighted(at index: Int, content: String) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]

        let spaces = "                                        "
        let displayContent = content.isEmpty ? spaces : content

        let goldBracketRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:b/><w:color w:val=\"\(kGoldBracketColor)\"/><w:sz w:val=\"28\"/><w:szCs w:val=\"28\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"
        let contentRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"

        let newRuns = "<w:r>\(goldBracketRPr)<w:t>[</w:t></w:r><w:r>\(contentRPr)<w:t xml:space=\"preserve\">\(displayContent)</w:t></w:r><w:r>\(goldBracketRPr)<w:t>]</w:t></w:r>"

        let pPr = "<w:pPr><w:spacing w:after=\"120\"/></w:pPr>"
        let finalContent = "<w:p>\(pPr)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Fill "Signed [  ] Date [  ]" line with gold brackets and cream highlight
    func fillSignedDateLineHighlighted(at index: Int, signatureContent: String, dateContent: String) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]

        let sigSpaces = "                                        "
        let dateSpaces = "                              "
        let sigContent = signatureContent.isEmpty ? sigSpaces : signatureContent
        let dtContent = dateContent.isEmpty ? dateSpaces : dateContent

        let plainRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/></w:rPr>"
        let goldBracketRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:b/><w:color w:val=\"\(kGoldBracketColor)\"/><w:sz w:val=\"28\"/><w:szCs w:val=\"28\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"
        let contentRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"

        let newRuns = "<w:r>\(plainRPr)<w:t xml:space=\"preserve\">Signed </w:t></w:r><w:r>\(goldBracketRPr)<w:t>[</w:t></w:r><w:r>\(contentRPr)<w:t xml:space=\"preserve\">\(sigContent)</w:t></w:r><w:r>\(goldBracketRPr)<w:t>]</w:t></w:r><w:r>\(plainRPr)<w:t xml:space=\"preserve\">                    Date </w:t></w:r><w:r>\(goldBracketRPr)<w:t>[</w:t></w:r><w:r>\(contentRPr)<w:t xml:space=\"preserve\">\(dtContent)</w:t></w:r><w:r>\(goldBracketRPr)<w:t>]</w:t></w:r>"

        let pPr = "<w:pPr><w:spacing w:after=\"120\"/></w:pPr>"
        let finalContent = "<w:p>\(pPr)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Set "Signed [ ] suffix" line with gold brackets and cream highlight
    func setSignedWithSuffixLineHighlighted(at index: Int, signatureContent: String, suffix: String, spacingAfter: Int = 120) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]

        let sigSpaces = "                              "
        let sigContent = signatureContent.isEmpty ? sigSpaces : signatureContent
        let escapedSuffix = escapeXML(suffix)

        let plainRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/></w:rPr>"
        let goldBracketRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:b/><w:color w:val=\"\(kGoldBracketColor)\"/><w:sz w:val=\"28\"/><w:szCs w:val=\"28\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"
        let contentRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"

        let newRuns = "<w:r>\(plainRPr)<w:t xml:space=\"preserve\">Signed </w:t></w:r><w:r>\(goldBracketRPr)<w:t>[</w:t></w:r><w:r>\(contentRPr)<w:t xml:space=\"preserve\">\(sigContent)</w:t></w:r><w:r>\(goldBracketRPr)<w:t>]</w:t></w:r><w:r>\(plainRPr)<w:t xml:space=\"preserve\"> \(escapedSuffix)</w:t></w:r>"

        let pPr = "<w:pPr><w:spacing w:after=\"\(spacingAfter)\"/></w:pPr>"
        let finalContent = "<w:p>\(pPr)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Set "Date[ ]" line with gold brackets and cream highlight
    func setDateLineHighlighted(at index: Int, dateContent: String, spacingAfter: Int = 120) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]

        let dateSpaces = "                                                            "
        let dtContent = dateContent.isEmpty ? dateSpaces : dateContent

        let plainRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/></w:rPr>"
        let goldBracketRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:b/><w:color w:val=\"\(kGoldBracketColor)\"/><w:sz w:val=\"28\"/><w:szCs w:val=\"28\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"
        let contentRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"

        let newRuns = "<w:r>\(plainRPr)<w:t xml:space=\"preserve\">Date</w:t></w:r><w:r>\(goldBracketRPr)<w:t>[</w:t></w:r><w:r>\(contentRPr)<w:t xml:space=\"preserve\">\(dtContent)</w:t></w:r><w:r>\(goldBracketRPr)<w:t>]</w:t></w:r>"

        let pPr = "<w:pPr><w:spacing w:after=\"\(spacingAfter)\"/></w:pPr>"
        let finalContent = "<w:p>\(pPr)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Set "Time[ ]" line with gold brackets and cream highlight
    func setTimeLineHighlighted(at index: Int, timeContent: String, spacingAfter: Int = 120) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]

        let timeSpaces = "                                                            "
        let tmContent = timeContent.isEmpty ? timeSpaces : timeContent

        let plainRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/></w:rPr>"
        let goldBracketRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:b/><w:color w:val=\"\(kGoldBracketColor)\"/><w:sz w:val=\"28\"/><w:szCs w:val=\"28\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"
        let contentRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"

        let newRuns = "<w:r>\(plainRPr)<w:t xml:space=\"preserve\">Time</w:t></w:r><w:r>\(goldBracketRPr)<w:t>[</w:t></w:r><w:r>\(contentRPr)<w:t xml:space=\"preserve\">\(tmContent)</w:t></w:r><w:r>\(goldBracketRPr)<w:t>]</w:t></w:r>"

        let pPr = "<w:pPr><w:spacing w:after=\"\(spacingAfter)\"/></w:pPr>"
        let finalContent = "<w:p>\(pPr)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Set "PRINT NAME[ ]" line with gold brackets and cream highlight
    func setPrintNameLineHighlighted(at index: Int, nameContent: String, spacingAfter: Int = 120) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]

        let nameSpaces = "                                                            "
        let name = nameContent.isEmpty ? nameSpaces : nameContent

        let plainRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/></w:rPr>"
        let goldBracketRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:b/><w:color w:val=\"\(kGoldBracketColor)\"/><w:sz w:val=\"28\"/><w:szCs w:val=\"28\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"
        let contentRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"

        let newRuns = "<w:r>\(plainRPr)<w:t xml:space=\"preserve\">PRINT NAME</w:t></w:r><w:r>\(goldBracketRPr)<w:t>[</w:t></w:r><w:r>\(contentRPr)<w:t xml:space=\"preserve\">\(name)</w:t></w:r><w:r>\(goldBracketRPr)<w:t>]</w:t></w:r>"

        let pPr = "<w:pPr><w:spacing w:after=\"\(spacingAfter)\"/></w:pPr>"
        let finalContent = "<w:p>\(pPr)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Set delivery option with opening gold bracket "[text" (for first option in a list)
    func setDeliveryOptionWithOpeningBracket(at index: Int, withStrikethrough: Bool = false) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        var existingText = para.content

        // Extract text content from all runs
        let textPattern = #"<w:t[^>]*>([^<]*)</w:t>"#
        guard let regex = try? NSRegularExpression(pattern: textPattern) else { return }

        var extractedTexts: [String] = []
        let nsContent = existingText as NSString
        let range = NSRange(location: 0, length: nsContent.length)
        let matches = regex.matches(in: existingText, range: range)

        for match in matches {
            if let textRange = Range(match.range(at: 1), in: existingText) {
                extractedTexts.append(String(existingText[textRange]))
            }
        }

        let fullText = extractedTexts.joined()

        let strikeTag = withStrikethrough ? "<w:strike/>" : ""
        let goldBracketRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:b/><w:color w:val=\"\(kGoldBracketColor)\"/>\(strikeTag)<w:sz w:val=\"28\"/><w:szCs w:val=\"28\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"
        let contentRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/>\(strikeTag)<w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"

        let escapedText = escapeXML(fullText)
        let newRuns = "<w:r>\(goldBracketRPr)<w:t>[</w:t></w:r><w:r>\(contentRPr)<w:t xml:space=\"preserve\">\(escapedText)</w:t></w:r>"

        var pPrContent = ""
        if let pPrMatch = existingText.range(of: #"<w:pPr>.*?</w:pPr>"#, options: .regularExpression) {
            pPrContent = String(existingText[pPrMatch])
        }

        var pOpenTag = "<w:p>"
        if let pOpenMatch = existingText.range(of: #"<w:p[^>]*>"#, options: .regularExpression) {
            pOpenTag = String(existingText[pOpenMatch])
        }

        let finalContent = "\(pOpenTag)\(pPrContent)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Set delivery option with closing gold bracket "text]" (for last option in a list)
    func setDeliveryOptionWithClosingBracket(at index: Int, withStrikethrough: Bool = false) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        var existingText = para.content

        // Extract text content from all runs
        let textPattern = #"<w:t[^>]*>([^<]*)</w:t>"#
        guard let regex = try? NSRegularExpression(pattern: textPattern) else { return }

        var extractedTexts: [String] = []
        let nsContent = existingText as NSString
        let range = NSRange(location: 0, length: nsContent.length)
        let matches = regex.matches(in: existingText, range: range)

        for match in matches {
            if let textRange = Range(match.range(at: 1), in: existingText) {
                extractedTexts.append(String(existingText[textRange]))
            }
        }

        let fullText = extractedTexts.joined()

        let strikeTag = withStrikethrough ? "<w:strike/>" : ""
        let goldBracketRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:b/><w:color w:val=\"\(kGoldBracketColor)\"/>\(strikeTag)<w:sz w:val=\"28\"/><w:szCs w:val=\"28\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"
        let contentRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/>\(strikeTag)<w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"

        let escapedText = escapeXML(fullText)
        let newRuns = "<w:r>\(contentRPr)<w:t xml:space=\"preserve\">\(escapedText)</w:t></w:r><w:r>\(goldBracketRPr)<w:t>]</w:t></w:r>"

        var pPrContent = ""
        if let pPrMatch = existingText.range(of: #"<w:pPr>.*?</w:pPr>"#, options: .regularExpression) {
            pPrContent = String(existingText[pPrMatch])
        }

        var pOpenTag = "<w:p>"
        if let pOpenMatch = existingText.range(of: #"<w:p[^>]*>"#, options: .regularExpression) {
            pOpenTag = String(existingText[pOpenMatch])
        }

        let finalContent = "\(pOpenTag)\(pPrContent)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Set delivery option with cream highlight only (for middle options in a list)
    func setDeliveryOptionWithCreamHighlightOnly(at index: Int, withStrikethrough: Bool = false) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        var existingText = para.content

        // Extract text content from all runs
        let textPattern = #"<w:t[^>]*>([^<]*)</w:t>"#
        guard let regex = try? NSRegularExpression(pattern: textPattern) else { return }

        var extractedTexts: [String] = []
        let nsContent = existingText as NSString
        let range = NSRange(location: 0, length: nsContent.length)
        let matches = regex.matches(in: existingText, range: range)

        for match in matches {
            if let textRange = Range(match.range(at: 1), in: existingText) {
                extractedTexts.append(String(existingText[textRange]))
            }
        }

        let fullText = extractedTexts.joined()

        let strikeTag = withStrikethrough ? "<w:strike/>" : ""
        let contentRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/>\(strikeTag)<w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"

        let escapedText = escapeXML(fullText)
        let newRuns = "<w:r>\(contentRPr)<w:t xml:space=\"preserve\">\(escapedText)</w:t></w:r>"

        var pPrContent = ""
        if let pPrMatch = existingText.range(of: #"<w:pPr>.*?</w:pPr>"#, options: .regularExpression) {
            pPrContent = String(existingText[pPrMatch])
        }

        var pOpenTag = "<w:p>"
        if let pOpenMatch = existingText.range(of: #"<w:p[^>]*>"#, options: .regularExpression) {
            pOpenTag = String(existingText[pOpenMatch])
        }

        let finalContent = "\(pOpenTag)\(pPrContent)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Set Part 4 signature line: "Signed [ ] on behalf of the managers of the responsible hospital"
    func setPart4SignatureLine(at index: Int) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]

        let sigSpaces = "                              "

        let plainRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/></w:rPr>"
        let goldBracketRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:b/><w:color w:val=\"\(kGoldBracketColor)\"/><w:sz w:val=\"28\"/><w:szCs w:val=\"28\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"
        let contentRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"

        let newRuns = "<w:r>\(plainRPr)<w:t xml:space=\"preserve\">Signed </w:t></w:r><w:r>\(goldBracketRPr)<w:t>[</w:t></w:r><w:r>\(contentRPr)<w:t xml:space=\"preserve\">\(sigSpaces)</w:t></w:r><w:r>\(goldBracketRPr)<w:t>]</w:t></w:r><w:r>\(plainRPr)<w:t xml:space=\"preserve\"> on behalf of the managers of the responsible hospital</w:t></w:r>"

        let pPr = "<w:pPr><w:spacing w:after=\"120\"/></w:pPr>"
        let finalContent = "<w:p>\(pPr)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Set "PRINT NAME [ ] Date [ ]" line with gold brackets and cream highlight
    func setPrintNameDateLineHighlighted(at index: Int, nameContent: String, dateContent: String) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]

        let nameSpaces = "                              "
        let dateSpaces = "                    "
        let name = nameContent.isEmpty ? nameSpaces : nameContent
        let date = dateContent.isEmpty ? dateSpaces : dateContent

        let plainRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/></w:rPr>"
        let goldBracketRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:b/><w:color w:val=\"\(kGoldBracketColor)\"/><w:sz w:val=\"28\"/><w:szCs w:val=\"28\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"
        let contentRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"

        let newRuns = "<w:r>\(plainRPr)<w:t xml:space=\"preserve\">PRINT NAME </w:t></w:r><w:r>\(goldBracketRPr)<w:t>[</w:t></w:r><w:r>\(contentRPr)<w:t xml:space=\"preserve\">\(name)</w:t></w:r><w:r>\(goldBracketRPr)<w:t>]</w:t></w:r><w:r>\(plainRPr)<w:t xml:space=\"preserve\">                             Date </w:t></w:r><w:r>\(goldBracketRPr)<w:t>[</w:t></w:r><w:r>\(contentRPr)<w:t xml:space=\"preserve\">\(date)</w:t></w:r><w:r>\(goldBracketRPr)<w:t>]</w:t></w:r>"

        let pPr = "<w:pPr><w:spacing w:after=\"120\"/></w:pPr>"
        let finalContent = "<w:p>\(pPr)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Set a highlighted space line with closing gold bracket (for after Part 4 date)
    func setHighlightedSpaceWithClosingBracket(at index: Int) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]

        let spaces = "                                                                                   "

        let goldBracketRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:b/><w:color w:val=\"\(kGoldBracketColor)\"/><w:sz w:val=\"28\"/><w:szCs w:val=\"28\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"
        let contentRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"

        let newRuns = "<w:r>\(contentRPr)<w:t xml:space=\"preserve\">\(spaces)</w:t></w:r><w:r>\(goldBracketRPr)<w:t>]</w:t></w:r>"

        let pPr = "<w:pPr><w:spacing w:after=\"120\"/></w:pPr>"
        let finalContent = "<w:p>\(pPr)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Set the "If you need to continue on separate sheet" line with special formatting:
    /// - Normal outer brackets
    /// - Golden inner checkbox brackets [ ]
    /// - Cream highlighting throughout
    func setContinueOnSeparateSheetLine(at index: Int, withStrikethrough: Bool = false) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]

        let strikeTag = withStrikethrough ? "<w:strike/>" : ""
        let normalBracketRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/>\(strikeTag)<w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"
        let goldBracketRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:b/><w:color w:val=\"\(kGoldBracketColor)\"/>\(strikeTag)<w:sz w:val=\"28\"/><w:szCs w:val=\"28\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"
        let contentRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/>\(strikeTag)<w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"

        // Format: [If you need to continue on a separate sheet please indicate here [ ] and attach that sheet to this form]
        // Normal [ at start, golden [ ] for checkbox, normal ] at end
        let newRuns = "<w:r>\(normalBracketRPr)<w:t>[</w:t></w:r>" +
                      "<w:r>\(contentRPr)<w:t xml:space=\"preserve\">If you need to continue on a separate sheet please indicate here </w:t></w:r>" +
                      "<w:r>\(goldBracketRPr)<w:t>[</w:t></w:r>" +
                      "<w:r>\(contentRPr)<w:t xml:space=\"preserve\"> </w:t></w:r>" +
                      "<w:r>\(goldBracketRPr)<w:t>]</w:t></w:r>" +
                      "<w:r>\(contentRPr)<w:t xml:space=\"preserve\"> and attach that sheet to this form</w:t></w:r>" +
                      "<w:r>\(normalBracketRPr)<w:t>]</w:t></w:r>"

        var pPrContent = ""
        if let pPrMatch = para.content.range(of: #"<w:pPr>.*?</w:pPr>"#, options: .regularExpression) {
            pPrContent = String(para.content[pPrMatch])
        }

        var pOpenTag = "<w:p>"
        if let pOpenMatch = para.content.range(of: #"<w:p[^>]*>"#, options: .regularExpression) {
            pOpenTag = String(para.content[pOpenMatch])
        }

        let finalContent = "\(pOpenTag)\(pPrContent)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Fill only the second bracket (date) in a signature line while preserving structure
    func fillSignatureDate(at index: Int, dateContent: String) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        var modifiedContent = para.content

        // Find all text content
        let textPattern = #"<w:t[^>]*>([^<]*)</w:t>"#
        guard let regex = try? NSRegularExpression(pattern: textPattern) else { return }

        let range = NSRange(modifiedContent.startIndex..., in: modifiedContent)
        let matches = regex.matches(in: modifiedContent, range: range)

        // Find the second bracket pair (Date bracket) and fill it
        var bracketCount = 0
        for match in matches {
            if let matchRange = Range(match.range, in: modifiedContent),
               match.numberOfRanges > 1,
               let textRange = Range(match.range(at: 1), in: modifiedContent) {
                let text = String(modifiedContent[textRange])

                // Count brackets in this text segment
                for char in text {
                    if char == "[" {
                        bracketCount += 1
                        if bracketCount == 2 {
                            // This is the second bracket - replace content between [ and ]
                            if let openBracket = text.firstIndex(of: "["),
                               let closeBracket = text.lastIndex(of: "]") {
                                let beforeBracket = String(text[..<openBracket])
                                let afterBracket = String(text[text.index(after: closeBracket)...])
                                let newText = beforeBracket + "[" + dateContent + "]" + afterBracket

                                let fullMatch = String(modifiedContent[matchRange])
                                let newFullMatch = fullMatch.replacingOccurrences(of: text, with: newText)
                                modifiedContent.replaceSubrange(matchRange, with: newFullMatch)

                                documentXML.replaceSubrange(para.range, with: modifiedContent)
                                return
                            }
                        }
                    }
                }
            }
        }
    }

    /// Remove permission markers from a paragraph (removes grey box appearance)
    /// This is safer than deleting - preserves paragraph structure
    func removePermissionMarkers(at index: Int) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        var newContent = para.content

        // Remove permission start markers
        let permStartPattern = #"<w:permStart[^/]*/>"#
        if let regex = try? NSRegularExpression(pattern: permStartPattern) {
            let range = NSRange(newContent.startIndex..., in: newContent)
            newContent = regex.stringByReplacingMatches(in: newContent, range: range, withTemplate: "")
        }

        // Remove permission end markers
        let permEndPattern = #"<w:permEnd[^/]*/>"#
        if let regex = try? NSRegularExpression(pattern: permEndPattern) {
            let range = NSRange(newContent.startIndex..., in: newContent)
            newContent = regex.stringByReplacingMatches(in: newContent, range: range, withTemplate: "")
        }

        documentXML.replaceSubrange(para.range, with: newContent)
    }

    /// Add spacing after a paragraph (for blank line effect)
    func setSpacingAfter(at index: Int, twips: Int = 240) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        var modifiedContent = para.content

        // Check if pPr already exists
        if let pPrEnd = modifiedContent.range(of: "</w:pPr>") {
            // Insert spacing before </w:pPr>
            let spacingElement = "<w:spacing w:after=\"\(twips)\"/>"
            modifiedContent.insert(contentsOf: spacingElement, at: pPrEnd.lowerBound)
        } else if let pStart = modifiedContent.range(of: "<w:p>") {
            // No pPr exists, add one after <w:p>
            let pPrElement = "<w:pPr><w:spacing w:after=\"\(twips)\"/></w:pPr>"
            modifiedContent.insert(contentsOf: pPrElement, at: pStart.upperBound)
        } else if let pStart = modifiedContent.range(of: "<w:p ") {
            // Handle <w:p with attributes
            if let closeTag = modifiedContent.range(of: ">", range: pStart.upperBound..<modifiedContent.endIndex) {
                let pPrElement = "<w:pPr><w:spacing w:after=\"\(twips)\"/></w:pPr>"
                modifiedContent.insert(contentsOf: pPrElement, at: closeTag.upperBound)
            }
        }

        documentXML.replaceSubrange(para.range, with: modifiedContent)
    }

    /// Set 1.5 line spacing on a paragraph
    func setLineSpacing15(at index: Int) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        var modifiedContent = para.content

        // 1.5 line spacing = 360 twips (1.0 = 240, 1.5 = 360, 2.0 = 480)
        let lineAttrs = " w:line=\"360\" w:lineRule=\"auto\""

        // Check if spacing element already exists
        if let existingSpacing = modifiedContent.range(of: #"<w:spacing([^/]*)/>"#, options: .regularExpression) {
            // Add line spacing attributes to existing spacing element
            let spacingStr = String(modifiedContent[existingSpacing])
            // Insert line attrs before the closing />
            let newSpacing = spacingStr.replacingOccurrences(of: "/>", with: "\(lineAttrs)/>")
            modifiedContent.replaceSubrange(existingSpacing, with: newSpacing)
        } else if let pPrEnd = modifiedContent.range(of: "</w:pPr>") {
            // Insert spacing before </w:pPr>
            let lineSpacingElement = "<w:spacing\(lineAttrs)/>"
            modifiedContent.insert(contentsOf: lineSpacingElement, at: pPrEnd.lowerBound)
        } else if let pStart = modifiedContent.range(of: "<w:p>") {
            // No pPr exists, add one after <w:p>
            let pPrElement = "<w:pPr><w:spacing\(lineAttrs)/></w:pPr>"
            modifiedContent.insert(contentsOf: pPrElement, at: pStart.upperBound)
        } else if let pStart = modifiedContent.range(of: "<w:p ") {
            // Handle <w:p with attributes
            if let closeTag = modifiedContent.range(of: ">", range: pStart.upperBound..<modifiedContent.endIndex) {
                let pPrElement = "<w:pPr><w:spacing\(lineAttrs)/></w:pPr>"
                modifiedContent.insert(contentsOf: pPrElement, at: closeTag.upperBound)
            }
        }

        documentXML.replaceSubrange(para.range, with: modifiedContent)
    }

    /// Delete a paragraph by replacing it with empty content
    func deleteParagraph(at index: Int) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        // Replace with empty string to remove the paragraph
        documentXML.replaceSubrange(para.range, with: "")
    }

    /// Apply yellow highlight to paragraph at given index (uses shading with light yellow color)
    func highlightYellow(at index: Int) {
        // Use template's exact color: rgba(255, 254, 213) = #FFFED5
        applyShading(at: index, fillColor: "FFFED5")
    }

    /// Apply shading color to paragraph at given index
    /// Uses Word's w:shd element with hex color value for precise color control
    func applyShading(at index: Int, fillColor: String) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        var newContent = para.content

        // Remove permission markers (they cause grey appearance in Word)
        let permStartPattern = #"<w:permStart[^/]*/>"#
        if let permStartRegex = try? NSRegularExpression(pattern: permStartPattern) {
            let permStartRange = NSRange(newContent.startIndex..., in: newContent)
            newContent = permStartRegex.stringByReplacingMatches(in: newContent, range: permStartRange, withTemplate: "")
        }
        let permEndPattern = #"<w:permEnd[^/]*/>"#
        if let permEndRegex = try? NSRegularExpression(pattern: permEndPattern) {
            let permEndRange = NSRange(newContent.startIndex..., in: newContent)
            newContent = permEndRegex.stringByReplacingMatches(in: newContent, range: permEndRange, withTemplate: "")
        }

        // Find all <w:r> elements and add/update shading
        let runPattern = #"<w:r>|<w:r [^>]*>"#
        if let regex = try? NSRegularExpression(pattern: runPattern) {
            let range = NSRange(newContent.startIndex..., in: newContent)
            let matches = regex.matches(in: newContent, range: range)

            // Process from end to start
            for match in matches.reversed() {
                if let matchRange = Range(match.range, in: newContent) {
                    // Check if there's an existing rPr
                    let afterRun = newContent.index(matchRange.upperBound, offsetBy: 0)
                    let remainingContent = String(newContent[afterRun...])

                    // Use w:shd for shading with specific hex color
                    let shdElement = "<w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(fillColor)\"/>"

                    if remainingContent.hasPrefix("<w:rPr>") {
                        // rPr exists, insert shading inside it
                        if let rPrEnd = newContent.range(of: "</w:rPr>", range: matchRange.upperBound..<newContent.endIndex) {
                            // Check if shading already exists
                            let rPrContent = String(newContent[matchRange.upperBound..<rPrEnd.lowerBound])
                            if !rPrContent.contains("<w:shd") {
                                newContent.insert(contentsOf: shdElement, at: rPrEnd.lowerBound)
                            }
                        }
                    } else {
                        // No rPr, create one
                        let rPr = "<w:rPr>\(shdElement)</w:rPr>"
                        newContent.insert(contentsOf: rPr, at: matchRange.upperBound)
                    }
                }
            }
        }

        documentXML.replaceSubrange(para.range, with: newContent)
    }

    /// Apply strikethrough to paragraph at given index
    func strikethrough(at index: Int, withHighlight: Bool = false) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        var newContent = para.content

        // Remove permission markers (they cause grey appearance in Word)
        let permStartPattern = #"<w:permStart[^/]*/>"#
        if let permStartRegex = try? NSRegularExpression(pattern: permStartPattern) {
            let permStartRange = NSRange(newContent.startIndex..., in: newContent)
            newContent = permStartRegex.stringByReplacingMatches(in: newContent, range: permStartRange, withTemplate: "")
        }
        let permEndPattern = #"<w:permEnd[^/]*/>"#
        if let permEndRegex = try? NSRegularExpression(pattern: permEndPattern) {
            let permEndRange = NSRange(newContent.startIndex..., in: newContent)
            newContent = permEndRegex.stringByReplacingMatches(in: newContent, range: permEndRange, withTemplate: "")
        }

        // Remove any existing shading if we're applying our own
        if withHighlight {
            let shdPattern = #"<w:shd[^/]*/>"#
            if let shdRegex = try? NSRegularExpression(pattern: shdPattern) {
                let shdRange = NSRange(newContent.startIndex..., in: newContent)
                newContent = shdRegex.stringByReplacingMatches(in: newContent, range: shdRange, withTemplate: "")
            }
        }

        // Find all <w:r> elements and add strikethrough (and optionally highlight)
        let runPattern = #"<w:r>|<w:r [^>]*>"#
        if let regex = try? NSRegularExpression(pattern: runPattern) {
            let range = NSRange(newContent.startIndex..., in: newContent)
            let matches = regex.matches(in: newContent, range: range)

            for match in matches.reversed() {
                if let matchRange = Range(match.range, in: newContent) {
                    let afterRun = matchRange.upperBound
                    let remainingContent = String(newContent[afterRun...])

                    let strikeElement = "<w:strike/>"
                    // Use template's exact color: rgba(255, 254, 213) = #FFFED5
                    let highlightElement = withHighlight ? "<w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"FFFED5\"/>" : ""

                    if remainingContent.hasPrefix("<w:rPr>") {
                        // rPr exists, insert strike (and highlight) inside it
                        if let rPrEnd = newContent.range(of: "</w:rPr>", range: matchRange.upperBound..<newContent.endIndex) {
                            let rPrContent = String(newContent[matchRange.upperBound..<rPrEnd.lowerBound])
                            var toInsert = ""
                            if !rPrContent.contains("<w:strike") {
                                toInsert += strikeElement
                            }
                            if withHighlight {
                                toInsert += highlightElement
                            }
                            if !toInsert.isEmpty {
                                newContent.insert(contentsOf: toInsert, at: rPrEnd.lowerBound)
                            }
                        }
                    } else {
                        // No rPr, create one
                        let rPr = "<w:rPr>\(strikeElement)\(highlightElement)</w:rPr>"
                        newContent.insert(contentsOf: rPr, at: matchRange.upperBound)
                    }
                }
            }
        }

        documentXML.replaceSubrange(para.range, with: newContent)
    }

    /// Fill content inside brackets with gold bracket styling (matches desktop)
    /// Rewrites the paragraph with gold brackets and cream highlighted content
    /// If content is empty, creates a wide placeholder with 40 spaces
    /// - Parameters:
    ///   - index: Paragraph index
    ///   - content: Content to fill inside brackets
    ///   - highlight: Whether to apply gold brackets with cream highlight (default: true)
    func fillBracketContent(at index: Int, content: String, highlight: Bool = true, spacingAfter: Int = 0) {
        // Use wide padding for empty content (30+ spaces for proper placeholder)
        let displayContent = content.isEmpty ? "                                        " : content
        // Use setParagraphText which now creates gold brackets
        setParagraphText(at: index, text: displayContent, highlight: highlight, spacingAfter: spacingAfter)
    }

    /// Set signature line content - only highlights the bracketed portions, not labels like "Signed" and "Date"
    /// The template already contains the brackets, this just fills them with content
    /// - Parameters:
    ///   - index: Paragraph index
    ///   - signatureContent: Content for signature bracket (can be empty for blank signature space)
    ///   - dateContent: Content for date bracket
    func setSignatureContent(at index: Int, signatureContent: String, dateContent: String) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        var newContent = para.content

        // Extract all text to find the full signature line structure
        let textPattern = #"<w:t[^>]*>([^<]*)</w:t>"#
        guard let regex = try? NSRegularExpression(pattern: textPattern) else { return }

        let range = NSRange(newContent.startIndex..., in: newContent)
        let matches = regex.matches(in: newContent, range: range)

        // Build full text
        var fullText = ""
        for match in matches {
            if match.numberOfRanges > 1,
               let textNSRange = Range(match.range(at: 1), in: newContent) {
                fullText += String(newContent[textNSRange])
            }
        }

        // The template has format like: "Signed [              ]                    Date [              ]"
        // We need to fill the brackets while preserving the structure

        // Find all bracket pairs
        var modifiedText = fullText
        var bracketPairs: [(openIndex: String.Index, closeIndex: String.Index)] = []
        var searchStart = modifiedText.startIndex

        while let openIdx = modifiedText.range(of: "[", range: searchStart..<modifiedText.endIndex),
              let closeIdx = modifiedText.range(of: "]", range: openIdx.upperBound..<modifiedText.endIndex) {
            bracketPairs.append((openIndex: openIdx.lowerBound, closeIndex: closeIdx.lowerBound))
            searchStart = closeIdx.upperBound
        }

        // Replace bracket contents (in reverse order to preserve indices)
        if bracketPairs.count >= 2 {
            // Second bracket is for date
            let dateBracket = bracketPairs[1]
            let dateRangeStart = modifiedText.index(after: dateBracket.openIndex)
            modifiedText.replaceSubrange(dateRangeStart..<dateBracket.closeIndex, with: dateContent)

            // First bracket is for signature (need to recalculate after first replacement)
            if let sigOpen = modifiedText.firstIndex(of: "[") {
                let sigClose = modifiedText[modifiedText.index(after: sigOpen)...].firstIndex(of: "]") ?? modifiedText.endIndex
                let sigRangeStart = modifiedText.index(after: sigOpen)
                // Use spaces to keep signature area if empty
                let sigContent = signatureContent.isEmpty ? "                    " : signatureContent
                modifiedText.replaceSubrange(sigRangeStart..<sigClose, with: sigContent)
            }
        } else if bracketPairs.count == 1 {
            // Only one bracket - just fill it
            let bracket = bracketPairs[0]
            let rangeStart = modifiedText.index(after: bracket.openIndex)
            modifiedText.replaceSubrange(rangeStart..<bracket.closeIndex, with: dateContent)
        }

        // Clear all text runs and put new text in first one
        var processedContent = newContent
        for match in matches.reversed() {
            if let matchRange = Range(match.range, in: processedContent) {
                processedContent.replaceSubrange(matchRange, with: "<w:t></w:t>")
            }
        }

        if let firstTRange = processedContent.range(of: "<w:t></w:t>") {
            let escapedText = escapeXML(modifiedText)
            processedContent.replaceSubrange(firstTRange, with: "<w:t>\(escapedText)</w:t>")
        }

        documentXML.replaceSubrange(para.range, with: processedContent)

        // Only highlight the date content if provided (not the labels)
        // This is handled by the template's existing formatting
    }

    /// Set signature line content with time - handles "Signed [  ] Date [  ] Time [  ]" format
    /// - Parameters:
    ///   - index: Paragraph index
    ///   - signatureContent: Content for signature bracket
    ///   - dateContent: Content for date bracket
    ///   - timeContent: Content for time bracket
    func setSignatureContentWithTime(at index: Int, signatureContent: String, dateContent: String, timeContent: String) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        var newContent = para.content

        let textPattern = #"<w:t[^>]*>([^<]*)</w:t>"#
        guard let regex = try? NSRegularExpression(pattern: textPattern) else { return }

        let range = NSRange(newContent.startIndex..., in: newContent)
        let matches = regex.matches(in: newContent, range: range)

        var fullText = ""
        for match in matches {
            if match.numberOfRanges > 1,
               let textNSRange = Range(match.range(at: 1), in: newContent) {
                fullText += String(newContent[textNSRange])
            }
        }

        // Find all bracket pairs
        var modifiedText = fullText
        var bracketPairs: [(openIndex: String.Index, closeIndex: String.Index)] = []
        var searchStart = modifiedText.startIndex

        while let openIdx = modifiedText.range(of: "[", range: searchStart..<modifiedText.endIndex),
              let closeIdx = modifiedText.range(of: "]", range: openIdx.upperBound..<modifiedText.endIndex) {
            bracketPairs.append((openIndex: openIdx.lowerBound, closeIndex: closeIdx.lowerBound))
            searchStart = closeIdx.upperBound
        }

        // Replace bracket contents in reverse order (time, date, signature)
        if bracketPairs.count >= 3 {
            // Third bracket is for time
            let timeBracket = bracketPairs[2]
            let timeRangeStart = modifiedText.index(after: timeBracket.openIndex)
            modifiedText.replaceSubrange(timeRangeStart..<timeBracket.closeIndex, with: timeContent)
        }

        // Re-find brackets after first modification
        bracketPairs.removeAll()
        searchStart = modifiedText.startIndex
        while let openIdx = modifiedText.range(of: "[", range: searchStart..<modifiedText.endIndex),
              let closeIdx = modifiedText.range(of: "]", range: openIdx.upperBound..<modifiedText.endIndex) {
            bracketPairs.append((openIndex: openIdx.lowerBound, closeIndex: closeIdx.lowerBound))
            searchStart = closeIdx.upperBound
        }

        if bracketPairs.count >= 2 {
            // Second bracket is for date
            let dateBracket = bracketPairs[1]
            let dateRangeStart = modifiedText.index(after: dateBracket.openIndex)
            modifiedText.replaceSubrange(dateRangeStart..<dateBracket.closeIndex, with: dateContent)
        }

        // Re-find brackets after second modification
        bracketPairs.removeAll()
        searchStart = modifiedText.startIndex
        while let openIdx = modifiedText.range(of: "[", range: searchStart..<modifiedText.endIndex),
              let closeIdx = modifiedText.range(of: "]", range: openIdx.upperBound..<modifiedText.endIndex) {
            bracketPairs.append((openIndex: openIdx.lowerBound, closeIndex: closeIdx.lowerBound))
            searchStart = closeIdx.upperBound
        }

        if !bracketPairs.isEmpty {
            // First bracket is for signature
            let sigBracket = bracketPairs[0]
            let sigRangeStart = modifiedText.index(after: sigBracket.openIndex)
            let sigContent = signatureContent.isEmpty ? "                    " : signatureContent
            modifiedText.replaceSubrange(sigRangeStart..<sigBracket.closeIndex, with: sigContent)
        }

        // Clear all text runs and put new text in first one
        var processedContent = newContent
        for match in matches.reversed() {
            if let matchRange = Range(match.range, in: processedContent) {
                processedContent.replaceSubrange(matchRange, with: "<w:t></w:t>")
            }
        }

        if let firstTRange = processedContent.range(of: "<w:t></w:t>") {
            let escapedText = escapeXML(modifiedText)
            processedContent.replaceSubrange(firstTRange, with: "<w:t>\(escapedText)</w:t>")
        }

        documentXML.replaceSubrange(para.range, with: processedContent)
    }

    /// Fill multiple bracket contents in a single paragraph (for lines like "[date] at [time]")
    /// - Parameters:
    ///   - index: Paragraph index
    ///   - contents: Array of contents to fill in each bracket (in order)
    ///   - highlight: Whether to highlight filled content
    func fillMultipleBrackets(at index: Int, contents: [String], highlight: Bool = true) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        var newContent = para.content

        let textPattern = #"<w:t[^>]*>([^<]*)</w:t>"#
        guard let regex = try? NSRegularExpression(pattern: textPattern) else { return }

        let range = NSRange(newContent.startIndex..., in: newContent)
        let matches = regex.matches(in: newContent, range: range)

        var fullText = ""
        for match in matches {
            if match.numberOfRanges > 1,
               let textNSRange = Range(match.range(at: 1), in: newContent) {
                fullText += String(newContent[textNSRange])
            }
        }

        var modifiedText = fullText

        // Fill brackets in reverse order to preserve indices
        for (idx, content) in contents.enumerated().reversed() {
            // Find all bracket pairs
            var bracketPairs: [(openIndex: String.Index, closeIndex: String.Index)] = []
            var searchStart = modifiedText.startIndex

            while let openIdx = modifiedText.range(of: "[", range: searchStart..<modifiedText.endIndex),
                  let closeIdx = modifiedText.range(of: "]", range: openIdx.upperBound..<modifiedText.endIndex) {
                bracketPairs.append((openIndex: openIdx.lowerBound, closeIndex: closeIdx.lowerBound))
                searchStart = closeIdx.upperBound
            }

            if idx < bracketPairs.count {
                let bracket = bracketPairs[idx]
                let rangeStart = modifiedText.index(after: bracket.openIndex)
                modifiedText.replaceSubrange(rangeStart..<bracket.closeIndex, with: content)
            }
        }

        // Clear all text runs and put new text in first one
        var processedContent = newContent
        for match in matches.reversed() {
            if let matchRange = Range(match.range, in: processedContent) {
                processedContent.replaceSubrange(matchRange, with: "<w:t></w:t>")
            }
        }

        if let firstTRange = processedContent.range(of: "<w:t></w:t>") {
            let escapedText = escapeXML(modifiedText)
            processedContent.replaceSubrange(firstTRange, with: "<w:t>\(escapedText)</w:t>")
        }

        documentXML.replaceSubrange(para.range, with: processedContent)

        // Apply highlight if any content is non-empty
        if highlight && contents.contains(where: { !$0.isEmpty }) {
            highlightYellow(at: index)
        }
    }

    /// Set paragraph with selective highlighting - provide the three parts directly
    /// Creates separate runs: before (no highlight), highlighted text (yellow), after (no highlight)
    /// - Parameters:
    ///   - index: Paragraph index
    ///   - beforeText: Text before the highlighted portion (no highlight)
    ///   - highlightedText: Text to highlight (yellow background)
    ///   - afterText: Text after the highlighted portion (no highlight)
    func setParagraphWithSelectiveHighlight(at index: Int, beforeText: String, highlightedText: String, afterText: String) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        let oldContent = para.content

        // Extract paragraph properties (w:pPr) if they exist
        var pPr = ""
        let pPrPattern = #"<w:pPr>.*?</w:pPr>"#
        if let pPrRegex = try? NSRegularExpression(pattern: pPrPattern, options: .dotMatchesLineSeparators),
           let match = pPrRegex.firstMatch(in: oldContent, range: NSRange(oldContent.startIndex..., in: oldContent)),
           let matchRange = Range(match.range, in: oldContent) {
            pPr = String(oldContent[matchRange])
        }

        // Build three separate runs with proper XML structure
        let escapedBefore = escapeXML(beforeText)
        let escapedHighlighted = escapeXML(highlightedText)
        let escapedAfter = escapeXML(afterText)

        // Arial font element
        let arialFont = "<w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\" w:cs=\"Arial\"/>"

        // Plain run with Arial font
        let plainRPr = "<w:rPr>\(arialFont)</w:rPr>"

        // Highlighted run uses w:shd for yellow background + Arial font
        let highlightRPr = "<w:rPr>\(arialFont)<w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"FFFFCC\"/></w:rPr>"

        // Create three complete runs
        var runs = ""
        if !beforeText.isEmpty {
            runs += "<w:r>\(plainRPr)<w:t xml:space=\"preserve\">\(escapedBefore)</w:t></w:r>"
        }
        if !highlightedText.isEmpty {
            runs += "<w:r>\(highlightRPr)<w:t xml:space=\"preserve\">\(escapedHighlighted)</w:t></w:r>"
        }
        if !afterText.isEmpty {
            runs += "<w:r>\(plainRPr)<w:t xml:space=\"preserve\">\(escapedAfter)</w:t></w:r>"
        }

        // Build new paragraph from scratch
        let newParagraph = "<w:p>\(pPr)\(runs)</w:p>"

        documentXML.replaceSubrange(para.range, with: newParagraph)
    }

    /// Set signature line with selective highlighting - only brackets content is highlighted
    /// Format: "Signed [signature] Date [date]" where only [signature] and [date] are highlighted
    /// Gold bold brackets with cream background (matches desktop styling)
    /// - Parameters:
    ///   - index: Paragraph index
    ///   - signatureContent: Content for signature bracket (spaces for blank)
    ///   - dateContent: Content for date bracket
    func setSignatureWithSelectiveHighlight(at index: Int, signatureContent: String, dateContent: String) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        let newContent = para.content

        // Extract paragraph properties if they exist (preserve paragraph formatting)
        var pPrContent = ""
        if let pPrMatch = newContent.range(of: #"<w:pPr>.*?</w:pPr>"#, options: .regularExpression) {
            pPrContent = String(newContent[pPrMatch])
        }

        // Extract the paragraph opening tag
        var pOpenTag = "<w:p>"
        if let pOpenMatch = newContent.range(of: #"<w:p[^>]*>"#, options: .regularExpression) {
            pOpenTag = String(newContent[pOpenMatch])
        }

        let sigContent = signatureContent.isEmpty ? "                                        " : signatureContent
        let dateStr = dateContent.isEmpty ? "                    " : dateContent

        // Create runs: "Signed " (plain), [sig] (gold brackets), " Date " (plain), [date] (gold brackets)
        let newRuns = "<w:r>\(plainRPr)<w:t xml:space=\"preserve\">Signed </w:t></w:r>\(bracketedRun(sigContent))<w:r>\(plainRPr)<w:t xml:space=\"preserve\"> Date </w:t></w:r>\(bracketedRun(dateStr))"

        // Build complete new paragraph (removes old runs, permission markers, etc.)
        let finalContent = "\(pOpenTag)\(pPrContent)\(newRuns)</w:p>"

        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Set paragraph to "Signed [    ] Date [    ]" format with cream highlight and gold brackets
    func setSignatureWithCreamHighlight(at index: Int, signatureContent: String, dateContent: String) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        let newContent = para.content

        // Extract paragraph properties if they exist (preserve paragraph formatting)
        var pPrContent = ""
        if let pPrMatch = newContent.range(of: #"<w:pPr>.*?</w:pPr>"#, options: .regularExpression) {
            pPrContent = String(newContent[pPrMatch])
        }

        // Extract the paragraph opening tag
        var pOpenTag = "<w:p>"
        if let pOpenMatch = newContent.range(of: #"<w:p[^>]*>"#, options: .regularExpression) {
            pOpenTag = String(newContent[pOpenMatch])
        }

        let sigContent = signatureContent.isEmpty ? "                                        " : signatureContent
        let dateStr = dateContent.isEmpty ? "                    " : dateContent

        // Run properties with cream highlight and gold brackets (no bold)
        let plainRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/></w:rPr>"
        let goldBracketRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:b/><w:color w:val=\"\(kGoldBracketColor)\"/><w:sz w:val=\"28\"/><w:szCs w:val=\"28\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"
        let contentRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"

        // Create runs: "Signed " (plain), [sig] (cream+gold), " Date " (plain), [date] (cream+gold)
        let newRuns = "<w:r>\(plainRPr)<w:t xml:space=\"preserve\">Signed </w:t></w:r><w:r>\(goldBracketRPr)<w:t>[</w:t></w:r><w:r>\(contentRPr)<w:t xml:space=\"preserve\">\(sigContent)</w:t></w:r><w:r>\(goldBracketRPr)<w:t>]</w:t></w:r><w:r>\(plainRPr)<w:t xml:space=\"preserve\"> Date </w:t></w:r><w:r>\(goldBracketRPr)<w:t>[</w:t></w:r><w:r>\(contentRPr)<w:t xml:space=\"preserve\">\(dateStr)</w:t></w:r><w:r>\(goldBracketRPr)<w:t>]</w:t></w:r>"

        // Build complete new paragraph (removes old runs, permission markers, etc.)
        let finalContent = "\(pOpenTag)\(pPrContent)\(newRuns)</w:p>"

        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Set paragraph to "Signed [    ] PRINT NAME [    ]" format with gold brackets
    func setSignedPrintNameLine(at index: Int, signatureContent: String, nameContent: String) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        let newContent = para.content

        var pPrContent = ""
        if let pPrMatch = newContent.range(of: #"<w:pPr>.*?</w:pPr>"#, options: .regularExpression) {
            pPrContent = String(newContent[pPrMatch])
        }

        var pOpenTag = "<w:p>"
        if let pOpenMatch = newContent.range(of: #"<w:p[^>]*>"#, options: .regularExpression) {
            pOpenTag = String(newContent[pOpenMatch])
        }

        let sigContent = signatureContent.isEmpty ? "                              " : signatureContent
        let nmContent = nameContent.isEmpty ? "                              " : nameContent

        let newRuns = "<w:r>\(plainRPr)<w:t xml:space=\"preserve\">Signed </w:t></w:r>\(bracketedRun(sigContent))<w:r>\(plainRPr)<w:t xml:space=\"preserve\">    PRINT NAME </w:t></w:r>\(bracketedRun(nmContent))"

        let finalContent = "\(pOpenTag)\(pPrContent)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Set paragraph to "Profession [    ] Date [    ]" format with gold brackets
    func setProfessionDateLine(at index: Int, professionContent: String, dateContent: String) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        let newContent = para.content

        var pPrContent = ""
        if let pPrMatch = newContent.range(of: #"<w:pPr>.*?</w:pPr>"#, options: .regularExpression) {
            pPrContent = String(newContent[pPrMatch])
        }

        var pOpenTag = "<w:p>"
        if let pOpenMatch = newContent.range(of: #"<w:p[^>]*>"#, options: .regularExpression) {
            pOpenTag = String(newContent[pOpenMatch])
        }

        let profContent = professionContent.isEmpty ? "                              " : professionContent
        let dtContent = dateContent.isEmpty ? "                    " : dateContent

        let newRuns = "<w:r>\(plainRPr)<w:t xml:space=\"preserve\">Profession </w:t></w:r>\(bracketedRun(profContent))<w:r>\(plainRPr)<w:t xml:space=\"preserve\">    Date </w:t></w:r>\(bracketedRun(dtContent))"

        let finalContent = "\(pOpenTag)\(pPrContent)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Set paragraph to "Signed [    ]" format with gold brackets
    func setSignedOnlyLine(at index: Int, signatureContent: String) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        let newContent = para.content

        var pPrContent = ""
        if let pPrMatch = newContent.range(of: #"<w:pPr>.*?</w:pPr>"#, options: .regularExpression) {
            pPrContent = String(newContent[pPrMatch])
        }

        var pOpenTag = "<w:p>"
        if let pOpenMatch = newContent.range(of: #"<w:p[^>]*>"#, options: .regularExpression) {
            pOpenTag = String(newContent[pOpenMatch])
        }

        let sigContent = signatureContent.isEmpty ? "                                                  " : signatureContent

        let newRuns = "<w:r>\(plainRPr)<w:t xml:space=\"preserve\">Signed</w:t></w:r>\(bracketedRun(sigContent))"

        let finalContent = "\(pOpenTag)\(pPrContent)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Set paragraph to "Signed [    ] PRINT NAME [    ]" with cream highlight and gold brackets
    func setSignedPrintNameLineHighlighted(at index: Int, signatureContent: String, nameContent: String) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        let newContent = para.content

        var pPrContent = ""
        if let pPrMatch = newContent.range(of: #"<w:pPr>.*?</w:pPr>"#, options: .regularExpression) {
            pPrContent = String(newContent[pPrMatch])
        }

        var pOpenTag = "<w:p>"
        if let pOpenMatch = newContent.range(of: #"<w:p[^>]*>"#, options: .regularExpression) {
            pOpenTag = String(newContent[pOpenMatch])
        }

        let sigContent = signatureContent.isEmpty ? "                              " : signatureContent
        let nmContent = nameContent.isEmpty ? "                              " : nameContent

        let plainRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/></w:rPr>"
        let goldBracketRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:b/><w:color w:val=\"\(kGoldBracketColor)\"/><w:sz w:val=\"28\"/><w:szCs w:val=\"28\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"
        let creamRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"

        let newRuns = "<w:r>\(plainRPr)<w:t xml:space=\"preserve\">Signed </w:t></w:r><w:r>\(goldBracketRPr)<w:t>[</w:t></w:r><w:r>\(creamRPr)<w:t xml:space=\"preserve\">\(sigContent)</w:t></w:r><w:r>\(goldBracketRPr)<w:t>]</w:t></w:r><w:r>\(plainRPr)<w:t xml:space=\"preserve\">    PRINT NAME </w:t></w:r><w:r>\(goldBracketRPr)<w:t>[</w:t></w:r><w:r>\(creamRPr)<w:t xml:space=\"preserve\">\(nmContent)</w:t></w:r><w:r>\(goldBracketRPr)<w:t>]</w:t></w:r>"

        let finalContent = "\(pOpenTag)\(pPrContent)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Set paragraph to "Profession [    ] Date [    ]" with cream highlight and gold brackets
    func setProfessionDateLineHighlighted(at index: Int, professionContent: String, dateContent: String) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        let newContent = para.content

        var pPrContent = ""
        if let pPrMatch = newContent.range(of: #"<w:pPr>.*?</w:pPr>"#, options: .regularExpression) {
            pPrContent = String(newContent[pPrMatch])
        }

        var pOpenTag = "<w:p>"
        if let pOpenMatch = newContent.range(of: #"<w:p[^>]*>"#, options: .regularExpression) {
            pOpenTag = String(newContent[pOpenMatch])
        }

        let profContent = professionContent.isEmpty ? "                              " : professionContent
        let dtContent = dateContent.isEmpty ? "                    " : dateContent

        let plainRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/></w:rPr>"
        let goldBracketRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:b/><w:color w:val=\"\(kGoldBracketColor)\"/><w:sz w:val=\"28\"/><w:szCs w:val=\"28\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"
        let creamRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"

        let newRuns = "<w:r>\(plainRPr)<w:t xml:space=\"preserve\">Profession </w:t></w:r><w:r>\(goldBracketRPr)<w:t>[</w:t></w:r><w:r>\(creamRPr)<w:t xml:space=\"preserve\">\(profContent)</w:t></w:r><w:r>\(goldBracketRPr)<w:t>]</w:t></w:r><w:r>\(plainRPr)<w:t xml:space=\"preserve\">    Date </w:t></w:r><w:r>\(goldBracketRPr)<w:t>[</w:t></w:r><w:r>\(creamRPr)<w:t xml:space=\"preserve\">\(dtContent)</w:t></w:r><w:r>\(goldBracketRPr)<w:t>]</w:t></w:r>"

        let finalContent = "\(pOpenTag)\(pPrContent)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Set paragraph to "Signed [    ]" with cream highlight and gold brackets
    func setSignedOnlyLineHighlighted(at index: Int, signatureContent: String) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        let newContent = para.content

        var pPrContent = ""
        if let pPrMatch = newContent.range(of: #"<w:pPr>.*?</w:pPr>"#, options: .regularExpression) {
            pPrContent = String(newContent[pPrMatch])
        }

        var pOpenTag = "<w:p>"
        if let pOpenMatch = newContent.range(of: #"<w:p[^>]*>"#, options: .regularExpression) {
            pOpenTag = String(newContent[pOpenMatch])
        }

        let sigContent = signatureContent.isEmpty ? "                                                  " : signatureContent

        let plainRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/></w:rPr>"
        let goldBracketRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:b/><w:color w:val=\"\(kGoldBracketColor)\"/><w:sz w:val=\"28\"/><w:szCs w:val=\"28\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"
        let creamRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"

        let newRuns = "<w:r>\(plainRPr)<w:t xml:space=\"preserve\">Signed </w:t></w:r><w:r>\(goldBracketRPr)<w:t>[</w:t></w:r><w:r>\(creamRPr)<w:t xml:space=\"preserve\">\(sigContent)</w:t></w:r><w:r>\(goldBracketRPr)<w:t>]</w:t></w:r>"

        let finalContent = "\(pOpenTag)\(pPrContent)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Set paragraph to "PRINT NAME[    ]                   Date[    ]" format with gold brackets
    func setPrintNameDateLine(at index: Int, nameContent: String, dateContent: String) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        let newContent = para.content

        var pPrContent = ""
        if let pPrMatch = newContent.range(of: #"<w:pPr>.*?</w:pPr>"#, options: .regularExpression) {
            pPrContent = String(newContent[pPrMatch])
        }

        var pOpenTag = "<w:p>"
        if let pOpenMatch = newContent.range(of: #"<w:p[^>]*>"#, options: .regularExpression) {
            pOpenTag = String(newContent[pOpenMatch])
        }

        let nmContent = nameContent.isEmpty ? "                              " : nameContent
        let dtContent = dateContent.isEmpty ? "                    " : dateContent

        let newRuns = "<w:r>\(plainRPr)<w:t xml:space=\"preserve\">PRINT NAME</w:t></w:r>\(bracketedRun(nmContent))<w:r>\(plainRPr)<w:t xml:space=\"preserve\">                             Date</w:t></w:r>\(bracketedRun(dtContent))"

        let finalContent = "\(pOpenTag)\(pPrContent)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Set paragraph to "Signed[    ] <suffix text>" format with gold brackets
    func setSignedWithSuffixLine(at index: Int, signatureContent: String, suffix: String) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        let newContent = para.content

        var pPrContent = ""
        if let pPrMatch = newContent.range(of: #"<w:pPr>.*?</w:pPr>"#, options: .regularExpression) {
            pPrContent = String(newContent[pPrMatch])
        }

        var pOpenTag = "<w:p>"
        if let pOpenMatch = newContent.range(of: #"<w:p[^>]*>"#, options: .regularExpression) {
            pOpenTag = String(newContent[pOpenMatch])
        }

        let sigContent = signatureContent.isEmpty ? "                              " : signatureContent
        let escapedSuffix = escapeXML(suffix)

        let newRuns = "<w:r>\(plainRPr)<w:t xml:space=\"preserve\">Signed</w:t></w:r>\(bracketedRun(sigContent))<w:r>\(plainRPr)<w:t xml:space=\"preserve\"> \(escapedSuffix)</w:t></w:r>"

        let finalContent = "\(pOpenTag)\(pPrContent)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Set paragraph to "Date[content]" format with gold brackets
    func setDateLine(at index: Int, dateContent: String) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        let newContent = para.content

        var pPrContent = ""
        if let pPrMatch = newContent.range(of: #"<w:pPr>.*?</w:pPr>"#, options: .regularExpression) {
            pPrContent = String(newContent[pPrMatch])
        }

        var pOpenTag = "<w:p>"
        if let pOpenMatch = newContent.range(of: #"<w:p[^>]*>"#, options: .regularExpression) {
            pOpenTag = String(newContent[pOpenMatch])
        }

        let content = dateContent.isEmpty ? "                                                            " : dateContent

        let newRuns = "<w:r>\(plainRPr)<w:t xml:space=\"preserve\">Date</w:t></w:r>\(bracketedRun(content))"

        let finalContent = "\(pOpenTag)\(pPrContent)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Set paragraph to "Time[content]" format with gold brackets
    func setTimeLine(at index: Int, timeContent: String) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        let newContent = para.content

        var pPrContent = ""
        if let pPrMatch = newContent.range(of: #"<w:pPr>.*?</w:pPr>"#, options: .regularExpression) {
            pPrContent = String(newContent[pPrMatch])
        }

        var pOpenTag = "<w:p>"
        if let pOpenMatch = newContent.range(of: #"<w:p[^>]*>"#, options: .regularExpression) {
            pOpenTag = String(newContent[pOpenMatch])
        }

        let content = timeContent.isEmpty ? "                                                            " : timeContent

        let newRuns = "<w:r>\(plainRPr)<w:t xml:space=\"preserve\">Time</w:t></w:r>\(bracketedRun(content))"

        let finalContent = "\(pOpenTag)\(pPrContent)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Set paragraph to "Date[date]                    Time[time]" format with gold brackets
    func setDateTimeLine(at index: Int, dateContent: String, timeContent: String) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        let newContent = para.content

        var pPrContent = ""
        if let pPrMatch = newContent.range(of: #"<w:pPr>.*?</w:pPr>"#, options: .regularExpression) {
            pPrContent = String(newContent[pPrMatch])
        }

        var pOpenTag = "<w:p>"
        if let pOpenMatch = newContent.range(of: #"<w:p[^>]*>"#, options: .regularExpression) {
            pOpenTag = String(newContent[pOpenMatch])
        }

        let dtContent = dateContent.isEmpty ? "                                        " : dateContent
        let tmContent = timeContent.isEmpty ? "                    " : timeContent

        // Format: "Date" (plain) [date] (gold brackets) "                    Time" (plain) [time] (gold brackets)
        let newRuns = "<w:r>\(plainRPr)<w:t xml:space=\"preserve\">Date</w:t></w:r>\(bracketedRun(dtContent))<w:r>\(plainRPr)<w:t xml:space=\"preserve\">                                        Time</w:t></w:r>\(bracketedRun(tmContent))"

        let finalContent = "\(pOpenTag)\(pPrContent)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Set "Date[ ] Time[ ]" line with gold brackets and cream highlight
    func setDateTimeLineHighlighted(at index: Int, dateContent: String, timeContent: String) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]

        let dateSpaces = "                                        "
        let timeSpaces = "                    "
        let dtContent = dateContent.isEmpty ? dateSpaces : dateContent
        let tmContent = timeContent.isEmpty ? timeSpaces : timeContent

        let plainRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/></w:rPr>"
        let goldBracketRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:b/><w:color w:val=\"\(kGoldBracketColor)\"/><w:sz w:val=\"28\"/><w:szCs w:val=\"28\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"
        let contentRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"

        let newRuns = "<w:r>\(plainRPr)<w:t xml:space=\"preserve\">Date</w:t></w:r><w:r>\(goldBracketRPr)<w:t>[</w:t></w:r><w:r>\(contentRPr)<w:t xml:space=\"preserve\">\(dtContent)</w:t></w:r><w:r>\(goldBracketRPr)<w:t>]</w:t></w:r><w:r>\(plainRPr)<w:t xml:space=\"preserve\">                                        Time</w:t></w:r><w:r>\(goldBracketRPr)<w:t>[</w:t></w:r><w:r>\(contentRPr)<w:t xml:space=\"preserve\">\(tmContent)</w:t></w:r><w:r>\(goldBracketRPr)<w:t>]</w:t></w:r>"

        let pPr = "<w:pPr><w:spacing w:after=\"120\"/></w:pPr>"
        let finalContent = "<w:p>\(pPr)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Set paragraph to "PREFIX Date [date]" format where PREFIX is plain text, with gold brackets
    func setPrefixDateLine(at index: Int, prefix: String, dateContent: String) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        let newContent = para.content

        var pPrContent = ""
        if let pPrMatch = newContent.range(of: #"<w:pPr>.*?</w:pPr>"#, options: .regularExpression) {
            pPrContent = String(newContent[pPrMatch])
        }

        var pOpenTag = "<w:p>"
        if let pOpenMatch = newContent.range(of: #"<w:p[^>]*>"#, options: .regularExpression) {
            pOpenTag = String(newContent[pOpenMatch])
        }

        let content = dateContent.isEmpty ? "                                                            " : dateContent
        let escapedPrefix = escapeXML(prefix)

        let newRuns = "<w:r>\(plainRPr)<w:t xml:space=\"preserve\">\(escapedPrefix) Date </w:t></w:r>\(bracketedRun(content))"

        let finalContent = "\(pOpenTag)\(pPrContent)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Set "PREFIX Date[ ]" line with gold brackets and cream highlight
    func setPrefixDateLineHighlighted(at index: Int, prefix: String, dateContent: String) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]

        let dateSpaces = "                                                            "
        let dtContent = dateContent.isEmpty ? dateSpaces : dateContent
        let escapedPrefix = escapeXML(prefix)

        let plainRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/></w:rPr>"
        let goldBracketRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:b/><w:color w:val=\"\(kGoldBracketColor)\"/><w:sz w:val=\"28\"/><w:szCs w:val=\"28\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"
        let contentRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"

        let newRuns = "<w:r>\(plainRPr)<w:t xml:space=\"preserve\">\(escapedPrefix) Date </w:t></w:r><w:r>\(goldBracketRPr)<w:t>[</w:t></w:r><w:r>\(contentRPr)<w:t xml:space=\"preserve\">\(dtContent)</w:t></w:r><w:r>\(goldBracketRPr)<w:t>]</w:t></w:r>"

        let pPr = "<w:pPr><w:spacing w:after=\"120\"/></w:pPr>"
        let finalContent = "<w:p>\(pPr)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Set paragraph to "PRINT NAME [content]" format with gold brackets
    func setPrintNameLine(at index: Int, nameContent: String) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        let newContent = para.content

        var pPrContent = ""
        if let pPrMatch = newContent.range(of: #"<w:pPr>.*?</w:pPr>"#, options: .regularExpression) {
            pPrContent = String(newContent[pPrMatch])
        }

        var pOpenTag = "<w:p>"
        if let pOpenMatch = newContent.range(of: #"<w:p[^>]*>"#, options: .regularExpression) {
            pOpenTag = String(newContent[pOpenMatch])
        }

        let content = nameContent.isEmpty ? "                                                            " : nameContent

        let newRuns = "<w:r>\(plainRPr)<w:t xml:space=\"preserve\">PRINT NAME</w:t></w:r>\(bracketedRun(content))"

        let finalContent = "\(pOpenTag)\(pPrContent)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Set paragraph to an empty bracket line "[                    ]" with gold brackets
    func setEmptyBracketLine(at index: Int) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        let newContent = para.content

        var pPrContent = ""
        if let pPrMatch = newContent.range(of: #"<w:pPr>.*?</w:pPr>"#, options: .regularExpression) {
            pPrContent = String(newContent[pPrMatch])
        }

        var pOpenTag = "<w:p>"
        if let pOpenMatch = newContent.range(of: #"<w:p[^>]*>"#, options: .regularExpression) {
            pOpenTag = String(newContent[pOpenMatch])
        }

        // Wide empty bracket for fillable area
        let bracketContent = "                                                                                    "
        let newRuns = bracketedRun(bracketContent)

        let finalContent = "\(pOpenTag)\(pPrContent)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Set paragraph to just "[content]" with gold brackets - NO label text, just the bracketed content
    /// If content is empty, creates empty bracket "[                    ]"
    func setBracketLine(at index: Int, content: String) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        let newContent = para.content

        var pPrContent = ""
        if let pPrMatch = newContent.range(of: #"<w:pPr>.*?</w:pPr>"#, options: .regularExpression) {
            pPrContent = String(newContent[pPrMatch])
        }

        var pOpenTag = "<w:p>"
        if let pOpenMatch = newContent.range(of: #"<w:p[^>]*>"#, options: .regularExpression) {
            pOpenTag = String(newContent[pOpenMatch])
        }

        // If content is empty, use wide spacing for fillable area
        let bracketContent = content.isEmpty ? "                                        " : content
        let newRuns = bracketedRun(bracketContent)

        let finalContent = "\(pOpenTag)\(pPrContent)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Set paragraph text with opening bracket "[text" and gold bracket (NO closing bracket)
    func setTextWithOpeningBracket(at index: Int, text: String) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        let newContent = para.content

        var pPrContent = ""
        if let pPrMatch = newContent.range(of: #"<w:pPr>.*?</w:pPr>"#, options: .regularExpression) {
            pPrContent = String(newContent[pPrMatch])
        }

        var pOpenTag = "<w:p>"
        if let pOpenMatch = newContent.range(of: #"<w:p[^>]*>"#, options: .regularExpression) {
            pOpenTag = String(newContent[pOpenMatch])
        }

        let escapedText = escapeXML(text)
        // Opening gold bracket, then content with cream highlight, NO closing bracket
        let newRuns = "<w:r>\(bracketRPr)<w:t>[</w:t></w:r><w:r>\(contentRPr)<w:t xml:space=\"preserve\">\(escapedText)</w:t></w:r>"

        let finalContent = "\(pOpenTag)\(pPrContent)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Set paragraph to just a closing bracket "]" with gold bracket and padding
    func setClosingBracketLine(at index: Int) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        let newContent = para.content

        var pPrContent = ""
        if let pPrMatch = newContent.range(of: #"<w:pPr>.*?</w:pPr>"#, options: .regularExpression) {
            pPrContent = String(newContent[pPrMatch])
        }

        var pOpenTag = "<w:p>"
        if let pOpenMatch = newContent.range(of: #"<w:p[^>]*>"#, options: .regularExpression) {
            pOpenTag = String(newContent[pOpenMatch])
        }

        // Wide padding with cream highlight, then gold closing bracket
        let padding = "                                                                                    "
        let creamRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"
        let goldBracketRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:b/><w:color w:val=\"\(kGoldBracketColor)\"/><w:sz w:val=\"28\"/><w:szCs w:val=\"28\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"
        let newRuns = "<w:r>\(creamRPr)<w:t xml:space=\"preserve\">\(padding)</w:t></w:r><w:r>\(goldBracketRPr)<w:t>]</w:t></w:r>"

        let finalContent = "\(pOpenTag)\(pPrContent)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Set paragraph to "[text" with cream highlight and gold bracket (for Part 2 delivery options)
    func setTextWithOpeningBracketHighlighted(at index: Int, text: String) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        let newContent = para.content

        var pPrContent = ""
        if let pPrMatch = newContent.range(of: #"<w:pPr>.*?</w:pPr>"#, options: .regularExpression) {
            pPrContent = String(newContent[pPrMatch])
        }

        var pOpenTag = "<w:p>"
        if let pOpenMatch = newContent.range(of: #"<w:p[^>]*>"#, options: .regularExpression) {
            pOpenTag = String(newContent[pOpenMatch])
        }

        let escapedText = escapeXML(text)
        // Opening gold bracket with cream bg, then content with cream highlight, NO closing bracket
        let goldBracketRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:b/><w:color w:val=\"\(kGoldBracketColor)\"/><w:sz w:val=\"28\"/><w:szCs w:val=\"28\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"
        let creamContentRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"
        let newRuns = "<w:r>\(goldBracketRPr)<w:t>[</w:t></w:r><w:r>\(creamContentRPr)<w:t xml:space=\"preserve\">\(escapedText)</w:t></w:r>"

        let finalContent = "\(pOpenTag)\(pPrContent)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Set paragraph with selective gold bracket highlighting - middle portion gets GB
    /// Format: beforeText [highlightedText] afterText - only middle gets GB + cream
    func setParagraphWithSelectiveGoldBracket(at index: Int, beforeText: String, bracketedText: String, afterText: String) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        let oldContent = para.content

        var pPr = ""
        let pPrPattern = #"<w:pPr>.*?</w:pPr>"#
        if let pPrRegex = try? NSRegularExpression(pattern: pPrPattern, options: .dotMatchesLineSeparators),
           let match = pPrRegex.firstMatch(in: oldContent, range: NSRange(oldContent.startIndex..., in: oldContent)),
           let matchRange = Range(match.range, in: oldContent) {
            pPr = String(oldContent[matchRange])
        }

        let escapedBefore = escapeXML(beforeText)
        let escapedBracketed = escapeXML(bracketedText)
        let escapedAfter = escapeXML(afterText)

        let arialFont = "<w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\" w:cs=\"Arial\"/>"
        let plainRPr = "<w:rPr>\(arialFont)<w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/></w:rPr>"
        let goldBracketRPr = "<w:rPr>\(arialFont)<w:b/><w:color w:val=\"\(kGoldBracketColor)\"/><w:sz w:val=\"28\"/><w:szCs w:val=\"28\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"
        let creamContentRPr = "<w:rPr>\(arialFont)<w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"

        var runs = ""
        if !beforeText.isEmpty {
            runs += "<w:r>\(plainRPr)<w:t xml:space=\"preserve\">\(escapedBefore)</w:t></w:r>"
        }
        // Gold bracket opening
        runs += "<w:r>\(goldBracketRPr)<w:t>[</w:t></w:r>"
        // Bracketed content with cream highlight
        runs += "<w:r>\(creamContentRPr)<w:t xml:space=\"preserve\">\(escapedBracketed)</w:t></w:r>"
        // Gold bracket closing
        runs += "<w:r>\(goldBracketRPr)<w:t>]</w:t></w:r>"
        if !afterText.isEmpty {
            runs += "<w:r>\(plainRPr)<w:t xml:space=\"preserve\">\(escapedAfter)</w:t></w:r>"
        }

        let finalContent = "<w:p>\(pPr)\(runs)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Set paragraph with selective gold bracket highlighting AND strikethrough
    /// Format: beforeText [highlightedText] afterText - everything struck through, middle gets GB + cream
    func setParagraphWithSelectiveGoldBracketStrikethrough(at index: Int, beforeText: String, bracketedText: String, afterText: String) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        let oldContent = para.content

        var pPr = ""
        let pPrPattern = #"<w:pPr>.*?</w:pPr>"#
        if let pPrRegex = try? NSRegularExpression(pattern: pPrPattern, options: .dotMatchesLineSeparators),
           let match = pPrRegex.firstMatch(in: oldContent, range: NSRange(oldContent.startIndex..., in: oldContent)),
           let matchRange = Range(match.range, in: oldContent) {
            pPr = String(oldContent[matchRange])
        }

        let escapedBefore = escapeXML(beforeText)
        let escapedBracketed = escapeXML(bracketedText)
        let escapedAfter = escapeXML(afterText)

        let arialFont = "<w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\" w:cs=\"Arial\"/>"
        // Plain text with strikethrough and cream highlight
        let plainRPr = "<w:rPr>\(arialFont)<w:strike/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"
        // Gold bracket with strikethrough
        let goldBracketRPr = "<w:rPr>\(arialFont)<w:b/><w:strike/><w:color w:val=\"\(kGoldBracketColor)\"/><w:sz w:val=\"28\"/><w:szCs w:val=\"28\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"
        // Cream content with strikethrough
        let creamContentRPr = "<w:rPr>\(arialFont)<w:strike/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"

        var runs = ""
        if !beforeText.isEmpty {
            runs += "<w:r>\(plainRPr)<w:t xml:space=\"preserve\">\(escapedBefore)</w:t></w:r>"
        }
        // Gold bracket opening
        runs += "<w:r>\(goldBracketRPr)<w:t>[</w:t></w:r>"
        // Bracketed content with cream highlight
        runs += "<w:r>\(creamContentRPr)<w:t xml:space=\"preserve\">\(escapedBracketed)</w:t></w:r>"
        // Gold bracket closing
        runs += "<w:r>\(goldBracketRPr)<w:t>]</w:t></w:r>"
        if !afterText.isEmpty {
            runs += "<w:r>\(plainRPr)<w:t xml:space=\"preserve\">\(escapedAfter)</w:t></w:r>"
        }

        let finalContent = "<w:p>\(pPr)\(runs)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Set paragraph text with cream highlight and CLOSING gold bracket at end
    func setTextWithClosingBracketHighlighted(at index: Int, text: String) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        let newContent = para.content

        var pPrContent = ""
        if let pPrMatch = newContent.range(of: #"<w:pPr>.*?</w:pPr>"#, options: .regularExpression) {
            pPrContent = String(newContent[pPrMatch])
        }

        var pOpenTag = "<w:p>"
        if let pOpenMatch = newContent.range(of: #"<w:p[^>]*>"#, options: .regularExpression) {
            pOpenTag = String(newContent[pOpenMatch])
        }

        let escapedText = escapeXML(text)
        // Content with cream highlight, then closing gold bracket
        let goldBracketRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:b/><w:color w:val=\"\(kGoldBracketColor)\"/><w:sz w:val=\"28\"/><w:szCs w:val=\"28\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"
        let creamContentRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"
        let newRuns = "<w:r>\(creamContentRPr)<w:t xml:space=\"preserve\">\(escapedText)</w:t></w:r><w:r>\(goldBracketRPr)<w:t>]</w:t></w:r>"

        let finalContent = "\(pOpenTag)\(pPrContent)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Set paragraph text with opening gold bracket and cream highlight (preserves existing text)
    /// For H5 Part 3 delivery option 1: "[today consigning..."
    func setExistingTextWithOpeningBracketHighlighted(at index: Int, withStrikethrough: Bool = false) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        let content = para.content

        // Extract existing text content
        let textPattern = #"<w:t[^>]*>([^<]*)</w:t>"#
        guard let textRegex = try? NSRegularExpression(pattern: textPattern) else { return }
        let range = NSRange(content.startIndex..., in: content)
        let textMatches = textRegex.matches(in: content, range: range)

        var fullText = ""
        for match in textMatches {
            if match.numberOfRanges > 1,
               let textNSRange = Range(match.range(at: 1), in: content) {
                fullText += String(content[textNSRange])
            }
        }

        var pPrContent = ""
        if let pPrMatch = content.range(of: #"<w:pPr>.*?</w:pPr>"#, options: .regularExpression) {
            pPrContent = String(content[pPrMatch])
        }

        var pOpenTag = "<w:p>"
        if let pOpenMatch = content.range(of: #"<w:p[^>]*>"#, options: .regularExpression) {
            pOpenTag = String(content[pOpenMatch])
        }

        let escapedText = escapeXML(fullText)
        let strikeTag = withStrikethrough ? "<w:strike/>" : ""
        // Opening gold bracket with cream bg, then content with cream highlight
        let goldBracketRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:b/><w:color w:val=\"\(kGoldBracketColor)\"/>\(strikeTag)<w:sz w:val=\"28\"/><w:szCs w:val=\"28\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"
        let creamContentRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/>\(strikeTag)<w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"
        let newRuns = "<w:r>\(goldBracketRPr)<w:t>[</w:t></w:r><w:r>\(creamContentRPr)<w:t xml:space=\"preserve\">\(escapedText)</w:t></w:r>"

        let finalContent = "\(pOpenTag)\(pPrContent)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Set paragraph text with cream highlight only (no brackets, preserves existing text)
    /// For H5 Part 3 delivery option 2: middle option
    func setExistingTextWithCreamHighlightOnly(at index: Int, withStrikethrough: Bool = false) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        let content = para.content

        // Extract existing text content
        let textPattern = #"<w:t[^>]*>([^<]*)</w:t>"#
        guard let textRegex = try? NSRegularExpression(pattern: textPattern) else { return }
        let range = NSRange(content.startIndex..., in: content)
        let textMatches = textRegex.matches(in: content, range: range)

        var fullText = ""
        for match in textMatches {
            if match.numberOfRanges > 1,
               let textNSRange = Range(match.range(at: 1), in: content) {
                fullText += String(content[textNSRange])
            }
        }

        var pPrContent = ""
        if let pPrMatch = content.range(of: #"<w:pPr>.*?</w:pPr>"#, options: .regularExpression) {
            pPrContent = String(content[pPrMatch])
        }

        var pOpenTag = "<w:p>"
        if let pOpenMatch = content.range(of: #"<w:p[^>]*>"#, options: .regularExpression) {
            pOpenTag = String(content[pOpenMatch])
        }

        let escapedText = escapeXML(fullText)
        let strikeTag = withStrikethrough ? "<w:strike/>" : ""
        let creamContentRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/>\(strikeTag)<w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"
        let newRuns = "<w:r>\(creamContentRPr)<w:t xml:space=\"preserve\">\(escapedText)</w:t></w:r>"

        let finalContent = "\(pOpenTag)\(pPrContent)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Set paragraph text with closing gold bracket and cream highlight (preserves existing text)
    /// For H5 Part 3 delivery option 3: "...internal mail system.]"
    func setExistingTextWithClosingBracketHighlighted(at index: Int, withStrikethrough: Bool = false) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        let content = para.content

        // Extract existing text content
        let textPattern = #"<w:t[^>]*>([^<]*)</w:t>"#
        guard let textRegex = try? NSRegularExpression(pattern: textPattern) else { return }
        let range = NSRange(content.startIndex..., in: content)
        let textMatches = textRegex.matches(in: content, range: range)

        var fullText = ""
        for match in textMatches {
            if match.numberOfRanges > 1,
               let textNSRange = Range(match.range(at: 1), in: content) {
                fullText += String(content[textNSRange])
            }
        }

        var pPrContent = ""
        if let pPrMatch = content.range(of: #"<w:pPr>.*?</w:pPr>"#, options: .regularExpression) {
            pPrContent = String(content[pPrMatch])
        }

        var pOpenTag = "<w:p>"
        if let pOpenMatch = content.range(of: #"<w:p[^>]*>"#, options: .regularExpression) {
            pOpenTag = String(content[pOpenMatch])
        }

        let escapedText = escapeXML(fullText)
        let strikeTag = withStrikethrough ? "<w:strike/>" : ""
        // Content with cream highlight, then closing gold bracket
        let creamContentRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/>\(strikeTag)<w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"
        let goldBracketRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:b/><w:color w:val=\"\(kGoldBracketColor)\"/>\(strikeTag)<w:sz w:val=\"28\"/><w:szCs w:val=\"28\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"
        let newRuns = "<w:r>\(creamContentRPr)<w:t xml:space=\"preserve\">\(escapedText)</w:t></w:r><w:r>\(goldBracketRPr)<w:t>]</w:t></w:r>"

        let finalContent = "\(pOpenTag)\(pPrContent)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Set M2 delivery first line with opening bracket - keeps literal [time] text
    /// "[consigning it to the hospital managers' internal mail system today at [time]."
    func setM2DeliveryFirstLineWithTime(at index: Int, timeContent: String, withStrikethrough: Bool = false) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        let content = para.content

        var pPrContent = ""
        if let pPrMatch = content.range(of: #"<w:pPr>.*?</w:pPr>"#, options: .regularExpression) {
            pPrContent = String(content[pPrMatch])
        }

        var pOpenTag = "<w:p>"
        if let pOpenMatch = content.range(of: #"<w:p[^>]*>"#, options: .regularExpression) {
            pOpenTag = String(content[pOpenMatch])
        }

        let strikeTag = withStrikethrough ? "<w:strike/>" : ""

        // Golden brackets are 14pt (28 half-points) for extra thickness
        let goldBracketRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:b/><w:color w:val=\"\(kGoldBracketColor)\"/>\(strikeTag)<w:sz w:val=\"28\"/><w:szCs w:val=\"28\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"
        let creamContentRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/>\(strikeTag)<w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"

        // Opening gold bracket, then full text with literal [time], then period
        let newRuns = "<w:r>\(goldBracketRPr)<w:t>[</w:t></w:r><w:r>\(creamContentRPr)<w:t xml:space=\"preserve\">consigning it to the hospital managers' internal mail system today at [time].</w:t></w:r>"

        let finalContent = "\(pOpenTag)\(pPrContent)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Set M2 delivery time entry line - cream highlighted space with time value
    func setM2DeliveryTimeEntryLine(at index: Int, timeContent: String, withStrikethrough: Bool = false) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        let content = para.content

        var pPrContent = ""
        if let pPrMatch = content.range(of: #"<w:pPr>.*?</w:pPr>"#, options: .regularExpression) {
            pPrContent = String(content[pPrMatch])
        }

        var pOpenTag = "<w:p>"
        if let pOpenMatch = content.range(of: #"<w:p[^>]*>"#, options: .regularExpression) {
            pOpenTag = String(content[pOpenMatch])
        }

        let strikeTag = withStrikethrough ? "<w:strike/>" : ""
        let creamContentRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/>\(strikeTag)<w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"

        // Create cream highlighted line (~84 chars) with time content
        let fullPadding = "                                                                                    "
        let displayContent: String
        if timeContent.isEmpty {
            displayContent = fullPadding
        } else {
            // Center the time in the padding
            let leftPad = "                                        "
            let rightPad = "                                        "
            displayContent = "\(leftPad)\(timeContent)\(rightPad)"
        }

        let newRuns = "<w:r>\(creamContentRPr)<w:t xml:space=\"preserve\">\(displayContent)</w:t></w:r>"

        let finalContent = "\(pOpenTag)\(pPrContent)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Set M2 delivery padding line - empty cream highlighted line (no brackets)
    func setM2DeliveryPaddingLine(at index: Int, withStrikethrough: Bool = false) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        let content = para.content

        var pPrContent = ""
        if let pPrMatch = content.range(of: #"<w:pPr>.*?</w:pPr>"#, options: .regularExpression) {
            pPrContent = String(content[pPrMatch])
        }

        var pOpenTag = "<w:p>"
        if let pOpenMatch = content.range(of: #"<w:p[^>]*>"#, options: .regularExpression) {
            pOpenTag = String(content[pOpenMatch])
        }

        let padding = "                                                                                    "
        let strikeTag = withStrikethrough ? "<w:strike/>" : ""
        let creamRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/>\(strikeTag)<w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"
        let newRuns = "<w:r>\(creamRPr)<w:t xml:space=\"preserve\">\(padding)</w:t></w:r>"

        let finalContent = "\(pOpenTag)\(pPrContent)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Set detention reason with opening bracket: "(i)  [for the patient's own health"
    /// Prefix (i) stays unhighlighted, content gets cream highlight with opening gold bracket
    func setDetentionReasonWithOpeningBracket(at index: Int, withStrikethrough: Bool = false) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        let content = para.content

        // Extract existing text content
        let textPattern = #"<w:t[^>]*>([^<]*)</w:t>"#
        guard let textRegex = try? NSRegularExpression(pattern: textPattern) else { return }
        let range = NSRange(content.startIndex..., in: content)
        let textMatches = textRegex.matches(in: content, range: range)

        var fullText = ""
        for match in textMatches {
            if match.numberOfRanges > 1,
               let textNSRange = Range(match.range(at: 1), in: content) {
                fullText += String(content[textNSRange])
            }
        }

        // Separate prefix (i), (ii), (iii) from content
        var prefix = ""
        var contentText = fullText
        if let prefixMatch = fullText.range(of: #"^\s*\([iv]+\)\s*"#, options: .regularExpression) {
            prefix = String(fullText[prefixMatch])
            contentText = String(fullText[prefixMatch.upperBound...])
        }

        var pPrContent = ""
        if let pPrMatch = content.range(of: #"<w:pPr>.*?</w:pPr>"#, options: .regularExpression) {
            pPrContent = String(content[pPrMatch])
        }

        var pOpenTag = "<w:p>"
        if let pOpenMatch = content.range(of: #"<w:p[^>]*>"#, options: .regularExpression) {
            pOpenTag = String(content[pOpenMatch])
        }

        let escapedPrefix = escapeXML(prefix)
        let escapedContent = escapeXML(contentText)
        let strikeTag = withStrikethrough ? "<w:strike/>" : ""

        // Prefix stays unhighlighted (but gets strikethrough if needed)
        let prefixRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/>\(strikeTag)<w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/></w:rPr>"
        let goldBracketRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:b/><w:color w:val=\"\(kGoldBracketColor)\"/>\(strikeTag)<w:sz w:val=\"28\"/><w:szCs w:val=\"28\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"
        let creamContentRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/>\(strikeTag)<w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"

        let newRuns = "<w:r>\(prefixRPr)<w:t xml:space=\"preserve\">\(escapedPrefix)</w:t></w:r><w:r>\(goldBracketRPr)<w:t>[</w:t></w:r><w:r>\(creamContentRPr)<w:t xml:space=\"preserve\">\(escapedContent)</w:t></w:r>"

        let finalContent = "\(pOpenTag)\(pPrContent)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Set detention reason with cream highlight only: "(ii)  for the patient's own safety"
    /// Prefix (ii) stays unhighlighted, content gets cream highlight
    func setDetentionReasonWithCreamHighlightOnly(at index: Int, withStrikethrough: Bool = false) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        let content = para.content

        // Extract existing text content
        let textPattern = #"<w:t[^>]*>([^<]*)</w:t>"#
        guard let textRegex = try? NSRegularExpression(pattern: textPattern) else { return }
        let range = NSRange(content.startIndex..., in: content)
        let textMatches = textRegex.matches(in: content, range: range)

        var fullText = ""
        for match in textMatches {
            if match.numberOfRanges > 1,
               let textNSRange = Range(match.range(at: 1), in: content) {
                fullText += String(content[textNSRange])
            }
        }

        // Separate prefix (i), (ii), (iii) from content
        var prefix = ""
        var contentText = fullText
        if let prefixMatch = fullText.range(of: #"^\s*\([iv]+\)\s*"#, options: .regularExpression) {
            prefix = String(fullText[prefixMatch])
            contentText = String(fullText[prefixMatch.upperBound...])
        }

        var pPrContent = ""
        if let pPrMatch = content.range(of: #"<w:pPr>.*?</w:pPr>"#, options: .regularExpression) {
            pPrContent = String(content[pPrMatch])
        }

        var pOpenTag = "<w:p>"
        if let pOpenMatch = content.range(of: #"<w:p[^>]*>"#, options: .regularExpression) {
            pOpenTag = String(content[pOpenMatch])
        }

        let escapedPrefix = escapeXML(prefix)
        let escapedContent = escapeXML(contentText)
        let strikeTag = withStrikethrough ? "<w:strike/>" : ""

        let prefixRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/>\(strikeTag)<w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/></w:rPr>"
        let creamContentRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/>\(strikeTag)<w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"

        let newRuns = "<w:r>\(prefixRPr)<w:t xml:space=\"preserve\">\(escapedPrefix)</w:t></w:r><w:r>\(creamContentRPr)<w:t xml:space=\"preserve\">\(escapedContent)</w:t></w:r>"

        let finalContent = "\(pOpenTag)\(pPrContent)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Set detention reason with closing bracket: "(iii)  for the protection of other persons]"
    /// Prefix (iii) stays unhighlighted, content gets cream highlight with closing gold bracket
    func setDetentionReasonWithClosingBracket(at index: Int, withStrikethrough: Bool = false) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        let content = para.content

        // Extract existing text content
        let textPattern = #"<w:t[^>]*>([^<]*)</w:t>"#
        guard let textRegex = try? NSRegularExpression(pattern: textPattern) else { return }
        let range = NSRange(content.startIndex..., in: content)
        let textMatches = textRegex.matches(in: content, range: range)

        var fullText = ""
        for match in textMatches {
            if match.numberOfRanges > 1,
               let textNSRange = Range(match.range(at: 1), in: content) {
                fullText += String(content[textNSRange])
            }
        }

        // Separate prefix (i), (ii), (iii) from content
        var prefix = ""
        var contentText = fullText
        if let prefixMatch = fullText.range(of: #"^\s*\([iv]+\)\s*"#, options: .regularExpression) {
            prefix = String(fullText[prefixMatch])
            contentText = String(fullText[prefixMatch.upperBound...])
        }

        var pPrContent = ""
        if let pPrMatch = content.range(of: #"<w:pPr>.*?</w:pPr>"#, options: .regularExpression) {
            pPrContent = String(content[pPrMatch])
        }

        var pOpenTag = "<w:p>"
        if let pOpenMatch = content.range(of: #"<w:p[^>]*>"#, options: .regularExpression) {
            pOpenTag = String(content[pOpenMatch])
        }

        let escapedPrefix = escapeXML(prefix)
        let escapedContent = escapeXML(contentText)
        let strikeTag = withStrikethrough ? "<w:strike/>" : ""

        let prefixRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/>\(strikeTag)<w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/></w:rPr>"
        let creamContentRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/>\(strikeTag)<w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"
        let goldBracketRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:b/><w:color w:val=\"\(kGoldBracketColor)\"/>\(strikeTag)<w:sz w:val=\"28\"/><w:szCs w:val=\"28\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"

        let newRuns = "<w:r>\(prefixRPr)<w:t xml:space=\"preserve\">\(escapedPrefix)</w:t></w:r><w:r>\(creamContentRPr)<w:t xml:space=\"preserve\">\(escapedContent)</w:t></w:r><w:r>\(goldBracketRPr)<w:t>]</w:t></w:r>"

        let finalContent = "\(pOpenTag)\(pPrContent)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Fill only the bracket content within existing text (for H1 Part 1 delivery date)
    /// Finds [placeholder] in text and replaces with [dateContent] while preserving surrounding text
    func fillDateBracketOnly(at index: Int, dateContent: String) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        var content = para.content

        // Find the bracket pattern in the text
        // Look for w:t elements containing "[" and "]"
        let bracketPattern = #"\[([^\]]*)\]"#
        guard let regex = try? NSRegularExpression(pattern: bracketPattern) else { return }

        // Extract all text content
        let textPattern = #"<w:t[^>]*>([^<]*)</w:t>"#
        guard let textRegex = try? NSRegularExpression(pattern: textPattern) else { return }

        let range = NSRange(content.startIndex..., in: content)
        let textMatches = textRegex.matches(in: content, range: range)

        var fullText = ""
        for match in textMatches {
            if match.numberOfRanges > 1,
               let textNSRange = Range(match.range(at: 1), in: content) {
                fullText += String(content[textNSRange])
            }
        }

        // Find bracket in full text
        let textRange = NSRange(fullText.startIndex..., in: fullText)
        if regex.firstMatch(in: fullText, range: textRange) != nil {
            // Found a bracket - now we need to replace it in the XML
            // Replace the entire paragraph with highlighted version preserving the prefix text

            // Extract pPr
            var pPrContent = ""
            if let pPrMatch = content.range(of: #"<w:pPr>.*?</w:pPr>"#, options: .regularExpression) {
                pPrContent = String(content[pPrMatch])
            }

            var pOpenTag = "<w:p>"
            if let pOpenMatch = content.range(of: #"<w:p[^>]*>"#, options: .regularExpression) {
                pOpenTag = String(content[pOpenMatch])
            }

            // Split text at bracket
            if let bracketStart = fullText.firstIndex(of: "["),
               let bracketEnd = fullText.firstIndex(of: "]") {
                let prefixText = String(fullText[fullText.startIndex..<bracketStart])
                let suffixText = bracketEnd < fullText.endIndex ? String(fullText[fullText.index(after: bracketEnd)...]) : ""

                let escapedPrefix = escapeXML(prefixText)
                let escapedSuffix = escapeXML(suffixText)
                let escapedDate = escapeXML(dateContent)

                // Build runs: prefix (cream), [date] (gold brackets + cream), suffix (cream)
                let creamRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"
                let goldBracketRPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:b/><w:color w:val=\"\(kGoldBracketColor)\"/><w:sz w:val=\"28\"/><w:szCs w:val=\"28\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"

                var newRuns = ""
                if !prefixText.isEmpty {
                    newRuns += "<w:r>\(creamRPr)<w:t xml:space=\"preserve\">\(escapedPrefix)</w:t></w:r>"
                }
                newRuns += "<w:r>\(goldBracketRPr)<w:t>[</w:t></w:r><w:r>\(creamRPr)<w:t xml:space=\"preserve\">\(escapedDate)</w:t></w:r><w:r>\(goldBracketRPr)<w:t>]</w:t></w:r>"
                if !suffixText.isEmpty {
                    newRuns += "<w:r>\(creamRPr)<w:t xml:space=\"preserve\">\(escapedSuffix)</w:t></w:r>"
                }

                let finalContent = "\(pOpenTag)\(pPrContent)\(newRuns)</w:p>"
                documentXML.replaceSubrange(para.range, with: finalContent)
            }
        }
    }

    /// Wrap existing paragraph text with gold opening bracket "[" and cream highlight
    /// Used for multi-paragraph bracket spans (first paragraph of span)
    func wrapWithOpeningBracket(at index: Int) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        var newContent = para.content

        // Remove permission markers
        let permStartPattern = #"<w:permStart[^/]*/>"#
        if let regex = try? NSRegularExpression(pattern: permStartPattern) {
            let range = NSRange(newContent.startIndex..., in: newContent)
            newContent = regex.stringByReplacingMatches(in: newContent, range: range, withTemplate: "")
        }
        let permEndPattern = #"<w:permEnd[^/]*/>"#
        if let regex = try? NSRegularExpression(pattern: permEndPattern) {
            let range = NSRange(newContent.startIndex..., in: newContent)
            newContent = regex.stringByReplacingMatches(in: newContent, range: range, withTemplate: "")
        }

        // Extract existing text from all w:t elements
        var existingText = ""
        let textPattern = #"<w:t[^>]*>([^<]*)</w:t>"#
        if let regex = try? NSRegularExpression(pattern: textPattern) {
            let range = NSRange(newContent.startIndex..., in: newContent)
            let matches = regex.matches(in: newContent, range: range)
            for match in matches {
                if match.numberOfRanges > 1,
                   let textRange = Range(match.range(at: 1), in: newContent) {
                    existingText += String(newContent[textRange])
                }
            }
        }

        // Extract paragraph properties
        var pPrContent = ""
        if let pPrMatch = newContent.range(of: #"<w:pPr>.*?</w:pPr>"#, options: .regularExpression) {
            pPrContent = String(newContent[pPrMatch])
        }

        var pOpenTag = "<w:p>"
        if let pOpenMatch = newContent.range(of: #"<w:p[^>]*>"#, options: .regularExpression) {
            pOpenTag = String(newContent[pOpenMatch])
        }

        // Create: gold "[" + existing text with cream highlight
        // Note: existingText is already XML-escaped from the template, don't double-escape
        let newRuns = "<w:r>\(bracketRPr)<w:t>[</w:t></w:r><w:r>\(contentRPr)<w:t xml:space=\"preserve\">\(existingText)</w:t></w:r>"

        let finalContent = "\(pOpenTag)\(pPrContent)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Wrap existing paragraph text with cream highlight and gold closing bracket "]"
    /// Used for multi-paragraph bracket spans (last paragraph of span)
    func wrapWithClosingBracket(at index: Int) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        var newContent = para.content

        // Remove permission markers
        let permStartPattern = #"<w:permStart[^/]*/>"#
        if let regex = try? NSRegularExpression(pattern: permStartPattern) {
            let range = NSRange(newContent.startIndex..., in: newContent)
            newContent = regex.stringByReplacingMatches(in: newContent, range: range, withTemplate: "")
        }
        let permEndPattern = #"<w:permEnd[^/]*/>"#
        if let regex = try? NSRegularExpression(pattern: permEndPattern) {
            let range = NSRange(newContent.startIndex..., in: newContent)
            newContent = regex.stringByReplacingMatches(in: newContent, range: range, withTemplate: "")
        }

        // Extract existing text from all w:t elements
        var existingText = ""
        let textPattern = #"<w:t[^>]*>([^<]*)</w:t>"#
        if let regex = try? NSRegularExpression(pattern: textPattern) {
            let range = NSRange(newContent.startIndex..., in: newContent)
            let matches = regex.matches(in: newContent, range: range)
            for match in matches {
                if match.numberOfRanges > 1,
                   let textRange = Range(match.range(at: 1), in: newContent) {
                    existingText += String(newContent[textRange])
                }
            }
        }

        // Extract paragraph properties
        var pPrContent = ""
        if let pPrMatch = newContent.range(of: #"<w:pPr>.*?</w:pPr>"#, options: .regularExpression) {
            pPrContent = String(newContent[pPrMatch])
        }

        var pOpenTag = "<w:p>"
        if let pOpenMatch = newContent.range(of: #"<w:p[^>]*>"#, options: .regularExpression) {
            pOpenTag = String(newContent[pOpenMatch])
        }

        // Create: existing text with cream highlight + gold "]"
        // Note: existingText is already XML-escaped from the template, don't double-escape
        let newRuns = "<w:r>\(contentRPr)<w:t xml:space=\"preserve\">\(existingText)</w:t></w:r><w:r>\(bracketRPr)<w:t>]</w:t></w:r>"

        let finalContent = "\(pOpenTag)\(pPrContent)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    // MARK: - H1 Delivery Option Methods

    /// Set H1 delivery option with opening bracket and time value
    /// Format: "[consigning it to the hospital managers' internal mail system today at [TIME]"
    func setH1DeliveryOptionWithOpeningBracket(at index: Int, timeValue: String, withStrikethrough: Bool = false) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        var newContent = para.content

        // Remove permission markers
        let permStartPattern = #"<w:permStart[^/]*/>"#
        if let regex = try? NSRegularExpression(pattern: permStartPattern) {
            let range = NSRange(newContent.startIndex..., in: newContent)
            newContent = regex.stringByReplacingMatches(in: newContent, range: range, withTemplate: "")
        }
        let permEndPattern = #"<w:permEnd[^/]*/>"#
        if let regex = try? NSRegularExpression(pattern: permEndPattern) {
            let range = NSRange(newContent.startIndex..., in: newContent)
            newContent = regex.stringByReplacingMatches(in: newContent, range: range, withTemplate: "")
        }

        // Extract existing text from all w:t elements
        var existingText = ""
        let textPattern = #"<w:t[^>]*>([^<]*)</w:t>"#
        if let regex = try? NSRegularExpression(pattern: textPattern) {
            let range = NSRange(newContent.startIndex..., in: newContent)
            let matches = regex.matches(in: newContent, range: range)
            for match in matches {
                if match.numberOfRanges > 1,
                   let textRange = Range(match.range(at: 1), in: newContent) {
                    existingText += String(newContent[textRange])
                }
            }
        }

        // Replace any existing bracket content [xxx] with the time value
        if let bracketStart = existingText.firstIndex(of: "["),
           let bracketEnd = existingText.firstIndex(of: "]") {
            let beforeBracket = String(existingText[existingText.startIndex..<bracketStart])
            let afterBracket = bracketEnd < existingText.index(before: existingText.endIndex) ? String(existingText[existingText.index(after: bracketEnd)...]) : ""
            existingText = beforeBracket + "[" + timeValue + "]" + afterBracket
        }

        // Extract paragraph properties
        var pPrContent = ""
        if let pPrMatch = newContent.range(of: #"<w:pPr>.*?</w:pPr>"#, options: .regularExpression) {
            pPrContent = String(newContent[pPrMatch])
        }

        var pOpenTag = "<w:p>"
        if let pOpenMatch = newContent.range(of: #"<w:p[^>]*>"#, options: .regularExpression) {
            pOpenTag = String(newContent[pOpenMatch])
        }

        let strikeTag = withStrikethrough ? "<w:strike/>" : ""
        let goldBracketRPrWithStrike = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:b/>\(strikeTag)<w:color w:val=\"\(kGoldBracketColor)\"/><w:sz w:val=\"28\"/><w:szCs w:val=\"28\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"
        let creamRPrWithStrike = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/>\(strikeTag)<w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"

        // Create: gold "[" + text with cream highlight (including inner [time] with gold brackets)
        let escapedText = escapeXML(existingText)
        let newRuns = "<w:r>\(goldBracketRPrWithStrike)<w:t>[</w:t></w:r><w:r>\(creamRPrWithStrike)<w:t xml:space=\"preserve\">\(escapedText)</w:t></w:r>"

        let finalContent = "\(pOpenTag)\(pPrContent)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Set H1 delivery option middle line with cream highlight only (no brackets)
    func setH1DeliveryOptionMiddle(at index: Int, withStrikethrough: Bool = false) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        var newContent = para.content

        // Remove permission markers
        let permStartPattern = #"<w:permStart[^/]*/>"#
        if let regex = try? NSRegularExpression(pattern: permStartPattern) {
            let range = NSRange(newContent.startIndex..., in: newContent)
            newContent = regex.stringByReplacingMatches(in: newContent, range: range, withTemplate: "")
        }
        let permEndPattern = #"<w:permEnd[^/]*/>"#
        if let regex = try? NSRegularExpression(pattern: permEndPattern) {
            let range = NSRange(newContent.startIndex..., in: newContent)
            newContent = regex.stringByReplacingMatches(in: newContent, range: range, withTemplate: "")
        }

        // Extract existing text
        var existingText = ""
        let textPattern = #"<w:t[^>]*>([^<]*)</w:t>"#
        if let regex = try? NSRegularExpression(pattern: textPattern) {
            let range = NSRange(newContent.startIndex..., in: newContent)
            let matches = regex.matches(in: newContent, range: range)
            for match in matches {
                if match.numberOfRanges > 1,
                   let textRange = Range(match.range(at: 1), in: newContent) {
                    existingText += String(newContent[textRange])
                }
            }
        }

        var pPrContent = ""
        if let pPrMatch = newContent.range(of: #"<w:pPr>.*?</w:pPr>"#, options: .regularExpression) {
            pPrContent = String(newContent[pPrMatch])
        }

        var pOpenTag = "<w:p>"
        if let pOpenMatch = newContent.range(of: #"<w:p[^>]*>"#, options: .regularExpression) {
            pOpenTag = String(newContent[pOpenMatch])
        }

        let strikeTag = withStrikethrough ? "<w:strike/>" : ""
        let creamRPrWithStrike = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/>\(strikeTag)<w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"

        let escapedText = escapeXML(existingText)
        let newRuns = "<w:r>\(creamRPrWithStrike)<w:t xml:space=\"preserve\">\(escapedText)</w:t></w:r>"

        let finalContent = "\(pOpenTag)\(pPrContent)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Set H1 delivery option with closing bracket
    /// Format: "delivering it (or having it delivered) by hand...]"
    func setH1DeliveryOptionWithClosingBracket(at index: Int, withStrikethrough: Bool = false) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        var newContent = para.content

        // Remove permission markers
        let permStartPattern = #"<w:permStart[^/]*/>"#
        if let regex = try? NSRegularExpression(pattern: permStartPattern) {
            let range = NSRange(newContent.startIndex..., in: newContent)
            newContent = regex.stringByReplacingMatches(in: newContent, range: range, withTemplate: "")
        }
        let permEndPattern = #"<w:permEnd[^/]*/>"#
        if let regex = try? NSRegularExpression(pattern: permEndPattern) {
            let range = NSRange(newContent.startIndex..., in: newContent)
            newContent = regex.stringByReplacingMatches(in: newContent, range: range, withTemplate: "")
        }

        // Extract existing text
        var existingText = ""
        let textPattern = #"<w:t[^>]*>([^<]*)</w:t>"#
        if let regex = try? NSRegularExpression(pattern: textPattern) {
            let range = NSRange(newContent.startIndex..., in: newContent)
            let matches = regex.matches(in: newContent, range: range)
            for match in matches {
                if match.numberOfRanges > 1,
                   let textRange = Range(match.range(at: 1), in: newContent) {
                    existingText += String(newContent[textRange])
                }
            }
        }

        var pPrContent = ""
        if let pPrMatch = newContent.range(of: #"<w:pPr>.*?</w:pPr>"#, options: .regularExpression) {
            pPrContent = String(newContent[pPrMatch])
        }

        var pOpenTag = "<w:p>"
        if let pOpenMatch = newContent.range(of: #"<w:p[^>]*>"#, options: .regularExpression) {
            pOpenTag = String(newContent[pOpenMatch])
        }

        let strikeTag = withStrikethrough ? "<w:strike/>" : ""
        let goldBracketRPrWithStrike = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:b/>\(strikeTag)<w:color w:val=\"\(kGoldBracketColor)\"/><w:sz w:val=\"28\"/><w:szCs w:val=\"28\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"
        let creamRPrWithStrike = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/>\(strikeTag)<w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"

        let escapedText = escapeXML(existingText)
        let newRuns = "<w:r>\(creamRPrWithStrike)<w:t xml:space=\"preserve\">\(escapedText)</w:t></w:r><w:r>\(goldBracketRPrWithStrike)<w:t>]</w:t></w:r>"

        let finalContent = "\(pOpenTag)\(pPrContent)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Set the "indicate here" checkbox paragraph with gold brackets around the checkbox
    /// Format: [If you need to continue... indicate here [ ] and attach...]
    /// Outer brackets are plain black, inner checkbox [ ] has gold brackets with ONE space cream highlighted
    func setIndicateHereCheckbox(at index: Int) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        let newContent = para.content

        var pPrContent = ""
        if let pPrMatch = newContent.range(of: #"<w:pPr>.*?</w:pPr>"#, options: .regularExpression) {
            pPrContent = String(newContent[pPrMatch])
        }

        var pOpenTag = "<w:p>"
        if let pOpenMatch = newContent.range(of: #"<w:p[^>]*>"#, options: .regularExpression) {
            pOpenTag = String(newContent[pOpenMatch])
        }

        // Build the paragraph with:
        // - Plain "[" outer opening bracket
        // - Plain "If you need to continue..." text
        // - Gold "[" checkbox opening
        // - Cream "  " checkbox space
        // - Gold "]" checkbox closing
        // - Plain " and attach..." text
        // - Plain "]" outer closing bracket

        var newRuns = ""
        // Outer opening bracket (plain)
        newRuns += "<w:r>\(plainRPr)<w:t>[</w:t></w:r>"
        // Text before checkbox (plain)
        newRuns += "<w:r>\(plainRPr)<w:t xml:space=\"preserve\">If you need to continue on a separate sheet please indicate here </w:t></w:r>"
        // Checkbox opening bracket (gold bold with cream)
        newRuns += "<w:r>\(bracketRPr)<w:t>[</w:t></w:r>"
        // Checkbox space (cream highlight) - ONE space with gold brackets
        newRuns += "<w:r>\(contentRPr)<w:t xml:space=\"preserve\"> </w:t></w:r>"
        // Checkbox closing bracket (gold bold with cream)
        newRuns += "<w:r>\(bracketRPr)<w:t>]</w:t></w:r>"
        // Text after checkbox (plain)
        newRuns += "<w:r>\(plainRPr)<w:t xml:space=\"preserve\"> and attach that sheet to this form</w:t></w:r>"
        // Outer closing bracket (plain)
        newRuns += "<w:r>\(plainRPr)<w:t>]</w:t></w:r>"

        let finalContent = "\(pOpenTag)\(pPrContent)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Clear a paragraph's content (remove all text, keep paragraph structure)
    func clearParagraph(at index: Int) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        let content = para.content

        var pOpenTag = "<w:p>"
        if let pOpenMatch = content.range(of: #"<w:p[^>]*>"#, options: .regularExpression) {
            pOpenTag = String(content[pOpenMatch])
        }

        var pPrContent = ""
        if let pPrMatch = content.range(of: #"<w:pPr>.*?</w:pPr>"#, options: .regularExpression) {
            pPrContent = String(content[pPrMatch])
        }

        // Keep paragraph structure but remove all runs/text
        let finalContent = "\(pOpenTag)\(pPrContent)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Collapse a paragraph to take up essentially zero vertical space
    func collapseParagraph(at index: Int) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        let content = para.content

        var pOpenTag = "<w:p>"
        if let pOpenMatch = content.range(of: #"<w:p[^>]*>"#, options: .regularExpression) {
            pOpenTag = String(content[pOpenMatch])
        }

        // Set line height to 1 twip (essentially invisible) with no spacing
        let pPr = "<w:pPr><w:spacing w:before=\"0\" w:after=\"0\" w:line=\"1\" w:lineRule=\"exact\"/></w:pPr>"
        let finalContent = "\(pOpenTag)\(pPr)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Remove all permission markers from the entire document
    func removeAllPermissionMarkers() {
        // Remove permission start markers
        let permStartPattern = #"<w:permStart[^/]*/>"#
        if let regex = try? NSRegularExpression(pattern: permStartPattern) {
            let range = NSRange(documentXML.startIndex..., in: documentXML)
            documentXML = regex.stringByReplacingMatches(in: documentXML, range: range, withTemplate: "")
        }
        // Remove permission end markers
        let permEndPattern = #"<w:permEnd[^/]*/>"#
        if let regex = try? NSRegularExpression(pattern: permEndPattern) {
            let range = NSRange(documentXML.startIndex..., in: documentXML)
            documentXML = regex.stringByReplacingMatches(in: documentXML, range: range, withTemplate: "")
        }
    }

    /// Wrap detention reason paragraph (i) with opening gold bracket after the "(i)" prefix
    func wrapDetentionReasonOpening(at index: Int) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        let content = para.content

        var pOpenTag = "<w:p>"
        if let pOpenMatch = content.range(of: #"<w:p[^>]*>"#, options: .regularExpression) {
            pOpenTag = String(content[pOpenMatch])
        }

        var pPrContent = ""
        if let pPrMatch = content.range(of: #"<w:pPr>.*?</w:pPr>"#, options: .regularExpression) {
            pPrContent = String(content[pPrMatch])
        }

        // Extract text content
        var textContent = ""
        let textPattern = #"<w:t[^>]*>([^<]*)</w:t>"#
        if let regex = try? NSRegularExpression(pattern: textPattern) {
            let range = NSRange(content.startIndex..., in: content)
            let matches = regex.matches(in: content, range: range)
            for match in matches {
                if let textRange = Range(match.range(at: 1), in: content) {
                    textContent += String(content[textRange])
                }
            }
        }

        // Split at "(i)" - prefix is unhighlighted, rest is highlighted with opening bracket
        var prefix = ""
        var rest = textContent
        if let iRange = textContent.range(of: "(i)") {
            prefix = String(textContent[..<iRange.upperBound]) + " "
            rest = String(textContent[iRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        }

        var newRuns = ""
        // Prefix "(i) " - plain, no highlight
        newRuns += "<w:r>\(plainRPr)<w:t xml:space=\"preserve\">\(escapeXML(prefix))</w:t></w:r>"
        // Opening gold bracket
        newRuns += "<w:r>\(bracketRPr)<w:t>[</w:t></w:r>"
        // Rest of text with cream highlight
        newRuns += "<w:r>\(contentRPr)<w:t xml:space=\"preserve\">\(escapeXML(rest))</w:t></w:r>"

        let finalContent = "\(pOpenTag)\(pPrContent)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Wrap detention reason paragraph (ii) - middle line, cream highlight only (no brackets)
    func wrapDetentionReasonMiddle(at index: Int) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        let content = para.content

        var pOpenTag = "<w:p>"
        if let pOpenMatch = content.range(of: #"<w:p[^>]*>"#, options: .regularExpression) {
            pOpenTag = String(content[pOpenMatch])
        }

        var pPrContent = ""
        if let pPrMatch = content.range(of: #"<w:pPr>.*?</w:pPr>"#, options: .regularExpression) {
            pPrContent = String(content[pPrMatch])
        }

        // Extract text content
        var textContent = ""
        let textPattern = #"<w:t[^>]*>([^<]*)</w:t>"#
        if let regex = try? NSRegularExpression(pattern: textPattern) {
            let range = NSRange(content.startIndex..., in: content)
            let matches = regex.matches(in: content, range: range)
            for match in matches {
                if let textRange = Range(match.range(at: 1), in: content) {
                    textContent += String(content[textRange])
                }
            }
        }

        // Split at "(ii)" - prefix is unhighlighted, rest is highlighted
        var prefix = ""
        var rest = textContent
        if let iiRange = textContent.range(of: "(ii)") {
            prefix = String(textContent[..<iiRange.upperBound]) + " "
            rest = String(textContent[iiRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        }

        var newRuns = ""
        // Prefix "(ii) " - plain, no highlight
        newRuns += "<w:r>\(plainRPr)<w:t xml:space=\"preserve\">\(escapeXML(prefix))</w:t></w:r>"
        // Rest of text with cream highlight (no brackets)
        newRuns += "<w:r>\(contentRPr)<w:t xml:space=\"preserve\">\(escapeXML(rest))</w:t></w:r>"

        let finalContent = "\(pOpenTag)\(pPrContent)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Wrap detention reason paragraph (iii) with closing gold bracket at end
    func wrapDetentionReasonClosing(at index: Int) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        let content = para.content

        var pOpenTag = "<w:p>"
        if let pOpenMatch = content.range(of: #"<w:p[^>]*>"#, options: .regularExpression) {
            pOpenTag = String(content[pOpenMatch])
        }

        var pPrContent = ""
        if let pPrMatch = content.range(of: #"<w:pPr>.*?</w:pPr>"#, options: .regularExpression) {
            pPrContent = String(content[pPrMatch])
        }

        // Extract text content
        var textContent = ""
        let textPattern = #"<w:t[^>]*>([^<]*)</w:t>"#
        if let regex = try? NSRegularExpression(pattern: textPattern) {
            let range = NSRange(content.startIndex..., in: content)
            let matches = regex.matches(in: content, range: range)
            for match in matches {
                if let textRange = Range(match.range(at: 1), in: content) {
                    textContent += String(content[textRange])
                }
            }
        }

        // Split at "(iii)" - prefix is unhighlighted, rest is highlighted with closing bracket
        var prefix = ""
        var rest = textContent
        if let iiiRange = textContent.range(of: "(iii)") {
            prefix = String(textContent[..<iiiRange.upperBound]) + " "
            rest = String(textContent[iiiRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        }

        var newRuns = ""
        // Prefix "(iii) " - plain, no highlight
        newRuns += "<w:r>\(plainRPr)<w:t xml:space=\"preserve\">\(escapeXML(prefix))</w:t></w:r>"
        // Rest of text with cream highlight
        newRuns += "<w:r>\(contentRPr)<w:t xml:space=\"preserve\">\(escapeXML(rest))</w:t></w:r>"
        // Closing gold bracket
        newRuns += "<w:r>\(bracketRPr)<w:t>]</w:t></w:r>"

        let finalContent = "\(pOpenTag)\(pPrContent)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Set T2 certifier type paragraph - highlight selected option, strikethrough non-selected
    /// Uses gold brackets with cream highlight content
    func setT2CertifierType(at index: Int, isApprovedClinician: Bool) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        let newContent = para.content

        var pPrContent = ""
        if let pPrMatch = newContent.range(of: #"<w:pPr>.*?</w:pPr>"#, options: .regularExpression) {
            pPrContent = String(newContent[pPrMatch])
        }

        var pOpenTag = "<w:p>"
        if let pOpenMatch = newContent.range(of: #"<w:p[^>]*>"#, options: .regularExpression) {
            pOpenTag = String(newContent[pOpenMatch])
        }

        // Strikethrough with cream highlight (for non-selected option)
        let strikeContentRPr = "<w:rPr>\(arialFont)<w:strike/><w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(kCreamHighlightColor)\"/></w:rPr>"

        let option1 = "the approved clinician in charge of the treatment described below"
        let option2 = "a registered medical practitioner appointed for the purposes of Part 4 of the Act (a SOAD)"
        let suffix = " certify that "

        var newRuns: String
        if isApprovedClinician {
            // Gold opening bracket, option1 (selected), strikethrough option2, gold closing bracket
            newRuns = "<w:r>\(bracketRPr)<w:t>[</w:t></w:r>"
            newRuns += "<w:r>\(contentRPr)<w:t xml:space=\"preserve\">\(escapeXML(option1))</w:t></w:r>"
            newRuns += "<w:r>\(strikeContentRPr)<w:t xml:space=\"preserve\">/\(escapeXML(option2))</w:t></w:r>"
            newRuns += "<w:r>\(bracketRPr)<w:t>]</w:t></w:r>"
        } else {
            // Gold opening bracket, strikethrough option1, option2 (selected), gold closing bracket
            newRuns = "<w:r>\(bracketRPr)<w:t>[</w:t></w:r>"
            newRuns += "<w:r>\(strikeContentRPr)<w:t xml:space=\"preserve\">\(escapeXML(option1))/</w:t></w:r>"
            newRuns += "<w:r>\(contentRPr)<w:t xml:space=\"preserve\">\(escapeXML(option2))</w:t></w:r>"
            newRuns += "<w:r>\(bracketRPr)<w:t>]</w:t></w:r>"
        }
        // Add suffix (plain text)
        newRuns += "<w:r>\(plainRPr)<w:t xml:space=\"preserve\">\(escapeXML(suffix))</w:t></w:r>"

        let finalContent = "\(pOpenTag)\(pPrContent)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Make paragraph text bold
    func makeBold(at index: Int) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        var newContent = para.content

        let runPattern = #"<w:r>|<w:r [^>]*>"#
        if let regex = try? NSRegularExpression(pattern: runPattern) {
            let range = NSRange(newContent.startIndex..., in: newContent)
            let matches = regex.matches(in: newContent, range: range)

            for match in matches.reversed() {
                if let matchRange = Range(match.range, in: newContent) {
                    let afterRun = matchRange.upperBound
                    let remainingContent = String(newContent[afterRun...])

                    let boldElement = "<w:b/>"

                    if remainingContent.hasPrefix("<w:rPr>") {
                        if let rPrEnd = newContent.range(of: "</w:rPr>", range: matchRange.upperBound..<newContent.endIndex) {
                            let rPrContent = String(newContent[matchRange.upperBound..<rPrEnd.lowerBound])
                            if !rPrContent.contains("<w:b") {
                                newContent.insert(contentsOf: boldElement, at: rPrEnd.lowerBound)
                            }
                        }
                    } else {
                        let rPr = "<w:rPr>\(boldElement)</w:rPr>"
                        newContent.insert(contentsOf: rPr, at: matchRange.upperBound)
                    }
                }
            }
        }

        documentXML.replaceSubrange(para.range, with: newContent)
    }

    /// Apply GB and cream highlight to A6 "not consulted" section paragraph
    /// This function handles numbered list paragraphs correctly
    func applyA6NotConsultedFormatting(at index: Int, isOpeningBracket: Bool, isClosingBracket: Bool) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        var newContent = para.content

        // Remove permission markers
        let permStartPattern = #"<w:permStart[^/]*/>"#
        if let regex = try? NSRegularExpression(pattern: permStartPattern) {
            let range = NSRange(newContent.startIndex..., in: newContent)
            newContent = regex.stringByReplacingMatches(in: newContent, range: range, withTemplate: "")
        }
        let permEndPattern = #"<w:permEnd[^/]*/>"#
        if let regex = try? NSRegularExpression(pattern: permEndPattern) {
            let range = NSRange(newContent.startIndex..., in: newContent)
            newContent = regex.stringByReplacingMatches(in: newContent, range: range, withTemplate: "")
        }

        // Extract text content from all w:t elements
        var textContent = ""
        let textPattern = #"<w:t[^>]*>([^<]*)</w:t>"#
        if let regex = try? NSRegularExpression(pattern: textPattern) {
            let range = NSRange(newContent.startIndex..., in: newContent)
            let matches = regex.matches(in: newContent, range: range)
            for match in matches {
                if match.numberOfRanges > 1,
                   let textRange = Range(match.range(at: 1), in: newContent) {
                    textContent += String(newContent[textRange])
                }
            }
        }

        // Extract paragraph properties (including numPr for list formatting)
        var pPrContent = ""
        if let pPrMatch = newContent.range(of: #"<w:pPr>[\s\S]*?</w:pPr>"#, options: .regularExpression) {
            pPrContent = String(newContent[pPrMatch])
        }

        // Extract paragraph opening tag
        var pOpenTag = "<w:p>"
        if let pOpenMatch = newContent.range(of: #"<w:p[^>]*>"#, options: .regularExpression) {
            pOpenTag = String(newContent[pOpenMatch])
        }

        // Build new runs with GB and cream highlight
        var newRuns = ""

        if isOpeningBracket {
            // Gold opening bracket
            newRuns += "<w:r>\(bracketRPr)<w:t>[</w:t></w:r>"
        }

        // Text content with cream highlight (text already XML-escaped from template)
        newRuns += "<w:r>\(contentRPr)<w:t xml:space=\"preserve\">\(textContent)</w:t></w:r>"

        if isClosingBracket {
            // Gold closing bracket
            newRuns += "<w:r>\(bracketRPr)<w:t>]</w:t></w:r>"
        }

        let finalContent = "\(pOpenTag)\(pPrContent)\(newRuns)</w:p>"
        documentXML.replaceSubrange(para.range, with: finalContent)
    }

    /// Set font to Arial for paragraph at given index
    func setFontArial(at index: Int) {
        let paragraphs = getParagraphs()
        guard index < paragraphs.count else { return }

        let para = paragraphs[index]
        var newContent = para.content

        // Font element for Arial
        let fontElement = "<w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\" w:cs=\"Arial\"/>"

        let runPattern = #"<w:r>|<w:r [^>]*>"#
        if let regex = try? NSRegularExpression(pattern: runPattern) {
            let range = NSRange(newContent.startIndex..., in: newContent)
            let matches = regex.matches(in: newContent, range: range)

            for match in matches.reversed() {
                if let matchRange = Range(match.range, in: newContent) {
                    let afterRun = matchRange.upperBound
                    let remainingContent = String(newContent[afterRun...])

                    if remainingContent.hasPrefix("<w:rPr>") {
                        // rPr exists, check if font already set
                        if let rPrEnd = newContent.range(of: "</w:rPr>", range: matchRange.upperBound..<newContent.endIndex) {
                            let rPrContent = String(newContent[matchRange.upperBound..<rPrEnd.lowerBound])
                            if !rPrContent.contains("<w:rFonts") {
                                // Insert font at start of rPr
                                let insertPos = newContent.index(matchRange.upperBound, offsetBy: 7) // after "<w:rPr>"
                                newContent.insert(contentsOf: fontElement, at: insertPos)
                            }
                        }
                    } else {
                        // No rPr, create one with font
                        let rPr = "<w:rPr>\(fontElement)</w:rPr>"
                        newContent.insert(contentsOf: rPr, at: matchRange.upperBound)
                    }
                }
            }
        }

        documentXML.replaceSubrange(para.range, with: newContent)
    }

    // MARK: - Table Operations (for table-based templates like MOJ Leave)

    /// Get all table elements from document.xml
    private func getTables() -> [(range: Range<String.Index>, content: String)] {
        var tables: [(range: Range<String.Index>, content: String)] = []
        var searchStart = documentXML.startIndex

        while searchStart < documentXML.endIndex {
            guard let tableStart = documentXML.range(of: "<w:tbl>", range: searchStart..<documentXML.endIndex) ??
                  documentXML.range(of: "<w:tbl ", range: searchStart..<documentXML.endIndex) else {
                break
            }

            // Find the closing </w:tbl>
            if let endRange = documentXML.range(of: "</w:tbl>", range: tableStart.upperBound..<documentXML.endIndex) {
                let fullRange = tableStart.lowerBound..<endRange.upperBound
                let content = String(documentXML[fullRange])
                tables.append((range: fullRange, content: content))
                searchStart = endRange.upperBound
            } else {
                break
            }
        }

        return tables
    }

    /// Get table cell text content at specific row and column
    private func getTableCells(from tableContent: String) -> [[String]] {
        var rows: [[String]] = []

        // Find all rows
        var rowSearch = tableContent.startIndex
        while rowSearch < tableContent.endIndex {
            guard let rowStart = tableContent.range(of: "<w:tr>", range: rowSearch..<tableContent.endIndex) ??
                  tableContent.range(of: "<w:tr ", range: rowSearch..<tableContent.endIndex) else {
                break
            }

            guard let rowEnd = tableContent.range(of: "</w:tr>", range: rowStart.upperBound..<tableContent.endIndex) else {
                break
            }

            let rowContent = String(tableContent[rowStart.lowerBound..<rowEnd.upperBound])
            var cells: [String] = []

            // Find all cells in this row
            var cellSearch = rowContent.startIndex
            while cellSearch < rowContent.endIndex {
                guard let cellStart = rowContent.range(of: "<w:tc>", range: cellSearch..<rowContent.endIndex) ??
                      rowContent.range(of: "<w:tc ", range: cellSearch..<rowContent.endIndex) else {
                    break
                }

                guard let cellEnd = rowContent.range(of: "</w:tc>", range: cellStart.upperBound..<rowContent.endIndex) else {
                    break
                }

                let cellContent = String(rowContent[cellStart.lowerBound..<cellEnd.upperBound])
                cells.append(cellContent)
                cellSearch = cellEnd.upperBound
            }

            rows.append(cells)
            rowSearch = rowEnd.upperBound
        }

        return rows
    }

    /// Set text in a specific table cell
    /// - Parameters:
    ///   - tableIndex: 0-based table index
    ///   - row: 0-based row index
    ///   - col: 0-based column index
    ///   - text: Text to set in the cell
    func setTableCellText(tableIndex: Int, row: Int, col: Int, text: String) {
        let tables = getTables()
        guard tableIndex < tables.count else { return }

        let table = tables[tableIndex]
        var tableContent = table.content

        // Find the specific row
        var rowSearch = tableContent.startIndex
        var currentRow = 0

        while rowSearch < tableContent.endIndex && currentRow <= row {
            guard let rowStart = tableContent.range(of: "<w:tr>", range: rowSearch..<tableContent.endIndex) ??
                  tableContent.range(of: "<w:tr ", range: rowSearch..<tableContent.endIndex) else {
                return
            }

            guard let rowEnd = tableContent.range(of: "</w:tr>", range: rowStart.upperBound..<tableContent.endIndex) else {
                return
            }

            if currentRow == row {
                // Find the specific cell
                let rowContent = String(tableContent[rowStart.lowerBound..<rowEnd.upperBound])
                var cellSearch = rowContent.startIndex
                var currentCol = 0

                while cellSearch < rowContent.endIndex && currentCol <= col {
                    guard let cellStart = rowContent.range(of: "<w:tc>", range: cellSearch..<rowContent.endIndex) ??
                          rowContent.range(of: "<w:tc ", range: cellSearch..<rowContent.endIndex) else {
                        return
                    }

                    guard let cellEnd = rowContent.range(of: "</w:tc>", range: cellStart.upperBound..<rowContent.endIndex) else {
                        return
                    }

                    if currentCol == col {
                        // Found the cell - replace text content
                        var cellContent = String(rowContent[cellStart.lowerBound..<cellEnd.upperBound])

                        // Escape XML and convert newlines
                        let escapedText = escapeXML(text)
                        let textWithBreaks = escapedText.replacingOccurrences(of: "\n", with: "</w:t></w:r><w:r><w:br/><w:t xml:space=\"preserve\">")

                        // Clear existing text and insert new text
                        // Use lookahead (?=>| ) to match only <w:t> or <w:t ...>, not <w:tc>, <w:tcPr>, <w:tr>, <w:tbl>, etc.
                        let clearPattern = #"(<w:t(?=>| )[^>]*>)[^<]*(</w:t>)"#
                        if let clearRegex = try? NSRegularExpression(pattern: clearPattern) {
                            let range = NSRange(cellContent.startIndex..., in: cellContent)
                            cellContent = clearRegex.stringByReplacingMatches(in: cellContent, range: range, withTemplate: "$1$2")
                        }

                        // Find first w:t element and insert text
                        if let firstWT = cellContent.range(of: "<w:t>") {
                            cellContent.insert(contentsOf: textWithBreaks, at: firstWT.upperBound)
                        } else if let firstWTSpace = cellContent.range(of: #"<w:t xml:space="preserve">"#) {
                            cellContent.insert(contentsOf: textWithBreaks, at: firstWTSpace.upperBound)
                        } else if let firstWTAny = cellContent.range(of: #"<w:t(?=>| )[^>]*>"#, options: .regularExpression) {
                            cellContent.insert(contentsOf: textWithBreaks, at: firstWTAny.upperBound)
                        } else {
                            // No w:t element found, add one in a paragraph
                            if let pStart = cellContent.range(of: "</w:p>") {
                                let newRun = "<w:r><w:t xml:space=\"preserve\">\(textWithBreaks)</w:t></w:r>"
                                cellContent.insert(contentsOf: newRun, at: pStart.lowerBound)
                            }
                        }

                        // Calculate the positions to replace
                        let cellStartOffset = rowContent.distance(from: rowContent.startIndex, to: cellStart.lowerBound)
                        let cellEndOffset = rowContent.distance(from: rowContent.startIndex, to: cellEnd.upperBound)

                        let rowStartOffset = tableContent.distance(from: tableContent.startIndex, to: rowStart.lowerBound)

                        let cellStartInTable = tableContent.index(tableContent.startIndex, offsetBy: rowStartOffset + cellStartOffset)
                        let cellEndInTable = tableContent.index(tableContent.startIndex, offsetBy: rowStartOffset + cellEndOffset)

                        tableContent.replaceSubrange(cellStartInTable..<cellEndInTable, with: cellContent)

                        // Update the main document
                        documentXML.replaceSubrange(table.range, with: tableContent)
                        return
                    }

                    currentCol += 1
                    cellSearch = cellEnd.upperBound
                }
            }

            currentRow += 1
            rowSearch = rowEnd.upperBound
        }
    }

    // MARK: - Raw Document XML Operations

    /// Replace all occurrences of a string in the raw document XML
    func replaceTextInDocument(_ old: String, with new: String) {
        documentXML = documentXML.replacingOccurrences(of: old, with: new)
    }

    /// Mark a checkbox ☐ → ☒ in the paragraph at the given index
    func markCheckbox(at paragraphIndex: Int) {
        let paragraphs = getParagraphs()
        guard paragraphIndex < paragraphs.count else { return }
        let para = paragraphs[paragraphIndex]
        let modified = para.content.replacingOccurrences(of: "☐", with: "☒")
        documentXML.replaceSubrange(para.range, with: modified)
    }

    /// Set text in a nested table cell (for tables-within-tables like the T131 header box).
    /// Uses raw XML scanning to find the nth nested <w:tbl> inside a top-level table.
    func setNestedTableCellText(outerTableIndex: Int, nestedRow: Int, nestedCol: Int, text: String) {
        // We need to find the outer table properly (nesting-aware)
        // Then locate the nested table inside it and modify a cell
        var depth = 0
        var topLevelIndex = -1
        var outerStart: String.Index?
        var outerEnd: String.Index?
        var searchPos = documentXML.startIndex

        // Walk through all <w:tbl> and </w:tbl> tags with nesting
        while searchPos < documentXML.endIndex {
            let tblOpen = documentXML.range(of: "<w:tbl", range: searchPos..<documentXML.endIndex)
            let tblClose = documentXML.range(of: "</w:tbl>", range: searchPos..<documentXML.endIndex)

            // Find which comes first
            if let openRange = tblOpen, let closeRange = tblClose {
                if openRange.lowerBound < closeRange.lowerBound {
                    depth += 1
                    if depth == 1 {
                        topLevelIndex += 1
                        outerStart = openRange.lowerBound
                    }
                    searchPos = openRange.upperBound
                } else {
                    if depth == 1 {
                        outerEnd = closeRange.upperBound
                        if topLevelIndex == outerTableIndex {
                            break
                        }
                    }
                    depth -= 1
                    searchPos = closeRange.upperBound
                }
            } else if let openRange = tblOpen {
                depth += 1
                if depth == 1 {
                    topLevelIndex += 1
                    outerStart = openRange.lowerBound
                }
                searchPos = openRange.upperBound
            } else if let closeRange = tblClose {
                if depth == 1 {
                    outerEnd = closeRange.upperBound
                    if topLevelIndex == outerTableIndex {
                        break
                    }
                }
                depth -= 1
                searchPos = closeRange.upperBound
            } else {
                break
            }
        }

        guard let oStart = outerStart, let oEnd = outerEnd else { return }
        var outerContent = String(documentXML[oStart..<oEnd])

        // Find the nested table (first <w:tbl> inside the outer table, skipping the outer's own opening)
        guard let outerTagEnd = outerContent.range(of: ">") else { return }
        guard let nestedTblStart = outerContent.range(of: "<w:tbl", range: outerTagEnd.upperBound..<outerContent.endIndex) else { return }
        guard let nestedTblEnd = outerContent.range(of: "</w:tbl>", range: nestedTblStart.upperBound..<outerContent.endIndex) else { return }

        let nestedContent = String(outerContent[nestedTblStart.lowerBound..<nestedTblEnd.upperBound])

        // Find the target row
        var rowSearch = nestedContent.startIndex
        var currentRow = 0
        while rowSearch < nestedContent.endIndex && currentRow <= nestedRow {
            guard let rowStart = nestedContent.range(of: "<w:tr", range: rowSearch..<nestedContent.endIndex) else { return }
            guard let rowEnd = nestedContent.range(of: "</w:tr>", range: rowStart.upperBound..<nestedContent.endIndex) else { return }

            if currentRow == nestedRow {
                let rowContent = String(nestedContent[rowStart.lowerBound..<rowEnd.upperBound])
                // Find the target cell
                var cellSearch = rowContent.startIndex
                var currentCol = 0
                while cellSearch < rowContent.endIndex && currentCol <= nestedCol {
                    guard let cellStart = rowContent.range(of: "<w:tc", range: cellSearch..<rowContent.endIndex) else { return }
                    guard let cellEnd = rowContent.range(of: "</w:tc>", range: cellStart.upperBound..<rowContent.endIndex) else { return }

                    if currentCol == nestedCol {
                        var cellContent = String(rowContent[cellStart.lowerBound..<cellEnd.upperBound])
                        let escapedText = escapeXML(text)

                        // Clear existing text
                        let clearPattern = #"(<w:t[^>]*>)[^<]*(</w:t>)"#
                        if let clearRegex = try? NSRegularExpression(pattern: clearPattern) {
                            let range = NSRange(cellContent.startIndex..., in: cellContent)
                            cellContent = clearRegex.stringByReplacingMatches(in: cellContent, range: range, withTemplate: "$1$2")
                        }

                        // Insert new text
                        if let firstWT = cellContent.range(of: "<w:t>") {
                            cellContent.insert(contentsOf: escapedText, at: firstWT.upperBound)
                        } else if let firstWTSpace = cellContent.range(of: #"<w:t xml:space="preserve">"#) {
                            cellContent.insert(contentsOf: escapedText, at: firstWTSpace.upperBound)
                        } else if let firstWTAny = cellContent.range(of: #"<w:t[^>]*>"#, options: .regularExpression) {
                            cellContent.insert(contentsOf: escapedText, at: firstWTAny.upperBound)
                        } else if let pEnd = cellContent.range(of: "</w:p>") {
                            let newRun = "<w:r><w:t xml:space=\"preserve\">\(escapedText)</w:t></w:r>"
                            cellContent.insert(contentsOf: newRun, at: pEnd.lowerBound)
                        }

                        // Replace the cell in the full document
                        let oldCell = String(rowContent[cellStart.lowerBound..<cellEnd.upperBound])
                        outerContent = outerContent.replacingOccurrences(of: oldCell, with: cellContent)
                        documentXML.replaceSubrange(oStart..<oEnd, with: outerContent)
                        return
                    }
                    currentCol += 1
                    cellSearch = cellEnd.upperBound
                }
            }
            currentRow += 1
            rowSearch = rowEnd.upperBound
        }
    }

    // MARK: - Generate Output

    func generateDOCX() -> Data? {
        // Update document.xml in entries
        guard let docXMLData = documentXML.data(using: .utf8) else { return nil }

        var updatedEntries = zipEntries.filter { $0.name != "word/document.xml" }
        updatedEntries.append((name: "word/document.xml", data: docXMLData))

        // Remove document protection if present
        updatedEntries = updatedEntries.map { entry in
            if entry.name == "word/settings.xml",
               var settingsXML = String(data: entry.data, encoding: .utf8) {
                // Remove documentProtection element
                if let protStart = settingsXML.range(of: "<w:documentProtection"),
                   let protEnd = settingsXML.range(of: "/>", range: protStart.upperBound..<settingsXML.endIndex) {
                    settingsXML.removeSubrange(protStart.lowerBound..<protEnd.upperBound)
                }
                return (name: entry.name, data: settingsXML.data(using: .utf8) ?? entry.data)
            }
            return entry
        }

        return createZipFile(from: updatedEntries)
    }

    // MARK: - ZIP Utilities

    private func extractZipEntries(from data: Data) -> [(name: String, data: Data)]? {
        var entries: [(name: String, data: Data)] = []
        var offset = 0

        while offset < data.count - 4 {
            // Check for local file header signature (0x04034b50)
            let sig = data.subdata(in: offset..<offset+4)
            guard sig == Data([0x50, 0x4b, 0x03, 0x04]) else {
                // Check for central directory signature
                if sig == Data([0x50, 0x4b, 0x01, 0x02]) {
                    break // End of local file headers
                }
                offset += 1
                continue
            }

            // Parse local file header
            let flags = UInt16(littleEndian: data.subdata(in: offset+6..<offset+8).withUnsafeBytes { $0.load(as: UInt16.self) })
            let compressionMethod = UInt16(littleEndian: data.subdata(in: offset+8..<offset+10).withUnsafeBytes { $0.load(as: UInt16.self) })
            let compressedSize = UInt32(littleEndian: data.subdata(in: offset+18..<offset+22).withUnsafeBytes { $0.load(as: UInt32.self) })
            let uncompressedSize = UInt32(littleEndian: data.subdata(in: offset+22..<offset+26).withUnsafeBytes { $0.load(as: UInt32.self) })
            let nameLength = UInt16(littleEndian: data.subdata(in: offset+26..<offset+28).withUnsafeBytes { $0.load(as: UInt16.self) })
            let extraLength = UInt16(littleEndian: data.subdata(in: offset+28..<offset+30).withUnsafeBytes { $0.load(as: UInt16.self) })

            let nameStart = offset + 30
            let nameEnd = nameStart + Int(nameLength)
            guard nameEnd <= data.count else { break }

            let nameData = data.subdata(in: nameStart..<nameEnd)
            guard let name = String(data: nameData, encoding: .utf8) else {
                offset = nameEnd + Int(extraLength) + Int(compressedSize)
                continue
            }

            let dataStart = nameEnd + Int(extraLength)
            let dataEnd = dataStart + Int(compressedSize)
            guard dataEnd <= data.count else { break }

            let fileData = data.subdata(in: dataStart..<dataEnd)

            // Decompress if needed
            var decompressedData: Data
            if compressionMethod == 8 { // DEFLATE
                if let inflated = inflateData(fileData, expectedSize: Int(uncompressedSize)) {
                    decompressedData = inflated
                } else {
                    decompressedData = fileData
                }
            } else {
                decompressedData = fileData
            }

            entries.append((name: name, data: decompressedData))
            offset = dataEnd
        }

        return entries.isEmpty ? nil : entries
    }

    private func inflateData(_ data: Data, expectedSize: Int) -> Data? {
        var destBuffer = [UInt8](repeating: 0, count: expectedSize)
        var sourceBuffer = [UInt8](data)

        let result = compression_decode_buffer(
            &destBuffer, expectedSize,
            &sourceBuffer, data.count,
            nil,
            COMPRESSION_ZLIB
        )

        guard result > 0 else { return nil }
        return Data(destBuffer.prefix(result))
    }

    private func deflateData(_ data: Data) -> Data? {
        let destSize = data.count + 1024
        var destBuffer = [UInt8](repeating: 0, count: destSize)
        var sourceBuffer = [UInt8](data)

        let result = compression_encode_buffer(
            &destBuffer, destSize,
            &sourceBuffer, data.count,
            nil,
            COMPRESSION_ZLIB
        )

        guard result > 0 else { return nil }
        return Data(destBuffer.prefix(result))
    }

    private func createZipFile(from entries: [(name: String, data: Data)]) -> Data {
        var zipData = Data()
        var centralDirectory = Data()
        var localHeaderOffsets: [UInt32] = []

        for entry in entries {
            localHeaderOffsets.append(UInt32(zipData.count))

            let nameData = entry.name.data(using: .utf8) ?? Data()
            let compressedData = deflateData(entry.data) ?? entry.data
            let compressionMethod: UInt16 = compressedData.count < entry.data.count ? 8 : 0
            let finalData = compressionMethod == 8 ? compressedData : entry.data

            let crc = crc32(entry.data)

            // Local file header
            var localHeader = Data()
            localHeader.append(contentsOf: [0x50, 0x4b, 0x03, 0x04]) // Signature
            localHeader.append(contentsOf: withUnsafeBytes(of: UInt16(20).littleEndian) { Array($0) }) // Version
            localHeader.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian) { Array($0) }) // Flags
            localHeader.append(contentsOf: withUnsafeBytes(of: compressionMethod.littleEndian) { Array($0) }) // Compression
            localHeader.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian) { Array($0) }) // Mod time
            localHeader.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian) { Array($0) }) // Mod date
            localHeader.append(contentsOf: withUnsafeBytes(of: crc.littleEndian) { Array($0) }) // CRC
            localHeader.append(contentsOf: withUnsafeBytes(of: UInt32(finalData.count).littleEndian) { Array($0) }) // Compressed size
            localHeader.append(contentsOf: withUnsafeBytes(of: UInt32(entry.data.count).littleEndian) { Array($0) }) // Uncompressed size
            localHeader.append(contentsOf: withUnsafeBytes(of: UInt16(nameData.count).littleEndian) { Array($0) }) // Name length
            localHeader.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian) { Array($0) }) // Extra length
            localHeader.append(nameData)
            localHeader.append(finalData)

            zipData.append(localHeader)

            // Central directory entry
            var cdEntry = Data()
            cdEntry.append(contentsOf: [0x50, 0x4b, 0x01, 0x02]) // Signature
            cdEntry.append(contentsOf: withUnsafeBytes(of: UInt16(20).littleEndian) { Array($0) }) // Version made by
            cdEntry.append(contentsOf: withUnsafeBytes(of: UInt16(20).littleEndian) { Array($0) }) // Version needed
            cdEntry.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian) { Array($0) }) // Flags
            cdEntry.append(contentsOf: withUnsafeBytes(of: compressionMethod.littleEndian) { Array($0) }) // Compression
            cdEntry.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian) { Array($0) }) // Mod time
            cdEntry.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian) { Array($0) }) // Mod date
            cdEntry.append(contentsOf: withUnsafeBytes(of: crc.littleEndian) { Array($0) }) // CRC
            cdEntry.append(contentsOf: withUnsafeBytes(of: UInt32(finalData.count).littleEndian) { Array($0) }) // Compressed size
            cdEntry.append(contentsOf: withUnsafeBytes(of: UInt32(entry.data.count).littleEndian) { Array($0) }) // Uncompressed size
            cdEntry.append(contentsOf: withUnsafeBytes(of: UInt16(nameData.count).littleEndian) { Array($0) }) // Name length
            cdEntry.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian) { Array($0) }) // Extra length
            cdEntry.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian) { Array($0) }) // Comment length
            cdEntry.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian) { Array($0) }) // Disk number
            cdEntry.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian) { Array($0) }) // Internal attrs
            cdEntry.append(contentsOf: withUnsafeBytes(of: UInt32(0).littleEndian) { Array($0) }) // External attrs
            cdEntry.append(contentsOf: withUnsafeBytes(of: localHeaderOffsets.last!.littleEndian) { Array($0) }) // Offset
            cdEntry.append(nameData)

            centralDirectory.append(cdEntry)
        }

        let cdStart = UInt32(zipData.count)
        zipData.append(centralDirectory)

        // End of central directory
        var eocd = Data()
        eocd.append(contentsOf: [0x50, 0x4b, 0x05, 0x06]) // Signature
        eocd.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian) { Array($0) }) // Disk number
        eocd.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian) { Array($0) }) // CD disk
        eocd.append(contentsOf: withUnsafeBytes(of: UInt16(entries.count).littleEndian) { Array($0) }) // Entries on disk
        eocd.append(contentsOf: withUnsafeBytes(of: UInt16(entries.count).littleEndian) { Array($0) }) // Total entries
        eocd.append(contentsOf: withUnsafeBytes(of: UInt32(centralDirectory.count).littleEndian) { Array($0) }) // CD size
        eocd.append(contentsOf: withUnsafeBytes(of: cdStart.littleEndian) { Array($0) }) // CD offset
        eocd.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian) { Array($0) }) // Comment length

        zipData.append(eocd)

        return zipData
    }

    private func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        let table = makeCRC32Table()

        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = table[index] ^ (crc >> 8)
        }

        return ~crc
    }

    private func makeCRC32Table() -> [UInt32] {
        var table = [UInt32](repeating: 0, count: 256)
        for i in 0..<256 {
            var crc = UInt32(i)
            for _ in 0..<8 {
                if crc & 1 == 1 {
                    crc = 0xEDB88320 ^ (crc >> 1)
                } else {
                    crc >>= 1
                }
            }
            table[i] = crc
        }
        return table
    }

    private func escapeXML(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}

// MARK: - Form-Specific Exporters

// MARK: A2 Form Exporter
class A2FormDOCXExporter {
    private let formData: A2FormData

    init(formData: A2FormData) {
        self.formData = formData
    }

    func generateDOCX() -> Data? {
        let exporter = TemplateDOCXExporter(templateName: "Form_A2_template")
        guard exporter.loadTemplate() else { return nil }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy"

        // Paragraph 3: Hospital name and address - gold bracketed placeholder
        var hospitalText = formData.hospitalName
        if !formData.hospitalAddress.isEmpty {
            hospitalText += ", " + formData.hospitalAddress
        }
        exporter.removePermissionMarkers(at: 3)
        exporter.fillBracketContent(at: 3, content: hospitalText)
        exporter.setFontArial(at: 3)

        // Paragraph 5: AMHP details - gold bracketed placeholder
        var amhpText = formData.amhpName
        if !formData.amhpAddress.isEmpty {
            amhpText += ", " + formData.amhpAddress
        }
        if !formData.amhpEmail.isEmpty {
            amhpText += ", " + formData.amhpEmail
        }
        exporter.removePermissionMarkers(at: 5)
        exporter.fillBracketContent(at: 5, content: amhpText)
        exporter.setFontArial(at: 5)

        // Paragraph 7: Patient details - gold bracketed placeholder
        var patientText = formData.patientName
        if !formData.patientAddress.isEmpty {
            patientText += ", " + formData.patientAddress
        }
        exporter.removePermissionMarkers(at: 7)
        exporter.fillBracketContent(at: 7, content: patientText)
        exporter.setFontArial(at: 7)

        // Paragraph 10: Local authority - gold bracketed placeholder
        exporter.removePermissionMarkers(at: 10)
        exporter.fillBracketContent(at: 10, content: formData.localAuthority)
        exporter.setFontArial(at: 10)

        // Paragraphs 12-14: Authority approval
        // Para 13: Instruction text "[name of local social services authority...]" - NO highlight
        exporter.removePermissionMarkers(at: 13)
        exporter.setFontArial(at: 13)
        // Para 14: Always show gold bracketed placeholder for different authority name
        exporter.removePermissionMarkers(at: 14)
        exporter.fillBracketContent(at: 14, content: formData.approvedByDifferentAuthority)
        exporter.setFontArial(at: 14)

        if formData.approvedBySameAuthority {
            // Use gold brackets for "that authority"
            exporter.removePermissionMarkers(at: 12)
            exporter.setBracketLine(at: 12, content: "that authority")
            exporter.setFontArial(at: 12)
            // Strikethrough the "different authority" section
            exporter.strikethrough(at: 13)
            exporter.strikethrough(at: 14)
        } else {
            // Strikethrough "that authority" option
            exporter.strikethrough(at: 12)
        }

        // Nearest relative section (paragraphs 15-26)
        // Para 17: "(a) To the best of my knowledge..." - opening GB (preserves template text)
        exporter.wrapWithOpeningBracket(at: 17)
        exporter.setFontArial(at: 17)
        // Para 19: "is the patient's nearest relative..." - highlighted (continues from para 17)
        exporter.removePermissionMarkers(at: 19)
        exporter.highlightYellow(at: 19)
        exporter.setFontArial(at: 19)
        // Para 20: "(b) I understand that [PRINT full name and address]" - highlighted
        exporter.removePermissionMarkers(at: 20)
        exporter.highlightYellow(at: 20)
        exporter.setFontArial(at: 20)
        // Para 22: "has been authorised by a county court..." - highlighted
        exporter.removePermissionMarkers(at: 22)
        exporter.highlightYellow(at: 22)
        exporter.setFontArial(at: 22)
        // Para 23: "I have/have not yet*..." - closing GB at end (preserves template text)
        exporter.wrapWithClosingBracket(at: 23)
        exporter.setFontArial(at: 23)

        // Paragraphs 25-26: Wrap with gold brackets (the "unknown NR" section)
        // Para 25 gets opening gold bracket, Para 26 gets closing gold bracket
        exporter.wrapWithOpeningBracket(at: 25)  // "(a) I have been unable to ascertain..."
        exporter.setFontArial(at: 25)
        exporter.wrapWithClosingBracket(at: 26)  // "(b) To the best of my knowledge..."
        exporter.setFontArial(at: 26)

        var nrText = formData.nrName
        if !formData.nrAddress.isEmpty {
            nrText += ", " + formData.nrAddress
        }

        // Para 18 & 21: Always set highlighted placeholders first (no GB)
        exporter.setParagraphTextHighlightOnly(at: 18, text: "")
        exporter.setFontArial(at: 18)
        exporter.setParagraphTextHighlightOnly(at: 21, text: "")
        exporter.setFontArial(at: 21)

        if formData.nrKnown {
            if formData.nrIsNearestRelative {
                // Option A - is the nearest relative
                // Para 18: Fill with NR name/address
                exporter.setParagraphTextHighlightOnly(at: 18, text: nrText)
                exporter.setFontArial(at: 18)
                // Para 21 already has empty placeholder - strikethrough option B
                exporter.strikethrough(at: 20)
                exporter.strikethrough(at: 21)
                exporter.strikethrough(at: 22)
            } else {
                // Option B - authorized person
                // Para 18 already has empty placeholder - strikethrough option A
                exporter.strikethrough(at: 17)
                exporter.strikethrough(at: 18)
                exporter.strikethrough(at: 19)
                // Para 21: Fill with NR name/address
                exporter.setParagraphTextHighlightOnly(at: 21, text: nrText)
                exporter.setFontArial(at: 21)
            }

            // Strikethrough NR unknown sections (25-26 already have gold brackets)
            exporter.strikethrough(at: 24)
            exporter.strikethrough(at: 25)
            exporter.strikethrough(at: 26)
        } else {
            // NR not known - placeholders already set above
            // Strikethrough known sections
            for i in 15..<24 {
                exporter.strikethrough(at: i)
            }
            // Strikethrough the non-selected unknown reason option
            if formData.nrUnableToAscertain {
                exporter.strikethrough(at: 26)
            } else {
                exporter.strikethrough(at: 25)
            }
        }

        // Paragraph 29: Last seen date
        let lastSeenDate = dateFormatter.string(from: formData.lastSeenDate)
        exporter.fillBracketContent(at: 29, content: lastSeenDate)
        exporter.setFontArial(at: 29)

        // Paragraph 34: No acquaintance reason (if applicable)
        exporter.fillBracketContent(at: 34, content: formData.noAcquaintanceReason)
        exporter.setFontArial(at: 34)

        // Paragraph 35: "[If you need to continue... indicate here [ ] and attach...]"
        // Inner checkbox [ ] needs gold brackets with cream highlight
        exporter.setIndicateHereCheckbox(at: 35)
        exporter.setFontArial(at: 35)

        // Paragraph 36: Signature - "Signed [blank] Date [date]" with yellow highlight on brackets
        let sigDate = dateFormatter.string(from: formData.signatureDate)
        exporter.setSignatureWithSelectiveHighlight(at: 36, signatureContent: "", dateContent: sigDate)
        exporter.setFontArial(at: 36)

        return exporter.generateDOCX()
    }
}

// MARK: T2 Form Exporter
class T2FormDOCXExporter {
    private let formData: T2FormData

    init(formData: T2FormData) {
        self.formData = formData
    }

    func generateDOCX() -> Data? {
        let exporter = TemplateDOCXExporter(templateName: "Form_T2_template")
        guard exporter.loadTemplate() else { return nil }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy"

        // MARK: - Clinician (paragraph 3 - whitespace field after label at 2)
        var clinicianText = formData.acName
        if !formData.hospitalName.isEmpty {
            clinicianText += ", " + formData.hospitalName
        }
        exporter.setParagraphText(at: 3, text: clinicianText, highlight: true)
        exporter.setFontArial(at: 3)

        // MARK: - Certifier Type (paragraph 4) - strikethrough non-selected option
        // Options: "approved clinician in charge of the treatment" OR "SOAD"
        exporter.setT2CertifierType(at: 4, isApprovedClinician: formData.certifierType == .approvedClinician)

        // MARK: - Patient (paragraph 6 - whitespace field after label at 5)
        var patientText = formData.patientName
        if !formData.patientAddress.isEmpty {
            patientText += ", " + formData.patientAddress
        }
        exporter.setParagraphText(at: 6, text: patientText, highlight: true)
        exporter.setFontArial(at: 6)

        // MARK: - Treatment Description (paragraph 8 - whitespace field after label at 7)
        var treatmentText = formData.treatmentDescription
        if treatmentText.isEmpty {
            treatmentText = formData.t2Treatment.displayText
        }
        exporter.setParagraphText(at: 8, text: treatmentText, highlight: true)
        exporter.setFontArial(at: 8)
        // Clear overflow paragraphs 9-10
        exporter.removePermissionMarkers(at: 9)
        exporter.removePermissionMarkers(at: 10)

        // MARK: - "[If you need to continue...]" line (paragraph 11) - gold brackets checkbox
        exporter.setIndicateHereCheckbox(at: 11)
        exporter.setFontArial(at: 11)

        // MARK: - Signature (paragraph 14)
        let sigDate = dateFormatter.string(from: formData.signatureDate)
        exporter.setSignatureWithSelectiveHighlight(at: 14, signatureContent: "", dateContent: sigDate)
        exporter.setFontArial(at: 14)

        return exporter.generateDOCX()
    }
}

// MARK: CTO1 Form Exporter
class CTO1FormDOCXExporter {
    private let formData: CTO1FormData

    init(formData: CTO1FormData) {
        self.formData = formData
    }

    func generateDOCX() -> Data? {
        let exporter = TemplateDOCXExporter(templateName: "Form_CTO1_template")
        guard exporter.loadTemplate() else { return nil }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy"

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        // ═══════════════════════════════════════════════════════════════════
        // PART 1 - Responsible Clinician
        // ═══════════════════════════════════════════════════════════════════

        // MARK: - RC Name/Address/Email (paragraph 5 - whitespace field after label at 4)
        var rcText = formData.rcName
        if !formData.responsibleHospital.isEmpty {
            rcText += ", " + formData.responsibleHospital
        }
        if !formData.rcEmail.isEmpty {
            rcText += ", " + formData.rcEmail
        }
        exporter.setParagraphText(at: 5, text: rcText, highlight: true)
        exporter.setFontArial(at: 5)

        // MARK: - Patient (paragraph 8 - whitespace field after label at 7)
        var patientText = formData.patientName
        if !formData.patientAddress.isEmpty {
            patientText += ", " + formData.patientAddress
        }
        exporter.setParagraphText(at: 8, text: patientText, highlight: true)
        exporter.setFontArial(at: 8)

        // MARK: - Treatment Necessity (paragraphs 12-14) with gold brackets
        // (i) the patient's health - opening bracket
        // (ii) the patient's safety - cream highlight only
        // (iii) the protection of other persons - closing bracket
        let healthStrike = !formData.clinicalReasons.healthEnabled
        let safetyStrike = !formData.clinicalReasons.safetyEnabled || !formData.clinicalReasons.safetySelfEnabled
        let othersStrike = !formData.clinicalReasons.safetyEnabled || !formData.clinicalReasons.safetyOthersEnabled

        exporter.setDetentionReasonWithOpeningBracket(at: 12, withStrikethrough: healthStrike)
        exporter.setDetentionReasonWithCreamHighlightOnly(at: 13, withStrikethrough: safetyStrike)
        exporter.setDetentionReasonWithClosingBracket(at: 14, withStrikethrough: othersStrike)

        // MARK: - Grounds/Opinion (paragraph 21 - whitespace field after label at 20)
        // Build complete patient info for text generation
        var patientInfoForText = formData.patientInfo
        let nameParts = formData.patientName.components(separatedBy: " ")
        patientInfoForText.firstName = nameParts.first ?? ""
        patientInfoForText.lastName = nameParts.dropFirst().joined(separator: " ")
        patientInfoForText.manualAge = formData.patientAge
        // Copy gender and ethnicity from form's patientInfo
        patientInfoForText.gender = formData.patientInfo.gender
        patientInfoForText.ethnicity = formData.patientInfo.ethnicity

        // Always use patient-specific text generation (with age, demographics, pronouns)
        var groundsText = formData.clinicalReasons.generateTextWithPatient(patientInfoForText)
        if groundsText.isEmpty {
            groundsText = formData.clinicalReasons.generatedText
        }
        exporter.setParagraphText(at: 21, text: groundsText, highlight: true)
        exporter.setFontArial(at: 21)
        // Clear overflow paragraphs 22-23
        exporter.removePermissionMarkers(at: 22)
        exporter.removePermissionMarkers(at: 23)

        // MARK: - "[If you need to continue...]" line (paragraph 24) - gold brackets checkbox
        exporter.setIndicateHereCheckbox(at: 24)
        exporter.setFontArial(at: 24)

        // MARK: - Conditions (paragraph 30 - whitespace field after label at 29)
        var conditionsText = formData.standardConditions.generatedText
        if !formData.additionalConditions.isEmpty {
            if !conditionsText.isEmpty {
                conditionsText += "\n"
            }
            conditionsText += formData.additionalConditions
        }
        exporter.setParagraphText(at: 30, text: conditionsText, highlight: true)
        exporter.setFontArial(at: 30)

        // MARK: - Part 1 RC Signature (paragraph 38) - gold brackets with cream highlight
        let rcSigDate = dateFormatter.string(from: formData.rcSignatureDate)
        exporter.fillSignedDateLineHighlighted(at: 38, signatureContent: "", dateContent: rcSigDate)
        exporter.setLineSpacing15(at: 38)

        // Paragraph 39 is PART 2 header - do not modify

        // ═══════════════════════════════════════════════════════════════════
        // PART 2 - AMHP
        // ═══════════════════════════════════════════════════════════════════

        // MARK: - AMHP Name/Address (paragraph 41) - "I [PRINT full name and address]" - gold brackets with cream highlight
        var amhpFullNameAddress = formData.amhpName
        if !formData.amhpLocalAuthority.isEmpty {
            amhpFullNameAddress += ", " + formData.amhpLocalAuthority
        }
        exporter.setBracketLineHighlighted(at: 41, content: amhpFullNameAddress)

        // MARK: - Local Social Services Authority (paragraph 43) - "am acting on behalf of [LSA]" - gold brackets with cream highlight
        exporter.setBracketLineHighlighted(at: 43, content: formData.amhpLocalAuthority)

        // MARK: - "that authority" bracket (paragraph 45) - gold brackets with cream highlight
        exporter.setBracketLineHighlighted(at: 45, content: "that authority ")

        // MARK: - Different LSA name bracket (paragraph 47) - gold brackets with cream highlight
        exporter.setBracketLineHighlighted(at: 47, content: "")

        // MARK: - AMHP Signature line (paragraph 52) - gold brackets with cream highlight
        exporter.fillSignedWithSuffixLineHighlighted(at: 52, signatureContent: "", suffix: "Approved mental health professional")
        exporter.setLineSpacing15(at: 52)

        // MARK: - AMHP Date line (paragraph 53) - gold brackets with cream highlight
        let amhpSigDate = dateFormatter.string(from: formData.amhpSignatureDate)
        exporter.fillLabelBracketLineHighlighted(at: 53, label: "Date", content: amhpSigDate)
        exporter.setLineSpacing15(at: 53)

        // ═══════════════════════════════════════════════════════════════════
        // PART 3 - CTO Effective Date & RC Signature
        // ═══════════════════════════════════════════════════════════════════

        // MARK: - Effective Date bracket (paragraph 57) - gold brackets with cream highlight
        let effDate = dateFormatter.string(from: formData.ctoStartDate)
        exporter.setBracketLineHighlighted(at: 57, content: effDate)
        exporter.setLineSpacing15(at: 57)

        // MARK: - Time bracket (paragraph 59) - gold brackets with cream highlight
        let effTime = timeFormatter.string(from: formData.ctoStartDate)
        exporter.setBracketLineHighlighted(at: 59, content: effTime)
        exporter.setLineSpacing15(at: 59)

        // MARK: - Part 3 RC Signature line (paragraph 60) - gold brackets with cream highlight
        exporter.fillSignedWithSuffixLineHighlighted(at: 60, signatureContent: "", suffix: "Responsible clinician")
        exporter.setLineSpacing15(at: 60)

        // MARK: - Part 3 Date line (paragraph 61) - gold brackets with cream highlight
        exporter.fillLabelBracketLineHighlighted(at: 61, label: "Date", content: rcSigDate)
        exporter.setLineSpacing15(at: 61)

        return exporter.generateDOCX()
    }
}

// MARK: A4 Form Exporter
class A4FormDOCXExporter {
    private let formData: A4FormData

    init(formData: A4FormData) {
        self.formData = formData
    }

    func generateDOCX() -> Data? {
        let exporter = TemplateDOCXExporter(templateName: "Form_A4_template")
        guard exporter.loadTemplate() else { return nil }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy"

        // Paragraph 3: Doctor name, address, email (whitespace field after label)
        var pracText = formData.doctorName
        if !formData.doctorAddress.isEmpty {
            pracText += ", " + formData.doctorAddress
        }
        exporter.setParagraphText(at: 3, text: pracText, highlight: true)
        exporter.setFontArial(at: 3)

        // Paragraph 5: Patient name and address (whitespace field after label)
        var patientText = formData.patientName
        if !formData.patientAddress.isEmpty {
            patientText += ", " + formData.patientAddress
        }
        exporter.setParagraphText(at: 5, text: patientText, highlight: true)
        exporter.setFontArial(at: 5)

        // Paragraph 8: Examination date (whitespace field after label)
        let examDate = dateFormatter.string(from: formData.examinationDate)
        exporter.setParagraphText(at: 8, text: examDate, highlight: true)
        exporter.setFontArial(at: 8)

        // Paragraphs 9-10: Previous acquaintance and S12 - bracket spans both lines
        exporter.removePermissionMarkers(at: 9)
        exporter.removePermissionMarkers(at: 10)
        exporter.applySpanningBracketStart(at: 9, content: "*I had previous acquaintance with the patient before I conducted that examination.")
        exporter.applySpanningBracketEnd(at: 10, content: "*I am approved under section 12 of the Act as having special experience in the diagnosis or treatment of mental disorder.")
        if formData.previousAcquaintance == .none {
            exporter.safeStrikethrough(at: 9)
        }
        if !formData.isSection12Approved {
            exporter.safeStrikethrough(at: 10)
        }

        // Paragraphs 16-18: Detention reasons with golden brackets
        // Para 16 gets opening bracket [, para 18 gets closing bracket ]
        let healthStrike = !formData.clinicalReasons.healthEnabled
        let safetyStrike = !formData.clinicalReasons.safetyEnabled || !formData.clinicalReasons.safetySelfEnabled
        let othersStrike = !formData.clinicalReasons.safetyEnabled || !formData.clinicalReasons.safetyOthersEnabled

        exporter.setDetentionReasonWithOpeningBracket(at: 16, withStrikethrough: healthStrike)
        exporter.setDetentionReasonWithCreamHighlightOnly(at: 17, withStrikethrough: safetyStrike)
        exporter.setDetentionReasonWithClosingBracket(at: 18, withStrikethrough: othersStrike)

        // Paragraph 21: Instruction text for clinical reasons (plain text, no GB or highlight)
        let instructionText = "[Your reasons should cover both (a) and (b) above. As part of them: describe the patient's symptoms and behaviour and explain how those symptoms and behaviour lead you to your opinion; explain why the patient ought to be admitted to hospital and why informal admission is not appropriate.]"
        exporter.setParagraphText(at: 21, text: instructionText, highlight: false)
        exporter.setFontArial(at: 21)

        // Paragraph 22: Clinical reasons/opinion
        var clinicalText = ""
        if !formData.mentalDisorderDescription.isEmpty {
            clinicalText = formData.mentalDisorderDescription
        } else if !formData.clinicalReasons.generatedText.isEmpty {
            clinicalText = formData.clinicalReasons.generatedText
        }

        // Replace "The patient" with actual patient name and demographics
        // Format: "John Doe is a 39 year old Asian man"
        if !clinicalText.isEmpty && !formData.patientName.isEmpty {
            var patientDescription = formData.patientName
            if let age = formData.patientInfo.age {
                patientDescription += " is a \(age) year old"
            } else {
                patientDescription += " is a"
            }
            // Add ethnicity (use shortDescription to drop "Other" suffix)
            let ethnicityDesc = formData.patientInfo.ethnicity.shortDescription.lowercased()
            if !ethnicityDesc.isEmpty {
                patientDescription += " \(ethnicityDesc)"
            }
            // Add gender noun (man/woman/person) instead of male/female, plus "who" for grammar
            patientDescription += " \(formData.patientInfo.gender.genderNoun) who"
            clinicalText = clinicalText.replacingOccurrences(of: "The patient", with: patientDescription)
            clinicalText = clinicalText.replacingOccurrences(of: "the patient", with: patientDescription.lowercased())

            // Replace pronouns based on gender (order matters - longest matches first)
            let gender = formData.patientInfo.gender
            if gender == .male {
                clinicalText = clinicalText.replacingOccurrences(of: " themselves", with: " himself")
                clinicalText = clinicalText.replacingOccurrences(of: " their ", with: " his ")
                clinicalText = clinicalText.replacingOccurrences(of: " their,", with: " his,")
                clinicalText = clinicalText.replacingOccurrences(of: " their.", with: " his.")
                clinicalText = clinicalText.replacingOccurrences(of: "Their ", with: "His ")
                clinicalText = clinicalText.replacingOccurrences(of: " them ", with: " him ")
                clinicalText = clinicalText.replacingOccurrences(of: " them,", with: " him,")
                clinicalText = clinicalText.replacingOccurrences(of: " them.", with: " him.")
                clinicalText = clinicalText.replacingOccurrences(of: " they ", with: " he ")
                clinicalText = clinicalText.replacingOccurrences(of: "They ", with: "He ")
            } else if gender == .female {
                clinicalText = clinicalText.replacingOccurrences(of: " themselves", with: " herself")
                clinicalText = clinicalText.replacingOccurrences(of: " their ", with: " her ")
                clinicalText = clinicalText.replacingOccurrences(of: " their,", with: " her,")
                clinicalText = clinicalText.replacingOccurrences(of: " their.", with: " her.")
                clinicalText = clinicalText.replacingOccurrences(of: "Their ", with: "Her ")
                clinicalText = clinicalText.replacingOccurrences(of: " them ", with: " her ")
                clinicalText = clinicalText.replacingOccurrences(of: " them,", with: " her,")
                clinicalText = clinicalText.replacingOccurrences(of: " them.", with: " her.")
                clinicalText = clinicalText.replacingOccurrences(of: " they ", with: " she ")
                clinicalText = clinicalText.replacingOccurrences(of: "They ", with: "She ")
            }
        }

        // Put clinical text in paragraph 22 and clear overflow paragraphs
        exporter.fillBracketContent(at: 22, content: clinicalText)
        exporter.setFontArial(at: 22)
        // Clear overflow whitespace paragraphs
        exporter.removePermissionMarkers(at: 23)
        exporter.removePermissionMarkers(at: 24)

        // Collapse paragraph 25 (the duplicate "If you need to continue" line without checkbox)
        exporter.collapseParagraph(at: 25)

        // Format paragraph 26 with checkbox
        exporter.setIndicateHereCheckbox(at: 26)
        exporter.setFontArial(at: 26)

        // Signature line at 27
        let sigDate = dateFormatter.string(from: formData.signatureDate)
        exporter.fillSignatureLineNoBold(at: 27, dateContent: sigDate)

        return exporter.generateDOCX()
    }
}

// MARK: Generic placeholder exporters for other forms

class A3FormDOCXExporter {
    private let formData: A3FormData

    init(formData: A3FormData) {
        self.formData = formData
    }

    func generateDOCX() -> Data? {
        let exporter = TemplateDOCXExporter(templateName: "Form_A3_template")
        guard exporter.loadTemplate() else { return nil }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy"

        // MARK: - Patient Details (paragraph 3)
        var patientText = formData.patientName
        if !formData.patientAddress.isEmpty {
            patientText += ", " + formData.patientAddress
        }
        exporter.fillBracketContent(at: 3, content: patientText, highlight: true, spacingAfter: 480)  // Blank line after

        // MARK: - First Practitioner (paragraph 6)
        var doc1Text = formData.doctor1Name
        if !formData.doctor1Address.isEmpty {
            doc1Text += ", " + formData.doctor1Address
        }
        exporter.fillBracketContent(at: 6, content: doc1Text, highlight: true)

        // MARK: - Exam 1 Date (paragraph 8)
        exporter.fillBracketContent(at: 8, content: dateFormatter.string(from: formData.doctor1ExaminationDate), highlight: true)

        // MARK: - Doctor 1 Previous Acquaintance & S12 (paragraphs 9-10) - bracket spans both lines
        exporter.removePermissionMarkers(at: 9)
        exporter.removePermissionMarkers(at: 10)
        exporter.applySpanningBracketStart(at: 9, content: "*I had previous acquaintance with the patient before I conducted that examination.")
        exporter.applySpanningBracketEnd(at: 10, content: "*I am approved under section 12 of the Act as having special experience in the diagnosis or treatment of mental disorder.")
        if formData.doctor1PreviousAcquaintance == .none {
            exporter.safeStrikethrough(at: 9)
        }
        if !formData.doctor1IsSection12Approved {
            exporter.safeStrikethrough(at: 10)
        }

        // MARK: - Second Practitioner (paragraph 13)
        var doc2Text = formData.doctor2Name
        if !formData.doctor2Address.isEmpty {
            doc2Text += ", " + formData.doctor2Address
        }
        exporter.fillBracketContent(at: 13, content: doc2Text, highlight: true)

        // MARK: - Exam 2 Date (paragraph 15)
        exporter.fillBracketContent(at: 15, content: dateFormatter.string(from: formData.doctor2ExaminationDate), highlight: true)

        // MARK: - Doctor 2 Previous Acquaintance & S12 (paragraphs 16-17) - bracket spans both lines
        exporter.removePermissionMarkers(at: 16)
        exporter.removePermissionMarkers(at: 17)
        exporter.applySpanningBracketStart(at: 16, content: "*I had previous acquaintance with the patient before I conducted that examination.")
        exporter.applySpanningBracketEnd(at: 17, content: "*I am approved under section 12 of the Act as having special experience in the diagnosis or treatment of mental disorder.")
        if formData.doctor2PreviousAcquaintance == .none {
            exporter.safeStrikethrough(at: 16)
        }
        if !formData.doctor2IsSection12Approved {
            exporter.safeStrikethrough(at: 17)
        }

        // MARK: - Detention Reasons (paragraphs 23, 24, 25) - bracket spans all three lines
        exporter.removePermissionMarkers(at: 23)
        exporter.removePermissionMarkers(at: 24)
        exporter.removePermissionMarkers(at: 25)
        exporter.applyDetentionReasonLine(at: 23, prefixNum: "(i)", bracketPosition: "start")
        exporter.applyDetentionReasonLine(at: 24, prefixNum: "(ii)", bracketPosition: "none")
        exporter.applyDetentionReasonLine(at: 25, prefixNum: "(iii)", bracketPosition: "end")
        // Strikethrough if not selected
        if !formData.clinicalReasons.healthEnabled {
            exporter.safeStrikethrough(at: 23)
        }
        if !formData.clinicalReasons.safetySelfEnabled {
            exporter.safeStrikethrough(at: 24)
        }
        if !formData.clinicalReasons.safetyOthersEnabled {
            exporter.safeStrikethrough(at: 25)
        }

        // MARK: - Clinical Reasons (paragraph 29)
        var clinicalText = ""
        if !formData.mentalDisorderDescription.isEmpty {
            clinicalText = formData.mentalDisorderDescription
        } else if !formData.clinicalReasons.displayText.isEmpty {
            clinicalText = formData.clinicalReasons.displayText
        } else if !formData.reasonsAssessmentNecessary.isEmpty {
            clinicalText = formData.reasonsAssessmentNecessary
        }

        // Replace "The patient" with actual patient name and demographics
        // Format: "John Doe is a 39 year old black African man"
        if !clinicalText.isEmpty && !formData.patientName.isEmpty {
            var patientDescription = formData.patientName
            if let age = formData.patientInfo.age {
                patientDescription += " is a \(age) year old"
            } else {
                patientDescription += " is a"
            }
            // Add ethnicity (lowercased) before gender noun
            if formData.patientInfo.ethnicity != .notSpecified {
                patientDescription += " \(formData.patientInfo.ethnicity.shortDescription.lowercased())"
            }
            // Add gender noun (man/woman/person) instead of male/female, plus "who" for grammar
            patientDescription += " \(formData.patientInfo.gender.genderNoun) who"
            clinicalText = clinicalText.replacingOccurrences(of: "The patient", with: patientDescription)
            clinicalText = clinicalText.replacingOccurrences(of: "the patient", with: patientDescription.lowercased())

            // Replace pronouns based on gender (order matters - longest matches first)
            let gender = formData.patientInfo.gender
            if gender == .male {
                clinicalText = clinicalText.replacingOccurrences(of: " themselves", with: " himself")
                clinicalText = clinicalText.replacingOccurrences(of: " their ", with: " his ")
                clinicalText = clinicalText.replacingOccurrences(of: " their,", with: " his,")
                clinicalText = clinicalText.replacingOccurrences(of: " their.", with: " his.")
                clinicalText = clinicalText.replacingOccurrences(of: "Their ", with: "His ")
                clinicalText = clinicalText.replacingOccurrences(of: " them ", with: " him ")
                clinicalText = clinicalText.replacingOccurrences(of: " them,", with: " him,")
                clinicalText = clinicalText.replacingOccurrences(of: " them.", with: " him.")
                clinicalText = clinicalText.replacingOccurrences(of: " they ", with: " he ")
                clinicalText = clinicalText.replacingOccurrences(of: "They ", with: "He ")
            } else if gender == .female {
                clinicalText = clinicalText.replacingOccurrences(of: " themselves", with: " herself")
                clinicalText = clinicalText.replacingOccurrences(of: " their ", with: " her ")
                clinicalText = clinicalText.replacingOccurrences(of: " their,", with: " her,")
                clinicalText = clinicalText.replacingOccurrences(of: " their.", with: " her.")
                clinicalText = clinicalText.replacingOccurrences(of: "Their ", with: "Her ")
                clinicalText = clinicalText.replacingOccurrences(of: " them ", with: " her ")
                clinicalText = clinicalText.replacingOccurrences(of: " them,", with: " her,")
                clinicalText = clinicalText.replacingOccurrences(of: " them.", with: " her.")
                clinicalText = clinicalText.replacingOccurrences(of: " they ", with: " she ")
                clinicalText = clinicalText.replacingOccurrences(of: "They ", with: "She ")
            }
        }

        exporter.fillBracketContent(at: 29, content: clinicalText, highlight: true)

        // MARK: - Indicate Here Checkbox (paragraph 31) - remove duplicates
        exporter.setIndicateHereCheckbox(at: 31)
        exporter.deleteParagraph(at: 32)  // Remove duplicate indicate here line
        // After deletion: indices shift down by 1

        // MARK: - Delete grey signature line and template NOTE (both now shifted)
        exporter.deleteParagraph(at: 32)  // Remove grey signature line (was 33)
        // After deletion: indices shift again
        exporter.deleteParagraph(at: 32)  // Remove template NOTE (was 34, then 33)
        // After deletion: first sig is now at 32, second at 33

        // MARK: - Signature Lines (both without bold)
        // First signature with extra spacing after for blank line
        exporter.fillSignatureLineNoBold(at: 32, dateContent: dateFormatter.string(from: formData.doctor1SignatureDate), spacingAfter: 480)
        exporter.fillSignatureLineNoBold(at: 33, dateContent: dateFormatter.string(from: formData.doctor2SignatureDate))

        // MARK: - Add NOTE at bottom (paragraph 34)
        exporter.addSection12Note(at: 34)

        return exporter.generateDOCX()
    }
}

class A6FormDOCXExporter {
    private let formData: A6FormData

    init(formData: A6FormData) {
        self.formData = formData
    }

    func generateDOCX() -> Data? {
        let exporter = TemplateDOCXExporter(templateName: "Form_A6_template")
        guard exporter.loadTemplate() else { return nil }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy"

        // MARK: - Hospital (paragraph 3)
        var hospitalText = formData.hospitalName
        if !formData.hospitalAddress.isEmpty {
            hospitalText += ", " + formData.hospitalAddress
        }
        exporter.fillBracketContent(at: 3, content: hospitalText)
        exporter.setFontArial(at: 3)

        // MARK: - AMHP Details (paragraph 5)
        var amhpText = formData.amhpName
        if !formData.amhpAddress.isEmpty {
            amhpText += ", " + formData.amhpAddress
        }
        if !formData.amhpEmail.isEmpty {
            amhpText += ", " + formData.amhpEmail
        }
        exporter.fillBracketContent(at: 5, content: amhpText)
        exporter.setFontArial(at: 5)

        // MARK: - Patient Details (paragraph 7)
        var patientText = formData.patientName
        if !formData.patientAddress.isEmpty {
            patientText += ", " + formData.patientAddress
        }
        exporter.fillBracketContent(at: 7, content: patientText)
        exporter.setFontArial(at: 7)

        // MARK: - Local Authority (paragraph 10)
        exporter.fillBracketContent(at: 10, content: formData.localAuthorityName)
        exporter.setFontArial(at: 10)

        // MARK: - Approved By (paragraphs 12-14)
        if formData.approvedBySameAuthority {
            // Same authority - highlight "that authority" (para 12) with brackets
            exporter.setParagraphText(at: 12, text: "that authority", highlight: true)
            exporter.setFontArial(at: 12)
            // Para 14 - fill with highlighted blank space (same size as bracket placeholder)
            exporter.fillBracketContent(at: 14, content: "                                                  ")
            exporter.setFontArial(at: 14)
        } else {
            // Different authority - only highlight and fill para 14
            exporter.fillBracketContent(at: 14, content: formData.approvedByDifferentAuthority)
            exporter.setFontArial(at: 14)
            exporter.highlightYellow(at: 14)
            // Para 12-13 not highlighted (unused option)
        }

        // MARK: - Nearest Relative Consultation (paragraphs 15-36)
        // Build NR text from name and address
        var nrText = formData.nrName
        if !formData.nrAddress.isEmpty {
            nrText += ", " + formData.nrAddress
        }

        if formData.nrWasConsulted {
            // === NR WAS CONSULTED ===
            let isOptionA = formData.nrIsNearestRelative

            if isOptionA {
                // Option (a): nearest relative
                // Para 17: "(a) I have consulted [PRINT...]" - opening GB (preserves template text)
                exporter.wrapWithOpeningBracket(at: 17)
                exporter.setFontArial(at: 17)
                // Para 18: Fill with NR name/address - highlight only, NO GB
                if nrText.isEmpty {
                    exporter.setParagraphTextHighlightOnly(at: 18, text: "")
                } else {
                    exporter.setParagraphTextHighlightOnly(at: 18, text: nrText)
                }
                exporter.setFontArial(at: 18)
                // Para 19: "who to the best of my knowledge..." - highlighted
                exporter.highlightYellow(at: 19)
                exporter.setFontArial(at: 19)
                // Option (b) - strikethrough (not selected)
                exporter.strikethrough(at: 20, withHighlight: true)
                exporter.strikethrough(at: 21, withHighlight: true)
                exporter.strikethrough(at: 22, withHighlight: true)
            } else {
                // Option (b): authorized person
                // Para 17-19: strikethrough option (a)
                exporter.strikethrough(at: 17, withHighlight: true)
                exporter.strikethrough(at: 18, withHighlight: true)
                exporter.strikethrough(at: 19, withHighlight: true)
                // Para 20: "(b) I have consulted [PRINT...]" - opening GB (preserves template text)
                exporter.wrapWithOpeningBracket(at: 20)
                exporter.setFontArial(at: 20)
                // Para 21: Fill with NR name/address - highlight only, NO GB (or empty placeholder)
                if nrText.isEmpty {
                    exporter.setParagraphTextHighlightOnly(at: 21, text: "")
                } else {
                    exporter.setParagraphTextHighlightOnly(at: 21, text: nrText)
                }
                exporter.setFontArial(at: 21)
                // Para 22: continuation - highlighted
                exporter.highlightYellow(at: 22)
                exporter.setFontArial(at: 22)
            }

            // Para 23: "That person has not notified me..." - closing GB (preserves template text)
            exporter.wrapWithClosingBracket(at: 23)
            exporter.setFontArial(at: 23)

            // "Not consulted" section - strikethrough with highlight (so it's clearly intentional)
            for i in 24...36 {
                if i == 33 {
                    // Para 33 needs special GB treatment even when struck through
                    exporter.setParagraphWithSelectiveGoldBracketStrikethrough(
                        at: 33,
                        beforeText: "but in my opinion it ",
                        bracketedText: "is not reasonably practicable/would involve unreasonable delay",
                        afterText: " <delete as appropriate> to consult that person before making this application, because —"
                    )
                } else {
                    exporter.strikethrough(at: i, withHighlight: true)
                }
            }
        } else {
            // === NR WAS NOT CONSULTED ===
            // Strikethrough the consulted section (paras 17-23)
            for i in 17...23 {
                exporter.strikethrough(at: i, withHighlight: true)
            }

            // Para 24: "Complete the following..." - NO highlight (just remove permission markers)
            exporter.removePermissionMarkers(at: 24)
            exporter.setFontArial(at: 24)

            // Handle based on ncReason
            switch formData.ncReason {
            case .notKnown:
                // (a) Unable to ascertain - keep para 25, strikethrough rest with highlight
                exporter.applyA6NotConsultedFormatting(at: 25, isOpeningBracket: true, isClosingBracket: true)
                // Strikethrough (b) and (c) sections with highlight
                for i in 26...36 {
                    if i == 33 {
                        // Para 33 needs special GB treatment even when struck through
                        exporter.setParagraphWithSelectiveGoldBracketStrikethrough(
                            at: 33,
                            beforeText: "but in my opinion it ",
                            bracketedText: "is not reasonably practicable/would involve unreasonable delay",
                            afterText: " <delete as appropriate> to consult that person before making this application, because —"
                        )
                    } else {
                        exporter.strikethrough(at: i, withHighlight: true)
                    }
                }

            case .noNR:
                // (b) No nearest relative - strikethrough (a), keep para 26, strikethrough rest
                exporter.strikethrough(at: 25, withHighlight: true)
                exporter.applyA6NotConsultedFormatting(at: 26, isOpeningBracket: true, isClosingBracket: true)
                // Strikethrough (c) section with highlight
                for i in 27...36 {
                    if i == 33 {
                        // Para 33 needs special GB treatment even when struck through
                        exporter.setParagraphWithSelectiveGoldBracketStrikethrough(
                            at: 33,
                            beforeText: "but in my opinion it ",
                            bracketedText: "is not reasonably practicable/would involve unreasonable delay",
                            afterText: " <delete as appropriate> to consult that person before making this application, because —"
                        )
                    } else {
                        exporter.strikethrough(at: i, withHighlight: true)
                    }
                }

            case .knownButCouldNot:
                // (c) Known but couldn't consult
                // Strikethrough (a) and (b)
                exporter.strikethrough(at: 25, withHighlight: true)
                exporter.strikethrough(at: 26, withHighlight: true)

                // Para 27: "(c) I understand that..." - opening GB
                exporter.applyA6NotConsultedFormatting(at: 27, isOpeningBracket: true, isClosingBracket: false)

                // Para 28: NR name/address placeholder - highlight only
                if nrText.isEmpty {
                    exporter.setParagraphTextHighlightOnly(at: 28, text: "")
                } else {
                    exporter.setParagraphTextHighlightOnly(at: 28, text: nrText)
                }
                exporter.setFontArial(at: 28)

                // Para 29: "is" - highlighted
                exporter.applyA6NotConsultedFormatting(at: 29, isOpeningBracket: false, isClosingBracket: false)

                // Strikethrough non-selected (i) or (ii) based on nrIsNearestRelative
                if formData.nrIsNearestRelative {
                    // (i) is the patient's nearest relative - keep 30, strikethrough 31
                    exporter.applyA6NotConsultedFormatting(at: 30, isOpeningBracket: false, isClosingBracket: false)
                    exporter.strikethrough(at: 31, withHighlight: true)
                } else {
                    // (ii) authorised - strikethrough 30, keep 31
                    exporter.strikethrough(at: 30, withHighlight: true)
                    exporter.applyA6NotConsultedFormatting(at: 31, isOpeningBracket: false, isClosingBracket: false)
                }

                // Para 32: "<Delete either (i) or (ii)>" - strikethrough instruction with highlight
                exporter.strikethrough(at: 32, withHighlight: true)

                // Para 33: "but in my opinion it [is not reasonably practicable/would involve unreasonable delay]..."
                // Determine which option based on ncDelayReason
                let delayText = formData.ncDelayReason == .notPracticable
                    ? "is not reasonably practicable"
                    : "would involve unreasonable delay"
                exporter.setParagraphWithSelectiveGoldBracket(
                    at: 33,
                    beforeText: "but in my opinion it ",
                    bracketedText: delayText,
                    afterText: " to consult that person before making this application, because —"
                )
                exporter.setFontArial(at: 33)

                // Para 34: Reason for not consulting - GB highlighted placeholder with closing bracket
                exporter.fillBracketContent(at: 34, content: formData.ncReasonText)
                exporter.setFontArial(at: 34)

                // Clear blank lines after reason (para 35-36 if they exist as spacers)
                exporter.clearParagraph(at: 35)
                exporter.clearParagraph(at: 36)
            }
        }

        // Paragraph 37: "[If you need to continue... indicate here [ ] and attach...]"
        // Inner checkbox [ ] needs gold brackets with cream highlight
        exporter.setIndicateHereCheckbox(at: 37)
        exporter.setFontArial(at: 37)

        // MARK: - Interview & Last Seen (paragraph 40)
        let lastSeenDate = dateFormatter.string(from: formData.interviewDate)
        exporter.fillBracketContent(at: 40, content: lastSeenDate)
        exporter.setFontArial(at: 40)

        // MARK: - No Acquaintance Reason (paragraph 45)

        // Paragraph 45: Reason if neither practitioner had previous acquaintance
        exporter.fillBracketContent(at: 45, content: formData.noAcquaintanceReason)
        exporter.setFontArial(at: 45)

        // Paragraph 46: "[If you need to continue... indicate here [ ] and attach...]"
        // Inner checkbox [ ] needs gold brackets with cream highlight
        exporter.setIndicateHereCheckbox(at: 46)
        exporter.setFontArial(at: 46)

        // Paragraphs 47-48: Remove duplicate "indicate here" lines from template
        exporter.clearParagraph(at: 47)
        exporter.clearParagraph(at: 48)

        // MARK: - Signature (paragraph 49)

        // Paragraph 49: Signature line - "Signed" and "Date" NOT highlighted, only bracket contents highlighted
        let sigDate = dateFormatter.string(from: formData.signatureDate)
        exporter.setSignatureWithSelectiveHighlight(at: 49, signatureContent: "", dateContent: sigDate)
        exporter.setFontArial(at: 49)

        return exporter.generateDOCX()
    }
}

class A7FormDOCXExporter {
    private let formData: A7FormData

    init(formData: A7FormData) {
        self.formData = formData
    }

    func generateDOCX() -> Data? {
        let exporter = TemplateDOCXExporter(templateName: "Form_A7_template")
        guard exporter.loadTemplate() else { return nil }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy"

        // Paragraph 3: Patient name and address (whitespace field - use setParagraphText)
        var patientText = formData.patientName
        if !formData.patientAddress.isEmpty {
            patientText += ", " + formData.patientAddress
        }
        exporter.setParagraphText(at: 3, text: patientText, highlight: true)
        exporter.setFontArial(at: 3)

        // MARK: - First Practitioner

        // Paragraph 6: First practitioner name, address, email (whitespace field - use setParagraphText)
        var doctor1Text = formData.doctor1Name
        if !formData.doctor1Address.isEmpty {
            doctor1Text += ", " + formData.doctor1Address
        }
        if !formData.doctor1Email.isEmpty {
            doctor1Text += ", " + formData.doctor1Email
        }
        exporter.setParagraphText(at: 6, text: doctor1Text, highlight: true)
        exporter.setFontArial(at: 6)

        // Paragraph 8: First practitioner examination date (whitespace field after "last examined...")
        let exam1Date = dateFormatter.string(from: formData.doctor1ExaminationDate)
        exporter.setParagraphText(at: 8, text: exam1Date, highlight: true)
        exporter.setFontArial(at: 8)

        // Paragraphs 9-10: First practitioner previous acquaintance and S12
        // Always apply highlight to match template, strikethrough only if not applicable
        if !formData.doctor1HasPreviousAcquaintance {
            exporter.strikethrough(at: 9, withHighlight: true) // Strike "had previous acquaintance"
        } else {
            exporter.highlightYellow(at: 9)
        }
        if !formData.doctor1IsSection12Approved {
            exporter.strikethrough(at: 10, withHighlight: true) // Strike S12 approved
        } else {
            exporter.highlightYellow(at: 10)
        }

        // MARK: - Second Practitioner

        // Paragraph 13: Second practitioner name, address, email (whitespace field - use setParagraphText)
        var doctor2Text = formData.doctor2Name
        if !formData.doctor2Address.isEmpty {
            doctor2Text += ", " + formData.doctor2Address
        }
        if !formData.doctor2Email.isEmpty {
            doctor2Text += ", " + formData.doctor2Email
        }
        exporter.setParagraphText(at: 13, text: doctor2Text, highlight: true)
        exporter.setFontArial(at: 13)

        // Paragraph 15: Second practitioner examination date (whitespace field after "last examined...")
        let exam2Date = dateFormatter.string(from: formData.doctor2ExaminationDate)
        exporter.setParagraphText(at: 15, text: exam2Date, highlight: true)
        exporter.setFontArial(at: 15)

        // Paragraphs 16-17: Second practitioner previous acquaintance and S12
        // Always apply highlight to match template, strikethrough only if not applicable
        if !formData.doctor2HasPreviousAcquaintance {
            exporter.strikethrough(at: 16, withHighlight: true)
        } else {
            exporter.highlightYellow(at: 16)
        }
        if !formData.doctor2IsSection12Approved {
            exporter.strikethrough(at: 17, withHighlight: true)
        } else {
            exporter.highlightYellow(at: 17)
        }

        // MARK: - Detention Reasons (paragraphs 23-25) with golden brackets
        // Para 23 gets opening bracket [, para 25 gets closing bracket ]
        // Prefix (i), (ii), (iii) stays unhighlighted, content gets cream highlight
        let healthStrike = !formData.clinicalReasons.healthEnabled
        let safetyStrike = !formData.clinicalReasons.safetyEnabled || !formData.clinicalReasons.safetySelfEnabled
        let othersStrike = !formData.clinicalReasons.safetyEnabled || !formData.clinicalReasons.safetyOthersEnabled

        exporter.setDetentionReasonWithOpeningBracket(at: 23, withStrikethrough: healthStrike)
        exporter.setDetentionReasonWithCreamHighlightOnly(at: 24, withStrikethrough: safetyStrike)
        exporter.setDetentionReasonWithClosingBracket(at: 25, withStrikethrough: othersStrike)

        // MARK: - Clinical Reasons (paragraph 30 - whitespace field after "because" instruction at 29)
        var clinicalText = ""
        if !formData.mentalDisorderDescription.isEmpty {
            clinicalText = formData.mentalDisorderDescription
        } else if !formData.clinicalReasons.generatedText.isEmpty {
            clinicalText = formData.clinicalReasons.generatedText
        }

        // Replace "The patient" with actual patient name and demographics
        // Format: "John Doe is a 39 year old black African man"
        if !clinicalText.isEmpty && !formData.patientName.isEmpty {
            var patientDescription = formData.patientName
            patientDescription += " is a \(formData.patientAge) year old"
            // Add ethnicity (lowercased) before gender noun
            if formData.patientInfo.ethnicity != .notSpecified {
                patientDescription += " \(formData.patientInfo.ethnicity.shortDescription.lowercased())"
            }
            // Add gender noun (man/woman/person) instead of male/female, plus "who" for grammar
            patientDescription += " \(formData.patientInfo.gender.genderNoun) who"
            clinicalText = clinicalText.replacingOccurrences(of: "The patient", with: patientDescription)
            clinicalText = clinicalText.replacingOccurrences(of: "the patient", with: patientDescription.lowercased())

            // Replace pronouns based on gender (order matters - longest matches first)
            let gender = formData.patientInfo.gender
            if gender == .male {
                clinicalText = clinicalText.replacingOccurrences(of: " themselves", with: " himself")
                clinicalText = clinicalText.replacingOccurrences(of: " their ", with: " his ")
                clinicalText = clinicalText.replacingOccurrences(of: " their,", with: " his,")
                clinicalText = clinicalText.replacingOccurrences(of: " their.", with: " his.")
                clinicalText = clinicalText.replacingOccurrences(of: "Their ", with: "His ")
                clinicalText = clinicalText.replacingOccurrences(of: " them ", with: " him ")
                clinicalText = clinicalText.replacingOccurrences(of: " them,", with: " him,")
                clinicalText = clinicalText.replacingOccurrences(of: " them.", with: " him.")
                clinicalText = clinicalText.replacingOccurrences(of: " they ", with: " he ")
                clinicalText = clinicalText.replacingOccurrences(of: "They ", with: "He ")
            } else if gender == .female {
                clinicalText = clinicalText.replacingOccurrences(of: " themselves", with: " herself")
                clinicalText = clinicalText.replacingOccurrences(of: " their ", with: " her ")
                clinicalText = clinicalText.replacingOccurrences(of: " their,", with: " her,")
                clinicalText = clinicalText.replacingOccurrences(of: " their.", with: " her.")
                clinicalText = clinicalText.replacingOccurrences(of: "Their ", with: "Her ")
                clinicalText = clinicalText.replacingOccurrences(of: " them ", with: " her ")
                clinicalText = clinicalText.replacingOccurrences(of: " them,", with: " her,")
                clinicalText = clinicalText.replacingOccurrences(of: " them.", with: " her.")
                clinicalText = clinicalText.replacingOccurrences(of: " they ", with: " she ")
                clinicalText = clinicalText.replacingOccurrences(of: "They ", with: "She ")
            }
        }

        exporter.setParagraphText(at: 30, text: clinicalText, highlight: true)
        exporter.setFontArial(at: 30)
        if clinicalText.isEmpty {
            exporter.highlightYellow(at: 30)
        }

        // Keep paragraph 31 as single blank line, collapse 32-33 to zero height
        exporter.clearParagraph(at: 31)
        exporter.collapseParagraph(at: 32)
        exporter.collapseParagraph(at: 33)

        // Paragraph 34: "[If you need to continue...]" - format with gold brackets checkbox (same as A3)
        exporter.setIndicateHereCheckbox(at: 34)

        // Paragraph 35: "We are also of the opinion..." (static text, leave alone)
        // Paragraph 36: "[Enter name of hospital(s)...]" (instruction, leave alone)

        // Paragraph 37: Treatment hospital whitespace (with gold brackets)
        exporter.setParagraphText(at: 37, text: formData.treatmentHospital, highlight: true)
        exporter.setFontArial(at: 37)

        // Collapse unused whitespace paragraphs before signatures (38-39)
        exporter.collapseParagraph(at: 38)
        exporter.collapseParagraph(at: 39)

        // MARK: - Signatures (same format as A3 - gold brackets with dates)
        let sig1Date = dateFormatter.string(from: formData.doctor1SignatureDate)
        exporter.fillSignatureLineNoBold(at: 40, dateContent: sig1Date, spacingAfter: 360)

        let sig2Date = dateFormatter.string(from: formData.doctor2SignatureDate)
        exporter.fillSignatureLineNoBold(at: 41, dateContent: sig2Date, spacingAfter: 120)

        // NOTE paragraph - Arial 14.5pt bold
        exporter.addSection12Note(at: 42)

        return exporter.generateDOCX()
    }
}

class A8FormDOCXExporter {
    private let formData: A8FormData

    init(formData: A8FormData) {
        self.formData = formData
    }

    func generateDOCX() -> Data? {
        let exporter = TemplateDOCXExporter(templateName: "Form_A8_template")
        guard exporter.loadTemplate() else { return nil }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy"

        // Paragraph 3: Doctor name and address (whitespace field after label)
        var doctorText = formData.doctorName
        if !formData.doctorAddress.isEmpty {
            doctorText += ", " + formData.doctorAddress
        }
        exporter.setParagraphText(at: 3, text: doctorText, highlight: true)
        exporter.setFontArial(at: 3)

        // Paragraph 5: Patient name and address (whitespace field after label)
        var patientText = formData.patientName
        if !formData.patientAddress.isEmpty {
            patientText += ", " + formData.patientAddress
        }
        exporter.setParagraphText(at: 5, text: patientText, highlight: true)
        exporter.setFontArial(at: 5)

        // Paragraph 8: Examination date (whitespace field after label)
        let examDate = dateFormatter.string(from: formData.examinationDate)
        exporter.setParagraphText(at: 8, text: examDate, highlight: true)
        exporter.setFontArial(at: 8)

        // Paragraphs 9-10: Previous acquaintance & S12 - gold bracket spans both lines (same as A3)
        exporter.removePermissionMarkers(at: 9)
        exporter.removePermissionMarkers(at: 10)
        exporter.applySpanningBracketStart(at: 9, content: "*I had previous acquaintance with the patient before I conducted that examination.")
        exporter.applySpanningBracketEnd(at: 10, content: "*I am approved under section 12 of the Act as having special experience in the diagnosis or treatment of mental disorder.")
        if !formData.hasPreviousAcquaintance {
            exporter.safeStrikethrough(at: 9)
        }
        if !formData.isSection12Approved {
            exporter.safeStrikethrough(at: 10)
        }

        // MARK: - Detention Reasons (paragraphs 16-18) with golden brackets
        // Para 16 gets opening bracket [, para 18 gets closing bracket ]
        // Prefix (i), (ii), (iii) stays unhighlighted, content gets cream highlight
        let healthStrike = !formData.clinicalReasons.healthEnabled
        let safetyStrike = !formData.clinicalReasons.safetyEnabled || !formData.clinicalReasons.safetySelfEnabled
        let othersStrike = !formData.clinicalReasons.safetyEnabled || !formData.clinicalReasons.safetyOthersEnabled

        exporter.setDetentionReasonWithOpeningBracket(at: 16, withStrikethrough: healthStrike)
        exporter.setDetentionReasonWithCreamHighlightOnly(at: 17, withStrikethrough: safetyStrike)
        exporter.setDetentionReasonWithClosingBracket(at: 18, withStrikethrough: othersStrike)

        // MARK: - Clinical Reasons (paragraph 23 - instruction with brackets)
        var clinicalText = ""
        if !formData.mentalDisorderDescription.isEmpty {
            clinicalText = formData.mentalDisorderDescription
        } else if !formData.clinicalReasons.generatedText.isEmpty {
            clinicalText = formData.clinicalReasons.generatedText
        }

        // Replace "The patient" with actual patient name and demographics
        // Format: "John Doe is a 39 year old black African man"
        if !clinicalText.isEmpty && !formData.patientName.isEmpty {
            var patientDescription = formData.patientName
            if let age = formData.patientInfo.age {
                patientDescription += " is a \(age) year old"
            } else {
                patientDescription += " is a"
            }
            // Add ethnicity (lowercased) before gender noun
            if formData.patientInfo.ethnicity != .notSpecified {
                patientDescription += " \(formData.patientInfo.ethnicity.shortDescription.lowercased())"
            }
            // Add gender noun (man/woman/person) instead of male/female, plus "who" for grammar
            patientDescription += " \(formData.patientInfo.gender.genderNoun) who"
            clinicalText = clinicalText.replacingOccurrences(of: "The patient", with: patientDescription)
            clinicalText = clinicalText.replacingOccurrences(of: "the patient", with: patientDescription.lowercased())

            // Replace pronouns based on gender
            let gender = formData.patientInfo.gender
            if gender == .male {
                clinicalText = clinicalText.replacingOccurrences(of: " themselves", with: " himself")
                clinicalText = clinicalText.replacingOccurrences(of: " their ", with: " his ")
                clinicalText = clinicalText.replacingOccurrences(of: " their,", with: " his,")
                clinicalText = clinicalText.replacingOccurrences(of: " their.", with: " his.")
                clinicalText = clinicalText.replacingOccurrences(of: "Their ", with: "His ")
                clinicalText = clinicalText.replacingOccurrences(of: " them ", with: " him ")
                clinicalText = clinicalText.replacingOccurrences(of: " them,", with: " him,")
                clinicalText = clinicalText.replacingOccurrences(of: " them.", with: " him.")
                clinicalText = clinicalText.replacingOccurrences(of: " they ", with: " he ")
                clinicalText = clinicalText.replacingOccurrences(of: "They ", with: "He ")
            } else if gender == .female {
                clinicalText = clinicalText.replacingOccurrences(of: " themselves", with: " herself")
                clinicalText = clinicalText.replacingOccurrences(of: " their ", with: " her ")
                clinicalText = clinicalText.replacingOccurrences(of: " their,", with: " her,")
                clinicalText = clinicalText.replacingOccurrences(of: " their.", with: " her.")
                clinicalText = clinicalText.replacingOccurrences(of: "Their ", with: "Her ")
                clinicalText = clinicalText.replacingOccurrences(of: " them ", with: " her ")
                clinicalText = clinicalText.replacingOccurrences(of: " them,", with: " her,")
                clinicalText = clinicalText.replacingOccurrences(of: " them.", with: " her.")
                clinicalText = clinicalText.replacingOccurrences(of: " they ", with: " she ")
                clinicalText = clinicalText.replacingOccurrences(of: "They ", with: "She ")
            }
        }

        // Paragraph 24: Clinical text (whitespace field after label at 23)
        exporter.setParagraphText(at: 24, text: clinicalText, highlight: true)
        exporter.setFontArial(at: 24)
        // Clear overflow whitespace paragraphs
        exporter.removePermissionMarkers(at: 25)
        exporter.removePermissionMarkers(at: 26)

        // Paragraph 27: "[If you need to continue... indicate here [ ] and attach...]"
        exporter.setIndicateHereCheckbox(at: 27)
        exporter.setFontArial(at: 27)

        // MARK: - Hospital Name (paragraph 29 - whitespace field after "available to the patient at the following hospital")
        exporter.setParagraphText(at: 29, text: formData.hospitalName, highlight: true)
        exporter.setFontArial(at: 29)
        // Clear overflow paragraphs 30-31
        exporter.removePermissionMarkers(at: 30)
        exporter.removePermissionMarkers(at: 31)

        // MARK: - Signature (paragraph 34) - gold brackets with cream highlight
        let sigDate = dateFormatter.string(from: formData.signatureDate)
        exporter.fillSignatureLineNoBold(at: 34, dateContent: sigDate)

        return exporter.generateDOCX()
    }
}

class H1FormDOCXExporter {
    private let formData: H1FormData

    init(formData: H1FormData) {
        self.formData = formData
    }

    func generateDOCX() -> Data? {
        let exporter = TemplateDOCXExporter(templateName: "Form_H1_template")
        guard exporter.loadTemplate() else { return nil }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy"

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        // MARK: - Hospital (paragraph 5 - whitespace field after label at 4)
        exporter.setParagraphText(at: 5, text: formData.hospitalName, highlight: true)
        exporter.setFontArial(at: 5)

        // MARK: - Doctor Name (paragraph 7 - whitespace field after label at 6)
        exporter.setParagraphText(at: 7, text: formData.doctorName, highlight: true)
        exporter.setFontArial(at: 7)

        // MARK: - Doctor Status (paragraphs 9-10)
        // Para 9: RC/AC option, Para 10: Nominated deputy option
        switch formData.doctorStatus {
        case .rcOrAc:
            exporter.highlightYellow(at: 9)
            exporter.strikethrough(at: 10, withHighlight: true)
        case .nominatedDeputy:
            exporter.strikethrough(at: 9, withHighlight: true)
            exporter.highlightYellow(at: 10)
        }

        // MARK: - Patient Name (paragraph 12 - whitespace field after label at 11)
        exporter.setParagraphText(at: 12, text: formData.patientName, highlight: true)
        exporter.setFontArial(at: 12)

        // MARK: - Reasons for Holding (paragraph 15 - whitespace field)
        // Build complete patient info for text generation
        var patientInfoForText = formData.patientInfo
        // Parse patient name into first/last
        let nameParts = formData.patientName.components(separatedBy: " ")
        patientInfoForText.firstName = nameParts.first ?? ""
        patientInfoForText.lastName = nameParts.dropFirst().joined(separator: " ")
        patientInfoForText.manualAge = formData.patientAge

        // Use patient-specific text generation for proper demographics and pronouns
        var reasonsText = ""
        let patientSpecificText = formData.h1Reasons.generateTextWithPatient(patientInfoForText)
        if !patientSpecificText.isEmpty {
            reasonsText = patientSpecificText
        } else if !formData.h1Reasons.generatedText.isEmpty {
            reasonsText = formData.h1Reasons.generatedText
        } else if !formData.reasonsForHolding.isEmpty {
            reasonsText = formData.reasonsForHolding
        }
        exporter.setParagraphText(at: 15, text: reasonsText, highlight: true)
        exporter.setFontArial(at: 15)
        // Clear overflow paragraphs 16-17
        exporter.removePermissionMarkers(at: 16)
        exporter.removePermissionMarkers(at: 17)

        // MARK: - Delivery Method (paragraphs 20-22) with golden brackets
        // Para 20: internal mail with opening bracket and time, Para 21: electronic, Para 22: hand delivery with closing bracket
        let deliveryTime = timeFormatter.string(from: formData.deliveryDate)
        let internalMailStrike = formData.deliveryMethod != .internalMail
        let electronicStrike = formData.deliveryMethod != .electronic
        let handDeliveryStrike = formData.deliveryMethod != .handDelivery

        exporter.setH1DeliveryOptionWithOpeningBracket(at: 20, timeValue: deliveryTime, withStrikethrough: internalMailStrike)
        exporter.setH1DeliveryOptionMiddle(at: 21, withStrikethrough: electronicStrike)
        exporter.setH1DeliveryOptionWithClosingBracket(at: 22, withStrikethrough: handDeliveryStrike)

        // MARK: - Signature (paragraph 23) - cream highlight with gold brackets
        let sigDate = dateFormatter.string(from: formData.signatureDate)
        exporter.setSignatureWithCreamHighlight(at: 23, signatureContent: "", dateContent: sigDate)
        exporter.setFontArial(at: 23)

        // MARK: - Part 2 (paragraphs 24-33) - Hospital managers section
        // Template shows opening "[" on para 27, all options highlighted, closing "]" on para 31

        // Para 27: "[furnished to the hospital managers through their internal mail system" (opening bracket, NO closing) - cream highlight
        exporter.setTextWithOpeningBracketHighlighted(at: 27, text: "furnished to the hospital managers through their internal mail system")

        // Para 28: "furnished to the hospital managers...electronic communication" - yellow highlight
        exporter.highlightYellow(at: 28)

        // Para 29: "delivered to me in person...at [time]" - yellow highlight
        exporter.highlightYellow(at: 29)

        // Para 30: "on [date]" - yellow highlight
        exporter.highlightYellow(at: 30)

        // Para 31: Just the closing "]" with yellow highlight
        exporter.setClosingBracketLine(at: 31)
        exporter.setFontArial(at: 31)

        // Para 32: "Signed [    ] on behalf of the hospital managers" - cream highlight with gold brackets
        exporter.fillSignedWithSuffixLineHighlighted(at: 32, signatureContent: "", suffix: "on behalf of the hospital managers")
        exporter.setLineSpacing15(at: 32)

        // Para 33: "PRINT NAME [    ] Date [    ]" - cream highlight with gold brackets
        exporter.fillPrintNameDateLineHighlighted(at: 33, nameContent: "", dateContent: "")
        exporter.setLineSpacing15(at: 33)

        return exporter.generateDOCX()
    }
}

class H5FormDOCXExporter {
    private let formData: H5FormData

    init(formData: H5FormData) {
        self.formData = formData
    }

    func generateDOCX() -> Data? {
        let exporter = TemplateDOCXExporter(templateName: "Form_H5_template")
        guard exporter.loadTemplate() else { return nil }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy"

        // ═══════════════════════════════════════════════════════════════════
        // PART 1 - To be completed by the responsible clinician
        // ═══════════════════════════════════════════════════════════════════

        // MARK: - Hospital (paragraph 5 - whitespace field after label at 4)
        var hospitalText = formData.hospitalName
        if !formData.hospitalAddress.isEmpty {
            hospitalText += ", " + formData.hospitalAddress
        }
        exporter.setParagraphText(at: 5, text: hospitalText, highlight: true)
        exporter.setFontArial(at: 5)

        // MARK: - Patient Name (paragraph 7 - whitespace field after label at 6)
        exporter.setParagraphText(at: 7, text: formData.patientName, highlight: true)
        exporter.setFontArial(at: 7)

        // MARK: - Examination Date (paragraph 9 - whitespace field after label at 8)
        let examDate = dateFormatter.string(from: formData.examinationDate)
        exporter.setParagraphText(at: 9, text: examDate, highlight: true)
        exporter.setFontArial(at: 9)

        // MARK: - Detention Expiry Date (paragraph 11 - whitespace field after label at 10)
        let expiryDate = dateFormatter.string(from: formData.detentionExpiryDate)
        exporter.setParagraphText(at: 11, text: expiryDate, highlight: true)
        exporter.setFontArial(at: 11)

        // MARK: - Consulted Person (paragraph 13 - whitespace field after label at 12)
        var consultedText = formData.professionalConsulted
        if !formData.consulteeEmail.isEmpty {
            consultedText += ", " + formData.consulteeEmail
        }
        if !formData.professionOfConsultee.isEmpty {
            consultedText += " (" + formData.professionOfConsultee + ")"
        }
        exporter.setParagraphText(at: 13, text: consultedText, highlight: true)
        exporter.setFontArial(at: 13)
        // Clear permission marker on continuation line
        exporter.removePermissionMarkers(at: 14)

        // MARK: - Detention Reasons (paragraphs 19-21) - gold brackets spanning all three, strikethrough non-applicable
        let healthStrike = !formData.clinicalReasons.healthEnabled
        let safetyStrike = !formData.clinicalReasons.safetyEnabled || !formData.clinicalReasons.safetySelfEnabled
        let othersStrike = !formData.clinicalReasons.safetyEnabled || !formData.clinicalReasons.safetyOthersEnabled

        exporter.setDetentionReasonWithOpeningBracket(at: 19, withStrikethrough: healthStrike)
        exporter.setDetentionReasonWithCreamHighlightOnly(at: 20, withStrikethrough: safetyStrike)
        exporter.setDetentionReasonWithClosingBracket(at: 21, withStrikethrough: othersStrike)
        // Clear "delete the indents" note
        exporter.removePermissionMarkers(at: 22)

        // MARK: - Clinical Reasons (paragraph 25 - whitespace field after label at 24)
        // Build complete patient info for text generation
        var patientInfoForText = formData.patientInfo
        let nameParts = formData.patientName.components(separatedBy: " ")
        patientInfoForText.firstName = nameParts.first ?? ""
        patientInfoForText.lastName = nameParts.dropFirst().joined(separator: " ")
        patientInfoForText.manualAge = formData.patientAge  // Use manually entered age for H5

        // Use patient-specific text generation for proper demographics and pronouns
        var clinicalText = formData.clinicalReasons.generateTextWithPatient(patientInfoForText)
        if clinicalText.isEmpty {
            clinicalText = formData.clinicalReasons.generatedText
        }
        if clinicalText.isEmpty && !formData.mentalDisorderDescription.isEmpty {
            clinicalText = formData.mentalDisorderDescription
        }
        exporter.setParagraphText(at: 25, text: clinicalText, highlight: true)
        exporter.setFontArial(at: 25)
        // Clear overflow paragraphs 27-28
        exporter.removePermissionMarkers(at: 27)
        exporter.removePermissionMarkers(at: 28)

        // MARK: - Cannot Be Provided Reasons (paragraph 30 - whitespace field after label at 29)
        exporter.setParagraphText(at: 30, text: formData.cannotBeProvidedWithoutDetention, highlight: true)
        exporter.setFontArial(at: 30)
        // Clear overflow paragraphs 32-33
        exporter.removePermissionMarkers(at: 32)
        exporter.removePermissionMarkers(at: 33)

        // MARK: - Part 1 Signature line (paragraph 36) - "Signed [ ] PRINT NAME [RC name]" - cream highlight with gold brackets
        exporter.setSignedPrintNameLineHighlighted(at: 36, signatureContent: "", nameContent: formData.rcName)

        // MARK: - Part 1 Profession and Date (paragraph 37) - "Profession [profession] Date [date]" - cream highlight with gold brackets
        let sigDate = dateFormatter.string(from: formData.signatureDate)
        exporter.setProfessionDateLineHighlighted(at: 37, professionContent: formData.rcProfession, dateContent: sigDate)

        // ═══════════════════════════════════════════════════════════════════
        // PART 2 - To be completed by a professional who has been professionally
        //          concerned with the patient's medical treatment
        // ═══════════════════════════════════════════════════════════════════

        // MARK: - Part 2 Signature line (paragraph 41) - "Signed [    ] PRINT NAME [consultee name]" - cream highlight
        // Consultee fills this - we pre-fill their print name
        exporter.setSignedPrintNameLineHighlighted(at: 41, signatureContent: "", nameContent: formData.professionalConsulted)

        // MARK: - Part 2 Profession/Date line (paragraph 42) - "Profession [profession] Date [date]" - cream highlight
        let consultationDateStr = dateFormatter.string(from: formData.consultationDate)
        exporter.setProfessionDateLineHighlighted(at: 42, professionContent: formData.professionOfConsultee, dateContent: consultationDateStr)

        // ═══════════════════════════════════════════════════════════════════
        // PART 3 - To be completed by the responsible clinician (Delivery)
        // ═══════════════════════════════════════════════════════════════════

        // MARK: - Delivery Method (paragraphs 46-48) with golden brackets
        // Para 46 always gets opening bracket [, para 48 always gets closing bracket ]
        // Selected option gets cream highlight, non-selected get strikethrough
        switch formData.deliveryMethod {
        case .internalMail:
            exporter.setExistingTextWithOpeningBracketHighlighted(at: 46, withStrikethrough: false)
            exporter.setExistingTextWithCreamHighlightOnly(at: 47, withStrikethrough: true)
            exporter.setExistingTextWithClosingBracketHighlighted(at: 48, withStrikethrough: true)
        case .electronic:
            exporter.setExistingTextWithOpeningBracketHighlighted(at: 46, withStrikethrough: true)
            exporter.setExistingTextWithCreamHighlightOnly(at: 47, withStrikethrough: false)
            exporter.setExistingTextWithClosingBracketHighlighted(at: 48, withStrikethrough: true)
        case .handDelivery:
            exporter.setExistingTextWithOpeningBracketHighlighted(at: 46, withStrikethrough: true)
            exporter.setExistingTextWithCreamHighlightOnly(at: 47, withStrikethrough: true)
            exporter.setExistingTextWithClosingBracketHighlighted(at: 48, withStrikethrough: false)
        }

        // MARK: - Part 3 Signature (paragraph 49) - "Signed [    ]" - cream highlight
        exporter.setSignedOnlyLineHighlighted(at: 49, signatureContent: "")

        // MARK: - Part 3 Print Name/Date (paragraph 50) - "PRINT NAME [RC name] Date [delivery date]" - cream highlight
        let deliveryDateStr = dateFormatter.string(from: formData.deliveryDate)
        exporter.fillPrintNameDateLineHighlighted(at: 50, nameContent: formData.rcName, dateContent: deliveryDateStr)

        // ═══════════════════════════════════════════════════════════════════
        // PART 4 - To be completed on behalf of the hospital managers
        // ═══════════════════════════════════════════════════════════════════

        // MARK: - Part 4 delivery options (paragraphs 54-57)
        // Opening bracket on first line, all options highlighted, closing bracket on separate line
        exporter.setTextWithOpeningBracketHighlighted(at: 54, text: "furnished to the hospital managers through their internal mail system")
        exporter.highlightYellow(at: 55)  // "furnished...by means of electronic communication"
        exporter.highlightYellow(at: 56)  // "received by me on behalf of the hospital managers on [date]"
        exporter.setClosingBracketLine(at: 57)  // Closing bracket line with cream highlight

        // MARK: - Part 4 Signature (paragraph 58) - "Signed [    ] on behalf of..." - cream highlight
        exporter.fillSignedWithSuffixLineHighlighted(at: 58, signatureContent: "", suffix: "on behalf of the hospital managers")
        exporter.setLineSpacing15(at: 58)

        // MARK: - Part 4 Print Name/Date (paragraph 59) - "PRINT NAME [    ] Date [    ]" - cream highlight
        exporter.fillPrintNameDateLineHighlighted(at: 59, nameContent: "", dateContent: "")
        exporter.setLineSpacing15(at: 59)

        return exporter.generateDOCX()
    }
}

class CTO3FormDOCXExporter {
    private let formData: CTO3FormData

    init(formData: CTO3FormData) {
        self.formData = formData
    }

    func generateDOCX() -> Data? {
        let exporter = TemplateDOCXExporter(templateName: "Form_CTO3_template")
        guard exporter.loadTemplate() else { return nil }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy"

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        // MARK: - Patient Name (paragraph 4 - whitespace field after label at 3)
        exporter.setParagraphText(at: 4, text: formData.patientName, highlight: true)
        exporter.setFontArial(at: 4)

        // MARK: - Hospital (paragraph 6 - whitespace field after label at 5)
        var hospitalText = formData.recallHospital
        if !formData.recallHospitalAddress.isEmpty {
            hospitalText += ", " + formData.recallHospitalAddress
        }
        exporter.setParagraphText(at: 6, text: hospitalText, highlight: true)
        exporter.setFontArial(at: 6)

        // MARK: - Option (a) or (b) handling
        // Para 9-12: Option (a) - "In my opinion..." section
        // Para 19-22: Option (b) - "You have failed to comply..." section
        // Golden bracket opens at para 9 "[In my opinion," and closes at para 22 "...certificate.]"
        if formData.recallReasonType == .treatmentRequired {
            // Option (a) selected - highlight (a), strikethrough (b)
            exporter.setDeliveryOptionWithOpeningBracket(at: 9, withStrikethrough: false)  // "[In my opinion,"
            exporter.setDeliveryOptionWithCreamHighlightOnly(at: 10, withStrikethrough: false) // "you require treatment..."
            exporter.setDeliveryOptionWithCreamHighlightOnly(at: 11, withStrikethrough: false) // "AND"
            exporter.setDeliveryOptionWithCreamHighlightOnly(at: 12, withStrikethrough: false) // "there would be a risk..."
            // Strikethrough option (b)
            exporter.setDeliveryOptionWithCreamHighlightOnly(at: 19, withStrikethrough: true) // "You have failed to comply..."
            exporter.setDeliveryOptionWithCreamHighlightOnly(at: 20, withStrikethrough: true) // "<delete as appropriate>"
            exporter.setDeliveryOptionWithCreamHighlightOnly(at: 21, withStrikethrough: true) // "(i) consideration of extension..."
            exporter.setDeliveryOptionWithClosingBracket(at: 22, withStrikethrough: true) // "(ii) enabling a Part 4A certificate...]"
        } else {
            // Option (b) selected - strikethrough (a), highlight (b)
            exporter.setDeliveryOptionWithOpeningBracket(at: 9, withStrikethrough: true)  // "[In my opinion,"
            exporter.setDeliveryOptionWithCreamHighlightOnly(at: 10, withStrikethrough: true) // "you require treatment..."
            exporter.setDeliveryOptionWithCreamHighlightOnly(at: 11, withStrikethrough: true) // "AND"
            exporter.setDeliveryOptionWithCreamHighlightOnly(at: 12, withStrikethrough: true) // "there would be a risk..."
            exporter.setDeliveryOptionWithCreamHighlightOnly(at: 13, withStrikethrough: true) // "This opinion is founded..."
            // Clear grounds paragraphs for option (b)
            exporter.removePermissionMarkers(at: 14)
            exporter.removePermissionMarkers(at: 15)
            exporter.removePermissionMarkers(at: 16)
            // Highlight option (b)
            exporter.setDeliveryOptionWithCreamHighlightOnly(at: 19, withStrikethrough: false) // "You have failed to comply..."
            // Handle (i)/(ii) sub-options
            if formData.breachExaminationType == .extensionOfCTO {
                exporter.setDeliveryOptionWithCreamHighlightOnly(at: 21, withStrikethrough: false) // "(i) consideration of extension..."
                exporter.setDeliveryOptionWithClosingBracket(at: 22, withStrikethrough: true) // "(ii) enabling a Part 4A certificate...]"
            } else {
                exporter.setDeliveryOptionWithCreamHighlightOnly(at: 21, withStrikethrough: true) // "(i) consideration of extension..."
                exporter.setDeliveryOptionWithClosingBracket(at: 22, withStrikethrough: false) // "(ii) enabling a Part 4A certificate...]"
            }
        }

        // MARK: - Reasons for Recall (paragraph 14 - only for option a)
        if formData.recallReasonType == .treatmentRequired {
            // Build patient info for "you"-directed text generation (CTO3 is addressed directly to patient)
            var patientInfoForText = formData.patientInfo
            let nameParts = formData.patientName.components(separatedBy: " ")
            patientInfoForText.firstName = nameParts.first ?? ""
            patientInfoForText.lastName = nameParts.dropFirst().joined(separator: " ")
            patientInfoForText.dateOfBirth = formData.patientDOB

            var reasonsText = formData.reasonsForRecall
            if reasonsText.isEmpty {
                // Use "you/your" directed text - CTO3 is a notice addressed to the patient
                reasonsText = formData.clinicalReasons.generateTextAsYou(patientInfoForText)
            }
            if reasonsText.isEmpty {
                reasonsText = formData.clinicalReasons.generatedText
            }
            exporter.setParagraphTextHighlightOnly(at: 14, text: reasonsText)
            exporter.setFontArial(at: 14)
            // Clear overflow paragraphs 15-16
            exporter.removePermissionMarkers(at: 15)
            exporter.removePermissionMarkers(at: 16)
            // Para 17: "[If you need to continue on a separate sheet...]" - special formatting
            exporter.setContinueOnSeparateSheetLine(at: 17, withStrikethrough: false)
        } else {
            // Option (b) - strikethrough the "continue" line as well
            exporter.setContinueOnSeparateSheetLine(at: 17, withStrikethrough: true)
        }

        // MARK: - Signature Section (para 23-26) with gold brackets - 1.5 line spacing (180 twips)
        // Para 23: "Signed [    ] Responsible clinician"
        exporter.setSignedWithSuffixLineHighlighted(at: 23, signatureContent: "", suffix: "Responsible clinician", spacingAfter: 180)

        // Para 24: "PRINT NAME [    ]"
        exporter.setPrintNameLineHighlighted(at: 24, nameContent: formData.rcName, spacingAfter: 180)

        // Para 25: "Date [    ]"
        let sigDate = dateFormatter.string(from: formData.signatureDate)
        exporter.setDateLineHighlighted(at: 25, dateContent: sigDate, spacingAfter: 180)

        // Para 26: "Time [    ]"
        let sigTime = timeFormatter.string(from: formData.recallTime)
        exporter.setTimeLineHighlighted(at: 26, timeContent: sigTime, spacingAfter: 180)

        return exporter.generateDOCX()
    }
}

class CTO4FormDOCXExporter {
    private let formData: CTO4FormData

    init(formData: CTO4FormData) {
        self.formData = formData
    }

    func generateDOCX() -> Data? {
        let exporter = TemplateDOCXExporter(templateName: "Form_CTO4_template")
        guard exporter.loadTemplate() else { return nil }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy"

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        // MARK: - Patient (paragraph 3 - whitespace field after label at 2)
        var patientText = formData.patientName
        if !formData.patientAddress.isEmpty {
            patientText += ", " + formData.patientAddress
        }
        exporter.setParagraphText(at: 3, text: patientText, highlight: true)
        exporter.setFontArial(at: 3)

        // MARK: - Hospital (paragraph 6 - whitespace field after label at 5)
        var hospitalText = formData.hospitalName
        if !formData.hospitalAddress.isEmpty {
            hospitalText += ", " + formData.hospitalAddress
        }
        exporter.setParagraphText(at: 6, text: hospitalText, highlight: true)
        exporter.setFontArial(at: 6)

        // MARK: - Detention Date/Time (paragraph 8) - "Date[date]          Time[time]" with gold brackets
        let detentionDate = dateFormatter.string(from: formData.patientRecalledDate)
        let detentionTime = timeFormatter.string(from: formData.patientRecalledDate)
        exporter.setDateTimeLineHighlighted(at: 8, dateContent: detentionDate, timeContent: detentionTime)
        exporter.setLineSpacing15(at: 8)

        // MARK: - Signature (paragraph 9) - "Signed [    ] on behalf of the hospital managers" with gold brackets
        exporter.setSignedWithSuffixLineHighlighted(at: 9, signatureContent: "", suffix: "on behalf of the hospital managers")
        exporter.setLineSpacing15(at: 9)

        // MARK: - Print Name (paragraph 10) - "PRINT NAME [name]" with gold brackets
        exporter.setPrintNameLineHighlighted(at: 10, nameContent: formData.rcName)
        exporter.setLineSpacing15(at: 10)

        // MARK: - Signature Date (paragraph 11) - "Date [date]" with gold brackets
        let sigDate = dateFormatter.string(from: formData.rcSignatureDate)
        exporter.setDateLineHighlighted(at: 11, dateContent: sigDate)
        exporter.setLineSpacing15(at: 11)

        // MARK: - Signature Time (paragraph 12) - "Time [time]" with gold brackets
        let sigTime = timeFormatter.string(from: formData.rcSignatureDate)
        exporter.setTimeLineHighlighted(at: 12, timeContent: sigTime)
        exporter.setLineSpacing15(at: 12)

        return exporter.generateDOCX()
    }
}

class CTO5FormDOCXExporter {
    private let formData: CTO5FormData

    init(formData: CTO5FormData) {
        self.formData = formData
    }

    func generateDOCX() -> Data? {
        let exporter = TemplateDOCXExporter(templateName: "Form_CTO5_template")
        guard exporter.loadTemplate() else { return nil }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy"

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        // PART 1 - RC

        // MARK: - RC (paragraph 5 - whitespace field after label at 4)
        // Include name, address (from ward/hospital), and email
        var rcText = formData.rcName
        // Build address from clinicianInfo ward/department and hospital/org
        var rcAddressParts: [String] = []
        if !formData.clinicianInfo.wardDepartment.isEmpty {
            rcAddressParts.append(formData.clinicianInfo.wardDepartment)
        }
        if !formData.clinicianInfo.hospitalOrg.isEmpty {
            rcAddressParts.append(formData.clinicianInfo.hospitalOrg)
        }
        if !rcAddressParts.isEmpty {
            rcText += ", " + rcAddressParts.joined(separator: ", ")
        }
        if !formData.clinicianInfo.email.isEmpty {
            rcText += ", " + formData.clinicianInfo.email
        }
        exporter.setParagraphText(at: 5, text: rcText, highlight: true)
        exporter.setFontArial(at: 5)

        // MARK: - Patient (paragraph 7 - whitespace field after label at 6)
        var patientText = formData.patientName
        if !formData.patientAddress.isEmpty {
            patientText += ", " + formData.patientAddress
        }
        exporter.setParagraphText(at: 7, text: patientText, highlight: true)
        exporter.setFontArial(at: 7)

        // MARK: - Hospital (paragraph 9 - whitespace field after label at 8)
        var hospitalText = formData.hospitalName
        if !formData.hospitalAddress.isEmpty {
            hospitalText += ", " + formData.hospitalAddress
        }
        exporter.setParagraphText(at: 9, text: hospitalText, highlight: true)
        exporter.setFontArial(at: 9)

        // MARK: - Detention Reasons (paragraphs 15-17) with GB
        let healthStrike = !formData.clinicalReasons.healthEnabled
        let safetyStrike = !formData.clinicalReasons.safetyEnabled || !formData.clinicalReasons.safetySelfEnabled
        let othersStrike = !formData.clinicalReasons.safetyEnabled || !formData.clinicalReasons.safetyOthersEnabled

        exporter.setDetentionReasonWithOpeningBracket(at: 15, withStrikethrough: healthStrike)
        exporter.setDetentionReasonWithCreamHighlightOnly(at: 16, withStrikethrough: safetyStrike)
        exporter.setDetentionReasonWithClosingBracket(at: 17, withStrikethrough: othersStrike)

        // MARK: - Clinical Reasons (paragraph 23 - whitespace field after label at 22)
        // Build patient info for gender-sensitive text generation
        var patientInfoForText = formData.patientInfo
        let nameParts = formData.patientName.components(separatedBy: " ")
        patientInfoForText.firstName = nameParts.first ?? ""
        patientInfoForText.lastName = nameParts.dropFirst().joined(separator: " ")
        patientInfoForText.manualAge = formData.patientAge

        var reasonsText = ""
        if !formData.reasonsForRevocation.isEmpty {
            reasonsText = formData.reasonsForRevocation
        } else {
            // Use patient-specific text generation for proper demographics and pronouns
            reasonsText = formData.clinicalReasons.generateTextWithPatient(patientInfoForText)
        }
        if reasonsText.isEmpty {
            reasonsText = formData.clinicalReasons.generatedText
        }
        exporter.setParagraphText(at: 23, text: reasonsText, highlight: true)
        exporter.setFontArial(at: 23)
        // Clear overflow paragraphs
        exporter.removePermissionMarkers(at: 24)
        exporter.removePermissionMarkers(at: 25)

        // MARK: - RC Signature (paragraph 28) - "Signed [    ] Responsible clinician" with GB
        exporter.setSignedWithSuffixLineHighlighted(at: 28, signatureContent: "", suffix: "Responsible clinician")
        exporter.setLineSpacing15(at: 28)

        // MARK: - RC Date (paragraph 29) - "Date [date]" with GB
        let rcSigDate = dateFormatter.string(from: formData.rcSignatureDate)
        exporter.setDateLineHighlighted(at: 29, dateContent: rcSigDate)
        exporter.setLineSpacing15(at: 29)

        // PART 2 - AMHP
        // MARK: - AMHP Name (paragraph 33) - GB with highlight
        exporter.setBracketLineHighlighted(at: 33, content: formData.amhpName)

        // MARK: - Local Authority (paragraph 35) - GB with highlight
        exporter.setBracketLineHighlighted(at: 35, content: formData.amhpLocalAuthority)

        // MARK: - "that authority" (paragraph 38) - GB with highlight
        exporter.setBracketLineHighlighted(at: 38, content: "that authority")

        // MARK: - Different Authority (paragraph 40) - GB with highlight for manual fill
        exporter.setBracketLineHighlighted(at: 40, content: "")

        // MARK: - AMHP Signature (paragraph 44) - "Signed [    ] Approved mental health professional" with GB
        exporter.setSignedWithSuffixLineHighlighted(at: 44, signatureContent: "", suffix: "Approved mental health professional")
        exporter.setLineSpacing15(at: 44)

        // MARK: - AMHP Date (paragraph 45) - "Date [date]" with GB
        let amhpSigDate = dateFormatter.string(from: formData.amhpSignatureDate)
        exporter.setDateLineHighlighted(at: 45, dateContent: amhpSigDate)
        exporter.setLineSpacing15(at: 45)

        // PART 3 - Revocation
        // MARK: - Part 3 text (paragraph 47) - plain text without GB or highlighting
        // The text stays as template with [time] and [date] placeholders - do not modify

        // MARK: - Detention Date/Time (paragraph 48) - "Date:[date] Time:[time]" with GB
        let detentionDate = dateFormatter.string(from: formData.patientRecalledDate)
        let detentionTime = timeFormatter.string(from: formData.patientRecalledDate)
        exporter.setDateTimeLineHighlighted(at: 48, dateContent: detentionDate, timeContent: detentionTime)
        exporter.setLineSpacing15(at: 48)

        // MARK: - RC Signature Part 3 (paragraph 50) - "Signed [    ]" with GB
        exporter.setSignedOnlyLineHighlighted(at: 50, signatureContent: "")
        exporter.setLineSpacing15(at: 50)

        // MARK: - RC Profession/Date (paragraph 51) - "Responsible clinician Date [date]" with GB
        exporter.setPrefixDateLineHighlighted(at: 51, prefix: "Responsible clinician", dateContent: rcSigDate)
        exporter.setLineSpacing15(at: 51)

        return exporter.generateDOCX()
    }
}

class CTO7FormDOCXExporter {
    private let formData: CTO7FormData

    init(formData: CTO7FormData) {
        self.formData = formData
    }

    func generateDOCX() -> Data? {
        let exporter = TemplateDOCXExporter(templateName: "Form_CTO7_template")
        guard exporter.loadTemplate() else { return nil }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy"

        // PART 1 - RC
        // MARK: - Hospital (paragraph 6 - whitespace field after label at 5)
        exporter.setParagraphText(at: 6, text: formData.responsibleHospital, highlight: true)
        exporter.setFontArial(at: 6)

        // MARK: - RC Name/Address/Email (paragraph 8 - whitespace field after label at 7)
        var rcText = formData.rcName
        if !formData.rcAddress.isEmpty {
            rcText += ", " + formData.rcAddress
        }
        if !formData.rcEmail.isEmpty {
            rcText += ", " + formData.rcEmail
        }
        exporter.setParagraphText(at: 8, text: rcText, highlight: true)
        exporter.setFontArial(at: 8)

        // MARK: - Patient (paragraph 10 - whitespace field after label at 9)
        var patientText = formData.patientName
        if !formData.patientAddress.isEmpty {
            patientText += ", " + formData.patientAddress
        }
        exporter.setParagraphText(at: 10, text: patientText, highlight: true)
        exporter.setFontArial(at: 10)

        // MARK: - CTO Date (paragraph 12 - whitespace field after label at 11)
        let ctoDate = dateFormatter.string(from: formData.currentCTOExpiryDate)
        exporter.setParagraphText(at: 12, text: ctoDate, highlight: true)
        exporter.setFontArial(at: 12)

        // MARK: - Exam Date (paragraph 14 - whitespace field after label at 13)
        let examDate = dateFormatter.string(from: formData.examinationDate)
        exporter.setParagraphText(at: 14, text: examDate, highlight: true)
        exporter.setFontArial(at: 14)

        // MARK: - Detention Reasons (paragraphs 18-20) - with gold brackets
        let healthStrike = !formData.clinicalReasons.healthEnabled
        let safetyStrike = !formData.clinicalReasons.safetyEnabled || !formData.clinicalReasons.safetySelfEnabled
        let othersStrike = !formData.clinicalReasons.safetyEnabled || !formData.clinicalReasons.safetyOthersEnabled

        exporter.setDetentionReasonWithOpeningBracket(at: 18, withStrikethrough: healthStrike)
        exporter.setDetentionReasonWithCreamHighlightOnly(at: 19, withStrikethrough: safetyStrike)
        exporter.setDetentionReasonWithClosingBracket(at: 20, withStrikethrough: othersStrike)

        // MARK: - Clinical Reasons (paragraph 27 - whitespace field after label at 26)
        // Build patient info for gender-sensitive text generation
        var patientInfoForText = formData.patientInfo
        let nameParts = formData.patientName.components(separatedBy: " ")
        patientInfoForText.firstName = nameParts.first ?? ""
        patientInfoForText.lastName = nameParts.dropFirst().joined(separator: " ")
        patientInfoForText.dateOfBirth = formData.patientDOB
        patientInfoForText.manualAge = formData.patientAge  // Use manual age for CTO7

        var reasonsText = formData.reasonsForExtension
        if reasonsText.isEmpty {
            // Use patient-specific text generation for proper demographics and pronouns
            reasonsText = formData.clinicalReasons.generateTextWithPatient(patientInfoForText)
        }
        if reasonsText.isEmpty {
            reasonsText = formData.clinicalReasons.generatedText
        }
        exporter.setParagraphText(at: 27, text: reasonsText, highlight: true)
        exporter.setFontArial(at: 27)
        // Clear overflow paragraph 28
        exporter.removePermissionMarkers(at: 28)

        // MARK: - "[If you need to continue...]" line (paragraph 29) - gold brackets checkbox
        exporter.setIndicateHereCheckbox(at: 29)
        exporter.setFontArial(at: 29)

        // MARK: - RC Signature (paragraph 31) - "Signed [ ] Responsible clinician" with gold brackets
        let rcSigDate = dateFormatter.string(from: formData.signatureDate)
        exporter.setSignedWithSuffixLineHighlighted(at: 31, signatureContent: "", suffix: "Responsible clinician")
        exporter.setLineSpacing15(at: 31)

        // MARK: - RC Signature Date (paragraph 32) - "Date[ ]" with gold brackets
        exporter.setDateLineHighlighted(at: 32, dateContent: rcSigDate)
        exporter.setLineSpacing15(at: 32)

        // PART 2 - AMHP Agreement
        // MARK: - AMHP Name/Address/Email (paragraph 35) - gold brackets with highlighted space
        exporter.setBracketLineHighlighted(at: 35, content: "")

        // MARK: - AMHP Local Authority (paragraph 37) - gold brackets with highlighted space
        exporter.setBracketLineHighlighted(at: 37, content: "")

        // MARK: - "that authority" (paragraph 39) - gold brackets with highlighted text
        exporter.setBracketLineHighlighted(at: 39, content: "that authority")

        // MARK: - Alternative Authority (paragraph 41) - gold brackets with highlighted space
        exporter.setBracketLineHighlighted(at: 41, content: "")

        // MARK: - AMHP Signature (paragraph 45) - "Signed [ ] Approved mental health professional" with gold brackets
        exporter.setSignedWithSuffixLineHighlighted(at: 45, signatureContent: "", suffix: "Approved mental health professional")
        exporter.setLineSpacing15(at: 45)

        // MARK: - AMHP Date (paragraph 46) - "Date[ ]" with gold brackets
        exporter.setDateLineHighlighted(at: 46, dateContent: "")
        exporter.setLineSpacing15(at: 46)

        // PART 3 - Consultation
        // MARK: - Professional Consulted (paragraph 49) - gold brackets
        // Format: "name, email, profession"
        var consultedParts: [String] = []
        if !formData.professionalConsulted.isEmpty {
            consultedParts.append(formData.professionalConsulted)
        }
        if !formData.consulteeEmail.isEmpty {
            consultedParts.append(formData.consulteeEmail)
        }
        if !formData.professionOfConsultee.isEmpty {
            consultedParts.append(formData.professionOfConsultee)
        }
        let consultedText = consultedParts.joined(separator: ", ")
        exporter.setBracketLineHighlighted(at: 49, content: consultedText)

        // MARK: - Part 3 Delivery Method (paragraphs 52-54) - gold bracket starting at 52, ending at 54
        // Para 52: "today consigning it to the hospital managers' internal mail system."
        // Para 53: "today sending it to the hospital managers... by means of electronic communication."
        // Para 54: "sending or delivering it without using the hospital managers' internal mail system."
        switch formData.deliveryMethod {
        case .internalMail:
            exporter.setDeliveryOptionWithOpeningBracket(at: 52, withStrikethrough: false)
            exporter.setDeliveryOptionWithCreamHighlightOnly(at: 53, withStrikethrough: true)
            exporter.setDeliveryOptionWithClosingBracket(at: 54, withStrikethrough: true)
        case .electronic:
            exporter.setDeliveryOptionWithOpeningBracket(at: 52, withStrikethrough: true)
            exporter.setDeliveryOptionWithCreamHighlightOnly(at: 53, withStrikethrough: false)
            exporter.setDeliveryOptionWithClosingBracket(at: 54, withStrikethrough: true)
        case .handDelivery:
            exporter.setDeliveryOptionWithOpeningBracket(at: 52, withStrikethrough: true)
            exporter.setDeliveryOptionWithCreamHighlightOnly(at: 53, withStrikethrough: true)
            exporter.setDeliveryOptionWithClosingBracket(at: 54, withStrikethrough: false)
        }

        // MARK: - RC Signature Part 3 (paragraph 55) - "Signed [ ] Responsible clinician" with gold brackets
        exporter.setSignedWithSuffixLineHighlighted(at: 55, signatureContent: "", suffix: "Responsible clinician")
        exporter.setLineSpacing15(at: 55)

        // MARK: - Part 3 Date (paragraph 56) - "Date[ ]" with gold brackets
        let consultDate = dateFormatter.string(from: formData.consultationDate)
        exporter.setDateLineHighlighted(at: 56, dateContent: consultDate)
        exporter.setLineSpacing15(at: 56)

        // PART 4 - Hospital Managers (for hospital managers to complete)
        // Para 60: "furnished to the hospital managers through their internal mail system."
        // Para 61: "furnished to the hospital managers... by means of electronic communication."
        // Para 62: "received by me on behalf of the hospital managers on [date]."
        // Gold bracket at start (para 60), closing bracket after blank line (para 63)
        exporter.setDeliveryOptionWithOpeningBracket(at: 60, withStrikethrough: false)
        exporter.setDeliveryOptionWithCreamHighlightOnly(at: 61, withStrikethrough: false)
        exporter.setDeliveryOptionWithCreamHighlightOnly(at: 62, withStrikethrough: false)

        // MARK: - Part 4 blank line with closing bracket (paragraph 63)
        exporter.setHighlightedSpaceWithClosingBracket(at: 63)

        // MARK: - Part 4 Signature (paragraph 64) - "Signed [ ] on behalf of the managers of the responsible hospital"
        exporter.setPart4SignatureLine(at: 64)
        exporter.setLineSpacing15(at: 64)

        // MARK: - Part 4 Print Name/Date (paragraph 65) - "PRINT NAME [ ] Date [ ]" with gold brackets
        exporter.setPrintNameDateLineHighlighted(at: 65, nameContent: "", dateContent: "")
        exporter.setLineSpacing15(at: 65)

        return exporter.generateDOCX()
    }
}

class M2FormDOCXExporter {
    private let formData: M2FormData

    init(formData: M2FormData) {
        self.formData = formData
    }

    func generateDOCX() -> Data? {
        let exporter = TemplateDOCXExporter(templateName: "Form_M2_template")
        guard exporter.loadTemplate() else { return nil }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy"

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        // MARK: - Hospital (paragraph 5 - whitespace field after label at 4)
        var hospitalText = formData.hospitalName
        if !formData.hospitalAddress.isEmpty {
            hospitalText += ", " + formData.hospitalAddress
        }
        exporter.setParagraphText(at: 5, text: hospitalText, highlight: true)
        exporter.setFontArial(at: 5)

        // MARK: - Nearest Relative Name (paragraph 7 - whitespace field after label at 6)
        exporter.setParagraphText(at: 7, text: formData.nrName, highlight: true)
        exporter.setFontArial(at: 7)

        // MARK: - Notice Time (paragraph 9 - whitespace field after label at 8)
        let noticeTime = timeFormatter.string(from: formData.dischargeNoticeTime)
        exporter.setParagraphText(at: 9, text: noticeTime, highlight: true)
        exporter.setFontArial(at: 9)

        // MARK: - Notice Date (paragraph 11 - whitespace field after label at 10)
        let noticeDate = dateFormatter.string(from: formData.dischargeNoticeDate)
        exporter.setParagraphText(at: 11, text: noticeDate, highlight: true)
        exporter.setFontArial(at: 11)

        // MARK: - Patient Name (paragraph 13 - whitespace field after label at 12)
        exporter.setParagraphText(at: 13, text: formData.patientName, highlight: true)
        exporter.setFontArial(at: 13)

        // MARK: - Reasons for Barring Discharge (paragraph 16 - whitespace field after label at 15)
        // Build complete patient info for text generation
        var patientInfoForText = formData.patientInfo
        let nameParts = formData.patientName.components(separatedBy: " ")
        patientInfoForText.firstName = nameParts.first ?? ""
        patientInfoForText.lastName = nameParts.dropFirst().joined(separator: " ")

        var reasonsText = formData.dangerousIfDischarged
        if reasonsText.isEmpty {
            // Use patient-specific text generation
            reasonsText = formData.clinicalReasons.generateTextWithPatient(patientInfoForText)
        }
        if reasonsText.isEmpty {
            reasonsText = formData.clinicalReasons.generatedText
        }
        exporter.setParagraphText(at: 16, text: reasonsText, highlight: true)
        exporter.setFontArial(at: 16)
        // Clear overflow paragraphs 17-18
        exporter.removePermissionMarkers(at: 17)
        exporter.removePermissionMarkers(at: 18)

        // MARK: - "[If you need to continue...]" line (paragraph 19) - gold brackets checkbox
        exporter.setIndicateHereCheckbox(at: 19)
        exporter.setFontArial(at: 19)

        // MARK: - Delivery Method (paragraphs 21-24) with golden brackets
        // Para 21 gets opening bracket [, para 24 gets closing bracket ]
        // Para 22 is time entry line with cream highlight (for internal mail option)
        let deliveryTime = timeFormatter.string(from: formData.signatureDate)
        switch formData.transmissionMethod {
        case .internalMail:
            // "consigning it to the hospital managers' internal mail system today at [time]."
            // Line 21: The text with literal [time]
            // Line 22: Cream highlighted area with the actual time entered
            exporter.setM2DeliveryFirstLineWithTime(at: 21, timeContent: deliveryTime, withStrikethrough: false)
            exporter.setM2DeliveryTimeEntryLine(at: 22, timeContent: deliveryTime, withStrikethrough: false)
            exporter.setExistingTextWithCreamHighlightOnly(at: 23, withStrikethrough: true)
            exporter.setExistingTextWithClosingBracketHighlighted(at: 24, withStrikethrough: true)
        case .electronic:
            // "today sending it to the hospital managers...by means of electronic communication."
            exporter.setM2DeliveryFirstLineWithTime(at: 21, timeContent: "", withStrikethrough: true)
            exporter.setM2DeliveryPaddingLine(at: 22, withStrikethrough: true)
            exporter.setExistingTextWithCreamHighlightOnly(at: 23, withStrikethrough: false)
            exporter.setExistingTextWithClosingBracketHighlighted(at: 24, withStrikethrough: true)
        case .otherDelivery:
            // "sending or delivering it without using the hospital managers' internal mail system."
            exporter.setM2DeliveryFirstLineWithTime(at: 21, timeContent: "", withStrikethrough: true)
            exporter.setM2DeliveryPaddingLine(at: 22, withStrikethrough: true)
            exporter.setExistingTextWithCreamHighlightOnly(at: 23, withStrikethrough: true)
            exporter.setExistingTextWithClosingBracketHighlighted(at: 24, withStrikethrough: false)
        }

        // MARK: - Signature (paragraph 25) - "Signed [...] Responsible clinician" - cream highlight with gold brackets
        exporter.fillSignedWithSuffixLineHighlighted(at: 25, signatureContent: "", suffix: "Responsible clinician")
        exporter.setLineSpacing15(at: 25)

        // MARK: - RC Name (paragraph 26) - "PRINT NAME [name]" - cream highlight with gold brackets
        exporter.fillLabelBracketLineHighlighted(at: 26, label: "PRINT NAME", content: formData.rcName)
        exporter.setLineSpacing15(at: 26)

        // MARK: - Email (paragraph 27) - "Email address (if applicable) [email]" - cream highlight with gold brackets
        exporter.fillLabelBracketLineHighlighted(at: 27, label: "Email address (if applicable)", content: formData.rcEmail)
        exporter.setLineSpacing15(at: 27)

        // MARK: - Date and Time (paragraph 28) - "Date [date] Time [time]" - cream highlight with gold brackets
        let sigDate = dateFormatter.string(from: formData.signatureDate)
        let sigTime = timeFormatter.string(from: formData.signatureDate)
        exporter.fillDateTimeLineHighlighted(at: 28, dateContent: sigDate, timeContent: sigTime)
        exporter.setLineSpacing15(at: 28)

        // ═══════════════════════════════════════════════════════════════════
        // PART 2 - To be completed on behalf of the hospital managers
        // ═══════════════════════════════════════════════════════════════════

        // Para 32: "[furnished to the hospital managers through their internal mail system." - opening golden bracket, cream highlight
        exporter.setTextWithOpeningBracketHighlighted(at: 32, text: "furnished to the hospital managers through their internal mail system.")

        // Para 33: "furnished to the hospital managers...electronic communication" - cream highlight only
        exporter.setExistingTextWithCreamHighlightOnly(at: 33)

        // Para 34: "received by me on behalf of the hospital managers at [time]" - cream highlight
        exporter.setExistingTextWithCreamHighlightOnly(at: 34)

        // Para 35: Cream highlighted time entry line (blank for hospital managers to fill in)
        exporter.setM2DeliveryTimeEntryLine(at: 35, timeContent: "", withStrikethrough: false)

        // Para 36: "on [date]." - cream highlight
        exporter.setExistingTextWithCreamHighlightOnly(at: 36)

        // Para 37: Closing "]" with cream highlight and golden bracket
        exporter.setClosingBracketLine(at: 37)

        // Para 38: "Signed [ ] on behalf of the hospital managers" - cream highlight with gold brackets
        exporter.fillSignedWithSuffixLineHighlighted(at: 38, signatureContent: "", suffix: "on behalf of the hospital managers")
        exporter.setLineSpacing15(at: 38)

        // Para 39: "PRINT NAME [ ] Date [ ]" - cream highlight with gold brackets
        exporter.fillPrintNameDateLineHighlighted(at: 39, nameContent: "", dateContent: "")
        exporter.setLineSpacing15(at: 39)

        return exporter.generateDOCX()
    }
}

// MARK: - MOJ Leave Form DOCX Exporter
// Based on MHCS Leave Application template with table-based structure
class MOJLeaveFormDOCXExporter {
    private let formData: MOJLeaveFormData

    init(formData: MOJLeaveFormData) {
        self.formData = formData
    }

    func generateDOCX() -> Data? {
        let exporter = TemplateDOCXExporter(templateName: "MHCS_Leave_Application_template")
        guard exporter.loadTemplate() else { return nil }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"

        // ═══════════════════════════════════════════════════════════════════
        // SECTION 1 & 2: Patient Details & RC Details
        // Table mappings match desktop: tables[3]=name, [4]=DOB, [5]=ref, [6]=hospital, [7]=RC
        // ═══════════════════════════════════════════════════════════════════

        // Table 4 [0,1]: Patient name
        exporter.setTableCellText(tableIndex: 3, row: 0, col: 1, text: formData.patientName)

        // Table 5 [0,1]: DOB
        if let dob = formData.patientDOB {
            exporter.setTableCellText(tableIndex: 4, row: 0, col: 1, text: dateFormatter.string(from: dob))
        }

        // Table 6 [0,1]: MOJ reference
        exporter.setTableCellText(tableIndex: 5, row: 0, col: 1, text: formData.mojReference)

        // Table 7 [0,1]: Hospital name
        exporter.setTableCellText(tableIndex: 6, row: 0, col: 1, text: formData.hospitalName)

        // Table 8 [0,1]: RC details (name, phone, email)
        let rcDetails = "\(formData.rcName)\n\n\(formData.rcPhone)\n\n\(formData.rcEmail)"
        exporter.setTableCellText(tableIndex: 7, row: 0, col: 1, text: rcDetails)

        // ═══════════════════════════════════════════════════════════════════
        // SECTION 3: Leave Details
        // ═══════════════════════════════════════════════════════════════════

        // Table 10 [0,1]: Documents reviewed
        exporter.setTableCellText(tableIndex: 9, row: 0, col: 1, text: formData.documentsReviewedText())

        // Table 11 [0,1]: Purpose of leave
        exporter.setTableCellText(tableIndex: 10, row: 0, col: 1, text: formData.purposeText)

        // Table 12 [0,1]: Overnight leave
        exporter.setTableCellText(tableIndex: 11, row: 0, col: 1, text: formData.overnightText)

        // Table 13 [0,1]: Escorted overnight
        exporter.setTableCellText(tableIndex: 12, row: 0, col: 1, text: formData.escortedOvernightText)

        // Table 14 [0,1]: Compassionate
        exporter.setTableCellText(tableIndex: 13, row: 0, col: 1, text: formData.compassionateText)

        // Table 15 [0,1]: Leave report
        exporter.setTableCellText(tableIndex: 14, row: 0, col: 1, text: formData.leaveReportText)

        // Table 16 [0,1]: Procedures
        exporter.setTableCellText(tableIndex: 15, row: 0, col: 1, text: formData.proceduresText)

        // ═══════════════════════════════════════════════════════════════════
        // SECTION 4: Clinical Details
        // ═══════════════════════════════════════════════════════════════════

        // Table 18 [0,1]: Hospital admissions / Past psychiatric history
        exporter.setTableCellText(tableIndex: 17, row: 0, col: 1, text: formData.hospitalAdmissionsText)

        // Table 19 [0,1]: Index offence
        exporter.setTableCellText(tableIndex: 18, row: 0, col: 1, text: formData.indexOffenceText)

        // Table 20 [0,1]: Mental disorder
        exporter.setTableCellText(tableIndex: 19, row: 0, col: 1, text: formData.mentalDisorderText)

        // Table 21 [0,1]: Attitude/behaviour
        exporter.setTableCellText(tableIndex: 20, row: 0, col: 1, text: formData.attitudeBehaviourText)

        // Table 22 [0,1]: Risk factors
        exporter.setTableCellText(tableIndex: 21, row: 0, col: 1, text: formData.riskFactorsText)

        // Table 23 [0,1]: Medication
        exporter.setTableCellText(tableIndex: 22, row: 0, col: 1, text: formData.medicationText)

        // Table 24 [0,1]: Psychology
        exporter.setTableCellText(tableIndex: 23, row: 0, col: 1, text: formData.psychologyText)

        // Table 25 [0,1]: Extremism
        exporter.setTableCellText(tableIndex: 24, row: 0, col: 1, text: formData.extremismText)

        // Table 27 [0,1]: Absconding
        exporter.setTableCellText(tableIndex: 26, row: 0, col: 1, text: formData.abscondingText)

        // ═══════════════════════════════════════════════════════════════════
        // SECTION 5: MAPPA
        // ═══════════════════════════════════════════════════════════════════

        // Table 29 [0,1]: MAPPA coordinator
        exporter.setTableCellText(tableIndex: 28, row: 0, col: 1, text: formData.mappaCoordinator)

        // Table 30 [0,1]: MAPPA notes
        var mappaNotesOutput = formData.mappaNotesText
        if formData.mappaCategory > 0 {
            mappaNotesOutput = "Category \(formData.mappaCategory), Level \(formData.mappaLevel)\n\n\(mappaNotesOutput)"
        }
        exporter.setTableCellText(tableIndex: 29, row: 0, col: 1, text: mappaNotesOutput)

        // ═══════════════════════════════════════════════════════════════════
        // SECTION 6: Victims
        // ═══════════════════════════════════════════════════════════════════

        // Table 32 [0,1]: VLO contact details
        let vloContact = formData.victimsVLOContact.isEmpty ? "VLO: Not available" : formData.victimsVLOContact
        exporter.setTableCellText(tableIndex: 31, row: 0, col: 1, text: vloContact)

        // Table 33 [0,1]: VLO reply date
        exporter.setTableCellText(tableIndex: 32, row: 0, col: 1, text: formData.victimsReplyDate)

        // Table 34 [0,1]: Victim conditions
        exporter.setTableCellText(tableIndex: 33, row: 0, col: 1, text: formData.victimsConditions)

        // Table 35 [0,1]: Risk assessment if no VLO
        exporter.setTableCellText(tableIndex: 34, row: 0, col: 1, text: formData.victimsRiskAssessment)

        // ═══════════════════════════════════════════════════════════════════
        // SECTION 7: Transferred Prisoners
        // ═══════════════════════════════════════════════════════════════════

        if formData.prisonersApplicable == "na" {
            // Table 37 [0,1]: OM contact - "Not applicable"
            exporter.setTableCellText(tableIndex: 36, row: 0, col: 1, text: "Not applicable")
        } else {
            // Table 37 [0,1]: OM contact
            exporter.setTableCellText(tableIndex: 36, row: 0, col: 1, text: formData.prisonersOMContact)

            // Table 38 [0,1]: OM response
            exporter.setTableCellText(tableIndex: 37, row: 0, col: 1, text: formData.prisonersResponse)

            // Table 39 [0,1]: Remission text
            exporter.setTableCellText(tableIndex: 38, row: 0, col: 1, text: formData.prisonersRemissionText)
        }

        // ═══════════════════════════════════════════════════════════════════
        // SECTION 8: Fitness to Plead
        // ═══════════════════════════════════════════════════════════════════

        // Table 40 [0,1]: Fitness to plead - Generate text from structured fields
        var fitnessText = ""
        if formData.fitnessFoundUnfit == "no" {
            fitnessText = "Patient was not found unfit to plead."
        } else {
            fitnessText = "Patient was found unfit to plead on sentencing."
            if formData.fitnessNowFit == "yes" {
                fitnessText += " Patient is now fit to plead."
            } else if formData.fitnessNowFit == "no" {
                fitnessText += " Patient remains unfit to plead."
            }
            if !formData.fitnessDetails.isEmpty {
                fitnessText += " " + formData.fitnessDetails
            }
        }
        exporter.setTableCellText(tableIndex: 39, row: 0, col: 1, text: fitnessText)

        // ═══════════════════════════════════════════════════════════════════
        // SECTION 9: Additional Comments
        // ═══════════════════════════════════════════════════════════════════

        // Table 42 [0,1]: Additional comments
        let additionalText = formData.additionalCommentsText.isEmpty ? "Nil" : formData.additionalCommentsText
        exporter.setTableCellText(tableIndex: 41, row: 0, col: 1, text: additionalText)

        // Table 43 [0,1]: Patient discussion
        var discussionParts: [String] = []
        if formData.discussedWithPatient {
            discussionParts.append("This has been discussed with the patient.")
            if formData.issuesOfConcern {
                if !formData.issuesDetails.isEmpty {
                    discussionParts.append("Issues of concern: \(formData.issuesDetails)")
                } else {
                    discussionParts.append("Issues of concern were raised.")
                }
            } else {
                discussionParts.append("No issues of concern.")
            }
        } else {
            discussionParts.append("This has not been discussed with the patient.")
        }
        exporter.setTableCellText(tableIndex: 42, row: 0, col: 1, text: discussionParts.joined(separator: " "))

        // ═══════════════════════════════════════════════════════════════════
        // Signature
        // ═══════════════════════════════════════════════════════════════════

        // Table 44: Signature (row 1, col 1 for signature, col 3 for date)
        let sigText = formData.signatureLine.isEmpty ? formData.signatureName : formData.signatureLine
        let fullSigText = "\(sigText)\n\nPrint name: \(formData.signatureName)"
        exporter.setTableCellText(tableIndex: 43, row: 1, col: 1, text: fullSigText)
        exporter.setTableCellText(tableIndex: 43, row: 1, col: 3, text: dateFormatter.string(from: formData.signatureDate))

        // ═══════════════════════════════════════════════════════════════════
        // Annex
        // ═══════════════════════════════════════════════════════════════════

        // Table 46 [0,1]: Annex - patient progress
        exporter.setTableCellText(tableIndex: 45, row: 0, col: 1, text: formData.annexProgress)

        // Table 47 [0,1]: Annex - patient wishes
        exporter.setTableCellText(tableIndex: 46, row: 0, col: 1, text: formData.annexWishes)

        // Table 48 [0,1]: Annex - RC confirmation
        exporter.setTableCellText(tableIndex: 47, row: 0, col: 1, text: formData.annexConfirm)

        return exporter.generateDOCX()
    }
}

// MARK: - MOJ ASR Form DOCX Exporter
// Based on MOJ_ASR_template.docx structure - paragraph-based export
class MOJASRFormDOCXExporter {
    private let formData: MOJASRFormData

    init(formData: MOJASRFormData) {
        self.formData = formData
    }

    func generateDOCX() -> Data? {
        let exporter = TemplateDOCXExporter(templateName: "MOJ_ASR_template")
        guard exporter.loadTemplate() else { return nil }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"

        // ═══════════════════════════════════════════════════════════════════
        // SECTION 1: Patient Details (Table 1)
        // Row 1: Name, Row 2: DOB, Row 3: Hospital, Row 4: MHCS Ref,
        // Row 5: MHA Section, Row 6: Section Date, Row 7: Other Detention
        // ═══════════════════════════════════════════════════════════════════

        exporter.setTableCellText(tableIndex: 1, row: 1, col: 1, text: formData.patientName)

        if let dob = formData.patientDOB {
            exporter.setTableCellText(tableIndex: 1, row: 2, col: 1, text: dateFormatter.string(from: dob))
        }

        exporter.setTableCellText(tableIndex: 1, row: 3, col: 1, text: formData.hospitalName)
        exporter.setTableCellText(tableIndex: 1, row: 4, col: 1, text: formData.mhcsRef)
        exporter.setTableCellText(tableIndex: 1, row: 5, col: 1, text: formData.mhaSection)

        if let sectionDate = formData.mhaSectionDate {
            exporter.setTableCellText(tableIndex: 1, row: 6, col: 1, text: dateFormatter.string(from: sectionDate))
        }

        exporter.setTableCellText(tableIndex: 1, row: 7, col: 1, text: formData.otherDetention)

        // ═══════════════════════════════════════════════════════════════════
        // SECTION 2: RC Details (Table 2)
        // Row 1: Name, Row 2: Job Title, Row 3: Phone, Row 4: Email, Row 5: MHA Office Email
        // ═══════════════════════════════════════════════════════════════════

        exporter.setTableCellText(tableIndex: 2, row: 1, col: 1, text: formData.rcName)
        exporter.setTableCellText(tableIndex: 2, row: 2, col: 1, text: formData.rcJobTitle)
        exporter.setTableCellText(tableIndex: 2, row: 3, col: 1, text: formData.rcPhone)
        exporter.setTableCellText(tableIndex: 2, row: 4, col: 1, text: formData.rcEmail)
        exporter.setTableCellText(tableIndex: 2, row: 5, col: 1, text: formData.mhaOfficeEmail)

        // ═══════════════════════════════════════════════════════════════════
        // SECTIONS 3-16: Content Paragraphs
        // Desktop uses insert_after_header to find paragraphs after section titles
        // We'll use paragraph-based approach similar to other forms
        // ═══════════════════════════════════════════════════════════════════

        // Section 3: Mental Disorder - combine diagnoses and clinical description
        let mentalDisorderText = generateMentalDisorderText()
        if !mentalDisorderText.isEmpty {
            exporter.setParagraphText(at: 25, text: mentalDisorderText)
            exporter.setFontArial(at: 25)
        }

        // Section 4: Attitude & Behaviour - generated from behaviour categories
        let behaviourText = formData.generateBehaviourText()
        if !behaviourText.isEmpty {
            exporter.setParagraphText(at: 30, text: behaviourText)
            exporter.setFontArial(at: 30)
        }

        // Section 5: Addressing Issues - generated from OT/psych/index work
        let addressingText = generateAddressingIssuesText()
        if !addressingText.isEmpty {
            exporter.setParagraphText(at: 35, text: addressingText)
            exporter.setFontArial(at: 35)
        }

        // Section 6: Patient's Attitude - generated from grid + offending behaviour
        let attitudeText = generatePatientAttitudeText()
        if !attitudeText.isEmpty {
            exporter.setParagraphText(at: 40, text: attitudeText)
            exporter.setFontArial(at: 40)
        }

        // Section 7: Capacity Issues - generated from capacity areas
        let capacityText = generateCapacityText()
        if !capacityText.isEmpty {
            exporter.setParagraphText(at: 45, text: capacityText)
            exporter.setFontArial(at: 45)
        }

        // Section 8: Progress - generated from sliders
        let progressText = formData.generateProgressText()
        if !progressText.isEmpty {
            exporter.setParagraphText(at: 50, text: progressText)
            exporter.setFontArial(at: 50)
        }

        // Section 9: Managing Risk
        if !formData.managingRiskText.isEmpty {
            exporter.setParagraphText(at: 55, text: formData.managingRiskText)
            exporter.setFontArial(at: 55)
        }

        // Section 10: How Risks Addressed
        if !formData.riskAddressedText.isEmpty {
            exporter.setParagraphText(at: 60, text: formData.riskAddressedText)
            exporter.setFontArial(at: 60)
        }

        // Section 11: Abscond / Escape
        if !formData.abscondText.isEmpty {
            exporter.setParagraphText(at: 65, text: formData.abscondText)
            exporter.setFontArial(at: 65)
        }

        // Section 12: MAPPA
        if !formData.mappaText.isEmpty {
            exporter.setParagraphText(at: 70, text: formData.mappaText)
            exporter.setFontArial(at: 70)
        }

        // Section 13: Victims
        if !formData.victimsText.isEmpty {
            exporter.setParagraphText(at: 75, text: formData.victimsText)
            exporter.setFontArial(at: 75)
        }

        // Section 14: Leave Report - generated from escorted/unescorted states
        let leaveText = generateLeaveReportText()
        if !leaveText.isEmpty {
            exporter.setParagraphText(at: 85, text: leaveText)
            exporter.setFontArial(at: 85)
        }

        // ═══════════════════════════════════════════════════════════════════
        // Leave Checkboxes (Table 3) - tick based on leave content
        // Desktop structure: Row 2=Escorted, Row 3=Unescorted, Row 4=Long Term Escorted
        // ═══════════════════════════════════════════════════════════════════
        let leaveLower = leaveText.lowercased()
        let hasEscorted = leaveLower.contains("escorted leave:")
        let hasUnescorted = leaveLower.contains("unescorted leave:")

        if hasEscorted {
            // Row 2: Escorted day (col 0)
            exporter.setTableCellText(tableIndex: 3, row: 2, col: 0, text: "X")
            // Row 4: Long Term Escorted (col 0)
            exporter.setTableCellText(tableIndex: 3, row: 4, col: 0, text: "X")
        }

        if hasUnescorted {
            // Row 3: Unescorted day (col 0)
            exporter.setTableCellText(tableIndex: 3, row: 3, col: 0, text: "X")
        }

        // Section 15: Additional Comments
        if !formData.additionalCommentsText.isEmpty {
            exporter.setParagraphText(at: 90, text: formData.additionalCommentsText)
            exporter.setFontArial(at: 90)
        }

        // Section 16: Unfit to Plead
        if !formData.unfitToPleadText.isEmpty {
            exporter.setParagraphText(at: 95, text: formData.unfitToPleadText)
            exporter.setFontArial(at: 95)
        }

        // ═══════════════════════════════════════════════════════════════════
        // Signature (Table 4)
        // Row 0: Signature area, Date in col 3
        // ═══════════════════════════════════════════════════════════════════

        exporter.setTableCellText(tableIndex: 4, row: 0, col: 1, text: formData.rcName)
        exporter.setTableCellText(tableIndex: 4, row: 0, col: 3, text: dateFormatter.string(from: formData.signatureDate))

        return exporter.generateDOCX()
    }

    // MARK: - Text Generation Helpers

    private func generateMentalDisorderText() -> String {
        var parts: [String] = []

        // Add diagnoses
        if !formData.diagnosis1.isEmpty {
            parts.append("Primary diagnosis: \(formData.diagnosis1)")
        }
        if !formData.diagnosis2.isEmpty {
            parts.append("Secondary diagnosis: \(formData.diagnosis2)")
        }
        if !formData.diagnosis3.isEmpty {
            parts.append("Third diagnosis: \(formData.diagnosis3)")
        }

        // Add clinical description
        if !formData.clinicalDescription.isEmpty {
            if !parts.isEmpty {
                parts.append("")
            }
            parts.append(formData.clinicalDescription)
        }

        return parts.joined(separator: "\n")
    }

    private func generateAddressingIssuesText() -> String {
        let pro = formData.patientGender == .male ? "He" : formData.patientGender == .female ? "She" : "They"
        let has = formData.patientGender == .other ? "have" : "has"

        var parts: [String] = []

        // Index offence work
        let indexLevels = ["not started", "considering", "starting", "engaging with", "well engaged with", "almost completed", "completed"]
        let indexLevel = indexLevels[min(formData.indexOffenceWorkLevel, indexLevels.count - 1)]
        parts.append("\(pro) \(has) \(indexLevel) work to address index offence(s) and risks.")

        if !formData.indexOffenceWorkDetails.isEmpty {
            parts.append(formData.indexOffenceWorkDetails)
        }

        // OT Groups
        var otGroups: [String] = []
        if formData.otBreakfastClub { otGroups.append("breakfast club") }
        if formData.otSmoothie { otGroups.append("smoothie") }
        if formData.otCooking { otGroups.append("cooking") }
        if formData.otCurrentAffairs { otGroups.append("current affairs") }
        if formData.otSelfCare { otGroups.append("self care") }
        if formData.otTrips { otGroups.append("OT trips") }
        if formData.otMusic { otGroups.append("music") }
        if formData.otArt { otGroups.append("art") }
        if formData.otGym { otGroups.append("gym") }
        if formData.otWoodwork { otGroups.append("woodwork") }
        if formData.otHorticulture { otGroups.append("horticulture") }
        if formData.otPhysio { otGroups.append("physio") }

        if !otGroups.isEmpty {
            let engagements = ["limited", "mixed", "reasonable", "good", "very good", "excellent"]
            let engagement = engagements[min(formData.otEngagementLevel, engagements.count - 1)]
            parts.append("\(pro) participates in \(otGroups.joined(separator: ", ")) with \(engagement) engagement.")
        }

        // Psychology
        var psychWork: [String] = []
        if formData.psychOneToOne { psychWork.append("1-1 sessions") }
        if formData.psychRisk { psychWork.append("risk work") }
        if formData.psychInsight { psychWork.append("insight work") }
        if formData.psychPsychoeducation { psychWork.append("psychoeducation") }
        if formData.psychManagingEmotions { psychWork.append("managing emotions") }
        if formData.psychDrugsAlcohol { psychWork.append("drugs and alcohol") }
        if formData.psychCarePathway { psychWork.append("care pathway") }
        if formData.psychDischargePlanning { psychWork.append("discharge planning") }

        if !psychWork.isEmpty {
            let engagements = ["limited", "mixed", "reasonable", "good", "very good", "excellent"]
            let engagement = engagements[min(formData.psychEngagementLevel, engagements.count - 1)]
            parts.append("Psychology work includes \(psychWork.joined(separator: ", ")) with \(engagement) engagement.")
        }

        if !formData.addressingIssuesNotes.isEmpty {
            parts.append(formData.addressingIssuesNotes)
        }

        return parts.joined(separator: " ")
    }

    private func generatePatientAttitudeText() -> String {
        let pro = formData.patientGender == .male ? "He" : formData.patientGender == .female ? "She" : "They"
        let has = formData.patientGender == .other ? "have" : "has"
        let pos = formData.patientGender == .male ? "his" : formData.patientGender == .female ? "her" : "their"

        var parts: [String] = []

        // Understanding and compliance
        let treatments: [(String, ASRTreatmentAttitude)] = [
            ("medical", formData.attMedical),
            ("nursing", formData.attNursing),
            ("psychology", formData.attPsychology),
            ("OT", formData.attOT),
            ("social work", formData.attSocialWork)
        ]

        for (name, att) in treatments {
            if att.understanding != .notSelected && att.compliance != .notSelected {
                parts.append("\(pro) \(has) \(att.understanding.rawValue) understanding of \(pos) \(name) treatment and compliance is \(att.compliance.rawValue).")
            }
        }

        // Offending behaviour
        let insights = ["no", "limited", "partial", "good", "full"]
        let responsibilities = ["denies", "minimises", "partially accepts", "mostly accepts", "fully accepts"]
        let empathies = ["no", "limited", "developing", "good", "full"]

        let insight = insights[min(formData.offendingInsightLevel, insights.count - 1)]
        let responsibility = responsibilities[min(formData.responsibilityLevel, responsibilities.count - 1)]
        let empathy = empathies[min(formData.victimEmpathyLevel, empathies.count - 1)]

        parts.append("\(pro) \(has) \(insight) insight into \(pos) offending behaviour, \(responsibility) responsibility, and demonstrates \(empathy) victim empathy.")

        if !formData.offendingDetails.isEmpty {
            parts.append(formData.offendingDetails)
        }

        return parts.joined(separator: " ")
    }

    private func generateCapacityText() -> String {
        let pro = formData.patientGender == .male ? "He" : formData.patientGender == .female ? "She" : "They"
        let has = formData.patientGender == .other ? "have" : "has"

        var parts: [String] = []

        let areas: [(String, ASRCapacityArea)] = [
            ("residence", formData.capResidence),
            ("medication", formData.capMedication),
            ("finances", formData.capFinances),
            ("leave", formData.capLeave)
        ]

        var hasCapacity: [String] = []
        var lacksCapacity: [String] = []

        for (name, area) in areas {
            if area.status == .hasCapacity {
                hasCapacity.append(name)
            } else if area.status == .lacksCapacity {
                var actions: [String] = []
                if area.bestInterest { actions.append("best interest assessment") }
                if area.imca { actions.append("IMCA") }
                if area.dols { actions.append("DoLS") }
                if area.cop { actions.append("COP") }

                if actions.isEmpty {
                    lacksCapacity.append(name)
                } else {
                    lacksCapacity.append("\(name) (\(actions.joined(separator: ", ")))")
                }
            }
        }

        if !hasCapacity.isEmpty {
            parts.append("\(pro) \(has) capacity regarding \(hasCapacity.joined(separator: ", ")).")
        }

        if !lacksCapacity.isEmpty {
            parts.append("\(pro) lacks capacity regarding \(lacksCapacity.joined(separator: ", ")).")
        }

        if !formData.capacityNotes.isEmpty {
            parts.append(formData.capacityNotes)
        }

        return parts.joined(separator: " ")
    }

    private func generateLeaveReportText() -> String {
        var parts: [String] = []

        // Escorted leave
        let escortedText = generateLeaveStateText(state: formData.escortedLeave, escortType: "escorted")
        if !escortedText.isEmpty {
            parts.append(escortedText)
        }

        // Unescorted leave
        let unescortedText = generateLeaveStateText(state: formData.unescortedLeave, escortType: "unescorted")
        if !unescortedText.isEmpty {
            parts.append(unescortedText)
        }

        return parts.joined(separator: "\n\n")
    }

    private func generateLeaveStateText(state: ASRLeaveState, escortType: String) -> String {
        var leaveTypes: [String] = []
        if state.ground.enabled { leaveTypes.append("ground (\(state.ground.weight)%)") }
        if state.local.enabled { leaveTypes.append("local community (\(state.local.weight)%)") }
        if state.community.enabled { leaveTypes.append("community (\(state.community.weight)%)") }
        if state.extended.enabled { leaveTypes.append("extended community (\(state.extended.weight)%)") }
        if state.overnight.enabled { leaveTypes.append("overnight (\(state.overnight.weight)%)") }

        if leaveTypes.isEmpty { return "" }

        var parts: [String] = []
        // Use uppercase to match desktop format (e.g., "ESCORTED LEAVE:")
        parts.append("\(escortType.uppercased()) LEAVE: \(state.leavesPerPeriod) leave(s) \(state.frequency.lowercased()), \(state.duration) duration.")
        parts.append("Leave types: \(leaveTypes.joined(separator: ", ")).")

        var other: [String] = []
        if state.medical { other.append("medical") }
        if state.court { other.append("court") }
        if state.compassionate { other.append("compassionate") }

        if !other.isEmpty {
            parts.append("Other leave includes: \(other.joined(separator: ", ")).")
        }

        if let suspended = state.suspended {
            if suspended {
                parts.append("Leave has been suspended.")
                if !state.suspensionDetails.isEmpty {
                    parts.append(state.suspensionDetails)
                }
            } else {
                parts.append("Leave has not been suspended.")
            }
        }

        return parts.joined(separator: " ")
    }
}

// Keep the old DOCXExporter for backward compatibility (can be removed later)
class DOCXExporter {
    struct TextStyle {
        var bold: Bool = false
        var italic: Bool = false
        var underline: Bool = false
        var strikethrough: Bool = false
        var highlight: String? = nil
        var fontSize: Int = 12
        var fontName: String = "Arial"

        init(bold: Bool = false, italic: Bool = false, underline: Bool = false, strikethrough: Bool = false, highlight: String? = nil, fontSize: Int = 12, fontName: String = "Arial") {
            self.bold = bold
            self.italic = italic
            self.underline = underline
            self.strikethrough = strikethrough
            self.highlight = highlight
            self.fontSize = fontSize
            self.fontName = fontName
        }
    }

    struct Paragraph {
        var runs: [Run]
        var alignment: Alignment = .left
        var spacing: Int = 0

        enum Alignment: String {
            case left = "left"
            case center = "center"
            case right = "right"
            case justify = "both"
        }
    }

    struct Run {
        var text: String
        var style: TextStyle

        init(_ text: String, style: TextStyle = TextStyle()) {
            self.text = text
            self.style = style
        }
    }

    private var paragraphs: [Paragraph] = []

    func addParagraph(_ text: String, style: TextStyle = TextStyle(), alignment: Paragraph.Alignment = .left, spacing: Int = 0) {
        let run = Run(text, style: style)
        let para = Paragraph(runs: [run], alignment: alignment, spacing: spacing)
        paragraphs.append(para)
    }

    func generateDOCX() -> Data? {
        // Minimal implementation - template-based is preferred
        return nil
    }
}

// MARK: - HCR-20 V3 Form DOCX Exporter
// Generates HCR-20 Risk Assessment document from scratch
class HCR20FormDOCXExporter {
    private let formData: HCR20FormData

    init(formData: HCR20FormData) {
        self.formData = formData
    }

    func generateDOCX() -> Data? {
        // Build document XML
        let documentXML = buildDocumentXML()

        // Create minimal DOCX structure (ZIP archive)
        return createDOCXArchive(documentXML: documentXML)
    }

    private func buildDocumentXML() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"

        var body = ""

        // ===== TITLE =====
        body += paragraph("HCR-20 Assessment Report", bold: true, size: 32, alignment: "center")
        body += paragraph("", size: 22)

        // ===== HEADER BOX (bordered fields) =====
        body += borderedField("NAME:", formData.patientName)
        if let dob = formData.patientDOB {
            body += borderedField("D.O.B:", dateFormatter.string(from: dob))
        }
        body += borderedField("NHS NUMBER:", formData.nhsNumber)
        body += borderedField("ADDRESS:", formData.wardName.isEmpty ? formData.hospitalName : "\(formData.wardName), \(formData.hospitalName)")
        if let admission = formData.admissionDate {
            body += borderedField("DATE OF ADMISSION:", dateFormatter.string(from: admission))
        }
        body += borderedField("LEGAL STATUS:", formData.mhaSection)
        body += paragraph("", size: 22)

        // Structured Clinical Judgment section
        body += borderedField("STRUCTURED CLINICAL JUDGMENT", "")
        body += borderedField("TOOLS INCLUDED IN THIS REPORT:", "HCR-20 V3")
        body += borderedField("AUTHOR OF ORIGINAL REPORT:", formData.assessorName)
        if !formData.supervisorName.isEmpty {
            body += borderedField("Under the Supervision of:", formData.supervisorName, labelItalic: true)
        }
        body += borderedField("Date of assessment:", dateFormatter.string(from: formData.assessmentDate))
        body += paragraph("", size: 22)

        // Confidentiality notice
        body += paragraph("This report is CONFIDENTIAL and should be restricted to persons with involvement with the patient. Sections of this report should not be cut and pasted into future reports without the expressed permission of the author.", size: 20)
        body += pageBreak()

        // ===== HCR-20 V3 INTRODUCTION =====
        body += paragraph("HCR-20 V3: RISK ASSESSMENT REPORT", bold: true, size: 28, alignment: "center")
        body += paragraph("", size: 22)

        body += paragraph("HCR-20 V3 (Douglas et al., 2013)", bold: true, size: 22)
        body += paragraph("The HCR-20 V3 is comprised of 20 risk factors across three subscales: Historical, Clinical, and Risk Management.", size: 22)
        body += paragraph("", size: 22)
        body += paragraph("The presence of factors is coded using a 3-level response format:", size: 22)
        body += paragraph("    • N = absent", size: 22)
        body += paragraph("    • P = possibly or partially present", size: 22)
        body += paragraph("    • Y = definitely present", size: 22)
        body += paragraph("", size: 22)
        body += paragraph("\"Omit\" is used when there is no reliable information by which to judge the presence of the factor.", size: 22)
        body += paragraph("", size: 22)
        body += paragraph("Evaluators then assess whether each risk factor is \"relevant\" to an individual's risk for violent behaviour.", size: 22)
        body += paragraph("The relevance of each factor is defined as 'Low', 'Moderate' or 'High'.", size: 22)
        body += paragraph("", size: 22)

        // ===== SOURCES OF INFORMATION =====
        body += paragraph("Sources of information:", bold: true, size: 22)
        body += generateSourcesText()
        body += paragraph("", size: 22)

        // ===== HISTORICAL ITEMS =====
        body += paragraph("Historical items", bold: true, size: 28, underline: true)
        body += hcrItemSection("H1", item: formData.h1, title: "History of Problems with Violence")
        body += hcrItemSection("H2", item: formData.h2, title: "History of Problems with Other Antisocial Behaviour")
        body += hcrItemSection("H3", item: formData.h3, title: "History of Problems with Relationships")
        body += hcrItemSection("H4", item: formData.h4, title: "History of Problems with Employment")
        body += hcrItemSection("H5", item: formData.h5, title: "History of Problems with Substance Use")
        body += hcrItemSection("H6", item: formData.h6, title: "History of Problems with Major Mental Disorder")
        body += hcrItemSection("H7", item: formData.h7, title: "History of Problems with Personality Disorder")
        body += hcrItemSection("H8", item: formData.h8, title: "History of Problems with Traumatic Experiences")
        body += hcrItemSection("H9", item: formData.h9, title: "History of Problems with Violent Attitudes")
        body += hcrItemSection("H10", item: formData.h10, title: "History of Problems with Treatment or Supervision Response")

        // ===== CLINICAL ITEMS =====
        body += pageBreak()
        body += paragraph("Clinical items", bold: true, size: 28, underline: true)
        body += hcrItemSection("C1", item: formData.c1, title: "Recent Problems with Insight")
        body += hcrItemSection("C2", item: formData.c2, title: "Recent Problems with Violent Ideation or Intent")
        body += hcrItemSection("C3", item: formData.c3, title: "Recent Problems with Symptoms of Major Mental Disorder")
        body += hcrItemSection("C4", item: formData.c4, title: "Recent Problems with Instability")
        body += hcrItemSection("C5", item: formData.c5, title: "Recent Problems with Treatment or Supervision Response")

        // ===== RISK MANAGEMENT ITEMS =====
        body += pageBreak()
        body += paragraph("Risk Management items", bold: true, size: 28, underline: true)
        body += hcrItemSection("R1", item: formData.r1, title: "Future Problems with Professional Services and Plans")
        body += hcrItemSection("R2", item: formData.r2, title: "Future Problems with Living Situation")
        body += hcrItemSection("R3", item: formData.r3, title: "Future Problems with Personal Support")
        body += hcrItemSection("R4", item: formData.r4, title: "Future Problems with Treatment or Supervision Response")
        body += hcrItemSection("R5", item: formData.r5, title: "Future Problems with Stress or Coping")

        // ===== VIOLENCE RISK FORMULATION =====
        body += pageBreak()
        body += paragraph("Violence risk formulation", bold: true, size: 28, underline: true)
        if !formData.formulationText.isEmpty {
            body += paragraph(formData.formulationText, size: 22)
        }
        body += paragraph("", size: 22)

        // Scenarios
        body += paragraph("Scenarios (what kind of violence is likely to be committed, victims and likely motivation):", bold: true, size: 22)
        if !formData.scenarioNature.isEmpty {
            body += paragraph(formData.scenarioNature, size: 22)
        }
        body += paragraph("", size: 22)

        body += paragraph("Seriousness (psychological/physical harm to victims, could this escalate to a serious or life-threatening level?):", bold: true, size: 22)
        if !formData.scenarioSeverity.isEmpty {
            body += paragraph(formData.scenarioSeverity, size: 22)
        }
        body += paragraph("", size: 22)

        body += paragraph("Imminence (how soon could the individual engage in violence? What are the warning signs that risk is increasing or imminent?):", bold: true, size: 22)
        if !formData.scenarioImminence.isEmpty {
            body += paragraph(formData.scenarioImminence, size: 22)
        }
        body += paragraph("", size: 22)

        body += paragraph("Frequency/Likelihood (how often might this violence occur? Is the risk chronic or acute?):", bold: true, size: 22)
        if !formData.scenarioFrequency.isEmpty {
            body += paragraph(formData.scenarioFrequency, size: 22)
        }
        body += paragraph("", size: 22)

        // ===== PROPOSED MANAGEMENT STRATEGIES =====
        body += paragraph("Proposed management strategies", bold: true, size: 24, underline: true)

        body += paragraph("Risk-enhancing factors:", bold: true, size: 22)
        if !formData.managementRiskEnhancing.isEmpty {
            body += paragraph(formData.managementRiskEnhancing, size: 22)
        }
        body += paragraph("", size: 22)

        body += paragraph("Protective factors:", bold: true, size: 22)
        if !formData.managementProtective.isEmpty {
            body += paragraph(formData.managementProtective, size: 22)
        }
        body += paragraph("", size: 22)

        body += paragraph("Monitoring:", bold: true, size: 22)
        if !formData.managementMonitoring.isEmpty {
            body += paragraph(formData.managementMonitoring, size: 22)
        }
        body += paragraph("", size: 22)

        // ===== TREATMENT / RECOMMENDATIONS =====
        body += paragraph("Treatment/ Recommendations", bold: true, size: 24, underline: true)
        if !formData.managementTreatment.isEmpty {
            body += paragraph(formData.managementTreatment, size: 22)
        }
        body += paragraph("", size: 22)

        body += paragraph("Supervision", bold: true, size: 22)
        if !formData.managementSupervision.isEmpty {
            body += paragraph(formData.managementSupervision, size: 22)
        }
        body += paragraph("", size: 22)

        body += paragraph("Victim safety planning", bold: true, size: 22)
        if !formData.managementVictimSafety.isEmpty {
            body += paragraph(formData.managementVictimSafety, size: 22)
        }
        body += paragraph("", size: 22)

        // ===== SIGNATURE =====
        body += paragraph("", size: 22)
        body += paragraph(formData.assessorName, bold: true, size: 22)
        body += paragraph(formData.assessorRole, size: 22)
        body += paragraph(dateFormatter.string(from: formData.signatureDate), size: 22)

        return wrapInDocumentXML(body: body)
    }

    private func generateSourcesText() -> String {
        var sources: [String] = []
        if formData.sourcesClinicalNotes { sources.append("Clinical Notes") }
        if formData.sourcesRiskAssessments { sources.append("Previous Risk Assessments") }
        if formData.sourcesForensicHistory { sources.append("Forensic History") }
        if formData.sourcesPsychologyReports { sources.append("Psychology Reports") }
        if formData.sourcesMDTDiscussion { sources.append("MDT Discussion") }
        if formData.sourcesPatientInterview { sources.append("Patient Interview") }
        if formData.sourcesCollateralInfo { sources.append("Collateral Information") }
        if !formData.sourcesOther.isEmpty { sources.append(formData.sourcesOther) }

        if sources.isEmpty && !formData.sourcesOfInformation.isEmpty {
            return paragraph(formData.sourcesOfInformation, size: 22)
        }

        var result = ""
        for source in sources {
            result += paragraph("    • \(source)", size: 22)
        }
        return result
    }

    private func hcrItemSection(_ code: String, item: HCR20ItemData, title: String) -> String {
        var result = ""

        // Item header: "ITEM H1"
        result += paragraph("ITEM \(code)", bold: true, size: 22)

        // Item title (underlined)
        result += paragraph(title, bold: true, size: 22, underline: true)

        // Content
        if !item.text.isEmpty {
            result += paragraph(item.text, size: 22)
        }
        result += paragraph("", size: 22)

        // Presence/Relevance table
        result += presenceRelevanceTable(presence: item.presence, relevance: item.relevance)
        result += paragraph("", size: 22)

        return result
    }

    private func presenceRelevanceTable(presence: HCR20PresenceRating, relevance: HCR20RelevanceRating) -> String {
        let presenceText: String
        switch presence {
        case .absent: presenceText = "Absent"
        case .possible: presenceText = "Possibly/Partially present"
        case .present: presenceText = "Definitely present"
        case .omit: presenceText = "Omit"
        }

        // Simple 2-row table using OOXML
        return """
        <w:tbl>
            <w:tblPr>
                <w:tblStyle w:val="TableGrid"/>
                <w:tblW w:w="5000" w:type="pct"/>
                <w:tblBorders>
                    <w:top w:val="single" w:sz="4" w:space="0" w:color="auto"/>
                    <w:left w:val="single" w:sz="4" w:space="0" w:color="auto"/>
                    <w:bottom w:val="single" w:sz="4" w:space="0" w:color="auto"/>
                    <w:right w:val="single" w:sz="4" w:space="0" w:color="auto"/>
                    <w:insideH w:val="single" w:sz="4" w:space="0" w:color="auto"/>
                    <w:insideV w:val="single" w:sz="4" w:space="0" w:color="auto"/>
                </w:tblBorders>
            </w:tblPr>
            <w:tr>
                <w:tc>
                    <w:tcPr><w:tcW w:w="2500" w:type="pct"/></w:tcPr>
                    <w:p><w:r><w:rPr><w:rFonts w:ascii="Arial Narrow" w:hAnsi="Arial Narrow"/><w:b/><w:sz w:val="22"/></w:rPr><w:t>Presence</w:t></w:r></w:p>
                </w:tc>
                <w:tc>
                    <w:tcPr><w:tcW w:w="2500" w:type="pct"/></w:tcPr>
                    <w:p><w:r><w:rPr><w:rFonts w:ascii="Arial Narrow" w:hAnsi="Arial Narrow"/><w:sz w:val="22"/></w:rPr><w:t>\(escapeXML(presenceText))</w:t></w:r></w:p>
                </w:tc>
            </w:tr>
            <w:tr>
                <w:tc>
                    <w:tcPr><w:tcW w:w="2500" w:type="pct"/></w:tcPr>
                    <w:p><w:r><w:rPr><w:rFonts w:ascii="Arial Narrow" w:hAnsi="Arial Narrow"/><w:b/><w:sz w:val="22"/></w:rPr><w:t>Relevance</w:t></w:r></w:p>
                </w:tc>
                <w:tc>
                    <w:tcPr><w:tcW w:w="2500" w:type="pct"/></w:tcPr>
                    <w:p><w:r><w:rPr><w:rFonts w:ascii="Arial Narrow" w:hAnsi="Arial Narrow"/><w:sz w:val="22"/></w:rPr><w:t>\(escapeXML(relevance.rawValue))</w:t></w:r></w:p>
                </w:tc>
            </w:tr>
        </w:tbl>
        """
    }

    private func borderedField(_ label: String, _ value: String, labelItalic: Bool = false) -> String {
        let escapedLabel = escapeXML(label)
        let escapedValue = escapeXML(value)

        var labelRPr = "<w:rPr><w:rFonts w:ascii=\"Arial Narrow\" w:hAnsi=\"Arial Narrow\"/><w:b/><w:sz w:val=\"22\"/>"
        if labelItalic { labelRPr += "<w:i/>" }
        labelRPr += "</w:rPr>"

        let valueRPr = "<w:rPr><w:rFonts w:ascii=\"Arial Narrow\" w:hAnsi=\"Arial Narrow\"/><w:sz w:val=\"22\"/></w:rPr>"

        // Bordered paragraph with label and value
        return """
        <w:p>
            <w:pPr>
                <w:pBdr>
                    <w:top w:val="single" w:sz="4" w:space="1" w:color="auto"/>
                    <w:left w:val="single" w:sz="4" w:space="4" w:color="auto"/>
                    <w:bottom w:val="single" w:sz="4" w:space="1" w:color="auto"/>
                    <w:right w:val="single" w:sz="4" w:space="4" w:color="auto"/>
                </w:pBdr>
                <w:spacing w:after="0"/>
            </w:pPr>
            <w:r>\(labelRPr)<w:t xml:space="preserve">\(escapedLabel)\t</w:t></w:r>
            <w:r>\(valueRPr)<w:t>\(escapedValue)</w:t></w:r>
        </w:p>
        """
    }

    private func pageBreak() -> String {
        return "<w:p><w:r><w:br w:type=\"page\"/></w:r></w:p>"
    }

    private func paragraph(_ text: String, bold: Bool = false, size: Int = 24, underline: Bool = false, color: String = "000000", alignment: String = "left") -> String {
        let escapedText = escapeXML(text)

        var rPr = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\"/><w:sz w:val=\"\(size)\"/><w:szCs w:val=\"\(size)\"/>"
        if bold { rPr += "<w:b/>" }
        if underline { rPr += "<w:u w:val=\"single\"/>" }
        if color != "000000" { rPr += "<w:color w:val=\"\(color)\"/>" }
        rPr += "</w:rPr>"

        var pPr = "<w:pPr>"
        if alignment == "center" {
            pPr += "<w:jc w:val=\"center\"/>"
        }
        pPr += "<w:spacing w:after=\"120\"/></w:pPr>"

        // Handle line breaks
        let lines = escapedText.components(separatedBy: "\n")
        var runs = ""
        for (idx, line) in lines.enumerated() {
            runs += "<w:r>\(rPr)<w:t xml:space=\"preserve\">\(line)</w:t>"
            if idx < lines.count - 1 {
                runs += "<w:br/>"
            }
            runs += "</w:r>"
        }

        return "<w:p>\(pPr)\(runs)</w:p>"
    }

    private func escapeXML(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "&", with: "&amp;")
        result = result.replacingOccurrences(of: "<", with: "&lt;")
        result = result.replacingOccurrences(of: ">", with: "&gt;")
        result = result.replacingOccurrences(of: "\"", with: "&quot;")
        result = result.replacingOccurrences(of: "'", with: "&apos;")
        return result
    }

    private func wrapInDocumentXML(body: String) -> String {
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
                    xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
            <w:body>
                \(body)
                <w:sectPr>
                    <w:pgSz w:w="12240" w:h="15840"/>
                    <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/>
                </w:sectPr>
            </w:body>
        </w:document>
        """
    }

    private func createDOCXArchive(documentXML: String) -> Data? {
        // DOCX is a ZIP archive with specific structure
        // We need at minimum: [Content_Types].xml, word/document.xml, _rels/.rels, word/_rels/document.xml.rels

        let contentTypes = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
            <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
            <Default Extension="xml" ContentType="application/xml"/>
            <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
        </Types>
        """

        let rootRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
            <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
        </Relationships>
        """

        let docRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        </Relationships>
        """

        // Create ZIP archive
        guard let archive = createZIPArchive(files: [
            ("[Content_Types].xml", contentTypes),
            ("_rels/.rels", rootRels),
            ("word/_rels/document.xml.rels", docRels),
            ("word/document.xml", documentXML)
        ]) else {
            return nil
        }

        return archive
    }

    private func createZIPArchive(files: [(String, String)]) -> Data? {
        // Simple ZIP implementation for DOCX
        var zipData = Data()

        var centralDirectory = Data()
        var localFileOffset: UInt32 = 0
        var fileCount: UInt16 = 0

        for (name, content) in files {
            guard let nameData = name.data(using: .utf8),
                  let contentData = content.data(using: .utf8) else { continue }

            // Local file header
            var localHeader = Data()
            localHeader.append(contentsOf: [0x50, 0x4B, 0x03, 0x04]) // Signature
            localHeader.append(contentsOf: [0x14, 0x00]) // Version needed
            localHeader.append(contentsOf: [0x00, 0x00]) // Flags
            localHeader.append(contentsOf: [0x00, 0x00]) // Compression (stored)
            localHeader.append(contentsOf: [0x00, 0x00]) // Mod time
            localHeader.append(contentsOf: [0x00, 0x00]) // Mod date
            localHeader.append(contentsOf: crc32(contentData)) // CRC-32
            localHeader.append(contentsOf: uint32LE(UInt32(contentData.count))) // Compressed size
            localHeader.append(contentsOf: uint32LE(UInt32(contentData.count))) // Uncompressed size
            localHeader.append(contentsOf: uint16LE(UInt16(nameData.count))) // Name length
            localHeader.append(contentsOf: [0x00, 0x00]) // Extra field length
            localHeader.append(nameData)
            localHeader.append(contentData)

            zipData.append(localHeader)

            // Central directory entry
            var centralEntry = Data()
            centralEntry.append(contentsOf: [0x50, 0x4B, 0x01, 0x02]) // Signature
            centralEntry.append(contentsOf: [0x14, 0x00]) // Version made by
            centralEntry.append(contentsOf: [0x14, 0x00]) // Version needed
            centralEntry.append(contentsOf: [0x00, 0x00]) // Flags
            centralEntry.append(contentsOf: [0x00, 0x00]) // Compression
            centralEntry.append(contentsOf: [0x00, 0x00]) // Mod time
            centralEntry.append(contentsOf: [0x00, 0x00]) // Mod date
            centralEntry.append(contentsOf: crc32(contentData)) // CRC-32
            centralEntry.append(contentsOf: uint32LE(UInt32(contentData.count))) // Compressed size
            centralEntry.append(contentsOf: uint32LE(UInt32(contentData.count))) // Uncompressed size
            centralEntry.append(contentsOf: uint16LE(UInt16(nameData.count))) // Name length
            centralEntry.append(contentsOf: [0x00, 0x00]) // Extra field length
            centralEntry.append(contentsOf: [0x00, 0x00]) // Comment length
            centralEntry.append(contentsOf: [0x00, 0x00]) // Disk number
            centralEntry.append(contentsOf: [0x00, 0x00]) // Internal attributes
            centralEntry.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // External attributes
            centralEntry.append(contentsOf: uint32LE(localFileOffset)) // Offset
            centralEntry.append(nameData)

            centralDirectory.append(centralEntry)

            localFileOffset = UInt32(zipData.count)
            fileCount += 1
        }

        let centralDirectoryOffset = UInt32(zipData.count)
        zipData.append(centralDirectory)

        // End of central directory
        var endRecord = Data()
        endRecord.append(contentsOf: [0x50, 0x4B, 0x05, 0x06]) // Signature
        endRecord.append(contentsOf: [0x00, 0x00]) // Disk number
        endRecord.append(contentsOf: [0x00, 0x00]) // Central directory disk
        endRecord.append(contentsOf: uint16LE(fileCount)) // Entries on this disk
        endRecord.append(contentsOf: uint16LE(fileCount)) // Total entries
        endRecord.append(contentsOf: uint32LE(UInt32(centralDirectory.count))) // Central directory size
        endRecord.append(contentsOf: uint32LE(centralDirectoryOffset)) // Central directory offset
        endRecord.append(contentsOf: [0x00, 0x00]) // Comment length

        zipData.append(endRecord)

        return zipData
    }

    private func uint16LE(_ value: UInt16) -> [UInt8] {
        return [UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF)]
    }

    private func uint32LE(_ value: UInt32) -> [UInt8] {
        return [
            UInt8(value & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 24) & 0xFF)
        ]
    }

    private func crc32(_ data: Data) -> [UInt8] {
        // Simple CRC-32 implementation
        var crc: UInt32 = 0xFFFFFFFF

        let table: [UInt32] = (0..<256).map { i -> UInt32 in
            var c = UInt32(i)
            for _ in 0..<8 {
                if c & 1 == 1 {
                    c = 0xEDB88320 ^ (c >> 1)
                } else {
                    c >>= 1
                }
            }
            return c
        }

        for byte in data {
            crc = table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
        }

        crc = crc ^ 0xFFFFFFFF
        return uint32LE(crc)
    }
}

// MARK: - PTR DOCX Exporter

/// Generates a Word document from Psychiatric Tribunal Report data using the T131 template.
/// Matches the desktop export format: fills table cells, marks Yes/No checkboxes,
/// fills header info box (nested table), signature box, and date character boxes.
class PTRDOCXExporter {

    /// Section content keyed by the iOS PTRSection rawValue
    private let sectionContent: [String: String]
    /// Patient details (structured fields)
    private let patientName: String
    private let patientDOB: Date?
    private let patientAddress: String
    /// Responsible clinician / signature info
    private let rcName: String
    private let rcRole: String
    private let signatureDate: String
    /// Yes/No states for checkbox sections
    private let hasLearningDisability: Bool
    private let detentionAppropriate: Bool
    private let s2DetentionJustified: Bool
    private let otherDetentionJustified: Bool

    init(
        sectionContent: [String: String],
        patientName: String,
        patientDOB: Date?,
        patientAddress: String,
        rcName: String,
        rcRole: String,
        signatureDate: String,
        hasLearningDisability: Bool,
        detentionAppropriate: Bool,
        s2DetentionJustified: Bool,
        otherDetentionJustified: Bool
    ) {
        self.sectionContent = sectionContent
        self.patientName = patientName
        self.patientDOB = patientDOB
        self.patientAddress = patientAddress
        self.rcName = rcName
        self.rcRole = rcRole
        self.signatureDate = signatureDate
        self.hasLearningDisability = hasLearningDisability
        self.detentionAppropriate = detentionAppropriate
        self.s2DetentionJustified = s2DetentionJustified
        self.otherDetentionJustified = otherDetentionJustified
    }

    // MARK: - iOS PTRSection rawValues → desktop card keys

    /// Maps iOS PTRSection rawValues to the desktop card_key used in the table mapping
    private static let sectionKeyMap: [String: String] = [
        "3. Factors affecting understanding": "factors_hearing",
        "4. Adjustments for tribunal": "adjustments",
        "5. Index offence(s) and forensic history": "forensic",
        "6. Previous mental health involvement": "previous_mh_dates",
        "7. Reasons for previous admission": "previous_admission_reasons",
        "8. Circumstances of current admission": "current_admission",
        "9. Mental disorder and diagnosis": "diagnosis",
        "10. Learning disability": "learning_disability",
        "11. Mental disorder requiring detention": "detention_required",
        "12. Medical treatment": "treatment",
        "13. Strengths or positive factors": "strengths",
        "14. Current progress and behaviour": "progress",
        "15. Understanding and compliance": "compliance",
        "16. Deprivation of liberty (MCA 2005)": "mca_dol",
        "17. Incidents of harm to self or others": "risk_harm",
        "18. Incidents of property damage": "risk_property",
        "19. Section 2: Detention justified": "s2_detention",
        "20. Other sections: Treatment justified": "other_detention",
        "21. Risk if discharged": "discharge_risk",
        "22. Community risk management": "community",
        "23. Recommendations to tribunal": "recommendations",
    ]

    /// Desktop table_mapping: table_idx -> (card_key, use_extract_detail)
    /// Tables 5-21 in the T131 template hold section content
    private static let tableMapping: [(tableIdx: Int, cardKey: String, extractDetail: Bool)] = [
        (5, "factors_hearing", true),
        (6, "adjustments", true),
        (7, "forensic", false),
        (8, "previous_mh_dates", false),
        (9, "previous_admission_reasons", false),
        (10, "current_admission", false),
        (11, "diagnosis", true),
        (12, "treatment", false),
        (13, "strengths", false),
        (14, "progress", false),
        (15, "compliance", false),
        (16, "mca_dol", false),
        (17, "risk_harm", false),
        (18, "risk_property", false),
        (19, "discharge_risk", true),
        (20, "community", false),
        (21, "recommendations", true),
    ]

    // Note: hasYesContent() is used ONLY for checkbox marking, not for table content filtering.
    // The iOS app doesn't have separate Yes/No radios for sections 3,4,9,21,23 —
    // users type free-form text, so we always write content to the table.

    /// Checkbox paragraph indices and their corresponding card keys / yes states.
    /// Each pair is (No paragraph index, Yes paragraph index, card key).
    private static let checkboxParagraphs: [(noIdx: Int, yesIdx: Int, cardKey: String)] = [
        (12, 13, "factors_hearing"),
        (16, 17, "adjustments"),
        (28, 29, "diagnosis"),
        (32, 33, "learning_disability"),
        (34, 35, "detention_required"),
        (38, 39, "s2_detention"),          // S2 detention
        (56, 57, "other_detention"),        // Other detention
        (59, 60, "discharge_risk"),         // placeholder — mapped below
        (62, 63, "discharge_risk_actual"),  // placeholder
        (68, 69, "recommendations"),
    ]

    // MARK: - Generate

    func generateDOCX() -> Data? {
        let exporter = TemplateDOCXExporter(templateName: "t131_template_new")
        guard exporter.loadTemplate() else {
            print("[PTRExport] Failed to load t131_template_new template")
            return nil
        }

        // Build content lookup from iOS section rawValues → desktop card keys
        var contentByKey: [String: String] = [:]
        for (sectionRawValue, text) in sectionContent {
            if let key = Self.sectionKeyMap[sectionRawValue] {
                contentByKey[key] = text
            }
        }

        // Debug: log what data we have
        print("[PTRExport] Patient: '\(patientName)', RC: '\(rcName)', Role: '\(rcRole)', Date: '\(signatureDate)'")
        print("[PTRExport] DOB: \(patientDOB != nil ? "set" : "nil"), Address: '\(patientAddress.prefix(40))'")
        print("[PTRExport] Toggles: LD=\(hasLearningDisability), detention=\(detentionAppropriate), s2=\(s2DetentionJustified), other=\(otherDetentionJustified)")
        print("[PTRExport] Content keys: \(contentByKey.keys.sorted())")
        for (key, val) in contentByKey.sorted(by: { $0.key < $1.key }) {
            print("[PTRExport]   \(key): \(val.count) chars, preview='\(String(val.prefix(60)))'")
        }

        // ============================================================
        // TABLE 1: Patient full name
        // ============================================================
        exporter.setTableCellText(tableIndex: 1, row: 0, col: 0, text: patientName)

        // ============================================================
        // TABLE 2: DOB character boxes (1x8, ddmmyyyy)
        // ============================================================
        if let dob = patientDOB {
            let fmt = DateFormatter()
            fmt.dateFormat = "ddMMyyyy"
            let dobStr = fmt.string(from: dob)
            for (i, char) in dobStr.prefix(8).enumerated() {
                exporter.setTableCellText(tableIndex: 2, row: 0, col: i, text: String(char))
            }
        }

        // ============================================================
        // TABLE 3: Residence/address
        // ============================================================
        exporter.setTableCellText(tableIndex: 3, row: 0, col: 0, text: patientAddress)

        // ============================================================
        // TABLE 4: RC Name
        // ============================================================
        exporter.setTableCellText(tableIndex: 4, row: 0, col: 0, text: rcName)

        // ============================================================
        // NESTED TABLE IN TABLE 0: Header info box
        // Row 2: RC name, Row 4: RC role, Row 6: Date
        // ============================================================
        exporter.setNestedTableCellText(outerTableIndex: 0, nestedRow: 2, nestedCol: 0, text: rcName)
        exporter.setNestedTableCellText(outerTableIndex: 0, nestedRow: 4, nestedCol: 0, text: rcRole)
        exporter.setNestedTableCellText(outerTableIndex: 0, nestedRow: 6, nestedCol: 0, text: signatureDate)

        // ============================================================
        // TABLES 5-21: Section content
        // ============================================================
        for mapping in Self.tableMapping {
            guard let content = contentByKey[mapping.cardKey], !content.isEmpty else {
                print("[PTRExport] Table \(mapping.tableIdx) (\(mapping.cardKey)): SKIPPED (empty)")
                continue
            }

            // For extractDetail sections, strip Yes/No prefix but always write content
            let textToWrite = mapping.extractDetail ? extractDetail(content) : content
            guard !textToWrite.isEmpty else {
                print("[PTRExport] Table \(mapping.tableIdx) (\(mapping.cardKey)): SKIPPED (extractDetail empty)")
                continue
            }
            print("[PTRExport] Table \(mapping.tableIdx) (\(mapping.cardKey)): WRITING \(textToWrite.count) chars")
            exporter.setTableCellText(tableIndex: mapping.tableIdx, row: 0, col: 0, text: textToWrite)
        }

        // ============================================================
        // CHECKBOXES: Mark ☐ → ☒ based on content/state
        // ============================================================
        markCheckboxes(exporter: exporter, contentByKey: contentByKey)

        // ============================================================
        // TABLE 22: Signature box
        // ============================================================
        var sigParts: [String] = []
        if !rcName.isEmpty { sigParts.append(rcName) }
        if !rcRole.isEmpty { sigParts.append(rcRole) }
        exporter.setTableCellText(tableIndex: 22, row: 0, col: 0, text: sigParts.joined(separator: "\n"))

        // ============================================================
        // TABLE 23: Date character boxes (1x8, ddmmyyyy)
        // ============================================================
        let dateClean = parseDateToCharBoxes(signatureDate)
        for (i, char) in dateClean.prefix(8).enumerated() {
            exporter.setTableCellText(tableIndex: 23, row: 0, col: i, text: String(char))
        }

        return exporter.generateDOCX()
    }

    // MARK: - Checkbox Marking

    private func markCheckboxes(exporter: TemplateDOCXExporter, contentByKey: [String: String]) {
        print("[PTRExport] Marking checkboxes...")

        // factors_hearing: paras 32(No), 33(Yes)
        let fhYes = hasYesContent(contentByKey["factors_hearing"] ?? "")
        print("[PTRExport]   factors_hearing: \(fhYes ? "YES→33" : "NO→32")")
        markYesNo(exporter: exporter, noIdx: 32, yesIdx: 33, isYes: fhYes)

        // adjustments: paras 37(No), 38(Yes)
        markYesNo(exporter: exporter, noIdx: 37, yesIdx: 38,
                  isYes: hasYesContent(contentByKey["adjustments"] ?? ""))

        // diagnosis: paras 54(No), 55(Yes)
        markYesNo(exporter: exporter, noIdx: 54, yesIdx: 55,
                  isYes: hasYesContent(contentByKey["diagnosis"] ?? ""))

        // learning_disability: paras 59(No), 60(Yes) — uses form toggle
        markYesNo(exporter: exporter, noIdx: 59, yesIdx: 60,
                  isYes: hasLearningDisability)

        // learning_disability sub-question (aggressive conduct): paras 61(No), 62(Yes)
        // Mark Yes if learning disability is present (same toggle)
        markYesNo(exporter: exporter, noIdx: 61, yesIdx: 62,
                  isYes: hasLearningDisability)

        // detention_required: paras 65(No), 66(Yes) — uses form toggle
        markYesNo(exporter: exporter, noIdx: 65, yesIdx: 66,
                  isYes: detentionAppropriate)

        // s2_detention: paras 90(No), 91(Yes) — uses form toggle
        markYesNo(exporter: exporter, noIdx: 90, yesIdx: 91,
                  isYes: s2DetentionJustified)

        // other_detention: paras 93(No), 94(Yes) — uses form toggle
        markYesNo(exporter: exporter, noIdx: 93, yesIdx: 94,
                  isYes: otherDetentionJustified)

        // discharge_risk: paras 96(No), 97(Yes)
        markYesNo(exporter: exporter, noIdx: 96, yesIdx: 97,
                  isYes: hasYesContent(contentByKey["discharge_risk"] ?? ""))

        // recommendations: paras 104(No), 105(Yes)
        markYesNo(exporter: exporter, noIdx: 104, yesIdx: 105,
                  isYes: hasYesContent(contentByKey["recommendations"] ?? ""))
    }

    /// Mark the appropriate checkbox (Yes or No) by replacing ☐ → ☒
    private func markYesNo(exporter: TemplateDOCXExporter, noIdx: Int, yesIdx: Int, isYes: Bool) {
        if isYes {
            exporter.markCheckbox(at: yesIdx)
        } else {
            exporter.markCheckbox(at: noIdx)
        }
    }

    // MARK: - Helpers (matching desktop logic)

    /// Check if content indicates a Yes answer (desktop: has_yes_content)
    private func hasYesContent(_ content: String) -> Bool {
        let lower = content.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if lower.isEmpty || lower == "no" { return false }

        let noPatterns = [
            "no ", "no,", "no-", "no.",
            "there have been no", "there is no",
            "no incidents", "no factors", "no adjustments",
            "does not have", "not applicable", "n/a",
        ]
        for pattern in noPatterns {
            if lower.hasPrefix(pattern) || lower.contains(pattern) {
                return false
            }
        }
        return true
    }

    /// Extract detail text after Yes/No prefix (desktop: extract_detail)
    private func extractDetail(_ content: String) -> String {
        let lower = content.lowercased()
        let prefixes = ["yes, ", "yes - ", "yes-", "yes,", "yes.", "no, ", "no - ", "no-", "no,", "no."]
        for prefix in prefixes {
            if lower.hasPrefix(prefix) {
                let detail = String(content.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                return detail
            }
        }
        if lower == "yes" || lower == "no" { return "" }
        return content
    }

    /// Parse a date string into ddmmyyyy for character boxes
    private func parseDateToCharBoxes(_ dateStr: String) -> String {
        let formats = ["dd/MM/yyyy", "dd-MM-yyyy", "dd.MM.yyyy", "dd MMMM yyyy", "dd MMM yyyy", "yyyy-MM-dd"]
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_GB")

        for format in formats {
            fmt.dateFormat = format
            if let date = fmt.date(from: dateStr.trimmingCharacters(in: .whitespacesAndNewlines)) {
                fmt.dateFormat = "ddMMyyyy"
                return fmt.string(from: date)
            }
        }

        // Fallback: strip non-digits
        let digitsOnly = dateStr.filter { $0.isNumber }
        if digitsOnly.count == 6 {
            let yearPart = String(digitsOnly.suffix(2))
            let year = (Int(yearPart) ?? 0) < 50 ? "20" + yearPart : "19" + yearPart
            return String(digitsOnly.prefix(4)) + year
        }
        return digitsOnly
    }
}

// MARK: - NTR DOCX Exporter

/// Generates a Word document from Nursing Tribunal Report data using the T134 template.
/// Matches the desktop export format: fills table cells, marks Yes/No checkboxes,
/// fills header info box (nested table), signature box, and date character boxes.
class NTRDOCXExporter {

    private let sectionContent: [String: String]
    private let patientName: String
    private let patientDOB: Date?
    private let patientAddress: String
    private let nurseName: String
    private let nurseRole: String
    private let signatureDate: String
    // Yes/No checkbox states
    private let hasFactors: Bool
    private let hasAdj: Bool
    private let hasContact: Bool
    private let seclusionUsed: Bool
    private let s2OK: Bool
    private let otherOK: Bool
    private let hasDR: Bool
    private let hasOI: Bool
    private let hasRec: Bool

    init(
        sectionContent: [String: String],
        patientName: String,
        patientDOB: Date?,
        patientAddress: String,
        nurseName: String,
        nurseRole: String,
        signatureDate: String,
        hasFactors: Bool,
        hasAdj: Bool,
        hasContact: Bool,
        seclusionUsed: Bool,
        s2OK: Bool,
        otherOK: Bool,
        hasDR: Bool,
        hasOI: Bool,
        hasRec: Bool
    ) {
        self.sectionContent = sectionContent
        self.patientName = patientName
        self.patientDOB = patientDOB
        self.patientAddress = patientAddress
        self.nurseName = nurseName
        self.nurseRole = nurseRole
        self.signatureDate = signatureDate
        self.hasFactors = hasFactors
        self.hasAdj = hasAdj
        self.hasContact = hasContact
        self.seclusionUsed = seclusionUsed
        self.s2OK = s2OK
        self.otherOK = otherOK
        self.hasDR = hasDR
        self.hasOI = hasOI
        self.hasRec = hasRec
    }

    /// Maps iOS NTRSection rawValues to the desktop card keys
    private static let sectionKeyMap: [String: String] = [
        "2. Factors affecting understanding": "factors_hearing",
        "3. Adjustments for tribunal": "adjustments",
        "4. Nature of nursing care": "nursing_care",
        "5. Level of observation": "observation_level",
        "6. Contact with relatives/friends": "contact",
        "7. Community support": "community_support",
        "8. Strengths or positive factors": "strengths",
        "9. Current progress and engagement": "progress",
        "10. AWOL or failed return": "awol",
        "11. Compliance with treatment": "compliance",
        "12. Incidents of harm": "risk_harm",
        "13. Incidents of property damage": "risk_property",
        "14. Seclusion or restraint": "seclusion",
        "17. Risk if discharged": "discharge_risk",
        "18. Community risk management": "community",
        "19. Other relevant information": "other_info",
        "20. Recommendations to tribunal": "recommendations",
    ]

    /// Desktop table_mapping: table_idx -> (card_key, use_extract_detail)
    /// Tables 4-20 in the T134 template hold section content
    private static let tableMapping: [(tableIdx: Int, cardKey: String, extractDetail: Bool)] = [
        (4, "factors_hearing", true),
        (5, "adjustments", true),
        (6, "nursing_care", false),
        (7, "observation_level", false),
        (8, "contact", true),
        (9, "community_support", false),
        (10, "strengths", false),
        (11, "progress", false),
        (12, "awol", false),
        (13, "compliance", false),
        (14, "risk_harm", false),
        (15, "risk_property", false),
        (16, "seclusion", true),
        (17, "discharge_risk", true),
        (18, "community", false),
        (19, "other_info", true),
        (20, "recommendations", true),
    ]

    func generateDOCX() -> Data? {
        let exporter = TemplateDOCXExporter(templateName: "t134_template_new")
        guard exporter.loadTemplate() else {
            print("[NTRExport] Failed to load t134_template_new template")
            return nil
        }

        // Build content lookup from iOS section rawValues → desktop card keys
        var contentByKey: [String: String] = [:]
        for (sectionRawValue, text) in sectionContent {
            if let key = Self.sectionKeyMap[sectionRawValue] {
                contentByKey[key] = text
            }
        }

        print("[NTRExport] Patient: '\(patientName)', Nurse: '\(nurseName)', Role: '\(nurseRole)', Date: '\(signatureDate)'")
        print("[NTRExport] Content keys: \(contentByKey.keys.sorted())")

        // ============================================================
        // TABLE 0 nested: Header info box
        // Row 2: name, Row 4: role, Row 6: date
        // ============================================================
        exporter.setNestedTableCellText(outerTableIndex: 0, nestedRow: 2, nestedCol: 0, text: nurseName)
        exporter.setNestedTableCellText(outerTableIndex: 0, nestedRow: 4, nestedCol: 0, text: nurseRole)
        exporter.setNestedTableCellText(outerTableIndex: 0, nestedRow: 6, nestedCol: 0, text: signatureDate)

        // ============================================================
        // TABLE 2: Patient full name
        // ============================================================
        exporter.setTableCellText(tableIndex: 2, row: 0, col: 0, text: patientName)

        // ============================================================
        // TABLE 3: DOB character boxes (8 cols, ddMMyyyy)
        // ============================================================
        if let dob = patientDOB {
            let fmt = DateFormatter()
            fmt.dateFormat = "ddMMyyyy"
            let dobStr = fmt.string(from: dob)
            for (i, char) in dobStr.prefix(8).enumerated() {
                exporter.setTableCellText(tableIndex: 3, row: 0, col: i, text: String(char))
            }
        }

        // ============================================================
        // TABLE 4: Residence
        // ============================================================
        // Note: Table 4 is also the first content table (factors_hearing).
        // The residence goes in a separate location — check if there's a
        // dedicated residence table. In T134, Table 1 may hold this.
        // For now, skip dedicated residence — the address is part of patient details.

        // ============================================================
        // TABLES 4-20: Section content
        // ============================================================
        for mapping in Self.tableMapping {
            guard let content = contentByKey[mapping.cardKey], !content.isEmpty else {
                print("[NTRExport] Table \(mapping.tableIdx) (\(mapping.cardKey)): SKIPPED (empty)")
                continue
            }

            let textToWrite = mapping.extractDetail ? extractDetail(content) : content
            guard !textToWrite.isEmpty else {
                print("[NTRExport] Table \(mapping.tableIdx) (\(mapping.cardKey)): SKIPPED (extractDetail empty)")
                continue
            }
            print("[NTRExport] Table \(mapping.tableIdx) (\(mapping.cardKey)): WRITING \(textToWrite.count) chars")
            exporter.setTableCellText(tableIndex: mapping.tableIdx, row: 0, col: 0, text: textToWrite)
        }

        // ============================================================
        // CHECKBOXES: Mark Yes/No based on content/state
        // ============================================================
        markCheckboxes(exporter: exporter, contentByKey: contentByKey)

        // ============================================================
        // TABLE 21: Signature text
        // ============================================================
        var sigParts: [String] = []
        if !nurseName.isEmpty { sigParts.append(nurseName) }
        if !nurseRole.isEmpty { sigParts.append(nurseRole) }
        exporter.setTableCellText(tableIndex: 21, row: 0, col: 0, text: sigParts.joined(separator: "\n"))

        // ============================================================
        // TABLE 23: Date character boxes (8 cols, ddMMyyyy)
        // ============================================================
        let dateClean = parseDateToCharBoxes(signatureDate)
        for (i, char) in dateClean.prefix(8).enumerated() {
            exporter.setTableCellText(tableIndex: 23, row: 0, col: i, text: String(char))
        }

        return exporter.generateDOCX()
    }

    private func markCheckboxes(exporter: TemplateDOCXExporter, contentByKey: [String: String]) {
        print("[NTRExport] Marking checkboxes...")

        // Section 2 factors: P026(No), P027(Yes)
        markYesNo(exporter: exporter, noIdx: 26, yesIdx: 27, isYes: hasFactors)

        // Section 3 adjustments: P031(No), P032(Yes)
        markYesNo(exporter: exporter, noIdx: 31, yesIdx: 32, isYes: hasAdj)

        // Section 6 contact: P042(No), P043(Yes)
        markYesNo(exporter: exporter, noIdx: 42, yesIdx: 43,
                  isYes: hasYesContent(contentByKey["contact"] ?? ""))

        // Section 14 seclusion: P068(No), P069(Yes)
        markYesNo(exporter: exporter, noIdx: 68, yesIdx: 69, isYes: seclusionUsed)

        // Section 15 s2_detention: P073(No), P074(Yes)
        markYesNo(exporter: exporter, noIdx: 73, yesIdx: 74, isYes: s2OK)

        // Section 16 other_detention: P076(No), P077(Yes)
        markYesNo(exporter: exporter, noIdx: 76, yesIdx: 77, isYes: otherOK)

        // Section 17 discharge_risk: P079(No), P080(Yes)
        markYesNo(exporter: exporter, noIdx: 79, yesIdx: 80,
                  isYes: hasYesContent(contentByKey["discharge_risk"] ?? ""))

        // Section 19 other_info: P087(No), P088(Yes)
        markYesNo(exporter: exporter, noIdx: 87, yesIdx: 88,
                  isYes: hasYesContent(contentByKey["other_info"] ?? ""))

        // Section 20 recommendations: P092(No), P093(Yes)
        markYesNo(exporter: exporter, noIdx: 92, yesIdx: 93,
                  isYes: hasYesContent(contentByKey["recommendations"] ?? ""))
    }

    private func markYesNo(exporter: TemplateDOCXExporter, noIdx: Int, yesIdx: Int, isYes: Bool) {
        if isYes {
            exporter.markCheckbox(at: yesIdx)
        } else {
            exporter.markCheckbox(at: noIdx)
        }
    }

    private func hasYesContent(_ content: String) -> Bool {
        let lower = content.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if lower.isEmpty || lower == "no" { return false }
        let noPatterns = [
            "no ", "no,", "no-", "no.",
            "there have been no", "there is no",
            "no incidents", "no factors", "no adjustments",
            "does not have", "not applicable", "n/a",
        ]
        for pattern in noPatterns {
            if lower.hasPrefix(pattern) || lower.contains(pattern) { return false }
        }
        return true
    }

    private func extractDetail(_ content: String) -> String {
        let lower = content.lowercased()
        let prefixes = ["yes, ", "yes - ", "yes-", "yes,", "yes.", "no, ", "no - ", "no-", "no,", "no."]
        for prefix in prefixes {
            if lower.hasPrefix(prefix) {
                return String(content.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        if lower == "yes" || lower == "no" { return "" }
        return content
    }

    private func parseDateToCharBoxes(_ dateStr: String) -> String {
        let formats = ["dd/MM/yyyy", "dd-MM-yyyy", "dd.MM.yyyy", "dd MMMM yyyy", "dd MMM yyyy", "yyyy-MM-dd"]
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_GB")
        for format in formats {
            fmt.dateFormat = format
            if let date = fmt.date(from: dateStr.trimmingCharacters(in: .whitespacesAndNewlines)) {
                fmt.dateFormat = "ddMMyyyy"
                return fmt.string(from: date)
            }
        }
        let digitsOnly = dateStr.filter { $0.isNumber }
        if digitsOnly.count == 6 {
            let yearPart = String(digitsOnly.suffix(2))
            let year = (Int(yearPart) ?? 0) < 50 ? "20" + yearPart : "19" + yearPart
            return String(digitsOnly.prefix(4)) + year
        }
        return digitsOnly
    }
}

// MARK: - SCT DOCX Exporter

/// Generates a Word document from Social Circumstances Tribunal Report data using the T133 template.
/// Matches the desktop export format: fills table cells, marks Yes/No checkboxes via text-pattern search,
/// fills header info box (nested table), signature box, and date character boxes.
class SCTDOCXExporter {

    private let sectionContent: [String: String]
    private let patientName: String
    private let patientDOB: Date?
    private let patientAddress: String
    private let socialWorkerName: String
    private let socialWorkerRole: String
    private let signatureDate: String
    // Yes/No checkbox states
    private let hasFactors: Bool
    private let hasAdj: Bool
    private let hasEmployment: Bool
    private let hasFunding: Bool
    private let hasMappa: Bool
    private let s2OK: Bool
    private let otherOK: Bool
    private let hasDR: Bool
    private let hasOI: Bool
    private let hasRec: Bool

    init(
        sectionContent: [String: String],
        patientName: String,
        patientDOB: Date?,
        patientAddress: String,
        socialWorkerName: String,
        socialWorkerRole: String,
        signatureDate: String,
        hasFactors: Bool,
        hasAdj: Bool,
        hasEmployment: Bool,
        hasFunding: Bool,
        hasMappa: Bool,
        s2OK: Bool,
        otherOK: Bool,
        hasDR: Bool,
        hasOI: Bool,
        hasRec: Bool
    ) {
        self.sectionContent = sectionContent
        self.patientName = patientName
        self.patientDOB = patientDOB
        self.patientAddress = patientAddress
        self.socialWorkerName = socialWorkerName
        self.socialWorkerRole = socialWorkerRole
        self.signatureDate = signatureDate
        self.hasFactors = hasFactors
        self.hasAdj = hasAdj
        self.hasEmployment = hasEmployment
        self.hasFunding = hasFunding
        self.hasMappa = hasMappa
        self.s2OK = s2OK
        self.otherOK = otherOK
        self.hasDR = hasDR
        self.hasOI = hasOI
        self.hasRec = hasRec
    }

    /// Maps iOS STRSection rawValues to desktop card keys
    private static let sectionKeyMap: [String: String] = [
        "1. Patient Details": "patient_details",
        "2. Factors affecting understanding": "factors_hearing",
        "3. Adjustments for tribunal": "adjustments",
        "4. Index offence(s) and forensic history": "forensic",
        "5. Previous MH involvement": "previous_mh_dates",
        "6. Home and family circumstances": "home_family",
        "7. Housing or accommodation": "housing",
        "8. Financial position": "financial",
        "9. Employment opportunities": "employment",
        "10. Previous community support": "previous_community",
        "11. Care pathway and Section 117": "care_pathway",
        "12. Proposed care plan": "care_plan",
        "13. Adequacy of care plan": "care_plan_adequacy",
        "14. Funding issues": "care_plan_funding",
        "15. Strengths or positive factors": "strengths",
        "16. Current progress": "progress",
        "17. Incidents of harm": "risk_harm",
        "18. Incidents of property damage": "risk_property",
        "19. Patient's views and wishes": "patient_views",
        "20. Nearest Relative views": "nearest_relative",
        "21. NR consultation inappropriate": "nr_inappropriate",
        "22. Carer views": "carer_views",
        "23. MAPPA involvement": "mappa",
        "24. MCA 2005 deprivation of liberty": "mca_dol",
        "25. Section 2: Detention justified": "s2_detention",
        "26. Other sections: Treatment justified": "other_detention",
        "27. Risk if discharged": "discharge_risk",
        "28. Community risk management": "community",
        "29. Other relevant information": "other_info",
        "30. Recommendations to tribunal": "recommendations",
        "31. Signature": "signature",
    ]

    /// Desktop table_mapping: table_idx -> (card_key, use_extract_detail)
    /// Tables 4-31 in the T133 template hold section content
    private static let tableMapping: [(tableIdx: Int, cardKey: String, extractDetail: Bool)] = [
        (4, "factors_hearing", true),
        (5, "adjustments", true),
        (6, "forensic", false),
        (7, "previous_mh_dates", false),
        (8, "home_family", false),
        (9, "housing", false),
        (10, "financial", false),
        (11, "employment", true),
        (12, "previous_community", false),
        (13, "care_pathway", false),
        (14, "care_plan", false),
        (15, "care_plan_adequacy", false),
        // Table 16 = funding date boxes, handled separately
        (17, "strengths", false),
        (18, "progress", false),
        (19, "risk_harm", false),
        (20, "risk_property", false),
        (21, "patient_views", false),
        (22, "nearest_relative", false),
        (23, "nr_inappropriate", false),
        (24, "carer_views", false),
        (25, "mappa", true),
        // Tables 26-27 = MAPPA chair/agency, skip
        (28, "mca_dol", false),
        (29, "discharge_risk", true),
        (30, "other_info", true),
        (31, "recommendations", true),
    ]

    /// Checkbox text patterns mapping paragraph heading text → content key
    /// Used for text-pattern-based checkbox marking (instead of paragraph indices)
    private static let checkboxPatterns: [(pattern: String, key: String)] = [
        ("factors that may affect", "factors_hearing"),
        ("any adjustments", "adjustments"),
        ("opportunities for employment", "employment"),
        ("issues as to funding", "care_plan_funding"),
        ("mappa meeting", "mappa"),
        ("section 2 cases", "s2_detention"),
        ("in all other cases", "other_detention"),
        ("discharged from hospital", "discharge_risk"),
        ("other relevant information", "other_info"),
        ("recommendations to the tribunal", "recommendations"),
    ]

    func generateDOCX() -> Data? {
        let exporter = TemplateDOCXExporter(templateName: "t133_template_new")
        guard exporter.loadTemplate() else {
            print("[SCTExport] Failed to load t133_template_new template")
            return nil
        }

        // Build content lookup from iOS section rawValues → desktop card keys
        var contentByKey: [String: String] = [:]
        for (sectionRawValue, text) in sectionContent {
            if let key = Self.sectionKeyMap[sectionRawValue] {
                contentByKey[key] = text
            }
        }

        print("[SCTExport] Patient: '\(patientName)', SW: '\(socialWorkerName)', Role: '\(socialWorkerRole)', Date: '\(signatureDate)'")
        print("[SCTExport] Content keys: \(contentByKey.keys.sorted())")

        // ============================================================
        // TABLE 0 nested: Header info box
        // Row 2: name, Row 4: role, Row 6: date
        // ============================================================
        exporter.setNestedTableCellText(outerTableIndex: 0, nestedRow: 2, nestedCol: 0, text: socialWorkerName)
        exporter.setNestedTableCellText(outerTableIndex: 0, nestedRow: 4, nestedCol: 0, text: socialWorkerRole)
        exporter.setNestedTableCellText(outerTableIndex: 0, nestedRow: 6, nestedCol: 0, text: signatureDate)

        // ============================================================
        // TABLE 1: Patient full name (row 0, col 1)
        // ============================================================
        exporter.setTableCellText(tableIndex: 1, row: 0, col: 1, text: patientName)

        // ============================================================
        // TABLE 2: DOB character boxes (8 cols, ddMMyyyy)
        // ============================================================
        if let dob = patientDOB {
            let fmt = DateFormatter()
            fmt.dateFormat = "ddMMyyyy"
            let dobStr = fmt.string(from: dob)
            for (i, char) in dobStr.prefix(8).enumerated() {
                exporter.setTableCellText(tableIndex: 2, row: 0, col: i, text: String(char))
            }
        }

        // ============================================================
        // TABLE 3: Residence/address
        // ============================================================
        if !patientAddress.isEmpty {
            exporter.setTableCellText(tableIndex: 3, row: 0, col: 0, text: patientAddress)
        }

        // ============================================================
        // TABLES 4-31: Section content
        // ============================================================
        for mapping in Self.tableMapping {
            guard let content = contentByKey[mapping.cardKey], !content.isEmpty else {
                print("[SCTExport] Table \(mapping.tableIdx) (\(mapping.cardKey)): SKIPPED (empty)")
                continue
            }

            let textToWrite = mapping.extractDetail ? extractDetail(content) : content
            guard !textToWrite.isEmpty else {
                print("[SCTExport] Table \(mapping.tableIdx) (\(mapping.cardKey)): SKIPPED (extractDetail empty)")
                continue
            }
            print("[SCTExport] Table \(mapping.tableIdx) (\(mapping.cardKey)): WRITING \(textToWrite.count) chars")
            exporter.setTableCellText(tableIndex: mapping.tableIdx, row: 0, col: 0, text: textToWrite)
        }

        // ============================================================
        // TABLE 29 special: Append community content after discharge_risk
        // ============================================================
        if let communityContent = contentByKey["community"], !communityContent.isEmpty {
            let drContent = contentByKey["discharge_risk"] ?? ""
            let drText = drContent.isEmpty ? "" : extractDetail(drContent)
            let combined: String
            if drText.isEmpty {
                combined = communityContent
            } else {
                combined = drText + "\n\n" + communityContent
            }
            print("[SCTExport] Table 29: APPENDING community content (\(communityContent.count) chars)")
            exporter.setTableCellText(tableIndex: 29, row: 0, col: 0, text: combined)
        }

        // ============================================================
        // CHECKBOXES: Mark Yes/No via text-pattern search
        // ============================================================
        markCheckboxesByPattern(exporter: exporter, contentByKey: contentByKey)

        // ============================================================
        // TABLE 32: Signature text
        // ============================================================
        var sigParts: [String] = []
        if !socialWorkerName.isEmpty { sigParts.append(socialWorkerName) }
        if !socialWorkerRole.isEmpty { sigParts.append(socialWorkerRole) }
        exporter.setTableCellText(tableIndex: 32, row: 0, col: 0, text: sigParts.joined(separator: "\n"))

        // ============================================================
        // TABLE 33: Date character boxes (8 cols, ddMMyyyy)
        // ============================================================
        let dateClean = parseDateToCharBoxes(signatureDate)
        for (i, char) in dateClean.prefix(8).enumerated() {
            exporter.setTableCellText(tableIndex: 33, row: 0, col: i, text: String(char))
        }

        return exporter.generateDOCX()
    }

    /// Marks Yes/No checkboxes by scanning all paragraphs for heading patterns,
    /// then replacing ☐ with ☒ based on content analysis.
    /// This is more robust than using paragraph indices since we don't need to know
    /// the exact paragraph numbers in the T133 template.
    private func markCheckboxesByPattern(exporter: TemplateDOCXExporter, contentByKey: [String: String]) {
        print("[SCTExport] Marking checkboxes by pattern...")

        let paragraphs = exporter.getParagraphs()
        var currentSectionKey: String? = nil

        for (idx, para) in paragraphs.enumerated() {
            let lowerContent = para.content.lowercased()

            // Check if this paragraph matches a heading pattern
            for cp in Self.checkboxPatterns {
                if lowerContent.contains(cp.pattern) {
                    currentSectionKey = cp.key
                    break
                }
            }

            // Check if this paragraph contains an unchecked checkbox
            guard para.content.contains("☐"), let sectionKey = currentSectionKey else {
                continue
            }

            // Determine if this is a Yes or No line
            let isYesLine = lowerContent.contains("yes") && !lowerContent.prefix(10).contains("no")
            let isNoLine = lowerContent.hasPrefix("☐ no") ||
                           lowerContent.hasPrefix("☐ n") ||
                           (lowerContent.contains("no") && !lowerContent.contains("yes"))

            // Get the answer for this section
            let isYes: Bool
            switch sectionKey {
            case "s2_detention":
                isYes = s2OK
            case "other_detention":
                isYes = otherOK
            default:
                let content = contentByKey[sectionKey] ?? ""
                isYes = hasYesContent(content)
            }

            // Mark the checkbox if it matches the answer
            if (isYes && isYesLine) || (!isYes && isNoLine) {
                print("[SCTExport]   Marking checkbox at paragraph \(idx) for \(sectionKey) (\(isYes ? "Yes" : "No"))")
                exporter.markCheckbox(at: idx)
            }
        }
    }

    private func hasYesContent(_ content: String) -> Bool {
        let lower = content.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if lower.isEmpty || lower == "no" { return false }
        let noPatterns = [
            "no ", "no,", "no-", "no.",
            "there have been no", "there is no",
            "no incidents", "no factors", "no adjustments",
            "does not have", "not applicable", "n/a",
        ]
        for pattern in noPatterns {
            if lower.hasPrefix(pattern) || lower.contains(pattern) { return false }
        }
        return true
    }

    private func extractDetail(_ content: String) -> String {
        let lower = content.lowercased()
        let prefixes = ["yes, ", "yes - ", "yes-", "yes,", "yes.", "no, ", "no - ", "no-", "no,", "no."]
        for prefix in prefixes {
            if lower.hasPrefix(prefix) {
                return String(content.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        if lower == "yes" || lower == "no" { return "" }
        return content
    }

    private func parseDateToCharBoxes(_ dateStr: String) -> String {
        let formats = ["dd/MM/yyyy", "dd-MM-yyyy", "dd.MM.yyyy", "dd MMMM yyyy", "dd MMM yyyy", "yyyy-MM-dd"]
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_GB")
        for format in formats {
            fmt.dateFormat = format
            if let date = fmt.date(from: dateStr.trimmingCharacters(in: .whitespacesAndNewlines)) {
                fmt.dateFormat = "ddMMyyyy"
                return fmt.string(from: date)
            }
        }
        let digitsOnly = dateStr.filter { $0.isNumber }
        if digitsOnly.count == 6 {
            let yearPart = String(digitsOnly.suffix(2))
            let year = (Int(yearPart) ?? 0) < 50 ? "20" + yearPart : "19" + yearPart
            return String(digitsOnly.prefix(4)) + year
        }
        return digitsOnly
    }
}
