//
//  ClinicalNote.swift
//  MyPsychAdmin
//

import Foundation

struct ClinicalNote: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var date: Date
    var type: String
    var rawType: String
    var author: String
    var body: String
    var source: NoteSource
    var category: ClinicalCategory?
    var preview: String {
        String(body.prefix(200))
    }

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        type: String = "",
        rawType: String = "",
        author: String = "",
        body: String = "",
        source: NoteSource = .manual,
        category: ClinicalCategory? = nil
    ) {
        self.id = id
        self.date = date
        self.type = type
        self.rawType = rawType
        self.author = author
        self.body = body
        self.source = source
        self.category = category
    }
}

enum NoteSource: String, Codable, CaseIterable, Hashable {
    case rio = "RIO"
    case carenotes = "CareNotes"
    case epjs = "EPJS"
    case manual = "Manual"
    case imported = "Imported"
}

// MARK: - Clinical Categories (matching desktop app exactly)
enum ClinicalCategory: String, Codable, CaseIterable, Identifiable {
    // 18 categories matching the desktop Python app
    case legal = "Legal"
    case diagnosis = "Diagnosis"
    case circumstancesOfAdmission = "Circumstances of Admission"
    case historyOfPresentingComplaint = "History of Presenting Complaint"
    case pastPsychiatricHistory = "Past Psychiatric History"
    case medicationHistory = "Medication History"
    case drugAndAlcoholHistory = "Drug and Alcohol History"
    case pastMedicalHistory = "Past Medical History"
    case forensicHistory = "Forensic History"
    case personalHistory = "Personal History"
    case mentalStateExamination = "Mental State Examination"
    case risk = "Risk"
    case physicalExamination = "Physical Examination"
    case ecg = "ECG"
    case impression = "Impression"
    case plan = "Plan"
    case capacityAssessment = "Capacity Assessment"
    case summary = "Summary"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var iconName: String {
        switch self {
        case .legal: return "building.columns"
        case .diagnosis: return "stethoscope"
        case .circumstancesOfAdmission: return "door.left.hand.open"
        case .historyOfPresentingComplaint: return "clock.arrow.circlepath"
        case .pastPsychiatricHistory: return "brain"
        case .medicationHistory: return "pills"
        case .drugAndAlcoholHistory: return "wineglass"
        case .pastMedicalHistory: return "heart.text.square"
        case .forensicHistory: return "checkmark.seal"
        case .personalHistory: return "person.2"
        case .mentalStateExamination: return "brain.head.profile"
        case .risk: return "exclamationmark.triangle"
        case .physicalExamination: return "figure.stand"
        case .ecg: return "waveform.path.ecg"
        case .impression: return "lightbulb"
        case .plan: return "list.bullet.clipboard"
        case .capacityAssessment: return "checkmark.shield"
        case .summary: return "doc.text"
        }
    }

    // Keywords for detecting this category in text (matching desktop extractor)
    var detectionKeywords: [String] {
        switch self {
        case .legal:
            return ["legal status", "mha status", "section", "detained", "informal", "voluntary", "s2", "s3", "s37", "s41", "mha"]
        case .diagnosis:
            return ["diagnosis", "diagnoses", "icd", "dsm", "f20", "f31", "f32", "f33", "schizophrenia", "bipolar", "depression"]
        case .circumstancesOfAdmission:
            return ["circumstances", "admission", "referral", "referred by", "presenting", "background to admission"]
        case .historyOfPresentingComplaint:
            return ["hpc", "history of presenting", "presenting complaint", "presenting issue", "pc:"]
        case .pastPsychiatricHistory:
            return ["pph", "past psychiatric", "previous psychiatric", "previous admissions", "past psych"]
        case .medicationHistory:
            return ["medication", "drug history", "dhx", "current meds", "allergies", "prescriptions"]
        case .drugAndAlcoholHistory:
            return ["drug and alcohol", "substance", "alcohol", "cannabis", "cocaine", "heroin", "illicit", "units per week"]
        case .pastMedicalHistory:
            return ["pmh", "past medical", "medical history", "physical health history", "comorbidities"]
        case .forensicHistory:
            return ["forensic", "offending", "criminal", "arrest", "conviction", "prison", "police", "court"]
        case .personalHistory:
            return ["personal history", "social history", "family history", "relationships", "occupation", "employment", "childhood", "developmental"]
        case .mentalStateExamination:
            return ["mse", "mental state", "appearance", "behaviour", "speech", "mood", "affect", "thought", "perception", "cognition", "insight"]
        case .risk:
            return ["risk", "suicide", "self-harm", "violence", "harm to others", "safeguarding", "risk assessment"]
        case .physicalExamination:
            return ["o/e", "on examination", "physical examination", "observations", "obs", "vitals"]
        case .ecg:
            return ["ecg", "electrocardiogram", "qtc", "rhythm"]
        case .impression:
            return ["impression", "formulation", "overview", "clinical impression"]
        case .plan:
            return ["plan", "management", "treatment plan", "next steps", "recommendations"]
        case .capacityAssessment:
            return ["capacity", "mca", "mental capacity", "best interests", "decision making"]
        case .summary:
            return ["summary", "overall", "review", "patient seen", "concluded"]
        }
    }
}

struct ExtractedData: Codable, Equatable {
    var categories: [ClinicalCategory: [String]] = [:]
    var patientInfo: PatientInfo = PatientInfo()
    var notes: [ClinicalNote] = []
    var timeline: [TimelineEvent] = []

    mutating func addToCategory(_ category: ClinicalCategory, content: String) {
        if categories[category] == nil {
            categories[category] = []
        }
        categories[category]?.append(content)
    }

    func getCategory(_ category: ClinicalCategory) -> [String] {
        categories[category] ?? []
    }
}

struct TimelineEvent: Identifiable, Codable, Equatable {
    let id: UUID
    var date: Date
    var type: TimelineEventType
    var description: String
    var location: String?

    init(id: UUID = UUID(), date: Date, type: TimelineEventType, description: String, location: String? = nil) {
        self.id = id
        self.date = date
        self.type = type
        self.description = description
        self.location = location
    }
}

enum TimelineEventType: String, Codable {
    case admission = "Admission"
    case discharge = "Discharge"
    case transfer = "Transfer"
    case cto = "CTO"
    case recall = "Recall"
    case incident = "Incident"
    case review = "Review"
}
