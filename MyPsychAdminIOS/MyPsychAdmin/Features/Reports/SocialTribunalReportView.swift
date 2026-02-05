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
            prefillFromSharedData()
            initializeCardTexts()
            if !hasPopulatedFromSharedData && !sharedData.notes.isEmpty {
                populateFromClinicalNotes(sharedData.notes)
                hasPopulatedFromSharedData = true
            }
        }
        .onReceive(sharedData.notesDidChange) { notes in
            if !notes.isEmpty { populateFromClinicalNotes(notes) }
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isExporting = false
            exportError = "Export not yet implemented"
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
                        if !extractedDoc.notes.isEmpty {
                            sharedData.setNotes(extractedDoc.notes, source: "str_import")
                        }
                        if !extractedDoc.patientInfo.fullName.isEmpty {
                            formData.patientName = extractedDoc.patientInfo.fullName
                            if let dob = extractedDoc.patientInfo.dateOfBirth { formData.patientDOB = dob }
                            formData.patientGender = extractedDoc.patientInfo.gender
                        }
                        populateFromClinicalNotes(extractedDoc.notes)
                        isImporting = false
                        importStatusMessage = "Imported \(extractedDoc.notes.count) notes"
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Recommendations to Tribunal").font(.headline)
            VStack(alignment: .leading, spacing: 4) {
                Text("Recommendation").font(.subheadline).foregroundColor(.secondary)
                Picker("", selection: $formData.recommendation) {
                    Text("Continued detention").tag("Continued detention")
                    Text("Conditional discharge").tag("Conditional discharge")
                    Text("Absolute discharge").tag("Absolute discharge")
                    Text("Transfer").tag("Transfer")
                    Text("CTO").tag("CTO")
                }
                .pickerStyle(.menu)
            }
            FormTextEditor(label: "Rationale", text: $formData.recommendationRationale, minHeight: 120)
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
            if types.isEmpty { return "No significant incidents reported." }
            return "Incidents include: " + types.joined(separator: ", ") + "."

        case .dischargeRisk:
            var risks: [String] = []
            if formData.dischargeRiskViolence { risks.append("violence") }
            if formData.dischargeRiskSelfHarm { risks.append("self-harm") }
            if formData.dischargeRiskNeglect { risks.append("self-neglect") }
            if formData.dischargeRiskExploitation { risks.append("exploitation") }
            if formData.dischargeRiskRelapse { risks.append("relapse") }
            if formData.dischargeRiskNonCompliance { risks.append("non-compliance") }
            if risks.isEmpty { return "No significant discharge risks identified." }
            return "Discharge risks: " + risks.joined(separator: ", ") + "."

        case .recommendations:
            return "Recommendation: \(formData.recommendation)"

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

        default:
            return ""
        }
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
