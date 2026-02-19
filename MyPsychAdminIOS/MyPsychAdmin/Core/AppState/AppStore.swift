//
//  AppStore.swift
//  MyPsychAdmin
//
//  Main application state container
//

import SwiftUI
import Combine

@Observable
final class AppStore {
    // MARK: - Shared Data
    let sharedData = SharedDataStore.shared

    // MARK: - Letter Writer State
    var letterSections: [SectionType: SectionState] = [:]
    var activeSectionType: SectionType?
    var letterOrder: [SectionType] = SectionType.orderedSections

    // MARK: - Forms State
    var selectedFormType: FormType?

    // MARK: - Navigation State
    var activeTab: AppTab = .home
    var navigationPath = NavigationPath()
    var isDetailsShowing = false
    var showingDocumentImporter = false

    // MARK: - UI State
    var isLoading = false
    var loadingMessage: String = ""
    var alertMessage: AlertMessage?

    // MARK: - Clinician Info (cached from SwiftData)
    var clinicianInfo: ClinicianInfo = ClinicianInfo()

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Initialize all letter sections with empty state
        for section in SectionType.allCases {
            letterSections[section] = SectionState()
        }

        setupBindings()
    }

    private func setupBindings() {
        // When extracted data changes, auto-populate letter sections
        sharedData.extractedDataDidChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] extractedData in
                self?.autoPopulateLetterSections(from: extractedData)
            }
            .store(in: &cancellables)

        // When patient info changes, update front page
        sharedData.patientInfoDidChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] patientInfo in
                self?.updateFrontPageWithPatientInfo(patientInfo)
            }
            .store(in: &cancellables)
    }

    // MARK: - Letter Section Management
    func getSection(_ type: SectionType) -> SectionState {
        letterSections[type] ?? SectionState()
    }

    func updateSection(_ type: SectionType, content: String) {
        letterSections[type]?.setContent(content)
    }

    // Subscript for binding access to section content
    subscript(_ type: SectionType) -> String {
        get {
            letterSections[type]?.content ?? ""
        }
        set {
            if letterSections[type] == nil {
                letterSections[type] = SectionState()
            }
            letterSections[type]?.setContent(newValue)
        }
    }

    func toggleSectionLock(_ type: SectionType) {
        letterSections[type]?.toggleLock()
    }

    func clearAllSections() {
        for section in SectionType.allCases {
            letterSections[section] = SectionState()
        }
    }

    // MARK: - Popup Data Persistence
    func savePopupData<T: Encodable>(_ data: T, for section: SectionType) {
        if let encoded = try? JSONEncoder().encode(data) {
            letterSections[section]?.popupData = encoded
        }
    }

    func loadPopupData<T: Decodable>(_ type: T.Type, for section: SectionType) -> T? {
        guard let data = letterSections[section]?.popupData else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func autoPopulateLetterSections(from extractedData: ExtractedData) {
        for sectionType in SectionType.allCases {
            guard let category = sectionType.extractorCategory else { continue }
            guard let sectionState = letterSections[sectionType] else { continue }

            // Only populate if section is not locked and is empty
            if !sectionState.isLocked && sectionState.isEmpty {
                let content = extractedData.categories[category]?.joined(separator: "\n\n") ?? ""
                if !content.isEmpty {
                    letterSections[sectionType]?.setContent(content)
                    print("[AppStore] Auto-populated \(sectionType.title) from extracted data")
                }
            }
        }
    }

    private func updateFrontPageWithPatientInfo(_ patientInfo: PatientInfo) {
        // Don't auto-update front page from patient info changes
        // The FrontPagePopupView handles all front page content including medications
        // This prevents overwriting popup-generated content that includes medications
    }

    // MARK: - Navigation Helpers
    func navigateTo(_ tab: AppTab) {
        activeTab = tab
    }

    // MARK: - Loading State
    func setLoading(_ loading: Bool, message: String = "") {
        isLoading = loading
        loadingMessage = message
    }

    func showAlert(title: String, message: String) {
        alertMessage = AlertMessage(title: title, message: message)
    }

    // MARK: - Export State
    var letterContent: String {
        var output = ""
        for section in letterOrder {
            guard let state = letterSections[section], !state.isEmpty else { continue }
            output += "## \(section.title)\n\n"
            output += state.content
            output += "\n\n"
        }
        return output
    }

    var hasLetterContent: Bool {
        letterSections.values.contains { !$0.isEmpty }
    }
}

// MARK: - Supporting Types
enum AppTab: String, CaseIterable, Identifiable {
    case home = "Home"
    case myDetails = "My Details"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .home: return "house"
        case .myDetails: return "person.circle"
        }
    }
}

struct AlertMessage: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
