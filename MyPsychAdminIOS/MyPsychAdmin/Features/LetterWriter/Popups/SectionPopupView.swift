//
//  SectionPopupView.swift
//  MyPsychAdmin
//
//  Base popup view that routes to section-specific editors
//

import SwiftUI

struct SectionPopupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var appStore
    let sectionType: SectionType

    var body: some View {
        NavigationStack {
            Group {
                switch sectionType {
                case .front:
                    FrontPagePopupView()
                case .presentingComplaint:
                    PresentingComplaintPopupView()
                case .historyOfPresentingComplaint:
                    HistoryOfPresentingComplaintPopupView()
                case .affect:
                    AffectPopupView()
                case .anxiety:
                    AnxietyPopupView()
                case .psychosis:
                    PsychosisPopupView()
                case .psychiatricHistory:
                    PsychiatricHistoryPopupView()
                case .backgroundHistory:
                    BackgroundHistoryPopupView()
                case .drugsAlcohol:
                    DrugAlcoholPopupView()
                case .socialHistory:
                    SocialHistoryPopupView()
                case .forensicHistory:
                    ForensicHistoryPopupView()
                case .physicalHealth:
                    PhysicalHealthPopupView()
                case .function:
                    FunctionPopupView()
                case .mentalStateExam:
                    MentalStateExamPopupView()
                case .summary:
                    SummaryPopupView()
                case .plan:
                    PlanPopupView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGray6))
            .navigationTitle(sectionType.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Front Page Popup (matches desktop)
struct FrontPagePopupView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(SharedDataStore.self) private var sharedData
    @Environment(\.dismiss) private var dismiss

    @State private var patientName = ""
    @State private var dateOfBirth = Calendar.current.date(byAdding: .year, value: -18, to: Date())!
    @State private var hasDOB = false
    @State private var nhsNumber = ""
    @State private var gender: Gender = .notSpecified
    @State private var clinician = ""
    @State private var dateOfLetter = Date()
    @State private var medications: [MedicationEntry] = []

    // Track medication changes to force preview update
    private var medicationsHash: Int {
        medications.map { "\($0.name)\($0.dose)\($0.frequency)" }.joined().hashValue
    }

    var body: some View {
        VStack(spacing: 0) {
            PreviewPanelView(content: generatedText)
                .id(medicationsHash) // Force re-render when medications change

            Form {
                Section("Patient Details") {
                    TextField("Patient Name", text: $patientName)

                    Toggle("Include Date of Birth", isOn: $hasDOB)
                    if hasDOB {
                        DatePicker("DOB", selection: $dateOfBirth, in: minDOBDate...maxDOBDate, displayedComponents: .date)
                        HStack {
                            Text("Age")
                            Spacer()
                            Text("\(calculatedAge) years")
                                .foregroundColor(.secondary)
                        }
                    }

                    TextField("NHS Number", text: $nhsNumber)
                        .keyboardType(.numberPad)

                    Picker("Gender", selection: $gender) {
                        ForEach(Gender.allCases) { g in
                            Text(g.rawValue).tag(g)
                        }
                    }
                }

                Section("Letter Details") {
                    TextField("Clinician", text: $clinician)
                    DatePicker("Date of Letter", selection: $dateOfLetter, in: ...Date(), displayedComponents: .date)
                }

                Section("Current Medications") {
                    ForEach(medications.indices, id: \.self) { index in
                        MedicationRowView(
                            medication: $medications[index],
                            onDelete: { medications.remove(at: index) }
                        )
                    }

                    Button {
                        medications.append(MedicationEntry())
                    } label: {
                        Label("Add Medication", systemImage: "plus.circle.fill")
                    }
                }
            }
        }
        .onAppear {
            loadFromSharedData()
        }
        .onDisappear {
            if !generatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                appStore.updateSection(.front, content: generatedText)
                updateSharedData()
            }
        }
    }

    private var calculatedAge: Int {
        Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 0
    }

    private var minDOBDate: Date {
        Calendar.current.date(byAdding: .year, value: -100, to: Date()) ?? Date()
    }

    private var maxDOBDate: Date {
        Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    }

    private var generatedText: String {
        var lines: [String] = []

        if !patientName.isEmpty {
            lines.append("Patient: \(patientName)")
        }

        if hasDOB {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd/MM/yyyy"
            lines.append("DOB: \(formatter.string(from: dateOfBirth))")
        }

        if gender != .notSpecified {
            lines.append("Gender: \(gender.rawValue)")
        }

        if !nhsNumber.isEmpty {
            lines.append("NHS Number: \(nhsNumber)")
        }

        if !clinician.isEmpty {
            lines.append("Clinician: \(clinician)")
        }

        let letterFormatter = DateFormatter()
        letterFormatter.dateFormat = "dd MMMM yyyy"
        lines.append("Date of Letter: \(letterFormatter.string(from: dateOfLetter))")

        // Medications
        let medsText = medications.compactMap { med -> String? in
            guard !med.name.isEmpty else { return nil }
            var str = med.name
            if !med.dose.isEmpty { str += ": \(med.dose)" }
            if !med.frequency.isEmpty { str += " \(med.frequency)" }
            return str
        }

        if !medsText.isEmpty {
            lines.append("\nMedications:")
            lines.append(contentsOf: medsText)
        }

        return lines.joined(separator: "\n")
    }

    private func loadFromSharedData() {
        let info = sharedData.patientInfo
        patientName = info.fullName
        if let dob = info.dateOfBirth {
            dateOfBirth = dob
            hasDOB = true
        }
        nhsNumber = info.nhsNumber
        gender = info.gender

        // Load saved front page state
        if let saved = appStore.loadPopupData(FrontPageState.self, for: .front) {
            clinician = saved.clinician
            if let letterDate = saved.dateOfLetter {
                dateOfLetter = letterDate
            }
            medications = saved.medications
        }

        // Prefill clinician from My Details if still empty
        if clinician.isEmpty && !appStore.clinicianInfo.fullName.isEmpty {
            clinician = appStore.clinicianInfo.fullName
        }
    }

    private func updateSharedData() {
        // Parse patient name
        let parts = patientName.split(separator: " ")
        let firstName = parts.first.map(String.init) ?? ""
        let lastName = parts.dropFirst().joined(separator: " ")

        var info = PatientInfo()
        info.firstName = firstName
        info.lastName = lastName
        info.dateOfBirth = hasDOB ? dateOfBirth : nil
        info.nhsNumber = nhsNumber
        info.gender = gender
        sharedData.setPatientInfo(info, source: "front_page_popup")

        // Save front page specific state
        let state = FrontPageState(
            clinician: clinician,
            dateOfLetter: dateOfLetter,
            medications: medications
        )
        appStore.savePopupData(state, for: .front)
    }
}

// MARK: - Front Page State
struct FrontPageState: Codable {
    var clinician: String = ""
    var dateOfLetter: Date? = nil
    var medications: [MedicationEntry] = []
}

// MARK: - Medication Entry
struct MedicationEntry: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String = ""
    var dose: String = ""
    var frequency: String = "OD"
}

// MARK: - Medication Row View
struct MedicationRowView: View {
    @Binding var medication: MedicationEntry
    let onDelete: () -> Void

    private let frequencies = ["OD", "BD", "TDS", "QDS", "Nocte", "PRN", "Weekly", "Fortnightly", "Monthly"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                MedicationSearchField(selection: $medication.name)
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }

            HStack {
                // Dose picker - populated based on medication
                MedicationDosePicker(
                    medicationName: medication.name,
                    selection: $medication.dose
                )

                Picker("Freq", selection: $medication.frequency) {
                    ForEach(frequencies, id: \.self) { Text($0) }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 120)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Medication Search Field
struct MedicationSearchField: View {
    @Binding var selection: String
    @State private var isExpanded = false
    @State private var searchText = ""

    private var filteredMeds: [String] {
        if searchText.isEmpty {
            return commonPsychMedications.keys.sorted()
        }
        return commonPsychMedications.keys.filter {
            $0.localizedCaseInsensitiveContains(searchText)
        }.sorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                isExpanded.toggle()
            } label: {
                HStack {
                    Text(selection.isEmpty ? "Select medication" : selection)
                        .foregroundColor(selection.isEmpty ? .secondary : .primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 0) {
                    TextField("Search...", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .padding(.vertical, 4)

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredMeds, id: \.self) { med in
                                Button {
                                    selection = med
                                    searchText = ""
                                    isExpanded = false
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
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 4)
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
                .shadow(radius: 2)
            }
        }
    }
}

// MARK: - Medication Dose Picker
struct MedicationDosePicker: View {
    let medicationName: String
    @Binding var selection: String

    private var doses: [String] {
        guard let info = commonPsychMedications[medicationName] else {
            return [""]
        }
        return info.doses.map { "\($0)mg" }
    }

    var body: some View {
        Picker("Dose", selection: $selection) {
            Text("Dose").tag("")
            ForEach(doses, id: \.self) { Text($0) }
        }
        .pickerStyle(.menu)
        .onChange(of: medicationName) { _, _ in
            // Reset dose when medication changes
            if !doses.contains(selection) {
                selection = doses.first ?? ""
            }
        }
    }
}

// MARK: - Common Psychiatric Medications Database
struct MedicationInfo {
    let doses: [Int]
    let bnfMax: String
}

let commonPsychMedications: [String: MedicationInfo] = [
    // ==================== ANTIPSYCHOTICS - ATYPICAL (ORAL) ====================
    "Olanzapine": MedicationInfo(doses: [2, 5, 7, 10, 15, 20], bnfMax: "20mg/day"),
    "Quetiapine": MedicationInfo(doses: [25, 50, 75, 100, 125, 150, 175, 200, 225, 250, 300, 350, 400, 450, 500, 550, 600, 700, 800], bnfMax: "800mg/day"),
    "Risperidone": MedicationInfo(doses: [0, 1, 2, 3, 4, 6], bnfMax: "16mg/day"),
    "Aripiprazole": MedicationInfo(doses: [2, 5, 10, 15, 20, 30], bnfMax: "30mg/day"),
    "Clozapine": MedicationInfo(doses: [12, 25, 50, 75, 100, 125, 150, 175, 200, 225, 250, 275, 300, 325, 350, 375, 400, 425, 450, 500, 550, 600, 650, 700, 750, 800, 850, 900], bnfMax: "900mg/day"),
    "Amisulpride": MedicationInfo(doses: [50, 100, 200, 400, 600, 800, 1000, 1200], bnfMax: "1200mg/day"),
    "Paliperidone": MedicationInfo(doses: [3, 6, 9, 12], bnfMax: "12mg/day"),
    "Lurasidone": MedicationInfo(doses: [18, 37, 74, 111, 148], bnfMax: "148mg/day"),

    // ==================== ANTIPSYCHOTICS - ATYPICAL (DEPOT) ====================
    "Olanzapine Depot": MedicationInfo(doses: [210, 300, 405], bnfMax: "405mg/2-4wk"),
    "Aripiprazole Depot": MedicationInfo(doses: [300, 400], bnfMax: "400mg/month"),
    "Paliperidone Depot (Xeplion)": MedicationInfo(doses: [25, 50, 75, 100, 150], bnfMax: "150mg/month"),
    "Paliperidone Depot (Trevicta)": MedicationInfo(doses: [175, 263, 350, 525], bnfMax: "525mg/3months"),
    "Risperidone Depot": MedicationInfo(doses: [25, 37, 50], bnfMax: "50mg/2wk"),

    // ==================== ANTIPSYCHOTICS - TYPICAL (ORAL) ====================
    "Haloperidol": MedicationInfo(doses: [0, 1, 2, 3, 5, 10, 20], bnfMax: "30mg/day"),
    "Chlorpromazine": MedicationInfo(doses: [10, 25, 50, 100, 200, 300], bnfMax: "1000mg/day"),
    "Sulpiride": MedicationInfo(doses: [50, 100, 200, 400, 800, 1200, 1600, 2400], bnfMax: "2400mg/day"),
    "Trifluoperazine": MedicationInfo(doses: [1, 2, 5, 10, 15], bnfMax: "30mg/day"),
    "Flupentixol": MedicationInfo(doses: [0, 1, 3, 6, 9, 12, 18], bnfMax: "18mg/day"),
    "Zuclopenthixol": MedicationInfo(doses: [2, 10, 25, 50, 75, 100, 150], bnfMax: "150mg/day"),

    // ==================== ANTIPSYCHOTICS - TYPICAL (DEPOT) ====================
    "Haloperidol Depot": MedicationInfo(doses: [50, 100, 150, 200, 250, 300], bnfMax: "300mg/4wk"),
    "Flupentixol Depot": MedicationInfo(doses: [20, 40, 100, 200, 400], bnfMax: "400mg/wk"),
    "Zuclopenthixol Depot": MedicationInfo(doses: [100, 200, 400, 500, 600], bnfMax: "600mg/wk"),

    // ==================== ANTIDEPRESSANTS - SSRIs ====================
    "Sertraline": MedicationInfo(doses: [25, 50, 75, 100, 125, 150, 175, 200], bnfMax: "200mg/day"),
    "Fluoxetine": MedicationInfo(doses: [10, 20, 40, 60, 80], bnfMax: "80mg/day"),
    "Citalopram": MedicationInfo(doses: [10, 20, 40], bnfMax: "40mg/day"),
    "Escitalopram": MedicationInfo(doses: [5, 10, 15, 20], bnfMax: "20mg/day"),
    "Paroxetine": MedicationInfo(doses: [10, 20, 30, 40, 50, 60], bnfMax: "60mg/day"),
    "Fluvoxamine": MedicationInfo(doses: [50, 100, 150, 200, 250, 300], bnfMax: "300mg/day"),

    // ==================== ANTIDEPRESSANTS - SNRIs ====================
    "Venlafaxine": MedicationInfo(doses: [37, 75, 150, 225, 300, 375], bnfMax: "375mg/day"),
    "Duloxetine": MedicationInfo(doses: [20, 30, 40, 60, 90, 120], bnfMax: "120mg/day"),

    // ==================== ANTIDEPRESSANTS - TCAs ====================
    "Amitriptyline": MedicationInfo(doses: [10, 25, 50, 75, 100, 150, 200], bnfMax: "200mg/day"),
    "Nortriptyline": MedicationInfo(doses: [10, 25, 50, 75, 100, 150], bnfMax: "150mg/day"),
    "Clomipramine": MedicationInfo(doses: [10, 25, 50, 75, 100, 150, 200, 250], bnfMax: "250mg/day"),
    "Imipramine": MedicationInfo(doses: [10, 25, 50, 75, 100, 150, 200, 300], bnfMax: "300mg/day"),
    "Dosulepin": MedicationInfo(doses: [25, 50, 75, 150, 225], bnfMax: "225mg/day"),
    "Lofepramine": MedicationInfo(doses: [70, 140, 210], bnfMax: "210mg/day"),

    // ==================== ANTIDEPRESSANTS - OTHER ====================
    "Mirtazapine": MedicationInfo(doses: [15, 30, 45], bnfMax: "45mg/day"),
    "Trazodone": MedicationInfo(doses: [50, 100, 150, 200, 300, 400, 600], bnfMax: "600mg/day"),
    "Bupropion": MedicationInfo(doses: [150, 300, 450], bnfMax: "450mg/day"),
    "Vortioxetine": MedicationInfo(doses: [5, 10, 15, 20], bnfMax: "20mg/day"),
    "Agomelatine": MedicationInfo(doses: [25, 50], bnfMax: "50mg/day"),

    // ==================== MOOD STABILISERS ====================
    "Lithium": MedicationInfo(doses: [200, 250, 400, 450, 500, 520, 600, 800, 1000, 1200], bnfMax: "per level"),
    "Valproate": MedicationInfo(doses: [100, 150, 200, 250, 300, 400, 500, 600, 700, 750, 800, 900, 1000, 1100, 1200, 1250, 1500, 1750, 2000, 2500], bnfMax: "2500mg/day"),
    "Carbamazepine": MedicationInfo(doses: [100, 200, 400, 600, 800, 1000, 1200, 1600], bnfMax: "1600mg/day"),
    "Lamotrigine": MedicationInfo(doses: [2, 5, 25, 50, 100, 150, 200, 300, 400], bnfMax: "400mg/day"),

    // ==================== BENZODIAZEPINES ====================
    "Diazepam": MedicationInfo(doses: [2, 5, 10, 15, 20, 30], bnfMax: "30mg/day"),
    "Lorazepam": MedicationInfo(doses: [0, 1, 2, 4], bnfMax: "10mg/day"),
    "Clonazepam": MedicationInfo(doses: [0, 1, 2, 4, 6, 8], bnfMax: "8mg/day"),
    "Alprazolam": MedicationInfo(doses: [0, 1, 2, 4, 6], bnfMax: "6mg/day"),
    "Temazepam": MedicationInfo(doses: [10, 20, 30, 40], bnfMax: "40mg/day"),
    "Nitrazepam": MedicationInfo(doses: [5, 10], bnfMax: "10mg/day"),
    "Oxazepam": MedicationInfo(doses: [10, 15, 30, 60, 90, 120], bnfMax: "120mg/day"),
    "Chlordiazepoxide": MedicationInfo(doses: [5, 10, 25, 50, 100], bnfMax: "100mg/day"),
    "Midazolam": MedicationInfo(doses: [7, 10, 15], bnfMax: "15mg/day"),
    "Clobazam": MedicationInfo(doses: [10, 20, 30, 40, 60], bnfMax: "60mg/day"),

    // ==================== HYPNOTICS (Z-DRUGS) ====================
    "Zopiclone": MedicationInfo(doses: [3, 7, 15], bnfMax: "15mg/day"),
    "Zolpidem": MedicationInfo(doses: [5, 10], bnfMax: "10mg/day"),

    // ==================== OTHER HYPNOTICS/ANXIOLYTICS ====================
    "Promethazine": MedicationInfo(doses: [10, 25, 50, 75, 100], bnfMax: "100mg/day"),
    "Melatonin": MedicationInfo(doses: [1, 2, 3, 5, 10], bnfMax: "10mg"),
    "Hydroxyzine": MedicationInfo(doses: [10, 25, 50, 75, 100], bnfMax: "100mg/day"),
    "Buspirone": MedicationInfo(doses: [5, 10, 15, 20, 30, 45], bnfMax: "45mg/day"),

    // ==================== ANTICHOLINERGICS ====================
    "Procyclidine": MedicationInfo(doses: [2, 5, 10, 15, 20, 30], bnfMax: "30mg/day"),
    "Trihexyphenidyl": MedicationInfo(doses: [2, 5, 10, 15, 20], bnfMax: "20mg/day"),
    "Benztropine": MedicationInfo(doses: [1, 2, 4, 6], bnfMax: "6mg/day"),
    "Orphenadrine": MedicationInfo(doses: [50, 100, 150, 200, 300, 400], bnfMax: "400mg/day"),

    // ==================== ADHD MEDICATIONS ====================
    "Methylphenidate": MedicationInfo(doses: [5, 10, 18, 20, 27, 36, 54, 72, 100], bnfMax: "100mg/day"),
    "Lisdexamfetamine": MedicationInfo(doses: [20, 30, 40, 50, 60, 70], bnfMax: "70mg/day"),
    "Atomoxetine": MedicationInfo(doses: [10, 18, 25, 40, 60, 80, 100, 120], bnfMax: "120mg/day"),
    "Dexamfetamine": MedicationInfo(doses: [5, 10, 15, 20, 30, 40, 60], bnfMax: "60mg/day"),
    "Guanfacine": MedicationInfo(doses: [1, 2, 3, 4], bnfMax: "4mg/day"),

    // ==================== OTHER PSYCHIATRIC ====================
    "Propranolol": MedicationInfo(doses: [10, 20, 40, 80, 160, 320], bnfMax: "320mg/day"),
    "Clonidine": MedicationInfo(doses: [25, 50, 75, 100, 150, 200], bnfMax: "mcg - varies"),
    "Pregabalin": MedicationInfo(doses: [25, 50, 75, 100, 150, 200, 300, 450, 600], bnfMax: "600mg/day"),
    "Gabapentin": MedicationInfo(doses: [100, 200, 300, 400, 600, 800, 1200, 1800, 2400, 3600], bnfMax: "3600mg/day"),
    "Topiramate": MedicationInfo(doses: [25, 50, 100, 200, 400], bnfMax: "400mg/day"),
    "Naltrexone": MedicationInfo(doses: [25, 50], bnfMax: "50mg/day"),
    "Acamprosate": MedicationInfo(doses: [333, 666, 999, 1332, 1998], bnfMax: "1998mg/day"),
    "Disulfiram": MedicationInfo(doses: [100, 200, 400, 500], bnfMax: "500mg/day"),
]

// MARK: - Presenting Complaint Saved State
struct PresentingComplaintState: Codable {
    var duration: String = ""
    var severity: Double = 0
    var selectedImpacts: [String] = []
    var selectedSymptoms: [String: [String]] = [:]
}

// MARK: - Presenting Complaint Popup
struct PresentingComplaintPopupView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(SharedDataStore.self) private var sharedData
    @Environment(\.dismiss) private var dismiss

    // Duration dropdown options (matching desktop)
    let durations = [
        "", "one day", "a few days", "a week", "2 weeks", "3 weeks",
        "1 month", "5 weeks", "6 weeks", "7 weeks",
        "2 months", "3 months", "4 months", "5 months", "6 months",
        "6 months to 1 year", "more than a year"
    ]

    // Impact options (matching desktop)
    let impactOptions = ["Work", "Relationships", "Self-care", "Social", "Sleep", "Routine"]

    // Symptoms by category (matching desktop exactly)
    let symptomCategories: [(String, [String])] = [
        ("Depressive Symptoms", ["low mood", "can't sleep", "tired", "can't eat", "memory issues", "angry", "suicidal", "cutting", "can't concentrate"]),
        ("Anxiety Symptoms", ["being stressed", "restless", "panic", "compulsions", "obsessions", "nightmares", "flashbacks"]),
        ("Manic Features", ["high mood", "increased activity", "overspending", "disinhibition"]),
        ("Psychosis Features", ["paranoia", "voices", "control or interference"])
    ]

    @State private var duration: String = ""
    @State private var severity: Double = 0  // 0 = not specified
    @State private var selectedImpacts: Set<String> = []
    @State private var selectedSymptoms: [String: Set<String>] = [:]
    @State private var expandedCategories: Set<String> = []
    @State private var hasLoadedState = false

    var body: some View {
        VStack(spacing: 0) {
            // Preview panel at top
            PreviewPanelView(content: generatedText)

            ScrollView {
                VStack(spacing: 16) {
                    // SECTION 1: Duration / Severity / Impact (always visible)
                    VStack(alignment: .leading, spacing: 12) {
                        // Duration row
                        HStack {
                            Text("Duration:")
                                .font(.headline)
                                .foregroundColor(.teal)
                                .frame(width: 80, alignment: .leading)

                            Picker("Duration", selection: $duration) {
                                Text("Not specified").tag("")
                                ForEach(durations.dropFirst(), id: \.self) { d in
                                    Text(d).tag(d)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        // Severity row
                        HStack {
                            Text("Severity:")
                                .font(.headline)
                                .foregroundColor(.teal)
                                .frame(width: 80, alignment: .leading)

                            Slider(value: $severity, in: 0...10, step: 1)

                            Text(severity == 0 ? "—" : "\(Int(severity))")
                                .font(.headline)
                                .foregroundColor(.teal)
                                .frame(width: 30)
                        }

                        // Impact on
                        Text("Impact on:")
                            .font(.headline)
                            .foregroundColor(.teal)

                        // Impact chips in grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(impactOptions, id: \.self) { impact in
                                ImpactChipButton(
                                    title: impact,
                                    isSelected: selectedImpacts.contains(impact),
                                    onTap: {
                                        if selectedImpacts.contains(impact) {
                                            selectedImpacts.remove(impact)
                                        } else {
                                            selectedImpacts.insert(impact)
                                        }
                                    }
                                )
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)

                    // SECTION 2: Symptoms (collapsible categories)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Symptoms")
                            .font(.headline)
                            .foregroundColor(.teal)

                        ForEach(symptomCategories, id: \.0) { category, symptoms in
                            CollapsibleSymptomCategory(
                                title: category,
                                symptoms: symptoms,
                                selectedSymptoms: Binding(
                                    get: { selectedSymptoms[category] ?? [] },
                                    set: { selectedSymptoms[category] = $0 }
                                ),
                                isExpanded: expandedCategories.contains(category),
                                onToggle: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if expandedCategories.contains(category) {
                                            expandedCategories.remove(category)
                                        } else {
                                            expandedCategories.insert(category)
                                        }
                                    }
                                }
                            )
                        }

                        // Reset button
                        HStack {
                            Spacer()
                            Button("Reset") {
                                duration = ""
                                severity = 0
                                selectedImpacts = []
                                selectedSymptoms = [:]
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray5))
                            .cornerRadius(6)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
                .padding()
            }
        }
        .onAppear {
            loadSavedState()
        }
        .onDisappear {
            saveState()
            let text = generatedText
            if !text.isEmpty && text != "No symptoms selected." {
                appStore.updateSection(.presentingComplaint, content: text)
            }
        }
    }

    // MARK: - State Persistence
    private func loadSavedState() {
        guard !hasLoadedState else { return }
        hasLoadedState = true

        if let saved = appStore.loadPopupData(PresentingComplaintState.self, for: .presentingComplaint) {
            duration = saved.duration
            severity = saved.severity
            selectedImpacts = Set(saved.selectedImpacts)
            // Convert [String: [String]] to [String: Set<String>]
            selectedSymptoms = saved.selectedSymptoms.mapValues { Set($0) }
        }
    }

    private func saveState() {
        let state = PresentingComplaintState(
            duration: duration,
            severity: severity,
            selectedImpacts: Array(selectedImpacts),
            // Convert [String: Set<String>] to [String: [String]]
            selectedSymptoms: selectedSymptoms.mapValues { Array($0) }
        )
        appStore.savePopupData(state, for: .presentingComplaint)
    }

    // Transform symptoms to clinical language (matching desktop)
    private func transformSymptom(_ s: String) -> String {
        let transforms: [String: String] = [
            "can't sleep": "an inability to sleep",
            "can't eat": "reduced appetite",
            "angry": "being angry",
            "suicidal": "significant suicidal thoughts",
            "cutting": "concerning self harm",
            "can't concentrate": "difficulties in maintaining concentration",
            "control or interference": "thoughts of control/interference",
            "restless": "restlessness",
            "tired": "tiredness"
        ]
        return transforms[s] ?? s
    }

    private var generatedText: String {
        let p = sharedData.patientInfo.pronouns
        let sub = p.Subject.capitalized
        let poss = p.possessive

        // Collect symptoms by category
        var symptomParts: [String] = []
        for (category, _) in symptomCategories {
            let selected = selectedSymptoms[category] ?? []
            if !selected.isEmpty {
                let categoryName = category.lowercased()
                let transformed = selected.map { transformSymptom($0) }
                let joined = joinWithAnd(Array(transformed))
                symptomParts.append("\(categoryName) including \(joined)")
            }
        }

        if symptomParts.isEmpty {
            return "No symptoms selected."
        }

        // Determine verb
        let verb = (sub.lowercased() == "he" || sub.lowercased() == "she") ? "presents" : "present"

        var parts: [String] = []

        // Opening with symptoms
        let symptomsText = symptomParts.joined(separator: "; ")
        parts.append("\(sub) \(verb) with \(symptomsText).")

        // Duration (only if specified)
        if !duration.isEmpty {
            parts.append("Symptoms have been present for \(duration).")
        }

        // Severity (only if > 0)
        if severity > 0 {
            parts.append("Severity is rated \(Int(severity)) out of 10.")
        }

        // Impact (only if any selected)
        if !selectedImpacts.isEmpty {
            let expanded = selectedImpacts.map { impact -> String in
                switch impact {
                case "Relationships": return "relationships"
                case "Social": return "social functioning"
                case "Routine": return "daily routine"
                default: return impact.lowercased()
                }
            }
            let joined = joinWithAnd(Array(expanded))
            parts.append("These symptoms impact \(poss) \(joined).")
        }

        return parts.joined(separator: " ")
    }

    private func joinWithAnd(_ items: [String]) -> String {
        guard !items.isEmpty else { return "" }
        if items.count == 1 { return items[0] }
        if items.count == 2 { return "\(items[0]) and \(items[1])" }
        return items.dropLast().joined(separator: ", ") + " and \(items.last!)"
    }
}

// MARK: - Impact Chip Button
struct ImpactChipButton: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(isSelected ? .teal : Color.black.opacity(0.08))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Collapsible Symptom Category
struct CollapsibleSymptomCategory: View {
    let title: String
    let symptoms: [String]
    @Binding var selectedSymptoms: Set<String>
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button(action: onToggle) {
                HStack {
                    Text(isExpanded ? "▼" : "▶")
                        .font(.system(size: 12))
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.teal)
                    Spacer()
                    if !selectedSymptoms.isEmpty {
                        Text("\(selectedSymptoms.count)")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(.teal)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)

            // Symptoms (when expanded)
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(symptoms, id: \.self) { symptom in
                        Toggle(isOn: Binding(
                            get: { selectedSymptoms.contains(symptom) },
                            set: { isOn in
                                if isOn {
                                    selectedSymptoms.insert(symptom)
                                } else {
                                    selectedSymptoms.remove(symptom)
                                }
                            }
                        )) {
                            Text(symptom)
                                .font(.body)
                        }
                        .toggleStyle(CheckboxToggleStyle())
                        .padding(.leading, 16)
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }
}

// MARK: - Checkbox Toggle Style
struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: { configuration.isOn.toggle() }) {
            HStack(spacing: 8) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .foregroundColor(configuration.isOn ? .teal : .gray)
                    .font(.system(size: 20))
                configuration.label
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SectionPopupView(sectionType: .presentingComplaint)
        .environment(AppStore())
        .environment(SharedDataStore.shared)
}
