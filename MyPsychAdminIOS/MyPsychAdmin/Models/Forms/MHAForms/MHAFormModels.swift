//
//  MHAFormModels.swift
//  MyPsychAdmin
//
//  Form data models for MHA Forms A4, A6, A7, A8, H1, H5
//

import Foundation

// MARK: - A4 Form (Section 2 Single Medical Recommendation)
struct A4FormData: StatutoryForm, Codable, Equatable {
    let id: UUID
    let formType: FormType = .a4
    var patientInfo: PatientInfo
    var clinicianInfo: ClinicianInfo
    let createdAt: Date
    var modifiedAt: Date

    // Patient Details
    var patientName: String = ""
    var patientAddress: String = ""
    var patientAge: Int = 30

    // Doctor Details
    var doctorName: String = ""
    var doctorAddress: String = ""
    var doctorQualifications: String = ""
    var isSection12Approved: Bool = true
    var approvalAuthority: String = ""
    var examinationDate: Date = Date()
    var examinationTime: Date = Date()
    var previousAcquaintance: PreviousAcquaintanceType = .none

    // Clinical Opinion
    var mentalDisorderDescription: String = ""
    var reasonsForDetention: String = ""
    var reasonsAssessmentNecessary: String = ""
    var reasonsInformalNotAppropriate: String = ""
    var reasonsSingleRecommendation: String = "" // Why only one doctor
    var clinicalReasons: ClinicalReasonsData = ClinicalReasonsData()

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
        self.doctorName = clinicianInfo.fullName
    }

    func validate() -> [FormValidationError] {
        var errors: [FormValidationError] = []
        if patientName.isEmpty { errors.append(FormValidationError(field: "patientName", message: "Patient name required")) }
        if doctorName.isEmpty { errors.append(FormValidationError(field: "doctorName", message: "Doctor name required")) }
        if clinicalReasons.primaryDiagnosis.isEmpty { errors.append(FormValidationError(field: "mentalDisorder", message: "Mental disorder description required")) }
        return errors
    }

    func toHTML() -> String {
        "<html><body><h1>Form A4 - Section 2 Single Medical Recommendation</h1><p>Patient: \(patientName)</p><p>Doctor: \(doctorName)</p></body></html>"
    }
}

// MARK: - A6 Form (Section 3 Application by AMHP)
struct A6FormData: StatutoryForm, Codable, Equatable {
    let id: UUID
    let formType: FormType = .a6
    var patientInfo: PatientInfo
    var clinicianInfo: ClinicianInfo
    let createdAt: Date
    var modifiedAt: Date

    // Hospital
    var hospitalName: String = ""
    var hospitalAddress: String = ""

    // AMHP Details
    var amhpName: String = ""
    var amhpAddress: String = ""
    var amhpEmail: String = ""
    var localAuthorityName: String = ""
    var approvedBySameAuthority: Bool = true
    var approvedByDifferentAuthority: String = ""

    // Patient
    var patientName: String = ""
    var patientAddress: String = ""
    var patientDOB: Date?

    // Nearest Relative - Restructured
    var nrWasConsulted: Bool = false                    // Primary: Was NR consulted?
    var nrName: String = ""                             // Name (required when consulted or option c)
    var nrAddress: String = ""                          // Address (required when consulted or option c)
    var nrIsNearestRelative: Bool = true                // true=(a) NR, false=(b) Authorised

    // Not Consulted specific fields
    var ncReason: NotConsultedReason = .notKnown        // Why not consulted
    var ncDelayReason: NCDelayReason = .notPracticable  // For option (c) only
    var ncReasonText: String = ""                       // Reason box text for option (c)

    // Interview
    var interviewDate: Date = Date()
    var interviewLocation: String = ""
    var patientInterviewed: Bool = true
    var reasonNotInterviewed: String = ""

    // Medical Recommendations
    var medRec1Doctor: String = ""
    var medRec1Date: Date?
    var medRec2Doctor: String = ""
    var medRec2Date: Date?
    var noAcquaintanceReason: String = ""  // If neither practitioner had previous acquaintance

    // Application Grounds (Section 3 specific)
    var mentalDisorderNature: String = ""
    var treatmentNecessary: String = ""
    var treatmentAvailable: String = ""
    var cannotBeProvidedOtherwise: String = ""

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
        self.amhpName = clinicianInfo.fullName
        self.amhpEmail = clinicianInfo.email
    }

    func validate() -> [FormValidationError] {
        var errors: [FormValidationError] = []
        if patientName.isEmpty { errors.append(FormValidationError(field: "patientName", message: "Patient name required")) }
        if amhpName.isEmpty { errors.append(FormValidationError(field: "amhpName", message: "AMHP name required")) }
        if hospitalName.isEmpty { errors.append(FormValidationError(field: "hospitalName", message: "Hospital name required")) }
        return errors
    }

    func toHTML() -> String {
        "<html><body><h1>Form A6 - Section 3 Application by AMHP</h1><p>Patient: \(patientName)</p><p>AMHP: \(amhpName)</p></body></html>"
    }
}

// MARK: - A7 Form (Section 3 Joint Medical Recommendation)
struct A7FormData: StatutoryForm, Codable, Equatable {
    let id: UUID
    let formType: FormType = .a7
    var patientInfo: PatientInfo
    var clinicianInfo: ClinicianInfo
    let createdAt: Date
    var modifiedAt: Date

    // Patient
    var patientName: String = ""
    var patientAddress: String = ""
    var patientAge: Int = 30

    // First Doctor/Practitioner
    var doctor1Name: String = ""
    var doctor1Address: String = ""
    var doctor1Email: String = ""
    var doctor1IsSection12Approved: Bool = true
    var doctor1ExaminationDate: Date = Date()
    var doctor1PreviousAcquaintance: PreviousAcquaintanceType = .none
    var doctor1HasPreviousAcquaintance: Bool = false

    // Second Doctor/Practitioner
    var doctor2Name: String = ""
    var doctor2Address: String = ""
    var doctor2Email: String = ""
    var doctor2IsSection12Approved: Bool = false
    var doctor2ExaminationDate: Date = Date()
    var doctor2PreviousAcquaintance: PreviousAcquaintanceType = .none
    var doctor2HasPreviousAcquaintance: Bool = false

    // Clinical Opinion (Section 3 specific)
    var mentalDisorderDescription: String = ""
    var mentalDisorderNature: String = "" // Nature AND degree
    var treatmentNecessary: String = ""
    var appropriateTreatmentAvailable: String = ""
    var cannotBeProvidedWithoutDetention: String = ""
    var clinicalReasons: ClinicalReasonsData = ClinicalReasonsData()

    // Treatment Hospital
    var treatmentHospital: String = ""

    // Signatures
    var doctor1SignatureDate: Date = Date()
    var doctor2SignatureDate: Date = Date()

    init(id: UUID = UUID(), patientInfo: PatientInfo = PatientInfo(), clinicianInfo: ClinicianInfo = ClinicianInfo()) {
        self.id = id
        self.patientInfo = patientInfo
        self.clinicianInfo = clinicianInfo
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.patientName = patientInfo.fullName
        self.patientAddress = patientInfo.address
        self.patientAge = patientInfo.age ?? 30
        self.doctor1Name = clinicianInfo.fullName
    }

    func validate() -> [FormValidationError] {
        var errors: [FormValidationError] = []
        if patientName.isEmpty { errors.append(FormValidationError(field: "patientName", message: "Patient name required")) }
        if doctor1Name.isEmpty { errors.append(FormValidationError(field: "doctor1Name", message: "First doctor name required")) }
        if doctor2Name.isEmpty { errors.append(FormValidationError(field: "doctor2Name", message: "Second doctor name required")) }
        if clinicalReasons.primaryDiagnosis.isEmpty { errors.append(FormValidationError(field: "mentalDisorder", message: "Mental disorder description required")) }
        return errors
    }

    func toHTML() -> String {
        "<html><body><h1>Form A7 - Section 3 Joint Medical Recommendation</h1><p>Patient: \(patientName)</p></body></html>"
    }
}

// MARK: - A8 Form (Section 3 Single Medical Recommendation)
struct A8FormData: StatutoryForm, Codable, Equatable {
    let id: UUID
    let formType: FormType = .a8
    var patientInfo: PatientInfo
    var clinicianInfo: ClinicianInfo
    let createdAt: Date
    var modifiedAt: Date

    // Patient
    var patientName: String = ""
    var patientAddress: String = ""
    var patientAge: Int = 30

    // Doctor
    var doctorName: String = ""
    var doctorAddress: String = ""
    var isSection12Approved: Bool = true
    var examinationDate: Date = Date()
    var hasPreviousAcquaintance: Bool = false
    var hospitalName: String = ""  // Hospital for detention

    // Clinical Opinion
    var mentalDisorderDescription: String = ""
    var mentalDisorderNature: String = ""
    var treatmentNecessary: String = ""
    var appropriateTreatmentAvailable: String = ""
    var cannotBeProvidedWithoutDetention: String = ""
    var reasonsSingleRecommendation: String = ""
    var clinicalReasons: ClinicalReasonsData = ClinicalReasonsData()

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
        self.doctorName = clinicianInfo.fullName
    }

    func validate() -> [FormValidationError] {
        var errors: [FormValidationError] = []
        if patientName.isEmpty { errors.append(FormValidationError(field: "patientName", message: "Patient name required")) }
        if doctorName.isEmpty { errors.append(FormValidationError(field: "doctorName", message: "Doctor name required")) }
        if reasonsSingleRecommendation.isEmpty { errors.append(FormValidationError(field: "singleReason", message: "Reason for single recommendation required")) }
        return errors
    }

    func toHTML() -> String {
        "<html><body><h1>Form A8 - Section 3 Single Medical Recommendation</h1><p>Patient: \(patientName)</p></body></html>"
    }
}

// MARK: - H1 Form (Section 5(2) Doctor's Holding Power)
struct H1FormData: StatutoryForm, Codable, Equatable {
    let id: UUID
    let formType: FormType = .h1
    var patientInfo: PatientInfo
    var clinicianInfo: ClinicianInfo
    let createdAt: Date
    var modifiedAt: Date

    // Hospital
    var hospitalName: String = ""

    // Patient
    var patientName: String = ""
    var patientAddress: String = ""
    var patientAge: Int = 30
    var wardName: String = ""

    // Doctor Details
    var doctorName: String = ""
    var doctorStatus: DoctorStatus = .rcOrAc
    var nominatedByRC: String = "" // If nominated deputy

    // Report
    var reportDate: Date = Date()
    var reportTime: Date = Date()
    var reasonsForHolding: String = ""
    var immediateNecessity: String = ""
    var h1Reasons: H1ReasonsData = H1ReasonsData()

    // Signature
    var signatureDate: Date = Date()
    var signatureTime: Date = Date()

    // Delivery
    var deliveryMethod: H1DeliveryMethod = .internalMail
    var deliveryDate: Date = Date()

    init(id: UUID = UUID(), patientInfo: PatientInfo = PatientInfo(), clinicianInfo: ClinicianInfo = ClinicianInfo()) {
        self.id = id
        self.patientInfo = patientInfo
        self.clinicianInfo = clinicianInfo
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.patientName = patientInfo.fullName
        self.patientAddress = patientInfo.address
        self.doctorName = clinicianInfo.fullName
    }

    func validate() -> [FormValidationError] {
        var errors: [FormValidationError] = []
        if patientName.isEmpty { errors.append(FormValidationError(field: "patientName", message: "Patient name required")) }
        if doctorName.isEmpty { errors.append(FormValidationError(field: "doctorName", message: "Doctor name required")) }
        if hospitalName.isEmpty { errors.append(FormValidationError(field: "hospitalName", message: "Hospital name required")) }
        if h1Reasons.generatedText.isEmpty { errors.append(FormValidationError(field: "reasons", message: "Reasons for holding power required")) }
        return errors
    }

    func toHTML() -> String {
        "<html><body><h1>Form H1 - Section 5(2) Doctor's Holding Power</h1><p>Patient: \(patientName)</p><p>Doctor: \(doctorName)</p></body></html>"
    }
}

enum DoctorStatus: String, Codable, CaseIterable, Identifiable {
    case rcOrAc = "Responsible Clinician / Approved Clinician"
    case nominatedDeputy = "Nominated Deputy"

    var id: String { rawValue }
}

enum H1DeliveryMethod: String, Codable, CaseIterable, Identifiable {
    case internalMail = "Internal mail system"
    case electronic = "Electronic communication"
    case handDelivery = "Hand delivery"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .internalMail: return "Consigning to internal mail system"
        case .electronic: return "Electronic communication"
        case .handDelivery: return "Delivering by hand"
        }
    }
}

// MARK: - H5 Form (Section 20 Renewal of Detention)
struct H5FormData: StatutoryForm, Codable, Equatable {
    let id: UUID
    let formType: FormType = .h5
    var patientInfo: PatientInfo
    var clinicianInfo: ClinicianInfo
    let createdAt: Date
    var modifiedAt: Date

    // Hospital
    var hospitalName: String = ""
    var hospitalAddress: String = ""

    // Patient
    var patientName: String = ""
    var patientAddress: String = ""
    var patientDOB: Date?
    var patientAge: Int = 30
    var currentSection: CurrentDetentionSection = .section3

    // RC Details
    var rcName: String = ""
    var rcProfession: String = ""
    var rcQualifications: String = ""

    // Examination
    var examinationDate: Date = Date()
    var detentionExpiryDate: Date = Date()

    // Clinical Opinion
    var mentalDisorderDescription: String = ""
    var mentalDisorderNature: String = ""
    var treatmentNecessary: String = ""
    var appropriateTreatmentAvailable: String = ""
    var cannotBeProvidedWithoutDetention: String = ""
    var clinicalReasons: ClinicalReasonsData = ClinicalReasonsData()

    // Consultation (1st consultee)
    var professionalConsulted: String = ""
    var consulteeEmail: String = ""
    var consultationDate: Date = Date()
    var professionOfConsultee: String = ""

    // 2nd Consultee
    var secondConsulteeName: String = ""
    var secondConsulteeEmail: String = ""
    var secondConsulteeProfession: String = ""
    var secondConsultationDate: Date = Date()

    // Renewal Period
    var renewalPeriod: RenewalPeriod = .sixMonths

    // Signature
    var signatureDate: Date = Date()

    // Delivery (Part 3)
    var deliveryMethod: H1DeliveryMethod = .internalMail
    var deliveryDate: Date = Date()

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
        if clinicalReasons.primaryDiagnosis.isEmpty { errors.append(FormValidationError(field: "mentalDisorder", message: "Mental disorder description required")) }
        if professionalConsulted.isEmpty { errors.append(FormValidationError(field: "consultation", message: "Consultation details required")) }
        return errors
    }

    func toHTML() -> String {
        "<html><body><h1>Form H5 - Section 20 Renewal</h1><p>Patient: \(patientName)</p><p>RC: \(rcName)</p></body></html>"
    }
}

enum CurrentDetentionSection: String, Codable, CaseIterable, Identifiable {
    case section3 = "Section 3"
    case section37 = "Section 37"
    case section47 = "Section 47"
    case section48 = "Section 48"

    var id: String { rawValue }
}

enum RenewalPeriod: String, Codable, CaseIterable, Identifiable {
    case sixMonths = "6 months"
    case oneYear = "1 year"

    var id: String { rawValue }
}
