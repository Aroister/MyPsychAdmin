//
//  A2FormView.swift
//  MyPsychAdmin
//
//  Form A2 - Section 2 Application by AMHP
//  Uses popup sheets for data entry (matching desktop pattern)
//

import SwiftUI

struct A2FormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var appStore
    @Environment(SharedDataStore.self) private var sharedData

    @State private var formData: A2FormData
    @State private var activePopup: A2Section? = nil
    @State private var validationErrors: [FormValidationError] = []
    @State private var docxURL: URL?
    @State private var isExporting = false
    @State private var showShareSheet = false
    @State private var exportError: String?

    enum A2Section: String, CaseIterable, Identifiable {
        case hospital = "Hospital"
        case amhp = "AMHP Details"
        case patient = "Patient Details"
        case authority = "Local Authority"
        case nearestRelative = "Nearest Relative"
        case interview = "Patient Interview"
        case medical = "Medical Recommendations"
        case signature = "Signature"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .hospital: return "building.2"
            case .amhp: return "person.badge.shield.checkmark"
            case .patient: return "person"
            case .authority: return "building.columns"
            case .nearestRelative: return "person.2"
            case .interview: return "bubble.left.and.bubble.right"
            case .medical: return "stethoscope"
            case .signature: return "signature"
            }
        }

        var color: Color {
            switch self {
            case .hospital: return .blue
            case .amhp: return .purple
            case .patient: return .green
            case .authority: return .orange
            case .nearestRelative: return .pink
            case .interview: return .teal
            case .medical: return .indigo
            case .signature: return .gray
            }
        }
    }

    init() {
        _formData = State(initialValue: A2FormData())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Validation errors at top
                    if !validationErrors.isEmpty {
                        FormValidationErrorView(errors: validationErrors)
                            .padding(.horizontal)
                    }

                    // Section cards grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(A2Section.allCases) { section in
                            A2SectionCard(
                                section: section,
                                preview: previewText(for: section),
                                hasError: sectionHasError(section),
                                isComplete: isSectionComplete(section)
                            ) {
                                activePopup = section
                            }
                        }
                    }
                    .padding()

                    Spacer().frame(height: 20)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Form A2")
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
                                formData = A2FormData(
                                    patientInfo: sharedData.patientInfo,
                                    clinicianInfo: appStore.clinicianInfo
                                )
                            } label: {
                                Label("Clear Form", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .onAppear { prefillFromSharedData() }
            .onDisappear { syncPatientDataToSharedStore() }
            .sheet(item: $activePopup) { section in
                popupSheet(for: section)
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = docxURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    // MARK: - Popup Sheets
    @ViewBuilder
    private func popupSheet(for section: A2Section) -> some View {
        switch section {
        case .hospital:
            A2HospitalPopup(formData: $formData)
        case .amhp:
            A2AMHPPopup(formData: $formData, clinicianInfo: appStore.clinicianInfo)
        case .patient:
            A2PatientPopup(formData: $formData, patientInfo: sharedData.patientInfo)
        case .authority:
            A2AuthorityPopup(formData: $formData)
        case .nearestRelative:
            A2NearestRelativePopup(formData: $formData)
        case .interview:
            A2InterviewPopup(formData: $formData)
        case .medical:
            A2MedicalPopup(formData: $formData)
        case .signature:
            A2SignaturePopup(formData: $formData)
        }
    }

    // MARK: - Helpers
    private func previewText(for section: A2Section) -> String {
        switch section {
        case .hospital:
            return formData.hospitalName.isEmpty ? "Tap to enter" : formData.hospitalName
        case .amhp:
            return formData.amhpName.isEmpty ? "Tap to enter" : formData.amhpName
        case .patient:
            return formData.patientName.isEmpty ? "Tap to enter" : formData.patientName
        case .authority:
            return formData.localAuthority.isEmpty ? "Tap to enter" : formData.localAuthority
        case .nearestRelative:
            if formData.nrKnown {
                return formData.nrName.isEmpty ? "Known - tap to enter" : formData.nrName
            } else {
                return "Unknown"
            }
        case .interview:
            return DateFormatter.shortDate.string(from: formData.lastSeenDate)
        case .medical:
            return formData.noAcquaintanceReason.isEmpty ? "No issues" : "Reason provided"
        case .signature:
            return DateFormatter.shortDate.string(from: formData.signatureDate)
        }
    }

    private func sectionHasError(_ section: A2Section) -> Bool {
        validationErrors.contains { error in
            switch section {
            case .hospital: return error.field.contains("hospital")
            case .amhp: return error.field.contains("amhp")
            case .patient: return error.field.contains("patient")
            case .authority: return error.field.contains("localAuthority") || error.field.contains("approvedBy")
            case .nearestRelative: return error.field.contains("nr")
            case .interview: return error.field.contains("lastSeen")
            case .medical: return error.field.contains("noAcquaintance")
            case .signature: return error.field.contains("signature")
            }
        }
    }

    private func isSectionComplete(_ section: A2Section) -> Bool {
        switch section {
        case .hospital:
            return !formData.hospitalName.isEmpty && !formData.hospitalAddress.isEmpty
        case .amhp:
            return !formData.amhpName.isEmpty
        case .patient:
            return !formData.patientName.isEmpty && !formData.patientAddress.isEmpty
        case .authority:
            return !formData.localAuthority.isEmpty
        case .nearestRelative:
            if formData.nrKnown {
                return !formData.nrName.isEmpty
            } else {
                return true // Unknown is a valid complete state
            }
        case .interview:
            return true // Date always has a value
        case .medical:
            return true // Optional field, always considered complete
        case .signature:
            return true // Date always has a value
        }
    }

    private func prefillFromSharedData() {
        formData.patientInfo = sharedData.patientInfo
        formData.clinicianInfo = appStore.clinicianInfo

        // Patient from shared data
        if !sharedData.patientInfo.fullName.isEmpty {
            formData.patientName = sharedData.patientInfo.fullName
            formData.patientAddress = sharedData.patientInfo.address
        }

        // AMHP from My Details
        if !appStore.clinicianInfo.fullName.isEmpty {
            formData.amhpName = appStore.clinicianInfo.fullName
            formData.amhpAddress = appStore.clinicianInfo.hospitalOrg
            formData.amhpEmail = appStore.clinicianInfo.email
        }

        // Hospital from My Details
        formData.hospitalName = appStore.clinicianInfo.hospitalOrg

        // Local Authority from My Details
        formData.localAuthority = appStore.clinicianInfo.teamService
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
            }, source: "A2Form")
        }
        // Sync nearest relative to SharedDataStore for A6, M2
        if !formData.nrName.isEmpty {
            sharedData.updateNearestRelative({ info in
                info.name = formData.nrName
                info.address = formData.nrAddress
            }, source: "A2Form")
        }
    }

    private func exportDOCX() {
        validationErrors = formData.validate()
        isExporting = true
        exportError = nil

        DispatchQueue.global(qos: .userInitiated).async {
            let data = A2FormDOCXExporter(formData: formData).generateDOCX()

            DispatchQueue.main.async {
                isExporting = false

                guard let docxData = data else {
                    exportError = "Failed to generate document"
                    return
                }

                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
                let timestamp = dateFormatter.string(from: Date())
                let filename = "Form_A2_\(timestamp).docx"
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

// MARK: - Section Card
struct A2SectionCard: View {
    let section: A2FormView.A2Section
    let preview: String
    let hasError: Bool
    let isComplete: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: section.icon)
                        .foregroundColor(isComplete ? .green : section.color)
                        .font(.title2)
                    Spacer()
                    if hasError {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.red)
                    } else if isComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }

                Text(section.rawValue)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text(preview)
                    .font(.caption)
                    .foregroundColor(isComplete ? .green : .secondary)
                    .lineLimit(2)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.yellow.opacity(0.15))
            .cornerRadius(12)
            .shadow(color: .yellow.opacity(0.15), radius: 4, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(hasError ? Color.red : Color.yellow.opacity(0.5), lineWidth: hasError ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Hospital Popup
struct A2HospitalPopup: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var formData: A2FormData

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Hospital Name", text: $formData.hospitalName)
                } header: {
                    Label("Hospital Name", systemImage: "building.2")
                } footer: {
                    Text("Enter the full name of the hospital")
                }

                Section {
                    TextEditor(text: $formData.hospitalAddress)
                        .frame(minHeight: 100)
                } header: {
                    Label("Hospital Address", systemImage: "mappin.and.ellipse")
                } footer: {
                    Text("Enter the complete address including postcode")
                }
            }
            .navigationTitle("Hospital")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - AMHP Popup
struct A2AMHPPopup: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var formData: A2FormData
    let clinicianInfo: ClinicianInfo

    var body: some View {
        NavigationStack {
            Form {
                if !clinicianInfo.fullName.isEmpty {
                    Section {
                        Button {
                            formData.amhpName = clinicianInfo.fullName
                            formData.amhpEmail = clinicianInfo.email
                        } label: {
                            Label("Use My Details", systemImage: "person.crop.circle.badge.checkmark")
                        }
                    }
                }

                Section {
                    TextField("Full Name", text: $formData.amhpName)
                } header: {
                    Label("AMHP Name", systemImage: "person")
                }

                Section {
                    TextEditor(text: $formData.amhpAddress)
                        .frame(minHeight: 80)
                } header: {
                    Label("Address", systemImage: "mappin")
                }

                Section {
                    TextField("Email", text: $formData.amhpEmail)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                } header: {
                    Label("Email", systemImage: "envelope")
                }
            }
            .navigationTitle("AMHP Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Patient Popup
struct A2PatientPopup: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var formData: A2FormData
    let patientInfo: PatientInfo

    var body: some View {
        NavigationStack {
            Form {
                if !patientInfo.fullName.isEmpty {
                    Section {
                        Button {
                            formData.patientName = patientInfo.fullName
                            formData.patientAddress = patientInfo.address
                        } label: {
                            Label("Use Imported Patient Details", systemImage: "arrow.down.doc")
                        }
                    }
                }

                Section {
                    TextField("Full Name", text: $formData.patientName)
                } header: {
                    Label("Patient Name", systemImage: "person")
                }

                Section {
                    TextEditor(text: $formData.patientAddress)
                        .frame(minHeight: 100)
                } header: {
                    Label("Patient Address", systemImage: "mappin")
                }
            }
            .navigationTitle("Patient Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Authority Popup
struct A2AuthorityPopup: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var formData: A2FormData

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Local Authority Name", text: $formData.localAuthority)
                } header: {
                    Label("Local Social Services Authority", systemImage: "building.columns")
                }

                Section {
                    Button {
                        formData.approvedBySameAuthority = true
                    } label: {
                        HStack {
                            Image(systemName: formData.approvedBySameAuthority ? "largecircle.fill.circle" : "circle")
                                .foregroundColor(formData.approvedBySameAuthority ? .blue : .gray)
                            Text("That authority (same as above)")
                                .foregroundColor(.primary)
                        }
                    }
                    .buttonStyle(.plain)

                    Button {
                        formData.approvedBySameAuthority = false
                    } label: {
                        HStack {
                            Image(systemName: !formData.approvedBySameAuthority ? "largecircle.fill.circle" : "circle")
                                .foregroundColor(!formData.approvedBySameAuthority ? .blue : .gray)
                            Text("Different authority")
                                .foregroundColor(.primary)
                        }
                    }
                    .buttonStyle(.plain)

                    if !formData.approvedBySameAuthority {
                        TextField("Authority Name", text: $formData.approvedByDifferentAuthority)
                    }
                } header: {
                    Text("Approved By")
                }
            }
            .navigationTitle("Local Authority")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Nearest Relative Popup
struct A2NearestRelativePopup: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var formData: A2FormData

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Do you know who the nearest relative is?", selection: $formData.nrKnown) {
                        Text("Yes").tag(true)
                        Text("No").tag(false)
                    }
                    .pickerStyle(.segmented)
                }

                if formData.nrKnown {
                    knownNRSection
                } else {
                    unknownNRSection
                }
            }
            .navigationTitle("Nearest Relative")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    private var knownNRSection: some View {
        Group {
            Section {
                Button {
                    formData.nrIsNearestRelative = true
                } label: {
                    HStack(alignment: .top) {
                        Image(systemName: formData.nrIsNearestRelative ? "largecircle.fill.circle" : "circle")
                            .foregroundColor(formData.nrIsNearestRelative ? .blue : .gray)
                        Text("(a) This person IS the patient's nearest relative")
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                    }
                }
                .buttonStyle(.plain)

                Button {
                    formData.nrIsNearestRelative = false
                } label: {
                    HStack(alignment: .top) {
                        Image(systemName: !formData.nrIsNearestRelative ? "largecircle.fill.circle" : "circle")
                            .foregroundColor(!formData.nrIsNearestRelative ? .blue : .gray)
                        Text("(b) This person has been AUTHORISED to act as nearest relative")
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                    }
                }
                .buttonStyle(.plain)
            } header: {
                Text("Relationship Type")
            }

            Section {
                TextField("Name", text: $formData.nrName)
                TextEditor(text: $formData.nrAddress)
                    .frame(minHeight: 60)
            } header: {
                Text("Nearest Relative Details")
            }

            Section {
                Picker("Informed about application?", selection: $formData.nrInformed) {
                    Text("Yes").tag(true)
                    Text("No").tag(false)
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Have you informed this person?")
            }
        }
    }

    private var unknownNRSection: some View {
        Section {
            Button {
                formData.nrUnableToAscertain = true
            } label: {
                HStack(alignment: .top) {
                    Image(systemName: formData.nrUnableToAscertain ? "largecircle.fill.circle" : "circle")
                        .foregroundColor(formData.nrUnableToAscertain ? .blue : .gray)
                    Text("(a) I have been unable to ascertain who is the patient's nearest relative")
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                }
            }
            .buttonStyle(.plain)

            Button {
                formData.nrUnableToAscertain = false
            } label: {
                HStack(alignment: .top) {
                    Image(systemName: !formData.nrUnableToAscertain ? "largecircle.fill.circle" : "circle")
                        .foregroundColor(!formData.nrUnableToAscertain ? .blue : .gray)
                    Text("(b) The patient appears to have no nearest relative within the meaning of the Act")
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                }
            }
            .buttonStyle(.plain)
        } header: {
            Text("Reason")
        }
    }
}

// MARK: - Interview Popup
struct A2InterviewPopup: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var formData: A2FormData

    private var daysSinceLastSeen: Int {
        Calendar.current.dateComponents([.day], from: formData.lastSeenDate, to: Date()).day ?? 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $formData.lastSeenDate, in: ...Date(), displayedComponents: .date)
                } header: {
                    Label("Date Patient Last Seen", systemImage: "calendar")
                } footer: {
                    Text("Must be within 14 days ending on the day this application is completed.")
                }

                if daysSinceLastSeen > 14 {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Warning: Selected date is more than 14 days ago (\(daysSinceLastSeen) days)")
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            .navigationTitle("Patient Interview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Medical Popup
struct A2MedicalPopup: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var formData: A2FormData

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("I attach the written recommendations of two registered medical practitioners.")
                        .foregroundColor(.secondary)
                }

                Section {
                    TextEditor(text: $formData.noAcquaintanceReason)
                        .frame(minHeight: 120)
                } header: {
                    Text("If neither medical practitioner had previous acquaintance with the patient, explain why")
                } footer: {
                    Text("Leave blank if not applicable")
                }
            }
            .navigationTitle("Medical Recommendations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Signature Popup
struct A2SignaturePopup: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var formData: A2FormData

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $formData.signatureDate, displayedComponents: .date)
                } header: {
                    Label("Signature Date", systemImage: "calendar")
                }

                Section {
                    HStack {
                        Image(systemName: "pencil.and.outline")
                            .foregroundColor(.gray)
                        Text("The form will be signed manually after printing.")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Signature")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Form Export View
struct FormExportView<T: StatutoryForm>: View {
    @Environment(\.dismiss) private var dismiss
    let formData: T

    @State private var docxURL: URL?
    @State private var isExporting = false
    @State private var showShareSheet = false
    @State private var exportError: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "doc.text")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)

                Text("Export \(formData.formType.rawValue)")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Your form will be exported as a Word document (.docx) that you can share or save.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)

                if let error = exportError {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }

                Spacer()

                Button(action: exportDOCX) {
                    if isExporting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Label("Export as DOCX", systemImage: "square.and.arrow.up")
                    }
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent)
                .disabled(isExporting)
            }
            .padding()
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = docxURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    private func exportDOCX() {
        isExporting = true
        exportError = nil

        DispatchQueue.global(qos: .userInitiated).async {
            var data: Data?

            // Generate DOCX based on form type
            if let a2Data = formData as? A2FormData {
                data = A2FormDOCXExporter(formData: a2Data).generateDOCX()
            } else if let a3Data = formData as? A3FormData {
                data = A3FormDOCXExporter(formData: a3Data).generateDOCX()
            } else if let a4Data = formData as? A4FormData {
                data = A4FormDOCXExporter(formData: a4Data).generateDOCX()
            } else if let a6Data = formData as? A6FormData {
                data = A6FormDOCXExporter(formData: a6Data).generateDOCX()
            } else if let a7Data = formData as? A7FormData {
                data = A7FormDOCXExporter(formData: a7Data).generateDOCX()
            } else if let a8Data = formData as? A8FormData {
                data = A8FormDOCXExporter(formData: a8Data).generateDOCX()
            } else if let h1Data = formData as? H1FormData {
                data = H1FormDOCXExporter(formData: h1Data).generateDOCX()
            } else if let h5Data = formData as? H5FormData {
                data = H5FormDOCXExporter(formData: h5Data).generateDOCX()
            } else if let cto1Data = formData as? CTO1FormData {
                data = CTO1FormDOCXExporter(formData: cto1Data).generateDOCX()
            } else if let cto3Data = formData as? CTO3FormData {
                data = CTO3FormDOCXExporter(formData: cto3Data).generateDOCX()
            } else if let cto4Data = formData as? CTO4FormData {
                data = CTO4FormDOCXExporter(formData: cto4Data).generateDOCX()
            } else if let cto5Data = formData as? CTO5FormData {
                data = CTO5FormDOCXExporter(formData: cto5Data).generateDOCX()
            } else if let cto7Data = formData as? CTO7FormData {
                data = CTO7FormDOCXExporter(formData: cto7Data).generateDOCX()
            } else if let t2Data = formData as? T2FormData {
                data = T2FormDOCXExporter(formData: t2Data).generateDOCX()
            } else if let m2Data = formData as? M2FormData {
                data = M2FormDOCXExporter(formData: m2Data).generateDOCX()
            }

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
                let filename = "Form_\(formData.formType.rawValue)_\(timestamp).docx"

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


#Preview {
    A2FormView()
        .environment(AppStore())
        .environment(SharedDataStore.shared)
}
