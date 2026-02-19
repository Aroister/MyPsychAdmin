//
//  CTOFormViews.swift
//  MyPsychAdmin
//
//  Form views for CTO1, CTO3, CTO4, CTO5, CTO7 - Popup-based card layout
//

import SwiftUI

// MARK: - CTO1 Form View (Community Treatment Order)
struct CTO1FormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var appStore
    @Environment(SharedDataStore.self) private var sharedData

    @State private var formData: CTO1FormData = CTO1FormData()
    @State private var activePopup: CTO1Section?
    @State private var validationErrors: [FormValidationError] = []
    @State private var docxURL: URL?
    @State private var isExporting = false
    @State private var showShareSheet = false
    @State private var exportError: String?

    enum CTO1Section: String, CaseIterable, Identifiable {
        case patientRC = "Patient / RC Details"
        case grounds = "Grounds for CTO"
        case conditions = "Conditions"
        case amhp = "AMHP Agreement"
        case signature = "Effective Date & Signatures"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .patientRC: return "person.2"
            case .grounds: return "doc.text"
            case .conditions: return "checklist"
            case .amhp: return "person.badge.shield.checkmark"
            case .signature: return "signature"
            }
        }
    }

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Form header
                    VStack(spacing: 8) {
                        Text("CTO1")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("Community Treatment Order")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)

                    FormValidationErrorView(errors: validationErrors) { error in
                        if let section = sectionForError(error) {
                            activePopup = section
                        }
                    }

                    // Section cards grid
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(CTO1Section.allCases) { section in
                            FormSectionCardWithStatus(
                                title: section.rawValue,
                                icon: section.icon,
                                preview: previewText(for: section),
                                color: .teal,
                                isComplete: isSectionComplete(section)
                            ) {
                                activePopup = section
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Form CTO1")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { exportDOCX() } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(isExporting)
                }
            }
            .onAppear { prefillFromSharedData() }
            .onDisappear { syncPatientDataToSharedStore() }
            .sheet(item: $activePopup) { section in
                CTO1PopupSheet(section: section, formData: $formData, patientInfo: sharedData.patientInfo)
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = docxURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    private func syncPatientDataToSharedStore() {
        if !formData.patientName.isEmpty {
            let nameParts = formData.patientName.components(separatedBy: " ")
            sharedData.updatePatientInfo({ info in
                info.firstName = nameParts.first ?? ""
                info.lastName = nameParts.dropFirst().joined(separator: " ")
                info.address = formData.patientAddress
                info.dateOfBirth = formData.patientDOB
            }, source: "CTO1Form")
        }
        // Sync clinical reasons
        if formData.clinicalReasons.primaryDiagnosisICD10 != .none || formData.clinicalReasons.healthEnabled || formData.clinicalReasons.safetyEnabled {
            sharedData.setClinicalReasons(formData.clinicalReasons, source: "CTO1Form")
        }
    }

    private func previewText(for section: CTO1Section) -> String {
        switch section {
        case .patientRC: return formData.patientName.isEmpty ? "Not entered" : formData.patientName
        case .grounds:
            if !formData.reasonsForCTO.isEmpty || !formData.clinicalReasons.generatedText.isEmpty {
                return "Entered"
            }
            return "Not entered"
        case .conditions:
            let count = [formData.standardConditions.seeCMHT, formData.standardConditions.complyWithMedication, formData.standardConditions.residence].filter { $0 }.count
            if count > 0 {
                return "\(count) condition\(count > 1 ? "s" : "") selected"
            } else if !formData.additionalConditions.isEmpty {
                return "Custom conditions"
            }
            return "Not selected"
        case .amhp: return formData.amhpName.isEmpty ? "Not entered" : formData.amhpName
        case .signature: return DateFormatter.shortDate.string(from: formData.ctoStartDate)
        }
    }

    private func prefillFromSharedData() {
        // Patient from shared data
        formData.patientName = sharedData.patientInfo.fullName
        formData.patientAddress = sharedData.patientInfo.address
        formData.patientDOB = sharedData.patientInfo.dateOfBirth
        // Hospital from My Details
        formData.responsibleHospital = appStore.clinicianInfo.hospitalOrg
        // RC from My Details
        formData.rcName = appStore.clinicianInfo.fullName
        formData.rcProfession = appStore.clinicianInfo.roleTitle
        formData.rcEmail = appStore.clinicianInfo.email
        // Clinical reasons from shared data
        if formData.clinicalReasons.primaryDiagnosisICD10 == .none && sharedData.hasClinicalReasons {
            formData.clinicalReasons = sharedData.clinicalReasons
            // Also populate reasonsForCTO from clinical reasons display text
            if formData.reasonsForCTO.isEmpty {
                formData.reasonsForCTO = sharedData.clinicalReasons.displayText
            }
        }
    }

    private func exportDOCX() {
        validationErrors = formData.validate()
        isExporting = true
        exportError = nil

        DispatchQueue.global(qos: .userInitiated).async {
            let data = CTO1FormDOCXExporter(formData: formData).generateDOCX()

            DispatchQueue.main.async {
                isExporting = false

                guard let docxData = data else {
                    exportError = "Failed to generate document"
                    return
                }

                // Save to temporary file
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
                let timestamp = dateFormatter.string(from: Date())
                let filename = "Form_CTO1_\(timestamp).docx"
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

    private func isSectionComplete(_ section: CTO1Section) -> Bool {
        switch section {
        case .patientRC: return !formData.patientName.isEmpty && !formData.rcName.isEmpty
        case .grounds:
            let hasDirectReasons = !formData.reasonsForCTO.isEmpty
            let hasClinicalReasons = !formData.clinicalReasons.generatedText.isEmpty || formData.clinicalReasons.primaryDiagnosisICD10 != .none
            return hasDirectReasons || hasClinicalReasons
        case .conditions: return formData.standardConditions.hasAnySelected || !formData.additionalConditions.isEmpty
        case .amhp: return !formData.amhpName.isEmpty && formData.amhpAgreement
        case .signature: return true
        }
    }

    private func sectionForError(_ error: FormValidationError) -> CTO1Section? {
        switch error.field {
        case "patientName", "patientAddress", "rcName", "responsibleHospital":
            return .patientRC
        case "mentalDisorderDescription", "reasonsForCTO", "clinicalReasons":
            return .grounds
        case "conditions", "standardConditions", "additionalConditions":
            return .conditions
        case "amhpName", "amhpAgreement":
            return .amhp
        default:
            return .signature
        }
    }
}

// MARK: - CTO1 Popup Sheet
struct CTO1PopupSheet: View {
    let section: CTO1FormView.CTO1Section
    @Binding var formData: CTO1FormData
    var patientInfo: PatientInfo
    @Environment(\.dismiss) private var dismiss
    @Environment(SharedDataStore.self) private var sharedData

    // Local state for gender/ethnicity that syncs with sharedData
    @State private var selectedGender: Gender = .notSpecified
    @State private var selectedEthnicity: Ethnicity = .notSpecified

    private var combinedPatientInfo: PatientInfo {
        var info = patientInfo
        info.firstName = formData.patientName.components(separatedBy: " ").first ?? ""
        info.lastName = formData.patientName.components(separatedBy: " ").dropFirst().joined(separator: " ")
        info.address = formData.patientAddress
        info.dateOfBirth = formData.patientDOB
        info.gender = selectedGender
        info.ethnicity = selectedEthnicity
        return info
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    sectionContent
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(section.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .onAppear {
            selectedGender = sharedData.patientInfo.gender
            selectedEthnicity = sharedData.patientInfo.ethnicity
            // Sync patientInfo for text generation
            formData.patientInfo = combinedPatientInfo
        }
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch section {
        case .patientRC:
            FormSectionHeader(title: "Patient Details", systemImage: "person")
            FormTextField(label: "Patient Name", text: $formData.patientName, isRequired: true)
            FormTextEditor(label: "Patient Address", text: $formData.patientAddress)
            HStack {
                Text("Age")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Stepper("\(formData.patientAge) years", value: $formData.patientAge, in: 18...120)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Gender")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Picker("Gender", selection: $selectedGender) {
                    ForEach(Gender.allCases) { gender in
                        Text(gender.rawValue).tag(gender)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedGender) { _, newValue in
                    sharedData.updatePatientInfo({ $0.gender = newValue }, source: "CTO1Form")
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Ethnicity")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Picker("Ethnicity", selection: $selectedEthnicity) {
                    ForEach(Ethnicity.allCases) { ethnicity in
                        Text(ethnicity.rawValue).tag(ethnicity)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedEthnicity) { _, newValue in
                    sharedData.updatePatientInfo({ $0.ethnicity = newValue }, source: "CTO1Form")
                }
            }
            FormDivider()
            FormSectionHeader(title: "Hospital", systemImage: "building.2")
            FormTextField(label: "Responsible Hospital", text: $formData.responsibleHospital, isRequired: true)
            FormDivider()
            FormSectionHeader(title: "Responsible Clinician", systemImage: "stethoscope")
            FormTextField(label: "RC Name", text: $formData.rcName, isRequired: true)
            FormTextField(label: "Profession", text: $formData.rcProfession)
            FormTextField(label: "Email", text: $formData.rcEmail, fieldId: "rcEmail")

        case .grounds:
            // Clinical Reasons Builder with patient info for CTO
            ClinicalReasonsView(data: $formData.clinicalReasons, patientInfo: combinedPatientInfo, showInformalSection: false, formType: .cto)
            FormDivider()
            FormTextEditor(label: "Why Recall May Be Necessary", text: $formData.recallMayBeNecessary, placeholder: "Explain circumstances under which recall may be necessary", minHeight: 80)

        case .conditions:
            FormSectionHeader(title: "Standard Conditions (Section 17B(2))", systemImage: "checklist")
            InfoBox(text: "Select the standard conditions that apply to this CTO.", icon: "info.circle", color: .blue)

            VStack(alignment: .leading, spacing: 12) {
                FormToggle(
                    label: "See CMHT",
                    isOn: $formData.standardConditions.seeCMHT,
                    description: "To comply with reviews as defined by the care-coordinator and the RC."
                )
                FormToggle(
                    label: "Comply with medication",
                    isOn: $formData.standardConditions.complyWithMedication,
                    description: "To adhere to psychiatric medications as prescribed by the RC."
                )
                FormToggle(
                    label: "Residence",
                    isOn: $formData.standardConditions.residence,
                    description: "To reside at an address in accordance with the requirements of the CMHT/RC."
                )
            }
            .padding(.vertical, 8)

            FormDivider()
            FormSectionHeader(title: "Additional Conditions", systemImage: "plus.circle")
            FormTextEditor(label: "Custom Conditions", text: $formData.additionalConditions, placeholder: "Add any additional conditions not covered above", minHeight: 100)

        case .amhp:
            FormTextField(label: "AMHP Name", text: $formData.amhpName, isRequired: true)
            FormTextField(label: "Local Authority", text: $formData.amhpLocalAuthority)
            FormDatePicker(label: "AMHP Consultation Date", date: $formData.amhpConsultationDate)
            FormDivider()
            FormToggle(label: "AMHP agrees that CTO criteria are met", isOn: $formData.amhpAgreement)
            if !formData.amhpAgreement {
                InfoBox(text: "AMHP agreement is required for a valid CTO.", icon: "exclamationmark.triangle.fill", color: .red)
            }

        case .signature:
            FormDatePicker(label: "CTO Start Date", date: $formData.ctoStartDate, isRequired: true)
            FormDatePicker(label: "CTO Start Time", date: $formData.ctoStartDate, includeTime: true)
            FormDivider()
            FormSectionHeader(title: "Responsible Clinician", systemImage: "1.circle")
            FormDatePicker(label: "RC Signature Date", date: $formData.rcSignatureDate)
            FormDivider()
            FormSectionHeader(title: "AMHP", systemImage: "2.circle")
            FormDatePicker(label: "AMHP Signature Date", date: $formData.amhpSignatureDate)
            InfoBox(text: "The form will be signed manually after printing.", icon: "pencil.and.outline", color: .gray)
        }
    }
}

// MARK: - CTO3 Form View (Notice of Recall to Hospital)
// Matches desktop layout: Details, Grounds, Signatures
struct CTO3FormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var appStore
    @Environment(SharedDataStore.self) private var sharedData

    @State private var formData: CTO3FormData = CTO3FormData()
    @State private var activePopup: CTO3Section?
    @State private var validationErrors: [FormValidationError] = []
    @State private var docxURL: URL?
    @State private var isExporting = false
    @State private var showShareSheet = false
    @State private var exportError: String?

    enum CTO3Section: String, CaseIterable, Identifiable {
        case details = "Details"
        case grounds = "Grounds"
        case signatures = "Signatures"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .details: return "person.text.rectangle"
            case .grounds: return "doc.text"
            case .signatures: return "signature"
            }
        }
    }

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Text("CTO3")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("Notice of Recall")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)

                    FormValidationErrorView(errors: validationErrors) { error in
                        if let section = sectionForError(error) {
                            activePopup = section
                        }
                    }

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(CTO3Section.allCases) { section in
                            FormSectionCardWithStatus(
                                title: section.rawValue,
                                icon: section.icon,
                                preview: previewText(for: section),
                                color: .red,
                                isComplete: isSectionComplete(section)
                            ) {
                                activePopup = section
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Form CTO3")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { exportDOCX() } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(isExporting)
                }
            }
            .onAppear { prefillFromSharedData() }
            .onDisappear { syncPatientDataToSharedStore() }
            .sheet(item: $activePopup) { section in
                CTO3PopupSheet(section: section, formData: $formData, patientInfo: sharedData.patientInfo)
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = docxURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    private func syncPatientDataToSharedStore() {
        if !formData.patientName.isEmpty {
            let nameParts = formData.patientName.components(separatedBy: " ")
            sharedData.updatePatientInfo({ info in
                info.firstName = nameParts.first ?? ""
                info.lastName = nameParts.dropFirst().joined(separator: " ")
                info.address = formData.patientAddress
                info.dateOfBirth = formData.patientDOB
            }, source: "CTO3Form")
        }
        // Sync clinical reasons
        if formData.clinicalReasons.primaryDiagnosisICD10 != .none || formData.clinicalReasons.healthEnabled || formData.clinicalReasons.safetyEnabled {
            sharedData.setClinicalReasons(formData.clinicalReasons, source: "CTO3Form")
        }
    }

    private func previewText(for section: CTO3Section) -> String {
        switch section {
        case .details: return formData.patientName.isEmpty ? "Not entered" : formData.patientName
        case .grounds:
            // Check both reasonsForRecall and clinicalReasons
            let hasDirectReasons = !formData.reasonsForRecall.isEmpty
            let hasClinicalReasons = !formData.clinicalReasons.displayText.isEmpty || formData.clinicalReasons.primaryDiagnosisICD10 != .none
            return (hasDirectReasons || hasClinicalReasons) ? "Entered" : "Not entered"
        case .signatures: return DateFormatter.shortDate.string(from: formData.signatureDate)
        }
    }

    private func prefillFromSharedData() {
        // Patient from shared data
        formData.patientName = sharedData.patientInfo.fullName
        formData.patientAddress = sharedData.patientInfo.address
        formData.patientDOB = sharedData.patientInfo.dateOfBirth
        // Hospital from My Details
        formData.recallHospital = appStore.clinicianInfo.hospitalOrg
        // RC from My Details
        formData.rcName = appStore.clinicianInfo.fullName
        // Clinical reasons from shared data
        if formData.clinicalReasons.primaryDiagnosisICD10 == .none && sharedData.hasClinicalReasons {
            formData.clinicalReasons = sharedData.clinicalReasons
        }
    }

    private func exportDOCX() {
        validationErrors = formData.validate()
        isExporting = true
        exportError = nil

        DispatchQueue.global(qos: .userInitiated).async {
            let data = CTO3FormDOCXExporter(formData: formData).generateDOCX()

            DispatchQueue.main.async {
                isExporting = false

                guard let docxData = data else {
                    exportError = "Failed to generate document"
                    return
                }

                // Save to temporary file
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
                let timestamp = dateFormatter.string(from: Date())
                let filename = "Form_CTO3_\(timestamp).docx"
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

    private func isSectionComplete(_ section: CTO3Section) -> Bool {
        switch section {
        case .details: return !formData.patientName.isEmpty && !formData.rcName.isEmpty
        case .grounds:
            let hasDirectReasons = !formData.reasonsForRecall.isEmpty
            let hasClinicalReasons = !formData.clinicalReasons.displayText.isEmpty || formData.clinicalReasons.primaryDiagnosisICD10 != .none
            return hasDirectReasons || hasClinicalReasons
        case .signatures: return true
        }
    }

    private func sectionForError(_ error: FormValidationError) -> CTO3Section? {
        switch error.field {
        case "patientName", "patientAddress", "rcName", "recallHospital":
            return .details
        case "reasonsForRecall", "clinicalReasons":
            return .grounds
        default:
            return .signatures
        }
    }
}

// MARK: - CTO3 Popup Sheet
struct CTO3PopupSheet: View {
    let section: CTO3FormView.CTO3Section
    @Binding var formData: CTO3FormData
    var patientInfo: PatientInfo
    @Environment(\.dismiss) private var dismiss
    @Environment(SharedDataStore.self) private var sharedData

    // Local state for gender/ethnicity that syncs with sharedData
    @State private var selectedGender: Gender = .notSpecified
    @State private var selectedEthnicity: Ethnicity = .notSpecified

    private var combinedPatientInfo: PatientInfo {
        var info = patientInfo
        info.firstName = formData.patientName.components(separatedBy: " ").first ?? ""
        info.lastName = formData.patientName.components(separatedBy: " ").dropFirst().joined(separator: " ")
        info.address = formData.patientAddress
        info.dateOfBirth = formData.patientDOB
        info.gender = selectedGender
        info.ethnicity = selectedEthnicity
        return info
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    sectionContent
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(section.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        // Sync patientInfo before dismissing
                        formData.patientInfo = combinedPatientInfo
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
        .onAppear {
            selectedGender = sharedData.patientInfo.gender
            selectedEthnicity = sharedData.patientInfo.ethnicity
        }
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch section {
        case .details:
            FormTextField(label: "Patient Name", text: $formData.patientName, isRequired: true)
            FormDivider()
            FormTextField(label: "Recall Hospital", text: $formData.recallHospital, isRequired: true)
            FormTextEditor(label: "Hospital Address", text: $formData.recallHospitalAddress)
            FormDivider()
            FormTextField(label: "RC Name", text: $formData.rcName, isRequired: true)
            FormDivider()
            FormDatePicker(label: "Recall Date", date: $formData.recallDate)
            FormDatePicker(label: "Recall Time", date: $formData.recallTime, includeTime: true)

        case .grounds:
            // Recall Reason Type - (a) or (b)
            FormSectionHeader(title: "Reason for Recall", systemImage: "exclamationmark.triangle")
            VStack(alignment: .leading, spacing: 8) {
                Text("Select the reason for recall:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Picker("Recall Reason", selection: $formData.recallReasonType) {
                    Text("(a) Treatment Required").tag(CTO3RecallReasonType.treatmentRequired)
                    Text("(b) Breach of Conditions").tag(CTO3RecallReasonType.breachOfConditions)
                }
                .pickerStyle(.segmented)
            }

            FormDivider()

            if formData.recallReasonType == .treatmentRequired {
                // Option (a) - Treatment required and risk of harm
                InfoBox(
                    text: "(a) In my opinion, you require treatment in hospital for mental disorder, AND there would be a risk of harm to your health or safety or to other persons if you were not recalled to hospital for that purpose.",
                    icon: "info.circle",
                    color: .blue
                )
                FormSectionHeader(title: "Clinical Grounds", systemImage: "doc.text")
                // Clinical Reasons Builder with patient info - CTO3 uses "you/your" form (addressed to patient)
                ClinicalReasonsView(data: $formData.clinicalReasons, patientInfo: combinedPatientInfo, showInformalSection: false, formType: .cto, useYouForm: true)
            } else {
                // Option (b) - Breach of conditions
                InfoBox(
                    text: "(b) You have failed to comply with the condition imposed under section 17B of the Mental Health Act 1983 that you make yourself available for examination for the purpose of:",
                    icon: "info.circle",
                    color: .orange
                )
                VStack(alignment: .leading, spacing: 8) {
                    Text("Select the examination purpose:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Picker("Examination Type", selection: $formData.breachExaminationType) {
                        Text("(i) Extension of CTO under section 20A").tag(CTO3BreachExaminationType.extensionOfCTO)
                        Text("(ii) Enabling a Part 4A certificate").tag(CTO3BreachExaminationType.part4ACertificate)
                    }
                    .pickerStyle(.menu)
                }
            }

        case .signatures:
            FormSectionHeader(title: "Notice Service", systemImage: "envelope")
            FormDatePicker(label: "Notice Served Date", date: $formData.noticeServedDate)
            FormDatePicker(label: "Notice Served Time", date: $formData.noticeServedTime, includeTime: true)
            FormTextField(label: "Notice Served To", text: $formData.noticeServedTo, placeholder: "Patient/Representative name")
            FormDivider()
            FormDatePicker(label: "Signature Date", date: $formData.signatureDate, isRequired: true)
            InfoBox(text: "The form will be signed manually after printing.", icon: "pencil.and.outline", color: .gray)
        }
    }
}

// MARK: - CTO4 Form View (Record of Detention After Recall)
// Matches desktop layout: Details, Detention, Signature
struct CTO4FormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var appStore
    @Environment(SharedDataStore.self) private var sharedData

    @State private var formData: CTO4FormData = CTO4FormData()
    @State private var activePopup: CTO4Section?
    @State private var validationErrors: [FormValidationError] = []
    @State private var docxURL: URL?
    @State private var isExporting = false
    @State private var showShareSheet = false
    @State private var exportError: String?

    enum CTO4Section: String, CaseIterable, Identifiable {
        case details = "Details"
        case detention = "Detention"
        case signature = "Signature"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .details: return "person.text.rectangle"
            case .detention: return "building.2"
            case .signature: return "signature"
            }
        }
    }

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Text("CTO4")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("Record of Detention After Recall")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)

                    FormValidationErrorView(errors: validationErrors) { error in
                        if let section = sectionForError(error) {
                            activePopup = section
                        }
                    }

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(CTO4Section.allCases) { section in
                            FormSectionCardWithStatus(
                                title: section.rawValue,
                                icon: section.icon,
                                preview: previewText(for: section),
                                color: .purple,
                                isComplete: isSectionComplete(section)
                            ) {
                                activePopup = section
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Form CTO4")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { exportDOCX() } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(isExporting)
                }
            }
            .onAppear { prefillFromSharedData() }
            .onDisappear { syncPatientDataToSharedStore() }
            .sheet(item: $activePopup) { section in
                CTO4PopupSheet(section: section, formData: $formData)
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = docxURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    private func syncPatientDataToSharedStore() {
        if !formData.patientName.isEmpty {
            let nameParts = formData.patientName.components(separatedBy: " ")
            sharedData.updatePatientInfo({ info in
                info.firstName = nameParts.first ?? ""
                info.lastName = nameParts.dropFirst().joined(separator: " ")
                info.address = formData.patientAddress
                info.dateOfBirth = formData.patientDOB
            }, source: "CTO4Form")
        }
    }

    private func previewText(for section: CTO4Section) -> String {
        switch section {
        case .details: return formData.patientName.isEmpty ? "Not entered" : formData.patientName
        case .detention: return formData.hospitalName.isEmpty ? "Not entered" : formData.hospitalName
        case .signature: return DateFormatter.shortDate.string(from: formData.rcSignatureDate)
        }
    }

    private func prefillFromSharedData() {
        // Patient from shared data
        formData.patientName = sharedData.patientInfo.fullName
        formData.patientAddress = sharedData.patientInfo.address
        formData.patientDOB = sharedData.patientInfo.dateOfBirth
        // Hospital from My Details
        formData.hospitalName = appStore.clinicianInfo.hospitalOrg
        // RC from My Details
        formData.rcName = appStore.clinicianInfo.fullName
    }

    private func exportDOCX() {
        validationErrors = formData.validate()
        isExporting = true
        exportError = nil

        DispatchQueue.global(qos: .userInitiated).async {
            let data = CTO4FormDOCXExporter(formData: formData).generateDOCX()

            DispatchQueue.main.async {
                isExporting = false

                guard let docxData = data else {
                    exportError = "Failed to generate document"
                    return
                }

                // Save to temporary file
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
                let timestamp = dateFormatter.string(from: Date())
                let filename = "Form_CTO4_\(timestamp).docx"
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

    private func isSectionComplete(_ section: CTO4Section) -> Bool {
        switch section {
        case .details: return !formData.patientName.isEmpty
        case .detention: return !formData.hospitalName.isEmpty
        case .signature: return true
        }
    }

    private func sectionForError(_ error: FormValidationError) -> CTO4Section? {
        switch error.field {
        case "patientName", "patientAddress":
            return .details
        case "hospitalName", "hospitalAddress":
            return .detention
        default:
            return .signature
        }
    }
}

// MARK: - CTO4 Popup Sheet
struct CTO4PopupSheet: View {
    let section: CTO4FormView.CTO4Section
    @Binding var formData: CTO4FormData
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    sectionContent
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(section.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch section {
        case .details:
            FormSectionHeader(title: "Patient", systemImage: "person")
            FormTextField(label: "Patient Name", text: $formData.patientName, isRequired: true)
            FormTextEditor(label: "Patient Address", text: $formData.patientAddress)
            FormDivider()
            FormSectionHeader(title: "Responsible Clinician", systemImage: "stethoscope")
            FormTextField(label: "RC Name", text: $formData.rcName, isRequired: true)

        case .detention:
            FormSectionHeader(title: "Hospital for Detention", systemImage: "building.2")
            FormTextField(label: "Hospital Name", text: $formData.hospitalName, isRequired: true)
            FormTextEditor(label: "Hospital Address", text: $formData.hospitalAddress)
            FormDivider()
            FormSectionHeader(title: "Detention Details", systemImage: "clock")
            FormDatePicker(label: "Detention Date", date: $formData.patientRecalledDate, isRequired: true)
            FormDatePicker(label: "Detention Time", date: $formData.patientRecalledDate, includeTime: true)
            InfoBox(text: "Enter the date and time at which the patient's detention began as a result of the recall notice.", icon: "info.circle", color: .blue)

        case .signature:
            FormDatePicker(label: "Signature Date", date: $formData.rcSignatureDate, isRequired: true)
            InfoBox(text: "The form will be signed manually after printing.", icon: "pencil.and.outline", color: .gray)
        }
    }
}

// MARK: - CTO5 Form View (Revocation of CTO)
// Matches desktop layout: Details, Reasons, AMHP, Revocation
struct CTO5FormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var appStore
    @Environment(SharedDataStore.self) private var sharedData

    @State private var formData: CTO5FormData = CTO5FormData()
    @State private var activePopup: CTO5Section?
    @State private var validationErrors: [FormValidationError] = []
    @State private var docxURL: URL?
    @State private var isExporting = false
    @State private var showShareSheet = false
    @State private var exportError: String?

    enum CTO5Section: String, CaseIterable, Identifiable {
        case details = "Details"
        case reasons = "Reasons"
        case amhp = "AMHP"
        case revocation = "Revocation"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .details: return "person.text.rectangle"
            case .reasons: return "doc.text"
            case .amhp: return "person.badge.shield.checkmark"
            case .revocation: return "signature"
            }
        }
    }

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Text("CTO5")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("Revocation of CTO")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)

                    FormValidationErrorView(errors: validationErrors) { error in
                        if let section = sectionForError(error) {
                            activePopup = section
                        }
                    }

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(CTO5Section.allCases) { section in
                            FormSectionCardWithStatus(
                                title: section.rawValue,
                                icon: section.icon,
                                preview: previewText(for: section),
                                color: .orange,
                                isComplete: isSectionComplete(section)
                            ) {
                                activePopup = section
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Form CTO5")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { exportDOCX() } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(isExporting)
                }
            }
            .onAppear { prefillFromSharedData() }
            .onDisappear { syncPatientDataToSharedStore() }
            .sheet(item: $activePopup) { section in
                CTO5PopupSheet(section: section, formData: $formData, patientInfo: sharedData.patientInfo)
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = docxURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    private func syncPatientDataToSharedStore() {
        if !formData.patientName.isEmpty {
            let nameParts = formData.patientName.components(separatedBy: " ")
            sharedData.updatePatientInfo({ info in
                info.firstName = nameParts.first ?? ""
                info.lastName = nameParts.dropFirst().joined(separator: " ")
                info.address = formData.patientAddress
                info.manualAge = formData.patientAge
            }, source: "CTO5Form")
        }
        // Sync clinical reasons
        if formData.clinicalReasons.primaryDiagnosisICD10 != .none || formData.clinicalReasons.healthEnabled || formData.clinicalReasons.safetyEnabled {
            sharedData.setClinicalReasons(formData.clinicalReasons, source: "CTO5Form")
        }
    }

    private func previewText(for section: CTO5Section) -> String {
        switch section {
        case .details: return formData.patientName.isEmpty ? "Not entered" : formData.patientName
        case .reasons:
            // Check both reasonsForRevocation and clinicalReasons
            let hasDirectReasons = !formData.reasonsForRevocation.isEmpty
            let hasClinicalReasons = !formData.clinicalReasons.displayText.isEmpty || formData.clinicalReasons.primaryDiagnosisICD10 != .none
            return (hasDirectReasons || hasClinicalReasons) ? "Entered" : "Not entered"
        case .amhp: return formData.amhpName.isEmpty ? "Not entered" : formData.amhpName
        case .revocation: return DateFormatter.shortDate.string(from: formData.revocationDate)
        }
    }

    private func prefillFromSharedData() {
        // Patient from shared data
        formData.patientName = sharedData.patientInfo.fullName
        formData.patientAddress = sharedData.patientInfo.address
        // Hospital from My Details
        formData.hospitalName = appStore.clinicianInfo.hospitalOrg
        // RC from My Details
        formData.rcName = appStore.clinicianInfo.fullName
        // Clinical reasons from shared data
        if formData.clinicalReasons.primaryDiagnosisICD10 == .none && sharedData.hasClinicalReasons {
            formData.clinicalReasons = sharedData.clinicalReasons
        }
    }

    private func exportDOCX() {
        validationErrors = formData.validate()
        isExporting = true
        exportError = nil

        DispatchQueue.global(qos: .userInitiated).async {
            let data = CTO5FormDOCXExporter(formData: formData).generateDOCX()

            DispatchQueue.main.async {
                isExporting = false

                guard let docxData = data else {
                    exportError = "Failed to generate document"
                    return
                }

                // Save to temporary file
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
                let timestamp = dateFormatter.string(from: Date())
                let filename = "Form_CTO5_\(timestamp).docx"
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

    private func isSectionComplete(_ section: CTO5Section) -> Bool {
        switch section {
        case .details: return !formData.patientName.isEmpty && !formData.rcName.isEmpty
        case .reasons:
            let hasDirectReasons = !formData.reasonsForRevocation.isEmpty
            let hasClinicalReasons = !formData.clinicalReasons.displayText.isEmpty || formData.clinicalReasons.primaryDiagnosisICD10 != .none
            return hasDirectReasons || hasClinicalReasons
        case .amhp: return !formData.amhpName.isEmpty && formData.amhpAgreement
        case .revocation: return true
        }
    }

    private func sectionForError(_ error: FormValidationError) -> CTO5Section? {
        switch error.field {
        case "patientName", "patientAddress", "rcName", "hospitalName":
            return .details
        case "reasonsForRevocation", "clinicalReasons":
            return .reasons
        case "amhpName", "amhpAgreement":
            return .amhp
        default:
            return .revocation
        }
    }
}

// MARK: - CTO5 Popup Sheet
struct CTO5PopupSheet: View {
    let section: CTO5FormView.CTO5Section
    @Binding var formData: CTO5FormData
    var patientInfo: PatientInfo
    @Environment(\.dismiss) private var dismiss
    @Environment(SharedDataStore.self) private var sharedData

    // Local state for gender/ethnicity that syncs with sharedData
    @State private var selectedGender: Gender = .notSpecified
    @State private var selectedEthnicity: Ethnicity = .notSpecified

    private var combinedPatientInfo: PatientInfo {
        var info = patientInfo
        info.firstName = formData.patientName.components(separatedBy: " ").first ?? ""
        info.lastName = formData.patientName.components(separatedBy: " ").dropFirst().joined(separator: " ")
        info.address = formData.patientAddress
        info.manualAge = formData.patientAge
        info.gender = selectedGender
        info.ethnicity = selectedEthnicity
        return info
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    sectionContent
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(section.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .onAppear {
            selectedGender = sharedData.patientInfo.gender
            selectedEthnicity = sharedData.patientInfo.ethnicity
        }
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch section {
        case .details:
            FormSectionHeader(title: "Patient", systemImage: "person")
            FormTextField(label: "Patient Name", text: $formData.patientName, isRequired: true)
            FormTextEditor(label: "Patient Address", text: $formData.patientAddress)
            HStack {
                Text("Age")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Stepper("\(formData.patientAge) years", value: $formData.patientAge, in: 18...120)
            }
            FormDivider()
            VStack(alignment: .leading, spacing: 4) {
                Text("Gender")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Picker("Gender", selection: $selectedGender) {
                    ForEach(Gender.allCases) { gender in
                        Text(gender.rawValue).tag(gender)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedGender) { _, newValue in
                    sharedData.updatePatientInfo({ $0.gender = newValue }, source: "CTO5Form")
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Ethnicity")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Picker("Ethnicity", selection: $selectedEthnicity) {
                    ForEach(Ethnicity.allCases) { ethnicity in
                        Text(ethnicity.rawValue).tag(ethnicity)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedEthnicity) { _, newValue in
                    sharedData.updatePatientInfo({ $0.ethnicity = newValue }, source: "CTO5Form")
                }
            }
            FormDivider()
            FormSectionHeader(title: "Responsible Hospital", systemImage: "building.2")
            FormTextField(label: "Hospital Name", text: $formData.hospitalName, isRequired: true)
            FormTextEditor(label: "Hospital Address", text: $formData.hospitalAddress)
            FormDivider()
            FormSectionHeader(title: "Detention Details", systemImage: "clock")
            FormDatePicker(label: "Detention Date", date: $formData.patientRecalledDate, isRequired: true)
            FormDatePicker(label: "Detention Time", date: $formData.patientRecalledDate, includeTime: true)
            InfoBox(text: "Enter the date and time since which the patient has been detained in hospital.", icon: "info.circle", color: .blue)
            FormDivider()
            FormSectionHeader(title: "Responsible Clinician", systemImage: "stethoscope")
            FormTextField(label: "RC Name", text: $formData.rcName, isRequired: true)

        case .reasons:
            // Clinical Reasons Builder with patient info for revocation reasons
            ClinicalReasonsView(data: $formData.clinicalReasons, patientInfo: combinedPatientInfo, showInformalSection: false, formType: .cto)

        case .amhp:
            FormTextField(label: "AMHP Name", text: $formData.amhpName, isRequired: true)
            FormTextField(label: "Local Authority", text: $formData.amhpLocalAuthority)
            FormDatePicker(label: "AMHP Consultation Date", date: $formData.amhpConsultationDate)
            FormDivider()
            FormToggle(label: "AMHP agrees to revocation", isOn: $formData.amhpAgreement)
            if !formData.amhpAgreement {
                InfoBox(text: "AMHP agreement is required for revocation.", icon: "exclamationmark.triangle.fill", color: .red)
            }

        case .revocation:
            FormDatePicker(label: "Revocation Date", date: $formData.revocationDate, isRequired: true)
            FormDivider()
            FormSectionHeader(title: "RC Signature", systemImage: "1.circle")
            FormDatePicker(label: "RC Signature Date", date: $formData.rcSignatureDate)
            FormDivider()
            FormSectionHeader(title: "AMHP Signature", systemImage: "2.circle")
            FormDatePicker(label: "AMHP Signature Date", date: $formData.amhpSignatureDate)
            InfoBox(text: "The form will be signed manually after printing.", icon: "pencil.and.outline", color: .gray)
        }
    }
}

// MARK: - CTO7 Form View (Report Extending CTO Period)
// Matches desktop layout: Details, Grounds, AMHP, Signatures
struct CTO7FormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var appStore
    @Environment(SharedDataStore.self) private var sharedData

    @State private var formData: CTO7FormData = CTO7FormData()
    @State private var activePopup: CTO7Section?
    @State private var validationErrors: [FormValidationError] = []
    @State private var docxURL: URL?
    @State private var isExporting = false
    @State private var showShareSheet = false
    @State private var exportError: String?
    @State private var showValidationAlert = false

    enum CTO7Section: String, CaseIterable, Identifiable {
        case details = "Details"
        case grounds = "Grounds"
        case amhp = "AMHP"
        case signatures = "Signatures"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .details: return "person.text.rectangle"
            case .grounds: return "doc.text"
            case .amhp: return "person.badge.shield.checkmark"
            case .signatures: return "signature"
            }
        }
    }

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Text("CTO7")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("Extension of CTO")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)

                    FormValidationErrorView(errors: validationErrors) { error in
                        if let section = sectionForError(error) {
                            activePopup = section
                        }
                    }

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(CTO7Section.allCases) { section in
                            FormSectionCardWithStatus(
                                title: section.rawValue,
                                icon: section.icon,
                                preview: previewText(for: section),
                                color: .blue,
                                isComplete: isSectionComplete(section)
                            ) {
                                activePopup = section
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Form CTO7")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { exportDOCX() } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(isExporting)
                }
            }
            .onAppear { prefillFromSharedData() }
            .onDisappear { syncPatientDataToSharedStore() }
            .sheet(item: $activePopup) { section in
                CTO7PopupSheet(section: section, formData: $formData, patientInfo: sharedData.patientInfo)
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = docxURL {
                    ShareSheet(items: [url])
                }
            }
            .alert("Required Fields Missing", isPresented: $showValidationAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(validationErrors.map { $0.message }.joined(separator: "\n"))
            }
        }
    }

    private func syncPatientDataToSharedStore() {
        if !formData.patientName.isEmpty {
            let nameParts = formData.patientName.components(separatedBy: " ")
            sharedData.updatePatientInfo({ info in
                info.firstName = nameParts.first ?? ""
                info.lastName = nameParts.dropFirst().joined(separator: " ")
                info.address = formData.patientAddress
                info.dateOfBirth = formData.patientDOB
            }, source: "CTO7Form")
        }
        // Sync clinical reasons
        if formData.clinicalReasons.primaryDiagnosisICD10 != .none || formData.clinicalReasons.healthEnabled || formData.clinicalReasons.safetyEnabled {
            sharedData.setClinicalReasons(formData.clinicalReasons, source: "CTO7Form")
        }
    }

    private func previewText(for section: CTO7Section) -> String {
        switch section {
        case .details: return formData.patientName.isEmpty ? "Not entered" : formData.patientName
        case .grounds:
            // Check both mentalDisorderDescription and clinicalReasons
            let hasDirectDescription = !formData.mentalDisorderDescription.isEmpty
            let hasClinicalReasons = !formData.clinicalReasons.displayText.isEmpty || formData.clinicalReasons.primaryDiagnosisICD10 != .none
            return (hasDirectDescription || hasClinicalReasons) ? "Entered" : "Not entered"
        case .amhp: return formData.professionalConsulted.isEmpty ? "Not entered" : formData.professionalConsulted
        case .signatures: return DateFormatter.shortDate.string(from: formData.signatureDate)
        }
    }

    private func prefillFromSharedData() {
        // Patient from shared data
        formData.patientName = sharedData.patientInfo.fullName
        formData.patientAddress = sharedData.patientInfo.address
        formData.patientDOB = sharedData.patientInfo.dateOfBirth
        formData.patientInfo = sharedData.patientInfo
        // Hospital from My Details
        formData.responsibleHospital = appStore.clinicianInfo.hospitalOrg
        // RC from My Details
        formData.rcName = appStore.clinicianInfo.fullName
        // Build address from ward/department and hospital/org
        var addressParts: [String] = []
        if !appStore.clinicianInfo.wardDepartment.isEmpty { addressParts.append(appStore.clinicianInfo.wardDepartment) }
        if !appStore.clinicianInfo.hospitalOrg.isEmpty { addressParts.append(appStore.clinicianInfo.hospitalOrg) }
        formData.rcAddress = addressParts.joined(separator: ", ")
        formData.rcEmail = appStore.clinicianInfo.email
        formData.rcProfession = appStore.clinicianInfo.roleTitle
        // Clinical reasons from shared data
        if formData.clinicalReasons.primaryDiagnosisICD10 == .none && sharedData.hasClinicalReasons {
            formData.clinicalReasons = sharedData.clinicalReasons
        }
    }

    private func exportDOCX() {
        validationErrors = formData.validate()

        // Block export if there are validation errors
        if !validationErrors.isEmpty {
            showValidationAlert = true
            return
        }

        isExporting = true
        exportError = nil

        DispatchQueue.global(qos: .userInitiated).async {
            let data = CTO7FormDOCXExporter(formData: formData).generateDOCX()

            DispatchQueue.main.async {
                isExporting = false

                guard let docxData = data else {
                    exportError = "Failed to generate document"
                    return
                }

                // Save to temporary file
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
                let timestamp = dateFormatter.string(from: Date())
                let filename = "Form_CTO7_\(timestamp).docx"
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

    private func isSectionComplete(_ section: CTO7Section) -> Bool {
        switch section {
        case .details: return !formData.patientName.isEmpty && !formData.responsibleHospital.isEmpty
        case .grounds:
            let hasDirectDescription = !formData.mentalDisorderDescription.isEmpty
            let hasClinicalReasons = !formData.clinicalReasons.displayText.isEmpty || formData.clinicalReasons.primaryDiagnosisICD10 != .none
            return hasDirectDescription || hasClinicalReasons
        case .amhp: return !formData.professionalConsulted.isEmpty
        case .signatures: return true
        }
    }

    private func sectionForError(_ error: FormValidationError) -> CTO7Section? {
        switch error.field {
        case "patientName", "patientAddress", "rcName", "responsibleHospital":
            return .details
        case "mentalDisorderDescription", "reasonsForExtension", "clinicalReasons":
            return .grounds
        case "professionalConsulted", "professionOfConsultee":
            return .amhp
        default:
            return .signatures
        }
    }
}

// MARK: - CTO7 Popup Sheet
struct CTO7PopupSheet: View {
    let section: CTO7FormView.CTO7Section
    @Binding var formData: CTO7FormData
    var patientInfo: PatientInfo
    @Environment(\.dismiss) private var dismiss
    @Environment(SharedDataStore.self) private var sharedData

    // Local state for gender/ethnicity that syncs with sharedData
    @State private var selectedGender: Gender = .notSpecified
    @State private var selectedEthnicity: Ethnicity = .notSpecified

    private var combinedPatientInfo: PatientInfo {
        var info = patientInfo
        info.firstName = formData.patientName.components(separatedBy: " ").first ?? ""
        info.lastName = formData.patientName.components(separatedBy: " ").dropFirst().joined(separator: " ")
        info.address = formData.patientAddress
        info.dateOfBirth = formData.patientDOB
        info.gender = selectedGender
        info.ethnicity = selectedEthnicity
        return info
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    sectionContent
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(section.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .onAppear {
            selectedGender = sharedData.patientInfo.gender
            selectedEthnicity = sharedData.patientInfo.ethnicity
            // Sync patientInfo for text generation
            formData.patientInfo = combinedPatientInfo
        }
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch section {
        case .details:
            FormSectionHeader(title: "Patient", systemImage: "person")
            FormTextField(label: "Patient Name", text: $formData.patientName, isRequired: true)
            FormTextEditor(label: "Patient Address", text: $formData.patientAddress)
            HStack {
                Text("Age")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Stepper("\(formData.patientAge) years", value: $formData.patientAge, in: 18...120)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Gender")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Picker("Gender", selection: $selectedGender) {
                    ForEach(Gender.allCases) { gender in
                        Text(gender.rawValue).tag(gender)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedGender) { _, newValue in
                    sharedData.updatePatientInfo({ $0.gender = newValue }, source: "CTO7Form")
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Ethnicity")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Picker("Ethnicity", selection: $selectedEthnicity) {
                    ForEach(Ethnicity.allCases) { ethnicity in
                        Text(ethnicity.rawValue).tag(ethnicity)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedEthnicity) { _, newValue in
                    sharedData.updatePatientInfo({ $0.ethnicity = newValue }, source: "CTO7Form")
                }
            }
            FormDivider()
            FormSectionHeader(title: "Hospital", systemImage: "building.2")
            FormTextField(label: "Responsible Hospital Name and Address", text: $formData.responsibleHospital, isRequired: true)
            FormDivider()
            FormSectionHeader(title: "Responsible Clinician", systemImage: "stethoscope")
            FormTextField(label: "RC Name", text: $formData.rcName, isRequired: true)
            FormTextEditor(label: "RC Address", text: $formData.rcAddress)
            FormTextField(label: "Email", text: $formData.rcEmail)
            FormTextField(label: "Profession", text: $formData.rcProfession)
            FormDivider()
            FormSectionHeader(title: "Current CTO", systemImage: "calendar")
            FormDatePicker(label: "CTO Start Date", date: $formData.ctoStartDate)
            FormDivider()
            FormSectionHeader(title: "Consultee", systemImage: "person.2")
            FormTextField(label: "Full Name", text: $formData.professionalConsulted, isRequired: true)
            FormTextField(label: "Email", text: $formData.consulteeEmail)
            FormTextField(label: "Profession", text: $formData.professionOfConsultee)

        case .grounds:
            FormDatePicker(label: "Examination Date", date: $formData.examinationDate)
            FormDivider()
            // Clinical Reasons Builder with patient info for extension grounds
            ClinicalReasonsView(data: $formData.clinicalReasons, patientInfo: combinedPatientInfo, showInformalSection: false, formType: .cto)

        case .amhp:
            FormDatePicker(label: "Consultation Date", date: $formData.consultationDate)

        case .signatures:
            FormSectionHeader(title: "Delivery Method", systemImage: "paperplane")
            VStack(alignment: .leading, spacing: 8) {
                Text("How are you furnishing this report?")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                ForEach(CTO7DeliveryMethod.allCases) { method in
                    HStack {
                        Image(systemName: formData.deliveryMethod == method ? "largecircle.fill.circle" : "circle")
                            .foregroundColor(formData.deliveryMethod == method ? .red : .gray)
                        Text(method.rawValue)
                            .font(.body)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { formData.deliveryMethod = method }
                }
            }
            .padding(.vertical, 4)
            FormDivider()
            FormSectionHeader(title: "Signature", systemImage: "signature")
            FormDatePicker(label: "Signature Date", date: $formData.signatureDate, isRequired: true)
            InfoBox(text: "The form will be signed manually after printing. Part 4 is to be completed by hospital managers.", icon: "pencil.and.outline", color: .gray)
        }
    }
}
