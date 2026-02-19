//
//  RiskExtractor.swift
//  MyPsychAdmin
//
//  Risk extraction service matching desktop app's risk_overview_panel.py
//  Extracts and categorizes risk indicators from clinical notes
//

import Foundation
import SwiftUI

// MARK: - Risk Severity
enum RiskSeverity: String, CaseIterable, Comparable {
    case low = "LOW"
    case medium = "MEDIUM"
    case high = "HIGH"

    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }

    var points: Int {
        switch self {
        case .low: return 1
        case .medium: return 3
        case .high: return 5
        }
    }

    static func < (lhs: RiskSeverity, rhs: RiskSeverity) -> Bool {
        lhs.points < rhs.points
    }
}

// MARK: - Overall Risk Level (Assessment)
enum OverallRiskLevel: String, CaseIterable {
    case low = "LOW"
    case moderate = "MODERATE"
    case high = "HIGH"
    case critical = "CRITICAL"

    var color: Color {
        switch self {
        case .low: return .green
        case .moderate: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }

    var icon: String {
        switch self {
        case .low: return "checkmark.shield"
        case .moderate: return "exclamationmark.shield"
        case .high: return "exclamationmark.triangle"
        case .critical: return "exclamationmark.octagon"
        }
    }

    var recommendation: String {
        switch self {
        case .low: return "Standard observation"
        case .moderate: return "Enhanced awareness, increased observation frequency"
        case .high: return "Increase observation, consider 1:1, de-escalation plan"
        case .critical: return "Immediate 1:1 observation, senior staff alert"
        }
    }
}

// MARK: - Risk Category
enum RiskCategory: String, CaseIterable, Identifiable {
    case verbalAggression = "Verbal Aggression"
    case physicalAggression = "Physical Aggression"
    case propertyDamage = "Property Damage"
    case selfHarm = "Self-Harm"
    case sexualBehaviour = "Sexual Behaviour"
    case bullyingExploitation = "Bullying/Exploitation"
    case selfNeglect = "Self-Neglect"
    case awolAbsconding = "AWOL/Absconding"
    case substanceMisuse = "Substance Misuse"
    case nonCompliance = "Non-Compliance"
    case suicidalIdeation = "Suicidal Ideation"
    case paranoia = "Paranoia/Delusions"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .verbalAggression: return "speaker.wave.3"
        case .physicalAggression: return "hand.raised.slash"
        case .propertyDamage: return "hammer"
        case .selfHarm: return "bandage"
        case .sexualBehaviour: return "exclamationmark.shield"
        case .bullyingExploitation: return "person.2.slash"
        case .selfNeglect: return "person.crop.circle.badge.minus"
        case .awolAbsconding: return "figure.walk.departure"
        case .substanceMisuse: return "pills"
        case .nonCompliance: return "xmark.circle"
        case .suicidalIdeation: return "heart.slash"
        case .paranoia: return "brain.head.profile"
        }
    }

    var color: Color {
        switch self {
        case .verbalAggression: return Color(red: 0.62, green: 0.62, blue: 0.62) // #9E9E9E
        case .physicalAggression: return Color(red: 0.72, green: 0.11, blue: 0.11) // #b71c1c
        case .propertyDamage: return Color(red: 0.90, green: 0.22, blue: 0.21) // #e53935
        case .selfHarm: return Color(red: 1.0, green: 0.34, blue: 0.13) // #ff5722
        case .sexualBehaviour: return Color(red: 0.0, green: 0.74, blue: 0.83) // #00BCD4
        case .bullyingExploitation: return Color(red: 0.47, green: 0.33, blue: 0.28) // #795548
        case .selfNeglect: return Color(red: 0.38, green: 0.49, blue: 0.55) // #607d8b
        case .awolAbsconding: return Color(red: 0.96, green: 0.49, blue: 0.0) // #f57c00
        case .substanceMisuse: return Color(red: 0.61, green: 0.15, blue: 0.69) // #9c27b0
        case .nonCompliance: return Color(red: 0.86, green: 0.15, blue: 0.15) // #dc2626
        case .suicidalIdeation: return Color(red: 0.55, green: 0.0, blue: 0.0) // Dark red
        case .paranoia: return Color(red: 0.4, green: 0.2, blue: 0.6) // Purple
        }
    }
}

// MARK: - Risk Subcategory
struct RiskSubcategory: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let category: RiskCategory
    let severity: RiskSeverity
    let patterns: [String]

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(category)
    }

    static func == (lhs: RiskSubcategory, rhs: RiskSubcategory) -> Bool {
        lhs.name == rhs.name && lhs.category == rhs.category
    }
}

// MARK: - Risk Incident
struct RiskIncident: Identifiable {
    let id = UUID()
    let date: Date
    let category: RiskCategory
    let subcategory: String
    let severity: RiskSeverity
    let matchedText: String
    let context: String
    let noteId: UUID
}

// MARK: - Extracted Risks
struct ExtractedRisks {
    var incidents: [RiskIncident] = []
    var totalScore: Int = 0
    var riskLevel: OverallRiskLevel = .low

    var incidentsByCategory: [RiskCategory: [RiskIncident]] {
        Dictionary(grouping: incidents) { $0.category }
    }

    var highSeverityCount: Int {
        incidents.filter { $0.severity == .high }.count
    }

    var categoriesAffected: Int {
        Set(incidents.map { $0.category }).count
    }

    var dateRange: (start: Date, end: Date)? {
        guard !incidents.isEmpty else { return nil }
        let dates = incidents.map { $0.date }
        return (dates.min()!, dates.max()!)
    }

    func incidents(for category: RiskCategory) -> [RiskIncident] {
        incidents.filter { $0.category == category }
    }

    func subcategories(for category: RiskCategory) -> [String] {
        Array(Set(incidents.filter { $0.category == category }.map { $0.subcategory })).sorted()
    }
}

// MARK: - Compiled Pattern (for pre-compiled regex)
private struct CompiledSubcategory {
    let name: String
    let category: RiskCategory
    let severity: RiskSeverity
    let regexes: [NSRegularExpression]
}

// MARK: - Risk Extractor
class RiskExtractor {
    static let shared = RiskExtractor()

    private let subcategories: [RiskSubcategory]
    private let protectivePatterns: [(pattern: String, points: Int)]
    private let falsePositivePatterns: [String]

    // Pre-compiled regexes for performance
    private let compiledSubcategories: [CompiledSubcategory]
    private let compiledFalsePositives: [NSRegularExpression]
    private let compiledProtective: [(regex: NSRegularExpression, points: Int)]

    private init() {
        subcategories = Self.buildSubcategories()
        protectivePatterns = Self.buildProtectivePatterns()
        falsePositivePatterns = Self.buildFalsePositivePatterns()

        // Pre-compile all regex patterns once
        compiledSubcategories = subcategories.map { sub in
            CompiledSubcategory(
                name: sub.name,
                category: sub.category,
                severity: sub.severity,
                regexes: sub.patterns.compactMap { try? NSRegularExpression(pattern: $0, options: .caseInsensitive) }
            )
        }

        compiledFalsePositives = falsePositivePatterns.compactMap {
            try? NSRegularExpression(pattern: $0, options: .caseInsensitive)
        }

        compiledProtective = protectivePatterns.compactMap { (pattern, points) in
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
            return (regex, points)
        }

        print("[RiskExtractor] Pre-compiled \(compiledSubcategories.count) subcategories, \(compiledFalsePositives.count) false positives, \(compiledProtective.count) protective patterns")
    }

    // MARK: - Subcategory Definitions
    private static func buildSubcategories() -> [RiskSubcategory] {
        var subs: [RiskSubcategory] = []

        // Verbal Aggression
        subs.append(RiskSubcategory(name: "Racial Abuse", category: .verbalAggression, severity: .high, patterns: [
            "racial\\s*(abuse|slur)", "racist\\s*(comment|remark|language)", "called.*\\b(n[i*]gger|p[a*]ki|ch[i*]nk)\\b"
        ]))
        subs.append(RiskSubcategory(name: "Sexual/Homophobic Slurs", category: .verbalAggression, severity: .high, patterns: [
            "homophobic\\s*(slur|abuse|comment)", "sexual\\s*slur", "called.*\\b(f[a*]ggot|dyke|queer)\\b"
        ]))
        subs.append(RiskSubcategory(name: "Direct Insults", category: .verbalAggression, severity: .medium, patterns: [
            "call(ed|ing)\\s+(staff|them|him|her)?\\s*.{0,15}(cunt|bitch|bastard|idiot|stupid|wanker)",
            "name[\\s-]?calling", "insult(ed|ing)\\s+(staff|patient|peer)"
        ]))
        subs.append(RiskSubcategory(name: "Swearing At Staff", category: .verbalAggression, severity: .medium, patterns: [
            "swear(ing)?\\s+(at|towards)\\s+(staff|nurse|hca|doctor)",
            "\\bf[u*]ck\\s+(off|you)\\b", "told\\s+.{0,10}fuck\\s+off"
        ]))
        subs.append(RiskSubcategory(name: "Verbal Abuse", category: .verbalAggression, severity: .medium, patterns: [
            "verbal(ly)?\\s*abuse", "verbally\\s*aggressive", "\\babusive\\s*(language|behaviour|toward)"
        ]))
        subs.append(RiskSubcategory(name: "Shouting", category: .verbalAggression, severity: .low, patterns: [
            "\\bshout(ing|ed)?\\b", "\\byell(ing|ed)?\\b", "raised\\s+(his|her)\\s+voice"
        ]))
        subs.append(RiskSubcategory(name: "Threatening Language", category: .verbalAggression, severity: .high, patterns: [
            "threaten(ed|ing)?\\s+(to|staff|patient)", "made\\s+threats?",
            "going\\s+to\\s+(kill|hurt|harm|stab|punch)", "verbal\\s*threats?"
        ]))
        subs.append(RiskSubcategory(name: "Spitting", category: .verbalAggression, severity: .high, patterns: [
            "\\bspit(ting)?\\s+(at|on|toward)", "\\bspat\\s+(at|on|toward)"
        ]))
        subs.append(RiskSubcategory(name: "Intimidation", category: .verbalAggression, severity: .high, patterns: [
            "\\bintimidati(ng|on)\\b", "attempt(ed|ing)?\\s+to\\s+intimidate",
            "\\bmenacing\\b", "\\bthreatening\\s+(manner|stance|posture)"
        ]))

        // Physical Aggression
        subs.append(RiskSubcategory(name: "Assault on Staff", category: .physicalAggression, severity: .high, patterns: [
            "assault(ed)?\\s+(a\\s+)?(staff|nurse|hca|doctor)",
            "(punch|kick|hit|slap|struck|attack)\\w*\\s+(a\\s+)?(staff|nurse|hca|doctor)",
            "physical(ly)?\\s+assault(ed)?\\s+staff"
        ]))
        subs.append(RiskSubcategory(name: "Assault on Peer", category: .physicalAggression, severity: .high, patterns: [
            "assault(ed)?\\s+(a\\s+)?(patient|peer|resident|other)",
            "(punch|kick|hit|slap|attack)\\w*\\s+(a\\s+)?(patient|peer|resident|another)"
        ]))
        subs.append(RiskSubcategory(name: "Physical Aggression", category: .physicalAggression, severity: .high, patterns: [
            "physical(ly)?\\s+aggress(ive|ion)", "\\bviolent\\b", "\\bviolence\\b",
            "physic(al)?\\s+altercation"
        ]))
        subs.append(RiskSubcategory(name: "Restraint Required", category: .physicalAggression, severity: .high, patterns: [
            "\\brestraint\\b", "\\brestrained\\b", "required\\s+restraint",
            "physical\\s+intervention", "control\\s+and\\s+restraint"
        ]))
        subs.append(RiskSubcategory(name: "Attempted Violence", category: .physicalAggression, severity: .medium, patterns: [
            "attempt(ed|ing)?\\s+to\\s+(punch|kick|hit|strike|attack|assault)",
            "tried\\s+to\\s+(punch|kick|hit|strike|attack)"
        ]))
        subs.append(RiskSubcategory(name: "Use of Weapon/Object", category: .physicalAggression, severity: .high, patterns: [
            "weapon", "used\\s+(a\\s+)?(knife|blade|scissors|object)\\s+(to|as)",
            "armed\\s+with", "brandish(ed|ing)?\\s+(a\\s+)?(knife|object)"
        ]))

        // Property Damage
        subs.append(RiskSubcategory(name: "Breaking Items", category: .propertyDamage, severity: .medium, patterns: [
            "broke\\s+(the|a|his|her)", "broken\\s+(window|door|furniture|item)",
            "smash(ed|ing)?\\s+(the|a|his|her)", "destroy(ed|ing)?\\s+(property|item|furniture)"
        ]))
        subs.append(RiskSubcategory(name: "Punching/Kicking Objects", category: .propertyDamage, severity: .medium, patterns: [
            "punch(ed|ing)?\\s+(the\\s+)?(wall|door|window|furniture)",
            "kick(ed|ing)?\\s+(the\\s+)?(wall|door|furniture)"
        ]))
        subs.append(RiskSubcategory(name: "Throwing Objects", category: .propertyDamage, severity: .medium, patterns: [
            "threw\\s+(a\\s+)?(object|item|chair|cup|plate)",
            "throw(ing)?\\s+(object|item|furniture)", "thrown\\s+objects?"
        ]))
        subs.append(RiskSubcategory(name: "Room Destruction", category: .propertyDamage, severity: .high, patterns: [
            "trashed\\s+(his|her|the)?\\s*room", "destroy(ed|ing)?\\s+(his|her)?\\s*room",
            "room\\s+(was\\s+)?destroyed", "ransack(ed|ing)?\\s+(his|her)?\\s*room"
        ]))

        // Self-Harm
        subs.append(RiskSubcategory(name: "Cutting", category: .selfHarm, severity: .high, patterns: [
            "(he|she|patient|resident)\\s+(cut|cuts|cutting)\\s+(his|her)\\s+(arm|wrist|leg|body|skin|face)",
            "(slash|slashing|slashed)\\s+(his|her)\\s+(wrist|arm)",
            "self[\\s-]?cut\\w*", "superficial\\s+cut(s|ting)?", "lacerat(ion|ed)\\s+(to|on)\\s+(arm|wrist|leg)"
        ]))
        subs.append(RiskSubcategory(name: "Head Banging", category: .selfHarm, severity: .high, patterns: [
            "bang(ing|ed)?\\s+(his|her)\\s+head", "head[\\s-]?bang(ing)?",
            "hit(ting)?\\s+(his|her)\\s+head\\s+(against|on)"
        ]))
        subs.append(RiskSubcategory(name: "Hitting Self", category: .selfHarm, severity: .high, patterns: [
            "hit(ting)?\\s+(himself|herself)", "punch(ing|ed)?\\s+(himself|herself)",
            "self[\\s-]?(hit|punch|strike)"
        ]))
        subs.append(RiskSubcategory(name: "Ligature", category: .selfHarm, severity: .high, patterns: [
            "\\bligature\\b", "ligature\\s+(attempt|found|applied|around)",
            "tied\\s+(something|cord|sheet|item)\\s+around\\s+(his|her)\\s+(neck|throat)",
            "attempted\\s+hanging", "found\\s+with\\s+ligature"
        ]))
        subs.append(RiskSubcategory(name: "Overdose", category: .selfHarm, severity: .high, patterns: [
            "\\boverdose\\b", "took\\s+(an\\s+)?overdose",
            "ingested\\s+(excess|multiple|too\\s+many)\\s+(tablets|pills|medication)",
            "intentional\\s+overdose"
        ]))
        subs.append(RiskSubcategory(name: "Self-Harm Threat", category: .selfHarm, severity: .medium, patterns: [
            "threaten(ed|ing)?\\s+to\\s+(self[\\s-]?harm|cut|hurt\\s+(himself|herself))",
            "stated\\s+(he|she)\\s+(would|will)\\s+(self[\\s-]?harm|cut)"
        ]))
        subs.append(RiskSubcategory(name: "Self-Harm Act", category: .selfHarm, severity: .high, patterns: [
            "self[\\s-]?harm(ed|ing)?", "episode\\s+of\\s+self[\\s-]?harm",
            "engag(ed|ing)\\s+in\\s+self[\\s-]?harm", "deliberate\\s+self[\\s-]?harm"
        ]))

        // Sexual Behaviour
        subs.append(RiskSubcategory(name: "Sexual Comments", category: .sexualBehaviour, severity: .medium, patterns: [
            "sexual(ly)?\\s+(inappropriate\\s+)?comment", "inappropriate\\s+sexual",
            "made\\s+sexual\\s+(remark|comment|advance)"
        ]))
        subs.append(RiskSubcategory(name: "Sexual Touching", category: .sexualBehaviour, severity: .high, patterns: [
            "sexual(ly)?\\s+touch(ed|ing)?", "inappropriate(ly)?\\s+touch(ed|ing)?",
            "groped?", "touch(ed|ing)?\\s+(staff|patient)\\s+(inappropriate|sexually)"
        ]))
        subs.append(RiskSubcategory(name: "Exposure", category: .sexualBehaviour, severity: .high, patterns: [
            "expos(ed|ing)\\s+(himself|herself)", "indecent\\s+exposure",
            "flash(ed|ing)\\s+(staff|patient)"
        ]))
        subs.append(RiskSubcategory(name: "Public Masturbation", category: .sexualBehaviour, severity: .high, patterns: [
            "masturbat(ing|ed|ion)?\\s+(in\\s+)?(public|communal|shared)",
            "found\\s+masturbating", "openly\\s+masturbating"
        ]))
        subs.append(RiskSubcategory(name: "Walking Naked", category: .sexualBehaviour, severity: .high, patterns: [
            "walk(ing|ed)?\\s+(around\\s+)?naked", "found\\s+naked\\s+(in\\s+)?(corridor|communal)",
            "\\bnude\\s+in\\s+(public|communal)"
        ]))
        subs.append(RiskSubcategory(name: "Sexual Disinhibition", category: .sexualBehaviour, severity: .medium, patterns: [
            "sexual(ly)?\\s+disinhibit(ed|ion)", "disinhibit(ed|ion)\\s+sexual"
        ]))

        // Bullying/Exploitation
        subs.append(RiskSubcategory(name: "Bullying Peer", category: .bullyingExploitation, severity: .high, patterns: [
            "bully(ing|ied)?\\s+(a\\s+)?(patient|peer|resident|other)",
            "\\bbully\\b", "bullying\\s+behaviour"
        ]))
        subs.append(RiskSubcategory(name: "Targeting Vulnerable", category: .bullyingExploitation, severity: .high, patterns: [
            "target(ing|ed)?\\s+(vulnerable|weaker|elderly)",
            "pick(ing|ed)?\\s+on\\s+(vulnerable|weaker)"
        ]))
        subs.append(RiskSubcategory(name: "Taking Items", category: .bullyingExploitation, severity: .medium, patterns: [
            "taking\\s+(items?|belongings?)\\s+from\\s+(patient|peer|other)",
            "stole\\s+from\\s+(patient|peer)", "stealing\\s+from\\s+(patient|peer)"
        ]))
        subs.append(RiskSubcategory(name: "Financial Exploitation", category: .bullyingExploitation, severity: .high, patterns: [
            "financial(ly)?\\s+exploit(ing|ed|ation)?", "taking\\s+money\\s+from",
            "extort(ing|ed|ion)?", "demand(ing|ed)?\\s+money"
        ]))
        subs.append(RiskSubcategory(name: "Coercion", category: .bullyingExploitation, severity: .high, patterns: [
            "\\bcoerci(on|ng|ve)\\b", "coercing\\s+(patient|peer)",
            "pressur(ing|ed)\\s+(patient|peer)\\s+to"
        ]))

        // Self-Neglect
        subs.append(RiskSubcategory(name: "Unkempt Appearance", category: .selfNeglect, severity: .medium, patterns: [
            "\\bunkempt\\b", "dishevelled", "poor\\s+(personal\\s+)?hygiene",
            "neglect(ing|ed)?\\s+(his|her)\\s+(appearance|hygiene)"
        ]))
        subs.append(RiskSubcategory(name: "Dirty Clothes", category: .selfNeglect, severity: .medium, patterns: [
            "dirty\\s+(clothes|clothing)", "soiled\\s+(clothes|clothing)",
            "wear(ing)?\\s+same\\s+(clothes|clothing)\\s+for"
        ]))
        subs.append(RiskSubcategory(name: "Body Odour", category: .selfNeglect, severity: .medium, patterns: [
            "body\\s+odour", "\\bBO\\b", "malodorous", "smell(ing|s)?\\s+(bad|unpleasant)"
        ]))
        subs.append(RiskSubcategory(name: "Refused Self-Care", category: .selfNeglect, severity: .medium, patterns: [
            "refus(ed|ing)?\\s+(to\\s+)?(wash|shower|bathe|self[\\s-]?care)",
            "declined\\s+(to\\s+)?(wash|shower|bathe)"
        ]))
        subs.append(RiskSubcategory(name: "Poor Dietary Intake", category: .selfNeglect, severity: .medium, patterns: [
            "poor\\s+(dietary\\s+)?intake", "not\\s+eating", "refus(ed|ing)?\\s+(to\\s+)?eat",
            "minimal\\s+(food\\s+)?intake", "poor\\s+appetite"
        ]))

        // AWOL/Absconding
        subs.append(RiskSubcategory(name: "AWOL", category: .awolAbsconding, severity: .high, patterns: [
            "\\bAWOL\\b", "absent\\s+without\\s+leave", "went\\s+AWOL"
        ]))
        subs.append(RiskSubcategory(name: "Failed to Return", category: .awolAbsconding, severity: .medium, patterns: [
            "fail(ed)?\\s+to\\s+return", "did\\s+not\\s+return\\s+(from|after)\\s+leave",
            "late\\s+return(ing)?\\s+from\\s+leave"
        ]))
        subs.append(RiskSubcategory(name: "Escape Attempt", category: .awolAbsconding, severity: .high, patterns: [
            "attempt(ed|ing)?\\s+to\\s+(escape|abscond|leave\\s+without)",
            "tried\\s+to\\s+(escape|abscond)", "\\babscond(ed|ing)?\\b"
        ]))

        // Substance Misuse
        subs.append(RiskSubcategory(name: "Positive Drug Test", category: .substanceMisuse, severity: .high, patterns: [
            "positive\\s+(drug\\s+)?test", "tested\\s+positive\\s+for",
            "UDS\\s+positive", "urine\\s+(drug\\s+)?screen\\s+positive"
        ]))
        subs.append(RiskSubcategory(name: "Smelling of Substances", category: .substanceMisuse, severity: .medium, patterns: [
            "smell(ing|s|ed)?\\s+of\\s+(alcohol|cannabis|marijuana|weed)",
            "odour\\s+of\\s+(alcohol|cannabis)"
        ]))
        subs.append(RiskSubcategory(name: "Appeared Intoxicated", category: .substanceMisuse, severity: .high, patterns: [
            "\\bintoxicated\\b", "appear(ed|s)?\\s+(to\\s+be\\s+)?(drunk|intoxicated|under\\s+the\\s+influence)",
            "\\bdrunk\\b", "slurred\\s+speech"
        ]))
        subs.append(RiskSubcategory(name: "Admitted Substance Use", category: .substanceMisuse, severity: .high, patterns: [
            "admit(ted|s)?\\s+(to\\s+)?(using|taking|smoking)",
            "disclosed\\s+(substance|drug|alcohol)\\s+use"
        ]))
        subs.append(RiskSubcategory(name: "Found with Substances", category: .substanceMisuse, severity: .high, patterns: [
            "found\\s+with\\s+(drugs?|substances?|contraband|cannabis|cocaine)",
            "discovered\\s+(drugs?|substances?)\\s+(in|on)"
        ]))

        // Non-Compliance
        subs.append(RiskSubcategory(name: "Refused Medication", category: .nonCompliance, severity: .medium, patterns: [
            "refus(ed|ing)?\\s+(his|her|to\\s+take)?\\s*(medication|meds|tablets)",
            "declined\\s+(medication|meds)", "non[\\s-]?compliant\\s+with\\s+(medication|meds)"
        ]))
        subs.append(RiskSubcategory(name: "Non-Compliance", category: .nonCompliance, severity: .medium, patterns: [
            "non[\\s-]?complian(t|ce)", "not\\s+compliant", "refus(ed|ing)?\\s+to\\s+(comply|cooperate)"
        ]))
        subs.append(RiskSubcategory(name: "Refused to Engage", category: .nonCompliance, severity: .low, patterns: [
            "refus(ed|ing)?\\s+to\\s+engage", "declined\\s+(to\\s+)?engage",
            "not\\s+engaging", "poor\\s+engagement"
        ]))

        // Suicidal Ideation
        subs.append(RiskSubcategory(name: "Suicidal Thoughts", category: .suicidalIdeation, severity: .high, patterns: [
            "suicid(al|e)\\s+(ideation|thought|idea)", "thought(s)?\\s+of\\s+suicide",
            "thinking\\s+(about|of)\\s+(suicide|ending|killing)",
            "express(ed|ing)?\\s+suicidal"
        ]))
        subs.append(RiskSubcategory(name: "Suicide Plan", category: .suicidalIdeation, severity: .high, patterns: [
            "suicide\\s+plan", "plan(s|ning)?\\s+to\\s+(end|kill|commit)",
            "has\\s+(a\\s+)?plan\\s+to\\s+(end|kill)"
        ]))
        subs.append(RiskSubcategory(name: "Suicide Attempt", category: .suicidalIdeation, severity: .high, patterns: [
            "suicide\\s+attempt", "attempt(ed)?\\s+(suicide|to\\s+(end|kill))",
            "tried\\s+to\\s+(kill|end)\\s+(himself|herself|their\\s+life)"
        ]))
        subs.append(RiskSubcategory(name: "Wish to Die", category: .suicidalIdeation, severity: .high, patterns: [
            "wish(es)?\\s+to\\s+(die|be\\s+dead)", "want(s)?\\s+to\\s+(die|be\\s+dead)",
            "doesn't\\s+want\\s+to\\s+live", "life\\s+not\\s+worth\\s+living"
        ]))

        // Paranoia/Delusions
        subs.append(RiskSubcategory(name: "Paranoid Ideation", category: .paranoia, severity: .medium, patterns: [
            "\\bparanoi(a|d)\\b", "paranoid\\s+(ideation|thought|belief)",
            "believ(es|ing)?\\s+(someone|people|they)\\s+(are|is)\\s+(watching|following|plotting)"
        ]))
        subs.append(RiskSubcategory(name: "Persecutory Delusions", category: .paranoia, severity: .high, patterns: [
            "persecutory\\s+delusion", "believ(es|ing)?\\s+(staff|people)\\s+(are|want)\\s+(to|trying)",
            "delusion(al)?\\s+belief"
        ]))
        subs.append(RiskSubcategory(name: "Responding to Voices", category: .paranoia, severity: .high, patterns: [
            "respond(ing)?\\s+to\\s+(internal\\s+)?stimuli", "responding\\s+to\\s+voice(s)?",
            "appear(s|ed)?\\s+to\\s+be\\s+hallucinating", "command\\s+hallucination"
        ]))

        return subs
    }

    // MARK: - Protective Patterns (reduce score)
    private static func buildProtectivePatterns() -> [(pattern: String, points: Int)] {
        return [
            ("complian(t|ce)\\s+with\\s+(all\\s+)?(his|her|their)?\\s*med", -3),
            ("engag(ed|ing)?\\s+well", -2),
            ("(calm|settled|pleasant|cooperative)", -2),
            ("good\\s+(appetite|sleep|engagement)", -2),
            ("no\\s+(concerns?|issues?|incidents?|aggression|violence)", -3),
            ("slept\\s+well", -1),
            ("eating\\s+well", -1),
            ("stable\\s+mood", -2),
            ("no\\s+thoughts?\\s+of\\s+(self[\\s-]?harm|suicide)", -3),
            ("denies\\s+(suicid|self[\\s-]?harm|harm)", -2)
        ]
    }

    // MARK: - False Positive Patterns
    private static func buildFalsePositivePatterns() -> [String] {
        return [
            "(was|were|has|had|have)\\s+not\\s+(been\\s+)?(physically\\s+)?",
            "no\\s+(aggression|violence|incident|concerns?)",
            "(risk\\s+of|at\\s+risk\\s+of|risk\\s+assessment)",
            "(potential|possibility)\\s+(of|for)",
            "(history\\s+of|past\\s+history|previous)",
            "discussed\\s+(risk|self[\\s-]?harm|suicide)",
            "no\\s+evidence\\s+of",
            "nil\\s+(self[\\s-]?harm|aggression|violence)",
            "not\\s+(expressed|reported|disclosed)"
        ]
    }

    // MARK: - Main Extraction
    func extractRisks(from notes: [ClinicalNote]) -> ExtractedRisks {
        var incidents: [RiskIncident] = []
        var protectivePoints = 0

        for note in notes {
            let text = note.body.lowercased()
            let nsRange = NSRange(text.startIndex..., in: text)

            // Check for false positives first (using pre-compiled regex)
            var skipRegions: [Range<String.Index>] = []
            for regex in compiledFalsePositives {
                for match in regex.matches(in: text, range: nsRange) {
                    if let range = Range(match.range, in: text) {
                        skipRegions.append(range)
                    }
                }
            }

            // Extract risk incidents (using pre-compiled regex)
            for compiled in compiledSubcategories {
                for regex in compiled.regexes {
                    for match in regex.matches(in: text, range: nsRange) {
                        guard let range = Range(match.range, in: text) else { continue }

                        // Skip if in false positive region
                        let isInFalsePositive = skipRegions.contains { fpRange in
                            fpRange.overlaps(range) ||
                            (text.distance(from: fpRange.lowerBound, to: range.lowerBound) >= 0 &&
                             text.distance(from: fpRange.lowerBound, to: range.lowerBound) < 50)
                        }
                        if isInFalsePositive { continue }

                        let matchedText = String(text[range])

                        // Check if this match is negated (desktop parity)
                        if isNegated(text: text, matchRange: range, keyword: matchedText) {
                            continue
                        }

                        let context = extractContext(text: note.body, range: range)

                        let incident = RiskIncident(
                            date: note.date,
                            category: compiled.category,
                            subcategory: compiled.name,
                            severity: compiled.severity,
                            matchedText: matchedText,
                            context: context,
                            noteId: note.id
                        )
                        incidents.append(incident)
                    }
                }
            }

            // Calculate protective points (using pre-compiled regex)
            for (regex, points) in compiledProtective {
                let matchCount = regex.numberOfMatches(in: text, range: nsRange)
                protectivePoints += matchCount * points
            }
        }

        // Remove duplicates (same category+subcategory+date)
        var seen: Set<String> = []
        incidents = incidents.filter { incident in
            let key = "\(incident.category.rawValue)-\(incident.subcategory)-\(Calendar.current.startOfDay(for: incident.date))"
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }

        // Sort by date (newest first)
        incidents.sort { $0.date > $1.date }

        // Calculate total score
        let rawScore = incidents.reduce(0) { $0 + $1.severity.points }
        let totalScore = max(0, rawScore + protectivePoints)

        // Determine risk level
        let riskLevel: OverallRiskLevel
        if totalScore <= 8 {
            riskLevel = .low
        } else if totalScore <= 15 {
            riskLevel = .moderate
        } else if totalScore <= 24 {
            riskLevel = .high
        } else {
            riskLevel = .critical
        }

        return ExtractedRisks(incidents: incidents, totalScore: totalScore, riskLevel: riskLevel)
    }

    // MARK: - Extract Context
    private func extractContext(text: String, range: Range<String.Index>) -> String {
        let startOffset = text.distance(from: text.startIndex, to: range.lowerBound)
        let endOffset = text.distance(from: text.startIndex, to: range.upperBound)

        let contextStart = max(0, startOffset - 50)
        let contextEnd = min(text.count, endOffset + 50)

        let startIndex = text.index(text.startIndex, offsetBy: contextStart)
        let endIndex = text.index(text.startIndex, offsetBy: contextEnd)

        var context = String(text[startIndex..<endIndex])
        if contextStart > 0 { context = "..." + context }
        if contextEnd < text.count { context = context + "..." }

        return context
    }

    // MARK: - Negation Detection (matching desktop tribunal_popups.py is_negated)
    private func isNegated(text: String, matchRange: Range<String.Index>, keyword: String) -> Bool {
        let textLower = text.lowercased()
        let keywordLower = keyword.lowercased()

        // Special handling for 'seclusion' - often refers to OTHER people, not the patient
        if keywordLower.contains("seclusion") || keywordLower.contains("secluded") {
            let thirdPartyPatterns = [
                "\\b(he|his|him|boyfriend|bf|partner)\\b[^.]*\\bseclusion\\b",
                "\\bseclusion\\b[^.]*\\b(he|his|him|boyfriend|bf|partner)\\b",
                "\\b(he|his)\\s+(is|was|has been|had been|keeps|kept)\\s+[^.]*\\bseclusion\\b",
                "\\b(acting out|behaviou?r)[^.]*\\bseclusion\\b"
            ]
            for pattern in thirdPartyPatterns {
                if textLower.range(of: pattern, options: .regularExpression) != nil {
                    return true
                }
            }
        }

        // Comprehensive negation patterns (matching desktop)
        let quickNegationPatterns = [
            // Direct negation
            "not\\s+led\\s+to\\s+\(keywordLower)",
            "have\\s+not\\s+led\\s+to\\s+\(keywordLower)",
            "has\\s+not\\s+led\\s+to\\s+\(keywordLower)",
            "not\\s+resulted?\\s+in\\s+\(keywordLower)",
            "no\\s+\(keywordLower)",
            "nil\\s+\(keywordLower)",
            "without\\s+\(keywordLower)",
            "absence\\s+of\\s+\(keywordLower)",

            // Clinical negation phrases with lists
            "no\\s+self[- ]?harm\\s+(or\\s+)?(incidents?\\s+of\\s+)?\(keywordLower)",
            "no\\s+incidents?,?\\s+self[- ]?harm\\s+(or\\s+)?\(keywordLower)",
            "no\\s+[\\w\\s,]+\\s+or\\s+(incidents?\\s+of\\s+)?\(keywordLower)",

            // Sentence-level negation: "no" anywhere before keyword
            "\\bno\\b[^.!?]{0,100}\\b\(keywordLower)",

            // "didn't/doesn't present as aggressive" patterns
            "didn'?t\\s+present\\s+(as\\s+)?\(keywordLower)",
            "did\\s+not\\s+present\\s+(as\\s+)?\(keywordLower)",
            "does\\s+not\\s+present\\s+(as\\s+)?\(keywordLower)",
            "doesn'?t\\s+present\\s+(as\\s+)?\(keywordLower)",

            // "did not pose any aggressive behaviour"
            "did\\s+not\\s+pose\\s+(any\\s+)?\(keywordLower)",
            "didn'?t\\s+pose\\s+(any\\s+)?\(keywordLower)",

            // "did not want to go into seclusion" / "didn't want seclusion"
            "did\\s+not\\s+want\\s+[^.]*\(keywordLower)",
            "didn'?t\\s+want\\s+[^.]*\(keywordLower)",
            "does\\s+not\\s+want\\s+[^.]*\(keywordLower)",
            "doesn'?t\\s+want\\s+[^.]*\(keywordLower)",

            // "did not feel she would like" patterns
            "did\\s+not\\s+feel\\s+[^.]*\(keywordLower)",
            "didn'?t\\s+feel\\s+[^.]*\(keywordLower)",
            "does\\s+not\\s+feel\\s+[^.]*\(keywordLower)",
            "doesn'?t\\s+feel\\s+[^.]*\(keywordLower)",

            // "did not want to be secluded/restrained"
            "did\\s+not\\s+want\\s+to\\s+be\\s+\(keywordLower)",
            "didn'?t\\s+want\\s+to\\s+be\\s+\(keywordLower)",
            "does\\s+not\\s+want\\s+to\\s+be\\s+\(keywordLower)",
            "doesn'?t\\s+want\\s+to\\s+be\\s+\(keywordLower)",

            // "as she did not want" - subordinate clause pattern
            "as\\s+(she|he|they)\\s+did\\s+not\\s+want\\s+[^.]*\(keywordLower)",
            "as\\s+(she|he|they)\\s+didn'?t\\s+want\\s+[^.]*\(keywordLower)",

            // "would not like to be" patterns
            "would\\s+not\\s+like\\s+to\\s+[^.]*\(keywordLower)",
            "wouldn'?t\\s+like\\s+to\\s+[^.]*\(keywordLower)",

            // "refused to go into seclusion" / "declined seclusion"
            "refused\\s+[^.]*\(keywordLower)",
            "declined\\s+[^.]*\(keywordLower)",

            // "not requiring seclusion" / "did not require"
            "not\\s+requir(e|ing|ed)\\s+[^.]*\(keywordLower)",
            "did\\s+not\\s+require\\s+[^.]*\(keywordLower)",

            // "didn't display any signs of aggression"
            "didn'?t\\s+display\\s+(any\\s+)?(signs?\\s+of\\s+)?\(keywordLower)",
            "did\\s+not\\s+display\\s+(any\\s+)?(signs?\\s+of\\s+)?\(keywordLower)",
            "no\\s+signs?\\s+of\\s+\(keywordLower)",

            // "have not been an incident of aggression"
            "have\\s+not\\s+been\\s+(an?\\s+)?incident[^.]*\(keywordLower)",
            "has\\s+not\\s+been\\s+(an?\\s+)?incident[^.]*\(keywordLower)",
            "there\\s+have\\s+not\\s+been\\b[^.]*\(keywordLower)",
            "there\\s+has\\s+not\\s+been\\b[^.]*\(keywordLower)",
            "no\\s+incident[^.]*\(keywordLower)",

            // Low risk context
            "\\b\(keywordLower)[^.]*:\\s*low\\b",
            "\\blow\\b[^.]*\(keywordLower)",

            // "not observed/reported" patterns
            "\\b\(keywordLower)[^.]*\\bnot\\s+(observed|reported|noted|seen)",
            "\\b\(keywordLower)[^.]*\\bwere\\s+not\\s+(observed|reported|noted|seen)",

            // Risk section mentions - these are historical risk lists
            "risks?[:\\s]+[^.]*\\b\(keywordLower)",
            "history\\s+of\\s+\(keywordLower)",
            "risk\\s+of\\s+\(keywordLower)",
            "risks?\\s*:\\s*.{0,300}\\b\(keywordLower)",

            // Risk assessment field labels
            "\\bto\\s+others?\\s*:\\s*history\\s+of\\b[^.]*\(keywordLower)",
            "\\bto\\s+others?\\s*:[^.]*\\b\(keywordLower)",
            "\\bto\\s+self\\s*:\\s*history\\s+of\\b[^.]*\(keywordLower)",
            "\\bto\\s+self\\s*:[^.]*\\b\(keywordLower)",

            // Forensic history mentions
            "\\bforensic\\s+history\\b[^.]*\(keywordLower)",
            "\\b\(keywordLower)[^.]*\\bforensic\\s+history\\b",

            // Care plan / management language
            "\\bmanagement\\s+of\\s+(high\\s+)?risks?\\b[^.]*\(keywordLower)",
            "\\bmanagement\\s+of\\b[^.]*\(keywordLower)",
            "\\bpreventative\\s+interventions?\\b[^.]*\(keywordLower)",

            // Relapse indicators / warning signs
            "\\brelapse\\s+indicators?\\b[^.]*\(keywordLower)",
            "\\bwarning\\s+signs?\\b[^.]*\(keywordLower)",
            "\\bearly\\s+warning\\b[^.]*\(keywordLower)",

            // "urges" - feelings/potential, not actual behaviour
            "\\b\(keywordLower)\\s+urges?\\b",
            "\\burges?\\s+to\\s+\(keywordLower)",
            "\\bhas\\s+\(keywordLower)\\s+urges?\\b",

            // Conditional/potential behaviour
            "can\\s+be\\s+\(keywordLower)",
            "may\\s+be(come)?\\s+\(keywordLower)",
            "could\\s+be(come)?\\s+\(keywordLower)",
            "if\\s+.*\\b\(keywordLower)",

            // Positive behaviour indicators in same sentence
            "\\bcalm\\s+and\\s+settled\\b[^.]*\\b\(keywordLower)",
            "\\b\(keywordLower)[^.]*\\bcalm\\s+and\\s+settled\\b",
            "\\bsettled\\s+and\\s+calm\\b[^.]*\\b\(keywordLower)",
            "\\b(very\\s+)?pleasant\\s+on\\s+approach\\b[^.]*\\b\(keywordLower)",

            // "Nothing suggested" / "nothing to suggest" patterns
            "\\bnothing\\s+suggested\\b[^.]*\\b\(keywordLower)",
            "\\bnothing\\s+to\\s+suggest\\b[^.]*\\b\(keywordLower)",
            "\\bno\\s+evidence\\s+(of|to\\s+suggest)\\b[^.]*\\b\(keywordLower)",
            "\\bno\\s+indication\\s+(of|that)\\b[^.]*\\b\(keywordLower)",
            "\\bno\\s+concerns?\\s+(about|regarding|of)\\b[^.]*\\b\(keywordLower)",
            "\\bno\\s+suggestion\\s+(of|that)\\b[^.]*\\b\(keywordLower)",
            "\\bat\\s+time\\s+of\\s+assessment\\b[^.]*\\b\(keywordLower)",

            // Denies patterns
            "\\bdenied\\s+(any\\s+)?\(keywordLower)",
            "\\bdenies\\s+(any\\s+)?\(keywordLower)",
            "\\bdeny\\s+(any\\s+)?\(keywordLower)",
            "\\bdenying\\s+(any\\s+)?\(keywordLower)",

            // Free from / absence
            "\\bfree\\s+from\\s+\(keywordLower)",
            "\\bnegative\\s+for\\s+\(keywordLower)",

            // "was not" / "has not been"
            "(was|were)\\s+not\\s+[^.]*\(keywordLower)",
            "(has|had|have)\\s+not\\s+(been\\s+)?[^.]*\(keywordLower)",

            // "no harm to self or others"
            "no\\s+harm\\s+to\\s+(self|others)",
            "no\\s+(self[- ]?harm|suicid)"
        ]

        for pattern in quickNegationPatterns {
            if textLower.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }

        // Get the sentence containing the match for additional checks
        let matchStart = text.distance(from: text.startIndex, to: matchRange.lowerBound)
        let textNS = textLower as NSString

        var sentStart = textNS.range(of: ".", options: .backwards, range: NSRange(location: 0, length: matchStart)).location
        if sentStart == NSNotFound { sentStart = 0 } else { sentStart += 1 }

        var sentEnd = textNS.range(of: ".", range: NSRange(location: matchStart, length: textNS.length - matchStart)).location
        if sentEnd == NSNotFound { sentEnd = textNS.length }

        let sentence = textNS.substring(with: NSRange(location: sentStart, length: sentEnd - sentStart)).trimmingCharacters(in: .whitespaces)

        // Check for broad negation patterns at sentence start
        let broadNegationPatterns = [
            "^no\\s+concerns?\\b",
            "^nil\\b",
            "^none\\b",
            "not\\s+been\\s+any\\b"
        ]

        for pattern in broadNegationPatterns {
            if sentence.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }

        // Handle comma-separated lists: "No incidents, self harm or aggression"
        let listNegationPattern = "^no\\s+[\\w\\s]+[,].*\(keywordLower)"
        if sentence.range(of: listNegationPattern, options: .regularExpression) != nil {
            return true
        }

        // Handle "No X or Y or Z" without commas
        let orListPattern = "^no\\s+[\\w\\s]+(\\s+or\\s+[\\w\\s]+)*\\s+or\\s+\(keywordLower)"
        if sentence.range(of: orListPattern, options: .regularExpression) != nil {
            return true
        }

        return false
    }
}
