//
//  MHAFormViews.swift
//  MyPsychAdmin
//
//  Form views for A4, A6, A7, A8, H1, H5 - Popup-based card layout
//

import SwiftUI

// MARK: - A4 Form View (Section 2 Single Medical Recommendation)

struct A4FormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var appStore
    @Environment(SharedDataStore.self) private var sharedData

    @State private var formData: A4FormData
    @State private var activePopup: A4Section?
    @State private var validationErrors: [FormValidationError] = []
    @State private var docxURL: URL?
    @State private var isExporting = false
    @State private var showShareSheet = false
    @State private var exportError: String?

    enum A4Section: String, CaseIterable, Identifiable {
        case patient = "Patient"
        case practitioner = "Practitioner"
        case clinical = "Clinical Reasons"
        case assessmentSignature = "Assessment & Signature"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .patient: return "person"
            case .practitioner: return "stethoscope"
            case .clinical: return "brain.head.profile"
            case .assessmentSignature: return "signature"
            }
        }
        var color: Color { .purple }
    }

    init() { _formData = State(initialValue: A4FormData()) }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(A4Section.allCases) { section in
                        FormSectionCardWithStatus(
                            title: section.rawValue,
                            icon: section.icon,
                            preview: previewText(for: section),
                            color: section.color,
                            isComplete: isSectionComplete(section)
                        ) {
                            activePopup = section
                        }
                    }
                }
                .padding()

                if !validationErrors.isEmpty {
                    FormValidationErrorView(errors: validationErrors) { error in
                        if let section = sectionForError(error) {
                            activePopup = section
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Form A4")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { exportDOCX() } label: { Image(systemName: "square.and.arrow.up") }
                        .disabled(isExporting)
                }
            }
            .sheet(item: $activePopup) { section in
                A4PopupSheet(section: section, formData: $formData, patientInfo: sharedData.patientInfo, errorFields: errorFieldsForSection(section))
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = docxURL { ShareSheet(items: [url]) }
            }
            .onAppear { prefillFromSharedData() }
            .onDisappear { syncPatientDataToSharedStore() }
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
            }, source: "A4Form")
        }
        // Sync clinical reasons
        if formData.clinicalReasons.primaryDiagnosisICD10 != .none || formData.clinicalReasons.healthEnabled || formData.clinicalReasons.safetyEnabled {
            sharedData.setClinicalReasons(formData.clinicalReasons, source: "A4Form")
        }
    }

    private func previewText(for section: A4Section) -> String {
        switch section {
        case .patient: return formData.patientName.isEmpty ? "Not entered" : formData.patientName
        case .practitioner: return formData.doctorName.isEmpty ? "Not entered" : formData.doctorName
        case .clinical:
            // Check both mentalDisorderDescription and clinicalReasons
            let hasDirectDescription = !formData.mentalDisorderDescription.isEmpty
            let hasClinicalReasons = !formData.clinicalReasons.displayText.isEmpty || formData.clinicalReasons.primaryDiagnosisICD10 != .none
            return (hasDirectDescription || hasClinicalReasons) ? "Entered" : "Not entered"
        case .assessmentSignature: return DateFormatter.shortDate.string(from: formData.signatureDate)
        }
    }

    private func isSectionComplete(_ section: A4Section) -> Bool {
        switch section {
        case .patient: return !formData.patientName.isEmpty
        case .practitioner: return !formData.doctorName.isEmpty
        case .clinical:
            let hasDirectDescription = !formData.mentalDisorderDescription.isEmpty
            let hasClinicalReasons = !formData.clinicalReasons.displayText.isEmpty || formData.clinicalReasons.primaryDiagnosisICD10 != .none
            return hasDirectDescription || hasClinicalReasons
        case .assessmentSignature: return true
        }
    }

    private func prefillFromSharedData() {
        // Patient from shared data
        formData.patientName = sharedData.patientInfo.fullName
        formData.patientAddress = sharedData.patientInfo.address
        if let age = sharedData.patientInfo.age {
            formData.patientAge = age
        }
        // Doctor from My Details
        formData.doctorName = appStore.clinicianInfo.fullName
        formData.doctorAddress = appStore.clinicianInfo.hospitalOrg
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
            let data = A4FormDOCXExporter(formData: formData).generateDOCX()
            DispatchQueue.main.async {
                isExporting = false
                guard let docxData = data else { exportError = "Failed to generate document"; return }
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
                let filename = "Form_A4_\(dateFormatter.string(from: Date())).docx"
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
                do {
                    try docxData.write(to: tempURL)
                    docxURL = tempURL
                    showShareSheet = true
                } catch { exportError = "Failed to save document: \(error.localizedDescription)" }
            }
        }
    }

    private func errorFieldsForSection(_ section: A4Section) -> Set<String> {
        let allErrorFields = Set(validationErrors.map { $0.field })
        switch section {
        case .patient: return allErrorFields.intersection(["patientName", "patientAddress"])
        case .practitioner: return allErrorFields.intersection(["doctorName"])
        case .clinical: return allErrorFields.intersection(["mentalDisorderDescription", "reasonsForDetention", "clinicalReasons"])
        case .assessmentSignature: return []
        }
    }

    private func sectionForError(_ error: FormValidationError) -> A4Section? {
        switch error.field {
        case "patientName", "patientAddress":
            return .patient
        case "doctorName":
            return .practitioner
        case "mentalDisorderDescription", "reasonsForDetention", "clinicalReasons":
            return .clinical
        default:
            return .assessmentSignature
        }
    }
}

struct A4PopupSheet: View {
    let section: A4FormView.A4Section
    @Binding var formData: A4FormData
    var patientInfo: PatientInfo
    var errorFields: Set<String> = []
    @Environment(\.dismiss) private var dismiss
    @Environment(SharedDataStore.self) private var sharedData

    // Local state for gender/ethnicity that syncs with sharedData
    @State private var selectedGender: Gender = .notSpecified
    @State private var selectedEthnicity: Ethnicity = .notSpecified

    // Combined patient info: form data + shared gender/ethnicity
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
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        switch section {
                        case .patient:
                            FormTextField(label: "Patient Name", text: $formData.patientName, isRequired: true, hasError: errorFields.contains("patientName"), fieldId: "patientName")
                            FormTextEditor(label: "Patient Address", text: $formData.patientAddress, isRequired: true, hasError: errorFields.contains("patientAddress"), fieldId: "patientAddress")
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Age")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
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
                                sharedData.updatePatientInfo({ $0.gender = newValue }, source: "A4Form")
                                formData.patientInfo.gender = newValue  // Also update formData for export
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
                                sharedData.updatePatientInfo({ $0.ethnicity = newValue }, source: "A4Form")
                                formData.patientInfo.ethnicity = newValue  // Also update formData for export
                            }
                        }
                        InfoBox(text: "Gender and ethnicity are used to generate personalized clinical narratives.", icon: "info.circle", color: .blue)

                    case .practitioner:
                        FormTextField(label: "Doctor Name", text: $formData.doctorName, isRequired: true, hasError: errorFields.contains("doctorName"), fieldId: "doctorName")
                        FormTextEditor(label: "Address", text: $formData.doctorAddress)
                        FormDivider()
                        FormDatePicker(label: "Examination Date", date: $formData.examinationDate)
                        FormDivider()
                        FormToggle(
                            label: "Previous Acquaintance",
                            isOn: Binding(
                                get: { formData.previousAcquaintance != .none },
                                set: { formData.previousAcquaintance = $0 ? .treatedPreviously : .none }
                            ),
                            description: "I had previous acquaintance with the patient before I conducted that examination"
                        )
                        FormToggle(
                            label: "Section 12 Approved",
                            isOn: $formData.isSection12Approved,
                            description: "I am approved under section 12 of the Act as having special experience in the diagnosis or treatment of mental disorder"
                        )

                    case .clinical:
                        // Show error banner if clinical reasons are missing
                        if !errorFields.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.red)
                                Text("Clinical reasons are required")
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                            .id("clinicalReasons")
                        }
                        // Clinical Reasons Builder with patient info for personalized narratives
                        ClinicalReasonsView(data: $formData.clinicalReasons, patientInfo: combinedPatientInfo, showInformalSection: true, formType: .assessment)

                    case .assessmentSignature:
                        FormSectionHeader(title: "Assessment", systemImage: "clipboard")
                        FormDatePicker(label: "Last Seen Date", date: $formData.examinationDate, isRequired: true)
                        FormDivider()
                        FormSectionHeader(title: "Signature", systemImage: "signature")
                        FormDatePicker(label: "Signature Date", date: $formData.signatureDate, isRequired: true)
                        InfoBox(text: "The form will be signed manually after printing.", icon: "pencil.and.outline", color: .gray)
                    }
                }
                .padding()
                }
                .onAppear {
                    selectedGender = sharedData.patientInfo.gender
                    selectedEthnicity = sharedData.patientInfo.ethnicity
                    // Sync to formData for export
                    formData.patientInfo.gender = sharedData.patientInfo.gender
                    formData.patientInfo.ethnicity = sharedData.patientInfo.ethnicity
                    // Scroll to first error field
                    if let firstError = errorFields.first {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation {
                                proxy.scrollTo(firstError, anchor: .center)
                            }
                        }
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(section.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - A6 Form View (Section 3 Application by AMHP)
// Matches desktop layout: Hospital, AMHP & Patient, Local Authority, Nearest Relative, Interview & Signature

struct A6FormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var appStore
    @Environment(SharedDataStore.self) private var sharedData

    @State private var formData: A6FormData
    @State private var activePopup: A6Section?
    @State private var validationErrors: [FormValidationError] = []
    @State private var docxURL: URL?
    @State private var isExporting = false
    @State private var showShareSheet = false
    @State private var exportError: String?

    enum A6Section: String, CaseIterable, Identifiable {
        case hospital = "Hospital"
        case amhpPatient = "AMHP & Patient"
        case authority = "Local Authority"
        case nearestRelative = "Nearest Relative"
        case interviewSignature = "Interview & Signature"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .hospital: return "building.2"
            case .amhpPatient: return "person.2"
            case .authority: return "building.columns"
            case .nearestRelative: return "person.badge.clock"
            case .interviewSignature: return "signature"
            }
        }
        var color: Color { .blue }
    }

    init() { _formData = State(initialValue: A6FormData()) }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(A6Section.allCases) { section in
                        FormSectionCardWithStatus(
                            title: section.rawValue,
                            icon: section.icon,
                            preview: previewText(for: section),
                            color: section.color,
                            isComplete: isSectionComplete(section)
                        ) {
                            activePopup = section
                        }
                    }
                }
                .padding()

                if !validationErrors.isEmpty {
                    FormValidationErrorView(errors: validationErrors) { error in
                        if let section = sectionForError(error) {
                            activePopup = section
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Form A6")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { exportDOCX() } label: { Image(systemName: "square.and.arrow.up") }
                        .disabled(isExporting)
                }
            }
            .sheet(item: $activePopup) { section in
                A6PopupSheet(section: section, formData: $formData, errorFields: errorFieldsForSection(section))
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = docxURL { ShareSheet(items: [url]) }
            }
            .onAppear { prefillFromSharedData() }
            .onDisappear { syncPatientDataToSharedStore() }
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
            }, source: "A6Form")
        }
    }

    private func previewText(for section: A6Section) -> String {
        switch section {
        case .hospital: return formData.hospitalName.isEmpty ? "Not entered" : formData.hospitalName
        case .amhpPatient:
            if !formData.amhpName.isEmpty && !formData.patientName.isEmpty {
                return "\(formData.amhpName) / \(formData.patientName)"
            } else if !formData.amhpName.isEmpty {
                return formData.amhpName
            } else if !formData.patientName.isEmpty {
                return formData.patientName
            }
            return "Not entered"
        case .authority: return formData.localAuthorityName.isEmpty ? "Not entered" : formData.localAuthorityName
        case .nearestRelative: return formData.nrName.isEmpty ? "Not entered" : formData.nrName
        case .interviewSignature: return DateFormatter.shortDate.string(from: formData.interviewDate)
        }
    }

    private func isSectionComplete(_ section: A6Section) -> Bool {
        switch section {
        case .hospital: return !formData.hospitalName.isEmpty
        case .amhpPatient: return !formData.amhpName.isEmpty && !formData.patientName.isEmpty
        case .authority: return !formData.localAuthorityName.isEmpty
        case .nearestRelative: return true // Optional
        case .interviewSignature: return true
        }
    }

    private func prefillFromSharedData() {
        // Patient from shared data
        formData.patientName = sharedData.patientInfo.fullName
        formData.patientAddress = sharedData.patientInfo.address
        formData.patientDOB = sharedData.patientInfo.dateOfBirth
        // Hospital from My Details
        formData.hospitalName = appStore.clinicianInfo.hospitalOrg
        // AMHP from My Details
        formData.amhpName = appStore.clinicianInfo.fullName
        formData.amhpAddress = appStore.clinicianInfo.hospitalOrg
        formData.amhpEmail = appStore.clinicianInfo.email
        formData.localAuthorityName = appStore.clinicianInfo.teamService
        // Interview date from second practitioner examination date if available
        if sharedData.hasSecondPractitioner {
            formData.interviewDate = sharedData.secondPractitioner.examinationDate
        }
        // Nearest relative from shared data (from A2)
        if sharedData.hasNearestRelative {
            formData.nrName = sharedData.nearestRelative.name
            formData.nrAddress = sharedData.nearestRelative.address
        }
    }

    private func exportDOCX() {
        validationErrors = formData.validate()
        isExporting = true
        exportError = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let data = A6FormDOCXExporter(formData: formData).generateDOCX()
            DispatchQueue.main.async {
                isExporting = false
                guard let docxData = data else { exportError = "Failed to generate document"; return }
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
                let filename = "Form_A6_\(dateFormatter.string(from: Date())).docx"
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
                do {
                    try docxData.write(to: tempURL)
                    docxURL = tempURL
                    showShareSheet = true
                } catch { exportError = "Failed to save document: \(error.localizedDescription)" }
            }
        }
    }

    private func errorFieldsForSection(_ section: A6Section) -> Set<String> {
        let allErrorFields = Set(validationErrors.map { $0.field })
        switch section {
        case .hospital: return allErrorFields.intersection(["hospitalName", "hospitalAddress"])
        case .amhpPatient: return allErrorFields.intersection(["amhpName", "patientName", "patientAddress"])
        case .authority: return allErrorFields.intersection(["localAuthorityName"])
        case .nearestRelative: return allErrorFields.intersection(["nrName", "nrAddress", "ncReasonText"])
        case .interviewSignature: return []
        }
    }

    private func sectionForError(_ error: FormValidationError) -> A6Section? {
        switch error.field {
        case "hospitalName", "hospitalAddress":
            return .hospital
        case "amhpName", "patientName", "patientAddress":
            return .amhpPatient
        case "localAuthorityName":
            return .authority
        case "nearestRelativeName", "nearestRelativeAddress":
            return .nearestRelative
        default:
            return .interviewSignature
        }
    }
}

struct A6PopupSheet: View {
    let section: A6FormView.A6Section
    @Binding var formData: A6FormData
    var errorFields: Set<String> = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        switch section {
                        case .hospital:
                            FormTextField(label: "Hospital Name", text: $formData.hospitalName, isRequired: true, hasError: errorFields.contains("hospitalName"), fieldId: "hospitalName")
                            FormTextEditor(label: "Hospital Address", text: $formData.hospitalAddress, hasError: errorFields.contains("hospitalAddress"), fieldId: "hospitalAddress")

                        case .amhpPatient:
                            FormSectionHeader(title: "AMHP Details", systemImage: "person.badge.shield.checkmark")
                            FormTextField(label: "AMHP Name", text: $formData.amhpName, isRequired: true, hasError: errorFields.contains("amhpName"), fieldId: "amhpName")
                            FormTextEditor(label: "AMHP Address", text: $formData.amhpAddress)
                            FormTextField(label: "Email", text: $formData.amhpEmail, keyboardType: .emailAddress)
                            FormDivider()
                            FormSectionHeader(title: "Patient Details", systemImage: "person")
                            FormTextField(label: "Patient Name", text: $formData.patientName, isRequired: true, hasError: errorFields.contains("patientName"), fieldId: "patientName")
                            FormTextEditor(label: "Patient Address", text: $formData.patientAddress, isRequired: true, hasError: errorFields.contains("patientAddress"), fieldId: "patientAddress")

                        case .authority:
                            FormTextField(label: "Local Social Services Authority", text: $formData.localAuthorityName, isRequired: true, hasError: errorFields.contains("localAuthorityName"), fieldId: "localAuthorityName")
                            FormDivider()
                            FormSectionHeader(title: "AMHP Approval", systemImage: "checkmark.seal")
                            FormToggle(label: "Approved by same authority", isOn: $formData.approvedBySameAuthority)
                            if !formData.approvedBySameAuthority {
                                FormTextField(label: "Approving Authority", text: $formData.approvedByDifferentAuthority, isRequired: true)
                            }

                        case .nearestRelative:
                            // Primary Toggle: Was NR consulted?
                            FormToggle(label: "Nearest Relative Consulted", isOn: $formData.nrWasConsulted)
                            FormDivider()

                            if formData.nrWasConsulted {
                                // === CONSULTED PATH ===
                                FormSectionHeader(title: "Consulted Person", systemImage: "checkmark.circle")

                                // Name & Address (required)
                                FormTextField(label: "Name", text: $formData.nrName, isRequired: true, fieldId: "nrName")
                                FormTextEditor(label: "Address", text: $formData.nrAddress, isRequired: true, fieldId: "nrAddress")

                                // (a) NR or (b) Authorised choice
                                FormToggle(label: "Is the patient's nearest relative", isOn: $formData.nrIsNearestRelative)
                                if !formData.nrIsNearestRelative {
                                    InfoBox(text: "Person is authorised by county court or NR", icon: "info.circle", color: .orange)
                                }
                            } else {
                                // === NOT CONSULTED PATH ===
                                FormSectionHeader(title: "Reason Not Consulted", systemImage: "xmark.circle")

                                // (a), (b), or (c) choice
                                Picker("Reason", selection: $formData.ncReason) {
                                    ForEach(NotConsultedReason.allCases) { reason in
                                        Text(reason.rawValue).tag(reason)
                                    }
                                }

                                // Only show additional fields for option (c) - Known but couldn't consult
                                if formData.ncReason == .knownButCouldNot {
                                    FormDivider()
                                    FormSectionHeader(title: "Known NR Details", systemImage: "person.fill")

                                    // Name & Address
                                    FormTextField(label: "Name", text: $formData.nrName, isRequired: true, fieldId: "nrName")
                                    FormTextEditor(label: "Address", text: $formData.nrAddress, isRequired: true, fieldId: "nrAddress")

                                    // (i) NR or (ii) Authorised choice
                                    FormToggle(label: "Is the patient's nearest relative", isOn: $formData.nrIsNearestRelative)
                                    if !formData.nrIsNearestRelative {
                                        InfoBox(text: "Person is authorised by county court or NR", icon: "info.circle", color: .orange)
                                    }

                                    // Delay reason picker
                                    FormDivider()
                                    FormSectionHeader(title: "Reason for Not Consulting", systemImage: "text.quote")
                                    Picker("It was not possible to consult because", selection: $formData.ncDelayReason) {
                                        ForEach(NCDelayReason.allCases) { reason in
                                            Text(reason.rawValue).tag(reason)
                                        }
                                    }

                                    // Reason text box - fills the "because —" placeholder
                                    FormTextEditor(label: "Reason (fills 'because —' section)", text: $formData.ncReasonText, isRequired: true, fieldId: "ncReasonText")
                                }
                            }

                        case .interviewSignature:
                            FormSectionHeader(title: "Patient Interview", systemImage: "bubble.left.and.bubble.right")
                            FormDatePicker(label: "Date Patient Last Seen", date: $formData.interviewDate, isRequired: true)
                            FormToggle(label: "Patient was interviewed", isOn: $formData.patientInterviewed)
                            if !formData.patientInterviewed {
                                FormTextEditor(label: "Reason Not Interviewed", text: $formData.reasonNotInterviewed, isRequired: true)
                            }
                            FormDivider()
                            FormSectionHeader(title: "Medical Recommendations", systemImage: "stethoscope")
                            FormTextEditor(label: "If neither practitioner had previous acquaintance with patient", text: $formData.noAcquaintanceReason)
                            InfoBox(text: "Leave blank if not applicable", icon: "info.circle", color: .gray)
                            FormDivider()
                            FormSectionHeader(title: "Signature", systemImage: "signature")
                            FormDatePicker(label: "Signature Date", date: $formData.signatureDate, isRequired: true)
                            InfoBox(text: "The form will be signed manually after printing.", icon: "pencil.and.outline", color: .gray)
                        }
                    }
                    .padding()
                }
                .onAppear {
                    if let firstError = errorFields.first {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation {
                                proxy.scrollTo(firstError, anchor: .center)
                            }
                        }
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(section.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - A7 Form View (Section 3 Joint Medical Recommendation)
// Matches desktop layout: Patient, Practitioners (both together), Clinical Reasons, Treatment & Signatures

struct A7FormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var appStore
    @Environment(SharedDataStore.self) private var sharedData

    @State private var formData: A7FormData
    @State private var activePopup: A7Section?
    @State private var validationErrors: [FormValidationError] = []
    @State private var docxURL: URL?
    @State private var isExporting = false
    @State private var showShareSheet = false
    @State private var exportError: String?

    enum A7Section: String, CaseIterable, Identifiable {
        case patient = "Patient"
        case practitioners = "Practitioners"
        case clinical = "Clinical Reasons"
        case treatmentSignatures = "Treatment & Signatures"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .patient: return "person"
            case .practitioners: return "person.2"
            case .clinical: return "brain.head.profile"
            case .treatmentSignatures: return "signature"
            }
        }
        var color: Color { .purple }
    }

    init() { _formData = State(initialValue: A7FormData()) }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(A7Section.allCases) { section in
                        FormSectionCardWithStatus(
                            title: section.rawValue,
                            icon: section.icon,
                            preview: previewText(for: section),
                            color: section.color,
                            isComplete: isSectionComplete(section)
                        ) {
                            activePopup = section
                        }
                    }
                }
                .padding()

                if !validationErrors.isEmpty {
                    FormValidationErrorView(errors: validationErrors) { error in
                        if let section = sectionForError(error) {
                            activePopup = section
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Form A7")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { exportDOCX() } label: { Image(systemName: "square.and.arrow.up") }
                        .disabled(isExporting)
                }
            }
            .sheet(item: $activePopup) { section in
                A7PopupSheet(section: section, formData: $formData, patientInfo: sharedData.patientInfo)
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = docxURL { ShareSheet(items: [url]) }
            }
            .onAppear { prefillFromSharedData() }
            .onDisappear { syncPatientDataToSharedStore() }
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
            }, source: "A7Form")
        }
        // Sync clinical reasons
        if formData.clinicalReasons.primaryDiagnosisICD10 != .none || formData.clinicalReasons.healthEnabled || formData.clinicalReasons.safetyEnabled {
            sharedData.setClinicalReasons(formData.clinicalReasons, source: "A7Form")
        }
        // Sync second practitioner data back to SharedDataStore for A3 and other forms
        if !formData.doctor2Name.isEmpty {
            sharedData.updateSecondPractitioner({ info in
                info.name = formData.doctor2Name
                info.email = formData.doctor2Email
                info.address = formData.doctor2Address
                info.examinationDate = formData.doctor2ExaminationDate
            }, source: "A7Form")
        }
    }

    private func previewText(for section: A7Section) -> String {
        switch section {
        case .patient: return formData.patientName.isEmpty ? "Not entered" : formData.patientName
        case .practitioners:
            if !formData.doctor1Name.isEmpty && !formData.doctor2Name.isEmpty {
                return "\(formData.doctor1Name) / \(formData.doctor2Name)"
            } else if !formData.doctor1Name.isEmpty {
                return formData.doctor1Name
            }
            return "Not entered"
        case .clinical:
            // Check both mentalDisorderDescription and clinicalReasons
            let hasDirectDescription = !formData.mentalDisorderDescription.isEmpty
            let hasClinicalReasons = !formData.clinicalReasons.displayText.isEmpty || formData.clinicalReasons.primaryDiagnosisICD10 != .none
            return (hasDirectDescription || hasClinicalReasons) ? "Entered" : "Not entered"
        case .treatmentSignatures: return DateFormatter.shortDate.string(from: formData.doctor1SignatureDate)
        }
    }

    private func isSectionComplete(_ section: A7Section) -> Bool {
        switch section {
        case .patient: return !formData.patientName.isEmpty
        case .practitioners: return !formData.doctor1Name.isEmpty && !formData.doctor2Name.isEmpty
        case .clinical:
            let hasDirectDescription = !formData.mentalDisorderDescription.isEmpty
            let hasClinicalReasons = !formData.clinicalReasons.displayText.isEmpty || formData.clinicalReasons.primaryDiagnosisICD10 != .none
            return hasDirectDescription || hasClinicalReasons
        case .treatmentSignatures: return true
        }
    }

    private func prefillFromSharedData() {
        // Patient from shared data
        formData.patientName = sharedData.patientInfo.fullName
        formData.patientAddress = sharedData.patientInfo.address
        formData.patientAge = sharedData.patientInfo.age ?? 30
        // Doctor 1 from My Details
        formData.doctor1Name = appStore.clinicianInfo.fullName
        formData.doctor1Address = appStore.clinicianInfo.hospitalOrg
        formData.doctor1Email = appStore.clinicianInfo.email
        // Treatment hospital
        formData.treatmentHospital = appStore.clinicianInfo.hospitalOrg
        // Clinical reasons from shared data
        if formData.clinicalReasons.primaryDiagnosisICD10 == .none && sharedData.hasClinicalReasons {
            formData.clinicalReasons = sharedData.clinicalReasons
        }
        // Doctor 2 (Second Practitioner) from shared data
        if formData.doctor2Name.isEmpty && sharedData.hasSecondPractitioner {
            formData.doctor2Name = sharedData.secondPractitioner.name
            formData.doctor2Email = sharedData.secondPractitioner.email
            formData.doctor2Address = sharedData.secondPractitioner.address
            formData.doctor2ExaminationDate = sharedData.secondPractitioner.examinationDate
        }
    }

    private func exportDOCX() {
        validationErrors = formData.validate()
        isExporting = true
        exportError = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let data = A7FormDOCXExporter(formData: formData).generateDOCX()
            DispatchQueue.main.async {
                isExporting = false
                guard let docxData = data else { exportError = "Failed to generate document"; return }
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
                let filename = "Form_A7_\(dateFormatter.string(from: Date())).docx"
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
                do {
                    try docxData.write(to: tempURL)
                    docxURL = tempURL
                    showShareSheet = true
                } catch { exportError = "Failed to save document: \(error.localizedDescription)" }
            }
        }
    }

    private func sectionForError(_ error: FormValidationError) -> A7Section? {
        switch error.field {
        case "patientName", "patientAddress":
            return .patient
        case "doctor1Name", "doctor2Name":
            return .practitioners
        case "mentalDisorderDescription", "reasonsForDetention", "clinicalReasons":
            return .clinical
        default:
            return .treatmentSignatures
        }
    }
}

struct A7PopupSheet: View {
    let section: A7FormView.A7Section
    @Binding var formData: A7FormData
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
                    switch section {
                    case .patient:
                        FormTextField(label: "Patient Name", text: $formData.patientName, isRequired: true)
                        FormTextEditor(label: "Patient Address", text: $formData.patientAddress, isRequired: true)
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
                                sharedData.updatePatientInfo({ $0.gender = newValue }, source: "A7Form")
                                formData.patientInfo.gender = newValue  // Also update formData for export
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
                                sharedData.updatePatientInfo({ $0.ethnicity = newValue }, source: "A7Form")
                                formData.patientInfo.ethnicity = newValue  // Also update formData for export
                            }
                        }
                        InfoBox(text: "Gender and ethnicity are used to generate personalized clinical narratives.", icon: "info.circle", color: .blue)

                    case .practitioners:
                        // First Practitioner
                        FormSectionHeader(title: "First Practitioner", systemImage: "1.circle")
                        FormTextField(label: "Full Name", text: $formData.doctor1Name, isRequired: true)
                        FormTextEditor(label: "Address", text: $formData.doctor1Address)
                        FormTextField(label: "Email", text: $formData.doctor1Email, keyboardType: .emailAddress)
                        FormDatePicker(label: "Examination Date", date: $formData.doctor1ExaminationDate)
                        FormToggle(label: "Section 12 Approved", isOn: $formData.doctor1IsSection12Approved)
                        FormToggle(label: "Previous Acquaintance", isOn: $formData.doctor1HasPreviousAcquaintance)
                        FormDivider()
                        // Second Practitioner
                        FormSectionHeader(title: "Second Practitioner", systemImage: "2.circle")
                        FormTextField(label: "Full Name", text: $formData.doctor2Name, isRequired: true)
                        FormTextEditor(label: "Address", text: $formData.doctor2Address)
                        FormTextField(label: "Email", text: $formData.doctor2Email, keyboardType: .emailAddress)
                        FormDatePicker(label: "Examination Date", date: $formData.doctor2ExaminationDate)
                        FormToggle(label: "Section 12 Approved", isOn: $formData.doctor2IsSection12Approved)
                        FormToggle(label: "Previous Acquaintance", isOn: $formData.doctor2HasPreviousAcquaintance)
                        if !formData.doctor1IsSection12Approved && !formData.doctor2IsSection12Approved {
                            InfoBox(text: "At least one practitioner must be Section 12 approved", icon: "exclamationmark.triangle.fill", color: .orange)
                        }

                    case .clinical:
                        // Clinical Reasons Builder with patient info for personalized narratives
                        // showInformalSection: true to match A3 - Section 3 also requires justification for why informal not appropriate
                        ClinicalReasonsView(data: $formData.clinicalReasons, patientInfo: combinedPatientInfo, showInformalSection: true, formType: .treatment)

                    case .treatmentSignatures:
                        FormSectionHeader(title: "Hospital for Treatment", systemImage: "building.2")
                        FormTextField(label: "Hospital Name", text: $formData.treatmentHospital)
                        FormDivider()
                        FormSectionHeader(title: "First Practitioner Signature", systemImage: "1.circle")
                        FormDatePicker(label: "Signature Date", date: $formData.doctor1SignatureDate)
                        FormDivider()
                        FormSectionHeader(title: "Second Practitioner Signature", systemImage: "2.circle")
                        FormDatePicker(label: "Signature Date", date: $formData.doctor2SignatureDate)
                        InfoBox(text: "The form will be signed manually after printing.", icon: "pencil.and.outline", color: .gray)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(section.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .onAppear {
            selectedGender = sharedData.patientInfo.gender
            selectedEthnicity = sharedData.patientInfo.ethnicity
            // Sync to formData for export
            formData.patientInfo.gender = sharedData.patientInfo.gender
            formData.patientInfo.ethnicity = sharedData.patientInfo.ethnicity
        }
    }
}

// MARK: - A8 Form View (Section 3 Single Medical Recommendation)

struct A8FormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var appStore
    @Environment(SharedDataStore.self) private var sharedData

    @State private var formData: A8FormData
    @State private var activePopup: A8Section?
    @State private var validationErrors: [FormValidationError] = []
    @State private var docxURL: URL?
    @State private var isExporting = false
    @State private var showShareSheet = false
    @State private var exportError: String?

    enum A8Section: String, CaseIterable, Identifiable {
        case patient = "Patient"
        case practitioner = "Practitioner"
        case clinical = "Clinical Reasons"
        case treatmentSignature = "Treatment & Signature"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .patient: return "person"
            case .practitioner: return "stethoscope"
            case .clinical: return "brain.head.profile"
            case .treatmentSignature: return "signature"
            }
        }
        var color: Color { .purple }
    }

    init() { _formData = State(initialValue: A8FormData()) }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(A8Section.allCases) { section in
                        FormSectionCardWithStatus(
                            title: section.rawValue,
                            icon: section.icon,
                            preview: previewText(for: section),
                            color: section.color,
                            isComplete: isSectionComplete(section)
                        ) {
                            activePopup = section
                        }
                    }
                }
                .padding()

                if !validationErrors.isEmpty {
                    FormValidationErrorView(errors: validationErrors) { error in
                        if let section = sectionForError(error) {
                            activePopup = section
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Form A8")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { exportDOCX() } label: { Image(systemName: "square.and.arrow.up") }
                        .disabled(isExporting)
                }
            }
            .sheet(item: $activePopup) { section in
                A8PopupSheet(section: section, formData: $formData, patientInfo: sharedData.patientInfo)
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = docxURL { ShareSheet(items: [url]) }
            }
            .onAppear { prefillFromSharedData() }
            .onDisappear { syncPatientDataToSharedStore() }
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
            }, source: "A8Form")
        }
        // Sync clinical reasons
        if formData.clinicalReasons.primaryDiagnosisICD10 != .none || formData.clinicalReasons.healthEnabled || formData.clinicalReasons.safetyEnabled {
            sharedData.setClinicalReasons(formData.clinicalReasons, source: "A8Form")
        }
    }

    private func previewText(for section: A8Section) -> String {
        switch section {
        case .patient: return formData.patientName.isEmpty ? "Not entered" : formData.patientName
        case .practitioner: return formData.doctorName.isEmpty ? "Not entered" : formData.doctorName
        case .clinical:
            // Check both mentalDisorderDescription and clinicalReasons
            let hasDirectDescription = !formData.mentalDisorderDescription.isEmpty
            let hasClinicalReasons = !formData.clinicalReasons.displayText.isEmpty || formData.clinicalReasons.primaryDiagnosisICD10 != .none
            return (hasDirectDescription || hasClinicalReasons) ? "Entered" : "Not entered"
        case .treatmentSignature: return DateFormatter.shortDate.string(from: formData.signatureDate)
        }
    }

    private func isSectionComplete(_ section: A8Section) -> Bool {
        switch section {
        case .patient: return !formData.patientName.isEmpty
        case .practitioner: return !formData.doctorName.isEmpty
        case .clinical:
            let hasDirectDescription = !formData.mentalDisorderDescription.isEmpty
            let hasClinicalReasons = !formData.clinicalReasons.displayText.isEmpty || formData.clinicalReasons.primaryDiagnosisICD10 != .none
            return hasDirectDescription || hasClinicalReasons
        case .treatmentSignature: return true
        }
    }

    private func prefillFromSharedData() {
        // Patient from shared data
        formData.patientName = sharedData.patientInfo.fullName
        formData.patientAddress = sharedData.patientInfo.address
        if let age = sharedData.patientInfo.age {
            formData.patientAge = age
        }
        // Doctor from My Details
        formData.doctorName = appStore.clinicianInfo.fullName
        formData.doctorAddress = appStore.clinicianInfo.hospitalOrg
        formData.hospitalName = appStore.clinicianInfo.hospitalOrg  // Pre-fill hospital for detention
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
            let data = A8FormDOCXExporter(formData: formData).generateDOCX()
            DispatchQueue.main.async {
                isExporting = false
                guard let docxData = data else { exportError = "Failed to generate document"; return }
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
                let filename = "Form_A8_\(dateFormatter.string(from: Date())).docx"
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
                do {
                    try docxData.write(to: tempURL)
                    docxURL = tempURL
                    showShareSheet = true
                } catch { exportError = "Failed to save document: \(error.localizedDescription)" }
            }
        }
    }

    private func sectionForError(_ error: FormValidationError) -> A8Section? {
        switch error.field {
        case "patientName", "patientAddress":
            return .patient
        case "doctorName":
            return .practitioner
        case "mentalDisorderDescription", "reasonsForDetention", "clinicalReasons":
            return .clinical
        default:
            return .treatmentSignature
        }
    }
}

struct A8PopupSheet: View {
    let section: A8FormView.A8Section
    @Binding var formData: A8FormData
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
                    switch section {
                    case .patient:
                        FormTextField(label: "Patient Name", text: $formData.patientName, isRequired: true)
                        FormTextEditor(label: "Patient Address", text: $formData.patientAddress, isRequired: true)
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
                                sharedData.updatePatientInfo({ $0.gender = newValue }, source: "A8Form")
                                formData.patientInfo.gender = newValue
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
                                sharedData.updatePatientInfo({ $0.ethnicity = newValue }, source: "A8Form")
                                formData.patientInfo.ethnicity = newValue
                            }
                        }
                        InfoBox(text: "Gender and ethnicity are used to generate personalized clinical narratives.", icon: "info.circle", color: .blue)

                    case .practitioner:
                        FormTextField(label: "Doctor Name", text: $formData.doctorName, isRequired: true)
                        FormTextEditor(label: "Address", text: $formData.doctorAddress)
                        FormToggle(label: "Section 12 Approved", isOn: $formData.isSection12Approved)
                        FormDatePicker(label: "Examination Date", date: $formData.examinationDate)
                        FormToggle(label: "Previous Acquaintance", isOn: $formData.hasPreviousAcquaintance)
                        FormDivider()
                        FormTextField(label: "Hospital for Detention", text: $formData.hospitalName, placeholder: "Enter hospital name", isRequired: true)

                    case .clinical:
                        // Clinical Reasons Builder with patient info for personalized narratives
                        // showInformalSection: true to match A3/A7 - Section 3 also requires justification for why informal not appropriate
                        ClinicalReasonsView(data: $formData.clinicalReasons, patientInfo: combinedPatientInfo, showInformalSection: true, formType: .treatment)

                    case .treatmentSignature:
                        FormSectionHeader(title: "Treatment", systemImage: "cross.case")
                        InfoBox(text: "Appropriate medical treatment is available at the hospital specified.", icon: "building.2", color: .blue)
                        FormDivider()
                        FormSectionHeader(title: "Signature", systemImage: "signature")
                        FormDatePicker(label: "Signature Date", date: $formData.signatureDate, isRequired: true)
                        InfoBox(text: "The form will be signed manually after printing.", icon: "pencil.and.outline", color: .gray)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(section.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .onAppear {
            selectedGender = sharedData.patientInfo.gender
            selectedEthnicity = sharedData.patientInfo.ethnicity
            // Sync to formData for export
            formData.patientInfo.gender = sharedData.patientInfo.gender
            formData.patientInfo.ethnicity = sharedData.patientInfo.ethnicity
        }
    }
}

// MARK: - H1 Form View (Section 5(2) Doctor's Holding Power)
// Matches desktop layout: Patient, Hospital, Practitioner, Reasons for Detention, Delivery & Signature

struct H1FormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var appStore
    @Environment(SharedDataStore.self) private var sharedData

    @State private var formData: H1FormData
    @State private var activePopup: H1Section?
    @State private var validationErrors: [FormValidationError] = []
    @State private var docxURL: URL?
    @State private var isExporting = false
    @State private var showShareSheet = false
    @State private var exportError: String?

    enum H1Section: String, CaseIterable, Identifiable {
        case patient = "Patient"
        case hospital = "Hospital"
        case practitioner = "Practitioner"
        case reasons = "Reasons for Detention"
        case deliverySignature = "Delivery & Signature"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .patient: return "person"
            case .hospital: return "building.2"
            case .practitioner: return "stethoscope"
            case .reasons: return "doc.text"
            case .deliverySignature: return "signature"
            }
        }
        var color: Color { .orange }
    }

    init() { _formData = State(initialValue: H1FormData()) }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(H1Section.allCases) { section in
                        FormSectionCardWithStatus(
                            title: section.rawValue,
                            icon: section.icon,
                            preview: previewText(for: section),
                            color: section.color,
                            isComplete: isSectionComplete(section)
                        ) {
                            activePopup = section
                        }
                    }
                }
                .padding()

                if !validationErrors.isEmpty {
                    FormValidationErrorView(errors: validationErrors) { error in
                        if let section = sectionForError(error) {
                            activePopup = section
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Form H1")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { exportDOCX() } label: { Image(systemName: "square.and.arrow.up") }
                        .disabled(isExporting)
                }
            }
            .sheet(item: $activePopup) { section in
                H1PopupSheet(section: section, formData: $formData, patientInfo: sharedData.patientInfo)
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = docxURL { ShareSheet(items: [url]) }
            }
            .onAppear { prefillFromSharedData() }
            .onDisappear { syncPatientDataToSharedStore() }
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
            }, source: "H1Form")
        }
    }

    private func previewText(for section: H1Section) -> String {
        switch section {
        case .patient: return formData.patientName.isEmpty ? "Not entered" : formData.patientName
        case .hospital: return formData.hospitalName.isEmpty ? "Not entered" : formData.hospitalName
        case .practitioner: return formData.doctorName.isEmpty ? "Not entered" : formData.doctorName
        case .reasons:
            // Check h1Reasons - has diagnosis or any reason selected
            let hasReasons = formData.h1Reasons.diagnosisICD10 != .none ||
                             !formData.h1Reasons.diagnosisCustom.isEmpty ||
                             formData.h1Reasons.refusingToRemain ||
                             formData.h1Reasons.veryUnwell ||
                             formData.h1Reasons.acuteDeteriouration ||
                             formData.h1Reasons.riskToSelf ||
                             formData.h1Reasons.riskToOthers
            return hasReasons ? "Entered" : "Not entered"
        case .deliverySignature: return DateFormatter.shortDate.string(from: formData.signatureDate)
        }
    }

    private func isSectionComplete(_ section: H1Section) -> Bool {
        switch section {
        case .patient: return !formData.patientName.isEmpty
        case .hospital: return !formData.hospitalName.isEmpty
        case .practitioner: return !formData.doctorName.isEmpty
        case .reasons:
            // Check h1Reasons - has diagnosis or any reason selected
            return formData.h1Reasons.diagnosisICD10 != .none ||
                   !formData.h1Reasons.diagnosisCustom.isEmpty ||
                   formData.h1Reasons.refusingToRemain ||
                   formData.h1Reasons.veryUnwell ||
                   formData.h1Reasons.acuteDeteriouration ||
                   formData.h1Reasons.riskToSelf ||
                   formData.h1Reasons.riskToOthers
        case .deliverySignature: return true
        }
    }

    private func prefillFromSharedData() {
        // Patient from shared data
        formData.patientName = sharedData.patientInfo.fullName
        formData.patientAddress = sharedData.patientInfo.address
        if let age = sharedData.patientInfo.age {
            formData.patientAge = age
        }
        // Doctor/Hospital from My Details
        formData.doctorName = appStore.clinicianInfo.fullName
        formData.hospitalName = appStore.clinicianInfo.hospitalOrg
        formData.wardName = appStore.clinicianInfo.wardDepartment
        // H1 reasons from shared clinical data
        if formData.h1Reasons.diagnosisICD10 == .none && sharedData.hasClinicalReasons {
            formData.h1Reasons.diagnosisICD10 = sharedData.clinicalReasons.primaryDiagnosisICD10
        }
    }

    private func exportDOCX() {
        validationErrors = formData.validate()
        isExporting = true
        exportError = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let data = H1FormDOCXExporter(formData: formData).generateDOCX()
            DispatchQueue.main.async {
                isExporting = false
                guard let docxData = data else { exportError = "Failed to generate document"; return }
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
                let filename = "Form_H1_\(dateFormatter.string(from: Date())).docx"
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
                do {
                    try docxData.write(to: tempURL)
                    docxURL = tempURL
                    showShareSheet = true
                } catch { exportError = "Failed to save document: \(error.localizedDescription)" }
            }
        }
    }

    private func sectionForError(_ error: FormValidationError) -> H1Section? {
        switch error.field {
        case "patientName", "patientAddress":
            return .patient
        case "hospitalName", "wardName":
            return .hospital
        case "doctorName":
            return .practitioner
        case "reasonsForHolding":
            return .reasons
        default:
            return .deliverySignature
        }
    }
}

struct H1PopupSheet: View {
    let section: H1FormView.H1Section
    @Binding var formData: H1FormData
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
                    switch section {
                    case .patient:
                        FormTextField(label: "Patient Name", text: $formData.patientName, isRequired: true)
                        FormTextEditor(label: "Patient Address", text: $formData.patientAddress)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Age")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
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
                                sharedData.updatePatientInfo({ $0.gender = newValue }, source: "H1Form")
                                formData.patientInfo.gender = newValue
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
                                sharedData.updatePatientInfo({ $0.ethnicity = newValue }, source: "H1Form")
                                formData.patientInfo.ethnicity = newValue
                            }
                        }
                        InfoBox(text: "Gender and ethnicity are used to generate personalized clinical narratives.", icon: "info.circle", color: .blue)

                    case .hospital:
                        FormTextField(label: "Hospital Name", text: $formData.hospitalName, isRequired: true)

                    case .practitioner:
                        FormTextField(label: "Doctor Name", text: $formData.doctorName, isRequired: true)
                        Picker("Doctor Status", selection: $formData.doctorStatus) {
                            ForEach(DoctorStatus.allCases) { Text($0.rawValue).tag($0) }
                        }
                        if formData.doctorStatus == .nominatedDeputy {
                            FormTextField(label: "Nominated by (RC Name)", text: $formData.nominatedByRC)
                        }
                        FormDivider()
                        FormDatePicker(label: "Report Date", date: $formData.reportDate)
                        FormDatePicker(label: "Report Time", date: $formData.reportTime, includeTime: true)

                    case .reasons:
                        // H1 Reasons Builder with patient info for personalized narratives
                        H1ReasonsView(data: $formData.h1Reasons, patientInfo: combinedPatientInfo)
                        InfoBox(text: "The holding power lasts for up to 72 hours from the time the report is furnished.", icon: "clock", color: .blue)

                    case .deliverySignature:
                        FormSectionHeader(title: "Report Delivery", systemImage: "envelope")
                        InfoBox(text: "The holding power begins when this report is furnished to the hospital managers.", icon: "info.circle", color: .blue)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Delivery Method")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            ForEach(H1DeliveryMethod.allCases) { method in
                                HStack {
                                    Image(systemName: formData.deliveryMethod == method ? "largecircle.fill.circle" : "circle")
                                        .foregroundColor(formData.deliveryMethod == method ? .orange : .gray)
                                    Text(method.rawValue)
                                        .font(.body)
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                                .onTapGesture { formData.deliveryMethod = method }
                            }
                        }
                        .padding(.vertical, 4)

                        if formData.deliveryMethod == .internalMail || formData.deliveryMethod == .handDelivery {
                            FormDatePicker(label: "Delivery Date", date: $formData.deliveryDate)
                        }

                        FormDivider()
                        FormSectionHeader(title: "Signature", systemImage: "signature")
                        FormDatePicker(label: "Signature Date", date: $formData.signatureDate, isRequired: true)
                        FormDatePicker(label: "Signature Time", date: $formData.signatureTime, includeTime: true)
                        InfoBox(text: "The form will be signed manually after printing.", icon: "pencil.and.outline", color: .gray)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(section.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .onAppear {
            selectedGender = sharedData.patientInfo.gender
            selectedEthnicity = sharedData.patientInfo.ethnicity
            // Sync to formData.patientInfo for export
            formData.patientInfo.gender = sharedData.patientInfo.gender
            formData.patientInfo.ethnicity = sharedData.patientInfo.ethnicity
        }
    }
}

// MARK: - H5 Form View (Section 20 Renewal of Detention)
// Matches desktop layout: Patient/Hospital/Clinician, Reasons for Renewal, Why Detention Required, Signatures

struct H5FormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var appStore
    @Environment(SharedDataStore.self) private var sharedData

    @State private var formData: H5FormData
    @State private var activePopup: H5Section?
    @State private var validationErrors: [FormValidationError] = []
    @State private var docxURL: URL?
    @State private var isExporting = false
    @State private var showShareSheet = false
    @State private var exportError: String?

    enum H5Section: String, CaseIterable, Identifiable {
        case details = "Patient / Hospital / Clinician"
        case reasonsForRenewal = "Reasons for Renewal"
        case whyDetentionRequired = "Why Detention Required"
        case signatures = "Signatures"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .details: return "person.text.rectangle"
            case .reasonsForRenewal: return "doc.text"
            case .whyDetentionRequired: return "exclamationmark.shield"
            case .signatures: return "signature"
            }
        }
        var color: Color { .red }
    }

    init() { _formData = State(initialValue: H5FormData()) }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(H5Section.allCases) { section in
                        FormSectionCardWithStatus(
                            title: section.rawValue,
                            icon: section.icon,
                            preview: previewText(for: section),
                            color: section.color,
                            isComplete: isSectionComplete(section)
                        ) {
                            activePopup = section
                        }
                    }
                }
                .padding()

                if !validationErrors.isEmpty {
                    FormValidationErrorView(errors: validationErrors) { error in
                        if let section = sectionForError(error) {
                            activePopup = section
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Form H5")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { exportDOCX() } label: { Image(systemName: "square.and.arrow.up") }
                        .disabled(isExporting)
                }
            }
            .sheet(item: $activePopup) { section in
                H5PopupSheet(section: section, formData: $formData, patientInfo: sharedData.patientInfo)
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = docxURL { ShareSheet(items: [url]) }
            }
            .onAppear { prefillFromSharedData() }
            .onDisappear { syncPatientDataToSharedStore() }
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
            }, source: "H5Form")
        }
        // Sync clinical reasons (including informal section for cross-form sharing)
        if formData.clinicalReasons.primaryDiagnosisICD10 != .none || formData.clinicalReasons.healthEnabled || formData.clinicalReasons.safetyEnabled || formData.clinicalReasons.informalNotAppropriateEnabled {
            sharedData.setClinicalReasons(formData.clinicalReasons, source: "H5Form")
        }
    }

    private func previewText(for section: H5Section) -> String {
        switch section {
        case .details:
            if !formData.patientName.isEmpty && !formData.hospitalName.isEmpty {
                return "\(formData.patientName) / \(formData.hospitalName)"
            } else if !formData.patientName.isEmpty {
                return formData.patientName
            }
            return "Not entered"
        case .reasonsForRenewal:
            // Check both mentalDisorderDescription and clinicalReasons
            let hasDirectDescription = !formData.mentalDisorderDescription.isEmpty
            let hasClinicalReasons = !formData.clinicalReasons.displayText.isEmpty || formData.clinicalReasons.primaryDiagnosisICD10 != .none
            return (hasDirectDescription || hasClinicalReasons) ? "Entered" : "Not entered"
        case .whyDetentionRequired:
            if formData.clinicalReasons.informalNotAppropriateEnabled {
                var count = 0
                if formData.clinicalReasons.informalTriedFailed { count += 1 }
                if formData.clinicalReasons.informalLackInsight { count += 1 }
                if formData.clinicalReasons.informalComplianceIssues { count += 1 }
                if formData.clinicalReasons.informalNeedsMHASupervision { count += 1 }
                return "\(count) reason\(count == 1 ? "" : "s") selected"
            }
            return formData.cannotBeProvidedWithoutDetention.isEmpty ? "Not entered" : "Entered"
        case .signatures: return DateFormatter.shortDate.string(from: formData.signatureDate)
        }
    }

    private func isSectionComplete(_ section: H5Section) -> Bool {
        switch section {
        case .details: return !formData.patientName.isEmpty && !formData.hospitalName.isEmpty && !formData.rcName.isEmpty
        case .reasonsForRenewal:
            let hasDirectDescription = !formData.mentalDisorderDescription.isEmpty
            let hasClinicalReasons = !formData.clinicalReasons.displayText.isEmpty || formData.clinicalReasons.primaryDiagnosisICD10 != .none
            return hasDirectDescription || hasClinicalReasons
        case .whyDetentionRequired: return !formData.cannotBeProvidedWithoutDetention.isEmpty || formData.clinicalReasons.informalNotAppropriateEnabled
        case .signatures: return true
        }
    }

    private func prefillFromSharedData() {
        // Patient from shared data
        formData.patientName = sharedData.patientInfo.fullName
        formData.patientAddress = sharedData.patientInfo.address
        formData.patientDOB = sharedData.patientInfo.dateOfBirth
        // Sync patient info to formData.patientInfo for export
        formData.patientInfo = sharedData.patientInfo
        // Hospital from My Details
        formData.hospitalName = appStore.clinicianInfo.hospitalOrg
        // RC from My Details
        formData.rcName = appStore.clinicianInfo.fullName
        formData.rcProfession = appStore.clinicianInfo.roleTitle
        formData.rcQualifications = appStore.clinicianInfo.discipline
        // Clinical reasons from shared data
        if formData.clinicalReasons.primaryDiagnosisICD10 == .none && sharedData.hasClinicalReasons {
            formData.clinicalReasons = sharedData.clinicalReasons
        }
        // "Why detention required" from shared clinical reasons' informal section
        if formData.cannotBeProvidedWithoutDetention.isEmpty && sharedData.clinicalReasons.informalNotAppropriateEnabled {
            formData.cannotBeProvidedWithoutDetention = generateInformalNotAppropriateText(from: sharedData.clinicalReasons, patient: sharedData.patientInfo)
        }
    }

    private func generateInformalNotAppropriateText(from reasons: ClinicalReasonsData, patient: PatientInfo) -> String {
        let pronouns = patient.pronouns
        let patientRef = patient.shortName.isEmpty ? "the patient" : patient.shortName

        var parts: [String] = []
        if reasons.informalTriedFailed {
            parts.append("informal admission has been tried and failed")
        }
        if reasons.informalLackInsight {
            parts.append("\(patientRef) lacks insight into \(pronouns.possessive) need for admission and treatment")
        }
        if reasons.informalComplianceIssues {
            parts.append("there are compliance issues with treatment")
        }
        if reasons.informalNeedsMHASupervision {
            parts.append("\(patientRef) requires the safeguards of the Mental Health Act")
        }
        if parts.isEmpty {
            return ""
        }
        return "Informal admission is not appropriate because \(parts.joined(separator: ", and "))."
    }

    private func exportDOCX() {
        validationErrors = formData.validate()
        isExporting = true
        exportError = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let data = H5FormDOCXExporter(formData: formData).generateDOCX()
            DispatchQueue.main.async {
                isExporting = false
                guard let docxData = data else { exportError = "Failed to generate document"; return }
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
                let filename = "Form_H5_\(dateFormatter.string(from: Date())).docx"
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
                do {
                    try docxData.write(to: tempURL)
                    docxURL = tempURL
                    showShareSheet = true
                } catch { exportError = "Failed to save document: \(error.localizedDescription)" }
            }
        }
    }

    private func sectionForError(_ error: FormValidationError) -> H5Section? {
        switch error.field {
        case "patientName", "patientAddress", "hospitalName", "rcName":
            return .details
        case "mentalDisorderDescription", "reasonsForDetention", "clinicalReasons":
            return .reasonsForRenewal
        case "cannotBeProvidedWithoutDetention":
            return .whyDetentionRequired
        default:
            return .signatures
        }
    }
}

struct H5PopupSheet: View {
    let section: H5FormView.H5Section
    @Binding var formData: H5FormData
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
        info.manualAge = formData.patientAge  // Use manually entered age for H5
        info.gender = selectedGender
        info.ethnicity = selectedEthnicity
        return info
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch section {
                    case .details:
                        // Patient
                        FormSectionHeader(title: "Patient", systemImage: "person")
                        FormTextField(label: "Patient Name", text: $formData.patientName, isRequired: true)
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
                                sharedData.updatePatientInfo({ $0.gender = newValue }, source: "H5Form")
                                formData.patientInfo.gender = newValue
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
                                sharedData.updatePatientInfo({ $0.ethnicity = newValue }, source: "H5Form")
                                formData.patientInfo.ethnicity = newValue
                            }
                        }
                        FormDivider()
                        // Hospital
                        FormSectionHeader(title: "Hospital", systemImage: "building.2")
                        FormTextField(label: "Hospital Name", text: $formData.hospitalName, isRequired: true)
                        FormTextEditor(label: "Hospital Address", text: $formData.hospitalAddress)
                        FormDivider()
                        // Responsible Clinician
                        FormSectionHeader(title: "Responsible Clinician", systemImage: "stethoscope")
                        FormTextField(label: "RC Name", text: $formData.rcName, isRequired: true)
                        FormDatePicker(label: "Examination Date", date: $formData.examinationDate)
                        FormDatePicker(label: "Detention Expiry Date", date: $formData.detentionExpiryDate)
                        InfoBox(text: "The date current detention authority is due to expire.", icon: "calendar.badge.exclamationmark", color: .orange)

                    case .reasonsForRenewal:
                        // Clinical Reasons Builder with patient info for personalized narratives
                        ClinicalReasonsView(data: $formData.clinicalReasons, patientInfo: combinedPatientInfo, showInformalSection: false, formType: .renewal)
                        FormDivider()
                        FormSectionHeader(title: "Consultation", systemImage: "person.2")
                        FormTextField(label: "Professional Consulted", text: $formData.professionalConsulted, isRequired: true)
                        FormTextField(label: "Email", text: $formData.consulteeEmail)
                        FormTextField(label: "Profession of Consultee", text: $formData.professionOfConsultee)
                        FormDatePicker(label: "Consultation Date", date: $formData.consultationDate)

                    case .whyDetentionRequired:
                        // Informal Admission Not Appropriate section (same as A3)
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle(isOn: $formData.clinicalReasons.informalNotAppropriateEnabled) {
                                Label("Informal Admission Not Appropriate", systemImage: "xmark.circle")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                            }

                            if formData.clinicalReasons.informalNotAppropriateEnabled {
                                VStack(alignment: .leading, spacing: 8) {
                                    Toggle("Tried informal - failed", isOn: $formData.clinicalReasons.informalTriedFailed)
                                    Toggle("Lack of insight", isOn: $formData.clinicalReasons.informalLackInsight)
                                    Toggle("Compliance issues", isOn: $formData.clinicalReasons.informalComplianceIssues)
                                    Toggle("Needs MHA supervision", isOn: $formData.clinicalReasons.informalNeedsMHASupervision)
                                }
                                .padding(.leading)
                                .font(.subheadline)
                            }
                        }
                        .onChange(of: formData.clinicalReasons.informalNotAppropriateEnabled) { _, _ in
                            updateInformalText()
                        }
                        .onChange(of: formData.clinicalReasons.informalTriedFailed) { _, _ in
                            updateInformalText()
                        }
                        .onChange(of: formData.clinicalReasons.informalLackInsight) { _, _ in
                            updateInformalText()
                        }
                        .onChange(of: formData.clinicalReasons.informalComplianceIssues) { _, _ in
                            updateInformalText()
                        }
                        .onChange(of: formData.clinicalReasons.informalNeedsMHASupervision) { _, _ in
                            updateInformalText()
                        }

                        FormDivider()

                        FormTextEditor(label: "Cannot Be Provided Without Detention", text: $formData.cannotBeProvidedWithoutDetention, placeholder: "Generated from selections above, or enter manually", minHeight: 120, isRequired: true)
                        InfoBox(text: "The patient cannot consent or is not consenting to treatment, and detention is necessary to provide appropriate treatment.", icon: "exclamationmark.triangle", color: .orange)
                        FormDivider()
                        Picker("Renewal Period", selection: $formData.renewalPeriod) {
                            ForEach(RenewalPeriod.allCases) { Text($0.rawValue).tag($0) }
                        }
                        InfoBox(text: "First renewal: 6 months. Subsequent renewals: 1 year each.", icon: "calendar", color: .blue)

                    case .signatures:
                        FormSectionHeader(title: "Part 1 Signature", systemImage: "signature")
                        FormDatePicker(label: "Signature Date", date: $formData.signatureDate, isRequired: true)
                        InfoBox(text: "The form will be signed manually after printing.", icon: "pencil.and.outline", color: .gray)

                        FormDivider()
                        FormSectionHeader(title: "Part 3 - Report Delivery", systemImage: "envelope")
                        InfoBox(text: "How you are furnishing this report to the hospital managers.", icon: "info.circle", color: .blue)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Delivery Method")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            ForEach(H1DeliveryMethod.allCases) { method in
                                HStack {
                                    Image(systemName: formData.deliveryMethod == method ? "largecircle.fill.circle" : "circle")
                                        .foregroundColor(formData.deliveryMethod == method ? .orange : .gray)
                                    Text(method.rawValue)
                                        .font(.body)
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                                .onTapGesture { formData.deliveryMethod = method }
                            }
                        }
                        .padding(.vertical, 4)

                        if formData.deliveryMethod == .internalMail || formData.deliveryMethod == .handDelivery {
                            FormDatePicker(label: "Delivery Date", date: $formData.deliveryDate)
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(section.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .onAppear {
            selectedGender = sharedData.patientInfo.gender
            selectedEthnicity = sharedData.patientInfo.ethnicity
            // Sync ALL patient info to formData.patientInfo for export
            let nameParts = formData.patientName.components(separatedBy: " ")
            formData.patientInfo.firstName = nameParts.first ?? ""
            formData.patientInfo.lastName = nameParts.dropFirst().joined(separator: " ")
            formData.patientInfo.dateOfBirth = formData.patientDOB
            formData.patientInfo.gender = sharedData.patientInfo.gender
            formData.patientInfo.ethnicity = sharedData.patientInfo.ethnicity
        }
        .onChange(of: formData.patientName) { _, newValue in
            // Keep formData.patientInfo synced when patient name changes
            let nameParts = newValue.components(separatedBy: " ")
            formData.patientInfo.firstName = nameParts.first ?? ""
            formData.patientInfo.lastName = nameParts.dropFirst().joined(separator: " ")
        }
        .onChange(of: formData.patientDOB) { _, newValue in
            // Keep formData.patientInfo synced when DOB changes
            formData.patientInfo.dateOfBirth = newValue
        }
    }

    private func updateInformalText() {
        let pronouns = combinedPatientInfo.pronouns
        let patientRef = combinedPatientInfo.shortName.isEmpty ? "the patient" : combinedPatientInfo.shortName

        var parts: [String] = []
        if formData.clinicalReasons.informalTriedFailed {
            parts.append("informal admission has been tried and failed")
        }
        if formData.clinicalReasons.informalLackInsight {
            parts.append("\(patientRef) lacks insight into \(pronouns.possessive) need for admission and treatment")
        }
        if formData.clinicalReasons.informalComplianceIssues {
            parts.append("there are compliance issues with treatment")
        }
        if formData.clinicalReasons.informalNeedsMHASupervision {
            parts.append("\(patientRef) requires the safeguards of the Mental Health Act")
        }
        if !parts.isEmpty {
            formData.cannotBeProvidedWithoutDetention = "Informal admission is not appropriate because \(parts.joined(separator: ", and "))."
        }
    }
}
