//
//  MentalStateExamPopupView.swift
//  MyPsychAdmin
//
//  Comprehensive Mental State Examination (MSE) assessment
//

import SwiftUI

// MARK: - MSE State (for persistence)
struct MSEState: Codable {
    var selectedAgeRange: String?
    var selectedEthnicity: String?
    var selectedAppearance: String?
    var selectedBehavior: String?
    var selectedSpeech: String?
    var moodObjective: Int
    var moodSubjective: Int
    var depressiveFeatures: Int
    var anxietyNormal: Bool
    var anxietySymptoms: [String]
    var thoughtsNormal: Bool
    var thoughtSymptoms: [String]
    var perceptionsNormal: Bool
    var perceptionSymptoms: [String]
    var cognitionConcern: Int
    var insightOverall: String?
    var insightRisk: String?
    var insightTreatment: String?
    var insightDiagnosis: String?
}

struct MentalStateExamPopupView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(SharedDataStore.self) private var sharedData
    @Environment(\.dismiss) private var dismiss

    // Demographics
    @State private var selectedAgeRange: String? = nil
    @State private var selectedEthnicity: String? = nil

    // Appearance
    @State private var selectedAppearance: String? = nil

    // Behavior
    @State private var selectedBehavior: String? = nil

    // Speech
    @State private var selectedSpeech: String? = nil

    // Mood (sliders)
    @State private var moodObjective: Int = 3 // Index into moodScale (normal)
    @State private var moodSubjective: Int = 3
    @State private var depressiveFeatures: Int = 0 // Index into depressionScale (nil)

    // Anxiety
    @State private var anxietyNormal: Bool = false
    @State private var anxietySymptoms: Set<String> = []

    // Thoughts
    @State private var thoughtsNormal: Bool = false
    @State private var thoughtSymptoms: Set<String> = []

    // Perceptions
    @State private var perceptionsNormal: Bool = false
    @State private var perceptionSymptoms: Set<String> = []

    // Cognition
    @State private var cognitionConcern: Int = 0 // Index into cognitionScale

    // Insight
    @State private var insightOverall: String? = nil
    @State private var insightRisk: String? = nil
    @State private var insightTreatment: String? = nil
    @State private var insightDiagnosis: String? = nil

    // Individual expanded states for each section (more stable than Set)
    @State private var demographicsExpanded = true
    @State private var appearanceExpanded = true
    @State private var behaviorExpanded = false
    @State private var speechExpanded = false
    @State private var moodExpanded = false
    @State private var anxietyExpanded = false
    @State private var thoughtsExpanded = false
    @State private var perceptionsExpanded = false
    @State private var cognitionExpanded = false
    @State private var insightExpanded = false

    // MARK: - Data Lists
    private let ageRanges = ["teenager (<20)", "early 20s", "mid/late 20s", "30s", "40s", "50s", "60s", "over 70"]

    // Check if DOB is set and calculate age range from it
    private var hasDOB: Bool {
        sharedData.patientInfo.dateOfBirth != nil
    }

    private var ageRangeFromDOB: String? {
        guard let dob = sharedData.patientInfo.dateOfBirth else { return nil }
        let age = Calendar.current.dateComponents([.year], from: dob, to: Date()).year ?? 0

        if age < 20 { return "teenager (<20)" }
        else if age < 25 { return "early 20s" }
        else if age < 30 { return "mid/late 20s" }
        else if age < 40 { return "30s" }
        else if age < 50 { return "40s" }
        else if age < 60 { return "50s" }
        else if age < 70 { return "60s" }
        else { return "over 70" }
    }

    private let ethnicities = ["Hispanic", "Caucasian", "Afro-Caribbean", "Asian", "Middle-Eastern", "Mixed-race"]

    private let appearances = [
        "well-dressed", "well-presented", "reasonably dressed", "reasonably presented",
        "mildly unkempt", "moderately dishevelled", "unkempt and dishevelled"
    ]

    private let behaviors: [(String, String)] = [
        ("appropriate", "appropriate"), ("pleasant", "pleasant"), ("drunk", "drunk"),
        ("mildly anxious", "mildly anxious"), ("moderately anxious", "moderately anxious"),
        ("very anxious", "very anxious"), ("upset", "upset"), ("irritable", "irritable"),
        ("hostile", "hostile"), ("angry", "angry at times"),
        ("intox (alc)", "likely to be intoxicated (alcohol)"),
        ("intox (cannabis)", "likely to be intoxicated (cannabis)"),
        ("withdrawn", "withdrawn"), ("normal", "normal")
    ]

    private let speeches: [(String, String)] = [
        ("normal", "normal"), ("loud", "loud"), ("tangential", "tangential"),
        ("garrulous", "garrulous"),
        ("Thought D -mania", "clearly suggestive of thought disorder (word salad, knights move thinking)"),
        ("Thought D -schizop", "clearly suggestive of thought disorder (tangential)"),
        ("slurred", "slurred")
    ]

    private let moodScale = ["very low", "low", "slightly low", "normal", "slightly high", "high", "very high"]
    private let depressionScale = ["nil", "mild", "moderate", "severe"]
    private let cognitionScale = ["nil", "slight", "mild", "moderate", "significant"]
    private let insightOptions = ["present", "partial", "absent"]

    private let anxietySymptomsList = [
        "palpitations", "breathing difficulty", "dry mouth", "sweating", "shaking",
        "chest pain/discomfort", "restlessness", "concentration issues", "irritable"
    ]

    private let thoughtSymptomsList = [
        "persecutory", "reference", "delusional perception", "somatic", "religious",
        "guilt/worthlessness", "grandiosity", "broadcast", "withdrawal", "insertion"
    ]

    private let perceptionSymptomsList = [
        "2nd person", "3rd person", "derogatory", "command", "running commentary",
        "visual", "tactile", "somatic", "olfactory/taste"
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Preview panel
            PreviewPanelView(content: generatedText)

            ScrollView {
                LazyVStack(spacing: 12) {
                    // Demographics
                    MSEBindingCollapsibleSection(title: "Demographics", isExpanded: $demographicsExpanded) {
                        VStack(alignment: .leading, spacing: 12) {
                            // Age Range - auto-set and disabled if DOB is in front page
                            if hasDOB, let ageFromDOB = ageRangeFromDOB {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Age Range (from DOB)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text(ageFromDOB)
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color(.systemGray5))
                                        .cornerRadius(8)
                                        .foregroundColor(.primary)
                                }
                            } else {
                                MSERadioGroup(title: "Age Range", options: ageRanges, selected: $selectedAgeRange)
                            }
                            MSERadioGroup(title: "Ethnicity", options: ethnicities, selected: $selectedEthnicity)
                        }
                    }

                    // Appearance
                    MSEBindingCollapsibleSection(title: "Appearance", isExpanded: $appearanceExpanded) {
                        MSERadioGroup(title: "", options: appearances, selected: $selectedAppearance)
                    }

                    // Behavior
                    MSEBindingCollapsibleSection(title: "Behavior", isExpanded: $behaviorExpanded) {
                        MSEMappedRadioGroup(title: "", options: behaviors, selected: $selectedBehavior)
                    }

                    // Speech
                    MSEBindingCollapsibleSection(title: "Speech", isExpanded: $speechExpanded) {
                        MSEMappedRadioGroup(title: "", options: speeches, selected: $selectedSpeech)
                    }

                    // Mood
                    MSEBindingCollapsibleSection(title: "Mood", isExpanded: $moodExpanded) {
                        VStack(alignment: .leading, spacing: 16) {
                            MSESliderSection(title: "Objective Mood", value: $moodObjective, labels: moodScale)
                            MSESliderSection(title: "Subjective Mood", value: $moodSubjective, labels: moodScale)
                            MSESliderSection(title: "Depressive Features", value: $depressiveFeatures, labels: depressionScale)
                        }
                    }

                    // Anxiety
                    MSEBindingCollapsibleSection(title: "Anxiety", isExpanded: $anxietyExpanded) {
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Normal (no pathological anxiety)", isOn: $anxietyNormal)
                                .onChange(of: anxietyNormal) { _, newValue in
                                    if newValue { anxietySymptoms.removeAll() }
                                }

                            if !anxietyNormal {
                                MSECheckboxGroup(options: anxietySymptomsList, selected: $anxietySymptoms)
                            }
                        }
                    }

                    // Thoughts
                    MSEBindingCollapsibleSection(title: "Thoughts", isExpanded: $thoughtsExpanded) {
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Normal", isOn: $thoughtsNormal)
                                .onChange(of: thoughtsNormal) { _, newValue in
                                    if newValue { thoughtSymptoms.removeAll() }
                                }

                            if !thoughtsNormal {
                                MSECheckboxGroup(options: thoughtSymptomsList, selected: $thoughtSymptoms)
                            }
                        }
                    }

                    // Perceptions
                    MSEBindingCollapsibleSection(title: "Perceptions", isExpanded: $perceptionsExpanded) {
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Normal (no perceptual disturbance)", isOn: $perceptionsNormal)
                                .onChange(of: perceptionsNormal) { _, newValue in
                                    if newValue { perceptionSymptoms.removeAll() }
                                }

                            if !perceptionsNormal {
                                MSECheckboxGroup(options: perceptionSymptomsList, selected: $perceptionSymptoms)
                            }
                        }
                    }

                    // Cognition
                    MSEBindingCollapsibleSection(title: "Cognition", isExpanded: $cognitionExpanded) {
                        MSESliderSection(title: "Cognitive Concern", value: $cognitionConcern, labels: cognitionScale)
                    }

                    // Insight
                    MSEBindingCollapsibleSection(title: "Insight", isExpanded: $insightExpanded) {
                        VStack(alignment: .leading, spacing: 12) {
                            MSERadioGroup(title: "Overall", options: insightOptions, selected: $insightOverall)
                            MSERadioGroup(title: "Risk", options: insightOptions, selected: $insightRisk)
                            MSERadioGroup(title: "Treatment", options: insightOptions, selected: $insightTreatment)
                            MSERadioGroup(title: "Diagnosis", options: insightOptions, selected: $insightDiagnosis)
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

    // MARK: - State Persistence
    private func loadState() {
        if let saved = appStore.loadPopupData(MSEState.self, for: .mentalStateExam) {
            selectedAgeRange = saved.selectedAgeRange
            selectedEthnicity = saved.selectedEthnicity
            selectedAppearance = saved.selectedAppearance
            selectedBehavior = saved.selectedBehavior
            selectedSpeech = saved.selectedSpeech
            moodObjective = saved.moodObjective
            moodSubjective = saved.moodSubjective
            depressiveFeatures = saved.depressiveFeatures
            anxietyNormal = saved.anxietyNormal
            anxietySymptoms = Set(saved.anxietySymptoms)
            thoughtsNormal = saved.thoughtsNormal
            thoughtSymptoms = Set(saved.thoughtSymptoms)
            perceptionsNormal = saved.perceptionsNormal
            perceptionSymptoms = Set(saved.perceptionSymptoms)
            cognitionConcern = saved.cognitionConcern
            insightOverall = saved.insightOverall
            insightRisk = saved.insightRisk
            insightTreatment = saved.insightTreatment
            insightDiagnosis = saved.insightDiagnosis
        }
    }

    private func saveState() {
        let state = MSEState(
            selectedAgeRange: selectedAgeRange,
            selectedEthnicity: selectedEthnicity,
            selectedAppearance: selectedAppearance,
            selectedBehavior: selectedBehavior,
            selectedSpeech: selectedSpeech,
            moodObjective: moodObjective,
            moodSubjective: moodSubjective,
            depressiveFeatures: depressiveFeatures,
            anxietyNormal: anxietyNormal,
            anxietySymptoms: Array(anxietySymptoms),
            thoughtsNormal: thoughtsNormal,
            thoughtSymptoms: Array(thoughtSymptoms),
            perceptionsNormal: perceptionsNormal,
            perceptionSymptoms: Array(perceptionSymptoms),
            cognitionConcern: cognitionConcern,
            insightOverall: insightOverall,
            insightRisk: insightRisk,
            insightTreatment: insightTreatment,
            insightDiagnosis: insightDiagnosis
        )
        appStore.savePopupData(state, for: .mentalStateExam)

        // Also update the section content
        if !generatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            appStore.updateSection(.mentalStateExam, content: generatedText)
        }
    }

    // MARK: - Text Generation
    private var generatedText: String {
        let p = sharedData.patientInfo.pronouns
        let subj = p.Subject
        let pos = p.Possessive
        let be = p.subject == "they" ? "were" : "was"
        let genderNoun = genderNounFromGender(sharedData.patientInfo.gender)

        var narrative: [String] = []

        // Demographics - logic depends on whether gender is defined
        // Gender defined (man/woman): "He was an Afro-Caribbean man, a teenager"
        // Gender not defined (person): "They were Hispanic, a teenager" (no article before ethnicity)
        let genderDefined = (genderNoun == "man" || genderNoun == "woman")
        var demographicParts: [String] = []

        if let ethnicity = selectedEthnicity {
            if genderDefined {
                // Include gender noun: "an Afro-Caribbean man"
                let article = ["a", "e", "i", "o", "u"].contains(String(ethnicity.first ?? " ").lowercased()) ? "an" : "a"
                demographicParts.append("\(article) \(ethnicity) \(genderNoun)")
            } else {
                // No gender noun, no article: just "Hispanic"
                demographicParts.append(ethnicity)
            }
        }

        // Add age range - prefer DOB-derived age if available
        let effectiveAge = ageRangeFromDOB ?? selectedAgeRange
        if let age = effectiveAge {
            if age.hasPrefix("teenager") {
                demographicParts.append("a teenager")
            } else if age.hasSuffix("s") || age.hasPrefix("over") {
                // For "20s", "30s", etc.
                if demographicParts.isEmpty {
                    // No ethnicity - include gender noun: "a man in his 30s"
                    demographicParts.append("a \(genderNoun) in \(p.possessive) \(age)")
                } else {
                    // Ethnicity already included gender if defined: "in his 30s"
                    demographicParts.append("in \(p.possessive) \(age)")
                }
            }
        } else if demographicParts.isEmpty {
            // No age, no ethnicity - just use gender noun with article
            demographicParts.append("a \(genderNoun)")
        }

        if !demographicParts.isEmpty {
            let description = demographicParts.joined(separator: ", ")
            narrative.append("\(subj) \(be) \(description).")
        }

        // Appearance
        if let appearance = selectedAppearance {
            narrative.append("\(subj) \(be) \(appearance).")
        }

        // Behavior
        if let behavior = selectedBehavior {
            let phrase = behaviors.first { $0.0 == behavior }?.1 ?? behavior
            narrative.append("In terms of behaviour, \(p.Subject.lowercased()) \(be) \(phrase).")
        }

        // Speech
        if let speech = selectedSpeech {
            let phrase = speeches.first { $0.0 == speech }?.1 ?? speech
            narrative.append("\(pos) speech was \(phrase).")
        }

        // Mood
        let objMood = moodScale[moodObjective]
        let subjMood = moodScale[moodSubjective]
        if objMood == subjMood {
            narrative.append("Mood was objectively and subjectively \(objMood).")
        } else {
            narrative.append("Mood was objectively \(objMood) and subjectively \(subjMood).")
        }

        let dep = depressionScale[depressiveFeatures]
        if dep != "nil" {
            narrative.append("There were \(dep) depressive features.")
        }

        // Anxiety
        if anxietyNormal {
            narrative.append("There was no evidence of pathological anxiety.")
        } else if !anxietySymptoms.isEmpty {
            let transformed = transformAnxietySymptoms(Array(anxietySymptoms))
            narrative.append("\(subj) reported anxiety symptoms, including \(joinWithAnd(transformed)).")
        }

        // Thoughts
        if thoughtsNormal {
            narrative.append("\(pos) thoughts were normal.")
        } else if !thoughtSymptoms.isEmpty {
            let transformed = transformThoughtSymptoms(Array(thoughtSymptoms))
            narrative.append("\(pos) thoughts were characterised by \(joinWithAnd(transformed)).")
        }

        // Perceptions
        if perceptionsNormal {
            narrative.append("There was no evidence of perceptual disturbance.")
        } else if !perceptionSymptoms.isEmpty {
            narrative.append("\(subj) reported \(joinWithAnd(Array(perceptionSymptoms))) hallucinations.")
        }

        // Cognition
        let cog = cognitionScale[cognitionConcern]
        if cog == "nil" {
            narrative.append("Cognition was broadly intact and not assessed clinically.")
        } else {
            narrative.append("Cognition was of \(cog) concern and requires further assessment.")
        }

        // Insight
        if let overall = insightOverall {
            var insightSentence = "Insight was \(overall) overall"

            var qualifiers: [(String, String)] = []
            if let risk = insightRisk { qualifiers.append(("risk", risk)) }
            if let treatment = insightTreatment { qualifiers.append(("treatment", treatment)) }
            if let diagnosis = insightDiagnosis { qualifiers.append(("diagnosis", diagnosis)) }

            if !qualifiers.isEmpty {
                let grouped = Dictionary(grouping: qualifiers, by: { $0.1 })
                var qualifierPhrases: [String] = []
                for (value, items) in grouped {
                    let categories = items.map { $0.0 }
                    qualifierPhrases.append("insight into \(joinWithAnd(categories)) being \(value)")
                }
                insightSentence += ", with \(joinWithAnd(qualifierPhrases))"
            }

            narrative.append(insightSentence + ".")
        }

        return narrative.joined(separator: " ")
    }

    // MARK: - Helper Functions
    private func genderNounFromGender(_ gender: Gender) -> String {
        switch gender {
        case .male: return "man"
        case .female: return "woman"
        case .other, .notSpecified: return "person"
        }
    }

    private func transformAnxietySymptoms(_ symptoms: [String]) -> [String] {
        symptoms.map { symptom in
            switch symptom {
            case "irritable": return "being irritable"
            default: return symptom
            }
        }
    }

    private func transformThoughtSymptoms(_ thoughts: [String]) -> [String] {
        let delusionTransforms = [
            "persecutory": "persecutory delusions",
            "reference": "delusions of reference",
            "delusional perception": "delusional perceptions",
            "somatic": "somatic delusions",
            "religious": "religious delusions",
            "guilt/worthlessness": "delusions of guilt/worthlessness",
            "grandiosity": "grandiose delusions"
        ]

        let thoughtInterference = Set(["broadcast", "withdrawal", "insertion"])
        var result: [String] = []
        var tiItems: [String] = []

        for t in thoughts {
            if thoughtInterference.contains(t) {
                tiItems.append(t)
            } else if let transformed = delusionTransforms[t] {
                result.append(transformed)
            } else {
                result.append(t)
            }
        }

        if !tiItems.isEmpty {
            if tiItems.count == 1 {
                result.append("delusions of thought \(tiItems[0])")
            } else {
                result.append("delusions of thought \(joinWithAnd(tiItems))")
            }
        }

        return result
    }

    private func joinWithAnd(_ items: [String]) -> String {
        guard !items.isEmpty else { return "" }
        if items.count == 1 { return items[0] }
        if items.count == 2 { return "\(items[0]) and \(items[1])" }
        return items.dropLast().joined(separator: ", ") + ", and \(items.last!)"
    }
}

// MARK: - MSE Binding Collapsible Section (stable during scroll)
struct MSEBindingCollapsibleSection<Content: View>: View {
    let title: String
    @Binding var isExpanded: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            Button {
                isExpanded.toggle()
            } label: {
                HStack {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray5))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)

            if isExpanded {
                content()
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
        }
        .animation(.none, value: isExpanded) // Prevent animation-related collapse
    }
}

// MARK: - MSE Radio Group
struct MSERadioGroup: View {
    let title: String
    let options: [String]
    @Binding var selected: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !title.isEmpty {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            FlowLayout(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    Button {
                        selected = selected == option ? nil : option
                    } label: {
                        Text(option)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(selected == option ? Color.indigo.opacity(0.2) : Color(.systemBackground))
                            .foregroundColor(selected == option ? .indigo : .primary)
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(selected == option ? Color.indigo : Color(.systemGray4), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - MSE Mapped Radio Group
struct MSEMappedRadioGroup: View {
    let title: String
    let options: [(String, String)]
    @Binding var selected: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !title.isEmpty {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            FlowLayout(spacing: 8) {
                ForEach(options, id: \.0) { (key, _) in
                    Button {
                        selected = selected == key ? nil : key
                    } label: {
                        Text(key)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(selected == key ? Color.indigo.opacity(0.2) : Color(.systemBackground))
                            .foregroundColor(selected == key ? .indigo : .primary)
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(selected == key ? Color.indigo : Color(.systemGray4), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - MSE Slider Section
struct MSESliderSection: View {
    let title: String
    @Binding var value: Int
    let labels: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                Spacer()
                Text(labels[value])
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Slider(value: Binding(
                get: { Double(value) },
                set: { value = Int($0) }
            ), in: 0...Double(labels.count - 1), step: 1)
            .tint(.indigo)
        }
    }
}

// MARK: - MSE Checkbox Group
struct MSECheckboxGroup: View {
    let options: [String]
    @Binding var selected: Set<String>

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(options, id: \.self) { option in
                Button {
                    if selected.contains(option) {
                        selected.remove(option)
                    } else {
                        selected.insert(option)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: selected.contains(option) ? "checkmark.square.fill" : "square")
                            .font(.caption)
                        Text(option)
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(selected.contains(option) ? Color.indigo.opacity(0.15) : Color(.systemBackground))
                    .foregroundColor(selected.contains(option) ? .indigo : .primary)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(selected.contains(option) ? Color.indigo : Color(.systemGray4), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    NavigationStack {
        MentalStateExamPopupView()
            .environment(AppStore())
            .environment(SharedDataStore.shared)
    }
}
