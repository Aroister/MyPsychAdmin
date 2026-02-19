//
//  GeneralPsychReportView.swift
//  MyPsychAdmin
//
//  General Psychiatric Report Form for iOS
//  Based on desktop general_psychiatric_report_page.py structure (14 sections)
//  Uses same card/popup layout pattern as MOJASRFormView
//

import SwiftUI
import UniformTypeIdentifiers
import Combine

struct GeneralPsychReportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var appStore
    @Environment(SharedDataStore.self) private var sharedData

    @State private var formData: GPRFormData
    @State private var validationErrors: [FormValidationError] = []

    // Card text content - split into generated (from controls) and manual notes
    @State private var generatedTexts: [GPRSection: String] = [:]
    @State private var manualNotes: [GPRSection: String] = [:]

    // Popup control
    @State private var activePopup: GPRSection? = nil

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
    @State private var isPopulatingNotes = false
    @State private var isReportMode = false

    // 14 Sections matching desktop General Psychiatric Report order
    enum GPRSection: String, CaseIterable, Identifiable {
        case patientDetails = "1. Patient Details"
        case reportBasedOn = "2. Report Based On"
        case circumstances = "3. Circumstances to this Admission"
        case background = "4. Background Information"
        case medicalHistory = "5. Past Medical History"
        case psychiatricHistory = "6. Past Psychiatric History"
        case risk = "7. Risk"
        case substanceUse = "8. History of Substance Use"
        case forensicHistory = "9. Forensic History"
        case medication = "10. Medication"
        case diagnosis = "11. Mental Disorder"
        case legalCriteria = "12. Legal Criteria for Detention"
        case strengths = "13. Strengths"
        case signature = "14. Signature"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .patientDetails: return "person"
            case .reportBasedOn: return "doc.text.magnifyingglass"
            case .circumstances: return "arrow.right.circle"
            case .background: return "person.2"
            case .medicalHistory: return "heart.text.square"
            case .psychiatricHistory: return "clock.arrow.circlepath"
            case .risk: return "exclamationmark.shield"
            case .substanceUse: return "pills"
            case .forensicHistory: return "building.columns"
            case .medication: return "cross.case"
            case .diagnosis: return "stethoscope"
            case .legalCriteria: return "scale.3d"
            case .strengths: return "star"
            case .signature: return "signature"
            }
        }

        var defaultHeight: CGFloat {
            switch self {
            case .patientDetails, .reportBasedOn, .signature: return 120
            case .psychiatricHistory, .risk: return 200
            case .medication, .diagnosis: return 180
            default: return 150
            }
        }
    }

    /// Session cache — persists GPR state across sheet open/close cycles
    private final class SessionCache {
        static let shared = SessionCache()
        var formData: GPRFormData?
        var generatedTexts: [GPRSection: String]?
        var manualNotes: [GPRSection: String]?
        var isReportMode = false
        var hasPopulatedFromSharedData = false
    }

    init() {
        let cache = SessionCache.shared
        _formData = State(initialValue: cache.formData ?? GPRFormData())
        _generatedTexts = State(initialValue: cache.generatedTexts ?? [:])
        _manualNotes = State(initialValue: cache.manualNotes ?? [:])
        _isReportMode = State(initialValue: cache.isReportMode)
        _hasPopulatedFromSharedData = State(initialValue: cache.hasPopulatedFromSharedData)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Transparent header bar
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Text("General Psychiatric Report")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                HStack(spacing: 16) {
                    if let message = importStatusMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    if isImporting {
                        ProgressView().progressViewStyle(.circular)
                    } else {
                        Button { showingImportPicker = true } label: {
                            Image(systemName: "square.and.arrow.down")
                        }
                    }
                    if isExporting {
                        ProgressView()
                    } else {
                        Button { exportDOCX() } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)

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
                    ForEach(GPRSection.allCases) { section in
                        GPREditableCard(
                            section: section,
                            text: binding(for: section),
                            onHeaderTap: { activePopup = section }
                        )
                    }
                }
                .padding()
            }
        }
        .background {
            Rectangle().fill(.thickMaterial).ignoresSafeArea()
        }
        .onAppear {
            prefillFromSharedData()
            initializeCardTexts()
            if !hasPopulatedFromSharedData && !sharedData.notes.isEmpty && !isReportMode {
                populateFromClinicalNotesAsync(sharedData.notes)
                hasPopulatedFromSharedData = true
            }
        }
        .onDisappear {
            // Save state to session cache so it persists across sheet open/close
            let cache = SessionCache.shared
            cache.formData = formData
            cache.generatedTexts = generatedTexts
            cache.manualNotes = manualNotes
            cache.isReportMode = isReportMode
            cache.hasPopulatedFromSharedData = hasPopulatedFromSharedData
        }
        .onReceive(sharedData.notesDidChange) { notes in
            if !notes.isEmpty && !isReportMode {
                populateFromClinicalNotesAsync(notes)
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
            GPRPopupView(
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

    private func binding(for section: GPRSection) -> Binding<String> {
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
        for section in GPRSection.allCases {
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
            formData.reportBy = appStore.clinicianInfo.fullName
            formData.signatureName = appStore.clinicianInfo.fullName
            formData.signatureDesignation = appStore.clinicianInfo.roleTitle
            formData.signatureQualifications = appStore.clinicianInfo.discipline
            formData.signatureRegNumber = appStore.clinicianInfo.registrationNumber
            formData.currentLocation = appStore.clinicianInfo.hospitalOrg
        }
    }

    // Computed patient info combining form data with gender for gender-sensitive text generation
    private var combinedPatientInfo: PatientInfo {
        var info = PatientInfo()
        let names = formData.patientName.components(separatedBy: " ")
        info.firstName = names.first ?? ""
        info.lastName = names.dropFirst().joined(separator: " ")
        info.gender = formData.patientGender
        info.dateOfBirth = formData.patientDOB
        return info
    }

    private func exportDOCX() {
        isExporting = true
        exportError = nil

        // Collect section content keyed by GPRSection rawValue
        var sectionContent: [String: String] = [:]
        for section in GPRSection.allCases {
            let generated = generatedTexts[section] ?? ""
            let manual = manualNotes[section] ?? ""
            let text: String
            if generated.isEmpty && manual.isEmpty {
                text = ""
            } else if generated.isEmpty {
                text = manual
            } else if manual.isEmpty {
                text = generated
            } else {
                text = generated + "\n\n" + manual
            }
            sectionContent[section.rawValue] = text
        }

        // Capture form state for background thread
        let patientName = formData.patientName
        let patientDOB = formData.patientDOB
        let patientGender = formData.patientGender
        let mhaSec = formData.mhaSection
        let location = formData.currentLocation
        let reportBy = formData.reportBy.isEmpty ? formData.signatureName : formData.reportBy
        let reportDate = Date()
        let admissionDate = formData.admissionDate
        let dateSeen = formData.dateSeen

        DispatchQueue.global(qos: .userInitiated).async {
            let exporter = GPRDOCXExporter(
                sectionContent: sectionContent,
                patientName: patientName,
                patientDOB: patientDOB,
                patientGender: patientGender,
                mhaSection: mhaSec,
                currentLocation: location,
                reportBy: reportBy,
                reportDate: reportDate,
                admissionDate: admissionDate,
                dateSeen: dateSeen
            )
            let data = exporter.generateDOCX()

            DispatchQueue.main.async {
                isExporting = false

                guard let docxData = data else {
                    exportError = "Failed to generate document"
                    return
                }

                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
                let timestamp = dateFormatter.string(from: Date())
                let safeName = patientName.replacingOccurrences(of: " ", with: "_")
                let filename = "GPR_\(safeName)_\(timestamp).docx"

                let tempDir = FileManager.default.temporaryDirectory
                let fileURL = tempDir.appendingPathComponent(filename)

                do {
                    try docxData.write(to: fileURL)
                    docxURL = fileURL
                    showShareSheet = true
                } catch {
                    exportError = "Failed to save: \(error.localizedDescription)"
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
                        // Patient info (always, regardless of report vs notes)
                        if !extractedDoc.patientInfo.fullName.isEmpty {
                            sharedData.setPatientInfo(extractedDoc.patientInfo, source: "gpr_import")
                            formData.patientName = extractedDoc.patientInfo.fullName
                            if let dob = extractedDoc.patientInfo.dateOfBirth {
                                formData.patientDOB = dob
                            }
                            formData.patientGender = extractedDoc.patientInfo.gender
                        }

                        // Report detection gate
                        let sections = Self.isGPRReport(extractedDoc)
                            ? parseGPRReportSections(from: extractedDoc.text)
                            : [:]

                        if !sections.isEmpty {
                            // REPORT PATH — imported document is a previous report
                            populateFromReport(sections)
                            importStatusMessage = "Imported report (\(sections.count) sections)"
                        } else {
                            // NOTES PATH — imported document is clinical notes
                            if !extractedDoc.notes.isEmpty {
                                sharedData.setNotes(extractedDoc.notes, source: "gpr_import")
                            }
                            populateFromClinicalNotes(extractedDoc.notes)
                            importStatusMessage = "Imported \(extractedDoc.notes.count) notes"
                        }

                        isImporting = false
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

    /// Async wrapper to run population on background thread for better UI responsiveness
    private func populateFromClinicalNotesAsync(_ notes: [ClinicalNote]) {
        guard !notes.isEmpty else { return }
        guard !isReportMode else {
            print("[GPR iOS] Report mode active, skipping notes population")
            return
        }
        guard !isPopulatingNotes else {
            print("[GPR iOS] Already populating, skipping")
            return
        }

        isPopulatingNotes = true

        Task.detached(priority: .userInitiated) {
            // Perform heavy computation on background thread
            let result = await self.computePopulationData(notes)

            // Update UI on main thread
            await MainActor.run {
                self.applyPopulationResult(result)
                self.isPopulatingNotes = false
            }
        }
    }

    /// Background computation for note population
    private func computePopulationData(_ notes: [ClinicalNote]) async -> GPRPopulationResult {
        print("[GPR iOS] Computing population data from \(notes.count) clinical notes (background)")

        var result = GPRPopulationResult()
        let calendar = Calendar.current

        // Build timeline to find admissions
        let episodes = TimelineBuilder.buildTimeline(from: notes, allNotes: notes)
        let inpatientEpisodes = episodes.filter { $0.type == .inpatient }

        // Get most recent admission
        let mostRecentAdmission = inpatientEpisodes.last

        // === SECTION 6: Find admission clerkings ===
        // Desktop find_clerkings_rio EXACT LOGIC:
        // 1. Filter to MEDICAL notes only (type contains "med", "doctor", "clinician", "physician")
        // 2. Check for CLERKING_TRIGGERS in content OR ROLE_TRIGGERS in originator
        var seenClerkingKeys: Set<String> = []
        var allClerkingsForEpisode: [(date: Date, text: String, admissionDate: Date)] = []

        // Desktop CLERKING_TRIGGERS_RIO (content triggers)
        let clerkingTriggers = [
            "admission clerking", "clerking", "duty doctor admission",
            "new admission", "new transfer", "circumstances of admission",
            "circumstances leading to admission", "new client assessment"
        ]

        // Desktop ROLE_TRIGGERS_RIO (originator/content role triggers)
        let roleTriggers = [
            "physician associate", "medical", "senior house officer",
            "sho", "ct1", "ct2", "ct3", "st4", "doctor"
        ]

        for episode in inpatientEpisodes {
            let admissionStart = episode.start
            let windowEnd = calendar.date(byAdding: .day, value: 10, to: admissionStart) ?? admissionStart  // Desktop uses 10 days

            let windowNotes = notes.filter { note in
                let noteDay = calendar.startOfDay(for: note.date)
                return noteDay >= admissionStart && noteDay <= windowEnd
            }.sorted { $0.date < $1.date }

            // Desktop: Filter to MEDICAL notes ONLY first
            // is_medical_type checks: "med" in t or "doctor" in t or "clinician" in t or "physician" in t
            let medicalNotes = windowNotes.filter { note in
                let typeLower = note.type.lowercased()
                return typeLower.contains("med") ||
                       typeLower.contains("doctor") ||
                       typeLower.contains("clinician") ||
                       typeLower.contains("physician")
            }

            print("[GPR iOS] Window \(admissionStart) -> \(windowEnd): \(windowNotes.count) notes, \(medicalNotes.count) medical")

            var firstClerkingDate: Date? = nil
            for note in medicalNotes {
                let bodyLower = note.body.lowercased()

                // Check for clerking triggers in content
                let hasClerkingTrigger = clerkingTriggers.contains { trigger in
                    bodyLower.contains(trigger)
                }

                // Check for role triggers in author (fallback) - desktop uses "originator", iOS uses "author"
                let authorLower = note.author.lowercased()
                let hasRoleTriggerInAuthor = roleTriggers.contains { role in
                    authorLower.contains(role)
                }

                // Desktop logic: note must have clerking trigger OR author role trigger
                if !hasClerkingTrigger && !hasRoleTriggerInAuthor {
                    continue
                }

                let key = "\(calendar.startOfDay(for: note.date))-\(String(note.body.prefix(120)))"
                if !seenClerkingKeys.contains(key) {
                    seenClerkingKeys.insert(key)
                    allClerkingsForEpisode.append((date: note.date, text: note.body, admissionDate: admissionStart))
                    if firstClerkingDate == nil {
                        firstClerkingDate = note.date
                    }
                    print("[GPR iOS] Found MEDICAL clerking: \(note.body.count) chars, type=\(note.type), trigger=\(hasClerkingTrigger), author=\(hasRoleTriggerInAuthor)")
                }
            }

            // FALLBACK: If no medical clerkings found for THIS episode, try ALL window notes with history sections
            let foundInThisEpisode = allClerkingsForEpisode.contains { $0.admissionDate == admissionStart }
            if !foundInThisEpisode {
                print("[GPR iOS] No medical clerkings found for episode \(admissionStart), trying fallback...")
                for note in windowNotes {
                    let bodyLower = note.body.lowercased()

                    // Check for history section headers - more flexible matching
                    // Check both newline prefix AND start of note
                    let hasPersonalHistory = bodyLower.contains("\npersonal history") ||
                                             bodyLower.hasPrefix("personal history")
                    let hasBackgroundHistory = bodyLower.contains("\nbackground history") ||
                                               bodyLower.hasPrefix("background history")
                    let hasPastMedicalHistory = bodyLower.contains("\npast medical history") ||
                                                bodyLower.hasPrefix("past medical history")
                    let hasForensicHistory = bodyLower.contains("\nforensic history") ||
                                             bodyLower.hasPrefix("forensic history")
                    let hasMSE = bodyLower.contains("\nmental state examination") ||
                                 bodyLower.hasPrefix("mental state examination") ||
                                 bodyLower.contains("\nmse") ||
                                 bodyLower.hasPrefix("mse")

                    let hasHistorySection = hasPersonalHistory || hasBackgroundHistory ||
                                            hasPastMedicalHistory || hasForensicHistory || hasMSE

                    // Note is a clerking if it has history sections AND is substantial (>500 chars)
                    let isSubstantial = note.body.count > 500
                    if hasHistorySection && isSubstantial {
                        let key = "\(calendar.startOfDay(for: note.date))-\(String(note.body.prefix(120)))"
                        if !seenClerkingKeys.contains(key) {
                            seenClerkingKeys.insert(key)
                            allClerkingsForEpisode.append((date: note.date, text: note.body, admissionDate: admissionStart))
                            if firstClerkingDate == nil {
                                firstClerkingDate = note.date
                            }
                            print("[GPR iOS] Found FALLBACK clerking: \(note.body.count) chars, type=\(note.type), hasPersonal=\(hasPersonalHistory)")
                        }
                    }
                }
            }

            let clerkingNoteDate = firstClerkingDate
            let adjustedAdmissionDate = clerkingNoteDate ?? episode.start

            let today = calendar.startOfDay(for: Date())
            let episodeEndDay = calendar.startOfDay(for: episode.end)
            let isOngoing = episodeEndDay >= today

            let durationStr: String
            let days = calendar.dateComponents([.day], from: adjustedAdmissionDate, to: episode.end).day ?? 0
            if isOngoing {
                durationStr = "Ongoing"
            } else if days < 30 {
                durationStr = "\(days) days"
            } else {
                let months = days / 30
                let remainDays = days % 30
                if remainDays > 0 {
                    durationStr = "\(months) months, \(remainDays) days"
                } else {
                    durationStr = "\(months) months"
                }
            }

            result.admissionsTableData.append(GPRAdmissionEntry(
                admissionDate: adjustedAdmissionDate,
                dischargeDate: isOngoing ? nil : episode.end,
                duration: durationStr
            ))
        }

        // GLOBAL FALLBACK: If still no clerkings found, search ALL notes for Personal history sections
        if allClerkingsForEpisode.isEmpty {
            print("[GPR iOS] GLOBAL FALLBACK: No clerkings found, searching ALL notes for Personal history...")
            for note in notes {
                let bodyLower = note.body.lowercased()

                // Check for Personal history section (the key indicator of a detailed clerking)
                let hasPersonalHistory = bodyLower.contains("\npersonal history") ||
                                         bodyLower.contains("personal history:") ||
                                         bodyLower.hasPrefix("personal history")

                if hasPersonalHistory && note.body.count > 500 {
                    let key = "\(calendar.startOfDay(for: note.date))-\(String(note.body.prefix(120)))"
                    if !seenClerkingKeys.contains(key) {
                        seenClerkingKeys.insert(key)
                        allClerkingsForEpisode.append((date: note.date, text: note.body, admissionDate: note.date))
                        print("[GPR iOS] GLOBAL FALLBACK: Found note with Personal history: \(note.body.count) chars, type=\(note.type)")
                    }
                }
            }
        }

        print("[GPR iOS] Total clerkings found: \(allClerkingsForEpisode.count)")

        // Store clerkings as GPRImportedEntry
        for clerking in allClerkingsForEpisode {
            result.clerkingNotes.append(GPRImportedEntry(
                date: clerking.date,
                text: clerking.text,
                snippet: String(clerking.text.prefix(200)),
                categories: ["Clerking"]
            ))
        }

        // === Process notes for various sections ===
        for note in notes {
            // Risk incidents - use contextual detection matching desktop
            if let riskResult = GPRCategoryKeywords.categorizeRiskIncidentWithContext(note.body) {
                let contextSnippet = riskResult.context.count > 150 ? String(riskResult.context.prefix(150)) + "..." : riskResult.context
                result.riskImportedEntries.append(GPRImportedEntry(
                    date: note.date,
                    text: riskResult.context,
                    snippet: contextSnippet,
                    categories: riskResult.categories
                ))
            }

            // NOTE: Background is extracted from CLERKINGS only (like desktop), not all notes
            // See the clerkings loop below for background extraction

            // NOTE: Medical history is extracted from CLERKINGS only (like desktop), not all notes
            // See the clerkings loop below for medical history extraction

            // Substance use with highlighting
            if let substanceResult = GPRCategoryKeywords.categorizeSubstanceWithContext(note.body) {
                let contextSnippet = substanceResult.context.count > 150 ? String(substanceResult.context.prefix(150)) + "..." : substanceResult.context
                result.substanceUseImported.append(GPRImportedEntry(
                    date: note.date,
                    text: substanceResult.context,
                    snippet: contextSnippet,
                    categories: substanceResult.categories
                ))
            }
        }

        // Forensic history from clerkings
        let forensicHeadings = ["forensic history", "forensic", "offence", "offending", "criminal", "police", "charges", "index offence"]
        for clerking in result.clerkingNotes {
            if let forensicSection = extractSectionStatic(from: clerking.text, sectionHeadings: forensicHeadings) {
                result.forensicHistoryImported.append(GPRImportedEntry(
                    date: clerking.date,
                    text: forensicSection,
                    snippet: String(forensicSection.prefix(200)),
                    categories: ["Forensic"]
                ))
            }
        }

        // Background history from CLERKINGS ONLY (matching desktop and Section 5 approach)
        // Desktop extracts from admission clerkings which have detailed "Personal history:" sections
        // CPA review notes have "Relevant Social History" which we want to SKIP
        print("[GPR iOS] Extracting background from \(result.clerkingNotes.count) clerkings only")

        // Use specific headings that appear in actual clerkings, NOT CPA review templates
        // "Personal history:" is in clerkings, "Relevant Social History" is in CPA reviews
        let backgroundHeadings = [
            "personal history", "background history", "family history",
            "developmental history", "early history", "past and personal history",
            "personal and social history"
        ]

        for clerking in result.clerkingNotes {
            if let bgSection = extractSectionStatic(from: clerking.text, sectionHeadings: backgroundHeadings) {
                // Only keep sections with substantial content (>200 chars for background)
                if bgSection.count > 200 {
                    let bgCategories = GPRCategoryKeywords.categorize(bgSection, using: GPRCategoryKeywords.background)
                    result.backgroundImportedEntries.append(GPRImportedEntry(
                        date: clerking.date,
                        text: bgSection,
                        snippet: String(bgSection.prefix(200)),
                        categories: bgCategories.isEmpty ? ["Background"] : bgCategories
                    ))
                    print("[GPR iOS] Found background in clerking: \(bgSection.count) chars")
                }
            }
        }

        // Sort by length (longest first) to prioritize most detailed
        result.backgroundImportedEntries.sort { $0.text.count > $1.text.count }

        print("[GPR iOS] Found \(result.backgroundImportedEntries.count) background entries from clerkings")

        // ADDITIONAL: Search ALL notes for Personal history sections (to find more background entries)
        // This expands beyond just clerkings to catch any note with detailed personal history
        var seenBackgroundTexts = Set(result.backgroundImportedEntries.map { String($0.text.prefix(200)) })
        for note in notes {
            if let bgSection = extractSectionStatic(from: note.body, sectionHeadings: backgroundHeadings) {
                // Only keep substantial sections (>200 chars) that aren't duplicates
                let textKey = String(bgSection.prefix(200))
                if bgSection.count > 200 && !seenBackgroundTexts.contains(textKey) {
                    // Skip CPA review template content
                    let bgLower = bgSection.lowercased()
                    let isCPATemplate = bgLower.contains("relevant social history") ||
                                        bgLower.contains("daily function") ||
                                        bgLower.contains("current illegal drugs")
                    if !isCPATemplate {
                        seenBackgroundTexts.insert(textKey)
                        let bgCategories = GPRCategoryKeywords.categorize(bgSection, using: GPRCategoryKeywords.background)
                        result.backgroundImportedEntries.append(GPRImportedEntry(
                            date: note.date,
                            text: bgSection,
                            snippet: String(bgSection.prefix(200)),
                            categories: bgCategories.isEmpty ? ["Background"] : bgCategories
                        ))
                        print("[GPR iOS] Found ADDITIONAL background in note: \(bgSection.count) chars")
                    }
                }
            }
        }

        // Re-sort by length after adding more entries
        result.backgroundImportedEntries.sort { $0.text.count > $1.text.count }
        print("[GPR iOS] Total background entries after broad search: \(result.backgroundImportedEntries.count)")

        // Medical history from clerkings ONLY (matching desktop approach)
        // Desktop extracts medical history from admission clerkings, NOT all notes
        print("[GPR iOS] Extracting medical history from \(result.clerkingNotes.count) clerkings (not all notes)")
        let medHistoryHeadings = [
            "past medical history", "medical history", "pmh",
            "physical health", "physical hx", "physical health history",
            "comorbidities", "comorbid", "physical examination", "ecg"
        ]
        let psyExclusionTerms = [
            "delusion", "delusional", "hallucination", "hallucinating",
            "insight", "thought", "affect", "mood", "mental state", "mse",
            "behaviour", "behavior", "psychotic", "paranoid"
        ]
        for clerking in result.clerkingNotes {
            if let pmhSection = extractSectionStatic(from: clerking.text, sectionHeadings: medHistoryHeadings) {
                // Apply PHYSICAL HEALTH PRECISION GUARD
                let pmhLower = pmhSection.lowercased()
                let hasPsychContent = psyExclusionTerms.contains { pmhLower.contains($0) }

                if !hasPsychContent {
                    let medCategories = GPRCategoryKeywords.categorize(pmhSection, using: GPRCategoryKeywords.medicalHistory)
                    result.medicalHistoryImported.append(GPRImportedEntry(
                        date: clerking.date,
                        text: pmhSection,
                        snippet: String(pmhSection.prefix(200)),
                        categories: medCategories.isEmpty ? ["Medical History"] : medCategories
                    ))
                    print("[GPR iOS] Found PMH in clerking: \(String(pmhSection.prefix(60)))...")
                }
            }
        }
        print("[GPR iOS] Found \(result.medicalHistoryImported.count) medical history entries from clerkings")

        // Circumstances - ALL notes from the last admission period (matching desktop TribunalProgressPopup)
        // Desktop: Uses notes from admission start to end of admission OR admission + 14 days (whichever is later)
        if let lastAdmission = mostRecentAdmission {
            let admissionStart = lastAdmission.start
            let admissionEnd = lastAdmission.end
            // Use the full admission period, or at least 14 days from admission
            let minWindowEnd = calendar.date(byAdding: .day, value: 14, to: admissionStart) ?? admissionStart
            let windowEnd = max(admissionEnd, minWindowEnd)

            let circumstancesNotes = notes.filter { note in
                return note.date >= admissionStart && note.date <= windowEnd
            }.sorted { $0.date < $1.date }

            print("[GPR iOS] Circumstances: Using last admission period \(admissionStart) to \(windowEnd), found \(circumstancesNotes.count) notes")

            for note in circumstancesNotes {
                result.circumstancesImported.append(GPRImportedEntry(
                    date: note.date,
                    text: note.body,
                    snippet: String(note.body.prefix(150)),
                    categories: ["Admission Period"]
                ))
            }
        }

        // Psychiatric history from admission clerkings
        let psychHistoryHeadings = ["past psychiatric history", "psychiatric history", "mental health history", "pph"]
        for clerking in result.clerkingNotes {
            if let psychSection = extractSectionStatic(from: clerking.text, sectionHeadings: psychHistoryHeadings) {
                result.psychiatricHistoryImported.append(GPRImportedEntry(
                    date: clerking.date,
                    text: psychSection,
                    snippet: String(psychSection.prefix(150)),
                    categories: ["Psychiatric History"]
                ))
            }
        }

        // Medications - extract from ALL notes for imported, last year for prefill
        let extractor = MedicationExtractor.shared
        let allExtracted = extractor.extractMedications(from: notes)

        for drug in allExtracted.drugs {
            let category = drug.psychiatricSubtype?.rawValue ?? drug.category.rawValue
            for mention in drug.mentions {
                var displayText = drug.name
                if let dose = mention.dose { displayText += " \(dose)" }
                if let freq = mention.frequency { displayText += " \(freq.uppercased())" }

                let snippet = mention.context.count > 100 ? String(mention.context.prefix(100)) + "..." : mention.context

                result.medicationImported.append(GPRImportedEntry(
                    date: mention.date,
                    text: displayText,
                    snippet: snippet,
                    categories: [category]
                ))
            }
        }
        result.medicationImported.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }

        // Prefill medications from last year only
        let oneYearAgo = calendar.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        let recentNotes = notes.filter { $0.date >= oneYearAgo }
        let recentExtracted = extractor.extractMedications(from: recentNotes)

        let subtypePriority: [PsychSubtype] = [.antipsychotic, .antidepressant, .antimanic, .hypnotic, .anticholinergic, .other]
        for subtype in subtypePriority {
            let drugsOfType = recentExtracted.psychiatricDrugs.filter { $0.psychiatricSubtype == subtype }
            if let mostRecent = drugsOfType.max(by: { ($0.latestDate ?? .distantPast) < ($1.latestDate ?? .distantPast) }) {
                var entry = GPRMedicationEntry()
                entry.name = mostRecent.name
                entry.dose = mostRecent.latestDose ?? ""
                if let freq = mostRecent.mentions.last?.frequency?.lowercased() {
                    switch freq {
                    case "od", "daily", "once": entry.frequency = "OD"
                    case "bd", "twice": entry.frequency = "BD"
                    case "tds": entry.frequency = "TDS"
                    case "qds", "qid": entry.frequency = "QDS"
                    case "nocte", "on", "night": entry.frequency = "Nocte"
                    case "prn": entry.frequency = "PRN"
                    case "weekly": entry.frequency = "Weekly"
                    case "fortnightly": entry.frequency = "Fortnightly"
                    case "monthly": entry.frequency = "Monthly"
                    default: entry.frequency = "OD"
                    }
                }
                result.medications.append(entry)
            }
        }
        if result.medications.isEmpty {
            result.medications.append(GPRMedicationEntry())
        }

        // === DIAGNOSIS (Section 11) - Extract ICD-10 diagnoses from notes ===
        // Track all found diagnoses with their dates for imported section
        var diagnosisFindings: [(date: Date, diagnosis: ICD10Diagnosis, context: String)] = []

        for note in notes {
            let extractions = ICD10Diagnosis.extractFromText(note.body)
            for extraction in extractions {
                diagnosisFindings.append((date: note.date, diagnosis: extraction.diagnosis, context: extraction.context))

                // Add to imported entries
                // text = full note body (shown when expanded)
                // snippet = diagnosis code + brief context (shown when collapsed)
                let snippetText = "[\(extraction.diagnosis.code)] " + (extraction.context.count > 120 ? String(extraction.context.prefix(120)) + "..." : extraction.context)
                result.diagnosisImported.append(GPRImportedEntry(
                    date: note.date,
                    text: note.body,
                    snippet: snippetText,
                    categories: [extraction.diagnosis.code]
                ))
            }
        }

        // Sort imported by date (newest first)
        result.diagnosisImported.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }

        // === Pre-fill with unique diagnoses from different categories ===
        // Group diagnoses by category and track best (most recent, highest severity) per category
        // Categories based on ICD-10 code prefix to avoid duplicates like multiple schizophrenia variants

        // Helper to get diagnostic category from ICD-10 code
        func getDiagnosticCategory(_ diagnosis: ICD10Diagnosis) -> String {
            let code = diagnosis.code.uppercased()
            // F20-F29: Schizophrenia/Psychosis spectrum (treat all F2x psychotic disorders as one category)
            if code.hasPrefix("F20") || code.hasPrefix("F21") || code.hasPrefix("F22") ||
               code.hasPrefix("F23") || code.hasPrefix("F24") || code.hasPrefix("F25") ||
               code.hasPrefix("F28") || code.hasPrefix("F29") {
                return "Psychosis"
            }
            // F30-F39: Mood disorders (bipolar and depression are one category)
            if code.hasPrefix("F30") || code.hasPrefix("F31") || code.hasPrefix("F32") ||
               code.hasPrefix("F33") || code.hasPrefix("F34") || code.hasPrefix("F38") || code.hasPrefix("F39") {
                return "Mood"
            }
            // F40-F48: Anxiety/Neurotic disorders
            if code.hasPrefix("F4") { return "Anxiety" }
            // F50: Eating disorders
            if code.hasPrefix("F50") { return "Eating" }
            // F60-F69: Personality disorders
            if code.hasPrefix("F6") { return "Personality" }
            // F70-F79: Intellectual disability
            if code.hasPrefix("F7") { return "IntellectualDisability" }
            // F00-F09: Organic disorders
            if code.hasPrefix("F0") { return "Organic" }
            // F10-F19: Substance use disorders
            if code.hasPrefix("F1") && !code.hasPrefix("F20") { return "Substance" }
            return "Other"
        }

        // Helper to get severity (4=highest for psychosis/severe mood, 1=lowest)
        func getDiagnosisSeverity(_ diagnosis: ICD10Diagnosis) -> Int {
            let code = diagnosis.code.uppercased()
            // Severity 4: Schizophrenia, Schizoaffective, Bipolar, Mania, Severe depression with psychosis
            if code.hasPrefix("F20") || code.hasPrefix("F21") || code.hasPrefix("F22") ||
               code.hasPrefix("F23") || code.hasPrefix("F24") || code.hasPrefix("F25") ||
               code.hasPrefix("F28") || code.hasPrefix("F29") ||
               code.hasPrefix("F30") || code.hasPrefix("F31") ||
               code == "F32.3" || code == "F33.3" { // Severe depression with psychosis
                return 4
            }
            // Severity 3: Other mood, anxiety, personality, eating disorders
            if code.hasPrefix("F32") || code.hasPrefix("F33") || code.hasPrefix("F34") ||
               code.hasPrefix("F4") || code.hasPrefix("F50") || code.hasPrefix("F6") ||
               code.hasPrefix("F0") {
                return 3
            }
            // Severity 2: Substance use, mild mood
            if code.hasPrefix("F1") || code.hasPrefix("F38") || code.hasPrefix("F39") {
                return 2
            }
            return 1
        }

        // Group by category, keeping best (highest severity, most recent) per category
        var bestByCategory: [String: (diagnosis: ICD10Diagnosis, date: Date, severity: Int)] = [:]

        for finding in diagnosisFindings {
            let category = getDiagnosticCategory(finding.diagnosis)
            let severity = getDiagnosisSeverity(finding.diagnosis)

            if let existing = bestByCategory[category] {
                // Prefer higher severity, then more recent date
                if severity > existing.severity ||
                   (severity == existing.severity && finding.date > existing.date) {
                    bestByCategory[category] = (finding.diagnosis, finding.date, severity)
                }
            } else {
                bestByCategory[category] = (finding.diagnosis, finding.date, severity)
            }
        }

        // Sort categories by severity (descending) then by date (most recent)
        let sortedCategories = bestByCategory.sorted { a, b in
            if a.value.severity != b.value.severity {
                return a.value.severity > b.value.severity
            }
            return a.value.date > b.value.date
        }

        // Take top 3 from different categories
        if sortedCategories.count > 0 {
            result.diagnosis1ICD10 = sortedCategories[0].value.diagnosis
        }
        if sortedCategories.count > 1 {
            result.diagnosis2ICD10 = sortedCategories[1].value.diagnosis
        }
        if sortedCategories.count > 2 {
            result.diagnosis3ICD10 = sortedCategories[2].value.diagnosis
        }

        print("[GPR iOS] Found \(diagnosisFindings.count) diagnosis mentions, \(bestByCategory.count) unique categories")
        print("[GPR iOS] Background: \(result.backgroundImportedEntries.count) entries from CLERKINGS only")
        print("[GPR iOS] Medical history: \(result.medicalHistoryImported.count) entries from CLERKINGS only")
        print("[GPR iOS] Background computation complete")
        return result
    }

    /// Apply computed result to form data on main thread
    private func applyPopulationResult(_ result: GPRPopulationResult) {
        formData.psychiatricHistoryImported = result.psychiatricHistoryImported
        formData.riskImportedEntries = result.riskImportedEntries
        formData.backgroundImportedEntries = result.backgroundImportedEntries
        formData.medicalHistoryImported = result.medicalHistoryImported
        formData.substanceUseImported = result.substanceUseImported
        formData.forensicHistoryImported = result.forensicHistoryImported
        formData.medicationImported = result.medicationImported
        formData.circumstancesImported = result.circumstancesImported
        formData.admissionsTableData = result.admissionsTableData
        formData.clerkingNotes = result.clerkingNotes
        formData.medications = result.medications

        // Diagnosis
        formData.diagnosisImported = result.diagnosisImported
        formData.diagnosis1ICD10 = result.diagnosis1ICD10
        formData.diagnosis2ICD10 = result.diagnosis2ICD10
        formData.diagnosis3ICD10 = result.diagnosis3ICD10

        // Auto-populate risk levels
        autoPopulateRiskLevels()

        print("[GPR iOS] Applied population result to form data")
    }

    /// Static version of extractSection for background thread use
    /// Matches desktop history_extractor_sections.py _detect_header logic exactly
    private static func extractSectionStatic(from text: String, sectionHeadings: [String]) -> String? {
        let lines = text.components(separatedBy: .newlines)
        // Common headings that indicate section boundaries (matches desktop CATEGORIES_ORDERED and HARD_OVERRIDE_HEADINGS)
        // Also includes common RiO progress note section headers to detect boundaries
        let allHeadings = [
            // Clinical history sections
            "background history", "personal history", "social history", "family history",
            "developmental history", "early history", "past and personal history",
            "past psychiatric history", "psychiatric history", "mental health history", "pph",
            "history of presenting complaint", "presenting complaint", "hpc",
            "past medical history", "medical history", "pmh", "physical health",
            // Drug and alcohol headings
            "drug and alcohol", "drug and alcohol history", "drug history", "alcohol history",
            "substance use", "substance misuse", "substance", "illicit",
            // Forensic and clinical
            "forensic history", "forensic", "offence", "offending", "criminal", "police", "charges", "index offence",
            "mental state", "mse", "mental state examination", "risk", "impression", "plan", "diagnosis",
            "medication", "medication history", "current medication", "physical examination", "summary", "capacity", "ecg",
            // Common RiO progress note headers that END medical history sections
            "finances", "finance", "accommodation", "leave", "section", "legal status",
            "occupational therapy", "ot", "psychology", "nursing", "social work", "sw",
            "cpa", "care plan", "review", "follow up", "follow-up", "next steps",
            "actions", "outcome", "progress", "update", "contact", "telephone",
            "activities", "engagement", "presentation", "observations", "obs level",
            "safeguarding", "discharge", "transfer", "referral"
        ]

        // Helper to detect headers - matches desktop _detect_header exactly
        // Desktop logic: if ":" not in line and "-" not in line: if len(words) <= 2 and nl not in HEADER_LOOKUP: return None
        // Then checks: nl == term or nl.startswith(term)
        func isHeaderLine(_ line: String, for headings: [String]) -> String? {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let lower = trimmed.lowercased()
            let words = trimmed.split(separator: " ")

            // Desktop: lines without : or - must have <= 2 words to be considered headers
            // (unless they exactly match a known header)
            let hasColon = line.contains(":")
            let hasDash = line.contains("-")

            // Clean the line for matching (remove : and normalize -)
            let cleanedLine = lower
                .replacingOccurrences(of: ":", with: "")
                .replacingOccurrences(of: "-", with: " ")
                .trimmingCharacters(in: .whitespaces)

            for heading in headings {
                // Desktop: nl == term or nl.startswith(term)
                if cleanedLine == heading || cleanedLine.hasPrefix(heading + " ") || lower.hasPrefix(heading) {
                    return heading
                }
            }

            // For short lines (<=2 words) with colon/dash, also check if line starts with heading
            if (hasColon || hasDash) && words.count <= 4 {
                for heading in headings {
                    if cleanedLine.hasPrefix(heading) {
                        return heading
                    }
                }
            }

            return nil
        }

        var sectionStartLine: Int? = nil
        var matchedHeading: String? = nil

        // Find the line where our target section starts
        for (index, line) in lines.enumerated() {
            if let heading = isHeaderLine(line, for: sectionHeadings) {
                sectionStartLine = index
                matchedHeading = heading
                break
            }
        }

        guard let startLine = sectionStartLine, let heading = matchedHeading else { return nil }

        var sectionEndLine = lines.count

        // Find where the section ends (next header line)
        for index in (startLine + 1)..<lines.count {
            let line = lines[index]
            if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }

            if let nextHeading = isHeaderLine(line, for: allHeadings) {
                if nextHeading != heading {
                    sectionEndLine = index
                    break
                }
            }
        }

        // Get content AFTER the header line
        var contentLines = Array(lines[(startLine + 1)..<sectionEndLine])

        // IMPORTANT: Also extract any inline content from the header line itself
        // e.g., "Personal history: Ms Adeniyi was born..." - the content after ":" is on the same line
        let headerLine = lines[startLine]
        if let colonRange = headerLine.range(of: ":") {
            let afterColon = String(headerLine[colonRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            if !afterColon.isEmpty {
                // Prepend the inline content
                contentLines.insert(afterColon, at: 0)
            }
        }

        let content = contentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

        return content.isEmpty ? nil : content
    }

    /// Instance method wrapper for extractSectionStatic
    private func extractSectionStatic(from text: String, sectionHeadings: [String]) -> String? {
        Self.extractSectionStatic(from: text, sectionHeadings: sectionHeadings)
    }

    private func populateFromClinicalNotes(_ notes: [ClinicalNote]) {
        guard !notes.isEmpty else { return }
        guard !isReportMode else { return }

        print("[GPR iOS] Populating from \(notes.count) clinical notes (sync)")

        // Clear existing imported entries
        formData.psychiatricHistoryImported.removeAll()
        formData.riskImportedEntries.removeAll()
        formData.backgroundImportedEntries.removeAll()
        formData.medicalHistoryImported.removeAll()
        formData.substanceUseImported.removeAll()
        formData.forensicHistoryImported.removeAll()
        formData.medicationImported.removeAll()
        formData.diagnosisImported.removeAll()
        formData.legalCriteriaImported.removeAll()
        formData.strengthsImported.removeAll()
        formData.circumstancesImported.removeAll()
        formData.admissionsTableData.removeAll()
        formData.clerkingNotes.removeAll()

        // Build timeline to find admissions (matches desktop logic)
        let episodes = TimelineBuilder.buildTimeline(from: notes, allNotes: notes)
        let inpatientEpisodes = episodes.filter { $0.type == .inpatient }

        print("[GPR iOS] Found \(inpatientEpisodes.count) inpatient episodes")

        // Get most recent admission for Circumstances filtering
        let mostRecentAdmission = inpatientEpisodes.last
        let calendar = Calendar.current

        // === SECTION 6: PSYCHIATRIC HISTORY - Populate admissions table and find clerking notes ===
        // Desktop find_clerkings_rio EXACT LOGIC:
        // 1. Filter to MEDICAL notes only (type contains "med", "doctor", "clinician", "physician")
        // 2. Check for CLERKING_TRIGGERS in content OR ROLE_TRIGGERS in originator
        var seenClerkingKeys: Set<String> = []
        var allClerkingsForEpisode: [(date: Date, text: String, admissionDate: Date)] = []

        // Desktop CLERKING_TRIGGERS_RIO (content triggers)
        let clerkingTriggers = [
            "admission clerking", "clerking", "duty doctor admission",
            "new admission", "new transfer", "circumstances of admission",
            "circumstances leading to admission", "new client assessment"
        ]

        // Desktop ROLE_TRIGGERS_RIO (originator/content role triggers)
        let roleTriggers = [
            "physician associate", "medical", "senior house officer",
            "sho", "ct1", "ct2", "ct3", "st4", "doctor"
        ]

        for episode in inpatientEpisodes {
            let admissionStart = episode.start
            let windowEnd = calendar.date(byAdding: .day, value: 10, to: admissionStart) ?? admissionStart  // Desktop uses 10 days

            // Get notes in the admission window, sorted by date
            let windowNotes = notes.filter { note in
                let noteDay = calendar.startOfDay(for: note.date)
                return noteDay >= admissionStart && noteDay <= windowEnd
            }.sorted { $0.date < $1.date }

            // Desktop: Filter to MEDICAL notes ONLY first
            // is_medical_type checks: "med" in t or "doctor" in t or "clinician" in t or "physician" in t
            let medicalNotes = windowNotes.filter { note in
                let typeLower = note.type.lowercased()
                return typeLower.contains("med") ||
                       typeLower.contains("doctor") ||
                       typeLower.contains("clinician") ||
                       typeLower.contains("physician")
            }

            print("[GPR iOS SYNC] Window \(admissionStart) -> \(windowEnd): \(windowNotes.count) notes, \(medicalNotes.count) medical")

            // Find clerkings from medical notes
            var firstClerkingDate: Date? = nil
            for note in medicalNotes {
                let bodyLower = note.body.lowercased()

                // Check for clerking triggers in content
                let hasClerkingTrigger = clerkingTriggers.contains { trigger in
                    bodyLower.contains(trigger)
                }

                // Check for role triggers in author (fallback) - desktop uses "originator", iOS uses "author"
                let authorLower = note.author.lowercased()
                let hasRoleTriggerInAuthor = roleTriggers.contains { role in
                    authorLower.contains(role)
                }

                // Desktop logic: note must have clerking trigger OR author role trigger
                if !hasClerkingTrigger && !hasRoleTriggerInAuthor {
                    continue
                }

                let key = "\(calendar.startOfDay(for: note.date))-\(String(note.body.prefix(120)))"
                if !seenClerkingKeys.contains(key) {
                    seenClerkingKeys.insert(key)
                    allClerkingsForEpisode.append((date: note.date, text: note.body, admissionDate: admissionStart))
                    if firstClerkingDate == nil {
                        firstClerkingDate = note.date
                    }
                    print("[GPR iOS SYNC] Found MEDICAL clerking: \(note.body.count) chars, type=\(note.type), trigger=\(hasClerkingTrigger), author=\(hasRoleTriggerInAuthor)")
                }
            }

            // FALLBACK: If no medical clerkings found for THIS episode, try ALL window notes with history sections
            let foundInThisEpisode = allClerkingsForEpisode.contains { $0.admissionDate == admissionStart }
            if !foundInThisEpisode {
                print("[GPR iOS SYNC] No medical clerkings found for episode \(admissionStart), trying fallback...")
                for note in windowNotes {
                    let bodyLower = note.body.lowercased()

                    // Check for history section headers - more flexible matching
                    // Check both newline prefix AND start of note
                    let hasPersonalHistory = bodyLower.contains("\npersonal history") ||
                                             bodyLower.hasPrefix("personal history")
                    let hasBackgroundHistory = bodyLower.contains("\nbackground history") ||
                                               bodyLower.hasPrefix("background history")
                    let hasPastMedicalHistory = bodyLower.contains("\npast medical history") ||
                                                bodyLower.hasPrefix("past medical history")
                    let hasForensicHistory = bodyLower.contains("\nforensic history") ||
                                             bodyLower.hasPrefix("forensic history")
                    let hasMSE = bodyLower.contains("\nmental state examination") ||
                                 bodyLower.hasPrefix("mental state examination") ||
                                 bodyLower.contains("\nmse") ||
                                 bodyLower.hasPrefix("mse")

                    let hasHistorySection = hasPersonalHistory || hasBackgroundHistory ||
                                            hasPastMedicalHistory || hasForensicHistory || hasMSE

                    // Note is a clerking if it has history sections AND is substantial (>500 chars)
                    let isSubstantial = note.body.count > 500
                    if hasHistorySection && isSubstantial {
                        let key = "\(calendar.startOfDay(for: note.date))-\(String(note.body.prefix(120)))"
                        if !seenClerkingKeys.contains(key) {
                            seenClerkingKeys.insert(key)
                            allClerkingsForEpisode.append((date: note.date, text: note.body, admissionDate: admissionStart))
                            if firstClerkingDate == nil {
                                firstClerkingDate = note.date
                            }
                            print("[GPR iOS SYNC] Found FALLBACK clerking: \(note.body.count) chars, type=\(note.type), hasPersonal=\(hasPersonalHistory)")
                        }
                    }
                }
            }

            // Use first clerking note date if found, otherwise use episode start
            let clerkingNoteDate = firstClerkingDate
            let clerkingNoteText = allClerkingsForEpisode.first(where: { $0.admissionDate == admissionStart })?.text

            // Use clerking note date if found, otherwise use episode start
            let adjustedAdmissionDate = clerkingNoteDate ?? episode.start

            // Check if episode is ongoing (end date is today or in the future)
            let today = calendar.startOfDay(for: Date())
            let episodeEndDay = calendar.startOfDay(for: episode.end)
            let isOngoing = episodeEndDay >= today

            // Calculate duration
            let durationStr: String
            let days = calendar.dateComponents([.day], from: adjustedAdmissionDate, to: episode.end).day ?? 0
            if isOngoing {
                durationStr = "Ongoing"
            } else if days < 7 {
                durationStr = "\(days) day\(days == 1 ? "" : "s")"
            } else if days < 30 {
                let weeks = days / 7
                durationStr = "\(weeks) week\(weeks == 1 ? "" : "s")"
            } else {
                let months = days / 30
                durationStr = "\(months) month\(months == 1 ? "" : "s")"
            }

            // Add to admissions table
            formData.admissionsTableData.append(GPRAdmissionEntry(
                admissionDate: adjustedAdmissionDate,
                dischargeDate: isOngoing ? nil : episode.end,
                duration: durationStr
            ))

            // Add first clerking note for section 6 display
            if let noteText = clerkingNoteText, let noteDate = clerkingNoteDate {
                let snippet = noteText.count > 150 ? String(noteText.prefix(150)) + "..." : noteText
                let admissionLabel = "Admission \(formatDate(adjustedAdmissionDate))"
                formData.clerkingNotes.append(GPRImportedEntry(
                    date: noteDate,
                    text: noteText,
                    snippet: snippet,
                    categories: [admissionLabel]
                ))

                // Also extract PPH section for psychiatricHistoryImported
                if let pphSection = extractSection(from: noteText, sectionHeadings: [
                    "past psychiatric history", "pph", "psychiatric history",
                    "mental health history", "previous psychiatric", "previous admissions",
                    "past psych history", "previous mental health"
                ]) {
                    let sectionSnippet = pphSection.count > 150 ? String(pphSection.prefix(150)) + "..." : pphSection
                    formData.psychiatricHistoryImported.append(GPRImportedEntry(
                        date: noteDate,
                        text: pphSection,
                        snippet: sectionSnippet,
                        categories: [admissionLabel]
                    ))
                }
            }
        }

        // GLOBAL FALLBACK: If still no clerkings found, search ALL notes for Personal history sections
        if allClerkingsForEpisode.isEmpty {
            print("[GPR iOS SYNC] GLOBAL FALLBACK: No clerkings found, searching ALL notes for Personal history...")
            for note in notes {
                let bodyLower = note.body.lowercased()

                // Check for Personal history section (the key indicator of a detailed clerking)
                let hasPersonalHistory = bodyLower.contains("\npersonal history") ||
                                         bodyLower.contains("personal history:") ||
                                         bodyLower.hasPrefix("personal history")

                if hasPersonalHistory && note.body.count > 500 {
                    let key = "\(calendar.startOfDay(for: note.date))-\(String(note.body.prefix(120)))"
                    if !seenClerkingKeys.contains(key) {
                        seenClerkingKeys.insert(key)
                        allClerkingsForEpisode.append((date: note.date, text: note.body, admissionDate: note.date))
                        print("[GPR iOS SYNC] GLOBAL FALLBACK: Found note with Personal history: \(note.body.count) chars, type=\(note.type)")
                    }
                }
            }
        }

        print("[GPR iOS SYNC] Total clerkings found: \(allClerkingsForEpisode.count)")

        // === SECTION 9: FORENSIC HISTORY - Extract from ALL clerkings (matches desktop) ===
        // Desktop extracts forensic history from ALL clerkings found, not just one per admission
        for clerking in allClerkingsForEpisode {
            let admissionLabel = "Admission \(formatDate(clerking.admissionDate))"

            if let forensicSection = extractSection(from: clerking.text, sectionHeadings: [
                "forensic history", "forensic", "offence", "offending",
                "criminal", "police", "charges", "index offence"
            ]) {
                let sectionSnippet = forensicSection.count > 150 ? String(forensicSection.prefix(150)) + "..." : forensicSection
                formData.forensicHistoryImported.append(GPRImportedEntry(
                    date: clerking.date,
                    text: forensicSection,
                    snippet: sectionSnippet,
                    categories: [admissionLabel]
                ))
            }
        }

        // === SECTION 5: MEDICAL HISTORY - Extract from ALL clerkings (matches desktop) ===
        // Desktop extracts medical history from ALL clerkings, with precision guard for psychiatric terms
        // Section headings match desktop: history_extractor_sections.py and data_extractor_popup.py
        let medicalHistoryHeadings = [
            "past medical history", "medical history", "pmh",
            "physical health", "physical hx", "physical health history",
            "comorbidities", "comorbid", "physical examination", "ecg"
        ]

        // Psychiatric exclusion terms (PHYSICAL HEALTH PRECISION GUARD from desktop)
        let psychiatricExclusionTerms = [
            "delusion", "delusional", "hallucination", "hallucinating",
            "insight", "thought", "affect", "mood", "mental state", "mse",
            "behaviour", "behavior", "psychotic", "paranoid"
        ]

        for clerking in allClerkingsForEpisode {
            let admissionLabel = "Admission \(formatDate(clerking.admissionDate))"

            if let pmhSection = extractSection(from: clerking.text, sectionHeadings: medicalHistoryHeadings) {
                // Apply PHYSICAL HEALTH PRECISION GUARD - exclude sections with psychiatric terms
                let pmhLower = pmhSection.lowercased()
                let hasPsychiatricContent = psychiatricExclusionTerms.contains { pmhLower.contains($0) }

                if !hasPsychiatricContent {
                    let sectionSnippet = pmhSection.count > 150 ? String(pmhSection.prefix(150)) + "..." : pmhSection
                    let medicalCategories = GPRCategoryKeywords.categorize(pmhSection, using: GPRCategoryKeywords.medicalHistory)
                    formData.medicalHistoryImported.append(GPRImportedEntry(
                        date: clerking.date,
                        text: pmhSection,
                        snippet: sectionSnippet,
                        categories: medicalCategories.isEmpty ? [admissionLabel] : medicalCategories
                    ))
                }
            }
        }

        print("[GPR iOS] Populated: \(formData.admissionsTableData.count) admissions, \(formData.clerkingNotes.count) clerking notes, \(allClerkingsForEpisode.count) total clerkings for forensic/medical")

        // === FALLBACK: If no medical history found from clerkings, search ALL notes ===
        // This matches how desktop data_extractor_popup.py searches all content for PHYSICAL_HEALTH category
        if formData.medicalHistoryImported.isEmpty {
            print("[GPR iOS] No medical history found in clerkings, searching all notes...")
            for note in notes {
                if let pmhSection = extractSection(from: note.body, sectionHeadings: medicalHistoryHeadings) {
                    let pmhLower = pmhSection.lowercased()
                    let hasPsychiatricContent = psychiatricExclusionTerms.contains { pmhLower.contains($0) }

                    if !hasPsychiatricContent {
                        let sectionSnippet = pmhSection.count > 150 ? String(pmhSection.prefix(150)) + "..." : pmhSection
                        let medicalCategories = GPRCategoryKeywords.categorize(pmhSection, using: GPRCategoryKeywords.medicalHistory)
                        formData.medicalHistoryImported.append(GPRImportedEntry(
                            date: note.date,
                            text: pmhSection,
                            snippet: sectionSnippet,
                            categories: medicalCategories.isEmpty ? ["Medical History"] : medicalCategories
                        ))
                    }
                }
            }
            print("[GPR iOS] Found \(formData.medicalHistoryImported.count) medical history entries from all notes")
        }

        // Process each note for other sections
        for note in notes {
            let text = note.body
            let date = note.date
            let snippet = text.count > 150 ? String(text.prefix(150)) + "..." : text
            let noteDay = calendar.startOfDay(for: date)

            // === CIRCUMSTANCES (Section 3) ===
            // Include ALL notes from the last admission period (matching desktop TribunalProgressPopup)
            // Use full admission period OR at least 14 days from admission start
            if let recentAdmission = mostRecentAdmission {
                let admissionStart = recentAdmission.start
                let admissionEnd = recentAdmission.end
                let minWindowEnd = calendar.date(byAdding: .day, value: 14, to: admissionStart) ?? admissionStart
                let windowEnd = max(admissionEnd, minWindowEnd)
                if noteDay >= admissionStart && noteDay <= windowEnd {
                    formData.circumstancesImported.append(GPRImportedEntry(
                        date: date,
                        text: text,
                        snippet: snippet,
                        categories: ["Admission Period"]
                    ))
                }
            }

            // === BACKGROUND (Section 4) - now extracted separately below after all notes processed ===

            // === RISK (Section 7) - search all notes with specific incident patterns (matching desktop) ===
            // Extract only the relevant context (matched line + 2 lines before/after) instead of full note
            if let riskResult = GPRCategoryKeywords.categorizeRiskIncidentWithContext(text) {
                let contextSnippet = riskResult.context.count > 150 ? String(riskResult.context.prefix(150)) + "..." : riskResult.context
                formData.riskImportedEntries.append(GPRImportedEntry(
                    date: date,
                    text: riskResult.context,
                    snippet: contextSnippet,
                    categories: riskResult.categories
                ))
            }

            // === MEDICAL HISTORY (Section 5) - now handled below with ALL clerkings ===
            // (moved to match desktop approach - extracts from ALL clerkings, not just admission window)

            // Substance Use - extract relevant context with highlighting (matching risk section approach)
            if let substanceResult = GPRCategoryKeywords.categorizeSubstanceWithContext(text) {
                let contextSnippet = substanceResult.context.count > 150 ? String(substanceResult.context.prefix(150)) + "..." : substanceResult.context
                formData.substanceUseImported.append(GPRImportedEntry(
                    date: date,
                    text: substanceResult.context,
                    snippet: contextSnippet,
                    categories: substanceResult.categories
                ))
            }

            // Diagnosis
            let diagnosisCategories = GPRCategoryKeywords.categorize(text, using: GPRCategoryKeywords.diagnosis)
            if !diagnosisCategories.isEmpty {
                formData.diagnosisImported.append(GPRImportedEntry(date: date, text: text, snippet: snippet, categories: diagnosisCategories))
            }

            // Strengths
            let strengthsCategories = GPRCategoryKeywords.categorize(text, using: GPRCategoryKeywords.strengths)
            if !strengthsCategories.isEmpty {
                formData.strengthsImported.append(GPRImportedEntry(date: date, text: text, snippet: snippet, categories: strengthsCategories))
            }

            // Legal Criteria
            let legalCategories = GPRCategoryKeywords.categorize(text, using: GPRCategoryKeywords.legalCriteria)
            if !legalCategories.isEmpty {
                formData.legalCriteriaImported.append(GPRImportedEntry(date: date, text: text, snippet: snippet, categories: legalCategories))
            }
        }

        // === BACKGROUND (Section 4) - Extract from CLERKINGS ONLY (matching Section 5 approach) ===
        // Desktop extracts from admission clerkings which have detailed "Personal history:" sections
        // CPA review notes have "Relevant Social History" which we want to SKIP
        print("[GPR iOS SYNC] Extracting background from \(allClerkingsForEpisode.count) clerkings only")

        // Use specific headings that appear in actual clerkings, NOT CPA review templates
        let backgroundHeadings = [
            "personal history", "background history", "family history",
            "developmental history", "early history", "past and personal history",
            "personal and social history"
        ]

        for clerking in allClerkingsForEpisode {
            if let bgSection = extractSection(from: clerking.text, sectionHeadings: backgroundHeadings) {
                // Only keep sections with substantial content (>200 chars for background)
                if bgSection.count > 200 {
                    let bgCategories = GPRCategoryKeywords.categorize(bgSection, using: GPRCategoryKeywords.background)
                    formData.backgroundImportedEntries.append(GPRImportedEntry(
                        date: clerking.date,
                        text: bgSection,
                        snippet: String(bgSection.prefix(200)),
                        categories: bgCategories.isEmpty ? ["Background"] : bgCategories
                    ))
                    print("[GPR iOS SYNC] Found background in clerking: \(bgSection.count) chars")
                }
            }
        }

        // Sort by length (longest first) to prioritize most detailed
        formData.backgroundImportedEntries.sort { $0.text.count > $1.text.count }
        print("[GPR iOS SYNC] Found \(formData.backgroundImportedEntries.count) background entries from clerkings")

        // ADDITIONAL: Search ALL notes for Personal history sections (to find more background entries)
        // This expands beyond just clerkings to catch any note with detailed personal history
        var seenBackgroundTexts = Set(formData.backgroundImportedEntries.map { String($0.text.prefix(200)) })
        for note in notes {
            if let bgSection = extractSection(from: note.body, sectionHeadings: backgroundHeadings) {
                // Only keep substantial sections (>200 chars) that aren't duplicates
                let textKey = String(bgSection.prefix(200))
                if bgSection.count > 200 && !seenBackgroundTexts.contains(textKey) {
                    // Skip CPA review template content
                    let bgLower = bgSection.lowercased()
                    let isCPATemplate = bgLower.contains("relevant social history") ||
                                        bgLower.contains("daily function") ||
                                        bgLower.contains("current illegal drugs")
                    if !isCPATemplate {
                        seenBackgroundTexts.insert(textKey)
                        let bgCategories = GPRCategoryKeywords.categorize(bgSection, using: GPRCategoryKeywords.background)
                        formData.backgroundImportedEntries.append(GPRImportedEntry(
                            date: note.date,
                            text: bgSection,
                            snippet: String(bgSection.prefix(200)),
                            categories: bgCategories.isEmpty ? ["Background"] : bgCategories
                        ))
                        print("[GPR iOS SYNC] Found ADDITIONAL background in note: \(bgSection.count) chars")
                    }
                }
            }
        }

        // Re-sort by length after adding more entries
        formData.backgroundImportedEntries.sort { $0.text.count > $1.text.count }
        print("[GPR iOS SYNC] Total background entries after broad search: \(formData.backgroundImportedEntries.count)")

        // Sort all by date (newest first)
        formData.psychiatricHistoryImported.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.riskImportedEntries.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.backgroundImportedEntries.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.medicalHistoryImported.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.substanceUseImported.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.forensicHistoryImported.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.diagnosisImported.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.strengthsImported.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.circumstancesImported.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.legalCriteriaImported.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }

        // === AUTO-POPULATE RISK LEVELS (matching desktop MOJ Leave 4e logic) ===
        autoPopulateRiskLevels()

        // === MEDICATION: Extract and pre-fill from last year's notes (matches desktop prefill_medications_from_notes) ===
        prefillMedicationsFromNotes(notes)

        print("[GPR iOS] Populated: \(formData.psychiatricHistoryImported.count) psych history, \(formData.circumstancesImported.count) circumstances, \(formData.backgroundImportedEntries.count) background, \(formData.riskImportedEntries.count) risk incidents")
    }

    /// Auto-populate Current and Historical risk levels from imported risk entries
    /// Matches desktop GPR set_notes_for_risk_analysis and MOJ Leave 4e logic
    private func autoPopulateRiskLevels() {
        guard !formData.riskImportedEntries.isEmpty else { return }

        // Mapping from risk incident categories to GPRRiskType
        let categoryToRiskType: [String: GPRRiskType] = [
            "Physical Aggression": .violence,
            "Verbal Aggression": .verbalAggression,
            "Self-Harm": .selfHarm,
            "Suicide": .suicide,
            "Self-Neglect": .selfNeglect,
            "Sexual Behaviour": .sexuallyInappropriate,
            "AWOL": .awol,
            "Property Damage": .propertyDamage,
            "Substance Misuse": .substanceMisuse,
            "Bullying": .exploitation,
        ]

        // Find latest and earliest dates for calculating time spans
        var latestDate: Date? = nil
        var earliestDate: Date? = nil
        for entry in formData.riskImportedEntries {
            if let date = entry.date {
                if latestDate == nil || date > latestDate! {
                    latestDate = date
                }
                if earliestDate == nil || date < earliestDate! {
                    earliestDate = date
                }
            }
        }

        // Calculate 3-month cutoff for "current" risk
        let threeMonthsAgo: Date? = latestDate.map { Calendar.current.date(byAdding: .day, value: -90, to: $0) ?? $0 }

        // Calculate number of years for historical severity averaging
        var numYears: Double = 1.0
        if let latest = latestDate, let earliest = earliestDate {
            let daySpan = Calendar.current.dateComponents([.day], from: earliest, to: latest).day ?? 365
            numYears = max(1.0, Double(daySpan) / 365.0)
        }

        // Count incidents by risk type
        var currentRiskCounts: [GPRRiskType: Int] = [:]
        var historicalRiskCounts: [GPRRiskType: Int] = [:]

        for entry in formData.riskImportedEntries {
            for category in entry.categories {
                if let riskType = categoryToRiskType[category] {
                    // Historical counts ALL entries
                    historicalRiskCounts[riskType, default: 0] += 1

                    // Current counts only last 3 months
                    if let entryDate = entry.date, let cutoff = threeMonthsAgo, entryDate >= cutoff {
                        currentRiskCounts[riskType, default: 0] += 1
                    }
                }
            }
        }

        // Set Current Risk levels
        // Severity: AWOL any = HIGH, >= 3 incidents = HIGH, else MEDIUM
        for (riskType, count) in currentRiskCounts {
            if count > 0 {
                let level: GPRRiskLevel
                if riskType == .awol {
                    level = .high  // AWOL: any occurrence = HIGH
                } else if count >= 3 {
                    level = .high
                } else {
                    level = .medium
                }
                formData.currentRisks[riskType] = level
            }
        }

        // Set Historical Risk levels
        // Severity based on average per year: > 5/year = HIGH, < 1/year = LOW, else MEDIUM
        for (riskType, count) in historicalRiskCounts {
            if count > 0 {
                let avgPerYear = Double(count) / numYears
                let level: GPRRiskLevel
                if avgPerYear > 5 {
                    level = .high
                } else if avgPerYear < 1 {
                    level = .low
                } else {
                    level = .medium
                }
                formData.historicalRisks[riskType] = level
            }
        }

        print("[GPR iOS] Auto-populated risks - Current: \(currentRiskCounts.count) types, Historical: \(historicalRiskCounts.count) types")
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: date)
    }

    /// Pre-fill medications from notes using MedicationExtractor
    /// Matches desktop GPRMedicationPopup.prefill_medications_from_notes()
    /// - Extracts medications from last year's notes
    /// - Groups by medication class (Antipsychotic, Antidepressant, etc.)
    /// - Picks most recent medication per class
    /// - Pre-fills the current medications list
    /// - Also populates medicationImported with all medication mentions for display
    private func prefillMedicationsFromNotes(_ notes: [ClinicalNote]) {
        guard !notes.isEmpty else {
            print("[GPR-MED] No notes for medication extraction")
            return
        }

        let calendar = Calendar.current
        let oneYearAgo = calendar.date(byAdding: .year, value: -1, to: Date()) ?? Date()

        // Use MedicationExtractor
        let extractor = MedicationExtractor.shared

        // === EXTRACT FROM ALL NOTES for imported section ===
        print("[GPR-MED] Extracting medications from ALL \(notes.count) notes for imported section...")
        let allExtracted = extractor.extractMedications(from: notes)

        // Populate imported notes section with ALL medication mentions
        formData.medicationImported.removeAll()
        for drug in allExtracted.drugs {
            let category = drug.psychiatricSubtype?.rawValue ?? drug.category.rawValue
            for mention in drug.mentions {
                // Build display text: "Drug Name Dose Frequency"
                var displayText = drug.name
                if let dose = mention.dose { displayText += " \(dose)" }
                if let freq = mention.frequency { displayText += " \(freq.uppercased())" }

                let snippet = mention.context.count > 100 ? String(mention.context.prefix(100)) + "..." : mention.context

                formData.medicationImported.append(GPRImportedEntry(
                    date: mention.date,
                    text: displayText,
                    snippet: snippet,
                    categories: [category]
                ))
            }
        }
        // Sort by date (newest first)
        formData.medicationImported.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        print("[GPR-MED] Populated \(formData.medicationImported.count) imported medication entries (all notes)")

        // === EXTRACT FROM LAST YEAR ONLY for pre-filling current medications ===
        let recentNotes = notes.filter { $0.date >= oneYearAgo }
        print("[GPR-MED] Extracting medications from \(recentNotes.count) notes (last year) for pre-fill...")

        let recentExtracted = extractor.extractMedications(from: recentNotes)

        if recentExtracted.drugs.isEmpty {
            print("[GPR-MED] No medications found in last year's notes for pre-fill")
            if formData.medications.isEmpty {
                formData.medications.append(GPRMedicationEntry())
            }
            return
        }

        print("[GPR-MED] Found \(recentExtracted.drugs.count) unique medications in last year")

        // === PRE-FILL CURRENT MEDICATIONS (1 per class from last year) ===
        var selectedMeds: [ClassifiedDrug] = []

        // Psychiatric medications by subtype priority
        let subtypePriority: [PsychSubtype] = [.antipsychotic, .antidepressant, .antimanic, .hypnotic, .anticholinergic, .other]

        for subtype in subtypePriority {
            let drugsOfType = recentExtracted.psychiatricDrugs.filter { $0.psychiatricSubtype == subtype }
            // Pick the one with the most recent mention
            if let mostRecent = drugsOfType.max(by: { ($0.latestDate ?? .distantPast) < ($1.latestDate ?? .distantPast) }) {
                selectedMeds.append(mostRecent)
            }
        }

        // Limit to top 8 medications
        let finalMeds = Array(selectedMeds.prefix(8))

        print("[GPR-MED] Selected \(finalMeds.count) medications (1 per class, last year)")

        // Pre-fill the medication entries
        formData.medications.removeAll()

        for drug in finalMeds {
            var entry = GPRMedicationEntry()
            entry.name = drug.name
            entry.dose = drug.latestDose ?? ""

            // Map frequency
            if let freq = drug.mentions.last?.frequency?.lowercased() {
                switch freq {
                case "od", "daily", "once": entry.frequency = "OD"
                case "bd", "twice": entry.frequency = "BD"
                case "tds": entry.frequency = "TDS"
                case "qds", "qid": entry.frequency = "QDS"
                case "nocte", "on", "night": entry.frequency = "Nocte"
                case "prn": entry.frequency = "PRN"
                case "weekly": entry.frequency = "Weekly"
                case "fortnightly": entry.frequency = "Fortnightly"
                case "monthly": entry.frequency = "Monthly"
                default: entry.frequency = "OD"
                }
            }

            formData.medications.append(entry)
            print("[GPR-MED]   [\(drug.psychiatricSubtype?.rawValue ?? "Other")] \(drug.name): \(entry.dose) \(entry.frequency)")
        }

        // Ensure at least one empty entry for manual input
        if formData.medications.isEmpty {
            formData.medications.append(GPRMedicationEntry())
        }

        print("[GPR-MED] Pre-filled \(finalMeds.count) medication(s) from last year")
    }

    /// Extracts a specific section from clinical note text based on heading patterns
    /// Uses LINE-BASED header detection like desktop history_extractor_sections.py
    /// Returns the content between the matched heading and the next heading (or end of text)
    private func extractSection(from text: String, sectionHeadings: [String]) -> String? {
        let lines = text.components(separatedBy: .newlines)

        // Common headings that indicate section boundaries (matches desktop CATEGORIES_ORDERED and HARD_OVERRIDE_HEADINGS)
        // Also includes common RiO progress note section headers to detect boundaries
        let allHeadings = [
            // Clinical history sections
            "background history", "personal history", "social history", "family history",
            "developmental history", "early history", "past and personal history",
            "past psychiatric history", "psychiatric history", "mental health history", "pph",
            "history of presenting complaint", "presenting complaint", "hpc",
            "past medical history", "medical history", "pmh", "physical health",
            // Drug and alcohol headings
            "drug and alcohol", "drug and alcohol history", "drug history", "alcohol history",
            "substance use", "substance misuse", "substance", "illicit",
            // Forensic and clinical
            "forensic history", "forensic", "offence", "offending", "criminal", "police", "charges", "index offence",
            "mental state", "mse", "mental state examination", "risk", "impression", "plan", "diagnosis",
            "medication", "medication history", "current medication", "physical examination", "summary", "capacity", "ecg",
            // Common RiO progress note headers that END medical history sections
            "finances", "finance", "accommodation", "leave", "section", "legal status",
            "occupational therapy", "ot", "psychology", "nursing", "social work", "sw",
            "cpa", "care plan", "review", "follow up", "follow-up", "next steps",
            "actions", "outcome", "progress", "update", "contact", "telephone",
            "activities", "engagement", "presentation", "observations", "obs level",
            "safeguarding", "discharge", "transfer", "referral"
        ]

        // Helper: detect if a line is a section header (matches desktop _detect_header exactly)
        // Desktop logic: if ":" not in line and "-" not in line: if len(words) <= 2: check
        // Then checks: nl == term or nl.startswith(term) - NO contains!
        func isHeaderLine(_ line: String, for headings: [String]) -> String? {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let lower = trimmed.lowercased()
            let words = trimmed.split(separator: " ")

            let hasColon = line.contains(":")
            let hasDash = line.contains("-")

            // Clean the line for matching
            let cleanedLine = lower
                .replacingOccurrences(of: ":", with: "")
                .replacingOccurrences(of: "-", with: " ")
                .trimmingCharacters(in: .whitespaces)

            for heading in headings {
                // Desktop: nl == term or nl.startswith(term) - NOT contains!
                if cleanedLine == heading || cleanedLine.hasPrefix(heading + " ") || lower.hasPrefix(heading) {
                    return heading
                }
            }

            // For short lines with colon/dash, also check hasPrefix without space
            if (hasColon || hasDash) && words.count <= 4 {
                for heading in headings {
                    if cleanedLine.hasPrefix(heading) {
                        return heading
                    }
                }
            }

            return nil
        }

        // Find the line where our target section starts
        var sectionStartLineIdx: Int? = nil
        var matchedHeading: String? = nil

        for (idx, line) in lines.enumerated() {
            if let header = isHeaderLine(line, for: sectionHeadings) {
                sectionStartLineIdx = idx
                matchedHeading = header
                break
            }
        }

        guard let startIdx = sectionStartLineIdx, let _ = matchedHeading else { return nil }

        // Find where the section ends (next heading line or end of text)
        var sectionEndLineIdx = lines.count

        for idx in (startIdx + 1)..<lines.count {
            let line = lines[idx]
            if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }

            if let header = isHeaderLine(line, for: allHeadings) {
                if !sectionHeadings.contains(header) {
                    sectionEndLineIdx = idx
                    break
                }
            }
        }

        // Extract content: skip the heading line, take content until next heading
        var contentLines = Array(lines[(startIdx + 1)..<sectionEndLineIdx])

        // IMPORTANT: Also extract any inline content from the header line itself
        // e.g., "Personal history: Ms Adeniyi was born..." - the content after ":" is on the same line
        let headerLine = lines[startIdx]
        if let colonRange = headerLine.range(of: ":") {
            let afterColon = String(headerLine[colonRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            if !afterColon.isEmpty {
                // Prepend the inline content
                contentLines.insert(afterColon, at: 0)
            }
        }

        let sectionContent = contentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

        // Only return if we have meaningful content (more than 20 chars)
        return sectionContent.count > 20 ? sectionContent : nil
    }

    // MARK: - GPR Report Detection & Parsing

    /// Multi-word phrases that distinguish a psychiatric report from clinical notes
    private static let gprReportFingerprints: [String] = [
        // T131-specific
        "mental health tribunal", "responsible clinician", "nature or degree",
        // Generic report headings
        "past psychiatric history", "forensic history", "mental state examination",
        "risk assessment", "legal criteria", "statutory criteria",
        "sources of information", "circumstances of admission",
        "history of substance use", "past medical history",
        "background information", "strengths and positive factors",
    ]

    /// Maps heading text patterns to GPR section enum values.
    /// Ordered most-specific to least-specific per section.
    private static let gprHeadingPatterns: [(pattern: String, section: GPRSection)] = [
        // Patient details
        ("patient details", .patientDetails),
        ("patient information", .patientDetails),
        ("personal details", .patientDetails),
        ("basic information", .patientDetails),
        ("demographic details", .patientDetails),
        ("demographic information", .patientDetails),
        // Report based on
        ("sources of information", .reportBasedOn),
        ("report based on", .reportBasedOn),
        ("documents reviewed", .reportBasedOn),
        ("knowledge of patient", .reportBasedOn),
        ("information considered", .reportBasedOn),
        ("information reviewed", .reportBasedOn),
        ("informant", .reportBasedOn),
        // Circumstances — specific before generic
        ("circumstances of current admission", .circumstances),
        ("circumstances of this admission", .circumstances),
        ("circumstances of admission", .circumstances),
        ("circumstances to this admission", .circumstances),
        ("circumstances leading to admission", .circumstances),
        ("circumstances leading to", .circumstances),
        ("history of presenting complaint", .circumstances),
        ("presenting complaint", .circumstances),
        ("presenting problems", .circumstances),
        ("presenting difficulties", .circumstances),
        ("reason for referral", .circumstances),
        ("reason for admission", .circumstances),
        ("referral information", .circumstances),
        ("current admission", .circumstances),
        ("current episode", .circumstances),
        // Background — specific compound headings first
        ("family history and personal history", .background),
        ("family and personal history", .background),
        ("background information", .background),
        ("background history", .background),
        ("background", .background),
        ("personal history", .background),
        ("family history", .background),
        ("social history", .background),
        ("social circumstances", .background),
        ("developmental history", .background),
        ("early history", .background),
        ("educational history", .background),
        ("occupational history", .background),
        ("employment history", .background),
        ("relationship history", .background),
        ("premorbid personality", .background),
        // Medical history — specific before generic
        ("past medical history", .medicalHistory),
        ("medical history", .medicalHistory),
        ("physical health", .medicalHistory),
        ("physical health history", .medicalHistory),
        ("physical examination", .medicalHistory),
        ("physical investigations", .medicalHistory),
        // Psychiatric history — specific before generic
        ("past psychiatric history", .psychiatricHistory),
        ("previous psychiatric history", .psychiatricHistory),
        ("psychiatric history", .psychiatricHistory),
        ("mental health history", .psychiatricHistory),
        ("history of mental illness", .psychiatricHistory),
        ("history of present illness", .psychiatricHistory),
        ("history of current illness", .psychiatricHistory),
        ("history and duration of admissions", .psychiatricHistory),
        ("duration of admissions", .psychiatricHistory),
        ("progress since admission", .psychiatricHistory),
        ("progress on the ward", .psychiatricHistory),
        ("progress in hospital", .psychiatricHistory),
        ("progress during admission", .psychiatricHistory),
        ("current mental state", .psychiatricHistory),
        ("mental state examination", .psychiatricHistory),
        ("mental state on examination", .psychiatricHistory),
        // Risk — specific before generic
        ("risk history", .risk),
        ("risk assessment", .risk),
        ("risk management", .risk),
        ("risk factors", .risk),
        ("risk to self", .risk),
        ("risk to others", .risk),
        ("risk profile", .risk),
        ("risk summary", .risk),
        ("current risk", .risk),
        ("incidents of harm", .risk),
        ("history of aggression", .risk),
        ("history of violence", .risk),
        // Substance use
        ("history of substance use", .substanceUse),
        ("history of substance misuse", .substanceUse),
        ("substance use history", .substanceUse),
        ("substance use", .substanceUse),
        ("substance misuse", .substanceUse),
        ("drug and alcohol", .substanceUse),
        ("drugs and alcohol", .substanceUse),
        ("alcohol and drugs", .substanceUse),
        ("alcohol and substance", .substanceUse),
        ("alcohol use", .substanceUse),
        // Forensic history
        ("forensic history", .forensicHistory),
        ("offending history", .forensicHistory),
        ("offending behaviour", .forensicHistory),
        ("index offence", .forensicHistory),
        ("criminal history", .forensicHistory),
        ("legal history", .forensicHistory),
        ("convictions", .forensicHistory),
        // Medication — specific before generic
        ("current medication", .medication),
        ("medication history", .medication),
        ("prescribed medication", .medication),
        ("pharmacological treatment", .medication),
        ("drug treatment", .medication),
        ("current treatment", .medication),
        ("medication", .medication),
        ("treatment plan", .medication),
        // Diagnosis — specific before generic
        ("current diagnosis", .diagnosis),
        ("principal diagnosis", .diagnosis),
        ("diagnostic formulation", .diagnosis),
        ("clinical impression", .diagnosis),
        ("differential diagnosis", .diagnosis),
        ("mental disorder", .diagnosis),
        ("diagnoses", .diagnosis),
        ("diagnosis", .diagnosis),
        ("formulation", .diagnosis),
        // Legal criteria — specific before generic
        ("legal criteria", .legalCriteria),
        ("statutory criteria", .legalCriteria),
        ("criteria for detention", .legalCriteria),
        ("criteria for continued detention", .legalCriteria),
        ("case for detention", .legalCriteria),
        ("case for maintaining", .legalCriteria),
        ("summary of case", .legalCriteria),
        ("relevance of mca", .legalCriteria),
        ("mental capacity", .legalCriteria),
        ("capacity", .legalCriteria),
        ("opinion and recommendations", .legalCriteria),
        ("recommendations", .legalCriteria),
        ("opinion", .legalCriteria),
        ("conclusion", .legalCriteria),
        ("any other relevant information", .legalCriteria),
        // Strengths
        ("patient's strengths", .strengths),
        ("strengths and positive factors", .strengths),
        ("strengths", .strengths),
        ("positive factors", .strengths),
        ("protective factors", .strengths),
        // Signature
        ("name of author", .signature),
        ("name of clinician", .signature),
        ("name of responsible clinician", .signature),
        ("signature", .signature),
        ("signed", .signature),
        ("declaration", .signature),
    ]

    /// Maps T131 numbered questions (1-24) to GPR sections
    private static let t131ToGPR: [Int: GPRSection] = [
        1: .patientDetails, 2: .signature,
        3: .legalCriteria, 4: .legalCriteria,
        5: .forensicHistory, 6: .psychiatricHistory, 7: .psychiatricHistory,
        8: .circumstances,
        9: .diagnosis, 10: .diagnosis,
        11: .legalCriteria, 12: .medication,
        13: .strengths, 14: .circumstances, 15: .medication,
        16: .legalCriteria,
        17: .risk, 18: .risk,
        19: .legalCriteria, 20: .legalCriteria, 21: .risk,
        22: .legalCriteria, 23: .legalCriteria,
        24: .signature,
    ]

    /// Sub-headers for T131 questions when multiple merge into one GPR section
    private static let t131SubHeaders: [Int: String] = [
        3: "Factors Affecting Hearing",
        4: "Adjustments",
        5: "Forensic History",
        6: "Previous Admissions",
        7: "Previous Admission Reasons",
        8: "Circumstances of Admission",
        9: "Mental Disorder",
        10: "Learning Disability",
        11: "Detention Required",
        12: "Treatment",
        13: "Strengths",
        14: "Progress",
        15: "Compliance",
        16: "MCA/DoL",
        17: "Incidents of Harm",
        18: "Property Damage",
        19: "Section 2 Detention",
        20: "Other Detention",
        21: "Discharge Risk",
        22: "Community Management",
        23: "Recommendations",
        24: "Signature",
    ]

    /// T131 template question text prefixes to strip during cleaning
    private static let questionPatterns: [String] = [
        "are there any factors", "are there any adjustments",
        "what is the nature of", "give details of any",
        "what are the strengths", "give a summary of",
        "in section 2 cases", "in all other cases",
        "if the patient was discharged", "if the patient were discharged",
        "please explain how", "is there any other relevant",
        "do you have any recommendations", "is the patient now suffering",
        "what appropriate and available", "what are the dates",
        "what are the circumstances", "give reasons for",
        "does the patient have a learning", "what is it about",
        "would they be likely to act", "managed effectively in the community",
        "if yes, has a diagnosis", "if yes, what is the diagnosis",
        "has a diagnosis been made", "what is the diagnosis",
    ]

    /// Detect whether an imported document is a psychiatric report rather than clinical notes
    private static func isGPRReport(_ document: ExtractedDocument) -> Bool {
        let text = document.text
        let textLower = text.lowercased()

        print("[GPR iOS] isGPRReport check: notes=\(document.notes.count), text=\(text.count) chars")

        // Check 1: Single long note (>2000 chars) + at least 2 fingerprint matches
        if document.notes.count == 1 && document.notes[0].body.count > 2000 {
            let fpMatches = gprReportFingerprints.filter { textLower.contains($0) }.count
            if fpMatches >= 2 {
                print("[GPR iOS] isGPRReport=true (single long note \(document.notes[0].body.count) chars, \(fpMatches) fingerprints)")
                return true
            }
        }

        // Check 2: Numbered question scan — regex for ^\s*(\d+)[.)] patterns in range 1-24
        let lines = text.components(separatedBy: .newlines)
        var questionNumbers = Set<Int>()
        let questionRegex = try? NSRegularExpression(pattern: #"^\s*(\d+)[\.\)]\s*"#, options: [])
        for line in lines {
            let nsLine = line as NSString
            if let match = questionRegex?.firstMatch(in: line, options: [], range: NSRange(location: 0, length: nsLine.length)) {
                let numStr = nsLine.substring(with: match.range(at: 1))
                if let num = Int(numStr), num >= 1 && num <= 24 {
                    questionNumbers.insert(num)
                }
            }
        }
        if questionNumbers.count >= 5 {
            print("[GPR iOS] isGPRReport=true (found \(questionNumbers.count) numbered questions)")
            return true
        }

        // Check 3: Fingerprint keywords — 3+ matches
        let fingerprintMatches = gprReportFingerprints.filter { textLower.contains($0) }.count
        if fingerprintMatches >= 3 {
            print("[GPR iOS] isGPRReport=true (matched \(fingerprintMatches) keyword fingerprints)")
            return true
        }

        // Check 4: No notes but substantial text (>500 chars) with some indicators
        if document.notes.isEmpty && text.count > 500 {
            if questionNumbers.count >= 2 || fingerprintMatches >= 1 {
                print("[GPR iOS] isGPRReport=true (no notes, \(text.count) chars, \(questionNumbers.count) questions, \(fingerprintMatches) fingerprints)")
                return true
            }
        }

        // Check 5: Heading scan — 3+ unique heading matches
        var matchedSections = Set<GPRSection>()
        for (pattern, section) in gprHeadingPatterns {
            if textLower.contains(pattern) && !matchedSections.contains(section) {
                matchedSections.insert(section)
            }
        }
        if matchedSections.count >= 3 {
            print("[GPR iOS] isGPRReport=true (found \(matchedSections.count) heading matches)")
            return true
        }

        print("[GPR iOS] isGPRReport=false")
        return false
    }

    /// Parse a GPR report text into sections. Tries numbered format first, falls back to heading-based.
    private func parseGPRReportSections(from text: String) -> [GPRSection: String] {
        // Mode A: Try T131 numbered sections — require at least 6 sections
        // to avoid false triggers on short numbered lists (e.g. 4-item statutory criteria)
        let numbered = parseNumberedSections(from: text)
        if numbered.count >= 6 {
            return consolidateNumberedSections(numbered)
        }
        // Mode B: Heading-based detection
        return parseHeadingSections(from: text)
    }

    /// Parse T131-style numbered sections from text
    private func parseNumberedSections(from text: String) -> [(questionNumber: Int, text: String)] {
        var result: [(questionNumber: Int, text: String)] = []

        // Pre-process: insert newlines before section number patterns
        var processedText = text
        if let splitRegex = try? NSRegularExpression(pattern: #"(?<=\s)(\d{1,2})\.\s+(?=[A-Z])"#) {
            let nsStr = processedText as NSString
            processedText = splitRegex.stringByReplacingMatches(
                in: processedText,
                range: NSRange(location: 0, length: nsStr.length),
                withTemplate: "\n$1. "
            )
        }

        let lines = processedText.components(separatedBy: .newlines)
        let questionRegex = try? NSRegularExpression(pattern: #"^\s*(\d+)[\.\)]\s*(.*)"#, options: [])

        var currentQuestion: Int? = nil
        var currentLines: [String] = []

        func flush() {
            guard let qNum = currentQuestion else { return }
            let sectionText = cleanGPRSectionText(currentLines.joined(separator: "\n"))
            if !sectionText.isEmpty {
                result.append((questionNumber: qNum, text: sectionText))
            }
        }

        for line in lines {
            let nsLine = line as NSString
            if let match = questionRegex?.firstMatch(in: line, options: [], range: NSRange(location: 0, length: nsLine.length)) {
                let numStr = nsLine.substring(with: match.range(at: 1))
                let remainder = nsLine.substring(with: match.range(at: 2))
                if let num = Int(numStr), num >= 1 && num <= 24 {
                    // Accept if sequential (next or skip up to 4) to handle T131 forms with skipped questions
                    let prev = currentQuestion ?? 0
                    let isSequential = (num > prev && num <= prev + 5)
                    if !isSequential && currentQuestion != nil {
                        currentLines.append(line)
                        continue
                    }
                    flush()
                    currentQuestion = num
                    currentLines = remainder.trimmingCharacters(in: .whitespaces).isEmpty ? [] : [remainder]
                    continue
                }
            }
            if currentQuestion != nil {
                currentLines.append(line)
            }
        }
        flush()

        print("[GPR iOS] Parsed \(result.count) numbered sections")
        return result
    }

    /// Consolidate numbered T131 sections into GPR sections using t131ToGPR mapping
    private func consolidateNumberedSections(_ numbered: [(questionNumber: Int, text: String)]) -> [GPRSection: String] {
        var result: [GPRSection: String] = [:]

        // Group by GPR section
        var sectionEntries: [GPRSection: [(num: Int, text: String)]] = [:]
        for entry in numbered {
            guard let gprSection = Self.t131ToGPR[entry.questionNumber] else { continue }
            sectionEntries[gprSection, default: []].append((num: entry.questionNumber, text: entry.text))
        }

        // Merge entries with sub-headers when multiple questions map to same section
        for (section, entries) in sectionEntries {
            if entries.count == 1 {
                result[section] = entries[0].text
            } else {
                // Multiple questions -> add bold sub-headers
                var parts: [String] = []
                for entry in entries {
                    let header = Self.t131SubHeaders[entry.num] ?? "Section \(entry.num)"
                    parts.append("**\(header):**\n\(entry.text)")
                }
                result[section] = parts.joined(separator: "\n\n")
            }
        }

        print("[GPR iOS] Consolidated into \(result.count) GPR sections")
        return result
    }

    /// Parse heading-based sections from generic/narrative reports.
    /// Works line-by-line to detect headings using multiple heuristics:
    /// - Heading line must be short (< 150 chars)
    /// - Pattern must be significant portion of line (or line < 80 chars)
    /// - Rejects mid-sentence PDF wraps (pattern followed by comma)
    /// - Rejects table labels (heading must be preceded by a blank line)
    /// Finds ALL occurrences so repeated headings (e.g. two "STATUTORY CRITERIA") are captured.
    private func parseHeadingSections(from text: String) -> [GPRSection: String] {
        // Normalize line endings (\r\n → \n, \r → \n)
        let normalizedText = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let lines = normalizedText.components(separatedBy: "\n")

        struct HeadingMatch {
            let lineIndex: Int
            let section: GPRSection
            let patternLength: Int
        }

        // Step 1: Find heading lines
        var headingMatches: [HeadingMatch] = []

        for (i, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            guard trimmed.count < 150 else { continue } // Real headings are short

            let lower = trimmed.lowercased()

            // Check if line is ALL CAPS (strong heading indicator)
            let isAllCaps = trimmed.count > 5
                && trimmed.rangeOfCharacter(from: .letters) != nil
                && trimmed.uppercased() == trimmed

            // Multi-section check: if this line matches patterns from 2+ different
            // sections, it's likely a table header row (e.g. "Current diagnosis Current medication Name of care")
            var sectionsOnLine = Set<GPRSection>()
            for (pattern, section) in Self.gprHeadingPatterns {
                if lower.contains(pattern) {
                    sectionsOnLine.insert(section)
                }
            }
            if sectionsOnLine.count > 1 {
                continue // Table header line — skip
            }

            // Try to match heading patterns — keep the longest/most specific match
            var bestMatch: (pattern: String, section: GPRSection)? = nil

            for (pattern, section) in Self.gprHeadingPatterns {
                guard lower.contains(pattern) else { continue }

                // Pattern should be significant portion of line, or line is short
                let ratio = Double(pattern.count) / Double(trimmed.count)
                guard trimmed.count < 80 || ratio > 0.25 else { continue }

                // After the pattern, should NOT start with comma (mid-sentence PDF wrap)
                if let pRange = lower.range(of: pattern) {
                    let after = String(lower[pRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if after.hasPrefix(",") { continue }
                }

                // Keep longest match
                if bestMatch == nil || pattern.count > bestMatch!.pattern.count {
                    bestMatch = (pattern, section)
                }
            }

            if let match = bestMatch {
                // Pattern-start-position check: ANY matching pattern for the same section
                // should appear near the start of the line (within first 5 chars) unless ALL CAPS.
                // This filters lines like "Other factors you consider relevant To include
                // family and personal history as needed" where patterns appear mid-line.
                // We check ALL patterns (not just best match) because compound headings like
                // "Family history and personal history" have "family history" at position 0
                // even though best match "personal history" is at position 19.
                if !isAllCaps {
                    var anyPatternNearStart = false
                    for (p, s) in Self.gprHeadingPatterns {
                        guard s == match.section else { continue }
                        if let pRange = lower.range(of: p) {
                            let pos = lower.distance(from: lower.startIndex, to: pRange.lowerBound)
                            if pos <= 5 {
                                anyPatternNearStart = true
                                break
                            }
                        }
                    }
                    if !anyPatternNearStart {
                        continue
                    }
                }

                headingMatches.append(HeadingMatch(lineIndex: i, section: match.section, patternLength: match.pattern.count))
            }
        }

        guard !headingMatches.isEmpty else {
            print("[GPR iOS] No heading lines found")
            return [:]
        }

        print("[GPR iOS] Found \(headingMatches.count) heading lines")

        // Step 2: Extract text between heading lines, merge by section
        var result: [GPRSection: String] = [:]

        for (j, heading) in headingMatches.enumerated() {
            let contentStartLine = heading.lineIndex + 1
            let contentEndLine: Int
            if j + 1 < headingMatches.count {
                contentEndLine = headingMatches[j + 1].lineIndex
            } else {
                contentEndLine = lines.count
            }

            guard contentStartLine < contentEndLine else { continue }

            var sectionText = lines[contentStartLine..<contentEndLine].joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            // Strip leading colon/semicolon/period
            while sectionText.hasPrefix(":") || sectionText.hasPrefix(".") || sectionText.hasPrefix(";") {
                sectionText = String(sectionText.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
            }

            let cleaned = cleanGPRSectionText(sectionText)
            if !cleaned.isEmpty {
                if let existing = result[heading.section] {
                    result[heading.section] = existing + "\n\n" + cleaned
                } else {
                    result[heading.section] = cleaned
                }
            }
        }

        print("[GPR iOS] Parsed \(result.count) heading-based sections")
        return result
    }

    /// Clean section text by stripping checkbox markers, question text, and normalizing whitespace
    private func cleanGPRSectionText(_ text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        var cleaned: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { cleaned.append(""); continue }

            // Skip checkbox-only lines
            let cbPattern = try? NSRegularExpression(
                pattern: #"^[\s☐☑☒✓✗□■\[\]]*\s*(Yes|No|N/?A|NA)[\s☐☑☒✓✗□■\[\]]*\s*(Yes|No|N/?A|NA)?[\s☐☑☒✓✗□■\[\]]*\s*(Yes|No|N/?A|NA)?[\s☐☑☒✓✗□■\[\]]*$"#,
                options: .caseInsensitive
            )
            let nsLine = trimmed as NSString
            if let cbMatch = cbPattern?.firstMatch(in: trimmed, options: [], range: NSRange(location: 0, length: nsLine.length)) {
                if cbMatch.range.length == nsLine.length { continue }
            }

            // Skip "see above" / "as above" / "n/a" / "nil" lines
            let lowerTrimmed = trimmed.lowercased()
            if lowerTrimmed == "see above" || lowerTrimmed == "as above" ||
               lowerTrimmed == "refer to above" || lowerTrimmed == "as per above" ||
               lowerTrimmed == "n/a" || lowerTrimmed == "na" || lowerTrimmed == "nil" {
                continue
            }

            // Skip T131 question text lines
            if isQuestionText(trimmed) { continue }

            cleaned.append(trimmed)
        }

        var result = cleaned.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip inline checkbox markers
        if let cbInline = try? NSRegularExpression(pattern: #"[☐☑☒✓✗□■]\s*(?:Yes|No|N/?A)\s*"#, options: .caseInsensitive) {
            result = cbInline.stringByReplacingMatches(in: result, range: NSRange(location: 0, length: (result as NSString).length), withTemplate: "")
        }
        for char in ["☐", "☑", "☒", "✓", "✗", "□", "■"] {
            result = result.replacingOccurrences(of: char, with: "")
        }

        // Normalize multiple newlines
        if let multiNewline = try? NSRegularExpression(pattern: #"\n{3,}"#) {
            result = multiNewline.stringByReplacingMatches(in: result, range: NSRange(location: 0, length: (result as NSString).length), withTemplate: "\n\n")
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Check if text is a T131 question/heading rather than answer content
    private func isQuestionText(_ text: String) -> Bool {
        guard text.count >= 10 else { return false }
        // Strip leading checkbox/number markers
        var lower = text.lowercased().trimmingCharacters(in: .whitespaces)
        if let cleanRegex = try? NSRegularExpression(pattern: #"^[\[\]☐☒xX\s\-–\d\.]*"#) {
            let nsStr = lower as NSString
            if let match = cleanRegex.firstMatch(in: lower, range: NSRange(location: 0, length: nsStr.length)) {
                lower = nsStr.substring(from: match.range.upperBound).trimmingCharacters(in: .whitespaces)
            }
        }

        for pattern in Self.questionPatterns {
            if lower.hasPrefix(pattern) { return true }
        }

        // Numbered question pattern - only match when followed by question words
        // to avoid stripping valid numbered content (medication lists, offences, etc.)
        if let numRegex = try? NSRegularExpression(pattern: #"^\d{1,2}\.\s+(?:What|Are|Is|Give|Do|Does|Has|Have|If|Please|Would|Provide|Describe|State|Set)"#, options: .caseInsensitive) {
            let nsStr = text as NSString
            if numRegex.firstMatch(in: text, range: NSRange(location: 0, length: nsStr.length)) != nil {
                return true
            }
        }

        return false
    }

    /// Extract patient details from the patient details section text
    private func extractPatientDetailsFromReport(_ text: String) {
        let nsText = text as NSString

        // Name
        if let nameRegex = try? NSRegularExpression(pattern: #"(?:Name|PATIENT)[:\s]+(.+?)(?:\n|$)"#, options: .caseInsensitive) {
            if let match = nameRegex.firstMatch(in: text, range: NSRange(location: 0, length: nsText.length)) {
                formData.patientName = nsText.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
            }
        }

        // DOB
        if let dobRegex = try? NSRegularExpression(pattern: #"(?:DOB|Date\s*of\s*Birth)[:\s]+(.+?)(?:\n|$)"#, options: .caseInsensitive) {
            if let match = dobRegex.firstMatch(in: text, range: NSRange(location: 0, length: nsText.length)) {
                var dobStr = nsText.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
                // Remove ordinal suffixes
                if let ordRegex = try? NSRegularExpression(pattern: #"(\d+)(?:st|nd|rd|th)"#) {
                    dobStr = ordRegex.stringByReplacingMatches(in: dobStr, range: NSRange(location: 0, length: (dobStr as NSString).length), withTemplate: "$1")
                }
                dobStr = dobStr.replacingOccurrences(of: ",", with: "")

                let formats = ["dd MMMM yyyy", "dd/MM/yyyy", "dd-MM-yyyy", "dd MMM yyyy", "yyyy-MM-dd"]
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_GB")
                for fmt in formats {
                    formatter.dateFormat = fmt
                    if let date = formatter.date(from: dobStr.trimmingCharacters(in: .whitespaces)) {
                        formData.patientDOB = date
                        break
                    }
                }
            }
        }

        // Gender
        if let genderRegex = try? NSRegularExpression(pattern: #"(?:Gender|Sex)[:\s]+(Male|Female|Other)"#, options: .caseInsensitive) {
            if let match = genderRegex.firstMatch(in: text, range: NSRange(location: 0, length: nsText.length)) {
                let genderStr = nsText.substring(with: match.range(at: 1)).lowercased()
                switch genderStr {
                case "male": formData.patientGender = .male
                case "female": formData.patientGender = .female
                default: break
                }
            }
        }

        // MHA Section
        if let mhaRegex = try? NSRegularExpression(pattern: #"(?:MHA\s*Status|MHA\s*Section|Detained\s*Under)[:\s]+(.+?)(?:\n|$)"#, options: .caseInsensitive) {
            if let match = mhaRegex.firstMatch(in: text, range: NSRange(location: 0, length: nsText.length)) {
                formData.mhaSection = nsText.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
            }
        }

        // Hospital/Ward
        if let locRegex = try? NSRegularExpression(pattern: #"(?:Hospital|Ward|Address|Residence)[:\s]+(.+?)(?:\n|$)"#, options: .caseInsensitive) {
            if let match = locRegex.firstMatch(in: text, range: NSRange(location: 0, length: nsText.length)) {
                formData.currentLocation = nsText.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
            }
        }

        // Admission Date
        if let admRegex = try? NSRegularExpression(pattern: #"(?:Date\s*of\s*Admission|Admission\s*Date)[:\s]+(.+?)(?:\n|$)"#, options: .caseInsensitive) {
            if let match = admRegex.firstMatch(in: text, range: NSRange(location: 0, length: nsText.length)) {
                var admStr = nsText.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
                if let ordRegex = try? NSRegularExpression(pattern: #"(\d+)(?:st|nd|rd|th)"#) {
                    admStr = ordRegex.stringByReplacingMatches(in: admStr, range: NSRange(location: 0, length: (admStr as NSString).length), withTemplate: "$1")
                }
                admStr = admStr.replacingOccurrences(of: ",", with: "")
                let formats = ["dd MMMM yyyy", "dd/MM/yyyy", "dd-MM-yyyy", "dd MMM yyyy", "yyyy-MM-dd"]
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_GB")
                for fmt in formats {
                    formatter.dateFormat = fmt
                    if let date = formatter.date(from: admStr.trimmingCharacters(in: .whitespaces)) {
                        formData.admissionDate = date
                        break
                    }
                }
            }
        }
    }

    /// Populate GPR form data from parsed report sections
    private func populateFromReport(_ sections: [GPRSection: String]) {
        print("[GPR iOS] populateFromReport: \(sections.count) sections")
        isReportMode = true

        // Clear existing imported entries
        formData.psychiatricHistoryImported.removeAll()
        formData.riskImportedEntries.removeAll()
        formData.backgroundImportedEntries.removeAll()
        formData.medicalHistoryImported.removeAll()
        formData.substanceUseImported.removeAll()
        formData.forensicHistoryImported.removeAll()
        formData.medicationImported.removeAll()
        formData.diagnosisImported.removeAll()
        formData.legalCriteriaImported.removeAll()
        formData.strengthsImported.removeAll()
        formData.circumstancesImported.removeAll()
        formData.clerkingNotes.removeAll()
        formData.admissionsTableData.removeAll()

        func makeEntry(_ text: String) -> GPRImportedEntry {
            GPRImportedEntry(date: nil, text: text, snippet: String(text.prefix(200)), categories: ["Report"])
        }

        for (section, text) in sections {
            guard !text.isEmpty else { continue }

            switch section {
            case .patientDetails:
                extractPatientDetailsFromReport(text)

            case .reportBasedOn:
                generatedTexts[.reportBasedOn] = text
                // Tick source checkboxes by keyword
                let lower = text.lowercased()
                if lower.contains("medical") || lower.contains("doctor") { formData.sourceMedicalReports = true }
                if lower.contains("nurs") { formData.sourceNursingInterviews = true }
                if lower.contains("patient") || lower.contains("interview") { formData.sourcePatientInterviews = true }
                if lower.contains("psycholog") { formData.sourcePsychologyReports = true }
                if lower.contains("social") { formData.sourceSocialWorkReports = true }
                if lower.contains("occupational") || lower.contains("o.t") || lower.contains(" ot ") { formData.sourceOTReports = true }
                if lower.contains("placement") || lower.contains("current") { formData.sourceCurrentPlacementNotes = true }

            case .circumstances:
                formData.circumstancesImported.append(makeEntry(text))

            case .background:
                formData.backgroundImportedEntries.append(makeEntry(text))

            case .medicalHistory:
                formData.medicalHistoryImported.append(makeEntry(text))

            case .psychiatricHistory:
                formData.psychiatricHistoryImported.append(makeEntry(text))

            case .risk:
                formData.riskImportedEntries.append(makeEntry(text))

            case .substanceUse:
                formData.substanceUseImported.append(makeEntry(text))

            case .forensicHistory:
                formData.forensicHistoryImported.append(makeEntry(text))

            case .medication:
                formData.medicationImported.append(makeEntry(text))

            case .diagnosis:
                formData.diagnosisImported.append(makeEntry(text))
                // Extract ICD-10 codes
                let extractions = ICD10Diagnosis.extractFromText(text)
                if extractions.count > 0 { formData.diagnosis1ICD10 = extractions[0].diagnosis }
                if extractions.count > 1 { formData.diagnosis2ICD10 = extractions[1].diagnosis }
                if extractions.count > 2 { formData.diagnosis3ICD10 = extractions[2].diagnosis }

            case .legalCriteria:
                formData.legalCriteriaImported.append(makeEntry(text))

            case .strengths:
                formData.strengthsImported.append(makeEntry(text))

            case .signature:
                // Extract clinician name
                if let nameRegex = try? NSRegularExpression(pattern: #"(?:Name|Signed|Clinician)[:\s]+(.+?)(?:\n|$)"#, options: .caseInsensitive) {
                    let nsText = text as NSString
                    if let match = nameRegex.firstMatch(in: text, range: NSRange(location: 0, length: nsText.length)) {
                        formData.signatureName = nsText.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
                    }
                }
            }
        }

        // Post-processing: extract diagnosis and medication from patient details
        // when they don't have standalone headings
        if sections[.diagnosis] == nil, let pdText = sections[.patientDetails] {
            extractDiagnosisFromPatientDetails(pdText)
        }
        if sections[.medication] == nil, let pdText = sections[.patientDetails] {
            extractMedicationFromPatientDetails(pdText)
        }

        print("[GPR iOS] populateFromReport complete: \(sections.count) sections mapped")
    }

    /// Extract diagnosis from patient details table when no standalone heading exists
    private func extractDiagnosisFromPatientDetails(_ text: String) {
        let lines = text.components(separatedBy: .newlines)
        // Look for ICD-10 code pattern (F##.# or F##) in any line
        let icdRegex = try? NSRegularExpression(pattern: #"(F\d{2}(?:\.\d{1,2})?)\s+(.+)"#)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let regex = icdRegex,
               let match = regex.firstMatch(in: trimmed, range: NSRange(location: 0, length: (trimmed as NSString).length)) {
                let diagText = trimmed
                formData.diagnosisImported.append(
                    GPRImportedEntry(date: nil, text: diagText, snippet: String(diagText.prefix(200)), categories: ["Report"])
                )
                // Extract ICD-10 codes
                let extractions = ICD10Diagnosis.extractFromText(diagText)
                if extractions.count > 0 { formData.diagnosis1ICD10 = extractions[0].diagnosis }
                if extractions.count > 1 { formData.diagnosis2ICD10 = extractions[1].diagnosis }
                if extractions.count > 2 { formData.diagnosis3ICD10 = extractions[2].diagnosis }
                break
            }
        }
    }

    /// Extract medication from patient details table when no standalone heading exists
    private func extractMedicationFromPatientDetails(_ text: String) {
        let lines = text.components(separatedBy: .newlines)
        // Look for lines that contain drug names with dose patterns (mg, mcg, units)
        let medRegex = try? NSRegularExpression(pattern: #"\d+\s*(?:mg|mcg|microgram|unit|ml)"#, options: .caseInsensitive)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            // Skip header lines
            let lower = trimmed.lowercased()
            if lower.contains("current medication") || lower.contains("current diagnosis") { continue }
            // Check if this line looks like a medication (contains dose)
            if let regex = medRegex,
               regex.firstMatch(in: trimmed, range: NSRange(location: 0, length: (trimmed as NSString).length)) != nil {
                formData.medicationImported.append(
                    GPRImportedEntry(date: nil, text: trimmed, snippet: String(trimmed.prefix(200)), categories: ["Report"])
                )
                break
            }
        }
    }
}

// MARK: - GPR Editable Card (Green theme for reports)
struct GPREditableCard: View {
    let section: GeneralPsychReportView.GPRSection
    @Binding var text: String
    let onHeaderTap: () -> Void

    @State private var editorHeight: CGFloat = 150

    var body: some View {
        VStack(spacing: 0) {
            // Header - tappable to open popup
            Button(action: onHeaderTap) {
                HStack(spacing: 10) {
                    Image(systemName: section.icon)
                        .foregroundColor(Color(hex: "008C7E") ?? .teal)
                        .frame(width: 20)

                    Text(section.rawValue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(Color(hex: "008C7E") ?? .teal)
                        .font(.caption)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
            }
            .buttonStyle(.plain)

            // Editable text area
            TextEditor(text: $text)
                .frame(height: editorHeight)
                .padding(8)
                .scrollContentBackground(.hidden)

            // Resize handle
            ResizeHandle(height: $editorHeight)
        }
        .background(.thinMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.7), radius: 12, y: 6)
        .onAppear {
            editorHeight = section.defaultHeight
        }
    }
}

// MARK: - GPR Popup View
struct GPRPopupView: View {
    let section: GeneralPsychReportView.GPRSection
    @Binding var formData: GPRFormData
    let manualNotes: String
    let onGenerate: (String, String) -> Void
    let onDismiss: () -> Void

    @State private var editableNotes: String = ""

    // Computed patient info combining form data with gender for gender-sensitive text generation
    private var combinedPatientInfo: PatientInfo {
        var info = PatientInfo()
        let names = formData.patientName.components(separatedBy: " ")
        info.firstName = names.first ?? ""
        info.lastName = names.dropFirst().joined(separator: " ")
        info.gender = formData.patientGender
        info.dateOfBirth = formData.patientDOB
        return info
    }

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
        case .reportBasedOn: reportBasedOnPopup
        case .circumstances: circumstancesPopup
        case .background: backgroundPopup
        case .medicalHistory: medicalHistoryPopup
        case .psychiatricHistory: psychiatricHistoryPopup
        case .risk: riskPopup
        case .substanceUse: substanceUsePopup
        case .forensicHistory: forensicHistoryPopup
        case .medication: medicationPopup
        case .diagnosis: diagnosisPopup
        case .legalCriteria: legalCriteriaPopup
        case .strengths: strengthsPopup
        case .signature: signaturePopup
        }
    }

    // MARK: - Section 1: Patient Details Popup
    private var patientDetailsPopup: some View {
        VStack(alignment: .leading, spacing: 12) {
            FormTextField(label: "Name", text: $formData.patientName, isRequired: true)

            HStack {
                Text("Gender").font(.subheadline).foregroundColor(.secondary)
                Spacer()
                Picker("", selection: $formData.patientGender) {
                    ForEach(Gender.allCases) { g in Text(g.rawValue).tag(g) }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            FormOptionalDatePicker(label: "Date of Birth", date: $formData.patientDOB,
                                   maxDate: Calendar.current.date(byAdding: .year, value: -18, to: Date()),
                                   minDate: Calendar.current.date(byAdding: .year, value: -100, to: Date()),
                                   defaultDate: Calendar.current.date(byAdding: .year, value: -18, to: Date()))

            // Calculated Age
            if let dob = formData.patientDOB {
                HStack {
                    Text("Age").font(.subheadline).foregroundColor(.secondary)
                    Spacer()
                    Text("\(Calendar.current.dateComponents([.year], from: dob, to: Date()).year ?? 0) years")
                        .foregroundColor(.primary)
                }
            }

            // MHA Section with picker
            VStack(alignment: .leading, spacing: 4) {
                Text("MHA Section").font(.subheadline).foregroundColor(.secondary)
                Picker("", selection: $formData.mhaSection) {
                    Text("Section 2").tag("Section 2")
                    Text("Section 3").tag("Section 3")
                    Text("Section 37").tag("Section 37")
                    Text("Section 37/41").tag("Section 37/41")
                    Text("Section 47").tag("Section 47")
                    Text("Section 47/49").tag("Section 47/49")
                    Text("Section 48/49").tag("Section 48/49")
                    Text("CTO").tag("CTO")
                    Text("Conditional Discharge").tag("Conditional Discharge")
                    Text("Informal").tag("Informal")
                    Text("Other").tag("Other")
                }
                .pickerStyle(.menu)
            }

            FormOptionalDatePicker(label: "Admission Date", date: $formData.admissionDate)
            FormTextField(label: "Current Location (Hospital/Ward)", text: $formData.currentLocation)
            FormTextField(label: "Report By", text: $formData.reportBy)
            FormOptionalDatePicker(label: "Date Seen", date: $formData.dateSeen)
        }
    }

    // MARK: - Section 2: Report Based On Popup
    private var reportBasedOnPopup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Document Sources").font(.headline)

            Toggle("Medical reports from the above", isOn: $formData.sourceMedicalReports)
            Toggle("Interviews with nursing staff", isOn: $formData.sourceNursingInterviews)
            Toggle("Interviews with the patient", isOn: $formData.sourcePatientInterviews)
            Toggle("Previous notes from current placement", isOn: $formData.sourceCurrentPlacementNotes)
            Toggle("Previous notes from other placements", isOn: $formData.sourceOtherPlacementNotes)
            Toggle("Psychology reports", isOn: $formData.sourcePsychologyReports)
            Toggle("Social work reports", isOn: $formData.sourceSocialWorkReports)
            Toggle("Occupational therapy reports", isOn: $formData.sourceOTReports)
        }
    }

    // MARK: - Section 6: Psychiatric History Popup
    private var psychiatricHistoryPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Detected Admissions Table (matching desktop)
            GPRCollapsibleSection(title: "Detected Admissions (\(formData.admissionsTableData.count))", color: .blue) {
                if formData.admissionsTableData.isEmpty {
                    Text("No admissions detected. Import notes to populate.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Include table in output", isOn: $formData.includeAdmissionsTable)
                            .font(.caption)

                        // Table header
                        HStack {
                            Text("Admission Date")
                                .font(.caption.weight(.semibold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("Discharge Date")
                                .font(.caption.weight(.semibold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("Duration")
                                .font(.caption.weight(.semibold))
                                .frame(width: 80, alignment: .trailing)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)

                        // Table rows
                        ForEach(formData.admissionsTableData.indices, id: \.self) { index in
                            HStack {
                                if let admDate = formData.admissionsTableData[index].admissionDate {
                                    Text(admDate, format: .dateTime.day().month(.abbreviated).year())
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                } else {
                                    Text("Unknown")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                if let disDate = formData.admissionsTableData[index].dischargeDate {
                                    Text(disDate, format: .dateTime.day().month(.abbreviated).year())
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                } else {
                                    Text("Ongoing")
                                        .foregroundColor(.orange)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                Text(formData.admissionsTableData[index].duration)
                                    .foregroundColor(.secondary)
                                    .frame(width: 80, alignment: .trailing)
                            }
                            .font(.caption)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            Divider()
                        }
                    }
                }
            }

            // Admission Clerking Notes (matching desktop)
            if !formData.clerkingNotes.isEmpty {
                GPRCollapsibleSection(title: "Admission Clerking Notes (\(formData.clerkingNotes.count))", color: .blue) {
                    GPRImportedEntriesList(entries: $formData.clerkingNotes)
                }
            }

            // Extracted PPH Sections
            if !formData.psychiatricHistoryImported.isEmpty {
                GPRCollapsibleSection(title: "Imported Data (\(formData.psychiatricHistoryImported.count))", color: .yellow) {
                    GPRImportedEntriesList(entries: $formData.psychiatricHistoryImported)
                }
            }
        }
    }

    // MARK: - Section 7: Risk Popup
    private var riskPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Current Risk
            GPRCollapsibleSection(title: "Current Risk", color: .red) {
                ForEach(GPRRiskType.allCases, id: \.self) { riskType in
                    GPRRiskRow(
                        riskType: riskType,
                        level: Binding(
                            get: { formData.currentRisks[riskType] ?? .none },
                            set: { formData.currentRisks[riskType] = $0 }
                        )
                    )
                }
            }

            // Historical Risk
            GPRCollapsibleSection(title: "Historical Risk", color: .orange) {
                ForEach(GPRRiskType.allCases, id: \.self) { riskType in
                    GPRRiskRow(
                        riskType: riskType,
                        level: Binding(
                            get: { formData.historicalRisks[riskType] ?? .none },
                            set: { formData.historicalRisks[riskType] = $0 }
                        )
                    )
                }
            }

            // Imported Data
            if !formData.riskImportedEntries.isEmpty {
                GPRCollapsibleSection(title: "Imported Data (\(formData.riskImportedEntries.count))", color: .yellow) {
                    GPRImportedEntriesList(entries: $formData.riskImportedEntries)
                }
            }
        }
    }

    // MARK: - Section 4: Background Popup
    // Matches desktop background_history_popup.py structure exactly
    private var backgroundPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            // --- EARLY DEVELOPMENT SECTION ---
            GPRCollapsibleSection(title: "Early Development", color: .green) {
                VStack(alignment: .leading, spacing: 16) {
                    // Birth
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Birth").font(.subheadline.weight(.semibold))
                        GPRRadioGroup(
                            selection: $formData.backgroundBirth,
                            options: ["Normal", "Premature", "Complicated", "Unknown"]
                        )
                    }

                    Divider()

                    // Milestones
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Developmental Milestones").font(.subheadline.weight(.semibold))
                        GPRRadioGroup(
                            selection: $formData.backgroundMilestones,
                            options: ["Normal", "Delayed", "Walking delayed", "Talking delayed", "Learning delayed", "Unknown", "Other"]
                        )
                    }
                }
            }

            // --- FAMILY & CHILDHOOD SECTION ---
            GPRCollapsibleSection(title: "Family & Childhood", color: .green) {
                VStack(alignment: .leading, spacing: 16) {
                    // Family History of Mental Illness
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Family History of Mental Illness").font(.subheadline.weight(.semibold))
                        GPRRadioGroup(
                            selection: $formData.backgroundFamilyHistoryType,
                            options: [
                                "No significant family history of mental illness",
                                "Family history of mood disorders",
                                "Family history of schizophrenia/psychosis",
                                "Family history of substance misuse",
                                "Family history of personality disorder",
                                "Other family psychiatric history"
                            ]
                        )
                    }

                    Divider()

                    // Childhood Abuse
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Childhood Abuse/Trauma").font(.subheadline.weight(.semibold))

                        // Severity
                        Text("Severity").font(.caption).foregroundColor(.secondary)
                        GPRRadioGroup(
                            selection: $formData.backgroundAbuseSeverity,
                            options: ["None reported", "Suspected", "Confirmed"]
                        )

                        // Types (checkboxes) - only show if not "None reported"
                        if formData.backgroundAbuseSeverity != "None reported" {
                            Text("Types").font(.caption).foregroundColor(.secondary).padding(.top, 4)
                            VStack(alignment: .leading, spacing: 4) {
                                Toggle("Physical abuse", isOn: $formData.backgroundAbusePhysical)
                                Toggle("Sexual abuse", isOn: $formData.backgroundAbuseSexual)
                                Toggle("Emotional abuse", isOn: $formData.backgroundAbuseEmotional)
                                Toggle("Neglect", isOn: $formData.backgroundAbuseNeglect)
                            }
                            .font(.subheadline)
                        }
                    }

                    Divider()

                    // Risk History in Childhood
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Risk History in Childhood").font(.subheadline.weight(.semibold))
                        Picker("", selection: $formData.childhoodRiskHistory) {
                            Text("No significant risk behavior").tag("No significant risk behavior in childhood reported")
                            Text("Conduct disorder").tag("History of conduct disorder in childhood")
                            Text("Aggressive behavior").tag("History of aggressive behavior in childhood")
                            Text("Fire-setting").tag("History of fire-setting in childhood")
                            Text("Cruelty to animals").tag("History of cruelty to animals in childhood")
                            Text("Truancy/school refusal").tag("History of truancy and school refusal")
                            Text("Early substance misuse").tag("History of substance misuse from early age")
                            Text("Early CJS involvement").tag("Early involvement with criminal justice system")
                        }
                        .pickerStyle(.menu)
                    }
                }
            }

            // --- EDUCATION & WORK SECTION ---
            GPRCollapsibleSection(title: "Education & Work", color: .green) {
                VStack(alignment: .leading, spacing: 16) {
                    // Schooling
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Schooling").font(.subheadline.weight(.semibold))

                        // Severity
                        Text("School Experience").font(.caption).foregroundColor(.secondary)
                        GPRRadioGroup(
                            selection: $formData.backgroundSchoolingSeverity,
                            options: ["No problems", "Moderate problems", "Severe problems"]
                        )

                        // Issues (checkboxes) - show if has problems
                        if formData.backgroundSchoolingSeverity != "No problems" {
                            Text("Issues").font(.caption).foregroundColor(.secondary).padding(.top, 4)
                            VStack(alignment: .leading, spacing: 4) {
                                Toggle("Learning difficulties", isOn: $formData.backgroundSchoolingLearningDifficulties)
                                Toggle("ADHD/attention problems", isOn: $formData.backgroundSchoolingADHD)
                                Toggle("Bullied/victimized", isOn: $formData.backgroundSchoolingBullied)
                                Toggle("Excluded/expelled", isOn: $formData.backgroundSchoolingExcluded)
                                Toggle("Truancy", isOn: $formData.backgroundSchoolingTruancy)
                            }
                            .font(.subheadline)
                        }
                    }

                    Divider()

                    // Qualifications
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Highest Qualifications").font(.subheadline.weight(.semibold))
                        GPRRadioGroup(
                            selection: $formData.backgroundQualifications,
                            options: ["None", "CSE/O-Level", "GCSE", "A-Level", "NVQ/Vocational", "HND/Foundation", "Degree", "Postgraduate", "Unknown"]
                        )
                    }

                    Divider()

                    // Work History
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Work History Pattern").font(.subheadline.weight(.semibold))
                        GPRRadioGroup(
                            selection: $formData.backgroundWorkPattern,
                            options: ["Continuous employment", "Intermittent employment", "Rarely employed", "Never employed", "Unknown"]
                        )
                    }

                    Divider()

                    // Last Worked
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Last Worked").font(.subheadline.weight(.semibold))
                        GPRRadioGroup(
                            selection: $formData.backgroundLastWorked,
                            options: ["Currently working", "Within 1 year", "1-5 years ago", "5-10 years ago", "Over 10 years ago", "Never worked", "Unknown"]
                        )
                    }
                }
            }

            // --- IDENTITY & RELATIONSHIPS SECTION ---
            GPRCollapsibleSection(title: "Identity & Relationships", color: .green) {
                VStack(alignment: .leading, spacing: 16) {
                    // Sexual Orientation
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sexual Orientation").font(.subheadline.weight(.semibold))
                        GPRRadioGroup(
                            selection: $formData.backgroundSexualOrientation,
                            options: ["Heterosexual", "Homosexual", "Bisexual", "Other", "Not documented"]
                        )
                    }

                    Divider()

                    // Children
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Children").font(.subheadline.weight(.semibold))

                        Text("Number of Children").font(.caption).foregroundColor(.secondary)
                        GPRRadioGroup(
                            selection: $formData.backgroundChildrenCount,
                            options: ["None", "1", "2", "3", "4+", "Unknown"]
                        )

                        // Only show age/composition if has children
                        if formData.backgroundChildrenCount != "None" && formData.backgroundChildrenCount != "Unknown" {
                            Text("Age Band").font(.caption).foregroundColor(.secondary).padding(.top, 4)
                            GPRRadioGroup(
                                selection: $formData.backgroundChildrenAgeBand,
                                options: ["Pre-school", "Primary school", "Secondary school", "Adult", "Mixed ages", "N/A"]
                            )

                            Text("Composition").font(.caption).foregroundColor(.secondary).padding(.top, 4)
                            GPRRadioGroup(
                                selection: $formData.backgroundChildrenComposition,
                                options: ["Male only", "Female only", "Mixed", "Unknown", "N/A"]
                            )
                        }
                    }

                    Divider()

                    // Relationships
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Relationship Status").font(.subheadline.weight(.semibold))
                        GPRRadioGroup(
                            selection: $formData.backgroundRelationshipStatus,
                            options: ["Single", "In relationship", "Married/Civil partnership", "Divorced/Separated", "Widowed", "Unknown"]
                        )

                        // Duration - show if in relationship
                        if formData.backgroundRelationshipStatus == "In relationship" ||
                           formData.backgroundRelationshipStatus == "Married/Civil partnership" {
                            Text("Relationship Duration").font(.caption).foregroundColor(.secondary).padding(.top, 4)
                            GPRRadioGroup(
                                selection: $formData.backgroundRelationshipDuration,
                                options: ["Less than 1 year", "1-5 years", "5-10 years", "Over 10 years", "Unknown", "N/A"]
                            )
                        }
                    }
                }
            }

            // --- ADDITIONAL NOTES (legacy text fields) ---
            GPRCollapsibleSection(title: "Additional Notes (Optional)", color: .gray) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Use these text fields for any additional background information not captured above:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    FormTextEditor(label: "Family History Notes", text: $formData.backgroundFamilyHistory, minHeight: 40)
                    FormTextEditor(label: "Childhood Notes", text: $formData.backgroundChildhoodHistory, minHeight: 40)
                    FormTextEditor(label: "Education Notes", text: $formData.backgroundEducation, minHeight: 40)
                    FormTextEditor(label: "Relationships Notes", text: $formData.backgroundRelationships, minHeight: 40)
                }
            }

            // Imported Notes
            if !formData.backgroundImportedEntries.isEmpty {
                GPRCollapsibleSection(title: "Imported Data (\(formData.backgroundImportedEntries.count))", color: .yellow) {
                    GPRImportedEntriesList(entries: $formData.backgroundImportedEntries)
                }
            }
        }
    }

    // MARK: - Section 5: Medical History Popup
    // Matches desktop physical_health_popup.py with 8 categories
    // Uses teal color (#008c7e) matching desktop theme
    private var medicalHistoryPopup: some View {
        let tealColor = Color(red: 0, green: 140/255, blue: 126/255) // #008c7e

        return VStack(alignment: .leading, spacing: 16) {
            // --- Cardiac Conditions ---
            GPRCollapsibleSection(title: "Cardiac Conditions", color: tealColor) {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Hypertension", isOn: $formData.medicalCardiacHypertension)
                    Toggle("MI (Myocardial Infarction)", isOn: $formData.medicalCardiacMI)
                    Toggle("Arrhythmias", isOn: $formData.medicalCardiacArrhythmias)
                    Toggle("High Cholesterol", isOn: $formData.medicalCardiacHighCholesterol)
                    Toggle("Heart Failure", isOn: $formData.medicalCardiacHeartFailure)
                }
                .font(.subheadline)
            }

            // --- Endocrine Conditions ---
            GPRCollapsibleSection(title: "Endocrine Conditions", color: tealColor) {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Diabetes", isOn: $formData.medicalEndocrineDiabetes)
                    Toggle("Thyroid Disorder", isOn: $formData.medicalEndocrineThyroidDisorder)
                    Toggle("PCOS (Polycystic Ovary Syndrome)", isOn: $formData.medicalEndocrinePCOS)
                }
                .font(.subheadline)
            }

            // --- Respiratory Conditions ---
            GPRCollapsibleSection(title: "Respiratory Conditions", color: tealColor) {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Asthma", isOn: $formData.medicalRespiratoryAsthma)
                    Toggle("COPD", isOn: $formData.medicalRespiratoryCOPD)
                    Toggle("Bronchitis", isOn: $formData.medicalRespiratoryBronchitis)
                }
                .font(.subheadline)
            }

            // --- Gastric Conditions ---
            GPRCollapsibleSection(title: "Gastric Conditions", color: tealColor) {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Gastric Ulcer", isOn: $formData.medicalGastricUlcer)
                    Toggle("Gastro-oesophageal Reflux Disease (GORD)", isOn: $formData.medicalGastricGORD)
                    Toggle("Irritable Bowel Syndrome (IBS)", isOn: $formData.medicalGastricIBS)
                }
                .font(.subheadline)
            }

            // --- Neurological Conditions ---
            GPRCollapsibleSection(title: "Neurological Conditions", color: tealColor) {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Multiple Sclerosis", isOn: $formData.medicalNeurologicalMS)
                    Toggle("Parkinson's Disease", isOn: $formData.medicalNeurologicalParkinsons)
                    Toggle("Epilepsy", isOn: $formData.medicalNeurologicalEpilepsy)
                }
                .font(.subheadline)
            }

            // --- Hepatic Conditions ---
            GPRCollapsibleSection(title: "Hepatic Conditions", color: tealColor) {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Hepatitis C", isOn: $formData.medicalHepaticHepC)
                    Toggle("Fatty Liver", isOn: $formData.medicalHepaticFattyLiver)
                    Toggle("Alcohol-related Liver Disease", isOn: $formData.medicalHepaticAlcoholRelated)
                }
                .font(.subheadline)
            }

            // --- Renal Conditions ---
            GPRCollapsibleSection(title: "Renal Conditions", color: tealColor) {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Chronic Kidney Disease (CKD)", isOn: $formData.medicalRenalCKD)
                    Toggle("End-stage Renal Disease (ESRD)", isOn: $formData.medicalRenalESRD)
                }
                .font(.subheadline)
            }

            // --- Cancer History ---
            GPRCollapsibleSection(title: "Cancer History", color: tealColor) {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Lung Cancer", isOn: $formData.medicalCancerLung)
                    Toggle("Prostate Cancer", isOn: $formData.medicalCancerProstate)
                    Toggle("Bladder Cancer", isOn: $formData.medicalCancerBladder)
                    Toggle("Uterine Cancer", isOn: $formData.medicalCancerUterine)
                    Toggle("Breast Cancer", isOn: $formData.medicalCancerBreast)
                    Toggle("Brain Cancer", isOn: $formData.medicalCancerBrain)
                    Toggle("Kidney Cancer", isOn: $formData.medicalCancerKidney)
                }
                .font(.subheadline)
            }

            // Imported Notes (matching desktop amber/yellow theme with 📅 dates)
            if !formData.medicalHistoryImported.isEmpty {
                GPRMedicalHistoryImportedSection(entries: $formData.medicalHistoryImported)
            }
        }
    }

    // MARK: - Section 8: Substance Use Popup
    // Matches desktop drugs_alcohol_popup.py structure
    private var substanceUsePopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            // --- ALCOHOL SECTION ---
            GPRCollapsibleSection(title: "Alcohol", color: .green) {
                VStack(alignment: .leading, spacing: 12) {
                    // Age started drinking
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Age started drinking").font(.subheadline.weight(.semibold))
                        Picker("", selection: $formData.alcoholAgeStarted) {
                            Text("None").tag("None")
                            Text("Early teens").tag("Early teens")
                            Text("Mid-teens").tag("Mid-teens")
                            Text("Early adulthood").tag("Early adulthood")
                            Text("30s and 40s").tag("30s and 40s")
                            Text("50s").tag("50s")
                            Text("Later adulthood").tag("Later adulthood")
                        }
                        .pickerStyle(.menu)
                    }

                    // Current alcohol use
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current alcohol use").font(.subheadline.weight(.semibold))
                        Picker("", selection: $formData.alcoholCurrentUse) {
                            Text("None").tag("None")
                            Text("1-5 units per week").tag("1-5 units per week")
                            Text("5-10 units per week").tag("5-10 units per week")
                            Text("10-20 units per week").tag("10-20 units per week")
                            Text("20-35 units per week").tag("20-35 units per week")
                            Text("35-50 units per week").tag("35-50 units per week")
                            Text(">50 units per week").tag(">50 units per week")
                        }
                        .pickerStyle(.menu)
                    }
                }
            }

            // --- SMOKING SECTION ---
            GPRCollapsibleSection(title: "Smoking", color: .green) {
                VStack(alignment: .leading, spacing: 12) {
                    // Age started smoking
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Age started smoking").font(.subheadline.weight(.semibold))
                        Picker("", selection: $formData.smokingAgeStarted) {
                            Text("None").tag("None")
                            Text("Early teens").tag("Early teens")
                            Text("Mid-teens").tag("Mid-teens")
                            Text("Early adulthood").tag("Early adulthood")
                            Text("30s and 40s").tag("30s and 40s")
                            Text("50s").tag("50s")
                            Text("Later adulthood").tag("Later adulthood")
                        }
                        .pickerStyle(.menu)
                    }

                    // Current smoking
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current smoking").font(.subheadline.weight(.semibold))
                        Picker("", selection: $formData.smokingCurrentUse) {
                            Text("None").tag("None")
                            Text("1-5 cigarettes per day").tag("1-5 cigarettes per day")
                            Text("5-10 cigarettes per day").tag("5-10 cigarettes per day")
                            Text("10-20 cigarettes per day").tag("10-20 cigarettes per day")
                            Text("20-30 cigarettes per day").tag("20-30 cigarettes per day")
                            Text(">30 cigarettes per day").tag(">30 cigarettes per day")
                        }
                        .pickerStyle(.menu)
                    }
                }
            }

            // --- ILLICIT DRUGS SECTION ---
            GPRCollapsibleSection(title: "Illicit Drugs", color: .green) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Select drugs used and specify details for each:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Cannabis
                    GPRDrugEntryView(
                        drugName: "Cannabis",
                        isUsed: $formData.drugCannabisUsed,
                        ageStarted: $formData.drugCannabisAge,
                        weeklySpend: $formData.drugCannabisSpend
                    )

                    // Cocaine
                    GPRDrugEntryView(
                        drugName: "Cocaine",
                        isUsed: $formData.drugCocaineUsed,
                        ageStarted: $formData.drugCocaineAge,
                        weeklySpend: $formData.drugCocaineSpend
                    )

                    // Crack Cocaine
                    GPRDrugEntryView(
                        drugName: "Crack Cocaine",
                        isUsed: $formData.drugCrackUsed,
                        ageStarted: $formData.drugCrackAge,
                        weeklySpend: $formData.drugCrackSpend
                    )

                    // Heroin
                    GPRDrugEntryView(
                        drugName: "Heroin",
                        isUsed: $formData.drugHeroinUsed,
                        ageStarted: $formData.drugHeroinAge,
                        weeklySpend: $formData.drugHeroinSpend
                    )

                    // Ecstasy (MDMA)
                    GPRDrugEntryView(
                        drugName: "Ecstasy (MDMA)",
                        isUsed: $formData.drugEcstasyUsed,
                        ageStarted: $formData.drugEcstasyAge,
                        weeklySpend: $formData.drugEcstasySpend
                    )

                    // LSD
                    GPRDrugEntryView(
                        drugName: "LSD",
                        isUsed: $formData.drugLSDUsed,
                        ageStarted: $formData.drugLSDAge,
                        weeklySpend: $formData.drugLSDSpend
                    )

                    // Spice / Synthetic Cannabinoids
                    GPRDrugEntryView(
                        drugName: "Spice / Synthetic Cannabinoids",
                        isUsed: $formData.drugSpiceUsed,
                        ageStarted: $formData.drugSpiceAge,
                        weeklySpend: $formData.drugSpiceSpend
                    )

                    // Amphetamines
                    GPRDrugEntryView(
                        drugName: "Amphetamines",
                        isUsed: $formData.drugAmphetaminesUsed,
                        ageStarted: $formData.drugAmphetaminesAge,
                        weeklySpend: $formData.drugAmphetaminesSpend
                    )

                    // Ketamine
                    GPRDrugEntryView(
                        drugName: "Ketamine",
                        isUsed: $formData.drugKetamineUsed,
                        ageStarted: $formData.drugKetamineAge,
                        weeklySpend: $formData.drugKetamineSpend
                    )

                    // Benzodiazepines
                    GPRDrugEntryView(
                        drugName: "Benzodiazepines",
                        isUsed: $formData.drugBenzodiazepinesUsed,
                        ageStarted: $formData.drugBenzodiazepinesAge,
                        weeklySpend: $formData.drugBenzodiazepinesSpend
                    )
                }
            }

            // Imported Notes
            if !formData.substanceUseImported.isEmpty {
                GPRCollapsibleSection(title: "Imported Data (\(formData.substanceUseImported.count))", color: .yellow) {
                    GPRImportedEntriesList(entries: $formData.substanceUseImported)
                }
            }
        }
    }

    // MARK: - Section 9: Forensic History Popup
    // Matches desktop forensic_history_popup.py
    private var forensicHistoryPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            // --- Convictions Section ---
            GPRCollapsibleSection(title: "Convictions & Prison History", color: .red) {
                VStack(alignment: .leading, spacing: 16) {
                    // Convictions Status
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Convictions").font(.subheadline.weight(.semibold))
                        Picker("", selection: $formData.forensicConvictionsStatus) {
                            Text("Did not wish to discuss").tag("declined")
                            Text("No convictions").tag("none")
                            Text("Has convictions").tag("some")
                        }
                        .pickerStyle(.segmented)

                        // Show sliders if has convictions
                        if formData.forensicConvictionsStatus == "some" {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Number of convictions:")
                                        .font(.caption)
                                    Spacer()
                                    Text(formData.forensicConvictionCount >= 10 ? "10+" : "\(formData.forensicConvictionCount)")
                                        .font(.caption.weight(.semibold))
                                }
                                Slider(value: Binding(
                                    get: { Double(formData.forensicConvictionCount) },
                                    set: { formData.forensicConvictionCount = Int($0) }
                                ), in: 0...10, step: 1)

                                HStack {
                                    Text("Number of offences:")
                                        .font(.caption)
                                    Spacer()
                                    Text(formData.forensicOffenceCount >= 10 ? "10+" : "\(formData.forensicOffenceCount)")
                                        .font(.caption.weight(.semibold))
                                }
                                Slider(value: Binding(
                                    get: { Double(formData.forensicOffenceCount) },
                                    set: { formData.forensicOffenceCount = Int($0) }
                                ), in: 0...10, step: 1)
                            }
                            .padding(.leading, 8)
                        }
                    }

                    Divider()

                    // Prison History
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Prison History").font(.subheadline.weight(.semibold))
                        Picker("", selection: $formData.forensicPrisonStatus) {
                            Text("Did not wish to discuss").tag("declined")
                            Text("Never been in prison").tag("never")
                            Text("Has been in prison/remanded").tag("yes")
                        }
                        .pickerStyle(.segmented)

                        // Show duration if has been in prison
                        if formData.forensicPrisonStatus == "yes" {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Total time in prison:").font(.caption)
                                Picker("", selection: $formData.forensicPrisonDuration) {
                                    Text("Less than 6 months").tag("Less than 6 months")
                                    Text("6-12 months").tag("6-12 months")
                                    Text("1-2 years").tag("1-2 years")
                                    Text("2-5 years").tag("2-5 years")
                                    Text("More than 5 years").tag("More than 5 years")
                                }
                                .pickerStyle(.menu)
                            }
                            .padding(.leading, 8)
                        }
                    }
                }
            }

            // --- Index Offence Section ---
            GPRCollapsibleSection(title: "Index Offence (Optional)", color: .red) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Enter details of index offence if applicable:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextEditor(text: $formData.forensicIndexOffence)
                        .frame(minHeight: 80)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
                }
            }

            // --- Imported Data Section (matches desktop "Imported Data" section) ---
            if !formData.forensicHistoryImported.isEmpty {
                GPRCollapsibleSection(title: "Imported Data (\(formData.forensicHistoryImported.count))", color: .yellow) {
                    GPRImportedEntriesList(entries: $formData.forensicHistoryImported)
                }
            }
        }
    }

    // MARK: - Section 10: Medication Popup
    // Matches desktop with medication dropdowns
    private var medicationPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            GPRCollapsibleSection(title: "Current Medications", color: .green) {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(formData.medications.indices, id: \.self) { index in
                        GPRMedicationRowView(
                            medication: $formData.medications[index],
                            onDelete: {
                                if formData.medications.count > 1 {
                                    formData.medications.remove(at: index)
                                }
                            }
                        )
                        if index < formData.medications.count - 1 {
                            Divider()
                        }
                    }

                    Button {
                        formData.medications.append(GPRMedicationEntry())
                    } label: {
                        Label("Add Medication", systemImage: "plus.circle")
                            .font(.subheadline)
                    }
                    .padding(.top, 8)
                }
            }

            // Imported medication mentions from notes (matches desktop "Extracted Notes" section)
            if !formData.medicationImported.isEmpty {
                GPRCollapsibleSection(title: "Imported Data (\(formData.medicationImported.count))", color: .yellow) {
                    GPRImportedEntriesList(entries: $formData.medicationImported)
                }
            }
        }
    }

    // MARK: - Section 11: Diagnosis Popup
    // Using ICD10Diagnosis dropdown like ASR form
    private var diagnosisPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            GPRCollapsibleSection(title: "ICD-10 Diagnosis", color: .purple) {
                VStack(alignment: .leading, spacing: 16) {
                    // Primary Diagnosis
                    GPRICD10DiagnosisPicker(
                        label: "Primary Diagnosis",
                        selection: $formData.diagnosis1ICD10,
                        customText: $formData.diagnosis1
                    )

                    Divider()

                    // Secondary Diagnosis
                    GPRICD10DiagnosisPicker(
                        label: "Secondary Diagnosis",
                        selection: $formData.diagnosis2ICD10,
                        customText: $formData.diagnosis2
                    )

                    Divider()

                    // Tertiary Diagnosis
                    GPRICD10DiagnosisPicker(
                        label: "Tertiary Diagnosis",
                        selection: $formData.diagnosis3ICD10,
                        customText: $formData.diagnosis3
                    )
                }
            }

            if !formData.diagnosisImported.isEmpty {
                GPRCollapsibleSection(title: "Imported Data (\(formData.diagnosisImported.count))", color: .yellow) {
                    GPRImportedEntriesList(entries: $formData.diagnosisImported)
                }
            }
        }
    }

    // MARK: - Section 12: Legal Criteria Popup
    // Matching ASR form legal criteria structure
    private var legalCriteriaPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Legal Criteria for Detention")
                .font(.headline)

            // Use the shared ClinicalReasonsView component (same as A3)
            // Pass patientInfo for gender-sensitive text generation
            ClinicalReasonsView(
                data: $formData.legalClinicalReasons,
                patientInfo: combinedPatientInfo,
                showInformalSection: true,
                formType: .assessment
            )

            if !formData.legalCriteriaImported.isEmpty {
                GPRCollapsibleSection(title: "Imported Data (\(formData.legalCriteriaImported.count))", color: .yellow) {
                    GPRImportedEntriesList(entries: $formData.legalCriteriaImported)
                }
            }
        }
    }

    // MARK: - Section 13: Strengths Popup
    private var strengthsPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            GPRCollapsibleSection(title: "Strengths", color: .green) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Engagement").font(.caption.bold())
                    Toggle("Staff", isOn: $formData.strengthEngagementStaff)
                    Toggle("Peers", isOn: $formData.strengthEngagementPeers)

                    Text("Activities & Treatment").font(.caption.bold()).padding(.top, 8)
                    Toggle("OT", isOn: $formData.strengthOT)
                    Toggle("Nursing", isOn: $formData.strengthNursing)
                    Toggle("Psychology", isOn: $formData.strengthPsychology)

                    Text("Affect").font(.caption.bold()).padding(.top, 8)
                    Toggle("Positive Affect", isOn: $formData.strengthAffect)
                    if formData.strengthAffect {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Sense of humour", isOn: $formData.strengthHumour)
                            Toggle("Warmth", isOn: $formData.strengthWarmth)
                            Toggle("Friendly", isOn: $formData.strengthFriendly)
                            Toggle("Caring", isOn: $formData.strengthCaring)
                        }
                        .padding(.leading, 20)
                        .font(.subheadline)
                    }
                }
            }

            if !formData.strengthsImported.isEmpty {
                GPRCollapsibleSection(title: "Imported Data (\(formData.strengthsImported.count))", color: .yellow) {
                    GPRImportedEntriesList(entries: $formData.strengthsImported)
                }
            }
        }
    }

    // MARK: - Section 3: Circumstances Popup
    private var circumstancesPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Circumstances Leading to Admission")
                .font(.headline)

            if formData.circumstancesImported.isEmpty {
                Text("No imported notes. Import clinical notes to populate this section.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            } else {
                // Narrative summary for last admission
                GPRNarrativeSummarySection(
                    entries: formData.circumstancesImported,
                    patientName: formData.patientName.components(separatedBy: " ").first ?? "The patient",
                    gender: formData.patientGender.rawValue,
                    period: .lastAdmission
                )

                GPRCollapsibleSection(title: "Imported Data (\(formData.circumstancesImported.count))", color: .yellow) {
                    GPRImportedEntriesList(entries: $formData.circumstancesImported)
                }
            }
        }
    }

    // MARK: - Section 14: Signature Popup
    private var signaturePopup: some View {
        VStack(alignment: .leading, spacing: 12) {
            FormTextField(label: "Name", text: $formData.signatureName, isRequired: true)
            FormTextField(label: "Designation", text: $formData.signatureDesignation)
            FormTextField(label: "Qualifications", text: $formData.signatureQualifications)
            FormTextField(label: "GMC/Professional Registration Number", text: $formData.signatureRegNumber)
            FormDatePicker(label: "Date", date: $formData.signatureDate, isRequired: true)
        }
    }

    // MARK: - Generate Text Logic

    private func generateText() -> String {
        switch section {
        case .patientDetails:
            return generatePatientDetailsText()
        case .reportBasedOn:
            return generateReportBasedOnText()
        case .psychiatricHistory:
            return generatePsychiatricHistoryText()
        case .risk:
            return generateRiskText()
        case .background:
            return generateBackgroundText()
        case .medicalHistory:
            return generateMedicalHistoryText()
        case .substanceUse:
            return generateSubstanceUseText()
        case .forensicHistory:
            return generateForensicHistoryText()
        case .medication:
            return generateMedicationText()
        case .diagnosis:
            return generateDiagnosisText()
        case .legalCriteria:
            return generateLegalCriteriaText()
        case .strengths:
            return generateStrengthsText()
        case .circumstances:
            return generateCircumstancesText()
        case .signature:
            return generateSignatureText()
        }
    }

    private func generatePatientDetailsText() -> String {
        var parts: [String] = []
        if !formData.patientName.isEmpty { parts.append("Name: \(formData.patientName)") }
        parts.append("Gender: \(formData.patientGender.rawValue)")
        if let dob = formData.patientDOB {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            let age = Calendar.current.dateComponents([.year], from: dob, to: Date()).year ?? 0
            parts.append("Date of Birth: \(formatter.string(from: dob))")
            parts.append("Age: \(age) years")
        }
        parts.append("Section: \(formData.mhaSection)")
        if let admDate = formData.admissionDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            parts.append("Admission Date: \(formatter.string(from: admDate))")
        }
        if !formData.currentLocation.isEmpty { parts.append("Current Location: \(formData.currentLocation)") }
        if !formData.reportBy.isEmpty { parts.append("Report By: \(formData.reportBy)") }
        if let dateSeen = formData.dateSeen {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            parts.append("Date Seen: \(formatter.string(from: dateSeen))")
        }
        return parts.joined(separator: "\n")
    }

    private func generateReportBasedOnText() -> String {
        var sources: [String] = []
        if formData.sourceMedicalReports { sources.append("Medical reports") }
        if formData.sourceNursingInterviews { sources.append("Interviews with nursing staff") }
        if formData.sourcePatientInterviews { sources.append("Interviews with the patient") }
        if formData.sourceCurrentPlacementNotes { sources.append("Previous notes from current placement") }
        if formData.sourceOtherPlacementNotes { sources.append("Previous notes from other placements") }
        if formData.sourcePsychologyReports { sources.append("Psychology reports") }
        if formData.sourceSocialWorkReports { sources.append("Social work reports") }
        if formData.sourceOTReports { sources.append("Occupational therapy reports") }

        if sources.isEmpty { return "" }
        return "This report is based on:\n" + sources.map { "• \($0)" }.joined(separator: "\n")
    }

    private func generatePsychiatricHistoryText() -> String {
        var parts: [String] = []

        // Admissions table
        if formData.includeAdmissionsTable && !formData.admissionsTableData.isEmpty {
            parts.append("HOSPITAL ADMISSIONS:")
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            for (index, admission) in formData.admissionsTableData.enumerated() {
                let admStr = admission.admissionDate.map { formatter.string(from: $0) } ?? "Unknown"
                let disStr = admission.dischargeDate.map { formatter.string(from: $0) } ?? "Present"
                parts.append("Admission \(index + 1): \(admStr) - \(disStr) (\(admission.duration))")
            }
        }

        // Selected imported notes
        let selected = formData.psychiatricHistoryImported.filter { $0.selected }
        if !selected.isEmpty {
            if !parts.isEmpty { parts.append("") }
            parts.append("")
            let formatter = DateFormatter()
            formatter.dateFormat = "dd/MM/yyyy"
            for entry in selected {
                if let date = entry.date {
                    parts.append("[\(formatter.string(from: date))] \(entry.text)")
                } else {
                    parts.append(entry.text)
                }
            }
        }

        return parts.joined(separator: "\n")
    }

    private func generateRiskText() -> String {
        var parts: [String] = []

        // Current risks grouped by level
        let highCurrent = GPRRiskType.allCases.filter { formData.currentRisks[$0] == .high }
        let mediumCurrent = GPRRiskType.allCases.filter { formData.currentRisks[$0] == .medium }
        let lowCurrent = GPRRiskType.allCases.filter { formData.currentRisks[$0] == .low }

        if !highCurrent.isEmpty || !mediumCurrent.isEmpty || !lowCurrent.isEmpty {
            var riskParts: [String] = []
            if !highCurrent.isEmpty {
                riskParts.append("the risk of \(highCurrent.map { $0.rawValue.lowercased() }.joined(separator: ", ")) is high")
            }
            if !mediumCurrent.isEmpty {
                riskParts.append("the risk of \(mediumCurrent.map { $0.rawValue.lowercased() }.joined(separator: ", ")) is moderate")
            }
            if !lowCurrent.isEmpty {
                riskParts.append("the risk of \(lowCurrent.map { $0.rawValue.lowercased() }.joined(separator: ", ")) is low")
            }
            parts.append("Currently, \(riskParts.joined(separator: ", and ")).")
        }

        // Historical risks
        let highHist = GPRRiskType.allCases.filter { formData.historicalRisks[$0] == .high }
        let mediumHist = GPRRiskType.allCases.filter { formData.historicalRisks[$0] == .medium }
        let lowHist = GPRRiskType.allCases.filter { formData.historicalRisks[$0] == .low }

        if !highHist.isEmpty || !mediumHist.isEmpty || !lowHist.isEmpty {
            var riskParts: [String] = []
            if !highHist.isEmpty {
                riskParts.append("the risk of \(highHist.map { $0.rawValue.lowercased() }.joined(separator: ", ")) was high")
            }
            if !mediumHist.isEmpty {
                riskParts.append("the risk of \(mediumHist.map { $0.rawValue.lowercased() }.joined(separator: ", ")) was moderate")
            }
            if !lowHist.isEmpty {
                riskParts.append("the risk of \(lowHist.map { $0.rawValue.lowercased() }.joined(separator: ", ")) was low")
            }
            parts.append("Historically, \(riskParts.joined(separator: ", and ")).")
        }

        // Selected imported
        let selected = formData.riskImportedEntries.filter { $0.selected }
        if !selected.isEmpty {
            if !parts.isEmpty { parts.append("") }
            parts.append("")
            let formatter = DateFormatter()
            formatter.dateFormat = "dd/MM/yyyy"
            for entry in selected {
                if let date = entry.date {
                    parts.append("[\(formatter.string(from: date))] \(entry.text)")
                } else {
                    parts.append(entry.text)
                }
            }
        }

        return parts.joined(separator: "\n")
    }

    private func generateBackgroundText() -> String {
        let pronoun = formData.patientGender == .male ? "He" : (formData.patientGender == .female ? "She" : "They")
        let possessive = formData.patientGender == .male ? "His" : (formData.patientGender == .female ? "Her" : "Their")
        let verb = formData.patientGender == .other ? "have" : "has"
        let wasVerb = formData.patientGender == .other ? "were" : "was"

        var parts: [String] = []

        // --- Early Development ---
        var earlyDev: [String] = []
        if formData.backgroundBirth != "Unknown" {
            earlyDev.append("\(possessive) birth \(wasVerb) \(formData.backgroundBirth.lowercased())")
        }
        if formData.backgroundMilestones != "Unknown" {
            if formData.backgroundMilestones == "Normal" {
                earlyDev.append("developmental milestones were achieved normally")
            } else if formData.backgroundMilestones == "Delayed" {
                earlyDev.append("developmental milestones were delayed")
            } else {
                earlyDev.append("\(formData.backgroundMilestones.lowercased())")
            }
        }
        if !earlyDev.isEmpty {
            parts.append("EARLY DEVELOPMENT: \(earlyDev.joined(separator: "; ")).")
        }

        // --- Family & Childhood ---
        var familyChildhood: [String] = []
        if formData.backgroundFamilyHistoryType != "No significant family history of mental illness" {
            familyChildhood.append(formData.backgroundFamilyHistoryType)
        }

        // Childhood abuse
        if formData.backgroundAbuseSeverity != "None reported" {
            var abuseTypes: [String] = []
            if formData.backgroundAbusePhysical { abuseTypes.append("physical") }
            if formData.backgroundAbuseSexual { abuseTypes.append("sexual") }
            if formData.backgroundAbuseEmotional { abuseTypes.append("emotional") }
            if formData.backgroundAbuseNeglect { abuseTypes.append("neglect") }

            if !abuseTypes.isEmpty {
                familyChildhood.append("\(formData.backgroundAbuseSeverity.lowercased()) history of childhood \(abuseTypes.joined(separator: ", ")) abuse")
            } else {
                familyChildhood.append("\(formData.backgroundAbuseSeverity.lowercased()) history of childhood abuse/trauma")
            }
        }

        // Childhood risk
        if formData.childhoodRiskHistory != "No significant risk behavior in childhood reported" {
            familyChildhood.append(formData.childhoodRiskHistory.lowercased())
        }

        if !familyChildhood.isEmpty {
            parts.append("FAMILY & CHILDHOOD: \(familyChildhood.joined(separator: ". ").capitalizingFirstLetter()).")
        }

        // --- Education & Work ---
        var eduWork: [String] = []

        // Schooling
        if formData.backgroundSchoolingSeverity != "No problems" {
            var schoolIssues: [String] = []
            if formData.backgroundSchoolingLearningDifficulties { schoolIssues.append("learning difficulties") }
            if formData.backgroundSchoolingADHD { schoolIssues.append("ADHD") }
            if formData.backgroundSchoolingBullied { schoolIssues.append("bullying") }
            if formData.backgroundSchoolingExcluded { schoolIssues.append("exclusion") }
            if formData.backgroundSchoolingTruancy { schoolIssues.append("truancy") }

            if !schoolIssues.isEmpty {
                eduWork.append("\(pronoun) experienced \(formData.backgroundSchoolingSeverity.lowercased()) at school including \(schoolIssues.joined(separator: ", "))")
            } else {
                eduWork.append("\(pronoun) experienced \(formData.backgroundSchoolingSeverity.lowercased()) at school")
            }
        }

        // Qualifications
        if formData.backgroundQualifications != "Unknown" {
            if formData.backgroundQualifications == "None" {
                eduWork.append("\(pronoun) \(verb) no formal qualifications")
            } else {
                eduWork.append("\(possessive) highest qualification is \(formData.backgroundQualifications)")
            }
        }

        // Work pattern
        if formData.backgroundWorkPattern != "Unknown" {
            eduWork.append("\(possessive) employment history shows \(formData.backgroundWorkPattern.lowercased())")
        }

        // Last worked
        if formData.backgroundLastWorked != "Unknown" && formData.backgroundLastWorked != "Currently working" {
            eduWork.append("\(pronoun) last worked \(formData.backgroundLastWorked.lowercased())")
        } else if formData.backgroundLastWorked == "Currently working" {
            eduWork.append("\(pronoun) is currently working")
        }

        if !eduWork.isEmpty {
            parts.append("EDUCATION & WORK: \(eduWork.joined(separator: ". ")).")
        }

        // --- Identity & Relationships ---
        var identity: [String] = []

        // Sexual orientation
        if formData.backgroundSexualOrientation != "Not documented" {
            identity.append("\(pronoun) identifies as \(formData.backgroundSexualOrientation.lowercased())")
        }

        // Children
        if formData.backgroundChildrenCount != "Unknown" {
            if formData.backgroundChildrenCount == "None" {
                identity.append("\(pronoun) \(verb) no children")
            } else {
                var childText = "\(pronoun) \(verb) \(formData.backgroundChildrenCount) child\(formData.backgroundChildrenCount == "1" ? "" : "ren")"
                if formData.backgroundChildrenAgeBand != "N/A" {
                    childText += " (\(formData.backgroundChildrenAgeBand.lowercased()) age)"
                }
                identity.append(childText)
            }
        }

        // Relationship status
        if formData.backgroundRelationshipStatus != "Unknown" {
            var relText = "\(pronoun) is \(formData.backgroundRelationshipStatus.lowercased())"
            if (formData.backgroundRelationshipStatus == "In relationship" ||
                formData.backgroundRelationshipStatus == "Married/Civil partnership") &&
                formData.backgroundRelationshipDuration != "Unknown" &&
                formData.backgroundRelationshipDuration != "N/A" {
                relText += " for \(formData.backgroundRelationshipDuration.lowercased())"
            }
            identity.append(relText)
        }

        if !identity.isEmpty {
            parts.append("IDENTITY & RELATIONSHIPS: \(identity.joined(separator: ". ")).")
        }

        // --- Legacy text fields (additional notes) ---
        if !formData.backgroundFamilyHistory.isEmpty {
            parts.append("Family History Notes: \(formData.backgroundFamilyHistory)")
        }
        if !formData.backgroundChildhoodHistory.isEmpty {
            parts.append("Childhood Notes: \(formData.backgroundChildhoodHistory)")
        }
        if !formData.backgroundEducation.isEmpty {
            parts.append("Education Notes: \(formData.backgroundEducation)")
        }
        if !formData.backgroundRelationships.isEmpty {
            parts.append("Relationships Notes: \(formData.backgroundRelationships)")
        }

        // --- Imported notes ---
        let selected = formData.backgroundImportedEntries.filter { $0.selected }
        if !selected.isEmpty {
            if !parts.isEmpty { parts.append("") }
            parts.append("")
            for entry in selected { parts.append(entry.text) }
        }

        return parts.joined(separator: "\n\n")
    }

    private func generateMedicalHistoryText() -> String {
        let pronoun = formData.patientGender == .male ? "He" : (formData.patientGender == .female ? "She" : "They")
        let verb = formData.patientGender == .other ? "have" : "has"
        var parts: [String] = []

        // --- Cardiac Conditions ---
        var cardiac: [String] = []
        if formData.medicalCardiacHypertension { cardiac.append("hypertension") }
        if formData.medicalCardiacMI { cardiac.append("MI") }
        if formData.medicalCardiacArrhythmias { cardiac.append("arrhythmias") }
        if formData.medicalCardiacHighCholesterol { cardiac.append("high cholesterol") }
        if formData.medicalCardiacHeartFailure { cardiac.append("heart failure") }
        if !cardiac.isEmpty {
            parts.append("Cardiac conditions, including \(cardiac.joined(separator: ", ")), are noted in the patient's history.")
        }

        // --- Endocrine Conditions ---
        var endocrine: [String] = []
        if formData.medicalEndocrineDiabetes { endocrine.append("diabetes") }
        if formData.medicalEndocrineThyroidDisorder { endocrine.append("thyroid disorder") }
        if formData.medicalEndocrinePCOS { endocrine.append("PCOS") }
        if !endocrine.isEmpty {
            parts.append("\(pronoun) \(verb) endocrine conditions including \(endocrine.joined(separator: ", ")).")
        }

        // --- Respiratory Conditions ---
        var respiratory: [String] = []
        if formData.medicalRespiratoryAsthma { respiratory.append("asthma") }
        if formData.medicalRespiratoryCOPD { respiratory.append("COPD") }
        if formData.medicalRespiratoryBronchitis { respiratory.append("bronchitis") }
        if !respiratory.isEmpty {
            parts.append("Additionally, \(pronoun.lowercased()) \(verb) respiratory conditions including \(respiratory.joined(separator: ", ")).")
        }

        // --- Gastric Conditions ---
        var gastric: [String] = []
        if formData.medicalGastricUlcer { gastric.append("gastric ulcer") }
        if formData.medicalGastricGORD { gastric.append("gastro-oesophageal reflux disease (GORD)") }
        if formData.medicalGastricIBS { gastric.append("irritable bowel syndrome") }
        if !gastric.isEmpty {
            parts.append("\(pronoun) \(verb) a long-standing history of gastrointestinal issues including \(gastric.joined(separator: ", ")).")
        }

        // --- Neurological Conditions ---
        var neuro: [String] = []
        if formData.medicalNeurologicalMS { neuro.append("multiple sclerosis") }
        if formData.medicalNeurologicalParkinsons { neuro.append("Parkinson's disease") }
        if formData.medicalNeurologicalEpilepsy { neuro.append("epilepsy") }
        if !neuro.isEmpty {
            parts.append("Neurologically, \(pronoun.lowercased()) \(verb) a history of \(neuro.joined(separator: ", ")), well-managed with treatment.")
        }

        // --- Hepatic Conditions ---
        var hepatic: [String] = []
        if formData.medicalHepaticHepC { hepatic.append("hepatitis C") }
        if formData.medicalHepaticFattyLiver { hepatic.append("fatty liver") }
        if formData.medicalHepaticAlcoholRelated { hepatic.append("alcohol-related liver disease") }
        if !hepatic.isEmpty {
            parts.append("Regarding hepatic conditions, \(pronoun.lowercased()) \(verb) been monitored for \(hepatic.joined(separator: ", ")).")
        }

        // --- Renal Conditions ---
        var renal: [String] = []
        if formData.medicalRenalCKD { renal.append("chronic kidney disease") }
        if formData.medicalRenalESRD { renal.append("end-stage renal disease") }
        if !renal.isEmpty {
            parts.append("\(pronoun) \(verb) been treated for \(renal.joined(separator: ", ")).")
        }

        // --- Cancer History ---
        var cancer: [String] = []
        if formData.medicalCancerLung { cancer.append("lung") }
        if formData.medicalCancerProstate { cancer.append("prostate") }
        if formData.medicalCancerBladder { cancer.append("bladder") }
        if formData.medicalCancerUterine { cancer.append("uterine") }
        if formData.medicalCancerBreast { cancer.append("breast") }
        if formData.medicalCancerBrain { cancer.append("brain") }
        if formData.medicalCancerKidney { cancer.append("kidney") }
        if !cancer.isEmpty {
            parts.append("Finally, \(pronoun.lowercased()) \(verb) a history of \(cancer.joined(separator: ", ")) cancer and continues with regular monitoring.")
        }

        // Legacy dictionary support
        let legacyConditions = formData.physicalHealthConditions.filter { $0.value }.map { $0.key }
        if !legacyConditions.isEmpty {
            parts.append("Other conditions: \(legacyConditions.joined(separator: ", ")).")
        }

        // Imported notes
        let selected = formData.medicalHistoryImported.filter { $0.selected }
        if !selected.isEmpty {
            if !parts.isEmpty { parts.append("") }
            parts.append("")
            for entry in selected { parts.append(entry.text) }
        }

        return parts.joined(separator: "\n\n")
    }

    private func generateSubstanceUseText() -> String {
        let pronoun = formData.patientGender == .male ? "He" : (formData.patientGender == .female ? "She" : "They")
        let verb = formData.patientGender == .other ? "have" : "has"
        var parts: [String] = []

        // Duration mapping from age started
        func durationText(_ ageStarted: String) -> String {
            switch ageStarted {
            case "Early teens", "Mid-teens": return "for many years"
            case "Early adulthood": return "for several years"
            case "30s and 40s", "50s": return "for some years"
            case "Later adulthood": return "more recently"
            default: return ""
            }
        }

        // --- Alcohol ---
        if formData.alcoholAgeStarted != "None" {
            var alcoholText = "\(pronoun) started drinking alcohol in \(formData.alcoholAgeStarted.lowercased())"
            let duration = durationText(formData.alcoholAgeStarted)
            if !duration.isEmpty {
                alcoholText += " and \(verb) been drinking \(duration)"
            }
            if formData.alcoholCurrentUse != "None" {
                alcoholText += ". Current consumption is \(formData.alcoholCurrentUse.lowercased())"
            }
            parts.append(alcoholText + ".")
        } else if formData.alcoholCurrentUse != "None" {
            parts.append("\(pronoun) currently drinks \(formData.alcoholCurrentUse.lowercased()).")
        }

        // --- Smoking ---
        if formData.smokingAgeStarted != "None" {
            var smokingText = "\(pronoun) started smoking in \(formData.smokingAgeStarted.lowercased())"
            let duration = durationText(formData.smokingAgeStarted)
            if !duration.isEmpty {
                smokingText += " and \(verb) been smoking \(duration)"
            }
            if formData.smokingCurrentUse != "None" {
                smokingText += ". Current smoking is \(formData.smokingCurrentUse.lowercased())"
            }
            parts.append(smokingText + ".")
        } else if formData.smokingCurrentUse != "None" {
            parts.append("\(pronoun) currently smokes \(formData.smokingCurrentUse.lowercased()).")
        }

        // --- Illicit Drugs ---
        // Collect all used drugs
        var currentDrugs: [(name: String, age: String, spend: String)] = []
        var pastDrugs: [(name: String, age: String)] = []

        let drugEntries: [(name: String, used: Bool, age: String, spend: String)] = [
            ("cannabis", formData.drugCannabisUsed, formData.drugCannabisAge, formData.drugCannabisSpend),
            ("cocaine", formData.drugCocaineUsed, formData.drugCocaineAge, formData.drugCocaineSpend),
            ("crack cocaine", formData.drugCrackUsed, formData.drugCrackAge, formData.drugCrackSpend),
            ("heroin", formData.drugHeroinUsed, formData.drugHeroinAge, formData.drugHeroinSpend),
            ("ecstasy (MDMA)", formData.drugEcstasyUsed, formData.drugEcstasyAge, formData.drugEcstasySpend),
            ("LSD", formData.drugLSDUsed, formData.drugLSDAge, formData.drugLSDSpend),
            ("spice/synthetic cannabinoids", formData.drugSpiceUsed, formData.drugSpiceAge, formData.drugSpiceSpend),
            ("amphetamines", formData.drugAmphetaminesUsed, formData.drugAmphetaminesAge, formData.drugAmphetaminesSpend),
            ("ketamine", formData.drugKetamineUsed, formData.drugKetamineAge, formData.drugKetamineSpend),
            ("benzodiazepines", formData.drugBenzodiazepinesUsed, formData.drugBenzodiazepinesAge, formData.drugBenzodiazepinesSpend)
        ]

        for drug in drugEntries {
            if drug.used {
                if drug.spend != "None" {
                    currentDrugs.append((drug.name, drug.age, drug.spend))
                } else {
                    pastDrugs.append((drug.name, drug.age))
                }
            }
        }

        // Generate drug text
        if !currentDrugs.isEmpty {
            for drug in currentDrugs {
                var drugText = "\(pronoun) uses \(drug.name)"
                if drug.age != "None" {
                    drugText += ", having started in \(drug.age.lowercased())"
                    let duration = durationText(drug.age)
                    if !duration.isEmpty {
                        drugText += " (\(duration))"
                    }
                }
                drugText += ", currently spending \(drug.spend.lowercased())"
                parts.append(drugText + ".")
            }
        }

        if !pastDrugs.isEmpty {
            let drugNames = pastDrugs.map { $0.name }.joined(separator: ", ")
            var pastText = "\(pronoun) \(verb) a history of using \(drugNames)"
            if pastDrugs.count == 1 && pastDrugs[0].age != "None" {
                pastText += ", starting in \(pastDrugs[0].age.lowercased())"
            }
            parts.append(pastText + ".")
        }

        // Imported notes
        let selected = formData.substanceUseImported.filter { $0.selected }
        if !selected.isEmpty {
            if !parts.isEmpty { parts.append("") }
            parts.append("")
            for entry in selected { parts.append(entry.text) }
        }

        return parts.joined(separator: "\n\n")
    }

    private func generateForensicHistoryText() -> String {
        var parts: [String] = []
        let pronoun = formData.patientGender == .male ? "He" : (formData.patientGender == .female ? "She" : "They")
        let pronounPoss = formData.patientGender == .male ? "his" : (formData.patientGender == .female ? "her" : "their")
        let verbHas = formData.patientGender == .male || formData.patientGender == .female ? "has" : "have"
        let verbWas = formData.patientGender == .male || formData.patientGender == .female ? "was" : "were"

        // Convictions section
        switch formData.forensicConvictionsStatus {
        case "declined":
            parts.append("\(pronoun) did not wish to discuss \(pronounPoss) forensic history.")
        case "none":
            parts.append("\(pronoun) \(verbHas) no criminal convictions.")
        case "some":
            let convictionCount = formData.forensicConvictionCount >= 10 ? "10+" : "\(formData.forensicConvictionCount)"
            let offenceCount = formData.forensicOffenceCount >= 10 ? "10+" : "\(formData.forensicOffenceCount)"
            parts.append("\(pronoun) \(verbHas) \(convictionCount) conviction(s) for \(offenceCount) offence(s).")
        default:
            break
        }

        // Prison history section
        switch formData.forensicPrisonStatus {
        case "declined":
            if !parts.isEmpty && formData.forensicConvictionsStatus != "declined" {
                parts.append("\(pronoun) did not wish to discuss \(pronounPoss) prison history.")
            }
        case "never":
            parts.append("\(pronoun) \(verbHas) never been in prison or on remand.")
        case "yes":
            let duration = formData.forensicPrisonDuration.isEmpty || formData.forensicPrisonDuration == "None" ? "" : " totalling \(formData.forensicPrisonDuration.lowercased())"
            parts.append("\(pronoun) \(verbHas) been in prison/remand\(duration).")
        default:
            break
        }

        // Index offence (if provided)
        if !formData.forensicIndexOffence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("Index Offence: \(formData.forensicIndexOffence.trimmingCharacters(in: .whitespacesAndNewlines))")
        }

        // Include selected imported entries
        let selected = formData.forensicHistoryImported.filter { $0.selected }
        if !selected.isEmpty {
            if !parts.isEmpty { parts.append("") }
            let formatter = DateFormatter()
            formatter.dateFormat = "dd/MM/yyyy"

            for entry in selected {
                var line = ""
                if let date = entry.date {
                    line += "[\(formatter.string(from: date))] "
                }
                if !entry.categories.isEmpty {
                    line += "(\(entry.categories.joined(separator: ", "))) "
                }
                line += entry.text
                parts.append(line)
            }
        }

        return parts.joined(separator: "\n\n")
    }

    private func generateMedicationText() -> String {
        var parts: [String] = []
        let meds = formData.medications.filter { !$0.name.isEmpty }
        if !meds.isEmpty {
            parts.append("Current medications:")
            for med in meds {
                var medStr = "• \(med.name)"
                if !med.dose.isEmpty { medStr += " \(med.dose)" }
                if !med.frequency.isEmpty { medStr += " \(med.frequency)" }
                parts.append(medStr)
            }
        }

        // Include selected imported medication entries
        let selected = formData.medicationImported.filter { $0.selected }
        if !selected.isEmpty {
            if !parts.isEmpty { parts.append("") }
            parts.append("")
            for entry in selected {
                parts.append("• \(entry.text)")
            }
        }

        return parts.joined(separator: "\n")
    }

    private func generateDiagnosisText() -> String {
        var parts: [String] = []

        var diagnoses: [String] = []
        // Primary diagnosis - check ICD-10 selection first, then custom text
        if formData.diagnosis1ICD10 != .none {
            diagnoses.append(formData.diagnosis1ICD10.rawValue)
        } else if !formData.diagnosis1.isEmpty {
            var d = formData.diagnosis1
            if !formData.diagnosis1Code.isEmpty { d += " (\(formData.diagnosis1Code))" }
            diagnoses.append(d)
        }

        // Secondary diagnosis - check ICD-10 selection first, then custom text
        if formData.diagnosis2ICD10 != .none {
            diagnoses.append(formData.diagnosis2ICD10.rawValue)
        } else if !formData.diagnosis2.isEmpty {
            var d = formData.diagnosis2
            if !formData.diagnosis2Code.isEmpty { d += " (\(formData.diagnosis2Code))" }
            diagnoses.append(d)
        }

        // Tertiary diagnosis - check ICD-10 selection first, then custom text
        if formData.diagnosis3ICD10 != .none {
            diagnoses.append(formData.diagnosis3ICD10.rawValue)
        } else if !formData.diagnosis3.isEmpty {
            var d = formData.diagnosis3
            if !formData.diagnosis3Code.isEmpty { d += " (\(formData.diagnosis3Code))" }
            diagnoses.append(d)
        }

        if !diagnoses.isEmpty {
            let verb = diagnoses.count == 1 ? "is" : "are"
            let noun = diagnoses.count == 1 ? "a mental disorder" : "mental disorders"
            parts.append("\(diagnoses.joined(separator: ", ")) \(verb) \(noun) as defined by the Mental Health Act.")
        }

        // Selected imported entries
        let selected = formData.diagnosisImported.filter { $0.selected }
        if !selected.isEmpty {
            for entry in selected {
                parts.append(entry.text)
            }
        }

        return parts.joined(separator: "\n\n")
    }

    private func generateLegalCriteriaText() -> String {
        var parts: [String] = []

        // Use the gender-sensitive generated text from ClinicalReasonsData (same as A3)
        let text = formData.legalClinicalReasons.generateTextWithPatient(combinedPatientInfo)
        if !text.isEmpty {
            parts.append(text)
        }

        // Selected imported entries
        let selected = formData.legalCriteriaImported.filter { $0.selected }
        if !selected.isEmpty {
            for entry in selected {
                parts.append(entry.text)
            }
        }

        if parts.isEmpty {
            return "Select criteria above to generate clinical text..."
        }
        return parts.joined(separator: "\n\n")
    }

    private func generateStrengthsText() -> String {
        let pronoun = formData.patientGender == .male ? "His" : (formData.patientGender == .female ? "Her" : "Their")
        var parts: [String] = []

        // Engagement
        var engagement: [String] = []
        if formData.strengthEngagementStaff { engagement.append("staff") }
        if formData.strengthEngagementPeers { engagement.append("peers") }
        if !engagement.isEmpty {
            parts.append("\(pronoun) engagement with \(engagement.joined(separator: " and ")) is good.")
        }

        // Activities
        var activities: [String] = []
        if formData.strengthOT { activities.append("occupational therapy") }
        if formData.strengthNursing { activities.append("nursing activities") }
        if formData.strengthPsychology { activities.append("psychology") }
        if !activities.isEmpty {
            parts.append("\(pronoun) participation in \(activities.joined(separator: ", ")) has been positive.")
        }

        // Affect
        if formData.strengthAffect {
            var affectTraits: [String] = []
            if formData.strengthHumour { affectTraits.append("sense of humour") }
            if formData.strengthWarmth { affectTraits.append("warmth") }
            if formData.strengthFriendly { affectTraits.append("friendliness") }
            if formData.strengthCaring { affectTraits.append("caring nature") }
            if !affectTraits.isEmpty {
                parts.append("\(pronoun) affect demonstrates \(affectTraits.joined(separator: ", ")).")
            }
        }

        let selected = formData.strengthsImported.filter { $0.selected }
        if !selected.isEmpty {
            if !parts.isEmpty { parts.append("") }
            parts.append("")
            for entry in selected { parts.append(entry.text) }
        }

        return parts.joined(separator: " ")
    }

    private func generateCircumstancesText() -> String {
        let selected = formData.circumstancesImported.filter { $0.selected }
        if selected.isEmpty { return "" }

        var parts: [String] = []
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        for entry in selected {
            if let date = entry.date {
                parts.append("[\(formatter.string(from: date))] \(entry.text)")
            } else {
                parts.append(entry.text)
            }
        }
        return parts.joined(separator: "\n\n")
    }

    private func generateSignatureText() -> String {
        var parts: [String] = []
        if !formData.signatureName.isEmpty { parts.append(formData.signatureName) }
        if !formData.signatureDesignation.isEmpty { parts.append(formData.signatureDesignation) }
        if !formData.signatureQualifications.isEmpty { parts.append(formData.signatureQualifications) }
        if !formData.signatureRegNumber.isEmpty { parts.append("Registration: \(formData.signatureRegNumber)") }
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        parts.append("Date: \(formatter.string(from: formData.signatureDate))")
        return parts.joined(separator: "\n")
    }
}

// MARK: - GPR Collapsible Section
struct GPRCollapsibleSection<Content: View>: View {
    let title: String
    let color: Color
    @ViewBuilder let content: () -> Content

    @State private var isExpanded = true

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation { isExpanded.toggle() }
            } label: {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                }
                .foregroundColor(color == .yellow ? .orange : color)
                .padding()
                .background(color.opacity(0.15))
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    content()
                }
                .padding()
                .background(Color(.systemBackground))
            }
        }
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - GPR Risk Row
struct GPRRiskRow: View {
    let riskType: GPRRiskType
    @Binding var level: GPRRiskLevel

    // Colors for risk levels
    private var levelColor: Color {
        switch level {
        case .none: return .clear
        case .low: return Color.green.opacity(0.2)
        case .medium: return Color.orange.opacity(0.25)
        case .high: return Color.red.opacity(0.25)
        }
    }

    private var textColor: Color {
        switch level {
        case .none: return .primary
        case .low: return Color(red: 0.1, green: 0.5, blue: 0.1)
        case .medium: return Color(red: 0.7, green: 0.4, blue: 0.0)
        case .high: return Color(red: 0.7, green: 0.1, blue: 0.1)
        }
    }

    var body: some View {
        HStack {
            Text(riskType.rawValue)
                .font(.subheadline)
                .fontWeight(level != .none ? .medium : .regular)
                .foregroundColor(textColor)

            Spacer()

            // Custom segmented control with colors
            HStack(spacing: 0) {
                ForEach(GPRRiskLevel.allCases, id: \.self) { lvl in
                    Button {
                        level = lvl
                    } label: {
                        Text(lvl.rawValue)
                            .font(.caption)
                            .fontWeight(level == lvl ? .semibold : .regular)
                            .foregroundColor(level == lvl ? .white : .primary)
                            .frame(width: 55, height: 28)
                            .background(level == lvl ? colorForLevel(lvl) : Color(.systemGray5))
                    }
                    .buttonStyle(.plain)
                    if lvl != .high {
                        Divider().frame(height: 20)
                    }
                }
            }
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(.systemGray3), lineWidth: 1)
            )
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(levelColor)
        .cornerRadius(8)
    }

    private func colorForLevel(_ lvl: GPRRiskLevel) -> Color {
        switch lvl {
        case .none: return Color(.systemGray3)
        case .low: return Color.green
        case .medium: return Color.orange
        case .high: return Color.red
        }
    }
}

// MARK: - GPR Imported Entries List with Filter Buttons
struct GPRImportedEntriesList: View {
    @Binding var entries: [GPRImportedEntry]
    @State private var selectedFilter: String? = nil

    // Get unique categories from all entries
    private var availableCategories: [String] {
        var categories = Set<String>()
        for entry in entries {
            for category in entry.categories {
                categories.insert(category)
            }
        }
        return Array(categories).sorted()
    }

    // Filter entries by selected category
    private var filteredIndices: [Int] {
        if let filter = selectedFilter {
            return entries.indices.filter { entries[$0].categories.contains(filter) }
        }
        return Array(entries.indices)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Filter buttons (only show if multiple categories)
            if availableCategories.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        // "All" button
                        Button {
                            selectedFilter = nil
                        } label: {
                            Text("All (\(entries.count))")
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(selectedFilter == nil ? Color.blue : Color.gray.opacity(0.2))
                                .foregroundColor(selectedFilter == nil ? .white : .primary)
                                .cornerRadius(12)
                        }
                        .buttonStyle(.plain)

                        // Category filter buttons
                        ForEach(availableCategories, id: \.self) { category in
                            let count = entries.filter { $0.categories.contains(category) }.count
                            Button {
                                selectedFilter = (selectedFilter == category) ? nil : category
                            } label: {
                                Text("\(category) (\(count))")
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(selectedFilter == category ?
                                        Color(hex: GPRCategoryKeywords.categoryColors[category] ?? "3B82F6") ?? .blue :
                                        Color.gray.opacity(0.2))
                                    .foregroundColor(selectedFilter == category ? .white : .primary)
                                    .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Show filter status
                if let filter = selectedFilter {
                    HStack {
                        Text("Filtered by: \(filter)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Clear") {
                            selectedFilter = nil
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 4)
                }
            }

            // Filtered entries
            ForEach(filteredIndices, id: \.self) { index in
                GPRImportedEntryRow(entry: $entries[index])
            }
        }
    }
}

struct GPRImportedEntryRow: View {
    @Binding var entry: GPRImportedEntry
    @State private var isExpanded: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Left: Expand/Collapse button
            Button(action: { isExpanded.toggle() }) {
                Image(systemName: isExpanded ? "minus.circle.fill" : "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)

            // Middle: Content
            VStack(alignment: .leading, spacing: 4) {
                if let date = entry.date {
                    Text(date, style: .date)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                if isExpanded {
                    // Show full text when expanded with highlights
                    HighlightedText(entry.text)
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    // Show snippet when collapsed with highlights
                    HighlightedText(entry.snippet ?? entry.text)
                        .font(.caption)
                        .lineLimit(3)
                }

                if !entry.categories.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(entry.categories, id: \.self) { category in
                                Text(category)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(hex: GPRCategoryKeywords.categoryColors[category] ?? "3B82F6") ?? .blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
            }

            Spacer()

            // Right: Checkbox to add to report
            Toggle("", isOn: $entry.selected)
                .labelsHidden()
                .toggleStyle(CheckboxToggleStyle())
        }
        .padding(8)
        .background(entry.selected ? Color.blue.opacity(0.1) : Color(.systemBackground))
        .cornerRadius(8)
    }
}

// MARK: - GPR Medical History Imported Section (matches desktop amber/yellow styling)
/// Displays imported medical history notes with desktop-matching amber theme
/// Uses 📅 date format, collapsible entries, and checkbox selection
struct GPRMedicalHistoryImportedSection: View {
    @Binding var entries: [GPRImportedEntry]
    @State private var isExpanded = true

    // Amber/yellow theme colors matching desktop (#806000, rgba(180, 150, 50))
    private let headerBg = Color(red: 255/255, green: 248/255, blue: 220/255)  // rgba(255, 248, 220, 0.95)
    private let borderColor = Color(red: 180/255, green: 150/255, blue: 50/255).opacity(0.5)
    private let textColor = Color(red: 128/255, green: 96/255, blue: 0)  // #806000

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header (matching desktop CollapsibleSection)
            Button {
                withAnimation { isExpanded.toggle() }
            } label: {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold))
                    Text("Imported Data (\(entries.count))")
                        .font(.headline.weight(.semibold))
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .foregroundColor(textColor)
                .background(headerBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(borderColor, lineWidth: 1)
                )
                .cornerRadius(isExpanded ? 0 : 6)
                .clipShape(RoundedCorner(radius: 6, corners: isExpanded ? [.topLeft, .topRight] : .allCorners))
            }
            .buttonStyle(.plain)

            // Content
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(entries.indices, id: \.self) { index in
                        GPRMedicalHistoryEntryRow(entry: $entries[index])
                    }
                }
                .padding(12)
                .background(headerBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(borderColor, lineWidth: 1)
                )
                .clipShape(RoundedCorner(radius: 6, corners: [.bottomLeft, .bottomRight]))
            }
        }
    }
}

// MARK: - Medical History Entry Row (matching desktop imported entry style)
struct GPRMedicalHistoryEntryRow: View {
    @Binding var entry: GPRImportedEntry
    @State private var isExpanded: Bool = false

    // Amber theme colors
    private let textColor = Color(red: 128/255, green: 96/255, blue: 0)  // #806000
    private let toggleBg = Color(red: 180/255, green: 150/255, blue: 50/255).opacity(0.2)
    private let bodyBg = Color(red: 255/255, green: 248/255, blue: 220/255).opacity(0.5)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Entry frame (matching desktop entryFrame style)
            VStack(alignment: .leading, spacing: 6) {
                // Header row with toggle, date, checkbox
                HStack(spacing: 8) {
                    // Toggle button (matching desktop ▸/▾)
                    Button {
                        withAnimation { isExpanded.toggle() }
                    } label: {
                        Text(isExpanded ? "▾" : "▸")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(textColor)
                            .frame(width: 22, height: 22)
                            .background(toggleBg)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)

                    // Date label with 📅 emoji (matching desktop style)
                    if let date = entry.date {
                        HStack(spacing: 4) {
                            Text("📅")
                            Text(formatDate(date))
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundColor(textColor)
                        .onTapGesture { withAnimation { isExpanded.toggle() } }
                    } else {
                        Text("📅 No date")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(textColor.opacity(0.7))
                    }

                    Spacer()

                    // Checkbox (matching desktop right-aligned checkbox)
                    Toggle("", isOn: $entry.selected)
                        .labelsHidden()
                        .toggleStyle(CheckboxToggleStyle())
                }

                // Body text (hidden by default, matching desktop QTextEdit style)
                if isExpanded {
                    Text(entry.text)
                        .font(.subheadline)
                        .foregroundColor(Color(red: 51/255, green: 51/255, blue: 51/255))  // #333
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(bodyBg)
                        .cornerRadius(6)
                }
            }
            .padding(10)
            .background(Color.white.opacity(0.95))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(red: 180/255, green: 150/255, blue: 50/255).opacity(0.4), lineWidth: 1)
            )
            .cornerRadius(8)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy"
        return formatter.string(from: date)
    }
}

// Helper for rounded corners on specific sides
struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Highlighted Text View
/// Renders text with [[...]] markers as highlighted (yellow background)
struct HighlightedText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(parseHighlights(text))
    }

    private func parseHighlights(_ input: String) -> AttributedString {
        var result = AttributedString()
        var remaining = input

        while let startRange = remaining.range(of: "[[") {
            // Add text before the marker
            let beforeText = String(remaining[..<startRange.lowerBound])
            result += AttributedString(beforeText)

            // Find the closing marker
            let afterStart = remaining[startRange.upperBound...]
            if let endRange = afterStart.range(of: "]]") {
                // Extract highlighted text
                let highlightedText = String(afterStart[..<endRange.lowerBound])
                var highlighted = AttributedString(highlightedText)
                highlighted.backgroundColor = .yellow
                highlighted.foregroundColor = .black
                result += highlighted

                // Continue with remaining text
                remaining = String(afterStart[endRange.upperBound...])
            } else {
                // No closing marker, add rest as plain text
                result += AttributedString(String(remaining[startRange.lowerBound...]))
                remaining = ""
            }
        }

        // Add any remaining text
        if !remaining.isEmpty {
            result += AttributedString(remaining)
        }

        return result
    }
}

// MARK: - GPR Health Condition Toggle
struct GPRHealthConditionToggle: View {
    let label: String
    @Binding var conditions: [String: Bool]

    var body: some View {
        Toggle(label, isOn: Binding(
            get: { conditions[label] ?? false },
            set: { conditions[label] = $0 }
        ))
        .font(.subheadline)
    }
}

// MARK: - GPR Substance Slider
struct GPRSubstanceSlider: View {
    let label: String
    @Binding var value: Int
    var isAmount: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                Spacer()
                if isAmount {
                    Text(["None", "Occasional", "Regular", "Heavy", "Dependent"][min(value, 4)])
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text(value == 0 ? "N/A" : "\(value)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Slider(value: Binding(
                get: { Double(value) },
                set: { value = Int($0) }
            ), in: isAmount ? 0...4 : 0...50, step: 1)
        }
    }
}

// MARK: - String Extension
extension String {
    func capitalizingFirstLetter() -> String {
        return prefix(1).uppercased() + dropFirst()
    }
}

// MARK: - GPR Radio Group (for Background popup)
struct GPRRadioGroup: View {
    @Binding var selection: String
    let options: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(options, id: \.self) { option in
                Button {
                    selection = option
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: selection == option ? "circle.inset.filled" : "circle")
                            .foregroundColor(selection == option ? Color(hex: "008C7E") ?? .teal : .gray)
                            .font(.system(size: 16))

                        Text(option)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)

                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - GPR Drug Entry View (for Substance Use popup)
struct GPRDrugEntryView: View {
    let drugName: String
    @Binding var isUsed: Bool
    @Binding var ageStarted: String
    @Binding var weeklySpend: String

    private let ageOptions = ["None", "Early teens", "Mid-teens", "Early adulthood", "30s and 40s", "50s", "Later adulthood"]
    private let spendOptions = ["None", "<£20 per week", "£20-50 per week", "£50-100 per week", "£100-250 per week", ">£250 per week"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Drug checkbox
            Toggle(drugName, isOn: $isUsed)
                .font(.subheadline.weight(.medium))

            // Show details only if drug is used
            if isUsed {
                VStack(alignment: .leading, spacing: 8) {
                    // Age started
                    HStack {
                        Text("Age started:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Picker("", selection: $ageStarted) {
                            ForEach(ageOptions, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    // Weekly spend
                    HStack {
                        Text("Current weekly spend:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Picker("", selection: $weeklySpend) {
                            ForEach(spendOptions, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                .padding(.leading, 20)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - GPR Medication Row View (for Medication popup)
struct GPRMedicationRowView: View {
    @Binding var medication: GPRMedicationEntry
    var onDelete: () -> Void

    private let frequencyOptions = ["OD", "BD", "TDS", "QDS", "Nocte", "PRN", "Weekly", "Fortnightly", "Monthly"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                // Medication name with search
                VStack(alignment: .leading, spacing: 2) {
                    Text("Medication").font(.caption).foregroundColor(.secondary)
                    GPRMedicationSearchField(selection: $medication.name)
                }

                // Dose
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dose").font(.caption).foregroundColor(.secondary)
                    GPRMedicationDosePicker(medicationName: medication.name, selection: $medication.dose)
                }
                .frame(width: 100)

                // Frequency
                VStack(alignment: .leading, spacing: 2) {
                    Text("Frequency").font(.caption).foregroundColor(.secondary)
                    Picker("", selection: $medication.frequency) {
                        Text("Select").tag("")
                        ForEach(frequencyOptions, id: \.self) { freq in
                            Text(freq).tag(freq)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .frame(width: 100)

                // Delete button
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
                .padding(.top, 20)
            }
        }
    }
}

// MARK: - GPR Medication Search Field
struct GPRMedicationSearchField: View {
    @Binding var selection: String
    @State private var searchText = ""
    @State private var isExpanded = false

    // Common psychiatric medications
    private let medications = [
        "Olanzapine", "Risperidone", "Quetiapine", "Aripiprazole", "Clozapine",
        "Haloperidol", "Chlorpromazine", "Zuclopenthixol", "Flupentixol", "Paliperidone",
        "Sertraline", "Fluoxetine", "Citalopram", "Escitalopram", "Paroxetine", "Venlafaxine", "Duloxetine", "Mirtazapine",
        "Lithium", "Sodium Valproate", "Carbamazepine", "Lamotrigine",
        "Diazepam", "Lorazepam", "Clonazepam", "Zopiclone", "Promethazine",
        "Procyclidine", "Trihexyphenidyl", "Orphenadrine",
        "Methylphenidate", "Lisdexamfetamine", "Atomoxetine"
    ].sorted()

    var filteredMedications: [String] {
        if searchText.isEmpty { return medications }
        return medications.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Search medication...", text: Binding(
                get: { selection.isEmpty ? searchText : selection },
                set: { newValue in
                    searchText = newValue
                    if !newValue.isEmpty && !medications.contains(newValue) {
                        selection = newValue
                    }
                    isExpanded = true
                }
            ))
            .textFieldStyle(.roundedBorder)
            .onTapGesture { isExpanded = true }

            if isExpanded && !filteredMedications.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(filteredMedications.prefix(10), id: \.self) { med in
                            Button {
                                selection = med
                                searchText = ""
                                isExpanded = false
                            } label: {
                                Text(med)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 8)
                            }
                            Divider()
                        }
                    }
                }
                .frame(maxHeight: 150)
                .background(Color(.systemBackground))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
            }
        }
    }
}

// MARK: - GPR Medication Dose Picker
struct GPRMedicationDosePicker: View {
    let medicationName: String
    @Binding var selection: String

    // Common doses for psychiatric medications
    private var doses: [String] {
        let medicationDoses: [String: [Int]] = [
            "Olanzapine": [2, 5, 10, 15, 20],
            "Risperidone": [1, 2, 3, 4, 6],
            "Quetiapine": [25, 50, 100, 150, 200, 300, 400, 600, 800],
            "Aripiprazole": [5, 10, 15, 20, 30],
            "Clozapine": [25, 50, 100, 200, 300, 400, 500, 600],
            "Haloperidol": [1, 2, 5, 10, 20],
            "Sertraline": [25, 50, 100, 150, 200],
            "Fluoxetine": [10, 20, 40, 60],
            "Lithium": [200, 400, 600, 800, 1000, 1200],
            "Sodium Valproate": [200, 300, 400, 500, 600, 800, 1000, 1200, 1500, 2000],
            "Diazepam": [2, 5, 10, 20],
            "Lorazepam": [1, 2, 4],
            "Promethazine": [25, 50, 100]
        ]

        if let doses = medicationDoses[medicationName] {
            return doses.map { "\($0)mg" }
        }
        return ["25mg", "50mg", "100mg", "150mg", "200mg", "300mg", "400mg", "500mg"]
    }

    var body: some View {
        Menu {
            Button("Custom") { }
            ForEach(doses, id: \.self) { dose in
                Button(dose) { selection = dose }
            }
        } label: {
            HStack {
                Text(selection.isEmpty ? "Select" : selection)
                    .foregroundColor(selection.isEmpty ? .secondary : .primary)
                Spacer()
                Image(systemName: "chevron.down")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(6)
            .background(Color(.systemGray6))
            .cornerRadius(6)
        }
    }
}

// MARK: - GPR ICD-10 Diagnosis Picker
struct GPRICD10DiagnosisPicker: View {
    let label: String
    @Binding var selection: ICD10Diagnosis
    @Binding var customText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.subheadline.weight(.semibold))

            Menu {
                Button("Clear") {
                    selection = .none
                    customText = ""
                }

                ForEach(ICD10Diagnosis.groupedDiagnoses, id: \.0) { group, diagnoses in
                    Menu(group) {
                        ForEach(diagnoses) { diagnosis in
                            Button(diagnosis.rawValue) {
                                selection = diagnosis
                                customText = ""
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(selection == .none ? "Select diagnosis..." : selection.rawValue)
                        .foregroundColor(selection == .none ? .secondary : .primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }

            // Custom diagnosis text field
            if selection == .none {
                TextField("Or enter custom diagnosis...", text: $customText)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
            }
        }
    }
}

// MARK: - Narrative Summary Section for GPR Section 3

struct GPRNarrativeSummarySection: View {
    let entries: [GPRImportedEntry]
    let patientName: String
    let gender: String
    var period: NarrativePeriod = .lastAdmission

    @State private var isExpanded = true
    @State private var includeNarrative = true
    @State private var generatedNarrative: NarrativeResult?

    private let narrativeGenerator = NarrativeGenerator()

    var body: some View {
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
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
                    .foregroundColor(Color(hex: "#806000"))
                }
                .buttonStyle(.plain)

                if isExpanded {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Include narrative in output", isOn: $includeNarrative)
                            .font(.caption)
                            .foregroundColor(Color(hex: "#806000"))

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
                type: "",
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
                let sortedEntries = entries.compactMap { entry -> (Date, GPRImportedEntry)? in
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
                    Text("\(patientName)'s circumstances leading to this admission have been documented. \(pronounPoss.capitalized) clinical presentation and events preceding admission are outlined in the imported notes.")
                        .font(.caption)
                }
            }
        }
    }
}

#Preview {
    GeneralPsychReportView()
        .environment(AppStore())
        .environment(SharedDataStore.shared)
}
