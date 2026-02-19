//
//  ReportsView.swift
//  MyPsychAdmin
//
//  Data Extractor / Patient History view - matches desktop app
//

import SwiftUI

struct ReportsView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(SharedDataStore.self) private var sharedData
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            if hasData {
                List {
                    // Patient Info Section
                    if !sharedData.patientInfo.fullName.isEmpty {
                        Section {
                            PatientInfoHeader()
                        }
                    }

                    // All 18 Clinical Categories - matching desktop order
                    Section("Clinical Categories") {
                        ForEach(ClinicalCategory.allCases, id: \.self) { category in
                            DataExtractorCategoryRow(
                                category: category,
                                hasData: sharedData.hasExtractedData(for: category)
                            )
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .searchable(text: $searchText, prompt: "Search history")
                .navigationTitle("Data Extractor")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button(role: .destructive) {
                                sharedData.clearAll()
                            } label: {
                                Label("Clear All Data", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            } else {
                // Empty state
                ContentUnavailableView {
                    Label("No Data Extracted", systemImage: "doc.text.magnifyingglass")
                } description: {
                    Text("Import clinical notes to extract and categorize clinical data into the 18 standard sections.")
                } actions: {
                    Button {
                        appStore.showingDocumentImporter = true
                    } label: {
                        Label("Import Notes", systemImage: "doc.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .navigationTitle("Data Extractor")
            }
        }
    }

    private var hasData: Bool {
        sharedData.hasNotes || !sharedData.patientInfo.fullName.isEmpty || !sharedData.extractedData.categories.isEmpty
    }
}

// MARK: - Patient Info Header
struct PatientInfoHeader: View {
    @Environment(SharedDataStore.self) private var sharedData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.title)
                    .foregroundColor(.blue)

                VStack(alignment: .leading) {
                    Text(sharedData.patientInfo.fullName)
                        .font(.headline)

                    if let dob = sharedData.patientInfo.dateOfBirth {
                        Text("DOB: \(formatDate(dob))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if !sharedData.patientInfo.nhsNumber.isEmpty {
                    Text(sharedData.patientInfo.nhsNumber)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if sharedData.hasNotes {
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundColor(.secondary)
                    Text("\(sharedData.notesCount) notes imported")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Category Row (matches desktop collapsible sections)
struct DataExtractorCategoryRow: View {
    let category: ClinicalCategory
    let hasData: Bool
    @Environment(SharedDataStore.self) private var sharedData
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            if hasData {
                let items = sharedData.getCategory(category)
                ForEach(items.indices, id: \.self) { index in
                    Text(items[index])
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 2)
                }
            } else {
                Text("No data extracted for this category")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
        } label: {
            HStack(spacing: 12) {
                // Category icon
                Image(systemName: category.iconName)
                    .foregroundColor(hasData ? .blue : .gray)
                    .frame(width: 24)

                // Category name
                Text(category.displayName)
                    .foregroundColor(hasData ? .primary : .secondary)

                Spacer()

                // Indicator if has data
                if hasData {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }
            }
        }
    }
}

#Preview {
    ReportsView()
        .environment(AppStore())
        .environment(SharedDataStore.shared)
}
