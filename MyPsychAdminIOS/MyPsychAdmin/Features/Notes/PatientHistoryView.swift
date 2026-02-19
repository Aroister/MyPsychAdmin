//
//  PatientHistoryView.swift
//  MyPsychAdmin
//
//  Patient history workspace with 18 clinical categories extracted from clerking notes
//  Matches desktop app's patient_history_panel.py - all sections collapsed by default
//

import SwiftUI

// MARK: - Note Selection with Highlight (for History)
struct HistoryNoteSelection: Equatable {
    let noteId: UUID
    let highlightText: String
}

struct PatientHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SharedDataStore.self) private var sharedData
    @State private var extractedHistory: ExtractedHistory?
    @State private var searchText = ""
    @State private var expandedCategories: Set<Int> = []
    @State private var expandedDates: Set<String> = []
    @State private var noteSelection: HistoryNoteSelection?
    @State private var isExtracting = false

    // Entries to filter out (patient identifiers, metadata)
    private let filteredPrefixes = [
        "name:", "patient name:", "dob:", "date of birth:", "nhs:",
        "nhs number:", "address:", "hospital number:", "mrn:",
        "gender:", "sex:", "ethnicity:", "religion:", "marital status:"
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search history...", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()

                // Content
                if isExtracting {
                    Spacer()
                    ProgressView("Extracting history...")
                    Spacer()
                } else if let history = extractedHistory, history.totalEntries > 0 {
                    // Categories List - all collapsed by default
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(filteredCategories(history)) { category in
                                HistoryCategorySection(
                                    category: category,
                                    entries: filteredEntries(history.entries(for: category.id)),
                                    isExpanded: expandedCategories.contains(category.id),
                                    expandedDates: $expandedDates,
                                    searchText: searchText,
                                    onToggle: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            if expandedCategories.contains(category.id) {
                                                expandedCategories.remove(category.id)
                                            } else {
                                                expandedCategories.insert(category.id)
                                            }
                                        }
                                    },
                                    onJumpToNote: { noteId, highlight in
                                        if let id = noteId {
                                            noteSelection = HistoryNoteSelection(noteId: id, highlightText: highlight)
                                        }
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                } else {
                    Spacer()
                    ContentUnavailableView {
                        Label("No History Found", systemImage: "doc.text.magnifyingglass")
                    } description: {
                        Text("No clerking notes were found. Import admission notes to extract patient history.")
                    }
                    Spacer()
                }
            }
            .navigationTitle("Patient History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                extractData()
            }
            .sheet(isPresented: Binding(
                get: { noteSelection != nil },
                set: { if !$0 { noteSelection = nil } }
            )) {
                if let selection = noteSelection,
                   let note = sharedData.notes.first(where: { $0.id == selection.noteId }) {
                    NoteDetailSheet(note: note, highlightText: selection.highlightText)
                }
            }
        }
    }

    private func extractData() {
        isExtracting = true

        // Autodetect pipeline from note sources
        let pipeline = detectPipeline()

        // Get admission dates from timeline/episodes
        let admissionDates = getAdmissionDates()

        DispatchQueue.global(qos: .userInitiated).async {
            let history = HistoryExtractor.shared.extractPatientHistory(
                notes: sharedData.notes,
                admissionDates: admissionDates,
                pipeline: pipeline
            )

            DispatchQueue.main.async {
                extractedHistory = history
                isExtracting = false
            }
        }
    }

    /// Autodetect pipeline based on note sources
    private func detectPipeline() -> String {
        var rioCount = 0
        var carenotesCount = 0

        for note in sharedData.notes {
            switch note.source {
            case .rio:
                rioCount += 1
            case .carenotes:
                carenotesCount += 1
            default:
                break
            }
        }

        // Default to rio if no clear winner or no source info
        return carenotesCount > rioCount ? "carenotes" : "rio"
    }

    private func getAdmissionDates() -> [Date] {
        var dates: [Date] = []

        for event in sharedData.extractedData.timeline {
            if event.type == .admission {
                dates.append(event.date)
            }
        }

        if dates.isEmpty {
            dates = detectAdmissionDates(from: sharedData.notes)
        }

        return dates.sorted()
    }

    private func detectAdmissionDates(from notes: [ClinicalNote]) -> [Date] {
        let admissionKeywords = [
            "admission to ward", "admitted to ward", "admitted to the ward",
            "on admission", "admission clerking", "clerking", "new admission"
        ]

        var admissionDates: [Date] = []
        var seen: Set<Date> = []

        for note in notes.sorted(by: { $0.date < $1.date }) {
            let lower = note.body.lowercased()
            let hasKeyword = admissionKeywords.contains { lower.contains($0) }

            if hasKeyword {
                let dayStart = Calendar.current.startOfDay(for: note.date)
                if !seen.contains(dayStart) {
                    seen.insert(dayStart)
                    admissionDates.append(note.date)
                }
            }
        }

        return admissionDates
    }

    /// Filter out entries that are just patient identifiers
    private func filteredEntries(_ entries: [HistoryEntry]) -> [HistoryEntry] {
        entries.filter { entry in
            let lower = entry.text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

            // Skip if it starts with a filtered prefix and is short (just the identifier)
            for prefix in filteredPrefixes {
                if lower.hasPrefix(prefix) && lower.count < 100 {
                    return false
                }
            }

            // Skip very short entries that are likely just labels
            if lower.count < 10 {
                return false
            }

            return true
        }
    }

    private func filteredCategories(_ history: ExtractedHistory) -> [HistoryCategory] {
        let categories = history.nonEmptyCategories.filter { category in
            // Only show categories that have entries after filtering
            !filteredEntries(history.entries(for: category.id)).isEmpty
        }

        if searchText.isEmpty {
            return categories
        }

        let search = searchText.lowercased()

        return categories.filter { category in
            if category.name.lowercased().contains(search) {
                return true
            }

            let entries = filteredEntries(history.entries(for: category.id))
            return entries.contains { entry in
                entry.text.lowercased().contains(search)
            }
        }
    }
}

// MARK: - Category Section
struct HistoryCategorySection: View {
    let category: HistoryCategory
    let entries: [HistoryEntry]
    let isExpanded: Bool
    @Binding var expandedDates: Set<String>
    let searchText: String
    let onToggle: () -> Void
    let onJumpToNote: (UUID?, String) -> Void

    // Icons matching desktop HISTORY_ICONS
    private var categoryIcon: String {
        switch category.id {
        case 1: return "building.columns"  // Legal
        case 2: return "brain"             // Diagnosis
        case 3: return "cross.case"        // Circumstances
        case 4: return "book"              // HPC
        case 5: return "person"            // Past Psych
        case 6: return "exclamationmark.triangle" // Medication
        case 7: return "bubble.left"       // Drug/Alcohol
        case 8: return "house"             // Past Medical
        case 9: return "books.vertical"    // Forensic
        case 10: return "heart"            // Personal
        case 11: return "pills"            // MSE
        case 12: return "allergens"        // Risk
        case 13: return "briefcase"        // Physical Exam
        case 14: return "waveform.path.ecg" // ECG
        case 15: return "scissors"         // Impression
        case 16: return "shield"           // Plan
        case 17: return "doc.text"         // Capacity
        case 18: return "magnifyingglass"  // Summary
        default: return "doc"
        }
    }

    private var entriesByDate: [(Date, [HistoryEntry])] {
        var grouped: [Date: [HistoryEntry]] = [:]
        for entry in entries {
            let dayStart = Calendar.current.startOfDay(for: entry.date)
            if grouped[dayStart] == nil {
                grouped[dayStart] = []
            }
            grouped[dayStart]?.append(entry)
        }
        return grouped.sorted { $0.key > $1.key }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Category Header
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    Image(systemName: categoryIcon)
                        .font(.title3)
                        .frame(width: 24)

                    Text(category.name)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Spacer()

                    Text("\(entries.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5))
                        .cornerRadius(10)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .buttonStyle(.plain)

            // Expanded Content - Date Groups (also collapsed by default)
            if isExpanded {
                VStack(spacing: 4) {
                    ForEach(entriesByDate, id: \.0) { (date, dateEntries) in
                        HistoryDateGroup(
                            date: date,
                            entries: dateEntries,
                            isExpanded: expandedDates.contains(dateKey(date)),
                            searchText: searchText,
                            onToggle: {
                                let key = dateKey(date)
                                if expandedDates.contains(key) {
                                    expandedDates.remove(key)
                                } else {
                                    expandedDates.insert(key)
                                }
                            },
                            onJumpToNote: onJumpToNote
                        )
                    }
                }
                .padding(.leading, 36)
                .padding(.top, 4)
            }
        }
    }

    private func dateKey(_ date: Date) -> String {
        "\(category.id)-\(date.timeIntervalSince1970)"
    }
}

// MARK: - Date Group View
struct HistoryDateGroup: View {
    let date: Date
    let entries: [HistoryEntry]
    let isExpanded: Bool
    let searchText: String
    let onToggle: () -> Void
    let onJumpToNote: (UUID?, String) -> Void

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd MMM yyyy"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            // Date Header - collapsed by default
            Button(action: onToggle) {
                HStack {
                    Text("► \(dateFormatter.string(from: date))")
                        .font(.caption)
                        .fontWeight(.medium)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(Color(.systemGray5).opacity(0.5))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)

            // Content - only shown when expanded
            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(entries) { entry in
                        Button {
                            // Pass the first 50 chars of entry text as highlight
                            let highlight = String(entry.text.prefix(50))
                            onJumpToNote(entry.noteId, highlight)
                        } label: {
                            HStack {
                                Text(entry.text)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Image(systemName: "doc.text")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                            .padding(10)
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.leading, 12)
                .padding(.top, 4)
            }
        }
    }
}

// MARK: - Note Detail Sheet
struct NoteDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let note: ClinicalNote
    var highlightText: String? = nil

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(note.type.isEmpty ? "Clinical Note" : note.type)
                                .font(.headline)
                            Text(dateFormatter.string(from: note.date))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if !note.author.isEmpty {
                                Text("By: \(note.author)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            if highlightText != nil {
                                HStack(spacing: 4) {
                                    Image(systemName: "text.magnifyingglass")
                                        .font(.caption2)
                                    Text("Highlighted: relevant section")
                                        .font(.caption2)
                                }
                                .foregroundColor(.orange)
                                .padding(.top, 4)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)

                        // Note body with highlighting
                        HighlightedNoteBody(
                            text: note.body,
                            highlightText: highlightText,
                            scrollProxy: proxy
                        )
                    }
                    .padding()
                }
            }
            .navigationTitle("Clinical Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Highlighted Note Body
struct HighlightedNoteBody: View {
    let text: String
    let highlightText: String?
    let scrollProxy: ScrollViewProxy
    @State private var hasScrolled = false

    var body: some View {
        if let highlight = highlightText, !highlight.isEmpty {
            highlightedContent(highlight: highlight)
        } else {
            Text(text)
                .font(.body)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private func highlightedContent(highlight: String) -> some View {
        let segments = splitTextWithHighlight(text: text, highlight: highlight)

        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                if segment.isHighlighted {
                    Text(segment.text)
                        .font(.body)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.yellow.opacity(0.5))
                        .cornerRadius(4)
                        .id("highlight-\(index)")
                        .onAppear {
                            if !hasScrolled {
                                hasScrolled = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    withAnimation {
                                        scrollProxy.scrollTo("highlight-\(index)", anchor: .center)
                                    }
                                }
                            }
                        }
                } else {
                    Text(segment.text)
                        .font(.body)
                }
            }
        }
        .textSelection(.enabled)
    }

    private func splitTextWithHighlight(text: String, highlight: String) -> [(text: String, isHighlighted: Bool)] {
        var segments: [(text: String, isHighlighted: Bool)] = []
        let lowerText = text.lowercased()
        let lowerHighlight = highlight.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Find the best match - try exact match first
        if let range = lowerText.range(of: lowerHighlight) {
            let startIndex = text.index(text.startIndex, offsetBy: lowerText.distance(from: lowerText.startIndex, to: range.lowerBound))
            let endIndex = text.index(text.startIndex, offsetBy: lowerText.distance(from: lowerText.startIndex, to: range.upperBound))

            // Extend highlight to capture the sentence/context (find sentence boundaries)
            var highlightStart = startIndex
            var highlightEnd = endIndex

            // Extend backwards to start of sentence (but max 100 chars)
            var backCount = 0
            while highlightStart > text.startIndex && backCount < 100 {
                let prevIndex = text.index(before: highlightStart)
                let char = text[prevIndex]
                if char == "." || char == "\n" {
                    break
                }
                highlightStart = prevIndex
                backCount += 1
            }

            // Extend forwards to end of sentence (but max 150 chars)
            var forwardCount = 0
            while highlightEnd < text.endIndex && forwardCount < 150 {
                let char = text[highlightEnd]
                highlightEnd = text.index(after: highlightEnd)
                forwardCount += 1
                if char == "." || char == "\n" {
                    break
                }
            }

            if highlightStart > text.startIndex {
                segments.append((String(text[text.startIndex..<highlightStart]), false))
            }
            segments.append((String(text[highlightStart..<highlightEnd]), true))
            if highlightEnd < text.endIndex {
                segments.append((String(text[highlightEnd..<text.endIndex]), false))
            }
        } else {
            // Try to find a significant portion of the highlight (first 30 chars)
            let shortHighlight = String(lowerHighlight.prefix(30))
            if shortHighlight.count >= 5, let range = lowerText.range(of: shortHighlight) {
                let startIndex = text.index(text.startIndex, offsetBy: lowerText.distance(from: lowerText.startIndex, to: range.lowerBound))
                // Extend the highlight to include more context (up to 150 chars after)
                let extendedEnd = text.index(startIndex, offsetBy: min(150, text.distance(from: startIndex, to: text.endIndex)))

                if startIndex > text.startIndex {
                    segments.append((String(text[text.startIndex..<startIndex]), false))
                }
                segments.append((String(text[startIndex..<extendedEnd]), true))
                if extendedEnd < text.endIndex {
                    segments.append((String(text[extendedEnd..<text.endIndex]), false))
                }
            } else {
                // No match found, just show the text without highlighting
                segments.append((text, false))
            }
        }

        return segments
    }
}

#Preview {
    PatientHistoryView()
        .environment(SharedDataStore.shared)
}
