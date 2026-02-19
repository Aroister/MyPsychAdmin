//
//  NotesView.swift
//  MyPsychAdmin
//
//  Notes section with split panel layout and workspace buttons
//  Matches desktop app's patient_notes_panel.py
//

import SwiftUI

struct NotesView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(SharedDataStore.self) private var sharedData
    @State private var selectedNote: ClinicalNote?
    @State private var showingImporter = false
    @State private var showingWorkspace: WorkspaceType?
    @State private var searchText = ""
    @State private var filterType: String = "All"

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Workspace Buttons Bar
                WorkspaceButtonsBar(selectedWorkspace: $showingWorkspace)
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                Divider()

                if sharedData.hasNotes {
                    // Split panel layout
                    GeometryReader { geometry in
                        VStack(spacing: 0) {
                            // Top: Notes List with Filter
                            NotesListView(
                                selectedNote: $selectedNote,
                                searchText: $searchText,
                                filterType: $filterType
                            )
                            .frame(height: geometry.size.height * 0.5)

                            Divider()
                                .background(Color.gray)

                            // Bottom: Note Detail
                            NoteDetailView(note: selectedNote)
                                .frame(height: geometry.size.height * 0.5)
                        }
                    }
                } else {
                    // Empty state
                    Spacer()
                    ContentUnavailableView {
                        Label("No Notes Imported", systemImage: "doc.text.magnifyingglass")
                    } description: {
                        Text("Import clinical notes from PDF, Word, or Excel files to view and analyze patient history.")
                    } actions: {
                        Button {
                            showingImporter = true
                        } label: {
                            Label("Import Notes", systemImage: "doc.badge.plus")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    Spacer()
                }
            }
            .navigationTitle("Notes")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingImporter = true
                    } label: {
                        Image(systemName: "doc.badge.plus")
                    }
                }

                if sharedData.hasNotes {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button(role: .destructive) {
                                sharedData.clearAll()
                            } label: {
                                Label("Clear All Notes", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingImporter) {
                DocumentImportView()
            }
            .sheet(item: $showingWorkspace) { workspace in
                WorkspaceDetailView(workspace: workspace)
            }
        }
    }
}

// MARK: - Workspace Types
enum WorkspaceType: String, Identifiable, CaseIterable {
    case admissions = "Admissions"
    case history = "Patient History"
    case physicalHealth = "Physical Health"
    case medications = "Medications"
    case risk = "Risk"
    case progress = "Progress"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .admissions: return "clock.arrow.2.circlepath"
        case .history: return "book.pages"
        case .physicalHealth: return "heart.text.square"
        case .medications: return "pills.fill"
        case .risk: return "exclamationmark.triangle.fill"
        case .progress: return "chart.line.uptrend.xyaxis"
        }
    }

    var color: Color {
        switch self {
        case .admissions: return .orange
        case .history: return .blue
        case .physicalHealth: return .red
        case .medications: return .green
        case .risk: return Color(red: 0.72, green: 0.11, blue: 0.11) // Dark red
        case .progress: return .purple
        }
    }

    // Categories relevant to this workspace
    var relevantCategories: [ClinicalCategory] {
        switch self {
        case .admissions:
            return [.circumstancesOfAdmission, .legal, .diagnosis]
        case .history:
            return [.historyOfPresentingComplaint, .pastPsychiatricHistory, .personalHistory, .forensicHistory, .drugAndAlcoholHistory]
        case .physicalHealth:
            return [.pastMedicalHistory, .physicalExamination, .ecg]
        case .medications:
            return [.medicationHistory]
        case .risk:
            return [.risk]
        case .progress:
            return [.summary, .plan, .impression]
        }
    }
}

// MARK: - Workspace Buttons Bar
struct WorkspaceButtonsBar: View {
    @Binding var selectedWorkspace: WorkspaceType?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(WorkspaceType.allCases) { workspace in
                    WorkspaceButton(
                        workspace: workspace,
                        action: { selectedWorkspace = workspace }
                    )
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

struct WorkspaceButton: View {
    let workspace: WorkspaceType
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: workspace.icon)
                    .font(.system(size: 14))
                Text(workspace.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(workspace.color.opacity(0.15))
            .foregroundColor(workspace.color)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Notes List View (Top Panel)
struct NotesListView: View {
    @Environment(SharedDataStore.self) private var sharedData
    @Binding var selectedNote: ClinicalNote?
    @Binding var searchText: String
    @Binding var filterType: String

    // Available filter types
    private var availableTypes: [String] {
        var types = Set<String>()
        for note in sharedData.notes {
            if !note.type.isEmpty {
                types.insert(note.type)
            }
        }
        return ["All"] + types.sorted()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Filter Bar
            HStack(spacing: 12) {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search notes...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.subheadline)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)

                // Type filter
                Menu {
                    ForEach(availableTypes, id: \.self) { type in
                        Button {
                            filterType = type
                        } label: {
                            HStack {
                                Text(type)
                                if filterType == type {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(filterType)
                            .font(.subheadline)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }

                // Count
                Text("\(filteredNotes.count) notes")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white)

            Divider()

            // Fixed Header Row
            HStack(spacing: 0) {
                Text("Date")
                    .font(.caption.bold())
                    .frame(width: 75, alignment: .leading)
                Text("Type")
                    .font(.caption.bold())
                    .frame(width: 85, alignment: .leading)
                Text("Author")
                    .font(.caption.bold())
                    .frame(width: 100, alignment: .leading)
                Text("Preview")
                    .font(.caption.bold())
                Spacer()
            }
            .foregroundColor(.black)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray5))

            Divider()

            // Scrollable Notes List
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredNotes) { note in
                        VStack(spacing: 0) {
                            NoteRowView(note: note, isSelected: selectedNote?.id == note.id)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedNote = note
                                }
                                .background(selectedNote?.id == note.id ? Color.blue.opacity(0.15) : Color.white)

                            // Divider between rows
                            Divider()
                        }
                    }
                }
            }
            .background(Color.white)
        }
        .background(Color.white)
    }

    private var filteredNotes: [ClinicalNote] {
        // Start with sorted notes (cached sort for large datasets)
        let sortedNotes = sharedData.notes.sorted { $0.date > $1.date }

        // Early return if no filters
        if filterType == "All" && searchText.isEmpty {
            return sortedNotes
        }

        let search = searchText.lowercased()
        let filterByType = filterType != "All"
        let filterBySearch = !searchText.isEmpty

        return sortedNotes.filter { note in
            // Type filter
            if filterByType && note.type != filterType {
                return false
            }

            // Search filter - check shorter fields first
            if filterBySearch {
                if note.type.lowercased().contains(search) { return true }
                if note.author.lowercased().contains(search) { return true }
                // Only check body (expensive) if other checks failed
                if note.body.lowercased().contains(search) { return true }
                return false
            }

            return true
        }
    }
}

struct NoteRowView: View {
    let note: ClinicalNote
    let isSelected: Bool

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yy"
        return f
    }()

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        HStack(spacing: 0) {
            // Date column with date and time
            VStack(alignment: .leading, spacing: 2) {
                Text(dateFormatter.string(from: note.date))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.black)
                Text(timeFormatter.string(from: note.date))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .frame(width: 75, alignment: .leading)

            // Type column with colored badge
            Text(note.type.isEmpty ? "-" : note.type)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(typeColor(for: note.type))
                .cornerRadius(4)
                .frame(width: 85, alignment: .leading)
                .lineLimit(1)

            // Author column
            Text(note.author.isEmpty ? "-" : note.author)
                .font(.caption)
                .foregroundColor(.black)
                .frame(width: 100, alignment: .leading)
                .lineLimit(1)

            // Preview column
            Text(note.preview)
                .font(.caption)
                .foregroundColor(.gray)
                .lineLimit(2)

            Spacer()

            // Source indicator
            Text(note.source.rawValue)
                .font(.caption2)
                .foregroundColor(.gray)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(.systemGray6))
                .cornerRadius(4)
                .padding(.trailing, 4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func typeColor(for type: String) -> Color {
        let lower = type.lowercased()
        if lower.contains("medical") || lower.contains("ward round") { return .blue }
        if lower.contains("nursing") { return .green }
        if lower.contains("social") { return .purple }
        if lower.contains("psycho") { return .orange }
        if lower.contains("admission") { return .red }
        if lower.contains("occupational") { return .teal }
        return Color(.systemGray)
    }
}

// MARK: - Note Detail View (Bottom Panel)
struct NoteDetailView: View {
    let note: ClinicalNote?

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd MMMM yyyy 'at' HH:mm"
        return f
    }()

    var body: some View {
        if let note = note {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(note.type.isEmpty ? "Clinical Note" : note.type)
                                .font(.headline)

                            HStack(spacing: 16) {
                                Label(dateFormatter.string(from: note.date), systemImage: "calendar")
                                if !note.author.isEmpty {
                                    Label(note.author, systemImage: "person")
                                }
                                Label(note.source.rawValue, systemImage: "doc.text")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)

                    // Body
                    Text(note.body)
                        .font(.body)
                        .textSelection(.enabled)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
        } else {
            VStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundColor(.gray)
                Text("Select a note to view details")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
        }
    }
}

// MARK: - Workspace Detail View
struct WorkspaceDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SharedDataStore.self) private var sharedData
    let workspace: WorkspaceType

    var body: some View {
        // Use specialized views for each workspace type
        switch workspace {
        case .admissions:
            AdmissionsTimelineView()
        case .history:
            PatientHistoryView()
        case .physicalHealth:
            PhysicalHealthView()
        case .medications:
            MedicationsView()
        case .risk:
            RiskWorkspaceView()
        case .progress:
            ProgressNotesView()
        }
    }
}

// MARK: - Risk Workspace View
struct RiskWorkspaceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SharedDataStore.self) private var sharedData

    var body: some View {
        NavigationStack {
            RiskView(notes: sharedData.notes, onViewNote: nil)
                .navigationTitle("Risk Overview")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}

#Preview {
    NotesView()
        .environment(AppStore())
        .environment(SharedDataStore.shared)
}
