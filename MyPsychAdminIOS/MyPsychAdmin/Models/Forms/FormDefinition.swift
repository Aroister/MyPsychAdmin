//
//  FormDefinition.swift
//  MyPsychAdmin
//
//  Base protocol and types for statutory forms
//

import SwiftUI
import Foundation

// MARK: - Form Protocol
protocol StatutoryForm: Identifiable, Codable {
    var id: UUID { get }
    var formType: FormType { get }
    var patientInfo: PatientInfo { get set }
    var clinicianInfo: ClinicianInfo { get set }
    var createdAt: Date { get }
    var modifiedAt: Date { get set }

    func validate() -> [FormValidationError]
    func toHTML() -> String
}

struct FormValidationError: Identifiable {
    let id = UUID()
    let field: String
    let message: String
}

// MARK: - Form Types
enum FormType: String, CaseIterable, Identifiable, Codable {
    // MHA Forms
    case a2 = "A2"
    case a3 = "A3"
    case a4 = "A4"
    case a6 = "A6"
    case a7 = "A7"
    case a8 = "A8"
    case h1 = "H1"
    case h5 = "H5"

    // CTO Forms
    case cto1 = "CTO1"
    case cto3 = "CTO3"
    case cto4 = "CTO4"
    case cto5 = "CTO5"
    case cto7 = "CTO7"

    // Other Forms
    case t2 = "T2"
    case m2 = "M2"
    case mojLeave = "MOJ Leave"
    case mojASR = "MOJ ASR"

    // Risk Assessment Forms
    case hcr20 = "HCR-20"

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .a2: return "A2 - S2 AMHP Application"
        case .a3: return "A3 - S2 Medical (Joint)"
        case .a4: return "A4 - S2 Medical (Single)"
        case .a6: return "A6 - S3 AMHP Application"
        case .a7: return "A7 - S3 Medical (Joint)"
        case .a8: return "A8 - S3 Medical (Single)"
        case .h1: return "H1 - S5(2) Doctor's Holding Power"
        case .h5: return "H5 - S20 Renewal"
        case .cto1: return "CTO1 - Community Treatment Order"
        case .cto3: return "CTO3 - CTO Recall"
        case .cto4: return "CTO4 - CTO Revocation"
        case .cto5: return "CTO5 - CTO Conditions Variation"
        case .cto7: return "CTO7 - CTO Extension"
        case .t2: return "T2 - Consent to Treatment"
        case .m2: return "M2 - Transfer Between Hospitals"
        case .mojLeave: return "MOJ Leave Application"
        case .mojASR: return "MOJ Annual Statutory Review"
        case .hcr20: return "HCR-20 V3 Risk Assessment"
        }
    }

    var shortDescription: String {
        switch self {
        case .a2: return "Application by AMHP for admission under Section 2"
        case .a3: return "Joint medical recommendation for Section 2"
        case .a4: return "Single medical recommendation for Section 2"
        case .a6: return "Application by AMHP for admission under Section 3"
        case .a7: return "Joint medical recommendation for Section 3"
        case .a8: return "Single medical recommendation for Section 3"
        case .h1: return "Doctor's holding power under Section 5(2)"
        case .h5: return "Renewal of detention under Section 20"
        case .cto1: return "Application for Community Treatment Order"
        case .cto3: return "Notice of recall to hospital"
        case .cto4: return "Revocation of Community Treatment Order"
        case .cto5: return "Variation of CTO conditions"
        case .cto7: return "Extension of Community Treatment Order"
        case .t2: return "Certificate of consent to treatment"
        case .m2: return "Authority for transfer between hospitals"
        case .mojLeave: return "Application for leave of absence (restricted patients)"
        case .mojASR: return "Annual statutory report for Ministry of Justice"
        case .hcr20: return "Historical-Clinical-Risk Management violence risk assessment"
        }
    }

    var category: FormCategory {
        switch self {
        case .a2, .a6: return .socialWork
        case .a3, .a7: return .medicalJoint
        case .a4, .a8: return .medicalSingle
        case .h1, .h5: return .holdingPower
        case .t2, .m2: return .treatmentTransfer
        case .cto1, .cto7: return .ctoInitialExtend
        case .cto3, .cto4, .cto5: return .ctoRecallRevoke
        case .mojLeave, .mojASR: return .moj
        case .hcr20: return .riskAssessment
        }
    }

    var sectionNumber: String? {
        switch self {
        case .a2, .a3, .a4: return "Section 2"
        case .a6, .a7, .a8: return "Section 3"
        case .h1: return "Section 5(2)"
        case .h5: return "Section 20"
        case .cto1, .cto3, .cto4, .cto5, .cto7: return "Section 17A"
        case .t2: return "Section 58"
        case .m2: return "Section 19"
        case .mojLeave, .mojASR: return nil
        case .hcr20: return nil
        }
    }
}

// MARK: - Form Categories
enum FormCategory: String, CaseIterable, Identifiable {
    case socialWork = "Social Work"
    case medicalJoint = "Medical (Joint)"
    case medicalSingle = "Medical (Single)"
    case holdingPower = "Holding Power & Renewal"
    case treatmentTransfer = "Treatment & Transfer"
    case ctoInitialExtend = "CTO - Initial & Extend"
    case ctoRecallRevoke = "CTO - Recall & Revoke"
    case moj = "Ministry of Justice"
    case riskAssessment = "Risk Assessment"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .socialWork: return Color(red: 0.42, green: 0.35, blue: 0.80)      // Purple
        case .medicalJoint: return Color(red: 0.22, green: 0.56, blue: 0.24)    // Green
        case .medicalSingle: return Color(red: 0.10, green: 0.46, blue: 0.82)   // Blue
        case .holdingPower: return Color(red: 0.96, green: 0.49, blue: 0.00)    // Orange
        case .treatmentTransfer: return Color(red: 0.47, green: 0.33, blue: 0.28) // Brown
        case .ctoInitialExtend: return Color(red: 0.00, green: 0.59, blue: 0.53) // Teal
        case .ctoRecallRevoke: return Color(red: 0.90, green: 0.30, blue: 0.24) // Red
        case .moj: return Color(red: 0.29, green: 0.33, blue: 0.39)             // Gray
        case .riskAssessment: return Color(red: 0.12, green: 0.25, blue: 0.69) // Blue
        }
    }

    var iconName: String {
        switch self {
        case .socialWork: return "person.badge.shield.checkmark"
        case .medicalJoint: return "person.2.badge.gearshape"
        case .medicalSingle: return "person.badge.clock"
        case .holdingPower: return "hand.raised"
        case .treatmentTransfer: return "signature"
        case .ctoInitialExtend: return "house.and.flag"
        case .ctoRecallRevoke: return "arrow.uturn.backward.circle"
        case .moj: return "building.columns"
        case .riskAssessment: return "exclamationmark.shield"
        }
    }

    var forms: [FormType] {
        FormType.allCases.filter { $0.category == self }
    }
}

// MARK: - Form Group (for UI display)
struct FormGroup: Identifiable {
    let id = UUID()
    let category: FormCategory
    let forms: [FormType]

    var label: String { category.rawValue }
    var color: Color { category.color }
}
