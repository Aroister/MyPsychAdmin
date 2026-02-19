//
//  DocumentImportView.swift
//  MyPsychAdmin
//

import SwiftUI
import UniformTypeIdentifiers

struct DocumentImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var appStore
    @Environment(SharedDataStore.self) private var sharedData

    @State private var showingFilePicker = false
    @State private var isProcessing = false
    @State private var processingMessage = ""
    @State private var importedContent: ImportedContent?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if isProcessing {
                    // Processing state
                    ProgressView()
                        .scaleEffect(1.5)
                    Text(processingMessage)
                        .foregroundColor(.secondary)
                } else if let content = importedContent {
                    // Preview imported content
                    ImportPreviewView(
                        content: content,
                        onConfirm: {
                            confirmImport(content)
                        },
                        onCancel: {
                            importedContent = nil
                        }
                    )
                } else if let error = errorMessage {
                    // Error state
                    ContentUnavailableView {
                        Label("Import Failed", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Try Again") {
                            errorMessage = nil
                        }
                    }
                } else {
                    // Initial state
                    ImportOptionsView(
                        onSelectFile: {
                            showingFilePicker = true
                        }
                    )
                }
            }
            .padding()
            .navigationTitle("Import Documents")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: supportedTypes,
                allowsMultipleSelection: true
            ) { result in
                handleFileSelection(result)
            }
        }
    }

    private var supportedTypes: [UTType] {
        var types: [UTType] = [.pdf]

        // Word documents
        if let docx = UTType("org.openxmlformats.wordprocessingml.document") {
            types.append(docx)
        }

        // Excel files
        if let xlsx = UTType("org.openxmlformats.spreadsheetml.sheet") {
            types.append(xlsx)
        }
        if let xls = UTType("com.microsoft.excel.xls") {
            types.append(xls)
        }

        // Fallback: allow any file
        types.append(.item)

        return types
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard !urls.isEmpty else { return }
            processFiles(urls)
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func processFiles(_ urls: [URL]) {
        isProcessing = true
        processingMessage = "Reading \(urls.count) document(s)..."

        Task {
            do {
                // Process files in parallel using TaskGroup
                let results = try await withThrowingTaskGroup(of: ProcessedDocument?.self) { group in
                    for url in urls {
                        group.addTask {
                            guard url.startAccessingSecurityScopedResource() else { return nil }
                            defer { url.stopAccessingSecurityScopedResource() }
                            return try await self.processDocument(url)
                        }
                    }

                    var documents: [ProcessedDocument] = []
                    for try await result in group {
                        if let doc = result {
                            documents.append(doc)
                        }
                    }
                    return documents
                }

                // Merge results (use array join instead of += for O(n) instead of O(n²))
                var allNotes: [ClinicalNote] = []
                var patientInfo = PatientInfo()
                var rawTextParts: [String] = []
                var allExtractedData: [ClinicalCategory: [String]] = [:]

                for content in results {
                    rawTextParts.append(content.text)
                    allNotes.append(contentsOf: content.notes)

                    // Merge extracted data
                    for (category, items) in content.extractedData {
                        if allExtractedData[category] != nil {
                            allExtractedData[category]?.append(contentsOf: items)
                        } else {
                            allExtractedData[category] = items
                        }
                    }

                    if patientInfo.fullName.isEmpty && !content.patientInfo.fullName.isEmpty {
                        patientInfo = content.patientInfo
                    }
                }

                let rawText = rawTextParts.joined(separator: "\n\n")

                await MainActor.run {
                    importedContent = ImportedContent(
                        notes: allNotes,
                        patientInfo: patientInfo,
                        rawText: rawText,
                        fileCount: urls.count,
                        extractedData: allExtractedData
                    )
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isProcessing = false
                }
            }
        }
    }

    private func processDocument(_ url: URL) async throws -> ProcessedDocument {
        // Use the DocumentProcessor for actual extraction
        let extracted = try await DocumentProcessor.shared.processDocument(at: url)

        return ProcessedDocument(
            text: extracted.text,
            notes: extracted.notes,
            patientInfo: extracted.patientInfo,
            extractedData: extracted.extractedData
        )
    }

    private func detectSource(from filename: String) -> NoteSource {
        let lower = filename.lowercased()
        if lower.contains("rio") {
            return .rio
        } else if lower.contains("carenotes") {
            return .carenotes
        } else if lower.contains("epjs") {
            return .epjs
        }
        return .imported
    }

    private func confirmImport(_ content: ImportedContent) {
        // Add notes to shared store
        sharedData.addNotes(content.notes, source: "document_import")

        // Update patient info if available
        if !content.patientInfo.fullName.isEmpty {
            sharedData.setPatientInfo(content.patientInfo, source: "document_import")
        }

        // Always store extracted data (even if categories are empty, include notes)
        var extractedData = ExtractedData()
        extractedData.categories = content.extractedData
        extractedData.patientInfo = content.patientInfo
        extractedData.notes = content.notes

        // If no categories but we have notes, put the note text in Summary
        if extractedData.categories.isEmpty && !content.notes.isEmpty {
            let summaryTexts = content.notes.map { $0.body }
            extractedData.categories[.summary] = summaryTexts
        }

        sharedData.setExtractedData(extractedData, source: "document_import")

        dismiss()
    }
}

// MARK: - Import Options View
struct ImportOptionsView: View {
    let onSelectFile: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            VStack(spacing: 8) {
                Text("Import Clinical Notes")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Select PDF, DOCX, or Excel files containing clinical notes to import.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 12) {
                SupportedFormatRow(icon: "doc.fill", format: "PDF", description: "Clinical letters, reports")
                SupportedFormatRow(icon: "doc.text.fill", format: "DOCX", description: "Word documents")
                SupportedFormatRow(icon: "tablecells.fill", format: "Excel", description: "Spreadsheet exports")
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)

            Button(action: onSelectFile) {
                Label("Select Files", systemImage: "folder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}

struct SupportedFormatRow: View {
    let icon: String
    let format: String
    let description: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)

            Text(format)
                .fontWeight(.medium)

            Spacer()

            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Import Preview View
struct ImportPreviewView: View {
    let content: ImportedContent
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Summary
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)

                    Text("Ready to Import")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("\(content.fileCount) file(s) processed")
                        .foregroundColor(.secondary)
                }

                // Stats
                VStack(spacing: 12) {
                    StatRow(label: "Notes Found", value: "\(content.notes.count)")

                    if !content.patientInfo.fullName.isEmpty {
                        StatRow(label: "Patient", value: content.patientInfo.fullName)
                    }

                    if let dob = content.patientInfo.dateOfBirth {
                        StatRow(label: "DOB", value: formatDate(dob))
                    }

                    if !content.patientInfo.nhsNumber.isEmpty {
                        StatRow(label: "NHS Number", value: content.patientInfo.nhsNumber)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // Extracted Clinical Data
                if !content.extractedData.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Categories Detected")
                            .font(.headline)

                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(content.extractedData.keys).prefix(10), id: \.self) { category in
                                HStack {
                                    Image(systemName: category.iconName)
                                        .foregroundColor(.blue)
                                        .frame(width: 20)
                                    Text(category.displayName)
                                        .font(.subheadline)
                                }
                            }
                        }

                        if content.extractedData.count > 10 {
                            Text("+ \(content.extractedData.count - 10) more categories")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }

                // Preview of first note
                if let firstNote = content.notes.first {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Text Preview")
                            .font(.headline)

                        Text(firstNote.preview)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(6)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }

                // Actions
                HStack(spacing: 12) {
                    Button("Cancel", role: .cancel, action: onCancel)
                        .buttonStyle(.bordered)

                    Button("Import", action: onConfirm)
                        .buttonStyle(.borderedProminent)
                }
                .padding(.top)
            }
            .padding()
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Supporting Types
struct ImportedContent {
    let notes: [ClinicalNote]
    let patientInfo: PatientInfo
    let rawText: String
    let fileCount: Int
    var extractedData: [ClinicalCategory: [String]] = [:]
}

struct ProcessedDocument {
    let text: String
    let notes: [ClinicalNote]
    let patientInfo: PatientInfo
    var extractedData: [ClinicalCategory: [String]] = [:]
}

#Preview {
    DocumentImportView()
        .environment(AppStore())
        .environment(SharedDataStore.shared)
}
