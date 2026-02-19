//
//  MyDetailsView.swift
//  MyPsychAdmin
//

import SwiftUI
import SwiftData
import PhotosUI

struct MyDetailsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppStore.self) private var appStore
    @Query private var clinicians: [ClinicianDetailsModel]

    @State private var fullName: String = ""
    @State private var roleTitle: String = ""
    @State private var discipline: String = ""
    @State private var registrationBody: String = ""
    @State private var registrationNumber: String = ""
    @State private var phone: String = ""
    @State private var email: String = ""
    @State private var teamService: String = ""
    @State private var hospitalOrg: String = ""
    @State private var wardDepartment: String = ""
    @State private var signatureBlock: String = ""

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var signatureImage: UIImage?
    @State private var showingSaveConfirmation = false
    @State private var hasChanges = false
    @State private var hasLoadedInitialData = false

    private var clinician: ClinicianDetailsModel? {
        clinicians.first
    }

    var body: some View {
        NavigationStack {
            Form {
                // Personal Information
                Section("Personal Information") {
                    TextField("Full Name", text: $fullName)
                        .textContentType(.name)

                    TextField("Role Title", text: $roleTitle)
                        .textContentType(.jobTitle)

                    Picker("Discipline", selection: $discipline) {
                        Text("Select...").tag("")
                        ForEach(disciplines, id: \.self) { d in
                            Text(d).tag(d)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                // Registration Details
                Section("Registration") {
                    Picker("Registration Body", selection: $registrationBody) {
                        Text("Select...").tag("")
                        ForEach(registrationBodies, id: \.self) { body in
                            Text(body).tag(body)
                        }
                    }
                    .pickerStyle(.navigationLink)

                    TextField("Registration Number", text: $registrationNumber)
                        .textContentType(.none)
                        .keyboardType(.default)
                }

                // Contact Information
                Section("Contact Information") {
                    TextField("Phone", text: $phone)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)

                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }

                // Work Location
                Section("Work Location") {
                    TextField("Team/Service", text: $teamService)

                    TextField("Hospital/Organisation", text: $hospitalOrg)
                        .textContentType(.organizationName)

                    TextField("Ward/Department", text: $wardDepartment)
                }

                // Signature
                Section("Signature") {
                    TextEditor(text: $signatureBlock)
                        .frame(minHeight: 100)

                    // Signature Image
                    VStack(alignment: .leading, spacing: 8) {
                        if let image = signatureImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 100)
                                .cornerRadius(8)

                            Button("Remove Signature Image", role: .destructive) {
                                signatureImage = nil
                                selectedPhoto = nil
                            }
                            .font(.caption)
                        }

                        PhotosPicker(
                            selection: $selectedPhoto,
                            matching: .images
                        ) {
                            Label(signatureImage == nil ? "Add Signature Image" : "Change Image",
                                  systemImage: "signature")
                        }
                    }
                }

                // Preview
                Section("Preview") {
                    VStack(alignment: .leading, spacing: 4) {
                        if !fullName.isEmpty {
                            Text(fullName)
                                .fontWeight(.semibold)
                        }
                        if !roleTitle.isEmpty {
                            Text(roleTitle)
                        }
                        if !registrationBody.isEmpty && !registrationNumber.isEmpty {
                            Text("\(registrationBody): \(registrationNumber)")
                        }
                        if !teamService.isEmpty {
                            Text(teamService)
                        }
                        if !hospitalOrg.isEmpty {
                            Text(hospitalOrg)
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
            }
            .navigationTitle("My Details")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveDetails()
                    }
                    .disabled(!hasChanges)
                }
            }
            .onAppear {
                if !hasLoadedInitialData {
                    loadDetails()
                    hasLoadedInitialData = true
                }
            }
            .onChange(of: selectedPhoto) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        signatureImage = image
                        hasChanges = true
                    }
                }
            }
            .onChange(of: fullName) { _, _ in hasChanges = true }
            .onChange(of: roleTitle) { _, _ in hasChanges = true }
            .onChange(of: discipline) { _, _ in hasChanges = true }
            .onChange(of: registrationBody) { _, _ in hasChanges = true }
            .onChange(of: registrationNumber) { _, _ in hasChanges = true }
            .onChange(of: phone) { _, _ in hasChanges = true }
            .onChange(of: email) { _, _ in hasChanges = true }
            .onChange(of: teamService) { _, _ in hasChanges = true }
            .onChange(of: hospitalOrg) { _, _ in hasChanges = true }
            .onChange(of: wardDepartment) { _, _ in hasChanges = true }
            .onChange(of: signatureBlock) { _, _ in hasChanges = true }
            .alert("Saved", isPresented: $showingSaveConfirmation) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your details have been saved successfully.")
            }
        }
    }

    private func loadDetails() {
        guard let clinician = clinician else { return }

        fullName = clinician.fullName
        roleTitle = clinician.roleTitle
        discipline = clinician.discipline
        registrationBody = clinician.registrationBody
        registrationNumber = clinician.registrationNumber
        phone = clinician.phone
        email = clinician.email
        teamService = clinician.teamService
        hospitalOrg = clinician.hospitalOrg
        wardDepartment = clinician.wardDepartment
        signatureBlock = clinician.signatureBlock

        if let imageData = clinician.signatureImageData {
            signatureImage = UIImage(data: imageData)
        }

        hasChanges = false
    }

    private func saveDetails() {
        let clinicianModel: ClinicianDetailsModel

        if let existing = clinician {
            clinicianModel = existing
        } else {
            clinicianModel = ClinicianDetailsModel()
            modelContext.insert(clinicianModel)
        }

        clinicianModel.fullName = fullName
        clinicianModel.roleTitle = roleTitle
        clinicianModel.discipline = discipline
        clinicianModel.registrationBody = registrationBody
        clinicianModel.registrationNumber = registrationNumber
        clinicianModel.phone = phone
        clinicianModel.email = email
        clinicianModel.teamService = teamService
        clinicianModel.hospitalOrg = hospitalOrg
        clinicianModel.wardDepartment = wardDepartment
        clinicianModel.signatureBlock = signatureBlock
        clinicianModel.signatureImageData = signatureImage?.jpegData(compressionQuality: 0.8)

        do {
            try modelContext.save()

            // Update AppStore with clinician info
            appStore.clinicianInfo = ClinicianInfo(from: clinicianModel)

            hasChanges = false
            showingSaveConfirmation = true
        } catch {
            print("Failed to save clinician details: \(error)")
        }
    }

    // MARK: - Options
    private let disciplines = [
        "Psychiatry",
        "Psychology",
        "Nursing",
        "Social Work",
        "Occupational Therapy",
        "Psychotherapy",
        "Other"
    ]

    private let registrationBodies = [
        "GMC",
        "NMC",
        "HCPC",
        "Social Work England",
        "BPS",
        "BABCP",
        "Other"
    ]
}

#Preview {
    MyDetailsView()
        .environment(AppStore())
        .modelContainer(for: ClinicianDetailsModel.self, inMemory: true)
}
