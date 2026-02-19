//
//  DocumentProcessor.swift
//  MyPsychAdmin
//
//  Ported from desktop Python importers:
//  - importer_rio.py
//  - importer_carenotes.py
//  - importer_epjs.py
//  - importer_autodetect.py
//

import Foundation
import PDFKit
import Vision
import Compression

// MARK: - Document Processor
actor DocumentProcessor {
    static let shared = DocumentProcessor()
    private init() {}

    // MARK: - Pre-compiled Regex Patterns (for performance)
    private static let dateRegex1 = try! NSRegularExpression(pattern: "^\\d{1,2}/\\d{1,2}/\\d{4}$")
    private static let dateRegex2 = try! NSRegularExpression(pattern: "^\\d{4}-\\d{2}-\\d{2}$")
    private static let dateRegex3 = try! NSRegularExpression(pattern: "^\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}(:\\d{2})?$")
    private static let timeRegex = try! NSRegularExpression(pattern: "^\\d{1,2}:\\d{2}(:\\d{2})?$")
    private static let epjsDateTimeRegex = try! NSRegularExpression(pattern: "^(\\d{1,2}\\s+[A-Za-z]{3}\\s+\\d{4})\\s+(\\d{1,2}:\\d{2})$")
    private static let longDashPattern = try! NSRegularExpression(pattern: "-{20,}\\s*\\d{1,2}\\s+[A-Za-z]{3}\\s+\\d{4}\\s+\\d{1,2}:\\d{2},")
    private static let careNotesSignaturePattern = try! NSRegularExpression(pattern: "-{2,}\\s*[^,]+,\\s*,\\s*\\d{1,2}/\\d{1,2}/\\d{4}")
    private static let bracketTypePattern = try! NSRegularExpression(pattern: "\\[([^\\]]+)\\]")
    private static let epjsSigPattern = try! NSRegularExpression(pattern: "-{20,}\\s*(\\d{1,2}\\s+[A-Za-z]{3}\\s+\\d{4})\\s+(\\d{1,2}:\\d{2})\\s*,\\s*([^,]+)")
    private static let confirmedByPattern = try! NSRegularExpression(pattern: "Confirmed By\\s+(.+?),\\s*\\d{1,2}/\\d{1,2}/\\d{4}", options: .caseInsensitive)
    private static let careNotesSigPattern = try! NSRegularExpression(pattern: "-{2,}\\s*([A-Za-z .'-]+?)\\s*,\\s*,?\\s*(\\d{1,2}/\\d{1,2}/\\d{4})?")
    private static let genericSigPattern = try! NSRegularExpression(pattern: "-{2,}\\s*([A-Za-z .'-]+)")
    private static let dateExtractPattern1 = try! NSRegularExpression(pattern: "\\d{1,2}/\\d{1,2}/\\d{4}")
    private static let dateExtractPattern2 = try! NSRegularExpression(pattern: "\\d{4}-\\d{2}-\\d{2}")
    private static let sharedStringsPattern = try! NSRegularExpression(pattern: "<t[^>]*>([^<]*)</t>")
    private static let cellPattern = try! NSRegularExpression(pattern: "<c([^>]*)>.*?<v>([^<]*)</v>", options: .dotMatchesLineSeparators)
    private static let inlineCellPattern = try! NSRegularExpression(pattern: "<c[^>]*t=\"inlineStr\"[^>]*>.*?<t>([^<]*)</t>", options: .dotMatchesLineSeparators)
    private static let nhsPattern = try! NSRegularExpression(pattern: "\\b(\\d{3}[\\s-]?\\d{3}[\\s-]?\\d{4})\\b")
    // DOB patterns: numeric (dd/mm/yyyy) and written month (7 May 1964, 18th July 1991)
    private static let dobPattern = try! NSRegularExpression(pattern: "(?:dob|d\\.o\\.b|date of birth)[:\\s]*(\\d{1,2}[/\\-]\\d{1,2}[/\\-]\\d{2,4})", options: .caseInsensitive)
    private static let dobWrittenPattern = try! NSRegularExpression(pattern: "(?:dob|d\\.o\\.b|date of birth)[:\\s]*(\\d{1,2}(?:st|nd|rd|th)?\\s+[A-Za-z]+\\s+\\d{4})", options: .caseInsensitive)
    // PDFKit table: "Date of Birth Date of Admission 7 May 1964"
    private static let dobPDFTablePattern = try! NSRegularExpression(pattern: "Date of Birth[^\\d]*(\\d{1,2}(?:st|nd|rd|th)?\\s+[A-Za-z]+,?\\s+\\d{4})", options: .caseInsensitive)

    // MARK: - Cached Date Formatters (for performance)
    private static let rioFormatters: [DateFormatter] = {
        let formats = ["dd/MM/yyyy HH:mm", "dd/MM/yyyy HH:mm:ss", "dd/MM/yyyy", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd"]
        return formats.map { format in
            let f = DateFormatter()
            f.dateFormat = format
            f.locale = Locale(identifier: "en_GB")
            return f
        }
    }()

    private static let epjsFormatters: [DateFormatter] = {
        let formats = ["dd MMM yyyy HH:mm", "dd MMM yyyy", "d MMM yyyy HH:mm", "d MMM yyyy"]
        return formats.map { format in
            let f = DateFormatter()
            f.dateFormat = format
            f.locale = Locale(identifier: "en_GB")
            return f
        }
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yyyy HH:mm"
        f.locale = Locale(identifier: "en_GB")
        return f
    }()

    private static let isoDateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        f.locale = Locale(identifier: "en_GB")
        return f
    }()

    private static let displayDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd MMM yyyy"
        return f
    }()

    // MARK: - Main Entry Point
    func processDocument(at url: URL, format: ImportFormat = .autoDetect) async throws -> ExtractedDocument {
        let ext = url.pathExtension.lowercased()

        switch ext {
        case "xlsx", "xls":
            return try await processExcel(at: url, format: format)
        case "pdf":
            return try await processPDF(at: url)
        case "docx":
            return try await processDOCX(at: url)
        default:
            return try await processText(at: url)
        }
    }

    // MARK: - Excel Processing (RIO/CareNotes/EPJS)
    private func processExcel(at url: URL, format: ImportFormat) async throws -> ExtractedDocument {
        let data = try Data(contentsOf: url)

        // Parse Excel properly - get shared strings lookup table
        var sharedStringsTable: [String] = []
        if let sharedStringsXML = extractTextFromZipXML(data: data, xmlPath: "xl/sharedStrings.xml") {
            sharedStringsTable = parseSharedStringsTable(sharedStringsXML)
        }

        // Parse sheet to get cells in order (row by row, cell by cell)
        var allCells: [String] = []
        if let sheetXML = extractTextFromZipXML(data: data, xmlPath: "xl/worksheets/sheet1.xml") {
            allCells = parseSheetCells(sheetXML, sharedStrings: sharedStringsTable)
        }

        guard !allCells.isEmpty else {
            throw DocumentError.noContent
        }

        // Clean cells - remove empty, nan, etc.
        let allLines = allCells.compactMap { cleanCell($0) }.filter { !$0.isEmpty }

        // Detect format if auto
        let detectedFormat = format == .autoDetect ? detectFormat(lines: allLines) : format
        print("[DocumentProcessor] Detected format: \(detectedFormat), lines: \(allLines.count)")

        // Parse based on format
        let notes: [ClinicalNote]
        switch detectedFormat {
        case .rio:
            notes = parseRioFormat(lines: allLines)
        case .careNotes:
            notes = parseCareNotesFormat(lines: allLines)
        case .epjs:
            notes = parseEPJSFormat(lines: allLines)
        default:
            notes = parseGenericFormat(lines: allLines)
        }

        print("[DocumentProcessor] Parsed \(notes.count) notes")

        // Extract patient info
        let patientInfo = extractPatientInfo(from: allLines.joined(separator: "\n"))

        // Extract categories from all notes
        let extractedData = extractClinicalCategories(from: notes)

        return ExtractedDocument(
            text: allLines.joined(separator: "\n"),
            notes: notes,
            patientInfo: patientInfo,
            extractedData: extractedData
        )
    }

    // Cached date formatters for performance
    private static let excelDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yyyy"
        return f
    }()

    private static let excelDateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yyyy HH:mm"
        return f
    }()

    // Excel epoch: 1899-12-30
    private static let excelEpoch = Date(timeIntervalSince1970: -2209161600)

    // Clean cell value (matching Python clean() function)
    private func cleanCell(_ value: String) -> String {
        var s = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return "" }

        let lower = s.lowercased()

        // Filter out Excel errors and common junk values
        if lower == "nan" || lower == "none" || lower == "<na>" || lower == "nat" ||
           lower == "detail" || lower == "amend" || lower == "lock" ||
           lower == "#name?" || lower == "#value!" || lower == "#ref!" ||
           lower == "#div/0!" || lower == "#n/a" || lower == "#null!" ||
           lower == "#num!" || lower == "#error!" || lower == "#spill!" || lower == "#calc!" ||
           lower == "n/a" || lower == "null" || lower == "undefined" ||
           lower == ".." || lower == "..." {
            return ""
        }

        // Filter out formula strings (start with =) that weren't evaluated
        if s.hasPrefix("=") && s.count < 200 {
            return ""
        }

        // Decode HTML entities
        s = decodeHTMLEntities(s)

        // Quick check: if it starts with a letter, it's not a number - return early
        if let first = s.first, first.isLetter {
            return s
        }

        // Check if this is an Excel date serial number (numeric value between ~30000-60000)
        if let number = Double(s), number >= 30000 && number <= 60000 {
            let hasTime = (number.truncatingRemainder(dividingBy: 1)) > 0.0001
            let date = Self.excelEpoch.addingTimeInterval(number * 86400)
            return hasTime ? Self.excelDateTimeFormatter.string(from: date) : Self.excelDateFormatter.string(from: date)
        }

        // Check if this is an Excel time (decimal between 0 and 1)
        if let number = Double(s), number >= 0 && number < 1 && s.contains(".") {
            let totalMinutes = Int(number * 24 * 60)
            return String(format: "%02d:%02d", totalMinutes / 60, totalMinutes % 60)
        }

        return s
    }

    // MARK: - Format Detection (matching desktop autodetect.py) - Using pre-compiled patterns
    private func detectFormat(lines: [String]) -> ImportFormat {
        let sample = Array(lines.prefix(200))
        let joinedLower = sample.joined(separator: " ").lowercased()

        // RIO — extremely distinctive: "originator:" + brackets
        if joinedLower.contains("originator:") && joinedLower.contains("[") && joinedLower.contains("]") {
            return .rio
        }

        // EPJS — long dashed separators (20+ hyphens) with EPJS-style footer
        for line in sample {
            if Self.longDashPattern.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) != nil {
                return .epjs
            }
        }

        // CareNotes — cut & paste signatures (short dashes + double comma)
        for line in sample {
            if Self.careNotesSignaturePattern.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) != nil {
                return .careNotes
            }
        }

        // CareNotes — report style markers (check once on joined string)
        if joinedLower.contains("night note entry") ||
           joinedLower.contains("keeping well") ||
           joinedLower.contains("keeping healthy") ||
           joinedLower.contains("keeping safe") ||
           joinedLower.contains("keeping connected") ||
           joinedLower.contains("inpatients -") ||
           joinedLower.contains("title:") {
            return .careNotes
        }

        // Default to CareNotes (safe default as per desktop)
        return .careNotes
    }

    // MARK: - Date Detection (matching desktop exactly) - Using pre-compiled patterns
    private func isDateLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let range = NSRange(trimmed.startIndex..., in: trimmed)

        return Self.dateRegex1.firstMatch(in: trimmed, range: range) != nil ||
               Self.dateRegex2.firstMatch(in: trimmed, range: range) != nil ||
               Self.dateRegex3.firstMatch(in: trimmed, range: range) != nil
    }

    private func isTimeLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        return Self.timeRegex.firstMatch(in: trimmed, range: range) != nil
    }

    private func isEPJSDateTime(_ line: String) -> (date: String, time: String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let range = NSRange(trimmed.startIndex..., in: trimmed)

        if let match = Self.epjsDateTimeRegex.firstMatch(in: trimmed, range: range),
           let dateRange = Range(match.range(at: 1), in: trimmed),
           let timeRange = Range(match.range(at: 2), in: trimmed) {
            return (String(trimmed[dateRange]), String(trimmed[timeRange]))
        }
        return nil
    }

    // MARK: - Date Parsing (matching desktop _parse_date) - Using cached formatters
    private func parseDate(from string: String) -> Date? {
        let cleaned = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }

        // Try RIO formats first (using cached formatters)
        for formatter in Self.rioFormatters {
            if let date = formatter.date(from: cleaned) {
                let year = Calendar.current.component(.year, from: date)
                if year >= 2000 && year <= 2100 {
                    return date
                }
            }
        }

        // Try EPJS formats (using cached formatters)
        for formatter in Self.epjsFormatters {
            if let date = formatter.date(from: cleaned) {
                let year = Calendar.current.component(.year, from: date)
                if year >= 2000 && year <= 2100 {
                    return date
                }
            }
        }

        // Try to extract date from longer string using pre-compiled regex
        let range = NSRange(cleaned.startIndex..., in: cleaned)

        // Try dd/mm/yyyy pattern
        if let match = Self.dateExtractPattern1.firstMatch(in: cleaned, range: range),
           let matchRange = Range(match.range, in: cleaned) {
            let dateStr = String(cleaned[matchRange])
            if let date = Self.rioFormatters[2].date(from: dateStr) { // dd/MM/yyyy formatter
                let year = Calendar.current.component(.year, from: date)
                if year >= 2000 && year <= 2100 {
                    return date
                }
            }
        }

        // Try yyyy-mm-dd pattern
        if let match = Self.dateExtractPattern2.firstMatch(in: cleaned, range: range),
           let matchRange = Range(match.range, in: cleaned) {
            let dateStr = String(cleaned[matchRange])
            if let date = Self.rioFormatters[4].date(from: dateStr) { // yyyy-MM-dd formatter
                let year = Calendar.current.component(.year, from: date)
                if year >= 2000 && year <= 2100 {
                    return date
                }
            }
        }

        return nil
    }

    /// Parse a date of birth string — accepts years from 1900+ (unlike parseDate which requires 2000+).
    /// Handles written months: "7 May 1964", "18th July, 1991", and numeric: "07/05/1964".
    private func parseDOB(from string: String) -> Date? {
        var cleaned = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }

        // Remove ordinal suffixes: 1st, 2nd, 3rd, 18th
        cleaned = cleaned.replacingOccurrences(of: "(?<=\\d)(st|nd|rd|th)", with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: ",", with: "")

        // Try written month formats
        let dobFormatters: [DateFormatter] = {
            let formats = ["d MMMM yyyy", "d MMM yyyy", "dd MMMM yyyy", "dd MMM yyyy",
                           "MMMM d yyyy", "MMM d yyyy",
                           "dd/MM/yyyy", "d/M/yyyy", "dd-MM-yyyy", "yyyy-MM-dd"]
            return formats.map { fmt in
                let f = DateFormatter()
                f.dateFormat = fmt
                f.locale = Locale(identifier: "en_GB")
                return f
            }
        }()

        for formatter in dobFormatters {
            if let date = formatter.date(from: cleaned) {
                let year = Calendar.current.component(.year, from: date)
                if year >= 1900 && year <= 2025 {
                    return date
                }
            }
        }

        // Try the general parseDate as fallback (for 2000+ dates)
        return parseDate(from: cleaned)
    }

    // Parse date + time combined (for CareNotes) - Using cached formatters
    private func parseDateWithTime(date: String, time: String?) -> Date? {
        if let time = time {
            let combined = "\(date) \(time)"
            if let result = Self.dateTimeFormatter.date(from: combined) {
                return result
            }
            if let result = Self.isoDateTimeFormatter.date(from: combined) {
                return result
            }
        }

        // Date only
        return parseDate(from: date)
    }

    // MARK: - RIO Format Parser (matching desktop importer_rio.py)
    private func parseRioFormat(lines: [String]) -> [ClinicalNote] {
        var notes: [ClinicalNote] = []
        var currentOriginator: String = ""
        var currentDate: Date?
        var currentType: String = ""
        var currentBody: [String] = []
        var linesAfterOriginator: Int = 0

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Check for Originator marker (start of new note)
            if trimmed.lowercased().hasPrefix("originator:") {
                // Save previous note if exists
                if !currentBody.isEmpty {
                    let note = ClinicalNote(
                        date: currentDate ?? Date(),
                        type: currentType.isEmpty ? "Clinical Note" : currentType,
                        author: currentOriginator,
                        body: currentBody.joined(separator: "\n"),
                        source: .rio
                    )
                    notes.append(note)
                }

                // Reset for new note
                currentOriginator = String(trimmed.dropFirst(11)).trimmingCharacters(in: .whitespaces)
                currentDate = nil
                currentType = ""
                currentBody = []
                linesAfterOriginator = 0
                continue
            }

            // Skip empty lines at start
            if currentBody.isEmpty && trimmed.isEmpty {
                continue
            }

            linesAfterOriginator += 1

            // Try to detect date in first 5 lines after originator (matching desktop logic)
            if currentDate == nil && linesAfterOriginator <= 5 && !trimmed.isEmpty {
                if let date = parseDate(from: trimmed) {
                    currentDate = date
                    continue
                }
            }

            // Detect type from bracketed text [Type]
            if currentType.isEmpty {
                if let bracketType = extractBracketedType(from: trimmed) {
                    currentType = canonicalizeNoteType(bracketType)
                }
            }

            // Skip admin lines
            let lowerTrimmed = trimmed.lowercased()
            if lowerTrimmed == "detail" || lowerTrimmed == "amend" || lowerTrimmed == "lock" {
                continue
            }

            // Add to body
            if !trimmed.isEmpty {
                currentBody.append(trimmed)
            }
        }

        // Don't forget last note
        if !currentBody.isEmpty {
            let note = ClinicalNote(
                date: currentDate ?? Date(),
                type: currentType.isEmpty ? "Clinical Note" : currentType,
                author: currentOriginator,
                body: currentBody.joined(separator: "\n"),
                source: .rio
            )
            notes.append(note)
        }

        return notes
    }

    // MARK: - CareNotes Format Parser (matching desktop importer_carenotes.py)
    private func parseCareNotesFormat(lines: [String]) -> [ClinicalNote] {
        var notes: [ClinicalNote] = []
        var currentDateString: String?
        var currentTimeString: String?
        var currentBody: [String] = []

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Check if this is a date line
            if isDateLine(trimmed) {
                // Save previous note
                if !currentBody.isEmpty, let dateStr = currentDateString {
                    let date = parseDateWithTime(date: dateStr, time: currentTimeString) ?? Date()
                    let (body, originator) = extractSignature(from: currentBody)
                    let noteType = extractNoteType(from: body)

                    let note = ClinicalNote(
                        date: date,
                        type: noteType,
                        author: originator,
                        body: body.joined(separator: "\n"),
                        source: .carenotes
                    )
                    notes.append(note)
                }

                // Start new note
                currentDateString = trimmed
                currentTimeString = nil
                currentBody = []
                continue
            }

            // Check for time line (immediately after date)
            if isTimeLine(trimmed) && currentBody.isEmpty {
                currentTimeString = trimmed
                continue
            }

            // Regular content line
            currentBody.append(trimmed)
        }

        // Last note
        if !currentBody.isEmpty, let dateStr = currentDateString {
            let date = parseDateWithTime(date: dateStr, time: currentTimeString) ?? Date()
            let (body, originator) = extractSignature(from: currentBody)
            let noteType = extractNoteType(from: body)

            let note = ClinicalNote(
                date: date,
                type: noteType,
                author: originator,
                body: body.joined(separator: "\n"),
                source: .carenotes
            )
            notes.append(note)
        }

        return notes
    }

    // MARK: - EPJS Format Parser (matching desktop importer_epjs.py) - Using pre-compiled patterns
    private func parseEPJSFormat(lines: [String]) -> [ClinicalNote] {
        var notes: [ClinicalNote] = []
        notes.reserveCapacity(lines.count / 20) // Pre-allocate estimate

        var currentDate: Date?
        var currentBody: [String] = []
        var currentOriginator: String = ""

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Check for EPJS signature line (end of note)
            let range = NSRange(trimmed.startIndex..., in: trimmed)
            if let match = Self.epjsSigPattern.firstMatch(in: trimmed, range: range) {
                // Save current note first
                if !currentBody.isEmpty {
                    let note = ClinicalNote(
                        date: currentDate ?? Date(),
                        type: extractNoteType(from: currentBody),
                        author: currentOriginator,
                        body: currentBody.joined(separator: "\n"),
                        source: .epjs
                    )
                    notes.append(note)
                }

                // Extract date and originator from signature
                if let dateRange = Range(match.range(at: 1), in: trimmed),
                   let timeRange = Range(match.range(at: 2), in: trimmed),
                   let nameRange = Range(match.range(at: 3), in: trimmed) {
                    let dateStr = String(trimmed[dateRange])
                    let timeStr = String(trimmed[timeRange])
                    currentOriginator = String(trimmed[nameRange]).trimmingCharacters(in: .whitespaces)
                    currentDate = Self.epjsFormatters[0].date(from: "\(dateStr) \(timeStr)")
                }

                currentBody = []
                continue
            }

            // Check for EPJS date-time line (start of new note)
            if let epjsDateTime = isEPJSDateTime(trimmed) {
                // Save previous note
                if !currentBody.isEmpty {
                    let note = ClinicalNote(
                        date: currentDate ?? Date(),
                        type: extractNoteType(from: currentBody),
                        author: currentOriginator,
                        body: currentBody.joined(separator: "\n"),
                        source: .epjs
                    )
                    notes.append(note)
                }

                // Parse new date using cached formatter
                currentDate = Self.epjsFormatters[0].date(from: "\(epjsDateTime.date) \(epjsDateTime.time)")
                currentBody = []
                currentOriginator = ""
                continue
            }

            // Check for "Confirmed By" pattern
            if let match = Self.confirmedByPattern.firstMatch(in: trimmed, range: range),
               let nameRange = Range(match.range(at: 1), in: trimmed) {
                currentOriginator = String(trimmed[nameRange]).trimmingCharacters(in: .whitespaces)
            }

            // Regular content
            currentBody.append(trimmed)
        }

        // Last note
        if !currentBody.isEmpty {
            let note = ClinicalNote(
                date: currentDate ?? Date(),
                type: extractNoteType(from: currentBody),
                author: currentOriginator,
                body: currentBody.joined(separator: "\n"),
                source: .epjs
            )
            notes.append(note)
        }

        return notes
    }

    // MARK: - Generic Format Parser
    private func parseGenericFormat(lines: [String]) -> [ClinicalNote] {
        var notes: [ClinicalNote] = []
        var currentDate: Date?
        var currentBody: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Check if this line is a date
            if isDateLine(trimmed) {
                // Save previous
                if !currentBody.isEmpty {
                    let note = ClinicalNote(
                        date: currentDate ?? Date(),
                        type: "Clinical Note",
                        author: "",
                        body: currentBody.joined(separator: "\n"),
                        source: .imported
                    )
                    notes.append(note)
                }

                currentDate = parseDate(from: trimmed)
                currentBody = []
                continue
            }

            // Try to detect date at start of line
            if currentDate == nil {
                if let date = parseDate(from: trimmed) {
                    currentDate = date
                    continue
                }
            }

            currentBody.append(trimmed)
        }

        // Last note or all content as one note
        if !currentBody.isEmpty {
            let note = ClinicalNote(
                date: currentDate ?? Date(),
                type: "Clinical Note",
                author: "",
                body: currentBody.joined(separator: "\n"),
                source: .imported
            )
            notes.append(note)
        }

        return notes
    }

    // MARK: - Category Extraction (18 sections)
    private func extractClinicalCategories(from notes: [ClinicalNote]) -> [ClinicalCategory: [String]] {
        var categories: [ClinicalCategory: [String]] = [:]

        for note in notes {
            let blocks = splitIntoHeaderBlocks(text: note.body)

            for block in blocks {
                if let category = block.category {
                    let datePrefix = formatDateForDisplay(note.date)
                    let content = "[\(datePrefix)] \(block.text)"

                    if categories[category] != nil {
                        categories[category]?.append(content)
                    } else {
                        categories[category] = [content]
                    }
                }
            }
        }

        // If nothing categorized, put all notes in Summary
        if categories.isEmpty && !notes.isEmpty {
            categories[.summary] = notes.map { note in
                let datePrefix = formatDateForDisplay(note.date)
                return "[\(datePrefix)] \(note.body)"
            }
        }

        return categories
    }

    // MARK: - Header Block Splitting
    private func splitIntoHeaderBlocks(text: String) -> [CategoryBlock] {
        var blocks: [CategoryBlock] = []
        var currentCategory: ClinicalCategory? = nil
        var currentLines: [String] = []

        let lines = text.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Try to detect category header
            if let detectedCategory = detectCategoryHeader(line: trimmed) {
                // Save previous block
                if !currentLines.isEmpty {
                    blocks.append(CategoryBlock(
                        category: currentCategory,
                        text: currentLines.joined(separator: "\n")
                    ))
                }

                currentCategory = detectedCategory
                currentLines = []

                // Add the header line itself if it has content after the header
                let afterHeader = removeHeaderPrefix(from: trimmed)
                if !afterHeader.isEmpty {
                    currentLines.append(afterHeader)
                }
            } else {
                currentLines.append(trimmed)
            }
        }

        // Last block
        if !currentLines.isEmpty {
            blocks.append(CategoryBlock(
                category: currentCategory,
                text: currentLines.joined(separator: "\n")
            ))
        }

        return blocks
    }

    // MARK: - Category Header Detection
    private func detectCategoryHeader(line: String) -> ClinicalCategory? {
        let lower = line.lowercased()

        // Check each category's keywords
        for category in ClinicalCategory.allCases {
            for keyword in category.detectionKeywords {
                // Must be at start of line or after common prefixes
                if lower.hasPrefix(keyword) ||
                   lower.hasPrefix("• \(keyword)") ||
                   lower.hasPrefix("- \(keyword)") ||
                   lower.hasPrefix("* \(keyword)") ||
                   lower.contains(":\(keyword)") ||
                   (lower.contains(keyword) && (lower.contains(":") || lower.count < 50)) {
                    return category
                }
            }
        }

        return nil
    }

    private func removeHeaderPrefix(from line: String) -> String {
        if let colonIndex = line.firstIndex(of: ":") {
            let afterColon = line[line.index(after: colonIndex)...]
            return String(afterColon).trimmingCharacters(in: .whitespaces)
        }
        return ""
    }

    // MARK: - Helper Functions

    // Decode common HTML entities
    private func decodeHTMLEntities(_ string: String) -> String {
        var result = string
        let entities = [
            ("&amp;", "&"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&quot;", "\""),
            ("&apos;", "'"),
            ("&#39;", "'"),
            ("&nbsp;", " "),
            ("&#160;", " "),
            ("&ndash;", "–"),
            ("&mdash;", "—"),
            ("&lsquo;", "'"),
            ("&rsquo;", "'"),
            ("&ldquo;", "\u{201C}"),
            ("&rdquo;", "\u{201D}"),
            ("&hellip;", "…"),
            ("&pound;", "£"),
            ("&euro;", "€"),
            ("&copy;", "©"),
            ("&reg;", "®"),
            ("&trade;", "™"),
            ("&deg;", "°"),
            ("&frac12;", "½"),
            ("&frac14;", "¼"),
            ("&frac34;", "¾"),
        ]

        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }

        return result
    }

    private func formatDateForDisplay(_ date: Date) -> String {
        return Self.displayDateFormatter.string(from: date)
    }

    private func extractBracketedType(from line: String) -> String? {
        if let match = Self.bracketTypePattern.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
           let range = Range(match.range(at: 1), in: line) {
            return String(line[range])
        }
        return nil
    }

    private func canonicalizeNoteType(_ type: String) -> String {
        let lower = type.lowercased()

        if lower.contains("nurs") { return "Nursing" }
        if lower.contains("medical") || lower.contains("doctor") || lower.contains("physician") ||
           lower.contains("sho") || lower.contains("registrar") || lower.contains("consultant") {
            return "Medical"
        }
        if lower.contains("social") || lower.contains("amhp") { return "Social Work" }
        if lower.contains("psycho") { return "Psychology" }
        if lower.contains("occupational") || lower.contains(" ot") { return "Occupational Therapy" }
        if lower.contains("ward round") { return "Ward Round" }
        if lower.contains("clerking") || lower.contains("admission") { return "Admission" }

        return type
    }

    private func extractSignature(from lines: [String]) -> ([String], String) {
        // Look for signature pattern at end: "-- Name, , dd/mm/yyyy" (CareNotes double comma)
        var bodyLines = lines
        var originator = ""

        let startIdx = max(0, lines.count - 5)
        for i in stride(from: lines.count - 1, through: startIdx, by: -1) {
            let line = lines[i]
            let range = NSRange(line.startIndex..., in: line)

            // Try CareNotes pattern first (using pre-compiled)
            if let match = Self.careNotesSigPattern.firstMatch(in: line, range: range),
               let nameRange = Range(match.range(at: 1), in: line) {
                originator = String(line[nameRange]).trimmingCharacters(in: .whitespaces)
                bodyLines = Array(lines.prefix(i))
                break
            }

            // Try generic pattern (using pre-compiled)
            if let match = Self.genericSigPattern.firstMatch(in: line, range: range),
               let nameRange = Range(match.range(at: 1), in: line) {
                originator = String(line[nameRange]).trimmingCharacters(in: .whitespaces)
                bodyLines = Array(lines.prefix(i))
                break
            }
        }

        return (bodyLines, originator)
    }

    private func extractNoteType(from lines: [String]) -> String {
        // First non-empty line often contains type
        for line in lines.prefix(3) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty && trimmed.count < 100 {
                if let colonIndex = trimmed.firstIndex(of: ":") {
                    let beforeColon = String(trimmed[..<colonIndex])
                    if beforeColon.count < 50 {
                        return canonicalizeNoteType(beforeColon)
                    }
                }
            }
        }
        return "Clinical Note"
    }

    // Pre-compiled name patterns — [ ] (space only) inside name capture to avoid grabbing next-line labels
    private static let namePatterns: [NSRegularExpression] = {
        let patterns: [(String, NSRegularExpression.Options)] = [
            // "Name" at start of line followed by space then value (PDFKit table extraction)
            // PDFKit often puts "Name Elaine Sanders" on one line
            ("(?:^|\\n)\\s*Name[ ]+([A-Z][a-z]+(?:[ ]+[A-Z][a-z]+)+)(?=\\n|$)", [.anchorsMatchLines]),
            // "Patient Name: ..." — word boundary prevents matching "Inpatient"
            ("\\bPatient\\s+[Nn]ame\\s*[:  ]\\s*([A-Z][a-z]+(?:[ ]+[A-Z][a-z]+)+)", []),
            // "Name of Patient: ..."
            ("[Nn]ame\\s+of\\s+[Pp]atient\\s*[: ]\\s*([A-Z][a-z]+(?:[ ]+[A-Z][a-z]+)+)", []),
            // "Name: Foo Bar" or "Name\tFoo Bar"
            ("\\bName\\s*[:\\t]\\s*([A-Z][a-z]+(?:[ ]+[A-Z][a-z]+)+)", []),
            // "Name\nFoo Bar" (newline between label and value)
            ("(?:^|\\n)\\s*Name\\s*\\n\\s*([A-Z][a-z]+(?:[ ]+[A-Z][a-z]+)+)", []),
            // "Re: Foo Bar" (referral letters)
            ("\\bRe:\\s+([A-Z][a-z]+(?:[ ]+[A-Z][a-z]+)+)", []),
        ]
        return patterns.compactMap { (pattern, options) in
            try? NSRegularExpression(pattern: pattern, options: options)
        }
    }()

    // MARK: - Patient Info Extraction - Using pre-compiled patterns
    private func extractPatientInfo(from text: String) -> PatientInfo {
        var info = PatientInfo()
        let lower = text.lowercased()
        let range = NSRange(text.startIndex..., in: text)

        // Name patterns (using pre-compiled)
        for (idx, regex) in Self.namePatterns.enumerated() {
            if let match = regex.firstMatch(in: text, range: range),
               let matchRange = Range(match.range(at: 1), in: text) {
                let fullName = String(text[matchRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                let names = fullName.split(separator: " ")
                if names.count >= 2 {
                    info.firstName = String(names[0])
                    info.lastName = names.dropFirst().joined(separator: " ")
                    print("[DocumentProcessor] Patient name matched by pattern \(idx): '\(fullName)'")
                    break
                }
            }
        }

        // NHS Number (using pre-compiled)
        if let match = Self.nhsPattern.firstMatch(in: text, range: range),
           let matchRange = Range(match.range(at: 1), in: text) {
            info.nhsNumber = String(text[matchRange]).replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "")
        }

        // DOB — try numeric format first, then written month, then PDFKit table format
        if let match = Self.dobPattern.firstMatch(in: text, range: range),
           let matchRange = Range(match.range(at: 1), in: text) {
            info.dateOfBirth = parseDOB(from: String(text[matchRange]))
        }
        if info.dateOfBirth == nil,
           let match = Self.dobWrittenPattern.firstMatch(in: text, range: range),
           let matchRange = Range(match.range(at: 1), in: text) {
            info.dateOfBirth = parseDOB(from: String(text[matchRange]))
        }
        if info.dateOfBirth == nil,
           let match = Self.dobPDFTablePattern.firstMatch(in: text, range: range),
           let matchRange = Range(match.range(at: 1), in: text) {
            info.dateOfBirth = parseDOB(from: String(text[matchRange]))
            print("[DocumentProcessor] DOB matched by PDF table pattern: '\(text[matchRange])'")
        }

        // Gender - fast string contains checks
        if lower.contains("female") || lower.contains(" she ") || lower.contains(" her ") {
            info.gender = .female
        } else if lower.contains(" male") || lower.contains(" he ") || lower.contains(" his ") {
            info.gender = .male
        }

        return info
    }

    // MARK: - PDF Processing
    private func processPDF(at url: URL) async throws -> ExtractedDocument {
        guard let pdf = PDFDocument(url: url) else {
            throw DocumentError.failedToRead
        }

        var allText = ""
        for i in 0..<min(pdf.pageCount, 50) {
            if let page = pdf.page(at: i), let text = page.string {
                allText += text + "\n\n"
            }
        }

        // Check if PDFKit only returned the XFA fallback message
        let isXFAFallback = allText.contains("Please wait...") &&
                            allText.contains("PDF\nviewer may not be able to display")

        if isXFAFallback || allText.trimmingCharacters(in: .whitespacesAndNewlines).count < 100 {
            // Try XFA extraction from raw PDF data
            if let xfaText = extractXFAFormData(from: url) {
                print("[DocumentProcessor] XFA extraction succeeded: \(xfaText.count) chars")
                allText = xfaText
            }
        }

        // Fallback: OCR scanned pages using Vision framework
        if allText.trimmingCharacters(in: .whitespacesAndNewlines).count < 100 {
            print("[DocumentProcessor] No text found — attempting OCR on \(pdf.pageCount) pages")
            allText = await ocrPDF(pdf)
            print("[DocumentProcessor] OCR extracted \(allText.count) chars")
        }

        let lines = allText.components(separatedBy: .newlines)
        let format = detectFormat(lines: lines)
        let notes: [ClinicalNote]

        switch format {
        case .rio:
            notes = parseRioFormat(lines: lines)
        case .careNotes:
            notes = parseCareNotesFormat(lines: lines)
        case .epjs:
            notes = parseEPJSFormat(lines: lines)
        default:
            notes = parseGenericFormat(lines: lines)
        }

        let patientInfo = extractPatientInfo(from: allText)
        let extractedData = extractClinicalCategories(from: notes)

        return ExtractedDocument(
            text: allText,
            notes: notes,
            patientInfo: patientInfo,
            extractedData: extractedData
        )
    }

    // MARK: - XFA Form Data Extraction
    /// Extract form data from XFA-based PDFs (e.g. T131/T134 tribunal report forms).
    /// These PDFs store data in compressed XML streams — use CGPDFDocument to decompress.
    private func extractXFAFormData(from url: URL) -> String? {
        // Use CGPDFDocument to access internal PDF structure and decompress streams
        guard let cgPDF = CGPDFDocument(url as CFURL) else {
            print("[DocumentProcessor] CGPDFDocument could not open PDF")
            return nil
        }

        var xfaXML: String? = nil

        // Strategy 1: Navigate catalog → AcroForm → XFA (the proper PDF way)
        if let catalog = cgPDF.catalog {
            var acroForm: CGPDFDictionaryRef?
            if CGPDFDictionaryGetDictionary(catalog, "AcroForm", &acroForm) {
                print("[DocumentProcessor] Found AcroForm dictionary")

                // XFA can be a single stream or an array of name/stream pairs
                var xfaStream: CGPDFStreamRef?
                var xfaArray: CGPDFArrayRef?

                if CGPDFDictionaryGetStream(acroForm!, "XFA", &xfaStream) {
                    // Single stream
                    var format = CGPDFDataFormat.raw
                    if let cfData = CGPDFStreamCopyData(xfaStream!, &format) {
                        let streamData = cfData as Data
                        xfaXML = String(data: streamData, encoding: .utf8)
                        print("[DocumentProcessor] XFA single stream: \(streamData.count) bytes, format=\(format.rawValue)")
                    }
                } else if CGPDFDictionaryGetArray(acroForm!, "XFA", &xfaArray) {
                    // XFA array: alternating [name, stream, name, stream, ...]
                    // Names identify stream types: "preamble", "config", "template", "localeSet", "datasets", "postamble"
                    // We specifically need the "datasets" stream which contains the actual form data values
                    let count = CGPDFArrayGetCount(xfaArray!)
                    print("[DocumentProcessor] XFA array with \(count) entries")

                    // First pass: look for named "datasets" stream via name/stream pairs
                    var datasetsXML: String? = nil
                    for i in stride(from: 0, to: count - 1, by: 2) {
                        // Even indices are names (PDF name or string objects)
                        var namePtr: UnsafePointer<Int8>?
                        var nameString: CGPDFStringRef?
                        var name = ""

                        if CGPDFArrayGetName(xfaArray!, i, &namePtr), let ptr = namePtr {
                            name = String(cString: ptr)
                        } else if CGPDFArrayGetString(xfaArray!, i, &nameString), let pdfStr = nameString,
                                  let cfStr = CGPDFStringCopyTextString(pdfStr) {
                            name = cfStr as String
                        }

                        print("[DocumentProcessor] XFA array[\(i)]: name='\(name)'")

                        // Odd indices are the corresponding streams
                        var stream: CGPDFStreamRef?
                        if CGPDFArrayGetStream(xfaArray!, i + 1, &stream) {
                            var format = CGPDFDataFormat.raw
                            if let cfData = CGPDFStreamCopyData(stream!, &format) {
                                let streamData = cfData as Data
                                if name == "datasets" {
                                    datasetsXML = String(data: streamData, encoding: .utf8)
                                    print("[DocumentProcessor] Found 'datasets' stream: \(streamData.count) bytes")
                                    break
                                }
                            }
                        }
                    }

                    // Fallback: if no named "datasets" found, scan all streams for one containing form field data
                    if datasetsXML == nil {
                        print("[DocumentProcessor] No named 'datasets' stream, scanning all streams for field data...")
                        var bestCandidate: (String, Int)? = nil
                        for i in 0..<count {
                            var stream: CGPDFStreamRef?
                            if CGPDFArrayGetStream(xfaArray!, i, &stream) {
                                var format = CGPDFDataFormat.raw
                                if let cfData = CGPDFStreamCopyData(stream!, &format) {
                                    let streamData = cfData as Data
                                    if let text = String(data: streamData, encoding: .utf8) {
                                        // The datasets stream contains xfa:data and actual field values
                                        let hasDataMarker = text.contains("<xfa:data") || text.contains("<xfa:datasets")
                                        let hasFieldValues = text.contains("</Q5_TextField>") ||
                                                             text.contains("</Q9_TextField>") ||
                                                             text.contains("</Q12_TextField>")
                                        if hasDataMarker || hasFieldValues {
                                            print("[DocumentProcessor] Stream at index \(i) has data markers: \(streamData.count) bytes")
                                            if bestCandidate == nil || streamData.count > bestCandidate!.1 {
                                                bestCandidate = (text, streamData.count)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        datasetsXML = bestCandidate?.0
                    }

                    xfaXML = datasetsXML
                }
            } else {
                print("[DocumentProcessor] No AcroForm dictionary in catalog")
            }
        }

        // Strategy 2: Brute-force scan all PDF objects for XFA-like streams
        if xfaXML == nil {
            print("[DocumentProcessor] Trying brute-force PDF object scan...")
            var candidates: [(String, Int)] = []

            // CGPDFDocument doesn't expose xref iteration, but we can scan raw data
            // for deflate-compressed streams and decompress them
            if let fileData = try? Data(contentsOf: url) {
                // Search for stream boundaries in raw PDF
                let streamMarker = "stream\r\n".data(using: .ascii)!
                let streamMarker2 = "stream\n".data(using: .ascii)!
                let endMarker = "\nendstream".data(using: .ascii)!
                let endMarker2 = "\r\nendstream".data(using: .ascii)!

                var searchStart = fileData.startIndex
                while searchStart < fileData.endIndex {
                    // Find next "stream\n" or "stream\r\n"
                    var streamStart: Data.Index? = nil
                    var markerLen = 0
                    if let range = fileData.range(of: streamMarker, in: searchStart..<fileData.endIndex) {
                        streamStart = range.upperBound
                        markerLen = streamMarker.count
                    } else if let range = fileData.range(of: streamMarker2, in: searchStart..<fileData.endIndex) {
                        streamStart = range.upperBound
                        markerLen = streamMarker2.count
                    }

                    guard let start = streamStart else { break }

                    // Find the corresponding endstream
                    var streamEnd: Data.Index? = nil
                    if let range = fileData.range(of: endMarker, in: start..<min(start + 2_000_000, fileData.endIndex)) {
                        streamEnd = range.lowerBound
                    } else if let range = fileData.range(of: endMarker2, in: start..<min(start + 2_000_000, fileData.endIndex)) {
                        streamEnd = range.lowerBound
                    }

                    guard let end = streamEnd else {
                        searchStart = start
                        break
                    }

                    searchStart = end + endMarker.count

                    let streamBytes = fileData[start..<end]
                    guard streamBytes.count > 20 && streamBytes.count < 2_000_000 else { continue }

                    // Try to decompress as zlib/deflate
                    if let decompressed = Self.inflateData(streamBytes) {
                        if let text = String(data: decompressed, encoding: .utf8) {
                            // Check if this contains XFA form data
                            if text.contains("xfa:data") || text.contains("xfa:datasets") ||
                               text.contains("Q5_TextField") || text.contains("Q9_TextField") ||
                               text.contains("Q12_TextField") {
                                print("[DocumentProcessor] Found XFA data in compressed stream: \(decompressed.count) bytes")
                                candidates.append((text, decompressed.count))
                            }
                        }
                    }
                }

                // Pick the largest candidate
                if let best = candidates.max(by: { $0.1 < $1.1 }) {
                    xfaXML = best.0
                }
            }
        }

        guard let xml = xfaXML else {
            print("[DocumentProcessor] No XFA data found in PDF")
            return nil
        }

        print("[DocumentProcessor] Found XFA XML: \(xml.count) chars")

        // Parse XML to extract field values
        let fields = parseXFAFields(from: xml)
        guard !fields.isEmpty else {
            print("[DocumentProcessor] XFA XML found but no fields extracted")
            return nil
        }

        print("[DocumentProcessor] Extracted \(fields.count) XFA fields: \(fields.keys.sorted())")

        // T131 field name → question number mapping (from desktop pdf_loader.py)
        let fieldToQuestion: [String: (Int, String)] = [
            "Q1_TextField2": (1, "Patient Details"),
            "Q2_TextField": (2, "Responsible Clinician"),
            "Q3_TextField": (3, "Factors affecting understanding"),
            "Q4_TextField": (4, "Adjustments for tribunal"),
            "Q5_TextField": (5, "Index offence and forensic history"),
            "Q6_TextField": (6, "Previous mental health involvement"),
            "Q7_TextField": (7, "Previous admission reasons"),
            "Q8_TextField": (8, "Current admission circumstances"),
            "Q9_TextField": (9, "Mental disorder and diagnosis"),
            "Q10_Radiobuttons": (10, "Learning disability"),
            "Q11_Radiobuttons": (11, "Detention required"),
            "Q12_TextField": (12, "Medical treatment"),
            "Q13_TextField": (13, "Strengths/positive factors"),
            "Q14_TextField": (14, "Progress and behaviour"),
            "Q15_TextField": (15, "Understanding/compliance"),
            "Q16_TextField": (16, "MCA DoL consideration"),
            "Q17_TextField": (17, "Incidents of harm"),
            "Q18_TextField": (18, "Incidents of property damage"),
            "Q19_Radiobuttons": (19, "Section 2 detention"),
            "Q20_Radiobuttons": (20, "Other sections detention"),
            "Q21_TextField": (21, "Risk if discharged"),
            "Q22_TextField": (22, "Community risk management"),
            "Q23_TextField": (23, "Recommendations to tribunal"),
        ]

        // Build numbered text output matching the format parsePTRReportSections expects
        var outputLines: [String] = []
        var questionTexts: [(Int, String, String)] = [] // (number, title, content)

        for (fieldName, value) in fields {
            if let (questionNum, title) = fieldToQuestion[fieldName] {
                let cleanedValue = value
                    .replacingOccurrences(of: "&#xD;", with: "\n")
                    .replacingOccurrences(of: "&#xA;", with: "\n")
                    .replacingOccurrences(of: "&#x9;", with: "\t")
                questionTexts.append((questionNum, title, cleanedValue))
            }
        }

        // Also check for additional fields (author name, dates, etc.)
        if let authorName = fields["TextField9"] {
            questionTexts.append((2, "Responsible Clinician", authorName))
        }

        // Sort by question number and format
        questionTexts.sort { $0.0 < $1.0 }

        // Merge duplicates (same question number)
        var merged: [Int: (String, String)] = [:]
        for (num, title, content) in questionTexts {
            if let existing = merged[num] {
                merged[num] = (title, existing.1 + "\n\n" + content)
            } else {
                merged[num] = (title, content)
            }
        }

        for num in merged.keys.sorted() {
            if let (title, content) = merged[num] {
                outputLines.append("\(num). \(title)")
                outputLines.append(content)
                outputLines.append("")
            }
        }

        let result = outputLines.joined(separator: "\n")
        return result.isEmpty ? nil : result
    }

    /// Parse XFA XML to extract field name → value pairs
    private func parseXFAFields(from xml: String) -> [String: String] {
        var fields: [String: String] = [:]

        // Use XMLParser for robust extraction
        let parser = XFAFieldParser()
        if let data = xml.data(using: .utf8) {
            let xmlParser = XMLParser(data: data)
            xmlParser.delegate = parser
            xmlParser.parse()
            fields = parser.fields
        }

        // Fallback: regex extraction if XMLParser fails or finds nothing
        if fields.isEmpty {
            // Match patterns like <Q5_TextField>content</Q5_TextField>
            let pattern = #"<(Q\d+_\w+|TextField\d+|DateTimeField\d*)>([^<]+)</\1>"#
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
                let nsXml = xml as NSString
                let matches = regex.matches(in: xml, range: NSRange(location: 0, length: nsXml.length))
                for match in matches {
                    let fieldName = nsXml.substring(with: match.range(at: 1))
                    let value = nsXml.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !value.isEmpty {
                        fields[fieldName] = value
                    }
                }
            }
        }

        return fields
    }

    /// Decompress zlib/deflate data (used for PDF FlateDecode streams)
    private static func inflateData(_ compressed: Data) -> Data? {
        // PDF FlateDecode uses zlib (RFC 1950) — 2-byte header then deflate payload
        // Try with the Compression framework's ZLIB algorithm
        let destBufferSize = compressed.count * 10 // Estimate 10x expansion
        let destBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: destBufferSize)
        defer { destBuffer.deallocate() }

        let decompressedSize = compressed.withUnsafeBytes { srcBuffer -> Int in
            guard let srcPtr = srcBuffer.bindMemory(to: UInt8.self).baseAddress else { return 0 }
            return compression_decode_buffer(
                destBuffer, destBufferSize,
                srcPtr, compressed.count,
                nil,
                COMPRESSION_ZLIB
            )
        }

        guard decompressedSize > 0 else { return nil }
        return Data(bytes: destBuffer, count: decompressedSize)
    }

    // MARK: - OCR for Scanned PDFs
    /// Use Apple Vision framework to OCR scanned PDF pages into text.
    private func ocrPDF(_ pdf: PDFDocument) async -> String {
        var pages: [String] = []

        for i in 0..<min(pdf.pageCount, 20) {
            guard let pdfPage = pdf.page(at: i) else { continue }
            let bounds = pdfPage.bounds(for: .mediaBox)

            // Render PDF page to CGImage at 2x for better OCR accuracy
            let scale: CGFloat = 2.0
            let width = Int(bounds.width * scale)
            let height = Int(bounds.height * scale)
            guard width > 0, height > 0 else { continue }

            let colorSpace = CGColorSpaceCreateDeviceRGB()
            guard let ctx = CGContext(
                data: nil, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { continue }

            ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
            ctx.scaleBy(x: scale, y: scale)
            pdfPage.draw(with: .mediaBox, to: ctx)

            guard let cgImage = ctx.makeImage() else { continue }

            // Run Vision OCR
            let pageText = await withCheckedContinuation { (continuation: CheckedContinuation<String, Never>) in
                let request = VNRecognizeTextRequest { request, error in
                    guard let observations = request.results as? [VNRecognizedTextObservation] else {
                        continuation.resume(returning: "")
                        return
                    }
                    let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                    continuation.resume(returning: lines.joined(separator: "\n"))
                }
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true

                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    print("[DocumentProcessor] OCR error page \(i): \(error)")
                    continuation.resume(returning: "")
                }
            }

            if !pageText.isEmpty {
                pages.append(pageText)
            }
        }

        return pages.joined(separator: "\n\n")
    }

    // MARK: - DOCX Processing
    private func processDOCX(at url: URL) async throws -> ExtractedDocument {
        let data = try Data(contentsOf: url)

        guard let xmlContent = extractTextFromZipXML(data: data, xmlPath: "word/document.xml") else {
            throw DocumentError.failedToRead
        }

        let text = extractPlainTextFromXML(xmlContent)
        let lines = text.components(separatedBy: .newlines)
        let format = detectFormat(lines: lines)
        let notes: [ClinicalNote]

        switch format {
        case .rio:
            notes = parseRioFormat(lines: lines)
        case .careNotes:
            notes = parseCareNotesFormat(lines: lines)
        case .epjs:
            notes = parseEPJSFormat(lines: lines)
        default:
            notes = parseGenericFormat(lines: lines)
        }

        let patientInfo = extractPatientInfo(from: text)
        let extractedData = extractClinicalCategories(from: notes)

        return ExtractedDocument(
            text: text,
            notes: notes,
            patientInfo: patientInfo,
            extractedData: extractedData
        )
    }

    // MARK: - Text Processing
    private func processText(at url: URL) async throws -> ExtractedDocument {
        let text = try String(contentsOf: url, encoding: .utf8)
        let lines = text.components(separatedBy: .newlines)
        let format = detectFormat(lines: lines)
        let notes: [ClinicalNote]

        switch format {
        case .rio:
            notes = parseRioFormat(lines: lines)
        case .careNotes:
            notes = parseCareNotesFormat(lines: lines)
        case .epjs:
            notes = parseEPJSFormat(lines: lines)
        default:
            notes = parseGenericFormat(lines: lines)
        }

        let patientInfo = extractPatientInfo(from: text)
        let extractedData = extractClinicalCategories(from: notes)

        return ExtractedDocument(
            text: text,
            notes: notes,
            patientInfo: patientInfo,
            extractedData: extractedData
        )
    }

    // MARK: - Excel XML Parsing (Optimized with Pre-compiled Regex)

    // Parse sharedStrings.xml into a lookup table (index -> string)
    private func parseSharedStringsTable(_ xml: String) -> [String] {
        let range = NSRange(xml.startIndex..., in: xml)
        let matches = Self.sharedStringsPattern.matches(in: xml, options: [], range: range)

        var strings: [String] = []
        strings.reserveCapacity(matches.count)
        for match in matches {
            if let contentRange = Range(match.range(at: 1), in: xml) {
                strings.append(String(xml[contentRange]))
            }
        }

        return strings
    }

    // Parse sheet1.xml to get cell values in order (row by row) - Using pre-compiled patterns
    private func parseSheetCells(_ xml: String, sharedStrings: [String]) -> [String] {
        var cells: [String] = []
        cells.reserveCapacity(5000) // Pre-allocate for performance

        let range = NSRange(xml.startIndex..., in: xml)
        let matches = Self.cellPattern.matches(in: xml, options: [], range: range)

        for match in matches {
            guard let attrRange = Range(match.range(at: 1), in: xml),
                  let valueRange = Range(match.range(at: 2), in: xml) else {
                continue
            }

            let attributes = String(xml[attrRange])
            let rawValue = String(xml[valueRange])

            // Check if t="s" (shared string reference)
            if attributes.contains("t=\"s\"") {
                if let idx = Int(rawValue), idx >= 0 && idx < sharedStrings.count {
                    cells.append(sharedStrings[idx])
                }
            } else {
                // Inline value (number, date serial, etc.)
                cells.append(rawValue)
            }
        }

        // Also check for inline strings using pre-compiled pattern
        let inlineMatches = Self.inlineCellPattern.matches(in: xml, options: [], range: range)
        for match in inlineMatches {
            if let textRange = Range(match.range(at: 1), in: xml) {
                cells.append(String(xml[textRange]))
            }
        }

        return cells
    }

    private func extractTextFromZipXML(data: Data, xmlPath: String) -> String? {
        var offset = 0
        while offset < data.count - 30 {
            guard data[offset] == 0x50, data[offset + 1] == 0x4B,
                  data[offset + 2] == 0x03, data[offset + 3] == 0x04 else {
                offset += 1
                continue
            }

            let compressionMethod = UInt16(data[offset + 8]) | (UInt16(data[offset + 9]) << 8)
            let compressedSize = Int(UInt32(data[offset + 18]) | (UInt32(data[offset + 19]) << 8) |
                                    (UInt32(data[offset + 20]) << 16) | (UInt32(data[offset + 21]) << 24))
            let uncompressedSize = Int(UInt32(data[offset + 22]) | (UInt32(data[offset + 23]) << 8) |
                                      (UInt32(data[offset + 24]) << 16) | (UInt32(data[offset + 25]) << 24))
            let fileNameLength = Int(UInt16(data[offset + 26]) | (UInt16(data[offset + 27]) << 8))
            let extraFieldLength = Int(UInt16(data[offset + 28]) | (UInt16(data[offset + 29]) << 8))

            let fileNameStart = offset + 30
            let fileNameEnd = fileNameStart + fileNameLength
            guard fileNameEnd <= data.count else { break }

            let fileName = String(data: data[fileNameStart..<fileNameEnd], encoding: .utf8) ?? ""
            let dataStart = fileNameEnd + extraFieldLength
            let dataEnd = dataStart + compressedSize
            guard dataEnd <= data.count else { break }

            if fileName == xmlPath || fileName.hasSuffix(xmlPath) {
                let compressedData = data[dataStart..<dataEnd]

                if compressionMethod == 0 {
                    return String(data: compressedData, encoding: .utf8)
                } else if compressionMethod == 8 {
                    return decompressAndDecode(Data(compressedData), size: uncompressedSize)
                }
            }

            offset = dataEnd
        }
        return nil
    }

    private func decompressAndDecode(_ data: Data, size: Int) -> String? {
        var decompressed = Data(count: size)
        let result = decompressed.withUnsafeMutableBytes { dest in
            data.withUnsafeBytes { src in
                guard let destPtr = dest.bindMemory(to: UInt8.self).baseAddress,
                      let srcPtr = src.bindMemory(to: UInt8.self).baseAddress else {
                    return 0
                }
                return compression_decode_buffer(
                    destPtr, size,
                    srcPtr, data.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }
        return result > 0 ? String(data: decompressed.prefix(result), encoding: .utf8) : nil
    }

    private func extractPlainTextFromXML(_ xml: String) -> String {
        var result = ""
        var inTag = false
        var text = ""

        for char in xml {
            if char == "<" {
                if !text.trimmingCharacters(in: .whitespaces).isEmpty {
                    result += text + " "
                }
                text = ""
                inTag = true
            } else if char == ">" {
                inTag = false
            } else if !inTag {
                text += String(char)
            }
        }

        return result.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Supporting Types
enum ImportFormat {
    case autoDetect
    case rio
    case careNotes
    case epjs
    case generic
}

struct CategoryBlock {
    let category: ClinicalCategory?
    let text: String
}

struct ExtractedDocument {
    let text: String
    let notes: [ClinicalNote]
    let patientInfo: PatientInfo
    let extractedData: [ClinicalCategory: [String]]
}

enum DocumentError: Error, LocalizedError {
    case unsupportedFormat
    case failedToRead
    case noContent

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat: return "Unsupported file format"
        case .failedToRead: return "Failed to read document"
        case .noContent: return "No content found"
        }
    }
}

// MARK: - XFA XML Field Parser
/// XMLParser delegate that extracts leaf-node text values from XFA form data XML.
/// Maps element tag names (e.g. "Q5_TextField") to their text content.
class XFAFieldParser: NSObject, XMLParserDelegate {
    var fields: [String: String] = [:]
    private var currentElement: String = ""
    private var currentText: String = ""
    private var elementStack: [String] = []

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        // Strip namespace prefix
        let tag = elementName.components(separatedBy: ":").last ?? elementName
        elementStack.append(tag)
        currentElement = tag
        currentText = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        let tag = elementName.components(separatedBy: ":").last ?? elementName
        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            // Store the field value, appending if key already exists
            if let existing = fields[tag], !existing.isEmpty {
                fields[tag] = existing + "\n" + trimmed
            } else {
                fields[tag] = trimmed
            }
        }
        elementStack.removeLast()
        currentElement = elementStack.last ?? ""
        currentText = ""
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        // XFA XML in PDFs may have encoding issues — log but don't crash
        print("[XFAFieldParser] Parse error (continuing): \(parseError.localizedDescription)")
    }
}
