//
//  MyPsychAdminApp.swift
//  MyPsychAdmin
//
//  iOS port of PyQt psychiatric administration app
//

import SwiftUI
import SwiftData

@main
struct MyPsychAdminApp: App {
    let modelContainer: ModelContainer
    @State private var appStore = AppStore()
    @State private var appSettings = AppSettings.shared

    init() {
        do {
            modelContainer = try ModelContainer(for: ClinicianDetailsModel.self)
        } catch {
            fatalError("Failed to initialize SwiftData container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appStore)
                .environment(appStore.sharedData)
                .environment(appSettings)
                .modelContainer(modelContainer)
                .preferredColorScheme(appSettings.colorScheme)
        }
    }
}

struct ContentView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(\.modelContext) private var modelContext
    @Query private var clinicians: [ClinicianDetailsModel]
    @State private var isLicenseValid = false
    @State private var hasCheckedLicense = false

    var body: some View {
        Group {
            if !hasCheckedLicense {
                // Loading state while checking license
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Checking license...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if isLicenseValid {
                // Main app content
                TabBarView()
            } else {
                // Activation required
                ActivationView(isActivated: $isLicenseValid)
            }
        }
        .task {
            checkLicense()
            loadClinicianInfo()
        }
        .onChange(of: clinicians) { _, newValue in
            // Update when clinician data changes
            if let clinician = newValue.first {
                appStore.clinicianInfo = ClinicianInfo(from: clinician)
            }
        }
    }

    private func checkLicense() {
        let result = LicenseManager.shared.isLicenseValid()

        switch result {
        case .valid:
            isLicenseValid = true
        case .notFound, .invalid, .expired, .wrongDevice, .wrongPlatform:
            isLicenseValid = false
        }

        hasCheckedLicense = true
    }

    private func loadClinicianInfo() {
        if let clinician = clinicians.first {
            appStore.clinicianInfo = ClinicianInfo(from: clinician)
        }
    }
}
