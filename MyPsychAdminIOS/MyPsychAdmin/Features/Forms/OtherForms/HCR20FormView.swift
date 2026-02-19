//
//  HCR20FormView.swift
//  MyPsychAdmin
//
//  HCR-20 V3 Risk Assessment Form for iOS
//  Based on desktop hcr20_form_page.py structure
//  Matches ASR form template UI patterns
//

import SwiftUI
import UniformTypeIdentifiers
import Combine

struct HCR20FormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var appStore
    @Environment(SharedDataStore.self) private var sharedData

    @State private var formData: HCR20FormData
    @State private var validationErrors: [FormValidationError] = []

    // Card text content - split into generated (from controls) and manual notes
    @State private var generatedTexts: [HCR20Section: String] = [:]
    @State private var manualNotes: [HCR20Section: String] = [:]

    // Popup control
    @State private var activePopup: HCR20Section? = nil

    // Export states
    @State private var docxURL: URL?
    @State private var isExporting = false
    @State private var showShareSheet = false
    @State private var exportError: String?

    // Import states
    @State private var showingImportPicker = false
    @State private var isImporting = false
    @State private var importStatusMessage: String?
    @State private var hasPopulatedFromSharedData = false

    // HCR-20 Sections
    enum HCR20Section: String, CaseIterable, Identifiable {
        // Patient & Assessment
        case patientDetails = "Patient Details"
        case assessmentDetails = "Assessment Details"
        case sourcesOfInformation = "Sources of Information"

        // Historical Items (H1-H10)
        case h1 = "H1: Violence"
        case h2 = "H2: Antisocial Behaviour"
        case h3 = "H3: Relationships"
        case h4 = "H4: Employment"
        case h5 = "H5: Substance Use"
        case h6 = "H6: Major Mental Disorder"
        case h7 = "H7: Personality Disorder"
        case h8 = "H8: Traumatic Experiences"
        case h9 = "H9: Violent Attitudes"
        case h10 = "H10: Treatment Response"

        // Clinical Items (C1-C5)
        case c1 = "C1: Insight"
        case c2 = "C2: Violent Ideation"
        case c3 = "C3: Symptoms"
        case c4 = "C4: Instability"
        case c5 = "C5: Treatment Response"

        // Risk Management Items (R1-R5)
        case r1 = "R1: Professional Services"
        case r2 = "R2: Living Situation"
        case r3 = "R3: Personal Support"
        case r4 = "R4: Treatment Response"
        case r5 = "R5: Stress/Coping"

        // Summary sections
        case formulation = "Formulation"
        case scenarios = "Scenarios"
        case management = "Management"
        case signature = "Signature"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .patientDetails: return "person"
            case .assessmentDetails: return "doc.text"
            case .sourcesOfInformation: return "list.bullet.rectangle"
            case .h1: return "exclamationmark.triangle"
            case .h2: return "person.badge.minus"
            case .h3: return "person.2"
            case .h4: return "briefcase"
            case .h5: return "pills"
            case .h6: return "brain.head.profile"
            case .h7: return "person.crop.circle.badge.exclamationmark"
            case .h8: return "heart.slash"
            case .h9: return "bubble.left.and.exclamationmark.bubble.right"
            case .h10: return "hand.raised.slash"
            case .c1: return "eye"
            case .c2: return "bolt.circle"
            case .c3: return "waveform.path.ecg"
            case .c4: return "arrow.up.arrow.down"
            case .c5: return "checkmark.shield"
            case .r1: return "building.2"
            case .r2: return "house"
            case .r3: return "person.3"
            case .r4: return "stethoscope"
            case .r5: return "brain"
            case .formulation: return "doc.richtext"
            case .scenarios: return "chart.bar.doc.horizontal"
            case .management: return "slider.horizontal.3"
            case .signature: return "signature"
            }
        }

        var defaultHeight: CGFloat {
            switch self {
            case .patientDetails, .assessmentDetails, .signature: return 120
            case .sourcesOfInformation: return 100
            case .formulation, .scenarios, .management: return 200
            default: return 150
            }
        }

        var isHCRItem: Bool {
            switch self {
            case .h1, .h2, .h3, .h4, .h5, .h6, .h7, .h8, .h9, .h10,
                 .c1, .c2, .c3, .c4, .c5,
                 .r1, .r2, .r3, .r4, .r5:
                return true
            default:
                return false
            }
        }

        var itemKey: String {
            switch self {
            case .h1: return "h1"
            case .h2: return "h2"
            case .h3: return "h3"
            case .h4: return "h4"
            case .h5: return "h5"
            case .h6: return "h6"
            case .h7: return "h7"
            case .h8: return "h8"
            case .h9: return "h9"
            case .h10: return "h10"
            case .c1: return "c1"
            case .c2: return "c2"
            case .c3: return "c3"
            case .c4: return "c4"
            case .c5: return "c5"
            case .r1: return "r1"
            case .r2: return "r2"
            case .r3: return "r3"
            case .r4: return "r4"
            case .r5: return "r5"
            default: return ""
            }
        }

        var fullTitle: String {
            HCR20FormData.itemTitles[itemKey] ?? rawValue
        }
    }

    // Keys for persistence
    private static let formDataKey = "HCR20FormData_saved"
    private static let generatedTextsKey = "HCR20FormData_generatedTexts"
    private static let manualNotesKey = "HCR20FormData_manualNotes"

    init() {
        if let savedData = Self.loadFormData() {
            _formData = State(initialValue: savedData)
        } else {
            _formData = State(initialValue: HCR20FormData())
        }
        _generatedTexts = State(initialValue: Self.loadGeneratedTexts())
        _manualNotes = State(initialValue: Self.loadManualNotes())
    }

    // MARK: - Persistence

    private static func loadFormData() -> HCR20FormData? {
        guard let data = UserDefaults.standard.data(forKey: formDataKey) else { return nil }
        guard var formData = try? JSONDecoder().decode(HCR20FormData.self, from: data) else { return nil }

        // Clear any persisted imported entries - they should only exist during active session
        formData.h1.importedEntries = []
        formData.h2.importedEntries = []
        formData.h3.importedEntries = []
        formData.h4.importedEntries = []
        formData.h5.importedEntries = []
        formData.h6.importedEntries = []
        formData.h7.importedEntries = []
        formData.h8.importedEntries = []
        formData.h9.importedEntries = []
        formData.h10.importedEntries = []
        formData.c1.importedEntries = []
        formData.c2.importedEntries = []
        formData.c3.importedEntries = []
        formData.c4.importedEntries = []
        formData.c5.importedEntries = []
        formData.r1.importedEntries = []
        formData.r2.importedEntries = []
        formData.r3.importedEntries = []
        formData.r4.importedEntries = []
        formData.r5.importedEntries = []

        return formData
    }

    private static func saveFormData(_ formData: HCR20FormData) {
        // Create a copy with imported entries cleared to avoid UserDefaults 4MB limit
        // Imported entries are transient and only used while the app is open
        var strippedData = formData
        strippedData.h1.importedEntries = []
        strippedData.h2.importedEntries = []
        strippedData.h3.importedEntries = []
        strippedData.h4.importedEntries = []
        strippedData.h5.importedEntries = []
        strippedData.h6.importedEntries = []
        strippedData.h7.importedEntries = []
        strippedData.h8.importedEntries = []
        strippedData.h9.importedEntries = []
        strippedData.h10.importedEntries = []
        strippedData.c1.importedEntries = []
        strippedData.c2.importedEntries = []
        strippedData.c3.importedEntries = []
        strippedData.c4.importedEntries = []
        strippedData.c5.importedEntries = []
        strippedData.r1.importedEntries = []
        strippedData.r2.importedEntries = []
        strippedData.r3.importedEntries = []
        strippedData.r4.importedEntries = []
        strippedData.r5.importedEntries = []

        if let data = try? JSONEncoder().encode(strippedData) {
            UserDefaults.standard.set(data, forKey: formDataKey)
        }
    }

    private static func loadGeneratedTexts() -> [HCR20Section: String] {
        guard let data = UserDefaults.standard.data(forKey: generatedTextsKey),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        var result: [HCR20Section: String] = [:]
        for (key, value) in dict {
            if let section = HCR20Section(rawValue: key) {
                result[section] = value
            }
        }
        return result
    }

    private static func saveGeneratedTexts(_ texts: [HCR20Section: String]) {
        let dict = Dictionary(uniqueKeysWithValues: texts.map { ($0.key.rawValue, $0.value) })
        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: generatedTextsKey)
        }
    }

    private static func loadManualNotes() -> [HCR20Section: String] {
        guard let data = UserDefaults.standard.data(forKey: manualNotesKey),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        var result: [HCR20Section: String] = [:]
        for (key, value) in dict {
            if let section = HCR20Section(rawValue: key) {
                result[section] = value
            }
        }
        return result
    }

    private static func saveManualNotes(_ notes: [HCR20Section: String]) {
        let dict = Dictionary(uniqueKeysWithValues: notes.map { ($0.key.rawValue, $0.value) })
        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: manualNotesKey)
        }
    }

    private func saveAllData() {
        Self.saveFormData(formData)
        Self.saveGeneratedTexts(generatedTexts)
        Self.saveManualNotes(manualNotes)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if let error = exportError {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.horizontal)
                    }

                    FormValidationErrorView(errors: validationErrors)
                        .padding(.horizontal)

                    // All section cards
                    ForEach(HCR20Section.allCases) { section in
                        HCR20EditableCard(
                            section: section,
                            formData: formData,
                            text: binding(for: section),
                            onHeaderTap: { activePopup = section }
                        )
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("HCR-20 V3")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        if let message = importStatusMessage {
                            Text(message)
                                .font(.caption)
                                .foregroundColor(.green)
                        }

                        if isImporting {
                            ProgressView()
                                .progressViewStyle(.circular)
                        } else {
                            Button {
                                showingImportPicker = true
                            } label: {
                                Image(systemName: "square.and.arrow.down")
                            }
                        }

                        if isExporting {
                            ProgressView()
                        } else {
                            Button {
                                exportDOCX()
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            prefillFromSharedData()
            initializeCardTexts()
            if !hasPopulatedFromSharedData && !sharedData.notes.isEmpty {
                populateFromClinicalNotes(sharedData.notes)
                hasPopulatedFromSharedData = true
            }
        }
        .onReceive(sharedData.notesDidChange) { notes in
            if !notes.isEmpty {
                populateFromClinicalNotes(notes)
            }
        }
        .onDisappear {
            saveAllData()
        }
        .onChange(of: formData) { _, _ in
            saveAllData()
        }
        .onChange(of: generatedTexts) { _, _ in
            Self.saveGeneratedTexts(generatedTexts)
        }
        .onChange(of: manualNotes) { _, _ in
            Self.saveManualNotes(manualNotes)
        }
        .sheet(item: $activePopup) { section in
            HCR20PopupView(
                section: section,
                formData: $formData,
                manualNotes: manualNotes[section] ?? "",
                onGenerate: { generatedText, notes in
                    generatedTexts[section] = generatedText
                    manualNotes[section] = notes
                    activePopup = nil
                },
                onDismiss: { activePopup = nil }
            )
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = docxURL {
                ShareSheet(items: [url])
            }
        }
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [
                .plainText,
                .pdf,
                UTType(filenameExtension: "xlsx") ?? .data,
                UTType(filenameExtension: "xls") ?? .data,
                UTType(filenameExtension: "docx") ?? .data,
                UTType(filenameExtension: "doc") ?? .data
            ],
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result)
        }
    }

    private func binding(for section: HCR20Section) -> Binding<String> {
        Binding(
            get: {
                let generated = generatedTexts[section] ?? ""
                let manual = manualNotes[section] ?? ""
                if generated.isEmpty && manual.isEmpty { return "" }
                if generated.isEmpty { return manual }
                if manual.isEmpty { return generated }
                return generated + "\n\n" + manual
            },
            set: { newValue in
                let generated = generatedTexts[section] ?? ""
                if generated.isEmpty {
                    manualNotes[section] = newValue
                } else if newValue.hasPrefix(generated) {
                    let afterGenerated = String(newValue.dropFirst(generated.count))
                    manualNotes[section] = afterGenerated.trimmingCharacters(in: .whitespacesAndNewlines)
                } else {
                    manualNotes[section] = newValue
                    generatedTexts[section] = ""
                }
            }
        )
    }

    private func initializeCardTexts() {
        for section in HCR20Section.allCases {
            if generatedTexts[section] == nil { generatedTexts[section] = "" }
            if manualNotes[section] == nil { manualNotes[section] = "" }
        }
    }

    private func prefillFromSharedData() {
        if !sharedData.patientInfo.fullName.isEmpty {
            formData.patientName = sharedData.patientInfo.fullName
            formData.patientDOB = sharedData.patientInfo.dateOfBirth
            formData.patientGender = sharedData.patientInfo.gender
        }
        if !appStore.clinicianInfo.fullName.isEmpty {
            formData.assessorName = appStore.clinicianInfo.fullName
            formData.assessorRole = appStore.clinicianInfo.roleTitle
            formData.hospitalName = appStore.clinicianInfo.hospitalOrg
        }
    }

    private func exportDOCX() {
        syncCardTextsToFormData()
        validationErrors = formData.validate()
        guard validationErrors.isEmpty else { return }

        isExporting = true
        exportError = nil

        DispatchQueue.global(qos: .userInitiated).async {
            let data = HCR20FormDOCXExporter(formData: formData).generateDOCX()

            DispatchQueue.main.async {
                isExporting = false

                guard let docxData = data else {
                    exportError = "Failed to generate document"
                    return
                }

                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
                let patientName = formData.patientName.isEmpty ? "Patient" : formData.patientName.replacingOccurrences(of: " ", with: "_")
                let filename = "HCR20_\(patientName)_\(dateFormatter.string(from: Date())).docx"
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

                do {
                    try docxData.write(to: tempURL)
                    docxURL = tempURL
                    showShareSheet = true
                } catch {
                    exportError = "Failed to save document: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Import Handling

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            guard url.startAccessingSecurityScopedResource() else {
                exportError = "Cannot access file"
                return
            }

            isImporting = true
            importStatusMessage = "Processing file..."

            Task {
                defer {
                    url.stopAccessingSecurityScopedResource()
                }

                do {
                    let tempDir = FileManager.default.temporaryDirectory
                    let tempURL = tempDir.appendingPathComponent(url.lastPathComponent)

                    try? FileManager.default.removeItem(at: tempURL)
                    try FileManager.default.copyItem(at: url, to: tempURL)

                    let extractedDoc = try await DocumentProcessor.shared.processDocument(at: tempURL)

                    await MainActor.run {
                        if !extractedDoc.notes.isEmpty {
                            sharedData.setNotes(extractedDoc.notes, source: "hcr20_import")
                        }

                        if !extractedDoc.patientInfo.fullName.isEmpty {
                            // Set in SharedDataStore so other views get notified
                            sharedData.setPatientInfo(extractedDoc.patientInfo, source: "hcr20_import")
                            formData.patientName = extractedDoc.patientInfo.fullName
                            if let dob = extractedDoc.patientInfo.dateOfBirth {
                                formData.patientDOB = dob
                            }
                            formData.patientGender = extractedDoc.patientInfo.gender
                        }

                        populateFromClinicalNotes(extractedDoc.notes)

                        isImporting = false
                        let noteCount = extractedDoc.notes.count
                        importStatusMessage = "Imported \(noteCount) notes"

                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            importStatusMessage = nil
                        }
                    }

                    try? FileManager.default.removeItem(at: tempURL)

                } catch {
                    await MainActor.run {
                        isImporting = false
                        exportError = "Import failed: \(error.localizedDescription)"
                    }
                }
            }

        case .failure(let error):
            exportError = "Import failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Populate from Clinical Notes

    private func populateFromClinicalNotes(_ notes: [ClinicalNote]) {
        guard !notes.isEmpty else { return }

        print("[HCR-20 iOS] Populating from \(notes.count) clinical notes")

        // Clear existing imported entries for all items
        clearAllImportedEntries()

        // Find most recent date for temporal filtering
        let sortedDates = notes.compactMap { $0.date }.sorted()
        let mostRecentDate = sortedDates.last ?? Date()
        let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: mostRecentDate) ?? mostRecentDate

        // Process each note
        for note in notes {
            let text = note.body
            let date = note.date
            let snippet = text.count > 150 ? String(text.prefix(150)) + "..." : text

            // Historical items (H1-H10): search ALL notes
            categorizeAndAddToItem(&formData.h1, text: text, date: date, snippet: snippet, keywords: HCR20CategoryKeywords.h1)
            categorizeAndAddToItem(&formData.h2, text: text, date: date, snippet: snippet, keywords: HCR20CategoryKeywords.h2)
            categorizeAndAddToItem(&formData.h3, text: text, date: date, snippet: snippet, keywords: HCR20CategoryKeywords.h3)
            categorizeAndAddToItem(&formData.h4, text: text, date: date, snippet: snippet, keywords: HCR20CategoryKeywords.h4)
            categorizeAndAddToItem(&formData.h5, text: text, date: date, snippet: snippet, keywords: HCR20CategoryKeywords.h5)
            categorizeAndAddToItem(&formData.h6, text: text, date: date, snippet: snippet, keywords: HCR20CategoryKeywords.h6)
            categorizeAndAddToItem(&formData.h7, text: text, date: date, snippet: snippet, keywords: HCR20CategoryKeywords.h7)
            categorizeAndAddToItem(&formData.h8, text: text, date: date, snippet: snippet, keywords: HCR20CategoryKeywords.h8)
            categorizeAndAddToItem(&formData.h9, text: text, date: date, snippet: snippet, keywords: HCR20CategoryKeywords.h9)
            categorizeAndAddToItem(&formData.h10, text: text, date: date, snippet: snippet, keywords: HCR20CategoryKeywords.h10)

            // Clinical items (C1-C5): only last 6 months
            if date >= sixMonthsAgo {
                categorizeAndAddToItem(&formData.c1, text: text, date: date, snippet: snippet, keywords: HCR20CategoryKeywords.c1)
                categorizeAndAddToItem(&formData.c2, text: text, date: date, snippet: snippet, keywords: HCR20CategoryKeywords.c2)
                categorizeAndAddToItem(&formData.c3, text: text, date: date, snippet: snippet, keywords: HCR20CategoryKeywords.c3)
                categorizeAndAddToItem(&formData.c4, text: text, date: date, snippet: snippet, keywords: HCR20CategoryKeywords.c4)
                categorizeAndAddToItem(&formData.c5, text: text, date: date, snippet: snippet, keywords: HCR20CategoryKeywords.c5)
            }

            // Risk Management items (R1-R5): all notes (future-oriented content)
            categorizeAndAddToItem(&formData.r1, text: text, date: date, snippet: snippet, keywords: HCR20CategoryKeywords.r1)
            categorizeAndAddToItem(&formData.r2, text: text, date: date, snippet: snippet, keywords: HCR20CategoryKeywords.r2)
            categorizeAndAddToItem(&formData.r3, text: text, date: date, snippet: snippet, keywords: HCR20CategoryKeywords.r3)
            categorizeAndAddToItem(&formData.r4, text: text, date: date, snippet: snippet, keywords: HCR20CategoryKeywords.r4)
            categorizeAndAddToItem(&formData.r5, text: text, date: date, snippet: snippet, keywords: HCR20CategoryKeywords.r5)
        }

        // Sort all arrays by date (most recent first)
        sortImportedEntries()

        print("[HCR-20 iOS] Populated items")
    }

    private func clearAllImportedEntries() {
        formData.h1.importedEntries.removeAll()
        formData.h2.importedEntries.removeAll()
        formData.h3.importedEntries.removeAll()
        formData.h4.importedEntries.removeAll()
        formData.h5.importedEntries.removeAll()
        formData.h6.importedEntries.removeAll()
        formData.h7.importedEntries.removeAll()
        formData.h8.importedEntries.removeAll()
        formData.h9.importedEntries.removeAll()
        formData.h10.importedEntries.removeAll()
        formData.c1.importedEntries.removeAll()
        formData.c2.importedEntries.removeAll()
        formData.c3.importedEntries.removeAll()
        formData.c4.importedEntries.removeAll()
        formData.c5.importedEntries.removeAll()
        formData.r1.importedEntries.removeAll()
        formData.r2.importedEntries.removeAll()
        formData.r3.importedEntries.removeAll()
        formData.r4.importedEntries.removeAll()
        formData.r5.importedEntries.removeAll()
    }

    private func categorizeAndAddToItem(_ item: inout HCR20ItemData, text: String, date: Date, snippet: String, keywords: [String: [String]]) {
        let categories = HCR20CategoryKeywords.categorize(text, using: keywords)
        if !categories.isEmpty {
            item.importedEntries.append(ASRImportedEntry(date: date, text: text, categories: categories, snippet: snippet))
        }
    }

    private func sortImportedEntries() {
        formData.h1.importedEntries.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.h2.importedEntries.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.h3.importedEntries.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.h4.importedEntries.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.h5.importedEntries.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.h6.importedEntries.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.h7.importedEntries.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.h8.importedEntries.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.h9.importedEntries.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.h10.importedEntries.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.c1.importedEntries.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.c2.importedEntries.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.c3.importedEntries.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.c4.importedEntries.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.c5.importedEntries.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.r1.importedEntries.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.r2.importedEntries.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.r3.importedEntries.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.r4.importedEntries.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.r5.importedEntries.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }

    private func syncCardTextsToFormData() {
        func combinedText(for section: HCR20Section) -> String {
            let generated = generatedTexts[section] ?? ""
            let manual = manualNotes[section] ?? ""
            if generated.isEmpty && manual.isEmpty { return "" }
            if generated.isEmpty { return manual }
            if manual.isEmpty { return generated }
            return generated + "\n\n" + manual
        }

        // Sync HCR items
        formData.h1.text = combinedText(for: .h1)
        formData.h2.text = combinedText(for: .h2)
        formData.h3.text = combinedText(for: .h3)
        formData.h4.text = combinedText(for: .h4)
        formData.h5.text = combinedText(for: .h5)
        formData.h6.text = combinedText(for: .h6)
        formData.h7.text = combinedText(for: .h7)
        formData.h8.text = combinedText(for: .h8)
        formData.h9.text = combinedText(for: .h9)
        formData.h10.text = combinedText(for: .h10)
        formData.c1.text = combinedText(for: .c1)
        formData.c2.text = combinedText(for: .c2)
        formData.c3.text = combinedText(for: .c3)
        formData.c4.text = combinedText(for: .c4)
        formData.c5.text = combinedText(for: .c5)
        formData.r1.text = combinedText(for: .r1)
        formData.r2.text = combinedText(for: .r2)
        formData.r3.text = combinedText(for: .r3)
        formData.r4.text = combinedText(for: .r4)
        formData.r5.text = combinedText(for: .r5)

        // Sync other sections
        formData.formulationText = combinedText(for: .formulation)
    }
}

// MARK: - HCR-20 Editable Card (Blue theme)
struct HCR20EditableCard: View {
    let section: HCR20FormView.HCR20Section
    let formData: HCR20FormData
    @Binding var text: String
    let onHeaderTap: () -> Void

    @State private var editorHeight: CGFloat = 150

    private var itemData: HCR20ItemData? {
        guard section.isHCRItem else { return nil }
        switch section {
        case .h1: return formData.h1
        case .h2: return formData.h2
        case .h3: return formData.h3
        case .h4: return formData.h4
        case .h5: return formData.h5
        case .h6: return formData.h6
        case .h7: return formData.h7
        case .h8: return formData.h8
        case .h9: return formData.h9
        case .h10: return formData.h10
        case .c1: return formData.c1
        case .c2: return formData.c2
        case .c3: return formData.c3
        case .c4: return formData.c4
        case .c5: return formData.c5
        case .r1: return formData.r1
        case .r2: return formData.r2
        case .r3: return formData.r3
        case .r4: return formData.r4
        case .r5: return formData.r5
        default: return nil
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header - tappable to open popup
            Button(action: onHeaderTap) {
                HStack(spacing: 10) {
                    Image(systemName: section.icon)
                        .foregroundColor(.blue)
                        .frame(width: 20)

                    Text(section.rawValue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Spacer()

                    // Show presence/relevance badges for HCR items
                    if let item = itemData {
                        HStack(spacing: 4) {
                            Text(item.presence.rawValue)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(presenceColor(item.presence))
                                .foregroundColor(.white)
                                .cornerRadius(4)

                            Text(item.relevance.rawValue)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(relevanceColor(item.relevance))
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }
                    }

                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(.blue)
                        .font(.caption)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
            }
            .buttonStyle(.plain)

            // Editable text area
            TextEditor(text: $text)
                .frame(height: editorHeight)
                .padding(8)
                .background(Color(.systemBackground))
                .scrollContentBackground(.hidden)

            // Resize handle
            ResizeHandle(height: $editorHeight)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
        .onAppear {
            editorHeight = section.defaultHeight
        }
    }

    private func presenceColor(_ presence: HCR20PresenceRating) -> Color {
        switch presence {
        case .absent: return .green
        case .possible: return .orange
        case .present: return .red
        case .omit: return .gray
        }
    }

    private func relevanceColor(_ relevance: HCR20RelevanceRating) -> Color {
        switch relevance {
        case .low: return .green
        case .moderate: return .orange
        case .high: return .red
        }
    }
}

// MARK: - HCR-20 Popup View
struct HCR20PopupView: View {
    let section: HCR20FormView.HCR20Section
    @Binding var formData: HCR20FormData
    let manualNotes: String
    let onGenerate: (String, String) -> Void
    let onDismiss: () -> Void

    @State private var editableNotes: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    popupContent

                    // Manual notes section
                    Divider()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Additional Notes").font(.caption).foregroundColor(.secondary)
                        TextEditor(text: $editableNotes)
                            .frame(minHeight: 60)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(section.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { onDismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Generate") {
                        let text = generateText()
                        onGenerate(text, editableNotes)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            editableNotes = manualNotes
        }
    }

    @ViewBuilder
    private var popupContent: some View {
        switch section {
        case .patientDetails: patientDetailsPopup
        case .assessmentDetails: assessmentDetailsPopup
        case .sourcesOfInformation: sourcesPopup
        case .h7: h7PersonalityDisorderPopup
        case .h8: h8TraumaticExperiencesPopup
        case .h9: h9ViolentAttitudesPopup
        case .h10: h10TreatmentResponsePopup
        case .c1: c1InsightPopup
        case .c2: c2ViolentIdeationPopup
        case .c3: c3SymptomsPopup
        case .c4: c4InstabilityPopup
        case .c5: c5TreatmentResponsePopup
        case .r1: r1ProfessionalServicesPopup
        case .r2: r2LivingSituationPopup
        case .r3: r3PersonalSupportPopup
        case .r4: r4TreatmentCompliancePopup
        case .r5: r5StressCopingPopup
        case .h1, .h2, .h3, .h4, .h5, .h6:
            hcrItemPopup
        case .formulation: formulationPopup
        case .scenarios: scenariosPopup
        case .management: managementPopup
        case .signature: signaturePopup
        }
    }

    // MARK: - Patient Details Popup
    private var patientDetailsPopup: some View {
        VStack(alignment: .leading, spacing: 12) {
            FormTextField(label: "Patient Name", text: $formData.patientName, isRequired: true)
            FormOptionalDatePicker(label: "Date of Birth", date: $formData.patientDOB,
                                   maxDate: Calendar.current.date(byAdding: .year, value: -18, to: Date()),
                                   minDate: Calendar.current.date(byAdding: .year, value: -100, to: Date()),
                                   defaultDate: Calendar.current.date(byAdding: .year, value: -18, to: Date()))

            HStack {
                Text("Gender").font(.subheadline).foregroundColor(.secondary)
                Spacer()
                Picker("", selection: $formData.patientGender) {
                    ForEach(Gender.allCases) { g in Text(g.rawValue).tag(g) }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }

            FormTextField(label: "Hospital Number", text: $formData.hospitalNumber)
            FormTextField(label: "NHS Number", text: $formData.nhsNumber)
            FormTextField(label: "Hospital", text: $formData.hospitalName)
            FormTextField(label: "Ward", text: $formData.wardName)
            FormTextField(label: "MHA Section", text: $formData.mhaSection)
            FormOptionalDatePicker(label: "Admission Date", date: $formData.admissionDate)
        }
    }

    // MARK: - Assessment Details Popup
    private var assessmentDetailsPopup: some View {
        VStack(alignment: .leading, spacing: 12) {
            FormTextField(label: "Assessor Name", text: $formData.assessorName, isRequired: true)
            FormTextField(label: "Role/Title", text: $formData.assessorRole)
            FormTextField(label: "Qualifications", text: $formData.assessorQualifications)
            FormTextField(label: "Supervisor (if applicable)", text: $formData.supervisorName)
            FormDatePicker(label: "Assessment Date", date: $formData.assessmentDate)
            FormTextEditor(label: "Purpose of Assessment", text: $formData.assessmentPurpose)
        }
    }

    // MARK: - Sources of Information Popup
    private var sourcesPopup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sources Reviewed").font(.headline)

            Toggle("Clinical Notes", isOn: $formData.sourcesClinicalNotes)
            Toggle("Risk Assessments", isOn: $formData.sourcesRiskAssessments)
            Toggle("Forensic History", isOn: $formData.sourcesForensicHistory)
            Toggle("Psychology Reports", isOn: $formData.sourcesPsychologyReports)
            Toggle("MDT Discussion", isOn: $formData.sourcesMDTDiscussion)
            Toggle("Patient Interview", isOn: $formData.sourcesPatientInterview)
            Toggle("Collateral Information", isOn: $formData.sourcesCollateralInfo)

            FormTextField(label: "Other Sources", text: $formData.sourcesOther)

            FormTextEditor(label: "Additional Details", text: $formData.sourcesOfInformation, minHeight: 100)
        }
    }

    // MARK: - HCR Item Popup (Generic for H1-H10, C1-C5, R1-R5)
    // Matches desktop structure: Presence, Relevance, Subsection text editors, Imported data
    private var hcrItemPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Item title
            Text(section.fullTitle)
                .font(.headline)
                .foregroundColor(.blue)

            // Clinical items show 6-month reminder
            if section.itemKey.hasPrefix("c") {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.orange)
                    Text("Clinical items consider the last 6 months only")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }

            // Risk Management items show Hospital/Community note
            if section.itemKey.hasPrefix("r") {
                HStack {
                    Image(systemName: "building.2")
                        .foregroundColor(.purple)
                    Text("Consider both hospital and community scenarios")
                        .font(.caption)
                        .foregroundColor(.purple)
                }
                .padding(8)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(8)
            }

            // Presence Rating
            VStack(alignment: .leading, spacing: 8) {
                Text("Presence:").font(.subheadline.weight(.semibold))
                HStack(spacing: 8) {
                    ForEach(HCR20PresenceRating.allCases) { rating in
                        Button {
                            setPresence(rating)
                        } label: {
                            Text(rating.displayText)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(currentPresence == rating ? presenceColor(rating) : Color(.systemGray5))
                                .foregroundColor(currentPresence == rating ? .white : .primary)
                                .cornerRadius(8)
                        }
                    }
                }
            }

            // Relevance Rating
            VStack(alignment: .leading, spacing: 8) {
                Text("Relevance:").font(.subheadline.weight(.semibold))
                HStack(spacing: 8) {
                    ForEach(HCR20RelevanceRating.allCases) { rating in
                        Button {
                            setRelevance(rating)
                        } label: {
                            Text(rating.rawValue)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(currentRelevance == rating ? relevanceColor(rating) : Color(.systemGray5))
                                .foregroundColor(currentRelevance == rating ? .white : .primary)
                                .cornerRadius(8)
                        }
                    }
                }
            }

            Divider()

            // Subsections - Each with a text editor (matches desktop structure)
            if let subsections = HCR20FormData.itemSubsections[section.itemKey] {
                ForEach(Array(subsections.enumerated()), id: \.offset) { index, subsection in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(subsection.0)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)

                        TextEditor(text: subsectionTextBinding(for: subsection.0))
                            .frame(minHeight: 80)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .overlay(
                                Group {
                                    if (currentItemData?.subsectionTexts[subsection.0] ?? "").isEmpty {
                                        Text(subsection.1)
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                            .padding(12)
                                            .allowsHitTesting(false)
                                    }
                                },
                                alignment: .topLeading
                            )
                    }
                }

                Divider()
            }

            // Imported Data Section
            if !currentImportedEntries.isEmpty {
                ImportedDataSection(
                    title: "Imported Notes (\(currentImportedEntries.count))",
                    entries: importedEntriesBinding,
                    categoryKeywords: HCR20CategoryKeywords.keywordsFor(item: section.itemKey)
                )
            }
        }
    }

    // MARK: - Formulation Popup
    private var formulationPopup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Violence Risk Formulation").font(.headline)
            Text("Integrate findings from HCR-20 items to provide a narrative formulation of the individual's violence risk.")
                .font(.caption)
                .foregroundColor(.secondary)

            FormTextEditor(label: "Formulation", text: $formData.formulationText, minHeight: 200)
        }
    }

    // MARK: - Scenarios Popup
    private var scenariosPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            // ═══════════════════════════════════════════════════════════════
            // 1. Nature of Risk
            // ═══════════════════════════════════════════════════════════════
            VStack(alignment: .leading, spacing: 12) {
                Text("1. Nature of Risk")
                    .font(.headline)
                    .foregroundColor(.blue)

                Text("Specify what kind of harm is likely. Select all applicable types.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Type of Harm
                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Type of Harm").font(.subheadline.weight(.semibold)).foregroundColor(.blue)
                        Toggle("Physical violence (general)", isOn: $formData.harmPhysicalGeneral)
                        Toggle("Physical violence (targeted at specific person)", isOn: $formData.harmPhysicalTargeted)
                        Toggle("Domestic violence", isOn: $formData.harmDomestic)
                        Toggle("Threatening or intimidating behaviour", isOn: $formData.harmThreatening)
                        Toggle("Weapon-related risk", isOn: $formData.harmWeapon)
                        Toggle("Sexual violence", isOn: $formData.harmSexual)
                        Toggle("Arson / property damage", isOn: $formData.harmArson)
                        Toggle("Institutional aggression (staff, patients)", isOn: $formData.harmInstitutional)
                        Toggle("Stalking / harassment", isOn: $formData.harmStalking)
                    }
                    .font(.subheadline)
                }
                .backgroundStyle(Color.blue.opacity(0.05))

                // Potential Victims
                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Potential Victims").font(.subheadline.weight(.semibold)).foregroundColor(.red)
                        Toggle("Known others (family, partners, acquaintances)", isOn: $formData.victimKnown)
                        Toggle("Strangers", isOn: $formData.victimStrangers)
                        Toggle("Staff / professionals", isOn: $formData.victimStaff)
                        Toggle("Co-patients / service users", isOn: $formData.victimPatients)
                        Toggle("Authority figures", isOn: $formData.victimAuthority)
                        Toggle("Vulnerable groups (children, elderly)", isOn: $formData.victimChildren)
                    }
                    .font(.subheadline)
                }
                .backgroundStyle(Color.red.opacity(0.05))

                // Likely Motivation
                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Likely Motivation").font(.subheadline.weight(.semibold)).foregroundColor(.orange)
                        Toggle("Impulsive / reactive (emotional dysregulation)", isOn: $formData.motivImpulsive)
                        Toggle("Instrumental / goal-directed", isOn: $formData.motivInstrumental)
                        Toggle("Paranoid / persecutory beliefs", isOn: $formData.motivParanoid)
                        Toggle("Response to command hallucinations", isOn: $formData.motivCommand)
                        Toggle("Grievance / revenge", isOn: $formData.motivGrievance)
                        Toggle("Territorial / defensive", isOn: $formData.motivTerritorial)
                        Toggle("Substance-related disinhibition", isOn: $formData.motivSubstance)
                    }
                    .font(.subheadline)
                }
                .backgroundStyle(Color.orange.opacity(0.05))
            }

            Divider()

            // ═══════════════════════════════════════════════════════════════
            // 2. Severity
            // ═══════════════════════════════════════════════════════════════
            VStack(alignment: .leading, spacing: 12) {
                Text("2. Severity")
                    .font(.headline)
                    .foregroundColor(.blue)

                Text("How serious could the harm be?")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Severity level picker
                Picker("Severity Level", selection: $formData.severityLevel) {
                    Text("Not selected").tag("")
                    Text("Low (minor injury/verbal threats)").tag("low")
                    Text("Moderate (assault causing injury)").tag("moderate")
                    Text("High (serious injury/weapon use)").tag("high")
                }
                .pickerStyle(.segmented)

                // Severity factors
                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Severity Factors").font(.subheadline.weight(.semibold)).foregroundColor(.orange)

                        if !generateSeverityFactorsText().isEmpty {
                            Text(generateSeverityFactorsText())
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }

                        DisclosureGroup("Select Indicators") {
                            VStack(alignment: .leading, spacing: 4) {
                                Toggle("History of assaults involving significant force", isOn: $formData.sevHistSerious)
                                Toggle("Limited inhibition when unwell", isOn: $formData.sevLimitedInhibition)
                                Toggle("Previous weapon use", isOn: $formData.sevWeaponHistory)
                                Toggle("Risk to vulnerable victims", isOn: $formData.sevVulnerableVictims)
                                Toggle("Pattern of escalation in violence", isOn: $formData.sevEscalationPattern)
                                Toggle("Lack of remorse following violence", isOn: $formData.sevLackRemorse)
                            }
                            .font(.caption)
                        }
                    }
                }
                .backgroundStyle(Color.orange.opacity(0.05))
            }

            Divider()

            // ═══════════════════════════════════════════════════════════════
            // 3. Imminence
            // ═══════════════════════════════════════════════════════════════
            VStack(alignment: .leading, spacing: 12) {
                Text("3. Imminence")
                    .font(.headline)
                    .foregroundColor(.blue)

                Text("How soon could risk escalate? Consider pending transitions and changes to protective factors.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Picker("Imminence", selection: $formData.imminenceLevel) {
                    Text("Not selected").tag("")
                    Text("Imminent (days)").tag("imminent")
                    Text("Short-term (weeks)").tag("weeks")
                    Text("Medium-term (months)").tag("months")
                    Text("Long-term (years)").tag("longterm")
                }
                .pickerStyle(.menu)

                // Current Trigger Status
                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Current Trigger Status").font(.subheadline.weight(.semibold)).foregroundColor(.red)

                        if !generateTriggerStatusText().isEmpty {
                            Text(generateTriggerStatusText())
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }

                        DisclosureGroup("Select Indicators") {
                            VStack(alignment: .leading, spacing: 4) {
                                Toggle("Triggers already present", isOn: $formData.trigPresent)
                                Toggle("Triggers emerging / building", isOn: $formData.trigEmerging)
                                Toggle("No current triggers identified", isOn: $formData.trigAbsent)
                            }
                            .font(.caption)
                        }
                    }
                }
                .backgroundStyle(Color.red.opacity(0.05))

                // Pending Transitions
                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Pending Transitions").font(.subheadline.weight(.semibold)).foregroundColor(.orange)

                        if !generateTransitionsText().isEmpty {
                            Text(generateTransitionsText())
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }

                        DisclosureGroup("Select Indicators") {
                            VStack(alignment: .leading, spacing: 4) {
                                Toggle("Discharge pending", isOn: $formData.transDischarge)
                                Toggle("Leave / unescorted access pending", isOn: $formData.transLeave)
                                Toggle("Supervision reduction pending", isOn: $formData.transReducedSupervision)
                                Toggle("Accommodation change pending", isOn: $formData.transAccommodation)
                                Toggle("Relationship change anticipated", isOn: $formData.transRelationship)
                                Toggle("Legal proceedings pending", isOn: $formData.transLegal)
                            }
                            .font(.caption)
                        }
                    }
                }
                .backgroundStyle(Color.orange.opacity(0.05))

                // Protective Factor Changes
                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Protective Factor Changes").font(.subheadline.weight(.semibold)).foregroundColor(.green)

                        if !generateProtectiveChangesText().isEmpty {
                            Text(generateProtectiveChangesText())
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }

                        DisclosureGroup("Select Indicators") {
                            VStack(alignment: .leading, spacing: 4) {
                                Toggle("Protective factors about to reduce", isOn: $formData.protReducing)
                                Toggle("Protective factors stable", isOn: $formData.protStable)
                                Toggle("Protective factors increasing", isOn: $formData.protIncreasing)
                            }
                            .font(.caption)
                        }
                    }
                }
                .backgroundStyle(Color.green.opacity(0.05))
            }

            Divider()

            // ═══════════════════════════════════════════════════════════════
            // 4. Frequency
            // ═══════════════════════════════════════════════════════════════
            VStack(alignment: .leading, spacing: 12) {
                Text("4. Frequency")
                    .font(.headline)
                    .foregroundColor(.blue)

                Text("How often might risk events occur? Focus on patterns, not counts.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Risk Pattern
                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Risk Pattern").font(.subheadline.weight(.semibold)).foregroundColor(.blue)

                        Picker("Pattern", selection: $formData.frequencyPattern) {
                            Text("Not selected").tag("")
                            Text("Episodic — linked to specific triggers").tag("episodic")
                            Text("Clustered — during relapse/stress periods").tag("clustered")
                            Text("Persistent — background risk").tag("persistent")
                            Text("Rare but severe").tag("rare")
                        }
                        .pickerStyle(.menu)
                    }
                }
                .backgroundStyle(Color.blue.opacity(0.05))

                // Trigger Contexts
                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Trigger Contexts").font(.subheadline.weight(.semibold)).foregroundColor(.orange)

                        if !generateFrequencyContextText().isEmpty {
                            Text(generateFrequencyContextText())
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }

                        DisclosureGroup("Select Indicators") {
                            VStack(alignment: .leading, spacing: 4) {
                                Toggle("Acute stress periods", isOn: $formData.ctxStress)
                                Toggle("Mental health relapse", isOn: $formData.ctxRelapse)
                                Toggle("Substance intoxication", isOn: $formData.ctxSubstance)
                                Toggle("Interpersonal conflict", isOn: $formData.ctxInterpersonal)
                                Toggle("Frustration / goal blocking", isOn: $formData.ctxFrustration)
                                Toggle("Perceived threat or provocation", isOn: $formData.ctxPerceivedThreat)
                            }
                            .font(.caption)
                        }
                    }
                }
                .backgroundStyle(Color.orange.opacity(0.05))
            }

            Divider()

            // ═══════════════════════════════════════════════════════════════
            // 5. Likelihood
            // ═══════════════════════════════════════════════════════════════
            VStack(alignment: .leading, spacing: 12) {
                Text("5. Likelihood")
                    .font(.headline)
                    .foregroundColor(.blue)

                Text("How plausible is the scenario? This is conditional likelihood, not absolute probability.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Baseline Likelihood
                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Baseline Likelihood").font(.subheadline.weight(.semibold)).foregroundColor(.blue)

                        Picker("Baseline", selection: $formData.likelihoodBaseline) {
                            Text("Not selected").tag("")
                            Text("Low — unless specific triggers occur").tag("low")
                            Text("Moderate — if current stability maintained").tag("moderate")
                            Text("High — when known risk pattern re-emerges").tag("high")
                        }
                        .pickerStyle(.menu)
                    }
                }
                .backgroundStyle(Color.blue.opacity(0.05))

                // Conditions that Increase Likelihood
                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Likelihood Increases If...").font(.subheadline.weight(.semibold)).foregroundColor(.orange)

                        if !generateLikelihoodConditionsText().isEmpty {
                            Text(generateLikelihoodConditionsText())
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }

                        DisclosureGroup("Select Indicators") {
                            VStack(alignment: .leading, spacing: 4) {
                                Toggle("Medication adherence lapses", isOn: $formData.condMedLapse)
                                Toggle("Interpersonal conflict escalates", isOn: $formData.condConflict)
                                Toggle("Substance use resumes", isOn: $formData.condSubstance)
                                Toggle("Supervision reduces", isOn: $formData.condSupervisionReduces)
                                Toggle("Symptoms of mental disorder return", isOn: $formData.condSymptomsReturn)
                                Toggle("Support network weakens", isOn: $formData.condSupportLoss)
                                Toggle("Life stressors increase", isOn: $formData.condStressIncreases)
                            }
                            .font(.caption)
                        }
                    }
                }
                .backgroundStyle(Color.orange.opacity(0.05))

                // Overall likelihood (keep existing segmented picker)
                Text("Overall Assessment").font(.subheadline.weight(.semibold))
                Picker("Likelihood", selection: $formData.likelihoodLevel) {
                    Text("Not selected").tag("")
                    Text("Low").tag("low")
                    Text("Moderate").tag("moderate")
                    Text("High").tag("high")
                }
                .pickerStyle(.segmented)
            }

            // Additional notes
            FormTextEditor(label: "Additional Scenario Notes", text: $formData.scenarioLikelihood, minHeight: 60)
        }
    }

    // MARK: - Management Popup
    private var managementPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            // ═══════════════════════════════════════════════════════════════
            // 6. Risk-Enhancing Factors
            // ═══════════════════════════════════════════════════════════════
            VStack(alignment: .leading, spacing: 12) {
                Text("6. Risk-Enhancing Factors")
                    .font(.headline)
                    .foregroundColor(.blue)

                Text("What makes things worse?")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Clinical enhancers
                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Clinical Factors (C1-C5)").font(.subheadline.weight(.semibold)).foregroundColor(.red)
                        Toggle("Poor insight into illness or risk", isOn: $formData.enhPoorInsight)
                        Toggle("Active violent ideation or intent", isOn: $formData.enhViolentIdeation)
                        Toggle("Active symptoms (psychosis, mania)", isOn: $formData.enhActiveSymptoms)
                        Toggle("Affective or behavioural instability", isOn: $formData.enhInstability)
                        Toggle("Poor treatment or supervision response", isOn: $formData.enhPoorTreatment)
                    }
                    .font(.subheadline)
                }
                .backgroundStyle(Color.red.opacity(0.05))

                // Situational enhancers
                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Situational Factors (R1-R5)").font(.subheadline.weight(.semibold)).foregroundColor(.orange)
                        Toggle("Inadequate professional services/plans", isOn: $formData.enhPoorPlan)
                        Toggle("Unstable or unsupportive living", isOn: $formData.enhUnstableLiving)
                        Toggle("Lack of personal support", isOn: $formData.enhPoorSupport)
                        Toggle("Non-compliance with treatment/supervision", isOn: $formData.enhNonCompliance)
                        Toggle("Poor stress tolerance or coping", isOn: $formData.enhPoorCoping)
                    }
                    .font(.subheadline)
                }
                .backgroundStyle(Color.orange.opacity(0.05))

                // Other enhancers
                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Other Factors").font(.subheadline.weight(.semibold)).foregroundColor(.blue)
                        Toggle("Substance use", isOn: $formData.enhSubstance)
                        Toggle("Conflictual relationships", isOn: $formData.enhConflict)
                        Toggle("Access to victims or triggers", isOn: $formData.enhAccessVictims)
                        Toggle("Stressful transitions", isOn: $formData.enhTransitions)
                        Toggle("Loss of supervision", isOn: $formData.enhLossSupervision)
                    }
                    .font(.subheadline)
                }
                .backgroundStyle(Color.blue.opacity(0.05))
            }

            Divider()

            // ═══════════════════════════════════════════════════════════════
            // 7. Protective Factors
            // ═══════════════════════════════════════════════════════════════
            VStack(alignment: .leading, spacing: 12) {
                Text("7. Protective Factors")
                    .font(.headline)
                    .foregroundColor(.blue)

                Text("Only include factors that operate in real life, not theoretical ones.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Strong protectors
                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Strong Protectors").font(.subheadline.weight(.semibold)).foregroundColor(.green)
                        Toggle("Sustained treatment adherence", isOn: $formData.protTreatmentAdherence)
                        Toggle("Structured supervision in place", isOn: $formData.protStructuredSupervision)
                        Toggle("Supportive, prosocial relationships", isOn: $formData.protSupportiveRelationships)
                        Toggle("Insight linked to behaviour change", isOn: $formData.protInsightLinked)
                        Toggle("Early help-seeking behaviour", isOn: $formData.protHelpSeeking)
                        Toggle("Restricted access to triggers/victims", isOn: $formData.protRestrictedAccess)
                        Toggle("Good response to medication", isOn: $formData.protMedicationResponse)
                    }
                    .font(.subheadline)
                }
                .backgroundStyle(Color.green.opacity(0.05))

                // Weak protectors
                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Weak/Conditional Protectors").font(.subheadline.weight(.semibold)).foregroundColor(.orange)
                        Toggle("Verbal motivation only (untested)", isOn: $formData.protVerbalMotivation)
                        Toggle("Untested coping skills", isOn: $formData.protUntestedCoping)
                        Toggle("Supports that may disengage under stress", isOn: $formData.protConditionalSupport)
                        Toggle("Externally motivated compliance only", isOn: $formData.protExternalMotivation)
                        Toggle("Stability dependent on environment", isOn: $formData.protSituationalStability)
                    }
                    .font(.subheadline)
                }
                .backgroundStyle(Color.orange.opacity(0.05))
            }

            Divider()

            // ═══════════════════════════════════════════════════════════════
            // 8. Monitoring Indicators
            // ═══════════════════════════════════════════════════════════════
            VStack(alignment: .leading, spacing: 12) {
                Text("8. Risk Monitoring Indicators")
                    .font(.headline)
                    .foregroundColor(.blue)

                Text("Early warning signs that risk is increasing.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Behavioural indicators
                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Behavioural Indicators").font(.subheadline.weight(.semibold)).foregroundColor(.red)
                        Toggle("Missed appointments", isOn: $formData.monMissedAppts)
                        Toggle("Medication refusal", isOn: $formData.monMedRefusal)
                        Toggle("Withdrawal from supports", isOn: $formData.monWithdrawal)
                        Toggle("Increased substance use", isOn: $formData.monSubstanceUse)
                        Toggle("Non-compliance with conditions", isOn: $formData.monNonCompliance)
                        Toggle("Rule-breaking behaviour", isOn: $formData.monRuleBreaking)
                    }
                    .font(.subheadline)
                }
                .backgroundStyle(Color.red.opacity(0.05))

                // Mental state indicators
                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Mental State Indicators").font(.subheadline.weight(.semibold)).foregroundColor(.orange)
                        Toggle("Sleep disturbance", isOn: $formData.monSleepDisturb)
                        Toggle("Rising paranoia or suspiciousness", isOn: $formData.monParanoia)
                        Toggle("Increasing irritability", isOn: $formData.monIrritability)
                        Toggle("Escalation in hostile language", isOn: $formData.monHostileLanguage)
                        Toggle("Fixation on grievances", isOn: $formData.monFixation)
                        Toggle("Increased agitation or restlessness", isOn: $formData.monAgitation)
                    }
                    .font(.subheadline)
                }
                .backgroundStyle(Color.orange.opacity(0.05))
            }

            Divider()

            // ═══════════════════════════════════════════════════════════════
            // 9. Risk Management Strategies (Treatment)
            // ═══════════════════════════════════════════════════════════════
            VStack(alignment: .leading, spacing: 12) {
                Text("9. Risk Management Strategies")
                    .font(.headline)
                    .foregroundColor(.blue)

                Text("What actually helps? Split into prevention, containment, and response strategies.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Preventative Strategies
                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Preventative Strategies").font(.subheadline.weight(.semibold)).foregroundColor(.green)

                        if !generatePreventionText().isEmpty {
                            Text(generatePreventionText())
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }

                        DisclosureGroup("Select Indicators") {
                            VStack(alignment: .leading, spacing: 4) {
                                Toggle("Medication adherence", isOn: $formData.mgmtMedAdherence)
                                Toggle("Regular clinical review", isOn: $formData.mgmtRegularReview)
                                Toggle("Structured daily routine", isOn: $formData.mgmtStructuredRoutine)
                                Toggle("Stress management interventions", isOn: $formData.mgmtStressManagement)
                                Toggle("Substance use controls / monitoring", isOn: $formData.mgmtSubstanceControls)
                                Toggle("Psychological therapy", isOn: $formData.mgmtTherapy)
                            }
                            .font(.caption)
                        }
                    }
                }
                .backgroundStyle(Color.green.opacity(0.05))

                // Containment Strategies
                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Containment Strategies").font(.subheadline.weight(.semibold)).foregroundColor(.orange)

                        if !generateContainmentText().isEmpty {
                            Text(generateContainmentText())
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }

                        DisclosureGroup("Select Indicators") {
                            VStack(alignment: .leading, spacing: 4) {
                                Toggle("Ongoing supervision", isOn: $formData.mgmtSupervision)
                                Toggle("Conditions / boundaries", isOn: $formData.mgmtConditions)
                                Toggle("Reduced access to triggers", isOn: $formData.mgmtReducedAccess)
                                Toggle("Supported accommodation", isOn: $formData.mgmtSupportedAccom)
                                Toggle("Curfew or time restrictions", isOn: $formData.mgmtCurfew)
                                Toggle("Geographic restrictions", isOn: $formData.mgmtGeographic)
                            }
                            .font(.caption)
                        }
                    }
                }
                .backgroundStyle(Color.orange.opacity(0.05))

                // Response Strategies
                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Response Strategies").font(.subheadline.weight(.semibold)).foregroundColor(.red)

                        if !generateResponseText().isEmpty {
                            Text(generateResponseText())
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }

                        DisclosureGroup("Select Indicators") {
                            VStack(alignment: .leading, spacing: 4) {
                                Toggle("Clear escalation pathways", isOn: $formData.mgmtEscalation)
                                Toggle("Crisis plan in place", isOn: $formData.mgmtCrisisPlan)
                                Toggle("Defined recall / admission thresholds", isOn: $formData.mgmtRecallThreshold)
                                Toggle("Out-of-hours response plan", isOn: $formData.mgmtOutOfHours)
                                Toggle("Police liaison protocol", isOn: $formData.mgmtPoliceProtocol)
                            }
                            .font(.caption)
                        }
                    }
                }
                .backgroundStyle(Color.red.opacity(0.05))
            }

            Divider()

            // ═══════════════════════════════════════════════════════════════
            // 10. Supervision Recommendations
            // ═══════════════════════════════════════════════════════════════
            VStack(alignment: .leading, spacing: 12) {
                Text("10. Supervision Recommendations")
                    .font(.headline)
                    .foregroundColor(.blue)

                Text("Be specific about level, frequency, who monitors what, and escalation triggers.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Supervision Level
                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Supervision Level").font(.subheadline.weight(.semibold)).foregroundColor(.blue)

                        Picker("Level", selection: $formData.supervisionLevel) {
                            Text("Not selected").tag("")
                            Text("Informal — voluntary engagement").tag("informal")
                            Text("Supported — structured community support").tag("supported")
                            Text("Conditional — with enforceable conditions").tag("conditional")
                            Text("Restricted — secure or hospital setting").tag("restricted")
                        }
                        .pickerStyle(.menu)
                    }
                }
                .backgroundStyle(Color.blue.opacity(0.05))

                // Contact Requirements
                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Contact Requirements").font(.subheadline.weight(.semibold)).foregroundColor(.green)

                        if !generateContactReqsText().isEmpty {
                            Text(generateContactReqsText())
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }

                        DisclosureGroup("Select Indicators") {
                            VStack(alignment: .leading, spacing: 4) {
                                Toggle("Regular face-to-face contact required", isOn: $formData.supFaceToFace)
                                Toggle("Medication adherence monitoring", isOn: $formData.supMedMonitoring)
                                Toggle("Urine screening for substances", isOn: $formData.supUrineScreening)
                                Toggle("Curfew checks", isOn: $formData.supCurfewChecks)
                                Toggle("Unannounced visits", isOn: $formData.supUnannounced)
                                Toggle("Regular phone check-ins", isOn: $formData.supPhoneCheckins)
                            }
                            .font(.caption)
                        }
                    }
                }
                .backgroundStyle(Color.green.opacity(0.05))

                // Escalation Triggers
                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Escalation Triggers").font(.subheadline.weight(.semibold)).foregroundColor(.red)

                        if !generateEscalationTriggersText().isEmpty {
                            Text(generateEscalationTriggersText())
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }

                        DisclosureGroup("Select Indicators") {
                            VStack(alignment: .leading, spacing: 4) {
                                Toggle("Engagement deteriorates", isOn: $formData.escEngagementDeteriorates)
                                Toggle("Non-compliance with conditions", isOn: $formData.escNonCompliance)
                                Toggle("Early warning signs emerge", isOn: $formData.escWarningSigns)
                                Toggle("Substance use relapse", isOn: $formData.escSubstanceRelapse)
                                Toggle("Mental state deterioration", isOn: $formData.escMentalState)
                                Toggle("Threats or aggressive behaviour", isOn: $formData.escThreats)
                            }
                            .font(.caption)
                        }
                    }
                }
                .backgroundStyle(Color.red.opacity(0.05))
            }

            Divider()

            // ═══════════════════════════════════════════════════════════════
            // 11. Victim Safety & Safeguarding Planning
            // ═══════════════════════════════════════════════════════════════
            VStack(alignment: .leading, spacing: 12) {
                Text("11. Victim Safety & Safeguarding Planning")
                    .font(.headline)
                    .foregroundColor(.blue)

                Text("This must be explicit, even if no named victim exists. Select applicable strategies.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // When There Is an Identified Victim
                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("When There Is an Identified Victim").font(.subheadline.weight(.semibold)).foregroundColor(.red)

                        if !generateNamedVictimText().isEmpty {
                            Text(generateNamedVictimText())
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }

                        DisclosureGroup("Select Indicators") {
                            VStack(alignment: .leading, spacing: 4) {
                                Toggle("Physical separation maintained", isOn: $formData.vicSeparation)
                                Toggle("No-contact conditions in place", isOn: $formData.vicNoContact)
                                Toggle("Third-party monitoring", isOn: $formData.vicThirdParty)
                                Toggle("Information sharing between agencies", isOn: $formData.vicInfoSharing)
                                Toggle("Victim informed of risk and release", isOn: $formData.vicVictimInformed)
                                Toggle("Exclusion zone in place", isOn: $formData.vicExclusionZone)
                            }
                            .font(.caption)
                        }
                    }
                }
                .backgroundStyle(Color.red.opacity(0.05))

                // When Victims Are Non-Specific
                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("When Victims Are Non-Specific").font(.subheadline.weight(.semibold)).foregroundColor(.orange)

                        if !generateGeneralSafetyText().isEmpty {
                            Text(generateGeneralSafetyText())
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }

                        DisclosureGroup("Select Indicators") {
                            VStack(alignment: .leading, spacing: 4) {
                                Toggle("Environmental controls", isOn: $formData.vicEnvControls)
                                Toggle("Staff safety planning", isOn: $formData.vicStaffSafety)
                                Toggle("Conflict avoidance strategies", isOn: $formData.vicConflictAvoid)
                                Toggle("De-escalation protocols", isOn: $formData.vicDeEscalation)
                                Toggle("Restricted access to vulnerable groups", isOn: $formData.vicRestrictedAccess)
                                Toggle("Public protection measures", isOn: $formData.vicPublicProtection)
                            }
                            .font(.caption)
                        }
                    }
                }
                .backgroundStyle(Color.orange.opacity(0.05))
            }
        }
    }

    // MARK: - Signature Popup
    private var signaturePopup: some View {
        VStack(alignment: .leading, spacing: 12) {
            FormDatePicker(label: "Signature Date", date: $formData.signatureDate, isRequired: true)
            InfoBox(text: "The form will be signed manually after printing.", icon: "pencil.and.outline", color: .gray)
        }
    }

    // MARK: - H7 Personality Disorder Popup (Specialized with PD types and trait checkboxes)
    private var h7PersonalityDisorderPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Item title
            Text(HCR20FormData.itemTitles["h7"] ?? "H7: Personality Disorder")
                .font(.headline)
                .foregroundColor(.blue)

            // Presence Rating
            VStack(alignment: .leading, spacing: 8) {
                Text("Presence:").font(.subheadline.weight(.semibold))
                HStack(spacing: 8) {
                    ForEach(HCR20PresenceRating.allCases) { rating in
                        Button {
                            formData.h7.presence = rating
                        } label: {
                            Text(rating.displayText)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(formData.h7.presence == rating ? presenceColor(rating) : Color(.systemGray5))
                                .foregroundColor(formData.h7.presence == rating ? .white : .primary)
                                .cornerRadius(8)
                        }
                    }
                }
            }

            // Relevance Rating
            VStack(alignment: .leading, spacing: 8) {
                Text("Relevance:").font(.subheadline.weight(.semibold))
                HStack(spacing: 8) {
                    ForEach(HCR20RelevanceRating.allCases) { rating in
                        Button {
                            formData.h7.relevance = rating
                        } label: {
                            Text(rating.rawValue)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(formData.h7.relevance == rating ? relevanceColor(rating) : Color(.systemGray5))
                                .foregroundColor(formData.h7.relevance == rating ? .white : .primary)
                                .cornerRadius(8)
                        }
                    }
                }
            }

            Divider()

            // ═══════════════════════════════════════════════════════════════
            // Personality Disorder Features Container
            // ═══════════════════════════════════════════════════════════════
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Personality Disorder Features")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.purple)

                    // Generated preview text (read-only, shows what checkboxes generate)
                    if !generateH7AllPDTraitsText().isEmpty {
                        Text(generateH7AllPDTraitsText())
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }

                    // Manual notes text editor
                    Text("Additional Notes:").font(.caption).foregroundColor(.secondary)
                    TextEditor(text: h7SubsectionBinding("Personality Disorder Features:"))
                        .frame(minHeight: 40)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)

                    // PD Type Buttons - Allow multiple to show traits
                    Text("Select PD Type to add traits:").font(.caption).foregroundColor(.secondary)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(["Dissocial", "EUPD-B", "EUPD-I", "Paranoid", "Schizoid", "Histrionic", "Anankastic", "Anxious", "Dependent"], id: \.self) { pdType in
                            Button {
                                formData.h7SelectedPDType = formData.h7SelectedPDType == pdType ? "" : pdType
                            } label: {
                                HStack(spacing: 4) {
                                    // Show checkmark if this PD type has any traits checked
                                    if h7HasCheckedTraits(for: pdType) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.caption2)
                                    }
                                    Text(pdType)
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity)
                                .background(formData.h7SelectedPDType == pdType ? pdTypeColor(pdType) : (h7HasCheckedTraits(for: pdType) ? pdTypeColor(pdType).opacity(0.3) : Color(.systemGray5)))
                                .foregroundColor(formData.h7SelectedPDType == pdType ? .white : (h7HasCheckedTraits(for: pdType) ? pdTypeColor(pdType) : .primary))
                                .cornerRadius(6)
                            }
                        }
                    }

                    // Show traits for selected PD type
                    if !formData.h7SelectedPDType.isEmpty {
                        h7TraitCheckboxes(for: formData.h7SelectedPDType)
                    }
                }
            }
            .backgroundStyle(Color.purple.opacity(0.05))

            // ═══════════════════════════════════════════════════════════════
            // Impact on Functioning Container
            // ═══════════════════════════════════════════════════════════════
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Impact on Functioning")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.orange)

                    // Generated preview text (read-only, shows what checkboxes generate)
                    if !generateH7ImpactText().isEmpty {
                        Text(generateH7ImpactText())
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }

                    // Manual notes text editor
                    Text("Additional Notes:").font(.caption).foregroundColor(.secondary)
                    TextEditor(text: h7SubsectionBinding("Impact on Functioning:"))
                        .frame(minHeight: 40)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)

                    // Impact checkboxes by category
                    DisclosureGroup("Relationships") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Difficulties maintaining intimate relationships", isOn: $formData.h7ImpactIntimate)
                            Toggle("Conflictual or estranged family relationships", isOn: $formData.h7ImpactFamily)
                            Toggle("Poor social relationships / isolation", isOn: $formData.h7ImpactSocial)
                            Toggle("Difficulties with professional relationships", isOn: $formData.h7ImpactProfessional)
                        }
                        .font(.caption)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.brown)

                    DisclosureGroup("Employment/Education") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Repeated job losses due to behaviour", isOn: $formData.h7ImpactJobLoss)
                            Toggle("Frequent workplace conflicts", isOn: $formData.h7ImpactWorkConflict)
                            Toggle("Significant underachievement", isOn: $formData.h7ImpactUnderachievement)
                        }
                        .font(.caption)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.brown)

                    DisclosureGroup("Treatment/Supervision") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Poor treatment engagement", isOn: $formData.h7ImpactPoorEngagement)
                            Toggle("Conflicts with clinical staff", isOn: $formData.h7ImpactStaffConflict)
                            Toggle("Non-compliance with supervision", isOn: $formData.h7ImpactNonCompliance)
                            Toggle("Manipulative behaviour in treatment", isOn: $formData.h7ImpactManipulation)
                        }
                        .font(.caption)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.brown)

                    DisclosureGroup("Violence Risk") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Pattern of aggressive behaviour", isOn: $formData.h7ImpactAggressionPattern)
                            Toggle("Instrumental/planned violence", isOn: $formData.h7ImpactInstrumental)
                            Toggle("Reactive/impulsive violence", isOn: $formData.h7ImpactReactive)
                            Toggle("Targeting of specific victim types", isOn: $formData.h7ImpactVictimTargeting)
                        }
                        .font(.caption)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.red)
                }
            }
            .backgroundStyle(Color.orange.opacity(0.05))

            // Imported Data
            if !formData.h7.importedEntries.isEmpty {
                ImportedDataSection(
                    title: "Imported Notes (\(formData.h7.importedEntries.count))",
                    entries: $formData.h7.importedEntries,
                    categoryKeywords: HCR20CategoryKeywords.h7
                )
            }
        }
    }

    // H7 Trait Checkboxes for each PD type
    @ViewBuilder
    private func h7TraitCheckboxes(for pdType: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(pdType) Traits (ICD-10)")
                .font(.caption.weight(.semibold))
                .foregroundColor(pdTypeColor(pdType))

            switch pdType {
            case "Dissocial":
                Toggle("Callous unconcern for feelings of others", isOn: $formData.h7DissocialUnconcern)
                Toggle("Gross and persistent irresponsibility", isOn: $formData.h7DissocialIrresponsibility)
                Toggle("Incapacity to maintain enduring relationships", isOn: $formData.h7DissocialIncapacityRelations)
                Toggle("Very low tolerance to frustration", isOn: $formData.h7DissocialLowFrustration)
                Toggle("Low threshold for discharge of aggression", isOn: $formData.h7DissocialAggression)
                Toggle("Incapacity to experience guilt", isOn: $formData.h7DissocialIncapacityGuilt)
                Toggle("Marked proneness to blame others", isOn: $formData.h7DissocialBlameOthers)
                Toggle("Plausible rationalisation for behaviour", isOn: $formData.h7DissocialRationalise)
            case "EUPD-B":
                Toggle("Frantic efforts to avoid abandonment", isOn: $formData.h7EupdBAbandonment)
                Toggle("Unstable and intense relationships", isOn: $formData.h7EupdBUnstableRelations)
                Toggle("Identity disturbance", isOn: $formData.h7EupdBIdentity)
                Toggle("Impulsivity in potentially damaging areas", isOn: $formData.h7EupdBImpulsivity)
                Toggle("Recurrent suicidal/self-harm behaviour", isOn: $formData.h7EupdBSuicidal)
                Toggle("Affective instability", isOn: $formData.h7EupdBAffective)
                Toggle("Chronic feelings of emptiness", isOn: $formData.h7EupdBEmptiness)
                Toggle("Inappropriate, intense anger", isOn: $formData.h7EupdBAnger)
                Toggle("Transient paranoia or dissociation", isOn: $formData.h7EupdBDissociation)
            case "EUPD-I":
                Toggle("Acts unexpectedly without considering consequences", isOn: $formData.h7EupdIActUnexpectedly)
                Toggle("Tendency to quarrelsome behaviour and conflicts", isOn: $formData.h7EupdIQuarrelsome)
                Toggle("Liability to outbursts of anger or violence", isOn: $formData.h7EupdIAngerOutbursts)
                Toggle("Difficulty maintaining actions without immediate reward", isOn: $formData.h7EupdINoPersistence)
                Toggle("Unstable and capricious mood", isOn: $formData.h7EupdIUnstableMood)
            case "Paranoid":
                Toggle("Suspects others are exploiting or harming", isOn: $formData.h7ParanoidSuspects)
                Toggle("Preoccupied with doubts about loyalty", isOn: $formData.h7ParanoidDoubtsLoyalty)
                Toggle("Reluctant to confide in others", isOn: $formData.h7ParanoidReluctantConfide)
                Toggle("Reads hidden demeaning meanings", isOn: $formData.h7ParanoidReadsThreats)
                Toggle("Persistently bears grudges", isOn: $formData.h7ParanoidBearsGrudges)
                Toggle("Perceives attacks on character", isOn: $formData.h7ParanoidPerceivesAttacks)
                Toggle("Recurrent suspicions about fidelity", isOn: $formData.h7ParanoidSuspiciousFidelity)
            case "Schizoid":
                Toggle("Few activities give pleasure", isOn: $formData.h7SchizoidNoPleasure)
                Toggle("Emotional coldness, detachment, flat affect", isOn: $formData.h7SchizoidCold)
                Toggle("Limited capacity to express warmth or anger", isOn: $formData.h7SchizoidLimitedWarmth)
                Toggle("Apparent indifference to praise or criticism", isOn: $formData.h7SchizoidIndifferent)
                Toggle("Little interest in sexual experiences", isOn: $formData.h7SchizoidLittleInterestSex)
                Toggle("Preference for solitary activities", isOn: $formData.h7SchizoidSolitary)
                Toggle("Excessive preoccupation with fantasy", isOn: $formData.h7SchizoidFantasy)
                Toggle("No close friends or confiding relationships", isOn: $formData.h7SchizoidNoConfidants)
                Toggle("Insensitivity to social norms", isOn: $formData.h7SchizoidInsensitive)
            case "Histrionic":
                Toggle("Discomfort when not centre of attention", isOn: $formData.h7HistrionicAttention)
                Toggle("Inappropriately seductive or provocative", isOn: $formData.h7HistrionicSeductive)
                Toggle("Rapidly shifting and shallow emotions", isOn: $formData.h7HistrionicShallowEmotion)
                Toggle("Uses appearance to draw attention", isOn: $formData.h7HistrionicAppearance)
                Toggle("Impressionistic speech lacking detail", isOn: $formData.h7HistrionicImpressionistic)
                Toggle("Self-dramatisation, theatricality", isOn: $formData.h7HistrionicDramatic)
                Toggle("Easily influenced by others", isOn: $formData.h7HistrionicSuggestible)
                Toggle("Considers relationships more intimate than they are", isOn: $formData.h7HistrionicIntimacy)
            case "Anankastic":
                Toggle("Excessive doubt and caution", isOn: $formData.h7AnankasticDoubt)
                Toggle("Preoccupation with details, rules, lists", isOn: $formData.h7AnankasticDetail)
                Toggle("Perfectionism that interferes with completion", isOn: $formData.h7AnankasticPerfectionism)
                Toggle("Excessive conscientiousness", isOn: $formData.h7AnankasticConscientious)
                Toggle("Preoccupation with productivity to exclusion of pleasure", isOn: $formData.h7AnankasticPleasure)
                Toggle("Excessive pedantry and adherence to convention", isOn: $formData.h7AnankasticPedantic)
                Toggle("Rigidity and stubbornness", isOn: $formData.h7AnankasticRigid)
                Toggle("Unreasonable insistence others do things their way", isOn: $formData.h7AnankasticInsistence)
            case "Anxious":
                Toggle("Persistent feelings of tension and apprehension", isOn: $formData.h7AnxiousTension)
                Toggle("Beliefs of social ineptness and inferiority", isOn: $formData.h7AnxiousInferior)
                Toggle("Excessive preoccupation with criticism or rejection", isOn: $formData.h7AnxiousCriticism)
                Toggle("Unwilling to become involved unless certain of being liked", isOn: $formData.h7AnxiousUnwilling)
                Toggle("Restrictions in lifestyle due to need for security", isOn: $formData.h7AnxiousRestricted)
                Toggle("Avoids activities involving significant interpersonal contact", isOn: $formData.h7AnxiousAvoidsActivities)
            case "Dependent":
                Toggle("Encourages or allows others to make decisions", isOn: $formData.h7DependentEncourage)
                Toggle("Subordinates own needs to those of others", isOn: $formData.h7DependentSubordinates)
                Toggle("Unwilling to make reasonable demands on others", isOn: $formData.h7DependentUnwillingDemands)
                Toggle("Feels uncomfortable or helpless when alone", isOn: $formData.h7DependentHelpless)
                Toggle("Preoccupied with fears of being left to care for self", isOn: $formData.h7DependentAbandonment)
                Toggle("Limited capacity to make everyday decisions", isOn: $formData.h7DependentLimitedCapacity)
            default:
                EmptyView()
            }
        }
        .font(.caption)
    }

    // Check if a PD type has any traits checked
    private func h7HasCheckedTraits(for pdType: String) -> Bool {
        switch pdType {
        case "Dissocial":
            return formData.h7DissocialUnconcern || formData.h7DissocialIrresponsibility ||
                   formData.h7DissocialIncapacityRelations || formData.h7DissocialLowFrustration ||
                   formData.h7DissocialAggression || formData.h7DissocialIncapacityGuilt ||
                   formData.h7DissocialBlameOthers || formData.h7DissocialRationalise
        case "EUPD-B":
            return formData.h7EupdBAbandonment || formData.h7EupdBUnstableRelations ||
                   formData.h7EupdBIdentity || formData.h7EupdBImpulsivity ||
                   formData.h7EupdBSuicidal || formData.h7EupdBAffective ||
                   formData.h7EupdBEmptiness || formData.h7EupdBAnger || formData.h7EupdBDissociation
        case "EUPD-I":
            return formData.h7EupdIActUnexpectedly || formData.h7EupdIQuarrelsome ||
                   formData.h7EupdIAngerOutbursts || formData.h7EupdINoPersistence || formData.h7EupdIUnstableMood
        case "Paranoid":
            return formData.h7ParanoidSuspects || formData.h7ParanoidDoubtsLoyalty ||
                   formData.h7ParanoidReluctantConfide || formData.h7ParanoidReadsThreats ||
                   formData.h7ParanoidBearsGrudges || formData.h7ParanoidPerceivesAttacks || formData.h7ParanoidSuspiciousFidelity
        case "Schizoid":
            return formData.h7SchizoidNoPleasure || formData.h7SchizoidCold ||
                   formData.h7SchizoidLimitedWarmth || formData.h7SchizoidIndifferent ||
                   formData.h7SchizoidLittleInterestSex || formData.h7SchizoidSolitary ||
                   formData.h7SchizoidFantasy || formData.h7SchizoidNoConfidants || formData.h7SchizoidInsensitive
        case "Histrionic":
            return formData.h7HistrionicAttention || formData.h7HistrionicSeductive ||
                   formData.h7HistrionicShallowEmotion || formData.h7HistrionicAppearance ||
                   formData.h7HistrionicImpressionistic || formData.h7HistrionicDramatic ||
                   formData.h7HistrionicSuggestible || formData.h7HistrionicIntimacy
        case "Anankastic":
            return formData.h7AnankasticDoubt || formData.h7AnankasticDetail ||
                   formData.h7AnankasticPerfectionism || formData.h7AnankasticConscientious ||
                   formData.h7AnankasticPleasure || formData.h7AnankasticPedantic ||
                   formData.h7AnankasticRigid || formData.h7AnankasticInsistence
        case "Anxious":
            return formData.h7AnxiousTension || formData.h7AnxiousInferior ||
                   formData.h7AnxiousCriticism || formData.h7AnxiousUnwilling ||
                   formData.h7AnxiousRestricted || formData.h7AnxiousAvoidsActivities
        case "Dependent":
            return formData.h7DependentEncourage || formData.h7DependentSubordinates ||
                   formData.h7DependentUnwillingDemands || formData.h7DependentHelpless ||
                   formData.h7DependentAbandonment || formData.h7DependentLimitedCapacity
        default:
            return false
        }
    }

    private func pdTypeColor(_ pdType: String) -> Color {
        switch pdType {
        case "Dissocial": return .red
        case "EUPD-B": return .orange
        case "EUPD-I": return Color(red: 0.96, green: 0.62, blue: 0.04) // amber
        case "Paranoid": return .green
        case "Schizoid": return .cyan
        case "Histrionic": return .pink
        case "Anankastic": return .indigo
        case "Anxious": return .teal
        case "Dependent": return Color(red: 0.39, green: 0.40, blue: 0.95) // indigo-ish
        default: return .gray
        }
    }

    // MARK: - H8 Traumatic Experiences Popup
    private var h8TraumaticExperiencesPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(HCR20FormData.itemTitles["h8"] ?? "H8: Traumatic Experiences")
                .font(.headline)
                .foregroundColor(.blue)

            // Presence & Relevance (same pattern)
            VStack(alignment: .leading, spacing: 8) {
                Text("Presence:").font(.subheadline.weight(.semibold))
                HStack(spacing: 8) {
                    ForEach(HCR20PresenceRating.allCases) { rating in
                        Button { formData.h8.presence = rating } label: {
                            Text(rating.displayText)
                                .font(.caption).fontWeight(.medium)
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(formData.h8.presence == rating ? presenceColor(rating) : Color(.systemGray5))
                                .foregroundColor(formData.h8.presence == rating ? .white : .primary)
                                .cornerRadius(8)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Relevance:").font(.subheadline.weight(.semibold))
                HStack(spacing: 8) {
                    ForEach(HCR20RelevanceRating.allCases) { rating in
                        Button { formData.h8.relevance = rating } label: {
                            Text(rating.rawValue)
                                .font(.caption).fontWeight(.medium)
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(formData.h8.relevance == rating ? relevanceColor(rating) : Color(.systemGray5))
                                .foregroundColor(formData.h8.relevance == rating ? .white : .primary)
                                .cornerRadius(8)
                        }
                    }
                }
            }

            Divider()

            // Childhood & Developmental Trauma
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Childhood & Developmental Trauma").font(.subheadline.weight(.semibold)).foregroundColor(Color(red: 0.6, green: 0.1, blue: 0.1))

                    // Preview of generated text from checkboxes
                    if !generateH8ChildhoodText().isEmpty {
                        Text(generateH8ChildhoodText())
                            .font(.caption).foregroundColor(.secondary)
                            .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6)).cornerRadius(8)
                    }

                    Text("Additional Notes:").font(.caption).foregroundColor(.secondary)
                    TextEditor(text: h8SubsectionBinding("Childhood Trauma:"))
                        .frame(minHeight: 40).padding(8).background(Color(.systemGray6)).cornerRadius(8)

                    DisclosureGroup("Abuse") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Physical abuse by caregivers", isOn: $formData.h8PhysicalAbuse)
                            Toggle("Sexual abuse (any perpetrator)", isOn: $formData.h8SexualAbuseChild)
                            Toggle("Emotional/psychological abuse", isOn: $formData.h8EmotionalAbuse)
                            Toggle("Witnessed domestic violence in home", isOn: $formData.h8WitnessedDV)
                        }.font(.caption)
                    }.font(.caption.weight(.semibold)).foregroundColor(.red)

                    DisclosureGroup("Neglect & Deprivation") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Emotional neglect", isOn: $formData.h8EmotionalNeglect)
                            Toggle("Physical neglect", isOn: $formData.h8PhysicalNeglect)
                            Toggle("Inconsistent or absent caregiving", isOn: $formData.h8InconsistentCare)
                            Toggle("Institutional care / foster care instability", isOn: $formData.h8InstitutionalCare)
                            Toggle("Parental abandonment", isOn: $formData.h8ParentalAbandonment)
                        }.font(.caption)
                    }.font(.caption.weight(.semibold)).foregroundColor(.red)

                    DisclosureGroup("Adverse Upbringing") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Chaotic household environment", isOn: $formData.h8ChaoticHousehold)
                            Toggle("Parental substance misuse", isOn: $formData.h8ParentalSubstance)
                            Toggle("Parental mental illness", isOn: $formData.h8ParentalMentalIllness)
                            Toggle("Criminal or violent caregivers", isOn: $formData.h8CriminalCaregivers)
                            Toggle("Repeated placement breakdowns", isOn: $formData.h8PlacementBreakdowns)
                        }.font(.caption)
                    }.font(.caption.weight(.semibold)).foregroundColor(.red)
                }
            }.backgroundStyle(Color.red.opacity(0.05))

            // Adult Trauma
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Adult Trauma").font(.subheadline.weight(.semibold)).foregroundColor(.orange)

                    if !generateH8AdultText().isEmpty {
                        Text(generateH8AdultText())
                            .font(.caption).foregroundColor(.secondary)
                            .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6)).cornerRadius(8)
                    }

                    Text("Additional Notes:").font(.caption).foregroundColor(.secondary)
                    TextEditor(text: h8SubsectionBinding("Adult Trauma:"))
                        .frame(minHeight: 40).padding(8).background(Color(.systemGray6)).cornerRadius(8)

                    DisclosureGroup("Victimisation") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Assaults (street violence, domestic violence)", isOn: $formData.h8AdultAssault)
                            Toggle("Sexual assault / rape", isOn: $formData.h8SexualAssaultAdult)
                            Toggle("Robbery with violence", isOn: $formData.h8RobberyViolence)
                            Toggle("Stalking or coercive control", isOn: $formData.h8StalkingCoercion)
                        }.font(.caption)
                    }.font(.caption.weight(.semibold)).foregroundColor(.orange)

                    DisclosureGroup("Institutional/Systemic") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Prison violence", isOn: $formData.h8PrisonViolence)
                            Toggle("Segregation / prolonged isolation", isOn: $formData.h8SegregationIsolation)
                            Toggle("Victimisation in hospital or care", isOn: $formData.h8HospitalVictimisation)
                            Toggle("Bullying, harassment, exploitation", isOn: $formData.h8BullyingHarassment)
                        }.font(.caption)
                    }.font(.caption.weight(.semibold)).foregroundColor(.orange)

                    DisclosureGroup("Occupational") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Exposure to violence (security, military)", isOn: $formData.h8OccupationalViolence)
                            Toggle("Witnessing serious injury or death", isOn: $formData.h8WitnessedDeath)
                            Toggle("Threats to life", isOn: $formData.h8ThreatsToLife)
                        }.font(.caption)
                    }.font(.caption.weight(.semibold)).foregroundColor(.orange)
                }
            }.backgroundStyle(Color.orange.opacity(0.05))

            // Loss & Catastrophe
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Trauma Linked to Loss or Catastrophe").font(.subheadline.weight(.semibold)).foregroundColor(.blue)

                    if !generateH8LossText().isEmpty {
                        Text(generateH8LossText())
                            .font(.caption).foregroundColor(.secondary)
                            .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6)).cornerRadius(8)
                    }

                    Text("Additional Notes:").font(.caption).foregroundColor(.secondary)
                    TextEditor(text: h8SubsectionBinding("Loss/Catastrophe:"))
                        .frame(minHeight: 40).padding(8).background(Color(.systemGray6)).cornerRadius(8)

                    DisclosureGroup("Bereavement & Displacement") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Sudden or violent death of close others", isOn: $formData.h8ViolentDeath)
                            Toggle("Multiple bereavements", isOn: $formData.h8MultipleBereavements)
                            Toggle("War, displacement, torture", isOn: $formData.h8WarDisplacement)
                            Toggle("Forced migration / asylum-related trauma", isOn: $formData.h8ForcedMigration)
                            Toggle("Serious accidents (RTA, workplace)", isOn: $formData.h8SeriousAccidents)
                            Toggle("Natural or man-made disasters", isOn: $formData.h8Disasters)
                        }.font(.caption)
                    }.font(.caption.weight(.semibold)).foregroundColor(.blue)
                }
            }.backgroundStyle(Color.blue.opacity(0.05))

            // Psychological Sequelae
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Psychological Sequelae").font(.subheadline.weight(.semibold)).foregroundColor(.purple)

                    if !generateH8SequelaeText().isEmpty {
                        Text(generateH8SequelaeText())
                            .font(.caption).foregroundColor(.secondary)
                            .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6)).cornerRadius(8)
                    }

                    Text("Additional Notes:").font(.caption).foregroundColor(.secondary)
                    TextEditor(text: h8SubsectionBinding("Psychological Sequelae:"))
                        .frame(minHeight: 40).padding(8).background(Color(.systemGray6)).cornerRadius(8)

                    DisclosureGroup("Diagnoses/Symptoms") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("PTSD / Complex PTSD", isOn: $formData.h8PtsdCptsd)
                            Toggle("Dissociation", isOn: $formData.h8Dissociation)
                            Toggle("Hypervigilance", isOn: $formData.h8Hypervigilance)
                            Toggle("Emotional dysregulation", isOn: $formData.h8EmotionalDysregulation)
                            Toggle("Nightmares / flashbacks", isOn: $formData.h8NightmaresFlashbacks)
                            Toggle("Persistent anger or hostility", isOn: $formData.h8PersistentAnger)
                        }.font(.caption)
                    }.font(.caption.weight(.semibold)).foregroundColor(.purple)

                    DisclosureGroup("Behavioural Patterns") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Aggression when triggered", isOn: $formData.h8TriggeredAggression)
                            Toggle("Poor impulse control", isOn: $formData.h8PoorImpulseControl)
                            Toggle("Substance use as coping", isOn: $formData.h8SubstanceCoping)
                            Toggle("Interpersonal mistrust", isOn: $formData.h8InterpersonalMistrust)
                            Toggle("Reactivity to perceived threat", isOn: $formData.h8ThreatReactivity)
                        }.font(.caption)
                    }.font(.caption.weight(.semibold)).foregroundColor(.purple)
                }
            }.backgroundStyle(Color.purple.opacity(0.05))

            // Trauma Narratives
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Trauma Narratives").font(.subheadline.weight(.semibold)).foregroundColor(.green)

                    if !generateH8NarrativeText().isEmpty {
                        Text(generateH8NarrativeText())
                            .font(.caption).foregroundColor(.secondary)
                            .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6)).cornerRadius(8)
                    }

                    Text("Additional Notes:").font(.caption).foregroundColor(.secondary)
                    TextEditor(text: h8SubsectionBinding("Trauma Narratives:"))
                        .frame(minHeight: 40).padding(8).background(Color(.systemGray6)).cornerRadius(8)

                    DisclosureGroup("Grievance/Victim Identity") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("\"Everyone has always hurt me\"", isOn: $formData.h8EveryoneHurts)
                            Toggle("\"I had to fight to survive\"", isOn: $formData.h8FightSurvive)
                            Toggle("\"You can't trust anyone\"", isOn: $formData.h8CantTrust)
                            Toggle("\"I was treated unfairly / abused by systems\"", isOn: $formData.h8SystemAbuse)
                            Toggle("Strong grievance or victim identity", isOn: $formData.h8GrievanceIdentity)
                        }.font(.caption)
                    }.font(.caption.weight(.semibold)).foregroundColor(.green)
                }
            }.backgroundStyle(Color.green.opacity(0.05))

            // Imported Data
            if !formData.h8.importedEntries.isEmpty {
                ImportedDataSection(
                    title: "Imported Notes (\(formData.h8.importedEntries.count))",
                    entries: $formData.h8.importedEntries,
                    categoryKeywords: HCR20CategoryKeywords.h8
                )
            }
        }
    }

    // MARK: - H9 Violent Attitudes Popup
    private var h9ViolentAttitudesPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(HCR20FormData.itemTitles["h9"] ?? "H9: Violent Attitudes")
                .font(.headline)
                .foregroundColor(.blue)

            // Presence & Relevance
            VStack(alignment: .leading, spacing: 8) {
                Text("Presence:").font(.subheadline.weight(.semibold))
                HStack(spacing: 8) {
                    ForEach(HCR20PresenceRating.allCases) { rating in
                        Button { formData.h9.presence = rating } label: {
                            Text(rating.displayText).font(.caption).fontWeight(.medium)
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(formData.h9.presence == rating ? presenceColor(rating) : Color(.systemGray5))
                                .foregroundColor(formData.h9.presence == rating ? .white : .primary)
                                .cornerRadius(8)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Relevance:").font(.subheadline.weight(.semibold))
                HStack(spacing: 8) {
                    ForEach(HCR20RelevanceRating.allCases) { rating in
                        Button { formData.h9.relevance = rating } label: {
                            Text(rating.rawValue).font(.caption).fontWeight(.medium)
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(formData.h9.relevance == rating ? relevanceColor(rating) : Color(.systemGray5))
                                .foregroundColor(formData.h9.relevance == rating ? .white : .primary)
                                .cornerRadius(8)
                        }
                    }
                }
            }

            Divider()

            // Violent Attitudes
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Violent Attitudes").font(.subheadline.weight(.semibold)).foregroundColor(.red)

                    if !generateH9ViolentAttitudesText().isEmpty {
                        Text(generateH9ViolentAttitudesText())
                            .font(.caption).foregroundColor(.secondary)
                            .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6)).cornerRadius(8)
                    }

                    Text("Additional Notes:").font(.caption).foregroundColor(.secondary)
                    TextEditor(text: h9SubsectionBinding("Violent Attitudes:"))
                        .frame(minHeight: 40).padding(8).background(Color(.systemGray6)).cornerRadius(8)

                    DisclosureGroup("Justification/Endorsement") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Views violence as acceptable or justified", isOn: $formData.h9JustifiesViolence)
                            Toggle("Believes victim deserved or provoked violence", isOn: $formData.h9VictimDeserved)
                            Toggle("Claims to have had no choice but to be violent", isOn: $formData.h9NoChoice)
                            Toggle("Sees violence as effective problem-solving", isOn: $formData.h9ViolenceSolves)
                        }.font(.caption)
                    }.font(.caption.weight(.semibold)).foregroundColor(.red)

                    DisclosureGroup("Minimisation/Denial") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Minimises harm caused to victims", isOn: $formData.h9MinimisesHarm)
                            Toggle("Downplays seriousness of violent incidents", isOn: $formData.h9DownplaysSeverity)
                            Toggle("Denies violent intent despite evidence", isOn: $formData.h9DeniesIntent)
                        }.font(.caption)
                    }.font(.caption.weight(.semibold)).foregroundColor(.orange)

                    DisclosureGroup("Externalisation/Blame") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Blames victim for provoking violence", isOn: $formData.h9BlamesVictim)
                            Toggle("Blames staff, system, or circumstances", isOn: $formData.h9BlamesOthers)
                            Toggle("Attributes violence to external factors", isOn: $formData.h9ExternalLocus)
                        }.font(.caption)
                    }.font(.caption.weight(.semibold)).foregroundColor(.yellow)

                    DisclosureGroup("Grievance/Entitlement") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Expresses persistent sense of persecution", isOn: $formData.h9FeelsPersecuted)
                            Toggle("Believes entitled to respect through force", isOn: $formData.h9EntitledRespect)
                            Toggle("Maintains grudges against specific individuals", isOn: $formData.h9HoldsGrudges)
                        }.font(.caption)
                    }.font(.caption.weight(.semibold)).foregroundColor(.green)

                    DisclosureGroup("Lack of Remorse/Empathy") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Shows no remorse for violent behaviour", isOn: $formData.h9NoRemorse)
                            Toggle("Appears indifferent to victim suffering", isOn: $formData.h9IndifferentHarm)
                            Toggle("Dismisses impact of violence on others", isOn: $formData.h9DismissesImpact)
                        }.font(.caption)
                    }.font(.caption.weight(.semibold)).foregroundColor(.purple)
                }
            }.backgroundStyle(Color.red.opacity(0.05))

            // Antisocial Attitudes
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Antisocial Attitudes").font(.subheadline.weight(.semibold)).foregroundColor(.orange)

                    if !generateH9AntisocialAttitudesText().isEmpty {
                        Text(generateH9AntisocialAttitudesText())
                            .font(.caption).foregroundColor(.secondary)
                            .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6)).cornerRadius(8)
                    }

                    Text("Additional Notes:").font(.caption).foregroundColor(.secondary)
                    TextEditor(text: h9SubsectionBinding("Antisocial Attitudes:"))
                        .frame(minHeight: 40).padding(8).background(Color(.systemGray6)).cornerRadius(8)

                    DisclosureGroup("Criminal Thinking") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Believes rules or laws do not apply to them", isOn: $formData.h9RulesDontApply)
                            Toggle("Feels entitled to take what they want", isOn: $formData.h9EntitledTake)
                            Toggle("Views exploitation of others as acceptable", isOn: $formData.h9ExploitsOthers)
                        }.font(.caption)
                    }.font(.caption.weight(.semibold)).foregroundColor(.orange)

                    DisclosureGroup("Authority Hostility") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Expresses hostility toward authority figures", isOn: $formData.h9HostileAuthority)
                            Toggle("Views police, courts, or system as corrupt", isOn: $formData.h9SystemCorrupt)
                            Toggle("Believes staff deserve mistreatment", isOn: $formData.h9StaffDeserve)
                        }.font(.caption)
                    }.font(.caption.weight(.semibold)).foregroundColor(.brown)

                    DisclosureGroup("Callousness") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Demonstrates lack of empathy for others", isOn: $formData.h9LacksEmpathy)
                            Toggle("Indifferent to consequences for others", isOn: $formData.h9IndifferentConsequences)
                            Toggle("Views others as means to an end", isOn: $formData.h9UsesOthers)
                        }.font(.caption)
                    }.font(.caption.weight(.semibold)).foregroundColor(.brown)

                    DisclosureGroup("Treatment Resistance") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Rejects need for help or intervention", isOn: $formData.h9RejectsHelp)
                            Toggle("Shows only superficial compliance", isOn: $formData.h9SuperficialCompliance)
                            Toggle("Beliefs remain unchanged despite treatment", isOn: $formData.h9UnchangedBeliefs)
                        }.font(.caption)
                    }.font(.caption.weight(.semibold)).foregroundColor(.brown)
                }
            }.backgroundStyle(Color.orange.opacity(0.05))

            // Imported Data
            if !formData.h9.importedEntries.isEmpty {
                ImportedDataSection(
                    title: "Imported Notes (\(formData.h9.importedEntries.count))",
                    entries: $formData.h9.importedEntries,
                    categoryKeywords: HCR20CategoryKeywords.h9
                )
            }
        }
    }

    // MARK: - H10 Treatment Response Popup
    private var h10TreatmentResponsePopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(HCR20FormData.itemTitles["h10"] ?? "H10: Treatment/Supervision Response")
                .font(.headline)
                .foregroundColor(.blue)

            // Presence & Relevance
            VStack(alignment: .leading, spacing: 8) {
                Text("Presence:").font(.subheadline.weight(.semibold))
                HStack(spacing: 8) {
                    ForEach(HCR20PresenceRating.allCases) { rating in
                        Button { formData.h10.presence = rating } label: {
                            Text(rating.displayText).font(.caption).fontWeight(.medium)
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(formData.h10.presence == rating ? presenceColor(rating) : Color(.systemGray5))
                                .foregroundColor(formData.h10.presence == rating ? .white : .primary)
                                .cornerRadius(8)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Relevance:").font(.subheadline.weight(.semibold))
                HStack(spacing: 8) {
                    ForEach(HCR20RelevanceRating.allCases) { rating in
                        Button { formData.h10.relevance = rating } label: {
                            Text(rating.rawValue).font(.caption).fontWeight(.medium)
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(formData.h10.relevance == rating ? relevanceColor(rating) : Color(.systemGray5))
                                .foregroundColor(formData.h10.relevance == rating ? .white : .primary)
                                .cornerRadius(8)
                        }
                    }
                }
            }

            Divider()

            // 1. Medication Non-Adherence
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Medication Non-Adherence").font(.subheadline.weight(.semibold)).foregroundColor(.red)

                    if !generateH10MedicationText().isEmpty {
                        Text(generateH10MedicationText())
                            .font(.caption).foregroundColor(.secondary)
                            .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6)).cornerRadius(8)
                    }

                    Text("Additional Notes:").font(.caption).foregroundColor(.secondary)
                    TextEditor(text: h10SubsectionBinding("Medication:"))
                        .frame(minHeight: 40).padding(8).background(Color(.systemGray6)).cornerRadius(8)

                    DisclosureGroup("Indicators") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Non-compliant with medication", isOn: $formData.h10MedNoncompliant)
                            Toggle("Poor adherence to prescribed treatment", isOn: $formData.h10MedPoorAdherence)
                            Toggle("Frequently refuses medication", isOn: $formData.h10MedFrequentRefusal)
                            Toggle("Stopped medication without medical advice", isOn: $formData.h10MedStoppedWithout)
                            Toggle("Intermittent compliance", isOn: $formData.h10MedIntermittent)
                            Toggle("Refused depot injection", isOn: $formData.h10MedRefusedDepot)
                            Toggle("Self-discontinued medication", isOn: $formData.h10MedSelfDiscontinued)
                            Toggle("Repeated stopping/starting pattern", isOn: $formData.h10MedRepeatedStopping)
                        }.font(.caption)
                    }.font(.caption.weight(.semibold)).foregroundColor(.red)
                }
            }.backgroundStyle(Color.red.opacity(0.05))

            // 2. Disengagement From Services
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Disengagement From Services").font(.subheadline.weight(.semibold)).foregroundColor(.orange)

                    if !generateH10DisengagementText().isEmpty {
                        Text(generateH10DisengagementText())
                            .font(.caption).foregroundColor(.secondary)
                            .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6)).cornerRadius(8)
                    }

                    Text("Additional Notes:").font(.caption).foregroundColor(.secondary)
                    TextEditor(text: h10SubsectionBinding("Disengagement:"))
                        .frame(minHeight: 40).padding(8).background(Color(.systemGray6)).cornerRadius(8)

                    DisclosureGroup("Indicators") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("DNA appointments repeatedly", isOn: $formData.h10DisDna)
                            Toggle("Disengaged from services", isOn: $formData.h10DisDisengaged)
                            Toggle("Lost to follow-up", isOn: $formData.h10DisLostFollowup)
                            Toggle("Poor engagement with care team", isOn: $formData.h10DisPoorEngagement)
                            Toggle("Minimal engagement with MDT", isOn: $formData.h10DisMinimalMdt)
                            Toggle("Refuses community follow-up", isOn: $formData.h10DisRefusesCommunity)
                            Toggle("Uncontactable for prolonged periods", isOn: $formData.h10DisUncontactable)
                        }.font(.caption)
                    }.font(.caption.weight(.semibold)).foregroundColor(.orange)
                }
            }.backgroundStyle(Color.orange.opacity(0.05))

            // 3. Resistance/Hostility Toward Treatment
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Resistance or Hostility Toward Treatment").font(.subheadline.weight(.semibold)).foregroundColor(.yellow)

                    if !generateH10HostilityText().isEmpty {
                        Text(generateH10HostilityText())
                            .font(.caption).foregroundColor(.secondary)
                            .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6)).cornerRadius(8)
                    }

                    Text("Additional Notes:").font(.caption).foregroundColor(.secondary)
                    TextEditor(text: h10SubsectionBinding("Hostility:"))
                        .frame(minHeight: 40).padding(8).background(Color(.systemGray6)).cornerRadius(8)

                    DisclosureGroup("Indicators") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Refuses to engage with treatment", isOn: $formData.h10HosRefusesEngage)
                            Toggle("Hostile to staff", isOn: $formData.h10HosHostileStaff)
                            Toggle("Dismissive of treatment", isOn: $formData.h10HosDismissive)
                            Toggle("Lacks insight into need for treatment", isOn: $formData.h10HosNoInsight)
                            Toggle("Does not believe treatment is necessary", isOn: $formData.h10HosNotNecessary)
                            Toggle("Rejects psychological input", isOn: $formData.h10HosRejectsPsych)
                            Toggle("Uncooperative with ward rules", isOn: $formData.h10HosUncooperative)
                            Toggle("Oppositional behaviour toward clinicians", isOn: $formData.h10HosOppositional)
                        }.font(.caption)
                    }.font(.caption.weight(.semibold)).foregroundColor(.brown)
                }
            }.backgroundStyle(Color.yellow.opacity(0.05))

            // 4. Failure Under Supervision
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Failure Under Supervision").font(.subheadline.weight(.semibold)).foregroundColor(.green)

                    if !generateH10FailureText().isEmpty {
                        Text(generateH10FailureText())
                            .font(.caption).foregroundColor(.secondary)
                            .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6)).cornerRadius(8)
                    }

                    Text("Additional Notes:").font(.caption).foregroundColor(.secondary)
                    TextEditor(text: h10SubsectionBinding("Failure:"))
                        .frame(minHeight: 40).padding(8).background(Color(.systemGray6)).cornerRadius(8)

                    DisclosureGroup("Indicators") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Breach of conditions", isOn: $formData.h10FailBreachConditions)
                            Toggle("Breach of CTO", isOn: $formData.h10FailBreachCto)
                            Toggle("Breach of probation", isOn: $formData.h10FailBreachProbation)
                            Toggle("Recall to hospital", isOn: $formData.h10FailRecall)
                            Toggle("Returned to custody", isOn: $formData.h10FailReturnedCustody)
                            Toggle("Non-compliance with licence conditions", isOn: $formData.h10FailLicenceBreach)
                            Toggle("Failed community placement", isOn: $formData.h10FailCommunityPlacement)
                            Toggle("Absconded / AWOL", isOn: $formData.h10FailAbsconded)
                            Toggle("Repeated recalls or breaches", isOn: $formData.h10FailRepeatedRecalls)
                        }.font(.caption)
                    }.font(.caption.weight(.semibold)).foregroundColor(.green)
                }
            }.backgroundStyle(Color.green.opacity(0.05))

            // 5. Ineffective Past Interventions
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ineffective Past Interventions").font(.subheadline.weight(.semibold)).foregroundColor(.indigo)

                    if !generateH10IneffectiveText().isEmpty {
                        Text(generateH10IneffectiveText())
                            .font(.caption).foregroundColor(.secondary)
                            .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6)).cornerRadius(8)
                    }

                    Text("Additional Notes:").font(.caption).foregroundColor(.secondary)
                    TextEditor(text: h10SubsectionBinding("Ineffective:"))
                        .frame(minHeight: 40).padding(8).background(Color(.systemGray6)).cornerRadius(8)

                    DisclosureGroup("Indicators") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Little benefit from treatment", isOn: $formData.h10InefLittleBenefit)
                            Toggle("Limited response to interventions", isOn: $formData.h10InefLimitedResponse)
                            Toggle("No sustained improvement", isOn: $formData.h10InefNoSustained)
                            Toggle("Treatment gains not maintained", isOn: $formData.h10InefGainsNotMaintained)
                            Toggle("Relapse following discharge", isOn: $formData.h10InefRelapseDischarge)
                            Toggle("Risk escalated despite treatment", isOn: $formData.h10InefRiskEscalated)
                            Toggle("Repeated admissions despite support", isOn: $formData.h10InefRepeatedAdmissions)
                        }.font(.caption)
                    }.font(.caption.weight(.semibold)).foregroundColor(.indigo)
                }
            }.backgroundStyle(Color.indigo.opacity(0.05))

            // 6. Only Complies Under Compulsion
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Only Complies Under Compulsion").font(.subheadline.weight(.semibold)).foregroundColor(.purple)

                    if !generateH10CompulsionText().isEmpty {
                        Text(generateH10CompulsionText())
                            .font(.caption).foregroundColor(.secondary)
                            .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6)).cornerRadius(8)
                    }

                    Text("Additional Notes:").font(.caption).foregroundColor(.secondary)
                    TextEditor(text: h10SubsectionBinding("Compulsion:"))
                        .frame(minHeight: 40).padding(8).background(Color(.systemGray6)).cornerRadius(8)

                    DisclosureGroup("Indicators") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Only compliant under section", isOn: $formData.h10CompOnlyUnderSection)
                            Toggle("Engages only when detained", isOn: $formData.h10CompEngagesDetained)
                            Toggle("Deteriorates in community setting", isOn: $formData.h10CompDeterioratesCommunity)
                            Toggle("Compliance contingent on legal framework", isOn: $formData.h10CompLegalFramework)
                            Toggle("Responds only to enforced treatment", isOn: $formData.h10CompEnforcedOnly)
                        }.font(.caption)
                    }.font(.caption.weight(.semibold)).foregroundColor(.purple)
                }
            }.backgroundStyle(Color.purple.opacity(0.05))

            // Imported Data
            if !formData.h10.importedEntries.isEmpty {
                ImportedDataSection(
                    title: "Imported Notes (\(formData.h10.importedEntries.count))",
                    entries: $formData.h10.importedEntries,
                    categoryKeywords: HCR20CategoryKeywords.h10
                )
            }
        }
    }

    // MARK: - C1: Insight Popup
    private var c1InsightPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            Text("C1: Recent Problems with Insight")
                .font(.headline).foregroundColor(.blue)

            HStack {
                Image(systemName: "clock").foregroundColor(.orange)
                Text("Clinical items consider the last 6 months only")
                    .font(.caption).foregroundColor(.orange)
            }
            .padding(8).background(Color.orange.opacity(0.1)).cornerRadius(8)

            // Presence/Relevance
            c1PresenceRelevanceSection

            // 1. Insight into Disorder
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Insight into Disorder").font(.subheadline.weight(.semibold)).foregroundColor(.blue)

                    // Generated preview
                    if !generateC1DisorderText().isEmpty {
                        Text(generateC1DisorderText())
                            .font(.caption).foregroundColor(.secondary)
                            .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6)).cornerRadius(8)
                    }

                    Text("Additional Notes:").font(.caption).foregroundColor(.secondary)
                    TextEditor(text: c1SubsectionBinding("Insight into Mental Health:"))
                        .frame(minHeight: 40).padding(8).background(Color(.systemGray6)).cornerRadius(8)

                    DisclosureGroup("Indicators") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Denies illness / nothing wrong with me", isOn: $formData.c1DisDeniesIllness)
                            Toggle("Rejects diagnosis", isOn: $formData.c1DisRejectsDiagnosis)
                            Toggle("Attributes symptoms externally", isOn: $formData.c1DisExternalAttribution)
                            Toggle("Poor/limited insight documented", isOn: $formData.c1DisPoorInsight)
                            Toggle("Does not recognise relapse signs", isOn: $formData.c1DisNoRecogniseRelapse)
                            Toggle("Accepts diagnosis (protective)", isOn: $formData.c1DisAcceptsDiagnosis)
                            Toggle("Recognises symptoms as illness-related (protective)", isOn: $formData.c1DisRecognisesSymptoms)
                        }.font(.caption)
                    }.font(.caption.weight(.semibold)).foregroundColor(.blue)
                }
            }.backgroundStyle(Color.blue.opacity(0.05))

            // 2. Insight into Illness-Risk Link
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Insight into Illness-Risk Link").font(.subheadline.weight(.semibold)).foregroundColor(.red)

                    if !generateC1LinkText().isEmpty {
                        Text(generateC1LinkText())
                            .font(.caption).foregroundColor(.secondary)
                            .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6)).cornerRadius(8)
                    }

                    Text("Additional Notes:").font(.caption).foregroundColor(.secondary)
                    TextEditor(text: c1SubsectionBinding("Insight into Violence Risk:"))
                        .frame(minHeight: 40).padding(8).background(Color(.systemGray6)).cornerRadius(8)

                    DisclosureGroup("Indicators") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Denies link between illness and offending", isOn: $formData.c1LinkDeniesConnection)
                            Toggle("Minimises past violence", isOn: $formData.c1LinkMinimisesViolence)
                            Toggle("Externalises blame (they provoked me)", isOn: $formData.c1LinkExternalisesBlame)
                            Toggle("Lacks victim empathy", isOn: $formData.c1LinkLacksVictimEmpathy)
                            Toggle("Limited/no reflection on index offence", isOn: $formData.c1LinkNoReflection)
                            Toggle("Understands triggers (protective)", isOn: $formData.c1LinkUnderstandsTriggers)
                            Toggle("Acknowledges was unwell during offence (protective)", isOn: $formData.c1LinkAcknowledgesUnwell)
                        }.font(.caption)
                    }.font(.caption.weight(.semibold)).foregroundColor(.red)
                }
            }.backgroundStyle(Color.red.opacity(0.05))

            // 3. Insight into Treatment Need
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Insight into Need for Treatment").font(.subheadline.weight(.semibold)).foregroundColor(.green)

                    if !generateC1TreatmentText().isEmpty {
                        Text(generateC1TreatmentText())
                            .font(.caption).foregroundColor(.secondary)
                            .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6)).cornerRadius(8)
                    }

                    Text("Additional Notes:").font(.caption).foregroundColor(.secondary)
                    TextEditor(text: c1SubsectionBinding("Insight into Need for Treatment:"))
                        .frame(minHeight: 40).padding(8).background(Color(.systemGray6)).cornerRadius(8)

                    DisclosureGroup("Indicators") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Refuses treatment", isOn: $formData.c1TxRefusesTreatment)
                            Toggle("Non-concordant with medication", isOn: $formData.c1TxNonConcordant)
                            Toggle("Lacks understanding of need for treatment", isOn: $formData.c1TxLacksUnderstanding)
                            Toggle("Only accepts treatment under compulsion", isOn: $formData.c1TxOnlyUnderCompulsion)
                            Toggle("Recurrent disengagement from services", isOn: $formData.c1TxRecurrentDisengagement)
                            Toggle("Accepts medication (protective)", isOn: $formData.c1TxAcceptsMedication)
                            Toggle("Engages with MDT (protective)", isOn: $formData.c1TxEngagesMDT)
                            Toggle("Requests help when unwell (protective)", isOn: $formData.c1TxRequestsHelp)
                        }.font(.caption)
                    }.font(.caption.weight(.semibold)).foregroundColor(.green)
                }
            }.backgroundStyle(Color.green.opacity(0.05))

            // 4. Stability/Fluctuation of Insight
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Stability/Fluctuation of Insight").font(.subheadline.weight(.semibold)).foregroundColor(.yellow)

                    if !generateC1StabilityText().isEmpty {
                        Text(generateC1StabilityText())
                            .font(.caption).foregroundColor(.secondary)
                            .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6)).cornerRadius(8)
                    }

                    DisclosureGroup("Indicators") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Insight fluctuates", isOn: $formData.c1StabFluctuates)
                            Toggle("Insight improves with medication", isOn: $formData.c1StabImprovesMeds)
                            Toggle("Poor insight when acutely unwell", isOn: $formData.c1StabPoorWhenUnwell)
                            Toggle("Insight only present when well", isOn: $formData.c1StabOnlyWhenWell)
                            Toggle("Insight lost during relapse", isOn: $formData.c1StabLostRelapse)
                        }.font(.caption)
                    }.font(.caption.weight(.semibold)).foregroundColor(.orange)
                }
            }.backgroundStyle(Color.yellow.opacity(0.05))

            // 5. Behavioural Indicators
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Behavioural Indicators").font(.subheadline.weight(.semibold)).foregroundColor(.purple)

                    if !generateC1BehaviourText().isEmpty {
                        Text(generateC1BehaviourText())
                            .font(.caption).foregroundColor(.secondary)
                            .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6)).cornerRadius(8)
                    }

                    DisclosureGroup("Indicators") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Stops medication after discharge", isOn: $formData.c1BehStopsMeds)
                            Toggle("Misses appointments", isOn: $formData.c1BehMissesAppts)
                            Toggle("Rejects follow-up", isOn: $formData.c1BehRejectsFollowup)
                            Toggle("Repeatedly blames services", isOn: $formData.c1BehBlamesServices)
                            Toggle("Recurrent relapse after disengagement", isOn: $formData.c1BehRecurrentRelapse)
                            Toggle("Consistent engagement (protective)", isOn: $formData.c1BehConsistentEngagement)
                        }.font(.caption)
                    }.font(.caption.weight(.semibold)).foregroundColor(.purple)
                }
            }.backgroundStyle(Color.purple.opacity(0.05))

            // Imported Data
            if !formData.c1.importedEntries.isEmpty {
                ImportedDataSection(
                    title: "Imported Notes (\(formData.c1.importedEntries.count))",
                    entries: $formData.c1.importedEntries,
                    categoryKeywords: HCR20CategoryKeywords.c1
                )
            }
        }
    }

    // MARK: - C2: Violent Ideation Popup
    private var c2ViolentIdeationPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("C2: Recent Problems with Violent Ideation or Intent")
                .font(.headline).foregroundColor(.blue)

            HStack {
                Image(systemName: "clock").foregroundColor(.orange)
                Text("Clinical items consider the last 6 months only")
                    .font(.caption).foregroundColor(.orange)
            }
            .padding(8).background(Color.orange.opacity(0.1)).cornerRadius(8)

            c2PresenceRelevanceSection

            // 1. Explicit Violent Ideation
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Explicit Violent Ideation").font(.subheadline.weight(.semibold)).foregroundColor(.red)

                    if !generateC2ExplicitText().isEmpty {
                        Text(generateC2ExplicitText())
                            .font(.caption).foregroundColor(.secondary)
                            .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6)).cornerRadius(8)
                    }

                    Text("Additional Notes:").font(.caption).foregroundColor(.secondary)
                    TextEditor(text: c2SubsectionBinding("Violent Ideation:"))
                        .frame(minHeight: 40).padding(8).background(Color(.systemGray6)).cornerRadius(8)

                    DisclosureGroup("Indicators") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Thoughts of harming others", isOn: $formData.c2ExpThoughtsHarm)
                            Toggle("Violent thoughts documented", isOn: $formData.c2ExpViolentThoughts)
                            Toggle("Homicidal ideation", isOn: $formData.c2ExpHomicidalIdeation)
                            Toggle("Desire to assault someone", isOn: $formData.c2ExpDesireAssault)
                            Toggle("Fantasies about killing", isOn: $formData.c2ExpKillFantasies)
                            Toggle("Specific target identified", isOn: $formData.c2ExpSpecificTarget)
                        }.font(.caption)
                    }.font(.caption.weight(.semibold)).foregroundColor(.red)
                }
            }.backgroundStyle(Color.red.opacity(0.05))

            // 2. Conditional Violence
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Conditional Violence").font(.subheadline.weight(.semibold)).foregroundColor(.orange)

                    if !generateC2ConditionalText().isEmpty {
                        Text(generateC2ConditionalText())
                            .font(.caption).foregroundColor(.secondary)
                            .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6)).cornerRadius(8)
                    }

                    DisclosureGroup("Indicators") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("States will act 'if provoked'", isOn: $formData.c2CondIfProvoked)
                            Toggle("Claims violence for 'self-defence'", isOn: $formData.c2CondSelfDefence)
                            Toggle("Warns may 'snap' or lose control", isOn: $formData.c2CondSnap)
                            Toggle("States 'someone will get hurt'", isOn: $formData.c2CondSomeoneHurt)
                            Toggle("Says 'don't know what I'll do'", isOn: $formData.c2CondDontKnow)
                        }.font(.caption)
                    }.font(.caption.weight(.semibold)).foregroundColor(.orange)
                }
            }.backgroundStyle(Color.orange.opacity(0.05))

            // 3. Justification/Endorsement
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Justification/Endorsement of Violence").font(.subheadline.weight(.semibold)).foregroundColor(.purple)

                    if !generateC2JustifyText().isEmpty {
                        Text(generateC2JustifyText())
                            .font(.caption).foregroundColor(.secondary)
                            .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6)).cornerRadius(8)
                    }

                    DisclosureGroup("Indicators") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Believes victim 'deserved it'", isOn: $formData.c2JustDeservedIt)
                            Toggle("Claims was provoked", isOn: $formData.c2JustProvoked)
                            Toggle("Says 'had no choice'", isOn: $formData.c2JustNoChoice)
                            Toggle("States 'anyone would have done the same'", isOn: $formData.c2JustAnyoneSame)
                            Toggle("Views violence as necessary response", isOn: $formData.c2JustNecessary)
                        }.font(.caption)
                    }.font(.caption.weight(.semibold)).foregroundColor(.purple)
                }
            }.backgroundStyle(Color.purple.opacity(0.05))

            // 4. Ideation Linked to Mental State
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ideation Linked to Mental State").font(.subheadline.weight(.semibold)).foregroundColor(.blue)

                    if !generateC2SymptomsText().isEmpty {
                        Text(generateC2SymptomsText())
                            .font(.caption).foregroundColor(.secondary)
                            .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6)).cornerRadius(8)
                    }

                    DisclosureGroup("Indicators") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Command hallucinations to harm", isOn: $formData.c2SymCommandHallucinations)
                            Toggle("Voices telling to hurt others", isOn: $formData.c2SymVoicesHarm)
                            Toggle("Paranoid with retaliatory intent", isOn: $formData.c2SymParanoidRetaliation)
                            Toggle("Violent thoughts when psychotic", isOn: $formData.c2SymPsychoticViolent)
                            Toggle("Persecutory beliefs with violent response", isOn: $formData.c2SymPersecutoryBeliefs)
                        }.font(.caption)
                    }.font(.caption.weight(.semibold)).foregroundColor(.blue)
                }
            }.backgroundStyle(Color.blue.opacity(0.05))

            // 5. Aggressive Rumination
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Aggressive Rumination").font(.subheadline.weight(.semibold)).foregroundColor(.yellow)

                    if !generateC2RuminationText().isEmpty {
                        Text(generateC2RuminationText())
                            .font(.caption).foregroundColor(.secondary)
                            .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6)).cornerRadius(8)
                    }

                    DisclosureGroup("Indicators") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Persistent anger documented", isOn: $formData.c2RumPersistentAnger)
                            Toggle("Holds grievances", isOn: $formData.c2RumGrievance)
                            Toggle("Holds grudges", isOn: $formData.c2RumGrudges)
                            Toggle("Brooding behaviour", isOn: $formData.c2RumBrooding)
                            Toggle("Thoughts of revenge", isOn: $formData.c2RumRevenge)
                            Toggle("Escalating language/preoccupation", isOn: $formData.c2RumEscalating)
                        }.font(.caption)
                    }.font(.caption.weight(.semibold)).foregroundColor(.orange)
                }
            }.backgroundStyle(Color.yellow.opacity(0.05))

            // 6. Threats
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Threats").font(.subheadline.weight(.semibold)).foregroundColor(.green)

                    if !generateC2ThreatsText().isEmpty {
                        Text(generateC2ThreatsText())
                            .font(.caption).foregroundColor(.secondary)
                            .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6)).cornerRadius(8)
                    }

                    Text("Additional Notes:").font(.caption).foregroundColor(.secondary)
                    TextEditor(text: c2SubsectionBinding("Violent Intent:"))
                        .frame(minHeight: 40).padding(8).background(Color(.systemGray6)).cornerRadius(8)

                    DisclosureGroup("Indicators") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Verbal threats made", isOn: $formData.c2ThrVerbalThreats)
                            Toggle("Threatened staff", isOn: $formData.c2ThrThreatenedStaff)
                            Toggle("Threatened family members", isOn: $formData.c2ThrThreatenedFamily)
                            Toggle("Intimidating behaviour", isOn: $formData.c2ThrIntimidating)
                            Toggle("Aggressive statements", isOn: $formData.c2ThrAggressiveStatements)
                            Toggle("Threats but no follow-through (note pattern)", isOn: $formData.c2ThrNoFollowThrough)
                        }.font(.caption)
                    }.font(.caption.weight(.semibold)).foregroundColor(.green)
                }
            }.backgroundStyle(Color.green.opacity(0.05))

            // Imported Data
            if !formData.c2.importedEntries.isEmpty {
                ImportedDataSection(
                    title: "Imported Notes (\(formData.c2.importedEntries.count))",
                    entries: $formData.c2.importedEntries,
                    categoryKeywords: HCR20CategoryKeywords.c2
                )
            }
        }
    }

    // MARK: - C3: Symptoms Popup
    private var c3SymptomsPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("C3: Recent Problems with Symptoms of Major Mental Disorder")
                .font(.headline).foregroundColor(.blue)

            HStack {
                Image(systemName: "clock").foregroundColor(.orange)
                Text("Clinical items consider the last 6 months only")
                    .font(.caption).foregroundColor(.orange)
            }
            .padding(8).background(Color.orange.opacity(0.1)).cornerRadius(8)

            c3PresenceRelevanceSection

            // 1. Psychotic Symptoms
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Psychotic Symptoms").font(.subheadline.weight(.semibold)).foregroundColor(.red)

                    if !generateC3PsychoticText().isEmpty {
                        Text(generateC3PsychoticText())
                            .font(.caption).foregroundColor(.secondary)
                            .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6)).cornerRadius(8)
                    }

                    Text("Additional Notes:").font(.caption).foregroundColor(.secondary)
                    TextEditor(text: c3SubsectionBinding("Symptoms of Psychotic Disorders:"))
                        .frame(minHeight: 40).padding(8).background(Color(.systemGray6)).cornerRadius(8)

                    DisclosureGroup("Indicators") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Paranoid ideation", isOn: $formData.c3PsyParanoid)
                            Toggle("Persecutory delusions", isOn: $formData.c3PsyPersecutory)
                            Toggle("Command hallucinations", isOn: $formData.c3PsyCommandHallucinations)
                            Toggle("Hearing voices", isOn: $formData.c3PsyHearingVoices)
                            Toggle("Grandiose delusions", isOn: $formData.c3PsyGrandiose)
                            Toggle("Thought disorder", isOn: $formData.c3PsyThoughtDisorder)
                            Toggle("Actively psychotic currently", isOn: $formData.c3PsyActivelyPsychotic)
                        }.font(.caption)
                    }.font(.caption.weight(.semibold)).foregroundColor(.red)
                }
            }.backgroundStyle(Color.red.opacity(0.05))

            // 2. Mania/Hypomania
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Mania/Hypomania").font(.subheadline.weight(.semibold)).foregroundColor(.orange)

                    if !generateC3ManiaText().isEmpty {
                        Text(generateC3ManiaText())
                            .font(.caption).foregroundColor(.secondary)
                            .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6)).cornerRadius(8)
                    }

                    Text("Additional Notes:").font(.caption).foregroundColor(.secondary)
                    TextEditor(text: c3SubsectionBinding("Symptoms of Major Mood Disorder:"))
                        .frame(minHeight: 40).padding(8).background(Color(.systemGray6)).cornerRadius(8)

                    DisclosureGroup("Indicators") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Manic episode", isOn: $formData.c3ManManic)
                            Toggle("Hypomanic episode", isOn: $formData.c3ManHypomanic)
                            Toggle("Elevated mood", isOn: $formData.c3ManElevatedMood)
                            Toggle("Grandiosity", isOn: $formData.c3ManGrandiosity)
                            Toggle("Disinhibited behaviour", isOn: $formData.c3ManDisinhibited)
                            Toggle("Reduced need for sleep", isOn: $formData.c3ManReducedSleep)
                        }.font(.caption)
                    }.font(.caption.weight(.semibold)).foregroundColor(.orange)
                }
            }.backgroundStyle(Color.orange.opacity(0.05))

            // 3. Severe Depression
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Severe Depression").font(.subheadline.weight(.semibold)).foregroundColor(.blue)

                    if !generateC3DepressionText().isEmpty {
                        Text(generateC3DepressionText())
                            .font(.caption).foregroundColor(.secondary)
                            .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6)).cornerRadius(8)
                    }

                    DisclosureGroup("Indicators") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Severe depression", isOn: $formData.c3DepSevere)
                            Toggle("Agitated depression", isOn: $formData.c3DepAgitated)
                            Toggle("Hopelessness with anger", isOn: $formData.c3DepHopelessness)
                            Toggle("Nihilistic beliefs", isOn: $formData.c3DepNihilistic)
                            Toggle("Paranoid depression", isOn: $formData.c3DepParanoid)
                        }.font(.caption)
                    }.font(.caption.weight(.semibold)).foregroundColor(.blue)
                }
            }.backgroundStyle(Color.blue.opacity(0.05))

            // 4. Affective Instability
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Affective Instability").font(.subheadline.weight(.semibold)).foregroundColor(.purple)

                    if !generateC3AffectiveText().isEmpty {
                        Text(generateC3AffectiveText())
                            .font(.caption).foregroundColor(.secondary)
                            .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6)).cornerRadius(8)
                    }

                    DisclosureGroup("Indicators") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Affect labile", isOn: $formData.c3AffLabile)
                            Toggle("Easily provoked", isOn: $formData.c3AffEasilyProvoked)
                            Toggle("Low frustration tolerance", isOn: $formData.c3AffLowFrustration)
                            Toggle("Explosive anger", isOn: $formData.c3AffExplosive)
                            Toggle("Rapid mood shifts", isOn: $formData.c3AffRapidShifts)
                        }.font(.caption)
                    }.font(.caption.weight(.semibold)).foregroundColor(.purple)
                }
            }.backgroundStyle(Color.purple.opacity(0.05))

            // 5. Arousal/Anxiety States
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Arousal/Anxiety States").font(.subheadline.weight(.semibold)).foregroundColor(.yellow)

                    if !generateC3ArousalText().isEmpty {
                        Text(generateC3ArousalText())
                            .font(.caption).foregroundColor(.secondary)
                            .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6)).cornerRadius(8)
                    }

                    DisclosureGroup("Indicators") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Hypervigilant", isOn: $formData.c3ArsHypervigilant)
                            Toggle("On edge / tense", isOn: $formData.c3ArsOnEdge)
                            Toggle("Heightened threat perception", isOn: $formData.c3ArsThreatPerception)
                            Toggle("PTSD symptoms exacerbated", isOn: $formData.c3ArsPtsdExacerbated)
                        }.font(.caption)
                    }.font(.caption.weight(.semibold)).foregroundColor(.orange)
                }
            }.backgroundStyle(Color.yellow.opacity(0.05))

            // 6. Symptoms Linked to Violence Risk
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Symptoms Linked to Violence Risk").font(.subheadline.weight(.semibold)).foregroundColor(.green)

                    if !generateC3LinkedText().isEmpty {
                        Text(generateC3LinkedText())
                            .font(.caption).foregroundColor(.secondary)
                            .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6)).cornerRadius(8)
                    }

                    DisclosureGroup("Indicators") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Symptoms precede violence historically", isOn: $formData.c3LnkSymptomsPrecedeViolence)
                            Toggle("Delusions targeting specific individuals", isOn: $formData.c3LnkDelisionsTargeting)
                            Toggle("Mania-driven aggression", isOn: $formData.c3LnkManiaDriveAggression)
                            Toggle("Depression with anger/irritability", isOn: $formData.c3LnkDepressionAnger)
                            Toggle("Active symptoms linked to past violence", isOn: $formData.c3LnkActiveSymptoms)
                        }.font(.caption)
                    }.font(.caption.weight(.semibold)).foregroundColor(.green)
                }
            }.backgroundStyle(Color.green.opacity(0.05))

            // Imported Data
            if !formData.c3.importedEntries.isEmpty {
                ImportedDataSection(
                    title: "Imported Notes (\(formData.c3.importedEntries.count))",
                    entries: $formData.c3.importedEntries,
                    categoryKeywords: HCR20CategoryKeywords.c3
                )
            }
        }
    }

    // MARK: - C4: Instability Popup
    private var c4InstabilityPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("C4: Recent Problems with Instability")
                .font(.headline).foregroundColor(.blue)

            HStack {
                Image(systemName: "clock").foregroundColor(.orange)
                Text("Clinical items consider the last 6 months only")
                    .font(.caption).foregroundColor(.orange)
            }
            .padding(8).background(Color.orange.opacity(0.1)).cornerRadius(8)

            c4PresenceRelevanceSection

            // 1. Affective Instability
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Affective Instability").font(.subheadline.weight(.semibold)).foregroundColor(.red)

                    if !generateC4AffectiveText().isEmpty {
                        Text(generateC4AffectiveText())
                            .font(.caption).foregroundColor(.secondary)
                            .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6)).cornerRadius(8)
                    }

                    Text("Additional Notes:").font(.caption).foregroundColor(.secondary)
                    TextEditor(text: c4SubsectionBinding("Affective Instability:"))
                        .frame(minHeight: 40).padding(8).background(Color(.systemGray6)).cornerRadius(8)

                    DisclosureGroup("Indicators") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Mood swings", isOn: $formData.c4AffMoodSwings)
                            Toggle("Volatile mood", isOn: $formData.c4AffVolatile)
                            Toggle("Labile affect", isOn: $formData.c4AffLabile)
                            Toggle("Irritable", isOn: $formData.c4AffIrritable)
                            Toggle("Easily angered", isOn: $formData.c4AffEasilyAngered)
                            Toggle("Poor emotional regulation", isOn: $formData.c4AffEmotionalDysreg)
                        }.font(.caption)
                    }.font(.caption.weight(.semibold)).foregroundColor(.red)
                }
            }.backgroundStyle(Color.red.opacity(0.05))

            // 2. Behavioural Impulsivity
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Behavioural Impulsivity").font(.subheadline.weight(.semibold)).foregroundColor(.orange)

                    if !generateC4ImpulsiveText().isEmpty {
                        Text(generateC4ImpulsiveText())
                            .font(.caption).foregroundColor(.secondary)
                            .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6)).cornerRadius(8)
                    }

                    Text("Additional Notes:").font(.caption).foregroundColor(.secondary)
                    TextEditor(text: c4SubsectionBinding("Behavioural Instability:"))
                        .frame(minHeight: 40).padding(8).background(Color(.systemGray6)).cornerRadius(8)

                    DisclosureGroup("Indicators") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Acts without thinking", isOn: $formData.c4ImpActsWithoutThinking)
                            Toggle("Poor impulse control", isOn: $formData.c4ImpPoorImpulseControl)
                            Toggle("Unpredictable behaviour", isOn: $formData.c4ImpUnpredictable)
                            Toggle("Erratic behaviour", isOn: $formData.c4ImpErratic)
                            Toggle("Reckless behaviour", isOn: $formData.c4ImpReckless)
                        }.font(.caption)
                    }.font(.caption.weight(.semibold)).foregroundColor(.orange)
                }
            }.backgroundStyle(Color.orange.opacity(0.05))

            // 3. Anger Dyscontrol
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Anger Dyscontrol").font(.subheadline.weight(.semibold)).foregroundColor(.purple)

                    if !generateC4AngerText().isEmpty {
                        Text(generateC4AngerText())
                            .font(.caption).foregroundColor(.secondary)
                            .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6)).cornerRadius(8)
                    }

                    DisclosureGroup("Indicators") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Explosive outbursts", isOn: $formData.c4AngExplosive)
                            Toggle("Angry outbursts", isOn: $formData.c4AngAngryOutburst)
                            Toggle("Difficulty controlling temper", isOn: $formData.c4AngDifficultyTemper)
                            Toggle("Frequently agitated", isOn: $formData.c4AngAgitated)
                            Toggle("Hostile manner", isOn: $formData.c4AngHostile)
                        }.font(.caption)
                    }.font(.caption.weight(.semibold)).foregroundColor(.purple)
                }
            }.backgroundStyle(Color.purple.opacity(0.05))

            // 4. Environmental/Life Instability
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Environmental/Life Instability").font(.subheadline.weight(.semibold)).foregroundColor(.blue)

                    if !generateC4EnvironText().isEmpty {
                        Text(generateC4EnvironText())
                            .font(.caption).foregroundColor(.secondary)
                            .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6)).cornerRadius(8)
                    }

                    Text("Additional Notes:").font(.caption).foregroundColor(.secondary)
                    TextEditor(text: c4SubsectionBinding("Cognitive Instability:"))
                        .frame(minHeight: 40).padding(8).background(Color(.systemGray6)).cornerRadius(8)

                    DisclosureGroup("Indicators") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Relationship breakdown", isOn: $formData.c4EnvRelationshipBreakdown)
                            Toggle("Housing instability", isOn: $formData.c4EnvHousingInstability)
                            Toggle("Job loss / unemployment", isOn: $formData.c4EnvJobLoss)
                            Toggle("Financial crisis", isOn: $formData.c4EnvFinancialCrisis)
                            Toggle("Recent move / relocation", isOn: $formData.c4EnvRecentMove)
                        }.font(.caption)
                    }.font(.caption.weight(.semibold)).foregroundColor(.blue)
                }
            }.backgroundStyle(Color.blue.opacity(0.05))

            // 5. Stability Indicators (Protective)
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Stability Indicators (Protective)").font(.subheadline.weight(.semibold)).foregroundColor(.green)

                    if !generateC4StabilityText().isEmpty {
                        Text(generateC4StabilityText())
                            .font(.caption).foregroundColor(.secondary)
                            .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6)).cornerRadius(8)
                    }

                    DisclosureGroup("Indicators") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Good emotional regulation", isOn: $formData.c4StabGoodEmotionalReg)
                            Toggle("Stable mood", isOn: $formData.c4StabStableMood)
                            Toggle("Settled lifestyle", isOn: $formData.c4StabSettledLifestyle)
                            Toggle("Consistent daily routine", isOn: $formData.c4StabConsistentRoutine)
                        }.font(.caption)
                    }.font(.caption.weight(.semibold)).foregroundColor(.green)
                }
            }.backgroundStyle(Color.green.opacity(0.05))

            // Imported Data
            if !formData.c4.importedEntries.isEmpty {
                ImportedDataSection(
                    title: "Imported Notes (\(formData.c4.importedEntries.count))",
                    entries: $formData.c4.importedEntries,
                    categoryKeywords: HCR20CategoryKeywords.c4
                )
            }
        }
    }

    // MARK: - C5: Treatment Response Popup
    private var c5TreatmentResponsePopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("C5: Recent Problems with Treatment or Supervision Response")
                .font(.headline).foregroundColor(.blue)

            HStack {
                Image(systemName: "clock").foregroundColor(.orange)
                Text("Clinical items consider the last 6 months only")
                    .font(.caption).foregroundColor(.orange)
            }
            .padding(8).background(Color.orange.opacity(0.1)).cornerRadius(8)

            c5PresenceRelevanceSection

            // 1. Medication Adherence
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Medication Adherence").font(.subheadline.weight(.semibold)).foregroundColor(.red)

                    if !generateC5MedicationText().isEmpty {
                        Text(generateC5MedicationText())
                            .font(.caption).foregroundColor(.secondary)
                            .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6)).cornerRadius(8)
                    }

                    Text("Additional Notes:").font(.caption).foregroundColor(.secondary)
                    TextEditor(text: c5SubsectionBinding("Medication Compliance:"))
                        .frame(minHeight: 40).padding(8).background(Color(.systemGray6)).cornerRadius(8)

                    DisclosureGroup("Indicators") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Non-compliant with medication", isOn: $formData.c5MedNonCompliant)
                            Toggle("Stops medication after discharge", isOn: $formData.c5MedStopsDischarge)
                            Toggle("Refuses medication", isOn: $formData.c5MedRefuses)
                            Toggle("Selective/partial adherence", isOn: $formData.c5MedSelective)
                            Toggle("Covert non-compliance", isOn: $formData.c5MedCovertNonCompliance)
                            Toggle("Accepts medication (protective)", isOn: $formData.c5MedAccepts)
                            Toggle("Consistently takes medication (protective)", isOn: $formData.c5MedConsistent)
                        }.font(.caption)
                    }.font(.caption.weight(.semibold)).foregroundColor(.red)
                }
            }.backgroundStyle(Color.red.opacity(0.05))

            // 2. Engagement with Services
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Engagement with Services").font(.subheadline.weight(.semibold)).foregroundColor(.orange)

                    if !generateC5EngagementText().isEmpty {
                        Text(generateC5EngagementText())
                            .font(.caption).foregroundColor(.secondary)
                            .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6)).cornerRadius(8)
                    }

                    Text("Additional Notes:").font(.caption).foregroundColor(.secondary)
                    TextEditor(text: c5SubsectionBinding("Treatment Engagement:"))
                        .frame(minHeight: 40).padding(8).background(Color(.systemGray6)).cornerRadius(8)

                    DisclosureGroup("Indicators") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Disengaged from services", isOn: $formData.c5EngDisengaged)
                            Toggle("Misses appointments (DNA)", isOn: $formData.c5EngMissesAppts)
                            Toggle("Poor attendance", isOn: $formData.c5EngPoorAttendance)
                            Toggle("Avoids reviews", isOn: $formData.c5EngAvoidsReviews)
                            Toggle("Actively engages with services (protective)", isOn: $formData.c5EngActivelyEngages)
                        }.font(.caption)
                    }.font(.caption.weight(.semibold)).foregroundColor(.orange)
                }
            }.backgroundStyle(Color.orange.opacity(0.05))

            // 3. Compliance with Conditions
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Compliance with Conditions").font(.subheadline.weight(.semibold)).foregroundColor(.purple)

                    if !generateC5ComplianceText().isEmpty {
                        Text(generateC5ComplianceText())
                            .font(.caption).foregroundColor(.secondary)
                            .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6)).cornerRadius(8)
                    }

                    Text("Additional Notes:").font(.caption).foregroundColor(.secondary)
                    TextEditor(text: c5SubsectionBinding("Supervision Compliance:"))
                        .frame(minHeight: 40).padding(8).background(Color(.systemGray6)).cornerRadius(8)

                    DisclosureGroup("Indicators") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Breaches conditions", isOn: $formData.c5CmpBreaches)
                            Toggle("Has absconded", isOn: $formData.c5CmpAbsconded)
                            Toggle("Required recall", isOn: $formData.c5CmpRecalled)
                            Toggle("Only complies under coercion", isOn: $formData.c5CmpOnlyCoerced)
                            Toggle("Resists monitoring", isOn: $formData.c5CmpResistsMonitoring)
                            Toggle("Accepts conditions (protective)", isOn: $formData.c5CmpAcceptsConditions)
                        }.font(.caption)
                    }.font(.caption.weight(.semibold)).foregroundColor(.purple)
                }
            }.backgroundStyle(Color.purple.opacity(0.05))

            // 4. Pattern Over Time
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pattern Over Time").font(.subheadline.weight(.semibold)).foregroundColor(.blue)

                    if !generateC5PatternText().isEmpty {
                        Text(generateC5PatternText())
                            .font(.caption).foregroundColor(.secondary)
                            .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6)).cornerRadius(8)
                    }

                    DisclosureGroup("Indicators") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Repeated disengagement", isOn: $formData.c5PatRepeatedDisengage)
                            Toggle("History of non-compliance", isOn: $formData.c5PatHistoryNonCompliance)
                            Toggle("Cycle of engagement → relapse", isOn: $formData.c5PatCycleRelapse)
                            Toggle("Sustained adherence over time (protective)", isOn: $formData.c5PatSustainedAdherence)
                        }.font(.caption)
                    }.font(.caption.weight(.semibold)).foregroundColor(.blue)
                }
            }.backgroundStyle(Color.blue.opacity(0.05))

            // 5. Treatment Responsiveness
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Treatment Responsiveness").font(.subheadline.weight(.semibold)).foregroundColor(.green)

                    if !generateC5ResponseText().isEmpty {
                        Text(generateC5ResponseText())
                            .font(.caption).foregroundColor(.secondary)
                            .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6)).cornerRadius(8)
                    }

                    DisclosureGroup("Indicators") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Treatment resistant", isOn: $formData.c5RspTreatmentResistant)
                            Toggle("No improvement with treatment", isOn: $formData.c5RspNoImprovement)
                            Toggle("Responds well to treatment (protective)", isOn: $formData.c5RspRespondsWell)
                            Toggle("Benefits from psychological therapy (protective)", isOn: $formData.c5RspBenefitsTherapy)
                        }.font(.caption)
                    }.font(.caption.weight(.semibold)).foregroundColor(.green)
                }
            }.backgroundStyle(Color.green.opacity(0.05))

            // Imported Data
            if !formData.c5.importedEntries.isEmpty {
                ImportedDataSection(
                    title: "Imported Notes (\(formData.c5.importedEntries.count))",
                    entries: $formData.c5.importedEntries,
                    categoryKeywords: HCR20CategoryKeywords.c5
                )
            }
        }
    }

    // MARK: - C1-C5 Helper Properties
    private var c1PresenceRelevanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Presence:").font(.subheadline.weight(.semibold))
                ForEach(HCR20PresenceRating.allCases) { rating in
                    Button {
                        formData.c1.presence = rating
                    } label: {
                        Text(rating.displayText)
                            .font(.caption).fontWeight(.medium)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(formData.c1.presence == rating ? presenceColor(rating) : Color(.systemGray5))
                            .foregroundColor(formData.c1.presence == rating ? .white : .primary)
                            .cornerRadius(6)
                    }
                }
            }
            HStack(spacing: 8) {
                Text("Relevance:").font(.subheadline.weight(.semibold))
                ForEach(HCR20RelevanceRating.allCases) { rating in
                    Button {
                        formData.c1.relevance = rating
                    } label: {
                        Text(rating.rawValue)
                            .font(.caption).fontWeight(.medium)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(formData.c1.relevance == rating ? relevanceColor(rating) : Color(.systemGray5))
                            .foregroundColor(formData.c1.relevance == rating ? .white : .primary)
                            .cornerRadius(6)
                    }
                }
            }
        }
    }

    private var c2PresenceRelevanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Presence:").font(.subheadline.weight(.semibold))
                ForEach(HCR20PresenceRating.allCases) { rating in
                    Button {
                        formData.c2.presence = rating
                    } label: {
                        Text(rating.displayText)
                            .font(.caption).fontWeight(.medium)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(formData.c2.presence == rating ? presenceColor(rating) : Color(.systemGray5))
                            .foregroundColor(formData.c2.presence == rating ? .white : .primary)
                            .cornerRadius(6)
                    }
                }
            }
            HStack(spacing: 8) {
                Text("Relevance:").font(.subheadline.weight(.semibold))
                ForEach(HCR20RelevanceRating.allCases) { rating in
                    Button {
                        formData.c2.relevance = rating
                    } label: {
                        Text(rating.rawValue)
                            .font(.caption).fontWeight(.medium)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(formData.c2.relevance == rating ? relevanceColor(rating) : Color(.systemGray5))
                            .foregroundColor(formData.c2.relevance == rating ? .white : .primary)
                            .cornerRadius(6)
                    }
                }
            }
        }
    }

    private var c3PresenceRelevanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Presence:").font(.subheadline.weight(.semibold))
                ForEach(HCR20PresenceRating.allCases) { rating in
                    Button {
                        formData.c3.presence = rating
                    } label: {
                        Text(rating.displayText)
                            .font(.caption).fontWeight(.medium)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(formData.c3.presence == rating ? presenceColor(rating) : Color(.systemGray5))
                            .foregroundColor(formData.c3.presence == rating ? .white : .primary)
                            .cornerRadius(6)
                    }
                }
            }
            HStack(spacing: 8) {
                Text("Relevance:").font(.subheadline.weight(.semibold))
                ForEach(HCR20RelevanceRating.allCases) { rating in
                    Button {
                        formData.c3.relevance = rating
                    } label: {
                        Text(rating.rawValue)
                            .font(.caption).fontWeight(.medium)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(formData.c3.relevance == rating ? relevanceColor(rating) : Color(.systemGray5))
                            .foregroundColor(formData.c3.relevance == rating ? .white : .primary)
                            .cornerRadius(6)
                    }
                }
            }
        }
    }

    private var c4PresenceRelevanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Presence:").font(.subheadline.weight(.semibold))
                ForEach(HCR20PresenceRating.allCases) { rating in
                    Button {
                        formData.c4.presence = rating
                    } label: {
                        Text(rating.displayText)
                            .font(.caption).fontWeight(.medium)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(formData.c4.presence == rating ? presenceColor(rating) : Color(.systemGray5))
                            .foregroundColor(formData.c4.presence == rating ? .white : .primary)
                            .cornerRadius(6)
                    }
                }
            }
            HStack(spacing: 8) {
                Text("Relevance:").font(.subheadline.weight(.semibold))
                ForEach(HCR20RelevanceRating.allCases) { rating in
                    Button {
                        formData.c4.relevance = rating
                    } label: {
                        Text(rating.rawValue)
                            .font(.caption).fontWeight(.medium)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(formData.c4.relevance == rating ? relevanceColor(rating) : Color(.systemGray5))
                            .foregroundColor(formData.c4.relevance == rating ? .white : .primary)
                            .cornerRadius(6)
                    }
                }
            }
        }
    }

    private var c5PresenceRelevanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Presence:").font(.subheadline.weight(.semibold))
                ForEach(HCR20PresenceRating.allCases) { rating in
                    Button {
                        formData.c5.presence = rating
                    } label: {
                        Text(rating.displayText)
                            .font(.caption).fontWeight(.medium)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(formData.c5.presence == rating ? presenceColor(rating) : Color(.systemGray5))
                            .foregroundColor(formData.c5.presence == rating ? .white : .primary)
                            .cornerRadius(6)
                    }
                }
            }
            HStack(spacing: 8) {
                Text("Relevance:").font(.subheadline.weight(.semibold))
                ForEach(HCR20RelevanceRating.allCases) { rating in
                    Button {
                        formData.c5.relevance = rating
                    } label: {
                        Text(rating.rawValue)
                            .font(.caption).fontWeight(.medium)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(formData.c5.relevance == rating ? relevanceColor(rating) : Color(.systemGray5))
                            .foregroundColor(formData.c5.relevance == rating ? .white : .primary)
                            .cornerRadius(6)
                    }
                }
            }
        }
    }

    // MARK: - C1-C5 Subsection Bindings
    private func c1SubsectionBinding(_ key: String) -> Binding<String> {
        Binding(
            get: { formData.c1.subsectionTexts[key] ?? "" },
            set: { formData.c1.subsectionTexts[key] = $0 }
        )
    }

    private func c2SubsectionBinding(_ key: String) -> Binding<String> {
        Binding(
            get: { formData.c2.subsectionTexts[key] ?? "" },
            set: { formData.c2.subsectionTexts[key] = $0 }
        )
    }

    private func c3SubsectionBinding(_ key: String) -> Binding<String> {
        Binding(
            get: { formData.c3.subsectionTexts[key] ?? "" },
            set: { formData.c3.subsectionTexts[key] = $0 }
        )
    }

    private func c4SubsectionBinding(_ key: String) -> Binding<String> {
        Binding(
            get: { formData.c4.subsectionTexts[key] ?? "" },
            set: { formData.c4.subsectionTexts[key] = $0 }
        )
    }

    private func c5SubsectionBinding(_ key: String) -> Binding<String> {
        Binding(
            get: { formData.c5.subsectionTexts[key] ?? "" },
            set: { formData.c5.subsectionTexts[key] = $0 }
        )
    }

    // MARK: - C1 Text Generation Functions
    private func generateC1DisorderText() -> String {
        let gender = formData.patientGender
        let subj = gender == .male ? "He" : "She"
        var items: [String] = []
        if formData.c1DisDeniesIllness { items.append("denies illness") }
        if formData.c1DisRejectsDiagnosis { items.append("rejects diagnosis") }
        if formData.c1DisExternalAttribution { items.append("attributes symptoms externally") }
        if formData.c1DisPoorInsight { items.append("has poor/limited insight") }
        if formData.c1DisNoRecogniseRelapse { items.append("does not recognise relapse signs") }
        if formData.c1DisAcceptsDiagnosis { items.append("accepts diagnosis (protective)") }
        if formData.c1DisRecognisesSymptoms { items.append("recognises symptoms as illness-related (protective)") }
        if items.isEmpty { return "" }
        return "\(subj) \(formatList(items))."
    }

    private func generateC1LinkText() -> String {
        let gender = formData.patientGender
        let subj = gender == .male ? "He" : "She"
        var items: [String] = []
        if formData.c1LinkDeniesConnection { items.append("denies link between illness and offending") }
        if formData.c1LinkMinimisesViolence { items.append("minimises past violence") }
        if formData.c1LinkExternalisesBlame { items.append("externalises blame") }
        if formData.c1LinkLacksVictimEmpathy { items.append("lacks victim empathy") }
        if formData.c1LinkNoReflection { items.append("has limited reflection on index offence") }
        if formData.c1LinkUnderstandsTriggers { items.append("understands triggers (protective)") }
        if formData.c1LinkAcknowledgesUnwell { items.append("acknowledges was unwell during offence (protective)") }
        if items.isEmpty { return "" }
        return "\(subj) \(formatList(items))."
    }

    private func generateC1TreatmentText() -> String {
        let gender = formData.patientGender
        let subj = gender == .male ? "He" : "She"
        var items: [String] = []
        if formData.c1TxRefusesTreatment { items.append("refuses treatment") }
        if formData.c1TxNonConcordant { items.append("is non-concordant with medication") }
        if formData.c1TxLacksUnderstanding { items.append("lacks understanding of need for treatment") }
        if formData.c1TxOnlyUnderCompulsion { items.append("only accepts treatment under compulsion") }
        if formData.c1TxRecurrentDisengagement { items.append("has recurrent disengagement from services") }
        if formData.c1TxAcceptsMedication { items.append("accepts medication (protective)") }
        if formData.c1TxEngagesMDT { items.append("engages with MDT (protective)") }
        if formData.c1TxRequestsHelp { items.append("requests help when unwell (protective)") }
        if items.isEmpty { return "" }
        return "\(subj) \(formatList(items))."
    }

    private func generateC1StabilityText() -> String {
        let gender = formData.patientGender
        let poss = gender == .male ? "His" : "Her"
        var items: [String] = []
        if formData.c1StabFluctuates { items.append("insight fluctuates") }
        if formData.c1StabImprovesMeds { items.append("insight improves with medication") }
        if formData.c1StabPoorWhenUnwell { items.append("poor insight when acutely unwell") }
        if formData.c1StabOnlyWhenWell { items.append("insight only present when well") }
        if formData.c1StabLostRelapse { items.append("insight lost during relapse") }
        if items.isEmpty { return "" }
        return "\(poss) \(formatList(items))."
    }

    private func generateC1BehaviourText() -> String {
        let gender = formData.patientGender
        let subj = gender == .male ? "He" : "She"
        var items: [String] = []
        if formData.c1BehStopsMeds { items.append("stops medication after discharge") }
        if formData.c1BehMissesAppts { items.append("misses appointments") }
        if formData.c1BehRejectsFollowup { items.append("rejects follow-up") }
        if formData.c1BehBlamesServices { items.append("repeatedly blames services") }
        if formData.c1BehRecurrentRelapse { items.append("has recurrent relapse after disengagement") }
        if formData.c1BehConsistentEngagement { items.append("has consistent engagement (protective)") }
        if items.isEmpty { return "" }
        return "\(subj) \(formatList(items))."
    }

    // MARK: - C2 Text Generation Functions
    private func generateC2ExplicitText() -> String {
        let gender = formData.patientGender
        let subj = gender == .male ? "He" : "She"
        var items: [String] = []
        if formData.c2ExpThoughtsHarm { items.append("has thoughts of harming others") }
        if formData.c2ExpViolentThoughts { items.append("has violent thoughts documented") }
        if formData.c2ExpHomicidalIdeation { items.append("has homicidal ideation") }
        if formData.c2ExpDesireAssault { items.append("has desire to assault someone") }
        if formData.c2ExpKillFantasies { items.append("has fantasies about killing") }
        if formData.c2ExpSpecificTarget { items.append("has specific target identified") }
        if items.isEmpty { return "" }
        return "\(subj) \(formatList(items))."
    }

    private func generateC2ConditionalText() -> String {
        let gender = formData.patientGender
        let subj = gender == .male ? "He" : "She"
        var items: [String] = []
        if formData.c2CondIfProvoked { items.append("states will act 'if provoked'") }
        if formData.c2CondSelfDefence { items.append("claims violence for 'self-defence'") }
        if formData.c2CondSnap { items.append("warns may 'snap' or lose control") }
        if formData.c2CondSomeoneHurt { items.append("states 'someone will get hurt'") }
        if formData.c2CondDontKnow { items.append("says 'don't know what I'll do'") }
        if items.isEmpty { return "" }
        return "\(subj) \(formatList(items))."
    }

    private func generateC2JustifyText() -> String {
        let gender = formData.patientGender
        let subj = gender == .male ? "He" : "She"
        var items: [String] = []
        if formData.c2JustDeservedIt { items.append("believes victim 'deserved it'") }
        if formData.c2JustProvoked { items.append("claims was provoked") }
        if formData.c2JustNoChoice { items.append("says 'had no choice'") }
        if formData.c2JustAnyoneSame { items.append("states 'anyone would have done the same'") }
        if formData.c2JustNecessary { items.append("views violence as necessary response") }
        if items.isEmpty { return "" }
        return "\(subj) \(formatList(items))."
    }

    private func generateC2SymptomsText() -> String {
        let gender = formData.patientGender
        let subj = gender == .male ? "He" : "She"
        var items: [String] = []
        if formData.c2SymCommandHallucinations { items.append("has command hallucinations to harm") }
        if formData.c2SymVoicesHarm { items.append("has voices telling to hurt others") }
        if formData.c2SymParanoidRetaliation { items.append("is paranoid with retaliatory intent") }
        if formData.c2SymPsychoticViolent { items.append("has violent thoughts when psychotic") }
        if formData.c2SymPersecutoryBeliefs { items.append("has persecutory beliefs with violent response") }
        if items.isEmpty { return "" }
        return "\(subj) \(formatList(items))."
    }

    private func generateC2RuminationText() -> String {
        let gender = formData.patientGender
        let subj = gender == .male ? "He" : "She"
        var items: [String] = []
        if formData.c2RumPersistentAnger { items.append("has persistent anger") }
        if formData.c2RumGrievance { items.append("holds grievances") }
        if formData.c2RumGrudges { items.append("holds grudges") }
        if formData.c2RumBrooding { items.append("displays brooding behaviour") }
        if formData.c2RumRevenge { items.append("has thoughts of revenge") }
        if formData.c2RumEscalating { items.append("has escalating language/preoccupation") }
        if items.isEmpty { return "" }
        return "\(subj) \(formatList(items))."
    }

    private func generateC2ThreatsText() -> String {
        let gender = formData.patientGender
        let subj = gender == .male ? "He" : "She"
        var items: [String] = []
        if formData.c2ThrVerbalThreats { items.append("has made verbal threats") }
        if formData.c2ThrThreatenedStaff { items.append("has threatened staff") }
        if formData.c2ThrThreatenedFamily { items.append("has threatened family members") }
        if formData.c2ThrIntimidating { items.append("displays intimidating behaviour") }
        if formData.c2ThrAggressiveStatements { items.append("makes aggressive statements") }
        if formData.c2ThrNoFollowThrough { items.append("makes threats but no follow-through") }
        if items.isEmpty { return "" }
        return "\(subj) \(formatList(items))."
    }

    // MARK: - C3 Text Generation Functions
    private func generateC3PsychoticText() -> String {
        let gender = formData.patientGender
        let subj = gender == .male ? "He" : "She"
        var items: [String] = []
        if formData.c3PsyParanoid { items.append("has paranoid ideation") }
        if formData.c3PsyPersecutory { items.append("has persecutory delusions") }
        if formData.c3PsyCommandHallucinations { items.append("has command hallucinations") }
        if formData.c3PsyHearingVoices { items.append("is hearing voices") }
        if formData.c3PsyGrandiose { items.append("has grandiose delusions") }
        if formData.c3PsyThoughtDisorder { items.append("has thought disorder") }
        if formData.c3PsyActivelyPsychotic { items.append("is actively psychotic") }
        if items.isEmpty { return "" }
        return "\(subj) \(formatList(items))."
    }

    private func generateC3ManiaText() -> String {
        let gender = formData.patientGender
        let subj = gender == .male ? "He" : "She"
        var items: [String] = []
        if formData.c3ManManic { items.append("is in manic episode") }
        if formData.c3ManHypomanic { items.append("is in hypomanic episode") }
        if formData.c3ManElevatedMood { items.append("has elevated mood") }
        if formData.c3ManGrandiosity { items.append("displays grandiosity") }
        if formData.c3ManDisinhibited { items.append("has disinhibited behaviour") }
        if formData.c3ManReducedSleep { items.append("has reduced need for sleep") }
        if items.isEmpty { return "" }
        return "\(subj) \(formatList(items))."
    }

    private func generateC3DepressionText() -> String {
        let gender = formData.patientGender
        let subj = gender == .male ? "He" : "She"
        var items: [String] = []
        if formData.c3DepSevere { items.append("has severe depression") }
        if formData.c3DepAgitated { items.append("has agitated depression") }
        if formData.c3DepHopelessness { items.append("has hopelessness with anger") }
        if formData.c3DepNihilistic { items.append("has nihilistic beliefs") }
        if formData.c3DepParanoid { items.append("has paranoid depression") }
        if items.isEmpty { return "" }
        return "\(subj) \(formatList(items))."
    }

    private func generateC3AffectiveText() -> String {
        let gender = formData.patientGender
        let poss = gender == .male ? "His" : "Her"
        var items: [String] = []
        if formData.c3AffLabile { items.append("affect is labile") }
        if formData.c3AffEasilyProvoked { items.append("is easily provoked") }
        if formData.c3AffLowFrustration { items.append("has low frustration tolerance") }
        if formData.c3AffExplosive { items.append("has explosive anger") }
        if formData.c3AffRapidShifts { items.append("has rapid mood shifts") }
        if items.isEmpty { return "" }
        return "\(poss) \(formatList(items))."
    }

    private func generateC3ArousalText() -> String {
        let gender = formData.patientGender
        let subj = gender == .male ? "He" : "She"
        var items: [String] = []
        if formData.c3ArsHypervigilant { items.append("is hypervigilant") }
        if formData.c3ArsOnEdge { items.append("is on edge/tense") }
        if formData.c3ArsThreatPerception { items.append("has heightened threat perception") }
        if formData.c3ArsPtsdExacerbated { items.append("has PTSD symptoms exacerbated") }
        if items.isEmpty { return "" }
        return "\(subj) \(formatList(items))."
    }

    private func generateC3LinkedText() -> String {
        let gender = formData.patientGender
        let poss = gender == .male ? "His" : "Her"
        var items: [String] = []
        if formData.c3LnkSymptomsPrecedeViolence { items.append("symptoms precede violence historically") }
        if formData.c3LnkDelisionsTargeting { items.append("delusions target specific individuals") }
        if formData.c3LnkManiaDriveAggression { items.append("mania drives aggression") }
        if formData.c3LnkDepressionAnger { items.append("depression with anger/irritability") }
        if formData.c3LnkActiveSymptoms { items.append("active symptoms linked to past violence") }
        if items.isEmpty { return "" }
        return "\(poss) \(formatList(items))."
    }

    // MARK: - C4 Text Generation Functions
    private func generateC4AffectiveText() -> String {
        let gender = formData.patientGender
        let subj = gender == .male ? "He" : "She"
        var items: [String] = []
        if formData.c4AffMoodSwings { items.append("has mood swings") }
        if formData.c4AffVolatile { items.append("has volatile mood") }
        if formData.c4AffLabile { items.append("has labile affect") }
        if formData.c4AffIrritable { items.append("is irritable") }
        if formData.c4AffEasilyAngered { items.append("is easily angered") }
        if formData.c4AffEmotionalDysreg { items.append("has poor emotional regulation") }
        if items.isEmpty { return "" }
        return "\(subj) \(formatList(items))."
    }

    private func generateC4ImpulsiveText() -> String {
        let gender = formData.patientGender
        let subj = gender == .male ? "He" : "She"
        var items: [String] = []
        if formData.c4ImpActsWithoutThinking { items.append("acts without thinking") }
        if formData.c4ImpPoorImpulseControl { items.append("has poor impulse control") }
        if formData.c4ImpUnpredictable { items.append("is unpredictable") }
        if formData.c4ImpErratic { items.append("is erratic") }
        if formData.c4ImpReckless { items.append("is reckless") }
        if items.isEmpty { return "" }
        return "\(subj) \(formatList(items))."
    }

    private func generateC4AngerText() -> String {
        let gender = formData.patientGender
        let subj = gender == .male ? "He" : "She"
        var items: [String] = []
        if formData.c4AngExplosive { items.append("has explosive outbursts") }
        if formData.c4AngAngryOutburst { items.append("has angry outbursts") }
        if formData.c4AngDifficultyTemper { items.append("has difficulty controlling temper") }
        if formData.c4AngAgitated { items.append("is frequently agitated") }
        if formData.c4AngHostile { items.append("has hostile manner") }
        if items.isEmpty { return "" }
        return "\(subj) \(formatList(items))."
    }

    private func generateC4EnvironText() -> String {
        let gender = formData.patientGender
        let subj = gender == .male ? "He" : "She"
        var items: [String] = []
        if formData.c4EnvRelationshipBreakdown { items.append("has relationship breakdown") }
        if formData.c4EnvHousingInstability { items.append("has housing instability") }
        if formData.c4EnvJobLoss { items.append("has job loss/unemployment") }
        if formData.c4EnvFinancialCrisis { items.append("has financial crisis") }
        if formData.c4EnvRecentMove { items.append("has had recent move/relocation") }
        if items.isEmpty { return "" }
        return "\(subj) \(formatList(items))."
    }

    private func generateC4StabilityText() -> String {
        let gender = formData.patientGender
        let subj = gender == .male ? "He" : "She"
        var items: [String] = []
        if formData.c4StabGoodEmotionalReg { items.append("has good emotional regulation") }
        if formData.c4StabStableMood { items.append("has stable mood") }
        if formData.c4StabSettledLifestyle { items.append("has settled lifestyle") }
        if formData.c4StabConsistentRoutine { items.append("has consistent daily routine") }
        if items.isEmpty { return "" }
        return "\(subj) \(formatList(items)) (protective factors)."
    }

    // MARK: - C5 Text Generation Functions
    private func generateC5MedicationText() -> String {
        let gender = formData.patientGender
        let subj = gender == .male ? "He" : "She"
        var items: [String] = []
        if formData.c5MedNonCompliant { items.append("is non-compliant with medication") }
        if formData.c5MedStopsDischarge { items.append("stops medication after discharge") }
        if formData.c5MedRefuses { items.append("refuses medication") }
        if formData.c5MedSelective { items.append("has selective/partial adherence") }
        if formData.c5MedCovertNonCompliance { items.append("has covert non-compliance") }
        if formData.c5MedAccepts { items.append("accepts medication (protective)") }
        if formData.c5MedConsistent { items.append("consistently takes medication (protective)") }
        if items.isEmpty { return "" }
        return "\(subj) \(formatList(items))."
    }

    private func generateC5EngagementText() -> String {
        let gender = formData.patientGender
        let subj = gender == .male ? "He" : "She"
        var items: [String] = []
        if formData.c5EngDisengaged { items.append("is disengaged from services") }
        if formData.c5EngMissesAppts { items.append("misses appointments") }
        if formData.c5EngPoorAttendance { items.append("has poor attendance") }
        if formData.c5EngAvoidsReviews { items.append("avoids reviews") }
        if formData.c5EngActivelyEngages { items.append("actively engages with services (protective)") }
        if items.isEmpty { return "" }
        return "\(subj) \(formatList(items))."
    }

    private func generateC5ComplianceText() -> String {
        let gender = formData.patientGender
        let subj = gender == .male ? "He" : "She"
        var items: [String] = []
        if formData.c5CmpBreaches { items.append("breaches conditions") }
        if formData.c5CmpAbsconded { items.append("has absconded") }
        if formData.c5CmpRecalled { items.append("has required recall") }
        if formData.c5CmpOnlyCoerced { items.append("only complies under coercion") }
        if formData.c5CmpResistsMonitoring { items.append("resists monitoring") }
        if formData.c5CmpAcceptsConditions { items.append("accepts conditions (protective)") }
        if items.isEmpty { return "" }
        return "\(subj) \(formatList(items))."
    }

    private func generateC5PatternText() -> String {
        let gender = formData.patientGender
        let subj = gender == .male ? "He" : "She"
        var items: [String] = []
        if formData.c5PatRepeatedDisengage { items.append("has repeated disengagement") }
        if formData.c5PatHistoryNonCompliance { items.append("has history of non-compliance") }
        if formData.c5PatCycleRelapse { items.append("has cycle of engagement → relapse") }
        if formData.c5PatSustainedAdherence { items.append("has sustained adherence over time (protective)") }
        if items.isEmpty { return "" }
        return "\(subj) \(formatList(items))."
    }

    private func generateC5ResponseText() -> String {
        let gender = formData.patientGender
        let subj = gender == .male ? "He" : "She"
        var items: [String] = []
        if formData.c5RspTreatmentResistant { items.append("is treatment resistant") }
        if formData.c5RspNoImprovement { items.append("shows no improvement with treatment") }
        if formData.c5RspRespondsWell { items.append("responds well to treatment (protective)") }
        if formData.c5RspBenefitsTherapy { items.append("benefits from psychological therapy (protective)") }
        if items.isEmpty { return "" }
        return "\(subj) \(formatList(items))."
    }

    // MARK: - R1 Professional Services Popup
    private var r1ProfessionalServicesPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("R1: Future Problems with Professional Services and Plans")
                .font(.headline)
                .foregroundColor(.blue)

            // Future-oriented reminder
            HStack {
                Image(systemName: "arrow.right.circle")
                    .foregroundColor(.purple)
                Text("Risk Management items are future-oriented")
                    .font(.caption)
                    .foregroundColor(.purple)
            }
            .padding(8)
            .background(Color.purple.opacity(0.1))
            .cornerRadius(8)

            r1PresenceRelevanceSection

            // Plan Quality
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Plan Quality")
                        .font(.subheadline.weight(.semibold))

                    if !generateR1PlanText().isEmpty {
                        Text(generateR1PlanText())
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }

                    DisclosureGroup("Indicators") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Clear care plan in place", isOn: $formData.r1PlnClearPlan)
                            Toggle("Risk management plan documented", isOn: $formData.r1PlnRiskPlan)
                            Toggle("No clear aftercare plan", isOn: $formData.r1PlnNoPlan)
                            Toggle("Discharge planning incomplete", isOn: $formData.r1PlnIncomplete)
                            Toggle("Generic/vague plan only", isOn: $formData.r1PlnGeneric)
                        }
                        .font(.caption)
                    }
                }
            }

            // Service Intensity & Adequacy
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Service Intensity & Adequacy")
                        .font(.subheadline.weight(.semibold))

                    if !generateR1ServiceText().isEmpty {
                        Text(generateR1ServiceText())
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }

                    DisclosureGroup("Indicators") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Services appropriate to risk level", isOn: $formData.r1SvcAppropriate)
                            Toggle("Insufficient support for risk level", isOn: $formData.r1SvcInsufficient)
                            Toggle("Limited community input planned", isOn: $formData.r1SvcLimited)
                            Toggle("Risk-service mismatch", isOn: $formData.r1SvcMismatch)
                        }
                        .font(.caption)
                    }
                }
            }

            // Transitions & Continuity
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Transitions & Continuity")
                        .font(.subheadline.weight(.semibold))

                    if !generateR1TransitionsText().isEmpty {
                        Text(generateR1TransitionsText())
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }

                    DisclosureGroup("Indicators") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Awaiting allocation", isOn: $formData.r1TrnAwaiting)
                            Toggle("On waiting list", isOn: $formData.r1TrnWaitingList)
                            Toggle("No confirmed follow-up", isOn: $formData.r1TrnNoFollowup)
                            Toggle("Gap in care likely", isOn: $formData.r1TrnGap)
                            Toggle("Timely follow-up arranged (protective)", isOn: $formData.r1TrnTimely)
                        }
                        .font(.caption)
                    }
                }
            }

            // Contingency Planning
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Contingency & Escalation Planning")
                        .font(.subheadline.weight(.semibold))

                    if !generateR1ContingencyText().isEmpty {
                        Text(generateR1ContingencyText())
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }

                    DisclosureGroup("Indicators") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Crisis plan in place", isOn: $formData.r1CntCrisisPlan)
                            Toggle("Early warning signs documented", isOn: $formData.r1CntWarningSigns)
                            Toggle("Clear escalation pathway", isOn: $formData.r1CntEscalation)
                            Toggle("No crisis plan", isOn: $formData.r1CntNoCrisis)
                            Toggle("Unclear escalation pathway", isOn: $formData.r1CntNoEscalation)
                        }
                        .font(.caption)
                    }
                }
            }

            // Imported data section
            if !formData.r1.importedEntries.isEmpty {
                ImportedDataSection(
                    title: "Imported Notes (\(formData.r1.importedEntries.count))",
                    entries: Binding(
                        get: { formData.r1.importedEntries },
                        set: { formData.r1.importedEntries = $0 }
                    ),
                    categoryKeywords: HCR20CategoryKeywords.keywordsFor(item: "r1")
                )
            }
        }
    }

    private var r1PresenceRelevanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Presence:")
                    .font(.subheadline.weight(.semibold))
                ForEach(HCR20PresenceRating.allCases) { rating in
                    Button {
                        formData.r1.presence = rating
                    } label: {
                        Text(rating.displayText)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(formData.r1.presence == rating ? presenceColor(rating) : Color(.systemGray5))
                            .foregroundColor(formData.r1.presence == rating ? .white : .primary)
                            .cornerRadius(6)
                    }
                }
            }
            HStack(spacing: 8) {
                Text("Relevance:")
                    .font(.subheadline.weight(.semibold))
                ForEach(HCR20RelevanceRating.allCases) { rating in
                    Button {
                        formData.r1.relevance = rating
                    } label: {
                        Text(rating.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(formData.r1.relevance == rating ? relevanceColor(rating) : Color(.systemGray5))
                            .foregroundColor(formData.r1.relevance == rating ? .white : .primary)
                            .cornerRadius(6)
                    }
                }
            }
        }
    }

    // MARK: - R2 Living Situation Popup
    private var r2LivingSituationPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("R2: Future Problems with Living Situation")
                .font(.headline)
                .foregroundColor(.blue)

            HStack {
                Image(systemName: "arrow.right.circle")
                    .foregroundColor(.purple)
                Text("Risk Management items are future-oriented")
                    .font(.caption)
                    .foregroundColor(.purple)
            }
            .padding(8)
            .background(Color.purple.opacity(0.1))
            .cornerRadius(8)

            r2PresenceRelevanceSection

            // Accommodation Stability
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Accommodation Stability")
                        .font(.subheadline.weight(.semibold))

                    if !generateR2AccomText().isEmpty {
                        Text(generateR2AccomText())
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }

                    DisclosureGroup("Indicators") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Unstable housing / NFA", isOn: $formData.r2AccomUnstable)
                            Toggle("Temporary accommodation", isOn: $formData.r2AccomTemporary)
                            Toggle("At risk of eviction", isOn: $formData.r2AccomEvictionRisk)
                            Toggle("Stable accommodation (protective)", isOn: $formData.r2AccomStable)
                        }
                        .font(.caption)
                    }
                }
            }

            // Who They Live With
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Who They Live With")
                        .font(.subheadline.weight(.semibold))

                    if !generateR2CohabText().isEmpty {
                        Text(generateR2CohabText())
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }

                    DisclosureGroup("Indicators") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Living with/near victim", isOn: $formData.r2CohabVictim)
                            Toggle("Conflictual family environment", isOn: $formData.r2CohabConflict)
                            Toggle("Living with substance-using peers", isOn: $formData.r2CohabSubstancePeers)
                            Toggle("Supportive household (protective)", isOn: $formData.r2CohabSupportive)
                        }
                        .font(.caption)
                    }
                }
            }

            // Supervision Level
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Supervision Level")
                        .font(.subheadline.weight(.semibold))

                    if !generateR2SuperText().isEmpty {
                        Text(generateR2SuperText())
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }

                    DisclosureGroup("Indicators") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Supported/staffed setting", isOn: $formData.r2SuperSupported)
                            Toggle("Completely unsupervised", isOn: $formData.r2SuperUnsupervised)
                            Toggle("Step-down without preparation", isOn: $formData.r2SuperStepDown)
                            Toggle("Deteriorates without support", isOn: $formData.r2SuperDeteriorates)
                        }
                        .font(.caption)
                    }
                }
            }

            // Substance Access
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Substance Access")
                        .font(.subheadline.weight(.semibold))

                    if !generateR2SubstText().isEmpty {
                        Text(generateR2SubstText())
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }

                    DisclosureGroup("Indicators") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Easy access to substances", isOn: $formData.r2SubstAccess)
                            Toggle("Substance-using peers nearby", isOn: $formData.r2SubstPeers)
                            Toggle("Substance-free environment (protective)", isOn: $formData.r2SubstFree)
                        }
                        .font(.caption)
                    }
                }
            }

            if !formData.r2.importedEntries.isEmpty {
                ImportedDataSection(
                    title: "Imported Notes (\(formData.r2.importedEntries.count))",
                    entries: Binding(
                        get: { formData.r2.importedEntries },
                        set: { formData.r2.importedEntries = $0 }
                    ),
                    categoryKeywords: HCR20CategoryKeywords.keywordsFor(item: "r2")
                )
            }
        }
    }

    private var r2PresenceRelevanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Presence:")
                    .font(.subheadline.weight(.semibold))
                ForEach(HCR20PresenceRating.allCases) { rating in
                    Button {
                        formData.r2.presence = rating
                    } label: {
                        Text(rating.displayText)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(formData.r2.presence == rating ? presenceColor(rating) : Color(.systemGray5))
                            .foregroundColor(formData.r2.presence == rating ? .white : .primary)
                            .cornerRadius(6)
                    }
                }
            }
            HStack(spacing: 8) {
                Text("Relevance:")
                    .font(.subheadline.weight(.semibold))
                ForEach(HCR20RelevanceRating.allCases) { rating in
                    Button {
                        formData.r2.relevance = rating
                    } label: {
                        Text(rating.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(formData.r2.relevance == rating ? relevanceColor(rating) : Color(.systemGray5))
                            .foregroundColor(formData.r2.relevance == rating ? .white : .primary)
                            .cornerRadius(6)
                    }
                }
            }
        }
    }

    // MARK: - R3 Personal Support Popup
    private var r3PersonalSupportPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("R3: Future Problems with Personal Support")
                .font(.headline)
                .foregroundColor(.blue)

            HStack {
                Image(systemName: "arrow.right.circle")
                    .foregroundColor(.purple)
                Text("Risk Management items are future-oriented")
                    .font(.caption)
                    .foregroundColor(.purple)
            }
            .padding(8)
            .background(Color.purple.opacity(0.1))
            .cornerRadius(8)

            r3PresenceRelevanceSection

            // Supportive Relationships
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Supportive Relationships")
                        .font(.subheadline.weight(.semibold))

                    if !generateR3SupportText().isEmpty {
                        Text(generateR3SupportText())
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }

                    DisclosureGroup("Indicators") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Supportive family", isOn: $formData.r3SupFamily)
                            Toggle("Supportive partner", isOn: $formData.r3SupPartner)
                            Toggle("Regular contact with supports", isOn: $formData.r3SupRegularContact)
                            Toggle("Support available in crisis", isOn: $formData.r3SupCrisisHelp)
                        }
                        .font(.caption)
                    }
                }
            }

            // Isolation/Weak Support
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Isolation/Weak Support")
                        .font(.subheadline.weight(.semibold))

                    if !generateR3IsolationText().isEmpty {
                        Text(generateR3IsolationText())
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }

                    DisclosureGroup("Indicators") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Limited social support", isOn: $formData.r3IsoLimited)
                            Toggle("Estranged from family", isOn: $formData.r3IsoEstranged)
                            Toggle("Lives alone with limited contact", isOn: $formData.r3IsoLivesAlone)
                            Toggle("Superficial/unreliable contacts only", isOn: $formData.r3IsoSuperficial)
                        }
                        .font(.caption)
                    }
                }
            }

            // Conflict Within Network
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Conflict Within Network")
                        .font(.subheadline.weight(.semibold))

                    if !generateR3ConflictText().isEmpty {
                        Text(generateR3ConflictText())
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }

                    DisclosureGroup("Indicators") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("High interpersonal conflict", isOn: $formData.r3ConInterpersonal)
                            Toggle("Volatile relationships", isOn: $formData.r3ConVolatile)
                            Toggle("Domestic conflict", isOn: $formData.r3ConDomestic)
                        }
                        .font(.caption)
                    }
                }
            }

            // Antisocial Peers
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Antisocial Peers")
                        .font(.subheadline.weight(.semibold))

                    if !generateR3PeersText().isEmpty {
                        Text(generateR3PeersText())
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }

                    DisclosureGroup("Indicators") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Mixes with antisocial peers", isOn: $formData.r3PeerAntisocial)
                            Toggle("Substance-using peers", isOn: $formData.r3PeerSubstance)
                            Toggle("Negative peer influence", isOn: $formData.r3PeerNegative)
                        }
                        .font(.caption)
                    }
                }
            }

            if !formData.r3.importedEntries.isEmpty {
                ImportedDataSection(
                    title: "Imported Notes (\(formData.r3.importedEntries.count))",
                    entries: Binding(
                        get: { formData.r3.importedEntries },
                        set: { formData.r3.importedEntries = $0 }
                    ),
                    categoryKeywords: HCR20CategoryKeywords.keywordsFor(item: "r3")
                )
            }
        }
    }

    private var r3PresenceRelevanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Presence:")
                    .font(.subheadline.weight(.semibold))
                ForEach(HCR20PresenceRating.allCases) { rating in
                    Button {
                        formData.r3.presence = rating
                    } label: {
                        Text(rating.displayText)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(formData.r3.presence == rating ? presenceColor(rating) : Color(.systemGray5))
                            .foregroundColor(formData.r3.presence == rating ? .white : .primary)
                            .cornerRadius(6)
                    }
                }
            }
            HStack(spacing: 8) {
                Text("Relevance:")
                    .font(.subheadline.weight(.semibold))
                ForEach(HCR20RelevanceRating.allCases) { rating in
                    Button {
                        formData.r3.relevance = rating
                    } label: {
                        Text(rating.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(formData.r3.relevance == rating ? relevanceColor(rating) : Color(.systemGray5))
                            .foregroundColor(formData.r3.relevance == rating ? .white : .primary)
                            .cornerRadius(6)
                    }
                }
            }
        }
    }

    // MARK: - R4 Treatment/Supervision Compliance Popup
    private var r4TreatmentCompliancePopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("R4: Future Problems with Treatment/Supervision Response")
                .font(.headline)
                .foregroundColor(.blue)

            HStack {
                Image(systemName: "arrow.right.circle")
                    .foregroundColor(.purple)
                Text("Risk Management items are future-oriented")
                    .font(.caption)
                    .foregroundColor(.purple)
            }
            .padding(8)
            .background(Color.purple.opacity(0.1))
            .cornerRadius(8)

            r4PresenceRelevanceSection

            // Medication Adherence
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Medication Adherence")
                        .font(.subheadline.weight(.semibold))

                    if !generateR4MedText().isEmpty {
                        Text(generateR4MedText())
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }

                    DisclosureGroup("Indicators") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Likely to stop medication", isOn: $formData.r4MedLikelyStop)
                            Toggle("Likely to refuse medication", isOn: $formData.r4MedLikelyRefuse)
                            Toggle("History of medication non-compliance", isOn: $formData.r4MedHistoryNoncompliance)
                            Toggle("Likely to comply with medication (protective)", isOn: $formData.r4MedLikelyComply)
                        }
                        .font(.caption)
                    }
                }
            }

            // Attendance/Engagement
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Attendance/Engagement")
                        .font(.subheadline.weight(.semibold))

                    if !generateR4AttendText().isEmpty {
                        Text(generateR4AttendText())
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }

                    DisclosureGroup("Indicators") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Likely to miss appointments", isOn: $formData.r4AttLikelyMiss)
                            Toggle("Likely to disengage from services", isOn: $formData.r4AttLikelyDisengage)
                            Toggle("History of DNAs", isOn: $formData.r4AttHistoryDna)
                            Toggle("Likely to engage (protective)", isOn: $formData.r4AttLikelyEngage)
                        }
                        .font(.caption)
                    }
                }
            }

            // Supervision Compliance
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Supervision Compliance")
                        .font(.subheadline.weight(.semibold))

                    if !generateR4SuperText().isEmpty {
                        Text(generateR4SuperText())
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }

                    DisclosureGroup("Indicators") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Likely to breach conditions", isOn: $formData.r4SupLikelyBreach)
                            Toggle("History of breaching conditions", isOn: $formData.r4SupHistoryBreach)
                            Toggle("Only compliant under coercion", isOn: $formData.r4SupOnlyCoerced)
                            Toggle("Likely to accept supervision (protective)", isOn: $formData.r4SupLikelyAccept)
                        }
                        .font(.caption)
                    }
                }
            }

            // Response to Enforcement
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Response to Enforcement")
                        .font(.subheadline.weight(.semibold))

                    if !generateR4EnforceText().isEmpty {
                        Text(generateR4EnforceText())
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }

                    DisclosureGroup("Indicators") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Becomes hostile when supervised", isOn: $formData.r4EnfHostile)
                            Toggle("Resists monitoring", isOn: $formData.r4EnfResists)
                            Toggle("Escalates when challenged", isOn: $formData.r4EnfEscalates)
                            Toggle("Accepts enforcement constructively (protective)", isOn: $formData.r4EnfAccepts)
                        }
                        .font(.caption)
                    }
                }
            }

            if !formData.r4.importedEntries.isEmpty {
                ImportedDataSection(
                    title: "Imported Notes (\(formData.r4.importedEntries.count))",
                    entries: Binding(
                        get: { formData.r4.importedEntries },
                        set: { formData.r4.importedEntries = $0 }
                    ),
                    categoryKeywords: HCR20CategoryKeywords.keywordsFor(item: "r4")
                )
            }
        }
    }

    private var r4PresenceRelevanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Presence:")
                    .font(.subheadline.weight(.semibold))
                ForEach(HCR20PresenceRating.allCases) { rating in
                    Button {
                        formData.r4.presence = rating
                    } label: {
                        Text(rating.displayText)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(formData.r4.presence == rating ? presenceColor(rating) : Color(.systemGray5))
                            .foregroundColor(formData.r4.presence == rating ? .white : .primary)
                            .cornerRadius(6)
                    }
                }
            }
            HStack(spacing: 8) {
                Text("Relevance:")
                    .font(.subheadline.weight(.semibold))
                ForEach(HCR20RelevanceRating.allCases) { rating in
                    Button {
                        formData.r4.relevance = rating
                    } label: {
                        Text(rating.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(formData.r4.relevance == rating ? relevanceColor(rating) : Color(.systemGray5))
                            .foregroundColor(formData.r4.relevance == rating ? .white : .primary)
                            .cornerRadius(6)
                    }
                }
            }
        }
    }

    // MARK: - R5 Stress or Coping Popup
    private var r5StressCopingPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("R5: Future Problems with Stress or Coping")
                .font(.headline)
                .foregroundColor(.blue)

            HStack {
                Image(systemName: "arrow.right.circle")
                    .foregroundColor(.purple)
                Text("Risk Management items are future-oriented")
                    .font(.caption)
                    .foregroundColor(.purple)
            }
            .padding(8)
            .background(Color.purple.opacity(0.1))
            .cornerRadius(8)

            r5PresenceRelevanceSection

            // Anticipated Stressors
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Anticipated Stressors")
                        .font(.subheadline.weight(.semibold))

                    if !generateR5StressText().isEmpty {
                        Text(generateR5StressText())
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }

                    DisclosureGroup("Indicators") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Discharge/transition stress", isOn: $formData.r5StrDischarge)
                            Toggle("Housing uncertainty", isOn: $formData.r5StrHousing)
                            Toggle("Relationship strain", isOn: $formData.r5StrRelationship)
                            Toggle("Financial problems", isOn: $formData.r5StrFinancial)
                            Toggle("Reduced support planned", isOn: $formData.r5StrReducedSupport)
                        }
                        .font(.caption)
                    }
                }
            }

            // Historical Pattern Under Stress
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Historical Pattern Under Stress")
                        .font(.subheadline.weight(.semibold))

                    if !generateR5PatternText().isEmpty {
                        Text(generateR5PatternText())
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }

                    DisclosureGroup("Indicators") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Deteriorates under stress", isOn: $formData.r5PatDeteriorates)
                            Toggle("Struggles during transitions", isOn: $formData.r5PatStrugglesTransitions)
                            Toggle("Stress has preceded incidents", isOn: $formData.r5PatStressIncidents)
                        }
                        .font(.caption)
                    }
                }
            }

            // Coping Capacity
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Coping Capacity")
                        .font(.subheadline.weight(.semibold))

                    if !generateR5CopingText().isEmpty {
                        Text(generateR5CopingText())
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }

                    DisclosureGroup("Indicators") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Limited coping skills", isOn: $formData.r5CopLimited)
                            Toggle("Requires external containment", isOn: $formData.r5CopRequiresContainment)
                            Toggle("Uses maladaptive coping (anger, avoidance)", isOn: $formData.r5CopMaladaptive)
                            Toggle("Effective coping strategies (protective)", isOn: $formData.r5CopEffective)
                        }
                        .font(.caption)
                    }
                }
            }

            // Substance Use as Coping
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Substance Use as Coping")
                        .font(.subheadline.weight(.semibold))

                    if !generateR5SubstanceText().isEmpty {
                        Text(generateR5SubstanceText())
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }

                    DisclosureGroup("Indicators") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Substance use likely under stress", isOn: $formData.r5SubLikely)
                            Toggle("High relapse risk", isOn: $formData.r5SubRelapseRisk)
                            Toggle("History of stress-linked substance use", isOn: $formData.r5SubHistory)
                        }
                        .font(.caption)
                    }
                }
            }

            // Protective Factors
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Protective Factors")
                        .font(.subheadline.weight(.semibold))

                    if !generateR5ProtectiveText().isEmpty {
                        Text(generateR5ProtectiveText())
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }

                    DisclosureGroup("Indicators") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Demonstrated ability to cope", isOn: $formData.r5ProtCopingDemonstrated)
                            Toggle("Seeks help early", isOn: $formData.r5ProtHelpSeeking)
                            Toggle("Rehearsed crisis plan", isOn: $formData.r5ProtCrisisPlan)
                            Toggle("Stable supports available", isOn: $formData.r5ProtStableSupports)
                        }
                        .font(.caption)
                    }
                }
            }

            if !formData.r5.importedEntries.isEmpty {
                ImportedDataSection(
                    title: "Imported Notes (\(formData.r5.importedEntries.count))",
                    entries: Binding(
                        get: { formData.r5.importedEntries },
                        set: { formData.r5.importedEntries = $0 }
                    ),
                    categoryKeywords: HCR20CategoryKeywords.keywordsFor(item: "r5")
                )
            }
        }
    }

    private var r5PresenceRelevanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Presence:")
                    .font(.subheadline.weight(.semibold))
                ForEach(HCR20PresenceRating.allCases) { rating in
                    Button {
                        formData.r5.presence = rating
                    } label: {
                        Text(rating.displayText)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(formData.r5.presence == rating ? presenceColor(rating) : Color(.systemGray5))
                            .foregroundColor(formData.r5.presence == rating ? .white : .primary)
                            .cornerRadius(6)
                    }
                }
            }
            HStack(spacing: 8) {
                Text("Relevance:")
                    .font(.subheadline.weight(.semibold))
                ForEach(HCR20RelevanceRating.allCases) { rating in
                    Button {
                        formData.r5.relevance = rating
                    } label: {
                        Text(rating.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(formData.r5.relevance == rating ? relevanceColor(rating) : Color(.systemGray5))
                            .foregroundColor(formData.r5.relevance == rating ? .white : .primary)
                            .cornerRadius(6)
                    }
                }
            }
        }
    }

    // MARK: - R1-R5 Text Generation Functions

    // R1 Text Generation
    private func generateR1PlanText() -> String {
        var items: [String] = []
        if formData.r1PlnClearPlan { items.append("There is a clear care plan in place") }
        if formData.r1PlnRiskPlan { items.append("A risk management plan is documented") }
        if formData.r1PlnNoPlan { items.append("There is no clear aftercare plan") }
        if formData.r1PlnIncomplete { items.append("Discharge planning is incomplete") }
        if formData.r1PlnGeneric { items.append("Only a generic/vague plan exists") }
        if items.isEmpty { return "" }
        return items.joined(separator: ". ") + "."
    }

    private func generateR1ServiceText() -> String {
        var items: [String] = []
        if formData.r1SvcAppropriate { items.append("Services are appropriate to the risk level") }
        if formData.r1SvcInsufficient { items.append("There is insufficient support for the risk level") }
        if formData.r1SvcLimited { items.append("Limited community input is planned") }
        if formData.r1SvcMismatch { items.append("There is a mismatch between risk level and services") }
        if items.isEmpty { return "" }
        return items.joined(separator: ". ") + "."
    }

    private func generateR1TransitionsText() -> String {
        let gender = formData.patientGender
        let subj = gender == .male ? "He" : "She"
        var items: [String] = []
        if formData.r1TrnAwaiting { items.append("\(subj) is awaiting allocation") }
        if formData.r1TrnWaitingList { items.append("\(subj) is on a waiting list") }
        if formData.r1TrnNoFollowup { items.append("No confirmed follow-up is arranged") }
        if formData.r1TrnGap { items.append("A gap in care is likely") }
        if formData.r1TrnTimely { items.append("Timely follow-up has been arranged") }
        if items.isEmpty { return "" }
        return items.joined(separator: ". ") + "."
    }

    private func generateR1ContingencyText() -> String {
        var items: [String] = []
        if formData.r1CntCrisisPlan { items.append("A crisis plan is in place") }
        if formData.r1CntWarningSigns { items.append("Early warning signs are documented") }
        if formData.r1CntEscalation { items.append("There is a clear escalation pathway") }
        if formData.r1CntNoCrisis { items.append("There is no crisis plan") }
        if formData.r1CntNoEscalation { items.append("The escalation pathway is unclear") }
        if items.isEmpty { return "" }
        return items.joined(separator: ". ") + "."
    }

    // R2 Text Generation
    private func generateR2AccomText() -> String {
        let gender = formData.patientGender
        let subj = gender == .male ? "He" : "She"
        var items: [String] = []
        if formData.r2AccomUnstable { items.append("\(subj) has unstable housing or no fixed address") }
        if formData.r2AccomTemporary { items.append("\(subj) is in temporary accommodation") }
        if formData.r2AccomEvictionRisk { items.append("\(subj) is at risk of eviction") }
        if formData.r2AccomStable { items.append("\(subj) has stable accommodation") }
        if items.isEmpty { return "" }
        return items.joined(separator: ". ") + "."
    }

    private func generateR2CohabText() -> String {
        let gender = formData.patientGender
        let subj = gender == .male ? "He" : "She"
        var items: [String] = []
        if formData.r2CohabVictim { items.append("\(subj) is living with or near a previous victim") }
        if formData.r2CohabConflict { items.append("\(subj) is in a conflictual family environment") }
        if formData.r2CohabSubstancePeers { items.append("\(subj) is living with substance-using peers") }
        if formData.r2CohabSupportive { items.append("\(subj) has a supportive household") }
        if items.isEmpty { return "" }
        return items.joined(separator: ". ") + "."
    }

    private func generateR2SuperText() -> String {
        let gender = formData.patientGender
        let subj = gender == .male ? "He" : "She"
        var items: [String] = []
        if formData.r2SuperSupported { items.append("\(subj) is in a supported/staffed setting") }
        if formData.r2SuperUnsupervised { items.append("\(subj) is in completely unsupervised accommodation") }
        if formData.r2SuperStepDown { items.append("\(subj) is facing a step-down without adequate preparation") }
        if formData.r2SuperDeteriorates { items.append("\(subj) deteriorates without support") }
        if items.isEmpty { return "" }
        return items.joined(separator: ". ") + "."
    }

    private func generateR2SubstText() -> String {
        let gender = formData.patientGender
        let subj = gender == .male ? "He" : "She"
        var items: [String] = []
        if formData.r2SubstAccess { items.append("\(subj) has easy access to substances") }
        if formData.r2SubstPeers { items.append("\(subj) has substance-using peers nearby") }
        if formData.r2SubstFree { items.append("\(subj) is in a substance-free environment") }
        if items.isEmpty { return "" }
        return items.joined(separator: ". ") + "."
    }

    // R3 Text Generation
    private func generateR3SupportText() -> String {
        let gender = formData.patientGender
        let subj = gender == .male ? "He" : "She"
        var items: [String] = []
        if formData.r3SupFamily { items.append("\(subj) has supportive family") }
        if formData.r3SupPartner { items.append("\(subj) has a supportive partner") }
        if formData.r3SupRegularContact { items.append("\(subj) has regular contact with supports") }
        if formData.r3SupCrisisHelp { items.append("\(subj) has support available in crisis") }
        if items.isEmpty { return "" }
        return items.joined(separator: ". ") + "."
    }

    private func generateR3IsolationText() -> String {
        let gender = formData.patientGender
        let subj = gender == .male ? "He" : "She"
        var items: [String] = []
        if formData.r3IsoLimited { items.append("\(subj) has limited social support") }
        if formData.r3IsoEstranged { items.append("\(subj) is estranged from family") }
        if formData.r3IsoLivesAlone { items.append("\(subj) lives alone with limited contact") }
        if formData.r3IsoSuperficial { items.append("\(subj) has only superficial or unreliable contacts") }
        if items.isEmpty { return "" }
        return items.joined(separator: ". ") + "."
    }

    private func generateR3ConflictText() -> String {
        let gender = formData.patientGender
        let subj = gender == .male ? "He" : "She"
        var items: [String] = []
        if formData.r3ConInterpersonal { items.append("\(subj) has high interpersonal conflict") }
        if formData.r3ConVolatile { items.append("\(subj) has volatile relationships") }
        if formData.r3ConDomestic { items.append("\(subj) experiences domestic conflict") }
        if items.isEmpty { return "" }
        return items.joined(separator: ". ") + "."
    }

    private func generateR3PeersText() -> String {
        let gender = formData.patientGender
        let subj = gender == .male ? "He" : "She"
        var items: [String] = []
        if formData.r3PeerAntisocial { items.append("\(subj) mixes with antisocial peers") }
        if formData.r3PeerSubstance { items.append("\(subj) associates with substance-using peers") }
        if formData.r3PeerNegative { items.append("\(subj) is exposed to negative peer influence") }
        if items.isEmpty { return "" }
        return items.joined(separator: ". ") + "."
    }

    // R4 Text Generation
    private func generateR4MedText() -> String {
        let gender = formData.patientGender
        let subj = gender == .male ? "He" : "She"
        var items: [String] = []
        if formData.r4MedLikelyStop { items.append("\(subj) is likely to stop medication") }
        if formData.r4MedLikelyRefuse { items.append("\(subj) is likely to refuse medication") }
        if formData.r4MedHistoryNoncompliance { items.append("\(subj) has a history of medication non-compliance") }
        if formData.r4MedLikelyComply { items.append("\(subj) is likely to comply with medication") }
        if items.isEmpty { return "" }
        return items.joined(separator: ". ") + "."
    }

    private func generateR4AttendText() -> String {
        let gender = formData.patientGender
        let subj = gender == .male ? "He" : "She"
        var items: [String] = []
        if formData.r4AttLikelyMiss { items.append("\(subj) is likely to miss appointments") }
        if formData.r4AttLikelyDisengage { items.append("\(subj) is likely to disengage from services") }
        if formData.r4AttHistoryDna { items.append("\(subj) has a history of DNAs") }
        if formData.r4AttLikelyEngage { items.append("\(subj) is likely to engage with services") }
        if items.isEmpty { return "" }
        return items.joined(separator: ". ") + "."
    }

    private func generateR4SuperText() -> String {
        let gender = formData.patientGender
        let subj = gender == .male ? "He" : "She"
        var items: [String] = []
        if formData.r4SupLikelyBreach { items.append("\(subj) is likely to breach conditions") }
        if formData.r4SupHistoryBreach { items.append("\(subj) has a history of breaching conditions") }
        if formData.r4SupOnlyCoerced { items.append("\(subj) only complies under coercion") }
        if formData.r4SupLikelyAccept { items.append("\(subj) is likely to accept supervision") }
        if items.isEmpty { return "" }
        return items.joined(separator: ". ") + "."
    }

    private func generateR4EnforceText() -> String {
        let gender = formData.patientGender
        let subj = gender == .male ? "He" : "She"
        var items: [String] = []
        if formData.r4EnfHostile { items.append("\(subj) becomes hostile when supervised") }
        if formData.r4EnfResists { items.append("\(subj) resists monitoring") }
        if formData.r4EnfEscalates { items.append("\(subj) escalates when challenged") }
        if formData.r4EnfAccepts { items.append("\(subj) accepts enforcement constructively") }
        if items.isEmpty { return "" }
        return items.joined(separator: ". ") + "."
    }

    // R5 Text Generation
    private func generateR5StressText() -> String {
        let gender = formData.patientGender
        let subj = gender == .male ? "He" : "She"
        var items: [String] = []
        if formData.r5StrDischarge { items.append("\(subj) faces discharge/transition stress") }
        if formData.r5StrHousing { items.append("\(subj) has housing uncertainty") }
        if formData.r5StrRelationship { items.append("\(subj) faces relationship strain") }
        if formData.r5StrFinancial { items.append("\(subj) has financial problems") }
        if formData.r5StrReducedSupport { items.append("\(subj) has reduced support planned") }
        if items.isEmpty { return "" }
        return items.joined(separator: ". ") + "."
    }

    private func generateR5PatternText() -> String {
        let gender = formData.patientGender
        let subj = gender == .male ? "He" : "She"
        var items: [String] = []
        if formData.r5PatDeteriorates { items.append("\(subj) deteriorates under stress") }
        if formData.r5PatStrugglesTransitions { items.append("\(subj) struggles during transitions") }
        if formData.r5PatStressIncidents { items.append("Stress has preceded incidents") }
        if items.isEmpty { return "" }
        return items.joined(separator: ". ") + "."
    }

    private func generateR5CopingText() -> String {
        let gender = formData.patientGender
        let subj = gender == .male ? "He" : "She"
        var items: [String] = []
        if formData.r5CopLimited { items.append("\(subj) has limited coping skills") }
        if formData.r5CopRequiresContainment { items.append("\(subj) requires external containment") }
        if formData.r5CopMaladaptive { items.append("\(subj) uses maladaptive coping strategies") }
        if formData.r5CopEffective { items.append("\(subj) has effective coping strategies") }
        if items.isEmpty { return "" }
        return items.joined(separator: ". ") + "."
    }

    private func generateR5SubstanceText() -> String {
        let gender = formData.patientGender
        let subj = gender == .male ? "He" : "She"
        var items: [String] = []
        if formData.r5SubLikely { items.append("Substance use is likely under stress") }
        if formData.r5SubRelapseRisk { items.append("\(subj) has high relapse risk") }
        if formData.r5SubHistory { items.append("\(subj) has history of stress-linked substance use") }
        if items.isEmpty { return "" }
        return items.joined(separator: ". ") + "."
    }

    private func generateR5ProtectiveText() -> String {
        let gender = formData.patientGender
        let subj = gender == .male ? "He" : "She"
        var items: [String] = []
        if formData.r5ProtCopingDemonstrated { items.append("\(subj) has demonstrated ability to cope") }
        if formData.r5ProtHelpSeeking { items.append("\(subj) seeks help early") }
        if formData.r5ProtCrisisPlan { items.append("\(subj) has a rehearsed crisis plan") }
        if formData.r5ProtStableSupports { items.append("\(subj) has stable supports available") }
        if items.isEmpty { return "" }
        return items.joined(separator: ". ") + "."
    }

    // MARK: - Scenario Text Generation Functions

    private func generateSeverityFactorsText() -> String {
        var items: [String] = []
        if formData.sevHistSerious { items.append("history of assaults involving significant force") }
        if formData.sevLimitedInhibition { items.append("limited inhibition when unwell") }
        if formData.sevWeaponHistory { items.append("previous weapon use") }
        if formData.sevVulnerableVictims { items.append("risk to vulnerable victims") }
        if formData.sevEscalationPattern { items.append("pattern of escalation in violence") }
        if formData.sevLackRemorse { items.append("lack of remorse following violence") }
        if items.isEmpty { return "" }
        return "Severity factors include " + formatList(items) + "."
    }

    private func generateTriggerStatusText() -> String {
        var items: [String] = []
        if formData.trigPresent { items.append("Known risk triggers are currently present") }
        if formData.trigEmerging { items.append("Risk triggers appear to be emerging") }
        if formData.trigAbsent { items.append("No specific triggers are currently identified") }
        if items.isEmpty { return "" }
        return items.joined(separator: ". ") + "."
    }

    private func generateTransitionsText() -> String {
        var items: [String] = []
        if formData.transDischarge { items.append("the immediate post-discharge period") }
        if formData.transLeave { items.append("progression to unescorted leave") }
        if formData.transReducedSupervision { items.append("reduction in supervision") }
        if formData.transAccommodation { items.append("change in accommodation") }
        if formData.transRelationship { items.append("anticipated relationship changes") }
        if formData.transLegal { items.append("pending legal proceedings") }
        if items.isEmpty { return "" }
        return "Risk may become imminent during " + formatList(items) + " when supervision reduces and stressors increase."
    }

    private func generateProtectiveChangesText() -> String {
        var items: [String] = []
        if formData.protReducing { items.append("Protective factors are about to reduce, potentially increasing imminence") }
        if formData.protStable { items.append("Protective factors remain stable at this time") }
        if formData.protIncreasing { items.append("Protective factors are increasing, reducing immediate risk") }
        if items.isEmpty { return "" }
        return items.joined(separator: ". ") + "."
    }

    private func generateFrequencyContextText() -> String {
        var items: [String] = []
        if formData.ctxStress { items.append("periods of acute stress") }
        if formData.ctxRelapse { items.append("mental health relapse") }
        if formData.ctxSubstance { items.append("substance intoxication") }
        if formData.ctxInterpersonal { items.append("interpersonal conflict") }
        if formData.ctxFrustration { items.append("frustration or goal blocking") }
        if formData.ctxPerceivedThreat { items.append("perceived threat or provocation") }
        if items.isEmpty { return "" }
        return "The context of these triggers include \(formatList(items))."
    }

    private func generateLikelihoodConditionsText() -> String {
        var items: [String] = []
        if formData.condMedLapse { items.append("medication adherence lapses") }
        if formData.condConflict { items.append("interpersonal conflict escalates") }
        if formData.condSubstance { items.append("substance use resumes") }
        if formData.condSupervisionReduces { items.append("supervision reduces") }
        if formData.condSymptomsReturn { items.append("symptoms of mental disorder return") }
        if formData.condSupportLoss { items.append("support network weakens") }
        if formData.condStressIncreases { items.append("life stressors increase") }
        if items.isEmpty { return "" }
        return "Likelihood increases significantly if " + formatListWithOr(items) + "."
    }

    private func formatListWithOr(_ items: [String]) -> String {
        if items.count == 0 { return "" }
        if items.count == 1 { return items[0] }
        if items.count == 2 { return "\(items[0]) or \(items[1])" }
        return items.dropLast().joined(separator: ", ") + " or " + items.last!
    }

    // MARK: - Helper Properties and Methods

    private var currentPresence: HCR20PresenceRating {
        currentItemData?.presence ?? .absent
    }

    private var currentRelevance: HCR20RelevanceRating {
        currentItemData?.relevance ?? .low
    }

    private var currentImportedEntries: [ASRImportedEntry] {
        currentItemData?.importedEntries ?? []
    }

    private var currentItemData: HCR20ItemData? {
        switch section {
        case .h1: return formData.h1
        case .h2: return formData.h2
        case .h3: return formData.h3
        case .h4: return formData.h4
        case .h5: return formData.h5
        case .h6: return formData.h6
        case .h7: return formData.h7
        case .h8: return formData.h8
        case .h9: return formData.h9
        case .h10: return formData.h10
        case .c1: return formData.c1
        case .c2: return formData.c2
        case .c3: return formData.c3
        case .c4: return formData.c4
        case .c5: return formData.c5
        case .r1: return formData.r1
        case .r2: return formData.r2
        case .r3: return formData.r3
        case .r4: return formData.r4
        case .r5: return formData.r5
        default: return nil
        }
    }

    private func setPresence(_ rating: HCR20PresenceRating) {
        switch section {
        case .h1: formData.h1.presence = rating
        case .h2: formData.h2.presence = rating
        case .h3: formData.h3.presence = rating
        case .h4: formData.h4.presence = rating
        case .h5: formData.h5.presence = rating
        case .h6: formData.h6.presence = rating
        case .h7: formData.h7.presence = rating
        case .h8: formData.h8.presence = rating
        case .h9: formData.h9.presence = rating
        case .h10: formData.h10.presence = rating
        case .c1: formData.c1.presence = rating
        case .c2: formData.c2.presence = rating
        case .c3: formData.c3.presence = rating
        case .c4: formData.c4.presence = rating
        case .c5: formData.c5.presence = rating
        case .r1: formData.r1.presence = rating
        case .r2: formData.r2.presence = rating
        case .r3: formData.r3.presence = rating
        case .r4: formData.r4.presence = rating
        case .r5: formData.r5.presence = rating
        default: break
        }
    }

    private func setRelevance(_ rating: HCR20RelevanceRating) {
        switch section {
        case .h1: formData.h1.relevance = rating
        case .h2: formData.h2.relevance = rating
        case .h3: formData.h3.relevance = rating
        case .h4: formData.h4.relevance = rating
        case .h5: formData.h5.relevance = rating
        case .h6: formData.h6.relevance = rating
        case .h7: formData.h7.relevance = rating
        case .h8: formData.h8.relevance = rating
        case .h9: formData.h9.relevance = rating
        case .h10: formData.h10.relevance = rating
        case .c1: formData.c1.relevance = rating
        case .c2: formData.c2.relevance = rating
        case .c3: formData.c3.relevance = rating
        case .c4: formData.c4.relevance = rating
        case .c5: formData.c5.relevance = rating
        case .r1: formData.r1.relevance = rating
        case .r2: formData.r2.relevance = rating
        case .r3: formData.r3.relevance = rating
        case .r4: formData.r4.relevance = rating
        case .r5: formData.r5.relevance = rating
        default: break
        }
    }

    private var importedEntriesBinding: Binding<[ASRImportedEntry]> {
        switch section {
        case .h1: return $formData.h1.importedEntries
        case .h2: return $formData.h2.importedEntries
        case .h3: return $formData.h3.importedEntries
        case .h4: return $formData.h4.importedEntries
        case .h5: return $formData.h5.importedEntries
        case .h6: return $formData.h6.importedEntries
        case .h7: return $formData.h7.importedEntries
        case .h8: return $formData.h8.importedEntries
        case .h9: return $formData.h9.importedEntries
        case .h10: return $formData.h10.importedEntries
        case .c1: return $formData.c1.importedEntries
        case .c2: return $formData.c2.importedEntries
        case .c3: return $formData.c3.importedEntries
        case .c4: return $formData.c4.importedEntries
        case .c5: return $formData.c5.importedEntries
        case .r1: return $formData.r1.importedEntries
        case .r2: return $formData.r2.importedEntries
        case .r3: return $formData.r3.importedEntries
        case .r4: return $formData.r4.importedEntries
        case .r5: return $formData.r5.importedEntries
        default: return .constant([])
        }
    }

    private func subsectionTextBinding(for subsection: String) -> Binding<String> {
        Binding(
            get: {
                currentItemData?.subsectionTexts[subsection] ?? ""
            },
            set: { newValue in
                setSubsectionText(subsection, value: newValue)
            }
        )
    }

    private func setSubsectionText(_ subsection: String, value: String) {
        switch section {
        case .h1: formData.h1.subsectionTexts[subsection] = value
        case .h2: formData.h2.subsectionTexts[subsection] = value
        case .h3: formData.h3.subsectionTexts[subsection] = value
        case .h4: formData.h4.subsectionTexts[subsection] = value
        case .h5: formData.h5.subsectionTexts[subsection] = value
        case .h6: formData.h6.subsectionTexts[subsection] = value
        case .h7: formData.h7.subsectionTexts[subsection] = value
        case .h8: formData.h8.subsectionTexts[subsection] = value
        case .h9: formData.h9.subsectionTexts[subsection] = value
        case .h10: formData.h10.subsectionTexts[subsection] = value
        case .c1: formData.c1.subsectionTexts[subsection] = value
        case .c2: formData.c2.subsectionTexts[subsection] = value
        case .c3: formData.c3.subsectionTexts[subsection] = value
        case .c4: formData.c4.subsectionTexts[subsection] = value
        case .c5: formData.c5.subsectionTexts[subsection] = value
        case .r1: formData.r1.subsectionTexts[subsection] = value
        case .r2: formData.r2.subsectionTexts[subsection] = value
        case .r3: formData.r3.subsectionTexts[subsection] = value
        case .r4: formData.r4.subsectionTexts[subsection] = value
        case .r5: formData.r5.subsectionTexts[subsection] = value
        default: break
        }
    }

    // Helper binding functions for specialized popups (H7, H8, H9, H10)
    private func h7SubsectionBinding(_ key: String) -> Binding<String> {
        Binding(
            get: { formData.h7.subsectionTexts[key] ?? "" },
            set: { formData.h7.subsectionTexts[key] = $0 }
        )
    }

    private func h8SubsectionBinding(_ key: String) -> Binding<String> {
        Binding(
            get: { formData.h8.subsectionTexts[key] ?? "" },
            set: { formData.h8.subsectionTexts[key] = $0 }
        )
    }

    private func h9SubsectionBinding(_ key: String) -> Binding<String> {
        Binding(
            get: { formData.h9.subsectionTexts[key] ?? "" },
            set: { formData.h9.subsectionTexts[key] = $0 }
        )
    }

    private func h10SubsectionBinding(_ key: String) -> Binding<String> {
        Binding(
            get: { formData.h10.subsectionTexts[key] ?? "" },
            set: { formData.h10.subsectionTexts[key] = $0 }
        )
    }

    private func presenceColor(_ presence: HCR20PresenceRating) -> Color {
        switch presence {
        case .absent: return .green
        case .possible: return .orange
        case .present: return .red
        case .omit: return .gray
        }
    }

    private func relevanceColor(_ relevance: HCR20RelevanceRating) -> Color {
        switch relevance {
        case .low: return .green
        case .moderate: return .orange
        case .high: return .red
        }
    }

    // MARK: - Text Generation

    private func generateText() -> String {
        switch section {
        case .patientDetails:
            return generatePatientDetailsText()
        case .assessmentDetails:
            return generateAssessmentDetailsText()
        case .sourcesOfInformation:
            return generateSourcesText()
        case .h7:
            return generateH7Text()
        case .h8:
            return generateH8Text()
        case .h9:
            return generateH9Text()
        case .h10:
            return generateH10Text()
        case .h1, .h2, .h3, .h4, .h5, .h6,
             .c1, .c2, .c3, .c4, .c5,
             .r1, .r2, .r3, .r4, .r5:
            return generateHCRItemText()
        case .formulation:
            return formData.formulationText
        case .scenarios:
            return generateScenariosText()
        case .management:
            return generateManagementText()
        case .signature:
            return generateSignatureText()
        }
    }

    private func generatePatientDetailsText() -> String {
        var parts: [String] = []
        if !formData.patientName.isEmpty {
            parts.append("Patient: \(formData.patientName)")
        }
        if let dob = formData.patientDOB {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            parts.append("DOB: \(formatter.string(from: dob))")
        }
        if !formData.hospitalName.isEmpty {
            parts.append("Hospital: \(formData.hospitalName)")
        }
        return parts.joined(separator: "\n")
    }

    private func generateAssessmentDetailsText() -> String {
        var parts: [String] = []
        if !formData.assessorName.isEmpty {
            parts.append("Assessor: \(formData.assessorName)")
        }
        if !formData.assessorRole.isEmpty {
            parts.append("Role: \(formData.assessorRole)")
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        parts.append("Date: \(formatter.string(from: formData.assessmentDate))")
        return parts.joined(separator: "\n")
    }

    private func generateSourcesText() -> String {
        var sources: [String] = []
        if formData.sourcesClinicalNotes { sources.append("Clinical Notes") }
        if formData.sourcesRiskAssessments { sources.append("Risk Assessments") }
        if formData.sourcesForensicHistory { sources.append("Forensic History") }
        if formData.sourcesPsychologyReports { sources.append("Psychology Reports") }
        if formData.sourcesMDTDiscussion { sources.append("MDT Discussion") }
        if formData.sourcesPatientInterview { sources.append("Patient Interview") }
        if formData.sourcesCollateralInfo { sources.append("Collateral Information") }
        if !formData.sourcesOther.isEmpty { sources.append(formData.sourcesOther) }

        if sources.isEmpty { return "" }
        return "Sources reviewed: " + sources.joined(separator: ", ") + "."
    }

    private func generateHCRItemText() -> String {
        guard let item = currentItemData else { return "" }

        var parts: [String] = []

        // Presence and relevance
        let presenceText: String
        switch item.presence {
        case .absent: presenceText = "No evidence of problems"
        case .possible: presenceText = "Partial/possible evidence"
        case .present: presenceText = "Definite evidence of problems"
        case .omit: presenceText = "Insufficient information to rate"
        }
        parts.append("\(presenceText) (\(item.presence.rawValue)).")

        if item.presence != .omit {
            parts.append("Relevance rated as \(item.relevance.rawValue.lowercased()).")
        }

        // Subsection texts (each subsection has a label and documented text)
        if let subsections = HCR20FormData.itemSubsections[section.itemKey] {
            for (label, _) in subsections {
                if let text = item.subsectionTexts[label], !text.isEmpty {
                    parts.append("\n\(label)\n\(text)")
                }
            }
        }

        // Append selected imported notes
        let selectedImports = item.importedEntries.filter { $0.selected }
        if !selectedImports.isEmpty {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "dd/MM/yyyy"
            var importedTexts: [String] = []
            for entry in selectedImports {
                if let date = entry.date {
                    importedTexts.append("[\(dateFormatter.string(from: date))] \(entry.text)")
                } else {
                    importedTexts.append(entry.text)
                }
            }
            parts.append("\n--- Imported Notes ---\n" + importedTexts.joined(separator: "\n"))
        }

        return parts.joined(separator: " ")
    }

    private func generateScenariosText() -> String {
        var parts: [String] = []

        // 1. Generate Nature of Risk from checkboxes
        let natureText = generateNatureOfRiskText()
        if !natureText.isEmpty {
            parts.append("NATURE OF RISK:\n\(natureText)")
        }

        // 2. Severity
        if !formData.severityLevel.isEmpty {
            let severityDescriptions: [String: String] = [
                "minor": "Minor harm anticipated (bruises, minor injuries not requiring medical attention)",
                "moderate": "Moderate harm anticipated (injury requiring medical attention)",
                "serious": "Serious harm anticipated (hospitalization likely required)",
                "severe": "Severe harm anticipated (permanent injury possible)",
                "fatal": "Fatal harm is a realistic possibility"
            ]
            if let desc = severityDescriptions[formData.severityLevel] {
                parts.append("SEVERITY:\n\(desc)")
            }
        }

        // 3. Imminence
        if !formData.imminenceLevel.isEmpty {
            let imminenceDescriptions: [String: String] = [
                "imminent": "Risk is imminent (within days)",
                "weeks": "Risk is short-term (within weeks)",
                "months": "Risk is medium-term (within months)",
                "longterm": "Risk is long-term (over years)"
            ]
            if let desc = imminenceDescriptions[formData.imminenceLevel] {
                parts.append("IMMINENCE:\n\(desc)")
            }
        }

        // 4. Frequency
        if !formData.frequencyLevel.isEmpty {
            let frequencyDescriptions: [String: String] = [
                "isolated": "Violence would likely be an isolated incident",
                "occasional": "Violence may occur occasionally (infrequent episodes)",
                "frequent": "Violence may be frequent (regular episodes)",
                "chronic": "Violence may be chronic (persistent pattern)"
            ]
            if let desc = frequencyDescriptions[formData.frequencyLevel] {
                parts.append("FREQUENCY:\n\(desc)")
            }
        }

        // 5. Likelihood
        if !formData.likelihoodLevel.isEmpty {
            let likelihoodDescriptions: [String: String] = [
                "low": "Overall likelihood of violence is LOW",
                "moderate": "Overall likelihood of violence is MODERATE",
                "high": "Overall likelihood of violence is HIGH"
            ]
            if let desc = likelihoodDescriptions[formData.likelihoodLevel] {
                parts.append("LIKELIHOOD:\n\(desc)")
            }
        }

        // Additional notes
        if !formData.scenarioLikelihood.isEmpty {
            parts.append("ADDITIONAL NOTES:\n\(formData.scenarioLikelihood)")
        }

        return parts.joined(separator: "\n\n")
    }

    private func generateNatureOfRiskText() -> String {
        // Harm type phrases
        let harmPhrases: [(Bool, String)] = [
            (formData.harmPhysicalGeneral, "general physical aggression"),
            (formData.harmPhysicalTargeted, "targeted physical violence towards specific individuals"),
            (formData.harmDomestic, "domestic violence"),
            (formData.harmThreatening, "threatening or intimidating behaviour"),
            (formData.harmWeapon, "weapon-related violence"),
            (formData.harmSexual, "sexual violence"),
            (formData.harmArson, "fire-setting or property damage"),
            (formData.harmInstitutional, "institutional aggression towards staff or patients"),
            (formData.harmStalking, "stalking or harassment behaviour")
        ]

        // Victim phrases
        let victimPhrases: [(Bool, String)] = [
            (formData.victimKnown, "known others (family, partners, acquaintances)"),
            (formData.victimStrangers, "strangers"),
            (formData.victimStaff, "staff and professionals"),
            (formData.victimPatients, "co-patients or service users"),
            (formData.victimAuthority, "authority figures"),
            (formData.victimChildren, "vulnerable groups including children or elderly")
        ]

        // Motivation phrases
        let motivPhrases: [(Bool, String)] = [
            (formData.motivImpulsive, "impulsive physical aggression during periods of emotional dysregulation"),
            (formData.motivInstrumental, "instrumental or goal-directed violence"),
            (formData.motivParanoid, "violence driven by paranoid or persecutory beliefs"),
            (formData.motivCommand, "acting on command hallucinations"),
            (formData.motivGrievance, "grievance-based or retaliatory violence"),
            (formData.motivTerritorial, "territorial or defensive aggression"),
            (formData.motivSubstance, "violence during substance-related disinhibition")
        ]

        let selectedHarms = harmPhrases.filter { $0.0 }.map { $0.1 }
        let selectedVictims = victimPhrases.filter { $0.0 }.map { $0.1 }
        let selectedMotivs = motivPhrases.filter { $0.0 }.map { $0.1 }

        var textParts: [String] = []

        if !selectedHarms.isEmpty {
            let harmStr = formatList(selectedHarms)
            textParts.append("Risk relates primarily to \(harmStr)")
        }

        if !selectedVictims.isEmpty {
            let victimStr = formatList(selectedVictims)
            textParts.append("towards \(victimStr)")
        }

        if !selectedMotivs.isEmpty {
            let motivStr = selectedMotivs.first ?? ""
            if textParts.isEmpty {
                textParts.append("Risk is characterised by \(motivStr)")
            } else {
                textParts.append("characterised by \(motivStr)")
            }
        }

        return textParts.isEmpty ? "" : textParts.joined(separator: " ") + "."
    }

    private func formatList(_ items: [String]) -> String {
        guard !items.isEmpty else { return "" }
        if items.count == 1 { return items[0] }
        let allButLast = items.dropLast().joined(separator: ", ")
        return "\(allButLast) and \(items.last!)"
    }

    private func generateManagementText() -> String {
        var parts: [String] = []

        // 6. Risk-Enhancing Factors (from checkboxes)
        let enhancingText = generateEnhancingFactorsText()
        if !enhancingText.isEmpty {
            parts.append("RISK-ENHANCING FACTORS:\n\(enhancingText)")
        }

        // 7. Protective Factors (from checkboxes)
        let protectiveText = generateProtectiveFactorsText()
        if !protectiveText.isEmpty {
            parts.append("PROTECTIVE FACTORS:\n\(protectiveText)")
        }

        // 8. Monitoring Indicators (from checkboxes)
        let monitoringText = generateMonitoringText()
        if !monitoringText.isEmpty {
            parts.append("MONITORING INDICATORS:\n\(monitoringText)")
        }

        // 9-11. Text fields
        if !formData.managementTreatment.isEmpty {
            parts.append("TREATMENT RECOMMENDATIONS:\n\(formData.managementTreatment)")
        }
        if !formData.managementSupervision.isEmpty {
            parts.append("SUPERVISION RECOMMENDATIONS:\n\(formData.managementSupervision)")
        }
        if !formData.managementVictimSafety.isEmpty {
            parts.append("VICTIM SAFETY PLANNING:\n\(formData.managementVictimSafety)")
        }

        return parts.joined(separator: "\n\n")
    }

    private func generateEnhancingFactorsText() -> String {
        // Clinical factors (C1-C5)
        let clinicalPhrases: [(Bool, String)] = [
            (formData.enhPoorInsight, "poor insight into illness or risk"),
            (formData.enhViolentIdeation, "active violent ideation or intent"),
            (formData.enhActiveSymptoms, "active symptoms of mental disorder"),
            (formData.enhInstability, "affective or behavioural instability"),
            (formData.enhPoorTreatment, "poor treatment or supervision response")
        ]

        // Situational factors (R1-R5)
        let situationalPhrases: [(Bool, String)] = [
            (formData.enhPoorPlan, "inadequate professional services or plans"),
            (formData.enhUnstableLiving, "unstable or unsupportive living situation"),
            (formData.enhPoorSupport, "lack of personal support"),
            (formData.enhNonCompliance, "non-compliance with treatment or supervision"),
            (formData.enhPoorCoping, "poor stress tolerance or coping")
        ]

        // Other/Personal factors
        let otherPhrases: [(Bool, String)] = [
            (formData.enhSubstance, "ongoing substance use"),
            (formData.enhConflict, "conflictual relationships"),
            (formData.enhAccessVictims, "access to victims or known triggers"),
            (formData.enhTransitions, "stressful transitions"),
            (formData.enhLossSupervision, "anticipated loss of supervision")
        ]

        let clinical = clinicalPhrases.filter { $0.0 }.map { $0.1 }
        let situational = situationalPhrases.filter { $0.0 }.map { $0.1 }
        let other = otherPhrases.filter { $0.0 }.map { $0.1 }

        var sentences: [String] = []

        if !clinical.isEmpty {
            sentences.append("Risk is enhanced by clinical factors, including \(formatList(clinical)).")
        }

        if !situational.isEmpty {
            sentences.append("Situational factors also increase the risk such as \(formatList(situational)).")
        }

        if !other.isEmpty {
            if !clinical.isEmpty && !situational.isEmpty {
                sentences.append("Finally, \(formatList(other)) also increase the risk.")
            } else if !clinical.isEmpty || !situational.isEmpty {
                sentences.append("Also, \(formatList(other)) increase the risk.")
            } else {
                sentences.append("Risk is enhanced by \(formatList(other)).")
            }
        }

        return sentences.joined(separator: " ")
    }

    private func generateProtectiveFactorsText() -> String {
        let strongPhrases: [(Bool, String)] = [
            (formData.protTreatmentAdherence, "sustained treatment adherence"),
            (formData.protStructuredSupervision, "structured supervision"),
            (formData.protSupportiveRelationships, "supportive, prosocial relationships"),
            (formData.protInsightLinked, "insight linked to behaviour change"),
            (formData.protHelpSeeking, "early help-seeking behaviour"),
            (formData.protRestrictedAccess, "restricted access to triggers and victims"),
            (formData.protMedicationResponse, "demonstrated response to medication")
        ]

        let weakPhrases: [(Bool, String)] = [
            (formData.protVerbalMotivation, "verbal motivation (untested)"),
            (formData.protUntestedCoping, "untested coping skills"),
            (formData.protConditionalSupport, "supports that may disengage under stress"),
            (formData.protExternalMotivation, "externally motivated compliance only"),
            (formData.protSituationalStability, "stability dependent on current environment")
        ]

        let strong = strongPhrases.filter { $0.0 }.map { $0.1 }
        let weak = weakPhrases.filter { $0.0 }.map { $0.1 }

        var parts: [String] = []
        if !strong.isEmpty {
            parts.append("Protective factors include \(formatList(strong))")
        }
        if !weak.isEmpty {
            if parts.isEmpty {
                parts.append("Identified protectors are weak or conditional, including \(formatList(weak))")
            } else {
                parts.append("However, some protectors are weak or conditional, including \(formatList(weak))")
            }
        }

        return parts.isEmpty ? "" : parts.joined(separator: ". ") + "."
    }

    private func generateMonitoringText() -> String {
        let monitorPhrases: [(Bool, String)] = [
            (formData.monMissedAppts, "missed appointments"),
            (formData.monMedRefusal, "medication refusal"),
            (formData.monWithdrawal, "withdrawal from supports"),
            (formData.monSubstanceUse, "increased substance use"),
            (formData.monNonCompliance, "non-compliance with conditions"),
            (formData.monRuleBreaking, "rule-breaking behaviour"),
            (formData.monSleepDisturb, "sleep disturbance"),
            (formData.monParanoia, "rising paranoia or suspiciousness"),
            (formData.monIrritability, "increasing irritability"),
            (formData.monHostileLanguage, "escalation in hostile language"),
            (formData.monFixation, "fixation on grievances"),
            (formData.monAgitation, "increased agitation or restlessness")
        ]

        let selected = monitorPhrases.filter { $0.0 }.map { $0.1 }
        if selected.isEmpty { return "" }
        return "Early warning signs to monitor include \(formatList(selected))."
    }

    private func generateSignatureText() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return "Signed: \(formatter.string(from: formData.signatureDate))"
    }

    // MARK: - H7 Personality Disorder Text Generation
    private func generateH7Text() -> String {
        let gender = formData.patientGender
        let subj = gender == .male ? "he" : "she"
        let Subj = subj.capitalized
        let poss = gender == .male ? "his" : "her"

        var parts: [String] = []

        // Presence and relevance
        let presenceText: String
        switch formData.h7.presence {
        case .absent: presenceText = "No evidence of problems with personality disorder"
        case .possible: presenceText = "Partial/possible evidence of personality disorder"
        case .present: presenceText = "Definite evidence of personality disorder"
        case .omit: presenceText = "Insufficient information to rate personality disorder"
        }
        parts.append("\(presenceText) (\(formData.h7.presence.rawValue)).")

        if formData.h7.presence != .omit {
            parts.append("Relevance rated as \(formData.h7.relevance.rawValue.lowercased()).")
        }

        // Generate cumulative text from ALL PD types with checked traits
        let allPDTraitsText = generateH7AllPDTraitsText()
        if !allPDTraitsText.isEmpty {
            parts.append("\nPERSONALITY DISORDER FEATURES:\n\(allPDTraitsText)")
        }

        // Impact checkboxes
        let impactText = generateH7ImpactText()
        if !impactText.isEmpty {
            parts.append("\nIMPACT ON FUNCTIONING:\n\(impactText)")
        }

        // Manual notes (additional text entered in subsection boxes)
        if let pdManualNotes = formData.h7.subsectionTexts["Personality Disorder Features:"], !pdManualNotes.isEmpty {
            parts.append("\nADDITIONAL NOTES:\n\(pdManualNotes)")
        }
        if let impactManualText = formData.h7.subsectionTexts["Impact on Functioning:"], !impactManualText.isEmpty {
            parts.append("\nIMPACT NOTES:\n\(impactManualText)")
        }

        // Imported notes
        let selectedImports = formData.h7.importedEntries.filter { $0.selected }
        if !selectedImports.isEmpty {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "dd/MM/yyyy"
            var importedTexts: [String] = []
            for entry in selectedImports {
                if let date = entry.date {
                    importedTexts.append("[\(dateFormatter.string(from: date))] \(entry.text)")
                } else {
                    importedTexts.append(entry.text)
                }
            }
            parts.append("\n--- Imported Notes ---\n" + importedTexts.joined(separator: "\n"))
        }

        return parts.joined(separator: " ")
    }

    private func generateH7TraitText(for pdType: String) -> String {
        let gender = formData.patientGender
        let subj = gender == .male ? "He" : "She"
        let poss = gender == .male ? "his" : "her"

        var traits: [String] = []

        switch pdType {
        case "Dissocial":
            if formData.h7DissocialUnconcern { traits.append("callous unconcern for feelings of others") }
            if formData.h7DissocialIrresponsibility { traits.append("gross and persistent irresponsibility") }
            if formData.h7DissocialIncapacityRelations { traits.append("incapacity to maintain enduring relationships") }
            if formData.h7DissocialLowFrustration { traits.append("very low tolerance to frustration") }
            if formData.h7DissocialAggression { traits.append("low threshold for discharge of aggression") }
            if formData.h7DissocialIncapacityGuilt { traits.append("incapacity to experience guilt") }
            if formData.h7DissocialBlameOthers { traits.append("marked proneness to blame others") }
            if formData.h7DissocialRationalise { traits.append("plausible rationalisation for behaviour") }
        case "EUPD-B":
            if formData.h7EupdBAbandonment { traits.append("frantic efforts to avoid abandonment") }
            if formData.h7EupdBUnstableRelations { traits.append("unstable and intense relationships") }
            if formData.h7EupdBIdentity { traits.append("identity disturbance") }
            if formData.h7EupdBImpulsivity { traits.append("impulsivity in potentially damaging areas") }
            if formData.h7EupdBSuicidal { traits.append("recurrent suicidal or self-harm behaviour") }
            if formData.h7EupdBAffective { traits.append("affective instability") }
            if formData.h7EupdBEmptiness { traits.append("chronic feelings of emptiness") }
            if formData.h7EupdBAnger { traits.append("inappropriate, intense anger") }
            if formData.h7EupdBDissociation { traits.append("transient paranoia or dissociation") }
        case "EUPD-I":
            if formData.h7EupdIActUnexpectedly { traits.append("acts unexpectedly without considering consequences") }
            if formData.h7EupdIQuarrelsome { traits.append("tendency to quarrelsome behaviour and conflicts") }
            if formData.h7EupdIAngerOutbursts { traits.append("liability to outbursts of anger or violence") }
            if formData.h7EupdINoPersistence { traits.append("difficulty maintaining actions without immediate reward") }
            if formData.h7EupdIUnstableMood { traits.append("unstable and capricious mood") }
        case "Paranoid":
            if formData.h7ParanoidSuspects { traits.append("suspects others are exploiting or harming") }
            if formData.h7ParanoidDoubtsLoyalty { traits.append("preoccupied with doubts about loyalty") }
            if formData.h7ParanoidReluctantConfide { traits.append("reluctant to confide in others") }
            if formData.h7ParanoidReadsThreats { traits.append("reads hidden demeaning meanings") }
            if formData.h7ParanoidBearsGrudges { traits.append("persistently bears grudges") }
            if formData.h7ParanoidPerceivesAttacks { traits.append("perceives attacks on character") }
            if formData.h7ParanoidSuspiciousFidelity { traits.append("recurrent suspicions about fidelity") }
        case "Schizoid":
            if formData.h7SchizoidNoPleasure { traits.append("few activities give pleasure") }
            if formData.h7SchizoidCold { traits.append("emotional coldness and detachment") }
            if formData.h7SchizoidLimitedWarmth { traits.append("limited capacity to express warmth or anger") }
            if formData.h7SchizoidIndifferent { traits.append("apparent indifference to praise or criticism") }
            if formData.h7SchizoidLittleInterestSex { traits.append("little interest in sexual experiences") }
            if formData.h7SchizoidSolitary { traits.append("preference for solitary activities") }
            if formData.h7SchizoidFantasy { traits.append("excessive preoccupation with fantasy") }
            if formData.h7SchizoidNoConfidants { traits.append("no close friends or confiding relationships") }
            if formData.h7SchizoidInsensitive { traits.append("insensitivity to social norms") }
        case "Histrionic":
            if formData.h7HistrionicAttention { traits.append("discomfort when not centre of attention") }
            if formData.h7HistrionicSeductive { traits.append("inappropriately seductive or provocative") }
            if formData.h7HistrionicShallowEmotion { traits.append("rapidly shifting and shallow emotions") }
            if formData.h7HistrionicAppearance { traits.append("uses appearance to draw attention") }
            if formData.h7HistrionicImpressionistic { traits.append("impressionistic speech lacking detail") }
            if formData.h7HistrionicDramatic { traits.append("self-dramatisation and theatricality") }
            if formData.h7HistrionicSuggestible { traits.append("easily influenced by others") }
            if formData.h7HistrionicIntimacy { traits.append("considers relationships more intimate than they are") }
        case "Anankastic":
            if formData.h7AnankasticDoubt { traits.append("excessive doubt and caution") }
            if formData.h7AnankasticDetail { traits.append("preoccupation with details, rules, lists") }
            if formData.h7AnankasticPerfectionism { traits.append("perfectionism that interferes with completion") }
            if formData.h7AnankasticConscientious { traits.append("excessive conscientiousness") }
            if formData.h7AnankasticPleasure { traits.append("preoccupation with productivity to exclusion of pleasure") }
            if formData.h7AnankasticPedantic { traits.append("excessive pedantry and adherence to convention") }
            if formData.h7AnankasticRigid { traits.append("rigidity and stubbornness") }
            if formData.h7AnankasticInsistence { traits.append("unreasonable insistence others do things their way") }
        case "Anxious":
            if formData.h7AnxiousTension { traits.append("persistent feelings of tension and apprehension") }
            if formData.h7AnxiousInferior { traits.append("beliefs of social ineptness and inferiority") }
            if formData.h7AnxiousCriticism { traits.append("excessive preoccupation with criticism or rejection") }
            if formData.h7AnxiousUnwilling { traits.append("unwilling to become involved unless certain of being liked") }
            if formData.h7AnxiousRestricted { traits.append("restrictions in lifestyle due to need for security") }
            if formData.h7AnxiousAvoidsActivities { traits.append("avoids activities involving significant interpersonal contact") }
        case "Dependent":
            if formData.h7DependentEncourage { traits.append("encourages or allows others to make decisions") }
            if formData.h7DependentSubordinates { traits.append("subordinates own needs to those of others") }
            if formData.h7DependentUnwillingDemands { traits.append("unwilling to make reasonable demands on others") }
            if formData.h7DependentHelpless { traits.append("feels uncomfortable or helpless when alone") }
            if formData.h7DependentAbandonment { traits.append("preoccupied with fears of being left to care for self") }
            if formData.h7DependentLimitedCapacity { traits.append("limited capacity to make everyday decisions") }
        default:
            break
        }

        if traits.isEmpty { return "" }
        return "\(subj) demonstrates \(formatList(traits))."
    }

    private func generateH7ImpactText() -> String {
        var impacts: [String] = []

        // Relationships
        if formData.h7ImpactIntimate { impacts.append("difficulties maintaining intimate relationships") }
        if formData.h7ImpactFamily { impacts.append("conflictual or estranged family relationships") }
        if formData.h7ImpactSocial { impacts.append("poor social relationships or isolation") }
        if formData.h7ImpactProfessional { impacts.append("difficulties with professional relationships") }

        // Employment
        if formData.h7ImpactJobLoss { impacts.append("repeated job losses due to behaviour") }
        if formData.h7ImpactWorkConflict { impacts.append("frequent workplace conflicts") }
        if formData.h7ImpactUnderachievement { impacts.append("significant underachievement") }

        // Treatment
        if formData.h7ImpactPoorEngagement { impacts.append("poor treatment engagement") }
        if formData.h7ImpactStaffConflict { impacts.append("conflicts with clinical staff") }
        if formData.h7ImpactNonCompliance { impacts.append("non-compliance with supervision") }
        if formData.h7ImpactManipulation { impacts.append("manipulative behaviour in treatment") }

        // Violence
        if formData.h7ImpactAggressionPattern { impacts.append("pattern of aggressive behaviour") }
        if formData.h7ImpactInstrumental { impacts.append("instrumental or planned violence") }
        if formData.h7ImpactReactive { impacts.append("reactive or impulsive violence") }
        if formData.h7ImpactVictimTargeting { impacts.append("targeting of specific victim types") }

        if impacts.isEmpty { return "" }
        return "Personality difficulties have impacted functioning through \(formatList(impacts))."
    }

    // MARK: - H7 ALL PD Traits Text Generation (Cumulative across all PD types)
    private func generateH7AllPDTraitsText() -> String {
        let gender = formData.patientGender
        let subj = gender == .male ? "He" : "She"

        var pdTypeTraits: [String: [String]] = [:]

        // Dissocial
        var dissocialTraits: [String] = []
        if formData.h7DissocialUnconcern { dissocialTraits.append("callous unconcern for feelings of others") }
        if formData.h7DissocialIrresponsibility { dissocialTraits.append("gross and persistent irresponsibility") }
        if formData.h7DissocialIncapacityRelations { dissocialTraits.append("incapacity to maintain enduring relationships") }
        if formData.h7DissocialLowFrustration { dissocialTraits.append("very low tolerance to frustration") }
        if formData.h7DissocialAggression { dissocialTraits.append("low threshold for discharge of aggression") }
        if formData.h7DissocialIncapacityGuilt { dissocialTraits.append("incapacity to experience guilt") }
        if formData.h7DissocialBlameOthers { dissocialTraits.append("marked proneness to blame others") }
        if formData.h7DissocialRationalise { dissocialTraits.append("plausible rationalisation for behaviour") }
        if !dissocialTraits.isEmpty { pdTypeTraits["Dissocial PD"] = dissocialTraits }

        // EUPD-Borderline
        var eupdBTraits: [String] = []
        if formData.h7EupdBAbandonment { eupdBTraits.append("frantic efforts to avoid abandonment") }
        if formData.h7EupdBUnstableRelations { eupdBTraits.append("unstable and intense relationships") }
        if formData.h7EupdBIdentity { eupdBTraits.append("identity disturbance") }
        if formData.h7EupdBImpulsivity { eupdBTraits.append("impulsivity in potentially damaging areas") }
        if formData.h7EupdBSuicidal { eupdBTraits.append("recurrent suicidal or self-harm behaviour") }
        if formData.h7EupdBAffective { eupdBTraits.append("affective instability") }
        if formData.h7EupdBEmptiness { eupdBTraits.append("chronic feelings of emptiness") }
        if formData.h7EupdBAnger { eupdBTraits.append("inappropriate, intense anger") }
        if formData.h7EupdBDissociation { eupdBTraits.append("transient paranoia or dissociation") }
        if !eupdBTraits.isEmpty { pdTypeTraits["EUPD-Borderline"] = eupdBTraits }

        // EUPD-Impulsive
        var eupdITraits: [String] = []
        if formData.h7EupdIActUnexpectedly { eupdITraits.append("acts unexpectedly without considering consequences") }
        if formData.h7EupdIQuarrelsome { eupdITraits.append("tendency to quarrelsome behaviour and conflicts") }
        if formData.h7EupdIAngerOutbursts { eupdITraits.append("liability to outbursts of anger or violence") }
        if formData.h7EupdINoPersistence { eupdITraits.append("difficulty maintaining actions without immediate reward") }
        if formData.h7EupdIUnstableMood { eupdITraits.append("unstable and capricious mood") }
        if !eupdITraits.isEmpty { pdTypeTraits["EUPD-Impulsive"] = eupdITraits }

        // Paranoid
        var paranoidTraits: [String] = []
        if formData.h7ParanoidSuspects { paranoidTraits.append("suspects others are exploiting or harming") }
        if formData.h7ParanoidDoubtsLoyalty { paranoidTraits.append("preoccupied with doubts about loyalty") }
        if formData.h7ParanoidReluctantConfide { paranoidTraits.append("reluctant to confide in others") }
        if formData.h7ParanoidReadsThreats { paranoidTraits.append("reads hidden demeaning meanings") }
        if formData.h7ParanoidBearsGrudges { paranoidTraits.append("persistently bears grudges") }
        if formData.h7ParanoidPerceivesAttacks { paranoidTraits.append("perceives attacks on character") }
        if formData.h7ParanoidSuspiciousFidelity { paranoidTraits.append("recurrent suspicions about fidelity") }
        if !paranoidTraits.isEmpty { pdTypeTraits["Paranoid PD"] = paranoidTraits }

        // Schizoid
        var schizoidTraits: [String] = []
        if formData.h7SchizoidNoPleasure { schizoidTraits.append("few activities give pleasure") }
        if formData.h7SchizoidCold { schizoidTraits.append("emotional coldness and detachment") }
        if formData.h7SchizoidLimitedWarmth { schizoidTraits.append("limited capacity to express warmth or anger") }
        if formData.h7SchizoidIndifferent { schizoidTraits.append("apparent indifference to praise or criticism") }
        if formData.h7SchizoidLittleInterestSex { schizoidTraits.append("little interest in sexual experiences") }
        if formData.h7SchizoidSolitary { schizoidTraits.append("preference for solitary activities") }
        if formData.h7SchizoidFantasy { schizoidTraits.append("excessive preoccupation with fantasy") }
        if formData.h7SchizoidNoConfidants { schizoidTraits.append("no close friends or confiding relationships") }
        if formData.h7SchizoidInsensitive { schizoidTraits.append("insensitivity to social norms") }
        if !schizoidTraits.isEmpty { pdTypeTraits["Schizoid PD"] = schizoidTraits }

        // Histrionic
        var histrionicTraits: [String] = []
        if formData.h7HistrionicAttention { histrionicTraits.append("discomfort when not centre of attention") }
        if formData.h7HistrionicSeductive { histrionicTraits.append("inappropriately seductive or provocative") }
        if formData.h7HistrionicShallowEmotion { histrionicTraits.append("rapidly shifting and shallow emotions") }
        if formData.h7HistrionicAppearance { histrionicTraits.append("uses appearance to draw attention") }
        if formData.h7HistrionicImpressionistic { histrionicTraits.append("impressionistic speech lacking detail") }
        if formData.h7HistrionicDramatic { histrionicTraits.append("self-dramatisation and theatricality") }
        if formData.h7HistrionicSuggestible { histrionicTraits.append("easily influenced by others") }
        if formData.h7HistrionicIntimacy { histrionicTraits.append("considers relationships more intimate than they are") }
        if !histrionicTraits.isEmpty { pdTypeTraits["Histrionic PD"] = histrionicTraits }

        // Anankastic
        var anankasticTraits: [String] = []
        if formData.h7AnankasticDoubt { anankasticTraits.append("excessive doubt and caution") }
        if formData.h7AnankasticDetail { anankasticTraits.append("preoccupation with details, rules, lists") }
        if formData.h7AnankasticPerfectionism { anankasticTraits.append("perfectionism that interferes with completion") }
        if formData.h7AnankasticConscientious { anankasticTraits.append("excessive conscientiousness") }
        if formData.h7AnankasticPleasure { anankasticTraits.append("preoccupation with productivity to exclusion of pleasure") }
        if formData.h7AnankasticPedantic { anankasticTraits.append("excessive pedantry and adherence to convention") }
        if formData.h7AnankasticRigid { anankasticTraits.append("rigidity and stubbornness") }
        if formData.h7AnankasticInsistence { anankasticTraits.append("unreasonable insistence others do things their way") }
        if !anankasticTraits.isEmpty { pdTypeTraits["Anankastic PD"] = anankasticTraits }

        // Anxious
        var anxiousTraits: [String] = []
        if formData.h7AnxiousTension { anxiousTraits.append("persistent feelings of tension and apprehension") }
        if formData.h7AnxiousInferior { anxiousTraits.append("beliefs of social ineptness and inferiority") }
        if formData.h7AnxiousCriticism { anxiousTraits.append("excessive preoccupation with criticism or rejection") }
        if formData.h7AnxiousUnwilling { anxiousTraits.append("unwilling to become involved unless certain of being liked") }
        if formData.h7AnxiousRestricted { anxiousTraits.append("restrictions in lifestyle due to need for security") }
        if formData.h7AnxiousAvoidsActivities { anxiousTraits.append("avoids activities involving significant interpersonal contact") }
        if !anxiousTraits.isEmpty { pdTypeTraits["Anxious (Avoidant) PD"] = anxiousTraits }

        // Dependent
        var dependentTraits: [String] = []
        if formData.h7DependentEncourage { dependentTraits.append("encourages or allows others to make decisions") }
        if formData.h7DependentSubordinates { dependentTraits.append("subordinates own needs to those of others") }
        if formData.h7DependentUnwillingDemands { dependentTraits.append("unwilling to make reasonable demands on others") }
        if formData.h7DependentHelpless { dependentTraits.append("feels uncomfortable or helpless when alone") }
        if formData.h7DependentAbandonment { dependentTraits.append("preoccupied with fears of being left to care for self") }
        if formData.h7DependentLimitedCapacity { dependentTraits.append("limited capacity to make everyday decisions") }
        if !dependentTraits.isEmpty { pdTypeTraits["Dependent PD"] = dependentTraits }

        if pdTypeTraits.isEmpty { return "" }

        // Build text for each PD type with checked traits
        var result: [String] = []
        for (pdType, traits) in pdTypeTraits.sorted(by: { $0.key < $1.key }) {
            result.append("\(pdType): \(subj) demonstrates \(formatList(traits)).")
        }
        return result.joined(separator: "\n\n")
    }

    // Update H7 subsection texts from checkbox states
    private func updateH7SubsectionTexts() {
        // Update PD Features text
        let pdFeaturesText = generateH7AllPDTraitsText()
        formData.h7.subsectionTexts["Personality Disorder Features:"] = pdFeaturesText

        // Update Impact text
        let impactText = generateH7ImpactText()
        formData.h7.subsectionTexts["Impact on Functioning:"] = impactText
    }

    // MARK: - H8 Traumatic Experiences Text Generation
    private func generateH8Text() -> String {
        let gender = formData.patientGender
        let subj = gender == .male ? "He" : "She"
        let poss = gender == .male ? "his" : "her"

        var parts: [String] = []

        // Presence and relevance
        let presenceText: String
        switch formData.h8.presence {
        case .absent: presenceText = "No evidence of significant traumatic experiences"
        case .possible: presenceText = "Partial/possible history of traumatic experiences"
        case .present: presenceText = "Definite history of traumatic experiences"
        case .omit: presenceText = "Insufficient information to rate traumatic experiences"
        }
        parts.append("\(presenceText) (\(formData.h8.presence.rawValue)).")

        if formData.h8.presence != .omit {
            parts.append("Relevance rated as \(formData.h8.relevance.rawValue.lowercased()).")
        }

        // Childhood trauma
        let childhoodText = generateH8ChildhoodText()
        if !childhoodText.isEmpty {
            parts.append("\nCHILDHOOD & DEVELOPMENTAL TRAUMA:\n\(childhoodText)")
        }

        // Adult trauma
        let adultText = generateH8AdultText()
        if !adultText.isEmpty {
            parts.append("\nADULT TRAUMA:\n\(adultText)")
        }

        // Loss & Catastrophe
        let lossText = generateH8LossText()
        if !lossText.isEmpty {
            parts.append("\nLOSS & CATASTROPHE:\n\(lossText)")
        }

        // Sequelae
        let sequelaeText = generateH8SequelaeText()
        if !sequelaeText.isEmpty {
            parts.append("\nPSYCHOLOGICAL SEQUELAE:\n\(sequelaeText)")
        }

        // Trauma narratives
        let narrativeText = generateH8NarrativeText()
        if !narrativeText.isEmpty {
            parts.append("\nTRAUMA NARRATIVES:\n\(narrativeText)")
        }

        // Subsection texts
        for key in ["Childhood Trauma:", "Adult Trauma:", "Loss/Catastrophe:", "Psychological Sequelae:", "Trauma Narratives:"] {
            if let text = formData.h8.subsectionTexts[key], !text.isEmpty {
                parts.append("\n\(key.uppercased())\n\(text)")
            }
        }

        // Imported notes
        let selectedImports = formData.h8.importedEntries.filter { $0.selected }
        if !selectedImports.isEmpty {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "dd/MM/yyyy"
            var importedTexts: [String] = []
            for entry in selectedImports {
                if let date = entry.date {
                    importedTexts.append("[\(dateFormatter.string(from: date))] \(entry.text)")
                } else {
                    importedTexts.append(entry.text)
                }
            }
            parts.append("\n--- Imported Notes ---\n" + importedTexts.joined(separator: "\n"))
        }

        return parts.joined(separator: " ")
    }

    private func generateH8ChildhoodText() -> String {
        var items: [String] = []
        if formData.h8PhysicalAbuse { items.append("physical abuse by caregivers") }
        if formData.h8SexualAbuseChild { items.append("sexual abuse") }
        if formData.h8EmotionalAbuse { items.append("emotional/psychological abuse") }
        if formData.h8WitnessedDV { items.append("witnessed domestic violence") }
        if formData.h8EmotionalNeglect { items.append("emotional neglect") }
        if formData.h8PhysicalNeglect { items.append("physical neglect") }
        if formData.h8InconsistentCare { items.append("inconsistent or absent caregiving") }
        if formData.h8InstitutionalCare { items.append("institutional care instability") }
        if formData.h8ParentalAbandonment { items.append("parental abandonment") }
        if formData.h8ChaoticHousehold { items.append("chaotic household environment") }
        if formData.h8ParentalSubstance { items.append("parental substance misuse") }
        if formData.h8ParentalMentalIllness { items.append("parental mental illness") }
        if formData.h8CriminalCaregivers { items.append("criminal or violent caregivers") }
        if formData.h8PlacementBreakdowns { items.append("repeated placement breakdowns") }

        if items.isEmpty { return "" }
        return "Childhood adversity includes \(formatList(items))."
    }

    private func generateH8AdultText() -> String {
        var items: [String] = []
        if formData.h8AdultAssault { items.append("assaults") }
        if formData.h8SexualAssaultAdult { items.append("sexual assault") }
        if formData.h8RobberyViolence { items.append("robbery with violence") }
        if formData.h8StalkingCoercion { items.append("stalking or coercive control") }
        if formData.h8PrisonViolence { items.append("prison violence") }
        if formData.h8SegregationIsolation { items.append("segregation or prolonged isolation") }
        if formData.h8HospitalVictimisation { items.append("victimisation in hospital or care") }
        if formData.h8BullyingHarassment { items.append("bullying, harassment, or exploitation") }
        if formData.h8OccupationalViolence { items.append("occupational exposure to violence") }
        if formData.h8WitnessedDeath { items.append("witnessing serious injury or death") }
        if formData.h8ThreatsToLife { items.append("threats to life") }

        if items.isEmpty { return "" }
        return "Adult trauma includes \(formatList(items))."
    }

    private func generateH8LossText() -> String {
        var items: [String] = []
        if formData.h8ViolentDeath { items.append("sudden or violent death of close others") }
        if formData.h8MultipleBereavements { items.append("multiple bereavements") }
        if formData.h8WarDisplacement { items.append("war, displacement, or torture") }
        if formData.h8ForcedMigration { items.append("forced migration or asylum-related trauma") }
        if formData.h8SeriousAccidents { items.append("serious accidents") }
        if formData.h8Disasters { items.append("natural or man-made disasters") }

        if items.isEmpty { return "" }
        return "Loss and catastrophe includes \(formatList(items))."
    }

    private func generateH8SequelaeText() -> String {
        var items: [String] = []
        if formData.h8PtsdCptsd { items.append("PTSD or Complex PTSD") }
        if formData.h8Dissociation { items.append("dissociation") }
        if formData.h8Hypervigilance { items.append("hypervigilance") }
        if formData.h8EmotionalDysregulation { items.append("emotional dysregulation") }
        if formData.h8NightmaresFlashbacks { items.append("nightmares or flashbacks") }
        if formData.h8PersistentAnger { items.append("persistent anger or hostility") }
        if formData.h8TriggeredAggression { items.append("aggression when triggered") }
        if formData.h8PoorImpulseControl { items.append("poor impulse control") }
        if formData.h8SubstanceCoping { items.append("substance use as coping") }
        if formData.h8InterpersonalMistrust { items.append("interpersonal mistrust") }
        if formData.h8ThreatReactivity { items.append("reactivity to perceived threat") }

        if items.isEmpty { return "" }
        return "Psychological sequelae include \(formatList(items))."
    }

    private func generateH8NarrativeText() -> String {
        var items: [String] = []
        if formData.h8EveryoneHurts { items.append("\"Everyone has always hurt me\"") }
        if formData.h8FightSurvive { items.append("\"I had to fight to survive\"") }
        if formData.h8CantTrust { items.append("\"You can't trust anyone\"") }
        if formData.h8SystemAbuse { items.append("\"I was treated unfairly by systems\"") }
        if formData.h8GrievanceIdentity { items.append("strong grievance or victim identity") }

        if items.isEmpty { return "" }
        return "Trauma narratives include \(formatList(items))."
    }

    // MARK: - H9 Violent Attitudes Text Generation
    private func generateH9Text() -> String {
        let gender = formData.patientGender
        let subj = gender == .male ? "He" : "She"
        let poss = gender == .male ? "his" : "her"

        var parts: [String] = []

        // Presence and relevance
        let presenceText: String
        switch formData.h9.presence {
        case .absent: presenceText = "No evidence of violent or antisocial attitudes"
        case .possible: presenceText = "Partial/possible evidence of problematic attitudes"
        case .present: presenceText = "Definite evidence of violent or antisocial attitudes"
        case .omit: presenceText = "Insufficient information to rate attitudes"
        }
        parts.append("\(presenceText) (\(formData.h9.presence.rawValue)).")

        if formData.h9.presence != .omit {
            parts.append("Relevance rated as \(formData.h9.relevance.rawValue.lowercased()).")
        }

        // Violent attitudes
        let violentText = generateH9ViolentAttitudesText()
        if !violentText.isEmpty {
            parts.append("\nVIOLENT ATTITUDES:\n\(violentText)")
        }

        // Antisocial attitudes
        let antisocialText = generateH9AntisocialAttitudesText()
        if !antisocialText.isEmpty {
            parts.append("\nANTISOCIAL ATTITUDES:\n\(antisocialText)")
        }

        // Subsection texts
        if let violentManual = formData.h9.subsectionTexts["Violent Attitudes:"], !violentManual.isEmpty {
            parts.append("\nVIOLENT ATTITUDES NOTES:\n\(violentManual)")
        }
        if let antisocialManual = formData.h9.subsectionTexts["Antisocial Attitudes:"], !antisocialManual.isEmpty {
            parts.append("\nANTISOCIAL ATTITUDES NOTES:\n\(antisocialManual)")
        }

        // Imported notes
        let selectedImports = formData.h9.importedEntries.filter { $0.selected }
        if !selectedImports.isEmpty {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "dd/MM/yyyy"
            var importedTexts: [String] = []
            for entry in selectedImports {
                if let date = entry.date {
                    importedTexts.append("[\(dateFormatter.string(from: date))] \(entry.text)")
                } else {
                    importedTexts.append(entry.text)
                }
            }
            parts.append("\n--- Imported Notes ---\n" + importedTexts.joined(separator: "\n"))
        }

        return parts.joined(separator: " ")
    }

    private func generateH9ViolentAttitudesText() -> String {
        var items: [String] = []
        if formData.h9JustifiesViolence { items.append("views violence as acceptable or justified") }
        if formData.h9VictimDeserved { items.append("believes victim deserved or provoked violence") }
        if formData.h9NoChoice { items.append("claims to have had no choice") }
        if formData.h9ViolenceSolves { items.append("sees violence as effective problem-solving") }
        if formData.h9MinimisesHarm { items.append("minimises harm caused to victims") }
        if formData.h9DownplaysSeverity { items.append("downplays seriousness of incidents") }
        if formData.h9DeniesIntent { items.append("denies violent intent despite evidence") }
        if formData.h9BlamesVictim { items.append("blames victim for provoking violence") }
        if formData.h9BlamesOthers { items.append("blames staff, system, or circumstances") }
        if formData.h9ExternalLocus { items.append("attributes violence to external factors") }
        if formData.h9FeelsPersecuted { items.append("expresses persistent sense of persecution") }
        if formData.h9EntitledRespect { items.append("believes entitled to respect through force") }
        if formData.h9HoldsGrudges { items.append("maintains grudges against specific individuals") }
        if formData.h9NoRemorse { items.append("shows no remorse for violent behaviour") }
        if formData.h9IndifferentHarm { items.append("appears indifferent to victim suffering") }
        if formData.h9DismissesImpact { items.append("dismisses impact of violence on others") }

        if items.isEmpty { return "" }
        return "Violent attitudes evident: \(formatList(items))."
    }

    private func generateH9AntisocialAttitudesText() -> String {
        var items: [String] = []
        if formData.h9RulesDontApply { items.append("believes rules do not apply to them") }
        if formData.h9EntitledTake { items.append("feels entitled to take what they want") }
        if formData.h9ExploitsOthers { items.append("views exploitation of others as acceptable") }
        if formData.h9HostileAuthority { items.append("expresses hostility toward authority figures") }
        if formData.h9SystemCorrupt { items.append("views system as corrupt") }
        if formData.h9StaffDeserve { items.append("believes staff deserve mistreatment") }
        if formData.h9LacksEmpathy { items.append("demonstrates lack of empathy") }
        if formData.h9IndifferentConsequences { items.append("indifferent to consequences for others") }
        if formData.h9UsesOthers { items.append("views others as means to an end") }
        if formData.h9RejectsHelp { items.append("rejects need for help or intervention") }
        if formData.h9SuperficialCompliance { items.append("shows only superficial compliance") }
        if formData.h9UnchangedBeliefs { items.append("beliefs remain unchanged despite treatment") }

        if items.isEmpty { return "" }
        return "Antisocial attitudes evident: \(formatList(items))."
    }

    // MARK: - H10 Treatment Response Text Generation
    private func generateH10Text() -> String {
        let gender = formData.patientGender
        let subj = gender == .male ? "He" : "She"
        let Subj = subj.capitalized
        let poss = gender == .male ? "his" : "her"

        var parts: [String] = []

        // Presence and relevance
        let presenceText: String
        switch formData.h10.presence {
        case .absent: presenceText = "No evidence of problems with treatment or supervision response"
        case .possible: presenceText = "Partial/possible evidence of treatment response problems"
        case .present: presenceText = "Definite evidence of problems with treatment or supervision"
        case .omit: presenceText = "Insufficient information to rate treatment response"
        }
        parts.append("\(presenceText) (\(formData.h10.presence.rawValue)).")

        if formData.h10.presence != .omit {
            parts.append("Relevance rated as \(formData.h10.relevance.rawValue.lowercased()).")
        }

        // Generate text for each category
        let medicationText = generateH10MedicationText()
        if !medicationText.isEmpty {
            parts.append("\nMEDICATION NON-ADHERENCE:\n\(medicationText)")
        }

        let disengagementText = generateH10DisengagementText()
        if !disengagementText.isEmpty {
            parts.append("\nDISENGAGEMENT FROM SERVICES:\n\(disengagementText)")
        }

        let hostilityText = generateH10HostilityText()
        if !hostilityText.isEmpty {
            parts.append("\nRESISTANCE/HOSTILITY:\n\(hostilityText)")
        }

        let failureText = generateH10FailureText()
        if !failureText.isEmpty {
            parts.append("\nFAILURE UNDER SUPERVISION:\n\(failureText)")
        }

        let ineffectiveText = generateH10IneffectiveText()
        if !ineffectiveText.isEmpty {
            parts.append("\nINEFFECTIVE INTERVENTIONS:\n\(ineffectiveText)")
        }

        let compulsionText = generateH10CompulsionText()
        if !compulsionText.isEmpty {
            parts.append("\nONLY COMPLIES UNDER COMPULSION:\n\(compulsionText)")
        }

        // Subsection texts
        for key in ["Medication:", "Disengagement:", "Hostility:", "Failure:", "Ineffective:", "Compulsion:"] {
            if let text = formData.h10.subsectionTexts[key], !text.isEmpty {
                parts.append("\n\(key.uppercased()) NOTES:\n\(text)")
            }
        }

        // Imported notes
        let selectedImports = formData.h10.importedEntries.filter { $0.selected }
        if !selectedImports.isEmpty {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "dd/MM/yyyy"
            var importedTexts: [String] = []
            for entry in selectedImports {
                if let date = entry.date {
                    importedTexts.append("[\(dateFormatter.string(from: date))] \(entry.text)")
                } else {
                    importedTexts.append(entry.text)
                }
            }
            parts.append("\n--- Imported Notes ---\n" + importedTexts.joined(separator: "\n"))
        }

        return parts.joined(separator: " ")
    }

    private func generateH10MedicationText() -> String {
        let gender = formData.patientGender
        let subj = gender == .male ? "He" : "She"
        let poss = gender == .male ? "his" : "her"

        var items: [String] = []
        if formData.h10MedNoncompliant { items.append("\(subj) has been non-compliant with medication") }
        if formData.h10MedPoorAdherence { items.append("\(subj) has demonstrated poor adherence to \(poss) treatment regimen") }
        if formData.h10MedFrequentRefusal { items.append("\(subj) frequently refuses medication") }
        if formData.h10MedStoppedWithout { items.append("\(subj) has stopped medication without medical advice") }
        if formData.h10MedIntermittent { items.append("\(subj) shows intermittent compliance with medication") }
        if formData.h10MedRefusedDepot { items.append("\(subj) has refused depot injections") }
        if formData.h10MedSelfDiscontinued { items.append("\(subj) has self-discontinued medication") }
        if formData.h10MedRepeatedStopping { items.append("\(subj) shows a pattern of repeatedly stopping and starting medication") }

        return items.joined(separator: ". ") + (items.isEmpty ? "" : ".")
    }

    private func generateH10DisengagementText() -> String {
        let gender = formData.patientGender
        let subj = gender == .male ? "He" : "She"
        let poss = gender == .male ? "his" : "her"

        var items: [String] = []
        if formData.h10DisDna { items.append("\(subj) has repeatedly failed to attend scheduled appointments") }
        if formData.h10DisDisengaged { items.append("\(subj) has disengaged from mental health services") }
        if formData.h10DisLostFollowup { items.append("\(subj) has been lost to follow-up on multiple occasions") }
        if formData.h10DisPoorEngagement { items.append("\(subj) demonstrates poor engagement with \(poss) care team") }
        if formData.h10DisMinimalMdt { items.append("\(subj) shows minimal engagement with the MDT") }
        if formData.h10DisRefusesCommunity { items.append("\(subj) refuses community follow-up appointments") }
        if formData.h10DisUncontactable { items.append("\(subj) has been uncontactable for prolonged periods") }

        return items.joined(separator: ". ") + (items.isEmpty ? "" : ".")
    }

    private func generateH10HostilityText() -> String {
        let gender = formData.patientGender
        let subj = gender == .male ? "He" : "She"
        let poss = gender == .male ? "his" : "her"

        var items: [String] = []
        if formData.h10HosRefusesEngage { items.append("\(subj) refuses to engage with treatment") }
        if formData.h10HosHostileStaff { items.append("\(subj) has been hostile toward clinical staff") }
        if formData.h10HosDismissive { items.append("\(subj) is dismissive of the value of treatment") }
        if formData.h10HosNoInsight { items.append("\(subj) lacks insight into \(poss) need for treatment") }
        if formData.h10HosNotNecessary { items.append("\(subj) does not believe treatment is necessary") }
        if formData.h10HosRejectsPsych { items.append("\(subj) rejects psychological input") }
        if formData.h10HosUncooperative { items.append("\(subj) has been uncooperative with ward rules") }
        if formData.h10HosOppositional { items.append("\(subj) displays oppositional behaviour toward clinicians") }

        return items.joined(separator: ". ") + (items.isEmpty ? "" : ".")
    }

    private func generateH10FailureText() -> String {
        let gender = formData.patientGender
        let subj = gender == .male ? "He" : "She"
        let poss = gender == .male ? "his" : "her"

        var items: [String] = []
        if formData.h10FailBreachConditions { items.append("\(subj) has breached conditions of supervision") }
        if formData.h10FailBreachCto { items.append("\(subj) has breached \(poss) Community Treatment Order") }
        if formData.h10FailBreachProbation { items.append("\(subj) has breached probation") }
        if formData.h10FailRecall { items.append("\(subj) has been recalled to hospital") }
        if formData.h10FailReturnedCustody { items.append("\(subj) has been returned to custody") }
        if formData.h10FailLicenceBreach { items.append("\(subj) has been non-compliant with licence conditions") }
        if formData.h10FailCommunityPlacement { items.append("\(subj) has had a failed community placement") }
        if formData.h10FailAbsconded { items.append("\(subj) has absconded or gone AWOL") }
        if formData.h10FailRepeatedRecalls { items.append("\(subj) has a history of repeated recalls or breaches") }

        return items.joined(separator: ". ") + (items.isEmpty ? "" : ".")
    }

    private func generateH10IneffectiveText() -> String {
        let gender = formData.patientGender
        let subj = gender == .male ? "He" : "She"

        var items: [String] = []
        if formData.h10InefLittleBenefit { items.append("\(subj) has shown little benefit from treatment") }
        if formData.h10InefLimitedResponse { items.append("\(subj) has had limited response to interventions") }
        if formData.h10InefNoSustained { items.append("There has been no sustained improvement") }
        if formData.h10InefGainsNotMaintained { items.append("Treatment gains have not been maintained") }
        if formData.h10InefRelapseDischarge { items.append("\(subj) has relapsed following discharge") }
        if formData.h10InefRiskEscalated { items.append("Risk has escalated despite treatment") }
        if formData.h10InefRepeatedAdmissions { items.append("\(subj) has had repeated admissions despite support") }

        return items.joined(separator: ". ") + (items.isEmpty ? "" : ".")
    }

    private func generateH10CompulsionText() -> String {
        let gender = formData.patientGender
        let subj = gender == .male ? "He" : "She"

        var items: [String] = []
        if formData.h10CompOnlyUnderSection { items.append("\(subj) is only compliant under section") }
        if formData.h10CompEngagesDetained { items.append("\(subj) engages only when detained") }
        if formData.h10CompDeterioratesCommunity { items.append("\(subj) deteriorates in community settings") }
        if formData.h10CompLegalFramework { items.append("Compliance is contingent on legal framework") }
        if formData.h10CompEnforcedOnly { items.append("\(subj) responds only to enforced treatment") }

        return items.joined(separator: ". ") + (items.isEmpty ? "" : ".")
    }

    // MARK: - Management Section (9, 10, 11) Text Generation

    private func generatePreventionText() -> String {
        var items: [String] = []
        if formData.mgmtMedAdherence { items.append("medication adherence") }
        if formData.mgmtRegularReview { items.append("regular clinical review") }
        if formData.mgmtStructuredRoutine { items.append("structured daily routine") }
        if formData.mgmtStressManagement { items.append("stress management interventions") }
        if formData.mgmtSubstanceControls { items.append("substance use controls and monitoring") }
        if formData.mgmtTherapy { items.append("psychological therapy") }
        if items.isEmpty { return "" }
        return "Preventative strategies include \(formatList(items))."
    }

    private func generateContainmentText() -> String {
        var items: [String] = []
        if formData.mgmtSupervision { items.append("ongoing supervision") }
        if formData.mgmtConditions { items.append("appropriate conditions and boundaries") }
        if formData.mgmtReducedAccess { items.append("reduced access to triggers") }
        if formData.mgmtSupportedAccom { items.append("supported accommodation") }
        if formData.mgmtCurfew { items.append("curfew or time restrictions") }
        if formData.mgmtGeographic { items.append("geographic restrictions") }
        if items.isEmpty { return "" }
        return "For containment we would recommend \(formatList(items))."
    }

    private func generateResponseText() -> String {
        var items: [String] = []
        if formData.mgmtEscalation { items.append("clear escalation pathways") }
        if formData.mgmtCrisisPlan { items.append("crisis plan") }
        if formData.mgmtRecallThreshold { items.append("defined recall or admission thresholds") }
        if formData.mgmtOutOfHours { items.append("out-of-hours response plan") }
        if formData.mgmtPoliceProtocol { items.append("police liaison protocol") }
        if items.isEmpty { return "" }
        return "A well formulated response to increased risk would involve \(formatList(items))."
    }

    private func generateContactReqsText() -> String {
        var items: [String] = []
        if formData.supFaceToFace { items.append("regular face-to-face contact") }
        if formData.supMedMonitoring { items.append("monitoring of medication adherence") }
        if formData.supUrineScreening { items.append("urine screening for substances") }
        if formData.supCurfewChecks { items.append("curfew checks") }
        if formData.supUnannounced { items.append("unannounced visits") }
        if formData.supPhoneCheckins { items.append("regular phone check-ins") }
        if items.isEmpty { return "" }
        return formatList(items)
    }

    private func generateEscalationTriggersText() -> String {
        var items: [String] = []
        if formData.escEngagementDeteriorates { items.append("engagement deteriorates") }
        if formData.escNonCompliance { items.append("non-compliance with conditions") }
        if formData.escWarningSigns { items.append("early warning signs emerge") }
        if formData.escSubstanceRelapse { items.append("substance use relapse") }
        if formData.escMentalState { items.append("mental state deterioration") }
        if formData.escThreats { items.append("threats or aggressive behaviour") }
        if items.isEmpty { return "" }
        return formatListWithOr(items)
    }

    private func generateNamedVictimText() -> String {
        var items: [String] = []
        if formData.vicSeparation { items.append("physical separation from previous victims") }
        if formData.vicNoContact { items.append("no-contact conditions") }
        if formData.vicThirdParty { items.append("third-party monitoring") }
        if formData.vicInfoSharing { items.append("information sharing between agencies") }
        if formData.vicVictimInformed { items.append("victim notification of risk and release") }
        if formData.vicExclusionZone { items.append("exclusion zone around victim locations") }
        if items.isEmpty { return "" }
        return "Victim safety planning should include \(formatList(items))."
    }

    private func generateGeneralSafetyText() -> String {
        var items: [String] = []
        if formData.vicEnvControls { items.append("environmental controls") }
        if formData.vicStaffSafety { items.append("staff safety planning") }
        if formData.vicConflictAvoid { items.append("conflict avoidance strategies") }
        if formData.vicDeEscalation { items.append("de-escalation protocols") }
        if formData.vicRestrictedAccess { items.append("restricted access to vulnerable groups") }
        if formData.vicPublicProtection { items.append("public protection measures") }
        if items.isEmpty { return "" }
        // Check if named victim text exists for proper sentence prefix
        let namedText = generateNamedVictimText()
        if !namedText.isEmpty {
            return "General safeguarding includes \(formatList(items))."
        } else {
            return "Safeguarding planning should include \(formatList(items))."
        }
    }
}

// MARK: - Shared Components are defined in MOJASRFormView.swift and FormComponents.swift
// ImportedDataSection, ImportedEntryRow, CheckboxToggleStyle, Color(hex:), InfoBox
