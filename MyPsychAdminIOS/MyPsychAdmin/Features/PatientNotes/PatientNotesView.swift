//
//  PatientNotesView.swift
//  MyPsychAdmin
//
//  Patient History / Data Extractor - shows 18 clinical categories
//  Matches desktop app's Patient History panel
//

import SwiftUI

struct PatientNotesView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(SharedDataStore.self) private var sharedData
    @State private var showingImporter = false
    @State private var selectedCategory: ClinicalCategory?

    var body: some View {
        NavigationStack {
            Group {
                if hasData {
                    List {
                        // Patient Info Header
                        if !sharedData.patientInfo.fullName.isEmpty {
                            Section {
                                PatientHeaderRow()
                            }
                        }

                        // Notes count
                        if sharedData.hasNotes {
                            Section {
                                HStack {
                                    Image(systemName: "doc.text.fill")
                                        .foregroundColor(.blue)
                                    Text("\(sharedData.notesCount) notes imported")
                                    Spacer()
                                }
                            }
                        }

                        // All 18 Clinical Categories
                        Section("Clinical Categories") {
                            ForEach(ClinicalCategory.allCases, id: \.self) { category in
                                CategoryRowButton(
                                    category: category,
                                    hasData: sharedData.hasExtractedData(for: category)
                                ) {
                                    selectedCategory = category
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                } else {
                    // Empty state
                    ContentUnavailableView {
                        Label("No Patient Data", systemImage: "doc.text.magnifyingglass")
                    } description: {
                        Text("Import clinical notes to extract and view patient history organized by the 18 standard clinical categories.")
                    } actions: {
                        Button {
                            showingImporter = true
                        } label: {
                            Label("Import Notes", systemImage: "doc.badge.plus")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("Patient History")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingImporter = true
                    } label: {
                        Image(systemName: "doc.badge.plus")
                    }
                }

                if hasData {
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
            }
            .sheet(isPresented: $showingImporter) {
                DocumentImportView()
            }
            .sheet(item: $selectedCategory) { category in
                CategoryDetailView(category: category)
            }
        }
    }

    private var hasData: Bool {
        sharedData.hasNotes || !sharedData.patientInfo.fullName.isEmpty || !sharedData.extractedData.categories.isEmpty
    }
}

// MARK: - Patient Header Row
struct PatientHeaderRow: View {
    @Environment(SharedDataStore.self) private var sharedData

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.circle.fill")
                .font(.largeTitle)
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text(sharedData.patientInfo.fullName)
                    .font(.headline)

                if let dob = sharedData.patientInfo.dateOfBirth {
                    HStack(spacing: 4) {
                        Text("DOB: \(formatDate(dob))")
                        if let age = sharedData.patientInfo.age {
                            Text("(\(age) yrs)")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                if !sharedData.patientInfo.nhsNumber.isEmpty {
                    Text("NHS: \(sharedData.patientInfo.nhsNumber)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Category Row Button
struct CategoryRowButton: View {
    let category: ClinicalCategory
    let hasData: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: category.iconName)
                    .foregroundColor(hasData ? .blue : .gray)
                    .frame(width: 28)

                // Category name
                Text(category.displayName)
                    .foregroundColor(hasData ? .primary : .secondary)

                Spacer()

                // Has data indicator
                if hasData {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.subheadline)
                }

                // Chevron
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Category Detail View (shows extracted data for a category)
struct CategoryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SharedDataStore.self) private var sharedData
    let category: ClinicalCategory

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    HStack {
                        Image(systemName: category.iconName)
                            .font(.title)
                            .foregroundColor(.blue)

                        Text(category.displayName)
                            .font(.title2)
                            .fontWeight(.bold)

                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // Content
                    let items = sharedData.getCategory(category)

                    if items.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)

                            Text("No data extracted")
                                .font(.headline)
                                .foregroundColor(.secondary)

                            Text("Import clinical notes containing \(category.displayName.lowercased()) information to see data here.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        // Show extracted data
                        ForEach(items.indices, id: \.self) { index in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(items[index])
                                    .font(.body)
                                    .textSelection(.enabled)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                            .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(category.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    PatientNotesView()
        .environment(AppStore())
        .environment(SharedDataStore.shared)
}
