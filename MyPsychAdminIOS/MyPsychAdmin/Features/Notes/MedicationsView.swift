//
//  MedicationsView.swift
//  MyPsychAdmin
//
//  Medications workspace with psychiatric/physical classification,
//  summary section, and medication timeline graphs
//  Matches desktop app's medication_panel.py
//

import SwiftUI
import Charts

struct MedicationsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SharedDataStore.self) private var sharedData
    @State private var extractedMeds: ExtractedMedications?
    @State private var selectedSection: MedicationSection = .summary
    @State private var selectedDrug: ClassifiedDrug?
    @State private var isLoading = true

    enum MedicationSection: String, CaseIterable {
        case summary = "Summary"
        case graphs = "Timeline"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Section Toggle
                Picker("Section", selection: $selectedSection) {
                    ForEach(MedicationSection.allCases, id: \.self) { section in
                        Text(section.rawValue).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                Divider()

                // Content
                if isLoading {
                    Spacer()
                    ProgressView("Extracting medications...")
                    Spacer()
                } else if let meds = extractedMeds, !meds.drugs.isEmpty {
                    switch selectedSection {
                    case .summary:
                        MedicationSummaryView(
                            medications: meds,
                            selectedDrug: $selectedDrug
                        )
                    case .graphs:
                        MedicationTimelineView(
                            medications: meds,
                            selectedDrug: $selectedDrug
                        )
                    }
                } else {
                    ContentUnavailableView {
                        Label("No Medications Found", systemImage: "pills")
                    } description: {
                        Text("No medication mentions were extracted from the clinical notes.")
                    }
                }
            }
            .navigationTitle("Medications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await extractData()
            }
        }
    }

    private func extractData() async {
        // Check cache first
        if let cached = sharedData.getCachedMedications() {
            await MainActor.run {
                extractedMeds = cached
                isLoading = false
            }
            return
        }

        let notes = sharedData.notes

        let meds = await Task.detached(priority: .userInitiated) {
            MedicationExtractor.shared.extractMedications(from: notes)
        }.value

        await MainActor.run {
            if !meds.drugs.isEmpty {
                extractedMeds = meds
                sharedData.setCachedMedications(meds)
            }
            isLoading = false
        }
    }
}

// MARK: - Note Selection with Highlight (for Medications)
struct MedNoteSelection: Equatable {
    let noteId: UUID
    let highlightText: String
}

// MARK: - Medication Summary View
struct MedicationSummaryView: View {
    let medications: ExtractedMedications
    @Binding var selectedDrug: ClassifiedDrug?
    @Environment(SharedDataStore.self) private var sharedData
    @State private var expandedSubtypes: Set<PsychSubtype> = []
    @State private var expandedDrugs: Set<String> = []
    @State private var showPhysical = false
    @State private var noteSelection: MedNoteSelection?

    private func noteFor(selection: MedNoteSelection?) -> ClinicalNote? {
        guard let selection = selection else { return nil }
        return sharedData.notes.first { $0.id == selection.noteId }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Quick Stats
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatCard(
                        title: "Psychiatric",
                        count: medications.psychiatricDrugs.count,
                        icon: "brain",
                        color: .purple
                    )
                    StatCard(
                        title: "Physical",
                        count: medications.physicalDrugs.count,
                        icon: "heart.fill",
                        color: .red
                    )
                }
                .padding(.horizontal)

                // Psychiatric Medications (collapsible by subtype)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "brain")
                            .foregroundColor(.purple)
                        Text("Psychiatric Medications")
                            .font(.headline)
                        Spacer()
                        Text("\(medications.psychiatricDrugs.count) drugs")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)

                    // Group by subtype
                    ForEach(PsychSubtype.allCases.filter { subtype in
                        !medications.drugsBySubtype(subtype).isEmpty
                    }) { subtype in
                        SubtypeSection(
                            subtype: subtype,
                            drugs: medications.drugsBySubtype(subtype),
                            isExpanded: expandedSubtypes.contains(subtype),
                            expandedDrugs: $expandedDrugs,
                            selectedDrug: $selectedDrug,
                            onToggle: {
                                if expandedSubtypes.contains(subtype) {
                                    expandedSubtypes.remove(subtype)
                                } else {
                                    expandedSubtypes.insert(subtype)
                                }
                            },
                            onViewNoteWithHighlight: { noteId, highlight in
                                noteSelection = MedNoteSelection(noteId: noteId, highlightText: highlight)
                            }
                        )
                    }
                }
                .padding(.top, 8)

                // Physical Medications
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        withAnimation {
                            showPhysical.toggle()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                            Text("Physical Medications")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Spacer()
                            Text("\(medications.physicalDrugs.count) drugs")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Image(systemName: showPhysical ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)

                    if showPhysical {
                        ForEach(medications.physicalDrugs) { drug in
                            DrugRow(
                                drug: drug,
                                isExpanded: expandedDrugs.contains(drug.name),
                                onToggle: {
                                    if expandedDrugs.contains(drug.name) {
                                        expandedDrugs.remove(drug.name)
                                    } else {
                                        expandedDrugs.insert(drug.name)
                                    }
                                },
                                onSelect: {
                                    selectedDrug = drug
                                },
                                onViewNoteWithHighlight: { noteId, highlight in
                                    noteSelection = MedNoteSelection(noteId: noteId, highlightText: highlight)
                                }
                            )
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.top, 8)

                Spacer(minLength: 40)
            }
            .padding(.top)
        }
        .sheet(item: Binding(
            get: { noteFor(selection: noteSelection) },
            set: { note in noteSelection = note.map { MedNoteSelection(noteId: $0.id, highlightText: noteSelection?.highlightText ?? "") } }
        )) { note in
            NoteDetailSheet(note: note, highlightText: noteSelection?.highlightText)
        }
    }
}

struct StatCard: View {
    let title: String
    let count: Int
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            VStack(alignment: .leading) {
                Text("\(count)")
                    .font(.title2)
                    .fontWeight(.bold)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct SubtypeSection: View {
    let subtype: PsychSubtype
    let drugs: [ClassifiedDrug]
    let isExpanded: Bool
    @Binding var expandedDrugs: Set<String>
    @Binding var selectedDrug: ClassifiedDrug?
    let onToggle: () -> Void
    var onViewNoteWithHighlight: ((UUID, String) -> Void)? = nil

    private var subtypeColor: Color {
        switch subtype {
        case .antipsychotic: return .purple
        case .antidepressant: return .blue
        case .antimanic: return .orange
        case .hypnotic: return .indigo
        case .anticholinergic: return .green
        case .other: return .gray
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: onToggle) {
                HStack {
                    Image(systemName: subtype.icon)
                        .foregroundColor(subtypeColor)
                        .frame(width: 24)
                    Text(subtype.rawValue)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Spacer()
                    Text("\(drugs.count)")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(subtypeColor)
                        .cornerRadius(10)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(subtypeColor.opacity(0.1))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .padding(.horizontal)

            // Drugs list
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(drugs) { drug in
                        DrugRow(
                            drug: drug,
                            isExpanded: expandedDrugs.contains(drug.name),
                            onToggle: {
                                if expandedDrugs.contains(drug.name) {
                                    expandedDrugs.remove(drug.name)
                                } else {
                                    expandedDrugs.insert(drug.name)
                                }
                            },
                            onSelect: {
                                selectedDrug = drug
                            },
                            onViewNoteWithHighlight: onViewNoteWithHighlight
                        )
                    }
                }
                .padding(.leading, 32)
                .padding(.trailing, 16)
            }
        }
    }
}

struct DrugRow: View {
    let drug: ClassifiedDrug
    let isExpanded: Bool
    let onToggle: () -> Void
    let onSelect: () -> Void
    var onViewNoteWithHighlight: ((UUID, String) -> Void)? = nil

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yy"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(drug.name)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        HStack(spacing: 8) {
                            if let dose = drug.latestDose {
                                Text(dose)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Text("\(drug.mentions.count) mentions")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    if let latest = drug.latestDate {
                        Text(dateFormatter.string(from: latest))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 2)

            // Expanded mentions - scrollable to show all
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("All Mentions (\(drug.mentions.count))")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        Spacer()
                    }

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(drug.mentions.sorted(by: { $0.date > $1.date })) { mention in
                                HStack(alignment: .top) {
                                    Text(dateFormatter.string(from: mention.date))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .frame(width: 60, alignment: .leading)

                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 8) {
                                            if let dose = mention.dose {
                                                Text(dose)
                                                    .font(.caption)
                                                    .fontWeight(.medium)
                                            }
                                            if let freq = mention.frequency {
                                                Text(freq)
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                            if let route = mention.route {
                                                Text(route)
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                        }

                                        Text(mention.context)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                    }

                                    Spacer()

                                    Button {
                                        onViewNoteWithHighlight?(mention.noteId, mention.matchedText)
                                    } label: {
                                        Image(systemName: "doc.text")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                            .padding(8)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .frame(maxHeight: 250)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6).opacity(0.5))
                .cornerRadius(8)
                .padding(.leading, 16)
            }
        }
    }
}

// MARK: - Medication Timeline View
struct MedicationTimelineView: View {
    let medications: ExtractedMedications
    @Binding var selectedDrug: ClassifiedDrug?
    @Environment(SharedDataStore.self) private var sharedData
    @State private var selectedCategory: DrugCategory = .psychiatric
    @State private var noteSelection: MedNoteSelection?

    private func noteFor(selection: MedNoteSelection?) -> ClinicalNote? {
        guard let selection = selection else { return nil }
        return sharedData.notes.first { $0.id == selection.noteId }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Category Picker
                Picker("Category", selection: $selectedCategory) {
                    ForEach(DrugCategory.allCases) { category in
                        Text(category.rawValue).tag(category)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Timeline with inline expansion
                if !currentDrugs.isEmpty {
                    MedicationTimelineList(
                        drugs: currentDrugs,
                        selectedDrug: $selectedDrug,
                        onViewNoteWithHighlight: { noteId, highlight in
                            noteSelection = MedNoteSelection(noteId: noteId, highlightText: highlight)
                        }
                    )
                    .padding(.horizontal)
                } else {
                    ContentUnavailableView {
                        Label("No \(selectedCategory.rawValue) Medications", systemImage: selectedCategory.icon)
                    } description: {
                        Text("No medications found in this category.")
                    }
                }

                Spacer(minLength: 40)
            }
            .padding(.top)
        }
        .sheet(item: Binding(
            get: { noteFor(selection: noteSelection) },
            set: { note in noteSelection = note.map { MedNoteSelection(noteId: $0.id, highlightText: noteSelection?.highlightText ?? "") } }
        )) { note in
            NoteDetailSheet(note: note, highlightText: noteSelection?.highlightText)
        }
    }

    private var currentDrugs: [ClassifiedDrug] {
        switch selectedCategory {
        case .psychiatric:
            return medications.psychiatricDrugs
        case .physical:
            return medications.physicalDrugs
        }
    }
}

// MARK: - Timeline List with Inline Expansion
struct MedicationTimelineList: View {
    let drugs: [ClassifiedDrug]
    @Binding var selectedDrug: ClassifiedDrug?
    var onViewNoteWithHighlight: ((UUID, String) -> Void)?

    private var dateRange: (start: Date, end: Date) {
        let allDates = drugs.flatMap { $0.mentions.map { $0.date } }
        let start = allDates.min() ?? Date()
        let end = allDates.max() ?? Date()
        return (start, end)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Date header
            HStack {
                Text("")
                    .frame(width: 100, alignment: .leading)
                HStack {
                    Text(formatDate(dateRange.start))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatDate(dateRange.end))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            // Drug rows with inline expansion
            ForEach(drugs) { drug in
                TimelineDrugRow(
                    drug: drug,
                    isSelected: selectedDrug?.id == drug.id,
                    dateRange: dateRange,
                    onSelect: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if selectedDrug?.id == drug.id {
                                selectedDrug = nil
                            } else {
                                selectedDrug = drug
                            }
                        }
                    },
                    onViewNoteWithHighlight: onViewNoteWithHighlight
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM yy"
        return f.string(from: date)
    }
}

// MARK: - Timeline Drug Row with Inline Chart
struct TimelineDrugRow: View {
    let drug: ClassifiedDrug
    let isSelected: Bool
    let dateRange: (start: Date, end: Date)
    let onSelect: () -> Void
    var onViewNoteWithHighlight: ((UUID, String) -> Void)?

    private let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yy"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            // Main row with timeline bar
            Button(action: onSelect) {
                HStack(spacing: 0) {
                    Text(drug.name)
                        .font(.caption)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .lineLimit(1)
                        .frame(width: 100, alignment: .leading)
                        .foregroundColor(isSelected ? .blue : .primary)

                    GeometryReader { geometry in
                        let totalWidth = geometry.size.width

                        if let firstDate = drug.earliestDate, let lastDate = drug.latestDate {
                            let startX = dateToX(firstDate, width: totalWidth)
                            let endX = dateToX(lastDate, width: totalWidth)

                            ZStack(alignment: .leading) {
                                // Background track
                                Rectangle()
                                    .fill(Color(.systemGray5))
                                    .frame(height: 8)
                                    .cornerRadius(4)

                                // Drug duration bar
                                Rectangle()
                                    .fill(drugColor)
                                    .frame(width: max(endX - startX, 8), height: 8)
                                    .cornerRadius(4)
                                    .offset(x: startX)

                                // Mention dots
                                ForEach(drug.mentions) { mention in
                                    Circle()
                                        .fill(drugColor)
                                        .frame(width: 6, height: 6)
                                        .offset(x: dateToX(mention.date, width: totalWidth) - 3)
                                }
                            }
                        }
                    }

                    Image(systemName: isSelected ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                }
                .frame(height: 32)
            }
            .buttonStyle(.plain)

            // Expanded content: Chart + Entries
            if isSelected {
                VStack(spacing: 12) {
                    // Dose chart for this medication
                    DrugDoseChart(drug: drug, onViewNote: onViewNoteWithHighlight)
                        .frame(height: 150)

                    // List of entries - scrollable
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Entries (\(drug.mentions.count))")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            Spacer()
                        }

                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 4) {
                                ForEach(drug.mentions.sorted(by: { $0.date > $1.date })) { mention in
                                    Button {
                                        onViewNoteWithHighlight?(mention.noteId, mention.matchedText)
                                    } label: {
                                        HStack {
                                            Text(shortDateFormatter.string(from: mention.date))
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                                .frame(width: 55, alignment: .leading)

                                            if let dose = mention.dose {
                                                Text(dose)
                                                    .font(.caption)
                                                    .fontWeight(.medium)
                                            }

                                            if let freq = mention.frequency {
                                                Text(freq)
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }

                                            Spacer()

                                            Image(systemName: "doc.text")
                                                .font(.caption2)
                                                .foregroundColor(.blue)
                                        }
                                        .foregroundColor(.primary)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                }
                .padding(.top, 8)
                .padding(.leading, 100)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 4)
    }

    private func dateToX(_ date: Date, width: CGFloat) -> CGFloat {
        let total = dateRange.end.timeIntervalSince(dateRange.start)
        guard total > 0 else { return 0 }
        let position = date.timeIntervalSince(dateRange.start)
        return CGFloat(position / total) * width
    }

    private var drugColor: Color {
        if let subtype = drug.psychiatricSubtype {
            switch subtype {
            case .antipsychotic: return .purple
            case .antidepressant: return .blue
            case .antimanic: return .orange
            case .hypnotic: return .indigo
            case .anticholinergic: return .green
            case .other: return .gray
            }
        }
        return .red
    }
}

// MARK: - Drug Dose Chart (inline)
struct DrugDoseChart: View {
    let drug: ClassifiedDrug
    var onViewNote: ((UUID, String) -> Void)?

    @State private var selectedPoint: DoseDataPoint?
    @State private var showExpandedChart = false

    struct DoseDataPoint: Identifiable, Equatable {
        let id = UUID()
        let date: Date
        let dose: Double
        let label: String
        let noteId: UUID
        let matchedText: String

        static func == (lhs: DoseDataPoint, rhs: DoseDataPoint) -> Bool {
            lhs.date == rhs.date && lhs.dose == rhs.dose
        }
    }

    private var doseData: [DoseDataPoint] {
        drug.mentions
            .compactMap { mention -> DoseDataPoint? in
                // Use totalDailyDose if available, otherwise parse from string
                let doseValue: Double
                if let total = mention.totalDailyDose, total > 0 {
                    doseValue = total
                } else if let doseStr = mention.dose {
                    let numericPart = doseStr.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                    guard let parsed = Double(numericPart), parsed > 0 else { return nil }
                    doseValue = parsed
                } else {
                    return nil
                }

                return DoseDataPoint(
                    date: mention.date,
                    dose: doseValue,
                    label: mention.dose ?? "\(Int(doseValue))mg",
                    noteId: mention.noteId,
                    matchedText: mention.matchedText
                )
            }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Dose Over Time")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                Spacer()

                // Show selected dose
                if let selected = selectedPoint {
                    Button {
                        onViewNote?(selected.noteId, selected.matchedText)
                    } label: {
                        HStack(spacing: 4) {
                            Text(selected.label)
                                .font(.caption)
                                .fontWeight(.semibold)
                            Image(systemName: "doc.text")
                                .font(.caption2)
                        }
                        .foregroundColor(.blue)
                    }
                }

                // Expand button
                Button {
                    showExpandedChart = true
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)
                }
            }

            if doseData.isEmpty {
                Text("No dose data available")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Chart {
                    ForEach(doseData) { item in
                        LineMark(
                            x: .value("Date", item.date),
                            y: .value("Dose", item.dose)
                        )
                        .foregroundStyle(drugColor.opacity(0.7))
                        .interpolationMethod(.linear)

                        PointMark(
                            x: .value("Date", item.date),
                            y: .value("Dose", item.dose)
                        )
                        .foregroundStyle(selectedPoint == item ? .blue : drugColor)
                        .symbolSize(selectedPoint == item ? 100 : 50)
                    }

                    // Selection indicator
                    if let selected = selectedPoint {
                        RuleMark(x: .value("Selected", selected.date))
                            .foregroundStyle(.blue.opacity(0.3))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 2]))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: max(1, doseData.count > 1 ? Int(dateSpanDays / 4) : 1))) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(formatAxisDate(date))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let dose = value.as(Double.self) {
                                Text("\(Int(dose))")
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .onTapGesture { location in
                                guard let plotFrame = proxy.plotFrame else { return }
                                let origin = geometry[plotFrame].origin
                                let tapX = location.x - origin.x

                                // Find closest data point
                                var closestPoint: DoseDataPoint?
                                var closestDistance: CGFloat = .infinity

                                for point in doseData {
                                    if let pointX = proxy.position(forX: point.date) {
                                        let distance = abs(pointX - tapX)
                                        if distance < closestDistance && distance < 30 {
                                            closestDistance = distance
                                            closestPoint = point
                                        }
                                    }
                                }

                                if let point = closestPoint {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        selectedPoint = point
                                    }
                                    // Automatically open the note
                                    onViewNote?(point.noteId, point.matchedText)
                                }
                            }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .sheet(isPresented: $showExpandedChart) {
            ExpandedDoseChartView(
                drug: drug,
                doseData: doseData,
                onViewNote: onViewNote
            )
        }
    }

    private var drugColor: Color {
        if let subtype = drug.psychiatricSubtype {
            switch subtype {
            case .antipsychotic: return .purple
            case .antidepressant: return .blue
            case .antimanic: return .orange
            case .hypnotic: return .indigo
            case .anticholinergic: return .green
            case .other: return .gray
            }
        }
        return .red
    }

    private var dateSpanDays: Double {
        guard let first = doseData.first?.date, let last = doseData.last?.date else { return 1 }
        return max(1, last.timeIntervalSince(first) / 86400)
    }

    private func formatAxisDate(_ date: Date) -> String {
        let f = DateFormatter()
        if dateSpanDays > 365 {
            f.dateFormat = "MMM yy"
        } else if dateSpanDays > 30 {
            f.dateFormat = "MMM dd"
        } else {
            f.dateFormat = "dd MMM"
        }
        return f.string(from: date)
    }
}

// MARK: - Expanded Dose Chart View (fullscreen with zoom/scroll)
struct ExpandedDoseChartView: View {
    @Environment(\.dismiss) private var dismiss
    let drug: ClassifiedDrug
    let doseData: [DrugDoseChart.DoseDataPoint]
    var onViewNote: ((UUID, String) -> Void)?

    @State private var selectedPoint: DrugDoseChart.DoseDataPoint?
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yy"
        return f
    }()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Info header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(drug.name)
                            .font(.headline)
                        Text("\(doseData.count) data points")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()

                    // Zoom controls
                    HStack(spacing: 12) {
                        Button {
                            withAnimation {
                                scale = max(0.5, scale - 0.25)
                            }
                        } label: {
                            Image(systemName: "minus.magnifyingglass")
                                .font(.title3)
                        }

                        Text("\(Int(scale * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 45)

                        Button {
                            withAnimation {
                                scale = min(4.0, scale + 0.25)
                            }
                        } label: {
                            Image(systemName: "plus.magnifyingglass")
                                .font(.title3)
                        }

                        Button {
                            withAnimation {
                                scale = 1.0
                                offset = .zero
                            }
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.title3)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))

                // Selected point info
                if let selected = selectedPoint {
                    HStack {
                        Text(shortDateFormatter.string(from: selected.date))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(selected.label)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                        Button {
                            onViewNote?(selected.noteId, selected.matchedText)
                            dismiss()
                        } label: {
                            HStack(spacing: 4) {
                                Text("View Note")
                                    .font(.caption)
                                Image(systemName: "doc.text")
                            }
                            .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                }

                // Zoomable chart area
                GeometryReader { geometry in
                    ScrollView([.horizontal, .vertical], showsIndicators: true) {
                        chartContent
                            .frame(
                                width: geometry.size.width * scale,
                                height: max(300, geometry.size.height * 0.6) * scale
                            )
                            .padding()
                    }
                }

                // Data table
                VStack(alignment: .leading, spacing: 8) {
                    Text("All Data Points")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal)

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(doseData) { point in
                                Button {
                                    selectedPoint = point
                                } label: {
                                    HStack {
                                        Text(shortDateFormatter.string(from: point.date))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .frame(width: 70, alignment: .leading)

                                        Text(point.label)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)

                                        Spacer()

                                        if selectedPoint == point {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                                    .background(selectedPoint == point ? Color.blue.opacity(0.1) : Color.clear)
                                }
                                .buttonStyle(.plain)

                                Divider()
                                    .padding(.leading)
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Dose Chart")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var chartContent: some View {
        Chart {
            ForEach(doseData) { item in
                LineMark(
                    x: .value("Date", item.date),
                    y: .value("Dose", item.dose)
                )
                .foregroundStyle(drugColor.opacity(0.7))
                .interpolationMethod(.linear)

                PointMark(
                    x: .value("Date", item.date),
                    y: .value("Dose", item.dose)
                )
                .foregroundStyle(selectedPoint == item ? .blue : drugColor)
                .symbolSize(selectedPoint == item ? 150 : 80)
                .annotation(position: .top, spacing: 4) {
                    if selectedPoint == item {
                        Text(item.label)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(4)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
            }

            if let selected = selectedPoint {
                RuleMark(x: .value("Selected", selected.date))
                    .foregroundStyle(.blue.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 2]))
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(formatAxisDate(date))
                            .font(.caption2)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let dose = value.as(Double.self) {
                        Text("\(Int(dose))mg")
                            .font(.caption2)
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        guard let plotFrame = proxy.plotFrame else { return }
                        let origin = geometry[plotFrame].origin
                        let tapX = location.x - origin.x

                        var closestPoint: DrugDoseChart.DoseDataPoint?
                        var closestDistance: CGFloat = .infinity

                        for point in doseData {
                            if let pointX = proxy.position(forX: point.date) {
                                let distance = abs(pointX - tapX)
                                if distance < closestDistance && distance < 40 {
                                    closestDistance = distance
                                    closestPoint = point
                                }
                            }
                        }

                        if let point = closestPoint {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedPoint = point
                            }
                        }
                    }
            }
        }
    }

    private var drugColor: Color {
        if let subtype = drug.psychiatricSubtype {
            switch subtype {
            case .antipsychotic: return .purple
            case .antidepressant: return .blue
            case .antimanic: return .orange
            case .hypnotic: return .indigo
            case .anticholinergic: return .green
            case .other: return .gray
            }
        }
        return .red
    }

    private var dateSpanDays: Double {
        guard let first = doseData.first?.date, let last = doseData.last?.date else { return 1 }
        return max(1, last.timeIntervalSince(first) / 86400)
    }

    private func formatAxisDate(_ date: Date) -> String {
        let f = DateFormatter()
        if dateSpanDays > 365 {
            f.dateFormat = "MMM yy"
        } else if dateSpanDays > 30 {
            f.dateFormat = "MMM dd"
        } else {
            f.dateFormat = "dd MMM"
        }
        return f.string(from: date)
    }
}

struct MedicationGanttChart: View {
    let drugs: [ClassifiedDrug]
    @Binding var selectedDrug: ClassifiedDrug?

    private var dateRange: (start: Date, end: Date) {
        let allDates = drugs.flatMap { $0.mentions.map { $0.date } }
        let start = allDates.min() ?? Date()
        let end = allDates.max() ?? Date()
        return (start, end)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with date labels
            HStack {
                Text("")
                    .frame(width: 100, alignment: .leading)

                GeometryReader { geometry in
                    let range = dateRange
                    let formatter = DateFormatter()

                    HStack {
                        Text(formatDate(range.start, formatter: formatter))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatDate(range.end, formatter: formatter))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(height: 20)
            .padding(.bottom, 8)

            // Gantt bars
            ForEach(drugs) { drug in
                Button {
                    selectedDrug = drug
                } label: {
                    HStack(spacing: 0) {
                        Text(drug.name)
                            .font(.caption)
                            .lineLimit(1)
                            .frame(width: 100, alignment: .leading)
                            .foregroundColor(selectedDrug?.id == drug.id ? .blue : .primary)

                        GeometryReader { geometry in
                            let range = dateRange
                            let totalWidth = geometry.size.width

                            if let firstDate = drug.earliestDate, let lastDate = drug.latestDate {
                                let startX = dateToX(firstDate, range: range, width: totalWidth)
                                let endX = dateToX(lastDate, range: range, width: totalWidth)

                                ZStack(alignment: .leading) {
                                    // Background track
                                    Rectangle()
                                        .fill(Color(.systemGray5))
                                        .frame(height: 8)
                                        .cornerRadius(4)

                                    // Drug duration bar
                                    Rectangle()
                                        .fill(drugColor(drug))
                                        .frame(width: max(endX - startX, 8), height: 8)
                                        .cornerRadius(4)
                                        .offset(x: startX)

                                    // Mention dots
                                    ForEach(drug.mentions) { mention in
                                        Circle()
                                            .fill(drugColor(drug))
                                            .frame(width: 6, height: 6)
                                            .offset(x: dateToX(mention.date, range: range, width: totalWidth) - 3)
                                    }
                                }
                            }
                        }
                    }
                    .frame(height: 32)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func dateToX(_ date: Date, range: (start: Date, end: Date), width: CGFloat) -> CGFloat {
        let total = range.end.timeIntervalSince(range.start)
        guard total > 0 else { return 0 }
        let position = date.timeIntervalSince(range.start)
        return CGFloat(position / total) * width
    }

    private func formatDate(_ date: Date, formatter: DateFormatter) -> String {
        formatter.dateFormat = "MMM yy"
        return formatter.string(from: date)
    }

    private func drugColor(_ drug: ClassifiedDrug) -> Color {
        if let subtype = drug.psychiatricSubtype {
            switch subtype {
            case .antipsychotic: return .purple
            case .antidepressant: return .blue
            case .antimanic: return .orange
            case .hypnotic: return .indigo
            case .anticholinergic: return .green
            case .other: return .gray
            }
        }
        return .red
    }
}

struct MedicationFrequencyChart: View {
    let drugs: [ClassifiedDrug]

    private var mentionsByMonth: [(Date, Int)] {
        let allMentions = drugs.flatMap { $0.mentions }
        var monthCounts: [Date: Int] = [:]

        let calendar = Calendar.current
        for mention in allMentions {
            let components = calendar.dateComponents([.year, .month], from: mention.date)
            if let monthStart = calendar.date(from: components) {
                monthCounts[monthStart, default: 0] += 1
            }
        }

        return monthCounts.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Medication Mentions Over Time")
                .font(.subheadline)
                .fontWeight(.medium)

            Chart {
                ForEach(mentionsByMonth, id: \.0) { item in
                    BarMark(
                        x: .value("Month", item.0),
                        y: .value("Mentions", item.1)
                    )
                    .foregroundStyle(.blue.gradient)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 6)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(formatMonth(date))
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func formatMonth(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM yy"
        return f.string(from: date)
    }
}

struct DrugDetailCard: View {
    let drug: ClassifiedDrug
    var onViewNoteWithHighlight: ((UUID, String) -> Void)? = nil
    @State private var showAllMentions = false

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd MMM yyyy"
        return f
    }()

    private let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yy"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(drug.name)
                        .font(.headline)

                    HStack(spacing: 8) {
                        Label(drug.category.rawValue, systemImage: drug.category.icon)
                        if let subtype = drug.psychiatricSubtype {
                            Text("• \(subtype.rawValue)")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                Spacer()
            }

            Divider()

            HStack {
                VStack(alignment: .leading) {
                    Text("First Mentioned")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let date = drug.earliestDate {
                        Text(dateFormatter.string(from: date))
                            .font(.subheadline)
                    }
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Last Mentioned")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let date = drug.latestDate {
                        Text(dateFormatter.string(from: date))
                            .font(.subheadline)
                    }
                }
            }

            HStack {
                VStack(alignment: .leading) {
                    Text("Total Mentions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(drug.mentions.count)")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                Spacer()
                if let dose = drug.latestDose {
                    VStack(alignment: .trailing) {
                        Text("Latest Dose")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(dose)
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                }
            }

            // Recent mentions with note viewing
            if !drug.mentions.isEmpty {
                Divider()

                Button {
                    withAnimation {
                        showAllMentions.toggle()
                    }
                } label: {
                    HStack {
                        Text("Recent Mentions")
                            .font(.caption)
                            .fontWeight(.medium)
                        Spacer()
                        Image(systemName: showAllMentions ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                if showAllMentions {
                    VStack(spacing: 6) {
                        ForEach(drug.mentions.suffix(5).reversed()) { mention in
                            Button {
                                onViewNoteWithHighlight?(mention.noteId, mention.matchedText)
                            } label: {
                                HStack {
                                    Text(shortDateFormatter.string(from: mention.date))
                                        .font(.caption2)
                                        .frame(width: 55, alignment: .leading)

                                    if let dose = mention.dose {
                                        Text(dose)
                                            .font(.caption2)
                                            .fontWeight(.medium)
                                    }

                                    Spacer()

                                    Image(systemName: "doc.text")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                }
                                .foregroundColor(.primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    MedicationsView()
        .environment(SharedDataStore.shared)
}
