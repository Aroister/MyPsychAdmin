//
//  PsychiatricTribunalReportView.swift
//  MyPsychAdmin
//
//  Psychiatric Tribunal Report Form for iOS
//  Based on desktop tribunal_report_page.py structure (24 sections)
//  Uses same card/popup layout pattern as MOJASRFormView
//

import SwiftUI
import UniformTypeIdentifiers
import Combine

struct PsychiatricTribunalReportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var appStore
    @Environment(SharedDataStore.self) private var sharedData

    // Form data - synced with SharedDataStore for persistence across navigation
    @State private var formData: PsychTribunalFormData = PsychTribunalFormData()
    @State private var validationErrors: [FormValidationError] = []

    // Card text content - synced with SharedDataStore
    @State private var generatedTexts: [PTRSection: String] = [:]
    @State private var manualNotes: [PTRSection: String] = [:]

    // Popup control
    @State private var activePopup: PTRSection? = nil

    // Export states
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var docxURL: URL?
    @State private var showShareSheet = false

    // Import states
    @State private var showingImportPicker = false
    @State private var isImporting = false
    @State private var importStatusMessage: String?
    @State private var hasPopulatedFromSharedData = false

    // 24 Sections matching desktop Psychiatric Tribunal Report order
    enum PTRSection: String, CaseIterable, Identifiable {
        case patientDetails = "1. Patient Details"
        case responsibleClinician = "2. Name of Responsible Clinician"
        case factorsHearing = "3. Factors affecting understanding"
        case adjustments = "4. Adjustments for tribunal"
        case forensicHistory = "5. Index offence(s) and forensic history"
        case previousMHDates = "6. Previous mental health involvement"
        case previousAdmissionReasons = "7. Reasons for previous admission"
        case currentAdmission = "8. Circumstances of current admission"
        case diagnosis = "9. Mental disorder and diagnosis"
        case learningDisability = "10. Learning disability"
        case detentionRequired = "11. Mental disorder requiring detention"
        case treatment = "12. Medical treatment"
        case strengths = "13. Strengths or positive factors"
        case progress = "14. Current progress and behaviour"
        case compliance = "15. Understanding and compliance"
        case mcaDoL = "16. Deprivation of liberty (MCA 2005)"
        case riskHarm = "17. Incidents of harm to self or others"
        case riskProperty = "18. Incidents of property damage"
        case s2Detention = "19. Section 2: Detention justified"
        case otherDetention = "20. Other sections: Treatment justified"
        case dischargeRisk = "21. Risk if discharged"
        case communityManagement = "22. Community risk management"
        case recommendations = "23. Recommendations to tribunal"
        case signature = "24. Signature"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .patientDetails: return "person"
            case .responsibleClinician: return "person.badge.shield.checkmark"
            case .factorsHearing: return "ear"
            case .adjustments: return "slider.horizontal.3"
            case .forensicHistory: return "building.columns"
            case .previousMHDates: return "calendar.badge.clock"
            case .previousAdmissionReasons: return "clock.arrow.circlepath"
            case .currentAdmission: return "arrow.right.circle"
            case .diagnosis: return "stethoscope"
            case .learningDisability: return "brain"
            case .detentionRequired: return "lock.shield"
            case .treatment: return "cross.case"
            case .strengths: return "star"
            case .progress: return "chart.line.uptrend.xyaxis"
            case .compliance: return "checkmark.circle"
            case .mcaDoL: return "figure.stand.line.dotted.figure.stand"
            case .riskHarm: return "exclamationmark.shield"
            case .riskProperty: return "house.lodge"
            case .s2Detention: return "doc.badge.gearshape"
            case .otherDetention: return "doc.badge.plus"
            case .dischargeRisk: return "arrow.right.to.line"
            case .communityManagement: return "person.3"
            case .recommendations: return "text.badge.checkmark"
            case .signature: return "signature"
            }
        }

        var defaultHeight: CGFloat {
            switch self {
            case .patientDetails, .responsibleClinician, .signature: return 120
            case .forensicHistory, .treatment, .progress: return 200
            case .riskHarm, .riskProperty, .dischargeRisk: return 180
            default: return 150
            }
        }

        var isYesNoSection: Bool {
            switch self {
            case .learningDisability, .detentionRequired, .s2Detention, .otherDetention:
                return true
            default:
                return false
            }
        }

        var questionText: String {
            switch self {
            case .learningDisability:
                return "10. Does the patient have a learning disability?"
            case .detentionRequired:
                return "11. Is the mental disorder of a nature or degree which makes detention appropriate?"
            case .s2Detention:
                return "19. Section 2: Is detention justified for the health or safety of the patient or the protection of others?"
            case .otherDetention:
                return "20. Other sections: Is medical treatment justified for health, safety or protection?"
            default:
                return rawValue
            }
        }
    }

    // Data persisted via SharedDataStore (survives navigation)
    init() {
        // Initial values - will be overwritten by SharedDataStore in onAppear
    }

    var body: some View {
        VStack(spacing: 0) {
            // Transparent header bar
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Text("Psychiatric Tribunal")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                HStack(spacing: 16) {
                    if let message = importStatusMessage {
                        Text(message).font(.caption).foregroundColor(.green)
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
                    ForEach(PTRSection.allCases) { section in
                        if section.isYesNoSection {
                            TribunalYesNoCard(
                                title: section.questionText,
                                icon: section.icon,
                                color: "6366F1",
                                isYes: yesNoBinding(for: section)
                            )
                        } else {
                            TribunalEditableCard(
                                title: section.rawValue,
                                icon: section.icon,
                                color: "6366F1",
                                text: binding(for: section),
                                defaultHeight: section.defaultHeight,
                                onHeaderTap: { activePopup = section }
                            )
                        }
                    }
                }
                .padding()
            }
        }
        .background {
            Rectangle().fill(.thickMaterial).ignoresSafeArea()
        }
        .onAppear {
            // Restore persisted data from SharedDataStore
            loadFromSharedDataStore()
            prefillFromSharedData()
            initializeCardTexts()
            if !hasPopulatedFromSharedData && !sharedData.notes.isEmpty {
                populateFromClinicalNotes(sharedData.notes)
                hasPopulatedFromSharedData = true
            }
        }
        .onChange(of: formData) { _, newValue in
            // Persist form data changes
            sharedData.psychTribunalFormData = newValue
        }
        .onChange(of: generatedTexts) { _, newValue in
            // Persist generated texts
            var dict: [String: String] = [:]
            for (section, text) in newValue {
                dict[section.rawValue] = text
            }
            sharedData.psychTribunalGeneratedTexts = dict
        }
        .onChange(of: manualNotes) { _, newValue in
            // Persist manual notes
            var dict: [String: String] = [:]
            for (section, text) in newValue {
                dict[section.rawValue] = text
            }
            sharedData.psychTribunalManualNotes = dict
        }
        .onReceive(sharedData.notesDidChange) { notes in
            if !notes.isEmpty { populateFromClinicalNotes(notes) }
        }
        .onReceive(sharedData.patientInfoDidChange) { patientInfo in
            // Auto-fill patient details when patient info changes
            if !patientInfo.fullName.isEmpty {
                formData.patientName = patientInfo.fullName
                formData.patientDOB = patientInfo.dateOfBirth
                formData.patientGender = patientInfo.gender
            }
        }
        .sheet(item: $activePopup) { section in
            PTRPopupView(
                section: section,
                formData: $formData,
                onGenerate: { generatedText, notes in
                    generatedTexts[section] = generatedText
                    manualNotes[section] = notes
                    activePopup = nil
                },
                onDismiss: { activePopup = nil },
                onCopyNarrativeToCard: { narrative in
                    // Copy narrative to the current section's card (Section 6 or 7)
                    generatedTexts[section] = narrative
                }
            )
        }
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [.plainText, .pdf,
                UTType(filenameExtension: "xlsx") ?? .data,
                UTType(filenameExtension: "docx") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result)
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = docxURL {
                ShareSheet(items: [url])
            }
        }
    }

    private func binding(for section: PTRSection) -> Binding<String> {
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

    private func yesNoBinding(for section: PTRSection) -> Binding<Bool> {
        Binding(
            get: {
                switch section {
                case .learningDisability: return formData.hasLearningDisability
                case .detentionRequired: return formData.detentionAppropriate
                case .s2Detention: return formData.s2DetentionJustified
                case .otherDetention: return formData.otherDetentionJustified
                default: return false
                }
            },
            set: { newValue in
                switch section {
                case .learningDisability: formData.hasLearningDisability = newValue
                case .detentionRequired: formData.detentionAppropriate = newValue
                case .s2Detention: formData.s2DetentionJustified = newValue
                case .otherDetention: formData.otherDetentionJustified = newValue
                default: break
                }
            }
        )
    }

    private func loadFromSharedDataStore() {
        // Restore form data from SharedDataStore
        formData = sharedData.psychTribunalFormData

        // Restore generated texts
        for (key, value) in sharedData.psychTribunalGeneratedTexts {
            if let section = PTRSection(rawValue: key) {
                generatedTexts[section] = value
            }
        }

        // Restore manual notes
        for (key, value) in sharedData.psychTribunalManualNotes {
            if let section = PTRSection(rawValue: key) {
                manualNotes[section] = value
            }
        }
    }

    private func initializeCardTexts() {
        for section in PTRSection.allCases {
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
            formData.signatureName = appStore.clinicianInfo.fullName
            formData.signatureDesignation = appStore.clinicianInfo.roleTitle
            formData.signatureQualifications = appStore.clinicianInfo.discipline
            formData.signatureRegNumber = appStore.clinicianInfo.registrationNumber
        }
    }

    private func exportDOCX() {
        validationErrors = formData.validate()
        guard validationErrors.isEmpty else { return }
        isExporting = true
        exportError = nil

        // Collect section content keyed by PTRSection rawValue
        var sectionContent: [String: String] = [:]
        for section in PTRSection.allCases {
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

        // Parse address from patient details card content
        let pdContent = sectionContent[PTRSection.patientDetails.rawValue] ?? ""
        var patientAddress = ""
        for line in pdContent.components(separatedBy: "\n") {
            let lower = line.lowercased()
            if lower.contains("residence:") || lower.contains("address:") || lower.contains("usual place") {
                patientAddress = line.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        if patientAddress.isEmpty {
            patientAddress = formData.currentLocation
        }

        // Format signature date
        let sigDateFmt = DateFormatter()
        sigDateFmt.dateFormat = "dd/MM/yyyy"
        let sigDateStr = sigDateFmt.string(from: formData.signatureDate)

        // Capture form state for background thread
        let patientName = formData.patientName
        let patientDOB = formData.patientDOB
        let rcName = formData.rcName
        let rcRole = formData.rcRoleTitle
        let hasLD = formData.hasLearningDisability
        let detentionOK = formData.detentionAppropriate
        let s2OK = formData.s2DetentionJustified
        let otherOK = formData.otherDetentionJustified

        DispatchQueue.global(qos: .userInitiated).async {
            let exporter = PTRDOCXExporter(
                sectionContent: sectionContent,
                patientName: patientName,
                patientDOB: patientDOB,
                patientAddress: patientAddress,
                rcName: rcName,
                rcRole: rcRole,
                signatureDate: sigDateStr,
                hasLearningDisability: hasLD,
                detentionAppropriate: detentionOK,
                s2DetentionJustified: s2OK,
                otherDetentionJustified: otherOK
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
                let filename = "PTR_Report_\(timestamp).docx"
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
                defer { url.stopAccessingSecurityScopedResource() }
                do {
                    let tempDir = FileManager.default.temporaryDirectory
                    let tempURL = tempDir.appendingPathComponent(url.lastPathComponent)
                    try? FileManager.default.removeItem(at: tempURL)
                    try FileManager.default.copyItem(at: url, to: tempURL)
                    let extractedDoc = try await DocumentProcessor.shared.processDocument(at: tempURL)

                    // Debug: dump what DocumentProcessor returned
                    print("[PTR iOS] DocumentProcessor result: notes=\(extractedDoc.notes.count), text=\(extractedDoc.text.count) chars, patientInfo='\(extractedDoc.patientInfo.fullName)', extractedData keys=\(extractedDoc.extractedData.keys.map { $0.rawValue })")
                    print("[PTR iOS] Raw text preview (first 500 chars): \(String(extractedDoc.text.prefix(500)))")
                    if !extractedDoc.notes.isEmpty {
                        for (i, note) in extractedDoc.notes.prefix(3).enumerated() {
                            print("[PTR iOS] Note[\(i)]: date=\(note.date), type='\(note.type)', body=\(note.body.count) chars, preview='\(String(note.body.prefix(100)))'")
                        }
                    }

                    await MainActor.run {
                        // Patient info (always extract regardless of report vs notes)
                        if !extractedDoc.patientInfo.fullName.isEmpty {
                            sharedData.setPatientInfo(extractedDoc.patientInfo, source: "ptr_import")
                            formData.patientName = extractedDoc.patientInfo.fullName
                            if let dob = extractedDoc.patientInfo.dateOfBirth {
                                formData.patientDOB = dob
                            }
                            formData.patientGender = extractedDoc.patientInfo.gender
                        }

                        let sections = Self.isPTRReport(extractedDoc) ? parsePTRReportSections(from: extractedDoc.text) : [:]

                        if !sections.isEmpty {
                            // REPORT PATH — imported document is a previous tribunal report
                            populateFromReport(sections, document: extractedDoc)
                            importStatusMessage = "Imported report (\(sections.count) sections)"
                        } else {
                            // NOTES PATH — imported document is clinical notes (or report with 0 parseable sections)
                            if !extractedDoc.notes.isEmpty {
                                sharedData.setNotes(extractedDoc.notes, source: "ptr_import")
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

    private func populateFromClinicalNotes(_ notes: [ClinicalNote]) {
        guard !notes.isEmpty else { return }

        // Clear existing imported entries
        formData.forensicImported.removeAll()
        formData.previousMHImported.removeAll()
        formData.admissionImported.removeAll()
        formData.progressImported.removeAll()
        formData.riskHarmImported.removeAll()
        formData.riskPropertyImported.removeAll()
        formData.strengthsImported.removeAll()
        formData.admissionsTableData.removeAll()
        formData.clerkingNotes.removeAll()

        // Build timeline to find admissions (matches desktop logic)
        let episodes = TimelineBuilder.buildTimeline(from: notes, allNotes: notes)
        let inpatientEpisodes = episodes.filter { $0.type == .inpatient }
        let calendar = Calendar.current

        // Get most recent admission for Section 8 (currentAdmission) filtering
        let mostRecentAdmission = inpatientEpisodes.last

        print("[PTR iOS] Found \(inpatientEpisodes.count) inpatient episodes")

        // === SECTION 6: Find admission clerkings (EXACT GPR iOS CODE) ===
        // Desktop find_clerkings_rio EXACT LOGIC:
        // 1. Filter to MEDICAL notes only (type contains "med", "doctor", "clinician", "physician")
        // 2. Check for CLERKING_TRIGGERS in content OR ROLE_TRIGGERS in originator
        var seenClerkingKeys: Set<String> = []
        var allClerkings: [(date: Date, text: String, admissionDate: Date)] = []

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

            print("[PTR iOS] Window \(admissionStart) -> \(windowEnd): \(windowNotes.count) notes, \(medicalNotes.count) medical")

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
                    allClerkings.append((date: note.date, text: note.body, admissionDate: admissionStart))
                    if firstClerkingDate == nil {
                        firstClerkingDate = note.date
                    }
                    print("[PTR iOS] Found MEDICAL clerking: \(note.body.count) chars, type=\(note.type), trigger=\(hasClerkingTrigger), author=\(hasRoleTriggerInAuthor)")
                }
            }

            // FALLBACK: If no medical clerkings found for THIS episode, try ALL window notes with history sections
            let foundInThisEpisode = allClerkings.contains { $0.admissionDate == admissionStart }
            if !foundInThisEpisode {
                print("[PTR iOS] No medical clerkings found for episode \(admissionStart), trying fallback...")
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
                            allClerkings.append((date: note.date, text: note.body, admissionDate: admissionStart))
                            if firstClerkingDate == nil {
                                firstClerkingDate = note.date
                            }
                            print("[PTR iOS] Found FALLBACK clerking: \(note.body.count) chars, type=\(note.type), hasPersonal=\(hasPersonalHistory)")
                        }
                    }
                }
            }
        }

        // GLOBAL FALLBACK: If still no clerkings found, search ALL notes for Personal history sections
        if allClerkings.isEmpty {
            print("[PTR iOS] GLOBAL FALLBACK: No clerkings found, searching ALL notes for Personal history...")
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
                        allClerkings.append((date: note.date, text: note.body, admissionDate: note.date))
                        print("[PTR iOS] GLOBAL FALLBACK: Found note with Personal history: \(note.body.count) chars, type=\(note.type)")
                    }
                }
            }
        }

        print("[PTR iOS] Total clerkings found: \(allClerkings.count)")

        // === SECTION 6: POPULATE ADMISSIONS TABLE (matching GPR) ===
        for episode in inpatientEpisodes {
            let isOngoing = episode.end > Date().addingTimeInterval(-86400) // Within last day means ongoing

            // Calculate duration
            let durationComponents = calendar.dateComponents([.day], from: episode.start, to: isOngoing ? Date() : episode.end)
            let days = durationComponents.day ?? 0
            let durationStr: String
            if days < 7 {
                durationStr = "\(days) day\(days == 1 ? "" : "s")"
            } else if days < 30 {
                let weeks = days / 7
                durationStr = "\(weeks) week\(weeks == 1 ? "" : "s")"
            } else if days < 365 {
                let months = days / 30
                durationStr = "\(months) month\(months == 1 ? "" : "s")"
            } else {
                let years = days / 365
                let remainingMonths = (days % 365) / 30
                if remainingMonths > 0 {
                    durationStr = "\(years)y \(remainingMonths)m"
                } else {
                    durationStr = "\(years) year\(years == 1 ? "" : "s")"
                }
            }

            formData.admissionsTableData.append(TribunalAdmissionEntry(
                admissionDate: episode.start,
                dischargeDate: isOngoing ? nil : episode.end,
                duration: durationStr
            ))
        }

        // === SECTION 6: POPULATE CLERKING NOTES (matching GPR) ===
        for clerking in allClerkings {
            let snippet = clerking.text.count > 200 ? String(clerking.text.prefix(200)) + "..." : clerking.text
            formData.clerkingNotes.append(TribunalImportedEntry(
                date: clerking.date,
                text: clerking.text,
                snippet: snippet,
                categories: ["Clerking"]
            ))
        }

        print("[PTR iOS] Populated: \(formData.admissionsTableData.count) admissions, \(formData.clerkingNotes.count) clerkings")

        // === SECTION 5: FORENSIC HISTORY - Extract from clerkings (matching GPR) ===
        let forensicHeadings = ["forensic history", "forensic", "offence", "offending", "criminal", "police", "charges", "index offence"]
        for clerking in allClerkings {
            if let forensicSection = extractSectionFromText(clerking.text, sectionHeadings: forensicHeadings) {
                let snippet = forensicSection.count > 150 ? String(forensicSection.prefix(150)) + "..." : forensicSection
                formData.forensicImported.append(TribunalImportedEntry(
                    date: clerking.date,
                    text: forensicSection,
                    snippet: snippet,
                    categories: ["Forensic"]
                ))
            }
        }

        print("[PTR iOS] Extracted \(formData.forensicImported.count) forensic sections from clerkings")

        // Keywords for other sections
        let progressKW = ["progress", "engagement", "behaviour", "behavior", "insight", "capacity"]
        let riskKW = ["assault", "attack", "violence", "aggression", "harm", "self-harm", "suicide"]
        let propertyKW = ["damage", "broke", "smashed", "property", "destroyed"]
        let strengthsKW = ["strength", "positive", "good", "well", "engaged", "motivated"]

        for note in notes {
            let text = note.body
            let date = note.date
            let snippet = text.count > 150 ? String(text.prefix(150)) + "..." : text
            let noteDay = calendar.startOfDay(for: date)

            // === Section 6 & 7: Previous MH involvement / admission reasons ===
            for episode in inpatientEpisodes {
                let windowEnd = calendar.date(byAdding: .day, value: 14, to: episode.start) ?? episode.start
                if noteDay >= episode.start && noteDay <= windowEnd {
                    if AdmissionKeywords.noteIndicatesAdmission(text) {
                        let admissionLabel = formatDate(episode.start)
                        formData.previousMHImported.append(TribunalImportedEntry(
                            date: date,
                            text: text,
                            snippet: snippet,
                            categories: ["Admission \(admissionLabel)"]
                        ))
                        break
                    }
                }
            }

            // === Section 8: Current admission circumstances ===
            if let recentAdmission = mostRecentAdmission {
                let windowStart = calendar.date(byAdding: .day, value: -2, to: recentAdmission.start) ?? recentAdmission.start
                let windowEnd = calendar.date(byAdding: .day, value: 14, to: recentAdmission.start) ?? recentAdmission.start
                if noteDay >= windowStart && noteDay <= windowEnd {
                    formData.admissionImported.append(TribunalImportedEntry(
                        date: date,
                        text: text,
                        snippet: snippet,
                        categories: ["Admission Period"]
                    ))
                }
            }

            // === Section 14: Progress (keyword-based) ===
            if progressKW.contains(where: { text.lowercased().contains($0) }) {
                formData.progressImported.append(TribunalImportedEntry(date: date, text: text, snippet: snippet))
            }

            // === Section 17: Risk harm (keyword-based) ===
            if riskKW.contains(where: { text.lowercased().contains($0) }) {
                formData.riskHarmImported.append(TribunalImportedEntry(date: date, text: text, snippet: snippet))
            }

            // === Section 18: Risk property (keyword-based) ===
            if propertyKW.contains(where: { text.lowercased().contains($0) }) {
                formData.riskPropertyImported.append(TribunalImportedEntry(date: date, text: text, snippet: snippet))
            }

            // === Section 13: Strengths (keyword-based) ===
            if strengthsKW.contains(where: { text.lowercased().contains($0) }) {
                formData.strengthsImported.append(TribunalImportedEntry(date: date, text: text, snippet: snippet))
            }
        }

        // Sort by date (newest first)
        formData.forensicImported.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.previousMHImported.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.admissionImported.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.progressImported.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.riskHarmImported.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.riskPropertyImported.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.strengthsImported.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }

        print("[PTR iOS] Populated: \(formData.forensicImported.count) forensic, \(formData.previousMHImported.count) psych history, \(formData.admissionImported.count) current admission, \(formData.progressImported.count) progress")

        // === SECTION 9: Auto-fill ICD-10 diagnoses from notes (matching ASR Section 3) ===
        extractAndFillDiagnoses(notes)
    }

    /// Extract ICD-10 diagnoses from notes and prefill Section 9 dropdowns (matching ASR form)
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
                print("[PTR iOS] Matched diagnosis: '\(pattern)' -> '\(diagnosis.rawValue)'")

                // Limit to 3 diagnoses
                if extractedDiagnoses.count >= 3 {
                    break
                }
            }
        }

        print("[PTR iOS] Extracted \(extractedDiagnoses.count) diagnoses for ICD-10 auto-fill")

        // Auto-fill the ICD-10 pickers if they're nil (not set)
        if extractedDiagnoses.count > 0 && formData.diagnosis1 == nil {
            formData.diagnosis1 = extractedDiagnoses[0]
            print("[PTR iOS] Set primary diagnosis: \(extractedDiagnoses[0].rawValue)")
        }
        if extractedDiagnoses.count > 1 && formData.diagnosis2 == nil {
            formData.diagnosis2 = extractedDiagnoses[1]
            print("[PTR iOS] Set secondary diagnosis: \(extractedDiagnoses[1].rawValue)")
        }
        if extractedDiagnoses.count > 2 && formData.diagnosis3 == nil {
            formData.diagnosis3 = extractedDiagnoses[2]
            print("[PTR iOS] Set tertiary diagnosis: \(extractedDiagnoses[2].rawValue)")
        }
    }

    // MARK: - PTR Report Detection & Population

    /// Detect whether an imported document is a previous tribunal report (numbered questions 1-24)
    /// rather than clinical notes. Matches desktop report_detector logic.
    private static func isPTRReport(_ document: ExtractedDocument) -> Bool {
        let text = document.text

        print("[PTR iOS] isPTRReport check: notes=\(document.notes.count), text=\(text.count) chars")

        // Check 1: Single long note — report parsed as one block
        if document.notes.count == 1 && document.notes[0].body.count > 2000 {
            print("[PTR iOS] isPTRReport=true (single long note, \(document.notes[0].body.count) chars)")
            return true
        }

        // Check 2: Numbered question scan — regex for ^\s*(\d+)[.)] patterns in range 1-24
        let lines = text.components(separatedBy: .newlines)
        var questionNumbers = Set<Int>()
        let questionPattern = try? NSRegularExpression(pattern: #"^\s*(\d+)[\.\)]\s*"#, options: [])
        for line in lines {
            let nsLine = line as NSString
            if let match = questionPattern?.firstMatch(in: line, options: [], range: NSRange(location: 0, length: nsLine.length)) {
                let numStr = nsLine.substring(with: match.range(at: 1))
                if let num = Int(numStr), num >= 1 && num <= 24 {
                    questionNumbers.insert(num)
                }
            }
        }
        if questionNumbers.count >= 5 {
            print("[PTR iOS] isPTRReport=true (found \(questionNumbers.count) numbered questions: \(questionNumbers.sorted()))")
            return true
        }

        // Check 3: Keyword fingerprints — PTR-specific phrases
        let textLower = text.lowercased()
        let fingerprints = [
            "mental health tribunal",
            "responsible clinician",
            "is the patient now suffering",
            "nature or degree",
            "mental disorder"
        ]
        let fingerprintMatches = fingerprints.filter { textLower.contains($0) }.count
        if fingerprintMatches >= 3 {
            print("[PTR iOS] isPTRReport=true (matched \(fingerprintMatches) keyword fingerprints)")
            return true
        }

        // Check 4: No notes but substantial text — only if it has some PTR indicators
        // (numbered questions or keyword fingerprints), otherwise it's likely notes that failed to parse
        if document.notes.isEmpty && text.count > 500 {
            if questionNumbers.count >= 2 || fingerprintMatches >= 1 {
                print("[PTR iOS] isPTRReport=true (no notes, \(text.count) chars, \(questionNumbers.count) questions, \(fingerprintMatches) fingerprints)")
                return true
            }
        }

        print("[PTR iOS] isPTRReport=false")
        return false
    }

    /// Parse a PTR report text into numbered sections mapped to PTRSection enum values.
    /// Matches the desktop question-to-category mapping from data_extractor_popup.py.
    private func parsePTRReportSections(from text: String) -> [PTRSection: String] {
        let questionToSection: [Int: PTRSection] = [
            1: .patientDetails, 2: .responsibleClinician, 3: .factorsHearing,
            4: .adjustments, 5: .forensicHistory, 6: .previousMHDates,
            7: .previousAdmissionReasons, 8: .currentAdmission, 9: .diagnosis,
            10: .learningDisability, 11: .detentionRequired, 12: .treatment,
            13: .strengths, 14: .progress, 15: .compliance, 16: .mcaDoL,
            17: .riskHarm, 18: .riskProperty, 19: .s2Detention,
            20: .otherDetention, 21: .dischargeRisk, 22: .communityManagement,
            23: .recommendations, 24: .signature
        ]

        var result: [PTRSection: String] = [:]

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
        let questionPattern = try? NSRegularExpression(pattern: #"^\s*(\d+)[\.\)]\s*(.*)"#, options: [])

        var currentQuestion: Int? = nil
        var currentLines: [String] = []

        func flushSection() {
            guard let qNum = currentQuestion, let section = questionToSection[qNum] else { return }
            let sectionText = cleanSectionText(currentLines.joined(separator: "\n"))
            if !sectionText.isEmpty {
                result[section] = sectionText
            }
        }

        for line in lines {
            let nsLine = line as NSString
            if let match = questionPattern?.firstMatch(in: line, options: [], range: NSRange(location: 0, length: nsLine.length)) {
                let numStr = nsLine.substring(with: match.range(at: 1))
                let remainder = nsLine.substring(with: match.range(at: 2))
                if let num = Int(numStr), num >= 1 && num <= 24 {
                    // Accept if sequential (next or skip 1), reject big jumps unless it's a
                    // real section boundary. This prevents false splits from content text
                    // containing patterns like "17. March" or "17. Any reference..."
                    let prev = currentQuestion ?? 0
                    let isSequential = (num > prev && num <= prev + 2)
                    if !isSequential && currentQuestion != nil {
                        // Big jump — only accept if it's clearly a real section
                        // (i.e., we haven't seen this section yet and it's a later section)
                        // Skip this match — treat as content
                        if currentQuestion != nil {
                            currentLines.append(line)
                        }
                        continue
                    }
                    flushSection()
                    currentQuestion = num
                    currentLines = remainder.trimmingCharacters(in: .whitespaces).isEmpty ? [] : [remainder]
                    continue
                }
            }
            if currentQuestion != nil {
                currentLines.append(line)
            }
        }
        flushSection()

        print("[PTR iOS] Parsed \(result.count) report sections: \(result.keys.map { $0.rawValue }.sorted())")
        return result
    }

    /// Clean section text by stripping template titles, checkbox markers, "see above" references, and whitespace
    private func cleanSectionText(_ text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        var cleaned: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { cleaned.append(""); continue }

            // Skip checkbox-only lines: ☐ Yes ☐ No ☐ N/A or similar (including ☒)
            let checkboxPattern = try? NSRegularExpression(pattern: #"^[\s☐☑☒✓✗□■\[\]]*\s*(Yes|No|N/?A|NA)[\s☐☑☒✓✗□■\[\]]*\s*(Yes|No|N/?A|NA)?[\s☐☑☒✓✗□■\[\]]*\s*(Yes|No|N/?A|NA)?[\s☐☑☒✓✗□■\[\]]*$"#, options: .caseInsensitive)
            let nsLine = trimmed as NSString
            if let cbMatch = checkboxPattern?.firstMatch(in: trimmed, options: [], range: NSRange(location: 0, length: nsLine.length)) {
                if cbMatch.range.length == nsLine.length { continue }
            }

            // Skip "see above" / "as above" / "n/a" lines
            let lowerTrimmed = trimmed.lowercased()
            if lowerTrimmed == "see above" || lowerTrimmed == "as above" ||
               lowerTrimmed == "refer to above" || lowerTrimmed == "as per above" ||
               lowerTrimmed == "n/a" || lowerTrimmed == "na" || lowerTrimmed == "nil" {
                continue
            }

            cleaned.append(trimmed)
        }

        var result = cleaned.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip inline checkbox markers: ☐ Yes, ☒ Yes, ☑ No, etc.
        if let cbInline = try? NSRegularExpression(pattern: #"[☐☑☒✓✗□■]\s*(?:Yes|No|N/?A)\s*"#, options: .caseInsensitive) {
            result = cbInline.stringByReplacingMatches(in: result, range: NSRange(location: 0, length: (result as NSString).length), withTemplate: "")
        }
        // Strip standalone checkbox characters
        for char in ["☐", "☑", "☒", "✓", "✗", "□", "■"] {
            result = result.replacingOccurrences(of: char, with: "")
        }

        // Exact T131 template question texts (extracted from t131_template_new.docx, longest first)
        let knownTitles = [
            // Section 15
            "what is the patient's understanding of, compliance with, and likely future willingness to accept any prescribed medication or comply with any appropriate medical treatment for mental disorder that is or might be made available",
            // Section 16
            "in the case of an eligible compliant patient who lacks capacity to agree or object to their detention or treatment, whether or not deprivation of liberty under the mental capacity act 2005 (as amended) would be appropriate and less restrictive",
            // Section 20
            "in all other cases is the provision of medical treatment in hospital, justified or necessary in the interests of the patient's health or safety, or for the protection of others",
            // Section 19
            "in section 2 cases is detention in hospital justified or necessary in the interests of the patient's health or safety, or for the protection of others",
            // Section 12
            "what appropriate and available medical treatment has been prescribed, provided, offered or is planned for the patient's mental disorder",
            // Section 21
            "if the patient was discharged from hospital, would they be likely to act in a manner dangerous to themselves or others",
            // Section 22
            "please explain how risks could be managed effectively in the community, including the use of any lawful conditions or recall powers",
            // Section 11
            "is there any mental disorder present which requires the patient to be detained in a hospital for assessment and/or medical treatment",
            // Section 17
            "give details of any incidents where the patient has harmed themselves or others, or threatened to harm themselves or others",
            // Section 3 (template has typo "there are" for "there")
            "are there are any factors that may affect the patient's understanding or ability to cope with a hearing",
            "are there any factors that may affect the patient's understanding or ability to cope with a hearing",
            // Section 4 (template has typo "there are" for "there")
            "are there are any adjustments that the tribunal may consider in order to deal with the case fairly and justly",
            "are there any adjustments that the tribunal may consider in order to deal with the case fairly and justly",
            // Section 6
            "what are the dates of the patient's previous involvement with mental health services, including any admissions to, discharge from and recall to hospital",
            // Section 18
            "give details of any incidents where the patient has damaged property, or threatened to damage property",
            // Section 8
            "what are the circumstances leading up to the patient's current admission to hospital",
            // Section 23 sub-question
            "please provide your recommendations and the reasons for them, in the box below",
            // Section 23
            "do you have any recommendations to the tribunal",
            // Section 10 sub-question
            "is that disability associated with abnormally aggressive or seriously irresponsible conduct",
            // Section 14
            "give a summary of the patient's current progress, behaviour, capacity and insight",
            // Section 9 sub-question
            "has a diagnosis been made and what is the diagnosis",
            // Section 7
            "give reasons for any previous admission or recall to hospital",
            // Section 5
            "give details of any index offence(s) and other relevant forensic history",
            // Section 13
            "what are the strengths or positive factors relating to the patient",
            // Section 9
            "is the patient now suffering from a mental disorder",
            // Section 10
            "does the patient have a learning disability",
            // Sub-questions after Yes/No
            "what are they",
            // Generic fallbacks
            "name of responsible clinician",
            "patient details",
            "full name",
            "signature",
        ]

        // Normalize curly quotes for matching
        let normalizedResult = result
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")
        let normalizedLower = normalizedResult.lowercased()

        // Strip matching titles from the start — loop to handle stacked questions
        // (e.g. section 9: main question + sub-question)
        var strippedCount = result.count
        var working = result
        var workingLower = normalizedLower
        var didStrip = true
        while didStrip {
            didStrip = false
            for title in knownTitles {
                if workingLower.hasPrefix(title) {
                    working = String(working.dropFirst(title.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                    // Strip trailing punctuation after title
                    while working.hasPrefix("?") || working.hasPrefix(":") || working.hasPrefix(".") || working.hasPrefix(",") || working.hasPrefix(")") || working.hasPrefix("-") {
                        working = String(working.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    // Strip parenthetical like "(if applicable, specify ICD-10 code)"
                    if working.hasPrefix("("), let closeIdx = working.firstIndex(of: ")") {
                        let dist = working.distance(from: working.startIndex, to: closeIdx)
                        if dist <= 100 { // Only strip short parentheticals
                            working = String(working[working.index(after: closeIdx)...]).trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    }
                    // Update lowercase for next iteration
                    workingLower = working
                        .replacingOccurrences(of: "\u{2018}", with: "'")
                        .replacingOccurrences(of: "\u{2019}", with: "'")
                        .lowercased()
                    didStrip = true
                    break
                }
            }
        }
        result = working

        // Strip "Yes -" / "No -" prefixes left after checkbox removal
        let yesNoPrefix = try? NSRegularExpression(pattern: #"^\s*(?:Yes|No)\s*[-–—:]\s*"#, options: .caseInsensitive)
        if let ynMatch = yesNoPrefix?.firstMatch(in: result, range: NSRange(location: 0, length: (result as NSString).length)) {
            result = String((result as NSString).substring(from: ynMatch.range.upperBound)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Strip secondary instruction text ("You should also comment...")
        let instrLower = result.lowercased()
        if instrLower.hasPrefix("you should also") || instrLower.hasPrefix("please also") {
            if let dotIdx = result.firstIndex(of: ".") {
                let dist = result.distance(from: result.startIndex, to: dotIdx)
                if dist <= 200 {
                    result = String(result[result.index(after: dotIdx)...]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Parse Yes/No/N/A from XFA radio button values or text.
    /// XFA radio values: "1"=Yes, "2"=No, "3"=N/A. Also handles plain text "Yes"/"No".
    private func parseYesNo(_ text: String) -> Bool? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        // XFA radio button numeric values
        if trimmed == "1" || trimmed.hasPrefix("1\n") { return true }
        if trimmed == "2" || trimmed.hasPrefix("2\n") { return false }
        if trimmed == "3" || trimmed.hasPrefix("3\n") { return nil } // N/A
        // Plain text
        if trimmed.hasPrefix("yes") { return true }
        if trimmed.hasPrefix("no") { return false }
        if trimmed.hasPrefix("n/a") || trimmed.hasPrefix("na") { return nil }
        return nil
    }

    /// Strip the Yes/No/N/A prefix from radio button text to get the explanation portion.
    private func stripYesNoPrefix(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Remove leading radio value ("1", "2", "3") or "Yes"/"No"/"N/A" and any following whitespace/newlines
        let patterns = ["^[123]\\s*\\n?", "^(?i)(yes|no|n/?a)\\s*[:\\-]?\\s*\\n?"]
        var result = trimmed
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let nsStr = result as NSString
                let match = regex.firstMatch(in: result, range: NSRange(location: 0, length: nsStr.length))
                if let m = match {
                    result = nsStr.substring(from: m.range.upperBound).trimmingCharacters(in: .whitespacesAndNewlines)
                    break
                }
            }
        }
        return result
    }

    /// Populate imported data fields from parsed report sections.
    /// Creates TribunalImportedEntry objects for the user to review and tick.
    /// Card text is NOT auto-filled — the user selects imported entries to populate cards.
    private func populateFromReport(_ sections: [PTRSection: String], document: ExtractedDocument) {
        // Clear existing imported entries (same as populateFromClinicalNotes)
        formData.forensicImported.removeAll()
        formData.previousMHImported.removeAll()
        formData.admissionImported.removeAll()
        formData.progressImported.removeAll()
        formData.riskHarmImported.removeAll()
        formData.riskPropertyImported.removeAll()
        formData.strengthsImported.removeAll()
        formData.clerkingNotes.removeAll()
        formData.treatmentImported.removeAll()
        formData.complianceImported.removeAll()
        formData.recommendationsImported.removeAll()

        // Helper to create a TribunalImportedEntry from section text
        func makeEntry(_ text: String) -> TribunalImportedEntry {
            TribunalImportedEntry(date: nil, text: text, snippet: String(text.prefix(200)), selected: false, categories: ["Report"])
        }

        // Section 3: Factors affecting hearing (Yes/No + details)
        if let text = sections[.factorsHearing], !text.isEmpty {
            let answer = parseYesNo(text)
            formData.hasFactorsAffectingHearing = (answer == true)
            let detail = stripYesNoPrefix(text)
            if !detail.isEmpty { formData.factorsDetails = detail }
            print("[PTR iOS] Q3 Factors affecting hearing: \(answer?.description ?? "nil"), detail=\(detail.prefix(80))")
        }

        // Section 4: Adjustments needed (Yes/No + details)
        if let text = sections[.adjustments], !text.isEmpty {
            let answer = parseYesNo(text)
            formData.hasAdjustmentsNeeded = (answer == true)
            let detail = stripYesNoPrefix(text)
            if !detail.isEmpty { formData.adjustmentsOther = detail }
            print("[PTR iOS] Q4 Adjustments needed: \(answer?.description ?? "nil"), detail=\(detail.prefix(80))")
        }

        // Section 5: Forensic History
        if let text = sections[.forensicHistory], !text.isEmpty {
            formData.forensicImported.append(makeEntry(text))
        }

        // Section 6: Previous MH Dates
        if let text = sections[.previousMHDates], !text.isEmpty {
            formData.previousMHImported.append(makeEntry(text))
            formData.clerkingNotes.append(makeEntry(text))
        }

        // Section 7: Previous Admission Reasons
        if let text = sections[.previousAdmissionReasons], !text.isEmpty {
            formData.clerkingNotes.append(makeEntry(text))
        }

        // Section 8: Current Admission
        if let text = sections[.currentAdmission], !text.isEmpty {
            formData.admissionImported.append(makeEntry(text))
        }

        // Section 9: Diagnosis — extract ICD-10 codes and set mental disorder flag
        if let text = sections[.diagnosis], !text.isEmpty {
            formData.hasMentalDisorder = true
            let extracted = ICD10Diagnosis.extractFromText(text)
            if extracted.count > 0 && formData.diagnosis1 == nil {
                formData.diagnosis1 = extracted[0].diagnosis
                print("[PTR iOS] Report Q9 set primary diagnosis: \(extracted[0].diagnosis.rawValue)")
            }
            if extracted.count > 1 && formData.diagnosis2 == nil {
                formData.diagnosis2 = extracted[1].diagnosis
                print("[PTR iOS] Report Q9 set secondary diagnosis: \(extracted[1].diagnosis.rawValue)")
            }
            if extracted.count > 2 && formData.diagnosis3 == nil {
                formData.diagnosis3 = extracted[2].diagnosis
                print("[PTR iOS] Report Q9 set tertiary diagnosis: \(extracted[2].diagnosis.rawValue)")
            }
            print("[PTR iOS] Q9 hasMentalDisorder set to true")
        }

        // Section 10: Learning Disability (Yes/No radio)
        if let text = sections[.learningDisability], !text.isEmpty {
            let answer = parseYesNo(text)
            formData.hasLearningDisability = (answer == true)
            let detail = stripYesNoPrefix(text)
            if !detail.isEmpty { formData.learningDisabilityDetails = detail }
            print("[PTR iOS] Q10 Learning disability: \(answer?.description ?? "nil"), detail=\(detail.prefix(80))")
        }

        // Section 11: Detention Required (Yes/No radio)
        if let text = sections[.detentionRequired], !text.isEmpty {
            let answer = parseYesNo(text)
            formData.detentionAppropriate = (answer ?? true)
            let detail = stripYesNoPrefix(text)
            if !detail.isEmpty { formData.detentionExplanation = detail }
            print("[PTR iOS] Q11 Detention appropriate: \(answer?.description ?? "nil"), detail=\(detail.prefix(80))")
        }

        // Section 13: Strengths
        if let text = sections[.strengths], !text.isEmpty {
            formData.strengthsImported.append(makeEntry(text))
        }

        // Section 14: Progress
        if let text = sections[.progress], !text.isEmpty {
            formData.progressImported.append(makeEntry(text))
        }

        // Section 16: MCA DoL
        if let text = sections[.mcaDoL], !text.isEmpty {
            formData.mcaDetails = text
        }

        // Section 17: Risk Harm
        if let text = sections[.riskHarm], !text.isEmpty {
            formData.riskHarmImported.append(makeEntry(text))
        }

        // Section 18: Risk Property
        if let text = sections[.riskProperty], !text.isEmpty {
            formData.riskPropertyImported.append(makeEntry(text))
        }

        // Section 19: S2 Detention (Yes/No radio)
        if let text = sections[.s2Detention], !text.isEmpty {
            let answer = parseYesNo(text)
            formData.s2DetentionJustified = (answer ?? true)
            let detail = stripYesNoPrefix(text)
            if !detail.isEmpty { formData.s2Explanation = detail }
            print("[PTR iOS] Q19 S2 detention justified: \(answer?.description ?? "nil"), detail=\(detail.prefix(80))")
        }

        // Section 20: Other Detention (Yes/No radio)
        if let text = sections[.otherDetention], !text.isEmpty {
            let answer = parseYesNo(text)
            formData.otherDetentionJustified = (answer ?? true)
            let detail = stripYesNoPrefix(text)
            if !detail.isEmpty { formData.otherDetentionExplanation = detail }
            print("[PTR iOS] Q20 Other detention justified: \(answer?.description ?? "nil"), detail=\(detail.prefix(80))")
        }

        // Section 12: Treatment — store as imported entry for user to tick
        if let text = sections[.treatment], !text.isEmpty {
            formData.treatmentImported.append(makeEntry(text))
        }

        // Section 15: Compliance — store as imported entry for user to tick
        if let text = sections[.compliance], !text.isEmpty {
            formData.complianceImported.append(makeEntry(text))
        }

        // Section 23: Recommendations — store as imported entry for user to tick
        if let text = sections[.recommendations], !text.isEmpty {
            formData.recommendationsImported.append(makeEntry(text))
        }

        // Section 21: Discharge Risk — populate details + auto-set risk toggles from keywords
        if let text = sections[.dischargeRisk], !text.isEmpty {
            formData.dischargeRiskDetails = text
            let lower = text.lowercased()
            if lower.contains("violence") { formData.dischargeRiskViolence = true }
            if lower.contains("self-harm") || lower.contains("suicide") { formData.dischargeRiskSelfHarm = true }
            if lower.contains("neglect") { formData.dischargeRiskNeglect = true }
            if lower.contains("exploitation") { formData.dischargeRiskExploitation = true }
            if lower.contains("relapse") { formData.dischargeRiskRelapse = true }
            if lower.contains("compliance") || lower.contains("non-compliance") { formData.dischargeRiskNonCompliance = true }
            print("[PTR iOS] Q21 Discharge risk details populated, keyword toggles set")
        }

        // Section 22: Community Management
        if let text = sections[.communityManagement], !text.isEmpty {
            formData.communityPlanDetails = text
        }

        print("[PTR iOS] populateFromReport complete: \(sections.count) sections mapped to imported data")
    }

    /// Extract a section from text based on headings (matches GPR extractSectionStatic EXACTLY)
    private func extractSectionFromText(_ text: String, sectionHeadings: [String]) -> String? {
        let lines = text.components(separatedBy: .newlines)

        // All headings that indicate section boundaries - MUST include abbreviations like "hx"
        let allHeadings = [
            // Clinical history sections (full and abbreviated)
            "background history", "personal history", "social history", "family history",
            "developmental history", "early history", "past and personal history",
            "personal hx", "social hx", "family hx", "personal/social hx",
            "past psychiatric history", "psychiatric history", "mental health history", "pph",
            "history of presenting complaint", "presenting complaint", "hpc",
            "past medical history", "medical history", "pmh", "physical health", "physical hx",
            // Drug and alcohol headings
            "drug and alcohol", "drug and alcohol history", "drug history", "alcohol history",
            "drugs history", "drugs hx", "substance use", "substance misuse", "substance", "illicit",
            // Forensic and clinical
            "forensic history", "forensic hx", "forensic", "offence", "offending", "criminal", "police", "charges", "index offence",
            "mental state", "mse", "mental state examination", "risk", "impression", "plan", "diagnosis",
            "medication", "medication history", "current medication", "physical examination", "summary", "capacity", "ecg",
            // Common RiO progress note headers that END sections
            "finances", "finance", "accommodation", "leave", "section", "legal status",
            "occupational therapy", "ot", "psychology", "nursing", "social work", "sw",
            "cpa", "care plan", "review", "follow up", "follow-up", "next steps",
            "actions", "outcome", "progress", "update", "contact", "telephone",
            "activities", "engagement", "presentation", "observations", "obs level",
            "safeguarding", "discharge", "transfer", "referral",
            // Meeting/clinical note markers
            "date", "time", "present", "apologies", "discussion", "interview", "allergies",
            "dgn", "imp", "assessment", "formulation"
        ]

        // Helper to detect headers - matches GPR/desktop _detect_header exactly
        func isHeaderLine(_ line: String, for headings: [String]) -> String? {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let lower = trimmed.lowercased()
            let words = trimmed.split(separator: " ")

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

            // For short lines (<=4 words) with colon/dash, also check if line starts with heading
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
        // e.g., "Forensic history: Ms Adeniyi was convicted..." - the content after ":" is on the same line
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

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Tribunal Editable Card (Reusable for all tribunal reports)
struct TribunalEditableCard: View {
    let title: String
    let icon: String
    let color: String
    @Binding var text: String
    let defaultHeight: CGFloat
    let onHeaderTap: () -> Void

    @State private var editorHeight: CGFloat = 150

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onHeaderTap) {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .foregroundColor(Color(hex: color))
                        .frame(width: 20)
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(Color(hex: color))
                        .font(.caption)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
            }
            .buttonStyle(.plain)

            TextEditor(text: $text)
                .frame(height: editorHeight)
                .padding(8)
                .scrollContentBackground(.hidden)

            ResizeHandle(height: $editorHeight)
        }
        .background(.thinMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.7), radius: 12, y: 6)
        .onAppear { editorHeight = defaultHeight }
    }
}

// MARK: - Tribunal Yes/No Card (Sections 10, 11, 19, 20)
struct TribunalYesNoCard: View {
    let title: String
    let icon: String
    let color: String
    @Binding var isYes: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundColor(Color(hex: color))
                    .frame(width: 20)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)

            HStack {
                Picker("", selection: $isYes) {
                    Text("No").tag(false)
                    Text("Yes").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(.thinMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.7), radius: 12, y: 6)
    }
}

// MARK: - PTR Popup View
struct PTRPopupView: View {
    let section: PsychiatricTribunalReportView.PTRSection
    @Binding var formData: PsychTribunalFormData
    let onGenerate: (String, String) -> Void
    let onDismiss: () -> Void
    var onCopyNarrativeToCard: ((String) -> Void)? = nil

    @Environment(SharedDataStore.self) private var sharedData

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    popupContent
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
                        onGenerate(text, "")
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    @ViewBuilder
    private var popupContent: some View {
        switch section {
        case .patientDetails: patientDetailsPopup
        case .responsibleClinician: responsibleClinicianPopup
        case .factorsHearing: factorsHearingPopup
        case .adjustments: adjustmentsPopup
        case .forensicHistory: forensicHistoryPopup
        case .previousMHDates: previousMHDatesPopup
        case .previousAdmissionReasons: previousAdmissionReasonsPopup
        case .currentAdmission: currentAdmissionPopup
        case .diagnosis: diagnosisPopup
        case .learningDisability: EmptyView()
        case .detentionRequired: EmptyView()
        case .treatment: treatmentPopup
        case .strengths: strengthsPopup
        case .progress: progressPopup
        case .compliance: compliancePopup
        case .mcaDoL: mcaDoLPopup
        case .riskHarm: riskHarmPopup
        case .riskProperty: riskPropertyPopup
        case .s2Detention: EmptyView()
        case .otherDetention: EmptyView()
        case .dischargeRisk: dischargeRiskPopup
        case .communityManagement: communityManagementPopup
        case .recommendations: recommendationsPopup
        case .signature: signaturePopup
        }
    }

    // MARK: - Section 1: Patient Details
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
            FormTextField(label: "Hospital Number", text: $formData.hospitalNumber)
            FormTextField(label: "NHS Number", text: $formData.nhsNumber)
            FormTextField(label: "Current Hospital/Ward", text: $formData.currentLocation)
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
                }
                .pickerStyle(.menu)
            }
            FormOptionalDatePicker(label: "Admission Date", date: $formData.admissionDate)
        }
    }

    // MARK: - Section 2: Responsible Clinician
    private var responsibleClinicianPopup: some View {
        VStack(alignment: .leading, spacing: 12) {
            FormTextField(label: "RC Name", text: $formData.rcName, isRequired: true)
            FormTextField(label: "Role/Title", text: $formData.rcRoleTitle)
            FormTextField(label: "Discipline", text: $formData.rcDiscipline)
            FormTextField(label: "Registration Number", text: $formData.rcRegNumber)
            FormTextField(label: "Contact Email", text: $formData.rcEmail)
            FormTextField(label: "Contact Phone", text: $formData.rcPhone)
        }
    }

    // MARK: - Section 3: Factors Affecting Hearing
    private var factorsHearingPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Are there any factors that may affect the patient's understanding or ability to cope with a hearing?")
                .font(.subheadline).foregroundColor(.secondary)

            // Yes/No Radio
            TribunalYesNoRadio(selection: $formData.hasFactorsAffectingHearing)

            if formData.hasFactorsAffectingHearing {
                Divider()

                // Single selection radio - matching desktop exactly
                VStack(alignment: .leading, spacing: 12) {
                    Text("Select Factor").font(.subheadline.bold())

                    TribunalRadioOption(
                        label: "Autism",
                        isSelected: formData.selectedFactor == "Autism",
                        onSelect: { formData.selectedFactor = "Autism" }
                    )

                    TribunalRadioOption(
                        label: "Learning Disability",
                        isSelected: formData.selectedFactor == "Learning Disability",
                        onSelect: { formData.selectedFactor = "Learning Disability" }
                    )

                    TribunalRadioOption(
                        label: "Low frustration tolerance / Irritability",
                        isSelected: formData.selectedFactor == "Low frustration tolerance",
                        onSelect: { formData.selectedFactor = "Low frustration tolerance" }
                    )
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)

                FormTextEditor(label: "Additional details", text: $formData.factorsDetails, minHeight: 80)
            }
        }
    }

    // MARK: - Section 4: Adjustments
    private var adjustmentsPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Are there any adjustments that the tribunal may consider in order to deal with the case fairly and justly?")
                .font(.subheadline).foregroundColor(.secondary)

            // Yes/No Radio
            TribunalYesNoRadio(selection: $formData.hasAdjustmentsNeeded)

            if formData.hasAdjustmentsNeeded {
                Divider()

                // Single selection radio - matching desktop exactly
                VStack(alignment: .leading, spacing: 12) {
                    Text("Select Adjustment").font(.subheadline.bold())

                    TribunalRadioOption(
                        label: "Needs careful explanation",
                        isSelected: formData.selectedAdjustment == "Explanation",
                        onSelect: { formData.selectedAdjustment = "Explanation" }
                    )

                    TribunalRadioOption(
                        label: "Needs breaks",
                        isSelected: formData.selectedAdjustment == "Breaks",
                        onSelect: { formData.selectedAdjustment = "Breaks" }
                    )

                    TribunalRadioOption(
                        label: "Needs more time",
                        isSelected: formData.selectedAdjustment == "More time",
                        onSelect: { formData.selectedAdjustment = "More time" }
                    )
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)

                FormTextEditor(label: "Additional details", text: $formData.adjustmentsOther, minHeight: 60)
            }
        }
    }

    // MARK: - Section 5: Forensic History
    // Matches GPR Section 9 forensicHistoryPopup structure exactly
    private var forensicHistoryPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            // --- Convictions Section (matching GPR) ---
            TribunalCollapsibleSection(title: "Convictions & Prison History", color: .red) {
                VStack(alignment: .leading, spacing: 16) {
                    // Convictions Status
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Convictions").font(.subheadline.weight(.semibold))
                        Picker("", selection: $formData.convictionsStatus) {
                            Text("Did not wish to discuss").tag("declined")
                            Text("No convictions").tag("none")
                            Text("Has convictions").tag("some")
                        }
                        .pickerStyle(.segmented)

                        // Show sliders if has convictions
                        if formData.convictionsStatus == "some" {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Number of convictions:")
                                        .font(.caption)
                                    Spacer()
                                    Text(formData.convictionCountIndex >= 10 ? "10+" : "\(formData.convictionCountIndex + 1)")
                                        .font(.caption.weight(.semibold))
                                }
                                Slider(value: Binding(
                                    get: { Double(formData.convictionCountIndex) },
                                    set: { formData.convictionCountIndex = Int($0) }
                                ), in: 0...10, step: 1)

                                HStack {
                                    Text("Number of offences:")
                                        .font(.caption)
                                    Spacer()
                                    Text(formData.offenceCountIndex >= 10 ? "10+" : "\(formData.offenceCountIndex + 1)")
                                        .font(.caption.weight(.semibold))
                                }
                                Slider(value: Binding(
                                    get: { Double(formData.offenceCountIndex) },
                                    set: { formData.offenceCountIndex = Int($0) }
                                ), in: 0...10, step: 1)
                            }
                            .padding(.leading, 8)
                        }
                    }

                    Divider()

                    // Prison History
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Prison History").font(.subheadline.weight(.semibold))
                        Picker("", selection: $formData.prisonStatus) {
                            Text("Did not wish to discuss").tag("declined")
                            Text("Never been in prison").tag("never")
                            Text("Has been in prison/remanded").tag("yes")
                        }
                        .pickerStyle(.segmented)

                        // Show duration if has been in prison
                        if formData.prisonStatus == "yes" {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Total time in prison:").font(.caption)
                                Picker("", selection: $formData.prisonDurationIndex) {
                                    Text("Less than 6 months").tag(0)
                                    Text("6-12 months").tag(1)
                                    Text("1-2 years").tag(2)
                                    Text("2-5 years").tag(3)
                                    Text("More than 5 years").tag(4)
                                }
                                .pickerStyle(.menu)
                            }
                            .padding(.leading, 8)
                        }
                    }
                }
            }

            // --- Index Offence Section (matching GPR) ---
            TribunalCollapsibleSection(title: "Index Offence", color: .red) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Enter details of index offence:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextEditor(text: $formData.indexOffence)
                        .frame(minHeight: 80)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))

                    FormOptionalDatePicker(label: "Date of Offence", date: $formData.indexOffenceDate)
                }
            }

            // --- Imported Data Section (matching GPR) ---
            if !formData.forensicImported.isEmpty {
                TribunalCollapsibleSection(title: "Imported Data (\(formData.forensicImported.count))", color: .yellow) {
                    TribunalImportedEntriesList(entries: $formData.forensicImported)
                }
            }
        }
    }

    // MARK: - Section 6: Previous MH Dates (matching GPR Past Psychiatric History structure exactly)
    private var previousMHDatesPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            // --- Detected Admissions Table (matching GPR exactly) ---
            TribunalCollapsibleSection(title: "Detected Admissions (\(formData.admissionsTableData.count))", color: .blue) {
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

            // --- Admission Clerking Notes (matching GPR exactly) ---
            if !formData.clerkingNotes.isEmpty {
                TribunalCollapsibleSection(title: "Admission Clerking Notes (\(formData.clerkingNotes.count))", color: .blue) {
                    TribunalImportedEntriesList(entries: $formData.clerkingNotes)
                }
            }

            // --- Progress and Risk Narrative (matching Notes Progress section) ---
            TribunalCollapsibleSection(title: "Progress & Risk Narrative", color: .purple) {
                PTRProgressNarrativeSection(
                    onCopyToCard: { narrative in
                        // Export narrative to the card for Section 6
                        onCopyNarrativeToCard?(narrative)
                    }
                )
            }
        }
    }

    // MARK: - Section 7: Previous Admission Reasons (same structure as Section 6)
    private var previousAdmissionReasonsPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            // --- Detected Admissions Table (matching Section 6) ---
            TribunalCollapsibleSection(title: "Detected Admissions (\(formData.admissionsTableData.count))", color: .blue) {
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

            // --- Admission Clerking Notes (matching Section 6) ---
            if !formData.clerkingNotes.isEmpty {
                TribunalCollapsibleSection(title: "Admission Clerking Notes (\(formData.clerkingNotes.count))", color: .blue) {
                    TribunalImportedEntriesList(entries: $formData.clerkingNotes)
                }
            }

            // --- Progress and Risk Narrative (matching Section 6) ---
            TribunalCollapsibleSection(title: "Progress & Risk Narrative", color: .purple) {
                PTRProgressNarrativeSection(
                    onCopyToCard: { narrative in
                        // Export narrative to the card for Section 7
                        onCopyNarrativeToCard?(narrative)
                    }
                )
            }
        }
    }

    // MARK: - Section 8: Current Admission (matches GPR Section 3 - most recent admission only)
    private var currentAdmissionPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            // --- Most Recent Admission Info ---
            if let mostRecent = formData.admissionsTableData.last {
                TribunalCollapsibleSection(title: "Current Admission", color: .orange) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Admission Date:")
                                .font(.caption.weight(.semibold))
                            Spacer()
                            if let admDate = mostRecent.admissionDate {
                                Text(admDate, format: .dateTime.day().month(.abbreviated).year())
                                    .font(.caption)
                            } else {
                                Text("Unknown")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        HStack {
                            Text("Status:")
                                .font(.caption.weight(.semibold))
                            Spacer()
                            if mostRecent.dischargeDate == nil {
                                Text("Ongoing")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            } else {
                                Text("Discharged \(mostRecent.dischargeDate!, format: .dateTime.day().month(.abbreviated).year())")
                                    .font(.caption)
                            }
                        }
                        HStack {
                            Text("Duration:")
                                .font(.caption.weight(.semibold))
                            Spacer()
                            Text(mostRecent.duration)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            // --- Admission Clerking Notes (for most recent admission) ---
            if !formData.clerkingNotes.isEmpty {
                // Filter to most recent admission's clerkings
                let recentClerkings = formData.clerkingNotes.suffix(3)  // Last 3 clerkings are most recent
                TribunalCollapsibleSection(title: "Admission Clerking (\(recentClerkings.count))", color: .orange) {
                    ForEach(Array(recentClerkings)) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            if let date = entry.date {
                                Text(date, format: .dateTime.day().month(.abbreviated).year())
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                            Text(entry.snippet ?? entry.text.prefix(200).description)
                                .font(.caption)
                                .lineLimit(3)
                        }
                        .padding(.vertical, 4)
                        Divider()
                    }
                }
            }

            // --- Current Admission Narrative (filtered to most recent admission) ---
            TribunalCollapsibleSection(title: "Admission Narrative", color: .orange) {
                PTRCurrentAdmissionNarrativeSection(
                    onCopyToCard: { narrative in
                        onCopyNarrativeToCard?(narrative)
                    }
                )
            }

            // --- Related Notes (legacy) ---
            if !formData.admissionImported.isEmpty {
                TribunalCollapsibleSection(title: "Related Notes (\(formData.admissionImported.count))", color: .yellow) {
                    TribunalImportedEntriesList(entries: $formData.admissionImported)
                }
            }
        }
    }

    // MARK: - Section 9: Diagnosis
    private var diagnosisPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Is the patient now suffering from a mental disorder?")
                .font(.subheadline).foregroundColor(.secondary)

            // Yes/No Radio
            TribunalYesNoRadio(selection: $formData.hasMentalDisorder)

            if formData.hasMentalDisorder {
                Divider()

                Text("ICD-10 Diagnosis").font(.headline)

                TribunalICD10DiagnosisPicker(
                    label: "Primary Diagnosis",
                    selection: $formData.diagnosis1
                )

                TribunalICD10DiagnosisPicker(
                    label: "Secondary Diagnosis",
                    selection: $formData.diagnosis2
                )

                TribunalICD10DiagnosisPicker(
                    label: "Tertiary Diagnosis",
                    selection: $formData.diagnosis3
                )
            }
        }
    }

    // MARK: - Section 10: Learning Disability
    private var learningDisabilityPopup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Does the patient have a learning disability?").font(.headline)

            Picker("", selection: $formData.hasLearningDisability) {
                Text("No").tag(false)
                Text("Yes").tag(true)
            }
            .pickerStyle(.segmented)

            if formData.hasLearningDisability {
                FormTextEditor(label: "Details of learning disability", text: $formData.learningDisabilityDetails, minHeight: 80)
            }
        }
    }

    // MARK: - Section 11: Detention Required
    private var detentionRequiredPopup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Is the mental disorder of a nature or degree which makes detention appropriate?")
                .font(.subheadline)

            Picker("", selection: $formData.detentionAppropriate) {
                Text("No").tag(false)
                Text("Yes").tag(true)
            }
            .pickerStyle(.segmented)

            FormTextEditor(label: "Explanation", text: $formData.detentionExplanation, minHeight: 100)
        }
    }

    // MARK: - Section 12: Treatment
    private var treatmentPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Medical Treatment - Medications with database
            Text("Medical Treatment").font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(formData.medications.indices, id: \.self) { index in
                    TribunalMedicationFullRowView(
                        entry: $formData.medications[index],
                        onDelete: { formData.medications.remove(at: index) }
                    )
                }
                Button {
                    formData.medications.append(TribunalMedicationEntry())
                } label: {
                    Label("Add Medication", systemImage: "plus.circle")
                }
                .padding(.top, 4)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)

            Divider()
            Text("Other Treatment").font(.headline)

            // Nursing - Checkbox + Dropdown
            HStack(alignment: .top) {
                Toggle("Nursing", isOn: $formData.nursingEnabled)
                    .toggleStyle(.tribunalCheckbox)
                Spacer()
                if formData.nursingEnabled {
                    Picker("", selection: $formData.nursingType) {
                        Text("Inpatient").tag("Inpatient")
                        Text("Community").tag("Community")
                    }
                    .pickerStyle(.menu)
                    .frame(width: 140)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)

            // Psychology - Checkbox + Radio + Dropdown
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Psychology", isOn: $formData.psychologyEnabled)
                    .toggleStyle(.tribunalCheckbox)

                if formData.psychologyEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 16) {
                            TribunalRadioOption(label: "Continue", isSelected: formData.psychologyStatus == "Continue", onSelect: { formData.psychologyStatus = "Continue" })
                            TribunalRadioOption(label: "Start", isSelected: formData.psychologyStatus == "Start", onSelect: { formData.psychologyStatus = "Start" })
                            TribunalRadioOption(label: "Refused", isSelected: formData.psychologyStatus == "Refused", onSelect: { formData.psychologyStatus = "Refused" })
                        }

                        if formData.psychologyStatus != "Refused" {
                            Picker("Therapy Type", selection: $formData.psychologyTherapyType) {
                                Text("CBT").tag("CBT")
                                Text("Trauma-focussed").tag("Trauma-focussed")
                                Text("DBT").tag("DBT")
                                Text("Psychodynamic").tag("Psychodynamic")
                                Text("Supportive").tag("Supportive")
                            }
                            .pickerStyle(.menu)
                        }
                    }
                    .padding(.leading, 24)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)

            // OT - Checkbox + Text
            VStack(alignment: .leading, spacing: 8) {
                Toggle("OT", isOn: $formData.otEnabled)
                    .toggleStyle(.tribunalCheckbox)

                if formData.otEnabled {
                    TextField("OT input details...", text: $formData.otDetails, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)
                        .padding(.leading, 24)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)

            // Social Work - Checkbox + Dropdown
            HStack(alignment: .top) {
                Toggle("Social Work", isOn: $formData.socialWorkEnabled)
                    .toggleStyle(.tribunalCheckbox)
                Spacer()
                if formData.socialWorkEnabled {
                    Picker("", selection: $formData.socialWorkType) {
                        Text("Inpatient").tag("Inpatient")
                        Text("Community").tag("Community")
                    }
                    .pickerStyle(.menu)
                    .frame(width: 140)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)

            // Care Pathway - Checkbox + Dropdown
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Care Pathway", isOn: $formData.carePathwayEnabled)
                    .toggleStyle(.tribunalCheckbox)

                if formData.carePathwayEnabled {
                    Picker("", selection: $formData.carePathwayType) {
                        Text("Inpatient - less restrictive").tag("inpatient - less restrictive")
                        Text("Inpatient - discharge").tag("inpatient - discharge")
                        Text("Outpatient - stepdown").tag("outpatient - stepdown")
                        Text("Outpatient - independent").tag("outpatient - independent")
                    }
                    .pickerStyle(.menu)
                    .padding(.leading, 24)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)

            if !formData.treatmentImported.isEmpty {
                TribunalCollapsibleSection(title: "Imported Treatment (\(formData.treatmentImported.count))", color: .yellow) {
                    TribunalImportedEntriesList(entries: $formData.treatmentImported)
                }
            }
        }
    }

    // MARK: - Section 13: Strengths
    private var strengthsPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Strengths or Positive Factors").font(.headline)
            FormTextEditor(label: "Narrative", text: $formData.strengthsNarrative, minHeight: 100)

            if !formData.strengthsImported.isEmpty {
                TribunalCollapsibleSection(title: "Imported Notes (\(formData.strengthsImported.count))", color: .yellow) {
                    TribunalImportedEntriesList(entries: $formData.strengthsImported)
                }
            }
        }
    }

    // MARK: - Section 14: Progress
    private var progressPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Current Progress, Behaviour, Capacity and Insight").font(.headline)

            // Auto-generated narrative summary section (matching desktop Section 14 style)
            if !formData.progressImported.isEmpty {
                TribunalNarrativeSummarySection(
                    entries: formData.progressImported,
                    patientName: formData.patientName.components(separatedBy: " ").first ?? "The patient",
                    gender: formData.patientGender.rawValue
                )
            }

            // Manual narrative for additional notes
            FormTextEditor(label: "Additional Notes", text: $formData.progressNarrative, minHeight: 80)

            if !formData.progressImported.isEmpty {
                TribunalCollapsibleSection(title: "Individual Progress Notes (\(formData.progressImported.count))", color: .yellow) {
                    TribunalImportedEntriesList(entries: $formData.progressImported)
                }
            }
        }
    }

    // MARK: - Section 15: Compliance
    private var compliancePopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Patient's understanding of, and compliance with, treatment").font(.headline)

            // Grid table with treatment types - matching desktop exactly
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Treatment").font(.caption.bold())
                        .frame(width: 90, alignment: .leading)
                    Spacer()
                    Text("Understanding").font(.caption.bold())
                        .frame(width: 110, alignment: .center)
                    Text("Compliance").font(.caption.bold())
                        .frame(width: 110, alignment: .center)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color(.systemGray5))

                Divider()

                // Medical
                TribunalComplianceRowDesktop(
                    label: "Medical",
                    understanding: $formData.medicalUnderstanding,
                    compliance: $formData.medicalCompliance
                )

                Divider()

                // Nursing
                TribunalComplianceRowDesktop(
                    label: "Nursing",
                    understanding: $formData.nursingUnderstanding,
                    compliance: $formData.nursingCompliance
                )

                Divider()

                // Psychology
                TribunalComplianceRowDesktop(
                    label: "Psychology",
                    understanding: $formData.psychologyUnderstanding,
                    compliance: $formData.psychologyCompliance
                )

                Divider()

                // OT
                TribunalComplianceRowDesktop(
                    label: "OT",
                    understanding: $formData.otUnderstanding,
                    compliance: $formData.otCompliance
                )

                Divider()

                // Social Work
                TribunalComplianceRowDesktop(
                    label: "Social Work",
                    understanding: $formData.socialWorkUnderstanding,
                    compliance: $formData.socialWorkCompliance
                )
            }
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )

            if !formData.complianceImported.isEmpty {
                TribunalCollapsibleSection(title: "Imported Compliance (\(formData.complianceImported.count))", color: .yellow) {
                    TribunalImportedEntriesList(entries: $formData.complianceImported)
                }
            }
        }
    }

    // MARK: - Section 16: MCA DoL
    private var mcaDoLPopup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Deprivation of Liberty under MCA 2005").font(.headline)

            Toggle("DoLS authorisation in place", isOn: $formData.dolsInPlace)
            Toggle("Court of Protection order", isOn: $formData.copOrder)
            Toggle("Standard authorisation", isOn: $formData.standardAuthorisation)

            VStack(alignment: .leading, spacing: 4) {
                Text("Floating provision consideration").font(.subheadline).foregroundColor(.secondary)
                Picker("", selection: $formData.floatingProvision) {
                    Text("Not applicable").tag("Not applicable")
                    Text("Being considered").tag("Being considered")
                    Text("In progress").tag("In progress")
                    Text("Granted").tag("Granted")
                }
                .pickerStyle(.menu)
            }

            FormTextEditor(label: "Details", text: $formData.mcaDetails, minHeight: 60)
        }
    }

    // MARK: - Section 17: Risk Harm
    private var riskHarmPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Incidents of Harm to Self or Others").font(.headline)

            TribunalCollapsibleSection(title: "Harm Types", color: .red) {
                Toggle("Physical assault on staff", isOn: $formData.harmAssaultStaff)
                Toggle("Physical assault on patients", isOn: $formData.harmAssaultPatients)
                Toggle("Physical assault on public", isOn: $formData.harmAssaultPublic)
                Toggle("Verbal aggression/threats", isOn: $formData.harmVerbalAggression)
                Toggle("Self-harm", isOn: $formData.harmSelfHarm)
                Toggle("Suicidal ideation/attempt", isOn: $formData.harmSuicidal)
            }

            if !formData.riskHarmImported.isEmpty {
                TribunalCollapsibleSection(title: "Imported Incidents (\(formData.riskHarmImported.count))", color: .yellow) {
                    TribunalImportedEntriesList(entries: $formData.riskHarmImported)
                }
            }
        }
    }

    // MARK: - Section 18: Risk Property
    private var riskPropertyPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Incidents of Property Damage").font(.headline)

            TribunalCollapsibleSection(title: "Property Damage Types", color: .orange) {
                Toggle("Ward property damage", isOn: $formData.propertyWard)
                Toggle("Personal belongings damage", isOn: $formData.propertyPersonal)
                Toggle("Fire setting", isOn: $formData.propertyFire)
                Toggle("Vehicle damage", isOn: $formData.propertyVehicle)
            }

            if !formData.riskPropertyImported.isEmpty {
                TribunalCollapsibleSection(title: "Imported Incidents (\(formData.riskPropertyImported.count))", color: .yellow) {
                    TribunalImportedEntriesList(entries: $formData.riskPropertyImported)
                }
            }
        }
    }

    // MARK: - Section 19: S2 Detention
    private var s2DetentionPopup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Section 2: Is detention justified for the health or safety of the patient or the protection of others?")
                .font(.subheadline)

            Picker("", selection: $formData.s2DetentionJustified) {
                Text("No").tag(false)
                Text("Yes").tag(true)
            }
            .pickerStyle(.segmented)

            FormTextEditor(label: "Explanation", text: $formData.s2Explanation, minHeight: 100)
        }
    }

    // MARK: - Section 20: Other Detention
    private var otherDetentionPopup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Other sections: Is medical treatment justified for health, safety or protection?")
                .font(.subheadline)

            Picker("", selection: $formData.otherDetentionJustified) {
                Text("No").tag(false)
                Text("Yes").tag(true)
            }
            .pickerStyle(.segmented)

            FormTextEditor(label: "Explanation", text: $formData.otherDetentionExplanation, minHeight: 100)
        }
    }

    // MARK: - Section 21: Discharge Risk
    private var dischargeRiskPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Risk if Discharged from Hospital").font(.headline)

            TribunalCollapsibleSection(title: "Risk Factors", color: .red) {
                Toggle("Risk of violence to others", isOn: $formData.dischargeRiskViolence)
                Toggle("Risk of self-harm/suicide", isOn: $formData.dischargeRiskSelfHarm)
                Toggle("Risk of self-neglect", isOn: $formData.dischargeRiskNeglect)
                Toggle("Risk of exploitation", isOn: $formData.dischargeRiskExploitation)
                Toggle("Risk of relapse", isOn: $formData.dischargeRiskRelapse)
                Toggle("Risk of non-compliance", isOn: $formData.dischargeRiskNonCompliance)
            }

            FormTextEditor(label: "Details", text: $formData.dischargeRiskDetails, minHeight: 100)
        }
    }

    // MARK: - Section 22: Community Management
    private var communityManagementPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Community Risk Management").font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text("CMHT involvement").font(.subheadline).foregroundColor(.secondary)
                Picker("", selection: $formData.cmhtInvolvement) {
                    Text("Not required").tag("Not required")
                    Text("Referral pending").tag("Referral pending")
                    Text("In place").tag("In place")
                }
                .pickerStyle(.menu)
            }

            Toggle("CPA in place", isOn: $formData.cpaInPlace)
            Toggle("Care coordinator assigned", isOn: $formData.careCoordinator)
            Toggle("Section 117 aftercare", isOn: $formData.section117)
            Toggle("MAPPA involvement", isOn: $formData.mappaInvolved)

            if formData.mappaInvolved {
                VStack(alignment: .leading, spacing: 4) {
                    Text("MAPPA Level").font(.subheadline).foregroundColor(.secondary)
                    Picker("", selection: $formData.mappaLevel) {
                        Text("Level 1").tag("Level 1")
                        Text("Level 2").tag("Level 2")
                        Text("Level 3").tag("Level 3")
                    }
                    .pickerStyle(.segmented)
                }
            }

            FormTextEditor(label: "Community Management Plan", text: $formData.communityPlanDetails, minHeight: 100)
        }
    }

    // MARK: - Section 23: Recommendations / Legal Criteria
    private var recommendationsPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            // ── Mental Disorder ──
            Text("Mental Disorder").font(.headline)

            legalRadio(label: "Present", altLabel: "Absent", selection: $formData.recMdPresent)

            if formData.recMdPresent == true {
                // ICD-10 diagnosis pickers
                VStack(alignment: .leading, spacing: 8) {
                    Text("Diagnosis (ICD-10)").font(.subheadline).foregroundColor(.secondary)

                    TribunalICD10DiagnosisPicker(
                        label: "Primary Diagnosis",
                        selection: $formData.recDiagnosis1
                    )
                    TribunalICD10DiagnosisPicker(
                        label: "Secondary Diagnosis",
                        selection: $formData.recDiagnosis2
                    )
                    TribunalICD10DiagnosisPicker(
                        label: "Tertiary Diagnosis",
                        selection: $formData.recDiagnosis3
                    )
                }
                .padding(.leading, 8)

                Divider()

                // ── Criteria Warranting Detention ──
                Text("Criteria Warranting Detention").font(.headline)

                legalRadio(label: "Met", altLabel: "Not Met", selection: $formData.recCwdMet)

                if formData.recCwdMet == true {
                    VStack(alignment: .leading, spacing: 10) {
                        // Nature
                        Toggle("Nature", isOn: $formData.recNature)
                            .toggleStyle(TribunalCheckboxStyle())

                        if formData.recNature {
                            VStack(alignment: .leading, spacing: 6) {
                                Toggle("Relapsing and remitting", isOn: $formData.recRelapsing)
                                    .toggleStyle(TribunalCheckboxStyle())
                                Toggle("Treatment resistant", isOn: $formData.recTreatmentResistant)
                                    .toggleStyle(TribunalCheckboxStyle())
                                Toggle("Chronic and enduring", isOn: $formData.recChronic)
                                    .toggleStyle(TribunalCheckboxStyle())
                            }
                            .padding(.leading, 24)
                        }

                        // Degree
                        Toggle("Degree", isOn: $formData.recDegree)
                            .toggleStyle(TribunalCheckboxStyle())

                        if formData.recDegree {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Symptom severity:").font(.subheadline).foregroundColor(.secondary)
                                Picker("Severity", selection: $formData.recDegreeLevel) {
                                    Text("Some").tag(1)
                                    Text("Several").tag(2)
                                    Text("Many").tag(3)
                                    Text("Overwhelming").tag(4)
                                }
                                .pickerStyle(.segmented)

                                FormTextEditor(label: "Symptoms including:", text: $formData.recDegreeDetails, minHeight: 60)
                            }
                            .padding(.leading, 24)
                        }
                    }
                    .padding(.leading, 8)
                }

                Divider()

                // ── Necessity ──
                Text("Necessity").font(.headline)

                legalRadio(label: "Yes", altLabel: "No", selection: $formData.recNecessary)

                if formData.recNecessary == true {
                    VStack(alignment: .leading, spacing: 10) {
                        // Health
                        Toggle("Health", isOn: $formData.recHealth)
                            .toggleStyle(TribunalCheckboxStyle())

                        if formData.recHealth {
                            VStack(alignment: .leading, spacing: 6) {
                                Toggle("Mental Health", isOn: $formData.recMentalHealth)
                                    .toggleStyle(TribunalCheckboxStyle())

                                if formData.recMentalHealth {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Toggle("Poor compliance", isOn: $formData.recPoorCompliance)
                                            .toggleStyle(TribunalCheckboxStyle())
                                        Toggle("Limited insight", isOn: $formData.recLimitedInsight)
                                            .toggleStyle(TribunalCheckboxStyle())
                                    }
                                    .padding(.leading, 24)
                                }

                                Toggle("Physical Health", isOn: $formData.recPhysicalHealth)
                                    .toggleStyle(TribunalCheckboxStyle())

                                if formData.recPhysicalHealth {
                                    FormTextEditor(label: "Physical health details", text: $formData.recPhysicalHealthDetails, minHeight: 60)
                                        .padding(.leading, 24)
                                }
                            }
                            .padding(.leading, 24)
                        }

                        // Safety
                        Toggle("Safety", isOn: $formData.recSafety)
                            .toggleStyle(TribunalCheckboxStyle())

                        if formData.recSafety {
                            VStack(alignment: .leading, spacing: 6) {
                                Toggle("Self", isOn: $formData.recSafetySelf)
                                    .toggleStyle(TribunalCheckboxStyle())

                                if formData.recSafetySelf {
                                    FormTextEditor(label: "Details about risk to self", text: $formData.recSelfDetails, minHeight: 60)
                                        .padding(.leading, 24)
                                }

                                Toggle("Others", isOn: $formData.recOthers)
                                    .toggleStyle(TribunalCheckboxStyle())

                                if formData.recOthers {
                                    FormTextEditor(label: "Details about risk to others", text: $formData.recOthersDetails, minHeight: 60)
                                        .padding(.leading, 24)
                                }
                            }
                            .padding(.leading, 24)
                        }
                    }
                    .padding(.leading, 8)
                }

                Divider()

                // ── Treatment Available ──
                Toggle("Treatment Available", isOn: $formData.recTreatmentAvailable)
                    .toggleStyle(TribunalCheckboxStyle())
                    .font(.headline)

                // ── Least Restrictive ──
                Toggle("Least Restrictive Option", isOn: $formData.recLeastRestrictive)
                    .toggleStyle(TribunalCheckboxStyle())
                    .font(.headline)
            }

            if formData.recMdPresent == false {
                Text("Mental disorder is absent — no further criteria apply.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }

            if !formData.recommendationsImported.isEmpty {
                TribunalCollapsibleSection(title: "Imported Recommendations (\(formData.recommendationsImported.count))", color: .yellow) {
                    TribunalImportedEntriesList(entries: $formData.recommendationsImported)
                }
            }
        }
    }

    /// Radio button pair for Optional<Bool> (nil = nothing selected)
    private func legalRadio(label: String, altLabel: String, selection: Binding<Bool?>) -> some View {
        HStack(spacing: 20) {
            Button {
                selection.wrappedValue = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: selection.wrappedValue == true ? "largecircle.fill.circle" : "circle")
                        .foregroundColor(selection.wrappedValue == true ? .purple : .gray)
                    Text(label).foregroundColor(.primary)
                }
            }
            .buttonStyle(.plain)

            Button {
                selection.wrappedValue = false
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: selection.wrappedValue == false ? "largecircle.fill.circle" : "circle")
                        .foregroundColor(selection.wrappedValue == false ? .purple : .gray)
                    Text(altLabel).foregroundColor(.primary)
                }
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    // MARK: - Section 24: Signature
    private var signaturePopup: some View {
        VStack(alignment: .leading, spacing: 12) {
            FormTextField(label: "Name", text: $formData.signatureName, isRequired: true)
            FormTextField(label: "Designation", text: $formData.signatureDesignation)
            FormTextField(label: "Qualifications", text: $formData.signatureQualifications)
            FormTextField(label: "GMC/Registration Number", text: $formData.signatureRegNumber)
            FormDatePicker(label: "Date", date: $formData.signatureDate, isRequired: true)
        }
    }

    // MARK: - Generate Text
    private func generateText() -> String {
        switch section {
        case .patientDetails:
            var parts: [String] = []
            if !formData.patientName.isEmpty { parts.append("Name: \(formData.patientName)") }
            parts.append("Gender: \(formData.patientGender.rawValue)")
            if let dob = formData.patientDOB {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                parts.append("DOB: \(formatter.string(from: dob))")
            }
            if !formData.hospitalNumber.isEmpty { parts.append("Hospital No: \(formData.hospitalNumber)") }
            if !formData.nhsNumber.isEmpty { parts.append("NHS No: \(formData.nhsNumber)") }
            if !formData.currentLocation.isEmpty { parts.append("Location: \(formData.currentLocation)") }
            parts.append("Section: \(formData.mhaSection)")
            return parts.joined(separator: "\n")

        case .responsibleClinician:
            var parts: [String] = []
            if !formData.rcName.isEmpty { parts.append(formData.rcName) }
            if !formData.rcRoleTitle.isEmpty { parts.append(formData.rcRoleTitle) }
            if !formData.rcDiscipline.isEmpty { parts.append(formData.rcDiscipline) }
            if !formData.rcRegNumber.isEmpty { parts.append("Reg: \(formData.rcRegNumber)") }
            return parts.joined(separator: "\n")

        case .factorsHearing:
            // Desktop matching: Yes/No with factor-specific output
            let pronoun = genderPronoun(formData.patientGender)
            if !formData.hasFactorsAffectingHearing {
                var text = "No"
                if !formData.factorsDetails.isEmpty { text += "\n\n\(formData.factorsDetails)" }
                return text
            }

            var text = ""
            switch formData.selectedFactor {
            case "Autism":
                text = "\(pronoun.subj) suffers from Autism so may need more time and breaks in the hearing."
            case "Learning Disability":
                text = "\(pronoun.subj) is diagnosed with a learning disability so may need more time and breaks in the hearing."
            case "Low frustration tolerance":
                text = "\(pronoun.subj) can be irritable and has low frustration tolerance so may need more time and breaks in the hearing."
            default:
                text = "Yes"
            }
            if !formData.factorsDetails.isEmpty { text += "\n\n\(formData.factorsDetails)" }
            return text

        case .adjustments:
            // Desktop matching: Yes/No with adjustment-specific output
            let pronoun = genderPronoun(formData.patientGender)
            if !formData.hasAdjustmentsNeeded {
                var text = "No"
                if !formData.adjustmentsOther.isEmpty { text += "\n\n\(formData.adjustmentsOther)" }
                return text
            }

            var text = ""
            switch formData.selectedAdjustment {
            case "Explanation":
                text = "\(pronoun.subj) is likely to need some careful explanation around aspects of the hearing to help with \(pronoun.pos) understanding of the process."
            case "Breaks":
                text = "\(pronoun.subj) will potentially need some breaks in the hearing."
            case "More time":
                text = "\(pronoun.subj) is likely to need more time in the hearing to help \(pronoun.obj) cope with the details."
            default:
                text = "Yes"
            }
            if !formData.adjustmentsOther.isEmpty { text += "\n\n\(formData.adjustmentsOther)" }
            return text

        case .forensicHistory:
            let pronoun = genderPronoun(formData.patientGender)
            var parts: [String] = []

            // Index Offence
            if !formData.indexOffence.isEmpty {
                parts.append("Index Offence: \(formData.indexOffence)")
            }
            if let date = formData.indexOffenceDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                parts.append("Date: \(formatter.string(from: date))")
            }

            // Convictions narrative (matching desktop ForensicHistoryPopup)
            let convictionLabels = ["one conviction", "two convictions", "three convictions", "four convictions",
                                    "five convictions", "six convictions", "seven convictions", "eight convictions",
                                    "nine convictions", "ten convictions", "more than ten convictions"]
            let offenceLabels = ["one offence", "two offences", "three offences", "four offences",
                                 "five offences", "six offences", "seven offences", "eight offences",
                                 "nine offences", "ten offences", "more than ten offences"]
            let prisonLabels = ["less than six months", "six to twelve months", "one to two years",
                                "two to five years", "more than five years"]

            switch formData.convictionsStatus {
            case "declined":
                parts.append("\n\(pronoun.subj) did not wish to discuss convictions.")
            case "none":
                parts.append("\n\(pronoun.subj) has no convictions.")
            case "some":
                let convCount = convictionLabels[min(formData.convictionCountIndex, convictionLabels.count - 1)]
                let offCount = offenceLabels[min(formData.offenceCountIndex, offenceLabels.count - 1)]
                parts.append("\n\(pronoun.subj) \(pronoun.have) \(convCount) from \(offCount).")
            default:
                break
            }

            // Prison narrative
            switch formData.prisonStatus {
            case "declined":
                parts.append("\(pronoun.subj) did not wish to discuss prison history.")
            case "never":
                parts.append("\(pronoun.subj) \(pronoun.have) never been in prison.")
            case "yes":
                let duration = prisonLabels[min(formData.prisonDurationIndex, prisonLabels.count - 1)]
                if formData.convictionsStatus == "none" || formData.convictionsStatus == "declined" || formData.convictionsStatus.isEmpty {
                    parts.append("\(pronoun.subj) \(pronoun.have) been remanded to prison for \(duration).")
                } else {
                    parts.append("\(pronoun.subj) \(pronoun.have) spent \(duration) in prison.")
                }
            default:
                break
            }

            // Additional narrative
            if !formData.forensicHistoryNarrative.isEmpty {
                parts.append("\n\(formData.forensicHistoryNarrative)")
            }

            // Selected imported entries
            let selected = formData.forensicImported.filter { $0.selected }
            if !selected.isEmpty {
                parts.append("")
                for entry in selected { parts.append(entry.text) }
            }
            return parts.joined(separator: "\n")

        case .diagnosis:
            // Desktop matching: Yes/No for mental disorder + ICD-10 diagnoses
            if !formData.hasMentalDisorder {
                return "No"
            }

            var diagnoses: [String] = []
            if let d1 = formData.diagnosis1, d1 != .none {
                diagnoses.append("\(d1.diagnosisName) (\(d1.code))")
            }
            if let d2 = formData.diagnosis2, d2 != .none {
                diagnoses.append("\(d2.diagnosisName) (\(d2.code))")
            }
            if let d3 = formData.diagnosis3, d3 != .none {
                diagnoses.append("\(d3.diagnosisName) (\(d3.code))")
            }

            if diagnoses.isEmpty {
                return "Yes"
            } else if diagnoses.count == 1 {
                return "Yes - \(diagnoses[0]) is a mental disorder as defined by the Mental Health Act."
            } else {
                let allButLast = diagnoses.dropLast().joined(separator: ", ")
                let last = diagnoses.last!
                return "Yes - \(allButLast) and \(last) are mental disorders as defined by the Mental Health Act."
            }

        case .treatment:
            // Desktop matching format
            let pronoun = genderPronoun(formData.patientGender)
            var parts: [String] = []

            // Medications
            let meds = formData.medications.filter { !$0.name.isEmpty }
            if !meds.isEmpty {
                let medList = meds.map { med in
                    var str = med.name
                    if !med.dose.isEmpty { str += " \(med.dose)" }
                    if !med.frequency.isEmpty { str += " \(med.frequency)" }
                    return str
                }
                parts.append("Current medication: \(medList.joined(separator: ", ")).")
            }

            // Nursing
            if formData.nursingEnabled {
                if formData.nursingType == "Inpatient" {
                    parts.append("\(pronoun.subj) will continue with ongoing nursing care and treatment.")
                } else {
                    parts.append("\(pronoun.subj) will have ongoing input from a community psychiatric nurse.")
                }
            }

            // Psychology
            if formData.psychologyEnabled {
                let therapy = formData.psychologyTherapyType.lowercased()
                if formData.psychologyStatus == "Continue" {
                    parts.append("Psychological treatment will be to continue \(therapy) therapy.")
                } else if formData.psychologyStatus == "Start" {
                    parts.append("Psychological treatment will be to start \(therapy) therapy.")
                } else if formData.psychologyStatus == "Refused" {
                    parts.append("Psychological treatment was offered but \(pronoun.subj.lowercased()) refused \(therapy) therapy.")
                }
            }

            // OT
            if formData.otEnabled && !formData.otDetails.isEmpty {
                parts.append("OT: \(formData.otDetails)")
            }

            // Social Work
            if formData.socialWorkEnabled {
                if formData.socialWorkType == "Inpatient" {
                    parts.append("\(pronoun.subj) will have social worker involved in \(pronoun.pos) care to manage \(pronoun.pos) social circumstances as an inpatient.")
                } else {
                    parts.append("\(pronoun.subj) will have social worker involved in \(pronoun.pos) care to manage \(pronoun.pos) social circumstances in the community.")
                }
            }

            // Care Pathway
            if formData.carePathwayEnabled {
                switch formData.carePathwayType {
                case "inpatient - less restrictive":
                    parts.append("Care pathway: \(pronoun.subj) will move to less restrictive inpatient environment.")
                case "inpatient - discharge":
                    parts.append("Care pathway: \(pronoun.subj) will move towards discharge from inpatient care.")
                case "outpatient - stepdown":
                    parts.append("Care pathway: \(pronoun.subj) will step down to outpatient care.")
                case "outpatient - independent":
                    parts.append("Care pathway: \(pronoun.subj) will move to independent living with outpatient support.")
                default:
                    break
                }
            }

            // Selected imported entries
            let selectedTreatment = formData.treatmentImported.filter { $0.selected }
            if !selectedTreatment.isEmpty {
                parts.append("")
                for entry in selectedTreatment { parts.append(entry.text) }
            }

            return parts.joined(separator: "\n")

        case .riskHarm:
            var types: [String] = []
            if formData.harmAssaultStaff { types.append("assault on staff") }
            if formData.harmAssaultPatients { types.append("assault on patients") }
            if formData.harmAssaultPublic { types.append("assault on public") }
            if formData.harmVerbalAggression { types.append("verbal aggression/threats") }
            if formData.harmSelfHarm { types.append("self-harm") }
            if formData.harmSuicidal { types.append("suicidal ideation/attempt") }
            let selectedHarm = formData.riskHarmImported.filter { $0.selected }
            if types.isEmpty && selectedHarm.isEmpty {
                return "No significant incidents of harm reported."
            }
            var text = ""
            if !types.isEmpty {
                text = "Incidents include: " + types.joined(separator: ", ") + "."
            }
            if !selectedHarm.isEmpty {
                if !text.isEmpty { text += "\n\n" }
                for entry in selectedHarm { text += "\n\(entry.text)" }
            }
            return text

        case .dischargeRisk:
            var risks: [String] = []
            if formData.dischargeRiskViolence { risks.append("violence to others") }
            if formData.dischargeRiskSelfHarm { risks.append("self-harm/suicide") }
            if formData.dischargeRiskNeglect { risks.append("self-neglect") }
            if formData.dischargeRiskExploitation { risks.append("exploitation") }
            if formData.dischargeRiskRelapse { risks.append("relapse") }
            if formData.dischargeRiskNonCompliance { risks.append("non-compliance") }
            if risks.isEmpty && formData.dischargeRiskDetails.isEmpty {
                return "Risk factors if discharged: None identified."
            }
            var text = ""
            if !risks.isEmpty {
                text = "Risk factors if discharged: " + risks.joined(separator: ", ") + "."
            }
            if !formData.dischargeRiskDetails.isEmpty {
                if !text.isEmpty { text += "\n\n" }
                text += formData.dischargeRiskDetails
            }
            return text

        case .recommendations:
            return generateLegalCriteriaText()

        case .signature:
            var parts: [String] = []
            if !formData.signatureName.isEmpty { parts.append(formData.signatureName) }
            if !formData.signatureDesignation.isEmpty { parts.append(formData.signatureDesignation) }
            if !formData.signatureQualifications.isEmpty { parts.append(formData.signatureQualifications) }
            if !formData.signatureRegNumber.isEmpty { parts.append("Reg: \(formData.signatureRegNumber)") }
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            parts.append("Date: \(formatter.string(from: formData.signatureDate))")
            return parts.joined(separator: "\n")

        case .compliance:
            let p = genderPronoun(formData.patientGender)
            var parts: [String] = []

            // Medical - understanding + compliance phrase
            if !formData.medicalUnderstanding.isEmpty && !formData.medicalCompliance.isEmpty {
                let uPhrase = complianceUnderstandingPhrase(formData.medicalUnderstanding, treatment: "medical", pronoun: p)
                let cPhrase = complianceCompliancePhrase(formData.medicalCompliance)
                if !uPhrase.isEmpty && !cPhrase.isEmpty {
                    parts.append("\(uPhrase) \(cPhrase).")
                }
            }

            // Nursing - natural phrase
            if !formData.nursingUnderstanding.isEmpty && !formData.nursingCompliance.isEmpty {
                let phrase = complianceNursingPhrase(formData.nursingUnderstanding, compliance: formData.nursingCompliance, pronoun: p)
                if !phrase.isEmpty { parts.append(phrase) }
            }

            // Psychology - natural phrase
            if !formData.psychologyUnderstanding.isEmpty && !formData.psychologyCompliance.isEmpty {
                let phrase = compliancePsychologyPhrase(formData.psychologyUnderstanding, compliance: formData.psychologyCompliance, pronoun: p)
                if !phrase.isEmpty { parts.append(phrase) }
            }

            // OT - natural phrase
            if !formData.otUnderstanding.isEmpty && !formData.otCompliance.isEmpty {
                let phrase = complianceOTPhrase(formData.otUnderstanding, compliance: formData.otCompliance, pronoun: p)
                if !phrase.isEmpty { parts.append(phrase) }
            }

            // Social Work - natural phrase
            if !formData.socialWorkUnderstanding.isEmpty && !formData.socialWorkCompliance.isEmpty {
                let phrase = complianceSocialWorkPhrase(formData.socialWorkUnderstanding, compliance: formData.socialWorkCompliance, pronoun: p)
                if !phrase.isEmpty { parts.append(phrase) }
            }

            // Selected imported entries
            let selectedCompliance = formData.complianceImported.filter { $0.selected }
            if !selectedCompliance.isEmpty {
                parts.append("")
                for entry in selectedCompliance { parts.append(entry.text) }
            }

            return parts.joined(separator: " ")

        case .previousMHDates:
            // Section 6: Previous Mental Health Involvement
            // Uses the narrative from shared cache + admissions table + selected clerking notes
            var parts: [String] = []

            // Add admissions table if enabled
            if formData.includeAdmissionsTable && !formData.admissionsTableData.isEmpty {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "dd MMM yyyy"

                var tableLines: [String] = ["Previous Admissions:"]
                for (index, entry) in formData.admissionsTableData.enumerated() {
                    var line = "\(index + 1). "
                    if let admDate = entry.admissionDate {
                        line += dateFormatter.string(from: admDate)
                    } else {
                        line += "Unknown"
                    }
                    line += " - "
                    if let disDate = entry.dischargeDate {
                        line += dateFormatter.string(from: disDate)
                    } else {
                        line += "Ongoing"
                    }
                    line += " (\(entry.duration))"
                    tableLines.append(line)
                }
                parts.append(tableLines.joined(separator: "\n"))
            }

            // Add narrative from shared cache
            if sharedData.hasValidNarrativeCache {
                let narrativeText = convertNarrativeSectionsToPlainText(sharedData.cachedNarrativeSections)
                if !narrativeText.isEmpty {
                    parts.append(narrativeText)
                }
            }

            // Selected clerking notes
            let selectedClerking6 = formData.clerkingNotes.filter { $0.selected }
            if !selectedClerking6.isEmpty {
                parts.append("")
                for entry in selectedClerking6 { parts.append(entry.text) }
            }

            return parts.joined(separator: "\n\n")

        case .previousAdmissionReasons:
            // Section 7: Previous Admission Reasons (same as Section 6)
            // Uses the narrative from shared cache + admissions table + selected clerking notes
            var parts: [String] = []

            // Add admissions table if enabled
            if formData.includeAdmissionsTable && !formData.admissionsTableData.isEmpty {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "dd MMM yyyy"

                var tableLines: [String] = ["Previous Admissions:"]
                for (index, entry) in formData.admissionsTableData.enumerated() {
                    var line = "\(index + 1). "
                    if let admDate = entry.admissionDate {
                        line += dateFormatter.string(from: admDate)
                    } else {
                        line += "Unknown"
                    }
                    line += " - "
                    if let disDate = entry.dischargeDate {
                        line += dateFormatter.string(from: disDate)
                    } else {
                        line += "Ongoing"
                    }
                    line += " (\(entry.duration))"
                    tableLines.append(line)
                }
                parts.append(tableLines.joined(separator: "\n"))
            }

            // Add narrative from shared cache
            if sharedData.hasValidNarrativeCache {
                let narrativeText = convertNarrativeSectionsToPlainText(sharedData.cachedNarrativeSections)
                if !narrativeText.isEmpty {
                    parts.append(narrativeText)
                }
            }

            // Selected clerking notes
            let selectedClerking7 = formData.clerkingNotes.filter { $0.selected }
            if !selectedClerking7.isEmpty {
                parts.append("")
                for entry in selectedClerking7 { parts.append(entry.text) }
            }

            return parts.joined(separator: "\n\n")

        case .currentAdmission:
            // Section 8: Current Admission
            var parts: [String] = []

            if let mostRecent = formData.admissionsTableData.last {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "dd MMM yyyy"

                var admissionInfo = "Current Admission: "
                if let admDate = mostRecent.admissionDate {
                    admissionInfo += dateFormatter.string(from: admDate)
                }
                if mostRecent.dischargeDate == nil {
                    admissionInfo += " (Ongoing, \(mostRecent.duration))"
                } else if let disDate = mostRecent.dischargeDate {
                    admissionInfo += " to \(dateFormatter.string(from: disDate)) (\(mostRecent.duration))"
                }
                parts.append(admissionInfo)
            }

            // Selected imported entries
            let selectedAdmission = formData.admissionImported.filter { $0.selected }
            if !selectedAdmission.isEmpty {
                parts.append("")
                for entry in selectedAdmission { parts.append(entry.text) }
            }

            return parts.joined(separator: "\n\n")

        case .detentionRequired:
            // Section 11: Yes/No + explanation
            if formData.detentionAppropriate {
                var text = "Yes"
                if !formData.detentionExplanation.isEmpty {
                    text += "\n\n\(formData.detentionExplanation)"
                }
                return text
            } else {
                var text = "No"
                if !formData.detentionExplanation.isEmpty {
                    text += "\n\n\(formData.detentionExplanation)"
                }
                return text
            }

        case .strengths:
            // Section 13: Strengths — selected imported entries
            var strengthParts: [String] = []
            if !formData.strengthsNarrative.isEmpty {
                strengthParts.append(formData.strengthsNarrative)
            }
            let selectedStrengths = formData.strengthsImported.filter { $0.selected }
            if !selectedStrengths.isEmpty {
                if !strengthParts.isEmpty { strengthParts.append("") }
                for entry in selectedStrengths { strengthParts.append(entry.text) }
            }
            return strengthParts.joined(separator: "\n")

        case .progress:
            // Section 14: Progress — selected imported entries
            var progressParts: [String] = []
            if !formData.progressNarrative.isEmpty {
                progressParts.append(formData.progressNarrative)
            }
            let selectedProgress = formData.progressImported.filter { $0.selected }
            if !selectedProgress.isEmpty {
                if !progressParts.isEmpty { progressParts.append("") }
                for entry in selectedProgress { progressParts.append(entry.text) }
            }
            return progressParts.joined(separator: "\n")

        case .mcaDoL:
            // Section 16: MCA / Deprivation of Liberty
            var mcaParts: [String] = []
            var mcaToggles: [String] = []
            if formData.dolsInPlace { mcaToggles.append("DoLS in place") }
            if formData.copOrder { mcaToggles.append("CoP order") }
            if formData.standardAuthorisation { mcaToggles.append("Standard authorisation") }
            if !mcaToggles.isEmpty { mcaParts.append(mcaToggles.joined(separator: ", ")) }
            if formData.floatingProvision != "Not applicable" {
                mcaParts.append("Floating provision: \(formData.floatingProvision)")
            }
            if !formData.mcaDetails.isEmpty { mcaParts.append(formData.mcaDetails) }
            if mcaParts.isEmpty { return "Not applicable." }
            return mcaParts.joined(separator: "\n")

        case .riskProperty:
            // Section 18: Risk Property — toggles + selected imported entries
            var propTypes: [String] = []
            if formData.propertyWard { propTypes.append("ward property damage") }
            if formData.propertyPersonal { propTypes.append("personal property damage") }
            if formData.propertyFire { propTypes.append("fire setting") }
            if formData.propertyVehicle { propTypes.append("vehicle damage") }
            if propTypes.isEmpty && formData.riskPropertyImported.filter({ $0.selected }).isEmpty {
                return "No significant incidents of property damage reported."
            }
            var propText = ""
            if !propTypes.isEmpty {
                propText = "Incidents include: " + propTypes.joined(separator: ", ") + "."
            }
            let selectedProperty = formData.riskPropertyImported.filter { $0.selected }
            if !selectedProperty.isEmpty {
                if !propText.isEmpty { propText += "\n\n" }
                for entry in selectedProperty { propText += "\n\(entry.text)" }
            }
            return propText

        case .learningDisability:
            // Section 10: Yes/No + details
            if formData.hasLearningDisability {
                var text = "Yes"
                if !formData.learningDisabilityDetails.isEmpty {
                    text += "\n\n\(formData.learningDisabilityDetails)"
                }
                return text
            } else {
                return "No"
            }

        case .s2Detention:
            // Section 19: Yes/No + explanation
            if formData.s2DetentionJustified {
                var text = "Yes"
                if !formData.s2Explanation.isEmpty {
                    text += "\n\n\(formData.s2Explanation)"
                }
                return text
            } else {
                var text = "No"
                if !formData.s2Explanation.isEmpty {
                    text += "\n\n\(formData.s2Explanation)"
                }
                return text
            }

        case .otherDetention:
            // Section 20: Yes/No + explanation
            if formData.otherDetentionJustified {
                var text = "Yes"
                if !formData.otherDetentionExplanation.isEmpty {
                    text += "\n\n\(formData.otherDetentionExplanation)"
                }
                return text
            } else {
                var text = "No"
                if !formData.otherDetentionExplanation.isEmpty {
                    text += "\n\n\(formData.otherDetentionExplanation)"
                }
                return text
            }

        case .communityManagement:
            // Section 22: CMHT involvement + active toggles + plan details
            var parts: [String] = []
            if formData.cmhtInvolvement != "Not required" {
                parts.append("CMHT: \(formData.cmhtInvolvement)")
            }
            var toggles: [String] = []
            if formData.cpaInPlace { toggles.append("CPA in place") }
            if formData.careCoordinator { toggles.append("Care Coordinator assigned") }
            if formData.section117 { toggles.append("Section 117 aftercare") }
            if formData.mappaInvolved { toggles.append("MAPPA \(formData.mappaLevel)") }
            if !toggles.isEmpty {
                parts.append(toggles.joined(separator: ", "))
            }
            if !formData.communityPlanDetails.isEmpty {
                parts.append(formData.communityPlanDetails)
            }
            if parts.isEmpty { return "No community risk management plan specified." }
            return parts.joined(separator: "\n")

        default:
            // For sections without specific generation, return the narrative or default
            return ""
        }
    }

    // MARK: - Legal Criteria Text Generation (Section 23)

    private func generateLegalCriteriaText() -> String {
        let p = genderPronoun(formData.patientGender)
        // Derive singular/plural verb forms from pronoun
        let suffers = (p.have == "has") ? "suffers" : "suffer"
        let does = (p.have == "has") ? "does" : "do"
        var parts: [String] = []

        // 1. Mental Disorder + Nature/Degree
        if formData.recMdPresent == true {
            // Build diagnosis text from ICD-10 combos
            var dxItems: [String] = []
            for dx in [formData.recDiagnosis1, formData.recDiagnosis2, formData.recDiagnosis3] {
                if let d = dx {
                    dxItems.append("\(d.diagnosisName) (\(d.code))")
                }
            }
            let dxText: String
            if dxItems.count > 1 {
                dxText = dxItems.dropLast().joined(separator: ", ") + " and " + dxItems.last!
            } else {
                dxText = dxItems.first ?? ""
            }

            let mdBase: String
            if !dxText.isEmpty {
                mdBase = "\(p.subj) \(suffers) from \(dxText) which is a mental disorder under the Mental Health Act"
            } else {
                mdBase = "\(p.subj) \(suffers) from a mental disorder under the Mental Health Act"
            }

            if formData.recCwdMet == true {
                // Nature/Degree warranting detention
                let natureChecked = formData.recNature
                let degreeChecked = formData.recDegree

                let ndText: String
                if natureChecked && degreeChecked {
                    ndText = ", which is of a nature and degree to warrant detention."
                } else if natureChecked {
                    ndText = ", which is of a nature to warrant detention."
                } else if degreeChecked {
                    ndText = ", which is of a degree to warrant detention."
                } else {
                    ndText = "."
                }

                parts.append(mdBase + ndText)

                // Nature sub-options
                if natureChecked {
                    var natureTypes: [String] = []
                    if formData.recRelapsing { natureTypes.append("relapsing and remitting") }
                    if formData.recTreatmentResistant { natureTypes.append("treatment resistant") }
                    if formData.recChronic { natureTypes.append("chronic and enduring") }
                    if !natureTypes.isEmpty {
                        parts.append("The illness is of a \(natureTypes.joined(separator: ", ")) nature.")
                    }
                }

                // Degree sub-options
                if degreeChecked {
                    let levels = [1: "some", 2: "several", 3: "many", 4: "overwhelming"]
                    let level = levels[formData.recDegreeLevel] ?? "several"
                    let details = formData.recDegreeDetails.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !details.isEmpty {
                        parts.append("The degree of the illness is evidenced by \(level) symptoms including \(details).")
                    } else {
                        parts.append("The degree of the illness is evidenced by \(level) symptoms.")
                    }
                }
            } else if formData.recCwdMet == false {
                parts.append(mdBase + ".")
                parts.append("The criteria for detention are not met.")
            } else {
                parts.append(mdBase + ".")
            }
        } else if formData.recMdPresent == false {
            parts.append("\(p.subj) \(does) not suffer from a mental disorder under the Mental Health Act.")
        }

        // 2. Necessity
        if formData.recNecessary == true {
            // Health - Mental Health
            if formData.recHealth && formData.recMentalHealth {
                parts.append("Medical treatment under the Mental Health Act is necessary to prevent deterioration in \(p.pos) mental health.")

                let poor = formData.recPoorCompliance
                let limited = formData.recLimitedInsight

                if poor && limited {
                    parts.append("Both historical non compliance and current limited insight makes the risk on stopping medication high without the safeguards of the Mental Health Act. This would result in a deterioration of \(p.pos) mental state.")
                } else if poor {
                    parts.append("This is based on historical non compliance and without detention I would be concerned this would result in a deterioration of \(p.pos) mental state.")
                } else if limited {
                    parts.append("I am concerned about \(p.pos) current limited insight into \(p.pos) mental health needs and how this would result in immediate non compliance with medication, hence a deterioration in \(p.pos) mental health.")
                }
            } else {
                parts.append("Medical treatment under the Mental Health Act is necessary.")
            }

            // Health - Physical Health
            if formData.recHealth && formData.recPhysicalHealth {
                let details = formData.recPhysicalHealthDetails.trimmingCharacters(in: .whitespacesAndNewlines)
                let base: String
                if formData.recMentalHealth {
                    base = "The Mental Health Act is also necessary for maintaining \(p.pos) physical health."
                } else {
                    base = "The Mental Health Act is necessary for \(p.pos) physical health."
                }
                if !details.isEmpty {
                    parts.append("\(base) \(details)")
                } else {
                    parts.append(base)
                }
            }

            // Safety
            if formData.recSafety {
                let useAlso = formData.recHealth

                if formData.recSafetySelf {
                    let details = formData.recSelfDetails.trimmingCharacters(in: .whitespacesAndNewlines)
                    let base: String
                    if useAlso {
                        base = "The Mental Health Act is also necessary for \(p.pos) risk to \(p.reflex)."
                    } else {
                        base = "The Mental Health Act is necessary for \(p.pos) risk to \(p.reflex)."
                    }
                    if !details.isEmpty {
                        parts.append("\(base) \(details)")
                    } else {
                        parts.append(base)
                    }
                }

                if formData.recOthers {
                    let details = formData.recOthersDetails.trimmingCharacters(in: .whitespacesAndNewlines)
                    let base: String
                    if useAlso || formData.recSafetySelf {
                        base = "Risk to others also makes the Mental Health Act necessary."
                    } else {
                        base = "Risk to others makes the Mental Health Act necessary."
                    }
                    if !details.isEmpty {
                        parts.append("\(base) \(details)")
                    } else {
                        parts.append(base)
                    }
                }
            }
        } else if formData.recNecessary == false {
            parts.append("Medical treatment under the Mental Health Act is not necessary.")
        }

        // 3. Treatment Available
        if formData.recTreatmentAvailable {
            parts.append("Treatment is available, medical, nursing, OT/Psychology and social work.")
        }

        // 4. Least Restrictive
        if formData.recLeastRestrictive {
            parts.append("I can confirm this is the least restrictive option to meet \(p.pos) needs.")
        }

        // Selected imported entries
        let selectedRec = formData.recommendationsImported.filter { $0.selected }
        if !selectedRec.isEmpty {
            for entry in selectedRec { parts.append(entry.text) }
        }

        return parts.joined(separator: " ")
    }

    // MARK: - Compliance Text Generation Helpers

    private func complianceUnderstandingPhrase(_ level: String, treatment: String, pronoun: GenderPronouns) -> String {
        switch level {
        case "good":
            return "\(pronoun.subj) has good understanding of \(pronoun.pos) \(treatment) treatment"
        case "fair":
            return "\(pronoun.subj) has some understanding of \(pronoun.pos) \(treatment) treatment"
        case "poor":
            return "\(pronoun.subj) has limited understanding of \(pronoun.pos) \(treatment) treatment"
        default:
            return ""
        }
    }

    private func complianceCompliancePhrase(_ level: String) -> String {
        switch level {
        case "full":
            return "and compliance is full"
        case "reasonable":
            return "and compliance is reasonable"
        case "partial":
            return "but compliance is partial"
        case "nil":
            return "and compliance is nil"
        default:
            return ""
        }
    }

    private func complianceNursingPhrase(_ understanding: String, compliance: String, pronoun: GenderPronouns) -> String {
        let engages = pronoun.subj == "They" ? "engage" : "engages"
        let sees = pronoun.subj == "They" ? "see" : "sees"
        let does = pronoun.subj == "They" ? "do" : "does"

        if understanding == "good" && (compliance == "full" || compliance == "reasonable") {
            return "\(pronoun.subj) \(engages) well with nursing staff and \(sees) the need for nursing input."
        } else if understanding == "good" && compliance == "partial" {
            return "\(pronoun.subj) understands the role of nursing but engagement is inconsistent."
        } else if understanding == "fair" && (compliance == "full" || compliance == "reasonable") {
            return "\(pronoun.subj) has some understanding of nursing care and \(engages) reasonably well."
        } else if understanding == "fair" && compliance == "partial" {
            return "\(pronoun.subj) has some understanding of nursing input but \(engages) only partially."
        } else if understanding == "poor" || compliance == "nil" {
            return "\(pronoun.subj) has limited insight into the need for nursing care and \(does) not engage meaningfully."
        }
        return ""
    }

    private func compliancePsychologyPhrase(_ understanding: String, compliance: String, pronoun: GenderPronouns) -> String {
        let engages = pronoun.subj == "They" ? "engage" : "engages"
        let does = pronoun.subj == "They" ? "do" : "does"

        if understanding == "good" && (compliance == "full" || compliance == "reasonable") {
            return "\(pronoun.subj) \(engages) in psychology sessions and sees the benefit of this work."
        } else if understanding == "good" && compliance == "partial" {
            return "\(pronoun.subj) understands the purpose of psychology but compliance with sessions is limited."
        } else if understanding == "fair" && (compliance == "full" || compliance == "reasonable") {
            return "\(pronoun.subj) has some understanding of psychology and attends sessions regularly."
        } else if understanding == "fair" && compliance == "partial" {
            return "\(pronoun.subj) also \(engages) in psychology sessions but the compliance with these is limited."
        } else if understanding == "poor" || compliance == "nil" {
            return "\(pronoun.subj) has limited insight into the need for psychology and \(does) not engage with sessions."
        }
        return ""
    }

    private func complianceOTPhrase(_ understanding: String, compliance: String, pronoun: GenderPronouns) -> String {
        let subj = pronoun.subj.lowercased()
        let engages = pronoun.subj == "They" ? "engage" : "engages"
        let isAre = pronoun.subj == "They" ? "are" : "is"

        if understanding == "good" && (compliance == "full" || compliance == "reasonable") {
            return "With respect to OT, \(subj) \(engages) well and sees the benefit of activities."
        } else if understanding == "good" && compliance == "partial" {
            return "With respect to OT, \(subj) understands the purpose but engagement is inconsistent."
        } else if understanding == "fair" && (compliance == "full" || compliance == "reasonable") {
            return "With respect to OT, \(subj) has some understanding and participates in activities."
        } else if understanding == "fair" && compliance == "partial" {
            return "With respect to OT, \(subj) has some insight but engagement is limited."
        } else if understanding == "poor" || compliance == "nil" {
            return "With respect to OT, \(subj) \(isAre) not engaging and doesn't see the need to."
        }
        return ""
    }

    private func complianceSocialWorkPhrase(_ understanding: String, compliance: String, pronoun: GenderPronouns) -> String {
        let engages = pronoun.subj == "They" ? "engage" : "engages"
        let sees = pronoun.subj == "They" ? "see" : "sees"

        if understanding == "good" && (compliance == "full" || compliance == "reasonable") {
            return "\(pronoun.subj) \(engages) well with the social worker and understands \(pronoun.pos) social circumstances."
        } else if understanding == "good" && compliance == "partial" {
            return "\(pronoun.subj) understands the social worker's role but engagement is inconsistent."
        } else if understanding == "fair" && (compliance == "full" || compliance == "reasonable") {
            return "\(pronoun.subj) has some understanding of social work input and \(engages) when available."
        } else if understanding == "fair" && compliance == "partial" {
            return "\(pronoun.subj) occasionally \(sees) the social worker and \(engages) partially when \(pronoun.subj.lowercased()) \(pronoun.subj == "They" ? "do" : "does") so."
        } else if understanding == "poor" || compliance == "nil" {
            return "\(pronoun.subj) has limited engagement with social work and doesn't see the relevance."
        }
        return ""
    }
}

// MARK: - Tribunal Collapsible Section
struct TribunalCollapsibleSection<Content: View>: View {
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

// MARK: - Tribunal Imported Entries List
struct TribunalImportedEntriesList: View {
    @Binding var entries: [TribunalImportedEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(entries.indices, id: \.self) { index in
                TribunalImportedEntryRow(entry: $entries[index])
            }
        }
    }
}

struct TribunalImportedEntryRow: View {
    @Binding var entry: TribunalImportedEntry
    @State private var isExpanded: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Left: Expand/Collapse button
            Button(action: { isExpanded.toggle() }) {
                Image(systemName: isExpanded ? "minus.circle.fill" : "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.purple)
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
                    // Show full text when expanded
                    Text(entry.text)
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    // Show snippet when collapsed
                    Text(entry.snippet ?? entry.text)
                        .font(.caption)
                        .lineLimit(3)
                }
            }

            Spacer()

            // Right: Checkbox to add to report
            Toggle("", isOn: $entry.selected)
                .labelsHidden()
                .toggleStyle(CheckboxToggleStyle())
        }
        .padding(8)
        .background(entry.selected ? Color.purple.opacity(0.1) : Color(.systemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Tribunal Yes/No Radio
struct TribunalYesNoRadio: View {
    @Binding var selection: Bool

    var body: some View {
        HStack(spacing: 20) {
            Button {
                selection = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: selection ? "largecircle.fill.circle" : "circle")
                        .foregroundColor(selection ? .purple : .gray)
                    Text("Yes")
                        .foregroundColor(.primary)
                }
            }
            .buttonStyle(.plain)

            Button {
                selection = false
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: !selection ? "largecircle.fill.circle" : "circle")
                        .foregroundColor(!selection ? .purple : .gray)
                    Text("No")
                        .foregroundColor(.primary)
                }
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Tribunal Radio Option (Single Selection)
struct TribunalRadioOption: View {
    let label: String
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(isSelected ? .purple : .gray)
                Text(label)
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - PTR Progress Narrative Section (SHARED cache with Notes Progress section)
struct PTRProgressNarrativeSection: View {
    @Environment(SharedDataStore.self) private var sharedData
    let onCopyToCard: (String) -> Void

    @State private var isGenerating = false
    @State private var selectedNoteId: UUID? = nil
    @State private var selectedHighlightText: String? = nil
    @State private var showingNotePanel = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if sharedData.notes.isEmpty {
                Text("Import clinical notes to generate narrative.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            } else if isGenerating {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Generating progress narrative...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else if sharedData.hasValidNarrativeCache {
                // Date range info
                if !sharedData.cachedNarrativeDateRange.isEmpty {
                    Text(sharedData.cachedNarrativeDateRange)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 4)
                }

                // Narrative with references (scrollable) - uses FlowingTextView like Notes Progress
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(sharedData.cachedNarrativeSections) { section in
                            if let title = section.title {
                                Text(title)
                                    .font(.caption.bold())
                                    .padding(.top, 4)
                            }
                            ForEach(section.content) { paragraph in
                                PTRFlowingTextView(
                                    segments: paragraph.segments,
                                    referenceMap: sharedData.cachedNarrativeReferenceMap,
                                    onReferenceTap: { noteId, highlightText in
                                        selectedNoteId = noteId
                                        selectedHighlightText = highlightText
                                        showingNotePanel = true
                                    }
                                )
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 300)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)

                // Note panel below (like Notes Progress)
                if showingNotePanel, let noteId = selectedNoteId,
                   let note = sharedData.notes.first(where: { $0.id == noteId }) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Source Note")
                                .font(.caption.bold())
                                .foregroundColor(.purple)
                            Spacer()
                            Button {
                                showingNotePanel = false
                                selectedNoteId = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }

                        HStack {
                            Text(note.date, style: .date)
                                .font(.caption2)
                            Text("•")
                                .foregroundColor(.secondary)
                            Text(note.type)
                                .font(.caption2)
                                .foregroundColor(.purple)
                            if !note.author.isEmpty {
                                Text("•")
                                    .foregroundColor(.secondary)
                                Text(note.author)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }

                        ScrollViewReader { proxy in
                            ScrollView {
                                PTRHighlightedNoteText(
                                    text: note.body,
                                    highlightText: selectedHighlightText
                                )
                                .id("noteContent")
                            }
                            .frame(maxHeight: 150)
                            .onAppear {
                                // Scroll to show highlighted text
                                if selectedHighlightText != nil {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        withAnimation {
                                            proxy.scrollTo("highlight", anchor: .center)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(8)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(8)
                }

                // Entry count
                Text("Based on \(sharedData.cachedNarrativeEntryCount) clinical entries")
                    .font(.caption2)
                    .foregroundColor(.purple)

                // Action buttons
                HStack(spacing: 12) {
                    Button {
                        // Copy plain text WITHOUT reference numbers
                        let plainText = convertNarrativeSectionsToPlainText(sharedData.cachedNarrativeSections)
                        onCopyToCard(plainText)
                    } label: {
                        Label("Copy to Card", systemImage: "doc.on.clipboard")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)

                    Button {
                        sharedData.clearNarrativeCache()
                        generateNarrative()
                    } label: {
                        Label("Regenerate", systemImage: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .tint(.purple)
                }
            } else {
                VStack(spacing: 12) {
                    Text("Generate a clinical narrative summary from the notes.\nThis includes progress, incidents, engagement, and risk factors.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Button {
                        generateNarrative()
                    } label: {
                        Label("Generate Narrative", systemImage: "text.badge.plus")
                            .font(.subheadline)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
        }
        .onAppear {
            // Check if notes changed since last cache
            sharedData.clearNarrativeCacheIfNeeded()
        }
    }

    private func generateNarrative() {
        isGenerating = true

        // Capture values before async task
        let notes = sharedData.notes
        let patientInfo = sharedData.patientInfo

        Task {
            let result = await Task.detached(priority: .userInitiated) {
                // Use the EXACT same generator as Notes Progress section
                let episodes = TimelineBuilder.buildTimeline(from: notes, allNotes: notes)
                let risks = RiskExtractor.shared.extractRisks(from: notes)
                let patientName = patientInfo.fullName.isEmpty ? "The patient" : patientInfo.fullName
                let pronouns = patientInfo.pronouns

                // Generate narrative sections using the same function as Notes Progress
                let sections = generateProgressNarrativeWithReferences(
                    patientName: patientName,
                    pronouns: pronouns,
                    episodes: episodes,
                    risks: risks,
                    notes: notes
                )

                // Build reference map - assign sequential numbers to each unique note ID
                var refMap: [UUID: Int] = [:]
                var refCounter = 1
                for section in sections {
                    for paragraph in section.content {
                        for segment in paragraph.segments {
                            if case .referenced(_, let ref, _) = segment {
                                if refMap[ref.noteId] == nil {
                                    refMap[ref.noteId] = refCounter
                                    refCounter += 1
                                }
                            }
                        }
                    }
                }

                // Get date range
                let allDates = notes.map { $0.date }
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "MMMM yyyy"
                var dateRangeStr = ""
                if let minDate = allDates.min(), let maxDate = allDates.max() {
                    dateRangeStr = "\(dateFormatter.string(from: minDate)) to \(dateFormatter.string(from: maxDate))"
                }

                return (sections, refMap, dateRangeStr, notes.count, notes.hashValue)
            }.value

            await MainActor.run {
                // Store in SHARED cache
                sharedData.cachedNarrativeSections = result.0
                sharedData.cachedNarrativeReferenceMap = result.1
                sharedData.cachedNarrativeDateRange = result.2
                sharedData.cachedNarrativeEntryCount = result.3
                sharedData.cachedNarrativeNotesHash = result.4
                isGenerating = false
            }
        }
    }
}

// MARK: - PTR Current Admission Narrative Section (filtered to most recent admission only)
struct PTRCurrentAdmissionNarrativeSection: View {
    @Environment(SharedDataStore.self) private var sharedData
    let onCopyToCard: (String) -> Void

    @State private var isGenerating = false
    @State private var narrativeSections: [NarrativeSection] = []
    @State private var referenceMap: [UUID: Int] = [:]
    @State private var dateRange: String = ""
    @State private var entryCount: Int = 0
    @State private var selectedNoteId: UUID? = nil
    @State private var selectedHighlightText: String? = nil
    @State private var showingNotePanel = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if sharedData.notes.isEmpty {
                Text("Import clinical notes to generate narrative.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            } else if isGenerating {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Generating admission narrative...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else if !narrativeSections.isEmpty {
                // Date range info
                if !dateRange.isEmpty {
                    Text(dateRange)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 4)
                }

                // Narrative with references (scrollable)
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(narrativeSections) { section in
                            if let title = section.title {
                                Text(title)
                                    .font(.caption.bold())
                                    .padding(.top, 4)
                            }
                            ForEach(section.content) { paragraph in
                                PTRFlowingTextView(
                                    segments: paragraph.segments,
                                    referenceMap: referenceMap,
                                    onReferenceTap: { noteId, highlightText in
                                        selectedNoteId = noteId
                                        selectedHighlightText = highlightText
                                        showingNotePanel = true
                                    }
                                )
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 300)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)

                // Note panel below
                if showingNotePanel, let noteId = selectedNoteId,
                   let note = sharedData.notes.first(where: { $0.id == noteId }) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Source Note")
                                .font(.caption.bold())
                                .foregroundColor(.orange)
                            Spacer()
                            Button {
                                showingNotePanel = false
                                selectedNoteId = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }

                        HStack {
                            Text(note.date, style: .date)
                                .font(.caption2)
                            Text("•")
                                .foregroundColor(.secondary)
                            Text(note.type)
                                .font(.caption2)
                                .foregroundColor(.orange)
                            if !note.author.isEmpty {
                                Text("•")
                                    .foregroundColor(.secondary)
                                Text(note.author)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }

                        ScrollViewReader { proxy in
                            ScrollView {
                                PTRHighlightedNoteText(
                                    text: note.body,
                                    highlightText: selectedHighlightText
                                )
                                .id("noteContent")
                            }
                            .frame(maxHeight: 150)
                            .onAppear {
                                if selectedHighlightText != nil {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        withAnimation {
                                            proxy.scrollTo("highlight", anchor: .center)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }

                // Entry count
                Text("Based on \(entryCount) entries from current admission")
                    .font(.caption2)
                    .foregroundColor(.orange)

                // Action buttons
                HStack(spacing: 12) {
                    Button {
                        let plainText = convertNarrativeSectionsToPlainText(narrativeSections)
                        onCopyToCard(plainText)
                    } label: {
                        Label("Copy to Card", systemImage: "doc.on.clipboard")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)

                    Button {
                        narrativeSections = []
                        generateNarrative()
                    } label: {
                        Label("Regenerate", systemImage: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                }
            } else {
                VStack(spacing: 12) {
                    Text("Generate a narrative for the current admission.\nFilters to notes from most recent admission date + 2 weeks.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Button {
                        generateNarrative()
                    } label: {
                        Label("Generate Narrative", systemImage: "text.badge.plus")
                            .font(.subheadline)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
        }
    }

    private func generateNarrative() {
        isGenerating = true

        let notes = sharedData.notes
        let patientInfo = sharedData.patientInfo

        Task {
            let result = await Task.detached(priority: .userInitiated) {
                // Build timeline to find most recent admission
                let episodes = TimelineBuilder.buildTimeline(from: notes, allNotes: notes)
                let inpatientEpisodes = episodes.filter { $0.type == .inpatient }

                guard let mostRecent = inpatientEpisodes.last else {
                    return ([] as [NarrativeSection], [:] as [UUID: Int], "", 0)
                }

                // Filter notes to admission period (admission date to 2 weeks post)
                let calendar = Calendar.current
                let admissionStart = mostRecent.start
                let twoWeeksPost = calendar.date(byAdding: .day, value: 14, to: admissionStart) ?? admissionStart

                let filteredNotes = notes.filter { note in
                    let noteDate = calendar.startOfDay(for: note.date)
                    return noteDate >= admissionStart && noteDate <= twoWeeksPost
                }

                guard !filteredNotes.isEmpty else {
                    return ([] as [NarrativeSection], [:] as [UUID: Int], "", 0)
                }

                // Generate narrative for filtered notes only
                let risks = RiskExtractor.shared.extractRisks(from: filteredNotes)
                let patientName = patientInfo.fullName.isEmpty ? "The patient" : patientInfo.fullName
                let pronouns = patientInfo.pronouns

                let sections = generateProgressNarrativeWithReferences(
                    patientName: patientName,
                    pronouns: pronouns,
                    episodes: [mostRecent],  // Only the most recent episode
                    risks: risks,
                    notes: filteredNotes
                )

                // Build reference map
                var refMap: [UUID: Int] = [:]
                var refCounter = 1
                for section in sections {
                    for paragraph in section.content {
                        for segment in paragraph.segments {
                            if case .referenced(_, let ref, _) = segment {
                                if refMap[ref.noteId] == nil {
                                    refMap[ref.noteId] = refCounter
                                    refCounter += 1
                                }
                            }
                        }
                    }
                }

                // Get date range
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "d MMM yyyy"
                let dateRangeStr = "Admission: \(dateFormatter.string(from: admissionStart)) to \(dateFormatter.string(from: twoWeeksPost))"

                return (sections, refMap, dateRangeStr, filteredNotes.count)
            }.value

            await MainActor.run {
                narrativeSections = result.0
                referenceMap = result.1
                dateRange = result.2
                entryCount = result.3
                isGenerating = false
            }
        }
    }
}

// MARK: - PTR Flowing Text View (with clickable references using AttributedString)
struct PTRFlowingTextView: View {
    let segments: [NarrativeSegment]
    let referenceMap: [UUID: Int]
    let onReferenceTap: (UUID, String?) -> Void

    var body: some View {
        Text(buildAttributedString())
            .font(.caption)
            .environment(\.openURL, OpenURLAction { url in
                handleReferenceURL(url)
                return .handled
            })
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.leading)
    }

    private func buildAttributedString() -> AttributedString {
        var result = AttributedString()

        for segment in segments {
            switch segment {
            case .plain(let text, let format):
                var attr = AttributedString(text)
                if format.contains(.bold) {
                    attr.font = .caption.bold()
                }
                result += attr

            case .referenced(let text, let reference, let format):
                // Add the main text
                var textAttr = AttributedString(text)
                if format.contains(.bold) {
                    textAttr.font = .caption.bold()
                }
                result += textAttr

                // Add the reference number as a tappable link
                let refNum = referenceMap[reference.noteId] ?? 0
                var refAttr = AttributedString("[\(refNum)]")
                refAttr.font = .caption2
                refAttr.foregroundColor = .purple
                refAttr.baselineOffset = 4

                // Encode noteId and highlightText in URL
                let highlightEncoded = (reference.highlightText ?? "").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                if let url = URL(string: "mparef://\(reference.noteId.uuidString)?h=\(highlightEncoded)") {
                    refAttr.link = url
                }
                result += refAttr
            }
        }

        return result
    }

    private func handleReferenceURL(_ url: URL) {
        guard url.scheme == "mparef",
              let noteIdString = url.host,
              let noteId = UUID(uuidString: noteIdString) else {
            return
        }

        var highlightText: String? = nil
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems {
            highlightText = queryItems.first(where: { $0.name == "h" })?.value
        }

        onReferenceTap(noteId, highlightText)
    }
}

// MARK: - PTR Highlighted Note Text (shows source note with relevant text highlighted)
struct PTRHighlightedNoteText: View {
    let text: String
    let highlightText: String?

    var body: some View {
        if let highlight = highlightText, !highlight.isEmpty {
            // Build attributed string with highlight
            Text(buildHighlightedText(fullText: text, highlight: highlight))
                .font(.caption)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(text)
                .font(.caption)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func buildHighlightedText(fullText: String, highlight: String) -> AttributedString {
        var result = AttributedString()

        // Find all occurrences of the highlight text (case-insensitive)
        var currentIndex = fullText.startIndex

        while currentIndex < fullText.endIndex {
            // Find the next occurrence
            let searchRange = currentIndex..<fullText.endIndex
            if let range = fullText.range(of: highlight, options: .caseInsensitive, range: searchRange) {
                // Add text before the match
                if currentIndex < range.lowerBound {
                    let beforeText = String(fullText[currentIndex..<range.lowerBound])
                    result += AttributedString(beforeText)
                }

                // Add the highlighted match
                let matchedText = String(fullText[range])
                var highlightedAttr = AttributedString(matchedText)
                highlightedAttr.backgroundColor = .yellow
                highlightedAttr.foregroundColor = .black

                result += highlightedAttr

                currentIndex = range.upperBound
            } else {
                // No more matches, add the rest of the text
                let remainingText = String(fullText[currentIndex...])
                result += AttributedString(remainingText)
                break
            }
        }

        return result
    }
}

/// Convert NarrativeSections to plain text WITHOUT reference numbers (for card export)
private func convertNarrativeSectionsToPlainText(_ sections: [NarrativeSection]) -> String {
    var lines: [String] = []

    for section in sections {
        if let title = section.title {
            lines.append(title)
        }
        for paragraph in section.content {
            var paragraphText = ""
            for segment in paragraph.segments {
                switch segment {
                case .plain(let text, _):
                    paragraphText += text
                case .referenced(let text, _, _):
                    // Do NOT include reference numbers in plain text export
                    paragraphText += text
                }
            }
            if !paragraphText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lines.append(paragraphText)
            }
        }
    }

    return lines.joined(separator: "\n")
}

// MARK: - Gender Pronoun Helper
struct GenderPronouns {
    let subj: String   // He/She/They
    let obj: String    // him/her/them
    let pos: String    // his/her/their
    let reflex: String // himself/herself/themselves
    let have: String   // has/have (for verb conjugation)
}

func genderPronoun(_ gender: Gender) -> GenderPronouns {
    switch gender {
    case .male:
        return GenderPronouns(subj: "He", obj: "him", pos: "his", reflex: "himself", have: "has")
    case .female:
        return GenderPronouns(subj: "She", obj: "her", pos: "her", reflex: "herself", have: "has")
    case .other, .notSpecified:
        return GenderPronouns(subj: "They", obj: "them", pos: "their", reflex: "themselves", have: "have")
    }
}

// MARK: - Tribunal Checkbox Toggle Style
struct TribunalCheckboxStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: { configuration.isOn.toggle() }) {
            HStack(spacing: 8) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .foregroundColor(configuration.isOn ? .purple : .gray)
                    .font(.title3)
                configuration.label
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(.plain)
    }
}

extension ToggleStyle where Self == TribunalCheckboxStyle {
    static var tribunalCheckbox: TribunalCheckboxStyle { TribunalCheckboxStyle() }
}

// MARK: - Tribunal Compliance Row (Desktop matching)
struct TribunalComplianceRowDesktop: View {
    let label: String
    @Binding var understanding: String
    @Binding var compliance: String

    // Desktop options exactly
    private let understandingOptions = ["Select...", "good", "fair", "poor"]
    private let complianceOptions = ["Select...", "full", "reasonable", "partial", "nil"]

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .frame(width: 90, alignment: .leading)

            Spacer()

            Picker("", selection: $understanding) {
                ForEach(understandingOptions, id: \.self) { option in
                    Text(option).tag(option == "Select..." ? "" : option)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 110)

            Picker("", selection: $compliance) {
                ForEach(complianceOptions, id: \.self) { option in
                    Text(option).tag(option == "Select..." ? "" : option)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 110)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
    }
}

// MARK: - Tribunal Medication Row View (Simple)
struct TribunalMedicationRowView: View {
    @Binding var entry: TribunalMedicationEntry
    let onDelete: () -> Void

    @State private var searchText: String = ""
    @State private var showingSuggestions = false
    @State private var filteredMedications: [(String, MedicationInfo)] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Search medication...", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: searchText) { _, newValue in
                            if newValue.count >= 2 {
                                filteredMedications = commonPsychMedications.filter { name, _ in
                                    name.lowercased().contains(newValue.lowercased())
                                }.map { ($0.key, $0.value) }
                                showingSuggestions = !filteredMedications.isEmpty
                            } else {
                                showingSuggestions = false
                            }
                        }
                        .onAppear { searchText = entry.name }

                    if !entry.name.isEmpty {
                        Text(entry.name).font(.caption).foregroundColor(.green)
                    }
                }

                Picker("", selection: $entry.dose) {
                    Text("Dose").tag("")
                    ForEach(dosesForMedication, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
                .frame(width: 100)

                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                }
            }

            if showingSuggestions {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(filteredMedications.prefix(6), id: \.0) { name, info in
                        Button {
                            entry.name = name
                            searchText = name
                            showingSuggestions = false
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(name).font(.subheadline).foregroundColor(.primary)
                                Text("BNF Max: \(info.bnfMax)").font(.caption2).foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            }
        }
    }

    private var dosesForMedication: [String] {
        if let medInfo = commonPsychMedications[entry.name] {
            return medInfo.doses.map { "\($0)mg" }
        }
        return ["5mg", "10mg", "15mg", "20mg", "25mg", "30mg", "50mg", "75mg", "100mg", "150mg", "200mg", "250mg", "300mg", "400mg", "500mg", "600mg", "800mg", "1000mg"]
    }
}

// MARK: - Tribunal Medication Full Row View (with Frequency - Desktop matching)
struct TribunalMedicationFullRowView: View {
    @Binding var entry: TribunalMedicationEntry
    let onDelete: () -> Void

    @State private var searchText: String = ""
    @State private var showingSuggestions = false
    @State private var filteredMedications: [(String, MedicationInfo)] = []

    private let frequencies = ["OD", "BD", "TDS", "QDS", "Nocte", "PRN", "Weekly", "Fortnightly", "Monthly"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                // Medication name search
                VStack(alignment: .leading, spacing: 2) {
                    TextField("Medication name...", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: searchText) { _, newValue in
                            if newValue.count >= 2 {
                                filteredMedications = commonPsychMedications.filter { name, _ in
                                    name.lowercased().contains(newValue.lowercased())
                                }.map { ($0.key, $0.value) }
                                showingSuggestions = !filteredMedications.isEmpty
                            } else {
                                showingSuggestions = false
                            }
                        }
                        .onAppear { searchText = entry.name }
                }
                .frame(maxWidth: .infinity)

                // Dose picker
                Picker("", selection: $entry.dose) {
                    Text("Dose").tag("")
                    ForEach(dosesForMedication, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
                .frame(width: 90)

                // Frequency picker
                Picker("", selection: $entry.frequency) {
                    Text("Freq").tag("")
                    ForEach(frequencies, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
                .frame(width: 90)

                // BNF Max display
                if let medInfo = commonPsychMedications[entry.name] {
                    Text(medInfo.bnfMax)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 70)
                }

                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                }
            }

            // Suggestions dropdown
            if showingSuggestions {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(filteredMedications.prefix(6), id: \.0) { name, info in
                        Button {
                            entry.name = name
                            searchText = name
                            showingSuggestions = false
                        } label: {
                            HStack {
                                Text(name).font(.subheadline).foregroundColor(.primary)
                                Spacer()
                                Text("Max: \(info.bnfMax)").font(.caption).foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            }
        }
        .padding(.vertical, 4)
    }

    private var dosesForMedication: [String] {
        if let medInfo = commonPsychMedications[entry.name] {
            return medInfo.doses.map { "\($0)mg" }
        }
        return ["5mg", "10mg", "15mg", "20mg", "25mg", "30mg", "50mg", "75mg", "100mg", "150mg", "200mg", "250mg", "300mg", "400mg", "500mg", "600mg", "800mg", "1000mg"]
    }
}

// MARK: - Tribunal ICD-10 Diagnosis Picker
struct TribunalICD10DiagnosisPicker: View {
    let label: String
    @Binding var selection: ICD10Diagnosis?

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button {
                isExpanded.toggle()
            } label: {
                HStack {
                    if let diagnosis = selection, diagnosis != .none {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(diagnosis.diagnosisName)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            Text(diagnosis.code)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Select diagnosis...")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)

            if isExpanded {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Clear option
                        Button {
                            selection = nil
                            isExpanded = false
                        } label: {
                            Text("Clear selection")
                                .font(.subheadline)
                                .foregroundColor(.red)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)

                        Divider()

                        // Grouped diagnoses - array of tuples
                        ForEach(ICD10Diagnosis.groupedDiagnoses, id: \.0) { category, diagnoses in
                            VStack(alignment: .leading, spacing: 0) {
                                Text(category)
                                    .font(.caption.bold())
                                    .foregroundColor(.purple)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.purple.opacity(0.1))

                                ForEach(diagnoses, id: \.self) { diagnosis in
                                    Button {
                                        selection = diagnosis
                                        isExpanded = false
                                    } label: {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(diagnosis.diagnosisName)
                                                .font(.subheadline)
                                                .foregroundColor(.primary)
                                            Text(diagnosis.code)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(selection == diagnosis ? Color.purple.opacity(0.15) : Color.clear)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 300)
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            }
        }
    }
}

// MARK: - Tribunal Narrative Summary Section (matching desktop Section 14 style)

/// Generates and displays a clinical narrative summary for Tribunal Section 14
struct TribunalNarrativeSummarySection: View {
    let entries: [TribunalImportedEntry]
    let patientName: String
    let gender: String
    var period: NarrativePeriod = .oneYear

    @State private var isExpanded = true
    @State private var includeNarrative = true
    @State private var generatedNarrative: NarrativeResult?

    private let narrativeGenerator = NarrativeGenerator()

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
                    .foregroundColor(Color(hex: "#806000"))
                }
                .buttonStyle(.plain)

                if isExpanded {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Include narrative in output", isOn: $includeNarrative)
                            .font(.caption)
                            .foregroundColor(Color(hex: "#806000"))

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
        // Convert TribunalImportedEntry to NarrativeEntry
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
                // Display the generated narrative
                Text(narrative.plainText)
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                // Fallback: basic narrative generation
                let sortedEntries = entries.compactMap { entry -> (Date, TribunalImportedEntry)? in
                    guard let date = entry.date else { return nil }
                    return (date, entry)
                }.sorted { $0.0 < $1.0 }

                if sortedEntries.isEmpty {
                    Text("No dated entries available for narrative generation.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    let earliest = sortedEntries.first!.0
                    let latest = sortedEntries.last!.0
                    let dateRange = Calendar.current.dateComponents([.day], from: earliest, to: latest).day ?? 1
                    let months = max(1, dateRange / 30)

                    // OVERVIEW
                    Text("REVIEW PERIOD OVERVIEW")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.primary)

                    let pronounPoss = gender.lowercased() == "male" || gender.lowercased() == "m" ? "his" :
                                     gender.lowercased() == "female" || gender.lowercased() == "f" ? "her" : "their"
                    let freqDesc = entries.count > months * 2 ? "regularly" : "periodically"
                    Text("\(patientName) has been reviewed \(freqDesc) over the past \(months) months with \(entries.count) documented contacts.")
                        .font(.caption)

                    Divider()

                    // MENTAL STATE
                    Text("MENTAL STATE AND PROGRESS")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.primary)

                    let positiveText = entries.filter { e in
                        let text = e.text.lowercased()
                        return text.contains("stable") || text.contains("settled") || text.contains("calm") ||
                               text.contains("pleasant") || text.contains("cooperative") || text.contains("engaged")
                    }
                    let negativeText = entries.filter { e in
                        let text = e.text.lowercased()
                        return text.contains("deteriorat") || text.contains("agitated") || text.contains("irritable") ||
                               text.contains("paranoid") || text.contains("psychotic") || text.contains("unsettled")
                    }

                    if positiveText.count > negativeText.count * 2 {
                        Text("\(patientName)'s mental state has been predominantly stable and positive throughout the review period.")
                            .font(.caption)
                    } else if negativeText.count > positiveText.count {
                        Text("\(patientName)'s mental state has shown some variability with periods of concern during the review period.")
                            .font(.caption)
                    } else {
                        Text("\(patientName)'s mental state has been variable, with both positive presentations and some concerning periods documented.")
                            .font(.caption)
                    }

                    Divider()

                    // SUMMARY
                    Text("SUMMARY")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.primary)

                    let summaryText = "\(patientName) has been reviewed \(freqDesc) over the past \(months) months. " + (positiveText.count > negativeText.count ? "\(pronounPoss) mental state has been predominantly stable." : "\(pronounPoss) mental state has shown some variability.")
                    Text(summaryText)
                        .font(.caption)
                }
            }
        }
    }
}

#Preview {
    PsychiatricTribunalReportView()
        .environment(AppStore())
        .environment(SharedDataStore.shared)
}
