//
//  MOJLeaveFormView.swift
//  MyPsychAdmin
//
//  MOJ Leave Application Form for Restricted Patients
//  Based on MHCS Leave Application Form structure (25 sections)
//  Updated to use expandable cards like ASR form with popups
//

import SwiftUI
import UniformTypeIdentifiers

struct MOJLeaveFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var appStore
    @Environment(SharedDataStore.self) private var sharedData

    @State private var formData: MOJLeaveFormData = MOJLeaveFormData()
    @State private var validationErrors: [FormValidationError] = []

    // Card text content - split into generated (from controls) and manual notes
    @State private var generatedTexts: [LeaveSection: String] = [:]
    @State private var manualNotes: [LeaveSection: String] = [:]

    // Popup control
    @State private var activePopup: LeaveSection? = nil

    // Export states
    @State private var docxURL: URL?
    @State private var isExporting = false
    @State private var showShareSheet = false
    @State private var exportError: String?
    @State private var importSuccess: String?

    // Import states
    @State private var showingImportPicker = false
    @State private var showingLeaveTypeSheet = false
    @State private var selectedImportLeaveType: ImportLeaveType = .escortedDay
    @State private var isImporting = false
    @State private var isProcessingNotes = false
    @State private var processingProgress: String = ""

    // Leave type options for import (matching Desktop)
    enum ImportLeaveType: String, CaseIterable, Identifiable {
        case escortedDay = "Escorted Community (Day)"
        case escortedOvernight = "Escorted (Overnight)"
        case unescortedDay = "Unescorted Community (Day)"
        case unescortedOvernight = "Unescorted Community (Overnight)"
        case compassionateDay = "Compassionate (Day)"
        case compassionateOvernight = "Compassionate (Overnight)"

        var id: String { rawValue }
    }

    // 25 Sections matching desktop MHCS Leave Application Form
    enum LeaveSection: String, CaseIterable, Identifiable {
        case patientDetails = "1. Patient Details"
        case rcDetails = "2. RC Details"
        case leaveType = "3a. Type of Leave"
        case documents = "3b. Documents Reviewed"
        case purpose = "3c. Purpose of Leave"
        case overnight = "3d. Unescorted Overnight"
        case escortedOvernight = "3e. Escorted Overnight"
        case compassionate = "3f. Compassionate Leave"
        case leaveReport = "3g. Leave Report"
        case procedures = "3h. Proposed Management"
        case hospitalAdmissions = "4a. Past Psychiatric History"
        case indexOffence = "4b. Index Offence"
        case mentalDisorder = "4c. Current Mental Disorder"
        case attitudeBehaviour = "4d. Attitude & Behaviour"
        case riskFactors = "4e. Risk Factors"
        case medication = "4f. Medication"
        case psychology = "4g. Risks & Psychology"
        case extremism = "4h. Extremism"
        case absconding = "4i. Absconding"
        case mappa = "5. MAPPA"
        case victims = "6. Victims"
        case transferredPrisoners = "7. Transferred Prisoners"
        case fitnessToPlead = "8. Fitness to Plead"
        case additionalComments = "9. Additional Comments"
        case signature = "Signature"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .patientDetails: return "person"
            case .rcDetails: return "stethoscope"
            case .leaveType: return "figure.walk"
            case .documents: return "doc.text"
            case .purpose: return "target"
            case .overnight: return "moon.stars"
            case .escortedOvernight: return "moon.fill"
            case .compassionate: return "heart"
            case .leaveReport: return "doc.plaintext"
            case .procedures: return "list.clipboard"
            case .hospitalAdmissions: return "building.2"
            case .indexOffence: return "exclamationmark.shield"
            case .mentalDisorder: return "brain.head.profile"
            case .attitudeBehaviour: return "person.wave.2"
            case .riskFactors: return "exclamationmark.triangle"
            case .medication: return "pills"
            case .psychology: return "brain"
            case .extremism: return "exclamationmark.octagon"
            case .absconding: return "figure.run"
            case .mappa: return "person.badge.shield.checkmark"
            case .victims: return "person.crop.circle.badge.exclamationmark"
            case .transferredPrisoners: return "building.columns"
            case .fitnessToPlead: return "checkmark.seal"
            case .additionalComments: return "text.bubble"
            case .signature: return "signature"
            }
        }

        var defaultHeight: CGFloat {
            switch self {
            case .patientDetails, .rcDetails, .signature: return 120
            case .leaveType, .documents: return 100
            case .purpose, .hospitalAdmissions, .indexOffence, .mentalDisorder: return 180
            case .attitudeBehaviour, .riskFactors, .medication, .psychology: return 180
            case .leaveReport: return 200
            default: return 150
            }
        }
    }

    // Data is kept in memory only - not persisted across app launches

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if let success = importSuccess {
                        Text(success)
                            .foregroundColor(.green)
                            .font(.caption)
                            .padding(.horizontal)
                    }

                    if let error = exportError {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.horizontal)
                    }

                    FormValidationErrorView(errors: validationErrors)
                        .padding(.horizontal)

                    // Processing indicator
                    if isProcessingNotes {
                        VStack(spacing: 8) {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(1.2)
                            Text(processingProgress.isEmpty ? "Processing notes..." : processingProgress)
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Please wait")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(Color(red: 153/255, green: 27/255, blue: 27/255))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    // All section cards
                    ForEach(LeaveSection.allCases) { section in
                        LeaveEditableCard(
                            section: section,
                            text: binding(for: section),
                            onHeaderTap: { activePopup = section }
                        )
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("MOJ Leave")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        // Import button
                        Button {
                            showingLeaveTypeSheet = true
                        } label: {
                            Image(systemName: "square.and.arrow.down")
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
        .overlay {
            if isImporting {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        Text("Importing data...")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Processing notes and extracting patient details")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .padding(32)
                    .background(Color(.systemGray5).opacity(0.95))
                    .cornerRadius(16)
                    .shadow(radius: 10)
                }
            }
        }
        .onAppear {
            prefillFromSharedData()
            initializeCardTexts()
            // Auto-populate from shared notes if available
            if !sharedData.notes.isEmpty {
                processExtractedNotesAsync(sharedData.notes)
            }
        }
        .onReceive(sharedData.notesDidChange) { notes in
            // Auto-populate when notes change in SharedDataStore
            if !notes.isEmpty {
                processExtractedNotesAsync(notes)
            }
        }
        .onChange(of: sharedData.notes.count) {
            // Fallback: detect notes changes via @Observable tracking
            if sharedData.notes.count > 0 {
                processExtractedNotesAsync(sharedData.notes)
            }
        }
        .onReceive(sharedData.patientInfoDidChange) { patientInfo in
            if !patientInfo.fullName.isEmpty {
                formData.patientName = patientInfo.fullName
                formData.patientDOB = patientInfo.dateOfBirth
                formData.patientGender = patientInfo.gender
            }
        }
        .sheet(item: $activePopup) { section in
            LeavePopupView(
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
        .sheet(isPresented: $showingLeaveTypeSheet) {
            LeaveTypeSelectionSheet(
                selectedType: $selectedImportLeaveType,
                onConfirm: {
                    showingLeaveTypeSheet = false
                    showingImportPicker = true
                },
                onCancel: {
                    showingLeaveTypeSheet = false
                }
            )
            .presentationDetents([.medium])
        }
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [
                .plainText,
                .pdf,
                .init(filenameExtension: "docx")!,
                .init(filenameExtension: "doc")!,
                .spreadsheet,
                .init(filenameExtension: "xlsx")!,
                .init(filenameExtension: "xls")!
            ],
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result)
        }
    }

    private func binding(for section: LeaveSection) -> Binding<String> {
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
        for section in LeaveSection.allCases {
            if generatedTexts[section] == nil { generatedTexts[section] = "" }
            if manualNotes[section] == nil { manualNotes[section] = "" }
        }
    }

    private func prefillFromSharedData() {
        if !sharedData.patientInfo.fullName.isEmpty {
            formData.patientName = sharedData.patientInfo.fullName
            formData.patientDOB = sharedData.patientInfo.dateOfBirth
            formData.hospitalNumber = sharedData.patientInfo.hospitalNumber
            formData.patientGender = sharedData.patientInfo.gender
        }
        if !appStore.clinicianInfo.fullName.isEmpty {
            formData.rcName = appStore.clinicianInfo.fullName
            formData.rcEmail = appStore.clinicianInfo.email
            formData.rcPhone = appStore.clinicianInfo.phone
            formData.hospitalName = appStore.clinicianInfo.hospitalOrg
            formData.signatureName = appStore.clinicianInfo.fullName
        }
    }

    private func exportDOCX() {
        syncCardTextsToFormData()
        validationErrors = formData.validate()
        guard validationErrors.isEmpty else { return }

        isExporting = true
        exportError = nil

        DispatchQueue.global(qos: .userInitiated).async {
            let data = MOJLeaveFormDOCXExporter(formData: formData).generateDOCX()

            DispatchQueue.main.async {
                isExporting = false

                guard let docxData = data else {
                    exportError = "Failed to generate document"
                    return
                }

                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
                let patientName = formData.patientName.isEmpty ? "Patient" : formData.patientName.replacingOccurrences(of: " ", with: "_")
                let filename = "MOJ_Leave_\(patientName)_\(dateFormatter.string(from: Date())).docx"
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
        print("[MOJ-LEAVE] handleImportResult called")
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                print("[MOJ-LEAVE] No URL in result")
                return
            }
            print("[MOJ-LEAVE] File URL: \(url.lastPathComponent)")

            guard url.startAccessingSecurityScopedResource() else {
                print("[MOJ-LEAVE] Cannot access security scoped resource")
                exportError = "Cannot access file"
                return
            }

            let ext = url.pathExtension.lowercased()
            print("[MOJ-LEAVE] File extension: \(ext)")

            // Auto-detect: Excel files are notes, PDF/DOCX are reports
            let isExcelFile = ext == "xlsx" || ext == "xls"

            // Show loading indicator
            isImporting = true

            Task {
                defer { url.stopAccessingSecurityScopedResource() }

                do {
                    print("[MOJ-LEAVE] Processing document...")
                    // Use DocumentProcessor for all file types
                    let document = try await DocumentProcessor.shared.processDocument(at: url)
                    print("[MOJ-LEAVE] Document processed: \(document.notes.count) notes extracted")

                    await MainActor.run {
                        // Share notes and patient info with other views
                        if !document.notes.isEmpty {
                            sharedData.setNotes(document.notes, source: "moj_leave_import")
                        }
                        if !document.patientInfo.fullName.isEmpty {
                            sharedData.setPatientInfo(document.patientInfo, source: "moj_leave_import")
                        }

                        // Extract patient data from DocumentProcessor (all file types)
                        processExtractedReportData(document)
                        print("[MOJ-LEAVE] Document patient info processed")

                        // Detect PTR (Psychiatric Tribunal Report) vs notes
                        let ptrSections = Self.parsePTRSections(from: document.text)
                        if !ptrSections.isEmpty {
                            // PTR detected — map PTR sections directly to Leave form sections
                            print("[MOJ-LEAVE] PTR detected with sections: \(ptrSections.keys.sorted())")
                            applyPTRDataToLeaveSections(ptrSections, document: document)
                        } else {
                            // Notes path — keyword categorization
                            processExtractedNotesAsync(document.notes)
                        }

                        // Extract patient details from note bodies (like Desktop does for any missing fields)
                        extractPatientDetailsFromNotes(document.notes)
                        print("[MOJ-LEAVE] Patient details extracted from notes")

                        // Filter leave report entries to last 2 years
                        filterLeaveReportToLastTwoYears()
                        print("[MOJ-LEAVE] Leave report filtered to last 2 years")

                        // Apply auto-defaults based on selected leave type
                        applyAutoLeaveDefaults(selectedImportLeaveType)
                        print("[MOJ-LEAVE] Auto-defaults applied for: \(selectedImportLeaveType.rawValue)")
                        print("[MOJ-LEAVE] Leave type checkboxes - escortedDay: \(formData.escortedDay), escortedOvernight: \(formData.escortedOvernight)")

                        // Hide loading indicator
                        isImporting = false

                        // Show success message
                        let sourceType = ptrSections.isEmpty ? "notes" : "PTR"
                        importSuccess = "Import complete! \(sourceType == "PTR" ? "Tribunal report" : "\(document.notes.count) notes") processed. Tap a section to see imported data."
                    }
                } catch {
                    print("[MOJ-LEAVE] Error processing file: \(error)")
                    await MainActor.run {
                        isImporting = false
                        exportError = "Failed to process file: \(error.localizedDescription)"
                    }
                }
            }

        case .failure(let error):
            print("[MOJ-LEAVE] Import failed: \(error)")
            exportError = "Import failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Async Note Processing (background thread)

    /// Async wrapper that moves heavy categorization to a background thread
    private func processExtractedNotesAsync(_ notes: [ClinicalNote]) {
        guard !notes.isEmpty, !isProcessingNotes else { return }
        isProcessingNotes = true
        processingProgress = "Processing \(notes.count) notes..."

        DispatchQueue.global(qos: .userInitiated).async {
            let results = Self.categorizeLeaveNotes(notes)
            DispatchQueue.main.async {
                self.applyLeaveCategorizationResults(results, notes: notes)
            }
        }
    }

    /// Apply categorization results to formData on the main thread
    private func applyLeaveCategorizationResults(_ results: LeaveCategorizationResults, notes: [ClinicalNote]) {
        formData.hospitalAdmissionsImportedEntries = results.hospitalAdmissions
        formData.indexOffenceImportedEntries = results.indexOffence
        formData.mentalDisorderImportedEntries = results.mentalDisorder
        formData.attitudeBehaviourImportedEntries = results.attitudeBehaviour
        formData.riskFactorsImportedEntries = results.riskFactors
        formData.medicationImportedEntries = results.medication
        formData.leaveReportImportedEntries = results.leaveReport
        formData.mappaImportedEntries = results.mappa
        formData.victimsImportedEntries = results.victims
        formData.extremismImportedEntries = results.extremism
        formData.abscondingImportedEntries = results.absconding
        formData.prisonersImportedEntries = results.prisoners
        formData.fitnessImportedEntries = results.fitness

        // Fast operations on main thread
        extractAndFillDiagnoses(notes)
        prefillRiskFactorsFromNotes(notes)
        prefillMedicationsFromNotes(notes)
        prefillPsychologyFromRisks()
        prefillExtremismFromEntries()
        prefillAbscondingFromEntries()

        isProcessingNotes = false
        processingProgress = ""
    }

    /// Results struct for background categorization
    private struct LeaveCategorizationResults: Sendable {
        var hospitalAdmissions: [ASRImportedEntry] = []
        var indexOffence: [ASRImportedEntry] = []
        var mentalDisorder: [ASRImportedEntry] = []
        var attitudeBehaviour: [ASRImportedEntry] = []
        var riskFactors: [ASRImportedEntry] = []
        var medication: [ASRImportedEntry] = []
        var leaveReport: [ASRImportedEntry] = []
        var mappa: [ASRImportedEntry] = []
        var victims: [ASRImportedEntry] = []
        var extremism: [ASRImportedEntry] = []
        var absconding: [ASRImportedEntry] = []
        var prisoners: [ASRImportedEntry] = []
        var fitness: [ASRImportedEntry] = []
    }

    // MARK: - PTR (Psychiatric Tribunal Report) Detection & Mapping

    /// PTR section markers — distinctive phrases from each numbered question
    private static let ptrSectionMarkers: [(section: Int, phrases: [String])] = [
        (5, [
            "index offence",
            "forensic history",
            "relevant forensic"
        ]),
        (6, [
            "previous involvement with mental health",
            "dates of previous involvement"
        ]),
        (7, [
            "reasons for previous admission",
            "give reasons for previous"
        ]),
        (8, [
            "circumstances of the current admission",
            "current admission"
        ]),
        (9, [
            "is the patient now suffering",
            "nature and degree of mental disorder",
            "mental disorder"
        ]),
        (10, [
            "does the patient have a learning disability",
            "patient have a learning disability",
            "learning disability"
        ]),
        (11, [
            "mental disorder present which requires the patient to be detained",
            "is there any mental disorder present",
            "requires the patient to be detained"
        ]),
        (12, [
            "appropriate and available medical treatment",
            "medical treatment has been prescribed",
            "treatment prescribed, provided, offered",
            "medical treatment prescribed"
        ]),
        (13, [
            "strengths and positive factors",
            "what are the strengths"
        ]),
        (14, [
            "current progress, behaviour, capacity and insight",
            "summary of the patient's current progress",
            "give a summary of the patient"
        ]),
        (15, [
            "understanding of, compliance with",
            "willingness to accept any prescribed medication",
            "comply with any appropriate medical treatment"
        ]),
        (16, [
            "eligible compliant patient who lacks capacity",
            "deprivation of liberty under the mental capacity act",
            "lacks capacity to agree or object to their detention"
        ]),
        (17, [
            "harmed themselves or others, or threatened to harm",
            "where the patient has harmed themselves or others",
            "threatened to harm themselves or others",
            "incidents where the patient has harmed"
        ]),
        (18, [
            "damaged property",
            "threatened to damage property",
            "incidents of property damage"
        ]),
        (19, [
            "in section 2 cases"
        ]),
        (20, [
            "in all other cases"
        ]),
        (21, [
            "likely to act in a manner dangerous",
            "discharged from hospital"
        ]),
        (22, [
            "managed effectively in the community",
            "risks managed in the community"
        ]),
        (23, [
            "recommendations to tribunal",
            "do you have any recommendations"
        ]),
        (24, [
            "other relevant information",
            "other information for the tribunal"
        ])
    ]

    /// Parse PTR numbered sections from document text
    private static func parsePTRSections(from text: String) -> [Int: String] {
        let lower = text.lowercased()

        struct SectionMatch: Comparable {
            let section: Int
            let position: Int
            let phraseEnd: Int
            static func < (lhs: SectionMatch, rhs: SectionMatch) -> Bool {
                lhs.position < rhs.position
            }
        }

        var matches: [SectionMatch] = []

        for marker in ptrSectionMarkers {
            for phrase in marker.phrases {
                if let range = lower.range(of: phrase) {
                    let pos = lower.distance(from: lower.startIndex, to: range.lowerBound)
                    let end = lower.distance(from: lower.startIndex, to: range.upperBound)
                    if !matches.contains(where: { $0.section == marker.section }) {
                        matches.append(SectionMatch(section: marker.section, position: pos, phraseEnd: end))
                    }
                    break
                }
            }
        }

        guard matches.count >= 2 else { return [:] }

        matches.sort()

        var sections: [Int: String] = [:]
        for i in 0..<matches.count {
            var contentStart = matches[i].phraseEnd
            // Skip past the question mark
            let searchFrom = text.index(text.startIndex, offsetBy: min(contentStart, text.count))
            let searchEnd = text.index(text.startIndex, offsetBy: min(contentStart + 200, text.count))
            if searchFrom < searchEnd {
                let tail = String(text[searchFrom..<searchEnd])
                if let qMark = tail.firstIndex(of: "?") {
                    contentStart += tail.distance(from: tail.startIndex, to: qMark) + 1
                }
            }

            let contentEnd = i + 1 < matches.count ? matches[i + 1].position : text.count

            guard contentStart < contentEnd && contentStart < text.count else { continue }

            let startIdx = text.index(text.startIndex, offsetBy: contentStart)
            let endIdx = text.index(text.startIndex, offsetBy: min(contentEnd, text.count))
            let content = String(text[startIdx..<endIdx])
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !content.isEmpty && content.count > 10 else { continue }
            sections[matches[i].section] = content
        }

        return sections
    }

    /// Apply PTR sections directly to Leave form sections — 1 entry per section
    private func applyPTRDataToLeaveSections(_ ptr: [Int: String], document: ExtractedDocument) {
        func makeEntry(_ text: String) -> ASRImportedEntry {
            let snippet = text.count > 200 ? String(text.prefix(200)) + "..." : text
            return ASRImportedEntry(date: nil, text: text, categories: ["Report"], snippet: snippet)
        }

        // MOJL 4a (Past Psychiatric History) → PTR 6 + PTR 7
        let s4a = [ptr[6], ptr[7]].compactMap { $0 }.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
        if !s4a.isEmpty {
            formData.hospitalAdmissionsImportedEntries = [makeEntry(s4a)]
        }

        // MOJL 4b (Index Offence) → PTR 5
        if let s5 = ptr[5] {
            formData.indexOffenceImportedEntries = [makeEntry(s5)]
        }

        // MOJL 4c (Mental Disorder) → PTR 9
        if let s9 = ptr[9] {
            formData.mentalDisorderImportedEntries = [makeEntry(s9)]
        }

        // MOJL 4d (Attitude & Behaviour) → PTR 14
        if let s14 = ptr[14] {
            formData.attitudeBehaviourImportedEntries = [makeEntry(s14)]
        }

        // MOJL 4e (Risk Factors) → PTR 17 + PTR 18
        let s4e = [ptr[17], ptr[18]].compactMap { $0 }.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
        if !s4e.isEmpty {
            formData.riskFactorsImportedEntries = [makeEntry(s4e)]
        }

        // MOJL 4f (Medication) → PTR 10 + PTR 12 + PTR 15
        let s4f = [ptr[10], ptr[12], ptr[15]].compactMap { $0 }.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
        if !s4f.isEmpty {
            formData.medicationImportedEntries = [makeEntry(s4f)]
        }

        // Auto-fill card text
        if !s4a.isEmpty && formData.hospitalAdmissionsText.isEmpty { formData.hospitalAdmissionsText = s4a }
        if let s5 = ptr[5], formData.indexOffenceText.isEmpty { formData.indexOffenceText = s5 }
        if let s9 = ptr[9], formData.mentalDisorderText.isEmpty { formData.mentalDisorderText = s9 }
        if let s14 = ptr[14], formData.attitudeBehaviourText.isEmpty { formData.attitudeBehaviourText = s14 }
        if !s4e.isEmpty && formData.riskFactorsText.isEmpty { formData.riskFactorsText = s4e }
        if !s4f.isEmpty && formData.medicationText.isEmpty { formData.medicationText = s4f }

        // Extract diagnoses — create temporary notes from raw text for the existing method
        if !document.text.isEmpty {
            let tempNote = ClinicalNote(body: document.text)
            extractAndFillDiagnoses([tempNote])
        }

        // Prefill risk factors and other auto-detections (these work off formData imported entries)
        prefillRiskFactorsFromNotes([])
        prefillExtremismFromEntries()
        prefillAbscondingFromEntries()

        print("[MOJ-LEAVE] PTR mapped: 4a=\(!s4a.isEmpty), 4b=\(ptr[5] != nil), 4c=\(ptr[9] != nil), 4d=\(ptr[14] != nil), 4e=\(!s4e.isEmpty), 4f=\(!s4f.isEmpty)")
    }

    /// Pure function: categorize notes off the main thread
    private static func categorizeLeaveNotes(_ notes: [ClinicalNote]) -> LeaveCategorizationResults {
        var results = LeaveCategorizationResults()

        // 4a. Past Psychiatric History from clerkings
        let pastPsychEntries = extractHistorySectionFromClerkingsStatic(notes, sectionType: .pastPsychiatric)
        for entry in pastPsychEntries {
            let snippet = entry.text.count > 150 ? String(entry.text.prefix(150)) + "..." : entry.text
            results.hospitalAdmissions.append(ASRImportedEntry(date: entry.date, text: entry.text, categories: ["Past Psychiatric History"], snippet: snippet))
        }

        // 4b. Index Offence / Forensic History from clerkings
        let forensicEntries = extractHistorySectionFromClerkingsStatic(notes, sectionType: .forensicHistory)
        for entry in forensicEntries {
            let snippet = entry.text.count > 150 ? String(entry.text.prefix(150)) + "..." : entry.text
            results.indexOffence.append(ASRImportedEntry(date: entry.date, text: entry.text, categories: ["Forensic History"], snippet: snippet))
        }

        // 4c. Mental Disorder - diagnosis-specific lines
        let diagnosisEntries = extractDiagnosisLinesStatic(from: notes)
        for entry in diagnosisEntries {
            let snippet = entry.text.count > 150 ? String(entry.text.prefix(150)) + "..." : entry.text
            let diagnosisCategories = detectDiagnosisCategoriesStatic(in: entry.text)
            results.mentalDisorder.append(ASRImportedEntry(date: entry.date, text: entry.text, categories: diagnosisCategories.isEmpty ? ["Diagnosis"] : diagnosisCategories, snippet: snippet))
        }

        // 4d. Attitude & Behaviour - 1 year filter
        let mostRecentDate = notes.map { $0.date }.max() ?? Date()
        let oneYearCutoff = Calendar.current.date(byAdding: .year, value: -1, to: mostRecentDate) ?? mostRecentDate
        var attitudeSeenTexts = Set<String>()

        for note in notes {
            if note.date < oneYearCutoff { continue }
            let text = note.body
            let textKey = text.lowercased().prefix(200).description
            if attitudeSeenTexts.contains(textKey) { continue }

            let attCats = LeaveFormCategoryKeywords.categorize(text, using: LeaveFormCategoryKeywords.attitudeBehaviour)
            if !attCats.isEmpty {
                attitudeSeenTexts.insert(textKey)
                let snippet = text.count > 150 ? String(text.prefix(150)) + "..." : text
                results.attitudeBehaviour.append(ASRImportedEntry(date: note.date, text: text, categories: attCats, snippet: snippet))
            }
        }

        // Process all notes for other sections
        for note in notes {
            let text = note.body
            let snippet = text.count > 150 ? String(text.prefix(150)) + "..." : text

            let riskCats = LeaveFormCategoryKeywords.categorize(text, using: LeaveFormCategoryKeywords.riskFactors)
            let medCats = LeaveFormCategoryKeywords.categorize(text, using: LeaveFormCategoryKeywords.medication)
            let leaveCats = LeaveFormCategoryKeywords.categorize(text, using: LeaveFormCategoryKeywords.leaveReport)
            let mappaCats = LeaveFormCategoryKeywords.categorize(text, using: LeaveFormCategoryKeywords.mappa)
            let victimsCats = LeaveFormCategoryKeywords.categorize(text, using: LeaveFormCategoryKeywords.victims)
            let extremismCats = LeaveFormCategoryKeywords.categorize(text, using: LeaveFormCategoryKeywords.extremism)
            let abscondingCats = LeaveFormCategoryKeywords.categorize(text, using: LeaveFormCategoryKeywords.absconding)
            let prisonersCats = LeaveFormCategoryKeywords.categorize(text, using: LeaveFormCategoryKeywords.transferredPrisoners)
            let fitnessCats = LeaveFormCategoryKeywords.categorize(text, using: LeaveFormCategoryKeywords.fitnessToPlead)

            if !riskCats.isEmpty {
                results.riskFactors.append(ASRImportedEntry(date: note.date, text: text, categories: riskCats, snippet: snippet))
            }
            if !medCats.isEmpty {
                results.medication.append(ASRImportedEntry(date: note.date, text: text, categories: medCats, snippet: snippet))
            }
            if !leaveCats.isEmpty {
                results.leaveReport.append(ASRImportedEntry(date: note.date, text: text, categories: leaveCats, snippet: snippet))
            }
            if !mappaCats.isEmpty {
                results.mappa.append(ASRImportedEntry(date: note.date, text: text, categories: mappaCats, snippet: snippet))
            }
            if !victimsCats.isEmpty {
                results.victims.append(ASRImportedEntry(date: note.date, text: text, categories: victimsCats, snippet: snippet))
            }
            if !extremismCats.isEmpty {
                results.extremism.append(ASRImportedEntry(date: note.date, text: text, categories: extremismCats, snippet: snippet))
            }
            if !abscondingCats.isEmpty {
                let twelveMonthsAgo = Calendar.current.date(byAdding: .month, value: -12, to: Date()) ?? Date()
                if note.date >= twelveMonthsAgo {
                    results.absconding.append(ASRImportedEntry(date: note.date, text: text, categories: abscondingCats, snippet: snippet))
                }
            }
            if !prisonersCats.isEmpty {
                results.prisoners.append(ASRImportedEntry(date: note.date, text: text, categories: prisonersCats, snippet: snippet))
            }
            if !fitnessCats.isEmpty {
                results.fitness.append(ASRImportedEntry(date: note.date, text: text, categories: fitnessCats, snippet: snippet))
            }
        }

        return results
    }

    /// Legacy synchronous version (kept for reference)
    private func processExtractedNotes(_ notes: [ClinicalNote]) {
        print("[MOJ-LEAVE] Processing \(notes.count) notes...")

        // === 4a. Past Psychiatric History - Use clerking extraction (like Desktop) ===
        let pastPsychEntries = Self.extractHistorySectionFromClerkingsStatic(notes, sectionType: .pastPsychiatric)
        for entry in pastPsychEntries {
            let snippet = entry.text.count > 150 ? String(entry.text.prefix(150)) + "..." : entry.text
            formData.hospitalAdmissionsImportedEntries.append(ASRImportedEntry(
                date: entry.date,
                text: entry.text,
                categories: ["Past Psychiatric History"],
                snippet: snippet
            ))
        }
        print("[MOJ-LEAVE] 4a Past Psych: Found \(pastPsychEntries.count) entries from clerkings")

        // === 4b. Index Offence / Forensic History - Use clerking extraction (like Desktop) ===
        let forensicEntries = Self.extractHistorySectionFromClerkingsStatic(notes, sectionType: .forensicHistory)
        for entry in forensicEntries {
            let snippet = entry.text.count > 150 ? String(entry.text.prefix(150)) + "..." : entry.text
            formData.indexOffenceImportedEntries.append(ASRImportedEntry(
                date: entry.date,
                text: entry.text,
                categories: ["Forensic History"],
                snippet: snippet
            ))
        }
        print("[MOJ-LEAVE] 4b Forensic: Found \(forensicEntries.count) entries from clerkings")

        // === 4c. Mental Disorder - Extract ONLY diagnosis-specific lines (matching Desktop) ===
        // Desktop searches all notes for lines containing diagnosis terms and extracts just those lines
        let diagnosisEntries = Self.extractDiagnosisLinesStatic(from: notes)
        for entry in diagnosisEntries {
            let snippet = entry.text.count > 150 ? String(entry.text.prefix(150)) + "..." : entry.text
            let diagnosisCategories = Self.detectDiagnosisCategoriesStatic(in: entry.text)
            formData.mentalDisorderImportedEntries.append(ASRImportedEntry(
                date: entry.date,
                text: entry.text,
                categories: diagnosisCategories.isEmpty ? ["Diagnosis"] : diagnosisCategories,
                snippet: snippet
            ))
        }
        print("[MOJ-LEAVE] 4c Mental Disorder: Found \(diagnosisEntries.count) diagnosis entries")

        // === Auto-fill ICD-10 diagnoses from all notes (matching Desktop logic) ===
        extractAndFillDiagnoses(notes)

        // === 4d. Attitude & Behaviour - 1 year filter like Desktop ===
        // Desktop filters to notes from last 1 year before most recent entry
        let mostRecentDate = notes.map { $0.date }.max() ?? Date()
        let oneYearCutoff = Calendar.current.date(byAdding: .year, value: -1, to: mostRecentDate) ?? mostRecentDate
        var attitudeSeenTexts = Set<String>()

        for note in notes {
            // Skip if older than 1 year cutoff
            if note.date < oneYearCutoff { continue }

            let text = note.body
            let textKey = text.lowercased().prefix(200).description

            // Skip duplicates
            if attitudeSeenTexts.contains(textKey) { continue }

            let attCats = LeaveFormCategoryKeywords.categorize(text, using: LeaveFormCategoryKeywords.attitudeBehaviour)
            if !attCats.isEmpty {
                attitudeSeenTexts.insert(textKey)
                let snippet = text.count > 150 ? String(text.prefix(150)) + "..." : text
                formData.attitudeBehaviourImportedEntries.append(ASRImportedEntry(date: note.date, text: text, categories: attCats, snippet: snippet))
            }
        }
        print("[MOJ-LEAVE] 4d Attitude: \(formData.attitudeBehaviourImportedEntries.count) entries (1-year filter applied)")

        // Process all notes for other sections (no time filter)
        for note in notes {
            let text = note.body
            let snippet = text.count > 150 ? String(text.prefix(150)) + "..." : text

            let riskCats = LeaveFormCategoryKeywords.categorize(text, using: LeaveFormCategoryKeywords.riskFactors)
            let medCats = LeaveFormCategoryKeywords.categorize(text, using: LeaveFormCategoryKeywords.medication)
            // Note: Psychology (4g) does not use imported entries - Section 3 is auto-populated from 4e
            let leaveCats = LeaveFormCategoryKeywords.categorize(text, using: LeaveFormCategoryKeywords.leaveReport)
            let mappaCats = LeaveFormCategoryKeywords.categorize(text, using: LeaveFormCategoryKeywords.mappa)
            let victimsCats = LeaveFormCategoryKeywords.categorize(text, using: LeaveFormCategoryKeywords.victims)
            let extremismCats = LeaveFormCategoryKeywords.categorize(text, using: LeaveFormCategoryKeywords.extremism)
            let abscondingCats = LeaveFormCategoryKeywords.categorize(text, using: LeaveFormCategoryKeywords.absconding)
            let prisonersCats = LeaveFormCategoryKeywords.categorize(text, using: LeaveFormCategoryKeywords.transferredPrisoners)
            let fitnessCats = LeaveFormCategoryKeywords.categorize(text, using: LeaveFormCategoryKeywords.fitnessToPlead)

            if !riskCats.isEmpty {
                formData.riskFactorsImportedEntries.append(ASRImportedEntry(date: note.date, text: text, categories: riskCats, snippet: snippet))
            }
            if !medCats.isEmpty {
                formData.medicationImportedEntries.append(ASRImportedEntry(date: note.date, text: text, categories: medCats, snippet: snippet))
            }
            if !leaveCats.isEmpty {
                formData.leaveReportImportedEntries.append(ASRImportedEntry(date: note.date, text: text, categories: leaveCats, snippet: snippet))
            }
            if !mappaCats.isEmpty {
                formData.mappaImportedEntries.append(ASRImportedEntry(date: note.date, text: text, categories: mappaCats, snippet: snippet))
            }
            if !victimsCats.isEmpty {
                formData.victimsImportedEntries.append(ASRImportedEntry(date: note.date, text: text, categories: victimsCats, snippet: snippet))
            }
            if !extremismCats.isEmpty {
                formData.extremismImportedEntries.append(ASRImportedEntry(date: note.date, text: text, categories: extremismCats, snippet: snippet))
            }
            // 4i Absconding: Only include entries within 12 months (matching Desktop)
            if !abscondingCats.isEmpty {
                let twelveMonthsAgo = Calendar.current.date(byAdding: .month, value: -12, to: Date()) ?? Date()
                if note.date >= twelveMonthsAgo {
                    formData.abscondingImportedEntries.append(ASRImportedEntry(date: note.date, text: text, categories: abscondingCats, snippet: snippet))
                } else {
                    print("[MOJ-LEAVE] 4i: Skipped absconding entry from \(note.date) - older than 12 months")
                }
            }
            if !prisonersCats.isEmpty {
                formData.prisonersImportedEntries.append(ASRImportedEntry(date: note.date, text: text, categories: prisonersCats, snippet: snippet))
            }
            if !fitnessCats.isEmpty {
                formData.fitnessImportedEntries.append(ASRImportedEntry(date: note.date, text: text, categories: fitnessCats, snippet: snippet))
            }
        }

        // Log summary of imported entries
        print("[MOJ-LEAVE] Import summary:")
        print("  - Hospital Admissions: \(formData.hospitalAdmissionsImportedEntries.count)")
        print("  - Index Offence: \(formData.indexOffenceImportedEntries.count)")
        print("  - Mental Disorder: \(formData.mentalDisorderImportedEntries.count)")
        print("  - Attitude/Behaviour: \(formData.attitudeBehaviourImportedEntries.count)")
        print("  - Risk Factors: \(formData.riskFactorsImportedEntries.count)")
        print("  - Medication: \(formData.medicationImportedEntries.count)")
        print("  - MAPPA: \(formData.mappaImportedEntries.count)")
        print("  - Extremism: \(formData.extremismImportedEntries.count)")
        print("  - Absconding: \(formData.abscondingImportedEntries.count)")

        // === Auto-prefill 4e Risk Factors from imported data (matching Desktop) ===
        prefillRiskFactorsFromNotes(notes)

        // === Auto-prefill 4f Medications from imported data (matching Desktop) ===
        prefillMedicationsFromNotes(notes)

        // === Auto-prefill 4g Psychology (Section 3) from 4e risks (matching Desktop) ===
        prefillPsychologyFromRisks()

        // === Auto-prefill 4h Extremism concern based on imported entries (matching Desktop) ===
        prefillExtremismFromEntries()

        // === Auto-prefill 4i AWOL status based on imported entries (matching Desktop) ===
        prefillAbscondingFromEntries()
    }

    // MARK: - 4h Extremism Prefill (matching Desktop logic)
    private func prefillExtremismFromEntries() {
        // If extremism entries were found, set concern to "yes", otherwise "na"
        if !formData.extremismImportedEntries.isEmpty {
            formData.extremismConcern = "yes"
            print("[MOJ-LEAVE] 4h: Auto-set extremism concern = YES (\(formData.extremismImportedEntries.count) entries found)")
        } else {
            formData.extremismConcern = "na"
            print("[MOJ-LEAVE] 4h: Auto-set extremism concern = N/A (no entries found)")
        }
    }

    // MARK: - 4i Absconding Prefill (matching Desktop logic)
    private func prefillAbscondingFromEntries() {
        // If absconding entries were found within 12 months, set AWOL to "yes", otherwise "no"
        if !formData.abscondingImportedEntries.isEmpty {
            formData.abscondingAWOL = "yes"
            print("[MOJ-LEAVE] 4i: Auto-set AWOL = YES (\(formData.abscondingImportedEntries.count) entries found in 12-month window)")
        } else {
            formData.abscondingAWOL = "no"
            print("[MOJ-LEAVE] 4i: Auto-set AWOL = NO (no entries found in 12-month window)")
        }
    }

    // MARK: - 4e Risk Prefill (matching Desktop logic)
    private func prefillRiskFactorsFromNotes(_ notes: [ClinicalNote]) {
        // Only analyze the IMPORTED risk entries, not all notes
        guard !formData.riskFactorsImportedEntries.isEmpty else {
            print("[MOJ-LEAVE] 4e: No risk entries imported, skipping prefill")
            return
        }

        // Combine only the imported risk entry text for analysis
        let fullText = formData.riskFactorsImportedEntries.map { $0.text }.joined(separator: "\n").lowercased()
        print("[MOJ-LEAVE] 4e: Analyzing \(formData.riskFactorsImportedEntries.count) imported risk entries")

        // Use imported risk entries for current risks
        let currentText = fullText

        // Use imported INDEX OFFENCE entries for historical risks (from 4b)
        let historicalText = formData.indexOffenceImportedEntries.map { $0.text }.joined(separator: "\n").lowercased()
        print("[MOJ-LEAVE] 4e: Using \(formData.indexOffenceImportedEntries.count) index offence entries for historical risks")

        // Risk keyword patterns (matching Desktop RISK_KEYWORD_MAP)
        let riskPatterns: [(key: String, positive: [String], negative: [String])] = [
            ("violenceOthers",
             ["violent", "violence", "aggressive", "aggression", "assaulted", "assault", "attacked", "attack",
              "punched", "punching", "kicked", "kicking", "weapon", "knife", "stabbed", "stabbing",
              "physically aggressive", "acts of violence", "violent behaviour"],
             ["no violence", "no aggression", "not violent", "non-violent", "no incidents of violence", "nil violence"]),
            ("violenceProperty",
             ["damage to property", "criminal damage", "damaged property", "smashed window", "broke window",
              "fire setting", "arson", "set fire to", "started fire", "destroyed property"],
             ["no damage", "no criminal damage", "no property damage"]),
            ("selfHarm",
             ["self-harm", "self harm", "self-harmed", "self-harming", "cut himself", "cut herself",
              "cutting behaviour", "ligature", "self-injur", "harmed himself", "harmed herself"],
             ["no self-harm", "no self harm", "not self-harming", "nil self-harm", "denies self-harm"]),
            ("suicide",
             ["suicid", "end my life", "end his life", "end her life", "kill myself", "kill himself",
              "kill herself", "take my life", "overdose", "attempted hang", "tried to hang"],
             ["no suicid", "not suicid", "nil suicid", "denies suicid", "no suicidal ideation"]),
            ("selfNeglect",
             ["self-neglect", "self neglect", "neglecting himself", "neglecting herself",
              "poor hygiene", "poor self-care", "not eating properly", "refusing food",
              "not washing", "not showering", "unkempt appearance"],
             ["no self-neglect", "good hygiene", "eating well", "good self-care", "well-kempt"]),
            ("sexual",
             ["raped", "raping", "committed rape", "convicted of rape", "sexual assault",
              "sexually assaulted", "sexual offence", "sexual offender", "indecent assault",
              "indecent exposure", "sexual abuse", "inappropriate sexual", "sexual misconduct"],
             ["no sexual offences", "no sexual concerns", "nil sexual", "no history of sexual offending"]),
            ("exploitation",
             ["being exploited", "was exploited", "exploitation risk", "vulnerable to exploitation",
              "financial exploitation", "cuckooing", "county lines", "taken advantage of"],
             ["no exploitation", "not vulnerable to exploitation", "not being exploited"]),
            ("substance",
             ["substance misuse", "substance abuse", "drug misuse", "drug abuse",
              "cannabis", "cocaine", "heroin", "amphetamine", "class a drug", "illicit drug",
              "intoxicated", "under influence", "alcohol misuse", "positive drug test"],
             ["no substance", "no drug use", "abstinent", "drug-free", "negative drug test", "clean drug test"]),
            ("stalking",
             ["stalked", "stalking", "stalker", "harassed", "harassing", "harassment",
              "followed victim", "followed woman", "obsessive behaviour", "unwanted contact"],
             ["no stalking", "no harassment", "not stalking", "no harassing behaviour"]),
            ("deterioration",
             ["mental state deteriorat", "deteriorating mental", "deterioration in",
              "relapse", "relapsed", "relapsing", "signs of relapse", "decompens",
              "becoming unwell", "worsening mental state", "psychotic symptoms"],
             ["mental stable", "no deteriorat", "mental state stable", "settled", "remains stable", "no signs of relapse"]),
            ("nonCompliance",
             ["non-complia", "non complia", "not compliant", "poor compliance",
              "refused medication", "refusing medication", "disengag", "not engaging",
              "lack of engagement", "abscond", "absconding risk", "failed to attend", "did not attend"],
             ["compliant", "good compliance", "engaging well", "good engagement", "fully engaged"])
        ]

        // Analyze and set risks
        for (riskKey, positive, negative) in riskPatterns {
            // Check current risks
            var currentLevel = 0  // 0=None
            var hasNegativeCurrent = false

            for neg in negative {
                if currentText.contains(neg) {
                    hasNegativeCurrent = true
                    currentLevel = 1  // Low
                    break
                }
            }

            if !hasNegativeCurrent {
                for pos in positive {
                    if currentText.contains(pos) {
                        // Check for negation context
                        if currentText.contains("no \(pos)") || currentText.contains("nil \(pos)") || currentText.contains("not \(pos)") {
                            currentLevel = 1  // Low
                        } else {
                            currentLevel = 2  // Medium
                        }
                        break
                    }
                }
            }

            // Check historical risks
            var historicalLevel = 0  // 0=None
            if !historicalText.isEmpty {
                var hasNegativeHistorical = false
                for neg in negative {
                    if historicalText.contains(neg) {
                        hasNegativeHistorical = true
                        break
                    }
                }

                if !hasNegativeHistorical {
                    for pos in positive {
                        if historicalText.contains(pos) {
                            // Higher severity for serious offences
                            if riskKey == "sexual" && (historicalText.contains("rape") || historicalText.contains("sexual assault")) {
                                historicalLevel = 3  // High
                            } else if riskKey == "violenceOthers" && (historicalText.contains("knife") || historicalText.contains("weapon") || historicalText.contains("stab")) {
                                historicalLevel = 3  // High
                            } else {
                                historicalLevel = 2  // Medium
                            }
                            break
                        }
                    }
                }
            }

            // Apply to form data (only if detected - don't overwrite existing values)
            switch riskKey {
            case "violenceOthers":
                if currentLevel > 0 && formData.riskCurrentViolenceOthers == 0 { formData.riskCurrentViolenceOthers = currentLevel }
                if historicalLevel > 0 && formData.riskHistoricalViolenceOthers == 0 { formData.riskHistoricalViolenceOthers = historicalLevel }
            case "violenceProperty":
                if currentLevel > 0 && formData.riskCurrentViolenceProperty == 0 { formData.riskCurrentViolenceProperty = currentLevel }
                if historicalLevel > 0 && formData.riskHistoricalViolenceProperty == 0 { formData.riskHistoricalViolenceProperty = historicalLevel }
            case "selfHarm":
                if currentLevel > 0 && formData.riskCurrentSelfHarm == 0 { formData.riskCurrentSelfHarm = currentLevel }
                if historicalLevel > 0 && formData.riskHistoricalSelfHarm == 0 { formData.riskHistoricalSelfHarm = historicalLevel }
            case "suicide":
                if currentLevel > 0 && formData.riskCurrentSuicide == 0 { formData.riskCurrentSuicide = currentLevel }
                if historicalLevel > 0 && formData.riskHistoricalSuicide == 0 { formData.riskHistoricalSuicide = historicalLevel }
            case "selfNeglect":
                if currentLevel > 0 && formData.riskCurrentSelfNeglect == 0 { formData.riskCurrentSelfNeglect = currentLevel }
                if historicalLevel > 0 && formData.riskHistoricalSelfNeglect == 0 { formData.riskHistoricalSelfNeglect = historicalLevel }
            case "sexual":
                if currentLevel > 0 && formData.riskCurrentSexual == 0 { formData.riskCurrentSexual = currentLevel }
                if historicalLevel > 0 && formData.riskHistoricalSexual == 0 { formData.riskHistoricalSexual = historicalLevel }
            case "exploitation":
                if currentLevel > 0 && formData.riskCurrentExploitation == 0 { formData.riskCurrentExploitation = currentLevel }
                if historicalLevel > 0 && formData.riskHistoricalExploitation == 0 { formData.riskHistoricalExploitation = historicalLevel }
            case "substance":
                if currentLevel > 0 && formData.riskCurrentSubstance == 0 { formData.riskCurrentSubstance = currentLevel }
                if historicalLevel > 0 && formData.riskHistoricalSubstance == 0 { formData.riskHistoricalSubstance = historicalLevel }
            case "stalking":
                if currentLevel > 0 && formData.riskCurrentStalking == 0 { formData.riskCurrentStalking = currentLevel }
                if historicalLevel > 0 && formData.riskHistoricalStalking == 0 { formData.riskHistoricalStalking = historicalLevel }
            case "deterioration":
                if currentLevel > 0 && formData.riskCurrentDeterioration == 0 { formData.riskCurrentDeterioration = currentLevel }
                if historicalLevel > 0 && formData.riskHistoricalDeterioration == 0 { formData.riskHistoricalDeterioration = historicalLevel }
            case "nonCompliance":
                if currentLevel > 0 && formData.riskCurrentNonCompliance == 0 { formData.riskCurrentNonCompliance = currentLevel }
                if historicalLevel > 0 && formData.riskHistoricalNonCompliance == 0 { formData.riskHistoricalNonCompliance = historicalLevel }
            default:
                break
            }

            if currentLevel > 0 || historicalLevel > 0 {
                print("[MOJ-LEAVE] 4e: Prefilled \(riskKey) - current: \(currentLevel), historical: \(historicalLevel)")
            }
        }
    }

    // MARK: - 4f Medication Prefill (matching Desktop logic)
    private func prefillMedicationsFromNotes(_ notes: [ClinicalNote]) {
        // Only prefill if no medications already entered
        guard formData.medicationEntries.isEmpty || formData.medicationEntries.allSatisfy({ $0.name.isEmpty }) else {
            print("[MOJ-LEAVE] 4f: Medications already entered, skipping prefill")
            return
        }

        // Use the MedicationExtractor to extract medications from recent notes (last 1 year)
        let mostRecentDate = notes.map { $0.date }.max() ?? Date()
        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: mostRecentDate) ?? mostRecentDate
        let recentNotes = notes.filter { $0.date >= oneYearAgo }

        print("[MOJ-LEAVE] 4f: Extracting medications from \(recentNotes.count) recent notes")

        let extracted = MedicationExtractor.shared.extractMedications(from: recentNotes)

        if extracted.drugs.isEmpty {
            print("[MOJ-LEAVE] 4f: No medications found in notes")
            return
        }

        // Priority order for psychiatric medication classes (matching Desktop)
        let psychClassPriority: [PsychSubtype] = [.antipsychotic, .antidepressant, .antimanic, .hypnotic, .anticholinergic, .other]

        // Get most recent medication per psychiatric class, prioritize psychiatric meds
        var selectedMeds: [(name: String, dose: String?, frequency: String?)] = []

        // First add psychiatric medications by subtype priority
        for subtype in psychClassPriority {
            let drugsOfType = extracted.drugsBySubtype(subtype)
            if let drug = drugsOfType.first {
                // Get most recent mention with dose
                if let mention = drug.mentions.sorted(by: { $0.date > $1.date }).first(where: { $0.dose != nil }) {
                    selectedMeds.append((name: drug.name, dose: mention.dose, frequency: mention.frequency))
                } else if let mention = drug.mentions.sorted(by: { $0.date > $1.date }).first {
                    selectedMeds.append((name: drug.name, dose: mention.dose, frequency: mention.frequency))
                }
            }
        }

        // Then add any physical medications
        for drug in extracted.physicalDrugs.prefix(2) {
            if let mention = drug.mentions.sorted(by: { $0.date > $1.date }).first {
                selectedMeds.append((name: drug.name, dose: mention.dose, frequency: mention.frequency))
            }
        }

        // Limit to 8 medications (matching Desktop)
        selectedMeds = Array(selectedMeds.prefix(8))

        if selectedMeds.isEmpty {
            print("[MOJ-LEAVE] 4f: No medications to prefill")
            return
        }

        // Clear existing empty entries and add the extracted medications
        formData.medicationEntries.removeAll()

        for med in selectedMeds {
            var entry = MedicationEntry()
            entry.name = med.name
            entry.dose = med.dose ?? ""
            // Map frequency to picker options
            if let freq = med.frequency?.lowercased() {
                let freqMap = ["od": "OD", "bd": "BD", "tds": "TDS", "qds": "QDS", "nocte": "Nocte",
                               "prn": "PRN", "weekly": "Weekly", "fortnightly": "Fortnightly", "monthly": "Monthly",
                               "daily": "OD", "twice": "BD", "mane": "OD", "om": "OD", "on": "Nocte"]
                entry.frequency = freqMap[freq] ?? freq.uppercased()
            }
            formData.medicationEntries.append(entry)
        }

        print("[MOJ-LEAVE] 4f: Prefilled \(formData.medicationEntries.count) medications")
    }

    // MARK: - 4g Psychology Prefill (matching Desktop logic)
    private func prefillPsychologyFromRisks() {
        // Map 4e risk keys to 4g risk keys (they use slightly different naming)
        let riskKeyMap: [String: String] = [
            "violenceOthers": "violence_others",
            "violenceProperty": "violence_property",
            "selfHarm": "self_harm",
            "suicide": "suicide",
            "selfNeglect": "self_neglect",
            "sexual": "sexual",
            "exploitation": "exploitation",
            "substance": "substance",
            "stalking": "stalking",
            "deterioration": "deterioration",
            "nonCompliance": "non_compliance"
        ]

        // Check current risks from 4e and auto-check in 4g Section 3
        let currentRisks: [(key: String, level: Int)] = [
            ("violenceOthers", formData.riskCurrentViolenceOthers),
            ("violenceProperty", formData.riskCurrentViolenceProperty),
            ("selfHarm", formData.riskCurrentSelfHarm),
            ("suicide", formData.riskCurrentSuicide),
            ("selfNeglect", formData.riskCurrentSelfNeglect),
            ("sexual", formData.riskCurrentSexual),
            ("exploitation", formData.riskCurrentExploitation),
            ("substance", formData.riskCurrentSubstance),
            ("stalking", formData.riskCurrentStalking),
            ("deterioration", formData.riskCurrentDeterioration),
            ("nonCompliance", formData.riskCurrentNonCompliance)
        ]

        let historicalRisks: [(key: String, level: Int)] = [
            ("violenceOthers", formData.riskHistoricalViolenceOthers),
            ("violenceProperty", formData.riskHistoricalViolenceProperty),
            ("selfHarm", formData.riskHistoricalSelfHarm),
            ("suicide", formData.riskHistoricalSuicide),
            ("selfNeglect", formData.riskHistoricalSelfNeglect),
            ("sexual", formData.riskHistoricalSexual),
            ("exploitation", formData.riskHistoricalExploitation),
            ("substance", formData.riskHistoricalSubstance),
            ("stalking", formData.riskHistoricalStalking),
            ("deterioration", formData.riskHistoricalDeterioration),
            ("nonCompliance", formData.riskHistoricalNonCompliance)
        ]

        var prefillCount = 0

        // Auto-check risk factors that have current or historical risk > 0
        for (riskKey, currentLevel) in currentRisks {
            guard let psychKey = riskKeyMap[riskKey] else { continue }

            // Check if already set
            if formData.psychRiskAttitudes[psychKey] != nil { continue }

            // Find corresponding historical level
            let historicalLevel = historicalRisks.first { $0.key == riskKey }?.level ?? 0

            // If either current or historical risk is detected, auto-check in 4g
            if currentLevel > 0 || historicalLevel > 0 {
                // Map risk level to attitude level
                // Risk levels: 0=None, 1=Low, 2=Medium, 3=High
                // Attitude options: 0=Avoids, 1=Limited, 2=Some, 3=Good, 4=Full
                let attitudeLevel: Int
                let maxRisk = max(currentLevel, historicalLevel)

                switch maxRisk {
                case 1:  // Low risk
                    attitudeLevel = 3  // Good understanding
                case 2:  // Medium risk
                    attitudeLevel = 2  // Some understanding
                case 3:  // High risk
                    attitudeLevel = 1  // Limited understanding (more work needed)
                default:
                    attitudeLevel = 2  // Default to Some
                }

                formData.psychRiskAttitudes[psychKey] = attitudeLevel
                prefillCount += 1
                print("[MOJ-LEAVE] 4g: Auto-checked \(psychKey) with attitude level \(attitudeLevel) (current:\(currentLevel), historical:\(historicalLevel))")
            }
        }

        if prefillCount > 0 {
            print("[MOJ-LEAVE] 4g: Prefilled \(prefillCount) risk attitudes from 4e")
        }
    }

    // MARK: - History Section Types (for clerking extraction)
    private enum HistorySectionType {
        case pastPsychiatric
        case forensicHistory
        case diagnosis
        case hpc           // History of Presenting Complaint (for 4c)
        case mentalState   // Mental State Examination (for 4c)
        case summary       // Summary/Impression (for 4c)

        var headers: [String] {
            switch self {
            case .pastPsychiatric:
                return [
                    "past psychiatric history", "psychiatric history", "past psych",
                    "pph", "psych hx", "previous admissions", "previous mh history"
                ]
            case .forensicHistory:
                return [
                    "forensic history", "forensic", "offence", "offending",
                    "criminal", "police", "charges", "index offence"
                ]
            case .diagnosis:
                return [
                    "diagnosis", "diagnoses", "icd-10", "icd10",
                    "diagnosed with", "working diagnosis", "primary diagnosis"
                ]
            case .hpc:
                return [
                    "history of presenting complaint", "hpc", "presenting complaint",
                    "current presentation", "presenting problem", "reason for admission",
                    "circumstances of admission", "circumstances leading to admission"
                ]
            case .mentalState:
                return [
                    "mental state examination", "mental state", "mse",
                    "current mental state", "mental status"
                ]
            case .summary:
                return [
                    "summary", "impression", "formulation", "conclusion"
                ]
            }
        }

        var nextSectionHeaders: [String] {
            switch self {
            case .pastPsychiatric:
                // Headers that come AFTER past psych (end the section)
                return [
                    "medication history", "drug history", "dhx", "allerg",
                    "drug and alcohol", "substance use", "substance misuse",
                    "past medical history", "medical history", "pmh",
                    "forensic history", "forensic", "offence",
                    "personal history", "social history", "family history",
                    "mental state examination", "mental state", "mse",
                    "risk", "physical examination", "examination",
                    "impression", "plan", "management", "summary"
                ]
            case .forensicHistory:
                // Headers that come AFTER forensic (end the section)
                return [
                    "personal history", "social history", "family history",
                    "mental state examination", "mental state", "mse",
                    "risk", "physical examination", "examination",
                    "impression", "plan", "management", "summary",
                    "past medical history", "medical history", "pmh",
                    "drug and alcohol", "substance use"
                ]
            case .diagnosis:
                // Headers that come AFTER diagnosis (end the section)
                return [
                    "circumstances of admission", "presenting complaint",
                    "medication history", "drug history", "dhx",
                    "past psychiatric history", "psychiatric history",
                    "forensic history", "personal history", "social history",
                    "mental state examination", "mental state", "mse",
                    "risk", "plan", "impression", "summary"
                ]
            case .hpc:
                // Headers that come AFTER HPC
                return [
                    "past psychiatric history", "psychiatric history", "pph",
                    "forensic history", "forensic", "personal history",
                    "social history", "family history", "medical history",
                    "mental state", "mse", "diagnosis", "risk", "plan"
                ]
            case .mentalState:
                // Headers that come AFTER MSE
                return [
                    "risk", "risk assessment", "diagnosis", "impression",
                    "plan", "management", "summary", "formulation"
                ]
            case .summary:
                // Headers that come AFTER summary
                return [
                    "plan", "management", "follow up", "recommendations"
                ]
            }
        }
    }

    // MARK: - Extract History Section from Clerkings (matching Desktop logic)
    private static func extractHistorySectionFromClerkingsStatic(_ notes: [ClinicalNote], sectionType: HistorySectionType) -> [(date: Date, text: String)] {
        // Clerking triggers (matching Desktop history_extractor_sections.py)
        let clerkingTriggers = [
            "admission clerking", "clerking", "duty doctor admission",
            "new admission", "new transfer", "circumstances of admission",
            "circumstances leading to admission", "new client assesment"
        ]

        let sectionHeaders = sectionType.headers
        let nextHeaders = sectionType.nextSectionHeaders

        var results: [(date: Date, text: String)] = []
        var seenTexts = Set<String>()

        // Find clerkings: notes that contain at least one clerking trigger
        let clerkings = notes.filter { note in
            let lower = note.body.lowercased()
            return clerkingTriggers.contains { lower.contains($0) }
        }

        for clerking in clerkings {
            let lines = clerking.body.components(separatedBy: .newlines)
            var inSection = false
            var sectionLines: [String] = []

            for line in lines {
                let lowerLine = line.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

                // Check if this line starts our target section
                if sectionHeaders.contains(where: { lowerLine.hasPrefix($0) || lowerLine.contains($0 + ":") || lowerLine.contains($0 + " :") }) {
                    inSection = true
                    // Don't include the header line itself
                    continue
                }

                // Check if this line starts a different section (end of our section)
                if inSection && nextHeaders.contains(where: { lowerLine.hasPrefix($0) || lowerLine.contains($0 + ":") }) {
                    inSection = false
                    continue
                }

                // If we're in our target section, collect the line
                if inSection {
                    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        sectionLines.append(trimmed)
                    }
                }
            }

            // If we found section content, add it
            if !sectionLines.isEmpty {
                let text = sectionLines.joined(separator: "\n")
                // Deduplicate by text content
                let textKey = text.lowercased().prefix(200).description
                if !seenTexts.contains(textKey) {
                    seenTexts.insert(textKey)
                    results.append((date: clerking.date, text: text))
                }
            }
        }

        // Sort by date
        results.sort { $0.date < $1.date }

        return results
    }

    // MARK: - Extract Diagnosis Lines from Notes (matching Desktop DIAGNOSIS_PATTERNS exactly)
    private static func extractDiagnosisLinesStatic(from notes: [ClinicalNote]) -> [(date: Date, text: String)] {
        // Exact patterns from Desktop moj_leave_form_page.py line 17437-17482
        let diagnosisPatterns = [
            // Schizophrenia variants
            "paranoid schizophrenia",
            "catatonic schizophrenia",
            "hebephrenic schizophrenia",
            "residual schizophrenia",
            "simple schizophrenia",
            "undifferentiated schizophrenia",
            "schizoaffective",
            // Autism
            "autism spectrum disorder",
            "autistic spectrum",
            "asperger",
            "atypical autism",
            // Mood disorders
            "bipolar affective disorder",
            "bipolar disorder",
            "manic depressi",      // matches manic depression/depressive
            "recurrent depressi",  // matches recurrent depression/depressive
            "major depressi",      // matches major depression/depressive
            // Personality disorders
            "emotionally unstable personality",
            "eupd",  // common abbreviation
            "borderline personality",
            "antisocial personality",
            "dissocial personality",
            "narcissistic personality",
            "paranoid personality",
            "personality disorder",
            // Anxiety
            "generalised anxiety",
            "generalized anxiety",
            "ptsd",
            "post-traumatic stress",
            "post traumatic stress",
            // Psychosis
            "acute psycho",  // matches acute psychosis/psychotic
            // Learning disability
            "learning disabilit",      // matches disability/disabilities
            "intellectual disabilit",  // matches disability/disabilities
            // Substance
            "alcohol dependence",
            "drug dependence",
            "opioid dependence",
            "substance misuse"
        ]

        var results: [(date: Date, text: String)] = []
        var seenTexts = Set<String>()

        for note in notes {
            let lines = note.body.components(separatedBy: .newlines)

            for line in lines {
                let lineLower = line.lowercased()
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.count < 10 { continue }

                // ONLY extract lines that START with "Diagnosis" header (matching Desktop)
                let isDiagnosisLine = lineLower.hasPrefix("diagnosis") ||
                                      lineLower.hasPrefix("diagnoses") ||
                                      lineLower.contains("diagnosis:") ||
                                      lineLower.contains("diagnoses:")

                if isDiagnosisLine {
                    // Check if line contains any ICD-10 diagnosis pattern
                    if diagnosisPatterns.contains(where: { lineLower.contains($0) }) {
                        let textKey = trimmed.lowercased().prefix(100).description
                        if !seenTexts.contains(textKey) {
                            seenTexts.insert(textKey)
                            results.append((date: note.date, text: trimmed))
                        }
                    }
                }
            }
        }

        results.sort { $0.date < $1.date }
        return results
    }

    // MARK: - Extract and Auto-fill ICD-10 Diagnoses (matching Desktop logic)
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
                print("[MOJ-LEAVE] Matched diagnosis: '\(pattern)' -> '\(diagnosis.rawValue)'")

                // Limit to 3 diagnoses
                if extractedDiagnoses.count >= 3 {
                    break
                }
            }
        }

        print("[MOJ-LEAVE] Extracted \(extractedDiagnoses.count) diagnoses for ICD-10 auto-fill")

        // Auto-fill the ICD-10 pickers if they're .none (not set)
        if extractedDiagnoses.count > 0 && formData.mdDiagnosis1 == .none {
            formData.mdDiagnosis1 = extractedDiagnoses[0]
            print("[MOJ-LEAVE] Set primary diagnosis: \(extractedDiagnoses[0].rawValue)")
        }
        if extractedDiagnoses.count > 1 && formData.mdDiagnosis2 == .none {
            formData.mdDiagnosis2 = extractedDiagnoses[1]
            print("[MOJ-LEAVE] Set secondary diagnosis: \(extractedDiagnoses[1].rawValue)")
        }
        if extractedDiagnoses.count > 2 && formData.mdDiagnosis3 == .none {
            formData.mdDiagnosis3 = extractedDiagnoses[2]
            print("[MOJ-LEAVE] Set tertiary diagnosis: \(extractedDiagnoses[2].rawValue)")
        }
    }

    /// Helper function to find an ICD10Diagnosis enum case that contains the search term
    private func findICD10Diagnosis(matching searchTerm: String) -> ICD10Diagnosis? {
        let searchLower = searchTerm.lowercased()
        return ICD10Diagnosis.allCases.first { diagnosis in
            diagnosis != .none && diagnosis.rawValue.lowercased().contains(searchLower)
        }
    }

    /// Detect specific diagnosis terms in text to use as selectable categories (like 3g leave types)
    private static func detectDiagnosisCategoriesStatic(in text: String) -> [String] {
        let textLower = text.lowercased()
        var categories: [String] = []

        // Map of diagnosis patterns to display categories
        let diagnosisTerms: [(pattern: String, category: String)] = [
            // Schizophrenia
            ("paranoid schizophrenia", "Paranoid Schizophrenia"),
            ("catatonic schizophrenia", "Catatonic Schizophrenia"),
            ("hebephrenic schizophrenia", "Hebephrenic Schizophrenia"),
            ("residual schizophrenia", "Residual Schizophrenia"),
            ("simple schizophrenia", "Simple Schizophrenia"),
            ("undifferentiated schizophrenia", "Undifferentiated Schizophrenia"),
            ("schizoaffective", "Schizoaffective"),
            ("schizophrenia", "Schizophrenia"),
            // Mood
            ("bipolar", "Bipolar"),
            ("manic depressi", "Bipolar"),
            ("recurrent depressi", "Recurrent Depression"),
            ("major depressi", "Major Depression"),
            ("depressive disorder", "Depression"),
            ("depression", "Depression"),
            // Personality
            ("emotionally unstable personality", "EUPD"),
            ("borderline personality", "BPD"),
            ("antisocial personality", "ASPD"),
            ("dissocial personality", "Dissocial PD"),
            ("paranoid personality", "Paranoid PD"),
            ("personality disorder", "Personality Disorder"),
            // Anxiety
            ("generalised anxiety", "GAD"),
            ("generalized anxiety", "GAD"),
            ("ptsd", "PTSD"),
            ("post-traumatic stress", "PTSD"),
            ("post traumatic stress", "PTSD"),
            // Psychosis
            ("acute psycho", "Acute Psychosis"),
            ("psychosis", "Psychosis"),
            ("psychotic", "Psychosis"),
            // Learning disability
            ("learning disabilit", "Learning Disability"),
            ("intellectual disabilit", "Intellectual Disability"),
            // Autism
            ("autism", "Autism"),
            ("autistic", "Autism"),
            ("asperger", "Asperger"),
            // Substance
            ("alcohol dependence", "Alcohol Dependence"),
            ("drug dependence", "Drug Dependence"),
            ("opioid dependence", "Opioid Dependence"),
            ("substance", "Substance Use"),
        ]

        var matchedCategories = Set<String>()
        for (pattern, category) in diagnosisTerms {
            if textLower.contains(pattern) && !matchedCategories.contains(category) {
                categories.append(category)
                matchedCategories.insert(category)
            }
        }

        return categories
    }

    private func processExtractedReportData(_ document: ExtractedDocument) {
        // Auto-fill patient info if available and current fields are empty
        if !document.patientInfo.fullName.isEmpty && formData.patientName.isEmpty {
            formData.patientName = document.patientInfo.fullName
        }
        if let dob = document.patientInfo.dateOfBirth, formData.patientDOB == nil {
            formData.patientDOB = dob
        }
        if !document.patientInfo.hospitalNumber.isEmpty && formData.hospitalNumber.isEmpty {
            formData.hospitalNumber = document.patientInfo.hospitalNumber
        }
        if document.patientInfo.gender != .notSpecified {
            formData.patientGender = document.patientInfo.gender
        }
    }

    // MARK: - Extract Patient Details from Notes (matching Desktop logic)
    private func extractPatientDetailsFromNotes(_ notes: [ClinicalNote]) {
        // Combine all note text for extraction
        var documentText = ""
        for note in notes.prefix(200) {
            documentText += note.body + "\n"
        }

        guard !documentText.isEmpty else {
            print("[MOJ-LEAVE] No document text available for patient details extraction")
            return
        }

        print("[MOJ-LEAVE] Extracting patient details from \(documentText.count) chars")

        // EXTRACT PATIENT NAME (if not already set)
        if formData.patientName.isEmpty {
            let namePatterns: [(String, String)] = [
                // SURNAME, Firstname format at start
                (#"^([A-Z][A-Z\-']+),\s*([A-Z][a-zA-Z\-']+(?:\s+[A-Z][a-zA-Z\-']+)?)"#, "surname_first"),
                // "PATIENT NAME" followed by name
                (#"(?i)patient\s+name\s*[:]?\s*([A-Z][a-zA-Z\-']+(?:[ ]+[A-Z][a-zA-Z\-']+){0,3})"#, "patient_name_label"),
                // "Name of Patient:" pattern
                (#"(?i)name\s+of\s+patient\s*[:]?\s*\n?\s*([A-Z][a-zA-Z\-']+(?:[ ]+[A-Z][a-zA-Z\-']+){0,3})"#, "name_of_patient"),
                // "Patient:" or "Name:" followed by name
                (#"(?i)(?:patient|name)\s*[:]\s*([A-Z][a-zA-Z\-']+(?:[ ]+[A-Z][a-zA-Z\-']+){0,3})"#, "patient_colon"),
                // "Re:" followed by name
                (#"(?i)re\s*[:]\s*([A-Z][a-zA-Z\-']+(?:[ ]+[A-Z][a-zA-Z\-']+){0,3})"#, "re_colon"),
            ]

            for (pattern, patternName) in namePatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: []),
                   let match = regex.firstMatch(in: documentText, options: [], range: NSRange(documentText.startIndex..., in: documentText)) {
                    var extractedName: String
                    if patternName == "surname_first", match.numberOfRanges >= 3,
                       let surnameRange = Range(match.range(at: 1), in: documentText),
                       let firstnameRange = Range(match.range(at: 2), in: documentText) {
                        let surname = String(documentText[surnameRange]).capitalized
                        let firstname = String(documentText[firstnameRange])
                        extractedName = "\(firstname) \(surname)"
                    } else if let range = Range(match.range(at: 1), in: documentText) {
                        extractedName = String(documentText[range])
                    } else {
                        continue
                    }

                    // Clean up name
                    extractedName = extractedName.replacingOccurrences(of: #"\s*\(.*?\)\s*"#, with: " ", options: .regularExpression)
                    extractedName = extractedName.trimmingCharacters(in: .whitespacesAndNewlines)

                    if extractedName.count >= 2 && extractedName.count <= 60 {
                        formData.patientName = extractedName
                        print("[MOJ-LEAVE] Extracted patient name: '\(extractedName)' (pattern: \(patternName))")
                        break
                    }
                }
            }
        }

        // EXTRACT DATE OF BIRTH (if not already set)
        if formData.patientDOB == nil {
            let dobPatterns = [
                #"(?i)(?:d\.?o\.?b\.?|date\s+of\s+birth)\s*[:]\s*\n?\s*(\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4})"#,
                #"(?i)(?:d\.?o\.?b\.?|date\s+of\s+birth)\s*[:]\s*\n?\s*(\d{1,2}\s+[A-Za-z]+\s+\d{4})"#,
                #"(?i)born\s*[:]\s*\n?\s*(\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4})"#,
            ]

            for pattern in dobPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: []),
                   let match = regex.firstMatch(in: documentText, options: [], range: NSRange(documentText.startIndex..., in: documentText)),
                   let range = Range(match.range(at: 1), in: documentText) {
                    let dateStr = String(documentText[range])
                    print("[MOJ-LEAVE] Found DOB match: '\(dateStr)'")

                    let dateFormats = [
                        "dd/MM/yyyy", "dd-MM-yyyy", "dd.MM.yyyy",
                        "dd/MM/yy", "dd-MM-yy", "dd.MM.yy",
                        "d MMMM yyyy", "d MMM yyyy",
                    ]

                    let formatter = DateFormatter()
                    formatter.locale = Locale(identifier: "en_GB")

                    for format in dateFormats {
                        formatter.dateFormat = format
                        if let parsedDate = formatter.date(from: dateStr) {
                            formData.patientDOB = parsedDate
                            print("[MOJ-LEAVE] Parsed DOB: \(parsedDate)")
                            break
                        }
                    }
                    if formData.patientDOB != nil { break }
                }
            }
        }

        // EXTRACT GENDER (if not already set)
        if formData.patientGender == .notSpecified {
            // Check for explicit "Female" or "Male"
            if documentText.range(of: #"(?<![a-zA-Z])Female(?![a-z])"#, options: .regularExpression) != nil {
                formData.patientGender = .female
                print("[MOJ-LEAVE] Detected explicit 'Female' in document")
            } else if documentText.range(of: #"(?<![a-zA-Z])Male(?![a-z])"#, options: .regularExpression) != nil,
                      documentText.range(of: #"(?<![a-zA-Z])Female(?![a-z])"#, options: .regularExpression) == nil {
                formData.patientGender = .male
                print("[MOJ-LEAVE] Detected explicit 'Male' in document")
            }

            // Check for titles in parentheses
            if formData.patientGender == .notSpecified {
                if documentText.range(of: #"(?i)\(\s*(?:Miss|Mrs|Ms)\s*\)"#, options: .regularExpression) != nil {
                    formData.patientGender = .female
                    print("[MOJ-LEAVE] Detected female title in parentheses")
                } else if documentText.range(of: #"(?i)\(\s*Mr\s*\)"#, options: .regularExpression) != nil {
                    formData.patientGender = .male
                    print("[MOJ-LEAVE] Detected male title in parentheses")
                }
            }

            // Check for titles followed by names
            if formData.patientGender == .notSpecified {
                if documentText.range(of: #"\bMr\.?\s+[A-Z]"#, options: .regularExpression) != nil {
                    formData.patientGender = .male
                    print("[MOJ-LEAVE] Inferred gender from 'Mr' title")
                } else if documentText.range(of: #"\b(?:Mrs|Ms|Miss)\.?\s+[A-Z]"#, options: .regularExpression) != nil {
                    formData.patientGender = .female
                    print("[MOJ-LEAVE] Inferred gender from female title")
                }
            }

            // Count pronouns as fallback
            if formData.patientGender == .notSpecified {
                let docLower = documentText.lowercased()
                let femaleCount = docLower.components(separatedBy: " she ").count +
                                  docLower.components(separatedBy: " her ").count +
                                  docLower.components(separatedBy: " herself ").count - 3
                let maleCount = docLower.components(separatedBy: " he ").count +
                                docLower.components(separatedBy: " him ").count +
                                docLower.components(separatedBy: " himself ").count - 3

                if femaleCount > maleCount * 2 && femaleCount >= 5 {
                    formData.patientGender = .female
                    print("[MOJ-LEAVE] Inferred Female from pronouns (she/her: \(femaleCount), he/him: \(maleCount))")
                } else if maleCount > femaleCount * 2 && maleCount >= 5 {
                    formData.patientGender = .male
                    print("[MOJ-LEAVE] Inferred Male from pronouns (he/him: \(maleCount), she/her: \(femaleCount))")
                }
            }
        }

        // EXTRACT WARD
        if formData.wardName.isEmpty {
            let wardPatterns = [
                #"(?i)ward\s*[:]\s*\n?\s*([A-Za-z][A-Za-z\s\-']+?)(?=\n|$)"#,
                #"(?i)usual\s+place\s+of\s+residence\s*[:]?\s*\n?\s*(.+?)(?=\n|$)"#,
                #"(?i)([A-Za-z\s\-']+\s+Ward)\b"#,
            ]

            for pattern in wardPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: []),
                   let match = regex.firstMatch(in: documentText, options: [], range: NSRange(documentText.startIndex..., in: documentText)),
                   let range = Range(match.range(at: 1), in: documentText) {
                    let ward = String(documentText[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if ward.count >= 2 && ward.count <= 50 {
                        formData.wardName = ward
                        print("[MOJ-LEAVE] Extracted ward: '\(ward)'")
                        break
                    }
                }
            }
        }

        // EXTRACT MHA SECTION
        if formData.mhaSection.isEmpty || formData.mhaSection == "37/41" {
            let mhaPatterns = [
                #"(?i)mental\s+health\s+act\s+(?:status|section)\s*[:]?\s*\n?\s*(S?\d+[\/\-]?\d*[A-Za-z]?)"#,
                #"(?i)(?:mha\s+)?section\s*[:]\s*\n?\s*(S?\d+[\/\-]?\d*[A-Za-z]?)"#,
                #"\b(S?37[\/\-]41|S?47[\/\-]49|S?48[\/\-]49|S?45A)\b"#,
            ]

            for pattern in mhaPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: []),
                   let match = regex.firstMatch(in: documentText, options: [], range: NSRange(documentText.startIndex..., in: documentText)),
                   let range = Range(match.range(at: 1), in: documentText) {
                    var mha = String(documentText[range])
                    // Normalize
                    mha = mha.replacingOccurrences(of: "^S", with: "", options: .regularExpression)
                    mha = mha.replacingOccurrences(of: "-", with: "/")
                    if !mha.isEmpty {
                        formData.mhaSection = mha
                        print("[MOJ-LEAVE] Extracted MHA Section: '\(mha)'")
                        break
                    }
                }
            }
        }

        // EXTRACT MOJ REFERENCE
        if formData.mojReference.isEmpty {
            let mojPatterns = [
                #"(?i)moj\s*(?:ref(?:erence)?|no\.?)\s*[:]?\s*\n?\s*([A-Z0-9][A-Z0-9\-\/\s]{4,20})"#,
                #"(?i)ministry\s+of\s+justice\s*(?:ref(?:erence)?|no\.?)?\s*[:]?\s*\n?\s*([A-Z0-9][A-Z0-9\-\/\s]{4,20})"#,
            ]

            for pattern in mojPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: []),
                   let match = regex.firstMatch(in: documentText, options: [], range: NSRange(documentText.startIndex..., in: documentText)),
                   let range = Range(match.range(at: 1), in: documentText) {
                    let ref = String(documentText[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if ref.count >= 4 && ref.count <= 25 {
                        formData.mojReference = ref
                        print("[MOJ-LEAVE] Extracted MOJ Reference: '\(ref)'")
                        break
                    }
                }
            }
        }

        // EXTRACT HOSPITAL NAME
        if formData.hospitalName.isEmpty {
            let hospitalPatterns = [
                #"(?i)hospital\s*[:]\s*\n?\s*([A-Za-z][A-Za-z\s\-']+?(?:Hospital|Unit|Centre))(?=\n|$)"#,
                #"(?i)([A-Za-z\s\-']+(?:Hospital|Unit|Centre))\b"#,
            ]

            for pattern in hospitalPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: []),
                   let match = regex.firstMatch(in: documentText, options: [], range: NSRange(documentText.startIndex..., in: documentText)),
                   let range = Range(match.range(at: 1), in: documentText) {
                    let hospital = String(documentText[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if hospital.count >= 5 && hospital.count <= 60 {
                        formData.hospitalName = hospital
                        print("[MOJ-LEAVE] Extracted hospital: '\(hospital)'")
                        break
                    }
                }
            }
        }

        print("[MOJ-LEAVE] Patient details extraction complete")
        print("  - Name: \(formData.patientName.isEmpty ? "(not found)" : formData.patientName)")
        print("  - DOB: \(formData.patientDOB == nil ? "(not found)" : String(describing: formData.patientDOB!))")
        print("  - Gender: \(formData.patientGender.rawValue)")
        print("  - Ward: \(formData.wardName.isEmpty ? "(not found)" : formData.wardName)")
        print("  - Hospital: \(formData.hospitalName.isEmpty ? "(not found)" : formData.hospitalName)")
        print("  - MHA Section: \(formData.mhaSection)")
        print("  - MOJ Ref: \(formData.mojReference.isEmpty ? "(not found)" : formData.mojReference)")
    }

    // MARK: - Filter Leave Report to Last 2 Years (matching Desktop logic)
    private func filterLeaveReportToLastTwoYears() {
        guard !formData.leaveReportImportedEntries.isEmpty else { return }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"
        dateFormatter.locale = Locale(identifier: "en_GB")

        // Find the most recent date in the entries
        var mostRecentDate = Date()
        let validDates = formData.leaveReportImportedEntries.compactMap { $0.date }

        if let maxDate = validDates.max() {
            mostRecentDate = maxDate
        }

        // Calculate 2-year cutoff (730 days)
        let twoYearsCutoff = Calendar.current.date(byAdding: .day, value: -730, to: mostRecentDate) ?? mostRecentDate

        print("[MOJ-LEAVE] 3g: Date range: \(dateFormatter.string(from: twoYearsCutoff)) to \(dateFormatter.string(from: mostRecentDate))")

        let originalCount = formData.leaveReportImportedEntries.count

        // Filter entries to last 2 years
        formData.leaveReportImportedEntries = formData.leaveReportImportedEntries.filter { entry in
            guard let entryDate = entry.date else {
                return true // Keep entries with no date
            }
            return entryDate >= twoYearsCutoff
        }

        let filteredCount = formData.leaveReportImportedEntries.count
        print("[MOJ-LEAVE] 3g: Filtered leave entries from \(originalCount) to \(filteredCount) (last 2 years)")
    }

    private func applyAutoLeaveDefaults(_ leaveType: ImportLeaveType) {
        // Check if leave type is already set - if so, don't override existing settings
        let hasExistingLeaveType = formData.escortedDay || formData.escortedOvernight ||
                                   formData.unescortedDay || formData.unescortedOvernight ||
                                   formData.compassionateDay || formData.compassionateOvernight

        if hasExistingLeaveType {
            print("[MOJ-LEAVE] Leave type already set, preserving existing 3g settings")
            return
        }

        // Reset all leave type checkboxes first
        formData.escortedDay = false
        formData.escortedOvernight = false
        formData.unescortedDay = false
        formData.unescortedOvernight = false
        formData.compassionateDay = false
        formData.compassionateOvernight = false

        // Set the selected leave type checkbox
        switch leaveType {
        case .escortedDay:
            formData.escortedDay = true
            formData.purposeType = "starting"
            formData.locationGround = true
            formData.locationLocal = true
            formData.dischargePlanningStatus = 0
            formData.overnightApplicable = "na"
            formData.escortedOvernightApplicable = "na"
            formData.compassionateApplicable = "na"

        case .escortedOvernight:
            formData.escortedOvernight = true
            formData.purposeType = "continuing"
            formData.locationCommunity = true
            formData.dischargePlanningStatus = 2
            formData.overnightApplicable = "na"
            formData.escortedOvernightApplicable = "yes"
            formData.escortedCapacity = "yes"
            formData.escortedInitialTesting = "yes"
            formData.compassionateApplicable = "na"

        case .unescortedDay:
            formData.unescortedDay = true
            formData.purposeType = "unescorted"
            formData.locationGround = true
            formData.locationLocal = true
            formData.locationCommunity = true
            formData.dischargePlanningStatus = 2
            formData.overnightApplicable = "na"
            formData.escortedOvernightApplicable = "na"
            formData.compassionateApplicable = "na"

        case .unescortedOvernight:
            formData.unescortedOvernight = true
            formData.purposeType = "rehabilitation"
            formData.locationCommunity = true
            formData.dischargePlanningStatus = 4
            formData.overnightApplicable = "yes"
            formData.overnightAccommodationType = "24hr_supported"
            formData.overnightPriorToRecall = "yes"
            formData.overnightLinkedToIndex = "no"
            formData.escortedOvernightApplicable = "na"
            formData.compassionateApplicable = "na"

        case .compassionateDay:
            formData.compassionateDay = true
            formData.purposeType = "starting"
            formData.locationCommunity = true
            formData.dischargePlanningStatus = 0
            formData.overnightApplicable = "na"
            formData.escortedOvernightApplicable = "na"
            formData.compassionateApplicable = "yes"
            formData.compassionateVirtualVisit = "no"
            formData.compassionateUrgent = "yes"

        case .compassionateOvernight:
            formData.compassionateOvernight = true
            formData.purposeType = "continuing"
            formData.locationCommunity = true
            formData.dischargePlanningStatus = 0
            formData.overnightApplicable = "na"
            formData.escortedOvernightApplicable = "yes"
            formData.compassionateApplicable = "yes"
            formData.compassionateVirtualVisit = "no"
            formData.compassionateUrgent = "yes"
        }

        // Apply common defaults for 3b Documents
        formData.docsCPAMinutes = true
        formData.docsPsychologyReports = true
        formData.docsHCR20 = true
        formData.docsPreviousReports = true
        formData.docsCurrentReports = true
        formData.docsPreviousNotes = true
        formData.docsCurrentNotes = true

        // Exclusion zone default to N/A
        formData.exclusionZone = "na"

        // =====================================================
        // Apply 3g Leave Report defaults directly
        // =====================================================
        formData.escortedLeave.suspended = false
        formData.escortedLeave.suspensionDetails = ""
        formData.unescortedLeave.suspended = false
        formData.unescortedLeave.suspensionDetails = ""

        switch leaveType {
        case .escortedDay:
            // Empty/no leave taken yet - reset both
            formData.escortedLeave = ASRLeaveState()
            formData.unescortedLeave = ASRLeaveState()

        case .escortedOvernight:
            // Escorted: 3 leaves weekly, 2hrs, Ground/Local/Community at 33% each
            formData.escortedLeave.leavesPerPeriod = 3
            formData.escortedLeave.frequency = "Weekly"
            formData.escortedLeave.duration = "2 hours"
            formData.escortedLeave.ground = ASRLeaveTypeWeight(enabled: true, weight: 33)
            formData.escortedLeave.local = ASRLeaveTypeWeight(enabled: true, weight: 33)
            formData.escortedLeave.community = ASRLeaveTypeWeight(enabled: true, weight: 34)
            formData.escortedLeave.extended = ASRLeaveTypeWeight(enabled: false, weight: 0)
            formData.escortedLeave.overnight = ASRLeaveTypeWeight(enabled: false, weight: 0)
            formData.escortedLeave.suspended = false
            formData.unescortedLeave = ASRLeaveState()

        case .unescortedDay:
            // Same escorted defaults as escorted_overnight
            formData.escortedLeave.leavesPerPeriod = 3
            formData.escortedLeave.frequency = "Weekly"
            formData.escortedLeave.duration = "2 hours"
            formData.escortedLeave.ground = ASRLeaveTypeWeight(enabled: true, weight: 33)
            formData.escortedLeave.local = ASRLeaveTypeWeight(enabled: true, weight: 33)
            formData.escortedLeave.community = ASRLeaveTypeWeight(enabled: true, weight: 34)
            formData.escortedLeave.extended = ASRLeaveTypeWeight(enabled: false, weight: 0)
            formData.escortedLeave.overnight = ASRLeaveTypeWeight(enabled: false, weight: 0)
            formData.escortedLeave.suspended = false
            formData.unescortedLeave = ASRLeaveState()

        case .unescortedOvernight:
            // Escorted defaults
            formData.escortedLeave.leavesPerPeriod = 3
            formData.escortedLeave.frequency = "Weekly"
            formData.escortedLeave.duration = "2 hours"
            formData.escortedLeave.ground = ASRLeaveTypeWeight(enabled: true, weight: 33)
            formData.escortedLeave.local = ASRLeaveTypeWeight(enabled: true, weight: 33)
            formData.escortedLeave.community = ASRLeaveTypeWeight(enabled: true, weight: 34)
            formData.escortedLeave.extended = ASRLeaveTypeWeight(enabled: false, weight: 0)
            formData.escortedLeave.overnight = ASRLeaveTypeWeight(enabled: false, weight: 0)
            formData.escortedLeave.suspended = false
            // Unescorted: Ground 11%, Local 36%, Community 53%
            formData.unescortedLeave.leavesPerPeriod = 3
            formData.unescortedLeave.frequency = "Weekly"
            formData.unescortedLeave.duration = "2 hours"
            formData.unescortedLeave.ground = ASRLeaveTypeWeight(enabled: true, weight: 11)
            formData.unescortedLeave.local = ASRLeaveTypeWeight(enabled: true, weight: 36)
            formData.unescortedLeave.community = ASRLeaveTypeWeight(enabled: true, weight: 53)
            formData.unescortedLeave.extended = ASRLeaveTypeWeight(enabled: false, weight: 0)
            formData.unescortedLeave.overnight = ASRLeaveTypeWeight(enabled: false, weight: 0)
            formData.unescortedLeave.suspended = false

        case .compassionateDay, .compassionateOvernight:
            // Clear all leave (no previous leave)
            formData.escortedLeave = ASRLeaveState()
            formData.unescortedLeave = ASRLeaveState()
        }

        // =====================================================
        // Apply 3h Proposed Management defaults directly
        // =====================================================
        // Exclusion zone N/A
        formData.proceduresExclusionZone = "na"
        formData.proceduresExclusionDetails = ""

        // All pre-leave checkboxes checked
        formData.proceduresRiskFree = true
        formData.proceduresMentalState = true
        formData.proceduresEscortsConfirmed = true
        formData.proceduresNoDrugs = true
        formData.proceduresTimings = true

        // All on-return checkboxes checked
        formData.proceduresSearch = true
        formData.proceduresDrugTesting = true
        formData.proceduresBreachSuspension = true
        formData.proceduresBreachInformMOJ = true

        // Specific to patient checked
        formData.proceduresSpecificToPatient = true

        // Set escorts and transport based on leave type
        switch leaveType {
        case .escortedDay:
            formData.proceduresEscorts = "2"
            formData.proceduresTransportHospital = true
        case .escortedOvernight:
            formData.proceduresEscorts = "2"
            formData.proceduresTransportHospital = true
        case .unescortedDay:
            formData.proceduresEscorts = ""
            formData.proceduresTransportPublic = true
        case .unescortedOvernight:
            formData.proceduresEscorts = ""
            formData.proceduresTransportPublic = true
        case .compassionateDay:
            formData.proceduresEscorts = "2"
            formData.proceduresTransportSecure = true
        case .compassionateOvernight:
            formData.proceduresEscorts = "2"
            formData.proceduresTransportSecure = true
        }

        print("[MOJ-LEAVE] Applied 3g and 3h defaults for: \(leaveType.rawValue)")
    }

    private func syncCardTextsToFormData() {
        func combinedText(for section: LeaveSection) -> String {
            let generated = generatedTexts[section] ?? ""
            let manual = manualNotes[section] ?? ""
            if generated.isEmpty && manual.isEmpty { return "" }
            if generated.isEmpty { return manual }
            if manual.isEmpty { return generated }
            return generated + "\n\n" + manual
        }

        formData.purposeText = combinedText(for: .purpose)
        formData.overnightText = combinedText(for: .overnight)
        formData.escortedOvernightText = combinedText(for: .escortedOvernight)
        formData.compassionateText = combinedText(for: .compassionate)
        formData.leaveReportText = combinedText(for: .leaveReport)
        formData.proceduresText = combinedText(for: .procedures)
        formData.hospitalAdmissionsText = combinedText(for: .hospitalAdmissions)
        formData.indexOffenceText = combinedText(for: .indexOffence)
        formData.mentalDisorderText = combinedText(for: .mentalDisorder)
        formData.attitudeBehaviourText = combinedText(for: .attitudeBehaviour)
        formData.riskFactorsText = combinedText(for: .riskFactors)
        formData.medicationText = combinedText(for: .medication)
        formData.psychologyText = combinedText(for: .psychology)
        formData.extremismText = combinedText(for: .extremism)
        formData.abscondingText = combinedText(for: .absconding)
        formData.mappaNotesText = combinedText(for: .mappa)
        formData.fitnessToPlead = combinedText(for: .fitnessToPlead)
        formData.additionalCommentsText = combinedText(for: .additionalComments)
    }
}

// MARK: - Editable Card
struct LeaveEditableCard: View {
    let section: MOJLeaveFormView.LeaveSection
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
            LeaveResizeHandle(height: $editorHeight)
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
struct LeaveResizeHandle: View {
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
struct LeavePopupView: View {
    let section: MOJLeaveFormView.LeaveSection
    @Binding var formData: MOJLeaveFormData
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
        case .rcDetails: rcDetailsPopup
        case .leaveType: leaveTypePopup
        case .documents: documentsPopup
        case .purpose: purposePopup
        case .overnight: overnightPopup
        case .escortedOvernight: escortedOvernightPopup
        case .compassionate: compassionatePopup
        case .leaveReport: leaveReportPopup
        case .procedures: proceduresPopup
        case .hospitalAdmissions: hospitalAdmissionsPopup
        case .indexOffence: indexOffencePopup
        case .mentalDisorder: mentalDisorderPopup
        case .attitudeBehaviour: attitudeBehaviourPopup
        case .riskFactors: riskFactorsPopup
        case .medication: medicationPopup
        case .psychology: psychologyPopup
        case .extremism: extremismPopup
        case .absconding: abscondingPopup
        case .mappa: mappaPopup
        case .victims: victimsPopup
        case .transferredPrisoners: transferredPrisonersPopup
        case .fitnessToPlead: fitnessToPlead
        case .additionalComments: additionalCommentsPopup
        case .signature: signaturePopup
        }
    }

    private func generateText() -> String {
        switch section {
        case .patientDetails: return generatePatientDetailsText()
        case .rcDetails: return generateRCDetailsText()
        case .leaveType: return formData.leaveTypeText()
        case .documents: return formData.documentsReviewedText()
        case .purpose: return generatePurposeText()
        case .overnight: return generateOvernightText()
        case .escortedOvernight: return generateEscortedOvernightText()
        case .compassionate: return generateCompassionateText()
        case .leaveReport: return generateLeaveReportText()
        case .procedures: return generateProceduresText()
        case .hospitalAdmissions: return formData.appendImportedNotes(formData.hospitalAdmissionsImportedEntries, to: formData.hospitalAdmissionsText)
        case .indexOffence: return formData.appendImportedNotes(formData.indexOffenceImportedEntries, to: formData.indexOffenceText)
        case .mentalDisorder: return generateMentalDisorderText()
        case .attitudeBehaviour: return generateAttitudeBehaviourText()
        case .riskFactors: return generateRiskFactorsText()
        case .medication: return generateMedicationText()
        case .psychology: return generatePsychologyText()
        case .extremism: return generateExtremismText()
        case .absconding: return generateAbscondingText()
        case .mappa: return generateMAPPAText()
        case .victims: return generateVictimsText()
        case .transferredPrisoners: return generatePrisonersText()
        case .fitnessToPlead: return generateFitnessToPlead()
        case .additionalComments: return generateAdditionalCommentsText()
        case .signature: return generateSignatureText()
        }
    }

    // MARK: - Popup Content Views

    private var patientDetailsPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            FormTextField(label: "Patient Name", text: $formData.patientName, isRequired: true)
            FormOptionalDatePicker(label: "Date of Birth", date: $formData.patientDOB,
                                   maxDate: Calendar.current.date(byAdding: .year, value: -18, to: Date()),
                                   minDate: Calendar.current.date(byAdding: .year, value: -100, to: Date()),
                                   defaultDate: Calendar.current.date(byAdding: .year, value: -18, to: Date()))

            FormSectionHeader(title: "Gender", systemImage: "person")
            Picker("Gender", selection: $formData.patientGender) {
                ForEach(Gender.allCases) { gender in
                    Text(gender.rawValue).tag(gender)
                }
            }
            .pickerStyle(.segmented)

            FormDivider()

            FormTextField(label: "Hospital Number", text: $formData.hospitalNumber)
            FormTextField(label: "Hospital Name", text: $formData.hospitalName)
            FormTextField(label: "Ward", text: $formData.wardName)

            FormDivider()

            FormSectionHeader(title: "MHA Section", systemImage: "building.columns")
            Picker("MHA Section", selection: $formData.mhaSection) {
                Text("37/41").tag("37/41")
                Text("47/49").tag("47/49")
                Text("48/49").tag("48/49")
                Text("45A").tag("45A")
                Text("Other").tag("Other")
            }
            .pickerStyle(.menu)

            FormTextField(label: "MOJ Reference", text: $formData.mojReference, placeholder: "MOJ reference number")
        }
    }

    private var rcDetailsPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            FormTextField(label: "RC Name", text: $formData.rcName, isRequired: true)
            FormTextField(label: "Email", text: $formData.rcEmail, keyboardType: .emailAddress)
            FormTextField(label: "Phone", text: $formData.rcPhone, keyboardType: .phonePad)
        }
    }

    private var leaveTypePopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Helper to determine if a section is disabled
            let compassionateActive = formData.compassionateDay || formData.compassionateOvernight
            let escortedActive = formData.escortedDay || formData.escortedOvernight
            let unescortedActive = formData.unescortedDay || formData.unescortedOvernight

            let compassionateDisabled = escortedActive || unescortedActive
            let escortedDisabled = compassionateActive || unescortedActive
            let unescortedDisabled = compassionateActive || escortedActive

            FormSectionHeader(title: "Compassionate Leave", systemImage: "heart")
            HStack(spacing: 20) {
                Toggle("Day", isOn: $formData.compassionateDay)
                    .disabled(compassionateDisabled && !formData.compassionateDay)
                    .onChange(of: formData.compassionateDay) { _, newValue in
                        if newValue { onLeaveTypeChanged("compassionate_day") }
                    }
                Toggle("Overnight", isOn: $formData.compassionateOvernight)
                    .disabled(compassionateDisabled && !formData.compassionateOvernight)
                    .onChange(of: formData.compassionateOvernight) { _, newValue in
                        if newValue { onLeaveTypeChanged("compassionate_overnight") }
                    }
            }
            .toggleStyle(CheckboxToggleStyle())
            .opacity(compassionateDisabled ? 0.5 : 1.0)

            FormDivider()

            FormSectionHeader(title: "Escorted Community", systemImage: "person.2")
            HStack(spacing: 20) {
                Toggle("Day", isOn: $formData.escortedDay)
                    .disabled(escortedDisabled && !formData.escortedDay)
                    .onChange(of: formData.escortedDay) { _, newValue in
                        if newValue { onLeaveTypeChanged("escorted_day") }
                    }
                Toggle("Overnight", isOn: $formData.escortedOvernight)
                    .disabled(escortedDisabled && !formData.escortedOvernight)
                    .onChange(of: formData.escortedOvernight) { _, newValue in
                        if newValue { onLeaveTypeChanged("escorted_overnight") }
                    }
            }
            .toggleStyle(CheckboxToggleStyle())
            .opacity(escortedDisabled ? 0.5 : 1.0)

            FormDivider()

            FormSectionHeader(title: "Unescorted Community", systemImage: "figure.walk")
            HStack(spacing: 20) {
                Toggle("Day", isOn: $formData.unescortedDay)
                    .disabled(unescortedDisabled && !formData.unescortedDay)
                    .onChange(of: formData.unescortedDay) { _, newValue in
                        if newValue { onLeaveTypeChanged("unescorted_day") }
                    }
                Toggle("Overnight", isOn: $formData.unescortedOvernight)
                    .disabled(unescortedDisabled && !formData.unescortedOvernight)
                    .onChange(of: formData.unescortedOvernight) { _, newValue in
                        if newValue { onLeaveTypeChanged("unescorted_overnight") }
                    }
            }
            .toggleStyle(CheckboxToggleStyle())
            .opacity(unescortedDisabled ? 0.5 : 1.0)

            // Info box showing which sections will be auto-filled
            if compassionateActive || escortedActive || unescortedActive {
                FormDivider()
                InfoBox(
                    text: "Selecting a leave type auto-fills sections 3c-3g with defaults. Tap Generate to apply.",
                    icon: "info.circle",
                    color: .blue
                )
            }
        }
    }

    private var documentsPopup: some View {
        VStack(alignment: .leading, spacing: 12) {
            FormSectionHeader(title: "Documents Reviewed", systemImage: "doc.text")

            Toggle("CPA Minutes", isOn: $formData.docsCPAMinutes)
            Toggle("Psychology Reports", isOn: $formData.docsPsychologyReports)
            Toggle("HCR-20", isOn: $formData.docsHCR20)
            Toggle("SARA", isOn: $formData.docsSARA)
            Toggle("Other Risk Assessment Tools", isOn: $formData.docsOtherRiskTools)
            Toggle("Previous Reports", isOn: $formData.docsPreviousReports)
            Toggle("Current Reports", isOn: $formData.docsCurrentReports)
            Toggle("Previous Notes", isOn: $formData.docsPreviousNotes)
            Toggle("Current Notes", isOn: $formData.docsCurrentNotes)

            FormDivider()

            FormTextField(label: "Other Documents", text: $formData.docsOther, placeholder: "Specify other documents...")

            HStack {
                Button("Select All") {
                    formData.docsCPAMinutes = true
                    formData.docsPsychologyReports = true
                    formData.docsHCR20 = true
                    formData.docsSARA = true
                    formData.docsOtherRiskTools = true
                    formData.docsPreviousReports = true
                    formData.docsCurrentReports = true
                    formData.docsPreviousNotes = true
                    formData.docsCurrentNotes = true
                }
                .buttonStyle(.bordered)

                Button("Deselect All") {
                    formData.docsCPAMinutes = false
                    formData.docsPsychologyReports = false
                    formData.docsHCR20 = false
                    formData.docsSARA = false
                    formData.docsOtherRiskTools = false
                    formData.docsPreviousReports = false
                    formData.docsCurrentReports = false
                    formData.docsPreviousNotes = false
                    formData.docsCurrentNotes = false
                }
                .buttonStyle(.bordered)
            }
        }
        .toggleStyle(CheckboxToggleStyle())
    }

    // MARK: - Section 3c: Purpose of Leave (structured matching Desktop)
    private var purposePopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 1. Purpose of Leave
            FormSectionHeader(title: "1. Purpose of Leave (therapeutic benefit)", systemImage: "target")
            VStack(alignment: .leading, spacing: 8) {
                ForEach([("starting", "Starting meaningful testing"),
                         ("continuing", "Continuing previous leave"),
                         ("unescorted", "Move to unescorted leave"),
                         ("rehabilitation", "Rehabilitation process")], id: \.0) { key, label in
                    Button(action: { formData.purposeType = key }) {
                        HStack {
                            Image(systemName: formData.purposeType == key ? "largecircle.fill.circle" : "circle")
                                .foregroundColor(formData.purposeType == key ? .blue : .gray)
                            Text(label).foregroundColor(.primary)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            FormDivider()

            // 2. Location of Leave
            FormSectionHeader(title: "2. Location of Leave", systemImage: "mappin.and.ellipse")
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Ground (hospital grounds)", isOn: $formData.locationGround)
                Toggle("Local (nearby area)", isOn: $formData.locationLocal)
                Toggle("Community (wider area)", isOn: $formData.locationCommunity)
                Toggle("Family (visit family home)", isOn: $formData.locationFamily)
            }
            .toggleStyle(CheckboxToggleStyle())

            // Exclusion zone
            Text("Proximity to exclusion zone:").font(.subheadline).foregroundColor(.secondary)
            Picker("Exclusion Zone", selection: $formData.exclusionZone) {
                Text("Select...").tag("")
                Text("Yes").tag("yes")
                Text("No").tag("no")
                Text("N/A").tag("na")
            }
            .pickerStyle(.segmented)

            FormDivider()

            // 3. Discharge Planning Status
            FormSectionHeader(title: "3. Discharge Planning Status", systemImage: "list.clipboard")
            let dischargeOptions = ["Not started", "Early stages", "In progress", "Almost completed", "Completed"]
            Text(dischargeOptions[formData.dischargePlanningStatus])
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.red)
            Slider(value: Binding(
                get: { Double(formData.dischargePlanningStatus) },
                set: { formData.dischargePlanningStatus = Int($0) }
            ), in: 0...4, step: 1)

            FormDivider()

            // Additional text
            FormTextEditor(
                label: "Additional Purpose Details",
                text: $formData.purposeText,
                placeholder: "Any additional details about the purpose of leave...",
                minHeight: 80
            )
        }
    }

    // MARK: - Section 3d: Unescorted Overnight Leave (structured matching Desktop)
    private var overnightPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Main toggle
            FormSectionHeader(title: "Unescorted Overnight Leave", systemImage: "moon.stars")
            Picker("Applicable", selection: $formData.overnightApplicable) {
                Text("Select...").tag("")
                Text("Yes").tag("yes")
                Text("N/A").tag("na")
            }
            .pickerStyle(.segmented)

            if formData.overnightApplicable == "yes" {
                FormDivider()

                // Accommodation type
                Text("Accommodation Type:").font(.subheadline.weight(.semibold))
                VStack(alignment: .leading, spacing: 8) {
                    ForEach([("24hr_supported", "24hr Supported Accommodation"),
                             ("9to5_supported", "9-5 Supported Accommodation"),
                             ("independent", "Independent Accommodation"),
                             ("family", "Family Home")], id: \.0) { key, label in
                        Button(action: { formData.overnightAccommodationType = key }) {
                            HStack {
                                Image(systemName: formData.overnightAccommodationType == key ? "largecircle.fill.circle" : "circle")
                                    .foregroundColor(formData.overnightAccommodationType == key ? .blue : .gray)
                                Text(label).foregroundColor(.primary)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                FormTextField(label: "Address", text: $formData.overnightAddress, placeholder: "Enter accommodation address...")

                FormDivider()

                // Prior to recall
                Text("Prior to recall:").font(.subheadline).foregroundColor(.secondary)
                Picker("Prior to Recall", selection: $formData.overnightPriorToRecall) {
                    Text("Select...").tag("")
                    Text("Yes").tag("yes")
                    Text("No").tag("no")
                }
                .pickerStyle(.segmented)

                // Linked to index offence
                Text("Linked to index offence:").font(.subheadline).foregroundColor(.secondary)
                Picker("Linked to Index", selection: $formData.overnightLinkedToIndex) {
                    Text("Select...").tag("")
                    Text("Yes").tag("yes")
                    Text("No").tag("no")
                }
                .pickerStyle(.segmented)

                FormDivider()

                // Support
                Text("Support available:").font(.subheadline.weight(.semibold))
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Staff support", isOn: $formData.overnightSupportStaff)
                    Toggle("CMHT support", isOn: $formData.overnightSupportCMHT)
                    Toggle("Inpatient support", isOn: $formData.overnightSupportInpatient)
                    Toggle("Family support", isOn: $formData.overnightSupportFamily)
                }
                .toggleStyle(CheckboxToggleStyle())

                // Number of nights
                Stepper("Nights per week: \(formData.overnightNightsPerWeek)", value: $formData.overnightNightsPerWeek, in: 0...7)

                FormDivider()

                // Discharge to address
                Text("Discharge to proposed address:").font(.subheadline).foregroundColor(.secondary)
                Picker("Discharge to Address", selection: $formData.overnightDischargeToAddress) {
                    Text("Select...").tag("")
                    Text("Yes").tag("yes")
                    Text("No").tag("no")
                }
                .pickerStyle(.segmented)
            }

            FormDivider()

            FormTextEditor(
                label: "Additional Details",
                text: $formData.overnightText,
                placeholder: "Any additional details...",
                minHeight: 60
            )
        }
    }

    // MARK: - Section 3e: Escorted Overnight Leave (structured matching Desktop)
    private var escortedOvernightPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Main toggle
            FormSectionHeader(title: "Escorted Overnight Leave", systemImage: "moon.fill")
            Picker("Applicable", selection: $formData.escortedOvernightApplicable) {
                Text("Select...").tag("")
                Text("Yes").tag("yes")
                Text("N/A").tag("na")
            }
            .pickerStyle(.segmented)

            if formData.escortedOvernightApplicable == "yes" {
                FormDivider()

                // Capacity for residence/leave
                Text("Capacity for residence/leave:").font(.subheadline.weight(.semibold))
                Picker("Capacity", selection: $formData.escortedCapacity) {
                    Text("Select...").tag("")
                    Text("Yes").tag("yes")
                    Text("No").tag("no")
                }
                .pickerStyle(.segmented)

                // Conditional on capacity
                if formData.escortedCapacity == "no" {
                    Text("DoLS plan in place:").font(.subheadline).foregroundColor(.secondary)
                    Picker("DoLS Plan", selection: $formData.escortedDoLSPlan) {
                        Text("Select...").tag("")
                        Text("Yes").tag("yes")
                        Text("No").tag("no")
                    }
                    .pickerStyle(.segmented)
                }

                if formData.escortedCapacity == "yes" {
                    Text("Initial testing:").font(.subheadline).foregroundColor(.secondary)
                    Picker("Initial Testing", selection: $formData.escortedInitialTesting) {
                        Text("Select...").tag("")
                        Text("Yes").tag("yes")
                        Text("No").tag("no")
                    }
                    .pickerStyle(.segmented)
                }

                FormDivider()

                // Discharge plan
                Text("Discharge plan includes:").font(.subheadline.weight(.semibold))
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("DoLS arrangement", isOn: $formData.escortedDischargePlanDoLS)
                    Toggle("Move to unescorted", isOn: $formData.escortedDischargePlanUnescorted)
                    Toggle("Initial testing", isOn: $formData.escortedDischargePlanInitialTesting)
                }
                .toggleStyle(CheckboxToggleStyle())
            }

            FormDivider()

            FormTextEditor(
                label: "Additional Details",
                text: $formData.escortedOvernightText,
                placeholder: "Any additional details...",
                minHeight: 60
            )
        }
    }

    // MARK: - Section 3f: Compassionate Leave (structured matching Desktop)
    private var compassionatePopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Main toggle
            FormSectionHeader(title: "Compassionate Leave", systemImage: "heart")
            Picker("Applicable", selection: $formData.compassionateApplicable) {
                Text("Select...").tag("")
                Text("Yes").tag("yes")
                Text("N/A").tag("na")
            }
            .pickerStyle(.segmented)

            if formData.compassionateApplicable == "yes" {
                FormDivider()

                // Virtual visit
                Text("Virtual visit:").font(.subheadline).foregroundColor(.secondary)
                Picker("Virtual Visit", selection: $formData.compassionateVirtualVisit) {
                    Text("Select...").tag("")
                    Text("Yes").tag("yes")
                    Text("No").tag("no")
                }
                .pickerStyle(.segmented)

                // Urgent
                Text("Urgent:").font(.subheadline).foregroundColor(.secondary)
                Picker("Urgent", selection: $formData.compassionateUrgent) {
                    Text("Select...").tag("")
                    Text("Yes").tag("yes")
                    Text("No").tag("no")
                }
                .pickerStyle(.segmented)
            }

            FormDivider()

            FormTextEditor(
                label: "Compassionate Leave Details",
                text: $formData.compassionateText,
                placeholder: "Provide details about the reason for compassionate leave...",
                minHeight: 80
            )
        }
    }

    // MARK: - Section 3g: Leave Report (using LeaveReportSection with sliders like ASR)
    private var leaveReportPopup: some View {
        VStack(alignment: .leading, spacing: 12) {
            LeaveReportSection(escortedLeave: $formData.escortedLeave, unescortedLeave: $formData.unescortedLeave)

            // Imported Data Section
            if !formData.leaveReportImportedEntries.isEmpty {
                FormDivider()
                ImportedDataSection(
                    title: "Imported Data",
                    entries: $formData.leaveReportImportedEntries,
                    categoryKeywords: LeaveFormCategoryKeywords.leaveReport
                )
            }
        }
    }

    private var proceduresPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            // === Section 1: Escorts / Transport ===
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 12) {
                    // Escorts
                    HStack {
                        Text("Escorts:").font(.subheadline)
                        Picker("Escorts", selection: $formData.proceduresEscorts) {
                            Text("Select...").tag("")
                            Text("1").tag("1")
                            Text("2").tag("2")
                            Text("3").tag("3")
                        }
                        .pickerStyle(.menu)
                        Spacer()
                    }

                    // Transport
                    Text("Transport:").font(.subheadline)
                    HStack(spacing: 16) {
                        Toggle("Secure", isOn: $formData.proceduresTransportSecure)
                        Toggle("Hospital", isOn: $formData.proceduresTransportHospital)
                        Toggle("Taxi", isOn: $formData.proceduresTransportTaxi)
                        Toggle("Public", isOn: $formData.proceduresTransportPublic)
                    }
                    .toggleStyle(CheckboxToggleStyle())
                    .font(.caption)

                    // Handcuffs
                    Toggle("Handcuffs to be carried", isOn: $formData.proceduresHandcuffs)
                        .toggleStyle(CheckboxToggleStyle())

                    // Exclusion Zone
                    HStack {
                        Text("Exclusion Zone:").font(.subheadline)
                        Picker("Exclusion", selection: $formData.proceduresExclusionZone) {
                            Text("N/A").tag("na")
                            Text("Yes").tag("yes")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 120)
                        Spacer()
                    }

                    if formData.proceduresExclusionZone == "yes" {
                        TextField("Exclusion zone details...", text: $formData.proceduresExclusionDetails)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .padding(.leading, 8)
            } label: {
                Label("Escorts / Transport", systemImage: "car.fill")
                    .font(.headline)
                    .foregroundColor(.primary)
            }

            FormDivider()

            // === Section 2: Public Protection - Pre-leave ===
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Risk free > 24 hours", isOn: $formData.proceduresRiskFree)
                    Toggle("Mental state assessment prior to leave", isOn: $formData.proceduresMentalState)
                    Toggle("Escorts confirmed as known to patient", isOn: $formData.proceduresEscortsConfirmed)
                    Toggle("No permission for drug and alcohol use", isOn: $formData.proceduresNoDrugs)
                    Toggle("Timings monitored", isOn: $formData.proceduresTimings)

                    HStack(spacing: 12) {
                        Button("Select All") {
                            formData.proceduresRiskFree = true
                            formData.proceduresMentalState = true
                            formData.proceduresEscortsConfirmed = true
                            formData.proceduresNoDrugs = true
                            formData.proceduresTimings = true
                        }
                        .buttonStyle(.borderedProminent)
                        .font(.caption)

                        Button("Deselect All") {
                            formData.proceduresRiskFree = false
                            formData.proceduresMentalState = false
                            formData.proceduresEscortsConfirmed = false
                            formData.proceduresNoDrugs = false
                            formData.proceduresTimings = false
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                    }
                    .padding(.top, 4)
                }
                .toggleStyle(CheckboxToggleStyle())
                .padding(.leading, 8)
            } label: {
                Label("Public Protection - Pre-leave", systemImage: "shield.lefthalf.filled")
                    .font(.headline)
                    .foregroundColor(.primary)
            }

            FormDivider()

            // === Section 3: Public Protection - On Return ===
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Search", isOn: $formData.proceduresSearch)
                    Toggle("Drug testing", isOn: $formData.proceduresDrugTesting)

                    Text("Breaches:").font(.subheadline).foregroundColor(.secondary).padding(.top, 4)
                    Toggle("Suspension of leave", isOn: $formData.proceduresBreachSuspension)
                    Toggle("Inform MOJ", isOn: $formData.proceduresBreachInformMOJ)

                    HStack(spacing: 12) {
                        Button("Select All") {
                            formData.proceduresSearch = true
                            formData.proceduresDrugTesting = true
                            formData.proceduresBreachSuspension = true
                            formData.proceduresBreachInformMOJ = true
                        }
                        .buttonStyle(.borderedProminent)
                        .font(.caption)

                        Button("Deselect All") {
                            formData.proceduresSearch = false
                            formData.proceduresDrugTesting = false
                            formData.proceduresBreachSuspension = false
                            formData.proceduresBreachInformMOJ = false
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                    }
                    .padding(.top, 4)

                    FormDivider()

                    Toggle("I confirm measures are specific to this patient", isOn: $formData.proceduresSpecificToPatient)
                        .font(.subheadline.weight(.medium))
                }
                .toggleStyle(CheckboxToggleStyle())
                .padding(.leading, 8)
            } label: {
                Label("Public Protection - On Return", systemImage: "arrow.uturn.backward.circle.fill")
                    .font(.headline)
                    .foregroundColor(.primary)
            }

        }
    }

    private var hospitalAdmissionsPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            FormTextEditor(
                label: "Past Psychiatric History / Hospital Admissions",
                text: $formData.hospitalAdmissionsText,
                placeholder: "Summarize the patient's psychiatric history and previous hospital admissions...",
                minHeight: 200
            )

            if !formData.hospitalAdmissionsImportedEntries.isEmpty {
                ImportedDataSection(
                    title: "Imported Data",
                    entries: $formData.hospitalAdmissionsImportedEntries,
                    categoryKeywords: LeaveFormCategoryKeywords.hospitalAdmissions
                )
            }
        }
    }

    private var indexOffencePopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            FormTextEditor(
                label: "Index Offence and Forensic History",
                text: $formData.indexOffenceText,
                placeholder: "Describe the index offence and forensic history...",
                minHeight: 200
            )

            if !formData.indexOffenceImportedEntries.isEmpty {
                ImportedDataSection(
                    title: "Imported Data",
                    entries: $formData.indexOffenceImportedEntries,
                    categoryKeywords: LeaveFormCategoryKeywords.indexOffence
                )
            }
        }
    }

    private var mentalDisorderPopup: some View {
        let mentalStateOptions = ["Stable", "Minor", "Moderate", "Significant", "Severe"]
        let insightOptions = ["Nil", "Some", "Partial", "Moderate", "Good", "Full"]
        let observationOptions = ["", "General", "Once/day & night", "Twice/day & night", "3 hourly", "2 hourly", "Hourly", "2x/hour", "3x/hour", "4x/hour", "1:1 eyesight", "1:1 arms length", "2:1", "3:1", "4:1"]
        let physImpactOptions = ["Minimal", "Mild", "Some", "Moderate", "Significant", "High"]

        return VStack(alignment: .leading, spacing: 16) {
            // ICD-10 Diagnoses
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 12) {
                    ICD10DiagnosisPicker(label: "Primary Diagnosis", selectedDiagnosis: $formData.mdDiagnosis1, customDiagnosis: .constant(""))
                    ICD10DiagnosisPicker(label: "Secondary Diagnosis", selectedDiagnosis: $formData.mdDiagnosis2, customDiagnosis: .constant(""))
                    ICD10DiagnosisPicker(label: "Tertiary Diagnosis", selectedDiagnosis: $formData.mdDiagnosis3, customDiagnosis: .constant(""))

                    FormTextEditor(
                        label: "Clinical Description",
                        text: $formData.mdClinicalDescription,
                        placeholder: "Additional clinical details...",
                        minHeight: 60
                    )
                }
                .padding(.leading, 8)
            } label: {
                Label("ICD-10 Diagnoses", systemImage: "list.clipboard")
                    .font(.headline)
                    .foregroundColor(.red)
            }

            FormDivider()

            // 1. Exacerbating Factors
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 8) {
                    LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 8) {
                        Toggle("Alcohol", isOn: $formData.mdExacAlcohol)
                            .toggleStyle(CheckboxToggleStyle())
                            .font(.caption)
                        Toggle("Substance misuse", isOn: $formData.mdExacSubstance)
                            .toggleStyle(CheckboxToggleStyle())
                            .font(.caption)
                        Toggle("Non-compliance", isOn: $formData.mdExacNonCompliance)
                            .toggleStyle(CheckboxToggleStyle())
                            .font(.caption)
                        Toggle("Financial", isOn: $formData.mdExacFinancial)
                            .toggleStyle(CheckboxToggleStyle())
                            .font(.caption)
                        Toggle("Personal relationships", isOn: $formData.mdExacPersonalRelationships)
                            .toggleStyle(CheckboxToggleStyle())
                            .font(.caption)
                        Toggle("Family stress", isOn: $formData.mdExacFamilyStress)
                            .toggleStyle(CheckboxToggleStyle())
                            .font(.caption)
                        Toggle("Physical health", isOn: $formData.mdExacPhysicalHealth)
                            .toggleStyle(CheckboxToggleStyle())
                            .font(.caption)
                        Toggle("Use of weapons", isOn: $formData.mdExacWeapons)
                            .toggleStyle(CheckboxToggleStyle())
                            .font(.caption)
                    }
                }
                .padding(.leading, 8)
            } label: {
                Label("1. Exacerbating Factors at Time of I/O", systemImage: "exclamationmark.triangle")
                    .font(.headline)
                    .foregroundColor(.red)
            }

            FormDivider()

            // 2. Current Mental State
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 12) {
                    // Mental State Symptoms slider
                    PsychologySlider(
                        label: "Current symptoms level",
                        value: $formData.mdMentalStateLevel,
                        options: mentalStateOptions,
                        color: .red
                    )

                    // Insight slider
                    PsychologySlider(
                        label: "Insight",
                        value: $formData.mdInsightLevel,
                        options: insightOptions,
                        color: .red
                    )
                }
                .padding(.leading, 8)
            } label: {
                Label("2. Current Mental State (Symptoms)", systemImage: "brain.head.profile")
                    .font(.headline)
                    .foregroundColor(.red)
            }

            FormDivider()

            // 3. Current Observations
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Observation Level", selection: $formData.mdObservations) {
                        ForEach(observationOptions, id: \.self) { option in
                            Text(option.isEmpty ? "Select..." : option).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .padding(.leading, 8)
            } label: {
                Label("3. Current Observations", systemImage: "eye")
                    .font(.headline)
                    .foregroundColor(.red)
            }

            FormDivider()

            // 4. Impact of Physical Health Issues
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 12) {
                    // Impact slider
                    PsychologySlider(
                        label: "Impact level",
                        value: $formData.mdPhysicalImpact,
                        options: physImpactOptions,
                        color: .orange
                    )

                    FormDivider()

                    // Physical health conditions by category
                    PhysicalHealthCategory(title: "Cardiac", conditions: ["Diabetes", "Hypertension", "MI", "Arrhythmias", "High cholesterol"], selected: $formData.mdPhysCardiac)
                    PhysicalHealthCategory(title: "Respiratory", conditions: ["Asthma", "COPD", "Bronchitis"], selected: $formData.mdPhysRespiratory)
                    PhysicalHealthCategory(title: "Gastric", conditions: ["Gastric ulcer", "GORD", "IBS"], selected: $formData.mdPhysGastric)
                    PhysicalHealthCategory(title: "Neurological", conditions: ["Multiple sclerosis", "Parkinson's", "Epilepsy"], selected: $formData.mdPhysNeurological)
                    PhysicalHealthCategory(title: "Hepatic", conditions: ["Hepatitis C", "Fatty liver", "ARLD"], selected: $formData.mdPhysHepatic)
                    PhysicalHealthCategory(title: "Renal", conditions: ["CKD", "ESRD"], selected: $formData.mdPhysRenal)
                    PhysicalHealthCategory(title: "Cancer", conditions: ["Lung", "Prostate", "Bladder", "Uterine", "Breast", "Brain", "Kidney"], selected: $formData.mdPhysCancer)
                }
                .padding(.leading, 8)
            } label: {
                Label("4. Impact of Physical Health Issues", systemImage: "heart.text.square")
                    .font(.headline)
                    .foregroundColor(.orange)
            }

            if !formData.mentalDisorderImportedEntries.isEmpty {
                FormDivider()
                ImportedDataSection(
                    title: "Imported Data",
                    entries: $formData.mentalDisorderImportedEntries,
                    categoryKeywords: LeaveFormCategoryKeywords.diagnosisKeywords
                )
            }
        }
    }

    private var attitudeBehaviourPopup: some View {
        let understandingOptions = ["", "Good", "Fair", "Poor"]
        let complianceOptions = ["", "Full", "Reasonable", "Partial", "Nil"]
        let wardRulesOptions = ["", "Compliant", "Mostly compliant", "Partially compliant", "Non-compliant"]
        let conflictOptions = ["", "Avoids", "De-escalates", "Neutral", "Escalates", "Aggressive"]
        let relationshipLabels = ["Limited", "Some", "Good", "Close", "Very good"]

        return VStack(alignment: .leading, spacing: 16) {
            // Treatment Understanding & Compliance
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 12) {
                    // Headers
                    HStack {
                        Text("Treatment").frame(width: 100, alignment: .leading).font(.caption.weight(.semibold))
                        Text("Understanding").frame(width: 100, alignment: .leading).font(.caption.weight(.semibold))
                        Text("Compliance").frame(width: 100, alignment: .leading).font(.caption.weight(.semibold))
                    }

                    TreatmentRow(label: "Medical", understanding: $formData.attMedicalUnderstanding, compliance: $formData.attMedicalCompliance, understandingOptions: understandingOptions, complianceOptions: complianceOptions)
                    TreatmentRow(label: "Nursing", understanding: $formData.attNursingUnderstanding, compliance: $formData.attNursingCompliance, understandingOptions: understandingOptions, complianceOptions: complianceOptions)
                    TreatmentRow(label: "Psychology", understanding: $formData.attPsychologyUnderstanding, compliance: $formData.attPsychologyCompliance, understandingOptions: understandingOptions, complianceOptions: complianceOptions)
                    TreatmentRow(label: "OT", understanding: $formData.attOTUnderstanding, compliance: $formData.attOTCompliance, understandingOptions: understandingOptions, complianceOptions: complianceOptions)
                    TreatmentRow(label: "Social Work", understanding: $formData.attSocialWorkUnderstanding, compliance: $formData.attSocialWorkCompliance, understandingOptions: understandingOptions, complianceOptions: complianceOptions)

                    FormDivider()

                    HStack {
                        Text("Ward Rules:").font(.subheadline)
                        Picker("", selection: $formData.attWardRules) {
                            ForEach(wardRulesOptions, id: \.self) { Text($0.isEmpty ? "Select..." : $0).tag($0) }
                        }.pickerStyle(.menu)
                    }

                    HStack {
                        Text("Conflict Response:").font(.subheadline)
                        Picker("", selection: $formData.attConflictResponse) {
                            ForEach(conflictOptions, id: \.self) { Text($0.isEmpty ? "Select..." : $0).tag($0) }
                        }.pickerStyle(.menu)
                    }
                }
                .padding(.leading, 8)
            } label: {
                Label("Treatment Understanding & Compliance", systemImage: "stethoscope")
                    .font(.headline)
            }

            FormDivider()

            // Relationships
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 12) {
                    RelationshipSlider(label: "Staff", value: $formData.attRelStaff, labels: relationshipLabels)
                    RelationshipSlider(label: "Peers", value: $formData.attRelPeers, labels: relationshipLabels)
                    RelationshipSlider(label: "Family", value: $formData.attRelFamily, labels: relationshipLabels)
                    RelationshipSlider(label: "Friends", value: $formData.attRelFriends, labels: relationshipLabels)
                }
                .padding(.leading, 8)
            } label: {
                Label("Relationships", systemImage: "person.2")
                    .font(.headline)
                    .foregroundColor(.cyan)
            }

            FormDivider()

            // Attitudes to Engagement
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 12) {
                    // OT Groups
                    Text("OT Groups:").font(.subheadline.weight(.semibold))
                    LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 6) {
                        Toggle("Breakfast", isOn: $formData.engOTBreakfast)
                            .toggleStyle(CheckboxToggleStyle()).font(.caption)
                        Toggle("Cooking", isOn: $formData.engOTCooking)
                            .toggleStyle(CheckboxToggleStyle()).font(.caption)
                        Toggle("Current affairs", isOn: $formData.engOTCurrentAffairs)
                            .toggleStyle(CheckboxToggleStyle()).font(.caption)
                        Toggle("Self care", isOn: $formData.engOTSelfCare)
                            .toggleStyle(CheckboxToggleStyle()).font(.caption)
                        Toggle("Music", isOn: $formData.engOTMusic)
                            .toggleStyle(CheckboxToggleStyle()).font(.caption)
                        Toggle("Art", isOn: $formData.engOTArt)
                            .toggleStyle(CheckboxToggleStyle()).font(.caption)
                        Toggle("Gym", isOn: $formData.engOTGym)
                            .toggleStyle(CheckboxToggleStyle()).font(.caption)
                        Toggle("Horticulture", isOn: $formData.engOTHorticulture)
                            .toggleStyle(CheckboxToggleStyle()).font(.caption)
                        Toggle("Woodwork", isOn: $formData.engOTWoodwork)
                            .toggleStyle(CheckboxToggleStyle()).font(.caption)
                        Toggle("Walking", isOn: $formData.engOTWalking)
                            .toggleStyle(CheckboxToggleStyle()).font(.caption)
                    }

                    PsychologySlider(
                        label: "OT Engagement",
                        value: $formData.engOTLevel,
                        options: ["Limited", "Mixed", "Reasonable", "Good", "Very Good", "Excellent"],
                        color: .green
                    )

                    FormDivider()

                    // Psychology
                    Text("Psychology:").font(.subheadline.weight(.semibold))
                    LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 6) {
                        Toggle("1-1", isOn: $formData.engPsych1to1)
                            .toggleStyle(CheckboxToggleStyle()).font(.caption)
                        Toggle("Risk", isOn: $formData.engPsychRisk)
                            .toggleStyle(CheckboxToggleStyle()).font(.caption)
                        Toggle("Insight", isOn: $formData.engPsychInsight)
                            .toggleStyle(CheckboxToggleStyle()).font(.caption)
                        Toggle("Psychoed", isOn: $formData.engPsychPsychoed)
                            .toggleStyle(CheckboxToggleStyle()).font(.caption)
                        Toggle("Emotions", isOn: $formData.engPsychEmotions)
                            .toggleStyle(CheckboxToggleStyle()).font(.caption)
                        Toggle("Drugs/alcohol", isOn: $formData.engPsychDrugsAlcohol)
                            .toggleStyle(CheckboxToggleStyle()).font(.caption)
                        Toggle("Discharge", isOn: $formData.engPsychDischarge)
                            .toggleStyle(CheckboxToggleStyle()).font(.caption)
                        Toggle("Relapse (group)", isOn: $formData.engPsychRelapseGroup)
                            .toggleStyle(CheckboxToggleStyle()).font(.caption)
                        Toggle("Relapse (1-1)", isOn: $formData.engPsychRelapse1to1)
                            .toggleStyle(CheckboxToggleStyle()).font(.caption)
                    }

                    PsychologySlider(
                        label: "Psychology Engagement",
                        value: $formData.engPsychLevel,
                        options: ["Limited", "Mixed", "Reasonable", "Good", "Very Good", "Excellent"],
                        color: .green
                    )
                }
                .padding(.leading, 8)
            } label: {
                Label("Attitudes to Engagement", systemImage: "hand.raised")
                    .font(.headline)
                    .foregroundColor(.green)
            }

            FormDivider()

            // Behaviour
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Behavioural concerns (last 12 months):").font(.subheadline.weight(.semibold))

                    BehaviourRow(label: "Verbal/physical aggression", value: $formData.behVerbalPhysical, details: $formData.behVerbalPhysicalDetails)
                    BehaviourRow(label: "Substance abuse", value: $formData.behSubstanceAbuse, details: $formData.behSubstanceAbuseDetails)
                    BehaviourRow(label: "Self-harm", value: $formData.behSelfHarm, details: $formData.behSelfHarmDetails)
                    BehaviourRow(label: "Fire-setting", value: $formData.behFireSetting, details: $formData.behFireSettingDetails)
                    BehaviourRow(label: "Intimidation/threats", value: $formData.behIntimidation, details: $formData.behIntimidationDetails)
                    BehaviourRow(label: "Secretive/manipulative", value: $formData.behSecretive, details: $formData.behSecretiveDetails)
                    BehaviourRow(label: "Subversive behaviour", value: $formData.behSubversive, details: $formData.behSubversiveDetails)
                    BehaviourRow(label: "Sexually inappropriate", value: $formData.behSexuallyInappropriate, details: $formData.behSexuallyInappropriateDetails)
                    BehaviourRow(label: "Extremist behaviour", value: $formData.behExtremist, details: $formData.behExtremistDetails)
                    BehaviourRow(label: "Periods of seclusion", value: $formData.behSeclusion, details: $formData.behSeclusionDetails)
                }
                .padding(.leading, 8)
            } label: {
                Label("Behaviour", systemImage: "exclamationmark.bubble")
                    .font(.headline)
                    .foregroundColor(.red)
            }

            if !formData.attitudeBehaviourImportedEntries.isEmpty {
                FormDivider()

                // Narrative Summary Section (matching desktop Section 4d)
                LeaveNarrativeSummarySection(
                    entries: formData.attitudeBehaviourImportedEntries,
                    period: .oneYear
                )

                FormDivider()
                ImportedDataSection(
                    title: "Imported Data",
                    entries: $formData.attitudeBehaviourImportedEntries,
                    categoryKeywords: LeaveFormCategoryKeywords.attitudeBehaviour
                )
            }
        }
    }

    private var riskFactorsPopup: some View {
        let riskLabels = ["None", "Low", "Medium", "High"]
        let riskTypes: [(key: String, label: String, current: Binding<Int>, historical: Binding<Int>)] = [
            ("violenceOthers", "Violence to others", $formData.riskCurrentViolenceOthers, $formData.riskHistoricalViolenceOthers),
            ("violenceProperty", "Violence to property", $formData.riskCurrentViolenceProperty, $formData.riskHistoricalViolenceProperty),
            ("selfHarm", "Self-harm", $formData.riskCurrentSelfHarm, $formData.riskHistoricalSelfHarm),
            ("suicide", "Suicide", $formData.riskCurrentSuicide, $formData.riskHistoricalSuicide),
            ("selfNeglect", "Self-neglect", $formData.riskCurrentSelfNeglect, $formData.riskHistoricalSelfNeglect),
            ("sexual", "Sexual offending", $formData.riskCurrentSexual, $formData.riskHistoricalSexual),
            ("exploitation", "Exploitation", $formData.riskCurrentExploitation, $formData.riskHistoricalExploitation),
            ("substance", "Substance misuse", $formData.riskCurrentSubstance, $formData.riskHistoricalSubstance),
            ("stalking", "Stalking", $formData.riskCurrentStalking, $formData.riskHistoricalStalking),
            ("vulnerability", "Vulnerability", $formData.riskCurrentVulnerability, $formData.riskHistoricalVulnerability),
            ("extremism", "Extremism", $formData.riskCurrentExtremism, $formData.riskHistoricalExtremism),
            ("deterioration", "Deterioration", $formData.riskCurrentDeterioration, $formData.riskHistoricalDeterioration),
            ("nonCompliance", "Non-compliance", $formData.riskCurrentNonCompliance, $formData.riskHistoricalNonCompliance)
        ]

        return VStack(alignment: .leading, spacing: 16) {
            // Current Risk
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(riskTypes, id: \.key) { risk in
                        RiskLevelRowWithSync(
                            label: risk.label,
                            currentValue: risk.current,
                            historicalValue: risk.historical,
                            labels: riskLabels
                        )
                    }
                }
                .padding(.leading, 8)
            } label: {
                Label("Current Risk", systemImage: "exclamationmark.shield")
                    .font(.headline)
                    .foregroundColor(.red)
            }

            FormDivider()

            // Historical Risk
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(riskTypes, id: \.key) { risk in
                        RiskLevelRow(label: risk.label, value: risk.historical, labels: riskLabels)
                    }
                }
                .padding(.leading, 8)
            } label: {
                Label("Historical Risk", systemImage: "clock.arrow.circlepath")
                    .font(.headline)
                    .foregroundColor(.orange)
            }

            FormDivider()

            // Understanding of Risks
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 12) {
                    let selectedRisks = riskTypes.filter { $0.current.wrappedValue > 0 || $0.historical.wrappedValue > 0 }

                    if selectedRisks.isEmpty {
                        Text("Select risks above to configure understanding")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(selectedRisks, id: \.key) { risk in
                            RiskUnderstandingRow(
                                label: risk.label,
                                riskKey: risk.key,
                                understandingLevels: $formData.riskUnderstandingLevels,
                                engagementLevels: $formData.riskUnderstandingEngagement
                            )
                        }
                    }
                }
                .padding(.leading, 8)
            } label: {
                Label("Understanding of Risks", systemImage: "brain")
                    .font(.headline)
                    .foregroundColor(.purple)
            }

            FormDivider()

            // Stabilising / Destabilising Factors
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 12) {
                    StabilisingFactorsSection(
                        stabilisingFactors: $formData.stabilisingFactors,
                        destabilisingFactors: $formData.destabilisingFactors
                    )
                }
                .padding(.leading, 8)
            } label: {
                Label("Stabilising / Destabilising", systemImage: "arrow.up.arrow.down")
                    .font(.headline)
                    .foregroundColor(.green)
            }

            if !formData.riskFactorsImportedEntries.isEmpty {
                FormDivider()
                ImportedDataSection(
                    title: "Imported Data",
                    entries: $formData.riskFactorsImportedEntries,
                    categoryKeywords: LeaveFormCategoryKeywords.riskFactors
                )
            }
        }
    }

    private var medicationPopup: some View {
        let frequencyOptions = ["OD", "BD", "TDS", "QDS", "Nocte", "PRN", "Weekly", "Fortnightly", "Monthly"]
        let complianceOptions = ["Poor", "Minimal", "Partial", "Good", "Very good", "Full"]
        let impactOptions = ["Nil", "Slight", "Some", "Moderate", "Good", "Excellent"]

        return VStack(alignment: .leading, spacing: 16) {
            // Current Medications
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach($formData.medicationEntries) { $entry in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                // Medication name - searchable dropdown
                                MedicationSearchField(selection: $entry.name)
                                    .frame(minWidth: 180)
                                    .padding(8)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)

                                Button {
                                    formData.medicationEntries.removeAll { $0.id == entry.id }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                        .font(.title2)
                                }
                            }

                            HStack(spacing: 12) {
                                // Dose picker - auto-populated from medication
                                MedicationDosePicker(medicationName: entry.name, selection: $entry.dose)
                                    .frame(width: 100)

                                // Frequency picker
                                Picker("Freq", selection: $entry.frequency) {
                                    ForEach(frequencyOptions, id: \.self) { Text($0).tag($0) }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 110)
                            }

                            // Show BNF max if medication is selected
                            if let medInfo = commonPsychMedications[entry.name] {
                                Text("Max BNF: \(medInfo.bnfMax)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .italic()
                            }
                        }
                        .padding(10)
                        .background(Color(.systemGray6).opacity(0.5))
                        .cornerRadius(10)
                    }

                    Button {
                        formData.medicationEntries.append(MedicationEntry())
                    } label: {
                        Label("Add Medication", systemImage: "plus.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .font(.caption)
                }
                .padding(.leading, 8)
            } label: {
                Label("Current Medications (\(formData.medicationEntries.count))", systemImage: "pills")
                    .font(.headline)
            }

            // Only show remaining sections if at least one medication is entered
            if formData.medicationEntries.contains(where: { !$0.name.isEmpty }) {
                FormDivider()

                // Capacity to Consent
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Capacity to consent", selection: $formData.medCapacity) {
                            Text("Select...").tag("select")
                            Text("Has capacity").tag("hasCapacity")
                            Text("Lacks capacity").tag("lacksCapacity")
                        }
                        .pickerStyle(.segmented)

                        // If lacks capacity, show MHA paperwork question
                        if formData.medCapacity == "lacksCapacity" {
                            HStack {
                                Text("MHA paperwork in place:")
                                    .font(.subheadline)
                                Picker("", selection: $formData.medMHAPaperwork) {
                                    Text("Select...").tag("")
                                    Text("Yes").tag("yes")
                                    Text("No").tag("no")
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 150)
                            }

                            // If MHA = No, show SOAD question
                            if formData.medMHAPaperwork == "no" {
                                HStack {
                                    Text("SOAD requested:")
                                        .font(.subheadline)
                                    Picker("", selection: $formData.medSOADRequested) {
                                        Text("Select...").tag("")
                                        Text("Yes").tag("yes")
                                        Text("No").tag("no")
                                    }
                                    .pickerStyle(.segmented)
                                    .frame(width: 150)
                                }
                            }
                        }
                    }
                    .padding(.leading, 8)
                } label: {
                    Label("Capacity to Consent", systemImage: "hand.raised")
                        .font(.headline)
                        .foregroundColor(.orange)
                }

                FormDivider()

                // Compliance, Impact, Response, Insight sliders
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 12) {
                        PsychologySlider(
                            label: "Compliance",
                            value: $formData.medCompliance,
                            options: complianceOptions,
                            color: .red
                        )

                        PsychologySlider(
                            label: "Impact on mental state",
                            value: $formData.medImpact,
                            options: impactOptions,
                            color: .red
                        )

                        PsychologySlider(
                            label: "Response to treatment",
                            value: $formData.medResponse,
                            options: impactOptions,
                            color: .red
                        )

                        PsychologySlider(
                            label: "Insight into need for medication",
                            value: $formData.medInsight,
                            options: impactOptions,
                            color: .red
                        )
                    }
                    .padding(.leading, 8)
                } label: {
                    Label("Compliance & Response", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.headline)
                        .foregroundColor(.red)
                }
            }

            if !formData.medicationImportedEntries.isEmpty {
                FormDivider()
                ImportedDataSection(
                    title: "Imported Data",
                    entries: $formData.medicationImportedEntries,
                    categoryKeywords: LeaveFormCategoryKeywords.medication
                )
            }
        }
    }

    private var psychologyPopup: some View {
        let indexOptions = ["None", "Considering", "Starting", "Engaging", "Well Engaged", "Almost Complete", "Complete"]
        let insightOptions = ["Nil", "Limited", "Partial", "Good", "Full"]
        let responsibilityOptions = ["Denies", "Minimises", "Partial", "Mostly", "Full"]
        let empathyOptions = ["Nil", "Limited", "Developing", "Good", "Full"]
        let attitudeOptions = ["Avoids", "Limited", "Some", "Good", "Full"]
        let effectivenessOptions = ["Nil", "Minimal", "Some", "Reasonable", "Good", "Very Good", "Excellent"]
        let relapseOptions = ["Not started", "Just started", "Ongoing", "Significant progression", "Almost completed", "Completed"]

        let riskFactors: [(key: String, label: String)] = [
            ("violence_others", "Violence to others"),
            ("violence_property", "Violence to property"),
            ("self_harm", "Self harm"),
            ("suicide", "Suicide/self-harm with intent"),
            ("self_neglect", "Self neglect"),
            ("sexual", "Sexual offending"),
            ("exploitation", "Exploitation/vulnerability"),
            ("substance", "Substance misuse"),
            ("stalking", "Stalking/harassment"),
            ("deterioration", "Mental state deterioration"),
            ("non_compliance", "Non-compliance/disengagement")
        ]

        let engagementItems: [(key: String, label: String)] = [
            ("one_to_one", "1-1"),
            ("risk", "Risk"),
            ("insight", "Insight"),
            ("psychoeducation", "Psychoeducation"),
            ("managing_emotions", "Managing emotions"),
            ("drugs_alcohol", "Drugs and alcohol"),
            ("carepathway", "Care pathway"),
            ("discharge_planning", "Discharge planning"),
            ("schema_therapy", "Schema therapy"),
            ("sotp", "SOTP")
        ]

        return VStack(alignment: .leading, spacing: 16) {
            // Section 1: Index Offence Work
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 12) {
                    PsychologySlider(
                        label: "Work to address index offence(s) and risks",
                        value: $formData.psychIndexEngagement,
                        options: indexOptions,
                        color: .purple
                    )

                    FormTextField(
                        label: "Details",
                        text: $formData.psychIndexDetails,
                        placeholder: "Additional details about index offence work..."
                    )
                }
                .padding(.leading, 8)
            } label: {
                Label("1. Index Offence Work", systemImage: "brain")
                    .font(.headline)
            }

            FormDivider()

            // Section 2: Offending Behaviour
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 12) {
                    PsychologySlider(
                        label: "Insight into offending",
                        value: $formData.psychInsight,
                        options: insightOptions,
                        color: .red
                    )

                    PsychologySlider(
                        label: "Accepts responsibility",
                        value: $formData.psychResponsibility,
                        options: responsibilityOptions,
                        color: .red
                    )

                    PsychologySlider(
                        label: "Victim empathy",
                        value: $formData.psychEmpathy,
                        options: empathyOptions,
                        color: .red
                    )

                    FormTextField(
                        label: "Details",
                        text: $formData.psychOffendingDetails,
                        placeholder: "Additional offending behaviour details..."
                    )
                }
                .padding(.leading, 8)
            } label: {
                Label("2. Offending Behaviour - Insight & Responsibility", systemImage: "exclamationmark.triangle")
                    .font(.headline)
                    .foregroundColor(.red)
            }

            FormDivider()

            // Section 3: Attitudes to risk factors
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(riskFactors, id: \.key) { risk in
                        PsychRiskAttitudeRow(
                            label: risk.label,
                            isSelected: Binding(
                                get: { formData.psychRiskAttitudes[risk.key] != nil },
                                set: { selected in
                                    if selected {
                                        formData.psychRiskAttitudes[risk.key] = 2  // Default to "Some"
                                    } else {
                                        formData.psychRiskAttitudes.removeValue(forKey: risk.key)
                                        formData.psychTreatments.removeValue(forKey: risk.key)
                                    }
                                }
                            ),
                            attitudeLevel: Binding(
                                get: { formData.psychRiskAttitudes[risk.key] ?? 2 },
                                set: { formData.psychRiskAttitudes[risk.key] = $0 }
                            ),
                            options: attitudeOptions
                        )
                    }
                }
                .padding(.leading, 8)
            } label: {
                Label("3. Attitudes to risk factors", systemImage: "brain.head.profile")
                    .font(.headline)
            }

            FormDivider()

            // Section 4: Treatment for risk factors
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 12) {
                    let selectedRisks = riskFactors.filter { formData.psychRiskAttitudes[$0.key] != nil }

                    if selectedRisks.isEmpty {
                        Text("Select risk factors in Section 3 to configure treatments")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .italic()
                            .padding(.vertical, 8)
                    } else {
                        ForEach(selectedRisks, id: \.key) { risk in
                            PsychTreatmentSection(
                                riskLabel: risk.label,
                                riskKey: risk.key,
                                treatmentData: Binding(
                                    get: { formData.psychTreatments[risk.key] ?? RiskTreatmentData() },
                                    set: { formData.psychTreatments[risk.key] = $0 }
                                ),
                                effectivenessOptions: effectivenessOptions
                            )
                        }
                    }
                }
                .padding(.leading, 8)
            } label: {
                Label("4. Treatment for risk factors", systemImage: "cross.case")
                    .font(.headline)
                    .foregroundColor(.green)
            }

            FormDivider()

            // Section 5: Relapse prevention
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 12) {
                    PsychologySlider(
                        label: "Relapse prevention progress",
                        value: $formData.psychRelapsePrevention,
                        options: relapseOptions,
                        color: .purple
                    )
                }
                .padding(.leading, 8)
            } label: {
                Label("5. Relapse prevention", systemImage: "arrow.counterclockwise.circle")
                    .font(.headline)
            }

            FormDivider()

            // Section 6: Current Engagement
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 8) {
                    LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 8) {
                        ForEach(engagementItems, id: \.key) { item in
                            Toggle(item.label, isOn: Binding(
                                get: { formData.psychCurrentEngagement.contains(item.key) },
                                set: { selected in
                                    if selected {
                                        formData.psychCurrentEngagement.insert(item.key)
                                        // Remove from outstanding if now engaged
                                        formData.psychOutstandingNeeds.remove(item.key)
                                    } else {
                                        formData.psychCurrentEngagement.remove(item.key)
                                    }
                                }
                            ))
                            .toggleStyle(CheckboxToggleStyle())
                            .font(.caption)
                        }
                    }
                }
                .padding(.leading, 8)
            } label: {
                Label("6. Current Engagement", systemImage: "person.fill.checkmark")
                    .font(.headline)
                    .foregroundColor(.blue)
            }

            FormDivider()

            // Section 7: Outstanding Needs
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 8) {
                    LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 8) {
                        ForEach(engagementItems, id: \.key) { item in
                            let isEngaged = formData.psychCurrentEngagement.contains(item.key)
                            Toggle(item.label, isOn: Binding(
                                get: { formData.psychOutstandingNeeds.contains(item.key) },
                                set: { selected in
                                    if selected && !isEngaged {
                                        formData.psychOutstandingNeeds.insert(item.key)
                                    } else {
                                        formData.psychOutstandingNeeds.remove(item.key)
                                    }
                                }
                            ))
                            .toggleStyle(CheckboxToggleStyle())
                            .font(.caption)
                            .disabled(isEngaged)
                            .opacity(isEngaged ? 0.4 : 1.0)
                        }
                    }

                    if formData.psychCurrentEngagement.count > 0 {
                        Text("Items currently engaged are greyed out")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
                .padding(.leading, 8)
            } label: {
                Label("7. Outstanding Needs", systemImage: "exclamationmark.circle")
                    .font(.headline)
                    .foregroundColor(.orange)
            }
            // Note: 4g Psychology does not have imported data display (matches Desktop)
            // Section 3 risk attitudes are auto-populated from 4e risk factors
        }
    }

    // MARK: - Psychology Helper Views

    /// Row for Section 3 risk factor attitude selection
    struct PsychRiskAttitudeRow: View {
        let label: String
        @Binding var isSelected: Bool
        @Binding var attitudeLevel: Int
        let options: [String]

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                Toggle(label, isOn: $isSelected)
                    .toggleStyle(CheckboxToggleStyle())
                    .font(.subheadline.weight(.semibold))

                if isSelected {
                    HStack {
                        Slider(value: Binding(
                            get: { Double(attitudeLevel) },
                            set: { attitudeLevel = Int($0) }
                        ), in: 0...Double(options.count - 1), step: 1)
                        .tint(.purple)
                        .frame(width: 150)

                        Text(options[min(attitudeLevel, options.count - 1)])
                            .font(.caption)
                            .foregroundColor(.purple)
                            .fontWeight(.semibold)
                            .frame(width: 60)
                    }
                    .padding(.leading, 24)
                }
            }
        }
    }

    /// Section for configuring treatments for a risk factor (Section 4)
    struct PsychTreatmentSection: View {
        let riskLabel: String
        let riskKey: String
        @Binding var treatmentData: RiskTreatmentData
        let effectivenessOptions: [String]

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text(riskLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.green)

                VStack(alignment: .leading, spacing: 6) {
                    TreatmentToggleRow(label: "Medication", isOn: $treatmentData.medication, effectiveness: $treatmentData.medicationEffectiveness, options: effectivenessOptions)
                    TreatmentToggleRow(label: "Psychology 1-1", isOn: $treatmentData.psych1to1, effectiveness: $treatmentData.psych1to1Effectiveness, options: effectivenessOptions)
                    TreatmentToggleRow(label: "Psychology groups", isOn: $treatmentData.psychGroups, effectiveness: $treatmentData.psychGroupsEffectiveness, options: effectivenessOptions)
                    TreatmentToggleRow(label: "Nursing support", isOn: $treatmentData.nursing, effectiveness: $treatmentData.nursingEffectiveness, options: effectivenessOptions)
                    TreatmentToggleRow(label: "OT support", isOn: $treatmentData.otSupport, effectiveness: $treatmentData.otSupportEffectiveness, options: effectivenessOptions)
                    TreatmentToggleRow(label: "Social Work", isOn: $treatmentData.socialWork, effectiveness: $treatmentData.socialWorkEffectiveness, options: effectivenessOptions)
                }
                .padding(.leading, 12)
            }
            .padding(10)
            .background(Color.green.opacity(0.05))
            .cornerRadius(8)
        }
    }

    /// Row for a treatment type with effectiveness slider
    struct TreatmentToggleRow: View {
        let label: String
        @Binding var isOn: Bool
        @Binding var effectiveness: Int
        let options: [String]

        var body: some View {
            VStack(alignment: .leading, spacing: 2) {
                Toggle(label, isOn: $isOn)
                    .toggleStyle(CheckboxToggleStyle())
                    .font(.caption)

                if isOn {
                    HStack {
                        Text("Effectiveness:")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Slider(value: Binding(
                            get: { Double(effectiveness) },
                            set: { effectiveness = Int($0) }
                        ), in: 0...Double(options.count - 1), step: 1)
                        .tint(.green)
                        .frame(width: 120)

                        Text(options[min(effectiveness, options.count - 1)])
                            .font(.caption2)
                            .foregroundColor(.green)
                            .fontWeight(.semibold)
                            .frame(width: 70)
                    }
                    .padding(.leading, 20)
                }
            }
        }
    }

    private var extremismPopup: some View {
        let vulnerabilityOptions = ["Nil", "Low", "Medium", "Significant", "High"]
        let viewsOptions = ["Nil", "Rare", "Some", "Often", "High"]

        return VStack(alignment: .leading, spacing: 16) {
            // Primary question: Is extremism a concern?
            HStack {
                Text("Extremism is a concern:")
                    .font(.headline)
                    .foregroundColor(.red)
                Spacer()
                Picker("", selection: $formData.extremismConcern) {
                    Text("N/A").tag("na")
                    Text("Yes").tag("yes")
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(8)

            // Details section (shown when Yes)
            if formData.extremismConcern == "yes" {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 12) {
                        // Vulnerability slider
                        PsychologySlider(
                            label: "Vulnerability to extremism",
                            value: $formData.extremismVulnerability,
                            options: vulnerabilityOptions,
                            color: .red
                        )

                        // Concerning views slider
                        PsychologySlider(
                            label: "Presence of concerning views",
                            value: $formData.extremismViews,
                            options: viewsOptions,
                            color: .red
                        )

                        FormDivider()

                        // Counter-terrorism contact checkboxes
                        Text("Contact with counter-terrorism:")
                            .font(.subheadline.weight(.semibold))
                        HStack(spacing: 20) {
                            Toggle("Police", isOn: $formData.extremismCTPolice)
                            Toggle("Probation", isOn: $formData.extremismCTProbation)
                        }
                        .toggleStyle(CheckboxToggleStyle())

                        FormDivider()

                        // Prevent referral
                        HStack {
                            Text("Prevent referral made:")
                                .font(.subheadline)
                            Picker("", selection: $formData.extremismPreventReferral) {
                                Text("Select...").tag("")
                                Text("Yes").tag("yes")
                                Text("No").tag("no")
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 180)
                        }

                        if formData.extremismPreventReferral == "yes" {
                            FormTextField(
                                label: "Prevent outcome",
                                text: $formData.extremismPreventOutcome,
                                placeholder: "Outcome of Prevent referral..."
                            )
                        }

                        FormDivider()

                        // Conditions to manage risk
                        FormTextEditor(
                            label: "Conditions needed to manage risk",
                            text: $formData.extremismConditions,
                            placeholder: "Any specific conditions required...",
                            minHeight: 60
                        )

                        // Work done to address risk
                        FormTextEditor(
                            label: "Work done to address risk",
                            text: $formData.extremismWorkDone,
                            placeholder: "Details of work undertaken...",
                            minHeight: 60
                        )
                    }
                    .padding(.leading, 8)
                } label: {
                    Label("Extremism Assessment Details", systemImage: "exclamationmark.octagon")
                        .font(.headline)
                        .foregroundColor(.red)
                }
            }

            // Additional text
            FormTextEditor(
                label: "Additional Notes",
                text: $formData.extremismText,
                placeholder: "Any additional extremism-related information...",
                minHeight: 80
            )

            if !formData.extremismImportedEntries.isEmpty {
                FormDivider()
                ImportedDataSection(
                    title: "Imported Data",
                    entries: $formData.extremismImportedEntries,
                    categoryKeywords: LeaveFormCategoryKeywords.extremism
                )
            }
        }
    }

    private var abscondingPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Primary question: Any AWOL incidents?
            HStack {
                Text("Any AWOL incidents?")
                    .font(.headline)
                    .foregroundColor(.orange)
                Spacer()
                Picker("", selection: $formData.abscondingAWOL) {
                    Text("N/A").tag("na")
                    Text("No").tag("no")
                    Text("Yes").tag("yes")
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)

            // Details section (shown when Yes)
            if formData.abscondingAWOL == "yes" {
                FormTextEditor(
                    label: "AWOL Details",
                    text: $formData.abscondingDetails,
                    placeholder: "Describe AWOL incidents including dates, circumstances, and outcomes...",
                    minHeight: 100
                )
            }

            // Additional notes
            FormTextEditor(
                label: "Additional Notes",
                text: $formData.abscondingText,
                placeholder: "Any additional absconding-related information...",
                minHeight: 80
            )

            if !formData.abscondingImportedEntries.isEmpty {
                FormDivider()
                ImportedDataSection(
                    title: "Imported Data",
                    entries: $formData.abscondingImportedEntries,
                    categoryKeywords: LeaveFormCategoryKeywords.absconding
                )
            }
        }
    }

    private var mappaPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Primary question: MAPPA eligible?
            HStack {
                Text("Convicted of MAPPA Eligible Index Offence:")
                    .font(.headline)
                    .foregroundColor(.blue)
                Spacer()
                Picker("", selection: $formData.mappaEligible) {
                    Text("No").tag("no")
                    Text("Yes").tag("yes")
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)

            // MAPPA details (shown when Yes)
            if formData.mappaEligible == "yes" {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 12) {
                        // 5a: Coordinator
                        FormTextEditor(
                            label: "5a. MAPPA Coordinator name and contact",
                            text: $formData.mappaCoordinator,
                            placeholder: "Enter MAPPA coordinator name and contact details...",
                            minHeight: 50
                        )

                        FormDivider()

                        // 5b: Category - shortened labels
                        Text("5b. MAPPA Category:")
                            .font(.subheadline.weight(.semibold))
                        Picker("Category", selection: $formData.mappaCategory) {
                            Text("—").tag(0)
                            Text("Cat 1").tag(1)
                            Text("Cat 2").tag(2)
                            Text("Cat 3").tag(3)
                            Text("Cat 4").tag(4)
                        }
                        .pickerStyle(.segmented)

                        FormDivider()

                        // 5c: Level - shortened labels
                        Text("5c. MAPPA Level:")
                            .font(.subheadline.weight(.semibold))
                        Picker("Level", selection: $formData.mappaLevel) {
                            Text("—").tag(0)
                            Text("L1").tag(1)
                            Text("L2").tag(2)
                            Text("L3").tag(3)
                        }
                        .pickerStyle(.segmented)

                        // Level 1 specific fields
                        if formData.mappaLevel == 1 {
                            FormDivider()
                            HStack {
                                Text("MAPPA I notification submitted?")
                                    .font(.subheadline)
                                Spacer()
                                Picker("", selection: $formData.mappaL1Notification) {
                                    Text("—").tag("")
                                    Text("Yes").tag("yes")
                                    Text("No").tag("no")
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 150)
                            }

                            // If No, ask if will submit prior to leave
                            if formData.mappaL1Notification == "no" {
                                HStack {
                                    Text("Will submit prior to leave?")
                                        .font(.subheadline)
                                        .padding(.leading, 20)
                                    Spacer()
                                    Picker("", selection: $formData.mappaL1WillSubmit) {
                                        Text("—").tag("")
                                        Text("Yes").tag("yes")
                                        Text("No").tag("no")
                                    }
                                    .pickerStyle(.segmented)
                                    .frame(width: 150)
                                }
                            }
                        }

                        // Level 2/3 specific fields
                        if formData.mappaLevel == 2 || formData.mappaLevel == 3 {
                            FormDivider()
                            HStack {
                                Text("MAPPA notification submitted & response received?")
                                    .font(.subheadline)
                                Spacer()
                                Picker("", selection: $formData.mappaL23Notification) {
                                    Text("—").tag("")
                                    Text("Yes").tag("yes")
                                    Text("No").tag("no")
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 150)
                            }

                            FormTextEditor(
                                label: "Why managed at this level & conditions requested",
                                text: $formData.mappaLevelReason,
                                placeholder: "Explain level rationale and any leave conditions...",
                                minHeight: 60
                            )
                        }
                    }
                    .padding(.leading, 8)
                } label: {
                    Label("MAPPA Details", systemImage: "person.badge.shield.checkmark")
                        .font(.headline)
                        .foregroundColor(.blue)
                }

                FormTextEditor(
                    label: "MAPPA Notes",
                    text: $formData.mappaNotesText,
                    placeholder: "Additional MAPPA information...",
                    minHeight: 80
                )
            }

            if !formData.mappaImportedEntries.isEmpty {
                FormDivider()
                ImportedDataSection(
                    title: "Imported Data",
                    entries: $formData.mappaImportedEntries,
                    categoryKeywords: LeaveFormCategoryKeywords.mappa
                )
            }
        }
    }

    private var victimsPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 6a: VLO Contact Details
            VStack(alignment: .leading, spacing: 8) {
                Text("6a. Victim Liaison Officer (VLO)")
                    .font(.headline)
                    .foregroundColor(.blue)
                FormTextEditor(
                    label: "Name and contact details of VLO(s)",
                    text: $formData.victimsVLOContact,
                    placeholder: "Enter VLO name and contact details...",
                    minHeight: 60
                )
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)

            // 6b: VLO Contacted
            VStack(alignment: .leading, spacing: 8) {
                Text("6b. VLO Contact Status")
                    .font(.headline)
                    .foregroundColor(.orange)
                HStack {
                    Text("Has VLO been contacted regarding this application?")
                        .font(.subheadline)
                    Spacer()
                    Picker("", selection: $formData.victimsContacted) {
                        Text("Select...").tag("")
                        Text("Yes").tag("yes")
                        Text("No").tag("no")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)

            // 6c: VLO Response
            VStack(alignment: .leading, spacing: 8) {
                Text("6c. VLO Response")
                    .font(.headline)
                    .foregroundColor(.green)
                FormTextField(
                    label: "When did the VLO reply?",
                    text: $formData.victimsReplyDate,
                    placeholder: "Enter date or status (e.g., 'Awaiting response', 'Case is dormant')..."
                )
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(8)

            // 6d: Conditions
            VStack(alignment: .leading, spacing: 8) {
                Text("6d. Conditions Requested by Victim(s)")
                    .font(.headline)
                    .foregroundColor(.purple)
                FormTextEditor(
                    label: "Non-contact conditions, exclusion zones, etc",
                    text: $formData.victimsConditions,
                    placeholder: "Copy directly from VLO's email reply. Include any exclusion zone maps as attachments...",
                    minHeight: 80
                )
            }
            .padding()
            .background(Color.purple.opacity(0.1))
            .cornerRadius(8)

            if !formData.victimsImportedEntries.isEmpty {
                FormDivider()
                ImportedDataSection(
                    title: "Imported Data",
                    entries: $formData.victimsImportedEntries,
                    categoryKeywords: LeaveFormCategoryKeywords.victims
                )
            }
        }
    }

    private var transferredPrisonersPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Primary question: Transferred prisoner?
            HStack {
                Text("Transferred Prisoner (s47/48/49 or s45A)?")
                    .font(.headline)
                    .foregroundColor(.orange)
                Spacer()
                Picker("", selection: $formData.prisonersApplicable) {
                    Text("N/A").tag("na")
                    Text("Yes").tag("yes")
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)

            // Details section (shown when Yes)
            if formData.prisonersApplicable == "yes" {
                InfoBox(
                    text: "Complete this section if patient is a s47/48/49 transferred prisoner or s45A hospital direction.",
                    icon: "info.circle",
                    color: .blue
                )

                // 7a: Offender Manager Details
                VStack(alignment: .leading, spacing: 8) {
                    Text("7a. Offender Manager (Probation Officer)")
                        .font(.headline)
                        .foregroundColor(.blue)
                    FormTextEditor(
                        label: "Name and contact details",
                        text: $formData.prisonersOMContact,
                        placeholder: "Details available from the transferring prison...",
                        minHeight: 60
                    )
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)

                // 7b: OM Notified
                VStack(alignment: .leading, spacing: 8) {
                    Text("7b. Offender Manager Notification")
                        .font(.headline)
                        .foregroundColor(.orange)
                    HStack {
                        Text("Has Offender Manager been notified of this application?")
                            .font(.subheadline)
                        Spacer()
                        Picker("", selection: $formData.prisonersNotified) {
                            Text("Select...").tag("")
                            Text("Yes").tag("yes")
                            Text("No").tag("no")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 180)
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)

                // 7c: OM Response
                VStack(alignment: .leading, spacing: 8) {
                    Text("7c. Offender Manager Response")
                        .font(.headline)
                        .foregroundColor(.green)
                    FormTextEditor(
                        label: "Response to leave proposal (issues/concerns raised)",
                        text: $formData.prisonersResponse,
                        placeholder: "Detail their response including any issues or concerns raised. Ensure remission has been considered...",
                        minHeight: 80
                    )
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)

                // 7d: Remission
                VStack(alignment: .leading, spacing: 8) {
                    Text("7d. Remission to Prison Consideration")
                        .font(.headline)
                        .foregroundColor(.purple)
                    FormTextEditor(
                        label: "Prognosis and remission considerations",
                        text: $formData.prisonersRemissionText,
                        placeholder: "Include: prognosis of when patient will be returned to prison, factors meaning remission is not appropriate, indicative timeframes/treatment requirements...",
                        minHeight: 100
                    )
                }
                .padding()
                .background(Color.purple.opacity(0.1))
                .cornerRadius(8)
            }

            if !formData.prisonersImportedEntries.isEmpty {
                FormDivider()
                ImportedDataSection(
                    title: "Imported Data",
                    entries: $formData.prisonersImportedEntries,
                    categoryKeywords: LeaveFormCategoryKeywords.transferredPrisoners
                )
            }
        }
    }

    private var fitnessToPlead: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Primary question: Found unfit to plead?
            VStack(alignment: .leading, spacing: 8) {
                Text("Has this patient been found unfit to plead on sentencing?")
                    .font(.headline)
                HStack {
                    Spacer()
                    Picker("", selection: $formData.fitnessFoundUnfit) {
                        Text("No").tag("no")
                        Text("Yes").tag("yes")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)

            // Details section (shown when Yes)
            if formData.fitnessFoundUnfit == "yes" {
                // Second question: Now fit to plead?
                VStack(alignment: .leading, spacing: 8) {
                    Text("Is patient now fit to plead?")
                        .font(.headline)
                    HStack {
                        Spacer()
                        Picker("", selection: $formData.fitnessNowFit) {
                            Text("Select...").tag("")
                            Text("Yes").tag("yes")
                            Text("No").tag("no")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 180)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)

                // Details text
                FormTextEditor(
                    label: "Details",
                    text: $formData.fitnessDetails,
                    placeholder: "Provide details about the patient's fitness to plead status...",
                    minHeight: 100
                )
            }

            if !formData.fitnessImportedEntries.isEmpty {
                FormDivider()
                ImportedDataSection(
                    title: "Imported Data",
                    entries: $formData.fitnessImportedEntries,
                    categoryKeywords: LeaveFormCategoryKeywords.fitnessToPlead
                )
            }
        }
    }

    private var additionalCommentsPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 9a: Additional Comments
            VStack(alignment: .leading, spacing: 8) {
                Text("9a. Additional Comments")
                    .font(.headline)
                    .foregroundColor(.primary)
                FormTextEditor(
                    label: "",
                    text: $formData.additionalCommentsText,
                    placeholder: "Enter any additional information or views pertinent to this leave application...",
                    minHeight: 100
                )
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)

            // 9b: Patient Discussion
            VStack(alignment: .leading, spacing: 12) {
                Text("9b. Patient Discussion")
                    .font(.headline)
                    .foregroundColor(.blue)

                // Has this been discussed with patient?
                HStack {
                    Text("Has this been discussed with the patient?")
                        .font(.subheadline)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { formData.discussedWithPatient ? "yes" : "no" },
                        set: { formData.discussedWithPatient = $0 == "yes" }
                    )) {
                        Text("No").tag("no")
                        Text("Yes").tag("yes")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                }

                // Issues of concern (shown when Yes)
                if formData.discussedWithPatient {
                    HStack {
                        Text("Any issues of concern?")
                            .font(.subheadline)
                            .padding(.leading, 20)
                        Spacer()
                        Picker("", selection: Binding(
                            get: { formData.issuesOfConcern ? "yes" : "no" },
                            set: { formData.issuesOfConcern = $0 == "yes" }
                        )) {
                            Text("No").tag("no")
                            Text("Yes").tag("yes")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 150)
                    }

                    // Details (shown when issues = Yes)
                    if formData.issuesOfConcern {
                        FormTextEditor(
                            label: "Details",
                            text: $formData.issuesDetails,
                            placeholder: "Enter details of concerns raised by the patient...",
                            minHeight: 80
                        )
                        .padding(.leading, 20)
                    }
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
    }

    private var signaturePopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            FormTextField(label: "Signature", text: $formData.signatureLine, placeholder: "Type name as signature")
            FormTextField(label: "Print Name", text: $formData.signatureName)
            FormDatePicker(label: "Date", date: $formData.signatureDate)

            FormDivider()

            FormSectionHeader(title: "Annex (Optional)", systemImage: "doc.append")

            FormTextEditor(
                label: "Patient Progress",
                text: $formData.annexProgress,
                placeholder: "Patient progress notes...",
                minHeight: 80
            )

            FormTextEditor(
                label: "Patient Wishes",
                text: $formData.annexWishes,
                placeholder: "Patient's expressed wishes...",
                minHeight: 80
            )

            FormTextEditor(
                label: "RC Confirmation",
                text: $formData.annexConfirm,
                placeholder: "RC confirmation...",
                minHeight: 80
            )
        }
    }

    // MARK: - Text Generators

    private func generatePatientDetailsText() -> String {
        var parts: [String] = []
        if !formData.patientName.isEmpty { parts.append("Patient: \(formData.patientName)") }
        if let dob = formData.patientDOB {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            parts.append("DOB: \(formatter.string(from: dob))")
        }
        parts.append("Gender: \(formData.patientGender.rawValue)")
        if !formData.hospitalNumber.isEmpty { parts.append("Hospital No: \(formData.hospitalNumber)") }
        if !formData.hospitalName.isEmpty { parts.append("Hospital: \(formData.hospitalName)") }
        if !formData.wardName.isEmpty { parts.append("Ward: \(formData.wardName)") }
        if !formData.mhaSection.isEmpty { parts.append("MHA Section: \(formData.mhaSection)") }
        if !formData.mojReference.isEmpty { parts.append("MOJ Ref: \(formData.mojReference)") }
        return parts.joined(separator: "\n")
    }

    private func generateRCDetailsText() -> String {
        var parts: [String] = []
        if !formData.rcName.isEmpty { parts.append("RC: \(formData.rcName)") }
        if !formData.rcEmail.isEmpty { parts.append("Email: \(formData.rcEmail)") }
        if !formData.rcPhone.isEmpty { parts.append("Phone: \(formData.rcPhone)") }
        return parts.joined(separator: "\n")
    }

    // MARK: - Section 4c Mental Disorder Text Generator

    private func generateMentalDisorderText() -> String {
        let pro = formData.patientGender == .male ? "He" : formData.patientGender == .female ? "She" : "They"
        let pos = formData.patientGender == .male ? "His" : formData.patientGender == .female ? "Her" : "Their"
        let has = formData.patientGender == .other ? "have" : "has"
        let is_ = formData.patientGender == .other ? "are" : "is"

        var parts: [String] = []

        // ICD-10 Diagnoses
        var diagnoses: [String] = []
        if formData.mdDiagnosis1 != .none { diagnoses.append(formData.mdDiagnosis1.rawValue) }
        if formData.mdDiagnosis2 != .none { diagnoses.append(formData.mdDiagnosis2.rawValue) }
        if formData.mdDiagnosis3 != .none { diagnoses.append(formData.mdDiagnosis3.rawValue) }

        if !diagnoses.isEmpty {
            if diagnoses.count == 1 {
                parts.append("\(pro) \(has) a diagnosis of \(diagnoses[0]).")
            } else {
                let lastDx = diagnoses.removeLast()
                parts.append("\(pro) \(has) diagnoses of \(diagnoses.joined(separator: ", ")) and \(lastDx).")
            }
        }

        // Clinical description
        if !formData.mdClinicalDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(formData.mdClinicalDescription)
        }

        // 1. Exacerbating Factors
        var factors: [String] = []
        if formData.mdExacAlcohol { factors.append("alcohol") }
        if formData.mdExacSubstance { factors.append("substance misuse") }
        if formData.mdExacNonCompliance { factors.append("non-compliance with treatment") }
        if formData.mdExacFinancial { factors.append("financial stress") }
        if formData.mdExacPersonalRelationships { factors.append("personal relationships") }
        if formData.mdExacFamilyStress { factors.append("family stress") }
        if formData.mdExacPhysicalHealth { factors.append("physical health issues") }
        if formData.mdExacWeapons { factors.append("use of weapons") }

        if !factors.isEmpty {
            if factors.count == 1 {
                parts.append("At the time of the index offence, \(pos.lowercased()) illness was exacerbated by \(factors[0]).")
            } else {
                let lastFactor = factors.removeLast()
                parts.append("At the time of the index offence, \(pos.lowercased()) illness was exacerbated by \(factors.joined(separator: ", ")) and \(lastFactor).")
            }
        }

        // 2. Current Mental State
        let mentalStateOptions = ["stable", "minor symptoms", "moderate symptoms", "significant symptoms", "severe symptoms"]
        let insightOptions = ["nil", "some", "partial", "moderate", "good", "full"]

        let mentalState = mentalStateOptions[min(formData.mdMentalStateLevel, mentalStateOptions.count - 1)]
        let insight = insightOptions[min(formData.mdInsightLevel, insightOptions.count - 1)]

        parts.append("\(pos) current mental state \(is_) \(mentalState) with \(insight) insight.")

        // 3. Observations
        if !formData.mdObservations.isEmpty {
            parts.append("\(pro) \(is_) currently on \(formData.mdObservations) observations.")
        }

        // 4. Physical Health
        let physImpactOptions = ["minimal", "mild", "some", "moderate", "significant", "high"]
        let physImpact = physImpactOptions[min(formData.mdPhysicalImpact, physImpactOptions.count - 1)]

        var allConditions: [String] = []
        allConditions.append(contentsOf: formData.mdPhysCardiac)
        allConditions.append(contentsOf: formData.mdPhysRespiratory)
        allConditions.append(contentsOf: formData.mdPhysGastric)
        allConditions.append(contentsOf: formData.mdPhysNeurological)
        allConditions.append(contentsOf: formData.mdPhysHepatic)
        allConditions.append(contentsOf: formData.mdPhysRenal)
        allConditions.append(contentsOf: formData.mdPhysCancer)

        if !allConditions.isEmpty {
            let conditionsList = allConditions.joined(separator: ", ")
            parts.append("Physical health issues (\(conditionsList)) have \(physImpact) impact on \(pos.lowercased()) mental health.")
        } else if formData.mdPhysicalImpact > 0 {
            parts.append("Physical health issues have \(physImpact) impact on \(pos.lowercased()) mental health.")
        }

        let baseText = parts.joined(separator: " ")
        return formData.appendImportedNotes(formData.mentalDisorderImportedEntries, to: baseText)
    }

    // MARK: - Section 4d Attitude & Behaviour Text Generator

    /// Helper to join items with "and" before last item
    private func joinWithAnd(_ items: [String]) -> String {
        if items.isEmpty { return "" }
        if items.count == 1 { return items[0] }
        return items.dropLast().joined(separator: ", ") + " and " + items.last!
    }

    private func generateAttitudeBehaviourText() -> String {
        let pro = formData.patientGender == .male ? "He" : formData.patientGender == .female ? "She" : "They"
        let pos = formData.patientGender == .male ? "His" : formData.patientGender == .female ? "Her" : "Their"
        let is_ = formData.patientGender == .other ? "are" : "is"
        let has = formData.patientGender == .other ? "have" : "has"

        var parts: [String] = []

        // 1. Treatment Understanding - grouped by level
        // "His understanding of his treatment needs is good for medical and nursing, fair for psychology, OT and social work."
        var understandingByLevel: [String: [String]] = [:]
        let treatments = [
            ("medical", formData.attMedicalUnderstanding),
            ("nursing", formData.attNursingUnderstanding),
            ("psychology", formData.attPsychologyUnderstanding),
            ("OT", formData.attOTUnderstanding),
            ("social work", formData.attSocialWorkUnderstanding)
        ]
        for (name, level) in treatments {
            if !level.isEmpty {
                let key = level.lowercased()
                understandingByLevel[key, default: []].append(name)
            }
        }

        if !understandingByLevel.isEmpty {
            let levelOrder = ["good", "fair", "poor"]
            var understandingParts: [String] = []
            for level in levelOrder {
                if let items = understandingByLevel[level], !items.isEmpty {
                    understandingParts.append("\(level) for \(joinWithAnd(items))")
                }
            }
            if !understandingParts.isEmpty {
                parts.append("\(pos) understanding of \(pos.lowercased()) treatment needs is \(understandingParts.joined(separator: ", ")).")
            }
        }

        // 2. Treatment Compliance - grouped by level with "but only" for lesser compliance
        // "He is reasonably compliant with medical and psychology, but only partially compliant with nursing, OT and social work."
        var complianceByLevel: [String: [String]] = [:]
        let complianceTreatments = [
            ("medical", formData.attMedicalCompliance),
            ("nursing", formData.attNursingCompliance),
            ("psychology", formData.attPsychologyCompliance),
            ("OT", formData.attOTCompliance),
            ("social work", formData.attSocialWorkCompliance)
        ]
        for (name, level) in complianceTreatments {
            if !level.isEmpty {
                let key = level.lowercased()
                complianceByLevel[key, default: []].append(name)
            }
        }

        if !complianceByLevel.isEmpty {
            let levelOrder = ["full", "reasonable", "partial", "nil"]
            let levelText = ["full": "fully", "reasonable": "reasonably", "partial": "partially", "nil": "not"]
            var complianceParts: [String] = []
            var isFirst = true
            for level in levelOrder {
                if let items = complianceByLevel[level], !items.isEmpty {
                    let adverb = levelText[level] ?? level
                    if isFirst {
                        complianceParts.append("\(adverb) compliant with \(joinWithAnd(items))")
                        isFirst = false
                    } else {
                        complianceParts.append("but only \(adverb) compliant with \(joinWithAnd(items))")
                    }
                }
            }
            if !complianceParts.isEmpty {
                parts.append("\(pro) \(is_) \(complianceParts.joined(separator: ", ")).")
            }
        }

        // 3. Ward rules
        if !formData.attWardRules.isEmpty {
            parts.append("\(pro) \(is_) \(formData.attWardRules.lowercased()) with ward rules.")
        }

        // 4. Conflict response - Desktop style: "In response to conflict he can escalate the situation."
        if !formData.attConflictResponse.isEmpty {
            let conflictText: String
            switch formData.attConflictResponse.lowercased() {
            case "avoids": conflictText = "In response to conflict \(pro.lowercased()) tends to avoid the situation."
            case "de-escalates": conflictText = "In response to conflict \(pro.lowercased()) tends to de-escalate the situation."
            case "neutral": conflictText = "In response to conflict \(pro.lowercased()) \(is_) neutral."
            case "escalates": conflictText = "In response to conflict \(pro.lowercased()) can escalate the situation."
            case "aggressive": conflictText = "In response to conflict \(pro.lowercased()) can become aggressive."
            default: conflictText = ""
            }
            if !conflictText.isEmpty { parts.append(conflictText) }
        }

        // 5. Relationships - grouped by level with "but" separator
        // "He has a close relationship with staff, but some relationships with peers, family and friends."
        let relationshipLabels = ["limited", "some", "good", "close", "very good"]
        var relationshipsByLevel: [String: [String]] = [:]
        let relationships = [
            ("staff", formData.attRelStaff),
            ("peers", formData.attRelPeers),
            ("family", formData.attRelFamily),
            ("friends", formData.attRelFriends)
        ]
        for (name, level) in relationships {
            let label = relationshipLabels[min(level, relationshipLabels.count - 1)]
            relationshipsByLevel[label, default: []].append(name)
        }

        if !relationshipsByLevel.isEmpty {
            let levelOrder = ["very good", "close", "good", "some", "limited"]
            var relationshipParts: [String] = []
            var isFirst = true
            for level in levelOrder {
                if let items = relationshipsByLevel[level], !items.isEmpty {
                    let singular = items.count == 1
                    let relWord = singular ? "relationship" : "relationships"
                    let article = (level == "close" || level == "good" || level == "limited") && singular ? "a " : ""
                    if isFirst {
                        relationshipParts.append("\(article)\(level) \(relWord) with \(joinWithAnd(items))")
                        isFirst = false
                    } else {
                        relationshipParts.append("but \(article)\(level) \(relWord) with \(joinWithAnd(items))")
                    }
                }
            }
            if !relationshipParts.isEmpty {
                parts.append("\(pro) \(has) \(relationshipParts.joined(separator: ", ")).")
            }
        }

        // 6. OT Groups - use "and" before last item
        let engagementLabels = ["limited", "mixed", "reasonable", "good", "very good", "excellent"]
        var otGroups: [String] = []
        if formData.engOTBreakfast { otGroups.append("breakfast") }
        if formData.engOTCooking { otGroups.append("cooking") }
        if formData.engOTCurrentAffairs { otGroups.append("current affairs") }
        if formData.engOTSelfCare { otGroups.append("self care") }
        if formData.engOTMusic { otGroups.append("music") }
        if formData.engOTArt { otGroups.append("art") }
        if formData.engOTGym { otGroups.append("gym") }
        if formData.engOTHorticulture { otGroups.append("horticulture") }
        if formData.engOTWoodwork { otGroups.append("woodwork") }
        if formData.engOTWalking { otGroups.append("walking") }

        if !otGroups.isEmpty {
            let otLevel = engagementLabels[min(formData.engOTLevel, engagementLabels.count - 1)]
            parts.append("\(pro) attends OT groups including \(joinWithAnd(otGroups)) with \(otLevel) engagement.")
        }

        // 7. Psychology - shorter names to match Desktop
        var psychGroups: [String] = []
        if formData.engPsych1to1 { psychGroups.append("1-1") }
        if formData.engPsychRisk { psychGroups.append("risk") }
        if formData.engPsychInsight { psychGroups.append("insight") }
        if formData.engPsychPsychoed { psychGroups.append("psychoed") }
        if formData.engPsychEmotions { psychGroups.append("emotions") }
        if formData.engPsychDrugsAlcohol { psychGroups.append("drugs/alcohol") }
        if formData.engPsychDischarge { psychGroups.append("discharge") }
        if formData.engPsychRelapseGroup { psychGroups.append("relapse (group)") }
        if formData.engPsychRelapse1to1 { psychGroups.append("relapse (1-1)") }

        if !psychGroups.isEmpty {
            let psychLevel = engagementLabels[min(formData.engPsychLevel, engagementLabels.count - 1)]
            parts.append("\(pro) engages in psychology work including \(joinWithAnd(psychGroups)) with \(psychLevel) engagement.")
        }

        // 8. Behaviour - Desktop style: "Regarding behaviours, there have been concerns about X. However, there has been no Y and no Z."
        var concerns: [String] = []
        var noConcerns: [String] = []

        let behaviourChecks: [(String, String, String)] = [
            (formData.behVerbalPhysical, "verbal or physical aggression", formData.behVerbalPhysicalDetails),
            (formData.behSubstanceAbuse, "substance abuse", formData.behSubstanceAbuseDetails),
            (formData.behSelfHarm, "self-harm", formData.behSelfHarmDetails),
            (formData.behFireSetting, "fire-setting", formData.behFireSettingDetails),
            (formData.behIntimidation, "intimidation or threats", formData.behIntimidationDetails),
            (formData.behSecretive, "secretive or manipulative behaviour", formData.behSecretiveDetails),
            (formData.behSubversive, "subversive behaviour", formData.behSubversiveDetails),
            (formData.behSexuallyInappropriate, "sexually inappropriate behaviour", formData.behSexuallyInappropriateDetails),
            (formData.behExtremist, "extremist behaviour", formData.behExtremistDetails),
            (formData.behSeclusion, "periods of seclusion", formData.behSeclusionDetails)
        ]

        for (value, label, details) in behaviourChecks {
            if value == "yes" {
                if !details.isEmpty {
                    concerns.append("\(label) (\(details))")
                } else {
                    concerns.append(label)
                }
            } else if value == "no" {
                noConcerns.append(label)
            }
        }

        if !concerns.isEmpty || !noConcerns.isEmpty {
            var behaviourText = "Regarding behaviours, "
            if !concerns.isEmpty {
                behaviourText += "there have been concerns about \(joinWithAnd(concerns)) in the last 12 months."
                if !noConcerns.isEmpty {
                    let noItems = noConcerns.map { "no \($0)" }
                    behaviourText += " However, there has been \(joinWithAnd(noItems))."
                }
            } else {
                behaviourText += "there have been no significant concerns in the last 12 months."
            }
            parts.append(behaviourText)
        }

        let baseText = parts.joined(separator: "\n")
        return formData.appendImportedNotes(formData.attitudeBehaviourImportedEntries, to: baseText)
    }

    // MARK: - Section 4e Risk Factors Text Generator

    private func generateRiskFactorsText() -> String {
        let pro = formData.patientGender == .male ? "He" : formData.patientGender == .female ? "She" : "They"
        let proLower = pro.lowercased()
        let pos = formData.patientGender == .male ? "his" : formData.patientGender == .female ? "her" : "their"
        let has = formData.patientGender == .other ? "have" : "has"
        let is_ = formData.patientGender == .other ? "are" : "is"

        var parts: [String] = []

        // Risk types mapping
        let riskTypes: [(key: String, label: String, current: Int, historical: Int)] = [
            ("violenceOthers", "violence to others", formData.riskCurrentViolenceOthers, formData.riskHistoricalViolenceOthers),
            ("violenceProperty", "violence to property", formData.riskCurrentViolenceProperty, formData.riskHistoricalViolenceProperty),
            ("selfHarm", "self-harm", formData.riskCurrentSelfHarm, formData.riskHistoricalSelfHarm),
            ("suicide", "suicide", formData.riskCurrentSuicide, formData.riskHistoricalSuicide),
            ("selfNeglect", "self-neglect", formData.riskCurrentSelfNeglect, formData.riskHistoricalSelfNeglect),
            ("sexual", "sexual offending", formData.riskCurrentSexual, formData.riskHistoricalSexual),
            ("exploitation", "exploitation of others", formData.riskCurrentExploitation, formData.riskHistoricalExploitation),
            ("substance", "substance misuse", formData.riskCurrentSubstance, formData.riskHistoricalSubstance),
            ("stalking", "stalking", formData.riskCurrentStalking, formData.riskHistoricalStalking),
            ("vulnerability", "vulnerability", formData.riskCurrentVulnerability, formData.riskHistoricalVulnerability),
            ("extremism", "extremism", formData.riskCurrentExtremism, formData.riskHistoricalExtremism),
            ("deterioration", "deterioration", formData.riskCurrentDeterioration, formData.riskHistoricalDeterioration),
            ("nonCompliance", "non-compliance", formData.riskCurrentNonCompliance, formData.riskHistoricalNonCompliance)
        ]

        let levelLabels = ["", "low", "medium", "high"]  // 0=none, 1=low, 2=medium, 3=high

        // 1. Compare current vs historical risks - Desktop style
        var improvements: [String: [String]] = ["low_from_high": [], "low_from_medium": [], "medium_from_high": []]
        var deteriorations: [String: [String]] = ["high_from_low": [], "high_from_medium": [], "medium_from_low": []]
        var sameLevel: [String: [String]] = ["high": [], "medium": [], "low": []]
        var currentOnly: [String: [String]] = ["high": [], "medium": [], "low": []]
        var historicalOnly: [String: [String]] = ["high": [], "medium": [], "low": []]

        for risk in riskTypes {
            let cur = risk.current
            let hist = risk.historical

            if cur > 0 && hist > 0 {
                // Both exist - compare
                if cur == hist {
                    sameLevel[levelLabels[cur], default: []].append(risk.label)
                } else if cur == 1 && hist == 3 {
                    improvements["low_from_high", default: []].append(risk.label)
                } else if cur == 1 && hist == 2 {
                    improvements["low_from_medium", default: []].append(risk.label)
                } else if cur == 2 && hist == 3 {
                    improvements["medium_from_high", default: []].append(risk.label)
                } else if cur == 3 && hist == 1 {
                    deteriorations["high_from_low", default: []].append(risk.label)
                } else if cur == 3 && hist == 2 {
                    deteriorations["high_from_medium", default: []].append(risk.label)
                } else if cur == 2 && hist == 1 {
                    deteriorations["medium_from_low", default: []].append(risk.label)
                }
            } else if cur > 0 {
                currentOnly[levelLabels[cur], default: []].append(risk.label)
            } else if hist > 0 {
                historicalOnly[levelLabels[hist], default: []].append(risk.label)
            }
        }

        var riskSentences: [String] = []

        // Improvements
        if let items = improvements["low_from_high"], !items.isEmpty {
            riskSentences.append("Risks of \(joinWithAnd(items)) are currently low which is an improvement from historically where they were high")
        }
        if let items = improvements["low_from_medium"], !items.isEmpty {
            riskSentences.append("risks of \(joinWithAnd(items)) are currently low, improved from medium historically")
        }
        if let items = improvements["medium_from_high"], !items.isEmpty {
            riskSentences.append("risks of \(joinWithAnd(items)) are currently medium, improved from high historically")
        }

        // Deteriorations
        if let items = deteriorations["high_from_low"], !items.isEmpty {
            let prefix = riskSentences.isEmpty ? "There has been a deterioration in " : "However, there has been a deterioration in "
            riskSentences.append("\(prefix)risk of \(joinWithAnd(items)) which was low historically and is currently high")
        }
        if let items = deteriorations["high_from_medium"], !items.isEmpty {
            let prefix = riskSentences.isEmpty ? "There has been a deterioration in " : "There has also been a deterioration in "
            riskSentences.append("\(prefix)risk of \(joinWithAnd(items)) which was medium historically and is currently high")
        }
        if let items = deteriorations["medium_from_low"], !items.isEmpty {
            let prefix = riskSentences.isEmpty ? "There has been a deterioration in " : "Additionally, "
            riskSentences.append("\(prefix)risk of \(joinWithAnd(items)) which was low historically and is currently medium")
        }

        // Same level
        for level in ["high", "medium", "low"] {
            if let items = sameLevel[level], !items.isEmpty {
                if items.count == 1 {
                    riskSentences.append("The risk of \(items[0]) is currently \(level) which is the same as historically")
                } else {
                    riskSentences.append("The risks of \(joinWithAnd(items)) are currently \(level) which is the same as historically")
                }
            }
        }

        // Current only
        for level in ["high", "medium", "low"] {
            if let items = currentOnly[level], !items.isEmpty {
                if items.count == 1 {
                    riskSentences.append("Current risk of \(items[0]) is \(level)")
                } else {
                    riskSentences.append("Current risks of \(joinWithAnd(items)) are \(level)")
                }
            }
        }

        // Historical only
        for level in ["high", "medium", "low"] {
            if let items = historicalOnly[level], !items.isEmpty {
                if items.count == 1 {
                    riskSentences.append("Historical risk of \(items[0]) was \(level)")
                } else {
                    riskSentences.append("Historical risks of \(joinWithAnd(items)) were \(level)")
                }
            }
        }

        if !riskSentences.isEmpty {
            parts.append(riskSentences.joined(separator: ". ") + ".")
        }

        // 2. Understanding of Risks - Desktop style: group by level with "but only" for first drop
        let understandingLabels = ["poor", "fair", "good"]  // 0=poor, 1=fair, 2=good

        var understandingByLevel: [Int: [String]] = [2: [], 1: [], 0: []]  // good=2, fair=1, poor=0
        for risk in riskTypes where risk.current > 0 || risk.historical > 0 {
            if let level = formData.riskUnderstandingLevels[risk.key] {
                understandingByLevel[level, default: []].append(risk.label)
            }
        }

        var undPhrases: [String] = []
        var usedBut = false
        for level in [2, 1, 0] {  // good, fair, poor
            guard let labels = understandingByLevel[level], !labels.isEmpty else { continue }
            let levelText = understandingLabels[level]

            // Build risk text with possessive pronoun
            let riskText: String
            if labels.count == 1 {
                riskText = "\(pos) \(labels[0]) risk"
            } else {
                riskText = "\(pos) \(joinWithAnd(labels)) risk"
            }

            if undPhrases.isEmpty {
                undPhrases.append("a \(levelText) understanding of \(riskText)")
            } else if !usedBut {
                undPhrases.append("but only a \(levelText) understanding of \(riskText)")
                usedBut = true
            } else {
                undPhrases.append("and a \(levelText) understanding of \(riskText)")
            }
        }

        if !undPhrases.isEmpty {
            parts.append("\(pro) \(has) \(undPhrases.joined(separator: ", ")).")
        }

        // 3. Engagement - Desktop style: per risk with level-specific phrasing
        let engagementLabels = ["none", "started", "ongoing", "advanced", "complete"]  // 0-4

        var engByLevel: [Int: [String]] = [4: [], 3: [], 2: [], 1: [], 0: []]  // complete=4, advanced=3, ongoing=2, started=1, none=0
        for risk in riskTypes where risk.current > 0 || risk.historical > 0 {
            if let eng = formData.riskUnderstandingEngagement[risk.key] {
                engByLevel[eng, default: []].append(risk.label)
            }
        }

        var engSentences: [String] = []
        var isFirstEng = true

        for level in [4, 3, 2, 1, 0] {
            guard let labels = engByLevel[level], !labels.isEmpty else { continue }
            let riskText = joinWithAnd(labels)

            switch level {
            case 4:  // Complete
                if isFirstEng {
                    engSentences.append("\(pro) \(has) complete engagement in treatment for \(riskText) risk.")
                } else {
                    engSentences.append("\(pro) also \(has) complete engagement for \(riskText).")
                }
            case 3:  // Advanced
                if isFirstEng {
                    engSentences.append("\(pro) \(has) advanced engagement in treatment for \(riskText) risk.")
                } else {
                    engSentences.append("There is also advanced engagement for \(riskText).")
                }
            case 2:  // Ongoing
                if isFirstEng {
                    engSentences.append("\(pro) \(has) ongoing engagement in treatment for \(riskText) risk.")
                } else {
                    engSentences.append("There is ongoing engagement for \(riskText).")
                }
            case 1:  // Started
                if isFirstEng {
                    engSentences.append("\(pro) \(has) just started treatment for \(riskText) risk.")
                } else {
                    engSentences.append("\(pro) \(has) just started treatment for \(riskText).")
                }
            case 0:  // None
                if isFirstEng {
                    engSentences.append("\(pro) \(is_) not engaging in any work for \(pos) \(riskText).")
                } else {
                    engSentences.append("Unfortunately, \(proLower) \(is_) not engaging in any work for \(pos) \(riskText).")
                }
            default:
                break
            }
            isFirstEng = false
        }

        if !engSentences.isEmpty {
            parts.append(engSentences.joined(separator: " "))
        }

        // 4. Stabilising Factors - Desktop style with special phrases
        let stabSpecialPhrases: [String: String] = [
            "MHA provision in place": "\(pro) would require the mental health act provision to be in place for community stability.",
            "CMHT engagement": "Engagement and involvement of the mental health team would be a significant stabiliser.",
            "supported accommodation": "Supported accommodation would be a significant stabiliser."
        ]

        if !formData.stabilisingFactors.isEmpty {
            var specialParts: [String] = []
            var regularFactors: [String] = []
            for factor in formData.stabilisingFactors.sorted() {
                if let special = stabSpecialPhrases[factor] {
                    specialParts.append(special)
                } else {
                    regularFactors.append(factor.lowercased())
                }
            }
            if !regularFactors.isEmpty {
                parts.append("Stabilising factors include \(regularFactors.joined(separator: ", ")).")
            }
            parts.append(contentsOf: specialParts)
        }

        // 5. Destabilising Factors - Desktop style with special phrases
        let destabSpecialPhrases: [String: String] = [
            "absence of MHA provision": "Absence of mental health act provision has been a destabiliser in the community.",
            "lack of CMHT engagement": "Lack of engagement with the mental health team has been a significant destabiliser.",
            "social stress/housing instability": "Social stress and housing instability have been destabilising factors."
        ]

        if !formData.destabilisingFactors.isEmpty {
            var specialParts: [String] = []
            var regularFactors: [String] = []
            for factor in formData.destabilisingFactors.sorted() {
                if let special = destabSpecialPhrases[factor] {
                    specialParts.append(special)
                } else {
                    regularFactors.append(factor.lowercased())
                }
            }
            if !regularFactors.isEmpty {
                parts.append("Destabilising factors include \(regularFactors.joined(separator: ", ")).")
            }
            parts.append(contentsOf: specialParts)
        }

        let baseText = parts.joined(separator: " ")
        return formData.appendImportedNotes(formData.riskFactorsImportedEntries, to: baseText)
    }

    // MARK: - Section 4f Medication Text Generator

    private func generateMedicationText() -> String {
        let pro = formData.patientGender == .male ? "He" : formData.patientGender == .female ? "She" : "They"
        let pos = formData.patientGender == .male ? "his" : formData.patientGender == .female ? "her" : "their"
        let has = formData.patientGender == .other ? "have" : "has"
        let is_ = formData.patientGender == .other ? "are" : "is"
        let lacks = formData.patientGender == .other ? "lack" : "lacks"

        var parts: [String] = []
        let complianceOptions = ["poor", "minimal", "partial", "good", "very good", "full"]
        let impactOptions = ["nil", "slight", "some", "moderate", "good", "excellent"]

        // 1. Medication list
        let medList = formData.medicationEntries.filter { !$0.name.isEmpty }.map { entry -> String in
            var medStr = entry.name.capitalized
            if !entry.dose.isEmpty { medStr += " \(entry.dose)" }
            if !entry.frequency.isEmpty { medStr += " \(entry.frequency)" }
            return medStr
        }

        if !medList.isEmpty {
            parts.append("\(pro) \(is_) currently prescribed: \(medList.joined(separator: ", ")).")

            // 2. Capacity
            var capacityComplianceText = ""
            if formData.medCapacity == "hasCapacity" {
                capacityComplianceText = "\(pro) \(has) capacity to consent to medication"
            } else if formData.medCapacity == "lacksCapacity" {
                parts.append("\(pro) \(lacks) capacity to consent to medication.")

                // MHA paperwork
                if formData.medMHAPaperwork == "yes" {
                    parts.append("MHA paperwork is in place.")
                } else if formData.medMHAPaperwork == "no" {
                    parts.append("MHA paperwork is not in place.")
                    // SOAD
                    if formData.medSOADRequested == "yes" {
                        parts.append("A SOAD has been requested.")
                    } else if formData.medSOADRequested == "no" {
                        parts.append("A SOAD has not been requested.")
                    }
                }
            }

            // 3. Compliance
            let compIdx = min(formData.medCompliance, complianceOptions.count - 1)
            let compliancePhrases = [
                "\(is_) poorly compliant",
                "\(is_) minimally compliant",
                "\(is_) partially compliant",
                "\(has) good compliance",
                "\(has) very good compliance",
                "\(has) full compliance"
            ]
            let complianceText = compliancePhrases[compIdx]

            if !capacityComplianceText.isEmpty {
                parts.append("\(capacityComplianceText) and \(complianceText).")
            } else {
                parts.append("\(pro) \(complianceText).")
            }

            // 4. Impact + Response combined
            let impactIdx = min(formData.medImpact, impactOptions.count - 1)
            let responseIdx = min(formData.medResponse, impactOptions.count - 1)

            let impactPhrases = [
                "The medication is having no impact on \(pos) mental state currently",
                "The medication is only having a slight impact on \(pos) mental state",
                "The medication has some impact on \(pos) mental state",
                "The medication has a moderate impact on \(pos) mental state",
                "The medication has a good impact on \(pos) mental state",
                "The medication has an excellent impact on \(pos) mental state"
            ]

            let responsePhrases = [
                "and the response has been limited.",
                "and the response has been slight.",
                "and \(pro.lowercased()) \(has) some response to treatment.",
                "and \(pro.lowercased()) \(has) a moderate response to treatment.",
                "and \(pro.lowercased()) \(has) a good response to treatment.",
                "and \(pro.lowercased()) \(has) an excellent response to treatment."
            ]

            parts.append("\(impactPhrases[impactIdx]) \(responsePhrases[responseIdx])")

            // 5. Insight
            let insightIdx = min(formData.medInsight, impactOptions.count - 1)
            let insightPhrases = [
                "Overall, insight for medication is not present.",
                "Overall, insight for medication is minimal.",
                "Overall, \(pro.lowercased()) \(has) some insight into the need for medication.",
                "Overall, \(pro.lowercased()) \(has) moderate insight into the need for medication.",
                "Overall, \(pro.lowercased()) \(has) good insight into the need for medication.",
                "Overall, \(pro.lowercased()) \(has) excellent insight into the need for medication."
            ]
            parts.append(insightPhrases[insightIdx])
        }

        let baseText = parts.joined(separator: " ")
        return formData.appendImportedNotes(formData.medicationImportedEntries, to: baseText)
    }

    // MARK: - Section 3c-3g Text Generators (matching Desktop)

    private func generatePurposeText() -> String {
        let pro = formData.patientGender == .male ? "He" : formData.patientGender == .female ? "She" : "They"
        let have = formData.patientGender == .other ? "have" : "has"
        let pos = formData.patientGender == .male ? "his" : formData.patientGender == .female ? "her" : "their"

        var parts: [String] = []

        // 1. Purpose narrative
        switch formData.purposeType {
        case "starting":
            parts.append("The purpose of leave is starting meaningful testing in the community looking toward progression to possible unescorted leave.")
        case "continuing":
            parts.append("\(pro) \(have) already had some leave granted so the aim would be to continue to build on this.")
        case "unescorted":
            parts.append("The aim of leave is to move from escorted to unescorted to allow further independence and rehabilitation.")
        case "rehabilitation":
            parts.append("The leave is to build on \(pos) rehabilitation process.")
        default:
            break
        }

        // 2. Location narrative
        var locations: [String] = []
        if formData.locationGround { locations.append("the hospital grounds") }
        if formData.locationLocal { locations.append("the local area") }
        if formData.locationCommunity { locations.append("the wider community") }
        if formData.locationFamily { locations.append("family residence") }

        if !locations.isEmpty {
            if locations.count == 1 {
                parts.append("Leave would take place within \(locations[0]).")
            } else {
                let locText = locations.dropLast().joined(separator: ", ") + " and " + locations.last!
                parts.append("Leave would take place within \(locText).")
            }
        }

        // Exclusion zone
        switch formData.exclusionZone {
        case "yes":
            parts.append("The leave is close to/within the exclusion zone and this will be monitored closely by the team.")
        case "no":
            parts.append("There are no concerns regarding the exclusion zone with this leave.")
        case "na":
            parts.append("There is no exclusion zone with this patient.")
        default:
            break
        }

        // 3. Discharge planning
        let dischargeOptions = ["Not started", "Early stages", "In progress", "Almost completed", "Completed"]
        let dischargeNarratives = [
            "Discharge planning has not yet commenced and leave would be an early step in this process.",
            "Discharge planning is in its early stages and leave would be an important step in building toward this.",
            "Discharge planning is currently in progress and leave would be an important step in this.",
            "Discharge planning is almost complete and leave would support the final stages of preparation.",
            "Discharge planning is complete and leave would support the transition to the community."
        ]
        if formData.dischargePlanningStatus < dischargeNarratives.count {
            parts.append(dischargeNarratives[formData.dischargePlanningStatus])
        }

        // Additional text
        if !formData.purposeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(formData.purposeText)
        }

        return parts.joined(separator: " ")
    }

    private func generateOvernightText() -> String {
        if formData.overnightApplicable == "na" || formData.overnightApplicable.isEmpty {
            return formData.overnightText.isEmpty ? "N/A" : formData.overnightText
        }

        let pro = formData.patientGender == .male ? "He" : formData.patientGender == .female ? "She" : "They"
        let pos = formData.patientGender == .male ? "his" : formData.patientGender == .female ? "her" : "their"

        var parts: [String] = []

        // Accommodation
        switch formData.overnightAccommodationType {
        case "24hr_supported":
            parts.append("Overnight leave would be to 24-hour supported accommodation.")
        case "9to5_supported":
            parts.append("Overnight leave would be to 9-5 supported accommodation.")
        case "independent":
            parts.append("Overnight leave would be to independent accommodation.")
        case "family":
            parts.append("Overnight leave would be to family home.")
        default:
            break
        }

        if !formData.overnightAddress.isEmpty {
            parts.append("Address: \(formData.overnightAddress).")
        }

        // Prior to recall
        if formData.overnightPriorToRecall == "yes" {
            parts.append("\(pro) resided at this address prior to recall.")
        } else if formData.overnightPriorToRecall == "no" {
            parts.append("This is a new address, not \(pos) address prior to recall.")
        }

        // Index link
        if formData.overnightLinkedToIndex == "yes" {
            parts.append("The address is linked to the index offence and will be closely monitored.")
        } else if formData.overnightLinkedToIndex == "no" {
            parts.append("The address is not linked to the index offence.")
        }

        // Support
        var support: [String] = []
        if formData.overnightSupportStaff { support.append("staff") }
        if formData.overnightSupportCMHT { support.append("CMHT") }
        if formData.overnightSupportInpatient { support.append("inpatient team") }
        if formData.overnightSupportFamily { support.append("family") }
        if !support.isEmpty {
            parts.append("Support will be provided by \(support.joined(separator: ", ")).")
        }

        // Nights
        if formData.overnightNightsPerWeek > 0 {
            parts.append("\(formData.overnightNightsPerWeek) night(s) per week are requested.")
        }

        // Discharge
        if formData.overnightDischargeToAddress == "yes" {
            parts.append("Discharge is planned to this address.")
        }

        if !formData.overnightText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(formData.overnightText)
        }

        return parts.joined(separator: " ")
    }

    private func generateEscortedOvernightText() -> String {
        if formData.escortedOvernightApplicable == "na" || formData.escortedOvernightApplicable.isEmpty {
            return formData.escortedOvernightText.isEmpty ? "N/A" : formData.escortedOvernightText
        }

        let pro = formData.patientGender == .male ? "He" : formData.patientGender == .female ? "She" : "They"
        let have = formData.patientGender == .other ? "have" : "has"
        let does = formData.patientGender == .other ? "do" : "does"

        var parts: [String] = []

        // Capacity
        if formData.escortedCapacity == "yes" {
            parts.append("\(pro) \(have) capacity for decisions regarding residence and leave.")
            if formData.escortedInitialTesting == "yes" {
                parts.append("This would be initial testing of escorted overnight leave.")
            }
        } else if formData.escortedCapacity == "no" {
            parts.append("\(pro) \(does) not have capacity for decisions regarding residence and leave.")
            if formData.escortedDoLSPlan == "yes" {
                parts.append("A DoLS plan is in place.")
            } else if formData.escortedDoLSPlan == "no" {
                parts.append("A DoLS application will be required.")
            }
        }

        // Discharge plan
        var dischargePlan: [String] = []
        if formData.escortedDischargePlanDoLS { dischargePlan.append("DoLS arrangement") }
        if formData.escortedDischargePlanUnescorted { dischargePlan.append("progression to unescorted leave") }
        if formData.escortedDischargePlanInitialTesting { dischargePlan.append("initial testing") }
        if !dischargePlan.isEmpty {
            parts.append("Discharge plan includes \(dischargePlan.joined(separator: ", ")).")
        }

        if !formData.escortedOvernightText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(formData.escortedOvernightText)
        }

        return parts.joined(separator: " ")
    }

    private func generateCompassionateText() -> String {
        if formData.compassionateApplicable == "na" || formData.compassionateApplicable.isEmpty {
            return formData.compassionateText.isEmpty ? "N/A" : formData.compassionateText
        }

        var parts: [String] = []

        if formData.compassionateVirtualVisit == "yes" {
            parts.append("A virtual visit has been arranged.")
        } else if formData.compassionateVirtualVisit == "no" {
            parts.append("An in-person visit is required.")
        }

        if formData.compassionateUrgent == "yes" {
            parts.append("This is an urgent compassionate leave request.")
        }

        if !formData.compassionateText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(formData.compassionateText)
        }

        return parts.isEmpty ? "Compassionate leave requested." : parts.joined(separator: " ")
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

                parts.append("Over the past two years, \(proL) \(has) taken approximately \(leaves) \(escortType) leave\(leavePlural) \(frequency), averaging \(duration) per leave, engaging in \(typeStr).")
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
                    var mutableTypes = otherTypes
                    let lastType = mutableTypes.removeLast()
                    parts.append("\(pro) \(has) also taken leave for \(mutableTypes.joined(separator: ", ")) and \(lastType).")
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
            resultParts.append("ESCORTED LEAVE:\n\(escortedText)")
        }
        if !unescortedText.isEmpty {
            resultParts.append("UNESCORTED LEAVE:\n\(unescortedText)")
        }

        let baseText = resultParts.isEmpty ? "No leave information provided." : resultParts.joined(separator: "\n\n")
        return formData.appendImportedNotes(formData.leaveReportImportedEntries, to: baseText)
    }

    private func generateProceduresText() -> String {
        let pro = formData.patientGender == .male ? "He" : formData.patientGender == .female ? "She" : "They"
        let proL = pro.lowercased()
        let pos = formData.patientGender == .male ? "His" : formData.patientGender == .female ? "Her" : "Their"
        let posL = pos.lowercased()

        var parts: [String] = []

        // Escorts
        if !formData.proceduresEscorts.isEmpty {
            let plural = formData.proceduresEscorts == "1" ? "" : "s"
            parts.append("\(pro) will be accompanied by \(formData.proceduresEscorts) escort\(plural)")
        }

        // Transport
        var transportSelected: [String] = []
        if formData.proceduresTransportSecure { transportSelected.append("secure transport") }
        if formData.proceduresTransportHospital { transportSelected.append("hospital transport") }
        if formData.proceduresTransportTaxi { transportSelected.append("taxi") }
        if formData.proceduresTransportPublic { transportSelected.append("public transport") }

        if !transportSelected.isEmpty {
            if transportSelected.count == 1 {
                parts.append("\(pro) will travel by \(transportSelected[0])")
            } else {
                parts.append("\(pro) will travel by \(transportSelected.joined(separator: " and by "))")
            }
        }

        // Handcuffs
        if formData.proceduresHandcuffs {
            parts.append("Handcuffs will be carried")
        }

        // Exclusion zone
        if formData.proceduresExclusionZone == "yes" {
            if !formData.proceduresExclusionDetails.isEmpty {
                parts.append("An exclusion zone applies: \(formData.proceduresExclusionDetails)")
            } else {
                parts.append("An exclusion zone applies")
            }
        } else if formData.proceduresExclusionZone == "na" {
            parts.append("There is no exclusion zone")
        }

        // Pre-leave checks
        var preLeaveParts: [String] = []
        if formData.proceduresRiskFree {
            preLeaveParts.append("\(proL) must be risk free for more than 24 hours")
        }
        if formData.proceduresMentalState {
            preLeaveParts.append("\(posL) mental state will be assessed prior to leave")
        }
        if formData.proceduresEscortsConfirmed {
            preLeaveParts.append("escorts will be confirmed as known to the patient")
        }
        if formData.proceduresTimings {
            preLeaveParts.append("all timings will be monitored")
        }

        if !preLeaveParts.isEmpty {
            parts.append("Prior to leave, \(preLeaveParts.joined(separator: " and "))")
        }

        // No drugs/alcohol (separate sentence)
        if formData.proceduresNoDrugs {
            parts.append("\(pro) will not be permitted to take drugs or alcohol")
        }

        // On return
        var onReturnParts: [String] = []
        if formData.proceduresSearch {
            onReturnParts.append("\(proL) will be searched")
        }
        if formData.proceduresDrugTesting {
            onReturnParts.append("\(proL) will undergo drug testing")
        }

        if !onReturnParts.isEmpty {
            if onReturnParts.count == 2 {
                parts.append("On return \(onReturnParts[0]) and \(onReturnParts[1])")
            } else {
                parts.append("On return \(onReturnParts[0])")
            }
        }

        // Breaches
        var breachParts: [String] = []
        if formData.proceduresBreachSuspension {
            breachParts.append("leave will be suspended")
        }
        if formData.proceduresBreachInformMOJ {
            breachParts.append("the MOJ will be informed")
        }

        if !breachParts.isEmpty {
            parts.append("In the event of any breach \(breachParts.joined(separator: " and "))")
        }

        // Specific to patient
        if formData.proceduresSpecificToPatient {
            parts.append("I can confirm the measures proposed are specifically defined for this patient")
        }

        return parts.isEmpty ? "" : parts.joined(separator: ". ") + "."
    }

    private func generateMAPPAText() -> String {
        // Check if not eligible
        if formData.mappaEligible == "no" {
            return "Non MAPPA eligible."
        }

        var parts: [String] = []

        if !formData.mappaCoordinator.isEmpty {
            parts.append("MAPPA Coordinator: \(formData.mappaCoordinator).")
        }

        if formData.mappaCategory > 0 {
            parts.append("MAPPA Category \(formData.mappaCategory).")
        }

        if formData.mappaLevel > 0 {
            parts.append("Managed at Level \(formData.mappaLevel).")

            // Level 1 specific
            if formData.mappaLevel == 1 {
                if formData.mappaL1Notification == "yes" {
                    parts.append("MAPPA I notification has been submitted.")
                } else if formData.mappaL1Notification == "no" {
                    parts.append("MAPPA I notification has not been submitted.")
                    if formData.mappaL1WillSubmit == "yes" {
                        parts.append("Notification will be submitted prior to leave.")
                    } else if formData.mappaL1WillSubmit == "no" {
                        parts.append("Notification will not be submitted prior to leave.")
                    }
                }
            }

            // Level 2/3 specific
            if formData.mappaLevel == 2 || formData.mappaLevel == 3 {
                if formData.mappaL23Notification == "yes" {
                    parts.append("MAPPA notification has been submitted and response received.")
                } else if formData.mappaL23Notification == "no" {
                    parts.append("MAPPA notification has not been submitted or response not yet received.")
                }
                if !formData.mappaLevelReason.isEmpty {
                    parts.append(formData.mappaLevelReason)
                }
            }
        }

        if !formData.mappaNotesText.isEmpty {
            parts.append(formData.mappaNotesText)
        }

        let baseText = parts.isEmpty ? "MAPPA information not entered." : parts.joined(separator: " ")
        return formData.appendImportedNotes(formData.mappaImportedEntries, to: baseText)
    }

    private func generateVictimsText() -> String {
        var parts: [String] = []

        if !formData.victimsVLOContact.isEmpty {
            parts.append("VLO: \(formData.victimsVLOContact).")
        }

        if formData.victimsContacted == "yes" {
            parts.append("VLO has been contacted regarding this application.")
        } else if formData.victimsContacted == "no" {
            parts.append("VLO has NOT been contacted.")
        }

        if !formData.victimsReplyDate.isEmpty {
            parts.append("VLO response: \(formData.victimsReplyDate).")
        }

        if !formData.victimsConditions.isEmpty {
            parts.append("Victim conditions: \(formData.victimsConditions).")
        }

        if !formData.victimsRiskAssessment.isEmpty {
            parts.append("Risk to victims: \(formData.victimsRiskAssessment).")
        }

        let baseText = parts.isEmpty ? "No victim information entered." : parts.joined(separator: " ")
        return formData.appendImportedNotes(formData.victimsImportedEntries, to: baseText)
    }

    private func generatePrisonersText() -> String {
        if formData.prisonersApplicable == "na" {
            return "Not applicable - patient is not a transferred prisoner."
        }
        var parts: [String] = []
        parts.append("Patient is a transferred prisoner (s47/48/49 or s45A).")

        if formData.prisonersNotified == "yes" {
            parts.append("Offender Manager has been notified of this application.")
        } else if formData.prisonersNotified == "no" {
            parts.append("Offender Manager has not yet been notified.")
        }

        if !formData.prisonersOMContact.isEmpty {
            parts.append("OM Contact: \(formData.prisonersOMContact)")
        }
        if !formData.prisonersResponse.isEmpty {
            parts.append("OM Response: \(formData.prisonersResponse)")
        }
        if !formData.prisonersRemissionText.isEmpty {
            parts.append("Remission considerations: \(formData.prisonersRemissionText)")
        }
        return parts.joined(separator: "\n")
    }

    private func generateAdditionalCommentsText() -> String {
        var parts: [String] = []

        // 9a: Additional comments text
        if !formData.additionalCommentsText.isEmpty {
            parts.append(formData.additionalCommentsText)
        }

        // 9b: Patient discussion - narrative style matching Desktop
        if formData.discussedWithPatient {
            var discussionParts: [String] = []
            discussionParts.append("This has been discussed with the patient.")

            if formData.issuesOfConcern {
                if !formData.issuesDetails.isEmpty {
                    discussionParts.append("Issues of concern: \(formData.issuesDetails)")
                } else {
                    discussionParts.append("Issues of concern were raised.")
                }
            } else {
                discussionParts.append("No issues of concern.")
            }
            parts.append(discussionParts.joined(separator: " "))
        } else {
            parts.append("This has not been discussed with the patient.")
        }

        return parts.joined(separator: " ")
    }

    private func generateFitnessToPlead() -> String {
        if formData.fitnessFoundUnfit == "no" {
            return "Patient was not found unfit to plead."
        }

        var parts: [String] = []
        parts.append("Patient was found unfit to plead on sentencing.")

        if formData.fitnessNowFit == "yes" {
            parts.append("Patient is now fit to plead.")
        } else if formData.fitnessNowFit == "no" {
            parts.append("Patient remains unfit to plead.")
        }

        if !formData.fitnessDetails.isEmpty {
            parts.append(formData.fitnessDetails)
        }

        return parts.joined(separator: " ")
    }

    private func generatePsychologyText() -> String {
        let pro = formData.patientGender == .male ? "He" : formData.patientGender == .female ? "She" : "They"
        let proLower = pro.lowercased()
        let has = formData.patientGender == .other ? "have" : "has"
        let is_ = formData.patientGender == .other ? "are" : "is"

        var parts: [String] = []

        // Section 1: Index offence work - flowing sentence
        let idxVal = formData.psychIndexEngagement
        let idxPhrases = [
            "\(pro) \(has) not started work to address the index offence",
            "\(pro) \(is_) considering work to address the index offence",
            "\(pro) \(is_) starting work to address the index offence",
            "\(pro) \(is_) engaging in work to address the index offence",
            "\(pro) \(is_) well engaged in work to address the index offence",
            "\(pro) \(has) almost completed work to address the index offence",
            "\(pro) \(has) completed work to address the index offence"
        ]
        let idxPhrase = idxPhrases[min(idxVal, idxPhrases.count - 1)]

        // Section 2: Insight continuation
        let insightVal = formData.psychInsight
        let insightOptions = ["no", "limited", "partial", "good", "full"]
        let insightText = insightOptions[min(insightVal, insightOptions.count - 1)]
        let insightCont: String
        if insightVal == 0 {
            insightCont = "with no insight into this"
        } else if insightVal <= 2 {
            insightCont = "with \(insightText) insight into this"
        } else {
            insightCont = "with \(insightText) insight"
        }

        // Responsibility continuation
        let respVal = formData.psychResponsibility
        let respCont: String
        switch respVal {
        case 0: respCont = "not accepting any responsibility"
        case 1: respCont = "minimising responsibility"
        case 2: respCont = "only accepting partial responsibility"
        case 3: respCont = "mostly accepting responsibility"
        default: respCont = "accepting full responsibility"
        }

        // Empathy
        let empathyVal = formData.psychEmpathy
        let empathyCont: String
        switch empathyVal {
        case 0: empathyCont = "\(pro) \(has) no victim empathy"
        case 1: empathyCont = "\(pro) \(has) limited victim empathy"
        case 2: empathyCont = "\(pro) \(is_) developing victim empathy"
        case 3: empathyCont = "\(pro) \(has) good victim empathy"
        default: empathyCont = "\(pro) \(has) full victim empathy"
        }

        // Combine into natural sentence
        parts.append("\(idxPhrase), \(insightCont) and \(respCont). \(empathyCont).")

        if !formData.psychIndexDetails.isEmpty {
            parts.append(formData.psychIndexDetails)
        }
        if !formData.psychOffendingDetails.isEmpty {
            parts.append(formData.psychOffendingDetails)
        }

        // Sections 3 & 4 Combined: Risk factors - understanding + treatment per risk (Desktop style)
        let pos = formData.patientGender == .male ? "his" : formData.patientGender == .female ? "her" : "their"
        let attitudeLabels = ["avoids discussing", "has limited understanding of", "has some understanding of", "has good understanding of", "fully understands"]
        let riskFactorLabels: [String: String] = [
            "violence_others": "violence to others",
            "violence_property": "violence to property",
            "self_harm": "self harm",
            "suicide": "suicide",
            "self_neglect": "self neglect",
            "sexual": "sexual offending",
            "exploitation": "exploitation",
            "substance": "substance misuse",
            "stalking": "stalking",
            "deterioration": "mental state deterioration",
            "non_compliance": "non-compliance"
        ]

        // Helper to convert effectiveness level to natural language
        func effectivenessPhrase(_ level: Int, _ treatmentName: String, isPlural: Bool = false) -> String {
            let verb = isPlural ? "have" : "has"
            switch level {
            case 0: return "\(treatmentName) \(verb) had no effect"
            case 1: return "\(treatmentName) \(verb) had minimal effect"
            case 2: return "\(treatmentName) \(verb) had some effect"
            case 3: return "\(treatmentName) \(verb) been reasonably helpful"
            case 4: return "\(treatmentName) \(verb) been helpful"
            case 5: return "\(treatmentName) \(verb) been very helpful"
            default: return "\(treatmentName) \(verb) been extremely helpful"
            }
        }

        // Build combined risk factor sentences - sorted by understanding level (best first)
        var riskSentences: [String] = []
        let sortedRiskKeys = formData.psychRiskAttitudes.keys.sorted { key1, key2 in
            let level1 = formData.psychRiskAttitudes[key1] ?? 0
            let level2 = formData.psychRiskAttitudes[key2] ?? 0
            return level1 > level2  // Higher level (better understanding) first
        }

        for riskKey in sortedRiskKeys {
            guard let attitudeLevel = formData.psychRiskAttitudes[riskKey],
                  let riskLabel = riskFactorLabels[riskKey] else { continue }

            // Understanding part
            let understandingText = attitudeLabels[min(attitudeLevel, attitudeLabels.count - 1)]
            var sentence = "\(pro) \(understandingText) \(pos) \(riskLabel)"

            // Treatment part - combine with understanding
            if let treatmentData = formData.psychTreatments[riskKey] {
                var treatmentPhrases: [String] = []

                if treatmentData.medication && treatmentData.medicationEffectiveness > 0 {
                    treatmentPhrases.append(effectivenessPhrase(treatmentData.medicationEffectiveness, "Medication"))
                }
                if treatmentData.psych1to1 && treatmentData.psych1to1Effectiveness > 0 {
                    treatmentPhrases.append(effectivenessPhrase(treatmentData.psych1to1Effectiveness, "Psychology 1-1"))
                }
                if treatmentData.psychGroups && treatmentData.psychGroupsEffectiveness > 0 {
                    treatmentPhrases.append(effectivenessPhrase(treatmentData.psychGroupsEffectiveness, "Psychology groups", isPlural: true))
                }
                if treatmentData.nursing && treatmentData.nursingEffectiveness > 0 {
                    treatmentPhrases.append(effectivenessPhrase(treatmentData.nursingEffectiveness, "Nursing"))
                }
                if treatmentData.otSupport && treatmentData.otSupportEffectiveness > 0 {
                    treatmentPhrases.append(effectivenessPhrase(treatmentData.otSupportEffectiveness, "OT"))
                }
                if treatmentData.socialWork && treatmentData.socialWorkEffectiveness > 0 {
                    treatmentPhrases.append(effectivenessPhrase(treatmentData.socialWorkEffectiveness, "Social Work"))
                }

                if !treatmentPhrases.isEmpty {
                    if treatmentPhrases.count == 1 {
                        sentence += ", and \(treatmentPhrases[0])"
                    } else {
                        // First treatment with "and", rest with "while"
                        sentence += ", and \(treatmentPhrases[0])"
                        for i in 1..<treatmentPhrases.count {
                            sentence += " while \(treatmentPhrases[i])"
                        }
                    }
                }
            }

            riskSentences.append(sentence)
        }

        if !riskSentences.isEmpty {
            // First sentence starts with "Regarding risk factors:"
            var riskText = "Regarding risk factors: \(riskSentences[0])."
            // Additional sentences start with "Additionally,"
            for i in 1..<riskSentences.count {
                // Lowercase the first character (the pronoun)
                let sentence = riskSentences[i]
                let lowercasedSentence = sentence.prefix(1).lowercased() + sentence.dropFirst()
                riskText += " Additionally, \(lowercasedSentence)."
            }
            parts.append(riskText)
        }

        // Section 5: Relapse prevention
        let relapseLabels = ["not started", "just started", "ongoing", "progressing significantly", "almost completed", "completed"]
        let relapseVal = formData.psychRelapsePrevention
        if relapseVal > 0 {
            let relapseText = relapseLabels[min(relapseVal, relapseLabels.count - 1)]
            parts.append("\(pro) \(has) \(relapseText) relapse prevention work.")
        }

        // Section 6: Current Engagement
        let engagementLabels: [String: String] = [
            "one_to_one": "1-1",
            "risk": "risk",
            "insight": "insight",
            "psychoeducation": "psychoeducation",
            "managing_emotions": "managing emotions",
            "drugs_alcohol": "drugs and alcohol",
            "carepathway": "care pathway",
            "discharge_planning": "discharge planning",
            "schema_therapy": "schema therapy",
            "sotp": "SOTP"
        ]
        if !formData.psychCurrentEngagement.isEmpty {
            let engagedItems = formData.psychCurrentEngagement.compactMap { engagementLabels[$0] }
            if !engagedItems.isEmpty {
                parts.append("\(pro) \(is_) currently engaged in work for \(joinWithAnd(engagedItems)).")
            }
        }

        // Section 7: Outstanding Needs
        if !formData.psychOutstandingNeeds.isEmpty {
            let outstandingItems = formData.psychOutstandingNeeds.compactMap { engagementLabels[$0] }
            if !outstandingItems.isEmpty {
                parts.append("Outstanding psychological needs include \(joinWithAnd(outstandingItems)).")
            }
        }

        // Note: 4g Psychology does not append imported notes (matches Desktop)
        return parts.joined(separator: " ")
    }

    private func generateExtremismText() -> String {
        let pro = formData.patientGender == .male ? "He" : formData.patientGender == .female ? "She" : "They"
        let has = formData.patientGender == .other ? "have" : "has"

        if formData.extremismConcern == "na" {
            return "N/A"
        }

        var parts: [String] = []
        parts.append("Extremism is identified as a concern.")

        // Vulnerability
        let vulnVal = formData.extremismVulnerability
        let vulnOptions = ["nil", "low", "medium", "significant", "high"]
        let vulnText = vulnOptions[min(vulnVal, vulnOptions.count - 1)]
        if vulnVal == 0 {
            parts.append("\(pro) \(has) no identified vulnerability to extremism.")
        } else {
            parts.append("\(pro) \(has) \(vulnText) vulnerability to extremism.")
        }

        // Concerning views
        let viewsVal = formData.extremismViews
        switch viewsVal {
        case 0: parts.append("There is no presence of concerning views.")
        case 1: parts.append("Concerning views are rarely expressed.")
        case 2: parts.append("There is some presence of concerning views.")
        case 3: parts.append("Concerning views are often expressed.")
        default: parts.append("There is a high presence of concerning views.")
        }

        // Counter-terrorism contact
        var ctContacts: [String] = []
        if formData.extremismCTPolice { ctContacts.append("police") }
        if formData.extremismCTProbation { ctContacts.append("probation") }
        if !ctContacts.isEmpty {
            parts.append("There has been contact with counter-terrorism \(ctContacts.joined(separator: " and ")).")
        }

        // Prevent referral
        if formData.extremismPreventReferral == "yes" {
            if !formData.extremismPreventOutcome.isEmpty {
                parts.append("A Prevent referral has been made with outcome: \(formData.extremismPreventOutcome).")
            } else {
                parts.append("A Prevent referral has been made.")
            }
        } else if formData.extremismPreventReferral == "no" {
            parts.append("No Prevent referral has been made.")
        }

        // Conditions
        if !formData.extremismConditions.isEmpty {
            parts.append("Conditions needed to manage risk: \(formData.extremismConditions)")
        }

        // Work done
        if !formData.extremismWorkDone.isEmpty {
            parts.append("Work done to address risk: \(formData.extremismWorkDone)")
        }

        if !formData.extremismText.isEmpty {
            parts.append(formData.extremismText)
        }

        return parts.joined(separator: " ")
    }

    private func generateAbscondingText() -> String {
        var parts: [String] = []

        switch formData.abscondingAWOL {
        case "yes":
            parts.append("There have been AWOL incidents in the last 12 months.")
            if !formData.abscondingDetails.isEmpty {
                parts.append(formData.abscondingDetails)
            }
        case "no":
            parts.append("There have been no AWOL incidents in the last 12 months.")
        default:
            parts.append("AWOL: N/A")
        }

        if !formData.abscondingText.isEmpty {
            parts.append(formData.abscondingText)
        }

        return parts.joined(separator: " ")
    }

    private func generateSignatureText() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        var parts: [String] = []
        if !formData.signatureName.isEmpty {
            parts.append("Signed: \(formData.signatureName)")
        }
        parts.append("Date: \(formatter.string(from: formData.signatureDate))")
        return parts.joined(separator: "\n")
    }

    // MARK: - Leave Type Automation (3a triggers 3c-3g defaults)

    /// Called when a leave type checkbox in 3a is checked.
    /// Applies default values to sections 3c, 3d, 3e, 3f, and 3g based on the leave type.
    private func onLeaveTypeChanged(_ leaveType: String) {
        // Apply defaults to all dependent sections
        apply3cDefaults(leaveType: leaveType)
        apply3dDefaults(leaveType: leaveType)
        apply3eDefaults(leaveType: leaveType)
        apply3fDefaults(leaveType: leaveType)
        apply3gDefaults(leaveType: leaveType)
        apply3hDefaults(leaveType: leaveType)
    }

    /// Apply 3c Purpose of Leave defaults based on leave type from 3a.
    private func apply3cDefaults(leaveType: String) {
        // Define defaults for each leave type
        // Purpose: starting, continuing, unescorted, rehabilitation
        // Locations: ground, local, community, family
        // Discharge: 0=Not started, 1=Early stages, 2=In progress, 3=Almost completed, 4=Completed
        switch leaveType {
        case "escorted_day":
            formData.purposeType = "starting"
            formData.locationGround = true
            formData.locationLocal = true
            formData.locationCommunity = false
            formData.locationFamily = false
            formData.exclusionZone = "na"
            formData.dischargePlanningStatus = 0

        case "escorted_overnight":
            formData.purposeType = "continuing"
            formData.locationGround = false
            formData.locationLocal = false
            formData.locationCommunity = true
            formData.locationFamily = false
            formData.exclusionZone = "na"
            formData.dischargePlanningStatus = 2

        case "unescorted_day":
            formData.purposeType = "unescorted"
            formData.locationGround = true
            formData.locationLocal = true
            formData.locationCommunity = true
            formData.locationFamily = false
            formData.exclusionZone = "na"
            formData.dischargePlanningStatus = 2

        case "unescorted_overnight":
            formData.purposeType = "rehabilitation"
            formData.locationGround = false
            formData.locationLocal = false
            formData.locationCommunity = true
            formData.locationFamily = false
            formData.exclusionZone = "na"
            formData.dischargePlanningStatus = 4

        case "compassionate_day":
            formData.purposeType = "rehabilitation"
            formData.locationGround = false
            formData.locationLocal = false
            formData.locationCommunity = true
            formData.locationFamily = false
            formData.exclusionZone = "na"
            formData.dischargePlanningStatus = 1

        case "compassionate_overnight":
            formData.purposeType = "rehabilitation"
            formData.locationGround = false
            formData.locationLocal = false
            formData.locationCommunity = true
            formData.locationFamily = false
            formData.exclusionZone = "na"
            formData.dischargePlanningStatus = 2

        default:
            break
        }
    }

    /// Apply 3d Unescorted Overnight Leave defaults based on leave type from 3a.
    private func apply3dDefaults(leaveType: String) {
        if leaveType == "unescorted_overnight" {
            // Only unescorted_overnight gets Yes
            formData.overnightApplicable = "yes"
            formData.overnightAccommodationType = "24hr_supported"
            formData.overnightPriorToRecall = "yes"
            formData.overnightLinkedToIndex = "no"
        } else {
            // All other leave types get N/A
            formData.overnightApplicable = "na"
        }
    }

    /// Apply 3e Escorted Overnight Leave defaults based on leave type from 3a.
    private func apply3eDefaults(leaveType: String) {
        if leaveType == "escorted_overnight" {
            // Only escorted_overnight gets Yes
            formData.escortedOvernightApplicable = "yes"
            formData.escortedCapacity = "yes"
            formData.escortedInitialTesting = "yes"
        } else {
            // All other leave types get N/A
            formData.escortedOvernightApplicable = "na"
        }
    }

    /// Apply 3f Compassionate Leave defaults based on leave type from 3a.
    private func apply3fDefaults(leaveType: String) {
        if leaveType.contains("compassionate") {
            // Compassionate leave types get Yes
            formData.compassionateApplicable = "yes"
            formData.compassionateVirtualVisit = "no"  // Physical presence required
            formData.compassionateUrgent = "yes"
        } else {
            // All other leave types get N/A
            formData.compassionateApplicable = "na"
        }
    }

    /// Apply 3g Leave Report defaults based on leave type from 3a.
    private func apply3gDefaults(leaveType: String) {
        // Always set suspension to No
        formData.escortedLeave.suspended = false
        formData.escortedLeave.suspensionDetails = ""
        formData.unescortedLeave.suspended = false
        formData.unescortedLeave.suspensionDetails = ""

        switch leaveType {
        case "escorted_day":
            // Empty/no leave taken yet - reset both to defaults
            formData.escortedLeave = ASRLeaveState()
            formData.unescortedLeave = ASRLeaveState()

        case "escorted_overnight":
            // Escorted: 3 leaves weekly, 2hrs, Ground/Local/Community at 33% each
            formData.escortedLeave.leavesPerPeriod = 3
            formData.escortedLeave.frequency = "Weekly"
            formData.escortedLeave.duration = "2 hours"
            formData.escortedLeave.ground = ASRLeaveTypeWeight(enabled: true, weight: 33)
            formData.escortedLeave.local = ASRLeaveTypeWeight(enabled: true, weight: 33)
            formData.escortedLeave.community = ASRLeaveTypeWeight(enabled: true, weight: 34)
            formData.escortedLeave.extended = ASRLeaveTypeWeight(enabled: false, weight: 0)
            formData.escortedLeave.overnight = ASRLeaveTypeWeight(enabled: false, weight: 0)
            formData.escortedLeave.suspended = false
            // Reset unescorted
            formData.unescortedLeave = ASRLeaveState()

        case "unescorted_day":
            // Same escorted defaults as escorted_overnight
            formData.escortedLeave.leavesPerPeriod = 3
            formData.escortedLeave.frequency = "Weekly"
            formData.escortedLeave.duration = "2 hours"
            formData.escortedLeave.ground = ASRLeaveTypeWeight(enabled: true, weight: 33)
            formData.escortedLeave.local = ASRLeaveTypeWeight(enabled: true, weight: 33)
            formData.escortedLeave.community = ASRLeaveTypeWeight(enabled: true, weight: 34)
            formData.escortedLeave.extended = ASRLeaveTypeWeight(enabled: false, weight: 0)
            formData.escortedLeave.overnight = ASRLeaveTypeWeight(enabled: false, weight: 0)
            formData.escortedLeave.suspended = false
            // Reset unescorted
            formData.unescortedLeave = ASRLeaveState()

        case "unescorted_overnight":
            // Escorted defaults
            formData.escortedLeave.leavesPerPeriod = 3
            formData.escortedLeave.frequency = "Weekly"
            formData.escortedLeave.duration = "2 hours"
            formData.escortedLeave.ground = ASRLeaveTypeWeight(enabled: true, weight: 33)
            formData.escortedLeave.local = ASRLeaveTypeWeight(enabled: true, weight: 33)
            formData.escortedLeave.community = ASRLeaveTypeWeight(enabled: true, weight: 34)
            formData.escortedLeave.extended = ASRLeaveTypeWeight(enabled: false, weight: 0)
            formData.escortedLeave.overnight = ASRLeaveTypeWeight(enabled: false, weight: 0)
            formData.escortedLeave.suspended = false
            // Unescorted: Ground 11%, Local 36%, Community 53%
            formData.unescortedLeave.leavesPerPeriod = 3
            formData.unescortedLeave.frequency = "Weekly"
            formData.unescortedLeave.duration = "2 hours"
            formData.unescortedLeave.ground = ASRLeaveTypeWeight(enabled: true, weight: 11)
            formData.unescortedLeave.local = ASRLeaveTypeWeight(enabled: true, weight: 36)
            formData.unescortedLeave.community = ASRLeaveTypeWeight(enabled: true, weight: 53)
            formData.unescortedLeave.extended = ASRLeaveTypeWeight(enabled: false, weight: 0)
            formData.unescortedLeave.overnight = ASRLeaveTypeWeight(enabled: false, weight: 0)
            formData.unescortedLeave.suspended = false

        case "compassionate_day", "compassionate_overnight":
            // Clear all leave (no previous leave)
            formData.escortedLeave = ASRLeaveState()
            formData.unescortedLeave = ASRLeaveState()

        default:
            break
        }
    }

    /// Apply 3h Proposed Management defaults based on leave type from 3a.
    /// Common to all: exclusion zone N/A, all pre-leave checked, all on-return checked, specific to patient checked.
    private func apply3hDefaults(leaveType: String) {
        // Common to all: exclusion zone N/A
        formData.proceduresExclusionZone = "na"
        formData.proceduresExclusionDetails = ""

        // All pre-leave checkboxes checked
        formData.proceduresRiskFree = true
        formData.proceduresMentalState = true
        formData.proceduresEscortsConfirmed = true
        formData.proceduresNoDrugs = true
        formData.proceduresTimings = true

        // All on-return checkboxes checked
        formData.proceduresSearch = true
        formData.proceduresDrugTesting = true
        formData.proceduresBreachSuspension = true
        formData.proceduresBreachInformMOJ = true

        // Specific to patient checked
        formData.proceduresSpecificToPatient = true

        // Clear all transport first
        formData.proceduresTransportSecure = false
        formData.proceduresTransportHospital = false
        formData.proceduresTransportTaxi = false
        formData.proceduresTransportPublic = false

        // Apply leave-type specific defaults
        switch leaveType {
        case "compassionate_day", "compassionate_overnight":
            // Escorts: 2, Transport: Hospital only
            formData.proceduresEscorts = "2"
            formData.proceduresTransportHospital = true

        case "escorted_day":
            // Escorts: 1, Transport: Hospital, Taxi, Public
            formData.proceduresEscorts = "1"
            formData.proceduresTransportHospital = true
            formData.proceduresTransportTaxi = true
            formData.proceduresTransportPublic = true

        case "escorted_overnight":
            // Escorts: nil, Transport: Hospital only
            formData.proceduresEscorts = ""
            formData.proceduresTransportHospital = true

        case "unescorted_day":
            // Escorts: nil, Transport: Hospital, Taxi, Public
            formData.proceduresEscorts = ""
            formData.proceduresTransportHospital = true
            formData.proceduresTransportTaxi = true
            formData.proceduresTransportPublic = true

        case "unescorted_overnight":
            // Escorts: nil, Transport: Hospital only
            formData.proceduresEscorts = ""
            formData.proceduresTransportHospital = true

        default:
            break
        }
    }
}

// MARK: - Helper Components

/// Treatment understanding/compliance row for attitude section
struct TreatmentRow: View {
    let label: String
    @Binding var understanding: String
    @Binding var compliance: String
    let understandingOptions: [String]
    let complianceOptions: [String]

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .frame(width: 100, alignment: .leading)
            Picker("", selection: $understanding) {
                ForEach(understandingOptions, id: \.self) { option in
                    Text(option.isEmpty ? "Select..." : option).tag(option)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 100)
            Picker("", selection: $compliance) {
                ForEach(complianceOptions, id: \.self) { option in
                    Text(option.isEmpty ? "Select..." : option).tag(option)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 100)
        }
    }
}

/// Relationship quality slider
struct RelationshipSlider: View {
    let label: String
    @Binding var value: Int
    let labels: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .frame(width: 80, alignment: .leading)
                Slider(value: Binding(
                    get: { Double(value) },
                    set: { value = Int($0) }
                ), in: 0...Double(labels.count - 1), step: 1)
                Text(labels[min(value, labels.count - 1)])
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.blue)
                    .frame(width: 80, alignment: .trailing)
            }
        }
    }
}

/// Risk level selection row
struct RiskLevelRow: View {
    let label: String
    @Binding var value: Int
    let labels: [String]

    private let colors: [Color] = [.gray, .green, .orange, .red]

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .frame(width: 140, alignment: .leading)
            Picker("", selection: $value) {
                ForEach(0..<labels.count, id: \.self) { index in
                    Text(labels[index]).tag(index)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 200)
            Circle()
                .fill(colors[min(value, colors.count - 1)])
                .frame(width: 12, height: 12)
        }
    }
}

/// Risk level row that syncs Current to Historical when Current is set
struct RiskLevelRowWithSync: View {
    let label: String
    @Binding var currentValue: Int
    @Binding var historicalValue: Int
    let labels: [String]

    private let colors: [Color] = [.gray, .green, .orange, .red]

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .frame(width: 140, alignment: .leading)
            Picker("", selection: Binding(
                get: { currentValue },
                set: { newValue in
                    currentValue = newValue
                    // Sync to historical: if current > historical, update historical
                    if newValue > historicalValue {
                        historicalValue = newValue
                    }
                }
            )) {
                ForEach(0..<labels.count, id: \.self) { index in
                    Text(labels[index]).tag(index)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 200)
            Circle()
                .fill(colors[min(currentValue, colors.count - 1)])
                .frame(width: 12, height: 12)
        }
    }
}

/// Risk understanding row with understanding level and engagement sliders
struct RiskUnderstandingRow: View {
    let label: String
    let riskKey: String
    @Binding var understandingLevels: [String: Int]
    @Binding var engagementLevels: [String: Int]

    let understandingOptions = ["Poor", "Fair", "Good"]
    let engagementOptions = ["None", "Started", "Ongoing", "Advanced", "Complete"]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.purple)

            HStack(spacing: 12) {
                // Understanding slider
                VStack(alignment: .leading, spacing: 2) {
                    Text("Understanding")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack {
                        Slider(value: Binding(
                            get: { Double(understandingLevels[riskKey] ?? 1) },
                            set: { understandingLevels[riskKey] = Int($0) }
                        ), in: 0...2, step: 1)
                        Text(understandingOptions[understandingLevels[riskKey] ?? 1])
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.purple)
                            .frame(width: 40)
                    }
                }

                // Engagement slider
                VStack(alignment: .leading, spacing: 2) {
                    Text("Engagement")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack {
                        Slider(value: Binding(
                            get: { Double(engagementLevels[riskKey] ?? 2) },
                            set: { engagementLevels[riskKey] = Int($0) }
                        ), in: 0...4, step: 1)
                        Text(engagementOptions[engagementLevels[riskKey] ?? 2])
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.purple)
                            .frame(width: 60)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

/// Stabilising/Destabilising factors section
struct StabilisingFactorsSection: View {
    @Binding var stabilisingFactors: [String]
    @Binding var destabilisingFactors: [String]
    @State private var isStabilising: Bool = true

    let factors: [(key: String, stab: String, destab: String)] = [
        ("substance", "No substance misuse", "Substance misuse"),
        ("relationships", "Strong relationships", "Poor relationships"),
        ("family", "No family stress", "Family stress"),
        ("compliance", "Medication compliance", "Medication non-compliance"),
        ("physical", "Good physical health", "Poor physical health"),
        ("financial", "Financial stability", "Financial problems"),
        ("mha", "MHA provision in place", "Absence of MHA provision"),
        ("cmht", "CMHT engagement", "Lack of CMHT engagement"),
        ("accommodation", "Supported accommodation", "Social stress/housing instability")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Toggle between Stabilising and Destabilising
            HStack(spacing: 16) {
                Button(action: { isStabilising = true }) {
                    Text("Stabilising")
                        .font(.subheadline.weight(isStabilising ? .bold : .regular))
                        .foregroundColor(isStabilising ? .white : .green)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(isStabilising ? Color.green : Color.clear)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.green, lineWidth: 1))
                }
                Button(action: { isStabilising = false }) {
                    Text("Destabilising")
                        .font(.subheadline.weight(!isStabilising ? .bold : .regular))
                        .foregroundColor(!isStabilising ? .white : .red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(!isStabilising ? Color.red : Color.clear)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.red, lineWidth: 1))
                }
                Spacer()
            }

            // Factor checkboxes
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(factors, id: \.key) { factor in
                    let label = isStabilising ? factor.stab : factor.destab
                    let binding: Binding<Bool> = Binding(
                        get: {
                            if isStabilising {
                                return stabilisingFactors.contains(factor.stab)
                            } else {
                                return destabilisingFactors.contains(factor.destab)
                            }
                        },
                        set: { isOn in
                            if isStabilising {
                                if isOn {
                                    if !stabilisingFactors.contains(factor.stab) {
                                        stabilisingFactors.append(factor.stab)
                                    }
                                } else {
                                    stabilisingFactors.removeAll { $0 == factor.stab }
                                }
                            } else {
                                if isOn {
                                    if !destabilisingFactors.contains(factor.destab) {
                                        destabilisingFactors.append(factor.destab)
                                    }
                                } else {
                                    destabilisingFactors.removeAll { $0 == factor.destab }
                                }
                            }
                        }
                    )
                    Toggle(label, isOn: binding)
                        .toggleStyle(CheckboxToggleStyle())
                        .font(.caption)
                }
            }
        }
    }
}

/// Psychology slider row (generic labeled slider)
struct PsychologySlider: View {
    let label: String
    @Binding var value: Int
    let options: [String]
    var color: Color = .purple

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.subheadline)
            HStack {
                Slider(value: Binding(
                    get: { Double(value) },
                    set: { value = Int($0) }
                ), in: 0...Double(options.count - 1), step: 1)
                Text(options[min(value, options.count - 1)])
                    .font(.caption.weight(.semibold))
                    .foregroundColor(color)
                    .frame(width: 100, alignment: .trailing)
            }
        }
    }
}

/// Physical health condition category with collapsible checkboxes
struct PhysicalHealthCategory: View {
    let title: String
    let conditions: [String]
    @Binding var selected: [String]
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                    if !selected.isEmpty {
                        Text("(\(selected.count))")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(conditions, id: \.self) { condition in
                        Toggle(condition, isOn: Binding(
                            get: { selected.contains(condition) },
                            set: { isOn in
                                if isOn {
                                    if !selected.contains(condition) {
                                        selected.append(condition)
                                    }
                                } else {
                                    selected.removeAll { $0 == condition }
                                }
                            }
                        ))
                        .toggleStyle(CheckboxToggleStyle())
                        .font(.caption)
                    }
                }
                .padding(.leading, 20)
            }
        }
    }
}

/// Behaviour row with Yes/No/Select picker and details field
struct BehaviourRow: View {
    let label: String
    @Binding var value: String
    @Binding var details: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Picker("", selection: $value) {
                    Text("Select...").tag("")
                    Text("Yes").tag("yes")
                    Text("No").tag("no")
                }
                .pickerStyle(.menu)
                .frame(width: 100)
            }
            if value == "yes" {
                TextField("Details...", text: $details)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
            }
        }
    }
}

// MARK: - Leave Type Selection Sheet
struct LeaveTypeSelectionSheet: View {
    @Binding var selectedType: MOJLeaveFormView.ImportLeaveType
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Select the type of leave you are applying for, then upload your data.\n\nThe form will be auto-populated based on your selection.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(spacing: 8) {
                    ForEach(MOJLeaveFormView.ImportLeaveType.allCases) { leaveType in
                        Button {
                            selectedType = leaveType
                        } label: {
                            HStack {
                                Image(systemName: selectedType == leaveType ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedType == leaveType ? .blue : .gray)
                                Text(leaveType.rawValue)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedType == leaveType ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
                            )
                        }
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 20)
            .navigationTitle("Import Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Upload & Generate") { onConfirm() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Leave Narrative Summary Section (matching Tribunal Section 14 style)

/// Generates and displays a clinical narrative summary for Section 4d Attitude & Behaviour
/// Matches the desktop Leave Section 4d narrative summary style
struct LeaveNarrativeSummarySection: View {
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
    MOJLeaveFormView()
        .environment(AppStore())
        .environment(SharedDataStore.shared)
}
