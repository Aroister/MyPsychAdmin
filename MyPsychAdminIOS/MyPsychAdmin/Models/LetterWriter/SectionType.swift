//
//  SectionType.swift
//  MyPsychAdmin
//
//  Defines the 16 letter sections matching the desktop app
//

import SwiftUI

enum SectionType: String, CaseIterable, Identifiable, Codable {
    case front = "front"
    case presentingComplaint = "pc"
    case historyOfPresentingComplaint = "hpc"
    case affect = "affect"
    case anxiety = "anxiety"
    case psychosis = "psychosis"
    case psychiatricHistory = "psychhx"
    case backgroundHistory = "background"
    case drugsAlcohol = "drugalc"
    case socialHistory = "social"
    case forensicHistory = "forensic"
    case physicalHealth = "physical"
    case function = "function"
    case mentalStateExam = "mse"
    case summary = "summary"
    case plan = "plan"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .front: return "Front Page"
        case .presentingComplaint: return "Presenting Complaint"
        case .historyOfPresentingComplaint: return "History of Presenting Complaint"
        case .affect: return "Affect"
        case .anxiety: return "Anxiety & Related Disorders"
        case .psychosis: return "Psychosis"
        case .psychiatricHistory: return "Psychiatric History"
        case .backgroundHistory: return "Background History"
        case .drugsAlcohol: return "Drug and Alcohol History"
        case .socialHistory: return "Social History"
        case .forensicHistory: return "Forensic History"
        case .physicalHealth: return "Physical Health"
        case .function: return "Function"
        case .mentalStateExam: return "Mental State Examination"
        case .summary: return "Summary"
        case .plan: return "Plan"
        }
    }

    var shortTitle: String {
        switch self {
        case .front: return "Front"
        case .presentingComplaint: return "PC"
        case .historyOfPresentingComplaint: return "HPC"
        case .affect: return "Affect"
        case .anxiety: return "Anxiety"
        case .psychosis: return "Psychosis"
        case .psychiatricHistory: return "Psych Hx"
        case .backgroundHistory: return "Background"
        case .drugsAlcohol: return "D&A"
        case .socialHistory: return "Social"
        case .forensicHistory: return "Forensic"
        case .physicalHealth: return "Physical"
        case .function: return "Function"
        case .mentalStateExam: return "MSE"
        case .summary: return "Summary"
        case .plan: return "Plan"
        }
    }

    var headerColor: Color {
        switch self {
        case .front:
            return Color(red: 0.15, green: 0.39, blue: 0.92) // Blue
        case .presentingComplaint, .historyOfPresentingComplaint:
            return Color(red: 0.13, green: 0.59, blue: 0.56) // Teal
        case .affect, .anxiety, .psychosis:
            return Color(red: 0.58, green: 0.24, blue: 0.75) // Purple
        case .psychiatricHistory, .backgroundHistory, .drugsAlcohol, .socialHistory, .forensicHistory:
            return Color(red: 0.13, green: 0.55, blue: 0.33) // Green
        case .physicalHealth, .function:
            return Color(red: 0.93, green: 0.55, blue: 0.14) // Orange
        case .mentalStateExam:
            return Color(red: 0.31, green: 0.27, blue: 0.71) // Indigo
        case .summary, .plan:
            return Color(red: 0.86, green: 0.21, blue: 0.27) // Red
        }
    }

    var extractorCategory: ClinicalCategory? {
        switch self {
        case .front: return nil // Front page is assembled from patient info
        case .presentingComplaint: return .circumstancesOfAdmission
        case .historyOfPresentingComplaint: return .historyOfPresentingComplaint
        case .psychiatricHistory: return .pastPsychiatricHistory
        case .backgroundHistory: return .personalHistory
        case .socialHistory: return .personalHistory
        case .forensicHistory: return .forensicHistory
        case .drugsAlcohol: return .drugAndAlcoholHistory
        case .physicalHealth: return .pastMedicalHistory
        case .function: return nil // Function not directly mapped
        case .mentalStateExam: return .mentalStateExamination
        case .summary: return .summary
        case .plan: return .plan
        case .affect, .anxiety, .psychosis: return nil
        }
    }

    var iconName: String {
        switch self {
        case .front: return "person.text.rectangle"
        case .presentingComplaint: return "exclamationmark.bubble"
        case .historyOfPresentingComplaint: return "clock.arrow.circlepath"
        case .affect: return "face.smiling"
        case .anxiety: return "waveform.path.ecg"
        case .psychosis: return "brain.head.profile"
        case .psychiatricHistory: return "list.clipboard"
        case .backgroundHistory: return "book.closed"
        case .drugsAlcohol: return "pills"
        case .socialHistory: return "person.2"
        case .forensicHistory: return "building.columns"
        case .physicalHealth: return "heart.text.square"
        case .function: return "figure.walk"
        case .mentalStateExam: return "checklist"
        case .summary: return "doc.text"
        case .plan: return "list.bullet.clipboard"
        }
    }

    static var orderedSections: [SectionType] {
        [
            .front, .presentingComplaint, .historyOfPresentingComplaint,
            .affect, .anxiety, .psychosis,
            .psychiatricHistory, .backgroundHistory, .drugsAlcohol,
            .socialHistory, .forensicHistory, .physicalHealth,
            .function, .mentalStateExam, .summary, .plan
        ]
    }
}
