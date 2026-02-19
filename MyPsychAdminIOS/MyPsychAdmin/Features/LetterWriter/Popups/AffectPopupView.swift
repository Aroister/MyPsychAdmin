//
//  AffectPopupView.swift
//  MyPsychAdmin
//
//  Affect assessment matching desktop version - clickable rows with mini editors
//

import SwiftUI

// MARK: - Affect State for Persistence
struct AffectState: Codable {
    var values: [String: (value: Double, details: String)] = [:]

    enum CodingKeys: String, CodingKey {
        case valuesList
    }

    struct ValueEntry: Codable {
        let key: String
        let value: Double
        let details: String
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let list = try container.decode([ValueEntry].self, forKey: .valuesList)
        values = Dictionary(uniqueKeysWithValues: list.map { ($0.key, ($0.value, $0.details)) })
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let list = values.map { ValueEntry(key: $0.key, value: $0.value.0, details: $0.value.1) }
        try container.encode(list, forKey: .valuesList)
    }
}

struct AffectPopupView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(SharedDataStore.self) private var sharedData
    @Environment(\.dismiss) private var dismiss

    // Symptom values and details
    @State private var values: [String: (value: Double, details: String)] = [:]

    // Section expansion
    @State private var expandedSection: String? = "Depressive Features"

    // Mini editor state
    @State private var showingEditor = false
    @State private var editingLabel: String = ""
    @State private var editingValue: Double = 50
    @State private var editingDetails: String = ""
    @State private var editorIsMania: Bool = false

    // Depressive symptom labels
    private let depressiveLabels = [
        "Mood", "Energy", "Anhedonia", "Sleep", "Appetite", "Libido",
        "Self-esteem", "Concentration", "Guilt",
        "Hopelessness / Helplessness", "Suicidal thoughts"
    ]

    // Manic symptom labels
    private let maniaLabels = [
        "Heightened perception", "Psychomotor activity",
        "Pressure of speech", "Disinhibition",
        "Distractibility", "Irritability", "Overspending"
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Preview panel
            PreviewPanelView(content: generatedText)

            // Diagnosis box
            HStack {
                Image(systemName: diagnosisIcon)
                Text(computedDiagnosis)
                    .fontWeight(.semibold)
            }
            .font(.subheadline)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.teal)
            .cornerRadius(8)
            .padding()

            // Symptom sections
            ScrollView {
                VStack(spacing: 12) {
                    // Depressive Features
                    AffectCollapsibleSection(
                        title: "Depressive Features",
                        isExpanded: expandedSection == "Depressive Features",
                        onToggle: { expandedSection = expandedSection == "Depressive Features" ? nil : "Depressive Features" }
                    ) {
                        VStack(spacing: 2) {
                            ForEach(depressiveLabels, id: \.self) { label in
                                AffectRowItem(
                                    label: label,
                                    isModified: isRowModified(label)
                                ) {
                                    openEditor(label: label, isMania: false)
                                }
                            }
                        }
                    }

                    // Manic Features
                    AffectCollapsibleSection(
                        title: "Manic Features",
                        isExpanded: expandedSection == "Manic Features",
                        onToggle: { expandedSection = expandedSection == "Manic Features" ? nil : "Manic Features" }
                    ) {
                        VStack(spacing: 2) {
                            ForEach(maniaLabels, id: \.self) { label in
                                AffectRowItem(
                                    label: label,
                                    isModified: isRowModified(label)
                                ) {
                                    openEditor(label: label, isMania: true)
                                }
                            }
                        }
                    }
                }
                .padding()
                .padding(.bottom, 20)
            }
        }
        .sheet(isPresented: $showingEditor) {
            MiniAffectEditor(
                label: editingLabel,
                value: $editingValue,
                details: $editingDetails,
                isMania: editorIsMania,
                onSave: saveEditorValue
            )
            .presentationDetents([.medium])
        }
        .onAppear { loadState() }
        .onDisappear { saveState() }
    }

    // MARK: - Row Helpers
    private func isRowModified(_ label: String) -> Bool {
        guard let entry = values[label] else { return false }
        if !entry.details.trimmingCharacters(in: .whitespaces).isEmpty { return true }
        // Mania: any click marks as modified
        if maniaLabels.contains(label) { return true }
        // Depression: check if non-neutral
        return entry.value < 45 || entry.value > 55
    }

    private func openEditor(label: String, isMania: Bool) {
        editingLabel = label
        editorIsMania = isMania
        let entry = values[label] ?? (isMania ? 0 : 50, "")
        editingValue = entry.value
        editingDetails = entry.details
        showingEditor = true
    }

    private func saveEditorValue() {
        values[editingLabel] = (editingValue, editingDetails)
        showingEditor = false
    }

    // MARK: - State Persistence
    private func loadState() {
        if let saved = appStore.loadPopupData(AffectState.self, for: .affect) {
            values = saved.values
        }
    }

    private func saveState() {
        var state = AffectState()
        state.values = values
        appStore.savePopupData(state, for: .affect)

        if !generatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            appStore.updateSection(.affect, content: generatedText)
        }
    }

    // MARK: - Diagnosis Computation
    private var computedDiagnosis: String {
        // Calculate depressive and manic scores
        var depScore: Double = 0
        var depSymptoms = 0
        var manicScore: Double = 0
        var manicSymptoms = 0

        let LOW_THRESH: Double = 40
        let HIGH_THRESH: Double = 60

        // Depressive scoring
        if let mood = values["Mood"]?.value, mood < LOW_THRESH {
            depScore += (LOW_THRESH - mood) * 2
            depSymptoms += 1
        } else if let mood = values["Mood"]?.value, mood > HIGH_THRESH {
            manicScore += (mood - HIGH_THRESH) * 2
            manicSymptoms += 1
        }

        if let energy = values["Energy"]?.value, energy < LOW_THRESH {
            depScore += (LOW_THRESH - energy) * 2
            depSymptoms += 1
        } else if let energy = values["Energy"]?.value, energy > HIGH_THRESH {
            manicScore += (energy - HIGH_THRESH) * 2
            manicSymptoms += 1
        }

        if let anhedonia = values["Anhedonia"]?.value, anhedonia > HIGH_THRESH {
            depScore += (anhedonia - HIGH_THRESH) * 2
            depSymptoms += 1
        }

        if let concentration = values["Concentration"]?.value, concentration < LOW_THRESH {
            depScore += (LOW_THRESH - concentration)
            depSymptoms += 1
        }

        if let selfEsteem = values["Self-esteem"]?.value, selfEsteem < LOW_THRESH {
            depScore += (LOW_THRESH - selfEsteem)
            depSymptoms += 1
        } else if let selfEsteem = values["Self-esteem"]?.value, selfEsteem > HIGH_THRESH {
            manicScore += (selfEsteem - HIGH_THRESH)
            manicSymptoms += 1
        }

        if let guilt = values["Guilt"]?.value, guilt > HIGH_THRESH {
            depScore += (guilt - HIGH_THRESH)
            depSymptoms += 1
        }

        if let hopelessness = values["Hopelessness / Helplessness"]?.value, hopelessness > HIGH_THRESH {
            depScore += (hopelessness - HIGH_THRESH)
            depSymptoms += 1
        }

        if let suicidal = values["Suicidal thoughts"]?.value, suicidal > HIGH_THRESH {
            depScore += (suicidal - HIGH_THRESH) * 1.5
            depSymptoms += 1
        }

        // Manic symptom scoring
        for label in maniaLabels {
            if let val = values[label]?.value, val > 33 {
                manicScore += val
                manicSymptoms += 1
            }
        }

        // Normalize
        depScore = min(depScore, 100)
        manicScore = min(manicScore, 100)

        let totalScore = depScore + manicScore
        if totalScore < 15 {
            return "No significant mood disturbance"
        }

        let depSignificant = depScore >= 25 && depSymptoms >= 2
        let manicSignificant = manicScore >= 25 && manicSymptoms >= 2

        // Mixed states
        if depSignificant && manicSignificant {
            if depScore > manicScore * 1.5 {
                return "Mixed: Depressive episode with manic features"
            } else if manicScore > depScore * 1.5 {
                return "Mixed: Manic/hypomanic with depressive features"
            } else {
                return "Mixed affective episode (F38.0)"
            }
        }

        // Pure manic
        if manicSignificant && !depSignificant {
            if manicScore >= 70 && manicSymptoms >= 5 {
                return "Manic episode, severe (F30.1)"
            } else if manicScore >= 50 && manicSymptoms >= 4 {
                return "Manic episode (F30.1)"
            } else if manicScore >= 30 && manicSymptoms >= 3 {
                return "Hypomanic episode (F30.0)"
            } else {
                return "Subthreshold hypomanic features"
            }
        }

        // Pure depressive
        if depSignificant && !manicSignificant {
            if depScore >= 70 {
                return "Severe depressive episode (F32.2)"
            } else if depScore >= 50 && depSymptoms >= 5 {
                return "Moderate depressive episode (F32.1)"
            } else if depScore >= 25 && depSymptoms >= 3 {
                return "Mild depressive episode (F32.0)"
            } else {
                return "Subthreshold depressive features"
            }
        }

        if manicSymptoms >= 2 && manicScore >= 15 {
            return "Subthreshold hypomanic features"
        }
        if depSymptoms >= 2 && depScore >= 15 {
            return "Subthreshold depressive features"
        }

        return "No clear mood episode identified"
    }

    private var diagnosisIcon: String {
        let diag = computedDiagnosis.lowercased()
        if diag.contains("mixed") { return "arrow.up.arrow.down" }
        if diag.contains("manic") || diag.contains("hypomanic") { return "arrow.up.circle" }
        if diag.contains("depressive") { return "arrow.down.circle" }
        return "checkmark.circle"
    }

    // MARK: - Text Generation (matching desktop)
    private var generatedText: String {
        let p = sharedData.patientInfo.pronouns

        // Helper to get bucket from value
        func bucket(for value: Double, isMania: Bool) -> String {
            if isMania {
                if value <= 33 { return "mild" }
                else if value <= 66 { return "moderate" }
                else { return "severe" }
            } else {
                if value <= 10 { return "vlow" }
                else if value <= 25 { return "low" }
                else if value <= 40 { return "mild_low" }
                else if value <= 60 { return "normal" }
                else if value <= 70 { return "mild_high" }
                else if value <= 85 { return "high" }
                else { return "vhigh" }
            }
        }

        // Generate text for a single symptom
        func scaleText(label: String, value: Double) -> String? {
            let b = bucket(for: value, isMania: maniaLabels.contains(label))
            let subj = p.Subject
            let pos = p.possessive
            let bePast = p.bePast

            switch label {
            case "Mood":
                switch b {
                case "vlow": return "\(subj.capitalized) felt very low in mood."
                case "low": return "\(subj.capitalized) felt low in mood."
                case "mild_low": return "\(subj.capitalized) felt mildly low in mood."
                case "normal": return "Mood was normal."
                case "mild_high": return "\(subj.capitalized) felt slightly elevated in mood."
                case "high": return "\(pos.capitalized) mood was elevated."
                case "vhigh": return "\(pos.capitalized) mood was significantly elevated."
                default: return nil
                }
            case "Energy":
                switch b {
                case "vlow": return "\(subj.capitalized) had very low energy."
                case "low": return "\(subj.capitalized) had low energy."
                case "mild_low": return "\(subj.capitalized) had mildly reduced energy."
                case "normal": return "Energy was normal."
                case "mild_high": return "\(subj.capitalized) had slightly increased energy."
                case "high": return "\(subj.capitalized) had increased energy."
                case "vhigh": return "\(subj.capitalized) had significantly increased energy."
                default: return nil
                }
            case "Anhedonia":
                switch b {
                case "normal", "low", "vlow", "mild_low": return "There was no anhedonia."
                case "mild_high": return "\(subj.capitalized) reported mild anhedonia."
                case "high": return "\(subj.capitalized) reported moderate anhedonia."
                case "vhigh": return "\(subj.capitalized) reported significant anhedonia."
                default: return "There was no anhedonia."
                }
            case "Sleep":
                switch b {
                case "vlow": return "Sleep was very poor."
                case "low": return "Sleep was poor."
                case "mild_low": return "Sleep was mildly disrupted."
                case "normal": return "Sleep was normal."
                case "mild_high": return "\(subj.capitalized) \(bePast) sleeping slightly more than usual."
                case "high": return "\(subj.capitalized) \(bePast) sleeping significantly more than usual."
                case "vhigh": return "\(subj.capitalized) described excessive oversleeping."
                default: return nil
                }
            case "Appetite":
                switch b {
                case "vlow": return "\(pos.capitalized) appetite was very poor."
                case "low": return "\(pos.capitalized) appetite was poor."
                case "mild_low": return "\(subj.capitalized) \(bePast) eating less than normal."
                case "normal": return "Appetite was normal."
                case "mild_high": return "\(subj.capitalized) \(bePast) eating more than normal."
                case "high": return "\(subj.capitalized) \(bePast) moderately overeating."
                case "vhigh": return "\(subj.capitalized) \(bePast) significantly overeating."
                default: return nil
                }
            case "Libido":
                switch b {
                case "vlow": return "\(pos.capitalized) sex drive was absent."
                case "low": return "\(pos.capitalized) sex drive was significantly reduced."
                case "mild_low": return "\(pos.capitalized) sex drive was mildly reduced."
                case "normal": return "Sex drive was normal."
                case "mild_high": return "\(pos.capitalized) sex drive was mildly increased."
                case "high": return "\(pos.capitalized) sex drive was significantly increased."
                case "vhigh": return "\(subj.capitalized) described excessively increased sex drive."
                default: return nil
                }
            case "Self-esteem":
                switch b {
                case "vlow": return "Self-esteem was very low."
                case "low": return "Self-esteem was low."
                case "mild_low": return "Self-esteem was mildly reduced."
                case "normal": return "Self-esteem was normal."
                case "mild_high": return "Self-esteem was slightly increased."
                case "high": return "Self-esteem was increased."
                case "vhigh": return "Self-esteem was significantly increased."
                default: return nil
                }
            case "Concentration":
                switch b {
                case "vlow": return "\(subj.capitalized) reported complete inability to concentrate."
                case "low": return "\(subj.capitalized) reported significant difficulty concentrating."
                case "mild_low": return "\(pos.capitalized) concentration was mildly disturbed."
                case "normal": return "Concentration was normal."
                case "mild_high": return "\(pos.capitalized) concentration was above normal."
                case "high": return "\(subj.capitalized) reported significantly increased concentration."
                case "vhigh": return "\(subj.capitalized) reported very high levels of concentration."
                default: return nil
                }
            case "Guilt":
                switch b {
                case "normal", "low", "vlow", "mild_low": return "There were no feelings of guilt."
                case "mild_high": return "\(subj.capitalized) had some feelings of guilt."
                case "high": return "\(subj.capitalized) had moderate feelings of guilt."
                case "vhigh": return "\(subj.capitalized) had overwhelming feelings of guilt."
                default: return "There were no feelings of guilt."
                }
            case "Hopelessness / Helplessness":
                switch b {
                case "normal", "low", "vlow", "mild_low": return "There were no feelings of hopelessness."
                case "mild_high": return "\(subj.capitalized) had some feelings of hopelessness."
                case "high": return "\(subj.capitalized) had moderate feelings of hopelessness."
                case "vhigh": return "\(subj.capitalized) had overwhelming feelings of hopelessness."
                default: return "There were no feelings of hopelessness."
                }
            case "Suicidal thoughts":
                switch b {
                case "normal", "low", "vlow", "mild_low": return "There were no suicidal thoughts."
                case "mild_high": return "\(subj.capitalized) reported fleeting suicidal thoughts."
                case "high": return "\(subj.capitalized) reported moderate suicidal thoughts."
                case "vhigh": return "\(subj.capitalized) reported overwhelming suicidal thoughts."
                default: return "There were no suicidal thoughts."
                }
            // Mania symptoms
            case "Heightened perception":
                switch b {
                case "mild": return "\(subj.capitalized) reported mildly increased perception."
                case "moderate": return "\(subj.capitalized) reported moderately increased perception."
                case "severe": return "\(subj.capitalized) reported severely increased perception."
                default: return nil
                }
            case "Psychomotor activity":
                switch b {
                case "mild": return "There was mild increase in psychomotor activity."
                case "moderate": return "There was moderate increase in psychomotor activity."
                case "severe": return "There was severe increase in psychomotor activity."
                default: return nil
                }
            case "Pressure of speech":
                switch b {
                case "mild": return "\(subj.capitalized) reported mild pressure of speech."
                case "moderate": return "\(subj.capitalized) reported moderate pressure of speech."
                case "severe": return "\(subj.capitalized) reported severe pressure of speech."
                default: return nil
                }
            case "Disinhibition":
                switch b {
                case "mild": return "There was mild disinhibition."
                case "moderate": return "There was moderate disinhibition."
                case "severe": return "There was severe disinhibition."
                default: return nil
                }
            case "Distractibility":
                switch b {
                case "mild": return "There was mild distractibility."
                case "moderate": return "There was moderate distractibility."
                case "severe": return "There was severe distractibility."
                default: return nil
                }
            case "Irritability":
                switch b {
                case "mild": return "There was mild irritability."
                case "moderate": return "There was moderate irritability."
                case "severe": return "There was severe irritability."
                default: return nil
                }
            case "Overspending":
                switch b {
                case "mild": return "There was mild overspending."
                case "moderate": return "There was moderate overspending."
                case "severe": return "There was severe overspending."
                default: return nil
                }
            default:
                return nil
            }
        }

        // Build depressive text grouped by category
        let core = ["Mood", "Energy", "Anhedonia"]
        let somatic = ["Sleep", "Appetite", "Libido"]
        let cognitive = ["Self-esteem", "Concentration"]
        let risk = ["Guilt", "Hopelessness / Helplessness", "Suicidal thoughts"]

        func isNormal(_ text: String?) -> Bool {
            guard let t = text else { return false }
            return t.contains("was normal") || t.contains("were normal") || t.contains("no anhedonia")
        }

        func lc(_ s: String) -> String {
            guard !s.isEmpty else { return s }
            return s.prefix(1).lowercased() + s.dropFirst()
        }

        // Get all depressive raw texts - strip periods for joining
        var depRaw: [String: String?] = [:]
        for label in depressiveLabels {
            if let entry = values[label] {
                var text = scaleText(label: label, value: entry.value)
                // Always strip trailing period
                if var t = text {
                    t = t.trimmingCharacters(in: CharacterSet(charactersIn: "."))
                    if !entry.details.isEmpty {
                        t += ", \(entry.details)"
                    }
                    text = t
                }
                depRaw[label] = text
            } else {
                var text = scaleText(label: label, value: 50) // Default normal
                text = text?.trimmingCharacters(in: CharacterSet(charactersIn: "."))
                depRaw[label] = text
            }
        }

        // Core sentence
        let coreNormal = core.filter { isNormal(depRaw[$0] ?? nil) }
        let coreAbnormal = core.filter { depRaw[$0] != nil && !isNormal(depRaw[$0]!) }

        var coreSentence: String
        if !coreAbnormal.isEmpty {
            var parts: [String] = []
            if coreAbnormal.contains("Mood"), let text = depRaw["Mood"] ?? nil {
                parts.append(lc(text))
            }
            for label in coreAbnormal where label != "Mood" {
                if let text = depRaw[label] ?? nil {
                    parts.append(lc(text))
                }
            }
            for label in coreNormal {
                if label == "Anhedonia" {
                    parts.append("there was no anhedonia")
                } else {
                    parts.append("\(label.lowercased()) was normal")
                }
            }
            coreSentence = "Regarding depression, " + parts.joined(separator: ", ") + "."
        } else {
            if Set(coreNormal) == Set(core) {
                coreSentence = "Regarding depression, mood and energy were normal and there was no anhedonia."
            } else {
                var parts: [String] = []
                for label in coreNormal {
                    if label == "Anhedonia" {
                        parts.append("there was no anhedonia")
                    } else {
                        parts.append("\(label.lowercased()) was normal")
                    }
                }
                coreSentence = "Regarding depression, " + parts.joined(separator: ", ") + "."
            }
        }

        // Somatic sentence
        let somaticNormal = somatic.filter { isNormal(depRaw[$0] ?? nil) }
        let somaticAbnormal = somatic.filter { depRaw[$0] != nil && !isNormal(depRaw[$0]!) }

        var somSentence = ""
        if !somaticAbnormal.isEmpty {
            var parts = somaticAbnormal.compactMap { depRaw[$0] ?? nil }.map { lc($0) }
            if !somaticNormal.isEmpty {
                let normalJoined = joinNormalItems(somaticNormal)
                parts.append("whilst \(normalJoined)")
            }
            somSentence = "; " + parts.joined(separator: ", ") + "."
        } else if somaticNormal.count == 3 {
            somSentence = "; sleep, appetite and sex drive were all normal."
        } else if !somaticNormal.isEmpty {
            somSentence = "; " + joinNormalItems(somaticNormal) + "."
        }

        // Cognitive sentence
        let cogNormal = cognitive.filter { isNormal(depRaw[$0] ?? nil) }
        let cogAbnormal = cognitive.filter { depRaw[$0] != nil && !isNormal(depRaw[$0]!) }

        var cogSentence = ""
        if !cogAbnormal.isEmpty {
            var parts = cogAbnormal.compactMap { depRaw[$0] ?? nil }.map { lc($0) }
            if !cogNormal.isEmpty {
                parts.append("and \(joinNormalItems(cogNormal))")
            }
            cogSentence = "; " + parts.joined(separator: ", ") + "."
        } else if cogNormal.count == 2 {
            cogSentence = "; self-esteem and concentration were normal."
        } else if !cogNormal.isEmpty {
            cogSentence = "; \(cogNormal[0].lowercased()) was normal."
        }

        // Risk sentence
        let riskNormal = risk.filter { isNormal(depRaw[$0] ?? nil) }
        let riskAbnormal = risk.filter { depRaw[$0] != nil && !isNormal(depRaw[$0]!) }

        var riskSentence = ""
        if !riskAbnormal.isEmpty {
            let texts = riskAbnormal.compactMap { depRaw[$0] ?? nil }.map { lc($0) }
            if texts.count == 1 {
                riskSentence = "; \(texts[0])."
            } else if texts.count == 2 {
                riskSentence = "; \(texts[0]), and \(texts[1])."
            } else {
                riskSentence = "; \(texts.dropLast().joined(separator: ", ")), and \(texts.last!)."
            }
        } else if riskNormal.count == 3 {
            riskSentence = "; no feelings of guilt, hopelessness or suicidal thoughts."
        } else if !riskNormal.isEmpty {
            var items: [String] = []
            for label in riskNormal {
                if label.contains("Guilt") { items.append("no feelings of guilt") }
                else if label.contains("Hopelessness") { items.append("no feelings of hopelessness") }
                else { items.append("no suicidal thoughts") }
            }
            if items.count > 1 {
                riskSentence = "; \(items.dropLast().joined(separator: ", ")) and \(items.last!)."
            } else {
                riskSentence = "; \(items[0])."
            }
        }

        // Combine depressive paragraph
        var depParagraph = coreSentence.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        for s in [somSentence, cogSentence, riskSentence] {
            if !s.isEmpty {
                depParagraph += s.trimmingCharacters(in: CharacterSet(charactersIn: "."))
            }
        }
        depParagraph += "."

        // Mania paragraph - group by severity
        var severeSymptoms: [String] = []
        var moderateSymptoms: [String] = []
        var mildSymptoms: [String] = []

        let symptomNames: [String: String] = [
            "Heightened perception": "heightened perception",
            "Psychomotor activity": "increased psychomotor activity",
            "Pressure of speech": "pressure of speech",
            "Disinhibition": "disinhibition",
            "Distractibility": "distractibility",
            "Irritability": "irritability",
            "Overspending": "overspending"
        ]

        for label in maniaLabels {
            guard let entry = values[label] else { continue }
            let name = symptomNames[label] ?? label.lowercased()
            if entry.value <= 33 {
                mildSymptoms.append(name)
            } else if entry.value <= 66 {
                moderateSymptoms.append(name)
            } else {
                severeSymptoms.append(name)
            }
        }

        func joinSymptoms(_ symptoms: [String]) -> String {
            if symptoms.count == 1 { return symptoms[0] }
            if symptoms.count == 2 { return "\(symptoms[0]) and \(symptoms[1])" }
            return symptoms.dropLast().joined(separator: ", ") + " and \(symptoms.last!)"
        }

        var maniaParts: [String] = []
        if !severeSymptoms.isEmpty { maniaParts.append("\(joinSymptoms(severeSymptoms)) (severe)") }
        if !moderateSymptoms.isEmpty { maniaParts.append("\(joinSymptoms(moderateSymptoms)) (moderate)") }
        if !mildSymptoms.isEmpty { maniaParts.append("\(joinSymptoms(mildSymptoms)) (mild)") }

        var maniaParagraph: String
        if !maniaParts.isEmpty {
            if maniaParts.count == 1 {
                maniaParagraph = "Regarding mania, there was \(maniaParts[0])."
            } else {
                maniaParagraph = "Regarding mania, there was \(maniaParts.dropLast().joined(separator: ", ")), and \(maniaParts.last!)."
            }
        } else {
            maniaParagraph = "No manic symptoms were present."
        }

        return depParagraph + "\n\n" + maniaParagraph
    }

    private func joinNormalItems(_ items: [String]) -> String {
        let mapped = items.map { item -> String in
            if item == "Libido" { return "sex drive" }
            return item.lowercased()
        }
        if mapped.count == 1 { return "\(mapped[0]) was normal" }
        if mapped.count == 2 { return "\(mapped[0]) and \(mapped[1]) were normal" }
        return mapped.dropLast().joined(separator: ", ") + " and \(mapped.last!) were normal"
    }
}

// MARK: - Affect Collapsible Section
struct AffectCollapsibleSection<Content: View>: View {
    let title: String
    let isExpanded: Bool
    let onToggle: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { onToggle() } }) {
                HStack {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.teal)
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
                    .padding(.vertical, 4)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
        }
    }
}

// MARK: - Affect Row Item
struct AffectRowItem: View {
    let label: String
    let isModified: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(label)
                    .font(.system(size: 17))
                    .foregroundColor(.teal)
                Spacer()
                if isModified {
                    Circle()
                        .fill(.teal)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(isModified ? .teal.opacity(0.15) : Color.clear)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Mini Affect Editor
struct MiniAffectEditor: View {
    let label: String
    @Binding var value: Double
    @Binding var details: String
    let isMania: Bool
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showDetails = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Title
                Text(label)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.teal)

                // Scale labels
                HStack {
                    Text(isMania ? "Mild" : "Low")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(isMania ? "Moderate" : "Normal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(isMania ? "Severe" : "High")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)

                // Slider
                Slider(value: $value, in: 0...100)
                    .tint(.teal)
                    .padding(.horizontal)

                // Details toggle
                Button {
                    withAnimation { showDetails.toggle() }
                } label: {
                    HStack {
                        Text("Add details")
                        Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                    }
                    .font(.subheadline)
                    .foregroundColor(.teal)
                }

                if showDetails {
                    TextEditor(text: $details)
                        .frame(height: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                        .padding(.horizontal)
                }

                Spacer()

                // Save button
                Button {
                    onSave()
                    dismiss()
                } label: {
                    Text("Save & Close")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.teal)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Shared Components for Popups

// MARK: - Preview Panel View (shared across popups)
struct PreviewPanelView: View {
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(.gray)
                Text("Preview")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray)
                Spacer()
            }

            ScrollView {
                Text(content.isEmpty ? "Select options below to generate clinical text..." : content)
                    .font(.system(size: 14))
                    .foregroundColor(content.isEmpty ? .gray : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 150)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        .padding(.horizontal)
    }
}

// MARK: - Collapsible Symptom Section (used by Anxiety, Psychosis popups)
struct CollapsibleSymptomSection<Content: View>: View {
    let title: String
    let isExpanded: Bool
    let onToggle: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
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
        .padding(.horizontal)
    }
}

// MARK: - Bidirectional Symptom Slider (low to high)
struct BidirectionalSymptomSlider: View {
    let label: String
    @Binding var value: Double
    var lowLabel: String = "Low"
    var highLabel: String = "High"

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text(severityText)
                    .font(.caption)
                    .foregroundColor(severityColor)
            }

            HStack {
                Text(lowLabel)
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Slider(value: $value, in: 0...100)
                    .tint(severityColor)

                Text(highLabel)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var severityText: String {
        if value < 20 { return "Very \(lowLabel.lowercased())" }
        if value < 40 { return lowLabel }
        if value < 60 { return "Normal" }
        if value < 80 { return highLabel }
        return "Very \(highLabel.lowercased())"
    }

    private var severityColor: Color {
        if value < 30 || value > 70 { return .red }
        if value < 40 || value > 60 { return .orange }
        return .green
    }
}

// MARK: - Unidirectional Symptom Slider (absent to severe)
struct UnidirectionalSymptomSlider: View {
    let label: String
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text(severityText)
                    .font(.caption)
                    .foregroundColor(severityColor)
            }

            HStack {
                Text("Absent")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Slider(value: $value, in: 0...100)
                    .tint(severityColor)

                Text("Severe")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var severityText: String {
        if value < 10 { return "Absent" }
        if value < 30 { return "Mild" }
        if value < 60 { return "Moderate" }
        return "Severe"
    }

    private var severityColor: Color {
        if value < 10 { return .green }
        if value < 30 { return .yellow }
        if value < 60 { return .orange }
        return .red
    }
}

#Preview {
    NavigationStack {
        AffectPopupView()
            .environment(AppStore())
            .environment(SharedDataStore.shared)
    }
}
