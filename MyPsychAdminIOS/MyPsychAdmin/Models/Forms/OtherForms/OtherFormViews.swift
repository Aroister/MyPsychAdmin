//
//  OtherFormViews.swift
//  MyPsychAdmin
//
//  Form views for T2, M2 - Popup-based card layout
//

import SwiftUI

// MARK: - T2 Form View (Certificate of Consent to Treatment)
// Matches desktop layout: Clinician, Patient, Treatment, Signature
struct T2FormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var appStore
    @Environment(SharedDataStore.self) private var sharedData

    @State private var formData: T2FormData = T2FormData()
    @State private var activePopup: T2Section?
    @State private var validationErrors: [FormValidationError] = []
    @State private var docxURL: URL?
    @State private var isExporting = false
    @State private var showShareSheet = false
    @State private var exportError: String?

    enum T2Section: String, CaseIterable, Identifiable {
        case clinician = "Clinician"
        case patient = "Patient"
        case treatment = "Treatment"
        case signature = "Signature"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .clinician: return "stethoscope"
            case .patient: return "person"
            case .treatment: return "pills"
            case .signature: return "signature"
            }
        }

        // Map form fields to sections
        static func sectionForField(_ field: String) -> T2Section? {
            switch field {
            case "acName": return .clinician
            case "patientName": return .patient
            case "treatment", "treatmentDescription": return .treatment
            default: return nil
            }
        }
    }

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    // Get error fields for a specific section
    private func errorFieldsForSection(_ section: T2Section) -> Set<String> {
        Set(validationErrors.compactMap { error in
            if T2Section.sectionForField(error.field) == section {
                return error.field
            }
            return nil
        })
    }

    // Check if section has any errors
    private func sectionHasError(_ section: T2Section) -> Bool {
        !errorFieldsForSection(section).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Form header
                    VStack(spacing: 8) {
                        Text("T2")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("Certificate of Consent to Treatment")
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
                        ForEach(T2Section.allCases) { section in
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
            .navigationTitle("Form T2")
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
                T2PopupSheet(
                    section: section,
                    formData: $formData,
                    patientInfo: sharedData.patientInfo,
                    errorFields: errorFieldsForSection(section)
                )
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
            }, source: "T2Form")
        }
    }

    private func previewText(for section: T2Section) -> String {
        switch section {
        case .clinician: return formData.acName.isEmpty ? "Not entered" : formData.acName
        case .patient: return formData.patientName.isEmpty ? "Not entered" : formData.patientName
        case .treatment:
            let hasTreatmentDesc = !formData.treatmentDescription.isEmpty
            let hasMedications = !formData.t2Treatment.generatedText.isEmpty
            return (hasTreatmentDesc || hasMedications) ? "Entered" : "Not entered"
        case .signature: return DateFormatter.shortDate.string(from: formData.signatureDate)
        }
    }

    private func prefillFromSharedData() {
        // Patient from shared data
        formData.patientName = sharedData.patientInfo.fullName
        formData.patientAddress = sharedData.patientInfo.address
        // Approved Clinician from My Details
        formData.acName = appStore.clinicianInfo.fullName
        formData.acProfession = appStore.clinicianInfo.roleTitle
        formData.hospitalName = appStore.clinicianInfo.hospitalOrg
    }

    private func exportDOCX() {
        validationErrors = formData.validate()
        isExporting = true
        exportError = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let data = T2FormDOCXExporter(formData: formData).generateDOCX()
            DispatchQueue.main.async {
                isExporting = false
                guard let docxData = data else { exportError = "Failed to generate document"; return }
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
                let filename = "Form_T2_\(dateFormatter.string(from: Date())).docx"
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
                do {
                    try docxData.write(to: tempURL)
                    docxURL = tempURL
                    showShareSheet = true
                } catch { exportError = "Failed to save document: \(error.localizedDescription)" }
            }
        }
    }

    private func isSectionComplete(_ section: T2Section) -> Bool {
        switch section {
        case .clinician: return !formData.acName.isEmpty
        case .patient: return !formData.patientName.isEmpty
        case .treatment: return !formData.treatmentDescription.isEmpty || !formData.t2Treatment.generatedText.isEmpty
        case .signature: return true
        }
    }

    private func sectionForError(_ error: FormValidationError) -> T2Section? {
        switch error.field {
        case "acName", "acProfession", "hospitalName":
            return .clinician
        case "patientName", "patientAddress":
            return .patient
        case "treatmentDescription":
            return .treatment
        default:
            return .signature
        }
    }
}

// MARK: - T2 Popup Sheet
struct T2PopupSheet: View {
    let section: T2FormView.T2Section
    @Binding var formData: T2FormData
    var patientInfo: PatientInfo
    var errorFields: Set<String> = []
    @Environment(\.dismiss) private var dismiss

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
                    // Scroll to first error field after a short delay
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
        case .clinician:
            FormTextField(
                label: "Clinician Name",
                text: $formData.acName,
                isRequired: true,
                hasError: errorFields.contains("acName"),
                fieldId: "acName"
            )
            FormTextField(label: "Profession", text: $formData.acProfession, fieldId: "acProfession")
            FormDivider()
            FormTextField(label: "Hospital Name", text: $formData.hospitalName, fieldId: "hospitalName")
            FormDivider()

            // Certifier Type - Approved Clinician or SOAD
            VStack(alignment: .leading, spacing: 8) {
                Text("I am certifying as")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                ForEach(T2CertifierType.allCases) { type in
                    HStack {
                        Image(systemName: formData.certifierType == type ? "largecircle.fill.circle" : "circle")
                            .foregroundColor(formData.certifierType == type ? .blue : .gray)
                        Text(type.rawValue)
                            .font(.body)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { formData.certifierType = type }
                }
            }
            .padding(.vertical, 4)
            InfoBox(text: "Select whether you are the approved clinician in charge of treatment or a SOAD. The other option will be struck through on the form.", icon: "info.circle", color: .blue)

        case .patient:
            FormTextField(
                label: "Patient Name",
                text: $formData.patientName,
                isRequired: true,
                hasError: errorFields.contains("patientName"),
                fieldId: "patientName"
            )
            FormTextEditor(label: "Patient Address", text: $formData.patientAddress, fieldId: "patientAddress")

        case .treatment:
            // Show error banner if treatment is missing
            if errorFields.contains("treatment") || errorFields.contains("treatmentDescription") {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                    Text("Treatment description is required")
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
                .id("treatment")
            }
            // T2 Treatment View with medication builder
            T2TreatmentView(data: $formData.t2Treatment)
            FormDivider()
            FormDatePicker(label: "Consent Date", date: $formData.consentDate)

        case .signature:
            FormDatePicker(label: "Signature Date", date: $formData.signatureDate, isRequired: true)
            InfoBox(text: "The form will be signed manually after printing.", icon: "pencil.and.outline", color: .gray)
        }
    }
}

// MARK: - M2 Form View (Report Barring Discharge by Nearest Relative)
// Matches desktop layout: Hospital & Notice Details, Patient Details, Reasons, RC & Signature
struct M2FormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var appStore
    @Environment(SharedDataStore.self) private var sharedData

    @State private var formData: M2FormData = M2FormData()
    @State private var activePopup: M2Section?
    @State private var validationErrors: [FormValidationError] = []
    @State private var docxURL: URL?
    @State private var isExporting = false
    @State private var showShareSheet = false
    @State private var exportError: String?

    enum M2Section: String, CaseIterable, Identifiable {
        case hospital = "Hospital & Notice Details"
        case patient = "Patient Details"
        case reasons = "Reasons"
        case signature = "RC & Signature"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .hospital: return "building.2"
            case .patient: return "person"
            case .reasons: return "doc.text"
            case .signature: return "signature"
            }
        }

        // Map form fields to sections
        static func sectionForField(_ field: String) -> M2Section? {
            switch field {
            case "hospitalName", "hospital": return .hospital
            case "patientName": return .patient
            case "reasons", "dangerousIfDischarged": return .reasons
            case "rcName": return .signature
            default: return nil
            }
        }
    }

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    // Get error fields for a specific section
    private func errorFieldsForSection(_ section: M2Section) -> Set<String> {
        Set(validationErrors.compactMap { error in
            if M2Section.sectionForField(error.field) == section {
                return error.field
            }
            return nil
        })
    }

    // Check if section has any errors
    private func sectionHasError(_ section: M2Section) -> Bool {
        !errorFieldsForSection(section).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Form header
                    VStack(spacing: 8) {
                        Text("M2")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("Report Barring Discharge by NR")
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
                        ForEach(M2Section.allCases) { section in
                            FormSectionCardWithStatus(
                                title: section.rawValue,
                                icon: section.icon,
                                preview: previewText(for: section),
                                color: .pink,
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
            .navigationTitle("Form M2")
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
                M2PopupSheet(
                    section: section,
                    formData: $formData,
                    patientInfo: sharedData.patientInfo,
                    errorFields: errorFieldsForSection(section)
                )
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
            }, source: "M2Form")
        }
        // Sync clinical reasons back to shared data
        if !formData.clinicalReasons.generatedText.isEmpty {
            sharedData.setClinicalReasons(formData.clinicalReasons, source: "M2Form")
        }
    }

    private func previewText(for section: M2Section) -> String {
        switch section {
        case .hospital: return formData.hospitalName.isEmpty ? "Not entered" : formData.hospitalName
        case .patient: return formData.patientName.isEmpty ? "Not entered" : formData.patientName
        case .reasons:
            let hasManualReasons = !formData.dangerousIfDischarged.isEmpty
            let hasGeneratedReasons = !formData.clinicalReasons.generatedText.isEmpty
            return (hasManualReasons || hasGeneratedReasons) ? "Entered" : "Not entered"
        case .signature: return DateFormatter.shortDate.string(from: formData.signatureDate)
        }
    }

    private func prefillFromSharedData() {
        // Patient from shared data
        formData.patientName = sharedData.patientInfo.fullName
        formData.patientAddress = sharedData.patientInfo.address
        formData.patientInfo = sharedData.patientInfo
        // Hospital from My Details
        formData.hospitalName = appStore.clinicianInfo.hospitalOrg
        // RC from My Details
        formData.rcName = appStore.clinicianInfo.fullName
        formData.rcProfession = appStore.clinicianInfo.roleTitle
        formData.rcEmail = appStore.clinicianInfo.email
        // Load clinical reasons from shared data (from A3, A4, A7, A8, H5, CTO forms)
        if sharedData.hasClinicalReasons {
            formData.clinicalReasons = sharedData.clinicalReasons
            // Also populate dangerousIfDischarged from clinical reasons display text
            if formData.dangerousIfDischarged.isEmpty {
                formData.dangerousIfDischarged = sharedData.clinicalReasons.displayText
            }
        }
        // Nearest relative from shared data (from A2, A6)
        if sharedData.hasNearestRelative {
            formData.nrName = sharedData.nearestRelative.name
            formData.nrAddress = sharedData.nearestRelative.address
            formData.nrRelationship = sharedData.nearestRelative.relationship
        }
    }

    private func exportDOCX() {
        validationErrors = formData.validate()
        isExporting = true
        exportError = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let data = M2FormDOCXExporter(formData: formData).generateDOCX()
            DispatchQueue.main.async {
                isExporting = false
                guard let docxData = data else { exportError = "Failed to generate document"; return }
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
                let filename = "Form_M2_\(dateFormatter.string(from: Date())).docx"
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
                do {
                    try docxData.write(to: tempURL)
                    docxURL = tempURL
                    showShareSheet = true
                } catch { exportError = "Failed to save document: \(error.localizedDescription)" }
            }
        }
    }

    private func isSectionComplete(_ section: M2Section) -> Bool {
        switch section {
        case .hospital: return !formData.hospitalName.isEmpty
        case .patient: return !formData.patientName.isEmpty
        case .reasons: return !formData.dangerousIfDischarged.isEmpty || !formData.clinicalReasons.generatedText.isEmpty
        case .signature: return !formData.rcName.isEmpty
        }
    }

    private func sectionForError(_ error: FormValidationError) -> M2Section? {
        switch error.field {
        case "hospitalName", "hospitalAddress":
            return .hospital
        case "patientName", "patientAddress":
            return .patient
        case "dangerousIfDischarged", "clinicalReasons":
            return .reasons
        default:
            return .signature
        }
    }
}

// MARK: - M2 Popup Sheet
struct M2PopupSheet: View {
    let section: M2FormView.M2Section
    @Binding var formData: M2FormData
    var patientInfo: PatientInfo
    var errorFields: Set<String> = []
    @Environment(\.dismiss) private var dismiss
    @Environment(SharedDataStore.self) private var sharedData

    // Local state for gender/ethnicity that syncs with sharedData
    @State private var selectedGender: Gender = .notSpecified
    @State private var selectedEthnicity: Ethnicity = .notSpecified

    private var combinedPatientInfo: PatientInfo {
        var info = formData.patientInfo
        info.firstName = formData.patientName.components(separatedBy: " ").first ?? ""
        info.lastName = formData.patientName.components(separatedBy: " ").dropFirst().joined(separator: " ")
        info.address = formData.patientAddress
        info.gender = selectedGender
        info.ethnicity = selectedEthnicity
        info.manualAge = formData.patientAge  // Use manually entered age
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
                    // Initialize state from shared data
                    selectedGender = sharedData.patientInfo.gender
                    selectedEthnicity = sharedData.patientInfo.ethnicity
                    // Sync patient info to formData.patientInfo for export
                    formData.patientInfo = combinedPatientInfo
                    // Scroll to first error field after a short delay
                    if let firstError = errorFields.first {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation {
                                proxy.scrollTo(firstError, anchor: .center)
                            }
                        }
                    }
                }
                .onChange(of: selectedGender) { _, newValue in
                    sharedData.updatePatientInfo({ $0.gender = newValue }, source: "M2Form")
                    formData.patientInfo = combinedPatientInfo
                }
                .onChange(of: selectedEthnicity) { _, newValue in
                    sharedData.updatePatientInfo({ $0.ethnicity = newValue }, source: "M2Form")
                    formData.patientInfo = combinedPatientInfo
                }
                .onChange(of: formData.patientAge) { _, newValue in
                    sharedData.updatePatientInfo({ $0.manualAge = newValue }, source: "M2Form")
                    formData.patientInfo = combinedPatientInfo
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
        case .hospital:
            FormTextField(
                label: "Hospital Name",
                text: $formData.hospitalName,
                isRequired: true,
                hasError: errorFields.contains("hospitalName") || errorFields.contains("hospital"),
                fieldId: "hospitalName"
            )
            FormTextEditor(label: "Hospital Address", text: $formData.hospitalAddress, fieldId: "hospitalAddress")
            FormDivider()
            FormSectionHeader(title: "Notice Details", systemImage: "envelope")
            FormDatePicker(label: "Notice of Discharge Received", date: $formData.dischargeNoticeDate)
            FormTimePicker(label: "Time of Notice", date: $formData.dischargeNoticeTime)
            FormDivider()
            FormSectionHeader(title: "Method of Transmission", systemImage: "paperplane")
            VStack(alignment: .leading, spacing: 8) {
                ForEach(M2TransmissionMethod.allCases) { method in
                    Button {
                        formData.transmissionMethod = method
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: formData.transmissionMethod == method ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(formData.transmissionMethod == method ? .blue : .secondary)
                                .font(.title3)
                            Text(method.formText)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(formData.transmissionMethod == method ? Color.blue.opacity(0.1) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

        case .patient:
            FormTextField(
                label: "Patient Name",
                text: $formData.patientName,
                isRequired: true,
                hasError: errorFields.contains("patientName"),
                fieldId: "patientName"
            )
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
            }
            FormDivider()
            FormSectionHeader(title: "Nearest Relative", systemImage: "person.2")
            FormTextField(label: "NR Name", text: $formData.nrName, fieldId: "nrName")
            FormTextEditor(label: "NR Address", text: $formData.nrAddress, fieldId: "nrAddress")

        case .reasons:
            // Show error banner if reasons are missing
            if errorFields.contains("reasons") || errorFields.contains("dangerousIfDischarged") {
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
                .id("reasons")
            }
            // Clinical Reasons Builder with patient info for barring discharge reasons
            ClinicalReasonsView(data: $formData.clinicalReasons, patientInfo: combinedPatientInfo, showInformalSection: false, formType: .cto)
            InfoBox(text: "The RC must demonstrate that the patient would be dangerous to themselves or others if discharged.", icon: "exclamationmark.triangle", color: .orange)

        case .signature:
            FormSectionHeader(title: "Responsible Clinician", systemImage: "stethoscope")
            FormTextField(
                label: "RC Name",
                text: $formData.rcName,
                isRequired: true,
                hasError: errorFields.contains("rcName"),
                fieldId: "rcName"
            )
            FormTextField(label: "Email", text: $formData.rcEmail, fieldId: "rcEmail")
            FormTextField(label: "RC Profession", text: $formData.rcProfession, fieldId: "rcProfession")
            FormDivider()
            FormDatePicker(label: "Signature Date", date: $formData.signatureDate, isRequired: true)
            InfoBox(text: "The form will be signed manually after printing.", icon: "pencil.and.outline", color: .gray)
        }
    }
}
