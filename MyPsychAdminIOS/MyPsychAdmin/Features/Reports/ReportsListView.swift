//
//  ReportsListView.swift
//  MyPsychAdmin
//
//  Reports hub page - matching desktop reports_page.py
//  Shows cards for each report type that users can select
//

import SwiftUI

struct ReportsListView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(SharedDataStore.self) private var sharedData
    @State private var selectedReport: ReportType?
    @State private var showingReport = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reports")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Select a report type to begin")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)

                    // General Reports Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("General Reports")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)

                        HStack(spacing: 16) {
                            ReportTypeCard(
                                reportType: .generalPsychiatric,
                                onSelect: { selectReport(.generalPsychiatric) }
                            )

                            Spacer()
                        }
                        .padding(.horizontal)
                    }

                    // Tribunal Reports Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Tribunal Reports")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)

                        // Show all 3 tribunal reports in a grid
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ], spacing: 12) {
                            ReportTypeCard(
                                reportType: .psychiatricTribunal,
                                onSelect: { selectReport(.psychiatricTribunal) }
                            )

                            ReportTypeCard(
                                reportType: .nursingTribunal,
                                onSelect: { selectReport(.nursingTribunal) }
                            )

                            ReportTypeCard(
                                reportType: .socialTribunal,
                                onSelect: { selectReport(.socialTribunal) }
                            )
                        }
                        .padding(.horizontal)
                    }

                    // Info Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                                .font(.title2)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Import Data First")
                                    .font(.headline)
                                Text("For best results, import patient notes before creating a report. Data will be automatically extracted into relevant sections.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    Spacer(minLength: 50)
                }
                .padding(.top)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Reports")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedReport) { reportType in
                // Route to specific report views based on type
                ZStack {
                    ClearSheetBackground()
                        .ignoresSafeArea()

                    switch reportType {
                    case .generalPsychiatric:
                        GeneralPsychReportView()
                    case .psychiatricTribunal:
                        PsychiatricTribunalReportView()
                    case .nursingTribunal:
                        NursingTribunalReportView()
                    case .socialTribunal:
                        SocialTribunalReportView()
                    }
                }
                .presentationBackground(.clear)
            }
        }
    }

    private func selectReport(_ type: ReportType) {
        selectedReport = type
    }
}

// MARK: - Report Type Card

struct ReportTypeCard: View {
    let reportType: ReportType
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 10) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color(hex: reportType.color).opacity(0.15))
                        .frame(width: 48, height: 48)

                    Image(systemName: reportType.iconName)
                        .font(.title3)
                        .foregroundColor(Color(hex: reportType.color))
                }

                // Title
                Text(reportType.shortTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                // Description
                Text(reportType.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer()

                // Sections count
                HStack {
                    Image(systemName: "list.bullet")
                        .font(.caption2)
                    Text("\(reportType.sections.count) sections")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 160, alignment: .leading)
            .background(.thinMaterial)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 6)
            .shadow(color: Color(hex: reportType.color).opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Report Editor View (Main report editing interface)

struct ReportEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var appStore
    @Environment(SharedDataStore.self) private var sharedData

    let reportType: ReportType
    @State private var reportData: ReportData
    @State private var selectedSection: ReportSection?
    @State private var showingExport = false
    @State private var showingImport = false

    init(reportType: ReportType) {
        self.reportType = reportType
        _reportData = State(initialValue: ReportData(reportType: reportType))
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                if geometry.size.width > 700 {
                    // iPad: Side-by-side layout
                    HStack(spacing: 0) {
                        // Sections sidebar
                        sectionsList
                            .frame(width: 280)
                            .background(Color(.systemGroupedBackground))

                        Divider()

                        // Content editor
                        sectionEditor
                    }
                } else {
                    // iPhone: Tab-based or stacked layout
                    VStack(spacing: 0) {
                        // Section picker
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(reportType.sections) { section in
                                    sectionChip(section)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                        }
                        .background(Color(.secondarySystemBackground))

                        // Content editor
                        sectionEditor
                    }
                }
            }
            .navigationTitle(reportType.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        // Import button
                        Button {
                            showingImport = true
                        } label: {
                            Image(systemName: "square.and.arrow.down")
                        }

                        // Export button
                        Button {
                            showingExport = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            .onAppear {
                // Select first section by default
                if selectedSection == nil, let first = reportType.sections.first {
                    selectedSection = first
                }
                // Prefill from shared data
                prefillFromSharedData()
            }
        }
    }

    // MARK: - Sections List (iPad sidebar)

    private var sectionsList: some View {
        List(selection: $selectedSection) {
            ForEach(reportType.sections) { section in
                HStack(spacing: 12) {
                    Image(systemName: section.iconName)
                        .foregroundColor(Color(hex: reportType.color))
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(section.number). \(section.title)")
                            .font(.subheadline)
                            .lineLimit(2)

                        // Show if has content
                        if !reportData.getSection(section.id).isEmpty {
                            Text("Has content")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }

                    Spacer()

                    if selectedSection == section {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedSection = section
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Section Chip (iPhone horizontal scroll)

    private func sectionChip(_ section: ReportSection) -> some View {
        Button {
            selectedSection = section
        } label: {
            HStack(spacing: 6) {
                Text("\(section.number)")
                    .font(.caption.bold())
                    .foregroundColor(selectedSection == section ? .white : Color(hex: reportType.color))
                    .frame(width: 20, height: 20)
                    .background(
                        Circle()
                            .fill(selectedSection == section ? Color(hex: reportType.color) : Color(hex: reportType.color).opacity(0.2))
                    )

                Text(section.title)
                    .font(.caption)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(selectedSection == section ? Color(hex: reportType.color).opacity(0.15) : Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(selectedSection == section ? Color(hex: reportType.color) : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Section Editor

    private var sectionEditor: some View {
        VStack(spacing: 0) {
            if let section = selectedSection {
                // Section header
                HStack {
                    Image(systemName: section.iconName)
                        .foregroundColor(Color(hex: reportType.color))
                        .font(.title2)

                    VStack(alignment: .leading) {
                        Text("Section \(section.number)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(section.title)
                            .font(.headline)
                    }

                    Spacer()
                }
                .padding()
                .background(Color(.secondarySystemBackground))

                // Text editor
                TextEditor(text: Binding(
                    get: { reportData.getSection(section.id) },
                    set: { reportData.updateSection(section.id, content: $0) }
                ))
                .padding()
                .background(Color(.systemBackground))
            } else {
                ContentUnavailableView("Select a Section", systemImage: "doc.text", description: Text("Choose a section from the list to start editing"))
            }
        }
    }

    // MARK: - Prefill from Shared Data

    private func prefillFromSharedData() {
        // Prefill patient info
        if !sharedData.patientInfo.fullName.isEmpty {
            reportData.patientInfo = sharedData.patientInfo
        }

        // Prefill clinician info
        reportData.clinicianInfo = appStore.clinicianInfo
    }
}

// MARK: - Transparent Sheet Background Helper

struct ClearSheetBackground: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = ClearView()
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    private class ClearView: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            // Walk up the entire view hierarchy and clear all backgrounds
            var current: UIView? = superview
            while let view = current {
                view.backgroundColor = .clear
                current = view.superview
            }
        }
    }
}

// MARK: - Color Extension for Hex

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    ReportsListView()
        .environment(AppStore())
        .environment(SharedDataStore.shared)
}
