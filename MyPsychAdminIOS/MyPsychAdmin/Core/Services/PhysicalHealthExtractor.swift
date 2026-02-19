//
//  PhysicalHealthExtractor.swift
//  MyPsychAdmin
//
//  Extracts BMI, BP, and blood test results from clinical notes
//  Matches desktop app's physical_health_extractor.py
//

import Foundation

// MARK: - Blood Test Definitions
struct BloodTestDefinition {
    let name: String
    let synonyms: [String]
    let unit: String
    let normalMin: Double?
    let normalMax: Double?

    var allNames: [String] {
        [name.lowercased()] + synonyms.map { $0.lowercased() }
    }
}

// MARK: - Physical Health Data Models
struct BMIReading: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let value: Double
    let noteId: UUID?
    let matchedText: String  // The actual text found in the note
}

struct BPReading: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let systolic: Int
    let diastolic: Int
    let noteId: UUID?
    let matchedText: String  // The actual text found in the note

    var formatted: String {
        "\(systolic)/\(diastolic)"
    }

    var category: BPCategory {
        if systolic < 120 && diastolic < 80 {
            return .normal
        } else if systolic < 130 && diastolic < 80 {
            return .elevated
        } else if systolic < 140 || diastolic < 90 {
            return .highStage1
        } else if systolic >= 140 || diastolic >= 90 {
            return .highStage2
        }
        return .normal
    }
}

enum BPCategory: String {
    case normal = "Normal"
    case elevated = "Elevated"
    case highStage1 = "High (Stage 1)"
    case highStage2 = "High (Stage 2)"

    var color: String {
        switch self {
        case .normal: return "green"
        case .elevated: return "yellow"
        case .highStage1: return "orange"
        case .highStage2: return "red"
        }
    }
}

struct BloodTestResult: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let testName: String
    let value: Double
    let unit: String
    let normalMin: Double?
    let normalMax: Double?
    let noteId: UUID?
    let matchedText: String  // The actual text found in the note (e.g., "Alkaline Phosphatase" instead of "ALP")

    var isAbnormal: Bool {
        if let min = normalMin, value < min { return true }
        if let max = normalMax, value > max { return true }
        return false
    }

    var isLow: Bool {
        guard let min = normalMin else { return false }
        return value < min
    }

    var isHigh: Bool {
        guard let max = normalMax else { return false }
        return value > max
    }

    var flagSymbol: String {
        if isLow { return "↓" }
        if isHigh { return "↑" }
        return ""
    }
}

struct ExtractedPhysicalHealth {
    var bmiReadings: [BMIReading] = []
    var bpReadings: [BPReading] = []
    var bloodTests: [String: [BloodTestResult]] = [:] // Keyed by canonical test name
}

// MARK: - Physical Health Extractor
class PhysicalHealthExtractor {
    static let shared = PhysicalHealthExtractor()

    // Pre-compiled regexes for performance
    private var bmiRegex: NSRegularExpression?
    private var bpRegex: NSRegularExpression?
    private var weightRegex: NSRegularExpression?
    private var heightRegex: NSRegularExpression?
    private var bloodTestRegexes: [(BloodTestDefinition, NSRegularExpression)] = []

    private init() {
        // Pre-compile all regexes once
        bmiRegex = try? NSRegularExpression(pattern: bmiPattern, options: [])
        bpRegex = try? NSRegularExpression(pattern: bpPattern, options: [])
        weightRegex = try? NSRegularExpression(pattern: weightPattern, options: [])
        heightRegex = try? NSRegularExpression(pattern: heightPattern, options: [])

        // Pre-compile blood test regexes
        for definition in canonicalBloods {
            let allNames = definition.allNames
            let escapedNames = allNames.map { NSRegularExpression.escapedPattern(for: $0) }
            let namesPattern = escapedNames.joined(separator: "|")
            let pattern = "(?i)\\b(\(namesPattern))\\b\\s*[:=]?\\s*([<>]?\\s*\\d+\\.?\\d*)"
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                bloodTestRegexes.append((definition, regex))
            }
        }
    }

    // MARK: - Canonical Blood Tests (matching desktop CANONICAL_BLOODS)
    private let canonicalBloods: [BloodTestDefinition] = [
        // Full Blood Count
        BloodTestDefinition(name: "Haemoglobin", synonyms: ["Hb", "Hgb", "hemoglobin"], unit: "g/L", normalMin: 120, normalMax: 170),
        BloodTestDefinition(name: "WBC", synonyms: ["White cells", "White blood cells", "WCC", "Leucocytes"], unit: "x10⁹/L", normalMin: 4.0, normalMax: 11.0),
        BloodTestDefinition(name: "Platelets", synonyms: ["Plts", "PLT", "Thrombocytes"], unit: "x10⁹/L", normalMin: 150, normalMax: 400),
        BloodTestDefinition(name: "MCV", synonyms: ["Mean cell volume", "Mean corpuscular volume"], unit: "fL", normalMin: 80, normalMax: 100),
        BloodTestDefinition(name: "MCH", synonyms: ["Mean cell haemoglobin"], unit: "pg", normalMin: 27, normalMax: 32),
        BloodTestDefinition(name: "Haematocrit", synonyms: ["Hct", "HCT", "PCV"], unit: "%", normalMin: 36, normalMax: 50),
        BloodTestDefinition(name: "RBC", synonyms: ["Red cells", "Red blood cells", "Erythrocytes"], unit: "x10¹²/L", normalMin: 4.0, normalMax: 6.0),
        BloodTestDefinition(name: "Neutrophils", synonyms: ["Neut", "Neutros"], unit: "x10⁹/L", normalMin: 2.0, normalMax: 7.5),
        BloodTestDefinition(name: "Lymphocytes", synonyms: ["Lymphs"], unit: "x10⁹/L", normalMin: 1.0, normalMax: 4.0),
        BloodTestDefinition(name: "Monocytes", synonyms: ["Monos"], unit: "x10⁹/L", normalMin: 0.2, normalMax: 1.0),
        BloodTestDefinition(name: "Eosinophils", synonyms: ["Eos"], unit: "x10⁹/L", normalMin: 0.0, normalMax: 0.5),
        BloodTestDefinition(name: "Basophils", synonyms: ["Basos"], unit: "x10⁹/L", normalMin: 0.0, normalMax: 0.1),

        // Renal Function
        BloodTestDefinition(name: "Sodium", synonyms: ["Na", "Na+"], unit: "mmol/L", normalMin: 135, normalMax: 145),
        BloodTestDefinition(name: "Potassium", synonyms: ["K", "K+"], unit: "mmol/L", normalMin: 3.5, normalMax: 5.0),
        BloodTestDefinition(name: "Urea", synonyms: ["Blood urea", "BUN"], unit: "mmol/L", normalMin: 2.5, normalMax: 7.8),
        BloodTestDefinition(name: "Creatinine", synonyms: ["Creat", "Cr"], unit: "μmol/L", normalMin: 60, normalMax: 120),
        BloodTestDefinition(name: "eGFR", synonyms: ["GFR", "Estimated GFR"], unit: "mL/min", normalMin: 90, normalMax: nil),
        BloodTestDefinition(name: "Chloride", synonyms: ["Cl", "Cl-"], unit: "mmol/L", normalMin: 96, normalMax: 106),
        BloodTestDefinition(name: "Bicarbonate", synonyms: ["HCO3", "CO2"], unit: "mmol/L", normalMin: 22, normalMax: 29),

        // Liver Function
        BloodTestDefinition(name: "ALT", synonyms: ["Alanine aminotransferase", "SGPT"], unit: "U/L", normalMin: 7, normalMax: 56),
        BloodTestDefinition(name: "AST", synonyms: ["Aspartate aminotransferase", "SGOT"], unit: "U/L", normalMin: 10, normalMax: 40),
        BloodTestDefinition(name: "ALP", synonyms: ["Alkaline phosphatase", "Alk phos"], unit: "U/L", normalMin: 44, normalMax: 147),
        BloodTestDefinition(name: "GGT", synonyms: ["Gamma GT", "γGT"], unit: "U/L", normalMin: 9, normalMax: 48),
        BloodTestDefinition(name: "Bilirubin", synonyms: ["Total bilirubin", "Bili"], unit: "μmol/L", normalMin: 3, normalMax: 21),
        BloodTestDefinition(name: "Albumin", synonyms: ["Alb"], unit: "g/L", normalMin: 35, normalMax: 50),
        BloodTestDefinition(name: "Total Protein", synonyms: ["TP", "Protein"], unit: "g/L", normalMin: 60, normalMax: 83),

        // Lipids
        BloodTestDefinition(name: "Total Cholesterol", synonyms: ["Cholesterol", "TC"], unit: "mmol/L", normalMin: nil, normalMax: 5.0),
        BloodTestDefinition(name: "LDL", synonyms: ["LDL cholesterol", "LDL-C"], unit: "mmol/L", normalMin: nil, normalMax: 3.0),
        BloodTestDefinition(name: "HDL", synonyms: ["HDL cholesterol", "HDL-C"], unit: "mmol/L", normalMin: 1.0, normalMax: nil),
        BloodTestDefinition(name: "Triglycerides", synonyms: ["TG", "Trigs"], unit: "mmol/L", normalMin: nil, normalMax: 1.7),

        // Thyroid
        BloodTestDefinition(name: "TSH", synonyms: ["Thyroid stimulating hormone"], unit: "mU/L", normalMin: 0.4, normalMax: 4.0),
        BloodTestDefinition(name: "Free T4", synonyms: ["FT4", "T4", "Thyroxine"], unit: "pmol/L", normalMin: 12, normalMax: 22),
        BloodTestDefinition(name: "Free T3", synonyms: ["FT3", "T3"], unit: "pmol/L", normalMin: 3.1, normalMax: 6.8),

        // Glucose/Diabetes
        BloodTestDefinition(name: "Glucose", synonyms: ["Blood glucose", "BM", "Blood sugar", "Fasting glucose"], unit: "mmol/L", normalMin: 3.5, normalMax: 6.0),
        BloodTestDefinition(name: "HbA1c", synonyms: ["Glycated haemoglobin", "A1c", "HBA1C"], unit: "mmol/mol", normalMin: nil, normalMax: 48),

        // Inflammatory
        BloodTestDefinition(name: "CRP", synonyms: ["C-reactive protein", "C reactive protein"], unit: "mg/L", normalMin: nil, normalMax: 5),
        BloodTestDefinition(name: "ESR", synonyms: ["Erythrocyte sedimentation rate", "Sed rate"], unit: "mm/hr", normalMin: nil, normalMax: 20),

        // Cardiac
        BloodTestDefinition(name: "Troponin", synonyms: ["TnI", "TnT", "High sensitivity troponin", "hs-TnI"], unit: "ng/L", normalMin: nil, normalMax: 14),
        BloodTestDefinition(name: "BNP", synonyms: ["Brain natriuretic peptide", "NT-proBNP"], unit: "pg/mL", normalMin: nil, normalMax: 100),

        // Iron Studies
        BloodTestDefinition(name: "Iron", synonyms: ["Serum iron", "Fe"], unit: "μmol/L", normalMin: 10, normalMax: 30),
        BloodTestDefinition(name: "Ferritin", synonyms: ["Serum ferritin"], unit: "μg/L", normalMin: 20, normalMax: 300),
        BloodTestDefinition(name: "TIBC", synonyms: ["Total iron binding capacity"], unit: "μmol/L", normalMin: 45, normalMax: 72),
        BloodTestDefinition(name: "Transferrin", synonyms: ["Transferrin saturation", "TSAT"], unit: "%", normalMin: 20, normalMax: 50),

        // Vitamins
        BloodTestDefinition(name: "Vitamin B12", synonyms: ["B12", "Cobalamin"], unit: "ng/L", normalMin: 200, normalMax: 900),
        BloodTestDefinition(name: "Folate", synonyms: ["Folic acid", "Serum folate"], unit: "μg/L", normalMin: 3, normalMax: 20),
        BloodTestDefinition(name: "Vitamin D", synonyms: ["25-OH vitamin D", "Cholecalciferol", "Vit D"], unit: "nmol/L", normalMin: 50, normalMax: nil),

        // Bone Profile
        BloodTestDefinition(name: "Calcium", synonyms: ["Ca", "Serum calcium", "Corrected calcium"], unit: "mmol/L", normalMin: 2.2, normalMax: 2.6),
        BloodTestDefinition(name: "Phosphate", synonyms: ["PO4", "Phosphorus"], unit: "mmol/L", normalMin: 0.8, normalMax: 1.5),
        BloodTestDefinition(name: "Magnesium", synonyms: ["Mg"], unit: "mmol/L", normalMin: 0.7, normalMax: 1.0),

        // Clotting
        BloodTestDefinition(name: "INR", synonyms: ["International normalised ratio"], unit: "", normalMin: 0.9, normalMax: 1.1),
        BloodTestDefinition(name: "PT", synonyms: ["Prothrombin time"], unit: "seconds", normalMin: 11, normalMax: 13.5),
        BloodTestDefinition(name: "APTT", synonyms: ["Activated partial thromboplastin time", "aPTT"], unit: "seconds", normalMin: 25, normalMax: 35),
        BloodTestDefinition(name: "Fibrinogen", synonyms: ["Fib"], unit: "g/L", normalMin: 2.0, normalMax: 4.0),
        BloodTestDefinition(name: "D-dimer", synonyms: ["D dimer"], unit: "ng/mL", normalMin: nil, normalMax: 500),

        // Drug Levels (psych-relevant)
        BloodTestDefinition(name: "Lithium", synonyms: ["Li", "Serum lithium"], unit: "mmol/L", normalMin: 0.4, normalMax: 1.0),
        BloodTestDefinition(name: "Valproate", synonyms: ["Valproic acid", "Sodium valproate", "Epilim level"], unit: "mg/L", normalMin: 50, normalMax: 100),
        BloodTestDefinition(name: "Carbamazepine", synonyms: ["Tegretol level"], unit: "mg/L", normalMin: 4, normalMax: 12),
        BloodTestDefinition(name: "Clozapine", synonyms: ["Clozapine level", "Clozaril level"], unit: "μg/L", normalMin: 350, normalMax: 600),
        BloodTestDefinition(name: "Prolactin", synonyms: ["PRL"], unit: "mU/L", normalMin: 86, normalMax: 324),
    ]

    // MARK: - Regex Patterns
    private let bmiPattern = #"(?i)(?:BMI|body mass index)\s*[:=]?\s*(\d+\.?\d*)"#
    private let bpPattern = #"(?i)(?:BP|blood pressure)\s*[:=]?\s*(\d{2,3})\s*/\s*(\d{2,3})"#
    private let weightPattern = #"(?i)(?:weight|wt)\s*[:=]?\s*(\d+\.?\d*)\s*(?:kg|kilos?)"#
    private let heightPattern = #"(?i)(?:height|ht)\s*[:=]?\s*(\d+\.?\d*)\s*(?:m|cm|metres?|meters?)"#

    // MARK: - Main Extraction Function
    func extractPhysicalHealth(from notes: [ClinicalNote]) -> ExtractedPhysicalHealth {
        var result = ExtractedPhysicalHealth()

        for note in notes {
            // Extract BMI
            if let bmi = extractBMI(from: note.body, date: note.date, noteId: note.id) {
                result.bmiReadings.append(bmi)
            }

            // Extract BP
            if let bp = extractBP(from: note.body, date: note.date, noteId: note.id) {
                result.bpReadings.append(bp)
            }

            // Extract Blood Tests
            let bloodTests = extractBloodTests(from: note.body, date: note.date, noteId: note.id)
            for test in bloodTests {
                if result.bloodTests[test.testName] == nil {
                    result.bloodTests[test.testName] = []
                }
                result.bloodTests[test.testName]?.append(test)
            }
        }

        // Sort by date
        result.bmiReadings.sort { $0.date < $1.date }
        result.bpReadings.sort { $0.date < $1.date }
        for (key, _) in result.bloodTests {
            result.bloodTests[key]?.sort { $0.date < $1.date }
        }

        return result
    }

    // MARK: - BMI Extraction
    private func extractBMI(from text: String, date: Date, noteId: UUID) -> BMIReading? {
        let range = NSRange(text.startIndex..., in: text)

        // Try direct BMI match
        if let regex = bmiRegex,
           let match = regex.firstMatch(in: text, options: [], range: range) {
            if let valueRange = Range(match.range(at: 1), in: text),
               let fullRange = Range(match.range, in: text),
               let value = Double(text[valueRange]) {
                if value >= 10 && value <= 70 {
                    let matchedText = String(text[fullRange])
                    return BMIReading(date: date, value: value, noteId: noteId, matchedText: matchedText)
                }
            }
        }

        // Try to calculate from weight and height
        var weight: Double?
        var height: Double?
        var weightMatch = ""
        var heightMatch = ""

        if let regex = weightRegex,
           let match = regex.firstMatch(in: text, options: [], range: range) {
            if let valueRange = Range(match.range(at: 1), in: text),
               let fullRange = Range(match.range, in: text) {
                weight = Double(text[valueRange])
                weightMatch = String(text[fullRange])
            }
        }

        if let regex = heightRegex,
           let match = regex.firstMatch(in: text, options: [], range: range) {
            if let valueRange = Range(match.range(at: 1), in: text),
               let fullRange = Range(match.range, in: text) {
                var h = Double(text[valueRange]) ?? 0
                // Convert cm to m if needed
                if h > 3 { h = h / 100 }
                height = h
                heightMatch = String(text[fullRange])
            }
        }

        if let w = weight, let h = height, h > 0 {
            let bmi = w / (h * h)
            if bmi >= 10 && bmi <= 70 {
                // Use weight match as the highlight since it's more specific
                let matchedText = weightMatch.isEmpty ? "weight" : weightMatch
                return BMIReading(date: date, value: bmi, noteId: noteId, matchedText: matchedText)
            }
        }

        return nil
    }

    // MARK: - BP Extraction
    private func extractBP(from text: String, date: Date, noteId: UUID) -> BPReading? {
        guard let regex = bpRegex else { return nil }
        let range = NSRange(text.startIndex..., in: text)

        if let match = regex.firstMatch(in: text, options: [], range: range) {
            if let sysRange = Range(match.range(at: 1), in: text),
               let diaRange = Range(match.range(at: 2), in: text),
               let fullRange = Range(match.range, in: text),
               let systolic = Int(text[sysRange]),
               let diastolic = Int(text[diaRange]) {
                // Validate reasonable BP values
                if systolic >= 60 && systolic <= 250 && diastolic >= 30 && diastolic <= 150 {
                    let matchedText = String(text[fullRange])
                    return BPReading(date: date, systolic: systolic, diastolic: diastolic, noteId: noteId, matchedText: matchedText)
                }
            }
        }
        return nil
    }

    // MARK: - Blood Test Extraction (optimized with pre-compiled regexes)
    private func extractBloodTests(from text: String, date: Date, noteId: UUID) -> [BloodTestResult] {
        var results: [BloodTestResult] = []
        var foundTests: Set<String> = [] // Track found test+value combos to avoid duplicates
        let range = NSRange(text.startIndex..., in: text)

        // Use pre-compiled regexes - single pass per test type
        for (definition, regex) in bloodTestRegexes {
            let matches = regex.matches(in: text, options: [], range: range)

            for match in matches {
                if let nameRange = Range(match.range(at: 1), in: text),
                   let valueRange = Range(match.range(at: 2), in: text) {
                    var valueStr = String(text[valueRange]).trimmingCharacters(in: .whitespaces)
                    valueStr = valueStr.replacingOccurrences(of: "<", with: "")
                        .replacingOccurrences(of: ">", with: "")
                        .trimmingCharacters(in: .whitespaces)

                    if let value = Double(valueStr), value > 0 {
                        // Avoid duplicates using a simple key
                        let key = "\(definition.name)-\(value)"
                        if !foundTests.contains(key) {
                            foundTests.insert(key)
                            // Capture the actual matched name from the note (e.g., "Alkaline Phosphatase" not "ALP")
                            let matchedName = String(text[nameRange])
                            results.append(BloodTestResult(
                                date: date,
                                testName: definition.name,
                                value: value,
                                unit: definition.unit,
                                normalMin: definition.normalMin,
                                normalMax: definition.normalMax,
                                noteId: noteId,
                                matchedText: matchedName
                            ))
                        }
                    }
                }
            }
        }

        return results
    }

    // MARK: - Utility
    func getDefinition(for testName: String) -> BloodTestDefinition? {
        canonicalBloods.first { $0.name == testName }
    }

    func getAllTestNames() -> [String] {
        canonicalBloods.map { $0.name }
    }
}
