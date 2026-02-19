//
//  MedicationExtractor.swift
//  MyPsychAdmin
//
//  ULTRA-FAST TOKEN-BASED MEDICATION EXTRACTOR
//  Matches desktop app's medication_extractor.py algorithm
//  - Token-based parsing (not context-based)
//  - Dose found within ±3 tokens of drug name
//  - Plausibility check with allowed_strengths
//

import Foundation

// MARK: - Medication Classification
enum DrugCategory: String, CaseIterable, Identifiable {
    case psychiatric = "Psychiatric"
    case physical = "Physical"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .psychiatric: return "brain"
        case .physical: return "heart.fill"
        }
    }
}

enum PsychSubtype: String, CaseIterable, Identifiable {
    case antipsychotic = "Antipsychotic"
    case antidepressant = "Antidepressant"
    case antimanic = "Antimanic"
    case hypnotic = "Hypnotic/Anxiolytic"
    case anticholinergic = "Anticholinergic"
    case other = "Other Psychiatric"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .antipsychotic: return "brain.head.profile"
        case .antidepressant: return "sun.max"
        case .antimanic: return "waveform.path.ecg"
        case .hypnotic: return "moon.zzz"
        case .anticholinergic: return "pills"
        case .other: return "cross.case"
        }
    }
}

// MARK: - Drug Definition with Allowed Strengths
struct DrugDefinition {
    let name: String
    let patterns: [String]  // All names/synonyms to match
    let category: DrugCategory
    let subtype: PsychSubtype?
    let allowedStrengths: [Double]?  // nil means any strength is allowed
    let maxDose: Double?  // Maximum plausible dose
    let allowedUnits: Set<String>?  // nil means any unit, otherwise only these units are valid

    init(name: String, patterns: [String], category: DrugCategory, subtype: PsychSubtype?,
         allowedStrengths: [Double]?, maxDose: Double?, allowedUnits: Set<String>? = nil) {
        self.name = name
        self.patterns = patterns
        self.category = category
        self.subtype = subtype
        self.allowedStrengths = allowedStrengths
        self.maxDose = maxDose
        self.allowedUnits = allowedUnits
    }
}

// MARK: - Medication Models
struct MedicationMention: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let drugName: String
    let dose: String?           // Display string e.g. "250mg"
    let totalDailyDose: Double? // Numeric total daily dose for charting
    let frequency: String?
    let route: String?
    let noteId: UUID
    let context: String
    let matchedText: String
}

struct ClassifiedDrug: Identifiable {
    let id = UUID()
    let name: String
    let category: DrugCategory
    let psychiatricSubtype: PsychSubtype?
    var mentions: [MedicationMention]

    var earliestDate: Date? {
        mentions.map { $0.date }.min()
    }

    var latestDate: Date? {
        mentions.map { $0.date }.max()
    }

    var latestDose: String? {
        mentions.sorted { $0.date > $1.date }.first?.dose
    }
}

struct ExtractedMedications {
    var drugs: [ClassifiedDrug] = []

    var psychiatricDrugs: [ClassifiedDrug] {
        drugs.filter { $0.category == .psychiatric }
    }

    var physicalDrugs: [ClassifiedDrug] {
        drugs.filter { $0.category == .physical }
    }

    func drugsBySubtype(_ subtype: PsychSubtype) -> [ClassifiedDrug] {
        psychiatricDrugs.filter { $0.psychiatricSubtype == subtype }
    }

    var totalMentions: Int {
        drugs.reduce(0) { $0 + $1.mentions.count }
    }
}

// MARK: - Medication Extractor (Token-Based - matches desktop)
class MedicationExtractor {
    static let shared = MedicationExtractor()

    // Token map: lowercase pattern -> DrugDefinition
    private var tokenMap: [String: DrugDefinition] = [:]
    private var firstChars: [Character: [String]] = [:]

    // Unit and frequency sets
    private let unitSet: Set<String> = ["mg", "mcg", "µg", "g", "units", "iu"]
    private let freqSet: Set<String> = ["od", "bd", "tds", "qds", "qid", "nocte", "mane", "stat", "prn", "daily", "weekly", "monthly", "om", "on", "morning", "night", "evening", "am", "pm", "bedtime", "twice", "once"]
    private let routeSet: Set<String> = ["po", "oral", "im", "sc", "iv", "neb", "inhaled", "topical", "subcut", "intramuscular", "intravenous"]

    // Frequency multipliers for total daily dose calculation
    private let freqMultipliers: [String: Double] = [
        "od": 1, "daily": 1, "om": 1, "on": 1, "nocte": 1, "mane": 1, "stat": 1, "once": 1,
        "bd": 2, "twice": 2,
        "tds": 3,
        "qds": 4, "qid": 4
    ]

    private init() {
        buildTokenIndex()
    }

    // MARK: - Drug Definitions (with allowed_strengths matching desktop CANONICAL_MEDS)
    private let drugDefinitions: [DrugDefinition] = [
        // Antipsychotics
        DrugDefinition(name: "Haloperidol", patterns: ["haloperidol", "haldol", "serenace"], category: .psychiatric, subtype: .antipsychotic, allowedStrengths: [0.5, 1, 1.5, 2, 2.5, 3, 5, 10, 20], maxDose: 30),
        DrugDefinition(name: "Haloperidol Depot", patterns: ["haloperidol decanoate", "haldol decanoate"], category: .psychiatric, subtype: .antipsychotic, allowedStrengths: [50, 100, 150, 200, 250, 300], maxDose: 300),
        DrugDefinition(name: "Chlorpromazine", patterns: ["chlorpromazine", "largactil"], category: .psychiatric, subtype: .antipsychotic, allowedStrengths: [10, 25, 50, 100], maxDose: 1000),
        DrugDefinition(name: "Flupentixol", patterns: ["flupentixol", "flupenthixol"], category: .psychiatric, subtype: .antipsychotic, allowedStrengths: [0.5, 1, 3], maxDose: 18),
        DrugDefinition(name: "Flupentixol Depot", patterns: ["flupentixol depot", "flupenthixol depot", "depixol"], category: .psychiatric, subtype: .antipsychotic, allowedStrengths: [20, 40, 100, 200, 400], maxDose: 400),
        DrugDefinition(name: "Zuclopenthixol", patterns: ["zuclopenthixol"], category: .psychiatric, subtype: .antipsychotic, allowedStrengths: [2, 10, 25, 50], maxDose: 150),
        DrugDefinition(name: "Zuclopenthixol Depot", patterns: ["zuclopenthixol depot", "zuclopenthixol decanoate", "clopixol", "clopixol depot"], category: .psychiatric, subtype: .antipsychotic, allowedStrengths: [100, 200, 500, 600], maxDose: 600),
        DrugDefinition(name: "Sulpiride", patterns: ["sulpiride", "dolmatil"], category: .psychiatric, subtype: .antipsychotic, allowedStrengths: [50, 100, 200, 400], maxDose: 2400),
        DrugDefinition(name: "Trifluoperazine", patterns: ["trifluoperazine", "stelazine"], category: .psychiatric, subtype: .antipsychotic, allowedStrengths: [1, 2, 5], maxDose: 30),
        DrugDefinition(name: "Olanzapine", patterns: ["olanzapine", "zyprexa"], category: .psychiatric, subtype: .antipsychotic, allowedStrengths: [2.5, 5, 7.5, 10, 15, 20], maxDose: 20),
        DrugDefinition(name: "Olanzapine Depot", patterns: ["olanzapine embonate", "olanzapine depot", "zypadhera"], category: .psychiatric, subtype: .antipsychotic, allowedStrengths: [210, 300, 405], maxDose: 405),
        DrugDefinition(name: "Risperidone", patterns: ["risperidone", "risperdal"], category: .psychiatric, subtype: .antipsychotic, allowedStrengths: [0.25, 0.5, 1, 2, 3, 4, 6], maxDose: 16),
        DrugDefinition(name: "Risperidone Depot", patterns: ["risperidone depot", "risperdal consta"], category: .psychiatric, subtype: .antipsychotic, allowedStrengths: [25, 37.5, 50], maxDose: 50),
        DrugDefinition(name: "Quetiapine", patterns: ["quetiapine", "seroquel"], category: .psychiatric, subtype: .antipsychotic, allowedStrengths: [25, 50, 75, 100, 125, 150, 175, 200, 225, 250, 300, 350, 400, 450, 500, 550, 600, 700, 800], maxDose: 800),
        DrugDefinition(name: "Aripiprazole", patterns: ["aripiprazole", "abilify"], category: .psychiatric, subtype: .antipsychotic, allowedStrengths: [2, 5, 10, 15, 20, 30], maxDose: 30),
        DrugDefinition(name: "Aripiprazole Depot", patterns: ["aripiprazole depot", "aripiprazole maintena", "abilify maintena"], category: .psychiatric, subtype: .antipsychotic, allowedStrengths: [300, 400], maxDose: 400),
        DrugDefinition(name: "Clozapine", patterns: ["clozapine", "clozaril", "denzapine", "zaponex"], category: .psychiatric, subtype: .antipsychotic, allowedStrengths: [12.5, 25, 50, 75, 100, 125, 150, 175, 200, 225, 250, 275, 300, 325, 350, 375, 400, 425, 450, 500], maxDose: 900),
        DrugDefinition(name: "Amisulpride", patterns: ["amisulpride", "solian"], category: .psychiatric, subtype: .antipsychotic, allowedStrengths: [50, 100, 200, 400], maxDose: 1200),
        DrugDefinition(name: "Paliperidone", patterns: ["paliperidone", "invega"], category: .psychiatric, subtype: .antipsychotic, allowedStrengths: [3, 6, 9, 12], maxDose: 12),
        DrugDefinition(name: "Paliperidone Depot", patterns: ["paliperidone depot", "xeplion", "trevicta", "paliperidone palmitate"], category: .psychiatric, subtype: .antipsychotic, allowedStrengths: [25, 50, 75, 100, 150, 175, 263, 350, 525], maxDose: 525),
        DrugDefinition(name: "Lurasidone", patterns: ["lurasidone", "latuda"], category: .psychiatric, subtype: .antipsychotic, allowedStrengths: [18.5, 37, 74], maxDose: 148),

        // Antidepressants (SSRIs)
        DrugDefinition(name: "Fluoxetine", patterns: ["fluoxetine", "prozac"], category: .psychiatric, subtype: .antidepressant, allowedStrengths: [10, 20, 40, 60], maxDose: 80),
        DrugDefinition(name: "Sertraline", patterns: ["sertraline", "zoloft", "lustral"], category: .psychiatric, subtype: .antidepressant, allowedStrengths: [25, 50, 75, 100, 125, 150, 175, 200], maxDose: 200),
        DrugDefinition(name: "Paroxetine", patterns: ["paroxetine", "seroxat"], category: .psychiatric, subtype: .antidepressant, allowedStrengths: [10, 20, 30, 40], maxDose: 60),
        DrugDefinition(name: "Citalopram", patterns: ["citalopram", "cipramil"], category: .psychiatric, subtype: .antidepressant, allowedStrengths: [10, 20, 40], maxDose: 40),
        DrugDefinition(name: "Escitalopram", patterns: ["escitalopram", "cipralex"], category: .psychiatric, subtype: .antidepressant, allowedStrengths: [5, 10, 15, 20], maxDose: 20),
        DrugDefinition(name: "Fluvoxamine", patterns: ["fluvoxamine", "faverin"], category: .psychiatric, subtype: .antidepressant, allowedStrengths: [50, 100], maxDose: 300),

        // Antidepressants (SNRIs)
        DrugDefinition(name: "Venlafaxine", patterns: ["venlafaxine", "efexor", "effexor"], category: .psychiatric, subtype: .antidepressant, allowedStrengths: [37.5, 75, 150, 225], maxDose: 375),
        DrugDefinition(name: "Duloxetine", patterns: ["duloxetine", "cymbalta"], category: .psychiatric, subtype: .antidepressant, allowedStrengths: [20, 30, 40, 60, 90, 120], maxDose: 120),

        // Antidepressants (TCAs)
        DrugDefinition(name: "Amitriptyline", patterns: ["amitriptyline", "elavil"], category: .psychiatric, subtype: .antidepressant, allowedStrengths: [10, 25, 50, 75], maxDose: 200),
        DrugDefinition(name: "Nortriptyline", patterns: ["nortriptyline", "allegron"], category: .psychiatric, subtype: .antidepressant, allowedStrengths: [10, 25], maxDose: 150),
        DrugDefinition(name: "Clomipramine", patterns: ["clomipramine", "anafranil"], category: .psychiatric, subtype: .antidepressant, allowedStrengths: [10, 25, 50, 75], maxDose: 250),
        DrugDefinition(name: "Imipramine", patterns: ["imipramine", "tofranil"], category: .psychiatric, subtype: .antidepressant, allowedStrengths: [10, 25], maxDose: 300),
        DrugDefinition(name: "Dosulepin", patterns: ["dosulepin", "dothiepin", "prothiaden"], category: .psychiatric, subtype: .antidepressant, allowedStrengths: [25, 75], maxDose: 225),
        DrugDefinition(name: "Lofepramine", patterns: ["lofepramine", "gamanil"], category: .psychiatric, subtype: .antidepressant, allowedStrengths: [70, 140, 210], maxDose: 210),

        // Antidepressants (Others)
        DrugDefinition(name: "Mirtazapine", patterns: ["mirtazapine", "zispin", "remeron"], category: .psychiatric, subtype: .antidepressant, allowedStrengths: [15, 30, 45], maxDose: 45),
        DrugDefinition(name: "Trazodone", patterns: ["trazodone", "molipaxin"], category: .psychiatric, subtype: .antidepressant, allowedStrengths: [50, 100, 150], maxDose: 600),
        DrugDefinition(name: "Bupropion", patterns: ["bupropion", "wellbutrin", "zyban"], category: .psychiatric, subtype: .antidepressant, allowedStrengths: [150, 300], maxDose: 450),
        DrugDefinition(name: "Vortioxetine", patterns: ["vortioxetine", "brintellix"], category: .psychiatric, subtype: .antidepressant, allowedStrengths: [5, 10, 15, 20], maxDose: 20),
        DrugDefinition(name: "Agomelatine", patterns: ["agomelatine", "valdoxan"], category: .psychiatric, subtype: .antidepressant, allowedStrengths: [25, 50], maxDose: 50),

        // Antimanics / Mood Stabilizers
        DrugDefinition(name: "Lithium", patterns: ["lithium", "priadel", "camcolit", "li-liquid", "liskonum"], category: .psychiatric, subtype: .antimanic, allowedStrengths: [200, 250, 400, 450, 500, 520, 600, 800, 1000, 1200], maxDose: 1200),
        DrugDefinition(name: "Valproate", patterns: ["valproate", "sodium valproate", "valproic acid", "epilim", "depakote", "convulex"], category: .psychiatric, subtype: .antimanic, allowedStrengths: [100, 150, 200, 250, 300, 400, 500, 600, 700, 750, 800, 900, 1000, 1100, 1200, 1250, 1300, 1400, 1500, 1600, 1750, 1800, 2000, 2500], maxDose: 2500),
        DrugDefinition(name: "Carbamazepine", patterns: ["carbamazepine", "tegretol"], category: .psychiatric, subtype: .antimanic, allowedStrengths: [100, 200, 400], maxDose: 1600),
        DrugDefinition(name: "Lamotrigine", patterns: ["lamotrigine", "lamictal"], category: .psychiatric, subtype: .antimanic, allowedStrengths: [2, 5, 25, 50, 100, 200], maxDose: 400),

        // Hypnotics/Anxiolytics (Benzodiazepines)
        DrugDefinition(name: "Diazepam", patterns: ["diazepam", "valium"], category: .psychiatric, subtype: .hypnotic, allowedStrengths: [2, 5, 10], maxDose: 30),
        DrugDefinition(name: "Lorazepam", patterns: ["lorazepam", "ativan"], category: .psychiatric, subtype: .hypnotic, allowedStrengths: [0.5, 1, 2, 2.5, 4], maxDose: 10),
        DrugDefinition(name: "Clonazepam", patterns: ["clonazepam", "rivotril"], category: .psychiatric, subtype: .hypnotic, allowedStrengths: [0.25, 0.5, 1, 2], maxDose: 8),
        DrugDefinition(name: "Alprazolam", patterns: ["alprazolam", "xanax"], category: .psychiatric, subtype: .hypnotic, allowedStrengths: [0.25, 0.5, 1, 2], maxDose: 6),
        DrugDefinition(name: "Temazepam", patterns: ["temazepam", "restoril"], category: .psychiatric, subtype: .hypnotic, allowedStrengths: [10, 20], maxDose: 40),
        DrugDefinition(name: "Nitrazepam", patterns: ["nitrazepam", "mogadon"], category: .psychiatric, subtype: .hypnotic, allowedStrengths: [5, 10], maxDose: 10),
        DrugDefinition(name: "Oxazepam", patterns: ["oxazepam", "serax"], category: .psychiatric, subtype: .hypnotic, allowedStrengths: [10, 15, 30], maxDose: 120),
        DrugDefinition(name: "Chlordiazepoxide", patterns: ["chlordiazepoxide", "librium"], category: .psychiatric, subtype: .hypnotic, allowedStrengths: [5, 10, 25], maxDose: 100),
        DrugDefinition(name: "Midazolam", patterns: ["midazolam"], category: .psychiatric, subtype: .hypnotic, allowedStrengths: [7.5, 10, 15], maxDose: 15),
        DrugDefinition(name: "Clobazam", patterns: ["clobazam", "frisium"], category: .psychiatric, subtype: .hypnotic, allowedStrengths: [10], maxDose: 60),

        // Hypnotics (Z-drugs)
        DrugDefinition(name: "Zopiclone", patterns: ["zopiclone", "zimovane"], category: .psychiatric, subtype: .hypnotic, allowedStrengths: [3.75, 7.5], maxDose: 15),
        DrugDefinition(name: "Zolpidem", patterns: ["zolpidem", "stilnoct", "ambien"], category: .psychiatric, subtype: .hypnotic, allowedStrengths: [5, 10], maxDose: 10),

        // Other Hypnotics
        DrugDefinition(name: "Promethazine", patterns: ["promethazine", "phenergan"], category: .psychiatric, subtype: .hypnotic, allowedStrengths: [10, 25, 50], maxDose: 100),
        DrugDefinition(name: "Melatonin", patterns: ["melatonin", "circadin"], category: .psychiatric, subtype: .hypnotic, allowedStrengths: [1, 2, 3, 5, 10], maxDose: 10),
        DrugDefinition(name: "Hydroxyzine", patterns: ["hydroxyzine", "atarax", "ucerax"], category: .psychiatric, subtype: .hypnotic, allowedStrengths: [10, 25, 50], maxDose: 100),

        // Anticholinergics
        DrugDefinition(name: "Procyclidine", patterns: ["procyclidine", "kemadrin"], category: .psychiatric, subtype: .anticholinergic, allowedStrengths: [2.5, 5], maxDose: 30),
        DrugDefinition(name: "Trihexyphenidyl", patterns: ["trihexyphenidyl", "benzhexol", "artane"], category: .psychiatric, subtype: .anticholinergic, allowedStrengths: [2, 5], maxDose: 20),
        DrugDefinition(name: "Benztropine", patterns: ["benztropine", "cogentin"], category: .psychiatric, subtype: .anticholinergic, allowedStrengths: [1, 2], maxDose: 6),
        DrugDefinition(name: "Orphenadrine", patterns: ["orphenadrine", "biorphen", "disipal"], category: .psychiatric, subtype: .anticholinergic, allowedStrengths: [50], maxDose: 400),

        // Physical Health Medications (no strict strength validation)
        DrugDefinition(name: "Amlodipine", patterns: ["amlodipine", "norvasc"], category: .physical, subtype: nil, allowedStrengths: nil, maxDose: nil),
        DrugDefinition(name: "Bisoprolol", patterns: ["bisoprolol", "cardicor"], category: .physical, subtype: nil, allowedStrengths: nil, maxDose: nil),
        DrugDefinition(name: "Ramipril", patterns: ["ramipril", "tritace"], category: .physical, subtype: nil, allowedStrengths: nil, maxDose: nil),
        DrugDefinition(name: "Lisinopril", patterns: ["lisinopril", "zestril"], category: .physical, subtype: nil, allowedStrengths: nil, maxDose: nil),
        DrugDefinition(name: "Atenolol", patterns: ["atenolol", "tenormin"], category: .physical, subtype: nil, allowedStrengths: nil, maxDose: nil),
        DrugDefinition(name: "Losartan", patterns: ["losartan", "cozaar"], category: .physical, subtype: nil, allowedStrengths: nil, maxDose: nil),
        DrugDefinition(name: "Candesartan", patterns: ["candesartan", "amias"], category: .physical, subtype: nil, allowedStrengths: nil, maxDose: nil),
        DrugDefinition(name: "Furosemide", patterns: ["furosemide", "frusemide", "lasix"], category: .physical, subtype: nil, allowedStrengths: nil, maxDose: nil),
        DrugDefinition(name: "Bendroflumethiazide", patterns: ["bendroflumethiazide", "aprinox"], category: .physical, subtype: nil, allowedStrengths: nil, maxDose: nil),
        DrugDefinition(name: "Aspirin", patterns: ["aspirin"], category: .physical, subtype: nil, allowedStrengths: nil, maxDose: nil),
        DrugDefinition(name: "Clopidogrel", patterns: ["clopidogrel", "plavix"], category: .physical, subtype: nil, allowedStrengths: nil, maxDose: nil),
        DrugDefinition(name: "Warfarin", patterns: ["warfarin", "coumadin"], category: .physical, subtype: nil, allowedStrengths: nil, maxDose: nil),
        DrugDefinition(name: "Apixaban", patterns: ["apixaban", "eliquis"], category: .physical, subtype: nil, allowedStrengths: nil, maxDose: nil),
        DrugDefinition(name: "Rivaroxaban", patterns: ["rivaroxaban", "xarelto"], category: .physical, subtype: nil, allowedStrengths: nil, maxDose: nil),
        DrugDefinition(name: "Atorvastatin", patterns: ["atorvastatin", "lipitor"], category: .physical, subtype: nil, allowedStrengths: nil, maxDose: nil),
        DrugDefinition(name: "Simvastatin", patterns: ["simvastatin", "zocor"], category: .physical, subtype: nil, allowedStrengths: nil, maxDose: nil),
        DrugDefinition(name: "Metformin", patterns: ["metformin", "glucophage"], category: .physical, subtype: nil, allowedStrengths: [500, 850, 1000], maxDose: 3000),
        DrugDefinition(name: "Gliclazide", patterns: ["gliclazide", "diamicron"], category: .physical, subtype: nil, allowedStrengths: nil, maxDose: nil),
        DrugDefinition(name: "Insulin", patterns: ["insulin", "novorapid", "humalog", "lantus", "levemir"], category: .physical, subtype: nil, allowedStrengths: nil, maxDose: 300, allowedUnits: ["units", "iu", "u"]),
        DrugDefinition(name: "Omeprazole", patterns: ["omeprazole", "losec"], category: .physical, subtype: nil, allowedStrengths: [10, 20, 40], maxDose: 80),
        DrugDefinition(name: "Lansoprazole", patterns: ["lansoprazole", "zoton"], category: .physical, subtype: nil, allowedStrengths: [15, 30], maxDose: 60),
        DrugDefinition(name: "Pantoprazole", patterns: ["pantoprazole", "protium"], category: .physical, subtype: nil, allowedStrengths: [20, 40], maxDose: 80),
        DrugDefinition(name: "Paracetamol", patterns: ["paracetamol", "acetaminophen", "tylenol"], category: .physical, subtype: nil, allowedStrengths: nil, maxDose: nil),
        DrugDefinition(name: "Ibuprofen", patterns: ["ibuprofen", "brufen", "nurofen"], category: .physical, subtype: nil, allowedStrengths: nil, maxDose: nil),
        DrugDefinition(name: "Naproxen", patterns: ["naproxen", "naprosyn"], category: .physical, subtype: nil, allowedStrengths: nil, maxDose: nil),
        DrugDefinition(name: "Codeine", patterns: ["codeine"], category: .physical, subtype: nil, allowedStrengths: nil, maxDose: nil),
        DrugDefinition(name: "Tramadol", patterns: ["tramadol", "zydol"], category: .physical, subtype: nil, allowedStrengths: nil, maxDose: nil),
        DrugDefinition(name: "Morphine", patterns: ["morphine", "oramorph", "mst"], category: .physical, subtype: nil, allowedStrengths: nil, maxDose: nil),
        DrugDefinition(name: "Gabapentin", patterns: ["gabapentin", "neurontin"], category: .physical, subtype: nil, allowedStrengths: nil, maxDose: nil),
        DrugDefinition(name: "Pregabalin", patterns: ["pregabalin", "lyrica"], category: .physical, subtype: nil, allowedStrengths: nil, maxDose: nil),
        DrugDefinition(name: "Salbutamol", patterns: ["salbutamol", "ventolin"], category: .physical, subtype: nil, allowedStrengths: [100, 200], maxDose: 800, allowedUnits: ["mcg", "µg"]),
        DrugDefinition(name: "Levothyroxine", patterns: ["levothyroxine", "thyroxine", "eltroxin"], category: .physical, subtype: nil, allowedStrengths: [25, 50, 75, 100, 125, 150, 200], maxDose: 300),
        DrugDefinition(name: "Folic Acid", patterns: ["folic acid", "folate"], category: .physical, subtype: nil, allowedStrengths: nil, maxDose: nil),
        DrugDefinition(name: "Vitamin D", patterns: ["vitamin d", "colecalciferol", "cholecalciferol"], category: .physical, subtype: nil, allowedStrengths: nil, maxDose: 60000, allowedUnits: ["units", "iu", "u"]),
        DrugDefinition(name: "Ferrous", patterns: ["ferrous", "iron"], category: .physical, subtype: nil, allowedStrengths: nil, maxDose: nil),
        DrugDefinition(name: "Thiamine", patterns: ["thiamine", "vitamin b1", "pabrinex"], category: .physical, subtype: nil, allowedStrengths: nil, maxDose: nil),
        DrugDefinition(name: "Oxybutynin", patterns: ["oxybutynin", "ditropan"], category: .physical, subtype: nil, allowedStrengths: [2.5, 5, 10, 15], maxDose: 30),
    ]

    // MARK: - Build Token Index
    private func buildTokenIndex() {
        for drug in drugDefinitions {
            for pattern in drug.patterns {
                let lower = pattern.lowercased()
                tokenMap[lower] = drug

                if let first = lower.first {
                    if firstChars[first] == nil {
                        firstChars[first] = []
                    }
                    firstChars[first]?.append(lower)
                }
            }
        }
    }

    // MARK: - Fast Tokeniser (matches desktop)
    private func fastTokenise(_ text: String) -> [String] {
        var result = text.lowercased()

        // Join known split drug names before tokenization
        // "Zap onex" → "zaponex", "Cloz aril" → "clozaril"
        let splitDrugNames = [
            "zap onex": "zaponex",
            "zap  onex": "zaponex",
            "cloz aril": "clozaril",
            "den zapine": "denzapine"
        ]
        for (split, joined) in splitDrugNames {
            result = result.replacingOccurrences(of: split, with: joined, options: .caseInsensitive)
        }

        // Normalize various decimal-like characters to standard period
        result = result.replacingOccurrences(of: "·", with: ".")  // middle dot
        result = result.replacingOccurrences(of: "•", with: ".")  // bullet
        result = result.replacingOccurrences(of: "∙", with: ".")  // bullet operator

        // Fix spaced decimals: "1. 5" or "1 .5" or "1 . 5" → "1.5"
        result = result.replacingOccurrences(of: #"(\d)\s*\.\s*(\d)"#, with: "$1.$2", options: .regularExpression)

        // Handle European decimal comma ONLY when followed by 1-2 digits (not thousands separator)
        result = result.replacingOccurrences(of: #"(\d),(\d{1,2})(?!\d)"#, with: "$1.$2", options: .regularExpression)

        // Separate merged dose+frequency like "500mgod" → "500mg od", "100mgbd" → "100mg bd"
        let freqPatterns = ["od", "bd", "tds", "qds", "om", "on", "nocte", "mane", "prn", "stat"]
        for freq in freqPatterns {
            result = result.replacingOccurrences(of: #"(\d+mg)"# + freq, with: "$1 " + freq, options: .regularExpression)
            result = result.replacingOccurrences(of: #"(\d+mcg)"# + freq, with: "$1 " + freq, options: .regularExpression)
        }

        // Protect decimals (digit.digit patterns)
        result = result.replacingOccurrences(of: "(?<=\\d)\\.(?=\\d)", with: "DECIMALDOT", options: .regularExpression)

        // Remove non-alphanumeric except our protected marker
        result = result.replacingOccurrences(of: "[^a-z0-9DECIMALDOT]+", with: " ", options: .regularExpression)
        result = result.replacingOccurrences(of: "DECIMALDOT", with: ".")

        return result.split(separator: " ").map { String($0) }
    }

    // MARK: - Parse Dose (prioritize doses AFTER the drug name)
    private func parseDose(tokens: [String], idx: Int) -> (Double, String)? {
        // First: look for dose AFTER the drug (idx+1 to idx+4) - this is the normal pattern
        let afterStart = idx + 1
        let afterEnd = min(idx + 5, tokens.count)

        if let result = findDoseInRange(tokens: tokens, start: afterStart, end: afterEnd) {
            return result
        }

        // Fallback: look for dose BEFORE the drug (idx-3 to idx-1) - rare cases
        let beforeStart = max(idx - 3, 0)
        let beforeEnd = idx

        return findDoseInRange(tokens: tokens, start: beforeStart, end: beforeEnd)
    }

    // MARK: - Parse Combined Doses (e.g., "100mg and 375mg")
    // Pass the drug definition to filter out implausible doses
    private func parseCombinedDoses(tokens: [String], idx: Int, definition: DrugDefinition? = nil) -> [(Double, String)] {
        var doses: [(Double, String)] = []
        let end = min(idx + 10, tokens.count)  // Need wider window to catch "from X to Y" patterns

        var i = idx + 1
        while i < end {
            let tok = tokens[i]

            // Stop if we hit another drug name
            if tokenMap[tok] != nil {
                break
            }

            // Stop at common medication list separators
            let stopWords: Set<String> = ["prn", "stat", "hold", "stop", "nil", "max", "as", "required"]
            if stopWords.contains(tok) {
                break
            }

            // Check for dose pattern
            if tok.range(of: #"^(\d+(?:\.\d+)?)(mg|mcg|µg|g)$"#, options: .regularExpression) != nil {
                let numPart = tok.replacingOccurrences(of: #"(mg|mcg|µg|g)$"#, with: "", options: .regularExpression)
                let unitPart = tok.replacingOccurrences(of: #"^\d+(?:\.\d+)?"#, with: "", options: .regularExpression)
                if let value = Double(numPart), value > 0 {
                    // Only include dose if it's plausible for this drug
                    if let def = definition {
                        if isPlausible(strength: value, unit: unitPart, definition: def) {
                            doses.append((value, unitPart))
                        }
                    } else {
                        doses.append((value, unitPart))
                    }
                }
            }

            // Also check for separate number + unit
            if let value = Double(tok), value > 0, i + 1 < end {
                let nextTok = tokens[i + 1]
                if unitSet.contains(nextTok) {
                    // Only include if plausible
                    if let def = definition, isPlausible(strength: value, unit: nextTok, definition: def) {
                        doses.append((value, nextTok))
                    } else if definition == nil {
                        doses.append((value, nextTok))
                    }
                    i += 1  // Skip the unit token
                }
            }

            i += 1
        }

        return doses
    }

    private func findDoseInRange(tokens: [String], start: Int, end: Int) -> (Double, String)? {
        for i in start..<end {
            let tok = tokens[i]

            // Stop if we hit another drug name - that dose belongs to the other drug
            if tokenMap[tok] != nil {
                return nil
            }

            // 1) Combined token e.g. "10mg", "25mcg"
            if tok.range(of: #"^(\d+(?:\.\d+)?)(mg|mcg|µg|g|units|iu)$"#, options: .regularExpression) != nil {
                let numPart = tok.replacingOccurrences(of: #"(mg|mcg|µg|g|units|iu)$"#, with: "", options: .regularExpression)
                let unitPart = tok.replacingOccurrences(of: #"^\d+(?:\.\d+)?"#, with: "", options: .regularExpression)
                if let value = Double(numPart) {
                    // Skip if followed by "/L" or "l" (blood level concentration)
                    if i + 1 < tokens.count {
                        let nextTok = tokens[i + 1].lowercased()
                        if nextTok == "l" || nextTok == "litre" || nextTok == "liter" {
                            continue  // This is a concentration (mg/L), not a dose
                        }
                    }
                    // Skip very small doses (< 1mg) - likely blood levels
                    if value < 1 && unitPart == "mg" {
                        continue  // Implausibly small dose, likely a blood level
                    }
                    return (value, unitPart)
                }
            }

            // 2) Separate tokens e.g. "10" + "mg"
            if let value = Double(tok), i + 1 < tokens.count {
                let nextTok = tokens[i + 1]
                if unitSet.contains(nextTok) {
                    // Skip if followed by "/L" (blood level)
                    if i + 2 < tokens.count {
                        let afterUnit = tokens[i + 2].lowercased()
                        if afterUnit == "l" || afterUnit == "litre" || afterUnit == "liter" {
                            continue
                        }
                    }
                    // Skip very small doses
                    if value < 1 && nextTok == "mg" {
                        continue
                    }
                    return (value, nextTok)
                }
            }
        }
        return nil
    }

    // MARK: - Parse Route and Frequency
    private func parseRouteFreq(tokens: [String], idx: Int) -> (String?, String?) {
        let end = min(idx + 12, tokens.count)  // Expanded window to capture "morning"/"night" further in sentence
        var route: String?
        var freq: String?

        // Check for "OM and ON" or "morning and night" pattern (means BD/twice daily)
        let morningFreqs: Set<String> = ["om", "mane", "morning", "am"]
        let eveningFreqs: Set<String> = ["on", "nocte", "night", "evening", "pm", "bedtime"]
        var foundMorning = false
        var foundEvening = false
        var foundAnd = false

        for i in idx..<end {
            let tok = tokens[i]

            // Stop at another drug name
            if i > idx && tokenMap[tok] != nil {
                break
            }

            if routeSet.contains(tok) && route == nil {
                route = tok
            } else if freqSet.contains(tok) && freq == nil {
                freq = tok
            }

            // Track morning/evening pattern
            if morningFreqs.contains(tok) { foundMorning = true }
            if eveningFreqs.contains(tok) { foundEvening = true }
            if tok == "and" { foundAnd = true }
        }

        // If we found "morning AND evening" pattern, treat as BD
        if foundMorning && foundEvening && foundAnd {
            freq = "bd"
        }

        return (route, freq)
    }

    // Word numbers to digits
    private let wordToNumber: [String: Double] = [
        "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
        "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
        "half": 0.5
    ]

    // MARK: - Parse Tablet Multiplier (x2, take 2, take two, etc.)
    private func parseTabletMultiplier(tokens: [String], idx: Int) -> Double {
        let end = min(idx + 8, tokens.count)

        for i in idx..<end {
            let tok = tokens[i]

            // Stop if we hit another drug name - that info belongs to another drug
            if i > idx && tokenMap[tok] != nil {
                break
            }

            // Pattern: "x2", "x3", etc.
            if tok.hasPrefix("x"), let num = Double(tok.dropFirst()), num > 0 && num <= 10 {
                return num
            }

            // Pattern: "take" followed by number (digit or word)
            if tok == "take" && i + 1 < tokens.count {
                let nextTok = tokens[i + 1]
                if let num = Double(nextTok), num > 0 && num <= 10 {
                    return num
                }
                if let num = wordToNumber[nextTok] {
                    return num
                }
            }

            // Pattern: number (digit or word) followed by "tablets" or similar
            let tabletWords = ["tablets", "tabs", "tablet", "tab"]
            if i + 1 < tokens.count && tabletWords.contains(tokens[i + 1]) {
                if let num = Double(tok), num > 0 && num <= 10 {
                    return num
                }
                if let num = wordToNumber[tok] {
                    return num
                }
            }
        }
        return 1.0  // Default: single tablet/dose
    }

    // MARK: - Calculate Total Daily Dose
    private func calculateTotalDailyDose(baseDose: Double, frequency: String?, tabletMultiplier: Double) -> Double {
        let freqMultiplier = frequency.flatMap { freqMultipliers[$0.lowercased()] } ?? 1.0
        return baseDose * tabletMultiplier * freqMultiplier
    }

    // MARK: - Plausibility Check
    private func isPlausible(strength: Double, unit: String, definition: DrugDefinition) -> Bool {
        // Check unit requirements first - some drugs only accept specific units
        if let allowedUnits = definition.allowedUnits {
            if !allowedUnits.contains(unit.lowercased()) {
                return false  // Wrong unit for this medication
            }
        }

        // Check max dose - this is the primary validation
        if let maxDose = definition.maxDose, strength > maxDose {
            return false
        }

        // For psychiatric medications, check against minimum allowed strength
        // This prevents picking up doses that belong to other drugs (e.g., 1mg for Clozapine)
        if definition.category == .psychiatric {
            if let allowed = definition.allowedStrengths, let minStrength = allowed.min() {
                // Dose must be at least 50% of the minimum typical strength
                // (allows for half-tablets but rejects clearly wrong doses)
                if strength < minStrength * 0.5 {
                    return false
                }
            }
            // Allow any dose between min and max
            return strength > 0
        }

        // For physical meds without allowedStrengths, allow any positive dose
        guard let allowed = definition.allowedStrengths else {
            return strength > 0
        }

        // Check allowed strengths with ±5% tolerance
        let tolerance = 0.05
        for allowedStrength in allowed {
            if abs(strength - allowedStrength) <= allowedStrength * tolerance {
                return true
            }
        }
        return false
    }

    // MARK: - Main Extraction Function
    func extractMedications(from notes: [ClinicalNote], debug: Bool = false) -> ExtractedMedications {
        var drugMentions: [String: [MedicationMention]] = [:]

        for note in notes {
            let tokens = fastTokenise(note.body)
            let originalText = note.body

            if debug {
                print("DEBUG: Tokens = \(tokens)")
            }

            // Temporary storage for same-note aggregation: [drugName: [(dose, unit, freq, route, context, matchedText)]]
            var noteMentions: [String: [(Double, String, String?, String?, String, String)]] = [:]

            for (i, tok) in tokens.enumerated() {
                guard let first = tok.first else { continue }

                // Quick reject: no drug starts with this letter
                guard firstChars[first] != nil else { continue }

                // Check if token matches a drug
                guard var definition = tokenMap[tok] else { continue }

                // Check for depot formulation indicators in surrounding tokens
                let depotIndicators: Set<String> = ["depot", "embonate", "decanoate", "consta", "maintena", "xeplion", "trevicta", "zypadhera"]
                let lookAhead = min(i + 5, tokens.count)
                let lookBehind = max(0, i - 2)
                let surroundingTokens = Set(tokens[lookBehind..<lookAhead])

                if !surroundingTokens.intersection(depotIndicators).isEmpty {
                    // This is a depot formulation - try to find depot version
                    let depotName = definition.name + " Depot"
                    if let depotDef = drugDefinitions.first(where: { $0.name == depotName }) {
                        definition = depotDef
                    }
                }

                // Skip if this appears in a non-prescribing context (compliance, stopped, etc.)
                // Check tokens BEFORE the drug name for these contexts
                let lookBackStart = max(0, i - 5)
                let contextTokens = Array(tokens[lookBackStart..<i])
                let nonPrescribingKeywords: Set<String> = [
                    "compliance", "noncompliance", "adherence", "nonadherance",
                    "stopped", "stopping", "discontinued", "discontinue", "discontinuing",
                    "allergic", "allergy", "allergies", "intolerant", "intolerance",
                    "declined", "refusing", "refused", "not", "non", "nil", "none"
                ]
                // Check if any non-prescribing keyword is in the context
                let hasNonPrescribingContext = contextTokens.contains { nonPrescribingKeywords.contains($0) }
                if hasNonPrescribingContext {
                    continue  // Skip - this is discussing the drug, not prescribing it
                }

                // Skip if this looks like a blood level result (e.g., "Clozapine - 0.32")
                // Blood levels are typically small decimals without mg unit
                var looksLikeBloodLevel = false
                if i + 1 < tokens.count {
                    let nextTokens = tokens[(i+1)..<min(i+4, tokens.count)]
                    for tok in nextTokens {
                        if let val = Double(tok), val > 0 && val < 5 && tok.contains(".") {
                            looksLikeBloodLevel = true
                            break
                        }
                    }
                }
                if looksLikeBloodLevel {
                    continue  // Skip this drug mention - it's a blood level result
                }

                // Parse dose within ±3 tokens
                guard let (strength, unit) = parseDose(tokens: tokens, idx: i) else {
                    continue  // No dose found - skip (matches desktop behavior)
                }

                // Plausibility check (includes unit validation)
                guard isPlausible(strength: strength, unit: unit, definition: definition) else {
                    continue  // Dose not plausible for this drug
                }

                // Check for combined doses like "100mg and 375mg" or "100mg + 250mg"
                let combinedDoses = parseCombinedDoses(tokens: tokens, idx: i, definition: definition)
                var totalStrength = strength

                // If we found multiple doses, check if they should be summed
                if combinedDoses.count >= 2 {
                    let searchRange = Array(tokens[min(i+1, tokens.count-1)..<min(i+10, tokens.count)])

                    // Check for dose CHANGE pattern: "increased from 300mg to 325mg", "reduced from X to Y"
                    // In these cases, use the SECOND dose (the new dose), not the sum
                    let doseChangeIndicators: Set<String> = ["from", "increased", "reduced", "decreased", "changed", "titrated", "adjusted"]
                    let hasDoseChangeIndicator = !searchRange.filter { doseChangeIndicators.contains($0) }.isEmpty
                    let hasToKeyword = searchRange.contains("to")

                    if hasDoseChangeIndicator && hasToKeyword && combinedDoses.count == 2 {
                        // This is a dose change - use the second dose (the new dose after "to")
                        totalStrength = combinedDoses[1].0
                    } else {
                        // Check for breakdown pattern: "450mg (100mg OM 350mg ON)"
                        // If the first dose approximately equals the sum of remaining doses, it's a total+breakdown
                        // Don't sum - just use the first dose (the stated total)
                        let firstDose = combinedDoses[0].0
                        let remainingDoses = Array(combinedDoses.dropFirst())
                        let sumOfRemaining = remainingDoses.reduce(0.0) { $0 + $1.0 }

                        // If first dose ≈ sum of remaining (within 10%), it's a breakdown - use first dose
                        let isBreakdown = !remainingDoses.isEmpty && abs(firstDose - sumOfRemaining) <= firstDose * 0.1

                        if isBreakdown {
                            // Use the stated total (first dose)
                            totalStrength = firstDose
                        } else {
                            // Check if there's "and" or "plus" between doses
                            let hasConnector = searchRange.contains("and") || searchRange.contains("plus")

                            // Also check if two doses appear close together (within 3 tokens of each other)
                            var dosesAreClose = false
                            var dosePositions: [Int] = []
                            for (j, tok) in searchRange.enumerated() {
                                if tok.range(of: #"^\d+(?:\.\d+)?mg$"#, options: .regularExpression) != nil {
                                    dosePositions.append(j)
                                }
                            }
                            if dosePositions.count >= 2 {
                                for k in 0..<(dosePositions.count - 1) {
                                    if dosePositions[k + 1] - dosePositions[k] <= 3 {
                                        dosesAreClose = true
                                        break
                                    }
                                }
                            }

                            // Check for split dosing pattern: morning dose + evening/nocte dose
                            let morningIndicators: Set<String> = ["morning", "mane", "am", "om", "breakfast"]
                            let eveningIndicators: Set<String> = ["nocte", "night", "evening", "pm", "on", "bedtime"]
                            let hasMorningIndicator = !searchRange.filter { morningIndicators.contains($0) }.isEmpty
                            let hasEveningIndicator = !searchRange.filter { eveningIndicators.contains($0) }.isEmpty
                            let isSplitDosing = hasMorningIndicator && hasEveningIndicator

                            if hasConnector || dosesAreClose || isSplitDosing {
                                // Sum all doses found (they're meant to be taken together)
                                let summedDose = combinedDoses.reduce(0.0) { $0 + $1.0 }
                                if let maxDose = definition.maxDose, summedDose <= maxDose {
                                    totalStrength = summedDose
                                }
                            }
                        }
                    }
                }

                // Parse route and frequency
                let (route, freq) = parseRouteFreq(tokens: tokens, idx: i)

                // Parse tablet multiplier (x2, take 2, etc.)
                var tabletMultiplier = parseTabletMultiplier(tokens: tokens, idx: i)

                // Get frequency multiplier (BD=2, TDS=3, QDS=4)
                let freqMultiplier = freq.flatMap { freqMultipliers[$0.lowercased()] } ?? 1.0

                // Calculate the dose for this mention (base dose × tablet multiplier × frequency multiplier)
                var mentionDose = totalStrength * tabletMultiplier * freqMultiplier

                if debug {
                    print("DEBUG: Drug=\(definition.name), base=\(totalStrength), tablet=\(tabletMultiplier), freq=\(freq ?? "nil"), freqMult=\(freqMultiplier), mentionDose=\(mentionDose)")
                }

                // Validate multiplied dose against maxDose - if exceeded, ignore the multipliers
                if let maxDose = definition.maxDose, mentionDose > maxDose {
                    // Multiplied dose exceeds maximum - try without frequency multiplier
                    mentionDose = strength * tabletMultiplier
                    if mentionDose > maxDose {
                        // Still too high - use base dose only
                        tabletMultiplier = 1.0
                        mentionDose = strength
                    }
                }

                // Find matched text in original for highlighting (include dose context)
                let doseString = "\(Int(totalStrength))mg"
                let matchedText = findDrugDoseMatch(in: originalText, drugToken: tok, doseString: doseString)

                // Build context (limited)
                let contextStart = max(0, i - 2)
                let contextEnd = min(tokens.count, i + 5)
                let context = tokens[contextStart..<contextEnd].joined(separator: " ")

                let key = definition.name.lowercased()
                if noteMentions[key] == nil {
                    noteMentions[key] = []
                }
                noteMentions[key]?.append((mentionDose, unit, freq, route, context, matchedText))
            }

            // Aggregate mentions for each drug in this note
            for (drugKey, mentions) in noteMentions {
                guard let definition = drugDefinitions.first(where: { $0.name.lowercased() == drugKey }) else { continue }

                if debug {
                    print("DEBUG: Aggregating \(drugKey) with \(mentions.count) mentions")
                    for (idx, m) in mentions.enumerated() {
                        print("DEBUG:   Mention \(idx): dose=\(m.0), freq=\(m.2 ?? "nil")")
                    }
                }

                // Determine if we should sum doses (only for true split dosing)
                // Morning indicators
                let morningIndicators: Set<String> = ["mane", "morning", "am", "om"]
                // Evening indicators
                let eveningIndicators: Set<String> = ["nocte", "night", "evening", "bedtime", "pm", "on"]

                // Separate mentions into morning, evening, and other
                var morningDoses: [Double] = []
                var eveningDoses: [Double] = []
                var otherDoses: [Double] = []

                for mention in mentions {
                    if let freq = mention.2?.lowercased() {
                        if morningIndicators.contains(freq) {
                            morningDoses.append(mention.0)
                        } else if eveningIndicators.contains(freq) {
                            eveningDoses.append(mention.0)
                        } else {
                            otherDoses.append(mention.0)
                        }
                    } else {
                        otherDoses.append(mention.0)
                    }
                }

                if debug {
                    print("DEBUG:   morningDoses=\(morningDoses), eveningDoses=\(eveningDoses), otherDoses=\(otherDoses)")
                }

                // For medication lists with multiple entries for the same drug, we need to sum
                // BUT we must be careful not to double-count when BD multiplier already applied
                var totalDose: Double
                let unit = mentions.first?.1 ?? "mg"

                // Sum all morning doses + all evening doses + all other doses
                let totalMorning = morningDoses.reduce(0, +)
                let totalEvening = eveningDoses.reduce(0, +)
                let totalOther = otherDoses.reduce(0, +)

                // Check if we have multiple SEPARATE drug mentions (medication list pattern)
                // vs single mention with BD/split dosing already calculated
                let hasMultipleMentions = mentions.count > 1
                let hasSplitDosing = !morningDoses.isEmpty && !eveningDoses.isEmpty

                if hasMultipleMentions {
                    // Multiple entries for this drug
                    // The first entry might have BD multiplier already applied (e.g., 500mg BD = 1000mg)
                    // The other entries are individual doses (200mg ON, 100mg ON)
                    // We should sum them: 1000 + 200 + 100 = 1300
                    totalDose = totalMorning + totalEvening + totalOther
                    if debug {
                        print("DEBUG:   Multiple mentions: sum = \(totalDose)")
                    }
                } else if hasSplitDosing {
                    // Single entry with split dosing
                    totalDose = totalMorning + totalEvening
                } else {
                    // NO explicit split dosing detected - be CONSERVATIVE
                    // Only sum if we're very confident it's split dosing
                    let allDoses = morningDoses + eveningDoses + otherDoses
                    let uniqueDoses = Set(allDoses).sorted()

                    if uniqueDoses.count == 2 && allDoses.count == 2 {
                        // Two different doses mentioned EXACTLY twice total
                        // Check if they look like realistic split dosing (one smaller AM, one larger PM)
                        let smaller = uniqueDoses[0]
                        let larger = uniqueDoses[1]

                        // Only sum if the ratio is reasonable (typically AM dose ≤ PM dose for split dosing)
                        // and both doses are individually plausible
                        let ratio = larger / smaller
                        if ratio <= 4.0 && ratio >= 1.0 {
                            // Reasonable ratio for split dosing
                            totalDose = smaller + larger
                        } else {
                            // Unusual ratio - just take the larger dose
                            totalDose = larger
                        }
                    } else {
                        // Multiple mentions OR same dose repeated - take largest single dose
                        // This is more conservative and avoids false aggregation
                        totalDose = uniqueDoses.last ?? allDoses.first ?? 0
                    }
                }

                // Validate total against maxDose - if exceeded, use a single dose (not aggregated)
                if let maxDose = definition.maxDose, totalDose > maxDose {
                    // Total exceeds maximum - use the first/primary dose only, not aggregated
                    // Sort mentions by dose value and take a reasonable one
                    let individualDoses = mentions.map { $0.0 }.sorted()
                    // Find the largest individual dose that's within maxDose
                    if let validDose = individualDoses.last(where: { $0 <= maxDose }) {
                        totalDose = validDose
                    } else {
                        // All individual doses exceed max - take smallest
                        totalDose = individualDoses.first ?? 0
                    }
                }

                if debug {
                    print("DEBUG:   Final totalDose = \(totalDose)")
                }

                // Use the first frequency found, or nil
                let freq = mentions.compactMap { $0.2 }.first
                let route = mentions.compactMap { $0.3 }.first

                // Combine contexts and matched texts
                let context = mentions.map { $0.4 }.joined(separator: "; ")
                let matchedText = mentions.map { $0.5 }.first ?? definition.name

                // Format total dose: use integer if whole number
                let doseStr: String
                if totalDose.truncatingRemainder(dividingBy: 1) == 0 {
                    doseStr = "\(Int(totalDose))\(unit)"
                } else {
                    doseStr = "\(totalDose)\(unit)"
                }

                let mention = MedicationMention(
                    date: note.date,
                    drugName: definition.name,
                    dose: doseStr,
                    totalDailyDose: totalDose,
                    frequency: freq,
                    route: route,
                    noteId: note.id,
                    context: context,
                    matchedText: matchedText
                )

                if drugMentions[drugKey] == nil {
                    drugMentions[drugKey] = []
                }
                drugMentions[drugKey]?.append(mention)
            }
        }

        // Build classified drugs
        var classifiedDrugs: [ClassifiedDrug] = []

        for (drugName, mentions) in drugMentions {
            guard !mentions.isEmpty,
                  let definition = drugDefinitions.first(where: { $0.name.lowercased() == drugName }) else {
                continue
            }

            classifiedDrugs.append(ClassifiedDrug(
                name: definition.name,
                category: definition.category,
                psychiatricSubtype: definition.subtype,
                mentions: mentions.sorted { $0.date < $1.date }
            ))
        }

        // Sort by category, then subtype, then name
        classifiedDrugs.sort { drug1, drug2 in
            if drug1.category != drug2.category {
                return drug1.category == .psychiatric
            }
            if let sub1 = drug1.psychiatricSubtype, let sub2 = drug2.psychiatricSubtype {
                if sub1 != sub2 {
                    return sub1.rawValue < sub2.rawValue
                }
            }
            return drug1.name < drug2.name
        }

        return ExtractedMedications(drugs: classifiedDrugs)
    }

    // MARK: - Find Original Match
    private func findOriginalMatch(in text: String, for token: String) -> String {
        // Find case-insensitive match in original text
        if let range = text.range(of: token, options: .caseInsensitive) {
            return String(text[range])
        }
        return token
    }

    // Find the drug name + dose context in original text for highlighting
    private func findDrugDoseMatch(in text: String, drugToken: String, doseString: String) -> String {
        // Try to find the drug name followed by (or preceded by) the dose
        let textLower = text.lowercased()
        let drugLower = drugToken.lowercased()

        // Find all occurrences of the drug name
        var searchStart = textLower.startIndex
        var bestMatch: (range: Range<String.Index>, score: Int)?

        while let drugRange = textLower.range(of: drugLower, range: searchStart..<textLower.endIndex) {
            // Look for the dose within a window around the drug name
            let windowStart = text.index(drugRange.lowerBound, offsetBy: -50, limitedBy: text.startIndex) ?? text.startIndex
            let windowEnd = text.index(drugRange.upperBound, offsetBy: 80, limitedBy: text.endIndex) ?? text.endIndex
            let window = String(text[windowStart..<windowEnd])

            // Check if this window contains the dose
            if window.lowercased().contains(doseString.lowercased()) {
                // Find the actual dose position in the window
                if let doseRange = window.range(of: doseString, options: .caseInsensitive) {
                    // Calculate match quality (prefer drug + dose closer together)
                    let drugPosInWindow = window.distance(from: window.startIndex, to: window.range(of: drugToken, options: .caseInsensitive)?.lowerBound ?? window.startIndex)
                    let dosePosInWindow = window.distance(from: window.startIndex, to: doseRange.lowerBound)
                    let distance = abs(dosePosInWindow - drugPosInWindow)
                    let score = 100 - distance  // Higher score for closer matches

                    // Get the range from drug to dose (or dose to drug)
                    let matchStart: String.Index
                    let matchEnd: String.Index

                    if let drugWindowRange = window.range(of: drugToken, options: .caseInsensitive) {
                        if drugWindowRange.lowerBound < doseRange.lowerBound {
                            matchStart = drugWindowRange.lowerBound
                            matchEnd = doseRange.upperBound
                        } else {
                            matchStart = doseRange.lowerBound
                            matchEnd = drugWindowRange.upperBound
                        }

                        // Extend slightly to capture more context
                        let extendedStart = window.index(matchStart, offsetBy: -5, limitedBy: window.startIndex) ?? window.startIndex
                        let extendedEnd = window.index(matchEnd, offsetBy: 10, limitedBy: window.endIndex) ?? window.endIndex

                        if bestMatch == nil || score > bestMatch!.score {
                            bestMatch = (extendedStart..<extendedEnd, score)
                        }
                    }
                }
            }

            searchStart = drugRange.upperBound
        }

        // Return the best match, or fall back to just the drug name
        if let best = bestMatch {
            // Find the window again and extract the text
            if let drugRange = textLower.range(of: drugLower) {
                let windowStart = text.index(drugRange.lowerBound, offsetBy: -50, limitedBy: text.startIndex) ?? text.startIndex
                let windowEnd = text.index(drugRange.upperBound, offsetBy: 80, limitedBy: text.endIndex) ?? text.endIndex
                let window = String(text[windowStart..<windowEnd])

                if best.range.lowerBound >= window.startIndex && best.range.upperBound <= window.endIndex {
                    return String(window[best.range]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }

        // Fall back: try to find drug + dose pattern directly
        // Pattern like "Clozapine 325mg" or "325mg Clozapine"
        let patterns = [
            "\(drugToken)\\s+\\d+\\s*mg",  // Drug 325mg
            "\\d+\\s*mg\\s+\(drugToken)",  // 325mg Drug
            "\(drugToken)[^\\n]{0,30}\(doseString)",  // Drug ... dose
            "\(doseString)[^\\n]{0,30}\(drugToken)"   // dose ... Drug
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range, in: text) {
                return String(text[range])
            }
        }

        return findOriginalMatch(in: text, for: drugToken)
    }

    // MARK: - Utility Functions
    func getPsychiatricSubtypes() -> [PsychSubtype] {
        PsychSubtype.allCases.filter { $0 != .other }
    }
}
