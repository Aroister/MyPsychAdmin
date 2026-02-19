//
//  RemainingPopupViews.swift
//  MyPsychAdmin
//
//  Additional popup views for remaining letter sections
//

import SwiftUI

// MARK: - State Structs for Persistence

struct PsychiatricHistoryState: Codable {
    var previousPsychContact: String = ""
    var gpPsychContact: String = ""
    var psychiatricMedication: String = ""
    var psychologicalTherapy: String = ""
}

struct DrugAlcoholState: Codable {
    // Alcohol
    var alcoholAgeStarted: Int = 0
    var alcoholUnits: Int = 0

    // Smoking
    var smokingAgeStarted: Int = 0
    var smokingAmount: Int = 0

    // Drugs - stores state for each drug type
    var drugStates: [String: DrugItemState] = [:]
}

struct DrugItemState: Codable {
    var ageStarted: Int = 0
    var weeklySpend: Int = 0
    var everUsed: Bool = false
}

struct SocialHistoryState: Codable {
    // Housing
    var housingType: String = ""       // homeless, house, flat
    var housingQualifier: String = ""  // private, council, own, family, temporary

    // Benefits
    var benefitsNone: Bool = false
    var benefitItems: [String] = []

    // Debt
    var debtStatus: String = ""        // none, not_in_debt, in_debt
    var debtSeverityIdx: Int = 0
    var debtManaging: String = ""      // managing, not_managing
    var additionalNotes: String = ""
}

struct ForensicHistoryState: Codable {
    // Convictions: "", "declined", "none", "some"
    var convictionsStatus: String = ""
    var convictionCountIdx: Int = 0   // 0-10 for "one conviction" to "more than ten convictions"
    var offenceCountIdx: Int = 0      // 0-10 for "one offence" to "more than ten offences"

    // Prison: "", "declined", "never", "yes"
    var prisonStatus: String = ""
    var prisonDurationIdx: Int = 0    // 0-4 for duration scale
}

struct PhysicalHealthState: Codable {
    // Checkbox selections for each category
    var cardiacConditions: [String] = []
    var endocrineConditions: [String] = []
    var respiratoryConditions: [String] = []
    var gastricConditions: [String] = []
    var neurologicalConditions: [String] = []
    var hepaticConditions: [String] = []
    var renalConditions: [String] = []
    var cancerHistory: [String] = []
}

struct FunctionState: Codable {
    // Self care items with severity: "", "slight", "mild", "moderate", "significant", "severe"
    var personalCare: String = ""
    var homeCare: String = ""
    var children: String = ""
    var pets: String = ""

    // Relationships with severity
    var intimate: String = ""
    var birthFamily: String = ""
    var friends: String = ""

    // Work status: "", "none", "some", "part_time", "full_time"
    var workStatus: String = ""

    // Travel with severity
    var trains: String = ""
    var buses: String = ""
    var cars: String = ""
}

// MARK: - Summary State (matches desktop ImpressionPopup)
struct SummaryState: Codable {
    var selectedDiagnoses: [String] = [] // Up to 3 ICD-10 diagnoses
    var additionalDetails: String = ""
}

// MARK: - Plan State (matches desktop PlanPopup)
struct PlanState: Codable {
    // Medication
    var medicationAction: String? = nil // "start", "stop", "increase", "decrease"
    var newMedName: String = ""
    var newMedDose: String = ""
    var newMedFrequency: String = ""

    // Psychoeducation
    var diagnosisDiscussed: Bool = false
    var medicationDiscussed: Bool = false

    // Capacity
    var capacityStatus: String? = nil // "has" or "lacks"
    var capacityDomain: String = "medication"

    // Psychology
    var psychologyStatus: String? = nil // "continue", "start", "refused"
    var psychologyTherapy: String = "CBT"

    // Occupational Therapy
    var otStatus: String? = nil

    // Care Coordination
    var careStatus: String? = nil

    // Physical Health
    var physicalHealthEnabled: Bool = false
    var physicalHealthTests: [String] = []

    // Next Appointment
    var nextAppointmentDate: Date? = nil

    // Letter Signed By
    var signatoryRole: String? = nil // "Consultant Psychiatrist", "Specialty Doctor", "Registrar"
    var registrarGrade: String? = nil
}

// MARK: - HPC Saved State
struct HPCState: Codable {
    var onset: String = ""
    var selectedTriggers: [String] = []
    var otherTrigger: String = ""
    var dateFirstNoticed: Date?
    var dateBecameSevere: Date?
    var coursePattern: String = ""
    var episodeNumber: String = ""
    var courseDescription: String = ""
    var selectedRisks: [String] = []
    var riskFrequency: String = ""
    var riskIntensity: String = ""
    var riskIntent: String = ""
    var riskMeans: String = ""
    var riskIncidents: String = ""
    var riskProtective: String = ""
    var selectedPastFlags: [String] = []
    var pastTreatment: String = ""
    var selectedModel: [String] = []
    var modelNotes: String = ""
    var collateralType: String = ""
    var collateralConcerns: String = ""
}

// MARK: - History of Presenting Complaint Popup
struct HistoryOfPresentingComplaintPopupView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(SharedDataStore.self) private var sharedData
    @Environment(\.dismiss) private var dismiss

    // Options matching desktop
    let onsetOptions = ["", "Gradual", "Slow", "Over months", "Sudden", "Unclear"]
    let triggerOptions = ["Stress", "Work", "Relationship", "Health", "Medication", "Substance"]
    let coursePatterns = ["Getting worse", "Improving", "Fluctuating", "Relapsing–remitting", "Chronic / unchanged"]
    let riskCategories = ["Suicidal thoughts", "Self-harm", "Harm to others", "Neglect", "Vulnerability", "None reported"]
    let pastFlags = ["Previous similar episodes", "Previous admissions", "Crisis team involvement", "Past self-harm/suicide attempts", "Past violence/aggression"]
    let modelOptions = ["Stress", "Chemical", "Trauma", "Physical", "Social", "Uncertain"]
    let collateralTypes = ["Present", "Telephone", "None obtained"]

    // State
    @State private var onset: String = ""
    @State private var selectedTriggers: Set<String> = []
    @State private var otherTrigger: String = ""
    @State private var hasDateFirstNoticed: Bool = false
    @State private var dateFirstNoticed: Date = Date()
    @State private var hasDateBecameSevere: Bool = false
    @State private var dateBecameSevere: Date = Date()

    @State private var coursePattern: String = ""
    @State private var episodeNumber: String = ""
    @State private var courseDescription: String = ""

    @State private var selectedRisks: Set<String> = []
    @State private var riskFrequency: String = ""
    @State private var riskIntensity: String = ""
    @State private var riskIntent: String = ""
    @State private var riskMeans: String = ""
    @State private var riskIncidents: String = ""
    @State private var riskProtective: String = ""

    @State private var selectedPastFlags: Set<String> = []
    @State private var pastTreatment: String = ""

    @State private var selectedModel: Set<String> = []
    @State private var modelNotes: String = ""

    @State private var collateralType: String = ""
    @State private var collateralConcerns: String = ""

    // Expanded sections
    @State private var expandedSections: Set<String> = []
    @State private var hasLoadedState = false

    var body: some View {
        VStack(spacing: 0) {
            PreviewPanelView(content: generatedText)

            ScrollView {
                VStack(spacing: 16) {
                    // SECTION 1: Onset & Triggers (always visible)
                    onsetTriggersSection

                    // SECTION 2: Collapsible sections
                    HPCCollapsibleSection(title: "Course of Illness", isExpanded: expandedSections.contains("course")) {
                        expandedSections.formSymmetricDifference(["course"])
                    } content: {
                        courseSection
                    }

                    HPCCollapsibleSection(title: "Risks", isExpanded: expandedSections.contains("risks")) {
                        expandedSections.formSymmetricDifference(["risks"])
                    } content: {
                        risksSection
                    }

                    HPCCollapsibleSection(title: "Past Episodes", isExpanded: expandedSections.contains("past")) {
                        expandedSections.formSymmetricDifference(["past"])
                    } content: {
                        pastEpisodesSection
                    }

                    HPCCollapsibleSection(title: "Explanatory Model", isExpanded: expandedSections.contains("model")) {
                        expandedSections.formSymmetricDifference(["model"])
                    } content: {
                        explanatoryModelSection
                    }

                    HPCCollapsibleSection(title: "Collateral Information", isExpanded: expandedSections.contains("collateral")) {
                        expandedSections.formSymmetricDifference(["collateral"])
                    } content: {
                        collateralSection
                    }
                }
                .padding()
            }
        }
        .onAppear { loadSavedState() }
        .onDisappear {
            saveState()
            if !generatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                appStore.updateSection(.historyOfPresentingComplaint, content: generatedText)
            }
        }
    }

    // MARK: - Onset & Triggers Section
    private var onsetTriggersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Onset dropdown
            HStack {
                Text("Onset:")
                    .font(.headline)
                    .foregroundColor(.teal)
                    .frame(width: 60, alignment: .leading)
                Picker("Onset", selection: $onset) {
                    Text("Not specified").tag("")
                    ForEach(onsetOptions.dropFirst(), id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
            }

            // Triggers
            Text("Triggers:")
                .font(.headline)
                .foregroundColor(.teal)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(triggerOptions, id: \.self) { trigger in
                    ImpactChipButton(title: trigger, isSelected: selectedTriggers.contains(trigger)) {
                        if selectedTriggers.contains(trigger) { selectedTriggers.remove(trigger) }
                        else { selectedTriggers.insert(trigger) }
                    }
                }
            }

            TextField("Other trigger (optional)", text: $otherTrigger)
                .textFieldStyle(.roundedBorder)

            // Optional dates
            Toggle("First noticed", isOn: $hasDateFirstNoticed)
            if hasDateFirstNoticed {
                DatePicker("Date", selection: $dateFirstNoticed, in: ...Date(), displayedComponents: .date)
            }

            Toggle("Became severe", isOn: Binding(
                get: { hasDateBecameSevere },
                set: { newValue in
                    hasDateBecameSevere = newValue
                    if newValue {
                        dateBecameSevere = dateFirstNoticed  // Start at first noticed date
                    }
                }
            ))
            if hasDateBecameSevere {
                DatePicker("Date", selection: $dateBecameSevere, in: dateFirstNoticed...Date(), displayedComponents: .date)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Course Section
    private var courseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Course pattern:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            ForEach(coursePatterns, id: \.self) { pattern in
                RadioButton(title: pattern, isSelected: coursePattern == pattern) {
                    coursePattern = pattern
                }
            }

            TextField("Episode number (optional)", text: $episodeNumber)
                .textFieldStyle(.roundedBorder)

            Text("Describe pattern (optional):")
                .font(.subheadline)
                .foregroundColor(.secondary)
            TextEditor(text: $courseDescription)
                .frame(minHeight: 60)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray4)))
        }
    }

    // MARK: - Risks Section
    private var risksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Risk categories:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            ForEach(riskCategories, id: \.self) { risk in
                Toggle(risk, isOn: Binding(
                    get: { selectedRisks.contains(risk) },
                    set: { isOn in
                        if risk == "None reported" && isOn {
                            selectedRisks = ["None reported"]
                        } else if isOn {
                            selectedRisks.remove("None reported")
                            selectedRisks.insert(risk)
                        } else {
                            selectedRisks.remove(risk)
                        }
                    }
                ))
                .toggleStyle(CheckboxToggleStyle())
            }

            if !selectedRisks.contains("None reported") {
                TextField("Frequency", text: $riskFrequency).textFieldStyle(.roundedBorder)
                TextField("Intensity", text: $riskIntensity).textFieldStyle(.roundedBorder)
                TextField("Intent or planning", text: $riskIntent).textFieldStyle(.roundedBorder)
                TextField("Access to means", text: $riskMeans).textFieldStyle(.roundedBorder)

                Text("Recent incidents:")
                    .font(.subheadline).foregroundColor(.secondary)
                TextEditor(text: $riskIncidents)
                    .frame(minHeight: 50)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray4)))

                Text("Protective factors:")
                    .font(.subheadline).foregroundColor(.secondary)
                TextEditor(text: $riskProtective)
                    .frame(minHeight: 50)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray4)))
            }
        }
    }

    // MARK: - Past Episodes Section
    private var pastEpisodesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Historical features:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            ForEach(pastFlags, id: \.self) { flag in
                Toggle(flag, isOn: Binding(
                    get: { selectedPastFlags.contains(flag) },
                    set: { if $0 { selectedPastFlags.insert(flag) } else { selectedPastFlags.remove(flag) } }
                ))
                .toggleStyle(CheckboxToggleStyle())
            }

            Text("Previous treatment & response:")
                .font(.subheadline).foregroundColor(.secondary)
            TextEditor(text: $pastTreatment)
                .frame(minHeight: 60)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray4)))
        }
    }

    // MARK: - Explanatory Model Section
    private var explanatoryModelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Patient's understanding:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(modelOptions, id: \.self) { model in
                    ImpactChipButton(title: model, isSelected: selectedModel.contains(model)) {
                        if selectedModel.contains(model) { selectedModel.remove(model) }
                        else { selectedModel.insert(model) }
                    }
                }
            }

            Text("Patient's explanation (optional):")
                .font(.subheadline).foregroundColor(.secondary)
            TextEditor(text: $modelNotes)
                .frame(minHeight: 50)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray4)))
        }
    }

    // MARK: - Collateral Section
    private var collateralSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Collateral:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            ForEach(collateralTypes, id: \.self) { type in
                RadioButton(title: type, isSelected: collateralType == type) {
                    collateralType = type
                }
            }

            Text("Carer concerns:")
                .font(.subheadline).foregroundColor(.secondary)
            TextEditor(text: $collateralConcerns)
                .frame(minHeight: 50)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray4)))
        }
    }

    // MARK: - State Persistence
    private func loadSavedState() {
        guard !hasLoadedState else { return }
        hasLoadedState = true
        if let saved = appStore.loadPopupData(HPCState.self, for: .historyOfPresentingComplaint) {
            onset = saved.onset
            selectedTriggers = Set(saved.selectedTriggers)
            otherTrigger = saved.otherTrigger
            if let d = saved.dateFirstNoticed { hasDateFirstNoticed = true; dateFirstNoticed = d }
            if let d = saved.dateBecameSevere { hasDateBecameSevere = true; dateBecameSevere = d }
            coursePattern = saved.coursePattern
            episodeNumber = saved.episodeNumber
            courseDescription = saved.courseDescription
            selectedRisks = Set(saved.selectedRisks)
            riskFrequency = saved.riskFrequency
            riskIntensity = saved.riskIntensity
            riskIntent = saved.riskIntent
            riskMeans = saved.riskMeans
            riskIncidents = saved.riskIncidents
            riskProtective = saved.riskProtective
            selectedPastFlags = Set(saved.selectedPastFlags)
            pastTreatment = saved.pastTreatment
            selectedModel = Set(saved.selectedModel)
            modelNotes = saved.modelNotes
            collateralType = saved.collateralType
            collateralConcerns = saved.collateralConcerns
        }
    }

    private func saveState() {
        let state = HPCState(
            onset: onset,
            selectedTriggers: Array(selectedTriggers),
            otherTrigger: otherTrigger,
            dateFirstNoticed: hasDateFirstNoticed ? dateFirstNoticed : nil,
            dateBecameSevere: hasDateBecameSevere ? dateBecameSevere : nil,
            coursePattern: coursePattern,
            episodeNumber: episodeNumber,
            courseDescription: courseDescription,
            selectedRisks: Array(selectedRisks),
            riskFrequency: riskFrequency,
            riskIntensity: riskIntensity,
            riskIntent: riskIntent,
            riskMeans: riskMeans,
            riskIncidents: riskIncidents,
            riskProtective: riskProtective,
            selectedPastFlags: Array(selectedPastFlags),
            pastTreatment: pastTreatment,
            selectedModel: Array(selectedModel),
            modelNotes: modelNotes,
            collateralType: collateralType,
            collateralConcerns: collateralConcerns
        )
        appStore.savePopupData(state, for: .historyOfPresentingComplaint)
    }

    // MARK: - Text Generation (matching desktop grammar)
    private var generatedText: String {
        let p = sharedData.patientInfo.pronouns
        let sub = p.Subject.capitalized
        let poss = p.possessive
        let verb: (String) -> String = { base in (sub.lowercased() == "they") ? base : base + "s" }

        var parts: [String] = []

        // Onset
        if !onset.isEmpty {
            let onsetPhrases: [String: String] = [
                "Over months": "\(sub) described an onset over several months.",
                "Gradual": "\(sub) described a gradual onset of symptoms.",
                "Slow": "\(poss.capitalized) symptoms started slowly.",
                "Sudden": "\(sub) said the symptoms commenced suddenly.",
                "Unclear": "\(sub) was not clear about the onset of \(poss) symptoms."
            ]
            if let phrase = onsetPhrases[onset] { parts.append(phrase) }
        }

        // Triggers
        if !selectedTriggers.isEmpty {
            let triggerExpand: [String: String] = [
                "Stress": "stress-related factors", "Work": "work issues",
                "Relationship": "relationship difficulties", "Health": "physical health decline",
                "Medication": "medication changes", "Substance": "substance use changes"
            ]
            let expanded = selectedTriggers.map { triggerExpand[$0] ?? $0.lowercased() }
            parts.append("Triggers appear to include \(expanded.joined(separator: ", ")).")
        }
        if !otherTrigger.isEmpty { parts.append("Additional trigger reported: \(otherTrigger).") }

        // Dates
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMM yyyy"
        if hasDateFirstNoticed { parts.append("Symptoms were first noticed around \(dateFormatter.string(from: dateFirstNoticed)).") }
        if hasDateBecameSevere { parts.append("Symptoms became more severe around \(dateFormatter.string(from: dateBecameSevere)).") }

        // Course
        if !coursePattern.isEmpty { parts.append("The course has been \(coursePattern.lowercased()).") }
        if !episodeNumber.isEmpty { parts.append("This appears to be episode number \(episodeNumber).") }
        if !courseDescription.isEmpty { parts.append(courseDescription) }

        // Risks
        if selectedRisks.contains("None reported") {
            parts.append("\(sub) \(verb("report")) no current risks.")
        } else if !selectedRisks.isEmpty {
            parts.append("Risks identified include: \(selectedRisks.map { $0.lowercased() }.joined(separator: ", ")).")
            if !riskFrequency.isEmpty { parts.append("Frequency: \(riskFrequency).") }
            if !riskIntensity.isEmpty { parts.append("Intensity: \(riskIntensity).") }
            if !riskIntent.isEmpty { parts.append("Intent: \(riskIntent).") }
            if !riskMeans.isEmpty { parts.append("Access to means: \(riskMeans).") }
            if !riskIncidents.isEmpty { parts.append("Recent incidents: \(riskIncidents)") }
            if !riskProtective.isEmpty { parts.append("Protective factors: \(riskProtective)") }
        }

        // Past episodes
        if !selectedPastFlags.isEmpty {
            let flagsText = joinWithAnd(Array(selectedPastFlags).map { $0.lowercased() })
            parts.append("Historical factors include \(flagsText).")
        }
        if !pastTreatment.isEmpty { parts.append("Previous treatment: \(pastTreatment)") }

        // Model
        if !selectedModel.isEmpty {
            let modelExpand: [String: String] = [
                "Stress": "stress-related", "Chemical": "chemical imbalance",
                "Trauma": "trauma-related", "Physical": "physical health related",
                "Social": "social or situational", "Uncertain": "uncertain"
            ]
            let expanded = selectedModel.map { modelExpand[$0] ?? $0.lowercased() }
            parts.append("\(sub) \(verb("understand")) the symptoms as \(expanded.joined(separator: ", ")).")
        }
        if !modelNotes.isEmpty { parts.append(modelNotes) }

        // Collateral
        if !collateralType.isEmpty {
            let collateralExpand: [String: String] = [
                "Present": "collateral present", "Telephone": "telephone collateral", "None obtained": "no collateral obtained"
            ]
            parts.append("Collateral: \(collateralExpand[collateralType] ?? collateralType.lowercased()).")
        }
        if !collateralConcerns.isEmpty { parts.append("Carer concerns: \(collateralConcerns)") }

        return parts.joined(separator: " ")
    }

    private func joinWithAnd(_ items: [String]) -> String {
        guard !items.isEmpty else { return "" }
        if items.count == 1 { return items[0] }
        if items.count == 2 { return "\(items[0]) and \(items[1])" }
        return items.dropLast().joined(separator: ", ") + ", and \(items.last!)"
    }
}

// MARK: - HPC Collapsible Section Component
struct HPCCollapsibleSection<Content: View>: View {
    let title: String
    let isExpanded: Bool
    let onToggle: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { onToggle() } }) {
                HStack {
                    Text(isExpanded ? "▼" : "▶").font(.system(size: 12))
                    Text(title).font(.headline).foregroundColor(.teal)
                    Spacer()
                }
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            if isExpanded {
                content()
                    .padding(.leading, 16)
                    .padding(.bottom, 12)
            }
        }
        .padding(.horizontal)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Radio Button Component
struct RadioButton: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(isSelected ? .teal : .gray)
                Text(title).foregroundColor(.primary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Psychiatric History Popup
struct PsychiatricHistoryPopupView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(SharedDataStore.self) private var sharedData
    @Environment(\.dismiss) private var dismiss

    // Dropdown labels (short) - selection stored as label
    private let previousPsychLabels = [
        "Never",
        "Did not want to discuss",
        "Outpatient but DNA",
        "Outpatient but no admission",
        "Outpatient + 1 admission",
        "Outpatient + several admissions",
        "Only inpatient"
    ]

    // Output phrases for previous psych (mapped by index)
    private let previousPsychPhrases = [
        "has never seen a psychiatrist before",
        "did not wish to discuss previous psychiatric contact",
        "has been an outpatient in the past but did not attend appointments",
        "has been an outpatient in the past without psychiatric admission",
        "has been an outpatient in the past and has had one inpatient admission",
        "has been an outpatient in the past and has had several inpatient admissions",
        "has only had inpatient psychiatric admissions"
    ]

    // Dropdown labels (short) for GP
    private let gpPsychLabels = [
        "Never",
        "Did not want to discuss",
        "Occasional",
        "Frequent",
        "Regular"
    ]

    // Output phrases for GP (mapped by index)
    private let gpPsychPhrases = [
        "has never seen their GP for psychiatric issues",
        "did not wish to discuss GP contact for psychiatric issues",
        "has occasionally seen their GP for psychiatric issues",
        "has frequently seen their GP for psychiatric issues",
        "has regular GP contact for psychiatric issues"
    ]

    // Dropdown labels for medication
    private let medicationLabels = [
        "Never",
        "Did not want to discuss",
        "Intermittent",
        "Regularly",
        "Current + good compliance",
        "Current + varied compliance",
        "Current + poor compliance",
        "Refuses"
    ]

    // Output phrases for medication
    private let medicationPhrases = [
        "has never taken psychiatric medication",
        "did not wish to discuss psychiatric medication",
        "has taken psychiatric medication intermittently in the past",
        "has taken psychiatric medication regularly in the past",
        "is currently prescribed psychiatric medication with good adherence",
        "is currently prescribed psychiatric medication with variable adherence",
        "is currently prescribed psychiatric medication with poor adherence",
        "refuses psychiatric medication currently and historically"
    ]

    // Dropdown labels for counselling
    private let counsellingLabels = [
        "Did not want to discuss",
        "Intermittent in past",
        "Moderate in past",
        "Extensive in past",
        "Current",
        "Refuses now + past",
        "Refuses now but not past"
    ]

    // Output phrases for counselling
    private let counsellingPhrases = [
        "did not wish to discuss psychological therapy",
        "has received intermittent psychological therapy in the past",
        "has received moderate psychological therapy in the past",
        "has received extensive psychological therapy historically",
        "is currently receiving psychological therapy",
        "refuses psychological therapy currently and historically",
        "refuses psychological therapy currently but has engaged in the past"
    ]

    @State private var previousPsychContact: String = ""
    @State private var gpPsychContact: String = ""
    @State private var psychiatricMedication: String = ""
    @State private var psychologicalTherapy: String = ""

    var body: some View {
        VStack(spacing: 0) {
            PreviewPanelView(content: generatedText)

            Form {
                Section("Previous psychiatric contact") {
                    Picker("Select...", selection: $previousPsychContact) {
                        Text("Not specified").tag("")
                        ForEach(previousPsychLabels, id: \.self) { label in
                            Text(label).tag(label)
                        }
                    }
                }

                Section("GP contact for psychiatric issues") {
                    Picker("Select...", selection: $gpPsychContact) {
                        Text("Not specified").tag("")
                        ForEach(gpPsychLabels, id: \.self) { label in
                            Text(label).tag(label)
                        }
                    }
                }

                Section("Psychiatric medication") {
                    Picker("Select...", selection: $psychiatricMedication) {
                        Text("Not specified").tag("")
                        ForEach(medicationLabels, id: \.self) { label in
                            Text(label).tag(label)
                        }
                    }
                }

                Section("Psychological therapy / counselling") {
                    Picker("Select...", selection: $psychologicalTherapy) {
                        Text("Not specified").tag("")
                        ForEach(counsellingLabels, id: \.self) { label in
                            Text(label).tag(label)
                        }
                    }
                }
            }
        }
        .onAppear { loadState() }
        .onDisappear { saveState() }
    }

    private func loadState() {
        if let saved = appStore.loadPopupData(PsychiatricHistoryState.self, for: .psychiatricHistory) {
            previousPsychContact = saved.previousPsychContact
            gpPsychContact = saved.gpPsychContact
            psychiatricMedication = saved.psychiatricMedication
            psychologicalTherapy = saved.psychologicalTherapy
        }
    }

    private func saveState() {
        var state = PsychiatricHistoryState()
        state.previousPsychContact = previousPsychContact
        state.gpPsychContact = gpPsychContact
        state.psychiatricMedication = psychiatricMedication
        state.psychologicalTherapy = psychologicalTherapy
        appStore.savePopupData(state, for: .psychiatricHistory)

        if !generatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            appStore.updateSection(.psychiatricHistory, content: generatedText)
        }
    }

    // Map label to output phrase (also handles legacy full-phrase values)
    private func getPreviousPsychPhrase(_ value: String) -> String? {
        // First check if it's a label
        if let index = previousPsychLabels.firstIndex(of: value) {
            return previousPsychPhrases[index]
        }
        // Fallback: check if it's already a phrase (legacy data)
        if previousPsychPhrases.contains(value) {
            return value
        }
        return nil
    }

    private func getGpPsychPhrase(_ value: String) -> String? {
        // First check if it's a label
        if let index = gpPsychLabels.firstIndex(of: value) {
            return gpPsychPhrases[index]
        }
        // Fallback: check if it's already a phrase (legacy data)
        if gpPsychPhrases.contains(value) {
            return value
        }
        return nil
    }

    private func getMedicationPhrase(_ value: String) -> String? {
        // First check if it's a label
        if let index = medicationLabels.firstIndex(of: value) {
            return medicationPhrases[index]
        }
        // Fallback: check if it's already a phrase (legacy data)
        if medicationPhrases.contains(value) {
            return value
        }
        return nil
    }

    private func getCounsellingPhrase(_ value: String) -> String? {
        // First check if it's a label
        if let index = counsellingLabels.firstIndex(of: value) {
            return counsellingPhrases[index]
        }
        // Fallback: check if it's already a phrase (legacy data)
        if counsellingPhrases.contains(value) {
            return value
        }
        return nil
    }

    private var generatedText: String {
        let p = sharedData.patientInfo.pronouns
        var sentences: [String] = []

        // Helper to apply pronoun grammar corrections
        func applyPronounGrammar(_ phrase: String) -> String {
            var result = phrase
            // Replace "their" with correct possessive pronoun
            result = result.replacingOccurrences(of: "their ", with: "\(p.possessive) ")

            // For "they", convert singular verbs to plural throughout the phrase
            if p.subject == "they" {
                // Handle verb conversions (order matters - check longer patterns first)
                result = result.replacingOccurrences(of: "refuses ", with: "refuse ")
                result = result.replacingOccurrences(of: " has ", with: " have ")
                result = result.replacingOccurrences(of: " is ", with: " are ")
                result = result.replacingOccurrences(of: " was ", with: " were ")

                // Handle prefix cases
                if result.hasPrefix("has ") {
                    result = "have " + String(result.dropFirst(4))
                } else if result.hasPrefix("is ") {
                    result = "are " + String(result.dropFirst(3))
                } else if result.hasPrefix("was ") {
                    result = "were " + String(result.dropFirst(4))
                } else if result.hasPrefix("refuses ") {
                    result = "refuse " + String(result.dropFirst(8))
                }
            }
            return result
        }

        if !previousPsychContact.isEmpty, let outputPhrase = getPreviousPsychPhrase(previousPsychContact) {
            let phrase = applyPronounGrammar(outputPhrase)
            sentences.append("\(p.Subject.capitalized) \(phrase).")
        }

        if !gpPsychContact.isEmpty, let outputPhrase = getGpPsychPhrase(gpPsychContact) {
            let phrase = applyPronounGrammar(outputPhrase)
            sentences.append("\(p.Subject.capitalized) \(phrase).")
        }

        if !psychiatricMedication.isEmpty, let outputPhrase = getMedicationPhrase(psychiatricMedication) {
            let phrase = applyPronounGrammar(outputPhrase)
            sentences.append("\(p.Subject.capitalized) \(phrase).")
        }

        if !psychologicalTherapy.isEmpty, let outputPhrase = getCounsellingPhrase(psychologicalTherapy) {
            let phrase = applyPronounGrammar(outputPhrase)
            sentences.append("\(p.Subject.capitalized) \(phrase).")
        }

        return sentences.joined(separator: " ")
    }
}

// MARK: - Drug and Alcohol Popup
struct DrugAlcoholPopupView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(SharedDataStore.self) private var sharedData
    @Environment(\.dismiss) private var dismiss

    // Scales matching desktop exactly
    private let ageStartedOptions = [
        (0, "Not specified"),
        (1, "Early teens"),
        (2, "Mid-teens"),
        (3, "Early adulthood"),
        (4, "30s and 40s"),
        (5, "50s"),
        (6, "Later adulthood")
    ]

    private let alcoholUnitsOptions = [
        (0, "Not specified"),
        (1, "1–5 units per week"),
        (2, "5–10 units per week"),
        (3, "10–20 units per week"),
        (4, "20–35 units per week"),
        (5, "35–50 units per week"),
        (6, ">50 units per week")
    ]

    private let smokingAmountOptions = [
        (0, "Not specified"),
        (1, "1–5 cigarettes per day"),
        (2, "5–10 cigarettes per day"),
        (3, "10–20 cigarettes per day"),
        (4, "20–30 cigarettes per day"),
        (5, ">30 cigarettes per day")
    ]

    private let drugCostOptions = [
        (0, "Not specified"),
        (1, "<£20 per week"),
        (2, "£20–50 per week"),
        (3, "£50–100 per week"),
        (4, "£100–250 per week"),
        (5, ">£250 per week")
    ]

    private let drugTypes = [
        "Cannabis", "Cocaine", "Crack cocaine", "Heroin", "Ecstasy (MDMA)",
        "LSD", "Spice / synthetic cannabinoids", "Amphetamines", "Ketamine", "Benzodiazepines"
    ]

    private let ageToDuration: [Int: String] = [
        1: "for many years",      // early teens
        2: "for many years",      // mid-teens
        3: "for several years",   // early adulthood
        4: "for some years",      // 30s and 40s
        5: "for some years",      // 50s
        6: "more recently"        // later adulthood
    ]

    // Age thresholds for each option
    private let ageThresholds: [Int: Int] = [
        1: 13,   // Early teens - must be at least 13
        2: 16,   // Mid-teens - must be at least 16
        3: 20,   // Early adulthood - must be at least 20
        4: 30,   // 30s and 40s - must be at least 30
        5: 50,   // 50s - must be at least 50
        6: 60    // Later adulthood - must be at least 60
    ]

    // Computed property to filter age options based on patient's DOB
    private var filteredAgeOptions: [(Int, String)] {
        guard let dob = sharedData.patientInfo.dateOfBirth else {
            return ageStartedOptions
        }

        let calendar = Calendar.current
        let now = Date()
        let ageComponents = calendar.dateComponents([.year], from: dob, to: now)
        let patientAge = ageComponents.year ?? 100

        return ageStartedOptions.filter { (index, _) in
            guard let threshold = ageThresholds[index] else {
                return true // Always include "Not specified" (index 0)
            }
            return patientAge >= threshold
        }
    }

    // Alcohol
    @State private var alcoholAgeStarted: Int = 0
    @State private var alcoholUnits: Int = 0

    // Smoking
    @State private var smokingAgeStarted: Int = 0
    @State private var smokingAmount: Int = 0

    // Drugs
    @State private var selectedDrug: String? = nil
    @State private var drugStates: [String: DrugItemState] = [:]

    @State private var expandedSections: Set<String> = ["Alcohol"]

    var body: some View {
        VStack(spacing: 0) {
            PreviewPanelView(content: generatedText)

            ScrollView {
                VStack(spacing: 12) {
                    // Alcohol Section
                    HistoryCollapsibleSection(title: "Alcohol", icon: "wineglass", isExpanded: expandedSections.contains("Alcohol")) {
                        expandedSections.formSymmetricDifference(["Alcohol"])
                    } content: {
                        VStack(alignment: .leading, spacing: 16) {
                            LabeledScalePicker(
                                label: "Age started drinking",
                                selection: $alcoholAgeStarted,
                                options: filteredAgeOptions
                            )
                            LabeledScalePicker(
                                label: "Current alcohol use",
                                selection: $alcoholUnits,
                                options: alcoholUnitsOptions
                            )
                        }
                    }

                    // Smoking Section
                    HistoryCollapsibleSection(title: "Smoking", icon: "smoke", isExpanded: expandedSections.contains("Smoking")) {
                        expandedSections.formSymmetricDifference(["Smoking"])
                    } content: {
                        VStack(alignment: .leading, spacing: 16) {
                            LabeledScalePicker(
                                label: "Age started smoking",
                                selection: $smokingAgeStarted,
                                options: filteredAgeOptions
                            )
                            LabeledScalePicker(
                                label: "Current smoking",
                                selection: $smokingAmount,
                                options: smokingAmountOptions
                            )
                        }
                    }

                    // Illicit Drugs Section
                    HistoryCollapsibleSection(title: "Illicit Drugs", icon: "pills", isExpanded: expandedSections.contains("Drugs")) {
                        expandedSections.formSymmetricDifference(["Drugs"])
                    } content: {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Select drugs used (tap to configure)")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            ForEach(drugTypes, id: \.self) { drug in
                                DrugRowView(
                                    drug: drug,
                                    isSelected: selectedDrug == drug,
                                    state: drugStates[drug] ?? DrugItemState(),
                                    ageOptions: filteredAgeOptions,
                                    costOptions: drugCostOptions,
                                    onSelect: {
                                        selectedDrug = (selectedDrug == drug) ? nil : drug
                                        // Mark as ever used when selected
                                        if drugStates[drug] == nil {
                                            drugStates[drug] = DrugItemState()
                                        }
                                        drugStates[drug]?.everUsed = true
                                    },
                                    onAgeChanged: { newAge in
                                        if drugStates[drug] == nil {
                                            drugStates[drug] = DrugItemState()
                                        }
                                        drugStates[drug]?.ageStarted = newAge
                                        drugStates[drug]?.everUsed = true
                                    },
                                    onSpendChanged: { newSpend in
                                        if drugStates[drug] == nil {
                                            drugStates[drug] = DrugItemState()
                                        }
                                        drugStates[drug]?.weeklySpend = newSpend
                                        drugStates[drug]?.everUsed = true
                                    }
                                )
                            }
                        }
                    }
                }
                .padding()
                .padding(.bottom, 20)
            }
        }
        .onAppear { loadState() }
        .onDisappear { saveState() }
    }

    private func loadState() {
        if let saved = appStore.loadPopupData(DrugAlcoholState.self, for: .drugsAlcohol) {
            alcoholAgeStarted = saved.alcoholAgeStarted
            alcoholUnits = saved.alcoholUnits
            smokingAgeStarted = saved.smokingAgeStarted
            smokingAmount = saved.smokingAmount
            drugStates = saved.drugStates
        }
    }

    private func saveState() {
        var state = DrugAlcoholState()
        state.alcoholAgeStarted = alcoholAgeStarted
        state.alcoholUnits = alcoholUnits
        state.smokingAgeStarted = smokingAgeStarted
        state.smokingAmount = smokingAmount
        state.drugStates = drugStates
        appStore.savePopupData(state, for: .drugsAlcohol)

        if !generatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            appStore.updateSection(.drugsAlcohol, content: generatedText)
        }
    }

    // MARK: - Text Generation (matching desktop exactly)
    private var generatedText: String {
        let p = sharedData.patientInfo.pronouns
        let subj = p.Subject.capitalized
        var sentences: [String] = []
        var verbIndex = 0

        let verbs = ["reported", "described", "also described", "also reported", "additionally reported"]

        func addSentence(_ body: String) {
            let verb = verbs[min(verbIndex, verbs.count - 1)]
            sentences.append("\(subj) \(verb) \(body).")
            verbIndex += 1
        }

        // Alcohol
        var alcBits: [String] = []
        if alcoholAgeStarted > 0 {
            alcBits.append("starting in \(ageStartedOptions[alcoholAgeStarted].1.lowercased())")
        }
        if alcoholUnits > 0 {
            alcBits.append("with current use of \(alcoholUnitsOptions[alcoholUnits].1.lowercased())")
        }
        if !alcBits.isEmpty {
            addSentence("drinking alcohol, " + alcBits.joined(separator: ", "))
        }

        // Smoking
        var smokeBits: [String] = []
        if smokingAgeStarted > 0 {
            smokeBits.append("starting in \(ageStartedOptions[smokingAgeStarted].1.lowercased())")
        }
        if smokingAmount > 0 {
            smokeBits.append("with current use of \(smokingAmountOptions[smokingAmount].1.lowercased())")
        }
        if !smokeBits.isEmpty {
            addSentence("smoking tobacco, " + smokeBits.joined(separator: ", "))
        }

        // Drugs - separate past use from current use
        var pastUseDrugs: [(drug: String, age: Int)] = []
        var currentUseDrugs: [(drug: String, age: Int, spend: Int)] = []

        for (drug, state) in drugStates {
            guard state.everUsed else { continue }

            if state.weeklySpend > 0 {
                currentUseDrugs.append((drug: drug, age: state.ageStarted, spend: state.weeklySpend))
            } else if state.ageStarted > 0 || state.everUsed {
                pastUseDrugs.append((drug: drug, age: state.ageStarted))
            }
        }

        // Past use drugs
        if !pastUseDrugs.isEmpty {
            let pastIntros = ["\(subj) admitted to previous use of", "\(subj) has previously used", "\(subj) used to take"]
            let intro = pastIntros[sentences.count % pastIntros.count]

            if pastUseDrugs.count == 1 {
                let d = pastUseDrugs[0]
                let drugName = d.drug.lowercased()
                let agePart = d.age > 0 ? ", starting in \(ageStartedOptions[d.age].1.lowercased())" : ""
                sentences.append("\(intro) \(drugName)\(agePart).")
            } else {
                let drugNames = pastUseDrugs.map { $0.drug.lowercased() }
                let drugsStr: String
                if drugNames.count == 2 {
                    drugsStr = "\(drugNames[0]) and \(drugNames[1])"
                } else {
                    drugsStr = drugNames.dropLast().joined(separator: ", ") + ", and \(drugNames.last!)"
                }
                sentences.append("\(intro) \(drugsStr).")
            }
        }

        // Current use drugs
        for d in currentUseDrugs {
            let drugName = d.drug.lowercased()
            var parts: [String] = []

            if d.age > 0 {
                parts.append("starting in \(ageStartedOptions[d.age].1.lowercased())")
                if let duration = ageToDuration[d.age] {
                    parts.append(duration)
                }
            }
            parts.append("spending \(drugCostOptions[d.spend].1.lowercased())")

            addSentence("current use of \(drugName), " + parts.joined(separator: ", "))
        }

        return sentences.joined(separator: " ")
    }
}

// MARK: - Drug Row View
struct DrugRowView: View {
    let drug: String
    let isSelected: Bool
    let state: DrugItemState
    let ageOptions: [(Int, String)]
    let costOptions: [(Int, String)]
    let onSelect: () -> Void
    let onAgeChanged: (Int) -> Void
    let onSpendChanged: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onSelect) {
                HStack {
                    Image(systemName: state.everUsed ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(state.everUsed ? .green : .gray)
                    Text(drug)
                        .foregroundColor(.primary)
                    Spacer()
                    if isSelected {
                        Image(systemName: "chevron.down")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)

            if isSelected {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Age started", selection: Binding(
                        get: { state.ageStarted },
                        set: { onAgeChanged($0) }
                    )) {
                        ForEach(ageOptions, id: \.0) { (value, label) in
                            Text(label).tag(value)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Weekly spend", selection: Binding(
                        get: { state.weeklySpend },
                        set: { onSpendChanged($0) }
                    )) {
                        ForEach(costOptions, id: \.0) { (value, label) in
                            Text(label).tag(value)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .padding(.leading, 28)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Labeled Scale Picker
struct LabeledScalePicker: View {
    let label: String
    @Binding var selection: Int
    let options: [(Int, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            Picker(label, selection: $selection) {
                ForEach(options, id: \.0) { (value, optionLabel) in
                    Text(optionLabel).tag(value)
                }
            }
            .pickerStyle(.menu)

            if selection > 0 {
                Text(options[selection].1)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.yellow.opacity(0.3))
                    .cornerRadius(4)
            }
        }
    }
}

// MARK: - Social History Popup
struct SocialHistoryPopupView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(SharedDataStore.self) private var sharedData
    @Environment(\.dismiss) private var dismiss

    // Housing options matching desktop
    private let housingTypes = [
        ("homeless", "Homeless"),
        ("house", "House"),
        ("flat", "Flat")
    ]

    private let housingQualifiers = [
        ("private", "Private"),
        ("council", "Council"),
        ("own", "Own"),
        ("family", "Family"),
        ("temporary", "Temporary")
    ]

    // Benefits options matching desktop
    private let benefitOptions = [
        "Section 117 aftercare", "ESA", "PIP", "Universal Credit",
        "DLA", "Pension", "Income Support", "Child Tax Credit", "Child Benefit"
    ]

    // Debt options matching desktop
    private let debtStatusOptions = [
        ("none", "Did not want to discuss"),
        ("not_in_debt", "No, not in debt"),
        ("in_debt", "Yes, in debt")
    ]

    private let debtSeverityOptions = [
        "no significant debt",
        "some small debt",
        "some moderate debt",
        "significant debt",
        "severely in debt"
    ]

    private let debtManagingOptions = [
        ("managing", "Is managing"),
        ("not_managing", "Is not managing")
    ]

    // State
    @State private var housingType: String = ""
    @State private var housingQualifier: String = ""
    @State private var benefitsNone: Bool = false
    @State private var benefitItems: Set<String> = []
    @State private var debtStatus: String = ""
    @State private var debtSeverityIdx: Int = 0
    @State private var debtManaging: String = ""

    @State private var expandedSections: Set<String> = ["Housing"]

    var body: some View {
        VStack(spacing: 0) {
            PreviewPanelView(content: generatedText)

            ScrollView {
                VStack(spacing: 12) {
                    // Housing Section
                    HistoryCollapsibleSection(title: "Housing", icon: "house", isExpanded: expandedSections.contains("Housing")) {
                        expandedSections.formSymmetricDifference(["Housing"])
                    } content: {
                        VStack(alignment: .leading, spacing: 12) {
                            // Housing type
                            Text("Type")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)

                            ForEach(housingTypes, id: \.0) { (value, label) in
                                RadioButton(title: label, isSelected: housingType == value) {
                                    housingType = value
                                    if value == "homeless" {
                                        housingQualifier = ""
                                    }
                                }
                            }

                            // Qualifier (only for house/flat)
                            if housingType == "house" || housingType == "flat" {
                                Divider()

                                Text("Qualifier")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)

                                ForEach(housingQualifiers, id: \.0) { (value, label) in
                                    RadioButton(title: label, isSelected: housingQualifier == value) {
                                        housingQualifier = value
                                    }
                                }
                            }
                        }
                    }

                    // Benefits Section
                    HistoryCollapsibleSection(title: "Benefits", icon: "sterlingsign.circle", isExpanded: expandedSections.contains("Benefits")) {
                        expandedSections.formSymmetricDifference(["Benefits"])
                    } content: {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(benefitOptions, id: \.self) { benefit in
                                Toggle(benefit, isOn: Binding(
                                    get: { benefitItems.contains(benefit) },
                                    set: { isOn in
                                        if !benefitsNone {
                                            if isOn { benefitItems.insert(benefit) }
                                            else { benefitItems.remove(benefit) }
                                        }
                                    }
                                ))
                                .disabled(benefitsNone)
                                .font(.subheadline)
                            }

                            Divider()

                            Toggle("Did not wish to discuss benefits", isOn: $benefitsNone)
                                .font(.subheadline)
                                .onChange(of: benefitsNone) { _, newValue in
                                    if newValue {
                                        benefitItems.removeAll()
                                    }
                                }
                        }
                    }

                    // Debt Section
                    HistoryCollapsibleSection(title: "Debt", icon: "creditcard", isExpanded: expandedSections.contains("Debt")) {
                        expandedSections.formSymmetricDifference(["Debt"])
                    } content: {
                        VStack(alignment: .leading, spacing: 12) {
                            // Debt status
                            ForEach(debtStatusOptions, id: \.0) { (value, label) in
                                RadioButton(title: label, isSelected: debtStatus == value) {
                                    debtStatus = value
                                    if value != "in_debt" {
                                        debtSeverityIdx = 0
                                        debtManaging = ""
                                    }
                                }
                            }

                            // If in debt, show severity and managing options
                            if debtStatus == "in_debt" {
                                Divider()

                                Text("Debt severity")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)

                                Picker("Severity", selection: $debtSeverityIdx) {
                                    ForEach(0..<debtSeverityOptions.count, id: \.self) { idx in
                                        Text(debtSeverityOptions[idx].capitalized).tag(idx)
                                    }
                                }
                                .pickerStyle(.menu)

                                Divider()

                                Text("Managing debt?")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)

                                ForEach(debtManagingOptions, id: \.0) { (value, label) in
                                    RadioButton(title: label, isSelected: debtManaging == value) {
                                        debtManaging = value
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
                .padding(.bottom, 20)
            }
        }
        .onAppear { loadState() }
        .onDisappear { saveState() }
    }

    private func loadState() {
        if let saved = appStore.loadPopupData(SocialHistoryState.self, for: .socialHistory) {
            housingType = saved.housingType
            housingQualifier = saved.housingQualifier
            benefitsNone = saved.benefitsNone
            benefitItems = Set(saved.benefitItems)
            debtStatus = saved.debtStatus
            debtSeverityIdx = saved.debtSeverityIdx
            debtManaging = saved.debtManaging
        }
    }

    private func saveState() {
        var state = SocialHistoryState()
        state.housingType = housingType
        state.housingQualifier = housingQualifier
        state.benefitsNone = benefitsNone
        state.benefitItems = Array(benefitItems)
        state.debtStatus = debtStatus
        state.debtSeverityIdx = debtSeverityIdx
        state.debtManaging = debtManaging
        appStore.savePopupData(state, for: .socialHistory)

        if !generatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            appStore.updateSection(.socialHistory, content: generatedText)
        }
    }

    // MARK: - Text Generation (matching desktop exactly)
    private var generatedText: String {
        let p = sharedData.patientInfo.pronouns
        var out: [String] = []

        // Housing
        if housingType == "homeless" {
            out.append("\(p.Subject.capitalized) \(p.bePresent) currently homeless.")
        } else if !housingType.isEmpty {
            if !housingQualifier.isEmpty {
                if housingQualifier == "own" {
                    out.append("\(p.Subject.capitalized) \(p.bePresent) living in \(p.possessive) own \(housingType).")
                } else if housingQualifier == "private" {
                    out.append("\(p.Subject.capitalized) \(p.bePresent) living in a privately rented \(housingType).")
                } else if housingQualifier == "temporary" {
                    out.append("\(p.Subject.capitalized) \(p.bePresent) living in a \(housingType) which is temporary accommodation.")
                } else {
                    out.append("\(p.Subject.capitalized) \(p.bePresent) living in a \(housingQualifier) \(housingType).")
                }
            } else {
                out.append("\(p.Subject.capitalized) \(p.bePresent) living in a \(housingType).")
            }
        }

        // Benefits
        if benefitsNone {
            out.append("\(p.Subject.capitalized) did not wish to discuss benefits.")
        } else if !benefitItems.isEmpty {
            let items = benefitItems.sorted()
            if items.count == 1 {
                out.append("\(p.Subject.capitalized) \(p.havePresent) access to \(items[0]).")
            } else {
                let joined = items.dropLast().joined(separator: ", ") + ", and \(items.last!)"
                out.append("\(p.Subject.capitalized) \(p.havePresent) access to \(joined).")
            }
        }

        // Debt
        if debtStatus == "none" {
            out.append("\(p.Subject.capitalized) did not wish to discuss financial matters.")
        } else if debtStatus == "not_in_debt" {
            out.append("\(p.Subject.capitalized) \(p.bePresent) not currently in debt.")
        } else if debtStatus == "in_debt" {
            let sev = debtSeverityOptions[debtSeverityIdx]

            // Use "is" for phrases like "severely in debt", "has" for "some debt"
            let debtVerb = sev.contains("in debt") ? p.bePresent : p.havePresent

            if debtManaging == "managing" {
                out.append("\(p.Subject.capitalized) \(debtVerb) \(sev) and \(p.bePresent) managing this.")
            } else if debtManaging == "not_managing" {
                out.append("\(p.Subject.capitalized) \(debtVerb) \(sev) and \(p.bePresent) not managing this.")
            } else {
                out.append("\(p.Subject.capitalized) \(debtVerb) \(sev).")
            }
        }

        return out.joined(separator: " ")
    }
}

// MARK: - Forensic History Popup
struct ForensicHistoryPopupView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(SharedDataStore.self) private var sharedData
    @Environment(\.dismiss) private var dismiss

    // Convictions state
    @State private var convictionsStatus: String = ""  // "", "declined", "none", "some"
    @State private var convictionCountIdx: Int = 0
    @State private var offenceCountIdx: Int = 0

    // Prison state
    @State private var prisonStatus: String = ""  // "", "declined", "never", "yes"
    @State private var prisonDurationIdx: Int = 0

    // Scale labels matching desktop
    private let convictionCounts = [
        "one conviction", "two convictions", "three convictions",
        "four convictions", "five convictions", "six convictions",
        "seven convictions", "eight convictions", "nine convictions",
        "ten convictions", "more than ten convictions"
    ]

    private let offenceCounts = [
        "one offence", "two offences", "three offences", "four offences",
        "five offences", "six offences", "seven offences",
        "eight offences", "nine offences", "ten offences",
        "more than ten offences"
    ]

    private let prisonDurations = [
        "less than six months",
        "six to twelve months",
        "one to two years",
        "two to five years",
        "more than five years"
    ]

    var body: some View {
        VStack(spacing: 0) {
            PreviewPanelView(content: generatedText)

            ScrollView {
                VStack(spacing: 16) {
                    // Convictions Section
                    SimpleCollapsibleSection(title: "Convictions", startExpanded: true) {
                        VStack(alignment: .leading, spacing: 12) {
                            RadioButton(title: "Did not wish to discuss", isSelected: convictionsStatus == "declined") {
                                convictionsStatus = "declined"
                            }
                            RadioButton(title: "No convictions", isSelected: convictionsStatus == "none") {
                                convictionsStatus = "none"
                            }
                            RadioButton(title: "Has convictions", isSelected: convictionsStatus == "some") {
                                convictionsStatus = "some"
                            }

                            if convictionsStatus == "some" {
                                VStack(alignment: .leading, spacing: 8) {
                                    LabeledScalePicker(
                                        label: "Number of convictions",
                                        selection: $convictionCountIdx,
                                        options: convictionCounts.enumerated().map { ($0.offset, $0.element) }
                                    )

                                    LabeledScalePicker(
                                        label: "Number of offences",
                                        selection: $offenceCountIdx,
                                        options: offenceCounts.enumerated().map { ($0.offset, $0.element) }
                                    )
                                }
                                .padding(.leading, 24)
                                .padding(.top, 8)
                            }
                        }
                    }

                    // Prison History Section
                    SimpleCollapsibleSection(title: "Prison History", startExpanded: true) {
                        VStack(alignment: .leading, spacing: 12) {
                            RadioButton(title: "Did not wish to discuss", isSelected: prisonStatus == "declined") {
                                prisonStatus = "declined"
                            }
                            RadioButton(title: "Never been in prison", isSelected: prisonStatus == "never") {
                                prisonStatus = "never"
                            }
                            RadioButton(title: "Has been in prison / remanded", isSelected: prisonStatus == "yes") {
                                prisonStatus = "yes"
                            }

                            if prisonStatus == "yes" {
                                VStack(alignment: .leading, spacing: 8) {
                                    LabeledScalePicker(
                                        label: "Total time spent in prison",
                                        selection: $prisonDurationIdx,
                                        options: prisonDurations.enumerated().map { ($0.offset, $0.element) }
                                    )
                                }
                                .padding(.leading, 24)
                                .padding(.top, 8)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .onAppear { loadState() }
        .onDisappear { saveState() }
    }

    private func loadState() {
        if let saved = appStore.loadPopupData(ForensicHistoryState.self, for: .forensicHistory) {
            convictionsStatus = saved.convictionsStatus
            convictionCountIdx = saved.convictionCountIdx
            offenceCountIdx = saved.offenceCountIdx
            prisonStatus = saved.prisonStatus
            prisonDurationIdx = saved.prisonDurationIdx
        }
    }

    private func saveState() {
        var state = ForensicHistoryState()
        state.convictionsStatus = convictionsStatus
        state.convictionCountIdx = convictionCountIdx
        state.offenceCountIdx = offenceCountIdx
        state.prisonStatus = prisonStatus
        state.prisonDurationIdx = prisonDurationIdx
        appStore.savePopupData(state, for: .forensicHistory)

        if !generatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            appStore.updateSection(.forensicHistory, content: generatedText)
        }
    }

    private var generatedText: String {
        let p = sharedData.patientInfo.pronouns
        var sentences: [String] = []

        // Convictions text
        switch convictionsStatus {
        case "declined":
            sentences.append("\(p.Subject.capitalized) did not wish to discuss convictions.")
        case "none":
            sentences.append("\(p.Subject.capitalized) has no convictions.")
        case "some":
            let convCount = convictionCounts[convictionCountIdx]
            let offCount = offenceCounts[offenceCountIdx]
            sentences.append("\(p.Subject.capitalized) \(p.havePresent) \(convCount) from \(offCount).")
        default:
            break
        }

        // Prison text
        switch prisonStatus {
        case "declined":
            sentences.append("\(p.Subject.capitalized) did not wish to discuss prison history.")
        case "never":
            sentences.append("\(p.Subject.capitalized) \(p.havePresent) never been in prison.")
        case "yes":
            let duration = prisonDurations[prisonDurationIdx]
            // If no convictions or declined, use "remanded" phrasing
            if convictionsStatus == "none" || convictionsStatus == "declined" || convictionsStatus.isEmpty {
                sentences.append("\(p.Subject.capitalized) \(p.havePresent) been remanded to prison for \(duration).")
            } else {
                sentences.append("\(p.Subject.capitalized) \(p.havePresent) spent \(duration) in prison.")
            }
        default:
            break
        }

        return sentences.joined(separator: " ")
    }
}

// MARK: - Physical Health Popup
struct PhysicalHealthPopupView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(SharedDataStore.self) private var sharedData
    @Environment(\.dismiss) private var dismiss

    // Health condition categories with checkboxes
    @State private var cardiacConditions: Set<String> = []
    @State private var endocrineConditions: Set<String> = []
    @State private var respiratoryConditions: Set<String> = []
    @State private var gastricConditions: Set<String> = []
    @State private var neurologicalConditions: Set<String> = []
    @State private var hepaticConditions: Set<String> = []
    @State private var renalConditions: Set<String> = []
    @State private var cancerHistory: Set<String> = []

    // Condition options matching desktop
    private let cardiacOptions = ["hypertension", "MI", "arrhythmias", "high cholesterol", "heart failure"]
    private let endocrineOptions = ["diabetes", "thyroid disorder", "PCOS"]
    private let respiratoryOptions = ["asthma", "COPD", "bronchitis"]
    private let gastricOptions = ["gastric ulcer", "gastro-oesophageal reflux disease (GORD)", "irritable bowel syndrome"]
    private let neurologicalOptions = ["multiple sclerosis", "Parkinson's disease", "epilepsy"]
    private let hepaticOptions = ["hepatitis C", "fatty liver", "alcohol-related liver disease"]
    private let renalOptions = ["chronic kidney disease", "end-stage renal disease"]
    private let cancerOptions = ["lung", "prostate", "bladder", "uterine", "breast", "brain", "kidney"]

    var body: some View {
        VStack(spacing: 0) {
            PreviewPanelView(content: generatedText)

            ScrollView {
                VStack(spacing: 16) {
                    // Cardiac Conditions
                    HealthConditionSection(
                        title: "Cardiac conditions",
                        options: cardiacOptions,
                        selectedOptions: $cardiacConditions
                    )

                    // Endocrine Conditions
                    HealthConditionSection(
                        title: "Endocrine conditions",
                        options: endocrineOptions,
                        selectedOptions: $endocrineConditions
                    )

                    // Respiratory Conditions
                    HealthConditionSection(
                        title: "Respiratory conditions",
                        options: respiratoryOptions,
                        selectedOptions: $respiratoryConditions
                    )

                    // Gastric Conditions
                    HealthConditionSection(
                        title: "Gastric conditions",
                        options: gastricOptions,
                        selectedOptions: $gastricConditions
                    )

                    // Neurological Conditions
                    HealthConditionSection(
                        title: "Neurological conditions",
                        options: neurologicalOptions,
                        selectedOptions: $neurologicalConditions
                    )

                    // Hepatic Conditions
                    HealthConditionSection(
                        title: "Hepatic conditions",
                        options: hepaticOptions,
                        selectedOptions: $hepaticConditions
                    )

                    // Renal Conditions
                    HealthConditionSection(
                        title: "Renal conditions",
                        options: renalOptions,
                        selectedOptions: $renalConditions
                    )

                    // Cancer History
                    HealthConditionSection(
                        title: "Cancer history",
                        options: cancerOptions,
                        selectedOptions: $cancerHistory
                    )
                }
                .padding()
            }
        }
        .onAppear { loadState() }
        .onDisappear { saveState() }
    }

    private func loadState() {
        if let saved = appStore.loadPopupData(PhysicalHealthState.self, for: .physicalHealth) {
            cardiacConditions = Set(saved.cardiacConditions)
            endocrineConditions = Set(saved.endocrineConditions)
            respiratoryConditions = Set(saved.respiratoryConditions)
            gastricConditions = Set(saved.gastricConditions)
            neurologicalConditions = Set(saved.neurologicalConditions)
            hepaticConditions = Set(saved.hepaticConditions)
            renalConditions = Set(saved.renalConditions)
            cancerHistory = Set(saved.cancerHistory)
        }
    }

    private func saveState() {
        var state = PhysicalHealthState()
        state.cardiacConditions = Array(cardiacConditions)
        state.endocrineConditions = Array(endocrineConditions)
        state.respiratoryConditions = Array(respiratoryConditions)
        state.gastricConditions = Array(gastricConditions)
        state.neurologicalConditions = Array(neurologicalConditions)
        state.hepaticConditions = Array(hepaticConditions)
        state.renalConditions = Array(renalConditions)
        state.cancerHistory = Array(cancerHistory)
        appStore.savePopupData(state, for: .physicalHealth)

        if !generatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            appStore.updateSection(.physicalHealth, content: generatedText)
        }
    }

    private var generatedText: String {
        let p = sharedData.patientInfo.pronouns
        var paragraphs: [String] = []

        // Cardiac
        if !cardiacConditions.isEmpty {
            let items = cardiacConditions.sorted().joined(separator: ", ")
            paragraphs.append("Cardiac conditions, including \(items), are noted in the patient's history.")
        }

        // Endocrine
        if !endocrineConditions.isEmpty {
            let items = endocrineConditions.sorted().joined(separator: ", ")
            paragraphs.append("\(p.Subject.capitalized) \(p.havePresent) endocrine conditions including \(items).")
        }

        // Respiratory
        if !respiratoryConditions.isEmpty {
            let items = respiratoryConditions.sorted().joined(separator: ", ")
            paragraphs.append("Additionally, \(p.Subject) \(p.havePresent) respiratory conditions including \(items).")
        }

        // Gastric
        if !gastricConditions.isEmpty {
            let items = gastricConditions.sorted().joined(separator: ", ")
            paragraphs.append("\(p.Subject.capitalized) \(p.havePresent) a long-standing history of gastrointestinal issues including \(items).")
        }

        // Neurological
        if !neurologicalConditions.isEmpty {
            let items = neurologicalConditions.sorted().joined(separator: ", ")
            paragraphs.append("Neurologically, \(p.Subject) \(p.havePresent) a history of \(items), well-managed with treatment.")
        }

        // Hepatic
        if !hepaticConditions.isEmpty {
            let items = hepaticConditions.sorted().joined(separator: ", ")
            paragraphs.append("Regarding hepatic conditions, \(p.Subject) \(p.havePresent) been monitored for \(items).")
        }

        // Renal
        if !renalConditions.isEmpty {
            let items = renalConditions.sorted().joined(separator: ", ")
            paragraphs.append("\(p.Subject.capitalized) \(p.havePresent) been treated for \(items).")
        }

        // Cancer
        if !cancerHistory.isEmpty {
            let items = cancerHistory.sorted().joined(separator: ", ")
            paragraphs.append("Finally, \(p.Subject) \(p.havePresent) a history of \(items) cancer and continues with regular monitoring.")
        }

        return paragraphs.joined(separator: " ")
    }
}

// Helper component for health condition sections
struct HealthConditionSection: View {
    let title: String
    let options: [String]
    @Binding var selectedOptions: Set<String>
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    Text(title)
                        .font(.headline)
                        .foregroundColor(selectedOptions.isEmpty ? .secondary : .primary)
                    Spacer()
                    if !selectedOptions.isEmpty {
                        Text("\(selectedOptions.count)")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .clipShape(Capsule())
                    }
                }
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            Divider()

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(options, id: \.self) { option in
                        Button(action: {
                            if selectedOptions.contains(option) {
                                selectedOptions.remove(option)
                            } else {
                                selectedOptions.insert(option)
                            }
                        }) {
                            HStack {
                                Image(systemName: selectedOptions.contains(option) ? "checkmark.square.fill" : "square")
                                    .foregroundColor(selectedOptions.contains(option) ? .blue : .secondary)
                                Text(option)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.leading, 28)
                .padding(.vertical, 8)
            }
        }
        .padding(.horizontal)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
}

// MARK: - Function Popup
struct FunctionPopupView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(SharedDataStore.self) private var sharedData
    @Environment(\.dismiss) private var dismiss

    // Self care items with severity
    @State private var personalCare: String = ""
    @State private var homeCare: String = ""
    @State private var children: String = ""
    @State private var pets: String = ""

    // Relationships with severity
    @State private var intimate: String = ""
    @State private var birthFamily: String = ""
    @State private var friends: String = ""

    // Work status
    @State private var workStatus: String = ""

    // Travel with severity
    @State private var trains: String = ""
    @State private var buses: String = ""
    @State private var cars: String = ""

    private let severityLevels = ["slight", "mild", "moderate", "significant", "severe"]
    private let workOptions = [
        ("none", "No work"),
        ("some", "Some work"),
        ("part_time", "Part-time work"),
        ("full_time", "Full-time work")
    ]

    var body: some View {
        VStack(spacing: 0) {
            PreviewPanelView(content: generatedText)

            ScrollView {
                VStack(spacing: 16) {
                    // Self Care Section
                    SimpleCollapsibleSection(title: "Self Care", startExpanded: true) {
                        VStack(alignment: .leading, spacing: 16) {
                            FunctionSeverityRow(label: "Personal care", severity: $personalCare, levels: severityLevels)
                            FunctionSeverityRow(label: "Home care", severity: $homeCare, levels: severityLevels)
                            FunctionSeverityRow(label: "Children", severity: $children, levels: severityLevels)
                            FunctionSeverityRow(label: "Pets", severity: $pets, levels: severityLevels)
                        }
                    }

                    // Relationships Section
                    SimpleCollapsibleSection(title: "Relationships", startExpanded: true) {
                        VStack(alignment: .leading, spacing: 16) {
                            FunctionSeverityRow(label: "Intimate", severity: $intimate, levels: severityLevels)
                            FunctionSeverityRow(label: "Birth family", severity: $birthFamily, levels: severityLevels)
                            FunctionSeverityRow(label: "Friends", severity: $friends, levels: severityLevels)
                        }
                    }

                    // Work Section
                    SimpleCollapsibleSection(title: "Work", startExpanded: true) {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(workOptions, id: \.0) { (value, label) in
                                RadioButton(title: label, isSelected: workStatus == value) {
                                    workStatus = value
                                }
                            }
                        }
                    }

                    // Travel Section
                    SimpleCollapsibleSection(title: "Travel", startExpanded: true) {
                        VStack(alignment: .leading, spacing: 16) {
                            FunctionSeverityRow(label: "Trains", severity: $trains, levels: severityLevels)
                            FunctionSeverityRow(label: "Buses", severity: $buses, levels: severityLevels)
                            FunctionSeverityRow(label: "Cars", severity: $cars, levels: severityLevels)
                        }
                    }
                }
                .padding()
            }
        }
        .onAppear { loadState() }
        .onDisappear { saveState() }
    }

    private func loadState() {
        if let saved = appStore.loadPopupData(FunctionState.self, for: .function) {
            personalCare = saved.personalCare
            homeCare = saved.homeCare
            children = saved.children
            pets = saved.pets
            intimate = saved.intimate
            birthFamily = saved.birthFamily
            friends = saved.friends
            workStatus = saved.workStatus
            trains = saved.trains
            buses = saved.buses
            cars = saved.cars
        }
    }

    private func saveState() {
        var state = FunctionState()
        state.personalCare = personalCare
        state.homeCare = homeCare
        state.children = children
        state.pets = pets
        state.intimate = intimate
        state.birthFamily = birthFamily
        state.friends = friends
        state.workStatus = workStatus
        state.trains = trains
        state.buses = buses
        state.cars = cars
        appStore.savePopupData(state, for: .function)

        if !generatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            appStore.updateSection(.function, content: generatedText)
        }
    }

    private var generatedText: String {
        let p = sharedData.patientInfo.pronouns
        var lines: [String] = []

        // Helper to group items by severity
        func groupBySeverity(_ items: [(String, String)]) -> [(String, [String])] {
            let severityOrder = ["severe", "significant", "moderate", "mild", "slight"]
            var grouped: [String: [String]] = [:]
            for (key, sev) in items where !sev.isEmpty {
                grouped[sev, default: []].append(key)
            }
            return severityOrder.compactMap { sev in
                grouped[sev].map { (sev, $0) }
            }
        }

        // Helper to join items naturally
        func joinItems(_ items: [String]) -> String {
            if items.count == 1 { return items[0] }
            if items.count == 2 { return "\(items[0]) and \(items[1])" }
            return items.dropLast().joined(separator: ", ") + " and \(items.last!)"
        }

        // SELF CARE
        let selfCareItems = [
            ("personal care", personalCare),
            ("manage home care", homeCare),
            ("look after \(p.possessive) children", children),
            ("manage \(p.possessive) pets", pets)
        ].filter { !$0.1.isEmpty }

        let hasSelfCare = !selfCareItems.isEmpty

        if hasSelfCare {
            let grouped = groupBySeverity(selfCareItems)
            var parts: [String] = []

            for (sev, items) in grouped {
                if sev == "severe" || sev == "significant" {
                    let adverb = sev == "severe" ? "severely" : "significantly"
                    parts.append("\(adverb) affecting \(p.possessive) ability to \(joinItems(items))")
                } else {
                    parts.append("some \(sev) impact on \(joinItems(items))")
                }
            }

            if !parts.isEmpty {
                let sentence = "The illness affects \(p.possessive) self-care on several levels, " + parts.joined(separator: ". There is also ") + "."
                lines.append(sentence)
            }
        }

        // RELATIONSHIPS
        let relationshipItems = [
            ("\(p.possessive) intimate relationship", intimate),
            ("\(p.possessive) relations with \(p.possessive) family of origin", birthFamily),
            ("friendships", friends)
        ].filter { !$0.1.isEmpty }

        let hasRelationships = !relationshipItems.isEmpty

        if hasRelationships {
            let intro = hasSelfCare ? "The illness also has had an impact on" : "The illness has had an impact on"
            let grouped = groupBySeverity(relationshipItems)
            var parts: [String] = []

            for (sev, items) in grouped {
                parts.append("\(joinItems(items)) \(sev)ly affected")
            }

            if !parts.isEmpty {
                lines.append("\(intro) \(p.possessive) relationships with \(parts.joined(separator: ", ")).")
            }
        }

        // WORK
        let hasWork = !workStatus.isEmpty
        switch workStatus {
        case "none":
            lines.append("Currently \(p.Subject) \(p.bePresent) not working.")
        case "some":
            lines.append("Currently \(p.Subject) \(p.subject == "they" ? "work" : "works") only occasionally.")
        case "part_time":
            lines.append("Currently \(p.Subject) \(p.bePresent) working part time.")
        case "full_time":
            lines.append("Currently \(p.Subject) \(p.bePresent) working full time with no occupational impairment.")
        default:
            break
        }

        // TRAVEL
        let travelItems = [
            ("trains", trains),
            ("buses", buses),
            ("cars", cars)
        ].filter { !$0.1.isEmpty }

        if !travelItems.isEmpty {
            let hasOtherContent = hasSelfCare || hasRelationships || hasWork
            let intro = hasOtherContent ? "In addition, travel is affected" : "The illness affects \(p.possessive) ability to travel"
            let grouped = groupBySeverity(travelItems)

            if let (sev, modes) = grouped.first {
                var sentence = "\(intro) - \(p.Subject) cannot travel on \(joinItems(modes)) (\(sev))"

                let remaining = grouped.dropFirst()
                if !remaining.isEmpty {
                    let remainingParts = remaining.map { (s, m) in
                        "\(s) impact on \(p.possessive) ability to travel in \(joinItems(m))"
                    }
                    sentence += " with \(joinItems(remainingParts))"
                }

                sentence += "."
                lines.append(sentence)
            }
        }

        return lines.joined(separator: " ")
    }
}

// Helper component for function severity rows
struct FunctionSeverityRow: View {
    let label: String
    @Binding var severity: String
    let levels: [String]

    @State private var isEnabled: Bool = false
    @State private var sliderValue: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button(action: {
                    isEnabled.toggle()
                    if !isEnabled {
                        severity = ""
                        sliderValue = 0
                    } else {
                        sliderValue = 20
                        severity = "slight"
                    }
                }) {
                    HStack {
                        Image(systemName: isEnabled ? "checkmark.square.fill" : "square")
                            .foregroundColor(isEnabled ? .blue : .secondary)
                        Text(label)
                            .foregroundColor(.primary)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                if isEnabled && !severity.isEmpty {
                    Text(severity)
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(severityColor)
                        .clipShape(Capsule())
                }
            }

            if isEnabled {
                Slider(value: $sliderValue, in: 0...100, step: 20)
                    .onChange(of: sliderValue) { _, newValue in
                        severity = levelFromSlider(newValue)
                    }
            }
        }
        .onAppear {
            isEnabled = !severity.isEmpty
            sliderValue = sliderFromLevel(severity)
        }
    }

    private func levelFromSlider(_ value: Double) -> String {
        if value >= 80 { return "severe" }
        if value >= 60 { return "significant" }
        if value >= 40 { return "moderate" }
        if value >= 20 { return "mild" }
        return "slight"
    }

    private func sliderFromLevel(_ level: String) -> Double {
        switch level {
        case "severe": return 100
        case "significant": return 80
        case "moderate": return 60
        case "mild": return 40
        case "slight": return 20
        default: return 0
        }
    }

    private var severityColor: Color {
        switch severity {
        case "severe": return .red
        case "significant": return .orange
        case "moderate": return .yellow
        case "mild": return .green
        case "slight": return .blue
        default: return .gray
        }
    }
}

// MARK: - ICD-10 Diagnoses (common subset for mobile)
private let icd10Diagnoses: [(diagnosis: String, code: String, severity: Int)] = [
    // High severity (4) - Psychotic disorders
    ("Paranoid schizophrenia", "F20.0", 4),
    ("Hebephrenic schizophrenia", "F20.1", 4),
    ("Catatonic schizophrenia", "F20.2", 4),
    ("Undifferentiated schizophrenia", "F20.3", 4),
    ("Schizophrenia, unspecified", "F20.9", 4),
    ("Schizotypal disorder", "F21", 4),
    ("Delusional disorder", "F22.0", 4),
    ("Acute polymorphic psychotic disorder", "F23.0", 4),
    ("Acute schizophrenia-like psychotic disorder", "F23.2", 4),
    ("Schizoaffective disorder, manic type", "F25.0", 4),
    ("Schizoaffective disorder, depressive type", "F25.1", 4),
    ("Schizoaffective disorder, mixed type", "F25.2", 4),

    // High severity (4) - Bipolar and severe mood
    ("Bipolar affective disorder", "F31", 4),
    ("Bipolar affective disorder - manic with psychotic symptoms", "F31.2", 4),
    ("Bipolar affective disorder - severe depression with psychotic symptoms", "F31.5", 4),
    ("Mania with psychotic symptoms", "F30.2", 4),
    ("Severe depressive episode with psychotic symptoms", "F32.3", 4),
    ("Recurrent depressive disorder - severe with psychotic symptoms", "F33.3", 4),

    // Moderate severity (3) - Mood disorders
    ("Hypomania", "F30.0", 3),
    ("Mania without psychotic symptoms", "F30.1", 3),
    ("Mild depressive episode", "F32.0", 3),
    ("Moderate depressive episode", "F32.1", 3),
    ("Severe depressive episode without psychotic symptoms", "F32.2", 3),
    ("Recurrent depressive disorder - mild", "F33.0", 3),
    ("Recurrent depressive disorder - moderate", "F33.1", 3),
    ("Recurrent depressive disorder - severe without psychotic symptoms", "F33.2", 3),

    // Moderate severity (3) - Anxiety disorders
    ("Agoraphobia", "F40.0", 3),
    ("Social phobias", "F40.1", 3),
    ("Specific phobias", "F40.2", 3),
    ("Panic disorder", "F41.0", 3),
    ("Generalized anxiety disorder", "F41.1", 3),
    ("Mixed anxiety and depressive disorder", "F41.2", 3),
    ("Obsessive-compulsive disorder", "F42", 3),
    ("Post-traumatic stress disorder", "F43.1", 3),
    ("Adjustment disorders", "F43.2", 3),

    // Moderate severity (3) - Personality disorders
    ("Paranoid personality disorder", "F60.0", 3),
    ("Schizoid personality disorder", "F60.1", 3),
    ("Dissocial personality disorder", "F60.2", 3),
    ("Emotionally unstable personality disorder - Impulsive type", "F60.30", 3),
    ("Emotionally unstable personality disorder - Borderline type", "F60.31", 3),
    ("Histrionic personality disorder", "F60.4", 3),
    ("Anankastic personality disorder", "F60.5", 3),
    ("Anxious personality disorder", "F60.6", 3),

    // Moderate severity (3) - Eating disorders
    ("Anorexia nervosa", "F50.0", 3),
    ("Bulimia nervosa", "F50.2", 3),

    // Lower severity (2) - Substance use
    ("M&BD - alcohol dependence", "F10.2", 2),
    ("M&BD - alcohol harmful use", "F10.1", 2),
    ("M&BD - cannabis dependence", "F12.2", 2),
    ("M&BD - cannabis harmful use", "F12.1", 2),
    ("M&BD - opioid dependence", "F11.2", 2),
    ("M&BD - cocaine dependence", "F14.2", 2),
    ("M&BD - multiple drug dependence", "F19.2", 2),

    // Lower severity (2) - Persistent mood
    ("Cyclothymia", "F34.0", 2),
    ("Dysthymia", "F34.1", 2),

    // Dementia
    ("Dementia: Alzheimer's - early onset", "F00.0", 3),
    ("Dementia: Alzheimer's - late onset", "F00.1", 3),
    ("Vascular dementia", "F01", 3),

    // Other
    ("Autism spectrum disorder", "F84.0", 3),
    ("ADHD", "F90.0", 3),
]

// MARK: - Summary Popup (matches desktop ImpressionPopup)
struct SummaryPopupView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(SharedDataStore.self) private var sharedData
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDiagnosis1: String = ""
    @State private var selectedDiagnosis2: String = ""
    @State private var selectedDiagnosis3: String = ""
    @State private var searchText1: String = ""
    @State private var searchText2: String = ""
    @State private var searchText3: String = ""
    @State private var additionalDetails: String = ""

    var body: some View {
        VStack(spacing: 0) {
            PreviewPanelView(content: generatedText)

            ScrollView {
                VStack(spacing: 16) {
                    // ICD-10 Diagnoses Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Diagnoses (ICD-10)")
                            .font(.headline)
                            .padding(.horizontal)

                        DiagnosisPicker(
                            label: "Primary Diagnosis",
                            selection: $selectedDiagnosis1,
                            searchText: $searchText1
                        )

                        DiagnosisPicker(
                            label: "Secondary Diagnosis",
                            selection: $selectedDiagnosis2,
                            searchText: $searchText2
                        )

                        DiagnosisPicker(
                            label: "Tertiary Diagnosis",
                            selection: $selectedDiagnosis3,
                            searchText: $searchText3
                        )
                    }
                    .padding(.top)

                    // Additional Details
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Additional Details")
                            .font(.headline)
                            .padding(.horizontal)

                        TextEditor(text: $additionalDetails)
                            .frame(minHeight: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                            .padding(.horizontal)
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .onAppear { loadState() }
        .onDisappear { saveState() }
    }

    private func loadState() {
        if let saved = appStore.loadPopupData(SummaryState.self, for: .summary) {
            if saved.selectedDiagnoses.count > 0 { selectedDiagnosis1 = saved.selectedDiagnoses[0] }
            if saved.selectedDiagnoses.count > 1 { selectedDiagnosis2 = saved.selectedDiagnoses[1] }
            if saved.selectedDiagnoses.count > 2 { selectedDiagnosis3 = saved.selectedDiagnoses[2] }
            additionalDetails = saved.additionalDetails
        }
    }

    private func saveState() {
        var state = SummaryState()
        state.selectedDiagnoses = [selectedDiagnosis1, selectedDiagnosis2, selectedDiagnosis3].filter { !$0.isEmpty }
        state.additionalDetails = additionalDetails
        appStore.savePopupData(state, for: .summary)

        if !generatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            appStore.updateSection(.summary, content: generatedText)
        }
    }

    private var generatedText: String {
        let p = sharedData.patientInfo.pronouns
        let patient = sharedData.patientInfo

        // Get PC and MSE text from letter sections
        let pcText = appStore[.presentingComplaint]
        let mseText = appStore[.mentalStateExam]

        // Extract ethnicity from MSE
        let ethnicity = extractEthnicityFromMSE(mseText)

        // Parse PC for symptom categories, duration, and impact
        let pcSummary = parsePCForSummary(pcText)

        // Build patient description
        let name = patient.fullName
        let subject = name.isEmpty ? "The patient" : name

        let genderNoun: String
        switch patient.gender {
        case .male: genderNoun = "man"
        case .female: genderNoun = "woman"
        default: genderNoun = "person"
        }

        let possPronoun = p.possessive

        // Build opening with age, ethnicity, gender
        var opening: String
        let age = patient.age

        func articleFor(_ word: String) -> String {
            guard let first = word.first else { return "a" }
            return "aeiou".contains(first.lowercased()) ? "an" : "a"
        }

        if let age = age, !ethnicity.isEmpty {
            let article = articleFor(String(age))
            opening = "\(subject) is \(article) \(age) year old \(ethnicity) \(genderNoun)"
        } else if let age = age {
            let article = articleFor(String(age))
            opening = "\(subject) is \(article) \(age) year old \(genderNoun)"
        } else if !ethnicity.isEmpty {
            let article = articleFor(ethnicity)
            opening = "\(subject) is \(article) \(ethnicity) \(genderNoun)"
        } else {
            opening = "\(subject) is a \(genderNoun)"
        }

        var parts: [String] = []

        // Build symptom summary from PC
        if !pcSummary.categories.isEmpty {
            // Group categories by severity
            let severityOrder = ["significant", "severe", "moderate", "mild"]
            var grouped: [String: [String]] = [:]
            for (category, severity) in pcSummary.categories {
                grouped[severity, default: []].append(category)
            }

            // Build symptom phrases
            var symptomPhrases: [String] = []
            for sev in severityOrder {
                if let categories = grouped[sev], !categories.isEmpty {
                    if categories.count == 1 {
                        symptomPhrases.append("\(sev) \(categories[0]) symptoms")
                    } else if categories.count == 2 {
                        symptomPhrases.append("\(sev) \(categories[0]) and \(categories[1]) symptoms")
                    } else {
                        let joined = categories.dropLast().joined(separator: ", ") + " and \(categories.last!)"
                        symptomPhrases.append("\(sev) \(joined) symptoms")
                    }
                }
            }

            // Join symptom groups
            let symptomsText: String
            if symptomPhrases.count == 1 {
                symptomsText = symptomPhrases[0]
            } else if symptomPhrases.count == 2 {
                symptomsText = "\(symptomPhrases[0]), and \(symptomPhrases[1])"
            } else {
                symptomsText = symptomPhrases.dropLast().joined(separator: ", ") + ", and \(symptomPhrases.last!)"
            }

            // Add duration if present
            if !pcSummary.duration.isEmpty {
                parts.append("\(opening) who presented with \(symptomsText) over the last \(pcSummary.duration).")
            } else {
                parts.append("\(opening) who presented with \(symptomsText).")
            }
        } else {
            // No categories parsed, fall back to simpler opening
            parts.append("\(opening).")
        }

        // Add impact if present
        if !pcSummary.impact.isEmpty {
            parts.append("These symptoms impact \(possPronoun) \(pcSummary.impact).")
        }

        // Add diagnoses
        let diagnoses = [selectedDiagnosis1, selectedDiagnosis2, selectedDiagnosis3].filter { !$0.isEmpty }
        if !diagnoses.isEmpty {
            let dxWithCodes = diagnoses.compactMap { dx -> String? in
                if let match = icd10Diagnoses.first(where: { $0.diagnosis == dx }) {
                    return "\(match.diagnosis) (ICD-10 \(match.code))"
                }
                return dx
            }
            parts.append("Diagnoses under consideration include \(dxWithCodes.joined(separator: "; ")).")
        } else {
            parts.append("No formal ICD-10 diagnosis has been selected at this stage.")
        }

        // Add additional details
        if !additionalDetails.isEmpty {
            parts.append(additionalDetails)
        }

        return parts.joined(separator: " ")
    }

    // MARK: - PC/MSE Parsing Helpers

    private func extractEthnicityFromMSE(_ mseText: String) -> String {
        guard !mseText.isEmpty else { return "" }

        let text = mseText.lowercased()

        // Check for common ethnicities in the MSE text
        let ethnicities = [
            "Afro-Caribbean": ["afro-caribbean", "afro caribbean"],
            "Caucasian": ["caucasian"],
            "Asian": ["asian"],
            "South Asian": ["south asian"],
            "Black": ["black"],
            "African": ["african"],
            "Caribbean": ["caribbean"],
            "Mixed": ["mixed"],
            "White": ["white"],
            "Hispanic": ["hispanic"],
            "Chinese": ["chinese"],
            "Indian": ["indian"],
            "Pakistani": ["pakistani"],
            "Bangladeshi": ["bangladeshi"],
            "Arab": ["arab"],
        ]

        for (ethnicity, patterns) in ethnicities {
            for pattern in patterns {
                if text.contains(pattern) {
                    return ethnicity
                }
            }
        }
        return ""
    }

    private func parsePCForSummary(_ pcText: String) -> (categories: [(String, String)], duration: String, impact: String) {
        guard !pcText.isEmpty else { return ([], "", "") }

        var categories: [(String, String)] = []
        var duration = ""
        var impact = ""

        // Count symptoms to determine severity
        func severityForCount(_ count: Int) -> String {
            if count <= 2 { return "mild" }
            else if count <= 5 { return "moderate" }
            else { return "significant" }
        }

        // Category patterns: "X symptoms including A, B, C"
        let categoryPatterns: [(pattern: String, name: String)] = [
            ("depressive\\s+symptoms?\\s+including\\s+([^;.]+)", "depressive"),
            ("manic\\s+(?:features?|symptoms?)\\s+including\\s+([^;.]+)", "manic"),
            ("psychosis\\s+(?:features?|symptoms?)\\s+including\\s+([^;.]+)", "psychotic"),
            ("psychotic\\s+(?:features?|symptoms?)\\s+including\\s+([^;.]+)", "psychotic"),
            ("anxiety\\s+(?:features?|symptoms?)\\s+including\\s+([^;.]+)", "anxiety"),
        ]

        for (pattern, category) in categoryPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: pcText, range: NSRange(pcText.startIndex..., in: pcText)),
               let range = Range(match.range(at: 1), in: pcText) {
                let symptomsStr = String(pcText[range])
                    .replacingOccurrences(of: " and ", with: ", ", options: .caseInsensitive)
                let symptoms = symptomsStr.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                let severity = severityForCount(symptoms.count)
                categories.append((category, severity))
            }
        }

        // Extract duration
        let durationPattern = "(?:symptoms?\\s+(?:have\\s+)?been\\s+present\\s+for|over\\s+the\\s+last)\\s+(\\d+\\s+(?:days?|weeks?|months?|years?))"
        if let regex = try? NSRegularExpression(pattern: durationPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: pcText, range: NSRange(pcText.startIndex..., in: pcText)),
           let range = Range(match.range(at: 1), in: pcText) {
            duration = String(pcText[range])
        }

        // Extract impact
        let impactPattern = "(?:symptoms?\\s+)?impact\\s+(?:her|his|their)\\s+([^.]+)"
        if let regex = try? NSRegularExpression(pattern: impactPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: pcText, range: NSRange(pcText.startIndex..., in: pcText)),
           let range = Range(match.range(at: 1), in: pcText) {
            impact = String(pcText[range]).trimmingCharacters(in: .whitespaces)
        }

        return (categories, duration, impact)
    }
}

// MARK: - Diagnosis Picker
struct DiagnosisPicker: View {
    let label: String
    @Binding var selection: String
    @Binding var searchText: String
    @State private var isExpanded = false

    private var filteredDiagnoses: [(diagnosis: String, code: String, severity: Int)] {
        if searchText.isEmpty {
            return icd10Diagnoses.sorted { $0.severity > $1.severity }
        }
        return icd10Diagnoses.filter {
            $0.diagnosis.localizedCaseInsensitiveContains(searchText) ||
            $0.code.localizedCaseInsensitiveContains(searchText)
        }.sorted { $0.severity > $1.severity }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            Button {
                withAnimation { isExpanded.toggle() }
            } label: {
                HStack {
                    Text(selection.isEmpty ? "Not specified" : selection)
                        .foregroundColor(selection.isEmpty ? .secondary : .primary)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .padding(.horizontal)

            if isExpanded {
                VStack(spacing: 0) {
                    TextField("Search diagnoses...", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)
                        .padding(.vertical, 8)

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            // Clear option
                            Button {
                                selection = ""
                                searchText = ""
                                withAnimation { isExpanded = false }
                            } label: {
                                HStack {
                                    Text("Not specified")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    if selection.isEmpty {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.indigo)
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 10)
                                .background(selection.isEmpty ? Color.indigo.opacity(0.1) : Color.clear)
                            }
                            .buttonStyle(.plain)

                            Divider()

                            ForEach(filteredDiagnoses, id: \.diagnosis) { dx in
                                Button {
                                    selection = dx.diagnosis
                                    searchText = ""
                                    withAnimation { isExpanded = false }
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(dx.diagnosis)
                                                .foregroundColor(.primary)
                                                .lineLimit(2)
                                            Text(dx.code)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        if selection == dx.diagnosis {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.indigo)
                                        }
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                                    .background(selection == dx.diagnosis ? Color.indigo.opacity(0.1) : Color.clear)
                                }
                                .buttonStyle(.plain)

                                Divider()
                            }
                        }
                    }
                    .frame(maxHeight: 250)
                }
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Plan Popup (matches desktop PlanPopup)
struct PlanPopupView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(SharedDataStore.self) private var sharedData
    @Environment(\.dismiss) private var dismiss

    // Medication
    @State private var medicationAction: String? = nil
    @State private var newMedName: String = ""
    @State private var newMedDose: String = ""
    @State private var newMedFrequency: String = "OD"

    // Psychoeducation
    @State private var diagnosisDiscussed: Bool = false
    @State private var medicationDiscussed: Bool = false

    // Capacity
    @State private var capacityStatus: String? = nil
    @State private var capacityDomain: String = "medication"

    // Psychology
    @State private var psychologyStatus: String? = nil
    @State private var psychologyTherapy: String = "CBT"

    // OT
    @State private var otStatus: String? = nil

    // Care Coordination
    @State private var careStatus: String? = nil

    // Physical Health
    @State private var physicalHealthEnabled: Bool = false
    @State private var selectedTests: Set<String> = []

    // Next Appointment
    @State private var nextAppointmentDate: Date? = nil
    @State private var showDatePicker: Bool = false

    // Letter Signed By
    @State private var signatoryRole: String? = nil
    @State private var registrarGrade: String = "CT1"

    // Section expanded states
    @State private var medicationExpanded = false
    @State private var psychoeducationExpanded = false
    @State private var capacityExpanded = false
    @State private var psychologyExpanded = false
    @State private var otExpanded = false
    @State private var careExpanded = false
    @State private var physicalHealthExpanded = false
    @State private var appointmentExpanded = false
    @State private var signatoryExpanded = false

    private let medicationActions = ["Start", "Stop", "Increase", "Decrease"]
    private let capacityDomains = ["medication", "finances", "residence", "self-care"]
    private let therapyTypes = ["CBT", "Trauma-focussed", "DBT", "Psychodynamic", "Supportive"]
    private let otOptions = ["Continue with current occupational therapy", "OT assessment requested"]
    private let careOptions = ["Needs care coordinator - referral to be made", "Continue with care coordination and CPA process"]
    private let physicalHealthTests = ["Annual physical", "U&Es", "FBC", "LFTs", "TFTs", "PSA", "Haematinics", "ECG", "CXR"]
    private let signatoryRoles = ["Consultant Psychiatrist", "Specialty Doctor", "Registrar"]
    private let registrarGrades = ["CT1", "CT2", "CT3", "ST4", "ST5", "ST6"]
    private let frequencies = ["OD", "BD", "TDS", "QDS", "Nocte", "PRN", "Weekly", "Fortnightly", "Monthly"]

    var body: some View {
        VStack(spacing: 0) {
            PreviewPanelView(content: generatedText)

            ScrollView {
                VStack(spacing: 12) {
                    // Medication Section
                    PlanCollapsibleSection(title: "Medication", isExpanded: $medicationExpanded) {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(medicationActions, id: \.self) { action in
                                PlanRadioButton(
                                    title: action,
                                    isSelected: medicationAction == action.lowercased(),
                                    action: { medicationAction = action.lowercased() }
                                )
                            }

                            if medicationAction == "start" {
                                VStack(alignment: .leading, spacing: 12) {
                                    // Medication Name Picker
                                    PlanMedicationPicker(selection: $newMedName)

                                    // Dose Picker (populated based on medication)
                                    HStack {
                                        Text("Dose:")
                                            .foregroundColor(.secondary)
                                        PlanDosePicker(medicationName: newMedName, selection: $newMedDose)
                                    }

                                    // Frequency Picker
                                    HStack {
                                        Text("Frequency:")
                                            .foregroundColor(.secondary)
                                        Picker("", selection: $newMedFrequency) {
                                            ForEach(frequencies, id: \.self) { Text($0) }
                                        }
                                        .pickerStyle(.menu)
                                    }

                                    // BNF Max info
                                    if let info = commonPsychMedications[newMedName] {
                                        Text("BNF Max: \(info.bnfMax)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.leading, 24)
                                .padding(.top, 8)
                            }
                        }
                    }

                    // Psychoeducation Section
                    PlanCollapsibleSection(title: "Psychoeducation", isExpanded: $psychoeducationExpanded) {
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Diagnosis discussed with patient", isOn: $diagnosisDiscussed)
                            Toggle("Medication / side-effects discussed", isOn: $medicationDiscussed)
                        }
                    }

                    // Capacity Section
                    PlanCollapsibleSection(title: "Capacity", isExpanded: $capacityExpanded) {
                        VStack(alignment: .leading, spacing: 12) {
                            PlanRadioButton(
                                title: "Has capacity",
                                isSelected: capacityStatus == "has",
                                action: { capacityStatus = "has" }
                            )
                            PlanRadioButton(
                                title: "Lacks capacity",
                                isSelected: capacityStatus == "lacks",
                                action: { capacityStatus = "lacks" }
                            )

                            if capacityStatus != nil {
                                Picker("Domain", selection: $capacityDomain) {
                                    ForEach(capacityDomains, id: \.self) { Text($0) }
                                }
                                .pickerStyle(.menu)
                            }
                        }
                    }

                    // Psychology Section
                    PlanCollapsibleSection(title: "Psychology", isExpanded: $psychologyExpanded) {
                        VStack(alignment: .leading, spacing: 12) {
                            PlanRadioButton(
                                title: "Continue",
                                isSelected: psychologyStatus == "continue",
                                action: { psychologyStatus = "continue" }
                            )
                            PlanRadioButton(
                                title: "Start",
                                isSelected: psychologyStatus == "start",
                                action: { psychologyStatus = "start" }
                            )
                            PlanRadioButton(
                                title: "Refused",
                                isSelected: psychologyStatus == "refused",
                                action: { psychologyStatus = "refused" }
                            )

                            if psychologyStatus != nil {
                                Picker("Therapy", selection: $psychologyTherapy) {
                                    ForEach(therapyTypes, id: \.self) { Text($0) }
                                }
                                .pickerStyle(.menu)
                            }
                        }
                    }

                    // Occupational Therapy Section
                    PlanCollapsibleSection(title: "Occupational Therapy", isExpanded: $otExpanded) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(otOptions, id: \.self) { option in
                                PlanRadioButton(
                                    title: option,
                                    isSelected: otStatus == option,
                                    action: { otStatus = option }
                                )
                            }
                        }
                    }

                    // Care Coordination Section
                    PlanCollapsibleSection(title: "Care Coordination", isExpanded: $careExpanded) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(careOptions, id: \.self) { option in
                                PlanRadioButton(
                                    title: option,
                                    isSelected: careStatus == option,
                                    action: { careStatus = option }
                                )
                            }
                        }
                    }

                    // Physical Health Section
                    PlanCollapsibleSection(title: "Physical Health", isExpanded: $physicalHealthExpanded) {
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Please can you arrange", isOn: $physicalHealthEnabled)
                                .onChange(of: physicalHealthEnabled) { _, newValue in
                                    if !newValue { selectedTests.removeAll() }
                                }

                            if physicalHealthEnabled {
                                ForEach(physicalHealthTests, id: \.self) { test in
                                    HStack {
                                        Image(systemName: selectedTests.contains(test) ? "checkmark.square.fill" : "square")
                                            .foregroundColor(selectedTests.contains(test) ? .indigo : .secondary)
                                        Text(test)
                                    }
                                    .onTapGesture {
                                        if selectedTests.contains(test) {
                                            selectedTests.remove(test)
                                        } else {
                                            selectedTests.insert(test)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Next Appointment Section
                    PlanCollapsibleSection(title: "Next Appointment", isExpanded: $appointmentExpanded) {
                        VStack(alignment: .leading, spacing: 8) {
                            if let date = nextAppointmentDate {
                                Text("Selected: \(date.formatted(date: .long, time: .omitted))")
                            }
                            DatePicker(
                                "Select date",
                                selection: Binding(
                                    get: { nextAppointmentDate ?? Date() },
                                    set: { nextAppointmentDate = $0 }
                                ),
                                in: Date()...,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.compact)
                        }
                    }

                    // Letter Signed By Section
                    PlanCollapsibleSection(title: "Letter Signed By", isExpanded: $signatoryExpanded) {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(signatoryRoles, id: \.self) { role in
                                PlanRadioButton(
                                    title: role,
                                    isSelected: signatoryRole == role,
                                    action: { signatoryRole = role }
                                )
                            }

                            if signatoryRole == "Registrar" {
                                Picker("Grade", selection: $registrarGrade) {
                                    ForEach(registrarGrades, id: \.self) { Text($0) }
                                }
                                .pickerStyle(.menu)
                            }
                        }
                    }
                }
                .padding()
                .padding(.bottom, 20)
            }
        }
        .onAppear { loadState() }
        .onDisappear { saveState() }
    }

    private func loadState() {
        if let saved = appStore.loadPopupData(PlanState.self, for: .plan) {
            medicationAction = saved.medicationAction
            newMedName = saved.newMedName
            newMedDose = saved.newMedDose
            newMedFrequency = saved.newMedFrequency
            diagnosisDiscussed = saved.diagnosisDiscussed
            medicationDiscussed = saved.medicationDiscussed
            capacityStatus = saved.capacityStatus
            capacityDomain = saved.capacityDomain
            psychologyStatus = saved.psychologyStatus
            psychologyTherapy = saved.psychologyTherapy
            otStatus = saved.otStatus
            careStatus = saved.careStatus
            physicalHealthEnabled = saved.physicalHealthEnabled
            selectedTests = Set(saved.physicalHealthTests)
            nextAppointmentDate = saved.nextAppointmentDate
            signatoryRole = saved.signatoryRole
            registrarGrade = saved.registrarGrade ?? "CT1"
        }
    }

    private func saveState() {
        var state = PlanState()
        state.medicationAction = medicationAction
        state.newMedName = newMedName
        state.newMedDose = newMedDose
        state.newMedFrequency = newMedFrequency
        state.diagnosisDiscussed = diagnosisDiscussed
        state.medicationDiscussed = medicationDiscussed
        state.capacityStatus = capacityStatus
        state.capacityDomain = capacityDomain
        state.psychologyStatus = psychologyStatus
        state.psychologyTherapy = psychologyTherapy
        state.otStatus = otStatus
        state.careStatus = careStatus
        state.physicalHealthEnabled = physicalHealthEnabled
        state.physicalHealthTests = Array(selectedTests)
        state.nextAppointmentDate = nextAppointmentDate
        state.signatoryRole = signatoryRole
        state.registrarGrade = registrarGrade
        appStore.savePopupData(state, for: .plan)

        if !generatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            appStore.updateSection(.plan, content: generatedText)
        }
    }

    private var generatedText: String {
        let p = sharedData.patientInfo.pronouns
        var blocks: [String] = []

        // Medication
        if let action = medicationAction {
            if action == "start" && !newMedName.isEmpty {
                var medStr = newMedName.capitalized
                if !newMedDose.isEmpty { medStr += " \(newMedDose)" }
                medStr += " \(newMedFrequency)"
                blocks.append("**I recommend starting \(medStr) - please can you prescribe.**")
            }
        }

        // Psychoeducation
        if diagnosisDiscussed {
            let name = sharedData.patientInfo.fullName
            let patientRef = name.isEmpty ? "the patient" : name
            blocks.append("The diagnosis was discussed with \(patientRef).")
        }
        if medicationDiscussed {
            let wasWere = p.subject == "they" ? "were" : "was"
            blocks.append("\(p.Subject) \(wasWere) advised about medication, specifically the purpose and effects as well as side-effects.")
        }

        // Capacity
        if let status = capacityStatus {
            let verb = status == "has" ? "have" : "lack"
            blocks.append("Capacity assessment (understands information, retains it, weighs up pros and cons, and can communicate wishes) was carried out for \(capacityDomain) and \(p.subject) \(p.subject == "they" ? "are" : "is") noted to \(verb) capacity.")
        }

        // Psychology
        if let status = psychologyStatus {
            let verb: String
            switch status {
            case "continue": verb = "will continue"
            case "start": verb = "will start"
            case "refused": verb = "refused"
            default: verb = status
            }
            blocks.append("We discussed psychology and \(p.subject) \(verb) \(psychologyTherapy) therapy.")
        }

        // OT
        if let ot = otStatus {
            blocks.append("Occupational Therapy: \(ot).")
        }

        // Care Coordination
        if let care = careStatus {
            blocks.append("Care Coordination: \(care).")
        }

        // Physical Health
        if physicalHealthEnabled {
            if selectedTests.isEmpty {
                blocks.append("\n**Physical health: Please can you arrange appropriate investigations.**")
            } else {
                blocks.append("\n**Physical health: Please can you arrange \(selectedTests.sorted().joined(separator: ", ")).**")
            }
        }

        // Next Appointment
        if let date = nextAppointmentDate {
            blocks.append("Next appointment arranged for \(date.formatted(date: .long, time: .omitted)).")
        }

        // Letter Signed By
        if let role = signatoryRole {
            var sigParts = ["Letter signed by:"]
            if role == "Registrar", !registrarGrade.isEmpty {
                sigParts.append("Registrar (\(registrarGrade))")
            } else {
                sigParts.append(role)
            }
            blocks.append(sigParts.joined(separator: "\n"))
        }

        return blocks.joined(separator: " ")
    }
}

// MARK: - Plan Collapsible Section
struct PlanCollapsibleSection<Content: View>: View {
    let title: String
    @Binding var isExpanded: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            if isExpanded {
                content()
                    .padding(.leading, 20)
                    .padding(.vertical, 8)
            }
        }
    }
}

// MARK: - Plan Radio Button
struct PlanRadioButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(isSelected ? .indigo : .secondary)
                Text(title)
                    .foregroundColor(.primary)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Plan Medication Picker
struct PlanMedicationPicker: View {
    @Binding var selection: String
    @State private var isExpanded = false
    @State private var searchText = ""

    private var filteredMeds: [String] {
        let allMeds = commonPsychMedications.keys.sorted()
        if searchText.isEmpty {
            return Array(allMeds.prefix(25))
        }
        return allMeds.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Medication:")
                .foregroundColor(.secondary)

            Button {
                withAnimation { isExpanded.toggle() }
            } label: {
                HStack {
                    Text(selection.isEmpty ? "Select medication" : selection)
                        .foregroundColor(selection.isEmpty ? .secondary : .primary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 0) {
                    TextField("Search medications...", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .padding(8)

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredMeds, id: \.self) { med in
                                Button {
                                    selection = med
                                    searchText = ""
                                    withAnimation { isExpanded = false }
                                } label: {
                                    HStack {
                                        Text(med)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        if selection == med {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.indigo)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(selection == med ? Color.indigo.opacity(0.1) : Color.clear)
                                }
                                .buttonStyle(.plain)
                                Divider()
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            }
        }
    }
}

// MARK: - Plan Dose Picker
struct PlanDosePicker: View {
    let medicationName: String
    @Binding var selection: String

    private var doses: [String] {
        guard let info = commonPsychMedications[medicationName] else {
            return []
        }
        return info.doses.map { "\($0)mg" }
    }

    var body: some View {
        Picker("", selection: $selection) {
            Text("Select dose").tag("")
            ForEach(doses, id: \.self) { dose in
                Text(dose).tag(dose)
            }
        }
        .pickerStyle(.menu)
        .onChange(of: medicationName) { _, _ in
            // Reset dose when medication changes if current dose not valid
            if !doses.contains(selection) && !doses.isEmpty {
                selection = doses.first ?? ""
            }
        }
    }
}

// MARK: - Common Psychiatric Medications (shared with Front Page)
// Note: commonPsychMedications is defined in SectionPopupView.swift

// MARK: - Simple Collapsible Section
struct SimpleCollapsibleSection<Content: View>: View {
    let title: String
    let startExpanded: Bool
    @ViewBuilder let content: () -> Content

    @State private var isExpanded: Bool = false

    init(title: String, startExpanded: Bool = false, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.startExpanded = startExpanded
        self.content = content
        self._isExpanded = State(initialValue: startExpanded)
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            Divider()

            if isExpanded {
                content()
                    .padding(.leading, 8)
                    .padding(.vertical, 8)
            }
        }
        .padding(.horizontal)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
}

#Preview("History of PC") {
    NavigationStack {
        HistoryOfPresentingComplaintPopupView()
            .environment(AppStore())
            .environment(SharedDataStore.shared)
    }
}

#Preview("Psychiatric History") {
    NavigationStack {
        PsychiatricHistoryPopupView()
            .environment(AppStore())
            .environment(SharedDataStore.shared)
    }
}
