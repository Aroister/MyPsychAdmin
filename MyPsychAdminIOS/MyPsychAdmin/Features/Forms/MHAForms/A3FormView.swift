//
//  A3FormView.swift
//  MyPsychAdmin
//
//  Form A3 - Section 2 Joint Medical Recommendation
//  Uses popup sheets for data entry (matching desktop pattern)
//

import SwiftUI

struct A3FormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var appStore
    @Environment(SharedDataStore.self) private var sharedData

    @State private var formData: A3FormData
    @State private var activePopup: A3Section? = nil
    @State private var validationErrors: [FormValidationError] = []
    @State private var docxURL: URL?
    @State private var isExporting = false
    @State private var showShareSheet = false
    @State private var exportError: String?
    @State private var hasPerformedInitialPrefill = false

    enum A3Section: String, CaseIterable, Identifiable {
        case patient = "Patient Details"
        case doctor1 = "First Practitioner"
        case doctor2 = "Second Practitioner"
        case clinical = "Clinical Opinion"
        case signature = "Signatures"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .patient: return "person"
            case .doctor1: return "1.circle"
            case .doctor2: return "2.circle"
            case .clinical: return "brain.head.profile"
            case .signature: return "signature"
            }
        }
    }

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    init() {
        _formData = State(initialValue: A3FormData())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Form header
                    VStack(spacing: 8) {
                        Text("A3")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("Joint Medical Recommendation")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)

                    // Validation errors - clickable to navigate to section
                    if !validationErrors.isEmpty {
                        FormValidationErrorView(errors: validationErrors) { error in
                            if let section = sectionForError(error) {
                                activePopup = section
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Section cards grid
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(A3Section.allCases) { section in
                            FormSectionCardWithStatus(
                                title: section.rawValue,
                                icon: section.icon,
                                preview: previewText(for: section),
                                color: .green,
                                hasError: sectionHasError(section),
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
            .navigationTitle("Form A3")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button { exportDOCX() } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .disabled(isExporting)
                        Menu {
                            Button(role: .destructive) {
                                formData = A3FormData()
                                prefillFromSharedData()
                            } label: {
                                Label("Clear Form", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .onAppear {
                if !hasPerformedInitialPrefill {
                    prefillFromSharedData()
                    hasPerformedInitialPrefill = true
                }
            }
            .onDisappear {
                syncPatientDataToSharedStore()
            }
            .sheet(item: $activePopup) { section in
                A3PopupSheet(section: section, formData: $formData, errorFields: errorFieldsForSection(section))
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = docxURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    private func syncPatientDataToSharedStore() {
        // Sync patient data back to SharedDataStore for other forms to use
        if !formData.patientName.isEmpty {
            let nameParts = formData.patientName.components(separatedBy: " ")
            let firstName = nameParts.first ?? ""
            let lastName = nameParts.dropFirst().joined(separator: " ")
            sharedData.updatePatientInfo({ info in
                info.firstName = firstName
                info.lastName = lastName
                info.address = formData.patientAddress
                info.manualAge = formData.patientAge
            }, source: "A3Form")
        }
        // Sync clinical reasons back to SharedDataStore
        if sharedData.hasClinicalReasons == false || formData.clinicalReasons.primaryDiagnosisICD10 != .none {
            sharedData.setClinicalReasons(formData.clinicalReasons, source: "A3Form")
        }
        // Sync second practitioner data back to SharedDataStore for A7 and other forms
        if !formData.doctor2Name.isEmpty {
            sharedData.updateSecondPractitioner({ info in
                info.name = formData.doctor2Name
                info.email = formData.doctor2Email
                info.address = formData.doctor2Address
                info.examinationDate = formData.doctor2ExaminationDate
            }, source: "A3Form")
        }
    }

    private func previewText(for section: A3Section) -> String {
        switch section {
        case .patient: return formData.patientName.isEmpty ? "Not entered" : formData.patientName
        case .doctor1: return formData.doctor1Name.isEmpty ? "Not entered" : formData.doctor1Name
        case .doctor2: return formData.doctor2Name.isEmpty ? "Not entered" : formData.doctor2Name
        case .clinical:
            if !formData.clinicalReasons.primaryDiagnosis.isEmpty {
                return formData.clinicalReasons.primaryDiagnosis
            } else if !formData.mentalDisorderDescription.isEmpty {
                return "Entered"
            } else {
                return "Not entered"
            }
        case .signature: return DateFormatter.shortDate.string(from: formData.doctor1SignatureDate)
        }
    }

    private func errorFieldsForSection(_ section: A3Section) -> Set<String> {
        let allErrorFields = Set(validationErrors.map { $0.field })
        switch section {
        case .patient: return allErrorFields.intersection(["patientName", "patientAddress"])
        case .doctor1: return allErrorFields.intersection(["doctor1Name"])
        case .doctor2: return allErrorFields.intersection(["doctor2Name"])
        case .clinical: return allErrorFields.intersection(["mentalDisorderDescription", "reasonsForDetention", "clinicalReasons"])
        case .signature: return []
        }
    }

    private func sectionHasError(_ section: A3Section) -> Bool {
        !errorFieldsForSection(section).isEmpty
    }

    private func sectionForError(_ error: FormValidationError) -> A3Section? {
        switch error.field {
        case "patientName", "patientAddress":
            return .patient
        case "doctor1Name":
            return .doctor1
        case "doctor2Name":
            return .doctor2
        case "mentalDisorderDescription", "reasonsForDetention":
            return .clinical
        default:
            return nil
        }
    }

    private func isSectionComplete(_ section: A3Section) -> Bool {
        switch section {
        case .patient: return !formData.patientName.isEmpty && !formData.patientAddress.isEmpty
        case .doctor1: return !formData.doctor1Name.isEmpty
        case .doctor2: return !formData.doctor2Name.isEmpty
        case .clinical: return !formData.clinicalReasons.primaryDiagnosis.isEmpty || !formData.mentalDisorderDescription.isEmpty
        case .signature: return true
        }
    }

    private func prefillFromSharedData() {
        // Patient from shared data - only if form field is empty
        if formData.patientName.isEmpty && !sharedData.patientInfo.fullName.isEmpty {
            formData.patientName = sharedData.patientInfo.fullName
        }
        if formData.patientAddress.isEmpty && !sharedData.patientInfo.address.isEmpty {
            formData.patientAddress = sharedData.patientInfo.address
        }
        if let age = sharedData.patientInfo.age {
            formData.patientAge = age
        }

        // Doctor 1 (First Practitioner) from My Details - only if form field is empty
        if formData.doctor1Name.isEmpty && !appStore.clinicianInfo.fullName.isEmpty {
            formData.doctor1Name = appStore.clinicianInfo.fullName
        }
        if formData.doctor1Email.isEmpty && !appStore.clinicianInfo.email.isEmpty {
            formData.doctor1Email = appStore.clinicianInfo.email
        }
        if formData.doctor1Address.isEmpty && !appStore.clinicianInfo.hospitalOrg.isEmpty {
            formData.doctor1Address = appStore.clinicianInfo.hospitalOrg
        }

        // Clinical reasons from shared data - only if form field is empty
        if formData.clinicalReasons.primaryDiagnosisICD10 == .none && sharedData.hasClinicalReasons {
            formData.clinicalReasons = sharedData.clinicalReasons
        }

        // Doctor 2 (Second Practitioner) from shared data - only if form field is empty
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
            let data = A3FormDOCXExporter(formData: formData).generateDOCX()

            DispatchQueue.main.async {
                isExporting = false

                guard let docxData = data else {
                    exportError = "Failed to generate document"
                    return
                }

                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
                let timestamp = dateFormatter.string(from: Date())
                let filename = "Form_A3_\(timestamp).docx"
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
}

// MARK: - A3 Popup Sheet
struct A3PopupSheet: View {
    let section: A3FormView.A3Section
    @Binding var formData: A3FormData
    var errorFields: Set<String> = []
    @Environment(\.dismiss) private var dismiss
    @Environment(SharedDataStore.self) private var sharedData

    // Local state for gender/ethnicity that syncs with sharedData
    @State private var selectedGender: Gender = .notSpecified
    @State private var selectedEthnicity: Ethnicity = .notSpecified

    // Computed patient info combining form data with shared gender/ethnicity
    private var combinedPatientInfo: PatientInfo {
        var info = PatientInfo()
        info.firstName = formData.patientName.components(separatedBy: " ").first ?? ""
        info.lastName = formData.patientName.components(separatedBy: " ").dropFirst().joined(separator: " ")
        info.address = formData.patientAddress
        info.manualAge = formData.patientAge
        info.gender = sharedData.patientInfo.gender
        info.ethnicity = sharedData.patientInfo.ethnicity
        return info
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        sectionContent
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

            // Gender picker (for narrative generation)
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
                    sharedData.updatePatientInfo({ $0.gender = newValue }, source: "A3Form")
                    formData.patientInfo.gender = newValue  // Also update formData for export
                }
            }

            // Ethnicity picker (for narrative generation)
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
                    sharedData.updatePatientInfo({ $0.ethnicity = newValue }, source: "A3Form")
                    formData.patientInfo.ethnicity = newValue  // Also update formData for export
                }
            }

            InfoBox(text: "Gender and ethnicity are used to generate personalized clinical narratives (e.g., 'Mr John Smith is a 43 year old Caucasian man...')", icon: "info.circle", color: .blue)

        case .doctor1:
            FormSectionHeader(title: "First Practitioner", systemImage: "1.circle")
            FormTextField(label: "Full Name", text: $formData.doctor1Name, isRequired: true, hasError: errorFields.contains("doctor1Name"), fieldId: "doctor1Name")
            FormTextField(label: "Email", text: $formData.doctor1Email, keyboardType: .emailAddress)
            FormTextEditor(label: "Address", text: $formData.doctor1Address)
            FormDivider()
            FormDatePicker(label: "Examination Date", date: $formData.doctor1ExaminationDate)
            FormDivider()
            FormToggle(
                label: "Previous Acquaintance",
                isOn: Binding(
                    get: { formData.doctor1PreviousAcquaintance != .none },
                    set: { formData.doctor1PreviousAcquaintance = $0 ? .treatedPreviously : .none }
                ),
                description: "I had previous acquaintance with the patient before I conducted that examination"
            )
            FormToggle(
                label: "Section 12 Approved",
                isOn: $formData.doctor1IsSection12Approved,
                description: "I am approved under section 12 of the Act as having special experience in the diagnosis or treatment of mental disorder"
            )

        case .doctor2:
            FormSectionHeader(title: "Second Practitioner", systemImage: "2.circle")
            FormTextField(label: "Full Name", text: $formData.doctor2Name, isRequired: true, hasError: errorFields.contains("doctor2Name"), fieldId: "doctor2Name")
            FormTextField(label: "Email", text: $formData.doctor2Email, keyboardType: .emailAddress)
            FormTextEditor(label: "Address", text: $formData.doctor2Address)
            FormDivider()
            FormDatePicker(label: "Examination Date", date: $formData.doctor2ExaminationDate)
            FormDivider()
            FormToggle(
                label: "Previous Acquaintance",
                isOn: Binding(
                    get: { formData.doctor2PreviousAcquaintance != .none },
                    set: { formData.doctor2PreviousAcquaintance = $0 ? .treatedPreviously : .none }
                ),
                description: "I had previous acquaintance with the patient before I conducted that examination"
            )
            FormToggle(
                label: "Section 12 Approved",
                isOn: $formData.doctor2IsSection12Approved,
                description: "I am approved under section 12 of the Act as having special experience in the diagnosis or treatment of mental disorder"
            )

        case .clinical:
            // Show error banner if clinical reasons are missing
            if errorFields.contains("mentalDisorderDescription") || errorFields.contains("reasonsForDetention") || errorFields.contains("clinicalReasons") {
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

            // Clinical Reasons Builder - use combined patient info from form + shared gender/ethnicity
            ClinicalReasonsView(data: $formData.clinicalReasons, patientInfo: combinedPatientInfo, showInformalSection: true, formType: .assessment)

        case .signature:
            FormSectionHeader(title: "First Practitioner Signature", systemImage: "1.circle")
            FormDatePicker(label: "Signature Date", date: $formData.doctor1SignatureDate)
            FormDivider()
            FormSectionHeader(title: "Second Practitioner Signature", systemImage: "2.circle")
            FormDatePicker(label: "Signature Date", date: $formData.doctor2SignatureDate)
            InfoBox(text: "The form will be signed manually after printing.", icon: "pencil.and.outline", color: .gray)
        }
    }
}

#Preview {
    A3FormView()
        .environment(AppStore())
        .environment(SharedDataStore.shared)
}
