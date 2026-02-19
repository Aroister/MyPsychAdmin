//
//  AdmissionsTimelineView.swift
//  MyPsychAdmin
//
//  Admissions / Community Timeline - matches desktop FloatingTimelinePanel
//

import SwiftUI

// MARK: - Episode Model
struct Episode: Identifiable, Equatable {
    let id = UUID()
    var type: EpisodeType
    var start: Date
    var end: Date
    var label: String
    var ward: String?
    var clerkingNote: ClinicalNote?

    var duration: Int {
        max(1, Calendar.current.dateComponents([.day], from: start, to: end).day ?? 1)
    }
}

enum EpisodeType: String {
    case inpatient = "Inpatient"
    case community = "Community"

    var color: Color {
        switch self {
        case .inpatient: return Color(red: 0.85, green: 0.33, blue: 0.31) // #d9534f
        case .community: return Color(red: 0.36, green: 0.72, blue: 0.36) // #5cb85c
        }
    }
}

// MARK: - Admission Keywords (matches desktop floating_timeline_panel.py)
struct AdmissionKeywords {
    static let primary: [String] = [
        // Ward admission phrases
        "admission to ward", "admitted to ward", "admitted to the ward",
        "brought to ward", "brought to the ward", "brought into ward",
        "brought onto ward", "brought onto the ward",
        "arrived on ward", "arrived on the ward", "arrived to ward",
        "transferred to ward", "transferred to the ward",
        "escorted to ward", "escorted to the ward",
        // General admission phrases
        "on admission", "admission clerking", "clerking",
        "duty doctor admission", "admission note",
        "accepted to ward", "accepted onto ward",
        "admitted under", "accepted under",
        // Section/detention phrases
        "detained under", "sectioned", "section 2", "section 3",
        "136 suite", "sec 136", "section 136",
        // Nursing admission entries
        "nursing admission", "admission assessment",
        "initial assessment", "ward admission",
        "new admission", "patient admitted",
        // Additional from timeline_builder.py
        "brought to the aac", "brought to aac", "brought in by police",
        "brought by police", "taken to the 136",
        "bed manager accepted", "bed identified"
    ]

    static func noteIndicatesAdmission(_ text: String) -> Bool {
        let lower = text.lowercased()
        return primary.contains { lower.contains($0) }
    }
}

// MARK: - Note Selection with Highlight (for Admissions)
struct AdmissionNoteSelection: Identifiable, Equatable {
    let note: ClinicalNote
    let highlightText: String

    var id: UUID { note.id }

    static func == (lhs: AdmissionNoteSelection, rhs: AdmissionNoteSelection) -> Bool {
        lhs.note.id == rhs.note.id && lhs.highlightText == rhs.highlightText
    }
}

// MARK: - Admissions Timeline View
struct AdmissionsTimelineView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SharedDataStore.self) private var sharedData
    @State private var episodes: [Episode] = []
    @State private var selectedEpisode: Episode?
    @State private var expandedEpisodeId: UUID?
    @State private var scale: CGFloat = 1.0
    @State private var isLoading = true
    @State private var noteSelection: AdmissionNoteSelection?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    Spacer()
                    ProgressView("Building timeline...")
                    Spacer()
                } else if episodes.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        legendBar
                        timelineContent
                        episodeList
                    }
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Admissions Timeline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await buildTimeline()
            }
        }
    }

    private func buildTimeline() async {
        let notes = sharedData.notes

        let result = await Task.detached(priority: .userInitiated) {
            TimelineBuilder.buildTimeline(from: notes, allNotes: notes)
        }.value

        await MainActor.run {
            episodes = result
            isLoading = false
        }
    }

    // MARK: - Legend Bar
    private var legendBar: some View {
        HStack(spacing: 20) {
            HStack(spacing: 6) {
                Circle()
                    .fill(EpisodeType.inpatient.color)
                    .frame(width: 12, height: 12)
                Text("Inpatient")
                    .font(.caption)
                    .foregroundColor(.primary)
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(EpisodeType.community.color)
                    .frame(width: 12, height: 12)
                Text("Community")
                    .font(.caption)
                    .foregroundColor(.primary)
            }

            Spacer()

            let admissionCount = episodes.filter { $0.type == .inpatient }.count
            Text("\(admissionCount) admission\(admissionCount == 1 ? "" : "s")")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(UIColor.systemBackground))
    }

    // MARK: - Timeline Content
    private var timelineContent: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                let width = geometry.size.width - 32

                ScrollView(.horizontal, showsIndicators: true) {
                    TimelineBarsView(
                        episodes: episodes,
                        totalWidth: max(width * scale, width),
                        height: 100,
                        selectedEpisode: $selectedEpisode,
                        onEpisodeTap: { episode in
                            handleEpisodeTap(episode)
                        }
                    )
                    .frame(width: max(width * scale, width), height: 100)
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 120)

            // Zoom controls
            HStack {
                Button {
                    withAnimation { scale = max(1.0, scale - 0.5) }
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                        .foregroundColor(scale <= 1.0 ? .gray : .blue)
                }
                .disabled(scale <= 1.0)

                Slider(value: $scale, in: 1.0...5.0, step: 0.5)
                    .frame(width: 150)
                    .tint(.blue)

                Button {
                    withAnimation { scale = min(5.0, scale + 0.5) }
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                        .foregroundColor(scale >= 5.0 ? .gray : .blue)
                }
                .disabled(scale >= 5.0)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Color(UIColor.systemBackground))
        }
    }

    // MARK: - Episode List
    private var episodeList: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(episodes) { episode in
                    EpisodeRowView(
                        episode: episode,
                        isSelected: selectedEpisode?.id == episode.id,
                        isExpanded: expandedEpisodeId == episode.id,
                        onViewNote: { note, highlight in
                            noteSelection = AdmissionNoteSelection(note: note, highlightText: highlight)
                        }
                    )
                    .id(episode.id)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        handleEpisodeTap(episode)
                    }
                    .listRowBackground(
                        selectedEpisode?.id == episode.id
                            ? Color.blue.opacity(0.1)
                            : Color(UIColor.systemBackground)
                    )
                }
            }
            .listStyle(.plain)
            .onChange(of: selectedEpisode?.id) { _, newId in
                if let id = newId {
                    withAnimation {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
            .sheet(item: $noteSelection) { selection in
                NoteDetailSheet(note: selection.note, highlightText: selection.highlightText)
            }
        }
    }

    // MARK: - Handle Episode Tap
    private func handleEpisodeTap(_ episode: Episode) {
        withAnimation(.easeInOut(duration: 0.25)) {
            selectedEpisode = episode

            if episode.type == .inpatient {
                // Toggle expansion for inpatient episodes
                if expandedEpisodeId == episode.id {
                    expandedEpisodeId = nil
                } else {
                    expandedEpisodeId = episode.id
                }
            } else {
                // Collapse any expanded episode for community
                expandedEpisodeId = nil
            }
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.2.circlepath")
                .font(.system(size: 48))
                .foregroundColor(.gray)

            Text("No Timeline Data")
                .font(.headline)
                .foregroundColor(.primary)

            Text("Import clinical notes to automatically detect admission and community periods.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
    }
}

// MARK: - Timeline Builder (matches desktop timeline_builder.py)
struct TimelineBuilder {

    /// Detect source type from notes
    static func detectSource(from notes: [ClinicalNote]) -> NoteSource {
        var sources: Set<NoteSource> = []
        for note in notes {
            sources.insert(note.source)
        }

        if sources == [.rio] { return .rio }
        if sources == [.carenotes] { return .carenotes }
        if sources == [.epjs] { return .epjs }

        return .rio
    }

    /// Build timeline episodes from notes (matches desktop algorithm)
    static func buildTimeline(from notes: [ClinicalNote], allNotes: [ClinicalNote]) -> [Episode] {
        guard !notes.isEmpty else { return [] }

        let source = detectSource(from: notes)

        var episodes: [Episode]
        switch source {
        case .carenotes:
            episodes = buildCareNotesTimeline(from: notes)
        default:
            episodes = buildRIOTimeline(from: notes)
        }

        // Attach clerking notes to inpatient episodes
        episodes = attachClerkingNotes(to: episodes, from: allNotes)

        return episodes
    }

    // MARK: - Attach Clerking Notes to Admissions
    static func attachClerkingNotes(to episodes: [Episode], from notes: [ClinicalNote]) -> [Episode] {
        let calendar = Calendar.current

        return episodes.map { episode in
            var updated = episode

            guard episode.type == .inpatient else { return updated }

            // Search 2-week window from admission start
            let windowEnd = calendar.date(byAdding: .day, value: 14, to: episode.start)!

            // Find notes in window, sorted by date
            let windowNotes = notes
                .filter { note in
                    let noteDay = calendar.startOfDay(for: note.date)
                    return noteDay >= episode.start && noteDay <= windowEnd
                }
                .sorted { $0.date < $1.date }

            // Find first note that indicates admission
            for note in windowNotes {
                if AdmissionKeywords.noteIndicatesAdmission(note.body) {
                    updated.clerkingNote = note
                    break
                }
            }

            return updated
        }
    }

    // MARK: - RIO Timeline (5-day window, >30 start, <10 end)
    static func buildRIOTimeline(from notes: [ClinicalNote]) -> [Episode] {
        let calendar = Calendar.current

        let allDates = notes.compactMap { note -> Date? in
            return calendar.startOfDay(for: note.date)
        }.sorted()

        guard !allDates.isEmpty else { return [] }

        let firstDate = allDates.first!
        let lastDate = allDates.last!
        let uniqueDates = Array(Set(allDates)).sorted()

        var densityCounts: [Date: Int] = [:]
        for date in uniqueDates {
            let windowEnd = calendar.date(byAdding: .day, value: 5, to: date)!
            let count = allDates.filter { $0 >= date && $0 <= windowEnd }.count
            densityCounts[date] = count
        }

        var segments: [(start: Date, end: Date)] = []
        var inAdmission = false
        var segmentStart: Date?

        for date in uniqueDates {
            let count = densityCounts[date] ?? 0

            if !inAdmission && count > 30 {
                inAdmission = true
                segmentStart = date
            } else if inAdmission && count < 10 {
                inAdmission = false
                if let start = segmentStart {
                    segments.append((start: start, end: date))
                }
                segmentStart = nil
            }
        }

        if inAdmission, let start = segmentStart {
            segments.append((start: start, end: lastDate))
        }

        if segments.isEmpty {
            return [Episode(
                type: .community,
                start: firstDate,
                end: lastDate,
                label: "Community"
            )]
        }

        segments.sort { $0.start < $1.start }
        var merged: [(start: Date, end: Date)] = [segments[0]]

        for seg in segments.dropFirst() {
            if seg.start <= merged.last!.end {
                merged[merged.count - 1].end = max(merged.last!.end, seg.end)
            } else {
                merged.append(seg)
            }
        }

        return buildEpisodes(from: merged, firstDate: firstDate, lastDate: lastDate)
    }

    // MARK: - CareNotes Timeline (15-day window, >=40 start, <10 end)
    static func buildCareNotesTimeline(from notes: [ClinicalNote]) -> [Episode] {
        let calendar = Calendar.current

        let allDates = notes.compactMap { note -> Date? in
            return calendar.startOfDay(for: note.date)
        }.sorted()

        guard !allDates.isEmpty else { return [] }

        let firstDate = allDates.first!
        let lastDate = allDates.last!
        let uniqueDates = Array(Set(allDates)).sorted()

        var densityCounts: [Date: Int] = [:]
        for date in uniqueDates {
            let windowEnd = calendar.date(byAdding: .day, value: 15, to: date)!
            let count = allDates.filter { $0 >= date && $0 <= windowEnd }.count
            densityCounts[date] = count
        }

        var segments: [(start: Date, end: Date)] = []
        var inAdmission = false
        var segmentStart: Date?

        for date in uniqueDates {
            let count = densityCounts[date] ?? 0

            if !inAdmission && count >= 40 {
                inAdmission = true
                segmentStart = date
            } else if inAdmission && count < 10 {
                inAdmission = false
                if let start = segmentStart {
                    segments.append((start: start, end: date))
                }
                segmentStart = nil
            }
        }

        if inAdmission, let start = segmentStart {
            segments.append((start: start, end: lastDate))
        }

        if segments.isEmpty {
            return [Episode(
                type: .community,
                start: firstDate,
                end: lastDate,
                label: "Community"
            )]
        }

        return buildEpisodes(from: segments, firstDate: firstDate, lastDate: lastDate)
    }

    // MARK: - Build Episodes from Segments
    private static func buildEpisodes(from segments: [(start: Date, end: Date)], firstDate: Date, lastDate: Date) -> [Episode] {
        let calendar = Calendar.current
        var episodes: [Episode] = []

        if firstDate < segments[0].start {
            let communityEnd = calendar.date(byAdding: .day, value: -1, to: segments[0].start)!
            episodes.append(Episode(
                type: .community,
                start: firstDate,
                end: communityEnd,
                label: "Community"
            ))
        }

        for (index, segment) in segments.enumerated() {
            episodes.append(Episode(
                type: .inpatient,
                start: segment.start,
                end: segment.end,
                label: "Admission \(index + 1)"
            ))

            if index < segments.count - 1 {
                let nextSegment = segments[index + 1]
                let communityStart = calendar.date(byAdding: .day, value: 1, to: segment.end)!
                let communityEnd = calendar.date(byAdding: .day, value: -1, to: nextSegment.start)!

                if communityStart < communityEnd {
                    episodes.append(Episode(
                        type: .community,
                        start: communityStart,
                        end: communityEnd,
                        label: "Community"
                    ))
                }
            }
        }

        let lastSegment = segments.last!
        if lastSegment.end < lastDate {
            let communityStart = calendar.date(byAdding: .day, value: 1, to: lastSegment.end)!
            episodes.append(Episode(
                type: .community,
                start: communityStart,
                end: lastDate,
                label: "Community"
            ))
        }

        return episodes
    }
}

// MARK: - Timeline Bars View
struct TimelineBarsView: View {
    let episodes: [Episode]
    let totalWidth: CGFloat
    let height: CGFloat
    @Binding var selectedEpisode: Episode?
    var onEpisodeTap: (Episode) -> Void

    private let barHeight: CGFloat = 44
    private let axisHeight: CGFloat = 28

    private var dateRange: (start: Date, end: Date) {
        guard let first = episodes.first, let last = episodes.last else {
            return (Date(), Date())
        }
        return (first.start, last.end)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Bars area - horizontal strip
            HStack(spacing: 0) {
                ForEach(episodes) { episode in
                    episodeBar(episode)
                }
            }
            .frame(height: height - axisHeight)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(8)

            // Date axis with multiple markers
            dateAxisWithMarkers
        }
    }

    private func episodeBar(_ episode: Episode) -> some View {
        let proportionalWidth = calculateWidth(for: episode)
        let isSelected = selectedEpisode?.id == episode.id

        return episode.type.color
            .frame(width: proportionalWidth)
            .overlay(
                Group {
                    if proportionalWidth > 50 {
                        Text(episode.type == .inpatient ? episode.label : "")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .stroke(isSelected ? Color.white : Color.clear, lineWidth: 3)
            )
            .onTapGesture {
                onEpisodeTap(episode)
            }
    }

    private func calculateWidth(for episode: Episode) -> CGFloat {
        let range = dateRange
        let totalDays = max(1, Calendar.current.dateComponents([.day], from: range.start, to: range.end).day ?? 1)
        let duration = max(1, episode.duration)
        let width = (CGFloat(duration) / CGFloat(totalDays)) * totalWidth
        return max(width, 4)
    }

    // MARK: - Date Axis with Multiple Markers
    private var dateAxisWithMarkers: some View {
        let range = dateRange
        let ticks = generateDateTicks(from: range.start, to: range.end)

        return GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // Tick marks and labels
                ForEach(ticks, id: \.self) { tick in
                    let xPosition = calculateXPosition(for: tick, in: geometry.size.width)

                    VStack(spacing: 2) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.5))
                            .frame(width: 1, height: 6)

                        Text(formatTickDate(tick))
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                            .fixedSize()
                    }
                    .position(x: xPosition, y: 14)
                }
            }
        }
        .frame(height: axisHeight)
    }

    private func generateDateTicks(from start: Date, to end: Date) -> [Date] {
        let calendar = Calendar.current
        let totalDays = calendar.dateComponents([.day], from: start, to: end).day ?? 1

        var ticks: [Date] = []

        // Determine tick interval based on total span
        let interval: DateComponents
        if totalDays > 4 * 365 {
            // > 4 years: yearly ticks
            interval = DateComponents(year: 1)
        } else if totalDays > 2 * 365 {
            // 2-4 years: 6-month ticks
            interval = DateComponents(month: 6)
        } else if totalDays > 365 {
            // 1-2 years: quarterly ticks
            interval = DateComponents(month: 3)
        } else if totalDays > 180 {
            // 6-12 months: bi-monthly ticks
            interval = DateComponents(month: 2)
        } else {
            // < 6 months: monthly ticks
            interval = DateComponents(month: 1)
        }

        // Start from the first day of the month after start date
        var components = calendar.dateComponents([.year, .month], from: start)
        components.day = 1
        var current = calendar.date(from: components) ?? start

        // Move to next interval if current is before start
        if current < start {
            current = calendar.date(byAdding: interval, to: current) ?? current
        }

        // Generate ticks
        while current <= end && ticks.count < 20 {
            ticks.append(current)
            current = calendar.date(byAdding: interval, to: current) ?? current
        }

        return ticks
    }

    private func calculateXPosition(for date: Date, in width: CGFloat) -> CGFloat {
        let range = dateRange
        let totalDays = max(1, Calendar.current.dateComponents([.day], from: range.start, to: range.end).day ?? 1)
        let daysFromStart = Calendar.current.dateComponents([.day], from: range.start, to: date).day ?? 0
        return (CGFloat(daysFromStart) / CGFloat(totalDays)) * width
    }

    private func formatTickDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yy"
        return formatter.string(from: date)
    }
}

// MARK: - Episode Row View
struct EpisodeRowView: View {
    let episode: Episode
    let isSelected: Bool
    let isExpanded: Bool
    var onViewNote: ((ClinicalNote, String) -> Void)? = nil

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd MMM yyyy"
        return f
    }()

    private let detailDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd MMM yyyy 'at' HH:mm"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            HStack(spacing: 12) {
                // Expand indicator for inpatient
                if episode.type == .inpatient {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(episode.type.color)
                        .frame(width: 12)
                } else {
                    Circle()
                        .fill(episode.type.color)
                        .frame(width: 12, height: 12)
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(episode.label)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        Spacer()

                        Text("\(episode.duration) days")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(UIColor.tertiarySystemFill))
                            .cornerRadius(4)
                    }

                    Text("\(dateFormatter.string(from: episode.start)) → \(dateFormatter.string(from: episode.end))")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let ward = episode.ward {
                        Text("Ward: \(ward)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 10)

            // Expanded clerking note content
            if isExpanded && episode.type == .inpatient {
                VStack(alignment: .leading, spacing: 8) {
                    if let note = episode.clerkingNote {
                        // Clerking note header
                        HStack(spacing: 8) {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(episode.type.color)

                            Text("Admission Clerking")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(episode.type.color)

                            Spacer()

                            Text(detailDateFormatter.string(from: note.date))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        // Note type and author
                        if !note.type.isEmpty || !note.author.isEmpty {
                            HStack(spacing: 12) {
                                if !note.type.isEmpty {
                                    Text(note.type)
                                        .font(.caption2)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue)
                                        .cornerRadius(4)
                                }
                                if !note.author.isEmpty {
                                    Text(note.author)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        // Note content
                        Text(note.body)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .lineLimit(15)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(8)

                        // View full note button
                        Button {
                            // Find the admission keyword for highlighting
                            let highlight = findAdmissionKeyword(in: note.body)
                            onViewNote?(note, highlight)
                        } label: {
                            HStack {
                                Image(systemName: "doc.text.magnifyingglass")
                                Text("View Full Note")
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    } else {
                        // No clerking note found
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)

                            Text("No admission clerking note found")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .italic()
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(8)
                    }
                }
                .padding(.leading, 24)
                .padding(.bottom, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    /// Find the first admission keyword in the note body for highlighting
    private func findAdmissionKeyword(in text: String) -> String {
        let lower = text.lowercased()
        for keyword in AdmissionKeywords.primary {
            if lower.contains(keyword) {
                return keyword
            }
        }
        return "admission"
    }
}

#Preview {
    AdmissionsTimelineView()
        .environment(SharedDataStore.shared)
}
