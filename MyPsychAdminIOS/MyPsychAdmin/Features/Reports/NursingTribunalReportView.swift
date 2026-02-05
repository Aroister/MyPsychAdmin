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
    }

    // No persistence - data only exists for current session
    init() {
        _formData = State(initialValue: NursingTribunalFormData())
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

                    ForEach(NTRSection.allCases) { section in
                        TribunalEditableCard(
                            title: section.rawValue,
                            icon: section.icon,
                            color: "10B981", // Green theme for nursing
                            text: binding(for: section),
                            defaultHeight: section.defaultHeight,
                            onHeaderTap: { activePopup = section }
                        )
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Nursing Tribunal")
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
            NTRPopupView(
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
                            sharedData.setNotes(extractedDoc.notes, source: "ntr_import")
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
}

// MARK: - NTR Popup View
struct NTRPopupView: View {
    let section: NursingTribunalReportView.NTRSection
    @Binding var formData: NursingTribunalFormData
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
        case .s2Detention: s2DetentionPopup
        case .otherDetention: otherDetentionPopup
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

    // MARK: - Section 15: S2 Detention
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

    // MARK: - Section 16: Other Detention
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
        }
    }

    // MARK: - Section 19: Other Info
    private var otherInfoPopup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Other Relevant Information").font(.headline)
            FormTextEditor(label: "Details", text: $formData.otherInfoNarrative, minHeight: 120)
        }
    }

    // MARK: - Section 20: Recommendations
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
            return parts.joined(separator: "\n")

        case .observationLevel:
            return "Observation level: \(formData.observationLevel)" + (formData.observationDetails.isEmpty ? "" : "\n\(formData.observationDetails)")

        case .compliance:
            return "Compliance: \(formData.complianceLevel)" + (formData.complianceNarrative.isEmpty ? "" : "\n\(formData.complianceNarrative)")

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
            return "Discharge risks: " + risks.joined(separator: ", ") + "." + (formData.dischargeRiskDetails.isEmpty ? "" : "\n\(formData.dischargeRiskDetails)")

        case .recommendations:
            return "Recommendation: \(formData.recommendation)" + (formData.recommendationRationale.isEmpty ? "" : "\n\(formData.recommendationRationale)")

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

        default:
            return ""
        }
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
