//
//  PsychosisPopupView.swift
//  MyPsychAdmin
//
//  Comprehensive psychosis assessment with Delusions and Hallucinations sections
//

import SwiftUI

// MARK: - Psychosis State for Persistence
struct PsychosisState: Codable {
    var currentMode: String = "Delusions"
    var delusionContent: [String: Int] = [:]
    var thoughtInterference: [String: Int] = [:]
    var passivityPhenomena: [String: Int] = [:]
    var delusionAssociated: [String] = []
    var auditoryHallucinations: [String: Int] = [:]
    var otherHallucinations: [String: Int] = [:]
    var hallucinationAssociated: [String] = []
    var additionalNotes: String = ""
}

struct PsychosisPopupView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(SharedDataStore.self) private var sharedData
    @Environment(\.dismiss) private var dismiss

    enum PsychosisMode: String, CaseIterable {
        case delusions = "Delusions"
        case hallucinations = "Hallucinations"
    }

    @State private var currentMode: PsychosisMode = .delusions

    // Delusions with severity (0-3: none, mild, moderate, severe)
    @State private var delusionContent: [String: Int] = [:]
    @State private var thoughtInterference: [String: Int] = [:]
    @State private var passivityPhenomena: [String: Int] = [:]
    @State private var delusionAssociated: Set<String> = []

    // Hallucinations with severity
    @State private var auditoryHallucinations: [String: Int] = [:]
    @State private var otherHallucinations: [String: Int] = [:]
    @State private var hallucinationAssociated: Set<String> = []

    @State private var additionalNotes: String = ""

    // MARK: - Symptom Lists
    private let delusionContentList: [(String, String)] = [
        ("persecutory", "persecutory delusions"),
        ("reference", "delusions of reference/misidentification"),
        ("delusional perception", "delusional perceptions"),
        ("somatic", "somatic delusions"),
        ("religious", "religious delusions outwith cultural norms"),
        ("mood/feeling", "delusions of mood/affect"),
        ("guilt/worthlessness", "profound mood-congruent delusions of guilt"),
        ("infidelity/jealousy", "delusional jealousy/infidelity"),
        ("nihilistic/negation", "mood-congruent delusions of worthlessness and nihilism"),
        ("grandiosity", "delusions of grandiosity")
    ]

    private let thoughtInterferenceList: [(String, String)] = [
        ("broadcast", "thought broadcast"),
        ("withdrawal", "thought withdrawal"),
        ("insertion", "thought insertion")
    ]

    private let passivityPhenomenaList: [(String, String)] = [
        ("thoughts", "external control of thoughts"),
        ("actions", "external control of actions"),
        ("limbs", "external limb-control (passivity)"),
        ("sensation", "external control of sensations")
    ]

    private let delusionAssociatedList: [(String, String)] = [
        ("mannerisms", "mannerisms"),
        ("fear", "a sense of fear around these experiences"),
        ("thought disorder", "associated thought disorder"),
        ("negative symptoms", "significant negative symptoms"),
        ("acting on delusions", "acting on these experiences"),
        ("catatonia", "catatonic features"),
        ("overvalued ideas", "overvalued ideas"),
        ("inappropriate affect", "inappropriate affect"),
        ("behaviour change / withdrawal", "significant behavioural change and withdrawal"),
        ("obsessional beliefs", "obsessional beliefs")
    ]

    private let auditoryHallucinationsList: [(String, String)] = [
        ("2nd person", "second-person auditory hallucinations (voices addressing the patient directly)"),
        ("3rd person", "third-person auditory hallucinations (a first-rank symptom)"),
        ("derogatory", "derogatory voices"),
        ("thought echo", "thought echo"),
        ("command", "command hallucinations"),
        ("running commentary", "a running commentary on the patient's actions"),
        ("multiple voices", "multiple voices rather than a single voice")
    ]

    private let otherHallucinationsList: [(String, String)] = [
        ("visual", "visual"),
        ("tactile", "tactile"),
        ("somatic", "somatic"),
        ("olfactory/taste", "olfactory/gustatory")
    ]

    private let hallucinationAssociatedList: [(String, String)] = [
        ("pseudohallucinations", "pseudohallucinations rather than true hallucinations"),
        ("sleep related", "sleep-related perceptions (hypnagogic or hypnopompic)"),
        ("shadows/illusions", "illusions rather than true hallucinations"),
        ("fear", "a sense of fear around these perceptions"),
        ("acting on hallucinations", "acting on these hallucinations")
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Preview panel
            PreviewPanelView(content: generatedText)

            // Mode selector
            Picker("Mode", selection: $currentMode) {
                ForEach(PsychosisMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            ScrollView {
                VStack(spacing: 16) {
                    switch currentMode {
                    case .delusions:
                        delusionsSection
                    case .hallucinations:
                        hallucinationsSection
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
        if let saved = appStore.loadPopupData(PsychosisState.self, for: .psychosis) {
            currentMode = PsychosisMode(rawValue: saved.currentMode) ?? .delusions
            delusionContent = saved.delusionContent
            thoughtInterference = saved.thoughtInterference
            passivityPhenomena = saved.passivityPhenomena
            delusionAssociated = Set(saved.delusionAssociated)
            auditoryHallucinations = saved.auditoryHallucinations
            otherHallucinations = saved.otherHallucinations
            hallucinationAssociated = Set(saved.hallucinationAssociated)
            additionalNotes = saved.additionalNotes
        }
    }

    private func saveState() {
        var state = PsychosisState()
        state.currentMode = currentMode.rawValue
        state.delusionContent = delusionContent
        state.thoughtInterference = thoughtInterference
        state.passivityPhenomena = passivityPhenomena
        state.delusionAssociated = Array(delusionAssociated)
        state.auditoryHallucinations = auditoryHallucinations
        state.otherHallucinations = otherHallucinations
        state.hallucinationAssociated = Array(hallucinationAssociated)
        state.additionalNotes = additionalNotes

        appStore.savePopupData(state, for: .psychosis)

        if !generatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            appStore.updateSection(.psychosis, content: generatedText)
        }
    }

    // MARK: - Delusions Section
    private var delusionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Delusional content
            PsychosisSymptomSection(
                title: "Delusional Content",
                items: delusionContentList,
                severities: $delusionContent
            )

            // Thought interference
            PsychosisSymptomSection(
                title: "Thought Interference",
                items: thoughtInterferenceList,
                severities: $thoughtInterference
            )

            // Passivity phenomena
            PsychosisSymptomSection(
                title: "Passivity Phenomena",
                items: passivityPhenomenaList,
                severities: $passivityPhenomena
            )

            // Associated with (no severity)
            PsychosisAssociatedSection(
                title: "Associated With",
                items: delusionAssociatedList,
                selected: $delusionAssociated
            )
        }
    }

    // MARK: - Hallucinations Section
    private var hallucinationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Auditory hallucinations
            PsychosisSymptomSection(
                title: "Auditory Hallucinations",
                items: auditoryHallucinationsList,
                severities: $auditoryHallucinations
            )

            // Other hallucinations
            PsychosisSymptomSection(
                title: "Other Modalities",
                items: otherHallucinationsList,
                severities: $otherHallucinations
            )

            // Associated with (no severity)
            PsychosisAssociatedSection(
                title: "Associated With",
                items: hallucinationAssociatedList,
                selected: $hallucinationAssociated
            )
        }
    }

    // MARK: - Text Generation
    private var generatedText: String {
        let p = sharedData.patientInfo.pronouns
        var lines: [String] = []

        // Delusions - grouped by severity (severe first, then moderate, then mild)
        let activeDelusions = delusionContent.filter { $0.value > 0 }
        if !activeDelusions.isEmpty {
            // Group by severity level
            let severeDelusions = activeDelusions.filter { $0.value == 3 }
            let moderateDelusions = activeDelusions.filter { $0.value == 2 }
            let mildDelusions = activeDelusions.filter { $0.value == 1 }

            // Severe delusions first
            if !severeDelusions.isEmpty {
                let phrases = severeDelusions.keys.compactMap { key in
                    delusionContentList.first { $0.0 == key }?.1
                }
                lines.append("Prominent delusional beliefs were noted, including \(joinWithAnd(phrases)).")
            }

            // Moderate delusions
            if !moderateDelusions.isEmpty {
                let phrases = moderateDelusions.keys.compactMap { key in
                    delusionContentList.first { $0.0 == key }?.1
                }
                if severeDelusions.isEmpty {
                    lines.append("Delusional beliefs were noted, including \(joinWithAnd(phrases)).")
                } else {
                    lines.append("Moderate delusional beliefs were also present, including \(joinWithAnd(phrases)).")
                }
            }

            // Mild delusions
            if !mildDelusions.isEmpty {
                let phrases = mildDelusions.keys.compactMap { key in
                    delusionContentList.first { $0.0 == key }?.1
                }
                if severeDelusions.isEmpty && moderateDelusions.isEmpty {
                    lines.append("Mild delusional beliefs were noted, including \(joinWithAnd(phrases)).")
                } else {
                    lines.append("Mild delusional ideation was also noted, including \(joinWithAnd(phrases)).")
                }
            }
        }

        // Passivity - grouped by severity
        let activePassivity = passivityPhenomena.filter { $0.value > 0 }
        if !activePassivity.isEmpty {
            let severePassivity = activePassivity.filter { $0.value == 3 }
            let moderatePassivity = activePassivity.filter { $0.value == 2 }
            let mildPassivity = activePassivity.filter { $0.value == 1 }

            if !severePassivity.isEmpty {
                let phrases = severePassivity.keys.compactMap { key in
                    passivityPhenomenaList.first { $0.0 == key }?.1
                }
                lines.append("There was significant passivity phenomena, including \(joinWithAnd(phrases)).")
            }
            if !moderatePassivity.isEmpty {
                let phrases = moderatePassivity.keys.compactMap { key in
                    passivityPhenomenaList.first { $0.0 == key }?.1
                }
                if severePassivity.isEmpty {
                    lines.append("Passivity phenomena were evident, including \(joinWithAnd(phrases)).")
                } else {
                    lines.append("Moderate passivity phenomena were also present, including \(joinWithAnd(phrases)).")
                }
            }
            if !mildPassivity.isEmpty {
                let phrases = mildPassivity.keys.compactMap { key in
                    passivityPhenomenaList.first { $0.0 == key }?.1
                }
                if severePassivity.isEmpty && moderatePassivity.isEmpty {
                    lines.append("Passivity phenomena were present, including \(joinWithAnd(phrases)).")
                } else {
                    lines.append("Mild passivity phenomena were also noted, including \(joinWithAnd(phrases)).")
                }
            }
        }

        // Thought interference - grouped by severity
        let activeTI = thoughtInterference.filter { $0.value > 0 }
        if !activeTI.isEmpty {
            let severeTI = activeTI.filter { $0.value == 3 }
            let moderateTI = activeTI.filter { $0.value == 2 }
            let mildTI = activeTI.filter { $0.value == 1 }

            if !severeTI.isEmpty {
                let phrases = severeTI.keys.compactMap { key in
                    thoughtInterferenceList.first { $0.0 == key }?.1
                }
                lines.append("There was marked thought interference, including \(joinWithAnd(phrases)).")
            }
            if !moderateTI.isEmpty {
                let phrases = moderateTI.keys.compactMap { key in
                    thoughtInterferenceList.first { $0.0 == key }?.1
                }
                if severeTI.isEmpty {
                    lines.append("There was evidence of thought interference, including \(joinWithAnd(phrases)).")
                } else {
                    lines.append("Moderate thought interference was also present, including \(joinWithAnd(phrases)).")
                }
            }
            if !mildTI.isEmpty {
                let phrases = mildTI.keys.compactMap { key in
                    thoughtInterferenceList.first { $0.0 == key }?.1
                }
                if severeTI.isEmpty && moderateTI.isEmpty {
                    lines.append("There was mild thought interference, including \(joinWithAnd(phrases)).")
                } else {
                    lines.append("Mild thought interference was also noted, including \(joinWithAnd(phrases)).")
                }
            }
        }

        // Delusion associated
        if !delusionAssociated.isEmpty {
            let phrases = delusionAssociated.compactMap { key in
                delusionAssociatedList.first { $0.0 == key }?.1
            }
            lines.append("These features were associated with \(joinWithAnd(phrases)).")
        }

        // Auditory hallucinations - grouped by severity
        let activeAuditory = auditoryHallucinations.filter { $0.value > 0 }
        if !activeAuditory.isEmpty {
            let severeAud = activeAuditory.filter { $0.value == 3 }
            let moderateAud = activeAuditory.filter { $0.value == 2 }
            let mildAud = activeAuditory.filter { $0.value == 1 }

            if !severeAud.isEmpty {
                let phrases = severeAud.keys.compactMap { key in
                    auditoryHallucinationsList.first { $0.0 == key }?.1
                }
                lines.append("Prominent hallucinatory experiences were reported, auditory phenomena including \(joinWithAnd(phrases)).")
            }
            if !moderateAud.isEmpty {
                let phrases = moderateAud.keys.compactMap { key in
                    auditoryHallucinationsList.first { $0.0 == key }?.1
                }
                if severeAud.isEmpty {
                    lines.append("Hallucinatory experiences were reported, auditory phenomena including \(joinWithAnd(phrases)).")
                } else {
                    lines.append("Moderate auditory hallucinations were also present, including \(joinWithAnd(phrases)).")
                }
            }
            if !mildAud.isEmpty {
                let phrases = mildAud.keys.compactMap { key in
                    auditoryHallucinationsList.first { $0.0 == key }?.1
                }
                if severeAud.isEmpty && moderateAud.isEmpty {
                    lines.append("Mild hallucinatory experiences were reported, auditory phenomena including \(joinWithAnd(phrases)).")
                } else {
                    lines.append("Mild auditory hallucinations were also noted, including \(joinWithAnd(phrases)).")
                }
            }
        }

        // Other hallucinations - grouped by severity
        let activeOther = otherHallucinations.filter { $0.value > 0 }
        if !activeOther.isEmpty {
            let severeOther = activeOther.filter { $0.value == 3 }
            let moderateOther = activeOther.filter { $0.value == 2 }
            let mildOther = activeOther.filter { $0.value == 1 }

            if !severeOther.isEmpty {
                let phrases = severeOther.keys.compactMap { key in
                    otherHallucinationsList.first { $0.0 == key }?.1
                }
                lines.append("\(p.Subject.capitalized) described prominent hallucinations in other modalities including \(joinWithAnd(phrases)).")
            }
            if !moderateOther.isEmpty {
                let phrases = moderateOther.keys.compactMap { key in
                    otherHallucinationsList.first { $0.0 == key }?.1
                }
                if severeOther.isEmpty {
                    lines.append("\(p.Subject.capitalized) described hallucinations in other modalities including \(joinWithAnd(phrases)).")
                } else {
                    lines.append("Moderate hallucinations were also present in other modalities including \(joinWithAnd(phrases)).")
                }
            }
            if !mildOther.isEmpty {
                let phrases = mildOther.keys.compactMap { key in
                    otherHallucinationsList.first { $0.0 == key }?.1
                }
                if severeOther.isEmpty && moderateOther.isEmpty {
                    lines.append("\(p.Subject.capitalized) described mild hallucinations in other modalities including \(joinWithAnd(phrases)).")
                } else {
                    lines.append("Mild hallucinations in other modalities were also noted, including \(joinWithAnd(phrases)).")
                }
            }
        }

        // Hallucination associated - with grouping to avoid repetition
        if !hallucinationAssociated.isEmpty {
            var phrases: [String] = []

            // Check for items that share "rather than true hallucinations" suffix
            let hasPseudohallucinations = hallucinationAssociated.contains("pseudohallucinations")
            let hasIllusions = hallucinationAssociated.contains("shadows/illusions")

            // Group pseudohallucinations and illusions if both present
            if hasPseudohallucinations && hasIllusions {
                phrases.append("pseudohallucinations and illusions rather than true hallucinations")
            } else if hasPseudohallucinations {
                phrases.append("pseudohallucinations rather than true hallucinations")
            } else if hasIllusions {
                phrases.append("illusions rather than true hallucinations")
            }

            // Add other non-grouped items
            for key in hallucinationAssociated {
                if key == "pseudohallucinations" || key == "shadows/illusions" { continue }
                if let phrase = hallucinationAssociatedList.first(where: { $0.0 == key })?.1 {
                    phrases.append(phrase)
                }
            }

            if !phrases.isEmpty {
                lines.append("These experiences were associated with \(joinWithSemicolons(phrases)).")
            }
        }

        if !additionalNotes.isEmpty {
            lines.append(additionalNotes)
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Helper Functions
    private func severityWording(_ sev: Int, domain: String) -> String {
        if domain == "del" {
            switch sev {
            case 3: return "Prominent delusional beliefs were noted"
            case 2: return "Delusional beliefs were noted"
            default: return "Mild delusional beliefs were noted"
            }
        } else {
            switch sev {
            case 3: return "Prominent hallucinatory experiences were reported"
            case 2: return "Hallucinatory experiences were reported"
            default: return "Mild hallucinatory experiences were reported"
            }
        }
    }

    private func joinWithAnd(_ items: [String]) -> String {
        guard !items.isEmpty else { return "" }
        if items.count == 1 { return items[0] }
        if items.count == 2 { return "\(items[0]) and \(items[1])" }
        return items.dropLast().joined(separator: ", ") + ", and \(items.last!)"
    }

    private func joinWithSemicolons(_ items: [String]) -> String {
        guard !items.isEmpty else { return "" }
        if items.count == 1 { return items[0] }
        if items.count == 2 { return "\(items[0]) and \(items[1])" }
        return items.dropLast().joined(separator: "; ") + "; and \(items.last!)"
    }
}

// MARK: - Psychosis Symptom Section (with severity)
struct PsychosisSymptomSection: View {
    let title: String
    let items: [(String, String)]
    @Binding var severities: [String: Int]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.purple)

            LazyVGrid(columns: [GridItem(.flexible())], spacing: 6) {
                ForEach(items, id: \.0) { (key, phrase) in
                    PsychosisSeverityButton(
                        label: key,
                        severity: severities[key] ?? 0,
                        onTap: {
                            let current = severities[key] ?? 0
                            severities[key] = (current + 1) % 4  // 0->1->2->3->0 (none->mild->mod->severe->none)
                        }
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

// MARK: - Psychosis Severity Button
struct PsychosisSeverityButton: View {
    let label: String
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
        case 2: return "Moderate"
        case 3: return "Severe"
        default: return ""
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(severity > 0 ? .primary : .secondary)

                Spacer()

                if severity > 0 {
                    Text(severityLabel)
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(severityColor)
                        .cornerRadius(4)
                }
            }
            .padding(10)
            .background(severity > 0 ? severityColor.opacity(0.15) : Color(.systemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(severity > 0 ? severityColor : Color(.systemGray4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Psychosis Associated Section (no severity)
struct PsychosisAssociatedSection: View {
    let title: String
    let items: [(String, String)]
    @Binding var selected: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.purple)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(items, id: \.0) { (key, _) in
                    Button {
                        if selected.contains(key) {
                            selected.remove(key)
                        } else {
                            selected.insert(key)
                        }
                    } label: {
                        Text(key)
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                            .padding(8)
                            .background(selected.contains(key) ? Color.purple.opacity(0.2) : Color(.systemBackground))
                            .foregroundColor(selected.contains(key) ? .purple : .primary)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(selected.contains(key) ? Color.purple : Color(.systemGray4), lineWidth: 1)
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

#Preview {
    NavigationStack {
        PsychosisPopupView()
            .environment(AppStore())
            .environment(SharedDataStore.shared)
    }
}
