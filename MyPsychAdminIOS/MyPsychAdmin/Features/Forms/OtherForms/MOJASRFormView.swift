//
//  MOJASRFormView.swift
//  MyPsychAdmin
//
//  MOJ Annual Statutory Report Form for Restricted Patients
//  Based on MOJ_ASR_template.docx structure (17 sections)
//  Matches desktop: Cards with free text + separate popups for controls
//

import SwiftUI
import UniformTypeIdentifiers
import Combine

struct MOJASRFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var appStore
    @Environment(SharedDataStore.self) private var sharedData

    @State private var formData: MOJASRFormData
    @State private var validationErrors: [FormValidationError] = []

    // Card text content - split into generated (from controls) and manual notes
    @State private var generatedTexts: [ASRSection: String] = [:]
    @State private var manualNotes: [ASRSection: String] = [:]

    // Popup control
    @State private var activePopup: ASRSection? = nil

    // Export states
    @State private var docxURL: URL?
    @State private var isExporting = false
    @State private var showShareSheet = false
    @State private var exportError: String?

    // Import states
    @State private var showingImportPicker = false
    // Note: Removed showingImportTypeSheet and importDocumentType - now auto-detects like Leave form
    @State private var isImporting = false
    @State private var importStatusMessage: String?
    @State private var hasPopulatedFromSharedData = false

    // 17 Sections matching desktop MOJ ASR Form
    enum ASRSection: String, CaseIterable, Identifiable {
        case patientDetails = "1. Patient Details"
        case rcDetails = "2. Responsible Clinician"
        case mentalDisorder = "3. Mental Disorder"
        case attitudeBehaviour = "4. Attitude & Behaviour"
        case addressingIssues = "5. Addressing Issues"
        case patientAttitude = "6. Patient's Attitude"
        case capacity = "7. Capacity Issues"
        case progress = "8. Progress"
        case managingRisk = "9. Managing Risk"
        case riskAddressed = "10. How Risks Addressed"
        case abscond = "11. Abscond / Escape"
        case mappa = "12. MAPPA"
        case victims = "13. Victims"
        case leaveReport = "14. Leave Report"
        case additionalComments = "15. Additional Comments"
        case unfitToPlead = "16. Unfit to Plead"
        case signature = "Signature"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .patientDetails: return "person"
            case .rcDetails: return "stethoscope"
            case .mentalDisorder: return "brain.head.profile"
            case .attitudeBehaviour: return "person.wave.2"
            case .addressingIssues: return "checkmark.circle"
            case .patientAttitude: return "face.smiling"
            case .capacity: return "brain"
            case .progress: return "chart.line.uptrend.xyaxis"
            case .managingRisk: return "exclamationmark.shield"
            case .riskAddressed: return "shield.checkered"
            case .abscond: return "figure.run"
            case .mappa: return "person.badge.shield.checkmark"
            case .victims: return "person.crop.circle.badge.exclamationmark"
            case .leaveReport: return "figure.walk"
            case .additionalComments: return "text.bubble"
            case .unfitToPlead: return "checkmark.seal"
            case .signature: return "signature"
            }
        }

        var defaultHeight: CGFloat {
            switch self {
            case .patientDetails, .rcDetails, .signature: return 120
            case .mentalDisorder, .attitudeBehaviour, .addressingIssues, .patientAttitude: return 180
            case .progress, .leaveReport: return 200
            default: return 150
            }
        }
    }

    // No persistence - form data is session-only (matching Leave form behavior)
    init() {
        _formData = State(initialValue: MOJASRFormData())
        _generatedTexts = State(initialValue: [:])
        _manualNotes = State(initialValue: [:])
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
                    ForEach(ASRSection.allCases) { section in
                        ASREditableCard(
                            section: section,
                            text: binding(for: section),
                            onHeaderTap: { activePopup = section }
                        )
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("MOJ ASR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        // Import status message
                        if let message = importStatusMessage {
                            Text(message)
                                .font(.caption)
                                .foregroundColor(.green)
                        }

                        // Import button - directly shows file picker (auto-detects type like Leave form)
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

                        // Export button
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
            // Populate from SharedDataStore notes if available
            if !hasPopulatedFromSharedData && !sharedData.notes.isEmpty {
                populateFromClinicalNotes(sharedData.notes)
                hasPopulatedFromSharedData = true
            }
        }
        .onReceive(sharedData.notesDidChange) { notes in
            // Auto-populate when notes are updated in SharedDataStore
            if !notes.isEmpty {
                populateFromClinicalNotes(notes)
            }
        }
        .sheet(item: $activePopup) { section in
            ASRPopupView(
                section: section,
                formData: $formData,
                manualNotes: manualNotes[section] ?? "",
                onGenerate: { generatedText, notes in
                    // Update generated text (replaces previous generated)
                    // Preserve/update manual notes
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
        // Note: Removed import type confirmation dialog - now auto-detects like Leave form
        // DocumentProcessor handles all file types automatically
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

    private func binding(for section: ASRSection) -> Binding<String> {
        Binding(
            get: {
                // Combine generated text and manual notes for display
                let generated = generatedTexts[section] ?? ""
                let manual = manualNotes[section] ?? ""
                if generated.isEmpty && manual.isEmpty { return "" }
                if generated.isEmpty { return manual }
                if manual.isEmpty { return generated }
                return generated + "\n\n" + manual
            },
            set: { newValue in
                // When user edits the card directly, update manual notes
                // Keep generated text intact, treat everything after it as manual
                let generated = generatedTexts[section] ?? ""
                if generated.isEmpty {
                    manualNotes[section] = newValue
                } else if newValue.hasPrefix(generated) {
                    // User kept generated text, extract manual portion
                    let afterGenerated = String(newValue.dropFirst(generated.count))
                    manualNotes[section] = afterGenerated.trimmingCharacters(in: .whitespacesAndNewlines)
                } else {
                    // User modified generated text - treat whole thing as manual
                    manualNotes[section] = newValue
                    generatedTexts[section] = ""
                }
            }
        )
    }

    private func initializeCardTexts() {
        // Initialize with empty values
        for section in ASRSection.allCases {
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
            formData.rcName = appStore.clinicianInfo.fullName
            formData.rcEmail = appStore.clinicianInfo.email
            formData.rcPhone = appStore.clinicianInfo.phone
            formData.rcJobTitle = appStore.clinicianInfo.roleTitle
            formData.hospitalName = appStore.clinicianInfo.hospitalOrg
        }
    }

    private func exportDOCX() {
        // Sync card texts back to formData for export
        syncCardTextsToFormData()

        validationErrors = formData.validate()
        guard validationErrors.isEmpty else { return }

        isExporting = true
        exportError = nil

        DispatchQueue.global(qos: .userInitiated).async {
            let data = MOJASRFormDOCXExporter(formData: formData).generateDOCX()

            DispatchQueue.main.async {
                isExporting = false

                guard let docxData = data else {
                    exportError = "Failed to generate document"
                    return
                }

                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
                let patientName = formData.patientName.isEmpty ? "Patient" : formData.patientName.replacingOccurrences(of: " ", with: "_")
                let filename = "MOJ_ASR_\(patientName)_\(dateFormatter.string(from: Date())).docx"
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

            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                exportError = "Cannot access file"
                return
            }

            isImporting = true
            importStatusMessage = "Processing file..."

            // Process the file using DocumentProcessor
            Task {
                defer {
                    url.stopAccessingSecurityScopedResource()
                }

                do {
                    // Copy file to temporary location for processing
                    let tempDir = FileManager.default.temporaryDirectory
                    let tempURL = tempDir.appendingPathComponent(url.lastPathComponent)

                    // Remove existing temp file if present
                    try? FileManager.default.removeItem(at: tempURL)
                    try FileManager.default.copyItem(at: url, to: tempURL)

                    // Use DocumentProcessor to parse the file (like desktop)
                    let extractedDoc = try await DocumentProcessor.shared.processDocument(at: tempURL)

                    await MainActor.run {
                        // Store notes in SharedDataStore (so other forms can use them too)
                        if !extractedDoc.notes.isEmpty {
                            sharedData.setNotes(extractedDoc.notes, source: "moj_asr_import")
                        }

                        // Update patient info if extracted
                        if !extractedDoc.patientInfo.fullName.isEmpty {
                            formData.patientName = extractedDoc.patientInfo.fullName
                            if let dob = extractedDoc.patientInfo.dateOfBirth {
                                formData.patientDOB = dob
                            }
                            formData.patientGender = extractedDoc.patientInfo.gender
                        }

                        // Populate imported entries from notes
                        populateFromClinicalNotes(extractedDoc.notes)

                        isImporting = false
                        let noteCount = extractedDoc.notes.count
                        importStatusMessage = "Imported \(noteCount) notes"

                        // Clear message after delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            importStatusMessage = nil
                        }
                    }

                    // Clean up temp file
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

    // MARK: - Populate from Clinical Notes (SharedDataStore or Import)

    /// Populate all section imported entries from ClinicalNote array
    /// Matches desktop's populate_popup_*_imports behavior
    private func populateFromClinicalNotes(_ notes: [ClinicalNote]) {
        guard !notes.isEmpty else { return }

        print("[MOJ-ASR iOS] Populating from \(notes.count) clinical notes")

        // Clear existing imported entries
        formData.behaviourImportedEntries.removeAll()
        formData.patientAttitudeImportedEntries.removeAll()
        formData.capacityImportedEntries.removeAll()
        formData.progressImportedEntries.removeAll()
        formData.riskImportedEntries.removeAll()
        formData.riskAddressedImportedEntries.removeAll()
        formData.abscondImportedEntries.removeAll()
        formData.mappaImportedEntries.removeAll()
        formData.victimsImportedEntries.removeAll()
        formData.leaveReportImportedEntries.removeAll()

        print("[MOJ-ASR iOS] Processing all \(notes.count) notes")

        // Calculate 12-month cutoff for Sections 4 & 6 - matching Desktop
        // Find the latest note date first, then calculate cutoff from that
        let latestNoteDate = notes.compactMap { $0.date }.max() ?? Date()
        let twelveMoCutoff = Calendar.current.date(byAdding: .year, value: -1, to: latestNoteDate) ?? Date.distantPast
        print("[MOJ-ASR iOS] 12-month cutoff date: \(twelveMoCutoff) (for Sections 4 & 6)")

        // Process each note and categorize
        for note in notes {
            let text = note.body
            let date = note.date
            let snippet = text.count > 150 ? String(text.prefix(150)) + "..." : text

            // Categorize using ASRCategoryKeywords (matches desktop)
            // Section 4 (behaviour) uses false positive filtering to exclude entries like "no aggression noted"
            let behaviourCats = ASRCategoryKeywords.categorize(text, using: ASRCategoryKeywords.behaviour, useFalsePositiveFiltering: true)
            let attitudeCats = ASRCategoryKeywords.categorize(text, using: ASRCategoryKeywords.patientAttitude)
            let capacityCats = ASRCategoryKeywords.categorize(text, using: ASRCategoryKeywords.capacity)
            let progressCats = ASRCategoryKeywords.categorize(text, using: ASRCategoryKeywords.progress)
            let riskCats = ASRCategoryKeywords.categorize(text, using: ASRCategoryKeywords.managingRisk)
            let riskAddressedCats = ASRCategoryKeywords.categorize(text, using: ASRCategoryKeywords.riskAddressed)
            let abscondCats = ASRCategoryKeywords.categorize(text, using: ASRCategoryKeywords.abscond)
            let mappaCats = ASRCategoryKeywords.categorize(text, using: ASRCategoryKeywords.mappa)
            let victimsCats = ASRCategoryKeywords.categorize(text, using: ASRCategoryKeywords.victims)
            let leaveCats = ASRCategoryKeywords.categorize(text, using: ASRCategoryKeywords.leaveReport)

            // Add to sections where categories match
            // Section 4 (Behaviour) - ONLY last 12 months (matching Desktop)
            if !behaviourCats.isEmpty {
                let noteDate = date ?? Date.distantPast
                if noteDate >= twelveMoCutoff {
                    formData.behaviourImportedEntries.append(ASRImportedEntry(date: date, text: text, categories: behaviourCats, snippet: snippet))
                }
            }
            // Section 6 (Patient Attitude) - ONLY last 12 months (matching Desktop)
            if !attitudeCats.isEmpty {
                let noteDate = date ?? Date.distantPast
                if noteDate >= twelveMoCutoff {
                    formData.patientAttitudeImportedEntries.append(ASRImportedEntry(date: date, text: text, categories: attitudeCats, snippet: snippet))
                }
            }
            // Section 7 (Capacity) - ONLY last 12 months (matching Desktop)
            if !capacityCats.isEmpty {
                let noteDate = date ?? Date.distantPast
                if noteDate >= twelveMoCutoff {
                    formData.capacityImportedEntries.append(ASRImportedEntry(date: date, text: text, categories: capacityCats, snippet: snippet))
                }
            }
            // Section 8 (Progress) - ONLY last 12 months (matching Desktop)
            if !progressCats.isEmpty {
                let noteDate = date ?? Date.distantPast
                if noteDate >= twelveMoCutoff {
                    formData.progressImportedEntries.append(ASRImportedEntry(date: date, text: text, categories: progressCats, snippet: snippet))
                }
            }
            if !riskCats.isEmpty {
                formData.riskImportedEntries.append(ASRImportedEntry(date: date, text: text, categories: riskCats, snippet: snippet))
            }
            // Section 10 (How Risks Addressed) - ONLY last 12 months (matching Desktop)
            if !riskAddressedCats.isEmpty {
                let noteDate = date ?? Date.distantPast
                if noteDate >= twelveMoCutoff {
                    formData.riskAddressedImportedEntries.append(ASRImportedEntry(date: date, text: text, categories: riskAddressedCats, snippet: snippet))
                }
            }
            // Section 11 (Abscond/Escape) - ONLY last 12 months (matching Desktop)
            if !abscondCats.isEmpty {
                let noteDate = date ?? Date.distantPast
                if noteDate >= twelveMoCutoff {
                    formData.abscondImportedEntries.append(ASRImportedEntry(date: date, text: text, categories: abscondCats, snippet: snippet))
                }
            }
            // Section 12 (MAPPA) - ONLY last 12 months (matching Desktop)
            if !mappaCats.isEmpty {
                let noteDate = date ?? Date.distantPast
                if noteDate >= twelveMoCutoff {
                    formData.mappaImportedEntries.append(ASRImportedEntry(date: date, text: text, categories: mappaCats, snippet: snippet))
                }
            }
            if !victimsCats.isEmpty {
                formData.victimsImportedEntries.append(ASRImportedEntry(date: date, text: text, categories: victimsCats, snippet: snippet))
            }
            // Section 14 (Leave Report) - ONLY last 12 months (matching Desktop)
            if !leaveCats.isEmpty {
                let noteDate = date ?? Date.distantPast
                if noteDate >= twelveMoCutoff {
                    formData.leaveReportImportedEntries.append(ASRImportedEntry(date: date, text: text, categories: leaveCats, snippet: snippet))
                }
            }
        }

        // Sort each array by date (most recent first)
        formData.behaviourImportedEntries.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.patientAttitudeImportedEntries.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.capacityImportedEntries.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.progressImportedEntries.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.riskImportedEntries.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.riskAddressedImportedEntries.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.abscondImportedEntries.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.mappaImportedEntries.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.victimsImportedEntries.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.leaveReportImportedEntries.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }

        print("[MOJ-ASR iOS] Populated: behaviour=\(formData.behaviourImportedEntries.count), attitude=\(formData.patientAttitudeImportedEntries.count), capacity=\(formData.capacityImportedEntries.count), progress=\(formData.progressImportedEntries.count), risk=\(formData.riskImportedEntries.count), abscond=\(formData.abscondImportedEntries.count), mappa=\(formData.mappaImportedEntries.count), victims=\(formData.victimsImportedEntries.count), leave=\(formData.leaveReportImportedEntries.count)")

        // === Section 3: Auto-fill ICD-10 diagnoses from notes (matching Desktop and Leave form) ===
        extractAndFillDiagnoses(notes)
    }

    // MARK: - Extract and Auto-fill ICD-10 Diagnoses (matching Desktop/Leave form logic)
    private func extractAndFillDiagnoses(_ notes: [ClinicalNote]) {
        // Combine all note text for diagnosis extraction
        var documentText = ""
        for note in notes.prefix(500) {
            documentText += note.body + "\n"
        }

        let docLower = documentText.lowercased()
        var extractedDiagnoses: [ICD10Diagnosis] = []
        var matchedCategories = Set<String>()

        // Diagnosis patterns with direct ICD10Diagnosis enum mapping (matching Desktop DIAGNOSIS_PATTERNS)
        let diagnosisPatterns: [(pattern: String, diagnosis: ICD10Diagnosis, category: String)] = [
            // Schizophrenia variants
            ("paranoid schizophrenia", .f200, "schizophrenia"),
            ("catatonic schizophrenia", .f202, "schizophrenia"),
            ("hebephrenic schizophrenia", .f201, "schizophrenia"),
            ("residual schizophrenia", .f205, "schizophrenia"),
            ("simple schizophrenia", .f206, "schizophrenia"),
            ("undifferentiated schizophrenia", .f203, "schizophrenia"),
            ("schizoaffective", .f259, "schizoaffective"),
            ("schizophrenia", .f209, "schizophrenia"),
            // Mood disorders
            ("bipolar affective disorder", .f319, "bipolar"),
            ("bipolar disorder", .f319, "bipolar"),
            ("manic depressi", .f319, "bipolar"),
            ("recurrent depressi", .f339, "depression"),
            ("major depressi", .f329, "depression"),
            ("depressi", .f329, "depression"),
            // Personality disorders
            ("emotionally unstable personality", .f603, "personality"),
            ("borderline personality", .f603, "personality"),
            ("antisocial personality", .f602, "personality"),
            ("dissocial personality", .f602, "personality"),
            ("paranoid personality", .f600, "personality"),
            ("personality disorder", .f609, "personality"),
            // Anxiety
            ("generalised anxiety", .f411, "anxiety"),
            ("generalized anxiety", .f411, "anxiety"),
            ("ptsd", .f431, "ptsd"),
            ("post-traumatic stress", .f431, "ptsd"),
            ("post traumatic stress", .f431, "ptsd"),
            // Psychosis
            ("acute psycho", .f23, "psychosis"),
            // Learning disability
            ("learning disabilit", .f79, "learning"),
            ("intellectual disabilit", .f79, "learning"),
            // Substance
            ("alcohol dependence", .f10, "alcohol"),
            ("opioid dependence", .f11, "drugs"),
        ]

        // Search for diagnosis patterns
        for (pattern, diagnosis, category) in diagnosisPatterns {
            // Skip if we've already matched this category
            if matchedCategories.contains(category) {
                continue
            }

            if docLower.contains(pattern) {
                extractedDiagnoses.append(diagnosis)
                matchedCategories.insert(category)
                print("[MOJ-ASR] Matched diagnosis: '\(pattern)' -> '\(diagnosis.rawValue)'")

                // Limit to 3 diagnoses
                if extractedDiagnoses.count >= 3 {
                    break
                }
            }
        }

        print("[MOJ-ASR] Extracted \(extractedDiagnoses.count) diagnoses for ICD-10 auto-fill")

        // Auto-fill the ICD-10 pickers if they're .none (not set)
        if extractedDiagnoses.count > 0 && formData.diagnosis1ICD10 == .none {
            formData.diagnosis1ICD10 = extractedDiagnoses[0]
            print("[MOJ-ASR] Set primary diagnosis: \(extractedDiagnoses[0].rawValue)")
        }
        if extractedDiagnoses.count > 1 && formData.diagnosis2ICD10 == .none {
            formData.diagnosis2ICD10 = extractedDiagnoses[1]
            print("[MOJ-ASR] Set secondary diagnosis: \(extractedDiagnoses[1].rawValue)")
        }
        if extractedDiagnoses.count > 2 && formData.diagnosis3ICD10 == .none {
            formData.diagnosis3ICD10 = extractedDiagnoses[2]
            print("[MOJ-ASR] Set tertiary diagnosis: \(extractedDiagnoses[2].rawValue)")
        }
    }

    // Legacy method for plain text import fallback
    private func processImportedText(_ text: String) {
        // Split text into entries (by date pattern or paragraph)
        let datePattern = /\d{1,2}\/\d{1,2}\/\d{2,4}/
        let lines = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        var entries: [(date: Date?, text: String)] = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"

        var currentEntry = ""
        var currentDate: Date? = nil

        for line in lines {
            if let match = line.firstMatch(of: datePattern) {
                // Save previous entry
                if !currentEntry.isEmpty {
                    entries.append((currentDate, currentEntry.trimmingCharacters(in: .whitespacesAndNewlines)))
                }
                // Parse date and start new entry
                let dateStr = String(match.output)
                currentDate = dateFormatter.date(from: dateStr)
                currentEntry = line
            } else {
                currentEntry += " " + line
            }
        }
        // Save last entry
        if !currentEntry.isEmpty {
            entries.append((currentDate, currentEntry.trimmingCharacters(in: .whitespacesAndNewlines)))
        }

        // If no date-based entries, treat whole text as one entry per paragraph
        if entries.isEmpty {
            let paragraphs = text.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            entries = paragraphs.map { (nil, $0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        }

        // Notes: categorize and add to imported entries
        processAsNotes(entries)
    }

    private func processAsNotes(_ entries: [(date: Date?, text: String)]) {
        // Calculate 12-month cutoff for Sections 4 & 6 - matching Desktop
        let latestEntryDate = entries.compactMap { $0.date }.max() ?? Date()
        let twelveMoCutoff = Calendar.current.date(byAdding: .year, value: -1, to: latestEntryDate) ?? Date.distantPast

        // Categorize each entry and add to appropriate section's imported entries
        for (date, text) in entries {
            // Check each section's keywords
            // Section 4 (behaviour) uses false positive filtering to exclude entries like "no aggression noted"
            let behaviourCats = ASRCategoryKeywords.categorize(text, using: ASRCategoryKeywords.behaviour, useFalsePositiveFiltering: true)
            let attitudeCats = ASRCategoryKeywords.categorize(text, using: ASRCategoryKeywords.patientAttitude)
            let capacityCats = ASRCategoryKeywords.categorize(text, using: ASRCategoryKeywords.capacity)
            let progressCats = ASRCategoryKeywords.categorize(text, using: ASRCategoryKeywords.progress)
            let riskCats = ASRCategoryKeywords.categorize(text, using: ASRCategoryKeywords.managingRisk)
            let riskAddressedCats = ASRCategoryKeywords.categorize(text, using: ASRCategoryKeywords.riskAddressed)
            let abscondCats = ASRCategoryKeywords.categorize(text, using: ASRCategoryKeywords.abscond)
            let mappaCats = ASRCategoryKeywords.categorize(text, using: ASRCategoryKeywords.mappa)
            let victimsCats = ASRCategoryKeywords.categorize(text, using: ASRCategoryKeywords.victims)
            let leaveCats = ASRCategoryKeywords.categorize(text, using: ASRCategoryKeywords.leaveReport)

            let snippet = text.count > 150 ? String(text.prefix(150)) + "..." : text

            // Add to sections where categories match
            // Section 4 (Behaviour) - ONLY last 12 months (matching Desktop)
            if !behaviourCats.isEmpty {
                let noteDate = date ?? Date.distantPast
                if noteDate >= twelveMoCutoff {
                    formData.behaviourImportedEntries.append(ASRImportedEntry(date: date, text: text, categories: behaviourCats, snippet: snippet))
                }
            }
            // Section 6 (Patient Attitude) - ONLY last 12 months (matching Desktop)
            if !attitudeCats.isEmpty {
                let noteDate = date ?? Date.distantPast
                if noteDate >= twelveMoCutoff {
                    formData.patientAttitudeImportedEntries.append(ASRImportedEntry(date: date, text: text, categories: attitudeCats, snippet: snippet))
                }
            }
            // Section 7 (Capacity) - ONLY last 12 months (matching Desktop)
            if !capacityCats.isEmpty {
                let noteDate = date ?? Date.distantPast
                if noteDate >= twelveMoCutoff {
                    formData.capacityImportedEntries.append(ASRImportedEntry(date: date, text: text, categories: capacityCats, snippet: snippet))
                }
            }
            // Section 8 (Progress) - ONLY last 12 months (matching Desktop)
            if !progressCats.isEmpty {
                let noteDate = date ?? Date.distantPast
                if noteDate >= twelveMoCutoff {
                    formData.progressImportedEntries.append(ASRImportedEntry(date: date, text: text, categories: progressCats, snippet: snippet))
                }
            }
            if !riskCats.isEmpty {
                formData.riskImportedEntries.append(ASRImportedEntry(date: date, text: text, categories: riskCats, snippet: snippet))
            }
            // Section 10 (How Risks Addressed) - ONLY last 12 months (matching Desktop)
            if !riskAddressedCats.isEmpty {
                let noteDate = date ?? Date.distantPast
                if noteDate >= twelveMoCutoff {
                    formData.riskAddressedImportedEntries.append(ASRImportedEntry(date: date, text: text, categories: riskAddressedCats, snippet: snippet))
                }
            }
            // Section 11 (Abscond/Escape) - ONLY last 12 months (matching Desktop)
            if !abscondCats.isEmpty {
                let noteDate = date ?? Date.distantPast
                if noteDate >= twelveMoCutoff {
                    formData.abscondImportedEntries.append(ASRImportedEntry(date: date, text: text, categories: abscondCats, snippet: snippet))
                }
            }
            // Section 12 (MAPPA) - ONLY last 12 months (matching Desktop)
            if !mappaCats.isEmpty {
                let noteDate = date ?? Date.distantPast
                if noteDate >= twelveMoCutoff {
                    formData.mappaImportedEntries.append(ASRImportedEntry(date: date, text: text, categories: mappaCats, snippet: snippet))
                }
            }
            if !victimsCats.isEmpty {
                formData.victimsImportedEntries.append(ASRImportedEntry(date: date, text: text, categories: victimsCats, snippet: snippet))
            }
            // Section 14 (Leave Report) - ONLY last 12 months (matching Desktop)
            if !leaveCats.isEmpty {
                let noteDate = date ?? Date.distantPast
                if noteDate >= twelveMoCutoff {
                    formData.leaveReportImportedEntries.append(ASRImportedEntry(date: date, text: text, categories: leaveCats, snippet: snippet))
                }
            }
        }
    }

    private func syncCardTextsToFormData() {
        // Combine generated + manual notes for each section
        func combinedText(for section: ASRSection) -> String {
            let generated = generatedTexts[section] ?? ""
            let manual = manualNotes[section] ?? ""
            if generated.isEmpty && manual.isEmpty { return "" }
            if generated.isEmpty { return manual }
            if manual.isEmpty { return generated }
            return generated + "\n\n" + manual
        }

        formData.clinicalDescription = combinedText(for: .mentalDisorder)
        formData.behaviourNotes = combinedText(for: .attitudeBehaviour)
        formData.addressingIssuesNotes = combinedText(for: .addressingIssues)
        formData.offendingDetails = combinedText(for: .patientAttitude)
        formData.capacityNotes = combinedText(for: .capacity)
        formData.managingRiskText = combinedText(for: .managingRisk)
        formData.riskAddressedText = combinedText(for: .riskAddressed)
        formData.abscondText = combinedText(for: .abscond)
        formData.mappaText = combinedText(for: .mappa)
        formData.victimsText = combinedText(for: .victims)
        formData.additionalCommentsText = combinedText(for: .additionalComments)
        formData.unfitToPleadText = combinedText(for: .unfitToPlead)
    }
}

// MARK: - Editable Card (like desktop ASRCardWidget)
struct ASREditableCard: View {
    let section: MOJASRFormView.ASRSection
    @Binding var text: String
    let onHeaderTap: () -> Void

    @State private var editorHeight: CGFloat = 150

    var body: some View {
        VStack(spacing: 0) {
            // Header - tappable to open popup
            Button(action: onHeaderTap) {
                HStack(spacing: 10) {
                    Image(systemName: section.icon)
                        .foregroundColor(.red)
                        .frame(width: 20)

                    Text(section.rawValue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(.red)
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
}

// MARK: - Resize Handle
struct ResizeHandle: View {
    @Binding var height: CGFloat
    @GestureState private var dragOffset: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(Color(.systemGray4))
            .frame(height: 8)
            .frame(maxWidth: 60)
            .cornerRadius(4)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(Color(.systemGray6))
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation.height
                    }
                    .onChanged { value in
                        let newHeight = max(80, min(400, height + value.translation.height))
                        height = newHeight
                    }
            )
    }
}

// MARK: - Popup View
struct ASRPopupView: View {
    let section: MOJASRFormView.ASRSection
    @Binding var formData: MOJASRFormData
    let manualNotes: String
    let onGenerate: (String, String) -> Void  // (generatedText, manualNotes)
    let onDismiss: () -> Void

    @State private var editableNotes: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    popupContent

                    // Manual notes section (shown for sections 1-9 only)
                    if ![.riskAddressed, .abscond, .mappa, .victims, .leaveReport, .additionalComments, .unfitToPlead, .signature].contains(section) {
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
        case .rcDetails: rcDetailsPopup
        case .mentalDisorder: mentalDisorderPopup
        case .attitudeBehaviour: attitudeBehaviourPopup
        case .addressingIssues: addressingIssuesPopup
        case .patientAttitude: patientAttitudePopup
        case .capacity: capacityPopup
        case .progress: progressPopup
        case .managingRisk: managingRiskPopup
        case .riskAddressed: riskAddressedPopup
        case .abscond: abscondPopup
        case .mappa: mappaPopup
        case .victims: victimsPopup
        case .leaveReport: leaveReportPopup
        case .additionalComments: additionalCommentsPopup
        case .unfitToPlead: unfitToPleadPopup
        case .signature: signaturePopup
        }
    }

    // MARK: - Section 1: Patient Details
    private var patientDetailsPopup: some View {
        VStack(alignment: .leading, spacing: 12) {
            FormTextField(label: "Patient Name", text: $formData.patientName, isRequired: true)
            FormOptionalDatePicker(label: "Date of Birth", date: $formData.patientDOB, maxDate: Date())

            HStack {
                Text("Gender").font(.subheadline).foregroundColor(.secondary)
                Spacer()
                Picker("", selection: $formData.patientGender) {
                    ForEach(Gender.allCases) { g in Text(g.rawValue).tag(g) }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }

            FormTextField(label: "NHS Number", text: $formData.nhsNumber)
            FormTextField(label: "Hospital", text: $formData.hospitalName)
            FormTextField(label: "MHCS Reference", text: $formData.mhcsRef)

            HStack {
                Text("MHA Section").font(.subheadline).foregroundColor(.secondary)
                Spacer()
                Picker("", selection: $formData.mhaSection) {
                    Text("S37/41").tag("S37/41")
                    Text("S45a").tag("S45a")
                    Text("S47/49").tag("S47/49")
                    Text("CPI - unfit").tag("CPI - unfit to plead")
                    Text("DVCV").tag("DVCV")
                }
                .pickerStyle(.menu)
            }

            FormOptionalDatePicker(label: "Section Date", date: $formData.mhaSectionDate)
        }
    }

    // MARK: - Section 2: RC Details
    private var rcDetailsPopup: some View {
        VStack(alignment: .leading, spacing: 12) {
            FormTextField(label: "RC Name", text: $formData.rcName, isRequired: true)
            FormTextField(label: "Job Title", text: $formData.rcJobTitle)
            FormTextField(label: "Phone", text: $formData.rcPhone, keyboardType: .phonePad)
            FormTextField(label: "Email", text: $formData.rcEmail, keyboardType: .emailAddress)
            FormTextField(label: "MHA Office Email", text: $formData.mhaOfficeEmail, keyboardType: .emailAddress)
        }
    }

    // MARK: - Section 3: Mental Disorder
    private var mentalDisorderPopup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ICD-10 Diagnoses").font(.headline)

            ICD10DiagnosisPicker(label: "Primary Diagnosis", selectedDiagnosis: $formData.diagnosis1ICD10, customDiagnosis: $formData.diagnosis1Custom)
            ICD10DiagnosisPicker(label: "Secondary Diagnosis", selectedDiagnosis: $formData.diagnosis2ICD10, customDiagnosis: $formData.diagnosis2Custom)
            ICD10DiagnosisPicker(label: "Third Diagnosis", selectedDiagnosis: $formData.diagnosis3ICD10, customDiagnosis: $formData.diagnosis3Custom)

            Divider()

            Text("Clinical Description").font(.subheadline).foregroundColor(.secondary)
            TextEditor(text: $formData.clinicalDescription)
                .frame(minHeight: 100)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
    }

    // MARK: - Section 4: Attitude & Behaviour
    private var attitudeBehaviourPopup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Behaviour Categories (last 12 months)").font(.headline)

            BehaviourCategoryRow(label: "Verbal/physical aggression", item: $formData.verbalPhysicalAggression)
            BehaviourCategoryRow(label: "Substance abuse", item: $formData.substanceAbuse)
            BehaviourCategoryRow(label: "Self-harm", item: $formData.selfHarm)
            BehaviourCategoryRow(label: "Fire-setting", item: $formData.fireSetting)
            BehaviourCategoryRow(label: "Intimidation/threats", item: $formData.intimidation)
            BehaviourCategoryRow(label: "Secretive/manipulative", item: $formData.secretiveManipulative)
            BehaviourCategoryRow(label: "Subversive behaviour", item: $formData.subversiveBehaviour)
            BehaviourCategoryRow(label: "Sexually disinhibited", item: $formData.sexuallyDisinhibited)
            BehaviourCategoryRow(label: "Extremist behaviour", item: $formData.extremistBehaviour)
            BehaviourCategoryRow(label: "Periods of seclusion", item: $formData.seclusionPeriods)

            // Imported Data Section
            ImportedDataSection(
                title: "Imported Notes",
                entries: $formData.behaviourImportedEntries,
                categoryKeywords: ASRCategoryKeywords.behaviour
            )
        }
    }

    // MARK: - Section 5: Addressing Issues (5 collapsible subsections like desktop)
    @State private var section5Expanded: [Int: Bool] = [1: false, 2: false, 3: false, 4: false, 5: false]

    private var addressingIssuesPopup: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 1. Work to address index offence(s) and risks
            DisclosureGroup(
                isExpanded: Binding(
                    get: { section5Expanded[1] ?? false },
                    set: { section5Expanded[1] = $0 }
                )
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    SliderWithLabel(value: $formData.indexOffenceWorkLevel, options: ["None", "Considering", "Starting", "Engaging", "Well Engaged", "Almost Complete", "Complete"])
                    TextField("Additional details...", text: $formData.indexOffenceWorkDetails)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.leading, 8)
                .padding(.top, 4)
            } label: {
                Text("1. Work to address index offence(s) and risks")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.red)
            }

            Divider()

            // 2. Prosocial activities (OT & Psychology)
            DisclosureGroup(
                isExpanded: Binding(
                    get: { section5Expanded[2] ?? false },
                    set: { section5Expanded[2] = $0 }
                )
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("OT Groups").font(.caption.weight(.semibold))
                    LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 6) {
                        CheckboxRow(label: "Breakfast club", isOn: $formData.otBreakfastClub)
                        CheckboxRow(label: "Smoothie", isOn: $formData.otSmoothie)
                        CheckboxRow(label: "Cooking", isOn: $formData.otCooking)
                        CheckboxRow(label: "Current affairs", isOn: $formData.otCurrentAffairs)
                        CheckboxRow(label: "Self care", isOn: $formData.otSelfCare)
                        CheckboxRow(label: "OT trips", isOn: $formData.otTrips)
                        CheckboxRow(label: "Music", isOn: $formData.otMusic)
                        CheckboxRow(label: "Art", isOn: $formData.otArt)
                        CheckboxRow(label: "Gym", isOn: $formData.otGym)
                        CheckboxRow(label: "Woodwork", isOn: $formData.otWoodwork)
                        CheckboxRow(label: "Horticulture", isOn: $formData.otHorticulture)
                        CheckboxRow(label: "Physio", isOn: $formData.otPhysio)
                    }
                    Text("OT Engagement").font(.caption).foregroundColor(.secondary)
                    SliderWithLabel(value: $formData.otEngagementLevel, options: ["Limited", "Mixed", "Reasonable", "Good", "Very Good", "Excellent"])

                    Divider()

                    Text("Psychology").font(.caption.weight(.semibold))
                    LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 6) {
                        CheckboxRow(label: "1-1", isOn: $formData.psychOneToOne)
                        CheckboxRow(label: "Risk", isOn: $formData.psychRisk)
                        CheckboxRow(label: "Insight", isOn: $formData.psychInsight)
                        CheckboxRow(label: "Psychoeducation", isOn: $formData.psychPsychoeducation)
                        CheckboxRow(label: "Managing emotions", isOn: $formData.psychManagingEmotions)
                        CheckboxRow(label: "Drugs and alcohol", isOn: $formData.psychDrugsAlcohol)
                        CheckboxRow(label: "Care pathway", isOn: $formData.psychCarePathway)
                        CheckboxRow(label: "Discharge planning", isOn: $formData.psychDischargePlanning)
                    }
                    Text("Psychology Engagement").font(.caption).foregroundColor(.secondary)
                    SliderWithLabel(value: $formData.psychEngagementLevel, options: ["Limited", "Mixed", "Reasonable", "Good", "Very Good", "Excellent"])
                }
                .padding(.leading, 8)
                .padding(.top, 4)
            } label: {
                Text("2. Prosocial activities (OT & Psychology)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.red)
            }

            Divider()

            // 3. Attitudes to risk factors
            DisclosureGroup(
                isExpanded: Binding(
                    get: { section5Expanded[3] ?? false },
                    set: { section5Expanded[3] = $0 }
                )
            ) {
                VStack(alignment: .leading, spacing: 6) {
                    RiskFactorRow(label: "Violence to others", isOn: $formData.riskViolenceOthers, attitude: $formData.riskViolenceOthersAttitude)
                    RiskFactorRow(label: "Violence to property", isOn: $formData.riskViolenceProperty, attitude: $formData.riskViolencePropertyAttitude)
                    RiskFactorRow(label: "Verbal aggression", isOn: $formData.riskVerbalAggression, attitude: $formData.riskVerbalAggressionAttitude)
                    RiskFactorRow(label: "Substance misuse", isOn: $formData.riskSubstanceMisuse, attitude: $formData.riskSubstanceMisuseAttitude)
                    RiskFactorRow(label: "Self harm", isOn: $formData.riskSelfHarm, attitude: $formData.riskSelfHarmAttitude)
                    RiskFactorRow(label: "Self neglect", isOn: $formData.riskSelfNeglect, attitude: $formData.riskSelfNeglectAttitude)
                    RiskFactorRow(label: "Stalking", isOn: $formData.riskStalking, attitude: $formData.riskStalkingAttitude)
                    RiskFactorRow(label: "Threatening behaviour", isOn: $formData.riskThreateningBehaviour, attitude: $formData.riskThreateningBehaviourAttitude)
                    RiskFactorRow(label: "Sexually inappropriate", isOn: $formData.riskSexuallyInappropriate, attitude: $formData.riskSexuallyInappropriateAttitude)
                    RiskFactorRow(label: "Vulnerability", isOn: $formData.riskVulnerability, attitude: $formData.riskVulnerabilityAttitude)
                    RiskFactorRow(label: "Bullying/victimisation", isOn: $formData.riskBullyingVictimisation, attitude: $formData.riskBullyingVictimisationAttitude)
                    RiskFactorRow(label: "Absconding/AWOL", isOn: $formData.riskAbsconding, attitude: $formData.riskAbscondingAttitude)
                    RiskFactorRow(label: "Reoffending", isOn: $formData.riskReoffending, attitude: $formData.riskReoffendingAttitude)
                }
                .padding(.leading, 8)
                .padding(.top, 4)
            } label: {
                Text("3. Understanding of risk factors")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.red)
            }
            // Sync Section 5 risk factors to Section 9 Current and Historical
            .onChange(of: formData.riskViolenceOthers) { _, newValue in
                let val = newValue ? 1 : 0
                formData.currentRiskViolenceOthers = val
                formData.historicalRiskViolenceOthers = val
            }
            .onChange(of: formData.riskViolenceProperty) { _, newValue in
                let val = newValue ? 1 : 0
                formData.currentRiskViolenceProperty = val
                formData.historicalRiskViolenceProperty = val
            }
            .onChange(of: formData.riskVerbalAggression) { _, newValue in
                let val = newValue ? 1 : 0
                formData.currentRiskVerbalAggression = val
                formData.historicalRiskVerbalAggression = val
            }
            .onChange(of: formData.riskSubstanceMisuse) { _, newValue in
                let val = newValue ? 1 : 0
                formData.currentRiskSubstanceMisuse = val
                formData.historicalRiskSubstanceMisuse = val
            }
            .onChange(of: formData.riskSelfHarm) { _, newValue in
                let val = newValue ? 1 : 0
                formData.currentRiskSelfHarm = val
                formData.historicalRiskSelfHarm = val
            }
            .onChange(of: formData.riskSelfNeglect) { _, newValue in
                let val = newValue ? 1 : 0
                formData.currentRiskSelfNeglect = val
                formData.historicalRiskSelfNeglect = val
            }
            .onChange(of: formData.riskStalking) { _, newValue in
                let val = newValue ? 1 : 0
                formData.currentRiskStalking = val
                formData.historicalRiskStalking = val
            }
            .onChange(of: formData.riskThreateningBehaviour) { _, newValue in
                let val = newValue ? 1 : 0
                formData.currentRiskThreateningBehaviour = val
                formData.historicalRiskThreateningBehaviour = val
            }
            .onChange(of: formData.riskSexuallyInappropriate) { _, newValue in
                let val = newValue ? 1 : 0
                formData.currentRiskSexuallyInappropriate = val
                formData.historicalRiskSexuallyInappropriate = val
            }
            .onChange(of: formData.riskVulnerability) { _, newValue in
                let val = newValue ? 1 : 0
                formData.currentRiskVulnerability = val
                formData.historicalRiskVulnerability = val
            }
            .onChange(of: formData.riskBullyingVictimisation) { _, newValue in
                let val = newValue ? 1 : 0
                formData.currentRiskBullyingVictimisation = val
                formData.historicalRiskBullyingVictimisation = val
            }
            .onChange(of: formData.riskAbsconding) { _, newValue in
                let val = newValue ? 1 : 0
                formData.currentRiskAbsconding = val
                formData.historicalRiskAbsconding = val
            }
            .onChange(of: formData.riskReoffending) { _, newValue in
                let val = newValue ? 1 : 0
                formData.currentRiskReoffending = val
                formData.historicalRiskReoffending = val
            }

            Divider()

            // 4. Treatment for risk factors
            DisclosureGroup(
                isExpanded: Binding(
                    get: { section5Expanded[4] ?? false },
                    set: { section5Expanded[4] = $0 }
                )
            ) {
                TreatmentForRiskFactorsView(formData: $formData)
                    .padding(.leading, 8)
                    .padding(.top, 4)
            } label: {
                Text("4. Treatment for risk factors")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.red)
            }

            Divider()

            // 5. Relapse prevention
            DisclosureGroup(
                isExpanded: Binding(
                    get: { section5Expanded[5] ?? false },
                    set: { section5Expanded[5] = $0 }
                )
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    SliderWithLabel(value: $formData.relapsePreventionLevel, options: ["Not started", "Just started", "Ongoing", "Significant", "Almost done", "Completed"])
                }
                .padding(.leading, 8)
                .padding(.top, 4)
            } label: {
                Text("5. Relapse prevention")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.red)
            }
        }
    }

    // MARK: - Section 6: Patient's Attitude
    private var patientAttitudePopup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Understanding & Compliance").font(.headline)

            TreatmentAttitudeRow(label: "Medical", attitude: $formData.attMedical)
            TreatmentAttitudeRow(label: "Nursing", attitude: $formData.attNursing)
            TreatmentAttitudeRow(label: "Psychology", attitude: $formData.attPsychology)
            TreatmentAttitudeRow(label: "OT", attitude: $formData.attOT)
            TreatmentAttitudeRow(label: "Social Work", attitude: $formData.attSocialWork)

            Divider()

            Text("Offending Behaviour").font(.headline)

            Text("Insight into offending").font(.caption)
            SliderWithLabel(value: $formData.offendingInsightLevel, options: ["Nil", "Limited", "Partial", "Good", "Full"])

            Text("Accepts responsibility").font(.caption)
            SliderWithLabel(value: $formData.responsibilityLevel, options: ["Denies", "Minimises", "Partial", "Mostly", "Full"])

            Text("Victim empathy").font(.caption)
            SliderWithLabel(value: $formData.victimEmpathyLevel, options: ["Nil", "Limited", "Developing", "Good", "Full"])

            // Imported Data Section
            ImportedDataSection(
                title: "Imported Notes",
                entries: $formData.patientAttitudeImportedEntries,
                categoryKeywords: ASRCategoryKeywords.patientAttitude
            )
        }
    }

    // MARK: - Section 7: Capacity
    private var capacityPopup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Capacity Assessment by Area").font(.headline)

            CapacityAreaRow(label: "Residence", areaType: .residence, area: $formData.capResidence)
            CapacityAreaRow(label: "Medication", areaType: .medication, area: $formData.capMedication)
            CapacityAreaRow(label: "Finances", areaType: .finances, area: $formData.capFinances)
            CapacityAreaRow(label: "Leave", areaType: .leave, area: $formData.capLeave)

            // Imported Data Section
            ImportedDataSection(
                title: "Imported Notes",
                entries: $formData.capacityImportedEntries,
                categoryKeywords: ASRCategoryKeywords.capacity
            )
        }
    }

    // MARK: - Section 8: Progress
    private var progressPopup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Progress over the last 12 months").font(.headline)

            Text("Mental State").font(.caption)
            SliderWithLabel(value: $formData.mentalStateLevel, options: ["Unsettled", "Often unsettled", "Unsettled at times", "Stable", "Some improvement", "Significant improvement", "Symptom free"])

            Text("Insight").font(.caption)
            SliderWithLabel(value: $formData.insightLevel, options: ["Remains limited", "Mostly absent", "Mild", "Moderate", "Good", "Full"])

            Text("Engagement with Treatment").font(.caption)
            SliderWithLabel(value: $formData.engagementLevel, options: ["Nil", "Some", "Partial", "Good", "Very good", "Full"])

            Text("Risk Reduction Work").font(.caption)
            SliderWithLabel(value: $formData.riskReductionLevel, options: ["Nil", "Started", "In process", "Good engagement", "Almost completed", "Completed"])

            Divider()

            Text("Leave").font(.caption)
            SliderWithLabel(value: $formData.leaveTypeLevel, options: ["No leave", "Escorted", "Unescorted", "Overnight"])

            if formData.leaveTypeLevel > 0 {
                Text("Leave Usage").font(.caption)
                SliderWithLabel(value: $formData.leaveUsageLevel, options: ["Intermittent", "Variable", "Regular", "Frequent", "Excellent"])

                Text("Leave Concerns").font(.caption)
                SliderWithLabel(value: $formData.leaveConcernsLevel, options: ["No", "Mild", "Some", "Several", "Significant"])
            }

            Divider()

            Text("Discharge Planning").font(.caption)
            SliderWithLabel(value: $formData.dischargePlanningLevel, options: ["Not started", "Early stages", "In progress", "Almost completed", "Completed"])

            Toggle("Discharge applications made", isOn: $formData.hasDischargeApplication)

            // Clinical Narrative Summary Section (matching Tribunal Section 14 style)
            ProgressNarrativeSummarySection(entries: formData.progressImportedEntries)

            // Imported Data Section
            ImportedDataSection(
                title: "Individual Progress Notes",
                entries: $formData.progressImportedEntries,
                categoryKeywords: ASRCategoryKeywords.progress
            )
        }
    }

    // MARK: - Section 9: Managing Risk
    private var managingRiskPopup: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Current Risk Factors (matches Section 5 risk factors)
            DisclosureGroup(
                isExpanded: .constant(true)
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    RiskFactorRowSection9(label: "Violence to others", value: $formData.currentRiskViolenceOthers)
                    RiskFactorRowSection9(label: "Violence to property", value: $formData.currentRiskViolenceProperty)
                    RiskFactorRowSection9(label: "Verbal aggression", value: $formData.currentRiskVerbalAggression)
                    RiskFactorRowSection9(label: "Substance misuse", value: $formData.currentRiskSubstanceMisuse)
                    RiskFactorRowSection9(label: "Self harm", value: $formData.currentRiskSelfHarm)
                    RiskFactorRowSection9(label: "Self neglect", value: $formData.currentRiskSelfNeglect)
                    RiskFactorRowSection9(label: "Stalking", value: $formData.currentRiskStalking)
                    RiskFactorRowSection9(label: "Threatening behaviour", value: $formData.currentRiskThreateningBehaviour)
                    RiskFactorRowSection9(label: "Sexually inappropriate", value: $formData.currentRiskSexuallyInappropriate)
                    RiskFactorRowSection9(label: "Vulnerability", value: $formData.currentRiskVulnerability)
                    RiskFactorRowSection9(label: "Bullying/victimisation", value: $formData.currentRiskBullyingVictimisation)
                    RiskFactorRowSection9(label: "Absconding/AWOL", value: $formData.currentRiskAbsconding)
                    RiskFactorRowSection9(label: "Reoffending", value: $formData.currentRiskReoffending)
                }
                .padding(.leading, 8)
                .padding(.top, 4)
            } label: {
                Label("Current Risk Factors", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundColor(.red)
            }
            .padding()
            .background(Color.red.opacity(0.05))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red.opacity(0.3), lineWidth: 1))
            // Sync current risk changes to historical risk
            .onChange(of: formData.currentRiskViolenceOthers) { _, newValue in formData.historicalRiskViolenceOthers = newValue }
            .onChange(of: formData.currentRiskViolenceProperty) { _, newValue in formData.historicalRiskViolenceProperty = newValue }
            .onChange(of: formData.currentRiskVerbalAggression) { _, newValue in formData.historicalRiskVerbalAggression = newValue }
            .onChange(of: formData.currentRiskSubstanceMisuse) { _, newValue in formData.historicalRiskSubstanceMisuse = newValue }
            .onChange(of: formData.currentRiskSelfHarm) { _, newValue in formData.historicalRiskSelfHarm = newValue }
            .onChange(of: formData.currentRiskSelfNeglect) { _, newValue in formData.historicalRiskSelfNeglect = newValue }
            .onChange(of: formData.currentRiskStalking) { _, newValue in formData.historicalRiskStalking = newValue }
            .onChange(of: formData.currentRiskThreateningBehaviour) { _, newValue in formData.historicalRiskThreateningBehaviour = newValue }
            .onChange(of: formData.currentRiskSexuallyInappropriate) { _, newValue in formData.historicalRiskSexuallyInappropriate = newValue }
            .onChange(of: formData.currentRiskVulnerability) { _, newValue in formData.historicalRiskVulnerability = newValue }
            .onChange(of: formData.currentRiskBullyingVictimisation) { _, newValue in formData.historicalRiskBullyingVictimisation = newValue }
            .onChange(of: formData.currentRiskAbsconding) { _, newValue in formData.historicalRiskAbsconding = newValue }
            .onChange(of: formData.currentRiskReoffending) { _, newValue in formData.historicalRiskReoffending = newValue }

            // Historical Risk Factors (matches Section 5 risk factors)
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 8) {
                    RiskFactorRowSection9(label: "Violence to others", value: $formData.historicalRiskViolenceOthers, tintColor: .orange)
                    RiskFactorRowSection9(label: "Violence to property", value: $formData.historicalRiskViolenceProperty, tintColor: .orange)
                    RiskFactorRowSection9(label: "Verbal aggression", value: $formData.historicalRiskVerbalAggression, tintColor: .orange)
                    RiskFactorRowSection9(label: "Substance misuse", value: $formData.historicalRiskSubstanceMisuse, tintColor: .orange)
                    RiskFactorRowSection9(label: "Self harm", value: $formData.historicalRiskSelfHarm, tintColor: .orange)
                    RiskFactorRowSection9(label: "Self neglect", value: $formData.historicalRiskSelfNeglect, tintColor: .orange)
                    RiskFactorRowSection9(label: "Stalking", value: $formData.historicalRiskStalking, tintColor: .orange)
                    RiskFactorRowSection9(label: "Threatening behaviour", value: $formData.historicalRiskThreateningBehaviour, tintColor: .orange)
                    RiskFactorRowSection9(label: "Sexually inappropriate", value: $formData.historicalRiskSexuallyInappropriate, tintColor: .orange)
                    RiskFactorRowSection9(label: "Vulnerability", value: $formData.historicalRiskVulnerability, tintColor: .orange)
                    RiskFactorRowSection9(label: "Bullying/victimisation", value: $formData.historicalRiskBullyingVictimisation, tintColor: .orange)
                    RiskFactorRowSection9(label: "Absconding/AWOL", value: $formData.historicalRiskAbsconding, tintColor: .orange)
                    RiskFactorRowSection9(label: "Reoffending", value: $formData.historicalRiskReoffending, tintColor: .orange)
                }
                .padding(.leading, 8)
                .padding(.top, 4)
            } label: {
                Label("Historical Risk Factors", systemImage: "clock.arrow.circlepath")
                    .font(.headline)
                    .foregroundColor(.orange)
            }
            .padding()
            .background(Color.orange.opacity(0.05))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.3), lineWidth: 1))

            // Imported Data Section
            ImportedDataSection(
                title: "Imported Notes",
                entries: $formData.riskImportedEntries,
                categoryKeywords: ASRCategoryKeywords.managingRisk
            )
        }
    }

    // MARK: - Section 10: How Risks Addressed
    private var riskAddressedPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 1. Progress and issues of concern
            VStack(alignment: .leading, spacing: 4) {
                Text("1. Progress and Issues of Concern").font(.subheadline.weight(.semibold))
                TextEditor(text: $formData.riskProgressText)
                    .frame(minHeight: 80)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray4), lineWidth: 1))
            }

            // 2. Factors underpinning index offence
            VStack(alignment: .leading, spacing: 4) {
                Text("2. Factors Underpinning Index Offence").font(.subheadline.weight(.semibold))
                TextEditor(text: $formData.riskFactorsText)
                    .frame(minHeight: 80)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray4), lineWidth: 1))
            }

            // 3. Attitudes to index offence & victims
            VStack(alignment: .leading, spacing: 4) {
                Text("3. Attitudes to Index Offence & Victims").font(.subheadline.weight(.semibold))
                TextEditor(text: $formData.riskAttitudesText)
                    .frame(minHeight: 80)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray4), lineWidth: 1))
            }

            // 4. Prevent referral
            VStack(alignment: .leading, spacing: 8) {
                Text("4. Prevent Referral").font(.subheadline.weight(.semibold))
                Picker("Referred to Prevent?", selection: $formData.preventReferral) {
                    ForEach(PreventReferralStatus.allCases) { status in
                        Text(status.rawValue).tag(status)
                    }
                }
                .pickerStyle(.segmented)

                if formData.preventReferral == .yes {
                    TextField("Outcome of referral...", text: $formData.preventOutcome)
                        .textFieldStyle(.roundedBorder)
                }
            }

            // Imported Data Section
            ImportedDataSection(
                title: "Imported Notes",
                entries: $formData.riskAddressedImportedEntries,
                categoryKeywords: ASRCategoryKeywords.riskAddressed
            )
        }
    }

    // MARK: - Section 11: Abscond / Escape
    private var abscondPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            // AWOL incidents Yes/No
            HStack {
                Text("Any AWOL incidents?").font(.subheadline.weight(.semibold))
                Spacer()
                Picker("", selection: $formData.hasAwolIncidents) {
                    Text("No").tag(false)
                    Text("Yes").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }

            // Details text box
            VStack(alignment: .leading, spacing: 4) {
                Text("Details:").font(.subheadline).foregroundColor(.secondary)
                TextEditor(text: $formData.abscondDetails)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray4), lineWidth: 1))
            }

            // Imported Data Section
            ImportedDataSection(
                title: "Imported Notes",
                entries: $formData.abscondImportedEntries,
                categoryKeywords: ASRCategoryKeywords.abscond
            )
        }
    }

    // MARK: - Section 12: MAPPA
    private var mappaPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 1. MAPPA Category
            VStack(alignment: .leading, spacing: 4) {
                Text("1. MAPPA Category").font(.subheadline.weight(.semibold))
                Picker("", selection: $formData.mappaCategory) {
                    ForEach(MAPPACategory.allCases) { cat in
                        Text(cat.rawValue).tag(cat)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }

            // 2. Level at which managed
            VStack(alignment: .leading, spacing: 4) {
                Text("2. Level at which managed").font(.subheadline.weight(.semibold))
                Picker("", selection: $formData.mappaLevel) {
                    ForEach(MAPPALevel.allCases) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }

            // 3. Date of referral
            VStack(alignment: .leading, spacing: 8) {
                Text("3. Date of referral to MAPPA").font(.subheadline.weight(.semibold))
                Picker("", selection: $formData.mappaDateKnown) {
                    Text("Date known").tag(true)
                    Text("Not known").tag(false)
                }
                .pickerStyle(.segmented)

                if formData.mappaDateKnown {
                    DatePicker("", selection: $formData.mappaDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                }
            }

            // 4. MAPPA comments
            VStack(alignment: .leading, spacing: 4) {
                Text("4. MAPPA comments (last 12 months)").font(.subheadline.weight(.semibold))
                TextEditor(text: $formData.mappaComments)
                    .frame(minHeight: 80)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray4), lineWidth: 1))
            }

            // 5. MAPPA Coordinator
            VStack(alignment: .leading, spacing: 4) {
                Text("5. MAPPA Coordinator name and contact").font(.subheadline.weight(.semibold))
                TextField("Name and contact details...", text: $formData.mappaCoordinator)
                    .textFieldStyle(.roundedBorder)
            }

            // Imported Data Section
            ImportedDataSection(
                title: "Imported Notes",
                entries: $formData.mappaImportedEntries,
                categoryKeywords: ASRCategoryKeywords.mappa
            )
        }
    }

    // MARK: - Section 13: Victims
    private var victimsPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 1. VLO name and contact
            VStack(alignment: .leading, spacing: 4) {
                Text("1. Victim Liaison Officer (VLO) name and contact").font(.subheadline.weight(.semibold))
                TextField("Full contact details...", text: $formData.vloContact)
                    .textFieldStyle(.roundedBorder)
            }

            // 2. Date of last contact
            VStack(alignment: .leading, spacing: 8) {
                Text("2. Date of last discussion/contact with VLO").font(.subheadline.weight(.semibold))
                Picker("", selection: $formData.vloDateKnown) {
                    Text("Date known").tag(true)
                    Text("Not known").tag(false)
                }
                .pickerStyle(.segmented)

                if formData.vloDateKnown {
                    DatePicker("", selection: $formData.vloDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                }
            }

            // 3. Victim-related concerns
            VStack(alignment: .leading, spacing: 4) {
                Text("3. Victim-related concerns (last 12 months)").font(.subheadline.weight(.semibold))
                TextEditor(text: $formData.victimConcerns)
                    .frame(minHeight: 100)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray4), lineWidth: 1))
            }

            // Imported Data Section
            ImportedDataSection(
                title: "Imported Notes",
                entries: $formData.victimsImportedEntries,
                categoryKeywords: ASRCategoryKeywords.victims
            )
        }
    }

    // MARK: - Section 14: Leave Report
    private var leaveReportPopup: some View {
        VStack(alignment: .leading, spacing: 12) {
            LeaveReportSection(escortedLeave: $formData.escortedLeave, unescortedLeave: $formData.unescortedLeave)

            // Imported Data Section
            ImportedDataSection(
                title: "Imported Notes",
                entries: $formData.leaveReportImportedEntries,
                categoryKeywords: ASRCategoryKeywords.leaveReport
            )
        }
    }

    // MARK: - Section 15: Additional Comments (Legal Criteria)
    private var additionalCommentsPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Legal Criteria Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Legal Criteria for Continued Detention")
                    .font(.headline)
                    .foregroundColor(.green)

                // 1. Mental Disorder
                VStack(alignment: .leading, spacing: 8) {
                    Text("Mental Disorder").font(.subheadline.weight(.semibold))
                    Picker("", selection: Binding(
                        get: { formData.mentalDisorderPresent == true ? 1 : (formData.mentalDisorderPresent == false ? 0 : -1) },
                        set: { formData.mentalDisorderPresent = $0 == 1 ? true : ($0 == 0 ? false : nil) }
                    )) {
                        Text("Select...").tag(-1)
                        Text("Absent").tag(0)
                        Text("Present").tag(1)
                    }
                    .pickerStyle(.segmented)

                    // ICD-10 dropdown when Present - using grouped categories like Section 3/A3
                    if formData.mentalDisorderPresent == true {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ICD-10 Diagnosis:").font(.caption).foregroundColor(.secondary)
                            Menu {
                                Button("Clear") { formData.mentalDisorderICD10 = .none }
                                ForEach(ICD10Diagnosis.groupedDiagnoses, id: \.0) { group, diagnoses in
                                    Menu(group) {
                                        ForEach(diagnoses) { diagnosis in
                                            Button(diagnosis.rawValue) { formData.mentalDisorderICD10 = diagnosis }
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(formData.mentalDisorderICD10 == .none ? "Select..." : formData.mentalDisorderICD10.rawValue)
                                        .font(.caption)
                                        .foregroundColor(formData.mentalDisorderICD10 == .none ? .secondary : .primary)
                                        .lineLimit(1)
                                    Spacer()
                                    Image(systemName: "chevron.down").font(.caption2).foregroundColor(.secondary)
                                }
                                .padding(10)
                                .background(Color(.systemGray6))
                                .cornerRadius(6)
                            }
                        }
                        .padding(.leading, 8)
                    }
                }

                // Show criteria section if mental disorder is present
                if formData.mentalDisorderPresent == true {
                    // 2. Criteria Warranting Detention
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Criteria Warranting Detention").font(.subheadline.weight(.semibold))
                        Picker("", selection: Binding(
                            get: { formData.criteriaWarrantingDetention == true ? 1 : (formData.criteriaWarrantingDetention == false ? 0 : -1) },
                            set: { formData.criteriaWarrantingDetention = $0 == 1 ? true : ($0 == 0 ? false : nil) }
                        )) {
                            Text("Select...").tag(-1)
                            Text("Not Met").tag(0)
                            Text("Met").tag(1)
                        }
                        .pickerStyle(.segmented)
                    }

                    // Show Nature/Degree if criteria met
                    if formData.criteriaWarrantingDetention == true {
                        VStack(alignment: .leading, spacing: 12) {
                            // Nature
                            VStack(alignment: .leading, spacing: 6) {
                                Toggle("Nature", isOn: $formData.criteriaByNature)
                                    .font(.subheadline.weight(.medium))

                                if formData.criteriaByNature {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Toggle("Relapsing and remitting", isOn: $formData.natureRelapsing)
                                        Toggle("Treatment resistant", isOn: $formData.natureTreatmentResistant)
                                        Toggle("Chronic and enduring", isOn: $formData.natureChronic)
                                    }
                                    .toggleStyle(.asrCheckbox)
                                    .font(.caption)
                                    .padding(.leading, 20)
                                }
                            }

                            // Degree
                            VStack(alignment: .leading, spacing: 6) {
                                Toggle("Degree", isOn: $formData.criteriaByDegree)
                                    .font(.subheadline.weight(.medium))

                                if formData.criteriaByDegree {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Symptom severity:").font(.caption).foregroundColor(.secondary)
                                        HStack {
                                            Slider(value: Binding(
                                                get: { Double(formData.degreeSeverity) },
                                                set: { formData.degreeSeverity = Int($0) }
                                            ), in: 1...4, step: 1)
                                            .tint(.green)
                                            Text(["Some", "Several", "Many", "Overwhelming"][formData.degreeSeverity - 1])
                                                .font(.caption.weight(.semibold))
                                                .foregroundColor(.green)
                                                .frame(width: 80)
                                        }

                                        Text("Symptoms including:").font(.caption).foregroundColor(.secondary)
                                        TextEditor(text: $formData.degreeDetails)
                                            .frame(minHeight: 60)
                                            .padding(6)
                                            .background(Color(.systemBackground))
                                            .cornerRadius(6)
                                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(.systemGray4), lineWidth: 1))
                                    }
                                    .padding(.leading, 20)
                                }
                            }
                        }
                        .padding(.leading, 8)
                    }

                    // 3. Necessity
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Necessity").font(.subheadline.weight(.semibold)).padding(.top, 8)
                        Picker("", selection: Binding(
                            get: { formData.necessity == true ? 1 : (formData.necessity == false ? 0 : -1) },
                            set: { formData.necessity = $0 == 1 ? true : ($0 == 0 ? false : nil) }
                        )) {
                            Text("Select...").tag(-1)
                            Text("No").tag(0)
                            Text("Yes").tag(1)
                        }
                        .pickerStyle(.segmented)

                        // Health & Safety options when Necessity = Yes
                        if formData.necessity == true {
                            VStack(alignment: .leading, spacing: 12) {
                                // Health
                                VStack(alignment: .leading, spacing: 6) {
                                    Toggle("Health", isOn: $formData.healthNecessity)
                                        .font(.subheadline.weight(.medium))

                                    if formData.healthNecessity {
                                        VStack(alignment: .leading, spacing: 8) {
                                            // Mental Health
                                            VStack(alignment: .leading, spacing: 4) {
                                                Toggle("Mental Health", isOn: $formData.mentalHealthNecessity)
                                                    .toggleStyle(.asrCheckbox)
                                                    .font(.caption)

                                                if formData.mentalHealthNecessity {
                                                    VStack(alignment: .leading, spacing: 4) {
                                                        Toggle("Poor compliance", isOn: $formData.poorCompliance)
                                                        Toggle("Limited insight", isOn: $formData.limitedInsight)
                                                    }
                                                    .toggleStyle(.asrCheckbox)
                                                    .font(.caption2)
                                                    .padding(.leading, 20)
                                                }
                                            }

                                            // Physical Health
                                            VStack(alignment: .leading, spacing: 4) {
                                                Toggle("Physical Health", isOn: $formData.physicalHealthNecessity)
                                                    .toggleStyle(.asrCheckbox)
                                                    .font(.caption)

                                                if formData.physicalHealthNecessity {
                                                    TextEditor(text: $formData.physicalHealthDetails)
                                                        .frame(minHeight: 50)
                                                        .padding(4)
                                                        .background(Color(.systemBackground))
                                                        .cornerRadius(4)
                                                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(.systemGray4), lineWidth: 1))
                                                        .padding(.leading, 20)
                                                }
                                            }
                                        }
                                        .padding(.leading, 20)
                                    }
                                }

                                // Safety
                                VStack(alignment: .leading, spacing: 6) {
                                    Toggle("Safety", isOn: $formData.safetyNecessity)
                                        .font(.subheadline.weight(.medium))

                                    if formData.safetyNecessity {
                                        VStack(alignment: .leading, spacing: 8) {
                                            // Self
                                            VStack(alignment: .leading, spacing: 4) {
                                                Toggle("Self", isOn: $formData.selfSafety)
                                                    .toggleStyle(.asrCheckbox)
                                                    .font(.caption)

                                                if formData.selfSafety {
                                                    // Self safety checkboxes
                                                    VStack(alignment: .leading, spacing: 6) {
                                                        HStack(spacing: 16) {
                                                            Text("").frame(width: 100)
                                                            Text("Historical").font(.caption2).foregroundColor(.secondary).frame(width: 70)
                                                            Text("Current").font(.caption2).foregroundColor(.secondary).frame(width: 70)
                                                        }
                                                        SafetyCheckboxRow(label: "Self-neglect", historical: $formData.selfNeglectHistorical, current: $formData.selfNeglectCurrent)
                                                        SafetyCheckboxRow(label: "Risky behaviour", historical: $formData.selfRiskyHistorical, current: $formData.selfRiskyCurrent)
                                                        SafetyCheckboxRow(label: "Self-harm", historical: $formData.selfHarmHistorical, current: $formData.selfHarmCurrent)

                                                        Text("Additional details:").font(.caption2).foregroundColor(.secondary).padding(.top, 4)
                                                        TextEditor(text: $formData.selfSafetyDetails)
                                                            .frame(minHeight: 50)
                                                            .padding(4)
                                                            .background(Color(.systemBackground))
                                                            .cornerRadius(4)
                                                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(.systemGray4), lineWidth: 1))
                                                    }
                                                    .padding(.leading, 20)
                                                }
                                            }

                                            // Others
                                            VStack(alignment: .leading, spacing: 4) {
                                                Toggle("Others", isOn: $formData.othersSafety)
                                                    .toggleStyle(.asrCheckbox)
                                                    .font(.caption)

                                                if formData.othersSafety {
                                                    // Others safety checkboxes
                                                    VStack(alignment: .leading, spacing: 6) {
                                                        HStack(spacing: 16) {
                                                            Text("").frame(width: 100)
                                                            Text("Historical").font(.caption2).foregroundColor(.secondary).frame(width: 70)
                                                            Text("Current").font(.caption2).foregroundColor(.secondary).frame(width: 70)
                                                        }
                                                        SafetyCheckboxRow(label: "Violence", historical: $formData.violenceHistorical, current: $formData.violenceCurrent)
                                                        SafetyCheckboxRow(label: "Verbal aggression", historical: $formData.verbalAggressionHistorical, current: $formData.verbalAggressionCurrent)
                                                        SafetyCheckboxRow(label: "Sexual violence", historical: $formData.sexualViolenceHistorical, current: $formData.sexualViolenceCurrent)
                                                        SafetyCheckboxRow(label: "Stalking", historical: $formData.stalkingHistorical, current: $formData.stalkingCurrent)
                                                        SafetyCheckboxRow(label: "Arson", historical: $formData.arsonHistorical, current: $formData.arsonCurrent)

                                                        Text("Additional details:").font(.caption2).foregroundColor(.secondary).padding(.top, 4)
                                                        TextEditor(text: $formData.othersSafetyDetails)
                                                            .frame(minHeight: 50)
                                                            .padding(4)
                                                            .background(Color(.systemBackground))
                                                            .cornerRadius(4)
                                                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(.systemGray4), lineWidth: 1))
                                                    }
                                                    .padding(.leading, 20)
                                                }
                                            }
                                        }
                                        .padding(.leading, 20)
                                    }
                                }
                            }
                            .padding(.leading, 8)
                        }
                    }

                    // 4. Treatment Available
                    Toggle("Treatment Available", isOn: $formData.treatmentAvailable)
                        .font(.subheadline.weight(.semibold))
                        .padding(.top, 8)

                    // 5. Least Restrictive Option
                    Toggle("Least Restrictive Option", isOn: $formData.leastRestrictiveOption)
                        .font(.subheadline.weight(.semibold))
                }
            }
            .padding(12)
            .background(Color.green.opacity(0.1))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green.opacity(0.3), lineWidth: 1))

            // Additional Comments text
            VStack(alignment: .leading, spacing: 4) {
                Text("Additional comments:").font(.subheadline).foregroundColor(.secondary)
                TextEditor(text: $formData.additionalCommentsText)
                    .frame(minHeight: 80)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray4), lineWidth: 1))
            }
        }
    }

    // MARK: - Section 16: Unfit to Plead
    private var unfitToPleadPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            // First question
            VStack(alignment: .leading, spacing: 8) {
                Text("Has this patient been found unfit to plead on sentencing?")
                    .font(.subheadline.weight(.semibold))
                Picker("", selection: Binding(
                    get: { formData.foundUnfitToPlead == true ? 1 : (formData.foundUnfitToPlead == false ? 0 : -1) },
                    set: { formData.foundUnfitToPlead = $0 == 1 ? true : ($0 == 0 ? false : nil) }
                )) {
                    Text("Select...").tag(-1)
                    Text("No").tag(0)
                    Text("Yes").tag(1)
                }
                .pickerStyle(.segmented)
            }

            // Show details if Yes
            if formData.foundUnfitToPlead == true {
                VStack(alignment: .leading, spacing: 12) {
                    // Fitness status
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Is patient now fit to plead?")
                            .font(.subheadline.weight(.semibold))
                        Picker("", selection: Binding(
                            get: { formData.nowFitToPlead == true ? 1 : (formData.nowFitToPlead == false ? 0 : -1) },
                            set: { formData.nowFitToPlead = $0 == 1 ? true : ($0 == 0 ? false : nil) }
                        )) {
                            Text("Select...").tag(-1)
                            Text("No").tag(0)
                            Text("Yes").tag(1)
                        }
                        .pickerStyle(.segmented)
                    }

                    // Details
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Details:").font(.subheadline).foregroundColor(.secondary)
                        TextEditor(text: $formData.unfitToPleadDetails)
                            .frame(minHeight: 100)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray4), lineWidth: 1))
                    }
                }
            }
        }
    }

    // MARK: - Signature
    private var signaturePopup: some View {
        VStack(alignment: .leading, spacing: 12) {
            FormDatePicker(label: "Signature Date", date: $formData.signatureDate)

            VStack(alignment: .leading, spacing: 4) {
                Text(formData.rcName.isEmpty ? "[RC Name]" : formData.rcName).fontWeight(.semibold)
                if !formData.rcJobTitle.isEmpty { Text(formData.rcJobTitle) }
                Text("Responsible Clinician")
                Text(formData.hospitalName.isEmpty ? "[Hospital]" : formData.hospitalName)
            }
            .font(.subheadline)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }

    // MARK: - Free Text Popup
    @State private var freeText: String = ""

    private func freeTextPopup(placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Enter text below:").font(.subheadline).foregroundColor(.secondary)
            TextEditor(text: $freeText)
                .frame(minHeight: 200)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
        .onAppear {
            // Load existing text based on section
            switch section {
            case .managingRisk: freeText = formData.managingRiskText
            case .riskAddressed: freeText = formData.riskAddressedText
            case .abscond: freeText = formData.abscondText
            case .mappa: freeText = formData.mappaText
            case .victims: freeText = formData.victimsText
            case .additionalComments: freeText = formData.additionalCommentsText
            case .unfitToPlead: freeText = formData.unfitToPleadText
            default: break
            }
        }
    }

    // MARK: - Generate Text
    private func generateText() -> String {
        switch section {
        case .patientDetails:
            return generatePatientDetailsText()
        case .rcDetails:
            return generateRCDetailsText()
        case .mentalDisorder:
            return generateMentalDisorderText()
        case .attitudeBehaviour:
            return formData.generateBehaviourText()
        case .addressingIssues:
            return generateAddressingIssuesText()
        case .patientAttitude:
            return generatePatientAttitudeText()
        case .capacity:
            return generateCapacityText()
        case .progress:
            return formData.generateProgressText()
        case .leaveReport:
            return generateLeaveReportText()
        case .signature:
            return generateSignatureText()
        case .managingRisk:
            return generateManagingRiskText()
        case .riskAddressed:
            return generateRiskAddressedText()
        case .abscond:
            return generateAbscondText()
        case .mappa:
            return generateMappaText()
        case .victims:
            return generateVictimsText()
        case .additionalComments:
            return generateAdditionalCommentsText()
        case .unfitToPlead:
            return generateUnfitToPleadText()
        }
    }

    /// Helper function to append selected imported entries to text
    private func appendImportedNotes(_ entries: [ASRImportedEntry], to text: String) -> String {
        let selectedImports = entries.filter { $0.selected }
        guard !selectedImports.isEmpty else { return text }

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

        if text.isEmpty {
            return "--- Imported Notes ---\n\(importedTexts.joined(separator: "\n"))"
        } else {
            return "\(text)\n\n--- Imported Notes ---\n\(importedTexts.joined(separator: "\n"))"
        }
    }

    private func generatePatientDetailsText() -> String {
        var parts: [String] = []
        if !formData.patientName.isEmpty { parts.append("Name: \(formData.patientName)") }
        if let dob = formData.patientDOB {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            parts.append("DOB: \(formatter.string(from: dob))")
        }
        parts.append("Gender: \(formData.patientGender.rawValue)")
        if !formData.hospitalName.isEmpty { parts.append("Hospital: \(formData.hospitalName)") }
        if !formData.mhcsRef.isEmpty { parts.append("MHCS Ref: \(formData.mhcsRef)") }
        parts.append("MHA Section: \(formData.mhaSection)")
        return parts.joined(separator: "\n")
    }

    private func generateRCDetailsText() -> String {
        var parts: [String] = []
        if !formData.rcName.isEmpty { parts.append("RC: \(formData.rcName)") }
        if !formData.rcJobTitle.isEmpty { parts.append("Title: \(formData.rcJobTitle)") }
        if !formData.rcPhone.isEmpty { parts.append("Phone: \(formData.rcPhone)") }
        if !formData.rcEmail.isEmpty { parts.append("Email: \(formData.rcEmail)") }
        return parts.joined(separator: "\n")
    }

    private func generateMentalDisorderText() -> String {
        var parts: [String] = []
        if !formData.diagnosis1.isEmpty {
            parts.append("Main diagnosis is \(formData.diagnosis1).")
        }
        if !formData.diagnosis2.isEmpty {
            parts.append("There is a second diagnosis of \(formData.diagnosis2).")
        }
        if !formData.diagnosis3.isEmpty {
            parts.append("Third diagnosis: \(formData.diagnosis3).")
        }
        if !formData.clinicalDescription.isEmpty {
            parts.append("\n\(formData.clinicalDescription)")
        }
        return parts.joined(separator: " ")
    }

    private func generateAddressingIssuesText() -> String {
        // Pronouns matching desktop
        let pro = formData.patientGender == .male ? "He" : formData.patientGender == .female ? "She" : "They"
        let proL = formData.patientGender == .male ? "he" : formData.patientGender == .female ? "she" : "they"
        let isPlural = formData.patientGender == .other
        let has = isPlural ? "have" : "has"
        let isAre = isPlural ? "are" : "is"
        let engages = isPlural ? "engage" : "engages"
        let pos = formData.patientGender == .male ? "His" : formData.patientGender == .female ? "Her" : "Their"
        let posL = formData.patientGender == .male ? "his" : formData.patientGender == .female ? "her" : "their"

        // Helper to format lists with "and" before last item
        func formatList(_ items: [String]) -> String {
            if items.isEmpty { return "" }
            if items.count == 1 { return items[0] }
            if items.count == 2 { return "\(items[0]) and \(items[1])" }
            return items.dropLast().joined(separator: ", ") + " and " + items.last!
        }

        var parts: [String] = []

        // 1. Index offence work (matching desktop narrative)
        let indexLevel = formData.indexOffenceWorkLevel
        if indexLevel > 0 {
            let indexNarratives: [Int: String] = [
                1: "\(isAre) considering engaging with work",
                2: "\(has) started work",
                3: "\(isAre) engaging with work",
                4: "\(isAre) well engaged with work",
                5: "\(has) almost completed work",
                6: "\(has) completed work"
            ]
            var indexText = "\(pro) \(indexNarratives[indexLevel] ?? "\(has) started work") to address the index offence and associated risks"
            if !formData.indexOffenceWorkDetails.isEmpty {
                indexText += ", including \(formData.indexOffenceWorkDetails)"
            }
            parts.append(indexText + ".")
        }

        // 2. OT Groups - matching desktop narrative
        var otGroups: [String] = []
        if formData.otBreakfastClub { otGroups.append("breakfast club") }
        if formData.otSmoothie { otGroups.append("smoothie groups") }
        if formData.otCooking { otGroups.append("cooking") }
        if formData.otCurrentAffairs { otGroups.append("current affairs") }
        if formData.otSelfCare { otGroups.append("self care") }
        if formData.otTrips { otGroups.append("OT trips") }
        if formData.otMusic { otGroups.append("music") }
        if formData.otArt { otGroups.append("art") }
        if formData.otGym { otGroups.append("gym") }
        if formData.otWoodwork { otGroups.append("woodwork") }
        if formData.otHorticulture { otGroups.append("horticulture") }
        if formData.otPhysio { otGroups.append("physio") }

        let hasOT = !otGroups.isEmpty
        if hasOT {
            let otList = formatList(otGroups)
            var otText = "\(pro) \(engages) in prosocial groups, such as in OT - \(otList)."

            let engNarratives = ["limited however", "mixed", "reasonably good", "good", "very good", "excellent"]
            let engLevel = min(formData.otEngagementLevel, engNarratives.count - 1)
            otText += " Overall engagement in these groups is \(engNarratives[engLevel])."
            parts.append(otText)
        }

        // 2b. Psychology - matching desktop narrative
        var psychItems: [(key: String, name: String)] = []
        if formData.psychOneToOne { psychItems.append(("oneToOne", "1-1s")) }
        if formData.psychRisk { psychItems.append(("risk", "risk")) }
        if formData.psychInsight { psychItems.append(("insight", "insight")) }
        if formData.psychPsychoeducation { psychItems.append(("psychoeducation", "psychoeducation")) }
        if formData.psychManagingEmotions { psychItems.append(("managingEmotions", "managing emotions")) }
        if formData.psychDrugsAlcohol { psychItems.append(("drugsAlcohol", "drugs and alcohol")) }
        if formData.psychCarePathway { psychItems.append(("carePathway", "care pathway")) }
        if formData.psychDischargePlanning { psychItems.append(("dischargePlanning", "discharge planning")) }

        if !psychItems.isEmpty {
            let hasOneToOne = psychItems.contains { $0.key == "oneToOne" }
            let groups = psychItems.filter { $0.key != "oneToOne" }.map { $0.name }

            var psychText = hasOT ? "Likewise \(proL) \(engages) in psychology" : "\(pro) \(engages) in psychology"

            var psychParts: [String] = []
            if hasOneToOne { psychParts.append("utilising 1-1s") }
            if !groups.isEmpty {
                let groupsList = formatList(groups)
                if hasOneToOne {
                    psychParts.append("and groups/sessions into \(groupsList)")
                } else {
                    psychParts.append("groups/sessions into \(groupsList)")
                }
            }
            if !psychParts.isEmpty {
                psychText += " " + psychParts.joined(separator: " ") + "."
            } else {
                psychText += "."
            }

            let psychEngNarratives = ["limited however", "mixed", "reasonably good", "good", "very good", "excellent"]
            let psychEngLevel = min(formData.psychEngagementLevel, psychEngNarratives.count - 1)
            psychText += " Overall engagement in psychology is \(psychEngNarratives[psychEngLevel])."
            parts.append(psychText)
        }

        // 3. Risk factors - matching desktop narrative (grouped by level, most positive first)
        let riskFactors: [(name: String, key: String, isActive: Bool, attitude: Int)] = [
            ("violence to others", "violenceOthers", formData.riskViolenceOthers, formData.riskViolenceOthersAttitude),
            ("violence to property", "violenceProperty", formData.riskViolenceProperty, formData.riskViolencePropertyAttitude),
            ("verbal aggression", "verbalAggression", formData.riskVerbalAggression, formData.riskVerbalAggressionAttitude),
            ("substance misuse", "substanceMisuse", formData.riskSubstanceMisuse, formData.riskSubstanceMisuseAttitude),
            ("self harm", "selfHarm", formData.riskSelfHarm, formData.riskSelfHarmAttitude),
            ("self neglect", "selfNeglect", formData.riskSelfNeglect, formData.riskSelfNeglectAttitude),
            ("stalking", "stalking", formData.riskStalking, formData.riskStalkingAttitude),
            ("threatening behaviour", "threateningBehaviour", formData.riskThreateningBehaviour, formData.riskThreateningBehaviourAttitude),
            ("sexually inappropriate behaviour", "sexuallyInappropriate", formData.riskSexuallyInappropriate, formData.riskSexuallyInappropriateAttitude),
            ("vulnerability", "vulnerability", formData.riskVulnerability, formData.riskVulnerabilityAttitude),
            ("bullying/victimisation", "bullyingVictimisation", formData.riskBullyingVictimisation, formData.riskBullyingVictimisationAttitude),
            ("absconding/AWOL", "absconding", formData.riskAbsconding, formData.riskAbscondingAttitude),
            ("reoffending", "reoffending", formData.riskReoffending, formData.riskReoffendingAttitude)
        ]

        let activeRisks = riskFactors.filter { $0.isActive }

        // Group by understanding level (0-4)
        var risksByLevel: [Int: [String]] = [:]
        for risk in activeRisks {
            let level = min(risk.attitude, 4)
            if risksByLevel[level] == nil { risksByLevel[level] = [] }
            risksByLevel[level]?.append(risk.name)
        }

        if !risksByLevel.isEmpty {
            let levelIntros: [Int: String] = [
                4: "full understanding of",
                3: "good understanding of",
                2: "some understanding of",
                1: "limited understanding of",
                0: "avoids discussing"
            ]
            let levelConnectors: [Int: String] = [
                4: "", 3: "", 2: "but only", 1: "but only", 0: "and"
            ]

            var sentenceParts: [String] = []
            var isFirst = true

            // Most positive (4) to least positive (0)
            for level in [4, 3, 2, 1, 0] {
                if let risks = risksByLevel[level], !risks.isEmpty {
                    let riskList = formatList(risks)
                    if isFirst {
                        sentenceParts.append("\(levelIntros[level]!) \(posL) risk of \(riskList)")
                        isFirst = false
                    } else {
                        let connector = levelConnectors[level]!
                        if level == 0 {
                            sentenceParts.append("\(connector) \(levelIntros[level]!) \(riskList)")
                        } else {
                            sentenceParts.append("\(connector) \(levelIntros[level]!) \(riskList)")
                        }
                    }
                }
            }

            if !sentenceParts.isEmpty {
                let riskText = "\(pos) attitudes to risk factors reveal " + sentenceParts.joined(separator: ", ") + "."
                parts.append(riskText)
            }
        }

        // 4. Treatment for risk factors - matching desktop (complex output for multiple risks)
        let treatmentLabels: [String: String] = [
            "medication": "medication",
            "psych1to1": "1-1 psychology",
            "psychGroups": "psychology groups",
            "nursing": "nursing support",
            "otSupport": "OT support",
            "socialWork": "social work"
        ]
        let effectivenessLevels = ["nil", "minimal", "some", "reasonable", "good", "very good", "excellent"]
        let concernLevels = ["nil", "minor", "moderate", "significant", "high"]

        // Collect treatment entries
        var treatmentEntries: [(riskKey: String, riskLabel: String, txLabel: String, effectiveness: Int)] = []
        var riskConcerns: [String: (level: Int, details: String)] = [:]

        for risk in activeRisks {
            if let treatment = formData.treatmentData[risk.key] {
                riskConcerns[risk.key] = (treatment.concernLevel, treatment.concernDetails)

                if treatment.medication {
                    treatmentEntries.append((risk.key, risk.name, treatmentLabels["medication"]!, treatment.medicationEffectiveness))
                }
                if treatment.psych1to1 {
                    treatmentEntries.append((risk.key, risk.name, treatmentLabels["psych1to1"]!, treatment.psych1to1Effectiveness))
                }
                if treatment.psychGroups {
                    treatmentEntries.append((risk.key, risk.name, treatmentLabels["psychGroups"]!, treatment.psychGroupsEffectiveness))
                }
                if treatment.nursing {
                    treatmentEntries.append((risk.key, risk.name, treatmentLabels["nursing"]!, treatment.nursingEffectiveness))
                }
                if treatment.otSupport {
                    treatmentEntries.append((risk.key, risk.name, treatmentLabels["otSupport"]!, treatment.otSupportEffectiveness))
                }
                if treatment.socialWork {
                    treatmentEntries.append((risk.key, risk.name, treatmentLabels["socialWork"]!, treatment.socialWorkEffectiveness))
                }
            }
        }

        if !treatmentEntries.isEmpty {
            // Group by risk factor
            var risksWithTreatments: [String: [(label: String, txLabel: String, effectiveness: Int)]] = [:]
            for entry in treatmentEntries {
                if risksWithTreatments[entry.riskKey] == nil {
                    risksWithTreatments[entry.riskKey] = []
                }
                risksWithTreatments[entry.riskKey]?.append((entry.riskLabel, entry.txLabel, entry.effectiveness))
            }

            if risksWithTreatments.count == 1 {
                // Single risk factor - simpler output
                let riskKey = risksWithTreatments.keys.first!
                let entries = risksWithTreatments[riskKey]!
                let txList = formatList(entries.map { $0.txLabel })
                let riskLabel = entries.first!.label
                let maxEff = entries.map { $0.effectiveness }.max() ?? 0
                let effText = effectivenessLevels[min(maxEff, effectivenessLevels.count - 1)]

                var txText = "\(pro) \(has) engaged in \(txList) for \(posL) risk of \(riskLabel)"
                if maxEff == 0 {
                    txText += " with no effectiveness to date"
                } else {
                    txText += " with \(effText) effectiveness"
                }

                let concern = riskConcerns[riskKey] ?? (0, "")
                if concern.level == 0 {
                    txText += " and no remaining concerns"
                } else {
                    let concernText = concernLevels[min(concern.level, concernLevels.count - 1)]
                    if !concern.details.isEmpty {
                        txText += " and \(concernText) remaining concerns (\(concern.details))"
                    } else {
                        txText += " and \(concernText) remaining concerns"
                    }
                }
                parts.append(txText + ".")
            } else {
                // Multiple risk factors - complex output
                // First sentence: what treatment for what
                var riskTreatmentParts: [String] = []
                for (riskKey, entries) in risksWithTreatments {
                    let riskLabel = entries.first!.label
                    let txList = formatList(entries.map { $0.txLabel })
                    riskTreatmentParts.append("\(riskLabel) (\(txList))")
                }
                let txText = "\(pro) \(has) engaged in treatment for " + formatList(riskTreatmentParts) + "."
                parts.append(txText)

                // Second sentence: effectiveness grouped by level
                var riskMaxEff: [(key: String, label: String, eff: Int)] = []
                for (riskKey, entries) in risksWithTreatments {
                    let maxEff = entries.map { $0.effectiveness }.max() ?? 0
                    let riskLabel = entries.first!.label
                    riskMaxEff.append((riskKey, riskLabel, maxEff))
                }

                // Group by effectiveness level
                var effByLevel: [Int: [String]] = [:]
                for item in riskMaxEff {
                    if effByLevel[item.eff] == nil { effByLevel[item.eff] = [] }
                    effByLevel[item.eff]?.append(item.label)
                }

                let sortedLevels = effByLevel.keys.sorted(by: >)
                if !sortedLevels.isEmpty {
                    var effParts: [String] = []
                    var isFirst = true
                    for effLevel in sortedLevels {
                        if let risks = effByLevel[effLevel], !risks.isEmpty {
                            let effText = effectivenessLevels[min(effLevel, effectivenessLevels.count - 1)]
                            let riskList = formatList(risks)
                            if isFirst {
                                if effLevel == 0 {
                                    effParts.append("of no effectiveness for \(riskList)")
                                } else {
                                    effParts.append("of \(effText) effectiveness for \(riskList)")
                                }
                                isFirst = false
                            } else {
                                if effLevel == 0 {
                                    effParts.append("of no effectiveness for \(riskList)")
                                } else {
                                    effParts.append("less so for \(riskList)")
                                }
                            }
                        }
                    }
                    if !effParts.isEmpty {
                        parts.append("The treatment has been " + effParts.joined(separator: " but ") + ".")
                    }
                }

                // Third: concerns - grouped by level
                var concernByLevel: [Int: (risks: [String], details: [String])] = [:]
                var risksNoConcerns: [String] = []

                for (riskKey, entries) in risksWithTreatments {
                    let concern = riskConcerns[riskKey] ?? (0, "")
                    let riskLabel = entries.first!.label
                    if concern.level > 0 {
                        if concernByLevel[concern.level] == nil {
                            concernByLevel[concern.level] = ([], [])
                        }
                        concernByLevel[concern.level]?.risks.append(riskLabel)
                        if !concern.details.isEmpty {
                            concernByLevel[concern.level]?.details.append(concern.details)
                        }
                    } else {
                        risksNoConcerns.append(riskLabel)
                    }
                }

                // Concerns - highest level first
                var concernParts: [String] = []
                for cLevel in concernByLevel.keys.sorted(by: >) {
                    if let cData = concernByLevel[cLevel] {
                        let levelText = concernLevels[min(cLevel, concernLevels.count - 1)].capitalized
                        let riskList = formatList(cData.risks)
                        if !cData.details.isEmpty {
                            concernParts.append("\(levelText) concerns remain around \(riskList), specifically \(cData.details.joined(separator: "; "))")
                        } else {
                            concernParts.append("\(levelText) concerns remain around \(riskList)")
                        }
                    }
                }
                if !concernParts.isEmpty {
                    parts.append(concernParts.joined(separator: ". ") + ".")
                }

                if !risksNoConcerns.isEmpty {
                    let noConcernList = formatList(risksNoConcerns)
                    parts.append("There are no remaining concerns around \(noConcernList).")
                }
            }
        }

        // 5. Relapse prevention - matching desktop narrative
        let relapseLevel = formData.relapsePreventionLevel
        let relapseNarratives: [Int: String] = [
            0: "Relapse prevention work has not yet started but is planned as \(proL) \(engages) further in the care pathway.",
            1: "\(pro) \(has) just started relapse prevention work.",
            2: "\(pro) \(isAre) undertaking ongoing relapse prevention work.",
            3: "\(pro) \(has) made significant progression in relapse prevention work.",
            4: "\(pro) \(has) almost completed relapse prevention work.",
            5: "\(pro) \(has) completed relapse prevention work."
        ]
        parts.append(relapseNarratives[min(relapseLevel, 5)] ?? relapseNarratives[0]!)

        return parts.joined(separator: " ")
    }

    private func generatePatientAttitudeText() -> String {
        let pro = formData.patientGender == .male ? "He" : formData.patientGender == .female ? "She" : "They"
        let proL = formData.patientGender == .male ? "he" : formData.patientGender == .female ? "she" : "they"
        let has = formData.patientGender == .other ? "have" : "has"
        let pos = formData.patientGender == .male ? "his" : formData.patientGender == .female ? "her" : "their"
        let engages = formData.patientGender == .other ? "engage" : "engages"
        let sees = formData.patientGender == .other ? "see" : "sees"
        let does = formData.patientGender == .other ? "do" : "does"
        let isAre = formData.patientGender == .other ? "are" : "is"

        var parts: [String] = []

        // === SECTION 1: Understanding & Compliance ===

        // Medical
        let med = formData.attMedical
        if med.understanding != .notSelected && med.compliance != .notSelected {
            let uPhrase = attUnderstandingPhrase(med.understanding, treatment: "medical", pro: pro, has: has, pos: pos)
            let cPhrase = attCompliancePhrase(med.compliance)
            if !uPhrase.isEmpty && !cPhrase.isEmpty {
                parts.append("\(uPhrase) \(cPhrase).")
            }
        }

        // Nursing
        let nursing = formData.attNursing
        if nursing.understanding != .notSelected && nursing.compliance != .notSelected {
            let phrase = attNursingPhrase(nursing.understanding, compliance: nursing.compliance, pro: pro, engages: engages, sees: sees, does: does)
            if !phrase.isEmpty {
                parts.append(phrase)
            }
        }

        // Psychology
        let psych = formData.attPsychology
        if psych.understanding != .notSelected && psych.compliance != .notSelected {
            let phrase = attPsychologyPhrase(psych.understanding, compliance: psych.compliance, pro: pro, engages: engages, does: does)
            if !phrase.isEmpty {
                parts.append(phrase)
            }
        }

        // OT
        let ot = formData.attOT
        if ot.understanding != .notSelected && ot.compliance != .notSelected {
            let phrase = attOTPhrase(ot.understanding, compliance: ot.compliance, proL: proL, engages: engages, isAre: isAre)
            if !phrase.isEmpty {
                parts.append(phrase)
            }
        }

        // Social Work
        let sw = formData.attSocialWork
        if sw.understanding != .notSelected && sw.compliance != .notSelected {
            let phrase = attSocialWorkPhrase(sw.understanding, compliance: sw.compliance, pro: pro, engages: engages, pos: pos, sees: sees)
            if !phrase.isEmpty {
                parts.append(phrase)
            }
        }

        // === SECTION 2: Offending Behaviour ===
        var offendingParts: [String] = []

        // Insight
        let insightLevel = formData.offendingInsightLevel
        switch insightLevel {
        case 0: offendingParts.append("\(pro) \(has) no insight into \(pos) offending behaviour")
        case 1: offendingParts.append("\(pro) \(has) limited insight into \(pos) offending behaviour")
        case 2: offendingParts.append("\(pro) \(has) partial insight into \(pos) offending behaviour")
        case 3: offendingParts.append("\(pro) \(has) good insight into \(pos) offending behaviour")
        default: offendingParts.append("\(pro) \(has) full insight into \(pos) offending behaviour")
        }

        // Responsibility
        let respLevel = formData.responsibilityLevel
        switch respLevel {
        case 0: offendingParts.append("and denies responsibility")
        case 1: offendingParts.append("and minimises \(pos) responsibility")
        case 2: offendingParts.append("and partially accepts responsibility")
        case 3: offendingParts.append("and mostly accepts responsibility")
        default: offendingParts.append("and fully accepts responsibility")
        }

        // Empathy
        let empathyLevel = formData.victimEmpathyLevel
        switch empathyLevel {
        case 0: offendingParts.append("with no victim empathy")
        case 1: offendingParts.append("with limited victim empathy")
        case 2: offendingParts.append("with developing victim empathy")
        case 3: offendingParts.append("with good victim empathy")
        default: offendingParts.append("with full victim empathy")
        }

        parts.append(offendingParts.joined(separator: " ") + ".")

        let baseText = parts.joined(separator: " ")
        return appendImportedNotes(formData.patientAttitudeImportedEntries, to: baseText)
    }

    // Helper functions for attitude phrases (matching desktop)
    private func attUnderstandingPhrase(_ level: UnderstandingLevel, treatment: String, pro: String, has: String, pos: String) -> String {
        switch level {
        case .good: return "\(pro) \(has) good understanding of \(pos) \(treatment) treatment"
        case .fair: return "\(pro) \(has) some understanding of \(pos) \(treatment) treatment"
        case .poor: return "\(pro) \(has) limited understanding of \(pos) \(treatment) treatment"
        case .notSelected: return ""
        }
    }

    private func attCompliancePhrase(_ level: ComplianceLevel) -> String {
        switch level {
        case .full: return "and compliance is full"
        case .reasonable: return "and compliance is reasonable"
        case .partial: return "but compliance is partial"
        case .none: return "and compliance is nil"
        case .notSelected: return ""
        }
    }

    private func attNursingPhrase(_ understanding: UnderstandingLevel, compliance: ComplianceLevel, pro: String, engages: String, sees: String, does: String) -> String {
        if understanding == .good && (compliance == .full || compliance == .reasonable) {
            return "\(pro) \(engages) well with nursing staff and \(sees) the need for nursing input."
        } else if understanding == .good && compliance == .partial {
            return "\(pro) understands the role of nursing but engagement is inconsistent."
        } else if understanding == .fair && (compliance == .full || compliance == .reasonable) {
            return "\(pro) has some understanding of nursing care and \(engages) reasonably well."
        } else if understanding == .fair && compliance == .partial {
            return "\(pro) has some understanding of nursing input but \(engages) only partially."
        } else if understanding == .poor || compliance == .none {
            return "\(pro) has limited insight into the need for nursing care and \(does) not engage meaningfully."
        }
        return ""
    }

    private func attPsychologyPhrase(_ understanding: UnderstandingLevel, compliance: ComplianceLevel, pro: String, engages: String, does: String) -> String {
        if understanding == .good && (compliance == .full || compliance == .reasonable) {
            return "\(pro) \(engages) in psychology sessions and sees the benefit of this work."
        } else if understanding == .good && compliance == .partial {
            return "\(pro) understands the purpose of psychology but compliance with sessions is limited."
        } else if understanding == .fair && (compliance == .full || compliance == .reasonable) {
            return "\(pro) has some understanding of psychology and attends sessions regularly."
        } else if understanding == .fair && compliance == .partial {
            return "\(pro) also \(engages) in psychology sessions but the compliance with these is limited."
        } else if understanding == .poor || compliance == .none {
            return "\(pro) has limited insight into the need for psychology and \(does) not engage with sessions."
        }
        return ""
    }

    private func attOTPhrase(_ understanding: UnderstandingLevel, compliance: ComplianceLevel, proL: String, engages: String, isAre: String) -> String {
        if understanding == .good && (compliance == .full || compliance == .reasonable) {
            return "With respect to OT, \(proL) \(engages) well and sees the benefit of activities."
        } else if understanding == .good && compliance == .partial {
            return "With respect to OT, \(proL) understands the purpose but engagement is inconsistent."
        } else if understanding == .fair && (compliance == .full || compliance == .reasonable) {
            return "With respect to OT, \(proL) has some understanding and participates in activities."
        } else if understanding == .fair && compliance == .partial {
            return "With respect to OT, \(proL) has some insight but engagement is limited."
        } else if understanding == .poor || compliance == .none {
            return "With respect to OT, \(proL) \(isAre) not engaging and doesn't see the need to."
        }
        return ""
    }

    private func attSocialWorkPhrase(_ understanding: UnderstandingLevel, compliance: ComplianceLevel, pro: String, engages: String, pos: String, sees: String) -> String {
        if understanding == .good && (compliance == .full || compliance == .reasonable) {
            return "\(pro) \(engages) well with the social worker and understands \(pos) social circumstances."
        } else if understanding == .good && compliance == .partial {
            return "\(pro) understands the social worker's role but engagement is inconsistent."
        } else if understanding == .fair && (compliance == .full || compliance == .reasonable) {
            return "\(pro) has some understanding of social work input and \(engages) when available."
        } else if understanding == .fair && compliance == .partial {
            return "\(pro) occasionally \(sees) the social worker and \(engages) partially when doing so."
        } else if understanding == .poor || compliance == .none {
            return "\(pro) has limited engagement with social work and doesn't see the relevance."
        }
        return ""
    }

    private func generateCapacityText() -> String {
        let pro = formData.patientGender == .male ? "He" : formData.patientGender == .female ? "She" : "They"
        let has = formData.patientGender == .other ? "have" : "has"
        let lacks = formData.patientGender == .other ? "lack" : "lacks"

        // Helper to format lists with "and" before last item
        func formatList(_ items: [String]) -> String {
            if items.isEmpty { return "" }
            if items.count == 1 { return items[0] }
            if items.count == 2 { return "\(items[0]) and \(items[1])" }
            return items.dropLast().joined(separator: ", ") + " and " + items.last!
        }

        var hasCapacityAreas: [String] = []
        var lacksCapacityParts: [String] = []

        let areas: [(name: String, type: CapacityAreaType, area: ASRCapacityArea)] = [
            ("residence", .residence, formData.capResidence),
            ("medication", .medication, formData.capMedication),
            ("finances", .finances, formData.capFinances),
            ("leave", .leave, formData.capLeave)
        ]

        for (name, areaType, area) in areas {
            if area.status == .hasCapacity {
                hasCapacityAreas.append(name)
            } else if area.status == .lacksCapacity {
                var areaPart = "\(pro) \(lacks) capacity for \(name) decisions"
                var selectedActions: [String] = []

                switch areaType {
                case .medication:
                    // Handle MHA paperwork and SOAD
                    if area.mhaPaperwork == true {
                        selectedActions.append("SOAD paperwork is in place")
                    } else if area.mhaPaperwork == false {
                        if area.soadRequested == true {
                            selectedActions.append("a SOAD has been requested")
                        } else if area.soadRequested == false {
                            selectedActions.append("a SOAD has not yet been requested")
                        }
                    }

                case .finances:
                    // Handle finance special case
                    if area.bestInterest { selectedActions.append("a Best Interest decision is in place") }
                    if area.imca { selectedActions.append("an IMCA has been appointed") }
                    switch area.financeType {
                    case .guardianship: selectedActions.append("Guardianship is being considered")
                    case .appointeeship: selectedActions.append("an Appointeeship is in place")
                    case .informalAppointeeship: selectedActions.append("informal appointeeship arrangements are in place")
                    case .none: break
                    }

                case .residence, .leave:
                    // Handle checkboxes
                    if area.bestInterest { selectedActions.append("a Best Interest decision is in place") }
                    if area.imca { selectedActions.append("an IMCA has been appointed") }
                    if area.dols { selectedActions.append("a DoLS application has been made") }
                    if area.cop { selectedActions.append("a Court of Protection application is being considered") }
                }

                if !selectedActions.isEmpty {
                    areaPart += " and " + selectedActions.joined(separator: ", ")
                }
                lacksCapacityParts.append(areaPart + ".")
            }
        }

        var parts: [String] = []

        // Has capacity areas
        if !hasCapacityAreas.isEmpty {
            let areasText = formatList(hasCapacityAreas)
            parts.append("\(pro) \(has) capacity for \(areasText) decisions.")
        }

        // Lacks capacity parts
        parts.append(contentsOf: lacksCapacityParts)

        if !formData.capacityNotes.isEmpty {
            parts.append(formData.capacityNotes)
        }

        let baseText = parts.joined(separator: " ")
        return appendImportedNotes(formData.capacityImportedEntries, to: baseText)
    }

    private func generateManagingRiskText() -> String {
        // Risk labels matching Section 5 risk factors
        let riskLabels = [
            ("violenceOthers", "violence to others", formData.currentRiskViolenceOthers, formData.historicalRiskViolenceOthers),
            ("violenceProperty", "violence to property", formData.currentRiskViolenceProperty, formData.historicalRiskViolenceProperty),
            ("verbalAggression", "verbal aggression", formData.currentRiskVerbalAggression, formData.historicalRiskVerbalAggression),
            ("substanceMisuse", "substance misuse", formData.currentRiskSubstanceMisuse, formData.historicalRiskSubstanceMisuse),
            ("selfHarm", "self harm", formData.currentRiskSelfHarm, formData.historicalRiskSelfHarm),
            ("selfNeglect", "self neglect", formData.currentRiskSelfNeglect, formData.historicalRiskSelfNeglect),
            ("stalking", "stalking", formData.currentRiskStalking, formData.historicalRiskStalking),
            ("threateningBehaviour", "threatening behaviour", formData.currentRiskThreateningBehaviour, formData.historicalRiskThreateningBehaviour),
            ("sexuallyInappropriate", "sexually inappropriate behaviour", formData.currentRiskSexuallyInappropriate, formData.historicalRiskSexuallyInappropriate),
            ("vulnerability", "vulnerability", formData.currentRiskVulnerability, formData.historicalRiskVulnerability),
            ("bullyingVictimisation", "bullying/victimisation", formData.currentRiskBullyingVictimisation, formData.historicalRiskBullyingVictimisation),
            ("absconding", "absconding/AWOL", formData.currentRiskAbsconding, formData.historicalRiskAbsconding),
            ("reoffending", "reoffending", formData.currentRiskReoffending, formData.historicalRiskReoffending)
        ]

        func buildNarrative(_ risks: [(String, Int)], isHistorical: Bool) -> String? {
            let activeRisks = risks.filter { $0.1 > 0 }
            guard !activeRisks.isEmpty else { return nil }

            let severityWords = [1: "low", 2: "moderate", 3: "high"]
            let high = activeRisks.filter { $0.1 == 3 }.map { $0.0 }
            let moderate = activeRisks.filter { $0.1 == 2 }.map { $0.0 }
            let low = activeRisks.filter { $0.1 == 1 }.map { $0.0 }

            func joinList(_ items: [String]) -> String {
                if items.count == 1 { return items[0] }
                if items.count == 2 { return "\(items[0]) and \(items[1])" }
                return items.dropLast().joined(separator: ", ") + ", and " + items.last!
            }

            var parts: [String] = []
            let prefix = isHistorical ? "Historically, the" : "The"

            if !high.isEmpty {
                parts.append("risk of \(joinList(high)) is high")
            }
            if !moderate.isEmpty {
                if parts.isEmpty {
                    parts.append("risk of \(joinList(moderate)) is moderate")
                } else {
                    parts.append("\(joinList(moderate)) is moderate")
                }
            }
            if !low.isEmpty {
                if parts.isEmpty {
                    parts.append("risk of \(joinList(low)) is low")
                } else {
                    parts.append("\(joinList(low)) is low")
                }
            }

            if parts.count == 1 {
                return "\(prefix) \(parts[0])."
            } else if parts.count == 2 {
                return "\(prefix) \(parts[0]), and \(parts[1])."
            } else {
                return "\(prefix) \(parts[0]), \(parts[1]), and \(parts[2])."
            }
        }

        let currentRisks = riskLabels.map { ($0.1, $0.2) }
        let historicalRisks = riskLabels.map { ($0.1, $0.3) }

        var sections: [String] = []
        if let current = buildNarrative(currentRisks, isHistorical: false) {
            sections.append(current)
        }
        if let historical = buildNarrative(historicalRisks, isHistorical: true) {
            sections.append(historical)
        }

        let baseText = sections.isEmpty ? "No specific risk factors identified." : sections.joined(separator: "\n\n")
        return appendImportedNotes(formData.riskImportedEntries, to: baseText)
    }

    private func generateRiskAddressedText() -> String {
        var parts: [String] = []

        if !formData.riskProgressText.isEmpty {
            parts.append("Progress and issues of concern: \(formData.riskProgressText)")
        }

        if !formData.riskFactorsText.isEmpty {
            parts.append("Factors underpinning index offence: \(formData.riskFactorsText)")
        }

        if !formData.riskAttitudesText.isEmpty {
            parts.append("Attitudes to index offence and victims: \(formData.riskAttitudesText)")
        }

        switch formData.preventReferral {
        case .yes:
            if !formData.preventOutcome.isEmpty {
                parts.append("The patient has been referred to Prevent. Outcome: \(formData.preventOutcome)")
            } else {
                parts.append("The patient has been referred to Prevent.")
            }
        case .no:
            parts.append("The patient has not been referred to Prevent.")
        case .notApplicable:
            parts.append("Prevent is not applicable in this case.")
        case .notSelected:
            break
        }

        let baseText = parts.isEmpty ? "[No information provided]" : parts.joined(separator: "\n")
        return appendImportedNotes(formData.riskAddressedImportedEntries, to: baseText)
    }

    private func generateAbscondText() -> String {
        var baseText: String
        if !formData.hasAwolIncidents {
            baseText = "There have been no AWOL incidents in the last 12 months."
        } else if !formData.abscondDetails.isEmpty {
            baseText = "There have been AWOL incidents in the last 12 months. \(formData.abscondDetails)"
        } else {
            baseText = "There have been AWOL incidents in the last 12 months."
        }
        return appendImportedNotes(formData.abscondImportedEntries, to: baseText)
    }

    private func generateMappaText() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"

        if formData.mappaCategory == .notApplicable {
            return appendImportedNotes(formData.mappaImportedEntries, to: "Patient is not currently referred to MAPPA.")
        }

        var parts: [String] = []
        parts.append("MAPPA Category: \(formData.mappaCategory.rawValue)")
        parts.append("Level: \(formData.mappaLevel.rawValue)")

        if formData.mappaDateKnown {
            parts.append("Date of referral: \(dateFormatter.string(from: formData.mappaDate))")
        } else {
            parts.append("Date of referral: Not known")
        }

        if !formData.mappaComments.isEmpty {
            parts.append("Comments: \(formData.mappaComments)")
        }

        if !formData.mappaCoordinator.isEmpty {
            parts.append("MAPPA Coordinator: \(formData.mappaCoordinator)")
        }

        let baseText = parts.joined(separator: "\n")
        return appendImportedNotes(formData.mappaImportedEntries, to: baseText)
    }

    private func generateVictimsText() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"

        var parts: [String] = []

        if !formData.vloContact.isEmpty {
            parts.append("Victim Liaison Officer: \(formData.vloContact)")
        }

        if formData.vloDateKnown {
            parts.append("Date of last contact with VLO: \(dateFormatter.string(from: formData.vloDate))")
        } else {
            parts.append("Date of last contact with VLO: Not known")
        }

        if !formData.victimConcerns.isEmpty {
            parts.append("Victim-related concerns (last 12 months): \(formData.victimConcerns)")
        }

        let baseText = parts.isEmpty ? "No victim liaison information available." : parts.joined(separator: "\n")
        return appendImportedNotes(formData.victimsImportedEntries, to: baseText)
    }

    private func generateAdditionalCommentsText() -> String {
        let pro = formData.patientGender == .male ? "He" : formData.patientGender == .female ? "She" : "They"
        let suffers = formData.patientGender == .other ? "suffer" : "suffers"
        let does = formData.patientGender == .other ? "do" : "does"
        let pos = formData.patientGender == .male ? "his" : formData.patientGender == .female ? "her" : "their"

        var parts: [String] = []

        // 1. Mental Disorder + Nature/Degree
        if formData.mentalDisorderPresent == true {
            var mdBase = "\(pro) \(suffers) from a mental disorder"
            if formData.mentalDisorderICD10 != .none {
                mdBase += " (\(formData.mentalDisorderICD10.rawValue))"
            }
            mdBase += " under the Mental Health Act"

            if formData.criteriaWarrantingDetention == true {
                let natureChecked = formData.criteriaByNature
                let degreeChecked = formData.criteriaByDegree

                if natureChecked && degreeChecked {
                    mdBase += ", which is of a nature and degree to warrant detention."
                } else if natureChecked {
                    mdBase += ", which is of a nature to warrant detention."
                } else if degreeChecked {
                    mdBase += ", which is of a degree to warrant detention."
                } else {
                    mdBase += "."
                }
                parts.append(mdBase)

                // Nature sub-options
                if natureChecked {
                    var natureTypes: [String] = []
                    if formData.natureRelapsing { natureTypes.append("relapsing and remitting") }
                    if formData.natureTreatmentResistant { natureTypes.append("treatment resistant") }
                    if formData.natureChronic { natureTypes.append("chronic and enduring") }

                    if !natureTypes.isEmpty {
                        parts.append("The illness is of a \(natureTypes.joined(separator: ", ")) nature.")
                    }
                }

                // Degree sub-options
                if degreeChecked {
                    let levels = ["some", "several", "many", "overwhelming"]
                    let level = levels[min(formData.degreeSeverity - 1, 3)]
                    let details = formData.degreeDetails.trimmingCharacters(in: .whitespacesAndNewlines)

                    if !details.isEmpty {
                        parts.append("The degree of the illness is evidenced by \(level) symptoms including \(details).")
                    } else {
                        parts.append("The degree of the illness is evidenced by \(level) symptoms.")
                    }
                }
            } else if formData.criteriaWarrantingDetention == false {
                parts.append(mdBase + ". The criteria for detention are not met.")
            } else {
                parts.append(mdBase + ".")
            }
        } else if formData.mentalDisorderPresent == false {
            parts.append("\(pro) \(does) not suffer from a mental disorder under the Mental Health Act.")
        }

        // 2. Necessity - Health
        if formData.necessity == true {
            if formData.healthNecessity {
                if formData.mentalHealthNecessity {
                    parts.append("Medical treatment under the Mental Health Act is necessary to prevent deterioration in \(pos) mental health.")

                    let poor = formData.poorCompliance
                    let limited = formData.limitedInsight

                    if poor && limited {
                        parts.append("Both historical non compliance and current limited insight makes the risk on stopping medication high without the safeguards of the Mental Health Act. This would result in a deterioration of \(pos) mental state.")
                    } else if poor {
                        parts.append("This is based on historical non compliance and without detention I would be concerned this would result in a deterioration of \(pos) mental state.")
                    } else if limited {
                        parts.append("I am concerned about \(pos) current limited insight into \(pos) mental health needs and how this would result in immediate non compliance with medication, hence a deterioration in \(pos) mental health.")
                    }
                }

                if formData.physicalHealthNecessity {
                    let phDetails = formData.physicalHealthDetails.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !phDetails.isEmpty {
                        parts.append("Medical treatment is also necessary for \(pos) physical health: \(phDetails)")
                    } else {
                        parts.append("Medical treatment is also necessary for \(pos) physical health.")
                    }
                }
            }

            // Safety - combined
            if formData.safetyNecessity {
                let selfChecked = formData.selfSafety
                let othersChecked = formData.othersSafety

                if selfChecked && othersChecked {
                    parts.append("Detention is necessary for \(pos) own safety and for the protection of others.")
                } else if selfChecked {
                    parts.append("Detention is necessary for \(pos) own safety.")
                } else if othersChecked {
                    parts.append("Detention is necessary for the protection of others.")
                }

                // Self safety details - matching A3 format
                if selfChecked {
                    let reflexive = formData.patientGender == .male ? "himself" :
                                    formData.patientGender == .female ? "herself" : "themselves"

                    // Build risk categories: both (hist+curr), hist only, curr only
                    var bothItems: [String] = []
                    var histOnly: [String] = []
                    var currOnly: [String] = []

                    // Self neglect
                    if formData.selfNeglectHistorical && formData.selfNeglectCurrent {
                        bothItems.append("self neglect")
                    } else if formData.selfNeglectHistorical {
                        histOnly.append("self neglect")
                    } else if formData.selfNeglectCurrent {
                        currOnly.append("self neglect")
                    }

                    // Risky behaviour
                    if formData.selfRiskyHistorical && formData.selfRiskyCurrent {
                        bothItems.append("placing of \(reflexive) in risky situations")
                    } else if formData.selfRiskyHistorical {
                        histOnly.append("placing of \(reflexive) in risky situations")
                    } else if formData.selfRiskyCurrent {
                        currOnly.append("placing of \(reflexive) in risky situations")
                    }

                    // Self harm
                    if formData.selfHarmHistorical && formData.selfHarmCurrent {
                        bothItems.append("self harm")
                    } else if formData.selfHarmHistorical {
                        histOnly.append("self harm")
                    } else if formData.selfHarmCurrent {
                        currOnly.append("self harm")
                    }

                    if !bothItems.isEmpty || !histOnly.isEmpty || !currOnly.isEmpty {
                        var selfText = "With respect to \(pos) own safety we are concerned about"
                        var riskParts: [String] = []

                        if !bothItems.isEmpty {
                            if bothItems.count == 1 {
                                riskParts.append("historical and current \(bothItems[0])")
                            } else {
                                let lastItem = bothItems.removeLast()
                                riskParts.append("historical and current \(bothItems.joined(separator: ", ")), and of \(lastItem)")
                            }
                        }
                        if !histOnly.isEmpty {
                            if histOnly.count == 1 {
                                riskParts.append("historical \(histOnly[0])")
                            } else {
                                let lastItem = histOnly.removeLast()
                                riskParts.append("historical \(histOnly.joined(separator: ", ")), and of \(lastItem)")
                            }
                        }
                        if !currOnly.isEmpty {
                            if currOnly.count == 1 {
                                riskParts.append("current \(currOnly[0])")
                            } else {
                                let lastItem = currOnly.removeLast()
                                riskParts.append("current \(currOnly.joined(separator: ", ")), and of \(lastItem)")
                            }
                        }

                        selfText += " " + riskParts.joined(separator: ", and ") + "."
                        parts.append(selfText)
                    }

                    let selfDetails = formData.selfSafetyDetails.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !selfDetails.isEmpty {
                        parts.append(selfDetails)
                    }
                }

                // Others safety details - matching A3 format
                if othersChecked {
                    var bothItems: [String] = []
                    var histOnly: [String] = []
                    var currOnly: [String] = []

                    // Violence
                    if formData.violenceHistorical && formData.violenceCurrent {
                        bothItems.append("violence to others")
                    } else if formData.violenceHistorical {
                        histOnly.append("violence to others")
                    } else if formData.violenceCurrent {
                        currOnly.append("violence to others")
                    }

                    // Verbal aggression
                    if formData.verbalAggressionHistorical && formData.verbalAggressionCurrent {
                        bothItems.append("verbal aggression")
                    } else if formData.verbalAggressionHistorical {
                        histOnly.append("verbal aggression")
                    } else if formData.verbalAggressionCurrent {
                        currOnly.append("verbal aggression")
                    }

                    // Sexual violence
                    if formData.sexualViolenceHistorical && formData.sexualViolenceCurrent {
                        bothItems.append("sexual violence")
                    } else if formData.sexualViolenceHistorical {
                        histOnly.append("sexual violence")
                    } else if formData.sexualViolenceCurrent {
                        currOnly.append("sexual violence")
                    }

                    // Stalking
                    if formData.stalkingHistorical && formData.stalkingCurrent {
                        bothItems.append("stalking")
                    } else if formData.stalkingHistorical {
                        histOnly.append("stalking")
                    } else if formData.stalkingCurrent {
                        currOnly.append("stalking")
                    }

                    // Arson
                    if formData.arsonHistorical && formData.arsonCurrent {
                        bothItems.append("arson")
                    } else if formData.arsonHistorical {
                        histOnly.append("arson")
                    } else if formData.arsonCurrent {
                        currOnly.append("arson")
                    }

                    if !bothItems.isEmpty || !histOnly.isEmpty || !currOnly.isEmpty {
                        var othersText = "With respect to risk to others we are concerned about the risk of"
                        var riskParts: [String] = []

                        if !bothItems.isEmpty {
                            riskParts.append("historical and current \(bothItems.joined(separator: ", "))")
                        }
                        if !histOnly.isEmpty {
                            riskParts.append("historical \(histOnly.joined(separator: ", "))")
                        }
                        if !currOnly.isEmpty {
                            riskParts.append("current \(currOnly.joined(separator: ", "))")
                        }

                        othersText += " " + riskParts.joined(separator: " and of ") + "."
                        parts.append(othersText)
                    }

                    let othersDetails = formData.othersSafetyDetails.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !othersDetails.isEmpty {
                        parts.append(othersDetails)
                    }
                }
            }
        }

        // 3. Treatment Available & Least Restrictive - combined
        let treatmentChecked = formData.treatmentAvailable
        let leastChecked = formData.leastRestrictiveOption

        if treatmentChecked && leastChecked {
            parts.append("I can confirm appropriate medical treatment is available and this is the least restrictive option for \(pos) care.")
        } else if treatmentChecked {
            parts.append("I can confirm appropriate medical treatment is available.")
        } else if leastChecked {
            parts.append("This is the least restrictive option for \(pos) care.")
        }

        // 4. Additional comments text
        let additional = formData.additionalCommentsText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !additional.isEmpty {
            parts.append(additional)
        }

        return parts.isEmpty ? "No additional comments." : parts.joined(separator: " ")
    }

    private func generateUnfitToPleadText() -> String {
        // Not found unfit to plead
        if formData.foundUnfitToPlead == false {
            return "Not applicable."
        }

        // Not selected
        guard formData.foundUnfitToPlead == true else {
            return "[Select whether patient was found unfit to plead]"
        }

        var result: String
        if formData.nowFitToPlead == true {
            result = "The patient is now considered fit to plead."
        } else if formData.nowFitToPlead == false {
            result = "The patient remains unfit to plead."
        } else {
            result = "[Fitness to plead status not selected]"
        }

        if !formData.unfitToPleadDetails.isEmpty {
            result += " \(formData.unfitToPleadDetails)"
        }

        return result
    }

    private func generateLeaveReportText() -> String {
        let pro = formData.patientGender == .male ? "He" : formData.patientGender == .female ? "She" : "They"
        let proL = pro.lowercased()
        let has = formData.patientGender == .other ? "have" : "has"
        let pos = formData.patientGender == .male ? "His" : formData.patientGender == .female ? "Her" : "Their"

        func generateLeaveFromState(_ state: ASRLeaveState, escortType: String) -> String {
            var parts: [String] = []

            let leaveTypeLabels: [String: String] = [
                "ground": "ground leave",
                "local": "local community leave",
                "community": "community leave",
                "extended": "extended community leave",
                "overnight": "overnight leave"
            ]

            // Collect checked types with weights, sorted by weight descending
            var checkedTypes: [(key: String, weight: Int, label: String)] = []
            if state.ground.enabled { checkedTypes.append(("ground", state.ground.weight, leaveTypeLabels["ground"]!)) }
            if state.local.enabled { checkedTypes.append(("local", state.local.weight, leaveTypeLabels["local"]!)) }
            if state.community.enabled { checkedTypes.append(("community", state.community.weight, leaveTypeLabels["community"]!)) }
            if state.extended.enabled { checkedTypes.append(("extended", state.extended.weight, leaveTypeLabels["extended"]!)) }
            if state.overnight.enabled { checkedTypes.append(("overnight", state.overnight.weight, leaveTypeLabels["overnight"]!)) }

            checkedTypes.sort { $0.weight > $1.weight }

            if !checkedTypes.isEmpty {
                var typePhrases: [String] = []
                for (i, item) in checkedTypes.enumerated() {
                    if i == 0 {
                        typePhrases.append("mainly \(item.label)")
                    } else if i == 1 {
                        typePhrases.append("but also some \(item.label)")
                    } else if i == 2 {
                        typePhrases.append("and to a lesser extent \(item.label)")
                    } else {
                        typePhrases.append("and occasionally \(item.label)")
                    }
                }

                let typeStr = typePhrases.count > 1 ? typePhrases.joined(separator: ", ") : typePhrases[0]
                let leaves = state.leavesPerPeriod
                let leavePlural = leaves == 1 ? "" : "s"
                let frequency = state.frequency.lowercased()
                let duration = state.duration

                parts.append("Over the past year, \(proL) \(has) taken approximately \(leaves) \(escortType) leave\(leavePlural) \(frequency), averaging \(duration) per leave, engaging in \(typeStr).")
            }

            // Other leave types
            var otherTypes: [String] = []
            if state.medical { otherTypes.append("medical appointments") }
            if state.court { otherTypes.append("court appearances") }
            if state.compassionate { otherTypes.append("compassionate visits") }

            if !otherTypes.isEmpty {
                if otherTypes.count == 1 {
                    parts.append("\(pro) \(has) also taken leave for \(otherTypes[0]).")
                } else {
                    let lastType = otherTypes.removeLast()
                    parts.append("\(pro) \(has) also taken leave for \(otherTypes.joined(separator: ", ")) and \(lastType).")
                }
            }

            // Leave suspension
            if state.suspended == true {
                let details = state.suspensionDetails.trimmingCharacters(in: .whitespacesAndNewlines)
                if !details.isEmpty {
                    parts.append("\(pos) leave has been suspended in the past. \(details)")
                } else {
                    parts.append("\(pos) leave has been suspended in the past.")
                }
            } else if state.suspended == false {
                parts.append("\(pos) leave has never been suspended.")
            }

            return parts.joined(separator: " ")
        }

        var resultParts: [String] = []

        let escortedText = generateLeaveFromState(formData.escortedLeave, escortType: "escorted")
        let unescortedText = generateLeaveFromState(formData.unescortedLeave, escortType: "unescorted")

        if !escortedText.isEmpty {
            resultParts.append("ESCORTED LEAVE: \(escortedText)")
        }
        if !unescortedText.isEmpty {
            resultParts.append("UNESCORTED LEAVE: \(unescortedText)")
        }

        let baseText = resultParts.isEmpty ? "No leave information provided." : resultParts.joined(separator: "\n\n")
        return appendImportedNotes(formData.leaveReportImportedEntries, to: baseText)
    }

    private func generateSignatureText() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return """
        \(formData.rcName)
        \(formData.rcJobTitle)
        Responsible Clinician
        \(formData.hospitalName)
        Date: \(formatter.string(from: formData.signatureDate))
        """
    }
}

// MARK: - Helper Views

struct BehaviourCategoryRow: View {
    let label: String
    @Binding var item: ASRBehaviourItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(.caption)
                Spacer()
                Picker("", selection: $item.present) {
                    Text("No").tag(false)
                    Text("Yes").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 90)
            }
            if item.present {
                TextField("Details...", text: $item.details)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
            }
        }
    }
}

struct TreatmentAttitudeRow: View {
    let label: String
    @Binding var attitude: ASRTreatmentAttitude

    var body: some View {
        HStack(spacing: 8) {
            Text(label).font(.caption).frame(width: 70, alignment: .leading)
            Picker("", selection: $attitude.understanding) {
                ForEach(UnderstandingLevel.allCases) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.menu).frame(maxWidth: .infinity)
            Picker("", selection: $attitude.compliance) {
                ForEach(ComplianceLevel.allCases) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.menu).frame(maxWidth: .infinity)
        }
    }
}

enum CapacityAreaType {
    case residence  // Best Interest, IMCA, DoLS, COP
    case medication // MHA paperwork in place? -> SOAD requested?
    case finances   // Best Interest, IMCA + Guardianship/Appointeeship radio
    case leave      // Best Interest, IMCA, DoLS, COP (same as residence)
}

struct CapacityAreaRow: View {
    let label: String
    let areaType: CapacityAreaType
    @Binding var area: ASRCapacityArea

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(.caption).fontWeight(.medium)
                Spacer()
                Picker("", selection: $area.status) {
                    ForEach(CapacityStatus.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.menu)
            }

            if area.status == .lacksCapacity {
                switch areaType {
                case .residence, .leave:
                    // Checkboxes: Best Interest, IMCA, DoLS, COP
                    HStack(spacing: 8) {
                        Toggle("Best Interest", isOn: $area.bestInterest)
                        Toggle("IMCA", isOn: $area.imca)
                        Toggle("DoLS", isOn: $area.dols)
                        Toggle("COP", isOn: $area.cop)
                    }
                    .toggleStyle(.asrCheckbox)
                    .font(.caption2)

                case .medication:
                    // MHA paperwork in place? (Yes/No)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 12) {
                            Text("MHA paperwork in place:").font(.caption)
                            Button(action: { area.mhaPaperwork = true }) {
                                HStack(spacing: 4) {
                                    Image(systemName: area.mhaPaperwork == true ? "largecircle.fill.circle" : "circle")
                                    Text("Yes")
                                }
                            }
                            .foregroundColor(area.mhaPaperwork == true ? .red : .secondary)
                            Button(action: { area.mhaPaperwork = false }) {
                                HStack(spacing: 4) {
                                    Image(systemName: area.mhaPaperwork == false ? "largecircle.fill.circle" : "circle")
                                    Text("No")
                                }
                            }
                            .foregroundColor(area.mhaPaperwork == false ? .red : .secondary)
                        }
                        .font(.caption)
                        .buttonStyle(.plain)

                        // Show SOAD question if MHA = No
                        if area.mhaPaperwork == false {
                            HStack(spacing: 12) {
                                Text("SOAD requested:").font(.caption)
                                Button(action: { area.soadRequested = true }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: area.soadRequested == true ? "largecircle.fill.circle" : "circle")
                                        Text("Yes")
                                    }
                                }
                                .foregroundColor(area.soadRequested == true ? .red : .secondary)
                                Button(action: { area.soadRequested = false }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: area.soadRequested == false ? "largecircle.fill.circle" : "circle")
                                        Text("No")
                                    }
                                }
                                .foregroundColor(area.soadRequested == false ? .red : .secondary)
                            }
                            .font(.caption)
                            .buttonStyle(.plain)
                        }
                    }

                case .finances:
                    // Checkboxes: Best Interest, IMCA
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Toggle("Best Interest", isOn: $area.bestInterest)
                            Toggle("IMCA", isOn: $area.imca)
                        }
                        .toggleStyle(.asrCheckbox)
                        .font(.caption2)

                        // Radio buttons: None, Guardianship, Appointeeship, Informal Appointeeship
                        HStack(spacing: 8) {
                            ForEach(FinanceCapacityType.allCases) { finType in
                                Button(action: { area.financeType = finType }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: area.financeType == finType ? "largecircle.fill.circle" : "circle")
                                        Text(finType.rawValue)
                                    }
                                }
                                .foregroundColor(area.financeType == finType ? .red : .secondary)
                            }
                        }
                        .font(.caption2)
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct SliderWithLabel: View {
    @Binding var value: Int
    let options: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(options[min(value, options.count - 1)])
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.red)
            Slider(value: Binding(get: { Double(value) }, set: { value = Int($0) }), in: 0...Double(options.count - 1), step: 1)
                .tint(.red)
        }
    }
}

/// Section 9 Risk Factor row with checkbox and Low/Medium/High severity
struct RiskFactorRowSection9: View {
    let label: String
    @Binding var value: Int  // 0=unchecked, 1=Low, 2=Medium, 3=High
    var tintColor: Color = .red

    private var isChecked: Bool { value > 0 }
    private let severityOptions = ["Low", "Medium", "High"]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Button {
                    if value == 0 { value = 1 } else { value = 0 }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                            .foregroundColor(isChecked ? tintColor : .gray)
                        Text(label)
                            .foregroundColor(.primary)
                    }
                }
                .buttonStyle(.plain)
                Spacer()
            }

            if isChecked {
                HStack(spacing: 8) {
                    ForEach(1...3, id: \.self) { level in
                        Button {
                            value = level
                        } label: {
                            Text(severityOptions[level - 1])
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(value == level ? tintColor : Color(.systemGray5))
                                .foregroundColor(value == level ? .white : .primary)
                                .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .padding(.leading, 28)
            }
        }
    }
}

struct LeaveReportSection: View {
    @Binding var escortedLeave: ASRLeaveState
    @Binding var unescortedLeave: ASRLeaveState
    @State private var showingEscorted = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("", selection: $showingEscorted) {
                Text("Escorted").tag(true)
                Text("Unescorted").tag(false)
            }.pickerStyle(.segmented)
            LeaveStateEditor(state: showingEscorted ? $escortedLeave : $unescortedLeave)
        }
    }
}

struct LeaveStateEditor: View {
    @Binding var state: ASRLeaveState
    let frequencies = ["Weekly", "2 weekly", "3 weekly", "Monthly", "2 monthly"]
    let durations = ["30 mins", "1 hour", "2 hours", "3 hours", "4 hours", "5 hours", "6 hours", "7 hours", "8 hours"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Row 1: Leaves, Frequency, Duration
            HStack {
                Text("Leaves:").font(.caption)
                Picker("", selection: $state.leavesPerPeriod) { ForEach(1..<8, id: \.self) { Text("\($0)").tag($0) } }.pickerStyle(.menu)
                Text("Frequency:").font(.caption)
                Picker("", selection: $state.frequency) { ForEach(frequencies, id: \.self) { Text($0).tag($0) } }.pickerStyle(.menu)
            }
            HStack {
                Text("Duration:").font(.caption)
                Picker("", selection: $state.duration) { ForEach(durations, id: \.self) { Text($0).tag($0) } }.pickerStyle(.menu)
            }

            // Leave types with linked sliders
            VStack(alignment: .leading, spacing: 6) {
                Text("Leave Types & Weighting").font(.caption).fontWeight(.medium)
                    .padding(.top, 4)

                LinkedLeaveTypeRow(label: "Ground", weight: $state.ground, allWeights: allWeightsBinding)
                LinkedLeaveTypeRow(label: "Local", weight: $state.local, allWeights: allWeightsBinding)
                LinkedLeaveTypeRow(label: "Community", weight: $state.community, allWeights: allWeightsBinding)
                LinkedLeaveTypeRow(label: "Extended", weight: $state.extended, allWeights: allWeightsBinding)
                LinkedLeaveTypeRow(label: "Overnight", weight: $state.overnight, allWeights: allWeightsBinding)
            }
            .padding(10)
            .background(Color.indigo.opacity(0.1))
            .cornerRadius(8)

            // Other leave types
            VStack(alignment: .leading, spacing: 6) {
                Text("Other Leave").font(.caption).fontWeight(.medium)
                HStack {
                    Toggle("Medical", isOn: $state.medical)
                    Toggle("Court", isOn: $state.court)
                    Toggle("Compassionate", isOn: $state.compassionate)
                }.toggleStyle(.asrCheckbox).font(.caption)
            }
            .padding(10)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)

            // Leave suspended
            VStack(alignment: .leading, spacing: 8) {
                Text("Leave Ever Suspended").font(.caption).fontWeight(.medium)
                Picker("", selection: Binding(
                    get: { state.suspended ?? false ? 1 : (state.suspended == nil ? -1 : 0) },
                    set: { state.suspended = $0 == 1 ? true : ($0 == 0 ? false : nil) }
                )) {
                    Text("Select...").tag(-1)
                    Text("No").tag(0)
                    Text("Yes").tag(1)
                }
                .pickerStyle(.segmented)

                if state.suspended == true {
                    TextEditor(text: $state.suspensionDetails)
                        .frame(minHeight: 60)
                        .padding(6)
                        .background(Color(.systemBackground))
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(.systemGray4), lineWidth: 1))
                }
            }
            .padding(10)
            .background(Color.red.opacity(0.1))
            .cornerRadius(8)
        }
    }

    private var allWeightsBinding: Binding<[String: Binding<ASRLeaveTypeWeight>]> {
        Binding(
            get: {
                [
                    "ground": $state.ground,
                    "local": $state.local,
                    "community": $state.community,
                    "extended": $state.extended,
                    "overnight": $state.overnight
                ]
            },
            set: { _ in }
        )
    }
}

struct LinkedLeaveTypeRow: View {
    let label: String
    @Binding var weight: ASRLeaveTypeWeight
    let allWeights: Binding<[String: Binding<ASRLeaveTypeWeight>]>

    var body: some View {
        HStack {
            Button {
                if weight.enabled {
                    // Unchecking - redistribute weight to others
                    let removedWeight = weight.weight
                    weight.enabled = false
                    weight.weight = 0
                    redistributeWeight(removedWeight: removedWeight)
                } else {
                    // Checking - take weight from others
                    weight.enabled = true
                    addNewWeight()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: weight.enabled ? "checkmark.square.fill" : "square")
                        .foregroundColor(weight.enabled ? .indigo : .gray)
                    Text(label)
                        .foregroundColor(.primary)
                }
            }
            .buttonStyle(.plain)
            .frame(width: 110, alignment: .leading)

            if weight.enabled {
                Slider(
                    value: Binding(
                        get: { Double(weight.weight) },
                        set: { newValue in
                            let oldValue = weight.weight
                            weight.weight = Int(newValue)
                            adjustOtherWeights(changedKey: label.lowercased(), oldValue: oldValue, newValue: Int(newValue))
                        }
                    ),
                    in: 0...100
                )
                .tint(.indigo)

                Text("\(weight.weight)%")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.indigo)
                    .frame(width: 40)
            }
        }
        .font(.caption)
    }

    private func addNewWeight() {
        let weights = allWeights.wrappedValue
        let otherEnabled = weights.filter { $0.key != label.lowercased() && $0.value.wrappedValue.enabled }

        if otherEnabled.isEmpty {
            // First item gets 100%
            weight.weight = 100
        } else {
            // Take 1% from new, rest distributed proportionally
            let newShare = 1
            weight.weight = newShare
            let remaining = 100 - newShare
            let totalOther = otherEnabled.reduce(0) { $0 + $1.value.wrappedValue.weight }

            if totalOther > 0 {
                for (_, binding) in otherEnabled {
                    let proportion = Double(binding.wrappedValue.weight) / Double(totalOther)
                    binding.wrappedValue.weight = Int(proportion * Double(remaining))
                }
            }
        }
    }

    private func redistributeWeight(removedWeight: Int) {
        let weights = allWeights.wrappedValue
        let otherEnabled = weights.filter { $0.key != label.lowercased() && $0.value.wrappedValue.enabled }

        if !otherEnabled.isEmpty {
            let totalOther = otherEnabled.reduce(0) { $0 + $1.value.wrappedValue.weight }
            let newTotal = totalOther + removedWeight

            for (_, binding) in otherEnabled {
                if totalOther > 0 {
                    let proportion = Double(binding.wrappedValue.weight) / Double(totalOther)
                    binding.wrappedValue.weight = Int(proportion * Double(newTotal))
                } else {
                    binding.wrappedValue.weight = newTotal / otherEnabled.count
                }
            }
        }
    }

    private func adjustOtherWeights(changedKey: String, oldValue: Int, newValue: Int) {
        let weights = allWeights.wrappedValue
        let otherEnabled = weights.filter { $0.key != changedKey && $0.value.wrappedValue.enabled }

        guard !otherEnabled.isEmpty else { return }

        let remaining = 100 - newValue
        let totalOther = otherEnabled.reduce(0) { $0 + $1.value.wrappedValue.weight }

        if totalOther > 0 {
            for (_, binding) in otherEnabled {
                let proportion = Double(binding.wrappedValue.weight) / Double(totalOther)
                binding.wrappedValue.weight = Int(proportion * Double(remaining))
            }
        }
    }
}

struct ICD10DiagnosisPicker: View {
    let label: String
    @Binding var selectedDiagnosis: ICD10Diagnosis
    @Binding var customDiagnosis: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundColor(.secondary)
            Menu {
                Button("Clear") { selectedDiagnosis = .none; customDiagnosis = "" }
                ForEach(ICD10Diagnosis.groupedDiagnoses, id: \.0) { group, diagnoses in
                    Menu(group) {
                        ForEach(diagnoses) { diagnosis in
                            Button(diagnosis.rawValue) { selectedDiagnosis = diagnosis; customDiagnosis = "" }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(selectedDiagnosis == .none ? (customDiagnosis.isEmpty ? "Select..." : customDiagnosis) : selectedDiagnosis.rawValue)
                        .font(.caption)
                        .foregroundColor(selectedDiagnosis == .none && customDiagnosis.isEmpty ? .secondary : .primary)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.down").font(.caption2).foregroundColor(.secondary)
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(6)
            }
            if selectedDiagnosis == .none {
                TextField("Or type custom...", text: $customDiagnosis).textFieldStyle(.roundedBorder).font(.caption)
            }
        }
    }
}

struct CheckboxRow: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Button(action: { isOn.toggle() }) {
            HStack(spacing: 8) {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .foregroundColor(isOn ? .blue : .gray)
                    .frame(width: 18)
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}

/// Safety checkbox row with Historical and Current columns
struct SafetyCheckboxRow: View {
    let label: String
    @Binding var historical: Bool
    @Binding var current: Bool

    var body: some View {
        HStack(spacing: 16) {
            Text(label)
                .font(.caption)
                .frame(width: 100, alignment: .leading)
            Toggle("", isOn: $historical)
                .toggleStyle(.asrCheckbox)
                .frame(width: 70)
            Toggle("", isOn: $current)
                .toggleStyle(.asrCheckbox)
                .frame(width: 70)
        }
    }
}

/// Risk factor row with checkbox and attitude slider (shows when checked)
struct RiskFactorRow: View {
    let label: String
    @Binding var isOn: Bool
    @Binding var attitude: Int

    private let attitudeOptions = ["Avoids", "Limited", "Some", "Good", "Full"]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: { isOn.toggle() }) {
                HStack(spacing: 8) {
                    Image(systemName: isOn ? "checkmark.square.fill" : "square")
                        .foregroundColor(isOn ? .purple : .gray)
                        .frame(width: 18)
                    Text(label)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            if isOn {
                HStack(spacing: 8) {
                    Slider(value: Binding(
                        get: { Double(attitude) },
                        set: { attitude = Int($0) }
                    ), in: 0...Double(attitudeOptions.count - 1), step: 1)
                    .tint(.purple)

                    Text(attitudeOptions[min(attitude, attitudeOptions.count - 1)])
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.purple)
                        .frame(width: 60, alignment: .trailing)
                }
                .padding(.leading, 26)
            }
        }
    }
}

/// Section 4: Treatment for risk factors - shows treatments for each selected risk
struct TreatmentForRiskFactorsView: View {
    @Binding var formData: MOJASRFormData
    @State private var selectedRisk: String? = nil

    private let effectivenessOptions = ["Nil", "Minimal", "Some", "Reasonable", "Good", "Very Good", "Excellent"]
    private let concernOptions = ["Nil", "Minor", "Moderate", "Significant", "High"]

    // Get list of selected risk factors
    private var selectedRisks: [(key: String, label: String)] {
        var risks: [(key: String, label: String)] = []
        if formData.riskViolenceOthers { risks.append(("violenceOthers", "Violence to others")) }
        if formData.riskViolenceProperty { risks.append(("violenceProperty", "Violence to property")) }
        if formData.riskVerbalAggression { risks.append(("verbalAggression", "Verbal aggression")) }
        if formData.riskSubstanceMisuse { risks.append(("substanceMisuse", "Substance misuse")) }
        if formData.riskSelfHarm { risks.append(("selfHarm", "Self harm")) }
        if formData.riskSelfNeglect { risks.append(("selfNeglect", "Self neglect")) }
        if formData.riskStalking { risks.append(("stalking", "Stalking")) }
        if formData.riskThreateningBehaviour { risks.append(("threateningBehaviour", "Threatening behaviour")) }
        if formData.riskSexuallyInappropriate { risks.append(("sexuallyInappropriate", "Sexually inappropriate")) }
        if formData.riskVulnerability { risks.append(("vulnerability", "Vulnerability")) }
        if formData.riskBullyingVictimisation { risks.append(("bullyingVictimisation", "Bullying/victimisation")) }
        if formData.riskAbsconding { risks.append(("absconding", "Absconding/AWOL")) }
        if formData.riskReoffending { risks.append(("reoffending", "Reoffending")) }
        return risks
    }

    // Check if any treatment is selected for the current risk
    private func hasAnyTreatment(_ riskKey: String) -> Bool {
        let treatment = formData.treatmentData[riskKey, default: RiskTreatmentData()]
        return treatment.medication || treatment.psych1to1 || treatment.psychGroups ||
               treatment.nursing || treatment.otSupport || treatment.socialWork
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if selectedRisks.isEmpty {
                Text("Select risk factors in Section 3 above to configure treatments")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                // Radio buttons for risk factors
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(selectedRisks, id: \.key) { risk in
                            Button(action: { selectedRisk = risk.key }) {
                                Text(risk.label)
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(selectedRisk == risk.key ? Color.purple : Color.gray.opacity(0.2))
                                    .foregroundColor(selectedRisk == risk.key ? .white : .primary)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if let riskKey = selectedRisk {
                    // Treatment options for selected risk
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Treatments for \(selectedRisks.first(where: { $0.key == riskKey })?.label ?? riskKey):")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.purple)

                        TreatmentRowView(label: "Medication", isOn: treatmentBinding(riskKey, \.medication), effectiveness: effectivenessBinding(riskKey, \.medicationEffectiveness), options: effectivenessOptions)
                        TreatmentRowView(label: "Psychology 1-1", isOn: treatmentBinding(riskKey, \.psych1to1), effectiveness: effectivenessBinding(riskKey, \.psych1to1Effectiveness), options: effectivenessOptions)
                        TreatmentRowView(label: "Psychology groups", isOn: treatmentBinding(riskKey, \.psychGroups), effectiveness: effectivenessBinding(riskKey, \.psychGroupsEffectiveness), options: effectivenessOptions)
                        TreatmentRowView(label: "Nursing support", isOn: treatmentBinding(riskKey, \.nursing), effectiveness: effectivenessBinding(riskKey, \.nursingEffectiveness), options: effectivenessOptions)
                        TreatmentRowView(label: "OT support", isOn: treatmentBinding(riskKey, \.otSupport), effectiveness: effectivenessBinding(riskKey, \.otSupportEffectiveness), options: effectivenessOptions)
                        TreatmentRowView(label: "Social Work", isOn: treatmentBinding(riskKey, \.socialWork), effectiveness: effectivenessBinding(riskKey, \.socialWorkEffectiveness), options: effectivenessOptions)

                        // Remaining concerns slider - appears when any treatment is ticked
                        if hasAnyTreatment(riskKey) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Remaining concerns for this risk factor:")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.red)

                                HStack(spacing: 8) {
                                    Slider(value: Binding(
                                        get: { Double(formData.treatmentData[riskKey, default: RiskTreatmentData()].concernLevel) },
                                        set: { formData.treatmentData[riskKey, default: RiskTreatmentData()].concernLevel = Int($0) }
                                    ), in: 0...Double(concernOptions.count - 1), step: 1)
                                    .tint(.red)

                                    Text(concernOptions[min(formData.treatmentData[riskKey, default: RiskTreatmentData()].concernLevel, concernOptions.count - 1)])
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(.red)
                                        .frame(width: 70, alignment: .trailing)
                                }

                                // Show details text field if concern > 0
                                if formData.treatmentData[riskKey, default: RiskTreatmentData()].concernLevel > 0 {
                                    TextField("Specify remaining concerns...", text: concernDetailsBinding(riskKey))
                                        .textFieldStyle(.roundedBorder)
                                        .font(.caption)
                                }
                            }
                            .padding(10)
                            .background(Color.red.opacity(0.05))
                            .cornerRadius(8)
                        }
                    }
                    .padding(10)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
                } else if !selectedRisks.isEmpty {
                    Text("Select a risk factor above to configure treatments")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
        }
        .onAppear {
            // Auto-select first risk if none selected
            if selectedRisk == nil, let first = selectedRisks.first {
                selectedRisk = first.key
            }
        }
        .onChange(of: selectedRisks.map { $0.key }) { _, newRisks in
            // If selected risk is no longer in list, select first available
            if let current = selectedRisk, !newRisks.contains(current) {
                selectedRisk = newRisks.first
            } else if selectedRisk == nil, let first = newRisks.first {
                selectedRisk = first
            }
        }
    }

    // Binding helpers for treatment data
    private func treatmentBinding(_ riskKey: String, _ keyPath: WritableKeyPath<RiskTreatmentData, Bool>) -> Binding<Bool> {
        Binding(
            get: { formData.treatmentData[riskKey, default: RiskTreatmentData()][keyPath: keyPath] },
            set: { formData.treatmentData[riskKey, default: RiskTreatmentData()][keyPath: keyPath] = $0 }
        )
    }

    private func effectivenessBinding(_ riskKey: String, _ keyPath: WritableKeyPath<RiskTreatmentData, Int>) -> Binding<Int> {
        Binding(
            get: { formData.treatmentData[riskKey, default: RiskTreatmentData()][keyPath: keyPath] },
            set: { formData.treatmentData[riskKey, default: RiskTreatmentData()][keyPath: keyPath] = $0 }
        )
    }

    private func concernDetailsBinding(_ riskKey: String) -> Binding<String> {
        Binding(
            get: { formData.treatmentData[riskKey, default: RiskTreatmentData()].concernDetails },
            set: { formData.treatmentData[riskKey, default: RiskTreatmentData()].concernDetails = $0 }
        )
    }
}

/// Single treatment row with checkbox and effectiveness slider
struct TreatmentRowView: View {
    let label: String
    @Binding var isOn: Bool
    @Binding var effectiveness: Int
    let options: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: { isOn.toggle() }) {
                HStack(spacing: 8) {
                    Image(systemName: isOn ? "checkmark.square.fill" : "square")
                        .foregroundColor(isOn ? .green : .gray)
                        .frame(width: 18)
                    Text(label)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            if isOn {
                HStack(spacing: 8) {
                    Text("Effectiveness:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Slider(value: Binding(
                        get: { Double(effectiveness) },
                        set: { effectiveness = Int($0) }
                    ), in: 0...Double(options.count - 1), step: 1)
                    .tint(.green)

                    Text(options[min(effectiveness, options.count - 1)])
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.green)
                        .frame(width: 70, alignment: .trailing)
                }
                .padding(.leading, 26)
            }
        }
    }
}

struct ASRCheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: { configuration.isOn.toggle() }) {
            HStack(spacing: 4) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .foregroundColor(configuration.isOn ? .blue : .gray)
                configuration.label.foregroundColor(.primary)
            }
        }.buttonStyle(.plain)
    }
}

extension ToggleStyle where Self == ASRCheckboxToggleStyle {
    static var asrCheckbox: ASRCheckboxToggleStyle { ASRCheckboxToggleStyle() }
}

// MARK: - Imported Data Components

/// Category tag pill for imported entries
struct CategoryTag: View {
    let category: String
    let color: Color

    init(category: String) {
        self.category = category
        let hexColor = ASRCategoryKeywords.categoryColors[category] ?? "#6b7280"
        self.color = Color(hex: hexColor) ?? .gray
    }

    var body: some View {
        Text(category)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}

/// Single imported entry row with checkbox and category tags
struct ImportedEntryRow: View {
    @Binding var entry: ASRImportedEntry
    @State private var isExpanded = false
    let dateFormatter: DateFormatter
    let categoryKeywords: [String: [String]]

    init(entry: Binding<ASRImportedEntry>, categoryKeywords: [String: [String]] = [:]) {
        self._entry = entry
        self.categoryKeywords = categoryKeywords
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "dd/MM/yyyy"
    }

    /// Get all keywords that should be highlighted based on matched categories
    private var keywordsToHighlight: [String] {
        var keywords: [String] = []
        for category in entry.categories {
            if let categoryKws = categoryKeywords[category] {
                keywords.append(contentsOf: categoryKws)
            }
        }
        // Sort by length descending to match longer phrases first
        return keywords.sorted { $0.count > $1.count }
    }

    /// Create attributed string with highlighted keywords
    private func highlightedText(_ text: String) -> AttributedString {
        var attributed = AttributedString(text)
        let textLower = text.lowercased()

        for keyword in keywordsToHighlight {
            let keywordLower = keyword.lowercased()
            var searchStart = textLower.startIndex

            while let range = textLower.range(of: keywordLower, range: searchStart..<textLower.endIndex) {
                // Convert String range to AttributedString range using character offsets
                let startOffset = textLower.distance(from: textLower.startIndex, to: range.lowerBound)
                let endOffset = textLower.distance(from: textLower.startIndex, to: range.upperBound)

                let attrStart = attributed.index(attributed.startIndex, offsetByCharacters: startOffset)
                let attrEnd = attributed.index(attributed.startIndex, offsetByCharacters: endOffset)
                attributed[attrStart..<attrEnd].backgroundColor = .yellow.opacity(0.5)
                attributed[attrStart..<attrEnd].foregroundColor = .black

                searchStart = range.upperBound
            }
        }

        return attributed
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Expand/collapse button on LEFT
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                Image(systemName: isExpanded ? "minus.circle.fill" : "plus.circle.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 18))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                // Date if available
                if let date = entry.date {
                    Text(dateFormatter.string(from: date))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // Category tags
                if !entry.categories.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(entry.categories, id: \.self) { category in
                                CategoryTag(category: category)
                            }
                        }
                    }
                }

                // Text - snippet when collapsed, full text with highlighting when expanded
                if isExpanded {
                    Text(highlightedText(entry.text))
                        .font(.caption)
                        .textSelection(.enabled)
                } else {
                    Text(entry.snippet ?? String(entry.text.prefix(150)) + (entry.text.count > 150 ? "..." : ""))
                        .font(.caption)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                }
            }

            Spacer()

            // Checkbox on RIGHT
            Button {
                entry.selected.toggle()
            } label: {
                Image(systemName: entry.selected ? "checkmark.square.fill" : "square")
                    .foregroundColor(entry.selected ? .blue : .gray)
                    .font(.system(size: 20))
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(entry.selected ? Color.blue.opacity(0.1) : Color(.systemGray6))
        .cornerRadius(8)
    }
}

/// Imported data section for ASR popups with filtering
struct ImportedDataSection: View {
    let title: String
    @Binding var entries: [ASRImportedEntry]
    let categoryKeywords: [String: [String]]
    @State private var selectedFilter: String? = nil
    @State private var isExpanded = true
    @State private var displayLimit: Int = 50  // Pagination: show 50 entries at a time

    var filteredEntries: [ASRImportedEntry] {
        guard let filter = selectedFilter else { return entries }
        return entries.filter { $0.categories.contains(filter) }
    }

    // Limit entries shown for performance
    var displayedEntries: ArraySlice<ASRImportedEntry> {
        filteredEntries.prefix(displayLimit)
    }

    var hasMoreEntries: Bool {
        filteredEntries.count > displayLimit
    }

    var remainingCount: Int {
        max(0, filteredEntries.count - displayLimit)
    }

    // Cache available categories - only compute once based on entries count
    var availableCategories: [String] {
        var cats = Set<String>()
        // Only sample first 500 entries for category extraction to avoid performance issues
        for entry in entries.prefix(500) {
            for cat in entry.categories {
                cats.insert(cat)
            }
        }
        return Array(cats).sorted()
    }

    // Cached selected count to avoid repeated filtering
    var selectedCount: Int {
        entries.prefix(1000).filter { $0.selected }.count + (entries.count > 1000 ? entries.dropFirst(1000).filter { $0.selected }.count : 0)
    }

    var body: some View {
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                // Header with expand/collapse
                HStack {
                    Button {
                        withAnimation { isExpanded.toggle() }
                    } label: {
                        HStack {
                            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                .font(.caption)
                            Text(title)
                                .font(.caption.weight(.semibold))
                            Text("(\(selectedCount)/\(entries.count))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .foregroundColor(.orange)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    // Select All / Deselect All buttons
                    if isExpanded {
                        HStack(spacing: 8) {
                            Button("Select All") {
                                for i in entries.indices {
                                    entries[i].selected = true
                                }
                            }
                            .font(.caption2)
                            .foregroundColor(.blue)

                            Text("|").foregroundColor(.secondary).font(.caption2)

                            Button("Deselect All") {
                                for i in entries.indices {
                                    entries[i].selected = false
                                }
                            }
                            .font(.caption2)
                            .foregroundColor(.blue)
                        }
                    }
                }

                if isExpanded {
                    // Category filter pills
                    if availableCategories.count > 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                // All button
                                Button {
                                    selectedFilter = nil
                                    displayLimit = 50  // Reset pagination when filter changes
                                } label: {
                                    Text("All")
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(selectedFilter == nil ? Color.orange : Color(.systemGray5))
                                        .foregroundColor(selectedFilter == nil ? .white : .primary)
                                        .cornerRadius(12)
                                }
                                .buttonStyle(.plain)

                                ForEach(availableCategories, id: \.self) { category in
                                    Button {
                                        selectedFilter = selectedFilter == category ? nil : category
                                        displayLimit = 50  // Reset pagination when filter changes
                                    } label: {
                                        CategoryTag(category: category)
                                            .opacity(selectedFilter == category ? 1.0 : 0.7)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // Entries list with pagination
                    VStack(spacing: 6) {
                        ForEach(Array(displayedEntries.enumerated()), id: \.element.id) { _, entry in
                            if let entryIndex = entries.firstIndex(where: { $0.id == entry.id }) {
                                ImportedEntryRow(entry: $entries[entryIndex], categoryKeywords: categoryKeywords)
                            }
                        }

                        // Load More button
                        if hasMoreEntries {
                            Button {
                                displayLimit += 50
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.down.circle")
                                    Text("Load More (\(remainingCount) remaining)")
                                }
                                .font(.caption)
                                .foregroundColor(.orange)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background(Color.orange.opacity(0.15))
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(10)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.3), lineWidth: 1))
        }
    }
}

// Color(hex:) extension is defined in ReportsListView.swift

// MARK: - Progress Narrative Summary Section (matching Tribunal Section 14 style)

/// Generates and displays a clinical narrative summary for Section 8 Progress
/// Matches the desktop Tribunal Section 14 narrative summary style
struct ProgressNarrativeSummarySection: View {
    let entries: [ASRImportedEntry]
    var period: NarrativePeriod = .oneYear

    @State private var isExpanded = true
    @State private var includeNarrative = true
    @State private var generatedNarrative: NarrativeResult?

    // Patient info from SharedDataStore
    @Environment(SharedDataStore.self) private var sharedData
    private let narrativeGenerator = NarrativeGenerator()

    var patientName: String {
        let name = sharedData.patientInfo.fullName
        return name.components(separatedBy: " ").first ?? "The patient"
    }

    var gender: String {
        sharedData.patientInfo.gender.rawValue
    }

    var body: some View {
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                // Header with expand/collapse
                Button {
                    withAnimation { isExpanded.toggle() }
                } label: {
                    HStack {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                        Text("Clinical Narrative Summary")
                            .font(.caption.weight(.semibold))
                        Spacer()
                        if let narrative = generatedNarrative {
                            Text(narrative.dateRange)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(Color(hex: "#806000") ?? .orange)
                }
                .buttonStyle(.plain)

                if isExpanded {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Include narrative in output", isOn: $includeNarrative)
                            .font(.caption)
                            .foregroundColor(Color(hex: "#806000") ?? .orange)

                        // Narrative content
                        narrativeContent
                            .padding(10)
                            .background(Color.white.opacity(0.7))
                            .cornerRadius(6)
                    }
                }
            }
            .padding(10)
            .background(Color(hex: "#fffbeb").opacity(0.8))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.4), lineWidth: 1))
            .onAppear { generateNarrative() }
            .onChange(of: entries.count) { _, _ in generateNarrative() }
        }
    }

    private func generateNarrative() {
        let narrativeEntries = entries.compactMap { entry -> NarrativeEntry? in
            return NarrativeEntry(
                date: entry.date,
                content: entry.text,
                type: entry.categories.joined(separator: ", "),
                originator: ""
            )
        }

        generatedNarrative = narrativeGenerator.generateNarrative(
            from: narrativeEntries,
            period: period,
            patientName: patientName,
            gender: gender
        )
    }

    @ViewBuilder
    private var narrativeContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let narrative = generatedNarrative, !narrative.plainText.isEmpty {
                Text(narrative.plainText)
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                // Fallback - basic narrative
                let sortedEntries = entries.compactMap { entry -> (Date, ASRImportedEntry)? in
                    guard let date = entry.date else { return nil }
                    return (date, entry)
                }.sorted { $0.0 < $1.0 }

                if sortedEntries.isEmpty {
                    Text("No dated entries available for narrative generation.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    let pronounPoss = gender.lowercased() == "male" || gender.lowercased() == "m" ? "his" :
                                     gender.lowercased() == "female" || gender.lowercased() == "f" ? "her" : "their"
                    let dateRange = Calendar.current.dateComponents([.day], from: sortedEntries.first!.0, to: sortedEntries.last!.0).day ?? 1
                    let months = max(1, dateRange / 30)
                    let freqDesc = entries.count > months * 2 ? "regularly" : "periodically"

                    Text("\(patientName) has been reviewed \(freqDesc) over the past \(months) months with \(entries.count) documented contacts. \(pronounPoss.capitalized) progress has been monitored throughout this period.")
                        .font(.caption)
                }
            }
        }
    }
}

#Preview {
    MOJASRFormView()
        .environment(AppStore())
        .environment(SharedDataStore.shared)
}
