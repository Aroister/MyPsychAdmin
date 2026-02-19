//
//  PhysicalHealthView.swift
//  MyPsychAdmin
//
//  Physical health workspace with BMI, BP charts, and blood tests table
//  Matches desktop app's physical_health_panel.py
//

import SwiftUI
import Charts

// MARK: - Note Selection with Highlight
struct NoteSelection: Equatable {
    let noteId: UUID
    let highlightText: String
}

struct PhysicalHealthView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SharedDataStore.self) private var sharedData
    @State private var extractedData: ExtractedPhysicalHealth?
    @State private var selectedSection: PhysicalHealthSection = .overview
    @State private var selectedTest: String?
    @State private var isLoading = true

    enum PhysicalHealthSection: String, CaseIterable {
        case overview = "Overview"
        case bmi = "BMI"
        case bp = "Blood Pressure"
        case bloodTests = "Blood Tests"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Section Picker
                Picker("Section", selection: $selectedSection) {
                    ForEach(PhysicalHealthSection.allCases, id: \.self) { section in
                        Text(section.rawValue).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                Divider()

                // Content
                if isLoading {
                    Spacer()
                    ProgressView("Extracting physical health data...")
                    Spacer()
                } else if let data = extractedData {
                    ScrollView {
                        VStack(spacing: 16) {
                            switch selectedSection {
                            case .overview:
                                OverviewSection(data: data, selectedSection: $selectedSection)
                            case .bmi:
                                BMISection(readings: data.bmiReadings)
                            case .bp:
                                BPSection(readings: data.bpReadings)
                            case .bloodTests:
                                BloodTestsSection(
                                    tests: data.bloodTests,
                                    selectedTest: $selectedTest
                                )
                            }
                        }
                        .padding()
                    }
                } else {
                    ContentUnavailableView {
                        Label("No Physical Health Data", systemImage: "heart.text.square")
                    } description: {
                        Text("No BMI, BP, or blood test results were extracted from the clinical notes.")
                    }
                }
            }
            .navigationTitle("Physical Health")
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
        let notes = sharedData.notes

        let data = await Task.detached(priority: .userInitiated) {
            PhysicalHealthExtractor.shared.extractPhysicalHealth(from: notes)
        }.value

        await MainActor.run {
            if !data.bmiReadings.isEmpty || !data.bpReadings.isEmpty || !data.bloodTests.isEmpty {
                extractedData = data
            }
            isLoading = false
        }
    }
}

// MARK: - Overview Section
struct OverviewSection: View {
    let data: ExtractedPhysicalHealth
    @Binding var selectedSection: PhysicalHealthView.PhysicalHealthSection

    var body: some View {
        VStack(spacing: 16) {
            // Summary Cards - tappable to navigate to sections
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                SummaryCard(
                    title: "BMI Readings",
                    value: "\(data.bmiReadings.count)",
                    icon: "scalemass",
                    color: .blue,
                    subtitle: latestBMI
                )
                .onTapGesture {
                    withAnimation { selectedSection = .bmi }
                }

                SummaryCard(
                    title: "BP Readings",
                    value: "\(data.bpReadings.count)",
                    icon: "heart.fill",
                    color: .red,
                    subtitle: latestBP
                )
                .onTapGesture {
                    withAnimation { selectedSection = .bp }
                }

                SummaryCard(
                    title: "Blood Tests",
                    value: "\(data.bloodTests.count)",
                    icon: "drop.fill",
                    color: .purple,
                    subtitle: "\(totalResults) results"
                )
                .onTapGesture {
                    withAnimation { selectedSection = .bloodTests }
                }

                SummaryCard(
                    title: "Abnormal",
                    value: "\(abnormalCount)",
                    icon: "exclamationmark.triangle.fill",
                    color: abnormalCount > 0 ? .orange : .green,
                    subtitle: abnormalCount > 0 ? "Flagged" : "All normal"
                )
                .onTapGesture {
                    withAnimation { selectedSection = .bloodTests }
                }
            }

            // Recent BMI Chart (if available)
            if !data.bmiReadings.isEmpty {
                CollapsibleSection(title: "BMI Trend", icon: "chart.line.uptrend.xyaxis", isExpanded: true) {
                    MiniLineChart(
                        data: data.bmiReadings.suffix(10).map { ($0.date, $0.value) },
                        color: .blue,
                        yAxisLabel: "BMI"
                    )
                    .frame(height: 150)
                }
            }

            // Recent BP Chart (if available)
            if !data.bpReadings.isEmpty {
                CollapsibleSection(title: "Blood Pressure Trend", icon: "heart.text.square", isExpanded: true) {
                    BPMiniChart(readings: Array(data.bpReadings.suffix(10)))
                        .frame(height: 150)
                }
            }

            // Flagged Results
            if !flaggedResults.isEmpty {
                CollapsibleSection(title: "Flagged Results", icon: "exclamationmark.triangle", isExpanded: true) {
                    VStack(spacing: 8) {
                        ForEach(flaggedResults.prefix(5)) { result in
                            FlaggedResultRow(result: result)
                        }
                        if flaggedResults.count > 5 {
                            Text("+ \(flaggedResults.count - 5) more")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var latestBMI: String {
        guard let latest = data.bmiReadings.last else { return "No data" }
        return String(format: "%.1f", latest.value)
    }

    private var latestBP: String {
        guard let latest = data.bpReadings.last else { return "No data" }
        return latest.formatted
    }

    private var totalResults: Int {
        data.bloodTests.values.reduce(0) { $0 + $1.count }
    }

    private var abnormalCount: Int {
        data.bloodTests.values.flatMap { $0 }.filter { $0.isAbnormal }.count
    }

    private var flaggedResults: [BloodTestResult] {
        data.bloodTests.values.flatMap { $0 }
            .filter { $0.isAbnormal }
            .sorted { $0.date > $1.date }
    }
}

struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
            }

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - BMI Section
struct BMISection: View {
    let readings: [BMIReading]
    @Environment(SharedDataStore.self) private var sharedData
    @State private var selectedReading: BMIReading?
    @State private var noteSelection: NoteSelection?

    private func noteFor(selection: NoteSelection?) -> ClinicalNote? {
        guard let selection = selection else { return nil }
        return sharedData.notes.first { $0.id == selection.noteId }
    }

    var body: some View {
        if readings.isEmpty {
            ContentUnavailableView {
                Label("No BMI Data", systemImage: "scalemass")
            } description: {
                Text("No BMI readings were extracted from the notes.")
            }
        } else {
            VStack(spacing: 16) {
                // Latest BMI - tappable to view note
                if let latest = readings.last {
                    Button {
                        if let noteId = latest.noteId {
                            noteSelection = NoteSelection(
                                noteId: noteId,
                                highlightText: latest.matchedText
                            )
                        }
                    } label: {
                        LatestValueCard(
                            title: "Latest BMI",
                            value: String(format: "%.1f", latest.value),
                            date: latest.date,
                            category: bmiCategory(latest.value),
                            color: bmiColor(latest.value),
                            showNoteIcon: true
                        )
                    }
                    .buttonStyle(.plain)
                }

                // Chart with zoom/scroll
                CollapsibleSection(title: "BMI Trend Over Time", icon: "chart.xyaxis.line", isExpanded: true) {
                    BMIChartView(readings: readings, selectedReading: $selectedReading, onSelectReading: { reading in
                        if let noteId = reading.noteId {
                            noteSelection = NoteSelection(
                                noteId: noteId,
                                highlightText: reading.matchedText
                            )
                        }
                    })
                        .frame(height: 250)
                }

                // Table
                CollapsibleSection(title: "All Readings", icon: "list.bullet", isExpanded: false) {
                    BMITableView(readings: readings, onSelectReading: { reading in
                        if let noteId = reading.noteId {
                            noteSelection = NoteSelection(
                                noteId: noteId,
                                highlightText: reading.matchedText
                            )
                        }
                    })
                }
            }
            .sheet(item: Binding(
                get: { noteFor(selection: noteSelection) },
                set: { note in noteSelection = note.map { NoteSelection(noteId: $0.id, highlightText: noteSelection?.highlightText ?? "") } }
            )) { note in
                NoteDetailSheet(note: note, highlightText: noteSelection?.highlightText)
            }
        }
    }

    private func bmiCategory(_ value: Double) -> String {
        if value < 18.5 { return "Underweight" }
        if value < 25 { return "Normal" }
        if value < 30 { return "Overweight" }
        return "Obese"
    }

    private func bmiColor(_ value: Double) -> Color {
        if value < 18.5 { return .orange }
        if value < 25 { return .green }
        if value < 30 { return .orange }
        return .red
    }
}

struct BMIChartView: View {
    let readings: [BMIReading]
    @Binding var selectedReading: BMIReading?
    var onSelectReading: ((BMIReading) -> Void)? = nil
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        VStack(spacing: 4) {
            Chart {
                // Normal range area
                RectangleMark(
                    xStart: .value("Start", readings.first?.date ?? Date()),
                    xEnd: .value("End", readings.last?.date ?? Date()),
                    yStart: .value("Min", 18.5),
                    yEnd: .value("Max", 25)
                )
                .foregroundStyle(.green.opacity(0.1))

                // BMI line
                ForEach(readings) { reading in
                    LineMark(
                        x: .value("Date", reading.date),
                        y: .value("BMI", reading.value)
                    )
                    .foregroundStyle(.blue)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date", reading.date),
                        y: .value("BMI", reading.value)
                    )
                    .foregroundStyle(reading.id == selectedReading?.id ? .orange : .blue)
                    .symbolSize(reading.id == selectedReading?.id ? 100 : 50)
                }
            }
            .chartYScale(domain: yAxisRange)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .scaleEffect(scale)
            .offset(offset)
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        let newScale = lastScale * value
                        scale = min(max(newScale, 1.0), 3.0)
                    }
                    .onEnded { _ in
                        lastScale = scale
                        if scale == 1.0 {
                            offset = .zero
                            lastOffset = .zero
                        }
                    }
            )
            .simultaneousGesture(
                scale > 1.0 ?
                DragGesture()
                    .onChanged { value in
                        offset = CGSize(
                            width: lastOffset.width + value.translation.width,
                            height: lastOffset.height + value.translation.height
                        )
                    }
                    .onEnded { _ in
                        lastOffset = offset
                    }
                : nil
            )
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { value in
                                    guard scale == 1.0 else { return }
                                    guard let plotFrame = proxy.plotFrame else { return }
                                    let x = value.location.x - geometry[plotFrame].origin.x
                                    if let date: Date = proxy.value(atX: x) {
                                        if let closest = readings.min(by: {
                                            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
                                        }) {
                                            selectedReading = closest
                                            onSelectReading?(closest)
                                        }
                                    }
                                }
                        )
                }
            }
            .overlay(alignment: .topLeading) {
                if let reading = selectedReading {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(formatDate(reading.date))
                            .font(.caption2)
                        HStack(spacing: 4) {
                            Text("BMI: \(String(format: "%.1f", reading.value))")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Image(systemName: "doc.text")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(6)
                    .background(.ultraThinMaterial)
                    .cornerRadius(6)
                    .padding(4)
                }
            }
            .clipped()

            // Zoom controls
            HStack {
                Text("Pinch to zoom")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                if scale > 1.0 {
                    Button("Reset") {
                        withAnimation {
                            scale = 1.0
                            lastScale = 1.0
                            offset = .zero
                            lastOffset = .zero
                        }
                    }
                    .font(.caption2)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private var yAxisRange: ClosedRange<Double> {
        let values = readings.map { $0.value }
        let minVal = Swift.max(15, (values.min() ?? 20) - 3)
        let maxVal = Swift.min(50, (values.max() ?? 25) + 3)
        return minVal...maxVal
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yy"
        return f.string(from: date)
    }
}

struct BMITableView: View {
    let readings: [BMIReading]
    var onSelectReading: ((BMIReading) -> Void)? = nil

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd MMM yyyy"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Date")
                    .fontWeight(.semibold)
                    .frame(width: 100, alignment: .leading)
                Text("BMI")
                    .fontWeight(.semibold)
                    .frame(width: 60)
                Text("Category")
                    .fontWeight(.semibold)
                Spacer()
                Text("Note")
                    .fontWeight(.semibold)
                    .frame(width: 40)
            }
            .font(.caption)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.systemGray5))

            ForEach(readings.reversed()) { reading in
                Button {
                    onSelectReading?(reading)
                } label: {
                    HStack {
                        Text(dateFormatter.string(from: reading.date))
                            .frame(width: 100, alignment: .leading)
                        Text(String(format: "%.1f", reading.value))
                            .fontWeight(.medium)
                            .frame(width: 60)
                        Text(bmiCategory(reading.value))
                            .foregroundColor(bmiColor(reading.value))
                        Spacer()
                        Image(systemName: "doc.text")
                            .foregroundColor(.blue)
                            .frame(width: 40)
                    }
                    .font(.caption)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                }
                .buttonStyle(.plain)

                Divider()
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    private func bmiCategory(_ value: Double) -> String {
        if value < 18.5 { return "Underweight" }
        if value < 25 { return "Normal" }
        if value < 30 { return "Overweight" }
        return "Obese"
    }

    private func bmiColor(_ value: Double) -> Color {
        if value < 18.5 { return .orange }
        if value < 25 { return .green }
        if value < 30 { return .orange }
        return .red
    }
}

// MARK: - BP Section
struct BPSection: View {
    let readings: [BPReading]
    @Environment(SharedDataStore.self) private var sharedData
    @State private var selectedReading: BPReading?
    @State private var noteSelection: NoteSelection?

    private func noteFor(selection: NoteSelection?) -> ClinicalNote? {
        guard let selection = selection else { return nil }
        return sharedData.notes.first { $0.id == selection.noteId }
    }

    var body: some View {
        if readings.isEmpty {
            ContentUnavailableView {
                Label("No Blood Pressure Data", systemImage: "heart.fill")
            } description: {
                Text("No BP readings were extracted from the notes.")
            }
        } else {
            VStack(spacing: 16) {
                // Latest BP - tappable to view note
                if let latest = readings.last {
                    Button {
                        if let noteId = latest.noteId {
                            noteSelection = NoteSelection(
                                noteId: noteId,
                                highlightText: latest.matchedText
                            )
                        }
                    } label: {
                        LatestValueCard(
                            title: "Latest Blood Pressure",
                            value: latest.formatted,
                            date: latest.date,
                            category: latest.category.rawValue,
                            color: bpCategoryColor(latest.category),
                            showNoteIcon: true
                        )
                    }
                    .buttonStyle(.plain)
                }

                // Chart with zoom/scroll
                CollapsibleSection(title: "Blood Pressure Trend", icon: "chart.xyaxis.line", isExpanded: true) {
                    BPChartView(readings: readings, selectedReading: $selectedReading, onSelectReading: { reading in
                        if let noteId = reading.noteId {
                            noteSelection = NoteSelection(
                                noteId: noteId,
                                highlightText: reading.matchedText
                            )
                        }
                    })
                        .frame(height: 250)
                }

                // Table
                CollapsibleSection(title: "All Readings", icon: "list.bullet", isExpanded: false) {
                    BPTableView(readings: readings, onSelectReading: { reading in
                        if let noteId = reading.noteId {
                            noteSelection = NoteSelection(
                                noteId: noteId,
                                highlightText: reading.matchedText
                            )
                        }
                    })
                }
            }
            .sheet(item: Binding(
                get: { noteFor(selection: noteSelection) },
                set: { note in noteSelection = note.map { NoteSelection(noteId: $0.id, highlightText: noteSelection?.highlightText ?? "") } }
            )) { note in
                NoteDetailSheet(note: note, highlightText: noteSelection?.highlightText)
            }
        }
    }

    private func bpCategoryColor(_ category: BPCategory) -> Color {
        switch category {
        case .normal: return .green
        case .elevated: return .yellow
        case .highStage1: return .orange
        case .highStage2: return .red
        }
    }
}

struct BPChartView: View {
    let readings: [BPReading]
    @Binding var selectedReading: BPReading?
    var onSelectReading: ((BPReading) -> Void)? = nil
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        VStack(spacing: 4) {
            Chart {
                // Normal range
                RectangleMark(
                    xStart: .value("Start", readings.first?.date ?? Date()),
                    xEnd: .value("End", readings.last?.date ?? Date()),
                    yStart: .value("Min", 60),
                    yEnd: .value("Max", 120)
                )
                .foregroundStyle(.green.opacity(0.1))

                ForEach(readings) { reading in
                    // Systolic line
                    LineMark(
                        x: .value("Date", reading.date),
                        y: .value("Systolic", reading.systolic),
                        series: .value("Type", "Systolic")
                    )
                    .foregroundStyle(.red)
                    .interpolationMethod(.catmullRom)

                    // Diastolic line
                    LineMark(
                        x: .value("Date", reading.date),
                        y: .value("Diastolic", reading.diastolic),
                        series: .value("Type", "Diastolic")
                    )
                    .foregroundStyle(.blue)
                    .interpolationMethod(.catmullRom)

                    // Points
                    PointMark(
                        x: .value("Date", reading.date),
                        y: .value("Systolic", reading.systolic)
                    )
                    .foregroundStyle(reading.id == selectedReading?.id ? .orange : .red)
                    .symbolSize(reading.id == selectedReading?.id ? 100 : 40)

                    PointMark(
                        x: .value("Date", reading.date),
                        y: .value("Diastolic", reading.diastolic)
                    )
                    .foregroundStyle(reading.id == selectedReading?.id ? .orange : .blue)
                    .symbolSize(reading.id == selectedReading?.id ? 100 : 40)
                }
            }
            .chartYScale(domain: yAxisRange)
            .chartForegroundStyleScale([
                "Systolic": .red,
                "Diastolic": .blue
            ])
            .chartLegend(position: .bottom)
            .scaleEffect(scale)
            .offset(offset)
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        let newScale = lastScale * value
                        scale = min(max(newScale, 1.0), 3.0)
                    }
                    .onEnded { _ in
                        lastScale = scale
                        if scale == 1.0 {
                            offset = .zero
                            lastOffset = .zero
                        }
                    }
            )
            .simultaneousGesture(
                scale > 1.0 ?
                DragGesture()
                    .onChanged { value in
                        offset = CGSize(
                            width: lastOffset.width + value.translation.width,
                            height: lastOffset.height + value.translation.height
                        )
                    }
                    .onEnded { _ in
                        lastOffset = offset
                    }
                : nil
            )
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { value in
                                    guard scale == 1.0 else { return }
                                    guard let plotFrame = proxy.plotFrame else { return }
                                    let x = value.location.x - geometry[plotFrame].origin.x
                                    if let date: Date = proxy.value(atX: x) {
                                        if let closest = readings.min(by: {
                                            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
                                        }) {
                                            selectedReading = closest
                                            onSelectReading?(closest)
                                        }
                                    }
                                }
                        )
                }
            }
            .overlay(alignment: .topLeading) {
                if let reading = selectedReading {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(formatDate(reading.date))
                            .font(.caption2)
                        HStack(spacing: 4) {
                            Text("BP: \(reading.formatted)")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Image(systemName: "doc.text")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                        Text(reading.category.rawValue)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(6)
                    .background(.ultraThinMaterial)
                    .cornerRadius(6)
                    .padding(4)
                }
            }
            .clipped()

            // Zoom controls
            HStack {
                Text("Pinch to zoom")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                if scale > 1.0 {
                    Button("Reset") {
                        withAnimation {
                            scale = 1.0
                            lastScale = 1.0
                            offset = .zero
                            lastOffset = .zero
                        }
                    }
                    .font(.caption2)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private var yAxisRange: ClosedRange<Int> {
        let sys = readings.map { $0.systolic }
        let dia = readings.map { $0.diastolic }
        let minVal = Swift.max(40, (dia.min() ?? 60) - 10)
        let maxVal = Swift.min(200, (sys.max() ?? 120) + 10)
        return minVal...maxVal
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yy"
        return f.string(from: date)
    }
}

struct BPMiniChart: View {
    let readings: [BPReading]

    var body: some View {
        Chart {
            ForEach(readings) { reading in
                LineMark(
                    x: .value("Date", reading.date),
                    y: .value("Systolic", reading.systolic),
                    series: .value("Type", "Systolic")
                )
                .foregroundStyle(.red)

                LineMark(
                    x: .value("Date", reading.date),
                    y: .value("Diastolic", reading.diastolic),
                    series: .value("Type", "Diastolic")
                )
                .foregroundStyle(.blue)
            }
        }
        .chartYScale(domain: 50...160)
    }
}

struct BPTableView: View {
    let readings: [BPReading]
    var onSelectReading: ((BPReading) -> Void)? = nil

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd MMM yyyy"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Date")
                    .fontWeight(.semibold)
                    .frame(width: 100, alignment: .leading)
                Text("BP")
                    .fontWeight(.semibold)
                    .frame(width: 70)
                Text("Category")
                    .fontWeight(.semibold)
                Spacer()
                Text("Note")
                    .fontWeight(.semibold)
                    .frame(width: 40)
            }
            .font(.caption)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.systemGray5))

            ForEach(readings.reversed()) { reading in
                Button {
                    onSelectReading?(reading)
                } label: {
                    HStack {
                        Text(dateFormatter.string(from: reading.date))
                            .frame(width: 100, alignment: .leading)
                        Text(reading.formatted)
                            .fontWeight(.medium)
                            .frame(width: 70)
                        Text(reading.category.rawValue)
                            .foregroundColor(categoryColor(reading.category))
                        Spacer()
                        Image(systemName: "doc.text")
                            .foregroundColor(.blue)
                            .frame(width: 40)
                    }
                    .font(.caption)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                }
                .buttonStyle(.plain)

                Divider()
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    private func categoryColor(_ category: BPCategory) -> Color {
        switch category {
        case .normal: return .green
        case .elevated: return .yellow
        case .highStage1: return .orange
        case .highStage2: return .red
        }
    }
}

// MARK: - Blood Tests Section
struct BloodTestsSection: View {
    let tests: [String: [BloodTestResult]]
    @Binding var selectedTest: String?

    var body: some View {
        if tests.isEmpty {
            ContentUnavailableView {
                Label("No Blood Test Data", systemImage: "drop.fill")
            } description: {
                Text("No blood test results were extracted from the notes.")
            }
        } else {
            VStack(spacing: 16) {
                // Summary of abnormal results
                let abnormal = tests.values.flatMap { $0 }.filter { $0.isAbnormal }
                if !abnormal.isEmpty {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("\(abnormal.count) abnormal results found")
                            .font(.subheadline)
                        Spacer()
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }

                // Test list with inline expandable charts
                CollapsibleSection(title: "Blood Test Results", icon: "list.bullet.rectangle", isExpanded: true) {
                    BloodTestsTableView(tests: tests, selectedTest: $selectedTest)
                }
            }
        }
    }
}

struct BloodTestsTableView: View {
    let tests: [String: [BloodTestResult]]
    @Binding var selectedTest: String?
    @Environment(SharedDataStore.self) private var sharedData
    @State private var noteSelection: NoteSelection?

    private var sortedTestNames: [String] {
        tests.keys.sorted()
    }

    private func noteFor(selection: NoteSelection?) -> ClinicalNote? {
        guard let selection = selection else { return nil }
        return sharedData.notes.first { $0.id == selection.noteId }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Test")
                    .fontWeight(.semibold)
                    .frame(width: 100, alignment: .leading)
                Text("Latest")
                    .fontWeight(.semibold)
                    .frame(width: 60)
                Text("Unit")
                    .fontWeight(.semibold)
                    .frame(width: 60)
                Text("Range")
                    .fontWeight(.semibold)
                Spacer()
                Text("Flag")
                    .fontWeight(.semibold)
                    .frame(width: 30)
            }
            .font(.caption)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.systemGray5))

            ForEach(sortedTestNames, id: \.self) { testName in
                if let results = tests[testName], let latest = results.last {
                    HStack(spacing: 0) {
                        // Main row - tap to expand/collapse
                        Button {
                            withAnimation {
                                selectedTest = selectedTest == testName ? nil : testName
                            }
                        } label: {
                            HStack {
                                Text(testName)
                                    .frame(width: 100, alignment: .leading)
                                    .lineLimit(1)

                                Text(formatValue(latest.value))
                                    .fontWeight(.medium)
                                    .foregroundColor(latest.isAbnormal ? .red : .primary)
                                    .frame(width: 60)

                                Text(latest.unit)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .frame(width: 60)

                                Text(normalRange(latest))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)

                                Spacer()

                                if latest.isAbnormal {
                                    Text(latest.flagSymbol)
                                        .foregroundColor(latest.isHigh ? .red : .blue)
                                        .fontWeight(.bold)
                                        .frame(width: 30)
                                } else {
                                    Text("")
                                        .frame(width: 30)
                                }
                            }
                            .font(.caption)
                        }
                        .buttonStyle(.plain)

                        // View note button
                        Button {
                            if let noteId = latest.noteId {
                                noteSelection = NoteSelection(
                                    noteId: noteId,
                                    highlightText: latest.matchedText
                                )
                            }
                        } label: {
                            Image(systemName: "doc.text")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 8)
                        }
                        .buttonStyle(.plain)

                        // Expand/collapse indicator
                        if results.count > 1 {
                            Image(systemName: selectedTest == testName ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.trailing, 4)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.leading, 12)
                    .padding(.trailing, 8)
                    .background(selectedTest == testName ? Color.blue.opacity(0.1) : Color.clear)

                    // Expanded: Chart + History (inline below the selected row)
                    if selectedTest == testName && results.count > 1 {
                        VStack(spacing: 8) {
                            // Inline Chart with tap to view note
                            BloodTestChartView(testName: testName, results: results, onSelectResult: { result in
                                if let noteId = result.noteId {
                                    noteSelection = NoteSelection(
                                        noteId: noteId,
                                        highlightText: result.matchedText
                                    )
                                }
                            })
                                .frame(height: 150)
                                .padding(.horizontal, 12)
                                .padding(.top, 8)

                            // History rows - tappable to view source note
                            VStack(spacing: 4) {
                                ForEach(results.dropLast().reversed()) { result in
                                    Button {
                                        if let noteId = result.noteId {
                                            noteSelection = NoteSelection(
                                                noteId: noteId,
                                                highlightText: result.matchedText
                                            )
                                        }
                                    } label: {
                                        HStack {
                                            Text(formatDate(result.date))
                                                .frame(width: 100, alignment: .leading)
                                            Text(formatValue(result.value))
                                                .foregroundColor(result.isAbnormal ? .red : .secondary)
                                            Text(result.unit)
                                            Spacer()
                                            if result.isAbnormal {
                                                Text(result.flagSymbol)
                                                    .foregroundColor(result.isHigh ? .red : .blue)
                                            }
                                            Image(systemName: "doc.text")
                                                .font(.caption2)
                                                .foregroundColor(.blue)
                                        }
                                        .font(.caption2)
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 4)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                    }

                    Divider()
                }
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .sheet(item: Binding(
            get: { noteFor(selection: noteSelection) },
            set: { note in noteSelection = note.map { NoteSelection(noteId: $0.id, highlightText: noteSelection?.highlightText ?? "") } }
        )) { note in
            NoteDetailSheet(note: note, highlightText: noteSelection?.highlightText)
        }
    }

    private func formatValue(_ value: Double) -> String {
        if value == floor(value) {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    private func normalRange(_ result: BloodTestResult) -> String {
        if let min = result.normalMin, let max = result.normalMax {
            return "\(formatValue(min))-\(formatValue(max))"
        } else if let min = result.normalMin {
            return ">\(formatValue(min))"
        } else if let max = result.normalMax {
            return "<\(formatValue(max))"
        }
        return "-"
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yy"
        return f.string(from: date)
    }
}

struct BloodTestChartView: View {
    let testName: String
    let results: [BloodTestResult]
    var onSelectResult: ((BloodTestResult) -> Void)? = nil
    @State private var selectedResult: BloodTestResult?

    var body: some View {
        Chart {
            // Normal range area
            if let first = results.first {
                if let min = first.normalMin, let max = first.normalMax {
                    RectangleMark(
                        xStart: .value("Start", results.first?.date ?? Date()),
                        xEnd: .value("End", results.last?.date ?? Date()),
                        yStart: .value("Min", min),
                        yEnd: .value("Max", max)
                    )
                    .foregroundStyle(.green.opacity(0.1))
                }
            }

            ForEach(results) { result in
                LineMark(
                    x: .value("Date", result.date),
                    y: .value("Value", result.value)
                )
                .foregroundStyle(result.isAbnormal ? .red : .blue)
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Date", result.date),
                    y: .value("Value", result.value)
                )
                .foregroundStyle(selectedResult?.id == result.id ? .orange : (result.isAbnormal ? .red : .blue))
                .symbolSize(selectedResult?.id == result.id ? 100 : 50)
            }
        }
        .chartYScale(domain: yAxisRange)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { value in
                                guard let plotFrame = proxy.plotFrame else { return }
                                let x = value.location.x - geometry[plotFrame].origin.x
                                if let date: Date = proxy.value(atX: x) {
                                    if let closest = results.min(by: {
                                        abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
                                    }) {
                                        selectedResult = closest
                                        onSelectResult?(closest)
                                    }
                                }
                            }
                    )
            }
        }
        .overlay(alignment: .topLeading) {
            if let result = selectedResult {
                VStack(alignment: .leading, spacing: 2) {
                    Text(formatDate(result.date))
                        .font(.caption2)
                    HStack(spacing: 4) {
                        Text("\(formatValue(result.value)) \(result.unit)")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Image(systemName: "doc.text")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
                .padding(6)
                .background(.ultraThinMaterial)
                .cornerRadius(6)
                .padding(4)
            }
        }
    }

    private var yAxisRange: ClosedRange<Double> {
        let values = results.map { $0.value }
        var minVal = values.min() ?? 0
        var maxVal = values.max() ?? 100

        if let normalMin = results.first?.normalMin {
            minVal = Swift.min(minVal, normalMin)
        }
        if let normalMax = results.first?.normalMax {
            maxVal = Swift.max(maxVal, normalMax)
        }

        let padding = (maxVal - minVal) * 0.1
        return (minVal - padding)...(maxVal + padding)
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yy"
        return f.string(from: date)
    }

    private func formatValue(_ value: Double) -> String {
        if value == floor(value) {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }
}

// MARK: - Shared Components
struct LatestValueCard: View {
    let title: String
    let value: String
    let date: Date
    let category: String
    let color: Color
    var showNoteIcon: Bool = false

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd MMM yyyy"
        return f
    }()

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Spacer()
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if showNoteIcon {
                    Image(systemName: "doc.text")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }

            Text(value)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(color)

            Text(category)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(color)

            HStack {
                Text(dateFormatter.string(from: date))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                if showNoteIcon {
                    Text("Tap to view note")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct CollapsibleSection<Content: View>: View {
    let title: String
    let icon: String
    @State var isExpanded: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(isExpanded ? 8 : 8)
            }
            .buttonStyle(.plain)

            if isExpanded {
                content()
                    .padding()
                    .background(Color(.systemGray6).opacity(0.5))
            }
        }
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
    }
}

struct FlaggedResultRow: View {
    let result: BloodTestResult

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yy"
        return f
    }()

    var body: some View {
        HStack {
            Image(systemName: result.isHigh ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .foregroundColor(result.isHigh ? .red : .blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(result.testName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(dateFormatter.string(from: result.date))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text("\(formatValue(result.value)) \(result.unit)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(result.isHigh ? .red : .blue)
                if let range = normalRange {
                    Text("Normal: \(range)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func formatValue(_ value: Double) -> String {
        if value == floor(value) {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    private var normalRange: String? {
        if let min = result.normalMin, let max = result.normalMax {
            return "\(formatValue(min))-\(formatValue(max))"
        } else if let min = result.normalMin {
            return ">\(formatValue(min))"
        } else if let max = result.normalMax {
            return "<\(formatValue(max))"
        }
        return nil
    }
}

struct MiniLineChart: View {
    let data: [(Date, Double)]
    let color: Color
    let yAxisLabel: String

    var body: some View {
        Chart {
            ForEach(data, id: \.0) { item in
                LineMark(
                    x: .value("Date", item.0),
                    y: .value(yAxisLabel, item.1)
                )
                .foregroundStyle(color)
                .interpolationMethod(.catmullRom)
            }
        }
    }
}

#Preview {
    PhysicalHealthView()
        .environment(SharedDataStore.shared)
}
