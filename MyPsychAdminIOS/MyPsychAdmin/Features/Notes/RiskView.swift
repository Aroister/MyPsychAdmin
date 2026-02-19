//
//  RiskView.swift
//  MyPsychAdmin
//
//  Risk overview panel matching desktop app's risk_overview_panel.py
//  Displays extracted risk incidents with collapsible categories
//

import SwiftUI
import Charts

// MARK: - Progress Data for Narrative (uses Episode from AdmissionsTimelineView)
struct RiskProgressData {
    let episodes: [Episode]
    let risks: ExtractedRisks
    let notes: [ClinicalNote]
    let patientName: String
    let pronouns: Pronouns
}

// MARK: - Risk Narrative Generator
enum RiskNarrativeGenerator {
    static func generateNarrative(from data: RiskProgressData) -> String {
        var sections: [String] = []
        sections.append(generateOverview(from: data))
        if data.episodes.filter({ $0.type == .inpatient }).count > 0 {
            sections.append(generateAdmissionHistory(from: data))
        }
        sections.append(generateFlowingNarrative(from: data))
        return sections.joined(separator: "\n\n")
    }

    private static func generateOverview(from data: RiskProgressData) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"

        var lines: [String] = ["OVERVIEW", String(repeating: "─", count: 40)]

        let dates = data.notes.map { $0.date }
        if let minDate = dates.min(), let maxDate = dates.max() {
            lines.append("Period: \(dateFormatter.string(from: minDate)) to \(dateFormatter.string(from: maxDate))")
            let months = max(1, (Calendar.current.dateComponents([.month], from: minDate, to: maxDate).month ?? 0) + 1)
            lines.append("Total months reviewed: \(months)")
        }

        let inpatientEpisodes = data.episodes.filter { $0.type == .inpatient }
        let totalDays = inpatientEpisodes.reduce(0) { $0 + $1.duration }
        if inpatientEpisodes.isEmpty {
            lines.append("Admissions: None recorded")
        } else {
            lines.append("Admissions: \(inpatientEpisodes.count) (\(totalDays) inpatient days)")
        }

        lines.append("Total incidents: \(data.risks.incidents.count)")

        let physicalCount = data.risks.incidents.filter { $0.category == .physicalAggression }.count
        let verbalCount = data.risks.incidents.filter { $0.category == .verbalAggression }.count
        let selfHarmCount = data.risks.incidents.filter { $0.category == .selfHarm }.count

        if physicalCount > 0 { lines.append("  • Physical aggression: \(physicalCount)") }
        if verbalCount > 0 { lines.append("  • Verbal aggression: \(verbalCount)") }
        if selfHarmCount > 0 { lines.append("  • Self-harm: \(selfHarmCount)") }

        return lines.joined(separator: "\n")
    }

    private static func generateAdmissionHistory(from data: RiskProgressData) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d MMM yy"

        var lines: [String] = ["ADMISSION HISTORY", String(repeating: "─", count: 40)]
        let admissions = data.episodes.filter { $0.type == .inpatient }
        for (index, admission) in admissions.enumerated() {
            lines.append("Admission \(index + 1): \(dateFormatter.string(from: admission.start)) to \(dateFormatter.string(from: admission.end)) (\(admission.duration) days)")
        }
        return lines.joined(separator: "\n")
    }

    private static func generateFlowingNarrative(from data: RiskProgressData) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        let shortFormatter = DateFormatter()
        shortFormatter.dateFormat = "d MMM yyyy"

        var lines: [String] = ["NARRATIVE", String(repeating: "─", count: 40)]

        let dates = data.notes.map { $0.date }
        guard let minDate = dates.min() else {
            lines.append("Insufficient data to generate narrative.")
            return lines.joined(separator: "\n")
        }

        let name = data.patientName.isEmpty ? "The patient" : data.patientName.components(separatedBy: " ").first ?? "The patient"
        let pronoun = data.pronouns.subject.lowercased()
        let pronounCap = data.pronouns.subject

        var paragraphs: [String] = []
        paragraphs.append("The records begin in \(dateFormatter.string(from: minDate)) when \(name) was under care.")

        for (index, episode) in data.episodes.enumerated() {
            let episodeIncidents = data.risks.incidents.filter { $0.date >= episode.start && $0.date <= episode.end }

            if episode.type == .inpatient {
                var text = "\(pronounCap) required admission on \(shortFormatter.string(from: episode.start))"
                if episode.duration > 0 {
                    text += ", remaining an inpatient for \(episode.duration) days."
                } else {
                    text += "."
                }
                if !episodeIncidents.isEmpty {
                    text += " During this admission, there were \(episodeIncidents.count) recorded incidents."
                }
                paragraphs.append(text)
            } else if !episodeIncidents.isEmpty {
                if index > 0 {
                    paragraphs.append("Following discharge, \(pronoun) remained in the community with \(episodeIncidents.count) incidents recorded.")
                } else {
                    paragraphs.append("During this period in the community, there were \(episodeIncidents.count) incidents recorded.")
                }
            } else if episode.duration > 30 {
                paragraphs.append("\(pronounCap) remained stable in the community with no significant incidents recorded.")
            }
        }

        paragraphs.append("Overall, the risk level is assessed as \(data.risks.riskLevel.rawValue.lowercased()) based on \(data.risks.incidents.count) recorded incidents.")

        lines.append(paragraphs.joined(separator: "\n\n"))
        return lines.joined(separator: "\n")
    }
}

struct RiskView: View {
    let notes: [ClinicalNote]
    let onViewNote: ((UUID) -> Void)?

    @Environment(SharedDataStore.self) private var sharedData
    @State private var extractedRisks: ExtractedRisks?
    @State private var isLoading = true
    @State private var expandedCategories: Set<RiskCategory> = []
    @State private var selectedNote: RiskNoteSelection?
    @State private var showExpandedChart = false

    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if let risks = extractedRisks, !risks.incidents.isEmpty {
                riskContentView(risks)
            } else {
                emptyStateView
            }
        }
        .task {
            await extractRisks()
        }
        .sheet(item: $selectedNote) { selection in
            if let note = notes.first(where: { $0.id == selection.noteId }) {
                RiskNoteDetailSheet(note: note, highlightText: selection.highlightText)
            }
        }
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Analysing risk indicators...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Risk Indicators Found", systemImage: "checkmark.shield")
        } description: {
            Text("No risk-related incidents were detected in the clinical notes.")
        }
    }

    // MARK: - Main Content (Overview only - no tabs)
    @ViewBuilder
    private func riskContentView(_ risks: ExtractedRisks) -> some View {
        overviewSection(risks)
    }

    // MARK: - Overview Section
    @ViewBuilder
    private func overviewSection(_ risks: ExtractedRisks) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Summary Section
                    riskSummarySection(risks)

                    // Category Distribution Chart
                    if risks.categoriesAffected > 1 {
                        categoryChartSection(risks) { category in
                            // Expand and scroll to the tapped category
                            withAnimation(.easeInOut(duration: 0.3)) {
                                expandedCategories.insert(category)
                                proxy.scrollTo(category.id, anchor: .top)
                            }
                        }
                    }

                    // Monthly Incidents Chart (expandable)
                    monthlyIncidentChart(risks)

                    // Risk Categories
                    ForEach(RiskCategory.allCases) { category in
                        let categoryIncidents = risks.incidents(for: category)
                        if !categoryIncidents.isEmpty {
                            categorySection(category: category, incidents: categoryIncidents)
                                .id(category.id)
                        }
                    }
                }
                .padding()
            }
        }
        .sheet(isPresented: $showExpandedChart) {
            expandedChartSheet(risks)
        }
    }

    // MARK: - Expanded Chart Sheet
    private func expandedChartSheet(_ risks: ExtractedRisks) -> some View {
        let monthlyData = groupIncidentsByMonth(risks.incidents)
        let sortedData = monthlyData.sorted(by: { $0.key < $1.key })

        return NavigationStack {
            ScrollView(.vertical) {
                Chart {
                    // Horizontal bars - month on Y axis, count on X axis
                    ForEach(sortedData, id: \.key) { month, count in
                        BarMark(
                            x: .value("Incidents", count),
                            y: .value("Month", month)
                        )
                        .foregroundStyle(barColor(for: count))
                        .annotation(position: .trailing) {
                            Text("\(count)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .chartYAxis {
                    // Show all month labels in expanded view
                    AxisMarks { value in
                        AxisValueLabel {
                            if let str = value.as(String.self) {
                                Text(formatMonthLabel(str))
                                    .font(.caption)
                            }
                        }
                    }
                }
                .frame(height: max(CGFloat(sortedData.count) * 36, 300))
                .padding()
            }
            .navigationTitle("Monthly Incidents")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showExpandedChart = false }
                }
            }
        }
    }


    // MARK: - Monthly Incident Chart
    private func monthlyIncidentChart(_ risks: ExtractedRisks) -> some View {
        let monthlyData = groupIncidentsByMonth(risks.incidents)
        let sortedData = monthlyData.sorted(by: { $0.key < $1.key })

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Monthly Incidents")
                    .font(.headline)
                Spacer()
                if sortedData.count > 6 {
                    Button {
                        showExpandedChart = true
                    } label: {
                        Label("Expand", systemImage: "arrow.up.left.and.arrow.down.right")
                            .font(.caption)
                    }
                }
            }

            if monthlyData.isEmpty {
                Text("No incidents to display")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                // Show limited months in compact view
                let displayData = sortedData.suffix(12)
                Chart {
                    ForEach(Array(displayData), id: \.key) { month, count in
                        BarMark(
                            x: .value("Month", month),
                            y: .value("Incidents", count)
                        )
                        .foregroundStyle(barColor(for: count))
                    }
                }
                .frame(height: 150)
                .chartXAxis {
                    // Compact view: show only year labels at year boundaries
                    AxisMarks { value in
                        if let str = value.as(String.self) {
                            let allMonths = Array(displayData).map { $0.key }
                            // Show label only at year boundaries (January) or first/last
                            let isJanuary = str.hasSuffix("-01")
                            let isFirst = allMonths.first == str
                            let isLast = allMonths.last == str
                            AxisValueLabel {
                                if isJanuary || isFirst || isLast {
                                    Text(formatYearLabel(str))
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                }

                // Show data range and expand hint
                if sortedData.count > 12 {
                    Text("Showing last 12 months. Tap Expand for full view.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Risk level legend
                HStack(spacing: 12) {
                    ForEach([(0, "Quiet", Color(red: 0.18, green: 0.35, blue: 0.24)),
                             (1, "Low", Color.green),
                             (4, "Moderate", Color.orange),
                             (9, "Elevated", Color.orange.opacity(0.8)),
                             (16, "High", Color.red)], id: \.1) { _, label, color in
                        HStack(spacing: 4) {
                            Circle().fill(color).frame(width: 8, height: 8)
                            Text(label).font(.caption2)
                        }
                    }
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func barColor(for count: Int) -> Color {
        switch count {
        case 0: return Color(red: 0.18, green: 0.35, blue: 0.24)
        case 1...3: return .green
        case 4...8: return .orange
        case 9...15: return Color(red: 0.98, green: 0.45, blue: 0.09)
        default: return .red
        }
    }

    private func groupIncidentsByMonth(_ incidents: [RiskIncident]) -> [String: Int] {
        var result: [String: Int] = [:]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"

        for incident in incidents {
            let key = formatter.string(from: incident.date)
            result[key, default: 0] += 1
        }
        return result
    }

    private func formatMonthLabel(_ yearMonth: String) -> String {
        let parts = yearMonth.split(separator: "-")
        guard parts.count == 2, let month = Int(parts[1]) else { return yearMonth }
        let monthNames = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        let year = String(parts[0].suffix(2))
        return "\(monthNames[month]) '\(year)"
    }

    // Year-only format for compact view - just "2024" or "2025"
    private func formatYearLabel(_ yearMonth: String) -> String {
        let parts = yearMonth.split(separator: "-")
        guard parts.count == 2 else { return yearMonth }
        return String(parts[0]) // Return full year like "2024"
    }


    // MARK: - Summary Section
    private func riskSummarySection(_ risks: ExtractedRisks) -> some View {
        VStack(spacing: 12) {
            // Risk Level Banner
            HStack {
                Image(systemName: risks.riskLevel.icon)
                    .font(.title2)
                Text("Overall Risk: \(risks.riskLevel.rawValue)")
                    .font(.headline)
                Spacer()
                Text("Score: \(risks.totalScore)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(risks.riskLevel.color.opacity(0.2))
            .foregroundStyle(risks.riskLevel == .low ? .primary : risks.riskLevel.color)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Recommendation
            Text(risks.riskLevel.recommendation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)

            // Key Metrics
            HStack(spacing: 12) {
                metricCard(title: "Incidents", value: "\(risks.incidents.count)", icon: "exclamationmark.triangle")
                metricCard(title: "HIGH Severity", value: "\(risks.highSeverityCount)", icon: "exclamationmark.octagon", color: .red)
                metricCard(title: "Categories", value: "\(risks.categoriesAffected)", icon: "folder")
            }

            // Date Range
            if let dateRange = risks.dateRange {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundStyle(.secondary)
                    Text("\(dateRange.start.formatted(date: .abbreviated, time: .omitted)) - \(dateRange.end.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func metricCard(title: String, value: String, icon: String, color: Color = .primary) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(color)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Category Chart
    private func categoryChartSection(_ risks: ExtractedRisks, onTapCategory: @escaping (RiskCategory) -> Void) -> some View {
        let categoriesWithData = RiskCategory.allCases
            .map { ($0, risks.incidents(for: $0).count) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Distribution by Category")
                    .font(.headline)
                Spacer()
                Text("Tap to jump")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Horizontal bar chart - tappable rows
            VStack(spacing: 8) {
                ForEach(categoriesWithData, id: \.0) { category, count in
                    Button {
                        onTapCategory(category)
                    } label: {
                        HStack(spacing: 8) {
                            // Category name (fixed width for alignment)
                            HStack(spacing: 6) {
                                Image(systemName: category.icon)
                                    .font(.caption)
                                    .foregroundStyle(category.color)
                                    .frame(width: 16)
                                Text(shortName(for: category))
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                            }
                            .frame(width: 100, alignment: .leading)

                            // Bar
                            GeometryReader { geometry in
                                let maxCount = categoriesWithData.map { $0.1 }.max() ?? 1
                                let barWidth = (CGFloat(count) / CGFloat(maxCount)) * geometry.size.width

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(category.color)
                                    .frame(width: max(barWidth, 4), height: 20)
                            }
                            .frame(height: 20)

                            // Count
                            Text("\(count)")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .frame(width: 30, alignment: .trailing)

                            // Chevron indicator
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // Short names for categories to fit in chart
    private func shortName(for category: RiskCategory) -> String {
        switch category {
        case .verbalAggression: return "Verbal Agg."
        case .physicalAggression: return "Physical Agg."
        case .propertyDamage: return "Property"
        case .selfHarm: return "Self-Harm"
        case .sexualBehaviour: return "Sexual"
        case .bullyingExploitation: return "Bullying"
        case .selfNeglect: return "Self-Neglect"
        case .awolAbsconding: return "AWOL"
        case .substanceMisuse: return "Substances"
        case .nonCompliance: return "Non-Comply"
        case .suicidalIdeation: return "Suicidal"
        case .paranoia: return "Paranoia"
        }
    }

    // MARK: - Category Section
    private func categorySection(category: RiskCategory, incidents: [RiskIncident]) -> some View {
        VStack(spacing: 0) {
            // Header (Collapsible)
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if expandedCategories.contains(category) {
                        expandedCategories.remove(category)
                    } else {
                        expandedCategories.insert(category)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: category.icon)
                        .foregroundStyle(category.color)
                        .frame(width: 24)

                    Text(category.rawValue)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Spacer()

                    // Severity badges
                    let highCount = incidents.filter { $0.severity == .high }.count
                    if highCount > 0 {
                        Text("\(highCount) HIGH")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }

                    Text("\(incidents.count)")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)

                    Image(systemName: expandedCategories.contains(category) ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(category.color.opacity(0.1))
            }
            .buttonStyle(.plain)

            // Content (Expanded)
            if expandedCategories.contains(category) {
                VStack(spacing: 8) {
                    // Subcategory pills
                    let subcategories = Set(incidents.map { $0.subcategory }).sorted()
                    if subcategories.count > 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(subcategories, id: \.self) { subcategory in
                                    let subIncidents = incidents.filter { $0.subcategory == subcategory }
                                    let maxSeverity = subIncidents.map { $0.severity }.max() ?? .low

                                    HStack(spacing: 4) {
                                        Text(subcategory)
                                            .font(.caption)
                                        Text("\(subIncidents.count)")
                                            .font(.caption2.bold())
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color(.systemGray5))
                                    .overlay(
                                        Capsule()
                                            .stroke(maxSeverity.color, lineWidth: 2)
                                    )
                                    .clipShape(Capsule())
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    // Incidents grouped by date
                    let groupedByDate = Dictionary(grouping: incidents) { incident in
                        Calendar.current.startOfDay(for: incident.date)
                    }
                    let sortedDates = groupedByDate.keys.sorted(by: >)

                    ForEach(sortedDates, id: \.self) { date in
                        if let dateIncidents = groupedByDate[date] {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal)

                                ForEach(dateIncidents) { incident in
                                    incidentCard(incident)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(category.color.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Incident Card
    private func incidentCard(_ incident: RiskIncident) -> some View {
        Button {
            selectedNote = RiskNoteSelection(noteId: incident.noteId, highlightText: incident.matchedText)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                // Severity indicator
                Circle()
                    .fill(incident.severity.color)
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(incident.subcategory)
                            .font(.subheadline.bold())
                        Spacer()
                        Text(incident.severity.rawValue)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(incident.severity.color.opacity(0.2))
                            .foregroundStyle(incident.severity.color)
                            .clipShape(Capsule())
                    }

                    // Context with highlighted matched text
                    highlightedText(incident.context, highlight: incident.matchedText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Highlighted Text
    private func highlightedText(_ text: String, highlight: String) -> Text {
        guard !highlight.isEmpty else { return Text(text) }

        let lowercaseText = text.lowercased()
        let lowercaseHighlight = highlight.lowercased()

        guard let range = lowercaseText.range(of: lowercaseHighlight) else {
            return Text(text)
        }

        let startIndex = text.index(text.startIndex, offsetBy: lowercaseText.distance(from: lowercaseText.startIndex, to: range.lowerBound))
        let endIndex = text.index(text.startIndex, offsetBy: lowercaseText.distance(from: lowercaseText.startIndex, to: range.upperBound))

        let before = String(text[..<startIndex])
        let match = String(text[startIndex..<endIndex])
        let after = String(text[endIndex...])

        return Text(before) + Text(match).bold().foregroundColor(.yellow) + Text(after)
    }

    // MARK: - Extract Risks
    private func extractRisks() async {
        // Check cache first
        if let cached = sharedData.getCachedRisks() {
            await MainActor.run {
                extractedRisks = cached
                isLoading = false
            }
            return
        }

        let extractor = RiskExtractor.shared
        let result = await Task.detached {
            extractor.extractRisks(from: notes)
        }.value

        await MainActor.run {
            extractedRisks = result
            sharedData.setCachedRisks(result)
            isLoading = false
        }
    }
}

// MARK: - Note Selection
struct RiskNoteSelection: Identifiable {
    let id = UUID()
    let noteId: UUID
    let highlightText: String
}

// MARK: - Note Detail Sheet
struct RiskNoteDetailSheet: View {
    let note: ClinicalNote
    let highlightText: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Header
                        VStack(alignment: .leading, spacing: 4) {
                            Text(note.type)
                                .font(.headline)
                            HStack {
                                Text(note.author)
                                Spacer()
                                Text(note.date.formatted(date: .abbreviated, time: .shortened))
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        Divider()

                        // Body with highlighting
                        RiskHighlightedNoteBody(text: note.body, highlightText: highlightText)
                            .id("noteBody")
                    }
                    .padding()
                }
                .onAppear {
                    if highlightText != nil {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation {
                                proxy.scrollTo("highlight", anchor: .center)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Clinical Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Highlighted Note Body
struct RiskHighlightedNoteBody: View {
    let text: String
    let highlightText: String?

    var body: some View {
        if let highlight = highlightText, !highlight.isEmpty,
           let range = text.range(of: highlight, options: .caseInsensitive) {
            let startIndex = text.distance(from: text.startIndex, to: range.lowerBound)
            let endIndex = text.distance(from: text.startIndex, to: range.upperBound)

            VStack(alignment: .leading, spacing: 0) {
                // Before highlight
                if startIndex > 0 {
                    Text(String(text[..<range.lowerBound]))
                        .font(.body)
                }

                // Highlighted section
                Text(String(text[range]))
                    .font(.body)
                    .padding(4)
                    .background(Color.yellow.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .id("highlight")

                // After highlight
                if endIndex < text.count {
                    Text(String(text[range.upperBound...]))
                        .font(.body)
                }
            }
        } else {
            Text(text)
                .font(.body)
        }
    }
}

#Preview {
    RiskView(notes: [], onViewNote: nil)
}
