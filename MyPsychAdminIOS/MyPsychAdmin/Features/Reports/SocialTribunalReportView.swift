//
//  SocialTribunalReportView.swift
//  MyPsychAdmin
//
//  Social Tribunal Report Form for iOS
//  Based on desktop social_tribunal_report_page.py structure (31 sections)
//  Uses same card/popup layout pattern as MOJASRFormView
//

import SwiftUI
import UniformTypeIdentifiers

struct SocialTribunalReportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var appStore
    @Environment(SharedDataStore.self) private var sharedData

    @State private var formData: SocialTribunalFormData
    @State private var validationErrors: [FormValidationError] = []
    @State private var generatedTexts: [STRSection: String] = [:]
    @State private var manualNotes: [STRSection: String] = [:]
    @State private var activePopup: STRSection? = nil
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var showingImportPicker = false
    @State private var isImporting = false
    @State private var importStatusMessage: String?
    @State private var hasPopulatedFromSharedData = false
    @State private var docxURL: URL?
    @State private var showShareSheet = false

    // 31 Sections matching desktop Social Tribunal Report order
    enum STRSection: String, CaseIterable, Identifiable {
        case patientDetails = "1. Patient Details"
        case factorsHearing = "2. Factors affecting understanding"
        case adjustments = "3. Adjustments for tribunal"
        case forensicHistory = "4. Index offence(s) and forensic history"
        case previousMH = "5. Previous MH involvement"
        case homeFamily = "6. Home and family circumstances"
        case housing = "7. Housing or accommodation"
        case financial = "8. Financial position"
        case employment = "9. Employment opportunities"
        case previousCommunity = "10. Previous community support"
        case carePathway = "11. Care pathway and Section 117"
        case carePlan = "12. Proposed care plan"
        case carePlanAdequacy = "13. Adequacy of care plan"
        case carePlanFunding = "14. Funding issues"
        case strengths = "15. Strengths or positive factors"
        case progress = "16. Current progress"
        case riskHarm = "17. Incidents of harm"
        case riskProperty = "18. Incidents of property damage"
        case patientViews = "19. Patient's views and wishes"
        case nearestRelative = "20. Nearest Relative views"
        case nrInappropriate = "21. NR consultation inappropriate"
        case carerViews = "22. Carer views"
        case mappa = "23. MAPPA involvement"
        case mcaDoL = "24. MCA 2005 deprivation of liberty"
        case s2Detention = "25. Section 2: Detention justified"
        case otherDetention = "26. Other sections: Treatment justified"
        case dischargeRisk = "27. Risk if discharged"
        case communityManagement = "28. Community risk management"
        case otherInfo = "29. Other relevant information"
        case recommendations = "30. Recommendations to tribunal"
        case signature = "31. Signature"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .patientDetails: return "person"
            case .factorsHearing: return "ear"
            case .adjustments: return "slider.horizontal.3"
            case .forensicHistory: return "building.columns"
            case .previousMH: return "clock.arrow.circlepath"
            case .homeFamily: return "house.and.flag"
            case .housing: return "house"
            case .financial: return "banknote"
            case .employment: return "briefcase"
            case .previousCommunity: return "person.3.sequence"
            case .carePathway: return "arrow.triangle.branch"
            case .carePlan: return "doc.text"
            case .carePlanAdequacy: return "checkmark.seal"
            case .carePlanFunding: return "creditcard"
            case .strengths: return "star"
            case .progress: return "chart.line.uptrend.xyaxis"
            case .riskHarm: return "exclamationmark.shield"
            case .riskProperty: return "flame"
            case .patientViews: return "bubble.left.and.bubble.right"
            case .nearestRelative: return "person.2.wave.2"
            case .nrInappropriate: return "person.badge.minus"
            case .carerViews: return "person.badge.key"
            case .mappa: return "shield.checkered"
            case .mcaDoL: return "figure.stand.line.dotted.figure.stand"
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
            case .forensicHistory, .progress, .carePlan: return 200
            case .riskHarm, .dischargeRisk: return 180
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
                return "25. Section 2: Is detention justified for the health or safety of the patient or the protection of others?"
            case .otherDetention:
                return "26. Other sections: Is medical treatment justified for health, safety or protection?"
            default:
                return rawValue
            }
        }
    }

    // No persistence - data only exists for current session
    init() {
        _formData = State(initialValue: SocialTribunalFormData())
        _generatedTexts = State(initialValue: [:])
        _manualNotes = State(initialValue: [:])
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if let error = exportError {
                        Text(error).foregroundColor(.red).font(.caption).padding(.horizontal)
                    }
                    FormValidationErrorView(errors: validationErrors).padding(.horizontal)

                    ForEach(STRSection.allCases) { section in
                        if section.isYesNoSection {
                            TribunalYesNoCard(
                                title: section.questionText,
                                icon: section.icon,
                                color: "F59E0B",
                                isYes: yesNoBinding(for: section)
                            )
                        } else {
                            TribunalEditableCard(
                                title: section.rawValue,
                                icon: section.icon,
                                color: "F59E0B", // Amber theme for social
                                text: binding(for: section),
                                defaultHeight: section.defaultHeight,
                                onHeaderTap: { activePopup = section }
                            )
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Social Tribunal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
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
            }
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
            sharedData.socialTribunalFormData = newValue
        }
        .onChange(of: generatedTexts) { _, newValue in
            var dict: [String: String] = [:]
            for (section, text) in newValue {
                dict[section.rawValue] = text
            }
            sharedData.socialTribunalGeneratedTexts = dict
        }
        .onChange(of: manualNotes) { _, newValue in
            var dict: [String: String] = [:]
            for (section, text) in newValue {
                dict[section.rawValue] = text
            }
            sharedData.socialTribunalManualNotes = dict
        }
        .onReceive(sharedData.notesDidChange) { notes in
            if !notes.isEmpty { populateFromClinicalNotes(notes) }
        }
        .onReceive(sharedData.patientInfoDidChange) { patientInfo in
            if !patientInfo.fullName.isEmpty {
                formData.patientName = patientInfo.fullName
                formData.patientDOB = patientInfo.dateOfBirth
                formData.patientGender = patientInfo.gender
            }
        }
        .sheet(item: $activePopup) { section in
            STRPopupView(
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

    private func binding(for section: STRSection) -> Binding<String> {
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

    private func yesNoBinding(for section: STRSection) -> Binding<Bool> {
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
        formData = sharedData.socialTribunalFormData
        for (key, value) in sharedData.socialTribunalGeneratedTexts {
            if let section = STRSection(rawValue: key) {
                generatedTexts[section] = value
            }
        }
        for (key, value) in sharedData.socialTribunalManualNotes {
            if let section = STRSection(rawValue: key) {
                manualNotes[section] = value
            }
        }
    }

    private func initializeCardTexts() {
        for section in STRSection.allCases {
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

        // Collect section content keyed by STRSection rawValue
        var sectionContent: [String: String] = [:]
        for section in STRSection.allCases {
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
        let patientAddress = formData.currentLocation

        // Format signature date
        let sigDateFmt = DateFormatter()
        sigDateFmt.dateFormat = "dd/MM/yyyy"
        let sigDateStr = sigDateFmt.string(from: formData.signatureDate)

        // Capture form state for background thread
        let patientName = formData.patientName
        let patientDOB = formData.patientDOB
        let socialWorkerName = formData.signatureName
        let socialWorkerRole = formData.signatureDesignation
        let hasFactors = formData.hasFactorsAffectingHearing
        let hasAdj = formData.hasAdjustmentsNeeded
        let hasEmployment = formData.hasEmploymentOpportunities
        let hasFunding = formData.carePlanFunding != "Confirmed"
        let hasMappa = formData.mappaInvolved
        let s2OK = formData.s2DetentionJustified
        let otherOK = formData.otherDetentionJustified
        let hasDR = formData.dischargeRiskViolence || formData.dischargeRiskSelfHarm || formData.dischargeRiskNeglect || formData.dischargeRiskExploitation || formData.dischargeRiskRelapse || formData.dischargeRiskNonCompliance
        let hasOI = !formData.otherInfoNarrative.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasRec = formData.recMdPresent == true

        DispatchQueue.global(qos: .userInitiated).async {
            let exporter = SCTDOCXExporter(
                sectionContent: sectionContent,
                patientName: patientName,
                patientDOB: patientDOB,
                patientAddress: patientAddress,
                socialWorkerName: socialWorkerName,
                socialWorkerRole: socialWorkerRole,
                signatureDate: sigDateStr,
                hasFactors: hasFactors,
                hasAdj: hasAdj,
                hasEmployment: hasEmployment,
                hasFunding: hasFunding,
                hasMappa: hasMappa,
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
                let filename = "SCT_Report_\(timestamp).docx"
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
                            sharedData.setPatientInfo(extractedDoc.patientInfo, source: "str_import")
                            formData.patientName = extractedDoc.patientInfo.fullName
                            if let dob = extractedDoc.patientInfo.dateOfBirth { formData.patientDOB = dob }
                            formData.patientGender = extractedDoc.patientInfo.gender
                        }

                        // CRITICAL BRANCHING: Report vs Notes Detection
                        let sections = Self.isSCTReport(extractedDoc) ? parseSCTReportSections(from: extractedDoc.text) : [:]

                        if !sections.isEmpty {
                            // REPORT PATH
                            populateFromReport(sections)
                            importStatusMessage = "Imported report (\(sections.count) sections)"
                        } else {
                            // NOTES PATH
                            if !extractedDoc.notes.isEmpty {
                                sharedData.setNotes(extractedDoc.notes, source: "str_import")
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
        formData.forensicImported.removeAll()
        formData.previousMHImported.removeAll()
        formData.homeFamilyImported.removeAll()
        formData.housingImported.removeAll()
        formData.financialImported.removeAll()
        formData.strengthsImported.removeAll()
        formData.progressImported.removeAll()
        formData.riskHarmImported.removeAll()
        formData.riskPropertyImported.removeAll()
        formData.recommendationsImported.removeAll()

        // Build timeline to find admissions
        let episodes = TimelineBuilder.buildTimeline(from: notes, allNotes: notes)
        let inpatientEpisodes = episodes.filter { $0.type == .inpatient }
        let mostRecentAdmission = inpatientEpisodes.last
        let calendar = Calendar.current

        let forensicKW = ["offence", "conviction", "court", "sentence", "criminal", "arrest"]
        let familyKW = ["family", "mother", "father", "sibling", "relative", "partner"]
        let housingKW = ["housing", "accommodation", "flat", "house", "homeless", "address"]
        let financialKW = ["benefit", "income", "financial", "money", "debt", "ESA", "PIP"]
        let progressKW = ["progress", "engagement", "behaviour", "insight", "compliance"]
        let riskKW = ["assault", "attack", "violence", "aggression", "harm", "self-harm"]
        let propertyKW = ["damage", "broke", "smashed", "property", "fire"]
        let strengthsKW = ["strength", "positive", "good", "engaged", "motivated"]

        for note in notes {
            let text = note.body
            let date = note.date
            let snippet = text.count > 150 ? String(text.prefix(150)) + "..." : text
            let noteDay = calendar.startOfDay(for: date)

            // Previous MH History: Only admission clerking notes within 14 days of each admission
            for episode in inpatientEpisodes {
                let windowEnd = calendar.date(byAdding: .day, value: 14, to: episode.start) ?? episode.start
                if noteDay >= episode.start && noteDay <= windowEnd {
                    if AdmissionKeywords.noteIndicatesAdmission(text) {
                        formData.previousMHImported.append(TribunalImportedEntry(date: date, text: text, snippet: snippet))
                        break
                    }
                }
            }

            // Progress, Strengths: Filter to most recent admission window (2 days before to 14 days after)
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
                }
            }

            // Forensic, Family, Housing, Financial: Use keyword matching across all notes (background info)
            if forensicKW.contains(where: { text.lowercased().contains($0) }) {
                formData.forensicImported.append(TribunalImportedEntry(date: date, text: text, snippet: snippet))
            }
            if familyKW.contains(where: { text.lowercased().contains($0) }) {
                formData.homeFamilyImported.append(TribunalImportedEntry(date: date, text: text, snippet: snippet))
            }
            if housingKW.contains(where: { text.lowercased().contains($0) }) {
                formData.housingImported.append(TribunalImportedEntry(date: date, text: text, snippet: snippet))
            }
            if financialKW.contains(where: { text.lowercased().contains($0) }) {
                formData.financialImported.append(TribunalImportedEntry(date: date, text: text, snippet: snippet))
            }

            // Risk: Use keyword matching across all notes (incident-based)
            if riskKW.contains(where: { text.lowercased().contains($0) }) {
                formData.riskHarmImported.append(TribunalImportedEntry(date: date, text: text, snippet: snippet))
            }
            if propertyKW.contains(where: { text.lowercased().contains($0) }) {
                formData.riskPropertyImported.append(TribunalImportedEntry(date: date, text: text, snippet: snippet))
            }
        }

        // Sort by date
        formData.forensicImported.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.previousMHImported.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.homeFamilyImported.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.housingImported.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.financialImported.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.progressImported.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.riskHarmImported.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.riskPropertyImported.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        formData.strengthsImported.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }

    // MARK: - Report Detection

    private static func isSCTReport(_ document: ExtractedDocument) -> Bool {
        let text = document.text

        // Check 1: Single long note — report parsed as one block
        if document.notes.count == 1 && document.notes[0].body.count > 2000 {
            print("[SCT iOS] isSCTReport=true (single long note, \(document.notes[0].body.count) chars)")
            return true
        }

        // Check 2: Numbered question scan — regex for ^\s*(\d+)[.)] patterns in range 1-28
        let lines = text.components(separatedBy: .newlines)
        var questionNumbers = Set<Int>()
        let questionPattern = try? NSRegularExpression(pattern: #"^\s*(\d+)[\.\)]\s*"#, options: [])
        for line in lines {
            let nsLine = line as NSString
            if let match = questionPattern?.firstMatch(in: line, options: [], range: NSRange(location: 0, length: nsLine.length)) {
                let numStr = nsLine.substring(with: match.range(at: 1))
                if let num = Int(numStr), num >= 1 && num <= 28 {
                    questionNumbers.insert(num)
                }
            }
        }
        if questionNumbers.count >= 5 {
            print("[SCT iOS] isSCTReport=true (found \(questionNumbers.count) numbered questions)")
            return true
        }

        // Check 3: SCT-specific keyword fingerprints
        let textLower = text.lowercased()
        let fingerprints = [
            "social circumstances report",
            "social circumstances",
            "care pathway",
            "section 117 after-care",
            "section 117 aftercare",
            "proposed care plan",
            "mappa",
            "nearest relative",
            "forensic history"
        ]
        let fingerprintMatches = fingerprints.filter { textLower.contains($0) }.count
        if fingerprintMatches >= 3 {
            print("[SCT iOS] isSCTReport=true (matched \(fingerprintMatches) keyword fingerprints)")
            return true
        }

        // Check 4: No notes but substantial text with some SCT indicators
        if document.notes.isEmpty && text.count > 500 {
            if questionNumbers.count >= 2 || fingerprintMatches >= 1 {
                print("[SCT iOS] isSCTReport=true (no notes, \(text.count) chars)")
                return true
            }
        }

        print("[SCT iOS] isSCTReport=false")
        return false
    }

    // MARK: - Report Parsing

    /// Parse SCT report text into sections using question text fragments as boundaries.
    /// DocumentProcessor.extractPlainTextFromXML produces ONE LONG LINE with no paragraph breaks,
    /// so we find section boundaries by searching for known question text fragments inline.
    private func parseSCTReportSections(from text: String) -> [STRSection: String] {
        var result: [STRSection: String] = [:]

        // Normalize curly quotes for searching
        let normalized = text
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")
        let lower = normalized.lowercased()

        // Section boundary markers — unique question text fragments near the START of each question.
        // Ordered by section number. Searched in the lowercased, quote-normalized text.
        // Note: SC report has 28 content sections mapping to 31 app sections (28=community, 29=other_info don't exist in some DOCX).
        let markers: [(section: STRSection, num: Int, fragments: [String])] = [
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
            (.forensicHistory, 4, [
                "give details of any index offence",
                "index offence"
            ]),
            (.previousMH, 5, [
                "what are the dates of the patient's previous involvement",
                "what are the dates of the patient\u{2019}s previous involvement",
                "previous involvement with mental health services"
            ]),
            (.homeFamily, 6, [
                "what are the patient's home and family circumstances",
                "what are the patient\u{2019}s home and family circumstances",
                "the patient's home and family",
                "the patient\u{2019}s home and family"
            ]),
            (.housing, 7, [
                "if discharged, what housing or accommodation",
                "if discharged what housing or accommodation",
                "what housing or accommodation would be available"
            ]),
            (.financial, 8, [
                "what is/would be the patient's financial position",
                "what is/would be the patient\u{2019}s financial position",
                "what is the patient's financial position",
                "what is the patient\u{2019}s financial position",
                "the patient's financial position"
            ]),
            (.employment, 9, [
                "if the patient were discharged are there any available opportunities for employment",
                "if the patient was discharged are there any available opportunities for employment",
                "any available opportunities for employment"
            ]),
            (.previousCommunity, 10, [
                "what was the patient's previous response to community support",
                "what was the patient\u{2019}s previous response to community support",
                "previous response to community support",
                "response to community support"
            ]),
            (.carePathway, 11, [
                "what care pathway and section 117 after-care",
                "what care pathway and section 117 aftercare"
            ]),
            (.carePlan, 12, [
                "give details of the proposed care plan"
            ]),
            (.carePlanAdequacy, 13, [
                "how adequate or effective is the proposed care plan"
            ]),
            (.carePlanFunding, 14, [
                "are there any issues as to funding the proposed care plan",
                "are there any issues as to funding the propose care plan"
            ]),
            (.strengths, 15, [
                "what are the strengths or positive factors"
            ]),
            (.progress, 16, [
                "give a summary of the patient's current progress",
                "give a summary of the patient\u{2019}s current progress"
            ]),
            (.riskHarm, 17, [
                "give details of any incidents in hospital where the patient has harmed",
                "give details of any incidents where the patient has harmed"
            ]),
            (.riskProperty, 18, [
                "give details of any incidents where the patient has damaged property",
                "give details of any incidents where the patient has damaged"
            ]),
            (.patientViews, 19, [
                "what are the patient's views, wishes, beliefs",
                "what are the patient\u{2019}s views, wishes, beliefs",
                "the patient's views, wishes",
                "the patient\u{2019}s views, wishes"
            ]),
            (.nearestRelative, 20, [
                "what are the views of the patient's nearest relative",
                "what are the views of the patient\u{2019}s nearest relative",
                "other than in restricted cases, what are the views"
            ]),
            (.nrInappropriate, 21, [
                "if (having consulted the patient) it was considered inappropriate",
                "if it was considered inappropriate or impractical to consult the nearest relative",
                "inappropriate or impractical to consult the nearest relative"
            ]),
            (.carerViews, 22, [
                "what are the views of any other person who takes a lead role",
                "views of any other person who takes a lead role"
            ]),
            (.mappa, 23, [
                "is the patient known to any mappa"
            ]),
            (.mcaDoL, 24, [
                "in the case of an eligible compliant patient who lacks capacity",
                "deprivation of liberty under the mental capacity act"
            ]),
            (.s2Detention, 25, [
                "in section 2 cases is the detention in hospital",
                "in section 2 cases, is the detention in hospital",
                "in section 2 cases is detention in hospital",
                "in section 2 cases, is detention in hospital"
            ]),
            (.otherDetention, 26, [
                "in all other cases is the provision of medical treatment",
                "in all other cases, is the provision of medical treatment"
            ]),
            (.dischargeRisk, 27, [
                "if the patient was discharged from hospital",
                "if the patient were discharged from hospital"
            ]),
            (.recommendations, 28, [
                "do you have any recommendations to the tribunal",
                "do you have any recommendations to the panel"
            ]),
        ]

        // Find position of each section marker in the text
        struct BoundaryHit {
            let section: STRSection
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

            let cleaned = cleanSCTSectionText(rawContent)
            if !cleaned.isEmpty {
                result[hits[i].section] = cleaned
            }
        }

        NSLog("[SCT iOS] Parsed %d report sections: %@", result.count, result.keys.map { $0.rawValue }.sorted().description)
        return result
    }

    /// Clean SCT section text by stripping number prefix, question text, checkbox markers,
    /// sub-question text, and instruction text. Handles inline (one-line) text from extractPlainTextFromXML.
    /// For Yes/No sections, detects the checked checkbox state and prepends "Yes\n" or "No\n".
    private func cleanSCTSectionText(_ text: String) -> String {
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
        // Detect "No x Yes" or "No Yes x" patterns (SC report uses lowercase 'x' next to the checked answer)
        if detectedAnswer == nil {
            // "Yes x" or "Yes X" at word boundary
            if let yxRegex = try? NSRegularExpression(pattern: #"\bYes\s+[xX]\b"#, options: []) {
                if yxRegex.firstMatch(in: working, range: NSRange(location: 0, length: (working as NSString).length)) != nil {
                    detectedAnswer = "Yes"
                }
            }
        }
        if detectedAnswer == nil {
            if let nxRegex = try? NSRegularExpression(pattern: #"\bNo\s+[xX]\b"#, options: []) {
                if nxRegex.firstMatch(in: working, range: NSRange(location: 0, length: (working as NSString).length)) != nil {
                    detectedAnswer = "No"
                }
            }
        }

        // 3. Strip all checkbox+word pairs inline — both Unicode and text-based.
        if let cbRegex = try? NSRegularExpression(pattern: #"[☐☑☒✓✗□■]\s*(?:Yes|No|N/?A)\s*"#, options: .caseInsensitive) {
            working = cbRegex.stringByReplacingMatches(in: working, range: NSRange(location: 0, length: (working as NSString).length), withTemplate: " ")
        }
        for ch in ["☐", "☑", "☒", "✓", "✗", "□", "■"] {
            working = working.replacingOccurrences(of: ch, with: " ")
        }
        // Text-based: "[X] Yes", "[ ] No", "Yes [X]", "No [ ]", standalone "[ ]", "[X]"
        if let tbCbRegex = try? NSRegularExpression(pattern: #"\[\s*[Xx]?\s*\]\s*(?:Yes|No|N/?A)?\s*"#, options: .caseInsensitive) {
            working = tbCbRegex.stringByReplacingMatches(in: working, range: NSRange(location: 0, length: (working as NSString).length), withTemplate: " ")
        }
        if let tbCbRegex2 = try? NSRegularExpression(pattern: #"(?:Yes|No|N/?A)\s*\[\s*[Xx]?\s*\]\s*"#, options: .caseInsensitive) {
            working = tbCbRegex2.stringByReplacingMatches(in: working, range: NSRange(location: 0, length: (working as NSString).length), withTemplate: " ")
        }
        // Strip standalone "x" markers next to Yes/No: "No x" or "Yes x" → just space
        if let xMarkerRegex = try? NSRegularExpression(pattern: #"(Yes|No)\s+[xX]\b"#, options: []) {
            working = xMarkerRegex.stringByReplacingMatches(in: working, range: NSRange(location: 0, length: (working as NSString).length), withTemplate: "$1")
        }
        if let xMarkerRegex2 = try? NSRegularExpression(pattern: #"\b[xX]\s+(Yes|No)"#, options: []) {
            working = xMarkerRegex2.stringByReplacingMatches(in: working, range: NSRange(location: 0, length: (working as NSString).length), withTemplate: "$1")
        }
        working = working.replacingOccurrences(of: "  +", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)

        // 4. Strip known question titles from the start (loop to handle stacked questions/sub-questions)
        let normalizeQ: (String) -> String = {
            $0.replacingOccurrences(of: "\u{2019}", with: "'")
              .replacingOccurrences(of: "\u{2018}", with: "'")
              .replacingOccurrences(of: "\u{201C}", with: "\"")
              .replacingOccurrences(of: "\u{201D}", with: "\"")
        }

        // SCT template question texts — longest first, all lowercased
        let knownTitles: [String] = [
            // Section 25/26 — detention/treatment justification (longest first)
            "in section 2 cases is the detention in hospital justifiable or necessary in the interests of the patient's health or safety, or for the protection of others",
            "in section 2 cases, is the detention in hospital justifiable or necessary in the interests of the patient's health or safety, or for the protection of others",
            "in section 2 cases is detention in hospital justified or necessary in the interests of the patient's health or safety, or for the protection of others",
            "in section 2 cases, is detention in hospital justified or necessary in the interests of the patient's health or safety, or for the protection of others",
            "in all other cases is the provision of medical treatment in hospital, justifiable or necessary in the interests of the patient's health or safety, or for the protection of others",
            "in all other cases, is the provision of medical treatment in hospital, justifiable or necessary in the interests of the patient's health or safety, or for the protection of others",
            "in all other cases is the provision of medical treatment in hospital justified or necessary in the interests of the patient's health or safety, or for the protection of others",
            "in all other cases, is the provision of medical treatment in hospital justified or necessary in the interests of the patient's health or safety, or for the protection of others",
            // Section 27 — discharge risk
            "if the patient was discharged from hospital, would they be likely to act in a manner dangerous to themselves or others",
            "if the patient was discharged from hospital, would they likely to act in a manner dangerous to themselves or others",
            "if the patient were discharged from hospital, would they be likely to act in a manner dangerous to themselves or others",
            "if the patient were discharged from hospital, would they likely to act in a manner dangerous to themselves or others",
            // Section 24 — MCA/DoL
            "in the case of an eligible compliant patient who lacks capacity to agree or object to their detention or treatment, say whether or not deprivation of liberty under the mental capacity act 2005 (as amended) would be appropriate and less restrictive",
            "deprivation of liberty under the mental capacity act 2005",
            // Section 21 — NR inappropriate
            "if (having consulted the patient) it was considered inappropriate or impractical to consult the nearest relative, what were the reasons for this and what attempts have been made to rectify matters",
            "if it was considered inappropriate or impractical to consult the nearest relative, what were the reasons",
            // Section 22 — carer views
            "what are the views of any other person who takes a lead role in the care and support of the patient but who is not professionally involved",
            "what are the views of any other person who takes a lead role in the care and support of the patient",
            // Section 20 — nearest relative
            "other than in restricted cases, what are the views of the patient's nearest relative",
            "what are the views of the patient's nearest relative",
            // Section 19 — patient views
            "what are the patient's views, wishes, beliefs, opinions, hopes and concerns",
            "what are the patient's views, wishes, beliefs, opinions",
            "the patient's views, wishes, beliefs",
            // Section 17 — harm incidents
            "give details of any incidents in hospital where the patient has harmed themselves or others, or threatened to harm themselves or others",
            "give details of any incidents in hospital where the patient has harmed themselves or others or threatened to harm themselves or others",
            "give details of any incidents in hospital where the patient has harmed themselves or others, or threatened harm to others",
            "give details of any incidents in hospital where the patient has harmed themselves or others",
            "give details of any incidents where the patient has harmed themselves or others, or threatened harm to others",
            "give details of any incidents where the patient has harmed themselves or others",
            // Section 18 — property damage
            "give details of any incidents where the patient has damaged property, or threatened to damage property",
            "give details of any incidents where the patient has damaged property",
            // Section 16 — progress
            "give a summary of the patient's current progress, behaviour, compliance and insight",
            "give a summary of the patient's current progress, behaviour, compliance",
            "give a summary of the patient's current progress",
            // Section 15 — strengths
            "what are the strengths or positive factors relating to the patient",
            // Section 14 — funding
            "are there any issues as to funding the proposed care plan",
            "are there any issues as to funding the propose care plan",
            "by what date will those issues be resolved",
            // Section 13 — adequacy
            "how adequate or effective is the proposed care plan likely to be",
            // Section 12 — care plan
            "give details of the proposed care plan",
            // Section 11 — care pathway
            "what care pathway and section 117 after-care will be made available to the patient",
            "what care pathway and section 117 aftercare will be made available to the patient",
            // Section 10 — previous community support
            "what was the patient's previous response to community support or section 117 aftercare",
            "what was the patient's previous response to community support",
            "previous response to community support",
            // Section 9 — employment
            "if the patient were discharged are there any available opportunities for employment",
            "if the patient was discharged are there any available opportunities for employment",
            "are there any available opportunities for employment",
            // Section 8 — financial
            "what is/would be the patient's financial position (including benefit entitlements)",
            "what is/would be the patient's financial position",
            "what is the patient's financial position",
            // Section 7 — housing
            "if discharged, what housing or accommodation would be available to the patient",
            "if discharged what housing or accommodation would be available to the patient",
            "what housing or accommodation would be available",
            // Section 6 — home/family
            "what are the patient's home and family circumstances",
            "the patient's home and family circumstances",
            // Section 5 — previous MH
            "what are the dates of the patient's previous involvement with mental health services, including any admissions to, discharge from and recall to hospital",
            "what are the dates of the patient's previous involvement with mental health services",
            "previous involvement with mental health services",
            // Section 4 — forensic history
            "give details of any index offence(s) and other relevant forensic history",
            "give details of any index offences and other relevant forensic history",
            "index offence(s) and other relevant forensic history",
            // Section 3 — adjustments
            "are there are any adjustments that the tribunal may consider in order to deal with the case fairly and justly",
            "are there any adjustments that the tribunal may consider in order to deal with the case fairly and justly",
            "are there are any adjustments that the panel may consider in order to deal with the case fairly and justly",
            "are there any adjustments that the panel may consider in order to deal with the case fairly and justly",
            // Section 2 — factors
            "are there are any factors that may affect the patient's understanding or ability to cope with a hearing",
            "are there any factors that may affect the patient's understanding or ability to cope with a hearing",
            // Section 28 — recommendations
            "please provide your recommendations and the reasons for them, in the box below",
            "please provide your recommendations and the reasons for them",
            "do you have any recommendations to the tribunal",
            "do you have any recommendations to the panel",
            // Section 23 — MAPPA
            "is the patient known to any mappa meeting or agency",
            "in which area, for why reason and at what level",
            "in which area, for what reason and at what level",
            "what is the name of the chair of the mappa meeting concerned with the patient",
            "what is the name of the representative of the lead agency",
            // Sub-questions / sub-headings
            "please explain how risks could be managed effectively in the community, including the use of any lawful conditions or recall powers",
            "please explain how risks could be managed effectively in the community",
            "information recorded on clinical notes",
            "psychiatric history recorded on clinical notes",
            "summary of incidents as recorded in clinical notes",
            // Yes/No sub-questions
            "yes - what are they",
            "yes \u{2013} what are they",
            "yes, give details below",
            "yes give details below",
            "if yes, what are they",
            "if yes what are they",
            "if yes, give details",
            "if yes give details",
            "if yes, please explain",
            "if yes please explain",
            "give details below",
            "what are they",
            // Notes / instructions
            "note: this report must be up-to-date and specifically prepared for the tribunal",
            "note: this report must be up-to-date and specifically prepared for the panel",
            "note: in the event that a mappa meeting or agency wishes to put forward evidence",
            // Broken-word artifacts from XML extraction
            "n ot applicable",
            // Generic labels
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
        if let residual = try? NSRegularExpression(
            pattern: #"^(?:(?:Yes|No)\s*){1,2}[-–—]?\s*(?:If\s+(?:yes|no)\s*[,:]?\s*)?(?:what are they|give details(?:\s+below)?|please (?:give|provide|explain)\b[^.?:]*)\s*[?:.]?\s*"#,
            options: .caseInsensitive
        ) {
            let ns = working as NSString
            if let m = residual.firstMatch(in: working, range: NSRange(location: 0, length: ns.length)) {
                let stripped = ns.substring(from: m.range.upperBound).trimmingCharacters(in: .whitespacesAndNewlines)
                if !stripped.isEmpty {
                    if detectedAnswer == nil {
                        let prefix = ns.substring(with: NSRange(location: 0, length: min(3, ns.length))).lowercased()
                        detectedAnswer = prefix.hasPrefix("yes") ? "Yes" : prefix.hasPrefix("no") ? "No" : nil
                    }
                    working = stripped
                }
            }
        }

        // 5b. Strip standalone "No" / "Yes" at the very start when followed by real content
        // (SC report sometimes has "No Yes x" or "No X - no formal employment Yes a What are they?" patterns)
        if let standaloneYN = try? NSRegularExpression(pattern: #"^(?:(?:Yes|No)\s+){1,2}(?:[xXa]\s+)?[-–—]?\s*"#, options: []) {
            let ns = working as NSString
            if let m = standaloneYN.firstMatch(in: working, range: NSRange(location: 0, length: ns.length)) {
                let remainder = ns.substring(from: m.range.upperBound).trimmingCharacters(in: .whitespacesAndNewlines)
                // Only strip if there's substantial content after
                if remainder.count > 10 {
                    working = remainder
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
        // Strip MAPPA note blocks (can appear mid-text, so no ^ anchor)
        if let mappaNote = try? NSRegularExpression(pattern: #"Note:\s*In the event that a MAPPA meeting.*?(?:should be attached to this report[.;]?)\s*"#, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            let ns = working as NSString
            working = mappaNote.stringByReplacingMatches(in: working, range: NSRange(location: 0, length: ns.length), withTemplate: "").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // 7. Skip trivial content
        let finalLower = working.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if finalLower == "see above" || finalLower == "as above" || finalLower == "refer to above" ||
           finalLower == "as per above" || finalLower == "n/a" || finalLower == "na" || finalLower == "nil" ||
           finalLower == "not applicable" || finalLower == "not applicable." ||
           finalLower == "n ot applicable" || finalLower == "n ot applicable." {
            working = ""
        }

        working = working.trimmingCharacters(in: .whitespacesAndNewlines)

        // 8. For Yes/No sections: prepend detected answer so parseYesNo/stripYesNoPrefix can handle it
        if let answer = detectedAnswer {
            if working.isEmpty { return answer }
            return "\(answer)\n\(working)"
        }

        NSLog("[SCT clean] result (%d chars): %@", working.count, String(working.prefix(120)))
        return working
    }

    // MARK: - Report Population

    private func populateFromReport(_ sections: [STRSection: String]) {
        // Clear existing imported entries
        formData.forensicImported.removeAll()
        formData.previousMHImported.removeAll()
        formData.homeFamilyImported.removeAll()
        formData.housingImported.removeAll()
        formData.financialImported.removeAll()
        formData.strengthsImported.removeAll()
        formData.progressImported.removeAll()
        formData.riskHarmImported.removeAll()
        formData.riskPropertyImported.removeAll()
        formData.recommendationsImported.removeAll()

        func makeEntry(_ text: String) -> TribunalImportedEntry {
            TribunalImportedEntry(date: nil, text: text, snippet: String(text.prefix(200)), selected: false, categories: ["Report"])
        }

        // Section 1: Patient Details — parse inline text using keyword boundaries.
        if let text = sections[.patientDetails], !text.isEmpty {
            let lower = text.lowercased()
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
                    formData.patientName = value
                case "dob":
                    if formData.patientDOB == nil {
                        let digitsOnly = value.filter { $0.isNumber }
                        var dobCandidates = [value]
                        let stripped = value.replacingOccurrences(
                            of: #"(\d{1,2})(st|nd|rd|th)\b"#, with: "$1", options: .regularExpression)
                        if stripped != value { dobCandidates.append(stripped) }
                        // Strip commas: "18 July, 1991" → "18 July 1991"
                        let noComma = stripped.replacingOccurrences(of: ",", with: "")
                        if noComma != stripped { dobCandidates.append(noComma) }
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
                    let g = value.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                    if g.hasPrefix("f") { formData.patientGender = .female }
                    else if g.hasPrefix("m") { formData.patientGender = .male }
                case "nhs":
                    if formData.nhsNumber.isEmpty {
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
            NSLog("[SCT iOS] Section 1 parsed: name='%@' dob=%@ gender=%@ nhs='%@' hosp='%@' addr='%@'",
                  formData.patientName, formData.patientDOB?.description ?? "nil",
                  formData.patientGender.rawValue, formData.nhsNumber,
                  formData.hospitalNumber, formData.currentLocation)
        }

        // Section 2: Factors affecting hearing (Yes/No + details + factor radio) + card text
        if let text = sections[.factorsHearing], !text.isEmpty {
            let answer = parseYesNo(text)
            formData.hasFactorsAffectingHearing = (answer == true)
            let detail = stripYesNoPrefix(text)
            if !detail.isEmpty {
                formData.factorsDetails = detail
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

        // Section 4: Forensic History → narrative + imported array + card text
        if let text = sections[.forensicHistory], !text.isEmpty {
            formData.forensicHistoryNarrative = text
            formData.forensicImported.append(makeEntry(text))
        }

        // Section 5: Previous MH → narrative + imported array + card text
        if let text = sections[.previousMH], !text.isEmpty {
            formData.previousMHNarrative = text
            formData.previousMHImported.append(makeEntry(text))
        }

        // Section 6: Home and Family → narrative + imported + card text
        if let text = sections[.homeFamily], !text.isEmpty {
            formData.homeFamilyNarrative = text
            formData.homeFamilyImported.append(makeEntry(text))
        }

        // Section 7: Housing → narrative + imported + card text
        if let text = sections[.housing], !text.isEmpty {
            formData.housingNarrative = text
            formData.housingImported.append(makeEntry(text))
        }

        // Section 8: Financial → narrative + imported + card text
        if let text = sections[.financial], !text.isEmpty {
            formData.financialNarrative = text
            formData.financialImported.append(makeEntry(text))
        }

        // Section 9: Employment (Yes/No + details) + card text
        if let text = sections[.employment], !text.isEmpty {
            let answer = parseYesNo(text)
            formData.hasEmploymentOpportunities = (answer == true)
            let detail = stripYesNoPrefix(text)
            if !detail.isEmpty { formData.employmentDetails = detail }
        }

        // Section 10: Previous Community Support → narrative + card text
        if let text = sections[.previousCommunity], !text.isEmpty {
            formData.previousCommunityNarrative = text
        }

        // Section 11: Care Pathway → narrative + card text
        if let text = sections[.carePathway], !text.isEmpty {
            formData.carePathwayNarrative = text
        }

        // Section 12: Care Plan → narrative + card text
        if let text = sections[.carePlan], !text.isEmpty {
            formData.carePlanNarrative = text
        }

        // Section 13: Care Plan Adequacy → details + card text
        if let text = sections[.carePlanAdequacy], !text.isEmpty {
            formData.carePlanAdequacyDetails = text
        }

        // Section 14: Care Plan Funding (Yes/No + details) + card text
        if let text = sections[.carePlanFunding], !text.isEmpty {
            let answer = parseYesNo(text)
            if answer == true {
                formData.carePlanFunding = "Issues identified"
            } else if answer == false {
                formData.carePlanFunding = "Confirmed"
            }
            let detail = stripYesNoPrefix(text)
            if !detail.isEmpty { formData.carePlanFundingDetails = detail }
        }

        // Section 15: Strengths → narrative + imported + card text
        if let text = sections[.strengths], !text.isEmpty {
            formData.strengthsNarrative = text
            formData.strengthsImported.append(makeEntry(text))
        }

        // Section 16: Progress → narrative + imported + card text
        if let text = sections[.progress], !text.isEmpty {
            formData.progressNarrative = text
            formData.progressImported.append(makeEntry(text))
        }

        // Section 17: Risk Harm → imported array + auto-set risk toggles + card text
        if let text = sections[.riskHarm], !text.isEmpty {
            formData.riskHarmImported.append(makeEntry(text))
            let lower = text.lowercased()
            if lower.contains("assault") && lower.contains("staff") { formData.harmAssaultStaff = true }
            if lower.contains("assault") && lower.contains("patient") { formData.harmAssaultPatients = true }
            if lower.contains("assault") && lower.contains("public") { formData.harmAssaultPublic = true }
            if lower.contains("verbal") || lower.contains("aggression") || lower.contains("swear") || lower.contains("abusive") { formData.harmVerbalAggression = true }
            if lower.contains("self-harm") || lower.contains("self harm") || lower.contains("pulled his toenail") { formData.harmSelfHarm = true }
            if lower.contains("suicid") || lower.contains("wanted to die") || lower.contains("kill himself") { formData.harmSuicidal = true }
        }

        // Section 18: Risk Property → imported array + auto-set toggles + card text
        if let text = sections[.riskProperty], !text.isEmpty {
            formData.riskPropertyImported.append(makeEntry(text))
            let lower = text.lowercased()
            if lower.contains("ward") || lower.contains("unit") { formData.propertyWard = true }
            if lower.contains("personal") || lower.contains("belonging") { formData.propertyPersonal = true }
            if lower.contains("fire") || lower.contains("arson") { formData.propertyFire = true }
            if lower.contains("graffiti") { formData.propertyWard = true }
        }

        // Section 19: Patient Views → narrative + card text
        if let text = sections[.patientViews], !text.isEmpty {
            formData.patientViewsNarrative = text
        }

        // Section 20: Nearest Relative → narrative + card text
        if let text = sections[.nearestRelative], !text.isEmpty {
            formData.nearestRelativeViews = text
        }

        // Section 21: NR Inappropriate → narrative + card text
        if let text = sections[.nrInappropriate], !text.isEmpty {
            formData.nrInappropriateReason = text
        }

        // Section 22: Carer Views → narrative + card text
        if let text = sections[.carerViews], !text.isEmpty {
            formData.carerViews = text
        }

        // Section 23: MAPPA (Yes/No + details) + card text
        if let text = sections[.mappa], !text.isEmpty {
            let answer = parseYesNo(text)
            formData.mappaInvolved = (answer == true)
            let detail = stripYesNoPrefix(text)
            if !detail.isEmpty { formData.mappaNarrative = detail }
        }

        // Section 24: MCA DoL → details + card text
        if let text = sections[.mcaDoL], !text.isEmpty {
            formData.mcaDetails = text
        }

        // Section 25: S2 Detention (Yes/No) — inline card
        if let text = sections[.s2Detention], !text.isEmpty {
            let answer = parseYesNo(text)
            formData.s2DetentionJustified = (answer ?? true)
            let detail = stripYesNoPrefix(text)
                .replacingOccurrences(of: #"^\s*N\s*/?\s*A\s*$"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !detail.isEmpty { formData.s2Explanation = detail }
        }

        // Section 26: Other Detention (Yes/No) — inline card
        if let text = sections[.otherDetention], !text.isEmpty {
            let answer = parseYesNo(text)
            formData.otherDetentionJustified = (answer ?? true)
            let detail = stripYesNoPrefix(text)
                .replacingOccurrences(of: #"^\s*N\s*/?\s*A\s*$"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !detail.isEmpty { formData.otherDetentionExplanation = detail }
        }

        // Section 27: Discharge Risk — populate details + auto-set risk toggles + card text
        if let text = sections[.dischargeRisk], !text.isEmpty {
            let detail = stripYesNoPrefix(text)
            formData.dischargeRiskDetails = detail.isEmpty ? text : detail
            let lower = text.lowercased()
            if lower.contains("violence") || lower.contains("arson") { formData.dischargeRiskViolence = true }
            if lower.contains("self-harm") || lower.contains("suicide") { formData.dischargeRiskSelfHarm = true }
            if lower.contains("neglect") { formData.dischargeRiskNeglect = true }
            if lower.contains("exploit") { formData.dischargeRiskExploitation = true }
            if lower.contains("relapse") { formData.dischargeRiskRelapse = true }
            if lower.contains("compliance") || lower.contains("non-compliance") || lower.contains("non-compliant") { formData.dischargeRiskNonCompliance = true }
        }

        // Section 28: Recommendations → imported array + card text
        if let text = sections[.recommendations], !text.isEmpty {
            formData.recommendationsImported.append(makeEntry(text))
        }

        // Sections that don't exist in the 28-section DOCX but exist in app (29=otherInfo, 30=recommendations/legal, 31=signature)
        // — skip, they'll be filled manually or from other sources

        print("[SCT iOS] populateFromReport complete: \(sections.count) sections mapped")
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

// MARK: - STR Popup View
struct STRPopupView: View {
    let section: SocialTribunalReportView.STRSection
    @Binding var formData: SocialTribunalFormData
    let manualNotes: String
    let onGenerate: (String, String) -> Void
    let onDismiss: () -> Void

    @State private var editableNotes: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    popupContent

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
        .onAppear { editableNotes = manualNotes }
    }

    @ViewBuilder
    private var popupContent: some View {
        switch section {
        case .patientDetails: patientDetailsPopup
        case .factorsHearing: factorsHearingPopup
        case .adjustments: adjustmentsPopup
        case .forensicHistory: forensicHistoryPopup
        case .previousMH: previousMHPopup
        case .homeFamily: homeFamilyPopup
        case .housing: housingPopup
        case .financial: financialPopup
        case .employment: employmentPopup
        case .previousCommunity: previousCommunityPopup
        case .carePathway: carePathwayPopup
        case .carePlan: carePlanPopup
        case .carePlanAdequacy: carePlanAdequacyPopup
        case .carePlanFunding: carePlanFundingPopup
        case .strengths: strengthsPopup
        case .progress: progressPopup
        case .riskHarm: riskHarmPopup
        case .riskProperty: riskPropertyPopup
        case .patientViews: patientViewsPopup
        case .nearestRelative: nearestRelativePopup
        case .nrInappropriate: nrInappropriatePopup
        case .carerViews: carerViewsPopup
        case .mappa: mappaPopup
        case .mcaDoL: mcaDoLPopup
        case .s2Detention: s2DetentionPopup
        case .otherDetention: otherDetentionPopup
        case .dischargeRisk: dischargeRiskPopup
        case .communityManagement: communityManagementPopup
        case .otherInfo: otherInfoPopup
        case .recommendations: recommendationsPopup
        case .signature: signaturePopup
        }
    }

    // MARK: - Section Popups
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
            FormOptionalDatePicker(label: "Date of Birth", date: $formData.patientDOB, maxDate: Date())
            FormTextField(label: "Hospital Number", text: $formData.hospitalNumber)
            FormTextField(label: "NHS Number", text: $formData.nhsNumber)
            FormTextField(label: "Current Location", text: $formData.currentLocation)
            FormOptionalDatePicker(label: "Admission Date", date: $formData.admissionDate)
        }
    }

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

    private var forensicHistoryPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            FormTextField(label: "Index Offence", text: $formData.indexOffence)
            FormOptionalDatePicker(label: "Date of Offence", date: $formData.indexOffenceDate)
            FormTextEditor(label: "Forensic History", text: $formData.forensicHistoryNarrative, minHeight: 100)
            if !formData.forensicImported.isEmpty {
                TribunalCollapsibleSection(title: "Imported Notes (\(formData.forensicImported.count))", color: .yellow) {
                    TribunalImportedEntriesList(entries: $formData.forensicImported)
                }
            }
        }
    }

    private var previousMHPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Previous involvement with mental health services").font(.headline)
            FormTextEditor(label: "Narrative", text: $formData.previousMHNarrative, minHeight: 100)
            if !formData.previousMHImported.isEmpty {
                TribunalCollapsibleSection(title: "Imported Notes (\(formData.previousMHImported.count))", color: .yellow) {
                    TribunalImportedEntriesList(entries: $formData.previousMHImported)
                }
            }
        }
    }

    private var homeFamilyPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Home and Family Circumstances").font(.headline)
            FormTextEditor(label: "Narrative", text: $formData.homeFamilyNarrative, minHeight: 100)
            if !formData.homeFamilyImported.isEmpty {
                TribunalCollapsibleSection(title: "Imported Notes (\(formData.homeFamilyImported.count))", color: .yellow) {
                    TribunalImportedEntriesList(entries: $formData.homeFamilyImported)
                }
            }
        }
    }

    private var housingPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Housing or Accommodation if Discharged").font(.headline)
            FormTextEditor(label: "Narrative", text: $formData.housingNarrative, minHeight: 100)
            if !formData.housingImported.isEmpty {
                TribunalCollapsibleSection(title: "Imported Notes (\(formData.housingImported.count))", color: .yellow) {
                    TribunalImportedEntriesList(entries: $formData.housingImported)
                }
            }
        }
    }

    private var financialPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Financial Position and Benefit Entitlements").font(.headline)
            FormTextEditor(label: "Narrative", text: $formData.financialNarrative, minHeight: 100)
            if !formData.financialImported.isEmpty {
                TribunalCollapsibleSection(title: "Imported Notes (\(formData.financialImported.count))", color: .yellow) {
                    TribunalImportedEntriesList(entries: $formData.financialImported)
                }
            }
        }
    }

    private var employmentPopup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Employment Opportunities if Discharged").font(.headline)
            Toggle("Has employment opportunities", isOn: $formData.hasEmploymentOpportunities)
            if formData.hasEmploymentOpportunities {
                FormTextEditor(label: "Details", text: $formData.employmentDetails, minHeight: 80)
            }
        }
    }

    private var previousCommunityPopup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Previous Response to Community Support").font(.headline)
            FormTextEditor(label: "Narrative", text: $formData.previousCommunityNarrative, minHeight: 120)
        }
    }

    private var carePathwayPopup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Care Pathway and Section 117 After-care").font(.headline)
            FormTextEditor(label: "Narrative", text: $formData.carePathwayNarrative, minHeight: 120)
        }
    }

    private var carePlanPopup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Proposed Care Plan").font(.headline)
            FormTextEditor(label: "Narrative", text: $formData.carePlanNarrative, minHeight: 150)
        }
    }

    private var carePlanAdequacyPopup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Adequacy of Proposed Care Plan").font(.headline)
            VStack(alignment: .leading, spacing: 4) {
                Text("Adequacy").font(.subheadline).foregroundColor(.secondary)
                Picker("", selection: $formData.carePlanAdequacy) {
                    Text("Adequate").tag("Adequate")
                    Text("Partially adequate").tag("Partially adequate")
                    Text("Inadequate").tag("Inadequate")
                    Text("Under review").tag("Under review")
                }
                .pickerStyle(.menu)
            }
            FormTextEditor(label: "Details", text: $formData.carePlanAdequacyDetails, minHeight: 80)
        }
    }

    private var carePlanFundingPopup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Funding Issues for Proposed Care Plan").font(.headline)
            VStack(alignment: .leading, spacing: 4) {
                Text("Funding Status").font(.subheadline).foregroundColor(.secondary)
                Picker("", selection: $formData.carePlanFunding) {
                    Text("Confirmed").tag("Confirmed")
                    Text("Pending").tag("Pending")
                    Text("Issues identified").tag("Issues identified")
                    Text("Not applicable").tag("Not applicable")
                }
                .pickerStyle(.menu)
            }
            FormTextEditor(label: "Details", text: $formData.carePlanFundingDetails, minHeight: 80)
        }
    }

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

    private var progressPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Current Progress, Behaviour, Compliance").font(.headline)

            // Auto-generated narrative summary section (matching desktop Section 14 style)
            if !formData.progressImported.isEmpty {
                SocialNarrativeSummarySection(
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

    private var patientViewsPopup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Patient's Views, Wishes, Beliefs, Opinions").font(.headline)
            VStack(alignment: .leading, spacing: 4) {
                Text("Views on discharge").font(.subheadline).foregroundColor(.secondary)
                Picker("", selection: $formData.patientViewsDischarge) {
                    Text("Keen for discharge").tag("Keen for discharge")
                    Text("Moving towards discharge").tag("Moving towards discharge")
                    Text("Ambivalent").tag("Ambivalent")
                    Text("Unsure").tag("Unsure")
                }
                .pickerStyle(.menu)
            }
            FormTextEditor(label: "Views narrative", text: $formData.patientViewsNarrative, minHeight: 80)
            FormTextEditor(label: "Concerns", text: $formData.patientConcerns, minHeight: 60)
            FormTextEditor(label: "Hopes", text: $formData.patientHopes, minHeight: 60)
        }
    }

    private var nearestRelativePopup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nearest Relative Views").font(.headline)
            FormTextField(label: "Name", text: $formData.nearestRelativeName)
            FormTextField(label: "Relationship", text: $formData.nearestRelativeRelationship)
            FormTextEditor(label: "Views", text: $formData.nearestRelativeViews, minHeight: 100)
        }
    }

    private var nrInappropriatePopup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reasons if Inappropriate to Consult Nearest Relative").font(.headline)
            FormTextEditor(label: "Reasons", text: $formData.nrInappropriateReason, minHeight: 100)
        }
    }

    private var carerViewsPopup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Views of Other Person Taking Lead Role in Care").font(.headline)
            FormTextField(label: "Name", text: $formData.carerName)
            FormTextField(label: "Role", text: $formData.carerRole)
            FormTextEditor(label: "Views", text: $formData.carerViews, minHeight: 100)
        }
    }

    private var mappaPopup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MAPPA Involvement").font(.headline)
            Toggle("MAPPA involved", isOn: $formData.mappaInvolved)
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
            FormTextEditor(label: "Details", text: $formData.mappaNarrative, minHeight: 80)
        }
    }

    private var mcaDoLPopup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MCA 2005 Deprivation of Liberty").font(.headline)
            Toggle("DoLS authorisation in place", isOn: $formData.dolsInPlace)
            VStack(alignment: .leading, spacing: 4) {
                Text("Floating provision").font(.subheadline).foregroundColor(.secondary)
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

    private var s2DetentionPopup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Section 2: Is detention justified?").font(.subheadline)
            Picker("", selection: $formData.s2DetentionJustified) {
                Text("No").tag(false)
                Text("Yes").tag(true)
            }
            .pickerStyle(.segmented)
            FormTextEditor(label: "Explanation", text: $formData.s2Explanation, minHeight: 100)
        }
    }

    private var otherDetentionPopup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Other sections: Is treatment justified?").font(.subheadline)
            Picker("", selection: $formData.otherDetentionJustified) {
                Text("No").tag(false)
                Text("Yes").tag(true)
            }
            .pickerStyle(.segmented)
            FormTextEditor(label: "Explanation", text: $formData.otherDetentionExplanation, minHeight: 100)
        }
    }

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
        }
    }

    private var otherInfoPopup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Other Relevant Information").font(.headline)
            FormTextEditor(label: "Details", text: $formData.otherInfoNarrative, minHeight: 120)
        }
    }

    private var recommendationsPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Mental Disorder").font(.headline)
            sctLegalRadio(label: "Present", altLabel: "Absent", selection: $formData.recMdPresent)

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
                sctLegalRadio(label: "Met", altLabel: "Not Met", selection: $formData.recCwdMet)

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
                sctLegalRadio(label: "Yes", altLabel: "No", selection: $formData.recNecessary)

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

    private func sctLegalRadio(label: String, altLabel: String, selection: Binding<Bool?>) -> some View {
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
            return parts.joined(separator: "\n")

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

        case .dischargeRisk:
            var risks: [String] = []
            if formData.dischargeRiskViolence { risks.append("violence") }
            if formData.dischargeRiskSelfHarm { risks.append("self-harm") }
            if formData.dischargeRiskNeglect { risks.append("self-neglect") }
            if formData.dischargeRiskExploitation { risks.append("exploitation") }
            if formData.dischargeRiskRelapse { risks.append("relapse") }
            if formData.dischargeRiskNonCompliance { risks.append("non-compliance") }
            var text = risks.isEmpty ? "No significant discharge risks identified." : "Discharge risks: " + risks.joined(separator: ", ") + "."
            if !formData.dischargeRiskDetails.isEmpty { text += "\n\n\(formData.dischargeRiskDetails)" }
            return text

        case .recommendations:
            var text = generateSctLegalCriteriaText()
            let recImported = selectedEntryText(formData.recommendationsImported)
            if !recImported.isEmpty { text += (text.isEmpty ? "" : "\n\n") + recImported }
            return text

        case .signature:
            var parts: [String] = []
            if !formData.signatureName.isEmpty { parts.append(formData.signatureName) }
            if !formData.signatureDesignation.isEmpty { parts.append(formData.signatureDesignation) }
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            parts.append("Date: \(formatter.string(from: formData.signatureDate))")
            return parts.joined(separator: "\n")

        case .factorsHearing:
            let pronoun = socialGenderPronoun(formData.patientGender)
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
            let pronoun = socialGenderPronoun(formData.patientGender)
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
            return formData.forensicHistoryNarrative

        case .previousMH:
            return formData.previousMHNarrative

        case .homeFamily:
            return formData.homeFamilyNarrative

        case .housing:
            return formData.housingNarrative

        case .financial:
            return formData.financialNarrative

        case .employment:
            return formData.employmentDetails

        case .previousCommunity:
            return formData.previousCommunityNarrative

        case .carePathway:
            return formData.carePathwayNarrative

        case .carePlan:
            return formData.carePlanNarrative

        case .carePlanAdequacy:
            return formData.carePlanAdequacyDetails

        case .carePlanFunding:
            return formData.carePlanFundingDetails

        case .strengths:
            return formData.strengthsNarrative

        case .progress:
            return formData.progressNarrative

        case .riskProperty:
            var types: [String] = []
            if formData.propertyWard { types.append("ward property") }
            if formData.propertyPersonal { types.append("personal belongings") }
            if formData.propertyFire { types.append("fire setting") }
            if formData.propertyVehicle { types.append("vehicle damage") }
            var text = types.isEmpty ? "No significant property incidents reported." : "Property damage includes: " + types.joined(separator: ", ") + "."
            let rpImported = selectedEntryText(formData.riskPropertyImported)
            if !rpImported.isEmpty { text += "\n\n\(rpImported)" }
            return text

        case .patientViews:
            return formData.patientViewsNarrative

        case .nearestRelative:
            return formData.nearestRelativeViews

        case .nrInappropriate:
            return formData.nrInappropriateReason

        case .carerViews:
            return formData.carerViews

        case .mappa:
            return formData.mappaNarrative

        case .mcaDoL:
            return formData.mcaDetails

        case .communityManagement:
            return formData.communityPlanDetails

        case .otherInfo:
            return formData.otherInfoNarrative

        default:
            return ""
        }
    }

    private func selectedEntryText(_ entries: [TribunalImportedEntry]) -> String {
        let selected = entries.filter { $0.selected }
        if selected.isEmpty { return "" }
        return selected.map { $0.text }.joined(separator: "\n\n")
    }

    private func generateSctLegalCriteriaText() -> String {
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

    private func socialGenderPronoun(_ gender: Gender) -> (subj: String, obj: String, pos: String) {
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

// MARK: - Social Narrative Summary Section (matching desktop Section 14 style)

/// Generates and displays a clinical narrative summary for Social Circumstances
struct SocialNarrativeSummarySection: View {
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

                    Text("\(patientName) has been reviewed \(freqDesc) over the past \(months) months with \(entries.count) documented contacts. \(pronounPoss.capitalized) engagement with social work has been monitored throughout this period.")
                        .font(.caption)
                }
            }
        }
    }
}

#Preview {
    SocialTribunalReportView()
        .environment(AppStore())
        .environment(SharedDataStore.shared)
}
