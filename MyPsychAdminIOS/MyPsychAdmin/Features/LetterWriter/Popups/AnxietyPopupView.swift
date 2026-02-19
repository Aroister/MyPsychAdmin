//
//  AnxietyPopupView.swift
//  MyPsychAdmin
//
//  Comprehensive anxiety assessment with Anxiety/Panic/Phobia, OCD, and PTSD sections
//

import SwiftUI

// MARK: - Anxiety State for Persistence
struct AnxietyState: Codable {
    var currentMode: String = "Anxiety/Panic/Phobia"
    var anxietySymptoms: [String: Int] = [:]
    var panicAssociated: Bool = false
    var panicSeverity: String = "moderate"
    var avoidanceAssociated: Bool = false
    var phobiaType: String = "Select type..."
    var phobiaSeverity: String = "moderate"
    var phobiaSubSymptoms: [String] = []

    var ocdThoughts: [String] = []
    var ocdCompulsions: [String] = []
    var ocdAssociated: [String] = []
    var ocdDepressionProminence: String? = nil
    var ocdOrganicDisorder: String? = nil
    var ocdSchizophrenia: String? = nil
    var ocdTourettes: String? = nil

    var ptsdPrecipitating: String? = nil
    var ptsdRecurrent: [String] = []
    var ptsdOnsetWithinSixMonths: Bool = false
    var ptsdAssociated: [String] = []

    var additionalNotes: String = ""
}

struct AnxietyPopupView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(SharedDataStore.self) private var sharedData
    @Environment(\.dismiss) private var dismiss

    enum AnxietyMode: String, CaseIterable {
        case anxietyPanicPhobia = "Anxiety/Panic/Phobia"
        case ocd = "OCD"
        case ptsd = "PTSD"
    }

    @State private var currentMode: AnxietyMode = .anxietyPanicPhobia

    // Anxiety/Panic/Phobia symptoms with severity (0-3: none, mild, moderate, severe)
    @State private var anxietySymptoms: [String: Int] = [:]
    @State private var panicAssociated: Bool = false
    @State private var panicSeverity: String = "moderate"
    @State private var avoidanceAssociated: Bool = false
    @State private var phobiaType: PhobiaType = .none
    @State private var phobiaSeverity: String = "moderate"
    @State private var phobiaSubSymptoms: Set<String> = []

    // OCD values
    @State private var ocdThoughts: Set<String> = []
    @State private var ocdCompulsions: Set<String> = []
    @State private var ocdAssociated: Set<String> = []
    @State private var ocdDepressionProminence: String? = nil
    @State private var ocdOrganicDisorder: String? = nil
    @State private var ocdSchizophrenia: String? = nil
    @State private var ocdTourettes: String? = nil

    // PTSD values
    @State private var ptsdPrecipitating: String? = nil
    @State private var ptsdRecurrent: Set<String> = []
    @State private var ptsdOnsetWithinSixMonths: Bool = false
    @State private var ptsdAssociated: Set<String> = []

    @State private var additionalNotes: String = ""

    enum PhobiaType: String, CaseIterable, Identifiable {
        case none = "Select type..."
        case agoraphobia = "Agoraphobia"
        case specificPhobia = "Specific phobia"
        case socialPhobia = "Social phobia"
        case hypochondriacal = "Hypochondriacal"

        var id: String { rawValue }

        var subSymptoms: [String] {
            switch self {
            case .none: return []
            case .agoraphobia: return ["crowds", "public places", "travelling alone", "travel away from home"]
            case .specificPhobia: return ["animals", "blood", "simple phobia", "exams", "small spaces"]
            case .socialPhobia: return ["social situations"]
            case .hypochondriacal: return ["heart disease", "body shape (dysmorphic)", "specific", "organ cancer"]
            }
        }
    }

    private let anxietySymptomsList = [
        "palpitations", "breathing difficulty", "dry mouth", "sweating", "shaking",
        "chest pain/discomfort", "hot flashes/cold chills", "concentration issues",
        "being irritable", "numbness/tingling", "restlessness", "dizzy/faint",
        "nausea/abdo distress", "swallowing difficulties", "choking", "on edge",
        "increased startle", "muscle tension/aches", "initial insomnia",
        "Fear of dying", "Fear of losing control", "depersonalisation/derealisation"
    ]

    private let ocdThoughtsList = ["impulses", "ideas", "magical thoughts", "images", "ruminations"]
    private let ocdCompulsionsList = ["obsessional slowness", "gas/elec checking", "lock-checking", "cleaning", "handwashing"]
    private let ocdAssociatedList = ["fear", "relief/contentment", "distress", "depers/dereal", "tries to resist", "recognised as own thoughts"]

    private let ptsdPrecipitatingList = ["accidental", "current", "historical"]
    private let ptsdRecurrentList = ["flashbacks", "imagery", "intense memories", "nightmares"]
    private let ptsdAssociatedList = ["distress", "hyperarousal", "avoidance", "fear", "numbness/depersonalisation"]

    var body: some View {
        VStack(spacing: 0) {
            // Preview panel
            PreviewPanelView(content: generatedText)

            // Mode selector
            Picker("Mode", selection: $currentMode) {
                ForEach(AnxietyMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            ScrollView {
                VStack(spacing: 16) {
                    switch currentMode {
                    case .anxietyPanicPhobia:
                        anxietyPanicPhobiaSection
                    case .ocd:
                        ocdSection
                    case .ptsd:
                        ptsdSection
                    }

                    // Additional notes
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Additional Notes")
                            .font(.headline)
                        TextEditor(text: $additionalNotes)
                            .frame(minHeight: 80)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 20)
            }
        }
        .onAppear { loadState() }
        .onDisappear { saveState() }
    }

    // MARK: - State Persistence
    private func loadState() {
        if let saved = appStore.loadPopupData(AnxietyState.self, for: .anxiety) {
            currentMode = AnxietyMode(rawValue: saved.currentMode) ?? .anxietyPanicPhobia
            anxietySymptoms = saved.anxietySymptoms
            panicAssociated = saved.panicAssociated
            panicSeverity = saved.panicSeverity
            avoidanceAssociated = saved.avoidanceAssociated
            phobiaType = PhobiaType(rawValue: saved.phobiaType) ?? .none
            phobiaSeverity = saved.phobiaSeverity
            phobiaSubSymptoms = Set(saved.phobiaSubSymptoms)

            ocdThoughts = Set(saved.ocdThoughts)
            ocdCompulsions = Set(saved.ocdCompulsions)
            ocdAssociated = Set(saved.ocdAssociated)
            ocdDepressionProminence = saved.ocdDepressionProminence
            ocdOrganicDisorder = saved.ocdOrganicDisorder
            ocdSchizophrenia = saved.ocdSchizophrenia
            ocdTourettes = saved.ocdTourettes

            ptsdPrecipitating = saved.ptsdPrecipitating
            ptsdRecurrent = Set(saved.ptsdRecurrent)
            ptsdOnsetWithinSixMonths = saved.ptsdOnsetWithinSixMonths
            ptsdAssociated = Set(saved.ptsdAssociated)

            additionalNotes = saved.additionalNotes
        }
    }

    private func saveState() {
        var state = AnxietyState()
        state.currentMode = currentMode.rawValue
        state.anxietySymptoms = anxietySymptoms
        state.panicAssociated = panicAssociated
        state.panicSeverity = panicSeverity
        state.avoidanceAssociated = avoidanceAssociated
        state.phobiaType = phobiaType.rawValue
        state.phobiaSeverity = phobiaSeverity
        state.phobiaSubSymptoms = Array(phobiaSubSymptoms)

        state.ocdThoughts = Array(ocdThoughts)
        state.ocdCompulsions = Array(ocdCompulsions)
        state.ocdAssociated = Array(ocdAssociated)
        state.ocdDepressionProminence = ocdDepressionProminence
        state.ocdOrganicDisorder = ocdOrganicDisorder
        state.ocdSchizophrenia = ocdSchizophrenia
        state.ocdTourettes = ocdTourettes

        state.ptsdPrecipitating = ptsdPrecipitating
        state.ptsdRecurrent = Array(ptsdRecurrent)
        state.ptsdOnsetWithinSixMonths = ptsdOnsetWithinSixMonths
        state.ptsdAssociated = Array(ptsdAssociated)

        state.additionalNotes = additionalNotes

        appStore.savePopupData(state, for: .anxiety)

        if !generatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            appStore.updateSection(.anxiety, content: generatedText)
        }
    }

    // MARK: - Anxiety/Panic/Phobia Section
    private var anxietyPanicPhobiaSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Symptoms grid
            CollapsibleSymptomSection(
                title: "Anxiety Symptoms",
                isExpanded: true,
                onToggle: {}
            ) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(anxietySymptomsList, id: \.self) { symptom in
                        SymptomSeverityButton(
                            symptom: symptom,
                            severity: anxietySymptoms[symptom] ?? 0,
                            onTap: {
                                let current = anxietySymptoms[symptom] ?? 0
                                anxietySymptoms[symptom] = (current + 1) % 4  // 0->1->2->3->0 (none->mild->mod->severe->none)
                            }
                        )
                    }
                }
            }

            // Panic association
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Associated with panic attacks", isOn: $panicAssociated)

                if panicAssociated {
                    Picker("Severity", selection: $panicSeverity) {
                        Text("Mild").tag("mild")
                        Text("Moderate").tag("moderate")
                        Text("Severe").tag("severe")
                    }
                    .pickerStyle(.segmented)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .padding(.horizontal)

            // Avoidance/Phobia
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Associated with avoidance", isOn: $avoidanceAssociated)

                if avoidanceAssociated {
                    Picker("Phobia Type", selection: $phobiaType) {
                        ForEach(PhobiaType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }

                    if phobiaType != .none {
                        Picker("Severity", selection: $phobiaSeverity) {
                            Text("Mild").tag("mild")
                            Text("Moderate").tag("moderate")
                            Text("Severe").tag("severe")
                        }
                        .pickerStyle(.segmented)

                        // Sub-symptoms
                        if !phobiaType.subSymptoms.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Specific features:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                ForEach(phobiaType.subSymptoms, id: \.self) { sub in
                                    Toggle(sub, isOn: Binding(
                                        get: { phobiaSubSymptoms.contains(sub) },
                                        set: { if $0 { phobiaSubSymptoms.insert(sub) } else { phobiaSubSymptoms.remove(sub) } }
                                    ))
                                    .font(.subheadline)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .padding(.horizontal)
        }
    }

    // MARK: - OCD Section
    private var ocdSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Thoughts
            OCDSubsection(title: "Thoughts", items: ocdThoughtsList, selected: $ocdThoughts)

            // Compulsions
            OCDSubsection(title: "Compulsions", items: ocdCompulsionsList, selected: $ocdCompulsions)

            // Associated with
            OCDSubsection(title: "Associated with", items: ocdAssociatedList, selected: $ocdAssociated)

            // Comorbidity (radio sections)
            VStack(alignment: .leading, spacing: 12) {
                Text("Comorbidity")
                    .font(.headline)
                    .padding(.horizontal)

                OCDRadioSection(
                    title: "Depression prominence",
                    options: ["less", "equal", "more"],
                    selected: $ocdDepressionProminence
                )

                OCDRadioSection(
                    title: "Organic mental disorder",
                    options: ["present", "absent"],
                    selected: $ocdOrganicDisorder
                )

                OCDRadioSection(
                    title: "Schizophrenia",
                    options: ["present", "absent"],
                    selected: $ocdSchizophrenia
                )

                OCDRadioSection(
                    title: "Tourette's",
                    options: ["present", "absent"],
                    selected: $ocdTourettes
                )
            }
        }
    }

    // MARK: - PTSD Section
    private var ptsdSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Precipitating event
            VStack(alignment: .leading, spacing: 8) {
                Text("Precipitating Event")
                    .font(.headline)

                ForEach(ptsdPrecipitatingList, id: \.self) { item in
                    Button {
                        ptsdPrecipitating = ptsdPrecipitating == item ? nil : item
                    } label: {
                        HStack {
                            Image(systemName: ptsdPrecipitating == item ? "circle.fill" : "circle")
                                .foregroundColor(ptsdPrecipitating == item ? .purple : .gray)
                            Text(item.capitalized)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .padding(.horizontal)

            // Recurrent symptoms
            VStack(alignment: .leading, spacing: 8) {
                Text("Recurrent Symptoms")
                    .font(.headline)

                ForEach(ptsdRecurrentList, id: \.self) { item in
                    Toggle(item.capitalized, isOn: Binding(
                        get: { ptsdRecurrent.contains(item) },
                        set: { if $0 { ptsdRecurrent.insert(item) } else { ptsdRecurrent.remove(item) } }
                    ))
                }

                Toggle("Symptoms commenced within six months", isOn: $ptsdOnsetWithinSixMonths)
                    .padding(.top, 8)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .padding(.horizontal)

            // Associated with
            VStack(alignment: .leading, spacing: 8) {
                Text("Associated with")
                    .font(.headline)

                ForEach(ptsdAssociatedList, id: \.self) { item in
                    Toggle(item.capitalized, isOn: Binding(
                        get: { ptsdAssociated.contains(item) },
                        set: { if $0 { ptsdAssociated.insert(item) } else { ptsdAssociated.remove(item) } }
                    ))
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .padding(.horizontal)
        }
    }

    // MARK: - Text Generation
    private var generatedText: String {
        let p = sharedData.patientInfo.pronouns
        let firstName = sharedData.patientInfo.firstName.isEmpty ? "The patient" : sharedData.patientInfo.firstName
        var paragraphs: [String] = []

        // Anxiety/Panic/Phobia
        let activeAnxiety = anxietySymptoms.filter { $0.value > 0 }
        if !activeAnxiety.isEmpty {
            let symptomNames = activeAnxiety.keys.sorted()
            let transformed = transformAnxietySymptoms(symptomNames)
            let joined = joinWithAnd(transformed)
            let severityPhrase = weightedSeverityPhrase(Array(activeAnxiety.values))

            var sentence = "\(firstName) reported anxiety symptoms including \(joined) (\(severityPhrase))"

            // Associations
            var associations: [String] = []
            if panicAssociated {
                associations.append("\(panicSeverity) panic attacks")
            }
            if avoidanceAssociated && phobiaType != .none {
                associations.append("\(phobiaSeverity) \(phobiaType.rawValue.lowercased())")
            }

            if !associations.isEmpty {
                sentence += ". These symptoms were associated with \(joinWithAnd(associations))"

                if avoidanceAssociated && !phobiaSubSymptoms.isEmpty {
                    let subJoined = joinWithAnd(Array(phobiaSubSymptoms))
                    sentence += ", with \(subJoined)"
                }
            }

            paragraphs.append(sentence + ".")
        }

        // OCD
        if !ocdThoughts.isEmpty || !ocdCompulsions.isEmpty {
            paragraphs.append("")
            paragraphs.append("**OCD symptoms:**")

            if !ocdThoughts.isEmpty {
                let phrases = ocdThoughts.map { ocdThoughtPhrase($0) }
                paragraphs.append("\(firstName) described obsessional thoughts, including \(joinWithAnd(phrases)).")
            }

            if !ocdCompulsions.isEmpty {
                let phrases = ocdCompulsions.map { ocdCompulsionPhrase($0) }
                paragraphs.append("\(p.Subject.capitalized) described compulsive behaviours such as \(joinWithAnd(phrases)).")
            }

            if !ocdAssociated.isEmpty {
                let phrases = ocdAssociated.map { ocdAssociatedPhrase($0, pronouns: p) }
                paragraphs.append("These symptoms were associated with \(joinWithAnd(phrases)).")
            }

            // Comorbidity
            var comorbidPhrases: [String] = []
            if let dep = ocdDepressionProminence {
                comorbidPhrases.append("depression that was \(dep) prominent than the OCD")
            }
            if let org = ocdOrganicDisorder {
                comorbidPhrases.append("organic mental disorder was \(org)")
            }
            if let schiz = ocdSchizophrenia {
                comorbidPhrases.append("schizophrenia was \(schiz)")
                if schiz == "present" {
                    paragraphs.append("In view of this, a formal diagnosis of obsessive-compulsive disorder was not made.")
                }
            }
            if let tour = ocdTourettes {
                comorbidPhrases.append(tour == "present" ? "comorbid Tourette's syndrome was noted" : "there was no comorbid Tourette's syndrome")
            }

            if !comorbidPhrases.isEmpty {
                paragraphs.append("Relevant comorbid considerations included \(joinWithAnd(comorbidPhrases)).")
            }
        }

        // PTSD
        if ptsdPrecipitating != nil || !ptsdRecurrent.isEmpty {
            paragraphs.append("")
            paragraphs.append("**PTSD symptoms:**")

            if let precip = ptsdPrecipitating {
                let phrase = ptsdPrecipitatingPhrase(precip)
                paragraphs.append("\(firstName) described post-traumatic stress features following \(phrase).")
            }

            if !ptsdRecurrent.isEmpty {
                let phrases = ptsdRecurrent.map { ptsdRecurrentPhrase($0) }
                var sentence = "There were recurrent symptoms including \(joinWithAnd(phrases))"
                if ptsdOnsetWithinSixMonths {
                    sentence += " - symptoms commenced within six months of the precipitating event"
                }
                paragraphs.append(sentence + ".")
            }

            if !ptsdAssociated.isEmpty {
                let phrases = ptsdAssociated.map { ptsdAssociatedPhrase($0) }
                paragraphs.append("These symptoms were associated with \(joinWithAnd(phrases)).")
            }
        }

        if !additionalNotes.isEmpty {
            paragraphs.append(additionalNotes)
        }

        return paragraphs.joined(separator: "\n")
    }

    // MARK: - Helper Functions
    private func transformAnxietySymptoms(_ symptoms: [String]) -> [String] {
        var result: [String] = []
        var hasFearDying = false
        var hasFearControl = false

        for s in symptoms {
            if s == "Fear of dying" { hasFearDying = true; continue }
            if s == "Fear of losing control" { hasFearControl = true; continue }

            switch s {
            case "being irritable": result.append("being irritable")
            case "dry mouth": result.append("having a dry mouth")
            case "on edge": result.append("feeling on edge")
            default: result.append(s)
            }
        }

        if hasFearDying && hasFearControl {
            result.append("a fear of dying and of losing control")
        } else if hasFearDying {
            result.append("a fear of dying")
        } else if hasFearControl {
            result.append("a fear of losing control")
        }

        return result
    }

    private func weightedSeverityPhrase(_ severities: [Int]) -> String {
        guard !severities.isEmpty else { return "" }

        let sevMap = [1: "mild", 2: "moderate", 3: "severe"]
        let counts = Dictionary(grouping: severities, by: { $0 }).mapValues { $0.count }

        if counts.count == 1, let first = severities.first {
            return "all \(sevMap[first] ?? "moderate")"
        }

        let dominant = counts.max(by: { $0.value < $1.value })?.key ?? 2
        let others = counts.keys.filter { $0 != dominant }.map { sevMap[$0] ?? "" }
        return "predominantly \(sevMap[dominant] ?? "moderate") with intermittent \(others.joined(separator: ", ")) symptoms"
    }

    private func joinWithAnd(_ items: [String]) -> String {
        guard !items.isEmpty else { return "" }
        if items.count == 1 { return items[0] }
        if items.count == 2 { return "\(items[0]) and \(items[1])" }
        return items.dropLast().joined(separator: ", ") + ", and \(items.last!)"
    }

    private func ocdThoughtPhrase(_ item: String) -> String {
        let map = [
            "impulses": "obsessive impulses",
            "ideas": "overwhelming recurrent obsessional ideas",
            "magical thoughts": "magical thinking",
            "images": "recurrent intrusive imagery",
            "ruminations": "excessive rumination"
        ]
        return map[item] ?? item
    }

    private func ocdCompulsionPhrase(_ item: String) -> String {
        let map = [
            "obsessional slowness": "compulsions took a long time",
            "gas/elec checking": "recurrently checking gas/electrics",
            "lock-checking": "excessive lock-checking",
            "cleaning": "overcleaning",
            "handwashing": "compulsive handwashing"
        ]
        return map[item] ?? item
    }

    private func ocdAssociatedPhrase(_ item: String, pronouns p: Pronouns) -> String {
        let map = [
            "fear": "a sense of fear",
            "relief/contentment": "a feeling of relief after carrying out the act",
            "distress": "significant distress",
            "depers/dereal": "feeling unreal with depersonalisation/derealisation",
            "tries to resist": "\(p.Subject) tries to resist these thoughts/acts",
            "recognised as own thoughts": "recognising the thoughts/acts as \(p.possessive) own"
        ]
        return map[item] ?? item
    }

    private func ptsdPrecipitatingPhrase(_ item: String) -> String {
        let map = ["accidental": "accidental trauma", "current": "ongoing trauma/abuse", "historical": "past trauma/abuse"]
        return map[item] ?? item
    }

    private func ptsdRecurrentPhrase(_ item: String) -> String {
        let map = [
            "flashbacks": "vivid, video-like flashbacks",
            "imagery": "recurrent imagery of the events",
            "intense memories": "intense and overwhelming memories",
            "nightmares": "distressing nightmares"
        ]
        return map[item] ?? item
    }

    private func ptsdAssociatedPhrase(_ item: String) -> String {
        let map = [
            "distress": "significant distress on discussion",
            "hyperarousal": "feelings of anxiety and panic on recall",
            "avoidance": "avoidance of sharing the event",
            "fear": "recurrent fear",
            "numbness/depersonalisation": "a sense of numbness and depersonalisation around the event"
        ]
        return map[item] ?? item
    }
}

// MARK: - Symptom Severity Button
struct SymptomSeverityButton: View {
    let symptom: String
    let severity: Int
    let onTap: () -> Void

    private var severityColor: Color {
        switch severity {
        case 0: return .gray.opacity(0.3)
        case 1: return .yellow
        case 2: return .orange
        case 3: return .red
        default: return .gray
        }
    }

    private var severityLabel: String {
        switch severity {
        case 0: return ""
        case 1: return "Mild"
        case 2: return "Mod"
        case 3: return "Severe"
        default: return ""
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 2) {
                Text(symptom)
                    .font(.caption)
                    .foregroundColor(severity > 0 ? .primary : .secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if severity > 0 {
                    Text(severityLabel)
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(severityColor)
                        .cornerRadius(4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(severity > 0 ? severityColor.opacity(0.15) : Color(.systemGray6))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(severity > 0 ? severityColor : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - OCD Subsection
struct OCDSubsection: View {
    let title: String
    let items: [String]
    @Binding var selected: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.teal)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(items, id: \.self) { item in
                    Button {
                        if selected.contains(item) {
                            selected.remove(item)
                        } else {
                            selected.insert(item)
                        }
                    } label: {
                        Text(item)
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                            .padding(8)
                            .background(selected.contains(item) ? Color.teal.opacity(0.2) : Color(.systemGray6))
                            .foregroundColor(selected.contains(item) ? .teal : .primary)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(selected.contains(item) ? Color.teal : Color.clear, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

// MARK: - OCD Radio Section
struct OCDRadioSection: View {
    let title: String
    let options: [String]
    @Binding var selected: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)

            HStack {
                ForEach(options, id: \.self) { option in
                    Button {
                        selected = selected == option ? nil : option
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: selected == option ? "circle.fill" : "circle")
                                .font(.caption)
                            Text(option.capitalized)
                                .font(.caption)
                        }
                        .foregroundColor(selected == option ? .teal : .secondary)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
        }
        .padding(.horizontal)
    }
}

#Preview {
    NavigationStack {
        AnxietyPopupView()
            .environment(AppStore())
            .environment(SharedDataStore.shared)
    }
}
