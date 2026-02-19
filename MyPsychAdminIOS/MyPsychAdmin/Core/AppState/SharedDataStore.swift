//
//  SharedDataStore.swift
//  MyPsychAdmin
//
//  Port of shared_data_store.py - Centralized state management singleton
//

import SwiftUI
import Combine

@Observable
final class SharedDataStore {
    // MARK: - Singleton
    static let shared = SharedDataStore()

    // MARK: - Core Data Storage
    private(set) var notes: [ClinicalNote] = []
    private(set) var patientInfo: PatientInfo = PatientInfo()
    private(set) var extractedData: ExtractedData = ExtractedData()
    private(set) var reportSections: [String: String] = [:]
    private(set) var reportSource: String = ""
    private(set) var clinicalReasons: ClinicalReasonsData = ClinicalReasonsData()
    private(set) var secondPractitioner: SecondPractitionerInfo = SecondPractitionerInfo()
    private(set) var nearestRelative: NearestRelativeInfo = NearestRelativeInfo()

    // MARK: - Report Form Data Persistence (survives navigation)
    var psychTribunalFormData: PsychTribunalFormData = PsychTribunalFormData()
    var psychTribunalGeneratedTexts: [String: String] = [:]
    var psychTribunalManualNotes: [String: String] = [:]

    var nursingTribunalFormData: NursingTribunalFormData = NursingTribunalFormData()
    var nursingTribunalGeneratedTexts: [String: String] = [:]
    var nursingTribunalManualNotes: [String: String] = [:]

    var socialTribunalFormData: SocialTribunalFormData = SocialTribunalFormData()
    var socialTribunalGeneratedTexts: [String: String] = [:]
    var socialTribunalManualNotes: [String: String] = [:]

    // MARK: - Cached Progress & Risk Narrative (shared across ALL views - Notes, PTR, etc.)
    // Once generated in any section, cached until app shutdown or notes change
    var cachedNarrativeSections: [NarrativeSection] = []
    var cachedNarrativeReferenceMap: [UUID: Int] = [:]
    var cachedNarrativeDateRange: String = ""
    var cachedNarrativeEntryCount: Int = 0
    var cachedNarrativeNotesHash: Int = 0

    /// Check if we have a valid cached narrative for current notes
    var hasValidNarrativeCache: Bool {
        !cachedNarrativeSections.isEmpty && cachedNarrativeNotesHash == notes.hashValue
    }

    /// Clear narrative cache (call when notes change significantly)
    func clearNarrativeCacheIfNeeded() {
        let currentHash = notes.hashValue
        if cachedNarrativeNotesHash != currentHash {
            cachedNarrativeSections = []
            cachedNarrativeReferenceMap = [:]
            cachedNarrativeDateRange = ""
            cachedNarrativeEntryCount = 0
            cachedNarrativeNotesHash = 0
            print("[SharedDataStore] Narrative cache invalidated - notes changed")
        }
    }

    /// Force clear narrative cache
    func clearNarrativeCache() {
        cachedNarrativeSections = []
        cachedNarrativeReferenceMap = [:]
        cachedNarrativeDateRange = ""
        cachedNarrativeEntryCount = 0
        cachedNarrativeNotesHash = 0
        print("[SharedDataStore] Narrative cache cleared")
    }

    // MARK: - Extraction Cache (invalidated when notes change)
    private(set) var cachedMedications: ExtractedMedications?
    private(set) var cachedRisks: ExtractedRisks?
    private var notesHash: Int = 0

    // MARK: - Change Publishers (for reactive updates)
    let notesDidChange = PassthroughSubject<[ClinicalNote], Never>()
    let patientInfoDidChange = PassthroughSubject<PatientInfo, Never>()
    let extractedDataDidChange = PassthroughSubject<ExtractedData, Never>()
    let reportSectionsDidChange = PassthroughSubject<([String: String], String), Never>()
    let clinicalReasonsDidChange = PassthroughSubject<ClinicalReasonsData, Never>()
    let secondPractitionerDidChange = PassthroughSubject<SecondPractitionerInfo, Never>()
    let nearestRelativeDidChange = PassthroughSubject<NearestRelativeInfo, Never>()

    // MARK: - Debug
    private var lastUpdateSource: String = ""

    private init() {}

    // MARK: - Notes Management
    var hasNotes: Bool { !notes.isEmpty }
    var notesCount: Int { notes.count }

    func setNotes(_ newNotes: [ClinicalNote], source: String = "unknown") {
        guard !newNotes.isEmpty || !notes.isEmpty else { return }

        let oldCount = notes.count
        notes = newNotes
        lastUpdateSource = source
        invalidateExtractionCache()

        print("[SharedDataStore] Notes updated from '\(source)': \(oldCount) -> \(notes.count) notes")
        notesDidChange.send(notes)
    }

    func addNotes(_ newNotes: [ClinicalNote], source: String = "unknown") {
        guard !newNotes.isEmpty else { return }
        notes.append(contentsOf: newNotes)
        lastUpdateSource = source
        invalidateExtractionCache()

        print("[SharedDataStore] Added \(newNotes.count) notes from '\(source)', total: \(notes.count)")
        notesDidChange.send(notes)
    }

    func clearNotes() {
        notes = []
        lastUpdateSource = "clear"
        invalidateExtractionCache()
        print("[SharedDataStore] Notes cleared")
        notesDidChange.send(notes)
    }

    // MARK: - Extraction Cache Management
    private func invalidateExtractionCache() {
        cachedMedications = nil
        cachedRisks = nil
        notesHash = 0
        print("[SharedDataStore] Extraction cache invalidated")
    }

    private func currentNotesHash() -> Int {
        var hasher = Hasher()
        for note in notes {
            hasher.combine(note.id)
            hasher.combine(note.body.count)
        }
        return hasher.finalize()
    }

    func getCachedMedications() -> ExtractedMedications? {
        let hash = currentNotesHash()
        if hash == notesHash && cachedMedications != nil {
            print("[SharedDataStore] Using cached medications")
            return cachedMedications
        }
        return nil
    }

    func setCachedMedications(_ meds: ExtractedMedications) {
        cachedMedications = meds
        notesHash = currentNotesHash()
        print("[SharedDataStore] Medications cached (\(meds.drugs.count) drugs)")
    }

    func getCachedRisks() -> ExtractedRisks? {
        let hash = currentNotesHash()
        if hash == notesHash && cachedRisks != nil {
            print("[SharedDataStore] Using cached risks")
            return cachedRisks
        }
        return nil
    }

    func setCachedRisks(_ risks: ExtractedRisks) {
        cachedRisks = risks
        notesHash = currentNotesHash()
        print("[SharedDataStore] Risks cached (\(risks.incidents.count) incidents)")
    }

    func getNotes(filteredBy type: String? = nil) -> [ClinicalNote] {
        guard let type = type else { return notes }
        return notes.filter { $0.type.lowercased().contains(type.lowercased()) }
    }

    func getNotes(from startDate: Date, to endDate: Date) -> [ClinicalNote] {
        notes.filter { $0.date >= startDate && $0.date <= endDate }
    }

    // MARK: - Patient Information
    func setPatientInfo(_ info: PatientInfo, source: String = "unknown") {
        patientInfo = info
        lastUpdateSource = source
        print("[SharedDataStore] Patient info updated from '\(source)'")
        patientInfoDidChange.send(patientInfo)
    }

    func updatePatientInfo(_ updates: (inout PatientInfo) -> Void, source: String = "unknown") {
        updates(&patientInfo)
        lastUpdateSource = source
        print("[SharedDataStore] Patient info merged from '\(source)'")
        patientInfoDidChange.send(patientInfo)
    }

    func getPatientField<T>(_ keyPath: KeyPath<PatientInfo, T>) -> T {
        patientInfo[keyPath: keyPath]
    }

    // MARK: - Clinical Reasons (Synced across forms)
    func setClinicalReasons(_ reasons: ClinicalReasonsData, source: String = "unknown") {
        clinicalReasons = reasons
        lastUpdateSource = source
        print("[SharedDataStore] Clinical reasons updated from '\(source)'")
        clinicalReasonsDidChange.send(clinicalReasons)
    }

    func updateClinicalReasons(_ updates: (inout ClinicalReasonsData) -> Void, source: String = "unknown") {
        updates(&clinicalReasons)
        lastUpdateSource = source
        print("[SharedDataStore] Clinical reasons merged from '\(source)'")
        clinicalReasonsDidChange.send(clinicalReasons)
    }

    var hasClinicalReasons: Bool {
        clinicalReasons.primaryDiagnosisICD10 != .none ||
        !clinicalReasons.primaryDiagnosisCustom.isEmpty ||
        clinicalReasons.healthEnabled ||
        clinicalReasons.safetyEnabled
    }

    // MARK: - Second Practitioner (for joint recommendation forms A3, A7)
    func setSecondPractitioner(_ info: SecondPractitionerInfo, source: String = "unknown") {
        secondPractitioner = info
        lastUpdateSource = source
        print("[SharedDataStore] Second practitioner updated from '\(source)'")
        secondPractitionerDidChange.send(secondPractitioner)
    }

    func updateSecondPractitioner(_ updates: (inout SecondPractitionerInfo) -> Void, source: String = "unknown") {
        updates(&secondPractitioner)
        lastUpdateSource = source
        print("[SharedDataStore] Second practitioner merged from '\(source)'")
        secondPractitionerDidChange.send(secondPractitioner)
    }

    var hasSecondPractitioner: Bool {
        !secondPractitioner.name.isEmpty
    }

    // MARK: - Nearest Relative (synced across A2, A6, M2)
    func setNearestRelative(_ info: NearestRelativeInfo, source: String = "unknown") {
        nearestRelative = info
        lastUpdateSource = source
        print("[SharedDataStore] Nearest relative updated from '\(source)'")
        nearestRelativeDidChange.send(nearestRelative)
    }

    func updateNearestRelative(_ updates: (inout NearestRelativeInfo) -> Void, source: String = "unknown") {
        updates(&nearestRelative)
        lastUpdateSource = source
        print("[SharedDataStore] Nearest relative merged from '\(source)'")
        nearestRelativeDidChange.send(nearestRelative)
    }

    var hasNearestRelative: Bool {
        !nearestRelative.name.isEmpty
    }

    // MARK: - Extracted Data
    func setExtractedData(_ data: ExtractedData, source: String = "unknown") {
        extractedData = data
        lastUpdateSource = source
        print("[SharedDataStore] Extracted data updated from '\(source)': \(data.categories.keys.map { $0.rawValue })")
        extractedDataDidChange.send(extractedData)
    }

    func updateCategory(_ category: ClinicalCategory, data: [String], source: String = "unknown") {
        extractedData.categories[category] = data
        lastUpdateSource = source
        print("[SharedDataStore] Category '\(category.displayName)' updated from '\(source)'")
        extractedDataDidChange.send(extractedData)
    }

    func getCategory(_ category: ClinicalCategory) -> [String] {
        extractedData.categories[category] ?? []
    }

    func getCategoryText(_ category: ClinicalCategory) -> String {
        getCategory(category).joined(separator: "\n\n")
    }

    // MARK: - Report Sections (Cross-form communication)
    func setReportSections(_ sections: [String: String], sourceForm: String = "unknown") {
        guard !sections.isEmpty else { return }

        reportSections = sections
        reportSource = sourceForm
        lastUpdateSource = "report_sections:\(sourceForm)"

        print("[SharedDataStore] Report sections updated from '\(sourceForm)': \(sections.count) sections")
        reportSectionsDidChange.send((reportSections, sourceForm))
    }

    func getReportSection(_ key: String) -> String? {
        reportSections[key]
    }

    // MARK: - Utility
    func clearAll() {
        notes = []
        patientInfo = PatientInfo()
        extractedData = ExtractedData()
        reportSections = [:]
        reportSource = ""
        clinicalReasons = ClinicalReasonsData()
        secondPractitioner = SecondPractitionerInfo()
        nearestRelative = NearestRelativeInfo()
        lastUpdateSource = "clear_all"
        invalidateExtractionCache()

        print("[SharedDataStore] All data cleared")

        notesDidChange.send(notes)
        patientInfoDidChange.send(patientInfo)
        extractedDataDidChange.send(extractedData)
        reportSectionsDidChange.send((reportSections, ""))
        clinicalReasonsDidChange.send(clinicalReasons)
        secondPractitionerDidChange.send(secondPractitioner)
        nearestRelativeDidChange.send(nearestRelative)
    }

    var summary: [String: Any] {
        [
            "notes_count": notes.count,
            "patient_name": patientInfo.fullName,
            "has_dob": patientInfo.dateOfBirth != nil,
            "extracted_categories": extractedData.categories.keys.map { $0.displayName },
            "report_sections_count": reportSections.count,
            "last_update_source": lastUpdateSource
        ]
    }

    // MARK: - Convenience Accessors
    var patientName: String { patientInfo.fullName }
    var pronouns: Pronouns { patientInfo.pronouns }

    func hasExtractedData(for category: ClinicalCategory) -> Bool {
        !(extractedData.categories[category]?.isEmpty ?? true)
    }
}
