//
//  NursingTribunalReportView.swift
//  MyPsychAdmin
//
//  Nursing Tribunal Report Form for iOS
//  Based on desktop nursing_tribunal_report_page.py structure (21 sections)
//  Uses same card/popup layout pattern as MOJASRFormView
//

import SwiftUI
import UniformTypeIdentifiers

struct NursingTribunalReportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var appStore
    @Environment(SharedDataStore.self) private var sharedData

    @State private var formData: NursingTribunalFormData
    @State private var validationErrors: [FormValidationError] = []
    @State private var generatedTexts: [NTRSection: String] = [:]
    @State private var manualNotes: [NTRSection: String] = [:]
    @State private var activePopup: NTRSection? = nil
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var showingImportPicker = false
    @State private var isImporting = false
    @State private var importStatusMessage: String?
    @State private var hasPopulatedFromSharedData = false
    @State private var docxURL: URL?
    @State private var showShareSheet = false

    // 21 Sections matching desktop Nursing Tribunal Report order
    enum NTRSection: String, CaseIterable, Identifiable {
        case patientDetails = "1. Patient Details"
        case factorsHearing = "2. Factors affecting understanding"
        case adjustments = "3. Adjustments for tribunal"
        case nursingCare = "4. Nature of nursing care"
        case observationLevel = "5. Level of observation"
        case contact = "6. Contact with relatives/friends"
        case communitySupport = "7. Community support"
        case strengths = "8. Strengths or positive factors"
        case progress = "9. Current progress and engagement"
        case awol = "10. AWOL or failed return"
        case compliance = "11. Compliance with treatment"
        case riskHarm = "12. Incidents of harm"
        case riskProperty = "13. Incidents of property damage"
        case seclusion = "14. Seclusion or restraint"
        case s2Detention = "15. Section 2: Detention justified"
        case otherDetention = "16. Other sections: Treatment justified"
        case dischargeRisk = "17. Risk if discharged"
        case communityManagement = "18. Community risk management"
        case otherInfo = "19. Other relevant information"
        case recommendations = "20. Recommendations to tribunal"
        case signature = "21. Signature"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .patientDetails: return "person"
            case .factorsHearing: return "ear"
            case .adjustments: return "slider.horizontal.3"
            case .nursingCare: return "cross.case"
            case .observationLevel: return "eye"
            case .contact: return "person.2"
            case .communitySupport: return "house.lodge"
            case .strengths: return "star"
            case .progress: return "chart.line.uptrend.xyaxis"
            case .awol: return "figure.walk.departure"
            case .compliance: return "checkmark.circle"
            case .riskHarm: return "exclamationmark.shield"
            case .riskProperty: return "flame"
            case .seclusion: return "lock.shield"
            case .s2Detention: return "doc.badge.gearshape"
            case .otherDetention: return "doc.badge.plus"
            case .dischargeRisk: return "arrow.right.to.line"
            case .communityManagement: return "person.3"
            case .otherInfo: return "info.circle"
            case .recommendations: return "text.badge.checkmark"
            case .signature: return "signature"
            }
        }

        var defaultHeight: CGFloat {
            switch self {
            case .patientDetails, .signature: return 120
            case .progress, .riskHarm: return 200
            default: return 150
            }
        }

        var isYesNoSection: Bool {
            switch self {
            case .s2Detention, .otherDetention: return true
            default: return false
            }
        }

        var questionText: String {
            switch self {
            case .s2Detention:
                return "15. Section 2: Is detention justified for the health or safety of the patient or the protection of others?"
            case .otherDetention:
                return "16. Other sections: Is medical treatment justified for health, safety or protection?"
            default:
                return rawValue
            }
        }
    }

    // No persistence - data only exists for current session
    init() {
        _formData = State(initialValue: NursingTribunalFormData())
        _generatedTexts = State(initialValue: [:])
        _manualNotes = State(initialValue: [:])
    }

    var body: some View {
        VStack(spacing: 0) {
            // Transparent header bar
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Text("Nursing Tribunal")
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
                        Text(error).foregroundColor(.red).font(.caption).padding(.horizontal)
                    }
                    FormValidationErrorView(errors: validationErrors).padding(.horizontal)

                    ForEach(NTRSection.allCases) { section in
                        if section.isYesNoSection {
                            TribunalYesNoCard(
                                title: section.questionText,
                                icon: section.icon,
                                color: "10B981",
                                isYes: yesNoBinding(for: section)
                            )
                        } else {
                            TribunalEditableCard(
                                title: section.rawValue,
                                icon: section.icon,
                                color: "10B981",
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
            loadFromSharedDataStore()
            prefillFromSharedData()
            initializeCardTexts()
            if !hasPopulatedFromSharedData && !sharedData.notes.isEmpty {
                populateFromClinicalNotes(sharedData.notes)
                hasPopulatedFromSharedData = true
            }
        }
        .onChange(of: formData) { _, newValue in
            sharedData.nursingTribunalFormData = newValue
        }
        .onChange(of: generatedTexts) { _, newValue in
            var dict: [String: String] = [:]
            for (section, text) in newValue {
                dict[section.rawValue] = text
            }
            sharedData.nursingTribunalGeneratedTexts = dict
        }
        .onChange(of: manualNotes) { _, newValue in
            var dict: [String: String] = [:]
            for (section, text) in newValue {
                dict[section.rawValue] = text
            }
            sharedData.nursingTribunalManualNotes = dict
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
            NTRPopupView(
                section: section,
                formData: $formData,
                onGenerate: { generatedText, notes in
                    generatedTexts[section] = generatedText
                    manualNotes[section] = notes
                    activePopup = nil
                },
                onDismiss: { activePopup = nil }
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

    private func binding(for section: NTRSection) -> Binding<String> {
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

    private func yesNoBinding(for section: NTRSection) -> Binding<Bool> {
        Binding(
            get: {
                switch section {
                case .s2Detention: return formData.s2DetentionJustified
                case .otherDetention: return formData.otherDetentionJustified
                default: return false
                }
            },
            set: { newValue in
                switch section {
                case .s2Detention: formData.s2DetentionJustified = newValue
                case .otherDetention: formData.otherDetentionJustified = newValue
                default: break
                }
            }
        )
    }

    private func loadFromSharedDataStore() {
        formData = sharedData.nursingTribunalFormData
        for (key, value) in sharedData.nursingTribunalGeneratedTexts {
            if let section = NTRSection(rawValue: key) {
                generatedTexts[section] = value
            }
        }
        for (key, value) in sharedData.nursingTribunalManualNotes {
            if let section = NTRSection(rawValue: key) {
                manualNotes[section] = value
            }
        }
    }

    private func initializeCardTexts() {
        for section in NTRSection.allCases {
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

        // Collect section content keyed by NTRSection rawValue
        var sectionContent: [String: String] = [:]
        for section in NTRSection.allCases {
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

        // Parse address from patient details
        var patientAddress = formData.currentLocation

        // Format signature date
        let sigDateFmt = DateFormatter()
        sigDateFmt.dateFormat = "dd/MM/yyyy"
        let sigDateStr = sigDateFmt.string(from: formData.signatureDate)

        // Capture form state for background thread
        let patientName = formData.patientName
        let patientDOB = formData.patientDOB
        let nurseName = formData.signatureName
        let nurseRole = formData.signatureDesignation
        let hasFactors = formData.hasFactorsAffectingHearing
        let hasAdj = formData.hasAdjustmentsNeeded
        let hasContact = formData.hasFriends || formData.hasPatientContact || formData.contactRelativesType != "None"
        let seclusionUsed = formData.seclusionUsed || formData.restraintUsed
        let s2OK = formData.s2DetentionJustified
        let otherOK = formData.otherDetentionJustified
        let hasDR = formData.dischargeRiskViolence || formData.dischargeRiskSelfHarm || formData.dischargeRiskNeglect || formData.dischargeRiskExploitation || formData.dischargeRiskRelapse || formData.dischargeRiskNonCompliance
        let hasOI = !formData.otherInfoNarrative.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasRec = formData.recMdPresent == true

        DispatchQueue.global(qos: .userInitiated).async {
            let exporter = NTRDOCXExporter(
                sectionContent: sectionContent,
                patientName: patientName,
                patientDOB: patientDOB,
                patientAddress: patientAddress,
                nurseName: nurseName,
                nurseRole: nurseRole,
                signatureDate: sigDateStr,
                hasFactors: hasFactors,
                hasAdj: hasAdj,
                hasContact: hasContact,
                seclusionUsed: seclusionUsed,
                s2OK: s2OK,
                otherOK: otherOK,
                hasDR: hasDR,
                hasOI: hasOI,
                hasRec: hasRec
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
                let filename = "NTR_Report_\(timestamp).docx"
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
            importStatusMessage = "Processing..."

            Task {
                defer { url.stopAccessingSecurityScopedResource() }
                do {
                    let tempDir = FileManager.default.temporaryDirectory
                    let tempURL = tempDir.appendingPathComponent(url.lastPathComponent)
                    try? FileManager.default.removeItem(at: tempURL)
                    try FileManager.default.copyItem(at: url, to: tempURL)
                    let extractedDoc = try await DocumentProcessor.shared.processDocument(at: tempURL)

                    await MainActor.run {
                        // Patient info (always extract regardless of report vs notes)
                        if !extractedDoc.patientInfo.fullName.isEmpty {
                            sharedData.setPatientInfo(extractedDoc.patientInfo, source: "ntr_import")
                            formData.patientName = extractedDoc.patientInfo.fullName
                            if let dob = extractedDoc.patientInfo.dateOfBirth {
                                formData.patientDOB = dob
                            }
                            formData.patientGender = extractedDoc.patientInfo.gender
                        }

                        // CRITICAL BRANCHING: Report vs Notes Detection
                        let sections = Self.isNTRReport(extractedDoc) ? parseNTRReportSections(from: extractedDoc.text) : [:]

                        if !sections.isEmpty {
                            // REPORT PATH
                            populateFromReport(sections)
                            importStatusMessage = "Imported report (\(sections.count) sections)"
                        } else {
                            // NOTES PATH
                            if !extractedDoc.notes.isEmpty {
                                sharedData.setNotes(extractedDoc.notes, source: "ntr_import")
                            }
                            populateFromClinicalNotes(extractedDoc.notes)
                            importStatusMessage = "Imported \(extractedDoc.notes.count) notes"
                        }

                        isImporting = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { importStatusMessage = nil }
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
        formData.strengthsImported.removeAll()
        formData.progressImported.removeAll()
        formData.awolImported.removeAll()
        formData.complianceImported.removeAll()
        formData.riskHarmImported.removeAll()
        formData.riskPropertyImported.removeAll()
        formData.seclusionImported.removeAll()

        // Build timeline to find admissions
        let episodes = TimelineBuilder.buildTimeline(from: notes, allNotes: notes)
        let inpatientEpisodes = episodes.filter { $0.type == .inpatient }
        let mostRecentAdmission = inpatientEpisodes.last
        let calendar = Calendar.current

        let progressKW = ["progress", "engagement", "behaviour", "behavior", "insight", "activities", "self-care"]
        let awolKW = ["awol", "absent", "leave", "failed to return", "missing"]
        let complianceKW = ["compliance", "compliant", "non-compliant", "refused", "declined", "medication"]
        let riskKW = ["assault", "attack", "violence", "aggression", "harm", "self-harm", "suicide"]
        let propertyKW = ["damage", "broke", "smashed", "property", "destroyed", "fire"]
        let seclusionKW = ["seclusion", "restraint", "restrained", "secluded", "rapid tranq"]
        let strengthsKW = ["strength", "positive", "good", "well", "engaged", "motivated"]

        for note in notes {
            let text = note.body
            let date = note.date
            let snippet = text.count > 150 ? String(text.prefix(150)) + "..." : text
            let noteDay = calendar.startOfDay(for: date)

            // Progress, Strengths, Compliance: Filter to most recent admission window (2 days before to 14 days after)
            if let recentAdmission = mostRecentAdmission {
                let windowStart = calendar.date(byAdding: .day, value: -2, to: recentAdmission.start) ?? recentAdmission.start
                let windowEnd = calendar.date(byAdding: .day, value: 14, to: recentAdmission.start) ?? recentAdmission.start

                if noteDay >= windowStart && noteDay <= windowEnd {
                    if progressKW.contains(where: { text.lowercased().contains($0) }) {
                        formData.progressImported.append(TribunalImportedEntry(date: date, text: text, snippet: snippet))
                    }
                    if strengthsKW.contains(where: { text.lowercased().contains($0) }) {
                        formData.strengthsImported.append(TribunalImportedEntry(date: date, text: text, snippet: snippet))
                    }
                    if complianceKW.contains(where: { text.lowercased().contains($0) }) {
                        formData.complianceImported.append(TribunalImportedEntry(date: date, text: text, snippet: snippet))
                    }
                }
            }

            // AWOL, Risk, Property, Seclusion: Use keyword matching across all notes (these are incident-based)
            if awolKW.contains(where: { text.lowercased().contains($0) }) {
                formData.awolImported.append(TribunalImportedEntry(date: date, text: text, snippet: snippet))
            }
            if riskKW.contains(where: { text.lowercased().contains($0) }) {
                formData.riskHarmImported.append(TribunalImportedEntry(date: date, text: text, snippet: snippet))
            }
            if propertyKW.contains(where: { text.lowercased().contains($0) }) {
                formData.riskPropertyImported.append(TribunalImportedEntry(date: date, text: text, snippet: snippet))
            }
            if seclusionKW.contains(where: { text.lowercased().contains($0) }) {
                formData.seclusionImported.append(TribunalImportedEntry(date: date, text: text, snippet: snippet))
            }
        }

        formData.progressImported.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.awolImported.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.complianceImported.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.riskHarmImported.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.riskPropertyImported.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.seclusionImported.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.strengthsImported.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }

    // MARK: - Report Detection

    private static func isNTRReport(_ document: ExtractedDocument) -> Bool {
        let text = document.text

        // Check 1: Single long note — report parsed as one block
        if document.notes.count == 1 && document.notes[0].body.count > 2000 {
            print("[NTR iOS] isNTRReport=true (single long note, \(document.notes[0].body.count) chars)")
            return true
        }

        // Check 2: Numbered question scan — regex for ^\s*(\d+)[.)] patterns in range 1-21
        let lines = text.components(separatedBy: .newlines)
        var questionNumbers = Set<Int>()
        let questionPattern = try? NSRegularExpression(pattern: #"^\s*(\d+)[\.\)]\s*"#, options: [])
        for line in lines {
            let nsLine = line as NSString
            if let match = questionPattern?.firstMatch(in: line, options: [], range: NSRange(location: 0, length: nsLine.length)) {
                let numStr = nsLine.substring(with: match.range(at: 1))
                if let num = Int(numStr), num >= 1 && num <= 21 {
                    questionNumbers.insert(num)
                }
            }
        }
        if questionNumbers.count >= 5 {
            print("[NTR iOS] isNTRReport=true (found \(questionNumbers.count) numbered questions)")
            return true
        }

        // Check 3: NTR-specific keyword fingerprints
        let textLower = text.lowercased()
        let fingerprints = [
            "nursing report",
            "nursing care",
            "observation level",
            "seclusion",
            "restraint",
            "nursing staff"
        ]
        let fingerprintMatches = fingerprints.filter { textLower.contains($0) }.count
        if fingerprintMatches >= 3 {
            print("[NTR iOS] isNTRReport=true (matched \(fingerprintMatches) keyword fingerprints)")
            return true
        }

        // Check 4: No notes but substantial text with some NTR indicators
        if document.notes.isEmpty && text.count > 500 {
            if questionNumbers.count >= 2 || fingerprintMatches >= 1 {
                print("[NTR iOS] isNTRReport=true (no notes, \(text.count) chars)")
                return true
            }
        }

        print("[NTR iOS] isNTRReport=false")
        return false
    }

    // MARK: - Report Parsing

    /// Parse NTR report text into sections using question text fragments as boundaries.
    /// DocumentProcessor.extractPlainTextFromXML produces ONE LONG LINE with no paragraph breaks,
    /// so we find section boundaries by searching for known question text fragments inline.
    private func parseNTRReportSections(from text: String) -> [NTRSection: String] {
        var result: [NTRSection: String] = [:]

        // Normalize curly quotes for searching
        let normalized = text
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")
        let lower = normalized.lowercased()

        // Section boundary markers — unique question text fragments near the START of each question.
        // Ordered by section number. Searched in the lowercased, quote-normalized text.
        let markers: [(section: NTRSection, num: Int, fragments: [String])] = [
            (.patientDetails, 1, ["patient details"]),
            (.factorsHearing, 2, [
                "are there are any factors that may affect the patient",
                "are there any factors that may affect the patient"
            ]),
            (.adjustments, 3, [
                "are there are any adjustments that the tribunal",
                "are there any adjustments that the tribunal",
                "are there are any adjustments that the panel",
                "are there any adjustments that the panel"
            ]),
            (.nursingCare, 4, [
                "what is the nature of nursing care"
            ]),
            (.observationLevel, 5, [
                "to what level of observation"
            ]),
            (.contact, 6, [
                "does the patient have contact with relatives"
            ]),
            (.communitySupport, 7, [
                "what community support does the patient",
                "what community support services are"
            ]),
            (.strengths, 8, [
                "what are the strengths or positive factors"
            ]),
            (.progress, 9, [
                "give a summary of the patient's current progress"
            ]),
            (.awol, 10, [
                "details of any occasions on which the patient has been absent",
                "absent without leave"
            ]),
            (.compliance, 11, [
                "what is the patient's understanding of, compliance"
            ]),
            (.riskHarm, 12, [
                "give details of any incidents in hospital where the patient has harmed",
                "give details of any incidents where the patient has harmed"
            ]),
            (.riskProperty, 13, [
                "give details of any incidents where the patient has damaged"
            ]),
            (.seclusion, 14, [
                "have there been any occasions on which the patient has been secluded"
            ]),
            (.s2Detention, 15, [
                "in section 2 cases is detention in hospital",
                "in section 2 cases, is detention in hospital"
            ]),
            (.otherDetention, 16, [
                "in all other cases is the provision of medical treatment",
                "in all other cases, is the provision of medical treatment"
            ]),
            (.dischargeRisk, 17, [
                "if the patient was discharged from hospital",
                "if the patient were discharged from hospital"
            ]),
            (.communityManagement, 18, [
                "please explain how risks could be managed"
            ]),
            (.otherInfo, 19, [
                "is there any other relevant information",
                "is there any other information you wish"
            ]),
            (.recommendations, 20, [
                "do you have any recommendations to the tribunal",
                "do you have any recommendations to the panel"
            ]),
        ]

        // Find position of each section marker in the text
        struct BoundaryHit {
            let section: NTRSection
            let num: Int
            let position: Int
        }

        var hits: [BoundaryHit] = []

        for marker in markers {
            for fragment in marker.fragments {
                if let range = lower.range(of: fragment) {
                    var sectionStart = lower.distance(from: lower.startIndex, to: range.lowerBound)

                    // Look backward for a number prefix like "3. " or "10. "
                    let lookback = min(sectionStart, 30)
                    if lookback > 0 {
                        let lbStart = text.index(text.startIndex, offsetBy: sectionStart - lookback)
                        let lbEnd = text.index(text.startIndex, offsetBy: sectionStart)
                        let before = String(text[lbStart..<lbEnd])
                        if let numRegex = try? NSRegularExpression(pattern: #"\b(\d{1,2})\.\s*$"#) {
                            let nsBefore = before as NSString
                            if let numMatch = numRegex.firstMatch(in: before, range: NSRange(location: 0, length: nsBefore.length)) {
                                let matchedNum = Int(nsBefore.substring(with: numMatch.range(at: 1))) ?? 0
                                if matchedNum == marker.num {
                                    sectionStart = sectionStart - lookback + numMatch.range.location
                                }
                            }
                        }
                    }

                    hits.append(BoundaryHit(section: marker.section, num: marker.num, position: sectionStart))
                    break
                }
            }
        }

        // Sort by position and remove duplicate sections (keep first occurrence)
        hits.sort { $0.position < $1.position }
        var seen = Set<Int>()
        hits = hits.filter { h in
            if seen.contains(h.num) { return false }
            seen.insert(h.num)
            return true
        }

        // Extract content between consecutive boundaries
        for i in 0..<hits.count {
            let startPos = hits[i].position
            let endPos = i + 1 < hits.count ? hits[i + 1].position : text.count
            guard startPos < endPos else { continue }

            let startIdx = text.index(text.startIndex, offsetBy: startPos)
            let endIdx = text.index(text.startIndex, offsetBy: min(endPos, text.count))
            let rawContent = String(text[startIdx..<endIdx]).trimmingCharacters(in: .whitespacesAndNewlines)

            let cleaned = cleanNTRSectionText(rawContent)
            if !cleaned.isEmpty {
                result[hits[i].section] = cleaned
            }
        }

        NSLog("[NTR iOS] Parsed %d report sections: %@", result.count, result.keys.map { $0.rawValue }.sorted().description)
        return result
    }

    /// Clean NTR section text by stripping number prefix, question text, checkbox markers,
    /// sub-question text, and instruction text. Handles inline (one-line) text from extractPlainTextFromXML.
    /// For Yes/No sections, detects the checked checkbox state and prepends "Yes\n" or "No\n".
    private func cleanNTRSectionText(_ text: String) -> String {
        var working = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if working.isEmpty { return "" }

        // 1. Strip leading number prefix: "3. " or "10. "
        if let numRegex = try? NSRegularExpression(pattern: #"^\d{1,2}\.\s*"#) {
            let ns = working as NSString
            if let m = numRegex.firstMatch(in: working, range: NSRange(location: 0, length: ns.length)) {
                working = ns.substring(from: m.range.upperBound).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // 2. Detect Yes/No answer from checked checkbox BEFORE stripping.
        //    Handles both Unicode (☒ Yes) and text-based ([X] Yes, [x] Yes) checkboxes.
        var detectedAnswer: String? = nil
        // Unicode checkbox detection
        if let ynRegex = try? NSRegularExpression(pattern: #"[☒☑✓]\s*(Yes|No)"#, options: .caseInsensitive) {
            if let m = ynRegex.firstMatch(in: working, range: NSRange(location: 0, length: (working as NSString).length)) {
                let ans = (working as NSString).substring(with: m.range(at: 1))
                detectedAnswer = ans.lowercased().hasPrefix("y") ? "Yes" : "No"
            }
        }
        // Text-based checkbox detection: "[X] Yes", "[x] Yes", "[ ] No" etc.
        if detectedAnswer == nil {
            // Pattern: checked box before or after Yes/No word
            if let tbRegex = try? NSRegularExpression(pattern: #"\[\s*[Xx]\s*\]\s*(Yes|No)"#, options: .caseInsensitive) {
                if let m = tbRegex.firstMatch(in: working, range: NSRange(location: 0, length: (working as NSString).length)) {
                    let ans = (working as NSString).substring(with: m.range(at: 1))
                    detectedAnswer = ans.lowercased().hasPrefix("y") ? "Yes" : "No"
                }
            }
        }
        if detectedAnswer == nil {
            if let tbRegex2 = try? NSRegularExpression(pattern: #"(Yes|No)\s*\[\s*[Xx]\s*\]"#, options: .caseInsensitive) {
                if let m = tbRegex2.firstMatch(in: working, range: NSRange(location: 0, length: (working as NSString).length)) {
                    let ans = (working as NSString).substring(with: m.range(at: 1))
                    detectedAnswer = ans.lowercased().hasPrefix("y") ? "Yes" : "No"
                }
            }
        }

        // 3. Strip all checkbox+word pairs inline — both Unicode and text-based.
        //    Unicode: "☐ No", "☒ Yes", etc.
        if let cbRegex = try? NSRegularExpression(pattern: #"[☐☑☒✓✗□■]\s*(?:Yes|No|N/?A)\s*"#, options: .caseInsensitive) {
            working = cbRegex.stringByReplacingMatches(in: working, range: NSRange(location: 0, length: (working as NSString).length), withTemplate: " ")
        }
        for ch in ["☐", "☑", "☒", "✓", "✗", "□", "■"] {
            working = working.replacingOccurrences(of: ch, with: " ")
        }
        //    Text-based: "[X] Yes", "[ ] No", "Yes [X]", "No [ ]", standalone "[ ]", "[X]"
        if let tbCbRegex = try? NSRegularExpression(pattern: #"\[\s*[Xx]?\s*\]\s*(?:Yes|No|N/?A)?\s*"#, options: .caseInsensitive) {
            working = tbCbRegex.stringByReplacingMatches(in: working, range: NSRange(location: 0, length: (working as NSString).length), withTemplate: " ")
        }
        if let tbCbRegex2 = try? NSRegularExpression(pattern: #"(?:Yes|No|N/?A)\s*\[\s*[Xx]?\s*\]\s*"#, options: .caseInsensitive) {
            working = tbCbRegex2.stringByReplacingMatches(in: working, range: NSRange(location: 0, length: (working as NSString).length), withTemplate: " ")
        }
        working = working.replacingOccurrences(of: "  +", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)

        // 4. Strip known question titles from the start (loop to handle stacked questions/sub-questions)
        let normalizeQ: (String) -> String = {
            $0.replacingOccurrences(of: "\u{2019}", with: "'")
              .replacingOccurrences(of: "\u{2018}", with: "'")
              .replacingOccurrences(of: "\u{201C}", with: "\"")
              .replacingOccurrences(of: "\u{201D}", with: "\"")
        }

        // T134 template question texts — longest first, all lowercased
        let knownTitles: [String] = [
            "in section 2 cases is detention in hospital justified or necessary in the interests of the patient's health or safety, or for the protection of others",
            "in section 2 cases, is detention in hospital justified or necessary in the interests of the patient's health or safety, or for the protection of others",
            "in all other cases is the provision of medical treatment in hospital, justified or necessary in the interests of the patient's health or safety, or for the protection of others",
            "in all other cases, is the provision of medical treatment in hospital justified or necessary in the interests of the patient's health or safety, or for the protection of others",
            "in all other cases, is the provision of medical treatment in hospital, justified or necessary in the interests of the patient's health or safety, or for the protection of others",
            "details of any occasions on which the patient has been absent without leave whilst liable to be detained, or occasions when the patient has failed to return when required after having been granted leave",
            "what is the patient's understanding of, compliance with, and likely future willingness to accept any prescribed medication or treatment for mental disorder that is or might be made available",
            "give a summary of the patient's current progress, engagement with nursing staff, behaviour, cooperation, activities, self-care and insight",
            "give a summary of the patient's current progress, engagement with nursing staff, behaviour, co-operation, activities, self-care and insight",
            "if the patient was discharged from hospital, would they be likely to act in a manner dangerous to themselves or others",
            "if the patient were discharged from hospital, would they be likely to act in a manner dangerous to themselves or others",
            "please explain how risks could be managed effectively in the community, including the use of any lawful conditions or recall powers",
            "please provide your recommendations and the reasons for them, in the box below",
            "please provide your recommendations and the reasons for them",
            "give details of any incidents in hospital where the patient has harmed themselves or others or threatened harm to others",
            "give details of any incidents in hospital where the patient has harmed themselves or others, or threatened harm to others",
            "give details of any incidents where the patient has harmed themselves or others or threatened harm to others",
            "give details of any incidents where the patient has harmed themselves or others, or threatened harm to others",
            "give details of any incidents where the patient has harmed themselves or others",
            "please explain why was that seclusion or restraint was necessary",
            "please explain why that seclusion or restraint was necessary",
            "please explain why it was that seclusion or restraint was necessary",
            "are there are any factors that may affect the patient's understanding or ability to cope with a hearing",
            "are there any factors that may affect the patient's understanding or ability to cope with a hearing",
            "are there are any adjustments that the tribunal may consider in order to deal with the case fairly and justly",
            "are there any adjustments that the tribunal may consider in order to deal with the case fairly and justly",
            "are there are any adjustments that the panel may consider in order to deal with the case fairly and justly",
            "are there any adjustments that the panel may consider in order to deal with the case fairly and justly",
            "give details of any incidents where the patient has damaged property, or threatened to damage property",
            "give details of any incidents where the patient has damaged property",
            "what is the nature of nursing care and medication currently being made available to the patient",
            "have there been any occasions on which the patient has been secluded or restrained",
            "is there any other relevant information that the tribunal should know",
            "is there any other relevant information that the panel should know",
            "is there any other information you wish to draw to the tribunal's attention",
            "is there any other information you wish to draw to the panel's attention",
            "what are the strengths or positive factors relating to the patient",
            "does the patient have contact with relatives, friends or other patients",
            "what is the nature of that interaction",
            "what community support does the patient have",
            "what community support services are, or would be, available to the patient",
            "do you have any recommendations to the tribunal",
            "do you have any recommendations to the panel",
            "to what level of observation is the patient currently subject",
            "yes - what are they",
            "yes \u{2013} what are they",
            "yes, give details below",
            "yes give details below",
            "if yes, what are they",
            "if yes what are they",
            "if yes, give details",
            "if yes give details",
            "give details below",
            "what are they",
            "note: this report must be up-to-date and specifically prepared for the tribunal",
            "note: this report must be up-to-date and specifically prepared for the panel",
            "patient details",
            "signature",
        ]

        var didStrip = true
        while didStrip {
            didStrip = false

            // 4a. Strip "Yes -" / "No -" / "Yes," / "Yes –" prefixes each iteration,
            //     so sub-question titles like "If yes, what are they?" become strippable.
            if let ynPre = try? NSRegularExpression(pattern: #"^\s*(?:Yes|No)\s*[-–—:,]\s*"#, options: .caseInsensitive) {
                let ns = working as NSString
                if let m = ynPre.firstMatch(in: working, range: NSRange(location: 0, length: ns.length)) {
                    working = ns.substring(from: m.range.upperBound).trimmingCharacters(in: .whitespacesAndNewlines)
                    didStrip = true
                }
            }

            let wNorm = normalizeQ(working)
            let wLower = wNorm.lowercased()
            let wCollapsed = wLower.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)

            for title in knownTitles {
                let tCollapsed = title.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

                guard wCollapsed.hasPrefix(tCollapsed) else { continue }

                // Walk through original working to find where title ends (handles extra spaces)
                let wArr = Array(wLower)
                let tArr = Array(tCollapsed)
                var wi = 0, ti = 0
                while wi < wArr.count && ti < tArr.count {
                    if wArr[wi] == tArr[ti] {
                        wi += 1; ti += 1
                    } else if wArr[wi].isWhitespace && tArr[ti] == " " {
                        while wi < wArr.count && wArr[wi].isWhitespace { wi += 1 }
                        ti += 1
                    } else if wArr[wi].isWhitespace {
                        wi += 1
                    } else {
                        break
                    }
                }

                guard ti >= tArr.count else { continue }

                working = String(working.dropFirst(wi)).trimmingCharacters(in: .whitespacesAndNewlines)
                // Strip trailing punctuation after title
                while let first = working.first, "?:.,)-\u{2013}\u{2014}".contains(first) || first == "-" {
                    working = String(working.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                // Strip short parentheticals like "(if applicable, specify ICD-10 code)"
                if working.hasPrefix("("), let ci = working.firstIndex(of: ")") {
                    if working.distance(from: working.startIndex, to: ci) <= 100 {
                        working = String(working[working.index(after: ci)...]).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
                didStrip = true
                break
            }
        }

        // 5a. Catch residual "Yes/No – If yes, what are they?" and similar sub-question prefixes
        //     that survive the title-stripping loop (e.g. from text-based checkbox formats).
        //     Also handles "No Yes –" where both checkbox labels survive stripping.
        if let residual = try? NSRegularExpression(
            pattern: #"^(?:(?:Yes|No)\s*){1,2}[-–—]?\s*(?:If\s+(?:yes|no)\s*[,:]?\s*)?(?:what are they|give details(?:\s+below)?|please (?:give|provide|explain)\b[^.?:]*)\s*[?:.]?\s*"#,
            options: .caseInsensitive
        ) {
            let ns = working as NSString
            if let m = residual.firstMatch(in: working, range: NSRange(location: 0, length: ns.length)) {
                let stripped = ns.substring(from: m.range.upperBound).trimmingCharacters(in: .whitespacesAndNewlines)
                if !stripped.isEmpty {
                    // Preserve Yes/No for detectedAnswer if not already set
                    if detectedAnswer == nil {
                        let prefix = ns.substring(with: NSRange(location: 0, length: min(3, ns.length))).lowercased()
                        detectedAnswer = prefix.hasPrefix("yes") ? "Yes" : prefix.hasPrefix("no") ? "No" : nil
                    }
                    working = stripped
                }
            }
        }

        // 6. Strip instruction text
        let iLower = working.lowercased()
        if iLower.hasPrefix("you should also") || iLower.hasPrefix("please also") {
            if let di = working.firstIndex(of: ".") {
                if working.distance(from: working.startIndex, to: di) <= 200 {
                    working = String(working[working.index(after: di)...]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }

        // 7. Skip trivial content
        let finalLower = working.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if finalLower == "see above" || finalLower == "as above" || finalLower == "refer to above" ||
           finalLower == "as per above" || finalLower == "n/a" || finalLower == "na" || finalLower == "nil" {
            working = ""
        }

        working = working.trimmingCharacters(in: .whitespacesAndNewlines)

        // 8. For Yes/No sections: prepend detected answer so parseYesNo/stripYesNoPrefix can handle it
        if let answer = detectedAnswer {
            if working.isEmpty { return answer }
            return "\(answer)\n\(working)"
        }

        NSLog("[NTR clean] result (%d chars): %@", working.count, String(working.prefix(120)))
        return working
    }

    // MARK: - Report Population

    private func populateFromReport(_ sections: [NTRSection: String]) {
        // Clear existing imported entries
        formData.strengthsImported.removeAll()
        formData.progressImported.removeAll()
        formData.awolImported.removeAll()
        formData.complianceImported.removeAll()
        formData.riskHarmImported.removeAll()
        formData.riskPropertyImported.removeAll()
        formData.seclusionImported.removeAll()
        formData.nursingCareImported.removeAll()
        formData.observationImported.removeAll()
        formData.contactImported.removeAll()
        formData.communitySupportImported.removeAll()
        formData.communityImported.removeAll()
        formData.recommendationsImported.removeAll()

        func makeEntry(_ text: String) -> TribunalImportedEntry {
            TribunalImportedEntry(date: nil, text: text, snippet: String(text.prefix(200)), selected: false, categories: ["Report"])
        }

        // Section 1: Patient Details — parse inline text using keyword boundaries.
        // The flat text from extractPlainTextFromXML merges table rows into one line, e.g.:
        //   "Name of Patient Jane Doe Date of Birth 15/03/1990 Gender Female NHS Number 123 456 7890 ..."
        // cleanNTRSectionText may strip "patient details" / "full name" prefixes, so we match
        // both the standard T134 table labels AND the short-form labels.
        if let text = sections[.patientDetails], !text.isEmpty {
            let lower = text.lowercased()
            // All known field label variants, mapped to canonical field names.
            // Order matters: longer/more-specific labels before shorter ones to avoid partial matches.
            let fieldKeys: [(key: String, field: String)] = [
                ("name of patient", "name"),
                ("full name", "name"),
                ("patient name", "name"),
                ("date of birth", "dob"),
                ("d.o.b", "dob"),
                ("dob", "dob"),
                ("gender", "gender"),
                ("sex", "gender"),
                ("nhs number", "nhs"),
                ("nhs no", "nhs"),
                ("hospital number", "hospital_number"),
                ("hosp number", "hospital_number"),
                ("hosp no", "hospital_number"),
                ("mental health act status", "mha"),
                ("mha status", "mha"),
                ("section", "mha"),
                ("usual place of residence", "address"),
                ("current location", "address"),
                ("address", "address"),
                ("date of admission", "admission_date"),
                ("admission date", "admission_date"),
            ]
            // Find positions — for each canonical field, keep only the first (earliest) match
            struct FieldHit { let field: String; let keyStart: Int; let valueStart: Int }
            var fieldHits: [FieldHit] = []
            var seenFields = Set<String>()
            for fk in fieldKeys {
                guard !seenFields.contains(fk.field) else { continue }
                if let range = lower.range(of: fk.key) {
                    let ks = lower.distance(from: lower.startIndex, to: range.lowerBound)
                    let vs = lower.distance(from: lower.startIndex, to: range.upperBound)
                    fieldHits.append(FieldHit(field: fk.field, keyStart: ks, valueStart: vs))
                    seenFields.insert(fk.field)
                }
            }
            fieldHits.sort { $0.keyStart < $1.keyStart }
            // Extract value between consecutive keyword positions
            for i in 0..<fieldHits.count {
                let vs = fieldHits[i].valueStart
                let ve = i + 1 < fieldHits.count ? fieldHits[i + 1].keyStart : text.count
                guard vs < ve else { continue }
                let sIdx = text.index(text.startIndex, offsetBy: vs)
                let eIdx = text.index(text.startIndex, offsetBy: ve)
                let value = String(text[sIdx..<eIdx]).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !value.isEmpty else { continue }
                switch fieldHits[i].field {
                case "name":
                    // Always overwrite — report section data is more reliable than generic extraction
                    formData.patientName = value
                case "dob":
                    if formData.patientDOB == nil {
                        // Handle individual-digit DOB from scanned PDFs: "0 3 0 5 1 9 6 9" → "03051969"
                        let digitsOnly = value.filter { $0.isNumber }
                        var dobCandidates = [value]
                        // Strip ordinals: "18th July 1991" → "18 July 1991"
                        let stripped = value.replacingOccurrences(
                            of: #"(\d{1,2})(st|nd|rd|th)\b"#, with: "$1", options: .regularExpression)
                        if stripped != value { dobCandidates.append(stripped) }
                        // If we got exactly 8 digits, reformat as dd/MM/yyyy
                        if digitsOnly.count == 8 {
                            let idx2 = digitsOnly.index(digitsOnly.startIndex, offsetBy: 2)
                            let idx4 = digitsOnly.index(digitsOnly.startIndex, offsetBy: 4)
                            let reformatted = "\(digitsOnly[..<idx2])/\(digitsOnly[idx2..<idx4])/\(digitsOnly[idx4...])"
                            dobCandidates.insert(reformatted, at: 0)
                        }
                        let fmts = ["dd/MM/yyyy", "dd-MM-yyyy", "dd.MM.yyyy", "d/M/yyyy",
                                    "d MMMM yyyy", "d MMMM, yyyy", "d MMM yyyy", "d MMM, yyyy",
                                    "ddMMyyyy", "MMMM d, yyyy", "MMM d, yyyy"]
                        outer: for candidate in dobCandidates {
                            let trimmed = candidate.trimmingCharacters(in: CharacterSet(charactersIn: " ,"))
                            for fmt in fmts {
                                let df = DateFormatter()
                                df.dateFormat = fmt
                                df.locale = Locale(identifier: "en_GB")
                                if let d = df.date(from: trimmed) { formData.patientDOB = d; break outer }
                            }
                        }
                    }
                case "gender":
                    if formData.patientGender == .male {
                        let g = value.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                        if g.hasPrefix("f") { formData.patientGender = .female }
                        else if g.hasPrefix("m") { formData.patientGender = .male }
                    }
                case "nhs":
                    if formData.nhsNumber.isEmpty {
                        // Normalize: strip spaces/dashes, then reformat as "123 456 7890"
                        let digits = value.filter { $0.isNumber }
                        if digits.count == 10 {
                            let idx3 = digits.index(digits.startIndex, offsetBy: 3)
                            let idx6 = digits.index(digits.startIndex, offsetBy: 6)
                            formData.nhsNumber = "\(digits[..<idx3]) \(digits[idx3..<idx6]) \(digits[idx6...])"
                        } else if !digits.isEmpty {
                            formData.nhsNumber = value.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    }
                case "hospital_number":
                    if formData.hospitalNumber.isEmpty { formData.hospitalNumber = value }
                case "mha":
                    if formData.mhaSection.isEmpty || formData.mhaSection == "Section 3" {
                        formData.mhaSection = value
                    }
                case "address":
                    if formData.currentLocation.isEmpty { formData.currentLocation = value }
                case "admission_date":
                    if formData.admissionDate == nil {
                        let stripped = value.replacingOccurrences(
                            of: #"(\d{1,2})(st|nd|rd|th)\b"#, with: "$1", options: .regularExpression)
                        let candidates = value == stripped ? [value] : [value, stripped]
                        let fmts = ["dd/MM/yyyy", "dd-MM-yyyy", "dd.MM.yyyy", "d/M/yyyy",
                                    "d MMMM yyyy", "d MMM yyyy"]
                        outer2: for candidate in candidates {
                            let trimmed = candidate.trimmingCharacters(in: CharacterSet(charactersIn: " ,"))
                            for fmt in fmts {
                                let df = DateFormatter()
                                df.dateFormat = fmt
                                df.locale = Locale(identifier: "en_GB")
                                if let d = df.date(from: trimmed) { formData.admissionDate = d; break outer2 }
                            }
                        }
                    }
                default: break
                }
            }
            NSLog("[NTR iOS] Section 1 parsed: name='%@' dob=%@ gender=%@ nhs='%@' hosp='%@' addr='%@'",
                  formData.patientName, formData.patientDOB?.description ?? "nil",
                  formData.patientGender.rawValue, formData.nhsNumber,
                  formData.hospitalNumber, formData.currentLocation)
        }

        // Section 2: Factors affecting hearing (Yes/No + details + factor radio)
        if let text = sections[.factorsHearing], !text.isEmpty {
            let answer = parseYesNo(text)
            formData.hasFactorsAffectingHearing = (answer == true)
            let detail = stripYesNoPrefix(text)
            if !detail.isEmpty {
                formData.factorsDetails = detail
                // Auto-detect specific factor from content (matching desktop behaviour)
                let detailLower = detail.lowercased()
                if detailLower.contains("autism") || detailLower.contains("autistic") {
                    formData.selectedFactor = "Autism"
                } else if detailLower.contains("learning disabilit") || detailLower.contains("learning difficult") {
                    formData.selectedFactor = "Learning Disability"
                } else if detailLower.contains("irritab") || detailLower.contains("frustration") || detailLower.contains("patience") {
                    formData.selectedFactor = "Low frustration tolerance"
                }
            }
        }

        // Section 3: Adjustments needed (Yes/No + details)
        if let text = sections[.adjustments], !text.isEmpty {
            let answer = parseYesNo(text)
            formData.hasAdjustmentsNeeded = (answer == true)
            let detail = stripYesNoPrefix(text)
            if !detail.isEmpty { formData.adjustmentsOther = detail }
        }

        // Section 4: Nursing Care → imported array
        if let text = sections[.nursingCare], !text.isEmpty {
            formData.nursingCareImported.append(makeEntry(text))
        }

        // Section 5: Observation Level → imported array
        if let text = sections[.observationLevel], !text.isEmpty {
            formData.observationImported.append(makeEntry(text))
        }

        // Section 6: Contact → imported array
        if let text = sections[.contact], !text.isEmpty {
            formData.contactImported.append(makeEntry(text))
        }

        // Section 7: Community Support → imported array
        if let text = sections[.communitySupport], !text.isEmpty {
            formData.communitySupportImported.append(makeEntry(text))
        }

        // Section 8: Strengths → imported array
        if let text = sections[.strengths], !text.isEmpty {
            formData.strengthsImported.append(makeEntry(text))
        }

        // Section 9: Progress → imported array
        if let text = sections[.progress], !text.isEmpty {
            formData.progressImported.append(makeEntry(text))
        }

        // Section 10: AWOL → imported array
        if let text = sections[.awol], !text.isEmpty {
            formData.awolImported.append(makeEntry(text))
        }

        // Section 11: Compliance → imported array
        if let text = sections[.compliance], !text.isEmpty {
            formData.complianceImported.append(makeEntry(text))
        }

        // Section 12: Risk Harm → imported array
        if let text = sections[.riskHarm], !text.isEmpty {
            formData.riskHarmImported.append(makeEntry(text))
        }

        // Section 13: Risk Property → imported array
        if let text = sections[.riskProperty], !text.isEmpty {
            formData.riskPropertyImported.append(makeEntry(text))
        }

        // Section 14: Seclusion (Yes/No + details + imported array)
        if let text = sections[.seclusion], !text.isEmpty {
            let answer = parseYesNo(text)
            if answer == true { formData.seclusionUsed = true }
            let detail = stripYesNoPrefix(text)
            if !detail.isEmpty {
                formData.seclusionDetails = detail
                formData.seclusionImported.append(makeEntry(detail))
            }
        }

        // Section 15: S2 Detention (Yes/No) — matches PTR Section 19
        if let text = sections[.s2Detention], !text.isEmpty {
            let answer = parseYesNo(text)
            formData.s2DetentionJustified = (answer ?? true)
            let detail = stripYesNoPrefix(text)
                .replacingOccurrences(of: #"^\s*N\s*/?\s*A\s*$"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !detail.isEmpty { formData.s2Explanation = detail }
        }

        // Section 16: Other Detention (Yes/No) — matches PTR Section 20
        if let text = sections[.otherDetention], !text.isEmpty {
            let answer = parseYesNo(text)
            formData.otherDetentionJustified = (answer ?? true)
            let detail = stripYesNoPrefix(text)
                .replacingOccurrences(of: #"^\s*N\s*/?\s*A\s*$"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !detail.isEmpty { formData.otherDetentionExplanation = detail }
        }

        // Section 17: Discharge Risk — populate details + auto-set risk toggles from keywords
        if let text = sections[.dischargeRisk], !text.isEmpty {
            let detail = stripYesNoPrefix(text)
            formData.dischargeRiskDetails = detail.isEmpty ? text : detail
            let lower = text.lowercased()
            if lower.contains("violence") { formData.dischargeRiskViolence = true }
            if lower.contains("self-harm") || lower.contains("suicide") { formData.dischargeRiskSelfHarm = true }
            if lower.contains("neglect") { formData.dischargeRiskNeglect = true }
            if lower.contains("exploitation") { formData.dischargeRiskExploitation = true }
            if lower.contains("relapse") { formData.dischargeRiskRelapse = true }
            if lower.contains("compliance") || lower.contains("non-compliance") { formData.dischargeRiskNonCompliance = true }
        }

        // Section 18: Community Management → imported array
        if let text = sections[.communityManagement], !text.isEmpty {
            formData.communityImported.append(makeEntry(text))
        }

        // Section 19: Other Info → narrative (strip Yes/No prefix from detected checkbox)
        if let text = sections[.otherInfo], !text.isEmpty {
            let detail = stripYesNoPrefix(text)
            formData.otherInfoNarrative = detail.isEmpty ? text : detail
        }

        // Section 20: Recommendations → imported array
        if let text = sections[.recommendations], !text.isEmpty {
            formData.recommendationsImported.append(makeEntry(text))
        }

        print("[NTR iOS] populateFromReport complete: \(sections.count) sections mapped")
    }

    // MARK: - Yes/No Helpers

    private func parseYesNo(_ text: String) -> Bool? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed == "1" || trimmed.hasPrefix("1\n") { return true }
        if trimmed == "2" || trimmed.hasPrefix("2\n") { return false }
        if trimmed == "3" || trimmed.hasPrefix("3\n") { return nil }
        if trimmed.hasPrefix("yes") { return true }
        if trimmed.hasPrefix("no") { return false }
        if trimmed.hasPrefix("n/a") || trimmed.hasPrefix("na") { return nil }
        return nil
    }

    private func stripYesNoPrefix(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
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
}

// MARK: - NTR Popup View
struct NTRPopupView: View {
    let section: NursingTribunalReportView.NTRSection
    @Binding var formData: NursingTribunalFormData
    let onGenerate: (String, String) -> Void
    let onDismiss: () -> Void

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
        case .factorsHearing: factorsHearingPopup
        case .adjustments: adjustmentsPopup
        case .nursingCare: nursingCarePopup
        case .observationLevel: observationLevelPopup
        case .contact: contactPopup
        case .communitySupport: communitySupportPopup
        case .strengths: strengthsPopup
        case .progress: progressPopup
        case .awol: awolPopup
        case .compliance: compliancePopup
        case .riskHarm: riskHarmPopup
        case .riskProperty: riskPropertyPopup
        case .seclusion: seclusionPopup
        case .s2Detention: EmptyView()
        case .otherDetention: EmptyView()
        case .dischargeRisk: dischargeRiskPopup
        case .communityManagement: communityManagementPopup
        case .otherInfo: otherInfoPopup
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
                }
                .pickerStyle(.menu)
            }
            FormOptionalDatePicker(label: "Admission Date", date: $formData.admissionDate)
        }
    }

    // MARK: - Section 2: Factors Affecting Hearing
    private var factorsHearingPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Are there any factors that may affect the patient's understanding or ability to cope with a hearing?")
                .font(.subheadline).foregroundColor(.secondary)

            // Yes/No Radio
            TribunalYesNoRadio(selection: $formData.hasFactorsAffectingHearing)

            if formData.hasFactorsAffectingHearing {
                Divider()

                // Single selection radio - matching desktop
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

    // MARK: - Section 3: Adjustments
    private var adjustmentsPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Are there any adjustments that the tribunal may consider in order to deal with the case fairly and justly?")
                .font(.subheadline).foregroundColor(.secondary)

            // Yes/No Radio
            TribunalYesNoRadio(selection: $formData.hasAdjustmentsNeeded)

            if formData.hasAdjustmentsNeeded {
                Divider()

                // Single selection radio - matching desktop
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

    // MARK: - Section 4: Nursing Care
    private var nursingCarePopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Nature of Nursing Care and Medication").font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text("Level of Care").font(.subheadline).foregroundColor(.secondary)
                Picker("", selection: $formData.nursingCareLevel) {
                    Text("General inpatient").tag("General inpatient")
                    Text("Enhanced observation").tag("Enhanced observation")
                    Text("1:1 nursing").tag("1:1 nursing")
                    Text("2:1 nursing").tag("2:1 nursing")
                    Text("Specialised care").tag("Specialised care")
                    Text("Rehabilitation").tag("Rehabilitation")
                }
                .pickerStyle(.menu)
            }

            TribunalCollapsibleSection(title: "Current Medications", color: .green) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(formData.medications.indices, id: \.self) { index in
                        TribunalMedicationRowView(
                            entry: $formData.medications[index],
                            onDelete: { formData.medications.remove(at: index) }
                        )
                    }
                    Button {
                        formData.medications.append(TribunalMedicationEntry())
                    } label: {
                        Label("Add Medication", systemImage: "plus.circle").font(.caption)
                    }
                }
            }
            if !formData.nursingCareImported.isEmpty {
                TribunalCollapsibleSection(title: "Imported Notes (\(formData.nursingCareImported.count))", color: .yellow) {
                    TribunalImportedEntriesList(entries: $formData.nursingCareImported)
                }
            }
        }
    }

    // MARK: - Section 5: Observation Level
    private var observationLevelPopup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Level of Observation").font(.headline)
            VStack(alignment: .leading, spacing: 4) {
                Text("Observation Level").font(.subheadline).foregroundColor(.secondary)
                Picker("", selection: $formData.observationLevel) {
                    Text("General").tag("General")
                    Text("Intermittent (15-30 min)").tag("Intermittent (15-30 min)")
                    Text("Continuous").tag("Continuous")
                    Text("Arm's length").tag("Arm's length")
                    Text("2:1").tag("2:1")
                    Text("Other").tag("Other")
                }
                .pickerStyle(.menu)
            }
            FormTextEditor(label: "Details", text: $formData.observationDetails, minHeight: 60)
            if !formData.observationImported.isEmpty {
                TribunalCollapsibleSection(title: "Imported Notes (\(formData.observationImported.count))", color: .yellow) {
                    TribunalImportedEntriesList(entries: $formData.observationImported)
                }
            }
        }
    }

    // MARK: - Section 6: Contact
    private var contactPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Contact with Relatives, Friends or Other Patients").font(.headline)

            TribunalCollapsibleSection(title: "Relatives", color: .blue) {
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Contact Type").font(.subheadline).foregroundColor(.secondary)
                        Picker("", selection: $formData.contactRelativesType) {
                            Text("Regular").tag("Regular")
                            Text("Occasional").tag("Occasional")
                            Text("Rare").tag("Rare")
                            Text("None").tag("None")
                        }
                        .pickerStyle(.segmented)
                    }
                    HStack {
                        Text("Contact Level: \(formData.contactRelativesLevel)").font(.caption)
                        Slider(value: Binding(
                            get: { Double(formData.contactRelativesLevel) },
                            set: { formData.contactRelativesLevel = Int($0) }
                        ), in: 0...5, step: 1)
                    }
                }
            }

            TribunalCollapsibleSection(title: "Friends", color: .blue) {
                Toggle("Has friends contact", isOn: $formData.hasFriends)
                if formData.hasFriends {
                    HStack {
                        Text("Contact Level: \(formData.contactFriendsLevel)").font(.caption)
                        Slider(value: Binding(
                            get: { Double(formData.contactFriendsLevel) },
                            set: { formData.contactFriendsLevel = Int($0) }
                        ), in: 0...5, step: 1)
                    }
                }
            }

            TribunalCollapsibleSection(title: "Other Patients", color: .blue) {
                Toggle("Has patient contact", isOn: $formData.hasPatientContact)
                if formData.hasPatientContact {
                    HStack {
                        Text("Contact Level: \(formData.contactPatientsLevel)").font(.caption)
                        Slider(value: Binding(
                            get: { Double(formData.contactPatientsLevel) },
                            set: { formData.contactPatientsLevel = Int($0) }
                        ), in: 0...5, step: 1)
                    }
                }
            }
            if !formData.contactImported.isEmpty {
                TribunalCollapsibleSection(title: "Imported Notes (\(formData.contactImported.count))", color: .yellow) {
                    TribunalImportedEntriesList(entries: $formData.contactImported)
                }
            }
        }
    }

    // MARK: - Section 7: Community Support
    private var communitySupportPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Community Support").font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text("Family Support Type").font(.subheadline).foregroundColor(.secondary)
                Picker("", selection: $formData.familySupportType) {
                    Text("None").tag("None")
                    Text("Limited").tag("Limited")
                    Text("Moderate").tag("Moderate")
                    Text("Good").tag("Good")
                }
                .pickerStyle(.segmented)
            }

            Toggle("CMHT involved", isOn: $formData.cmhtInvolved)
            Toggle("Treatment plan in place", isOn: $formData.treatmentPlanInPlace)

            VStack(alignment: .leading, spacing: 4) {
                Text("Accommodation Type").font(.subheadline).foregroundColor(.secondary)
                Picker("", selection: $formData.accommodationType) {
                    Text("24hr supported").tag("24hr supported")
                    Text("Supported").tag("Supported")
                    Text("Independent").tag("Independent")
                }
                .pickerStyle(.segmented)
            }
            if !formData.communitySupportImported.isEmpty {
                TribunalCollapsibleSection(title: "Imported Notes (\(formData.communitySupportImported.count))", color: .yellow) {
                    TribunalImportedEntriesList(entries: $formData.communitySupportImported)
                }
            }
        }
    }

    // MARK: - Section 8: Strengths
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

    // MARK: - Section 9: Progress
    private var progressPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Current Progress, Engagement, Behaviour").font(.headline)

            // Auto-generated narrative summary section (matching desktop Section 14 style)
            if !formData.progressImported.isEmpty {
                NursingNarrativeSummarySection(
                    entries: formData.progressImported,
                    patientName: formData.patientName.components(separatedBy: " ").first ?? "The patient",
                    gender: formData.patientGender.rawValue
                )
            }

            FormTextEditor(label: "Additional Notes", text: $formData.progressNarrative, minHeight: 80)
            if !formData.progressImported.isEmpty {
                TribunalCollapsibleSection(title: "Individual Progress Notes (\(formData.progressImported.count))", color: .yellow) {
                    TribunalImportedEntriesList(entries: $formData.progressImported)
                }
            }
        }
    }

    // MARK: - Section 10: AWOL
    private var awolPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AWOL or Failed Return from Leave").font(.headline)
            FormTextEditor(label: "Narrative", text: $formData.awolNarrative, minHeight: 100)
            if !formData.awolImported.isEmpty {
                TribunalCollapsibleSection(title: "Imported Notes (\(formData.awolImported.count))", color: .yellow) {
                    TribunalImportedEntriesList(entries: $formData.awolImported)
                }
            }
        }
    }

    // MARK: - Section 11: Compliance
    private var compliancePopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Compliance with Medication/Treatment").font(.headline)
            VStack(alignment: .leading, spacing: 4) {
                Text("Compliance Level").font(.subheadline).foregroundColor(.secondary)
                Picker("", selection: $formData.complianceLevel) {
                    Text("Full").tag("Full")
                    Text("Partial").tag("Partial")
                    Text("Poor").tag("Poor")
                    Text("None").tag("None")
                }
                .pickerStyle(.segmented)
            }
            FormTextEditor(label: "Details", text: $formData.complianceNarrative, minHeight: 80)
            if !formData.complianceImported.isEmpty {
                TribunalCollapsibleSection(title: "Imported Notes (\(formData.complianceImported.count))", color: .yellow) {
                    TribunalImportedEntriesList(entries: $formData.complianceImported)
                }
            }
        }
    }

    // MARK: - Section 12: Risk Harm
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

    // MARK: - Section 13: Risk Property
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

    // MARK: - Section 14: Seclusion
    private var seclusionPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Seclusion or Restraint").font(.headline)
            Toggle("Seclusion used", isOn: $formData.seclusionUsed)
            Toggle("Restraint used", isOn: $formData.restraintUsed)
            FormTextEditor(label: "Details", text: $formData.seclusionDetails, minHeight: 80)
            if !formData.seclusionImported.isEmpty {
                TribunalCollapsibleSection(title: "Imported Incidents (\(formData.seclusionImported.count))", color: .yellow) {
                    TribunalImportedEntriesList(entries: $formData.seclusionImported)
                }
            }
        }
    }

    // Sections 15 & 16 use inline TribunalYesNoCard (no popup) — matches PTR 19/20

    // MARK: - Section 17: Discharge Risk
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

    // MARK: - Section 18: Community Management
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
            FormTextEditor(label: "Community Management Plan", text: $formData.communityPlanDetails, minHeight: 100)
            if !formData.communityImported.isEmpty {
                TribunalCollapsibleSection(title: "Imported Notes (\(formData.communityImported.count))", color: .yellow) {
                    TribunalImportedEntriesList(entries: $formData.communityImported)
                }
            }
        }
    }

    // MARK: - Section 19: Other Info
    private var otherInfoPopup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Other Relevant Information").font(.headline)
            FormTextEditor(label: "Details", text: $formData.otherInfoNarrative, minHeight: 120)
        }
    }

    // MARK: - Section 20: Recommendations / Legal Criteria
    private var recommendationsPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Mental Disorder").font(.headline)
            ntrLegalRadio(label: "Present", altLabel: "Absent", selection: $formData.recMdPresent)

            if formData.recMdPresent == true {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Diagnosis (ICD-10)").font(.subheadline).foregroundColor(.secondary)
                    TribunalICD10DiagnosisPicker(label: "Primary Diagnosis", selection: $formData.recDiagnosis1)
                    TribunalICD10DiagnosisPicker(label: "Secondary Diagnosis", selection: $formData.recDiagnosis2)
                    TribunalICD10DiagnosisPicker(label: "Tertiary Diagnosis", selection: $formData.recDiagnosis3)
                }
                .padding(.leading, 8)

                Divider()
                Text("Criteria Warranting Detention").font(.headline)
                ntrLegalRadio(label: "Met", altLabel: "Not Met", selection: $formData.recCwdMet)

                if formData.recCwdMet == true {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Nature", isOn: $formData.recNature).toggleStyle(TribunalCheckboxStyle())
                        if formData.recNature {
                            VStack(alignment: .leading, spacing: 6) {
                                Toggle("Relapsing and remitting", isOn: $formData.recRelapsing).toggleStyle(TribunalCheckboxStyle())
                                Toggle("Treatment resistant", isOn: $formData.recTreatmentResistant).toggleStyle(TribunalCheckboxStyle())
                                Toggle("Chronic and enduring", isOn: $formData.recChronic).toggleStyle(TribunalCheckboxStyle())
                            }
                            .padding(.leading, 24)
                        }
                        Toggle("Degree", isOn: $formData.recDegree).toggleStyle(TribunalCheckboxStyle())
                        if formData.recDegree {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Symptom severity:").font(.subheadline).foregroundColor(.secondary)
                                Picker("Severity", selection: $formData.recDegreeLevel) {
                                    Text("Some").tag(1); Text("Several").tag(2); Text("Many").tag(3); Text("Overwhelming").tag(4)
                                }.pickerStyle(.segmented)
                                FormTextEditor(label: "Symptoms including:", text: $formData.recDegreeDetails, minHeight: 60)
                            }
                            .padding(.leading, 24)
                        }
                    }
                    .padding(.leading, 8)
                }

                Divider()
                Text("Necessity").font(.headline)
                ntrLegalRadio(label: "Yes", altLabel: "No", selection: $formData.recNecessary)

                if formData.recNecessary == true {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Health", isOn: $formData.recHealth).toggleStyle(TribunalCheckboxStyle())
                        if formData.recHealth {
                            VStack(alignment: .leading, spacing: 6) {
                                Toggle("Mental Health", isOn: $formData.recMentalHealth).toggleStyle(TribunalCheckboxStyle())
                                if formData.recMentalHealth {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Toggle("Poor compliance", isOn: $formData.recPoorCompliance).toggleStyle(TribunalCheckboxStyle())
                                        Toggle("Limited insight", isOn: $formData.recLimitedInsight).toggleStyle(TribunalCheckboxStyle())
                                    }.padding(.leading, 24)
                                }
                                Toggle("Physical Health", isOn: $formData.recPhysicalHealth).toggleStyle(TribunalCheckboxStyle())
                                if formData.recPhysicalHealth {
                                    FormTextEditor(label: "Physical health details", text: $formData.recPhysicalHealthDetails, minHeight: 60).padding(.leading, 24)
                                }
                            }.padding(.leading, 24)
                        }
                        Toggle("Safety", isOn: $formData.recSafety).toggleStyle(TribunalCheckboxStyle())
                        if formData.recSafety {
                            VStack(alignment: .leading, spacing: 6) {
                                Toggle("Self", isOn: $formData.recSafetySelf).toggleStyle(TribunalCheckboxStyle())
                                if formData.recSafetySelf {
                                    FormTextEditor(label: "Details about risk to self", text: $formData.recSelfDetails, minHeight: 60).padding(.leading, 24)
                                }
                                Toggle("Others", isOn: $formData.recOthers).toggleStyle(TribunalCheckboxStyle())
                                if formData.recOthers {
                                    FormTextEditor(label: "Details about risk to others", text: $formData.recOthersDetails, minHeight: 60).padding(.leading, 24)
                                }
                            }.padding(.leading, 24)
                        }
                    }.padding(.leading, 8)
                }

                Divider()
                Toggle("Treatment Available", isOn: $formData.recTreatmentAvailable).toggleStyle(TribunalCheckboxStyle()).font(.headline)
                Toggle("Least Restrictive Option", isOn: $formData.recLeastRestrictive).toggleStyle(TribunalCheckboxStyle()).font(.headline)
            }

            if formData.recMdPresent == false {
                Text("Mental disorder is absent — no further criteria apply.")
                    .font(.subheadline).foregroundColor(.secondary).padding(.top, 4)
            }
            if !formData.recommendationsImported.isEmpty {
                TribunalCollapsibleSection(title: "Imported Notes (\(formData.recommendationsImported.count))", color: .yellow) {
                    TribunalImportedEntriesList(entries: $formData.recommendationsImported)
                }
            }
        }
    }

    private func ntrLegalRadio(label: String, altLabel: String, selection: Binding<Bool?>) -> some View {
        HStack(spacing: 20) {
            Button { selection.wrappedValue = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: selection.wrappedValue == true ? "largecircle.fill.circle" : "circle")
                        .foregroundColor(selection.wrappedValue == true ? .purple : .gray)
                    Text(label).foregroundColor(.primary)
                }
            }.buttonStyle(.plain)
            Button { selection.wrappedValue = false } label: {
                HStack(spacing: 8) {
                    Image(systemName: selection.wrappedValue == false ? "largecircle.fill.circle" : "circle")
                        .foregroundColor(selection.wrappedValue == false ? .purple : .gray)
                    Text(altLabel).foregroundColor(.primary)
                }
            }.buttonStyle(.plain)
            Spacer()
        }
    }

    // MARK: - Section 21: Signature
    private var signaturePopup: some View {
        VStack(alignment: .leading, spacing: 12) {
            FormTextField(label: "Name", text: $formData.signatureName, isRequired: true)
            FormTextField(label: "Designation", text: $formData.signatureDesignation)
            FormTextField(label: "Qualifications", text: $formData.signatureQualifications)
            FormTextField(label: "Registration Number", text: $formData.signatureRegNumber)
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
            parts.append("Section: \(formData.mhaSection)")
            return parts.joined(separator: "\n")

        case .nursingCare:
            var parts: [String] = ["Nursing care: \(formData.nursingCareLevel)"]
            let meds = formData.medications.filter { !$0.name.isEmpty }
            if !meds.isEmpty {
                parts.append("\nMedications:")
                for med in meds {
                    var medStr = "• \(med.name)"
                    if !med.dose.isEmpty { medStr += " \(med.dose)" }
                    parts.append(medStr)
                }
            }
            let ncImported = selectedEntryText(formData.nursingCareImported)
            if !ncImported.isEmpty { parts.append("\n\(ncImported)") }
            return parts.joined(separator: "\n")

        case .observationLevel:
            var text = "Observation level: \(formData.observationLevel)"
            if !formData.observationDetails.isEmpty { text += "\n\(formData.observationDetails)" }
            let obsImported = selectedEntryText(formData.observationImported)
            if !obsImported.isEmpty { text += "\n\n\(obsImported)" }
            return text

        case .contact:
            var parts: [String] = []
            parts.append("Relatives: \(formData.contactRelativesType)")
            if formData.hasFriends { parts.append("Friends: contact level \(formData.contactFriendsLevel)") }
            if formData.hasPatientContact { parts.append("Other patients: contact level \(formData.contactPatientsLevel)") }
            let ctImported = selectedEntryText(formData.contactImported)
            if !ctImported.isEmpty { parts.append("\n\(ctImported)") }
            return parts.joined(separator: "\n")

        case .communitySupport:
            var parts: [String] = []
            parts.append("Family support: \(formData.familySupportType)")
            if formData.cmhtInvolved { parts.append("CMHT involved") }
            if formData.treatmentPlanInPlace { parts.append("Treatment plan in place") }
            parts.append("Accommodation: \(formData.accommodationType)")
            let csImported = selectedEntryText(formData.communitySupportImported)
            if !csImported.isEmpty { parts.append("\n\(csImported)") }
            return parts.joined(separator: "\n")

        case .strengths:
            var parts: [String] = []
            if !formData.strengthsNarrative.isEmpty { parts.append(formData.strengthsNarrative) }
            let sImported = selectedEntryText(formData.strengthsImported)
            if !sImported.isEmpty { parts.append(sImported) }
            return parts.joined(separator: "\n\n")

        case .progress:
            var parts: [String] = []
            if !formData.progressNarrative.isEmpty { parts.append(formData.progressNarrative) }
            let pImported = selectedEntryText(formData.progressImported)
            if !pImported.isEmpty { parts.append(pImported) }
            return parts.joined(separator: "\n\n")

        case .awol:
            var parts: [String] = []
            if !formData.awolNarrative.isEmpty { parts.append(formData.awolNarrative) }
            let aImported = selectedEntryText(formData.awolImported)
            if !aImported.isEmpty { parts.append(aImported) }
            return parts.joined(separator: "\n\n")

        case .compliance:
            var text = "Compliance: \(formData.complianceLevel)"
            if !formData.complianceNarrative.isEmpty { text += "\n\(formData.complianceNarrative)" }
            let cImported = selectedEntryText(formData.complianceImported)
            if !cImported.isEmpty { text += "\n\n\(cImported)" }
            return text

        case .riskHarm:
            var types: [String] = []
            if formData.harmAssaultStaff { types.append("assault on staff") }
            if formData.harmAssaultPatients { types.append("assault on patients") }
            if formData.harmAssaultPublic { types.append("assault on public") }
            if formData.harmVerbalAggression { types.append("verbal aggression") }
            if formData.harmSelfHarm { types.append("self-harm") }
            if formData.harmSuicidal { types.append("suicidal ideation/attempt") }
            var text = types.isEmpty ? "No significant incidents reported." : "Incidents include: " + types.joined(separator: ", ") + "."
            let rhImported = selectedEntryText(formData.riskHarmImported)
            if !rhImported.isEmpty { text += "\n\n\(rhImported)" }
            return text

        case .riskProperty:
            var types: [String] = []
            if formData.propertyWard { types.append("ward property") }
            if formData.propertyPersonal { types.append("personal belongings") }
            if formData.propertyFire { types.append("fire setting") }
            if formData.propertyVehicle { types.append("vehicle damage") }
            var text = types.isEmpty ? "No significant property damage incidents." : "Property damage: " + types.joined(separator: ", ") + "."
            let rpImported = selectedEntryText(formData.riskPropertyImported)
            if !rpImported.isEmpty { text += "\n\n\(rpImported)" }
            return text

        case .seclusion:
            var parts: [String] = []
            if formData.seclusionUsed { parts.append("Seclusion used") }
            if formData.restraintUsed { parts.append("Restraint used") }
            if !formData.seclusionDetails.isEmpty { parts.append(formData.seclusionDetails) }
            let secImported = selectedEntryText(formData.seclusionImported)
            if !secImported.isEmpty { parts.append(secImported) }
            if parts.isEmpty { return "No seclusion or restraint." }
            return parts.joined(separator: "\n")

        case .dischargeRisk:
            var risks: [String] = []
            if formData.dischargeRiskViolence { risks.append("violence") }
            if formData.dischargeRiskSelfHarm { risks.append("self-harm") }
            if formData.dischargeRiskNeglect { risks.append("self-neglect") }
            if formData.dischargeRiskExploitation { risks.append("exploitation") }
            if formData.dischargeRiskRelapse { risks.append("relapse") }
            if formData.dischargeRiskNonCompliance { risks.append("non-compliance") }
            if risks.isEmpty { return "No significant discharge risks identified." }
            return "Discharge risks: " + risks.joined(separator: ", ") + "." + (formData.dischargeRiskDetails.isEmpty ? "" : "\n\(formData.dischargeRiskDetails)")

        case .communityManagement:
            var parts: [String] = []
            parts.append("CMHT: \(formData.cmhtInvolvement)")
            if formData.cpaInPlace { parts.append("CPA in place") }
            if formData.careCoordinator { parts.append("Care coordinator assigned") }
            if formData.section117 { parts.append("Section 117 aftercare") }
            if !formData.communityPlanDetails.isEmpty { parts.append(formData.communityPlanDetails) }
            let cmImported = selectedEntryText(formData.communityImported)
            if !cmImported.isEmpty { parts.append(cmImported) }
            return parts.joined(separator: "\n")

        case .otherInfo:
            return formData.otherInfoNarrative

        case .recommendations:
            var text = generateNtrLegalCriteriaText()
            let recImported = selectedEntryText(formData.recommendationsImported)
            if !recImported.isEmpty { text += (text.isEmpty ? "" : "\n\n") + recImported }
            return text

        case .signature:
            var parts: [String] = []
            if !formData.signatureName.isEmpty { parts.append(formData.signatureName) }
            if !formData.signatureDesignation.isEmpty { parts.append(formData.signatureDesignation) }
            if !formData.signatureQualifications.isEmpty { parts.append(formData.signatureQualifications) }
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            parts.append("Date: \(formatter.string(from: formData.signatureDate))")
            return parts.joined(separator: "\n")

        case .factorsHearing:
            let pronoun = nursingGenderPronoun(formData.patientGender)
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
            let pronoun = nursingGenderPronoun(formData.patientGender)
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

        case .s2Detention:
            var text = formData.s2DetentionJustified ? "Yes" : "No"
            if !formData.s2Explanation.isEmpty { text += "\n\(formData.s2Explanation)" }
            return text

        case .otherDetention:
            var text = formData.otherDetentionJustified ? "Yes" : "No"
            if !formData.otherDetentionExplanation.isEmpty { text += "\n\(formData.otherDetentionExplanation)" }
            return text
        }
    }

    private func selectedEntryText(_ entries: [TribunalImportedEntry]) -> String {
        let selected = entries.filter { $0.selected }
        if selected.isEmpty { return "" }
        return selected.map { $0.text }.joined(separator: "\n\n")
    }

    private func generateNtrLegalCriteriaText() -> String {
        let p = genderPronoun(formData.patientGender)
        let suffers = (p.have == "has") ? "suffers" : "suffer"
        let does = (p.have == "has") ? "does" : "do"
        var parts: [String] = []

        if formData.recMdPresent == true {
            var dxItems: [String] = []
            for dx in [formData.recDiagnosis1, formData.recDiagnosis2, formData.recDiagnosis3] {
                if let d = dx { dxItems.append("\(d.diagnosisName) (\(d.code))") }
            }
            let dxText = dxItems.count > 1 ? dxItems.dropLast().joined(separator: ", ") + " and " + dxItems.last! : dxItems.first ?? ""
            let mdBase = !dxText.isEmpty
                ? "\(p.subj) \(suffers) from \(dxText) which is a mental disorder under the Mental Health Act"
                : "\(p.subj) \(suffers) from a mental disorder under the Mental Health Act"

            if formData.recCwdMet == true {
                let ndText: String
                if formData.recNature && formData.recDegree { ndText = ", which is of a nature and degree to warrant detention." }
                else if formData.recNature { ndText = ", which is of a nature to warrant detention." }
                else if formData.recDegree { ndText = ", which is of a degree to warrant detention." }
                else { ndText = "." }
                parts.append(mdBase + ndText)

                if formData.recNature {
                    var nt: [String] = []
                    if formData.recRelapsing { nt.append("relapsing and remitting") }
                    if formData.recTreatmentResistant { nt.append("treatment resistant") }
                    if formData.recChronic { nt.append("chronic and enduring") }
                    if !nt.isEmpty { parts.append("The illness is of a \(nt.joined(separator: ", ")) nature.") }
                }
                if formData.recDegree {
                    let levels = [1: "some", 2: "several", 3: "many", 4: "overwhelming"]
                    let level = levels[formData.recDegreeLevel] ?? "several"
                    let det = formData.recDegreeDetails.trimmingCharacters(in: .whitespacesAndNewlines)
                    parts.append(!det.isEmpty ? "The degree of the illness is evidenced by \(level) symptoms including \(det)." : "The degree of the illness is evidenced by \(level) symptoms.")
                }
            } else if formData.recCwdMet == false {
                parts.append(mdBase + ".")
                parts.append("The criteria for detention are not met.")
            } else { parts.append(mdBase + ".") }
        } else if formData.recMdPresent == false {
            parts.append("\(p.subj) \(does) not suffer from a mental disorder under the Mental Health Act.")
        }

        if formData.recNecessary == true {
            if formData.recHealth && formData.recMentalHealth {
                parts.append("Medical treatment under the Mental Health Act is necessary to prevent deterioration in \(p.pos) mental health.")
                if formData.recPoorCompliance && formData.recLimitedInsight {
                    parts.append("Both historical non compliance and current limited insight makes the risk on stopping medication high without the safeguards of the Mental Health Act. This would result in a deterioration of \(p.pos) mental state.")
                } else if formData.recPoorCompliance {
                    parts.append("This is based on historical non compliance and without detention I would be concerned this would result in a deterioration of \(p.pos) mental state.")
                } else if formData.recLimitedInsight {
                    parts.append("I am concerned about \(p.pos) current limited insight into \(p.pos) mental health needs and how this would result in immediate non compliance with medication, hence a deterioration in \(p.pos) mental health.")
                }
            } else { parts.append("Medical treatment under the Mental Health Act is necessary.") }

            if formData.recHealth && formData.recPhysicalHealth {
                let det = formData.recPhysicalHealthDetails.trimmingCharacters(in: .whitespacesAndNewlines)
                let base = formData.recMentalHealth ? "The Mental Health Act is also necessary for maintaining \(p.pos) physical health." : "The Mental Health Act is necessary for \(p.pos) physical health."
                parts.append(!det.isEmpty ? "\(base) \(det)" : base)
            }
            if formData.recSafety {
                let useAlso = formData.recHealth
                if formData.recSafetySelf {
                    let det = formData.recSelfDetails.trimmingCharacters(in: .whitespacesAndNewlines)
                    let base = useAlso ? "The Mental Health Act is also necessary for \(p.pos) risk to \(p.reflex)." : "The Mental Health Act is necessary for \(p.pos) risk to \(p.reflex)."
                    parts.append(!det.isEmpty ? "\(base) \(det)" : base)
                }
                if formData.recOthers {
                    let det = formData.recOthersDetails.trimmingCharacters(in: .whitespacesAndNewlines)
                    let base = (useAlso || formData.recSafetySelf) ? "Risk to others also makes the Mental Health Act necessary." : "Risk to others makes the Mental Health Act necessary."
                    parts.append(!det.isEmpty ? "\(base) \(det)" : base)
                }
            }
        } else if formData.recNecessary == false {
            parts.append("Medical treatment under the Mental Health Act is not necessary.")
        }

        if formData.recTreatmentAvailable { parts.append("Treatment is available, medical, nursing, OT/Psychology and social work.") }
        if formData.recLeastRestrictive { parts.append("I can confirm this is the least restrictive option to meet \(p.pos) needs.") }

        return parts.joined(separator: " ")
    }

    private func nursingGenderPronoun(_ gender: Gender) -> (subj: String, obj: String, pos: String) {
        switch gender {
        case .male:
            return ("He", "him", "his")
        case .female:
            return ("She", "her", "her")
        case .other, .notSpecified:
            return ("They", "them", "their")
        }
    }
}

// MARK: - Nursing Narrative Summary Section (matching desktop Section 14 style)

/// Generates and displays a clinical narrative summary for Nursing Section 9
struct NursingNarrativeSummarySection: View {
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
                // Fallback
                let sortedEntries = entries.compactMap { entry -> (Date, TribunalImportedEntry)? in
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

                    Text("\(patientName) has been reviewed \(freqDesc) over the past \(months) months with \(entries.count) documented contacts. \(pronounPoss.capitalized) mental state has been monitored throughout this period.")
                        .font(.caption)
                }
            }
        }
    }
}

#Preview {
    NursingTribunalReportView()
        .environment(AppStore())
        .environment(SharedDataStore.shared)
}
