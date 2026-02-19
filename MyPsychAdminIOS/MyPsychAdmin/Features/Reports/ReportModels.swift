//
//  ReportModels.swift
//  MyPsychAdmin
//
//  Data models for Tribunal Reports matching desktop implementation
//

import Foundation

// MARK: - Report Types

enum ReportType: String, CaseIterable, Identifiable, Codable {
    case generalPsychiatric = "General Psychiatric Report"
    case psychiatricTribunal = "Psychiatric Tribunal Report"
    case nursingTribunal = "Nursing Tribunal Report"
    case socialTribunal = "Social Circumstances Report"

    var id: String { rawValue }

    var shortTitle: String {
        switch self {
        case .generalPsychiatric: return "General"
        case .psychiatricTribunal: return "Psychiatric"
        case .nursingTribunal: return "Nursing"
        case .socialTribunal: return "Social"
        }
    }

    var description: String {
        switch self {
        case .generalPsychiatric:
            return "CPA Report Medical - General psychiatric assessment"
        case .psychiatricTribunal:
            return "T131 - Responsible Clinician's statutory tribunal report"
        case .nursingTribunal:
            return "T134 - Nursing staff tribunal report"
        case .socialTribunal:
            return "T133 - Social circumstances tribunal report"
        }
    }

    var iconName: String {
        switch self {
        case .generalPsychiatric: return "stethoscope"
        case .psychiatricTribunal: return "person.badge.clock"
        case .nursingTribunal: return "heart.text.square"
        case .socialTribunal: return "person.2.wave.2"
        }
    }

    var color: String {
        switch self {
        case .generalPsychiatric: return "#2563eb"  // Blue
        case .psychiatricTribunal: return "#7c3aed" // Purple
        case .nursingTribunal: return "#059669"     // Green
        case .socialTribunal: return "#d97706"      // Amber
        }
    }

    var sections: [ReportSection] {
        switch self {
        case .generalPsychiatric:
            return GeneralPsychiatricSection.allCases.map { $0.toReportSection() }
        case .psychiatricTribunal:
            return PsychiatricTribunalSection.allCases.map { $0.toReportSection() }
        case .nursingTribunal:
            return NursingTribunalSection.allCases.map { $0.toReportSection() }
        case .socialTribunal:
            return SocialTribunalSection.allCases.map { $0.toReportSection() }
        }
    }
}

// MARK: - Report Section Protocol

struct ReportSection: Identifiable, Hashable {
    let id: String
    let number: Int
    let title: String
    let iconName: String
}

// MARK: - General Psychiatric Report Sections (14 sections)

enum GeneralPsychiatricSection: Int, CaseIterable, Identifiable {
    case patientDetails = 1
    case reportBasedOn
    case circumstances
    case backgroundInfo
    case pastMedicalHistory
    case pastPsychHistory
    case risk
    case substanceUse
    case forensicHistory
    case medication
    case mentalDisorder
    case legalCriteria
    case strengths
    case signature

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .patientDetails: return "Patient Details"
        case .reportBasedOn: return "Report Based On"
        case .circumstances: return "Circumstances to this Admission"
        case .backgroundInfo: return "Background Information"
        case .pastMedicalHistory: return "Past Medical History"
        case .pastPsychHistory: return "Past Psychiatric History"
        case .risk: return "Risk"
        case .substanceUse: return "History of Substance Use"
        case .forensicHistory: return "Forensic History"
        case .medication: return "Medication"
        case .mentalDisorder: return "Mental Disorder"
        case .legalCriteria: return "Legal Criteria for Detention"
        case .strengths: return "Strengths"
        case .signature: return "Signature"
        }
    }

    var iconName: String {
        switch self {
        case .patientDetails: return "person.fill"
        case .reportBasedOn: return "doc.text.fill"
        case .circumstances: return "arrow.right.circle.fill"
        case .backgroundInfo: return "info.circle.fill"
        case .pastMedicalHistory: return "heart.text.square.fill"
        case .pastPsychHistory: return "brain.head.profile"
        case .risk: return "exclamationmark.triangle.fill"
        case .substanceUse: return "pills.fill"
        case .forensicHistory: return "building.columns.fill"
        case .medication: return "cross.vial.fill"
        case .mentalDisorder: return "brain"
        case .legalCriteria: return "scale.3d"
        case .strengths: return "star.fill"
        case .signature: return "signature"
        }
    }

    func toReportSection() -> ReportSection {
        ReportSection(id: "\(rawValue)", number: rawValue, title: title, iconName: iconName)
    }
}

// MARK: - Psychiatric Tribunal Report Sections (24 sections - T131)

enum PsychiatricTribunalSection: Int, CaseIterable, Identifiable {
    case patientDetails = 1
    case rcName
    case factorsAffecting
    case adjustments
    case indexOffence
    case previousInvolvement
    case previousAdmission
    case currentAdmission
    case mentalDisorder
    case learningDisability
    case mentalDisorderDetention
    case medicalTreatment
    case strengths
    case currentProgress
    case complianceTreatment
    case deprivationLiberty
    case incidentsHarm
    case propertyDamage
    case section2Detention
    case otherSectionsTreatment
    case riskIfDischarged
    case communityRisk
    case recommendations
    case signature

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .patientDetails: return "Patient Details"
        case .rcName: return "Name of Responsible Clinician"
        case .factorsAffecting: return "Factors affecting understanding"
        case .adjustments: return "Adjustments for tribunal"
        case .indexOffence: return "Index offence(s) and forensic history"
        case .previousInvolvement: return "Previous mental health involvement"
        case .previousAdmission: return "Reasons for previous admission"
        case .currentAdmission: return "Circumstances leading to admission"
        case .mentalDisorder: return "Mental disorder and diagnosis"
        case .learningDisability: return "Learning disability"
        case .mentalDisorderDetention: return "Mental disorder requiring detention"
        case .medicalTreatment: return "Medical treatment"
        case .strengths: return "Strengths or positive factors"
        case .currentProgress: return "Current progress & behaviour"
        case .complianceTreatment: return "Compliance with treatment"
        case .deprivationLiberty: return "Deprivation of liberty (MCA)"
        case .incidentsHarm: return "Incidents of harm"
        case .propertyDamage: return "Property damage"
        case .section2Detention: return "Section 2: Detention justified"
        case .otherSectionsTreatment: return "Other sections: Treatment justified"
        case .riskIfDischarged: return "Risk if discharged"
        case .communityRisk: return "Community risk management"
        case .recommendations: return "Recommendations to tribunal"
        case .signature: return "Signature"
        }
    }

    var iconName: String {
        switch self {
        case .patientDetails: return "person.fill"
        case .rcName: return "person.badge.key.fill"
        case .factorsAffecting: return "brain.head.profile"
        case .adjustments: return "slider.horizontal.3"
        case .indexOffence: return "building.columns.fill"
        case .previousInvolvement: return "clock.arrow.circlepath"
        case .previousAdmission: return "arrow.uturn.backward.circle.fill"
        case .currentAdmission: return "arrow.right.circle.fill"
        case .mentalDisorder: return "brain"
        case .learningDisability: return "lightbulb.fill"
        case .mentalDisorderDetention: return "lock.fill"
        case .medicalTreatment: return "cross.vial.fill"
        case .strengths: return "star.fill"
        case .currentProgress: return "chart.line.uptrend.xyaxis"
        case .complianceTreatment: return "checkmark.seal.fill"
        case .deprivationLiberty: return "lock.shield.fill"
        case .incidentsHarm: return "exclamationmark.triangle.fill"
        case .propertyDamage: return "hammer.fill"
        case .section2Detention: return "doc.badge.gearshape.fill"
        case .otherSectionsTreatment: return "doc.badge.plus"
        case .riskIfDischarged: return "exclamationmark.octagon.fill"
        case .communityRisk: return "person.3.fill"
        case .recommendations: return "lightbulb.max.fill"
        case .signature: return "signature"
        }
    }

    func toReportSection() -> ReportSection {
        ReportSection(id: "\(rawValue)", number: rawValue, title: title, iconName: iconName)
    }
}

// MARK: - Nursing Tribunal Report Sections (21 sections - T134)

enum NursingTribunalSection: Int, CaseIterable, Identifiable {
    case patientDetails = 1
    case factorsAffecting
    case adjustments
    case nursingCare
    case observationLevel
    case contactRelatives
    case communitySupport
    case strengths
    case currentProgress
    case awolHistory
    case complianceMedication
    case incidentsHarm
    case propertyDamage
    case seclusionRestraint
    case section2Detention
    case otherSectionsTreatment
    case riskIfDischarged
    case communityRisk
    case otherInfo
    case recommendations
    case signature

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .patientDetails: return "Patient Details"
        case .factorsAffecting: return "Factors affecting understanding"
        case .adjustments: return "Adjustments for tribunal"
        case .nursingCare: return "Nature of nursing care"
        case .observationLevel: return "Level of observation"
        case .contactRelatives: return "Contact with relatives"
        case .communitySupport: return "Community support"
        case .strengths: return "Strengths or positive factors"
        case .currentProgress: return "Current progress & engagement"
        case .awolHistory: return "AWOL or failed return"
        case .complianceMedication: return "Compliance with medication"
        case .incidentsHarm: return "Incidents of harm"
        case .propertyDamage: return "Property damage"
        case .seclusionRestraint: return "Seclusion or restraint"
        case .section2Detention: return "Section 2: Detention justified"
        case .otherSectionsTreatment: return "Other sections: Treatment justified"
        case .riskIfDischarged: return "Risk if discharged"
        case .communityRisk: return "Community risk management"
        case .otherInfo: return "Other relevant information"
        case .recommendations: return "Recommendations to tribunal"
        case .signature: return "Signature"
        }
    }

    var iconName: String {
        switch self {
        case .patientDetails: return "person.fill"
        case .factorsAffecting: return "brain.head.profile"
        case .adjustments: return "slider.horizontal.3"
        case .nursingCare: return "heart.text.square.fill"
        case .observationLevel: return "eye.fill"
        case .contactRelatives: return "person.2.fill"
        case .communitySupport: return "house.fill"
        case .strengths: return "star.fill"
        case .currentProgress: return "chart.line.uptrend.xyaxis"
        case .awolHistory: return "figure.walk.departure"
        case .complianceMedication: return "pills.fill"
        case .incidentsHarm: return "exclamationmark.triangle.fill"
        case .propertyDamage: return "hammer.fill"
        case .seclusionRestraint: return "lock.fill"
        case .section2Detention: return "doc.badge.gearshape.fill"
        case .otherSectionsTreatment: return "doc.badge.plus"
        case .riskIfDischarged: return "exclamationmark.octagon.fill"
        case .communityRisk: return "person.3.fill"
        case .otherInfo: return "info.circle.fill"
        case .recommendations: return "lightbulb.max.fill"
        case .signature: return "signature"
        }
    }

    func toReportSection() -> ReportSection {
        ReportSection(id: "\(rawValue)", number: rawValue, title: title, iconName: iconName)
    }
}

// MARK: - Social Tribunal Report Sections (26 sections - T133)

enum SocialTribunalSection: Int, CaseIterable, Identifiable {
    case patientDetails = 1
    case factorsAffecting
    case adjustments
    case indexOffence
    case previousInvolvement
    case homeFamily
    case housing
    case financialPosition
    case employment
    case previousResponse
    case carePathway
    case proposedCarePlan
    case adequacyCarePlan
    case fundingIssues
    case strengths
    case currentProgress
    case incidentsHarm
    case propertyDamage
    case patientViews
    case nearestRelativeViews
    case inappropriateConsult
    case otherPersonViews
    case mappaInvolvement
    case deprivationLiberty
    case section2Detention
    case signature

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .patientDetails: return "Patient Details"
        case .factorsAffecting: return "Factors affecting understanding"
        case .adjustments: return "Adjustments for tribunal"
        case .indexOffence: return "Index offence(s) and forensic history"
        case .previousInvolvement: return "Previous mental health involvement"
        case .homeFamily: return "Home and family circumstances"
        case .housing: return "Housing if discharged"
        case .financialPosition: return "Financial position"
        case .employment: return "Employment opportunities"
        case .previousResponse: return "Previous response to support"
        case .carePathway: return "Care pathway and Section 117"
        case .proposedCarePlan: return "Proposed care plan"
        case .adequacyCarePlan: return "Adequacy of care plan"
        case .fundingIssues: return "Funding issues"
        case .strengths: return "Strengths or positive factors"
        case .currentProgress: return "Current progress & compliance"
        case .incidentsHarm: return "Incidents of harm"
        case .propertyDamage: return "Property damage"
        case .patientViews: return "Patient's views and wishes"
        case .nearestRelativeViews: return "Nearest Relative views"
        case .inappropriateConsult: return "Reasons if inappropriate to consult NR"
        case .otherPersonViews: return "Other person's views"
        case .mappaInvolvement: return "MAPPA involvement"
        case .deprivationLiberty: return "Deprivation of liberty (MCA)"
        case .section2Detention: return "Section 2: Detention justified"
        case .signature: return "Signature"
        }
    }

    var iconName: String {
        switch self {
        case .patientDetails: return "person.fill"
        case .factorsAffecting: return "brain.head.profile"
        case .adjustments: return "slider.horizontal.3"
        case .indexOffence: return "building.columns.fill"
        case .previousInvolvement: return "clock.arrow.circlepath"
        case .homeFamily: return "house.fill"
        case .housing: return "building.2.fill"
        case .financialPosition: return "sterlingsign.circle.fill"
        case .employment: return "briefcase.fill"
        case .previousResponse: return "arrow.uturn.backward.circle.fill"
        case .carePathway: return "point.topleft.down.curvedto.point.bottomright.up.fill"
        case .proposedCarePlan: return "list.clipboard.fill"
        case .adequacyCarePlan: return "checkmark.rectangle.fill"
        case .fundingIssues: return "banknote.fill"
        case .strengths: return "star.fill"
        case .currentProgress: return "chart.line.uptrend.xyaxis"
        case .incidentsHarm: return "exclamationmark.triangle.fill"
        case .propertyDamage: return "hammer.fill"
        case .patientViews: return "bubble.left.fill"
        case .nearestRelativeViews: return "person.2.fill"
        case .inappropriateConsult: return "xmark.circle.fill"
        case .otherPersonViews: return "person.wave.2.fill"
        case .mappaInvolvement: return "shield.fill"
        case .deprivationLiberty: return "lock.shield.fill"
        case .section2Detention: return "doc.badge.gearshape.fill"
        case .signature: return "signature"
        }
    }

    func toReportSection() -> ReportSection {
        ReportSection(id: "\(rawValue)", number: rawValue, title: title, iconName: iconName)
    }
}

// MARK: - Report Data Model

struct ReportData: Codable, Identifiable, Equatable {
    let id: UUID
    var reportType: ReportType
    var patientInfo: PatientInfo
    var clinicianInfo: ClinicianInfo
    var sections: [String: String]  // sectionId -> content
    let createdAt: Date
    var modifiedAt: Date

    init(id: UUID = UUID(), reportType: ReportType, patientInfo: PatientInfo = PatientInfo(), clinicianInfo: ClinicianInfo = ClinicianInfo()) {
        self.id = id
        self.reportType = reportType
        self.patientInfo = patientInfo
        self.clinicianInfo = clinicianInfo
        self.sections = [:]
        self.createdAt = Date()
        self.modifiedAt = Date()
    }

    mutating func updateSection(_ sectionId: String, content: String) {
        sections[sectionId] = content
        modifiedAt = Date()
    }

    func getSection(_ sectionId: String) -> String {
        sections[sectionId] ?? ""
    }
}
