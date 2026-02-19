//
//  FormRouterView.swift
//  MyPsychAdmin
//
//  Routes to the correct form view based on FormType
//

import SwiftUI

struct FormRouterView: View {
    let formType: FormType

    var body: some View {
        Group {
            switch formType {
            // MHA Forms
            case .a2:
                A2FormView()
            case .a3:
                A3FormView()
            case .a4:
                A4FormView()
            case .a6:
                A6FormView()
            case .a7:
                A7FormView()
            case .a8:
                A8FormView()
            case .h1:
                H1FormView()
            case .h5:
                H5FormView()

            // CTO Forms
            case .cto1:
                CTO1FormView()
            case .cto3:
                CTO3FormView()
            case .cto4:
                CTO4FormView()
            case .cto5:
                CTO5FormView()
            case .cto7:
                CTO7FormView()

            // Other Forms
            case .t2:
                T2FormView()
            case .m2:
                M2FormView()
            case .mojLeave:
                MOJLeaveFormView()
            case .mojASR:
                MOJASRFormView()
            case .hcr20:
                HCR20FormView()
            }
        }
    }
}

// MARK: - Generic MHA Form View
struct GenericMHAFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var appStore
    @Environment(SharedDataStore.self) private var sharedData

    let formType: FormType
    let title: String

    @State private var patientName = ""
    @State private var patientAddress = ""
    @State private var doctorName = ""
    @State private var hospitalName = ""
    @State private var clinicalOpinion = ""
    @State private var signatureDate = Date()
    @State private var showingExport = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Patient Details") {
                    TextField("Patient Name", text: $patientName)
                    TextField("Patient Address", text: $patientAddress, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Hospital") {
                    TextField("Hospital Name", text: $hospitalName)
                }

                Section("Practitioner Details") {
                    TextField("Doctor/Clinician Name", text: $doctorName)
                }

                Section("Clinical Opinion") {
                    TextEditor(text: $clinicalOpinion)
                        .frame(minHeight: 150)
                }

                Section("Signature") {
                    DatePicker("Date", selection: $signatureDate, displayedComponents: .date)
                }

                Section {
                    Button {
                        showingExport = true
                    } label: {
                        Label("Export Form", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Form \(formType.rawValue)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                patientName = sharedData.patientInfo.fullName
                patientAddress = sharedData.patientInfo.address
                doctorName = appStore.clinicianInfo.fullName
            }
            .sheet(isPresented: $showingExport) {
                GenericFormExportSheet(
                    formType: formType,
                    patientName: patientName,
                    hospitalName: hospitalName,
                    doctorName: doctorName
                )
            }
        }
    }
}

// MARK: - Generic CTO Form View
struct GenericCTOFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var appStore
    @Environment(SharedDataStore.self) private var sharedData

    let formType: FormType
    let title: String

    @State private var patientName = ""
    @State private var patientAddress = ""
    @State private var rcName = ""
    @State private var amhpName = ""
    @State private var hospitalName = ""
    @State private var ctoDetails = ""
    @State private var signatureDate = Date()
    @State private var showingExport = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Patient Details") {
                    TextField("Patient Name", text: $patientName)
                    TextField("Patient Address", text: $patientAddress, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Hospital") {
                    TextField("Hospital Name", text: $hospitalName)
                }

                Section("Responsible Clinician") {
                    TextField("RC Name", text: $rcName)
                }

                if formType == .cto1 || formType == .cto4 {
                    Section("AMHP Details") {
                        TextField("AMHP Name", text: $amhpName)
                    }
                }

                Section("CTO Details") {
                    TextEditor(text: $ctoDetails)
                        .frame(minHeight: 150)
                }

                Section("Signature") {
                    DatePicker("Date", selection: $signatureDate, displayedComponents: .date)
                }

                Section {
                    Button {
                        showingExport = true
                    } label: {
                        Label("Export Form", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.teal)
                }
            }
            .navigationTitle("Form \(formType.rawValue)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                patientName = sharedData.patientInfo.fullName
                patientAddress = sharedData.patientInfo.address
                rcName = appStore.clinicianInfo.fullName
            }
            .sheet(isPresented: $showingExport) {
                GenericFormExportSheet(
                    formType: formType,
                    patientName: patientName,
                    hospitalName: hospitalName,
                    doctorName: rcName
                )
            }
        }
    }
}

// MARK: - Generic Other Form View
struct GenericOtherFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var appStore
    @Environment(SharedDataStore.self) private var sharedData

    let formType: FormType
    let title: String

    @State private var patientName = ""
    @State private var patientAddress = ""
    @State private var clinicianName = ""
    @State private var hospitalName = ""
    @State private var formDetails = ""
    @State private var signatureDate = Date()
    @State private var showingExport = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Patient Details") {
                    TextField("Patient Name", text: $patientName)
                    TextField("Patient Address", text: $patientAddress, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Hospital") {
                    TextField("Hospital Name", text: $hospitalName)
                }

                Section("Clinician Details") {
                    TextField("Clinician Name", text: $clinicianName)
                }

                Section("Form Details") {
                    TextEditor(text: $formDetails)
                        .frame(minHeight: 150)
                }

                Section("Signature") {
                    DatePicker("Date", selection: $signatureDate, displayedComponents: .date)
                }

                Section {
                    Button {
                        showingExport = true
                    } label: {
                        Label("Export Form", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
            }
            .navigationTitle("Form \(formType.rawValue)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                patientName = sharedData.patientInfo.fullName
                patientAddress = sharedData.patientInfo.address
                clinicianName = appStore.clinicianInfo.fullName
            }
            .sheet(isPresented: $showingExport) {
                GenericFormExportSheet(
                    formType: formType,
                    patientName: patientName,
                    hospitalName: hospitalName,
                    doctorName: clinicianName
                )
            }
        }
    }
}

// MOJASRFormView moved to Features/Forms/OtherForms/MOJASRFormView.swift

// MARK: - Generic Form Export Sheet
struct GenericFormExportSheet: View {
    @Environment(\.dismiss) private var dismiss

    let formType: FormType
    let patientName: String
    let hospitalName: String
    let doctorName: String

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "doc.text")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)

                Text("Export Form \(formType.rawValue)")
                    .font(.title2)
                    .fontWeight(.semibold)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Patient: \(patientName.isEmpty ? "Not entered" : patientName)")
                    Text("Hospital: \(hospitalName.isEmpty ? "Not entered" : hospitalName)")
                    Text("Clinician: \(doctorName.isEmpty ? "Not entered" : doctorName)")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)

                Spacer()

                ShareLink(item: "Form \(formType.rawValue)\n\nPatient: \(patientName)\nHospital: \(hospitalName)\nClinician: \(doctorName)") {
                    Label("Share Form", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    FormRouterView(formType: .a2)
        .environment(AppStore())
        .environment(SharedDataStore.shared)
}
