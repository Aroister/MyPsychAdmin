//
//  BackgroundHistoryPopupView.swift
//  MyPsychAdmin
//
//  Comprehensive background/personal history matching desktop widget-based structure
//

import SwiftUI

// MARK: - Background History State for Persistence
struct BackgroundHistoryState: Codable {
    // Birth
    var birth: String = ""

    // Milestones
    var milestones: String = ""

    // Family History
    var familyHistory: String = ""

    // Abuse
    var abuseSeverity: String = ""
    var abuseTypes: [String] = []

    // Schooling
    var schoolingSeverity: String = ""
    var schoolingIssues: [String] = []

    // Qualifications
    var qualifications: String = ""

    // Work History
    var workHistory: String = ""

    // Sexual Orientation
    var sexualOrientation: String = ""

    // Children
    var children: String = ""

    // Relationships
    var relationships: String = ""
}

struct BackgroundHistoryPopupView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(SharedDataStore.self) private var sharedData
    @Environment(\.dismiss) private var dismiss

    // Birth options (matching desktop BirthWidget)
    private let birthOptions = [
        ("normal", "Normal"),
        ("difficult", "Difficult"),
        ("premature", "Premature"),
        ("traumatic", "Traumatic")
    ]

    // Milestones options (matching desktop MilestonesWidget)
    private let milestonesOptions = [
        ("normal", "Normal"),
        ("mildly delayed", "Mildly delayed"),
        ("moderately delayed", "Moderately delayed"),
        ("significantly delayed", "Significantly delayed"),
        ("delayed with concerns about speech", "Delayed – speech"),
        ("delayed with concerns about motor function", "Delayed – motor"),
        ("delayed with concerns about speech and motor function", "Delayed – speech & motor")
    ]

    // Family History options (matching desktop FamilyHistoryWidget)
    private let familyHistoryOptions = [
        ("none_no_alcohol", "No family psychiatric history and no alcoholism"),
        ("some_no_alcohol", "Some family mental illness, no alcoholism"),
        ("significant_no_alcohol", "Significant family mental illness, no alcoholism"),
        ("none_with_alcohol", "No family mental illness, alcoholism present"),
        ("some_with_alcohol", "Some family mental illness and alcoholism"),
        ("significant_with_alcohol", "Significant family mental illness and alcoholism")
    ]

    // Abuse severity options
    private let abuseSeverityOptions = [
        ("none", "None"),
        ("some", "Some"),
        ("significant", "Significant")
    ]

    // Abuse types
    private let abuseTypesList = ["emotional", "physical", "sexual", "neglect"]

    // Schooling severity options
    private let schoolingSeverityOptions = [
        ("none", "Unremarkable"),
        ("some", "Some issues"),
        ("significant", "Significant issues")
    ]

    // Schooling issues
    private let schoolingIssuesList = [
        ("conduct problems", "Conduct problems"),
        ("bullying", "Bullying"),
        ("truancy", "Truancy"),
        ("expulsion", "Expelled")
    ]

    // Qualifications options (matching desktop QualificationsWidget)
    private let qualificationsOptions = [
        ("none", "No formal qualifications"),
        ("basic", "Basic qualifications (e.g. GCSEs or equivalent)"),
        ("further", "Further education (e.g. A-levels, NVQ)"),
        ("degree", "Degree-level qualification"),
        ("postgrad", "Postgraduate qualification")
    ]

    // Work history options (matching desktop WorkHistoryWidget)
    private let workHistoryOptions = [
        ("never_worked", "Has never worked"),
        ("sporadic", "Sporadic employment history"),
        ("stable", "Stable employment history"),
        ("retired", "Retired"),
        ("unemployed", "Currently unemployed")
    ]

    // Sexual orientation options
    private let orientationOptions = [
        ("heterosexual", "Heterosexual"),
        ("homosexual", "Homosexual"),
        ("bisexual", "Bisexual"),
        ("other", "Other"),
        ("prefer_not_to_say", "Prefer not to say")
    ]

    // Children options (matching desktop ChildrenWidget)
    private let childrenOptions = [
        ("none", "No children"),
        ("one", "One child"),
        ("two", "Two children"),
        ("three_or_more", "Three or more children"),
        ("prefer_not_to_say", "Prefers not to discuss")
    ]

    // Relationships options (matching desktop RelationshipsWidget)
    private let relationshipsOptions = [
        ("single", "Single"),
        ("relationship", "In a relationship"),
        ("married", "Married"),
        ("civil_partnership", "Civil partnership"),
        ("divorced", "Divorced"),
        ("widowed", "Widowed"),
        ("separated", "Separated")
    ]

    @State private var birth: String = ""
    @State private var milestones: String = ""
    @State private var familyHistory: String = ""
    @State private var abuseSeverity: String = ""
    @State private var abuseTypes: Set<String> = []
    @State private var schoolingSeverity: String = ""
    @State private var schoolingIssues: Set<String> = []
    @State private var qualifications: String = ""
    @State private var workHistory: String = ""
    @State private var sexualOrientation: String = ""
    @State private var children: String = ""
    @State private var relationships: String = ""

    @State private var expandedSections: Set<String> = ["Early Development"]

    var body: some View {
        VStack(spacing: 0) {
            // Preview panel
            PreviewPanelView(content: generatedText)

            ScrollView {
                VStack(spacing: 12) {
                    // Early Development
                    HistoryCollapsibleSection(title: "Early Development", icon: "figure.child", isExpanded: expandedSections.contains("Early Development")) {
                        expandedSections.formSymmetricDifference(["Early Development"])
                    } content: {
                        VStack(alignment: .leading, spacing: 16) {
                            // Birth
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Birth")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                ForEach(birthOptions, id: \.0) { (value, label) in
                                    RadioButton(title: label, isSelected: birth == value) {
                                        birth = value
                                    }
                                }
                            }

                            Divider()

                            // Milestones
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Developmental Milestones")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                ForEach(milestonesOptions, id: \.0) { (value, label) in
                                    RadioButton(title: label, isSelected: milestones == value) {
                                        milestones = value
                                    }
                                }
                            }
                        }
                    }

                    // Family & Childhood
                    HistoryCollapsibleSection(title: "Family & Childhood", icon: "person.3", isExpanded: expandedSections.contains("Family & Childhood")) {
                        expandedSections.formSymmetricDifference(["Family & Childhood"])
                    } content: {
                        VStack(alignment: .leading, spacing: 16) {
                            // Family History
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Family History")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                ForEach(familyHistoryOptions, id: \.0) { (value, label) in
                                    RadioButton(title: label, isSelected: familyHistory == value) {
                                        familyHistory = value
                                    }
                                }
                            }

                            Divider()

                            // Childhood Abuse
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Childhood Abuse")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)

                                Text("Severity")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                ForEach(abuseSeverityOptions, id: \.0) { (value, label) in
                                    RadioButton(title: label, isSelected: abuseSeverity == value) {
                                        abuseSeverity = value
                                        if value == "none" {
                                            abuseTypes = []
                                        }
                                    }
                                }

                                if abuseSeverity != "" && abuseSeverity != "none" {
                                    Text("If present:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 4)
                                    ForEach(abuseTypesList, id: \.self) { type in
                                        Toggle(type.capitalized, isOn: Binding(
                                            get: { abuseTypes.contains(type) },
                                            set: { if $0 { abuseTypes.insert(type) } else { abuseTypes.remove(type) } }
                                        ))
                                        .font(.subheadline)
                                    }
                                }
                            }
                        }
                    }

                    // Education & Work
                    HistoryCollapsibleSection(title: "Education & Work", icon: "graduationcap", isExpanded: expandedSections.contains("Education & Work")) {
                        expandedSections.formSymmetricDifference(["Education & Work"])
                    } content: {
                        VStack(alignment: .leading, spacing: 16) {
                            // Schooling
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Schooling")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)

                                Text("Overall")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                ForEach(schoolingSeverityOptions, id: \.0) { (value, label) in
                                    RadioButton(title: label, isSelected: schoolingSeverity == value) {
                                        schoolingSeverity = value
                                        if value == "none" {
                                            schoolingIssues = []
                                        }
                                    }
                                }

                                if schoolingSeverity != "" && schoolingSeverity != "none" {
                                    Text("If present:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 4)
                                    ForEach(schoolingIssuesList, id: \.0) { (value, label) in
                                        Toggle(label, isOn: Binding(
                                            get: { schoolingIssues.contains(value) },
                                            set: { if $0 { schoolingIssues.insert(value) } else { schoolingIssues.remove(value) } }
                                        ))
                                        .font(.subheadline)
                                    }
                                }
                            }

                            Divider()

                            // Qualifications
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Qualifications")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                ForEach(qualificationsOptions, id: \.0) { (value, label) in
                                    RadioButton(title: label, isSelected: qualifications == value) {
                                        qualifications = value
                                    }
                                }
                            }

                            Divider()

                            // Work History
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Work History")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                ForEach(workHistoryOptions, id: \.0) { (value, label) in
                                    RadioButton(title: label, isSelected: workHistory == value) {
                                        workHistory = value
                                    }
                                }
                            }
                        }
                    }

                    // Identity & Relationships
                    HistoryCollapsibleSection(title: "Identity & Relationships", icon: "heart", isExpanded: expandedSections.contains("Identity & Relationships")) {
                        expandedSections.formSymmetricDifference(["Identity & Relationships"])
                    } content: {
                        VStack(alignment: .leading, spacing: 16) {
                            // Sexual Orientation
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Sexual Orientation")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                ForEach(orientationOptions, id: \.0) { (value, label) in
                                    RadioButton(title: label, isSelected: sexualOrientation == value) {
                                        sexualOrientation = value
                                    }
                                }
                            }

                            Divider()

                            // Children
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Children")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                ForEach(childrenOptions, id: \.0) { (value, label) in
                                    RadioButton(title: label, isSelected: children == value) {
                                        children = value
                                    }
                                }
                            }

                            Divider()

                            // Relationships
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Relationship Status")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                ForEach(relationshipsOptions, id: \.0) { (value, label) in
                                    RadioButton(title: label, isSelected: relationships == value) {
                                        relationships = value
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
        if let saved = appStore.loadPopupData(BackgroundHistoryState.self, for: .backgroundHistory) {
            birth = saved.birth
            milestones = saved.milestones
            familyHistory = saved.familyHistory
            abuseSeverity = saved.abuseSeverity
            abuseTypes = Set(saved.abuseTypes)
            schoolingSeverity = saved.schoolingSeverity
            schoolingIssues = Set(saved.schoolingIssues)
            qualifications = saved.qualifications
            workHistory = saved.workHistory
            sexualOrientation = saved.sexualOrientation
            children = saved.children
            relationships = saved.relationships
        }
    }

    private func saveState() {
        var state = BackgroundHistoryState()
        state.birth = birth
        state.milestones = milestones
        state.familyHistory = familyHistory
        state.abuseSeverity = abuseSeverity
        state.abuseTypes = Array(abuseTypes)
        state.schoolingSeverity = schoolingSeverity
        state.schoolingIssues = Array(schoolingIssues)
        state.qualifications = qualifications
        state.workHistory = workHistory
        state.sexualOrientation = sexualOrientation
        state.children = children
        state.relationships = relationships
        appStore.savePopupData(state, for: .backgroundHistory)

        if !generatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            appStore.updateSection(.backgroundHistory, content: generatedText)
        }
    }

    // MARK: - Text Generation (matching desktop exactly)
    private var generatedText: String {
        let p = sharedData.patientInfo.pronouns
        var paragraphs: [String] = []

        // Birth
        if !birth.isEmpty {
            let sentence: String
            switch birth {
            case "normal": sentence = "\(p.Subject.capitalized) described \(p.possessive) birth as normal."
            case "difficult": sentence = "\(p.Subject.capitalized) described \(p.possessive) birth as difficult."
            case "premature": sentence = "\(p.Subject.capitalized) \(p.bePast) born prematurely."
            case "traumatic": sentence = "\(p.Subject.capitalized) described \(p.possessive) birth as traumatic."
            default: sentence = ""
            }
            if !sentence.isEmpty { paragraphs.append(sentence) }
        }

        // Milestones
        if !milestones.isEmpty {
            let sentence: String
            switch milestones {
            case "normal": sentence = "\(p.possessive.capitalized) developmental milestones were normal."
            case "mildly delayed": sentence = "\(p.possessive.capitalized) developmental milestones were mildly delayed."
            case "moderately delayed": sentence = "\(p.possessive.capitalized) developmental milestones were moderately delayed."
            case "significantly delayed": sentence = "\(p.possessive.capitalized) developmental milestones were significantly delayed."
            case "delayed with concerns about speech": sentence = "\(p.possessive.capitalized) developmental milestones were delayed in speech."
            case "delayed with concerns about motor function": sentence = "\(p.possessive.capitalized) developmental milestones were delayed in motor development."
            case "delayed with concerns about speech and motor function": sentence = "\(p.possessive.capitalized) developmental milestones were delayed in both speech and motor development."
            default: sentence = ""
            }
            if !sentence.isEmpty { paragraphs.append(sentence) }
        }

        // Family History
        if !familyHistory.isEmpty {
            let sentence: String
            switch familyHistory {
            case "none_no_alcohol": sentence = "There is no known family history of mental illness or alcoholism."
            case "some_no_alcohol": sentence = "There is some family history of mental illness, with no history of alcoholism."
            case "significant_no_alcohol": sentence = "There is a significant family history of mental illness, with no history of alcoholism."
            case "none_with_alcohol": sentence = "There is no known family history of mental illness, but there is a history of alcoholism."
            case "some_with_alcohol": sentence = "There is some family history of mental illness and alcoholism."
            case "significant_with_alcohol": sentence = "There is a significant family history of mental illness and alcoholism."
            default: sentence = ""
            }
            if !sentence.isEmpty { paragraphs.append(sentence) }
        }

        // Abuse
        if !abuseSeverity.isEmpty {
            let sentence: String
            if abuseSeverity == "none" {
                sentence = "\(p.Subject.capitalized) described no history of childhood abuse."
            } else if abuseTypes.isEmpty {
                sentence = "\(p.Subject.capitalized) described a history of \(abuseSeverity) abuse as a child."
            } else {
                let sortedTypes = abuseTypes.sorted()
                let typesStr = joinWithAnd(sortedTypes)
                sentence = "\(p.Subject.capitalized) described a history of \(abuseSeverity) abuse as a child, specifically \(typesStr)."
            }
            paragraphs.append(sentence)
        }

        // Schooling
        if !schoolingSeverity.isEmpty {
            let sentence: String
            if schoolingSeverity == "none" {
                sentence = "Schooling was unremarkable."
            } else if schoolingIssues.isEmpty {
                sentence = "Schooling was associated with educational difficulties."
            } else {
                let sortedIssues = schoolingIssues.sorted()
                let issuesStr = sortedIssues.joined(separator: " and ")
                if schoolingSeverity == "some" {
                    sentence = "Schooling was associated with some difficulties, including \(issuesStr)."
                } else {
                    sentence = "Schooling was significantly disrupted, with \(issuesStr)."
                }
            }
            paragraphs.append(sentence)
        }

        // Qualifications
        if !qualifications.isEmpty {
            let sentence: String
            switch qualifications {
            case "none": sentence = "\(p.Subject.capitalized) \(p.havePresent) no formal qualifications."
            case "basic": sentence = "\(p.Subject.capitalized) \(p.havePresent) basic qualifications (e.g. GCSEs or equivalent)."
            case "further": sentence = "\(p.Subject.capitalized) \(p.havePresent) further education qualifications (e.g. A-levels, NVQ)."
            case "degree": sentence = "\(p.Subject.capitalized) \(p.havePresent) a degree-level qualification."
            case "postgrad": sentence = "\(p.Subject.capitalized) \(p.havePresent) a postgraduate qualification."
            default: sentence = ""
            }
            if !sentence.isEmpty { paragraphs.append(sentence) }
        }

        // Work History
        if !workHistory.isEmpty {
            let sentence: String
            switch workHistory {
            case "never_worked": sentence = "\(p.Subject.capitalized) \(p.havePresent) never worked."
            case "sporadic": sentence = "\(p.Subject.capitalized) \(p.havePresent) had sporadic employment."
            case "stable": sentence = "\(p.Subject.capitalized) \(p.havePresent) had stable employment."
            case "retired": sentence = "\(p.Subject.capitalized) \(p.bePresent) retired."
            case "unemployed": sentence = "\(p.Subject.capitalized) \(p.bePresent) currently unemployed."
            default: sentence = ""
            }
            if !sentence.isEmpty { paragraphs.append(sentence) }
        }

        // Sexual Orientation
        if !sexualOrientation.isEmpty && sexualOrientation != "prefer_not_to_say" {
            let sentence: String
            switch sexualOrientation {
            case "heterosexual": sentence = "\(p.Subject.capitalized) identifies as heterosexual."
            case "homosexual": sentence = "\(p.Subject.capitalized) identifies as homosexual."
            case "bisexual": sentence = "\(p.Subject.capitalized) identifies as bisexual."
            case "other": sentence = "\(p.Subject.capitalized) did not specify \(p.possessive) sexual orientation."
            default: sentence = ""
            }
            if !sentence.isEmpty { paragraphs.append(sentence) }
        }

        // Children
        if !children.isEmpty {
            let sentence: String
            switch children {
            case "none": sentence = "\(p.Subject.capitalized) \(p.havePresent) no children."
            case "one": sentence = "\(p.Subject.capitalized) \(p.havePresent) one child."
            case "two": sentence = "\(p.Subject.capitalized) \(p.havePresent) two children."
            case "three_or_more": sentence = "\(p.Subject.capitalized) \(p.havePresent) three or more children."
            case "prefer_not_to_say": sentence = "\(p.Subject.capitalized) preferred not to discuss children."
            default: sentence = ""
            }
            if !sentence.isEmpty { paragraphs.append(sentence) }
        }

        // Relationships
        if !relationships.isEmpty {
            let sentence: String
            switch relationships {
            case "single": sentence = "\(p.Subject.capitalized) \(p.bePresent) single."
            case "relationship": sentence = "\(p.Subject.capitalized) \(p.bePresent) in a relationship."
            case "married": sentence = "\(p.Subject.capitalized) \(p.bePresent) married."
            case "civil_partnership": sentence = "\(p.Subject.capitalized) \(p.bePresent) in a civil partnership."
            case "divorced": sentence = "\(p.Subject.capitalized) \(p.bePresent) divorced."
            case "widowed": sentence = "\(p.Subject.capitalized) \(p.bePresent) widowed."
            case "separated": sentence = "\(p.Subject.capitalized) \(p.bePresent) separated."
            default: sentence = ""
            }
            if !sentence.isEmpty { paragraphs.append(sentence) }
        }

        return paragraphs.joined(separator: " ")
    }

    private func joinWithAnd(_ items: [String]) -> String {
        guard !items.isEmpty else { return "" }
        if items.count == 1 { return items[0] }
        if items.count == 2 { return "\(items[0]) and \(items[1])" }
        return items.dropLast().joined(separator: ", ") + " and \(items.last!)"
    }
}

// MARK: - History Collapsible Section
struct HistoryCollapsibleSection<Content: View>: View {
    let title: String
    let icon: String
    let isExpanded: Bool
    let onToggle: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(.brown)
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
    }
}

// MARK: - History Text Field (kept for compatibility)
struct HistoryTextField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.roundedBorder)
        }
    }
}

#Preview {
    NavigationStack {
        BackgroundHistoryPopupView()
            .environment(AppStore())
            .environment(SharedDataStore.shared)
    }
}
