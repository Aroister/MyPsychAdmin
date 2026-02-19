//
//  CTOFormModels.swift
//  MyPsychAdmin
//
//  Form data models for CTO Forms (Community Treatment Orders)
//  CTO1, CTO3, CTO4, CTO5, CTO7
//

import Foundation

// MARK: - CTO1 Form (Community Treatment Order)
struct CTO1FormData: StatutoryForm, Codable, Equatable {
    let id: UUID
    let formType: FormType = .cto1
    var patientInfo: PatientInfo
    var clinicianInfo: ClinicianInfo
    let createdAt: Date
    var modifiedAt: Date

    // Patient Details
    var patientName: String = ""
    var patientAddress: String = ""
    var patientDOB: Date?
    var patientAge: Int = 18

    // Hospital/Authority Details
    var responsibleHospital: String = ""
    var hospitalManagerName: String = ""

    // RC Details
    var rcName: String = ""
    var rcProfession: String = ""
    var rcEmail: String = ""

    // AMHP Details
    var amhpName: String = ""
    var amhpLocalAuthority: String = ""

    // CTO Details
    var ctoStartDate: Date = Date()
    var reasonsForCTO: String = ""

    // Conditions (Section 17B(2))
    var standardConditions: CTOStandardConditions = CTOStandardConditions()
    var additionalConditions: String = ""

    // Clinical Opinion
    var mentalDisorderDescription: String = ""
    var treatmentNecessary: String = ""
    var treatmentCanBeProvided: String = ""
    var recallMayBeNecessary: String = ""
    var appropriateTreatmentAvailable: String = ""
    var clinicalReasons: ClinicalReasonsData = ClinicalReasonsData()

    // Consultation
    var amhpAgreement: Bool = true
    var amhpConsultationDate: Date = Date()

    // Signatures
    var rcSignatureDate: Date = Date()
    var amhpSignatureDate: Date = Date()

    init(id: UUID = UUID(), patientInfo: PatientInfo = PatientInfo(), clinicianInfo: ClinicianInfo = ClinicianInfo()) {
        self.id = id
        self.patientInfo = patientInfo
        self.clinicianInfo = clinicianInfo
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.patientName = patientInfo.fullName
        self.patientAddress = patientInfo.address
        self.patientDOB = patientInfo.dateOfBirth
        self.rcName = clinicianInfo.fullName
        self.rcEmail = clinicianInfo.email
    }

    func validate() -> [FormValidationError] {
        var errors: [FormValidationError] = []
        if patientName.isEmpty { errors.append(FormValidationError(field: "patientName", message: "Patient name required")) }
        if rcName.isEmpty { errors.append(FormValidationError(field: "rcName", message: "RC name required")) }
        if amhpName.isEmpty { errors.append(FormValidationError(field: "amhpName", message: "AMHP name required")) }
        if !amhpAgreement { errors.append(FormValidationError(field: "amhpAgreement", message: "AMHP must agree to CTO")) }
        if !standardConditions.hasAnySelected && additionalConditions.isEmpty { errors.append(FormValidationError(field: "conditions", message: "At least one condition required")) }
        return errors
    }

    func toHTML() -> String {
        "<html><body><h1>Form CTO1 - Community Treatment Order</h1><p>Patient: \(patientName)</p><p>RC: \(rcName)</p></body></html>"
    }
}

struct CTOCondition: Identifiable, Codable, Equatable {
    let id: UUID
    var condition: String
    var isStandard: Bool // Standard vs custom condition

    init(id: UUID = UUID(), condition: String, isStandard: Bool = false) {
        self.id = id
        self.condition = condition
        self.isStandard = isStandard
    }
}

// Standard CTO Conditions (Section 17B(2)) - matching desktop app
struct CTOStandardConditions: Codable, Equatable {
    var seeCMHT: Bool = false
    var complyWithMedication: Bool = false
    var residence: Bool = false

    var generatedText: String {
        var conditions: [String] = []
        var num = 1

        if seeCMHT {
            conditions.append("\(num). To comply with reviews as defined by the care-coordinator and the RC.")
            num += 1
        }

        if complyWithMedication {
            conditions.append("\(num). To adhere to psychiatric medications as prescribed by the RC.")
            num += 1
        }

        if residence {
            conditions.append("\(num). To reside at an address in accordance with the requirements of the CMHT/RC.")
            num += 1
        }

        return conditions.joined(separator: "\n")
    }

    var hasAnySelected: Bool {
        seeCMHT || complyWithMedication || residence
    }
}

// MARK: - CTO3 Recall Reason Type
enum CTO3RecallReasonType: String, Codable, CaseIterable, Identifiable {
    case treatmentRequired = "Treatment Required"  // Option (a)
    case breachOfConditions = "Breach of Conditions"  // Option (b)

    var id: String { rawValue }
}

// MARK: - CTO3 Breach Examination Type (for option b)
enum CTO3BreachExaminationType: String, Codable, CaseIterable, Identifiable {
    case extensionOfCTO = "Extension of CTO"  // (i) consideration of extension
    case part4ACertificate = "Part 4A Certificate"  // (ii) enabling Part 4A certificate

    var id: String { rawValue }
}

// MARK: - CTO3 Form (Notice of Recall)
struct CTO3FormData: StatutoryForm, Codable, Equatable {
    let id: UUID
    let formType: FormType = .cto3
    var patientInfo: PatientInfo
    var clinicianInfo: ClinicianInfo
    let createdAt: Date
    var modifiedAt: Date

    // Patient
    var patientName: String = ""
    var patientAddress: String = ""
    var patientDOB: Date?

    // Hospital
    var recallHospital: String = ""
    var recallHospitalAddress: String = ""

    // RC Details
    var rcName: String = ""

    // Recall Details
    var recallDate: Date = Date()
    var recallTime: Date = Date()
    var reasonsForRecall: String = ""

    // Recall Reason - (a) or (b)
    var recallReasonType: CTO3RecallReasonType = .treatmentRequired

    // For option (b) - which examination type
    var breachExaminationType: CTO3BreachExaminationType = .extensionOfCTO

    // Clinical Opinion (for option a)
    var treatmentRequired: String = ""
    var riskWithoutRecall: String = ""
    var breachOfConditions: Bool = false  // Kept for backwards compatibility
    var breachDetails: String = ""
    var clinicalReasons: ClinicalReasonsData = ClinicalReasonsData()

    // Notice
    var noticeServedDate: Date = Date()
    var noticeServedTime: Date = Date()
    var noticeServedTo: String = "" // Patient or representative

    // Signature
    var signatureDate: Date = Date()

    init(id: UUID = UUID(), patientInfo: PatientInfo = PatientInfo(), clinicianInfo: ClinicianInfo = ClinicianInfo()) {
        self.id = id
        self.patientInfo = patientInfo
        self.clinicianInfo = clinicianInfo
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.patientName = patientInfo.fullName
        self.patientAddress = patientInfo.address
        self.rcName = clinicianInfo.fullName
    }

    func validate() -> [FormValidationError] {
        var errors: [FormValidationError] = []
        if patientName.isEmpty { errors.append(FormValidationError(field: "patientName", message: "Patient name required")) }
        if rcName.isEmpty { errors.append(FormValidationError(field: "rcName", message: "RC name required")) }
        if recallHospital.isEmpty { errors.append(FormValidationError(field: "recallHospital", message: "Recall hospital required")) }
        if clinicalReasons.generatedText.isEmpty && reasonsForRecall.isEmpty { errors.append(FormValidationError(field: "reasons", message: "Reasons for recall required")) }
        return errors
    }

    func toHTML() -> String {
        "<html><body><h1>Form CTO3 - Notice of Recall</h1><p>Patient: \(patientName)</p></body></html>"
    }
}

// MARK: - CTO4 Form (Record of Detention After Recall)
struct CTO4FormData: StatutoryForm, Codable, Equatable {
    let id: UUID
    let formType: FormType = .cto4
    var patientInfo: PatientInfo
    var clinicianInfo: ClinicianInfo
    let createdAt: Date
    var modifiedAt: Date

    // Patient
    var patientName: String = ""
    var patientAddress: String = ""
    var patientDOB: Date?

    // Hospital
    var hospitalName: String = ""
    var hospitalAddress: String = ""

    // RC Details
    var rcName: String = ""

    // Recall/Detention Details
    var patientRecalledDate: Date = Date()

    // Signature
    var rcSignatureDate: Date = Date()

    init(id: UUID = UUID(), patientInfo: PatientInfo = PatientInfo(), clinicianInfo: ClinicianInfo = ClinicianInfo()) {
        self.id = id
        self.patientInfo = patientInfo
        self.clinicianInfo = clinicianInfo
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.patientName = patientInfo.fullName
        self.patientAddress = patientInfo.address
        self.rcName = clinicianInfo.fullName
    }

    func validate() -> [FormValidationError] {
        var errors: [FormValidationError] = []
        if patientName.isEmpty { errors.append(FormValidationError(field: "patientName", message: "Patient name required")) }
        if hospitalName.isEmpty { errors.append(FormValidationError(field: "hospitalName", message: "Hospital name required")) }
        return errors
    }

    func toHTML() -> String {
        "<html><body><h1>Form CTO4 - Record of Detention After Recall</h1><p>Patient: \(patientName)</p></body></html>"
    }
}

// MARK: - CTO5 Form (Revocation of CTO)
struct CTO5FormData: StatutoryForm, Codable, Equatable {
    let id: UUID
    let formType: FormType = .cto5
    var patientInfo: PatientInfo
    var clinicianInfo: ClinicianInfo
    let createdAt: Date
    var modifiedAt: Date

    // Patient
    var patientName: String = ""
    var patientAddress: String = ""
    var patientAge: Int = 30

    // Hospital
    var hospitalName: String = ""
    var hospitalAddress: String = ""

    // RC Details
    var rcName: String = ""

    // AMHP Details
    var amhpName: String = ""
    var amhpLocalAuthority: String = ""

    // Revocation Details
    var revocationDate: Date = Date()
    var patientRecalledDate: Date = Date()
    var reasonsForRevocation: String = ""

    // Clinical Opinion
    var conditionsForDetentionMet: String = ""
    var treatmentNecessary: String = ""
    var appropriateTreatmentAvailable: String = ""
    var clinicalReasons: ClinicalReasonsData = ClinicalReasonsData()

    // AMHP Agreement
    var amhpAgreement: Bool = true
    var amhpConsultationDate: Date = Date()

    // Signatures
    var rcSignatureDate: Date = Date()
    var amhpSignatureDate: Date = Date()

    init(id: UUID = UUID(), patientInfo: PatientInfo = PatientInfo(), clinicianInfo: ClinicianInfo = ClinicianInfo()) {
        self.id = id
        self.patientInfo = patientInfo
        self.clinicianInfo = clinicianInfo
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.patientName = patientInfo.fullName
        self.patientAddress = patientInfo.address
        self.rcName = clinicianInfo.fullName
    }

    func validate() -> [FormValidationError] {
        var errors: [FormValidationError] = []
        if patientName.isEmpty { errors.append(FormValidationError(field: "patientName", message: "Patient name required")) }
        if rcName.isEmpty { errors.append(FormValidationError(field: "rcName", message: "RC name required")) }
        if amhpName.isEmpty { errors.append(FormValidationError(field: "amhpName", message: "AMHP name required")) }
        if !amhpAgreement { errors.append(FormValidationError(field: "amhpAgreement", message: "AMHP must agree to revocation")) }
        if clinicalReasons.generatedText.isEmpty && reasonsForRevocation.isEmpty { errors.append(FormValidationError(field: "reasons", message: "Reasons for revocation required")) }
        return errors
    }

    func toHTML() -> String {
        "<html><body><h1>Form CTO5 - Revocation of CTO</h1><p>Patient: \(patientName)</p></body></html>"
    }
}

// MARK: - CTO7 Delivery Method
enum CTO7DeliveryMethod: String, Codable, CaseIterable, Identifiable {
    case internalMail = "Internal mail system"
    case electronic = "Electronic communication"
    case handDelivery = "Hand delivery"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .internalMail: return "Consigning to internal mail system"
        case .electronic: return "Electronic communication"
        case .handDelivery: return "Hand delivery without internal mail"
        }
    }
}

// MARK: - CTO7 Form (Extension of CTO)
struct CTO7FormData: StatutoryForm, Codable, Equatable {
    let id: UUID
    let formType: FormType = .cto7
    var patientInfo: PatientInfo
    var clinicianInfo: ClinicianInfo
    let createdAt: Date
    var modifiedAt: Date

    // Patient
    var patientName: String = ""
    var patientAddress: String = ""
    var patientDOB: Date?
    var patientAge: Int = 18

    // Hospital
    var responsibleHospital: String = ""

    // RC Details
    var rcName: String = ""
    var rcAddress: String = ""
    var rcEmail: String = ""
    var rcProfession: String = ""

    // Current CTO Details
    var ctoStartDate: Date = Date()
    var currentCTOExpiryDate: Date = Date()

    // Extension Details
    var extensionPeriod: CTOExtensionPeriod = .sixMonths
    var newExpiryDate: Date = Date()

    // Examination
    var examinationDate: Date = Date()

    // Clinical Opinion
    var mentalDisorderDescription: String = ""
    var treatmentNecessary: String = ""
    var recallMayBeNecessary: String = ""
    var appropriateTreatmentAvailable: String = ""
    var reasonsForExtension: String = ""
    var clinicalReasons: ClinicalReasonsData = ClinicalReasonsData()

    // Consultation
    var professionalConsulted: String = ""
    var consulteeEmail: String = ""
    var professionOfConsultee: String = ""
    var consultationDate: Date = Date()

    // Part 3 - Delivery Method
    var deliveryMethod: CTO7DeliveryMethod = .internalMail

    // Signature
    var signatureDate: Date = Date()

    init(id: UUID = UUID(), patientInfo: PatientInfo = PatientInfo(), clinicianInfo: ClinicianInfo = ClinicianInfo()) {
        self.id = id
        self.patientInfo = patientInfo
        self.clinicianInfo = clinicianInfo
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.patientName = patientInfo.fullName
        self.patientAddress = patientInfo.address
        self.patientDOB = patientInfo.dateOfBirth
        self.rcName = clinicianInfo.fullName
        // Build address from hospital/org and ward/department
        var addressParts: [String] = []
        if !clinicianInfo.wardDepartment.isEmpty { addressParts.append(clinicianInfo.wardDepartment) }
        if !clinicianInfo.hospitalOrg.isEmpty { addressParts.append(clinicianInfo.hospitalOrg) }
        self.rcAddress = addressParts.joined(separator: ", ")
        self.rcEmail = clinicianInfo.email
    }

    func validate() -> [FormValidationError] {
        var errors: [FormValidationError] = []
        if patientName.isEmpty { errors.append(FormValidationError(field: "patientName", message: "Patient name required")) }
        if rcName.isEmpty { errors.append(FormValidationError(field: "rcName", message: "RC name required")) }
        if clinicalReasons.primaryDiagnosis.isEmpty { errors.append(FormValidationError(field: "mentalDisorder", message: "Mental disorder description required")) }
        if professionalConsulted.isEmpty { errors.append(FormValidationError(field: "consultation", message: "Consultee name required")) }
        return errors
    }

    func toHTML() -> String {
        "<html><body><h1>Form CTO7 - Extension of CTO</h1><p>Patient: \(patientName)</p></body></html>"
    }
}

enum CTOExtensionPeriod: String, Codable, CaseIterable, Identifiable {
    case sixMonths = "6 months"
    case oneYear = "1 year"

    var id: String { rawValue }
}
