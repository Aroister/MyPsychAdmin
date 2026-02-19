//
//  A2FormData.swift
//  MyPsychAdmin
//
//  Form A2 - Section 2 Application by AMHP
//  Mental Health Act 1983 - Regulation 4(1)(a)(ii)
//

import Foundation

struct A2FormData: StatutoryForm, Codable, Equatable {
    let id: UUID
    let formType: FormType = .a2
    var patientInfo: PatientInfo
    var clinicianInfo: ClinicianInfo
    let createdAt: Date
    var modifiedAt: Date

    // MARK: - 1. Hospital Details
    var hospitalName: String = ""
    var hospitalAddress: String = ""

    // MARK: - 2. AMHP Details
    var amhpName: String = ""
    var amhpAddress: String = ""
    var amhpEmail: String = ""

    // MARK: - 3. Patient Details
    var patientName: String = ""
    var patientAddress: String = ""

    // MARK: - 4. Local Authority
    var localAuthority: String = ""
    var approvedBySameAuthority: Bool = true
    var approvedByDifferentAuthority: String = ""

    // MARK: - 5. Nearest Relative
    var nrKnown: Bool = true
    // If NR is known:
    var nrIsNearestRelative: Bool = true  // true = option (a), false = option (b) authorized
    var nrName: String = ""
    var nrAddress: String = ""
    var nrInformed: Bool = true
    // If NR is not known:
    var nrUnableToAscertain: Bool = true  // true = option (a), false = option (b) no NR

    // MARK: - 6. Patient Interview
    var lastSeenDate: Date = Date()

    // MARK: - 7. Medical Recommendations
    var noAcquaintanceReason: String = ""

    // MARK: - 8. Signature
    var signatureDate: Date = Date()

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

        // Pre-fill from clinician info
        self.amhpName = clinicianInfo.fullName
        self.amhpEmail = clinicianInfo.email
    }

    // MARK: - Validation
    func validate() -> [FormValidationError] {
        var errors: [FormValidationError] = []

        if hospitalName.isEmpty {
            errors.append(FormValidationError(field: "hospitalName", message: "Hospital name is required"))
        }

        if hospitalAddress.isEmpty {
            errors.append(FormValidationError(field: "hospitalAddress", message: "Hospital address is required"))
        }

        if amhpName.isEmpty {
            errors.append(FormValidationError(field: "amhpName", message: "AMHP name is required"))
        }

        if patientName.isEmpty {
            errors.append(FormValidationError(field: "patientName", message: "Patient name is required"))
        }

        if patientAddress.isEmpty {
            errors.append(FormValidationError(field: "patientAddress", message: "Patient address is required"))
        }

        if localAuthority.isEmpty {
            errors.append(FormValidationError(field: "localAuthority", message: "Local authority is required"))
        }

        if !approvedBySameAuthority && approvedByDifferentAuthority.isEmpty {
            errors.append(FormValidationError(field: "approvedByDifferentAuthority", message: "Approving authority name is required"))
        }

        if nrKnown && nrName.isEmpty {
            errors.append(FormValidationError(field: "nrName", message: "Nearest relative name is required"))
        }

        // Validate last seen date is within 14 days
        let daysDiff = Calendar.current.dateComponents([.day], from: lastSeenDate, to: Date()).day ?? 0
        if daysDiff > 14 {
            errors.append(FormValidationError(field: "lastSeenDate", message: "Patient must have been seen within 14 days"))
        }

        return errors
    }

    // MARK: - HTML Export
    func toHTML() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long

        let nrStatusText: String
        if nrKnown {
            let optionText = nrIsNearestRelative
                ? "(a) This person IS the patient's nearest relative"
                : "(b) This person has been AUTHORISED to act as nearest relative"
            let informedText = nrInformed ? "Yes" : "No"
            nrStatusText = """
            <div class="field"><span class="label">Status:</span> \(optionText)</div>
            <div class="field"><span class="label">Name:</span> \(nrName)</div>
            <div class="field"><span class="label">Address:</span> \(nrAddress)</div>
            <div class="field"><span class="label">Informed:</span> \(informedText)</div>
            """
        } else {
            let optionText = nrUnableToAscertain
                ? "(a) I have been unable to ascertain who is the patient's nearest relative"
                : "(b) The patient appears to have no nearest relative within the meaning of the Act"
            nrStatusText = "<div class=\"field\"><span class=\"label\">Status:</span> \(optionText)</div>"
        }

        let approvedByText = approvedBySameAuthority
            ? localAuthority
            : approvedByDifferentAuthority

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <title>Form A2 - Section 2 Application by AMHP</title>
            <style>
                body { font-family: Arial, sans-serif; font-size: 12pt; line-height: 1.4; }
                h1 { font-size: 16pt; text-align: center; }
                h2 { font-size: 14pt; border-bottom: 1px solid #333; padding-bottom: 4px; }
                .field { margin-bottom: 8px; }
                .label { font-weight: bold; }
                .signature { margin-top: 40px; border-top: 1px solid #333; padding-top: 8px; }
            </style>
        </head>
        <body>
            <h1>FORM A2</h1>
            <h2>Mental Health Act 1983 - Section 2</h2>
            <p>Application by an approved mental health professional for admission for assessment</p>

            <h2>Part 1: Hospital</h2>
            <div class="field"><span class="label">Hospital:</span> \(hospitalName)</div>
            <div class="field"><span class="label">Address:</span> \(hospitalAddress)</div>

            <h2>Part 2: AMHP Details</h2>
            <div class="field"><span class="label">Name:</span> \(amhpName)</div>
            <div class="field"><span class="label">Address:</span> \(amhpAddress)</div>
            <div class="field"><span class="label">Email:</span> \(amhpEmail)</div>

            <h2>Part 3: Patient Details</h2>
            <div class="field"><span class="label">Name:</span> \(patientName)</div>
            <div class="field"><span class="label">Address:</span> \(patientAddress)</div>

            <h2>Part 4: Local Authority</h2>
            <div class="field"><span class="label">Local Social Services Authority:</span> \(localAuthority)</div>
            <div class="field"><span class="label">Approved by:</span> \(approvedByText)</div>

            <h2>Part 5: Nearest Relative</h2>
            \(nrStatusText)

            <h2>Part 6: Patient Interview</h2>
            <div class="field"><span class="label">Date patient last seen:</span> \(dateFormatter.string(from: lastSeenDate))</div>

            <h2>Part 7: Medical Recommendations</h2>
            <p>I attach the written recommendations of two registered medical practitioners.</p>
            \(!noAcquaintanceReason.isEmpty ? "<div class=\"field\"><span class=\"label\">Reason neither practitioner had previous acquaintance:</span> \(noAcquaintanceReason)</div>" : "")

            <div class="signature">
                <div class="field"><span class="label">Signed:</span> _______________________</div>
                <div class="field"><span class="label">Date:</span> \(dateFormatter.string(from: signatureDate))</div>
                <div class="field"><span class="label">Approved Mental Health Professional</span></div>
            </div>
        </body>
        </html>
        """
    }
}

// MARK: - Nearest Relative Consultation Status (shared by A2, A6, etc.)
enum NRConsultationStatus: String, Codable, CaseIterable, Identifiable {
    case consulted = "Consulted"
    case notPracticable = "Not practicable"
    case wouldCauseDelay = "Would cause unreasonable delay"
    case notApplicable = "Not applicable"

    var id: String { rawValue }
}

// MARK: - A6 Not Consulted Reason
enum NotConsultedReason: String, Codable, CaseIterable, Identifiable {
    case notKnown = "Unable to ascertain"           // (a)
    case noNR = "No nearest relative"               // (b)
    case knownButCouldNot = "Known but could not consult"  // (c)

    var id: String { rawValue }
}

// MARK: - A6 Delay Reason (for option c)
enum NCDelayReason: String, Codable, CaseIterable, Identifiable {
    case notPracticable = "Not reasonably practicable"
    case wouldCauseDelay = "Would involve unreasonable delay"

    var id: String { rawValue }
}
