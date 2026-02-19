//
//  HistoryExtractor.swift
//  MyPsychAdmin
//
//  Extracts patient history from clerking notes using header detection
//  Matches desktop app's history_extractor_sections.py EXACTLY
//

import Foundation

// MARK: - Category Definition
struct HistoryCategory: Identifiable {
    let id: Int
    let name: String
    let terms: [String]

    static let ordered: [HistoryCategory] = [
        HistoryCategory(id: 1, name: "Legal", terms: [
            "legal", "legal status", "status", "mha status", "mha", "section", "detained"
        ]),
        HistoryCategory(id: 2, name: "Diagnosis", terms: [
            "diagnosis", "diagnoses", "diagnosis of", "diagnosed with", "previous diagnosis", "icd"
        ]),
        HistoryCategory(id: 3, name: "Circumstances of Admission", terms: [
            "circumstances of admission", "circumstances leading to", "background and circumstances",
            "background", "presenting circumstance", "presenting complaint", "presenting history",
            "pc", "assessment", "history", "referral source"
        ]),
        HistoryCategory(id: 4, name: "History of Presenting Complaint", terms: [
            "history of presenting complaint", "hxpc", "hpc", "pc", "presenting complaint",
            "presenting issue", "presentation"
        ]),
        HistoryCategory(id: 5, name: "Past Psychiatric History", terms: [
            "past psychiatric history", "psychiatric history", "past psych", "pph",
            "psych hx", "previous admissions", "previous mh history"
        ]),
        HistoryCategory(id: 6, name: "Medication History", terms: [
            "medication history", "drug history", "dhx", "medication", "allerg", "allergies",
            "medications", "regular medication", "current medication"
        ]),
        HistoryCategory(id: 7, name: "Drug and Alcohol History", terms: [
            "drug history", "alcohol history", "substance use", "substance misuse",
            "drugs", "alcohol", "illicit"
        ]),
        HistoryCategory(id: 8, name: "Past Medical History", terms: [
            "past medical history", "medical history", "pmh", "physical health", "physical hx"
        ]),
        HistoryCategory(id: 9, name: "Forensic History", terms: [
            "forensic history", "forensic", "offence", "offending", "criminal", "police", "charges"
        ]),
        HistoryCategory(id: 10, name: "Personal History", terms: [
            "personal history", "social history", "social hx", "family history", "fhx",
            "relationships", "occupation", "employment", "childhood", "developmental"
        ]),
        HistoryCategory(id: 11, name: "Mental State Examination", terms: [
            "mental state examination", "mental state", "mse", "appearance", "behaviour",
            "speech", "mood", "affect", "thought", "perception", "cognition", "insight"
        ]),
        HistoryCategory(id: 12, name: "Risk", terms: [
            "risk", "suicide", "self harm", "violence", "risk assessment", "harm", "risk history"
        ]),
        HistoryCategory(id: 13, name: "Physical Examination", terms: [
            "physical examination", "examination", "o/e", "observations", "obs"
        ]),
        HistoryCategory(id: 14, name: "ECG", terms: ["ecg", "electrocardiogram"]),
        HistoryCategory(id: 15, name: "Impression", terms: [
            "impression", "formulation", "overview", "clinical summary", "summary of presentation"
        ]),
        HistoryCategory(id: 16, name: "Plan", terms: [
            "plan", "management", "treatment plan", "next steps", "actions"
        ]),
        HistoryCategory(id: 17, name: "Capacity Assessment", terms: [
            "capacity", "mental capacity", "mca", "capacity assessment"
        ]),
        HistoryCategory(id: 18, name: "Summary", terms: [
            "summary", "overall", "patient seen", "review"
        ])
    ]

    var icon: String {
        switch id {
        case 1: return "building.columns"      // Legal
        case 2: return "stethoscope"           // Diagnosis
        case 3: return "door.left.hand.open"   // Circumstances
        case 4: return "clock.arrow.circlepath" // HPC
        case 5: return "brain"                 // Past Psych
        case 6: return "pills"                 // Medication
        case 7: return "wineglass"             // Drug/Alcohol
        case 8: return "heart.text.square"     // Past Medical
        case 9: return "checkmark.seal"        // Forensic
        case 10: return "person.2"             // Personal
        case 11: return "brain.head.profile"   // MSE
        case 12: return "exclamationmark.triangle" // Risk
        case 13: return "figure.stand"         // Physical Exam
        case 14: return "waveform.path.ecg"    // ECG
        case 15: return "lightbulb"            // Impression
        case 16: return "list.bullet.clipboard" // Plan
        case 17: return "checkmark.shield"     // Capacity
        case 18: return "doc.text"             // Summary
        default: return "folder"
        }
    }
}

// MARK: - History Entry
struct HistoryEntry: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let text: String
    let noteId: UUID?
}

// MARK: - Extracted History Result
struct ExtractedHistory {
    var categories: [Int: [HistoryEntry]] = [:]
    var clerkingCount: Int = 0

    func entries(for categoryId: Int) -> [HistoryEntry] {
        categories[categoryId] ?? []
    }

    var totalEntries: Int {
        categories.values.reduce(0) { $0 + $1.count }
    }

    var nonEmptyCategories: [HistoryCategory] {
        HistoryCategory.ordered.filter { !(categories[$0.id]?.isEmpty ?? true) }
    }
}

// MARK: - History Extractor (matching desktop logic)
class HistoryExtractor {
    static let shared = HistoryExtractor()

    // Build header lookup from category terms
    private var headerLookup: [String: [HistoryCategory]] = [:]
    private var categoryWeights: [String: Int] = [:]

    init() {
        // Build lookup table
        for category in HistoryCategory.ordered {
            categoryWeights[category.name] = category.id
            for term in category.terms {
                let normalized = normalize(term)
                if headerLookup[normalized] == nil {
                    headerLookup[normalized] = []
                }
                headerLookup[normalized]?.append(category)
            }
        }
    }

    // MARK: - RIO Clerking Triggers
    private let clerkingTriggersRIO: [String] = [
        "admission clerking", "clerking", "duty doctor admission",
        "new admission", "new transfer", "circumstances of admission",
        "circumstances leading to admission", "new client assesment"
    ]

    private let roleTriggersRIO: [String] = [
        "physician associate", "medical", "senior house officer",
        "sho", "ct1", "ct2", "ct3", "st4", "doctor"
    ]

    // MARK: - CareNotes Triggers
    private let carenotesStrong: [String] = [
        "title:", "mental health:", "physical health:", "observation level",
        "medication:", "activities", "risk behaviours:", "section:",
        "confirmed by", "presenting complaint", "assessment"
    ]

    // MARK: - Normalisation (matching desktop exactly)
    private func normalize(_ text: String) -> String {
        guard !text.isEmpty else { return "" }
        let cleaned = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func normHeader(_ s: String) -> String {
        guard !s.isEmpty else { return "" }
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        // Remove trailing spaces, dashes, colons
        while t.hasSuffix(" ") || t.hasSuffix("-") || t.hasSuffix("–") || t.hasSuffix(":") {
            t = String(t.dropLast())
        }
        return t.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    // MARK: - Header Detection (matching desktop _detect_header)
    private func detectHeader(_ line: String) -> HistoryCategory? {
        let nl = normHeader(line)
        let words = line.split(separator: " ")

        // If line doesn't contain : or -, and is short without known header, skip
        if !line.contains(":") && !line.contains("-") {
            if words.count <= 2 && headerLookup[nl] == nil {
                return nil
            }
        }

        var best: HistoryCategory?
        var bestWeight = -1

        for (term, categories) in headerLookup {
            if nl == term || nl.hasPrefix(term) {
                for cat in categories {
                    let mapped = mapSpecial(cat)
                    let weight = categoryWeights[mapped.name] ?? 0
                    if weight > bestWeight {
                        best = mapped
                        bestWeight = weight
                    }
                }
            }
        }

        return best
    }

    // Map special categories (matching desktop _map_special)
    private func mapSpecial(_ cat: HistoryCategory) -> HistoryCategory {
        // Capacity Assessment -> Mental State Examination
        if cat.name == "Capacity Assessment" {
            return HistoryCategory.ordered.first { $0.name == "Mental State Examination" } ?? cat
        }
        // Summary -> Impression
        if cat.name == "Summary" {
            return HistoryCategory.ordered.first { $0.name == "Impression" } ?? cat
        }
        return cat
    }

    // MARK: - Block Splitting (matching desktop split_into_header_blocks)
    private struct Block {
        var category: HistoryCategory?
        var text: String
    }

    private func splitIntoHeaderBlocks(_ text: String) -> [Block] {
        let lines = text.components(separatedBy: .newlines)
        var blocks: [Block] = []
        var currentCategory: HistoryCategory?
        var currentLines: [String] = []

        func flush() {
            if !currentLines.isEmpty {
                blocks.append(Block(
                    category: currentCategory,
                    text: currentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                ))
                currentLines = []
            }
        }

        for line in lines {
            if let detected = detectHeader(line) {
                flush()
                currentCategory = detected
                currentLines = [line]
            } else {
                currentLines.append(line)
            }
        }

        flush()
        return blocks
    }

    // MARK: - Block Classification (matching desktop classify_blocks)
    private func classifyBlocks(_ blocks: [Block]) -> [Block] {
        var output: [Block] = []

        for block in blocks {
            // Split on internal headers
            let subs = splitBlockOnInternalHeaders(block)

            for sub in subs {
                if sub.category != nil {
                    output.append(sub)
                } else {
                    // Fallback: score keywords
                    let txt = sub.text.lowercased()
                    var best: HistoryCategory?
                    var bestScore = 0

                    for cat in HistoryCategory.ordered {
                        let mapped = mapSpecial(cat)
                        var score = 0
                        for term in cat.terms {
                            if txt.contains(normHeader(term)) {
                                score += categoryWeights[mapped.name] ?? 0
                            }
                        }
                        if score > bestScore {
                            best = mapped
                            bestScore = score
                        }
                    }

                    // Fallback to Impression if no match
                    let finalCategory = best ?? HistoryCategory.ordered.first { $0.name == "Impression" }
                    output.append(Block(category: finalCategory, text: sub.text))
                }
            }
        }

        return output
    }

    private func splitBlockOnInternalHeaders(_ block: Block) -> [Block] {
        let lines = block.text.components(separatedBy: .newlines)
        var subs: [Block] = []
        var currentCategory = block.category
        var currentLines: [String] = []

        func flush() {
            if !currentLines.isEmpty {
                var cleanLines = currentLines
                // Remove header line if it's just a header
                if let first = cleanLines.first, headerLookup[normHeader(first)] != nil {
                    cleanLines = Array(cleanLines.dropFirst())
                }
                subs.append(Block(
                    category: currentCategory,
                    text: cleanLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                ))
                currentLines = []
            }
        }

        for line in lines {
            if let detected = detectHeader(line) {
                flush()
                currentCategory = detected
                currentLines = [line]
            } else {
                currentLines.append(line)
            }
        }

        flush()
        return subs
    }

    // MARK: - Check if Note Type is Medical
    private func isMedicalType(_ type: String?) -> Bool {
        guard let t = type?.lowercased() else { return false }
        return t.contains("med") || t.contains("doctor") || t.contains("clinician") || t.contains("physician")
    }

    // MARK: - Find Clerkings - RIO Pipeline
    private func findClerkingsRIO(notes: [ClinicalNote], admissionDates: [Date]) -> [(date: Date, content: String, noteId: UUID)] {
        var clerkings: [(date: Date, content: String, noteId: UUID)] = []
        var seen: Set<String> = []

        for admDate in admissionDates {
            let winStart = admDate
            let winEnd = Calendar.current.date(byAdding: .day, value: 10, to: admDate) ?? admDate

            // Filter to medical notes in window
            let medicalNotes = notes.filter { note in
                note.date >= winStart && note.date <= winEnd && isMedicalType(note.type)
            }

            for note in medicalNotes {
                let txt = normalize(note.body)

                // Must have BOTH a clerking trigger AND a role trigger
                let hasClerkingTrigger = clerkingTriggersRIO.contains { txt.contains($0) }
                let hasRoleTrigger = roleTriggersRIO.contains { txt.contains($0) }

                if !hasClerkingTrigger || !hasRoleTrigger {
                    continue
                }

                // Dedup by date + text preview
                let key = "\(note.date.timeIntervalSince1970)-\(String(txt.prefix(120)))"
                if seen.contains(key) {
                    continue
                }
                seen.insert(key)

                clerkings.append((date: note.date, content: note.body, noteId: note.id))
            }
        }

        return clerkings
    }

    // MARK: - Find Clerkings - CareNotes Pipeline
    private func findClerkingsCareNotes(notes: [ClinicalNote], admissionDates: [Date]) -> [(date: Date, content: String, noteId: UUID)] {
        var clerkings: [(date: Date, content: String, noteId: UUID)] = []
        var seen: Set<String> = []

        for admDate in admissionDates {
            let winStart = Calendar.current.date(byAdding: .day, value: -5, to: admDate) ?? admDate
            let winEnd = Calendar.current.date(byAdding: .day, value: 5, to: admDate) ?? admDate

            let withinWindow = notes.filter { note in
                note.date >= winStart && note.date <= winEnd
            }

            for note in withinWindow {
                let txt = normalize(note.body)

                // Must have ANY strong trigger
                let hasStrongTrigger = carenotesStrong.contains { txt.contains($0) }
                if !hasStrongTrigger {
                    continue
                }

                let key = "\(note.date.timeIntervalSince1970)-\(String(txt.prefix(200)))"
                if seen.contains(key) {
                    continue
                }
                seen.insert(key)

                clerkings.append((date: note.date, content: note.body, noteId: note.id))
                break // Only one per admission window for CareNotes
            }
        }

        return clerkings
    }

    // MARK: - Extract History from Single Clerking
    private func extractHistoryFromClerking(_ clerking: (date: Date, content: String, noteId: UUID)) -> [Int: [HistoryEntry]] {
        let blocks = splitIntoHeaderBlocks(clerking.content)
        let classified = classifyBlocks(blocks)

        var result: [Int: [HistoryEntry]] = [:]

        for block in classified {
            guard let cat = block.category, !block.text.isEmpty else { continue }

            if result[cat.id] == nil {
                result[cat.id] = []
            }
            result[cat.id]?.append(HistoryEntry(
                date: clerking.date,
                text: block.text,
                noteId: clerking.noteId
            ))
        }

        return result
    }

    // MARK: - Merge and Dedupe
    private func mergeHistories(_ histories: [[Int: [HistoryEntry]]]) -> [Int: [HistoryEntry]] {
        var merged: [Int: [HistoryEntry]] = [:]

        for hist in histories {
            for (catId, entries) in hist {
                if merged[catId] == nil {
                    merged[catId] = []
                }
                merged[catId]?.append(contentsOf: entries)
            }
        }

        // Sort by date within each category
        for catId in merged.keys {
            merged[catId]?.sort { $0.date < $1.date }
        }

        return merged
    }

    private func dedupeHistory(_ history: [Int: [HistoryEntry]]) -> [Int: [HistoryEntry]] {
        var output: [Int: [HistoryEntry]] = [:]

        for catId in 1...18 {
            var grouped: [Date: [String]] = [:]

            for entry in history[catId] ?? [] {
                let dayStart = Calendar.current.startOfDay(for: entry.date)
                if grouped[dayStart] == nil {
                    grouped[dayStart] = []
                }
                grouped[dayStart]?.append(entry.text)
            }

            var mergedEntries: [HistoryEntry] = []

            for (date, texts) in grouped {
                // Split into lines, remove empty, rejoin
                var cleanedLines: [String] = []
                for text in texts {
                    for line in text.components(separatedBy: .newlines) {
                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            cleanedLines.append(trimmed)
                        }
                    }
                }

                let combined = cleanedLines.joined(separator: "\n")
                if !combined.isEmpty {
                    mergedEntries.append(HistoryEntry(date: date, text: combined, noteId: nil))
                }
            }

            mergedEntries.sort { $0.date < $1.date }
            output[catId] = mergedEntries
        }

        return output
    }

    // MARK: - Main Extraction Function
    func extractPatientHistory(
        notes: [ClinicalNote],
        admissionDates: [Date],
        pipeline: String = "rio"
    ) -> ExtractedHistory {
        guard !notes.isEmpty else {
            return ExtractedHistory()
        }

        // Find clerkings based on pipeline
        let clerkings: [(date: Date, content: String, noteId: UUID)]
        if pipeline.lowercased() == "carenotes" {
            clerkings = findClerkingsCareNotes(notes: notes, admissionDates: admissionDates)
        } else {
            clerkings = findClerkingsRIO(notes: notes, admissionDates: admissionDates)
        }

        if clerkings.isEmpty {
            return ExtractedHistory()
        }

        // Extract history from each clerking
        let histories = clerkings.map { extractHistoryFromClerking($0) }

        // Merge and dedupe
        let merged = mergeHistories(histories)
        let deduped = dedupeHistory(merged)

        return ExtractedHistory(categories: deduped, clerkingCount: clerkings.count)
    }
}
