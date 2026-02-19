//
//  A3FormData.swift
//  MyPsychAdmin
//
//  Form A3 - Section 2 Joint Medical Recommendation
//  Mental Health Act 1983 - Regulation 4(1)(b)
//

import Foundation

struct A3FormData: StatutoryForm, Codable, Equatable {
    let id: UUID
    let formType: FormType = .a3
    var patientInfo: PatientInfo
    var clinicianInfo: ClinicianInfo
    let createdAt: Date
    var modifiedAt: Date

    // MARK: - Patient Details
    var patientName: String = ""
    var patientAddress: String = ""
    var patientAge: Int = 30

    // MARK: - First Practitioner Details
    var doctor1Name: String = ""
    var doctor1Email: String = ""
    var doctor1Address: String = ""
    var doctor1Qualifications: String = ""
    var doctor1IsSection12Approved: Bool = true
    var doctor1ApprovalAuthority: String = ""
    var doctor1ExaminationDate: Date = Date()
    var doctor1ExaminationTime: Date = Date()
    var doctor1PreviousAcquaintance: PreviousAcquaintanceType = .none
    var doctor1PreviousAcquaintanceDetails: String = ""

    // MARK: - Second Practitioner Details
    var doctor2Name: String = ""
    var doctor2Email: String = ""
    var doctor2Address: String = ""
    var doctor2Qualifications: String = ""
    var doctor2IsSection12Approved: Bool = false
    var doctor2ApprovalAuthority: String = ""
    var doctor2ExaminationDate: Date = Date()
    var doctor2ExaminationTime: Date = Date()
    var doctor2PreviousAcquaintance: PreviousAcquaintanceType = .none
    var doctor2PreviousAcquaintanceDetails: String = ""

    // MARK: - Clinical Opinion
    var mentalDisorderDescription: String = ""
    var reasonsForDetention: String = ""
    var reasonsAssessmentNecessary: String = ""
    var reasonsInformalAdmissionNotAppropriate: String = ""
    var clinicalReasons: ClinicalReasonsData = ClinicalReasonsData()

    // MARK: - Joint Statement
    var lastExaminedDate: Date = Date()
    var examinedTogether: Bool = false
    var separateExaminationReason: String = ""

    // MARK: - Signatures
    var doctor1SignatureDate: Date = Date()
    var doctor2SignatureDate: Date = Date()

    init(
        id: UUID = UUID(),
        patientInfo: PatientInfo = PatientInfo(),
        clinicianInfo: ClinicianInfo = ClinicianInfo()
    ) {
        self.id = id
        self.patientInfo = patientInfo
        self.clinicianInfo = clinicianInfo
        self.createdAt = Date()
        self.modifiedAt = Date()

        // Pre-fill from patient info
        self.patientName = patientInfo.fullName
        self.patientAddress = patientInfo.address
        if let age = patientInfo.age {
            self.patientAge = age
        }

        // Pre-fill first doctor from clinician info
        self.doctor1Name = clinicianInfo.fullName
    }

    func validate() -> [FormValidationError] {
        var errors: [FormValidationError] = []

        if patientName.isEmpty {
            errors.append(FormValidationError(field: "patientName", message: "Patient name is required"))
        }

        if doctor1Name.isEmpty {
            errors.append(FormValidationError(field: "doctor1Name", message: "First doctor name is required"))
        }

        if doctor2Name.isEmpty {
            errors.append(FormValidationError(field: "doctor2Name", message: "Second doctor name is required"))
        }

        if !doctor1IsSection12Approved && !doctor2IsSection12Approved {
            errors.append(FormValidationError(field: "section12Approval", message: "At least one doctor must be Section 12 approved"))
        }

        if mentalDisorderDescription.isEmpty {
            errors.append(FormValidationError(field: "mentalDisorderDescription", message: "Description of mental disorder is required"))
        }

        if reasonsForDetention.isEmpty {
            errors.append(FormValidationError(field: "reasonsForDetention", message: "Reasons for detention are required"))
        }

        return errors
    }

    func toHTML() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <title>Form A3 - Section 2 Joint Medical Recommendation</title>
            <style>
                body { font-family: Arial, sans-serif; font-size: 12pt; line-height: 1.4; }
                h1 { font-size: 16pt; text-align: center; }
                h2 { font-size: 14pt; border-bottom: 1px solid #333; padding-bottom: 4px; }
                .field { margin-bottom: 8px; }
                .label { font-weight: bold; }
            </style>
        </head>
        <body>
            <h1>FORM A3</h1>
            <h2>Mental Health Act 1983 - Section 2</h2>
            <p>Joint medical recommendation for admission for assessment</p>

            <h2>Patient Details</h2>
            <div class="field"><span class="label">Name:</span> \(patientName)</div>
            <div class="field"><span class="label">Address:</span> \(patientAddress)</div>

            <h2>First Practitioner</h2>
            <div class="field"><span class="label">Name:</span> \(doctor1Name)</div>
            <div class="field"><span class="label">Section 12 Approved:</span> \(doctor1IsSection12Approved ? "Yes" : "No")</div>
            <div class="field"><span class="label">Examined on:</span> \(dateFormatter.string(from: doctor1ExaminationDate))</div>

            <h2>Second Practitioner</h2>
            <div class="field"><span class="label">Name:</span> \(doctor2Name)</div>
            <div class="field"><span class="label">Section 12 Approved:</span> \(doctor2IsSection12Approved ? "Yes" : "No")</div>
            <div class="field"><span class="label">Examined on:</span> \(dateFormatter.string(from: doctor2ExaminationDate))</div>

            <h2>Clinical Opinion</h2>
            <div class="field"><span class="label">Mental Disorder:</span> \(mentalDisorderDescription)</div>
            <div class="field"><span class="label">Reasons for Detention:</span> \(reasonsForDetention)</div>
            <div class="field"><span class="label">Why Assessment Necessary:</span> \(reasonsAssessmentNecessary)</div>

            <h2>Signatures</h2>
            <div class="field"><span class="label">First Practitioner:</span> \(doctor1Name) - \(dateFormatter.string(from: doctor1SignatureDate))</div>
            <div class="field"><span class="label">Second Practitioner:</span> \(doctor2Name) - \(dateFormatter.string(from: doctor2SignatureDate))</div>
        </body>
        </html>
        """
    }
}

enum PreviousAcquaintanceType: String, Codable, CaseIterable, Identifiable {
    case none = "No previous acquaintance"
    case treatedPreviously = "Treated patient previously"
    case personalKnowledge = "Personal knowledge of patient"

    var id: String { rawValue }
}
