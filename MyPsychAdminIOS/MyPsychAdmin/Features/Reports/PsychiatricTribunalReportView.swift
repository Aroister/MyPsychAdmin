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

    @State private var formData: PsychTribunalFormData
    @State private var validationErrors: [FormValidationError] = []

    // Card text content
    @State private var generatedTexts: [PTRSection: String] = [:]
    @State private var manualNotes: [PTRSection: String] = [:]

    // Popup control
    @State private var activePopup: PTRSection? = nil

    // Export states
    @State private var isExporting = false
    @State private var exportError: String?

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
    }

    // No persistence - data only exists for current session
    init() {
        _formData = State(initialValue: PsychTribunalFormData())
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
                    ForEach(PTRSection.allCases) { section in
                        TribunalEditableCard(
                            title: section.rawValue,
                            icon: section.icon,
                            color: "6366F1", // Purple theme for psychiatric tribunal
                            text: binding(for: section),
                            defaultHeight: section.defaultHeight,
                            onHeaderTap: { activePopup = section }
                        )
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Psychiatric Tribunal")
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
            PTRPopupView(
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
            importStatusMessage = "Processing file..."

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
                            sharedData.setNotes(extractedDoc.notes, source: "ptr_import")
                        }
                        if !extractedDoc.patientInfo.fullName.isEmpty {
                            formData.patientName = extractedDoc.patientInfo.fullName
                            if let dob = extractedDoc.patientInfo.dateOfBirth {
                                formData.patientDOB = dob
                            }
                            formData.patientGender = extractedDoc.patientInfo.gender
                        }
                        populateFromClinicalNotes(extractedDoc.notes)
                        isImporting = false
                        importStatusMessage = "Imported \(extractedDoc.notes.count) notes"
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

        // Build timeline to find admissions (matches desktop logic)
        let episodes = TimelineBuilder.buildTimeline(from: notes, allNotes: notes)
        let inpatientEpisodes = episodes.filter { $0.type == .inpatient }
        let calendar = Calendar.current

        // Get most recent admission for Section 8 (currentAdmission) filtering
        let mostRecentAdmission = inpatientEpisodes.last

        print("[PTR iOS] Found \(inpatientEpisodes.count) inpatient episodes")

        // Keywords for non-timeline sections
        let forensicKW = ["offence", "conviction", "court", "sentence", "index", "criminal", "arrest", "police"]
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
            // Only include notes that are admission clerking notes (within 14 days of each admission start)
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
            // Notes from 2 days before to 14 days after most recent admission
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

            // === Section 5: Forensic history (keyword-based) ===
            if forensicKW.contains(where: { text.lowercased().contains($0) }) {
                formData.forensicImported.append(TribunalImportedEntry(date: date, text: text, snippet: snippet))
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

        print("[PTR iOS] Populated: \(formData.previousMHImported.count) psych history (clerking), \(formData.admissionImported.count) current admission, \(formData.progressImported.count) progress")
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
                .background(Color(.systemGray6))
            }
            .buttonStyle(.plain)

            TextEditor(text: $text)
                .frame(height: editorHeight)
                .padding(8)
                .background(Color(.systemBackground))
                .scrollContentBackground(.hidden)

            ResizeHandle(height: $editorHeight)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
        .onAppear { editorHeight = defaultHeight }
    }
}

// MARK: - PTR Popup View
struct PTRPopupView: View {
    let section: PsychiatricTribunalReportView.PTRSection
    @Binding var formData: PsychTribunalFormData
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
        case .responsibleClinician: responsibleClinicianPopup
        case .factorsHearing: factorsHearingPopup
        case .adjustments: adjustmentsPopup
        case .forensicHistory: forensicHistoryPopup
        case .previousMHDates: previousMHDatesPopup
        case .previousAdmissionReasons: previousAdmissionReasonsPopup
        case .currentAdmission: currentAdmissionPopup
        case .diagnosis: diagnosisPopup
        case .learningDisability: learningDisabilityPopup
        case .detentionRequired: detentionRequiredPopup
        case .treatment: treatmentPopup
        case .strengths: strengthsPopup
        case .progress: progressPopup
        case .compliance: compliancePopup
        case .mcaDoL: mcaDoLPopup
        case .riskHarm: riskHarmPopup
        case .riskProperty: riskPropertyPopup
        case .s2Detention: s2DetentionPopup
        case .otherDetention: otherDetentionPopup
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
            FormOptionalDatePicker(label: "Date of Birth", date: $formData.patientDOB, maxDate: Date())
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
    private var forensicHistoryPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            FormTextField(label: "Index Offence", text: $formData.indexOffence)
            FormOptionalDatePicker(label: "Date of Offence", date: $formData.indexOffenceDate)
            FormTextEditor(label: "Relevant Forensic History", text: $formData.forensicHistoryNarrative, minHeight: 100)

            if !formData.forensicImported.isEmpty {
                TribunalCollapsibleSection(title: "Imported Notes (\(formData.forensicImported.count))", color: .yellow) {
                    TribunalImportedEntriesList(entries: $formData.forensicImported)
                }
            }
        }
    }

    // MARK: - Section 6: Previous MH Dates
    private var previousMHDatesPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Dates of previous involvement with mental health services")
                .font(.headline)

            if !formData.previousMHImported.isEmpty {
                TribunalCollapsibleSection(title: "Imported Notes (\(formData.previousMHImported.count))", color: .yellow) {
                    TribunalImportedEntriesList(entries: $formData.previousMHImported)
                }
            } else {
                Text("Import clinical notes to populate this section.")
                    .font(.caption).foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
        }
    }

    // MARK: - Section 7: Previous Admission Reasons
    private var previousAdmissionReasonsPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Reasons for previous admission or recall to hospital")
                .font(.headline)
            FormTextEditor(label: "Previous Admission Reasons", text: $formData.previousAdmissionReasons, minHeight: 100)

            if !formData.previousMHImported.isEmpty {
                TribunalCollapsibleSection(title: "Related Notes (\(formData.previousMHImported.count))", color: .yellow) {
                    TribunalImportedEntriesList(entries: $formData.previousMHImported)
                }
            }
        }
    }

    // MARK: - Section 8: Current Admission
    private var currentAdmissionPopup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Circumstances leading to current admission").font(.headline)
            FormTextEditor(label: "Narrative", text: $formData.currentAdmissionNarrative, minHeight: 120)

            if !formData.admissionImported.isEmpty {
                TribunalCollapsibleSection(title: "Imported Notes (\(formData.admissionImported.count))", color: .yellow) {
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

    // MARK: - Section 23: Recommendations
    private var recommendationsPopup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recommendations to Tribunal").font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text("Recommendation").font(.subheadline).foregroundColor(.secondary)
                Picker("", selection: $formData.recommendation) {
                    Text("Continued detention").tag("Continued detention")
                    Text("Conditional discharge").tag("Conditional discharge")
                    Text("Absolute discharge").tag("Absolute discharge")
                    Text("Transfer to another hospital").tag("Transfer to another hospital")
                    Text("Community Treatment Order").tag("Community Treatment Order")
                }
                .pickerStyle(.menu)
            }

            FormTextEditor(label: "Rationale", text: $formData.recommendationRationale, minHeight: 120)
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
            var parts: [String] = []
            if !formData.indexOffence.isEmpty { parts.append("Index Offence: \(formData.indexOffence)") }
            if let date = formData.indexOffenceDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                parts.append("Date: \(formatter.string(from: date))")
            }
            if !formData.forensicHistoryNarrative.isEmpty { parts.append("\n\(formData.forensicHistoryNarrative)") }
            let selected = formData.forensicImported.filter { $0.selected }
            if !selected.isEmpty {
                parts.append("\n--- From Notes ---")
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

            return parts.joined(separator: "\n")

        case .riskHarm:
            var types: [String] = []
            if formData.harmAssaultStaff { types.append("assault on staff") }
            if formData.harmAssaultPatients { types.append("assault on patients") }
            if formData.harmAssaultPublic { types.append("assault on public") }
            if formData.harmVerbalAggression { types.append("verbal aggression/threats") }
            if formData.harmSelfHarm { types.append("self-harm") }
            if formData.harmSuicidal { types.append("suicidal ideation/attempt") }
            if types.isEmpty { return "No significant incidents of harm reported." }
            var text = "Incidents include: " + types.joined(separator: ", ") + "."
            let selected = formData.riskHarmImported.filter { $0.selected }
            if !selected.isEmpty {
                text += "\n\n--- From Notes ---"
                for entry in selected { text += "\n\(entry.text)" }
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
            if risks.isEmpty { return "Risk factors if discharged: None identified." }
            var text = "Risk factors if discharged: " + risks.joined(separator: ", ") + "."
            if !formData.dischargeRiskDetails.isEmpty { text += "\n\n\(formData.dischargeRiskDetails)" }
            return text

        case .recommendations:
            var text = "Recommendation: \(formData.recommendation)"
            if !formData.recommendationRationale.isEmpty { text += "\n\n\(formData.recommendationRationale)" }
            return text

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

            return parts.joined(separator: " ")

        default:
            // For sections without specific generation, return the narrative or default
            return ""
        }
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

// MARK: - Gender Pronoun Helper
struct GenderPronouns {
    let subj: String   // He/She/They
    let obj: String    // him/her/them
    let pos: String    // his/her/their
    let reflex: String // himself/herself/themselves
}

func genderPronoun(_ gender: Gender) -> GenderPronouns {
    switch gender {
    case .male:
        return GenderPronouns(subj: "He", obj: "him", pos: "his", reflex: "himself")
    case .female:
        return GenderPronouns(subj: "She", obj: "her", pos: "her", reflex: "herself")
    case .other, .notSpecified:
        return GenderPronouns(subj: "They", obj: "them", pos: "their", reflex: "themselves")
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
