//
//  OtherFormModels.swift
//  MyPsychAdmin
//
//  Form data models for T2, M2, MOJ Leave, MOJ ASR
//

import Foundation

// MARK: - M2 Transmission Method
enum M2TransmissionMethod: String, Codable, CaseIterable, Identifiable {
    case internalMail = "Internal Mail"
    case electronic = "Electronic"
    case otherDelivery = "Other Delivery"

    var id: String { rawValue }

    var formText: String {
        switch self {
        case .internalMail:
            return "consigning it to the hospital managers' internal mail system today at [time]."
        case .electronic:
            return "today sending it to the hospital managers, or a person authorised by them to receive it, by means of electronic communication."
        case .otherDelivery:
            return "sending or delivering it without using the hospital managers' internal mail system."
        }
    }
}

// MARK: - T2 Certifier Type
enum T2CertifierType: String, Codable, CaseIterable, Identifiable {
    case approvedClinician = "Approved Clinician"
    case soad = "SOAD"

    var id: String { rawValue }

    var formText: String {
        switch self {
        case .approvedClinician:
            return "the approved clinician in charge of the treatment described below"
        case .soad:
            return "a registered medical practitioner appointed for the purposes of Part 4 of the Act (a SOAD)"
        }
    }
}

// MARK: - T2 Form (Consent to Treatment)
struct T2FormData: StatutoryForm, Codable, Equatable {
    let id: UUID
    let formType: FormType = .t2
    var patientInfo: PatientInfo
    var clinicianInfo: ClinicianInfo
    let createdAt: Date
    var modifiedAt: Date

    // Patient
    var patientName: String = ""
    var patientAddress: String = ""

    // Hospital
    var hospitalName: String = ""

    // AC/RC Details
    var acName: String = ""
    var acProfession: String = ""
    var certifierType: T2CertifierType = .approvedClinician

    // Treatment Details
    var treatmentPlan: String = ""
    var treatmentDescription: String = ""
    var medicationDetails: String = ""
    var t2Treatment: T2TreatmentData = T2TreatmentData()

    // Consent
    var consentDate: Date = Date()
    var patientCapableOfConsent: Bool = true
    var consentGiven: Bool = true
    var consentExplanation: String = ""

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
        self.acName = clinicianInfo.fullName
    }

    func validate() -> [FormValidationError] {
        var errors: [FormValidationError] = []
        if patientName.isEmpty { errors.append(FormValidationError(field: "patientName", message: "Patient name required")) }
        if acName.isEmpty { errors.append(FormValidationError(field: "acName", message: "AC name required")) }
        if t2Treatment.generatedText.isEmpty && treatmentDescription.isEmpty { errors.append(FormValidationError(field: "treatment", message: "Treatment description required")) }
        return errors
    }

    func toHTML() -> String {
        "<html><body><h1>Form T2 - Consent to Treatment</h1><p>Patient: \(patientName)</p></body></html>"
    }
}

// MARK: - M2 Form (Report Barring Discharge by Nearest Relative)
struct M2FormData: StatutoryForm, Codable, Equatable {
    let id: UUID
    let formType: FormType = .m2
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
    var patientAge: Int = 30

    // Nearest Relative Notice
    var nrName: String = ""
    var nrAddress: String = ""
    var nrRelationship: String = ""
    var dischargeNoticeDate: Date = Date()
    var dischargeNoticeTime: Date = Date()
    var transmissionMethod: M2TransmissionMethod = .internalMail

    // RC Report
    var rcName: String = ""
    var rcEmail: String = ""
    var rcProfession: String = ""

    // Reasons for Barring Discharge
    var dangerousIfDischarged: String = "" // Why patient would be dangerous if discharged
    var riskToSelf: String = ""
    var riskToOthers: String = ""
    var treatmentNeeds: String = ""
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
        self.rcName = clinicianInfo.fullName
    }

    func validate() -> [FormValidationError] {
        var errors: [FormValidationError] = []
        if patientName.isEmpty { errors.append(FormValidationError(field: "patientName", message: "Patient name required")) }
        if hospitalName.isEmpty { errors.append(FormValidationError(field: "hospital", message: "Hospital name required")) }
        if rcName.isEmpty { errors.append(FormValidationError(field: "rcName", message: "RC name required")) }
        if clinicalReasons.generatedText.isEmpty && dangerousIfDischarged.isEmpty { errors.append(FormValidationError(field: "reasons", message: "Reasons why discharge would be dangerous required")) }
        return errors
    }

    func toHTML() -> String {
        "<html><body><h1>Form M2 - Report Barring Discharge</h1><p>Patient: \(patientName)</p></body></html>"
    }
}

// MARK: - Leave Form Category Keywords (for import categorization)
struct LeaveFormCategoryKeywords {
    // Past Psychiatric History (4a) - matching Desktop PSYCH_CATEGORIES
    static let hospitalAdmissions: [String: [String]] = [
        "Admission": [
            "admitted", "admission", "readmitted", "readmission", "informal admission",
            "voluntary admission", "inpatient", "transferred to"
        ],
        "Section": [
            "section 2", "section 3", "section 37", "section 41", "s2", "s3", "s37", "s41",
            "detained under", "mha", "mental health act", "sectioned"
        ],
        "Treatment": [
            "medication", "clozapine", "depot", "antipsychotic", "olanzapine", "risperidone",
            "aripiprazole", "treatment", "ect", "electroconvulsive"
        ],
        "Diagnosis": [
            "diagnosis", "diagnosed", "schizophrenia", "bipolar", "psychosis", "psychotic",
            "schizoaffective", "personality disorder", "depression", "anxiety"
        ],
        "Discharge": [
            "discharged", "discharge", "conditional discharge", "absolute discharge",
            "community treatment order", "cto", "released"
        ],
        "Hospital": [
            "hospital", "unit", "ward", "rampton", "broadmoor", "ashworth",
            "medium secure", "low secure", "high secure", "picu"
        ]
    ]

    // Index Offence / Forensic (4b) - matching Desktop OFFENCE_KEYWORDS
    static let indexOffence: [String: [String]] = [
        "Sexual Offence": [
            "sexual offence", "sexual offense", "sex offence", "sex offense",
            "rape", "sexual assault", "indecent assault", "indecent exposure",
            "child abuse", "child sexual", "paedophil", "pedophil",
            "sexual exploitation", "grooming", "indecent images",
            "voyeurism", "sexual harassment", "sexual abuse",
            "sexual touching", "incest", "buggery",
            "registered sex offender", "shpo", "sexual harm prevention"
        ],
        "Violent Offence": [
            "murder", "manslaughter", "attempted murder", "gbh",
            "grievous bodily harm", "abh", "actual bodily harm",
            "wounding", "assault occasioning", "violent disorder",
            "affray", "robbery", "armed robbery", "aggravated assault",
            "kidnapping", "false imprisonment", "hostage",
            "arson", "attempted arson", "arson with intent",
            "threat to kill", "threats to kill",
            "possession of offensive weapon", "possession of firearm",
            "knife crime", "stabbing", "shooting"
        ],
        "Extremism": [
            "terrorism", "terrorist", "terror offence", "terror-related",
            "extremism", "extremist", "radicalisation", "radicalization",
            "proscribed organisation", "proscribed organization"
        ],
        "Forensic History": [
            "index offence", "forensic history", "offending history",
            "conviction", "convicted", "sentence", "sentenced",
            "prison", "court", "criminal record", "previous offence"
        ]
    ]

    // Mental Disorder (4c) - matching Desktop MENTAL_DISORDER categories
    static let mentalDisorder: [String: [String]] = [
        "Mental State": [
            "mental state", "mental state examination", "mse", "presentation",
            "affect", "thought form", "thought content", "perception",
            "cognition", "orientation", "concentration", "memory"
        ],
        "Psychosis": [
            "psychosis", "psychotic", "schizophrenia", "schizoaffective",
            "delusion", "delusional", "hallucination", "paranoid", "paranoia",
            "thought disorder", "disorganised", "disorganized"
        ],
        "Mood Disorder": [
            "depression", "depressed", "depressive", "bipolar", "mania", "manic",
            "hypomania", "hypomanic", "mood disorder", "affective disorder",
            "low mood", "elevated mood", "suicidal ideation"
        ],
        "Personality Disorder": [
            "personality disorder", "bpd", "eupd", "aspd", "borderline",
            "antisocial", "emotionally unstable", "dissocial"
        ],
        "HPC": [
            "history of presenting complaint", "hpc", "presenting complaint",
            "current presentation", "presenting problem", "reason for admission"
        ],
        "Symptoms": [
            "symptoms", "symptom", "relapse", "deterioration", "exacerbation",
            "stable", "remission", "recovery", "improvement"
        ]
    ]

    // Diagnosis-specific keywords for 4c highlighting (matching detectDiagnosisCategories)
    static let diagnosisKeywords: [String: [String]] = [
        // Section types (when no specific diagnosis detected)
        "HPC": ["presenting complaint", "hpc", "admission", "circumstances", "presentation", "reason for"],
        "Mental State": ["mental state", "mse", "affect", "mood", "thought", "perception", "cognition", "orientation"],
        "Summary": ["summary", "impression", "formulation", "conclusion"],
        "Mental Disorder": ["mental disorder", "psychiatric", "mental health"],
        // Schizophrenia
        "Paranoid Schizophrenia": ["paranoid schizophrenia", "paranoid", "schizophrenia"],
        "Catatonic Schizophrenia": ["catatonic schizophrenia", "catatonic", "schizophrenia"],
        "Hebephrenic Schizophrenia": ["hebephrenic schizophrenia", "hebephrenic", "schizophrenia"],
        "Residual Schizophrenia": ["residual schizophrenia", "residual", "schizophrenia"],
        "Simple Schizophrenia": ["simple schizophrenia", "schizophrenia"],
        "Undifferentiated Schizophrenia": ["undifferentiated schizophrenia", "schizophrenia"],
        "Schizoaffective": ["schizoaffective", "schizo-affective"],
        "Schizophrenia": ["schizophrenia", "schizophrenic"],
        // Mood
        "Bipolar": ["bipolar", "manic depression", "manic depressive", "mania", "manic"],
        "Recurrent Depression": ["recurrent depression", "recurrent depressive"],
        "Major Depression": ["major depression", "major depressive"],
        "Depression": ["depression", "depressed", "depressive"],
        // Personality
        "EUPD": ["emotionally unstable personality", "eupd", "emotionally unstable"],
        "BPD": ["borderline personality", "borderline", "bpd"],
        "ASPD": ["antisocial personality", "aspd", "antisocial"],
        "Dissocial PD": ["dissocial personality", "dissocial"],
        "Paranoid PD": ["paranoid personality"],
        "Personality Disorder": ["personality disorder"],
        // Anxiety
        "GAD": ["generalised anxiety", "generalized anxiety", "gad"],
        "PTSD": ["ptsd", "post-traumatic stress", "post traumatic stress", "trauma"],
        // Psychosis
        "Acute Psychosis": ["acute psychosis", "acute psychotic"],
        "Psychosis": ["psychosis", "psychotic"],
        // Learning/Intellectual
        "Learning Disability": ["learning disability", "learning difficulties"],
        "Intellectual Disability": ["intellectual disability"],
        // Autism
        "Autism": ["autism", "autistic", "asd", "autism spectrum"],
        "Asperger": ["asperger", "aspergers"],
        // Substance
        "Alcohol Dependence": ["alcohol dependence", "alcohol dependency", "alcoholism"],
        "Drug Dependence": ["drug dependence", "drug addiction"],
        "Opioid Dependence": ["opioid dependence", "opiate dependence", "heroin"],
        "Substance Use": ["substance", "drug use", "substance misuse"],
        // Generic
        "Diagnosis": ["diagnosis", "diagnosed", "icd-10", "icd10"]
    ]

    // Attitude & Behaviour - EXACT match to Desktop FILTERS (moj_leave_form_page.py line 7304-7324)
    static let attitudeBehaviour: [String: [String]] = [
        "Mental State": [
            "mental state", "mse", "mood", "affect", "thought", "delusion", "hallucination",
            "psychotic", "psychosis", "depression", "depressed", "anxiety", "anxious",
            "paranoid", "paranoia", "voices", "hearing voices", "suicidal", "self-harm",
            "presentation", "eye contact", "speech", "insight", "agitated", "elated",
            "flat affect", "blunted", "congruent", "incongruent", "thought disorder"
        ],
        "Compliance": [
            "compliant", "compliance", "non-compliant", "medication", "taking medication",
            "refusing medication", "depot", "injection", "oral medication", "tablets",
            "concordant", "concordance", "adherent", "adherence", "treatment plan",
            "accepted", "declined", "refused", "non-concordant", "not taking"
        ],
        "Attendance": [
            "appointment", "attended", "did not attend", "dna", "failed to attend",
            "engagement", "engaged", "engaging", "not engaging", "ward round",
            "review", "session", "meeting", "psychology", "ot session", "group",
            "1:1", "one to one", "1-1", "cpa", "absent", "present", "arrived"
        ],
        "Progress/Behaviour": ["progress", "behaviour", "behavior", "capacity", "attitude"]
    ]

    // Risk Factors
    static let riskFactors: [String: [String]] = [
        "Violence": ["violence", "violent", "assault", "harm to others"],
        "Self-Harm": ["self-harm", "suicide", "suicidal", "overdose"],
        "Substance": ["substance", "drug", "alcohol", "relapse"],
        "Abscond": ["abscond", "awol", "escape"]
    ]

    // Medication
    static let medication: [String: [String]] = [
        "Antipsychotic": ["antipsychotic", "clozapine", "olanzapine", "risperidone", "aripiprazole"],
        "Mood Stabiliser": ["mood stabili", "lithium", "valproate", "carbamazepine"],
        "Antidepressant": ["antidepressant", "sertraline", "mirtazapine", "venlafaxine"],
        "Compliance": ["complian", "depot", "injection", "adherent"]
    ]

    // Psychology
    static let psychology: [String: [String]] = [
        "Risk Assessment": ["hcr-20", "sara", "risk assessment", "structured professional"],
        "Therapy": ["cbt", "dbt", "therapy", "intervention", "formulation"],
        "Psychology": ["psychology", "psycholog"]
    ]

    // Leave Report - SPECIFIC leave terms only (matching Desktop LEAVE_CATEGORIES)
    // Leave Report - matching Desktop keywords exactly
    static let leaveReport: [String: [String]] = [
        "Leave": ["leave", "leave of absence", "leave granted", "leave request", "leave application", "took leave", "went on leave", "returned from leave", "leave taken"],
        "Ground Leave": ["ground leave", "grounds leave", "leave to grounds"],
        "Local Leave": ["local leave", "local community"],
        "Community Leave": ["community leave", "section 17", "s17", "s.17"],
        "Extended Leave": ["extended leave"],
        "Overnight Leave": ["overnight leave", "overnight stay"],
        "Trial Leave": ["trial leave", "compassionate"],
        "Escorted Leave": ["escorted", "accompanied", "with escort", "staff escort"],
        "Unescorted Leave": ["unescorted", "unaccompanied", "without escort", "independent leave"],
        "Medical/Court": ["medical appointment", "court attendance"],
        "Leave Suspension": ["leave suspended", "suspension", "leave cancelled", "awol", "absconded", "failed to return"]
    ]

    // MAPPA (Section 5) - Specific keywords matching Desktop
    static let mappa: [String: [String]] = [
        // Core MAPPA terms - matching Desktop
        "MAPPA": ["mappa", "multi-agency public protection", "multi agency public protection", "public protection", "public protection arrangement"],
        // MAPPA-specific phrases
        "MAPPA Details": ["mappa category", "mappa level", "mappa coordinator", "mappa meeting", "mappa referral", "mappa panel", "mappa notification", "mappa review", "risk management meeting"],
        // Offender types
        "Offender Type": ["registered sex offender", "violent offender", "schedule 15", "other dangerous offender", "sex offender", "category 1", "category 2", "category 3", "level 1", "level 2", "level 3"],
        // Offender management
        "Offender Management": ["offender manager", "probation", "nps", "visor", "police public protection"],
        // Orders
        "Orders": ["shpo", "sexual harm prevention order"]
    ]

    // Victims (Section 6) - Specific keywords matching Desktop
    static let victims: [String: [String]] = [
        // VLO-specific terms - use spaces around abbreviation to avoid matching inside words
        "VLO": [" vlo ", " vlo.", " vlo,", " vlo:", "victim liaison officer", "victim liaison"],
        // Victim-specific phrases
        "Victim": ["victim contact", "victim notification", "victim conditions", "victim concerns"],
        // Restriction-specific phrases (not "restriction" alone)
        "Conditions": ["exclusion zone", "non-contact order", "victim exclusion", "contact restrictions"]
    ]

    // Extremism (4h) - Specific keywords matching Desktop
    static let extremism: [String: [String]] = [
        // Core extremism terms
        "Extremism": ["extremism", "extremist", "radicalisation", "radicalization", "radicalised", "radicalized", "radicalising", "radicalizing"],
        // Terrorism - specific terms only (not "terror" alone - too broad)
        "Terrorism": ["terrorism", "terrorist", "terror-related", "terror offence"],
        // UK Prevent programme - must be specific phrases
        "Prevent": ["prevent programme", "prevent program", "prevent referral", "prevent strategy", "prevent duty", "referred to prevent", "prevent team"],
        // Channel programme (part of Prevent)
        "Channel": ["channel programme", "channel program", "channel referral", "channel panel", "referred to channel"],
        // Counter-terrorism
        "Counter-terrorism": ["counter-terrorism", "counter terrorism", "ct police", "ctiru"],
        // Specific ideologies
        "Ideology": ["far-right", "far right", "right-wing extremism", "left-wing extremism", "islamist", "jihadist", "salafist", "white supremacist", "white nationalist", "neo-nazi", "neo nazi", "nationalist extremism"],
        // Other specific terms
        "Risk": ["hate group", "extremist ideology", "violent extremism", "domestic extremism", "international terrorism", "extremist views", "extremist material", "de-radicalisation", "de-radicalization"]
    ]

    // Absconding (4i) - Specific keywords matching Desktop
    static let absconding: [String: [String]] = [
        // AWOL specific terms
        "AWOL": ["awol", "absent without leave", "went awol", "was awol"],
        // Absconding terms
        "Absconding": ["absconded", "absconding", "abscond"],
        // Failure to return - specific phrases
        "Failure to Return": ["failed to return", "did not return", "didn't return", "failure to return", "failed to return from leave", "did not return from leave"],
        // Late return
        "Late Return": ["returned late", "late return"],
        // Unauthorised absence - specific phrases
        "Unauthorised": ["unauthorised absence", "unauthorized absence"],
        // Missing - specific phrases only (not "missing" alone - too broad)
        "Missing": ["went missing", "missing from ward", "missing from leave"]
    ]

    // Transferred Prisoners (Section 7) - Specific keywords matching Desktop
    static let transferredPrisoners: [String: [String]] = [
        // Specific transfer phrases (not "transfer" or "transferred" alone - too broad)
        "Transfer": ["transferred prisoner", "prison transfer", "transfer back to prison"],
        // MHA sections specific to transferred prisoners
        "MHA Status": ["s47", "s48", "s45a", "section 47", "section 48", "section 45a", "hospital direction", "notional 37"],
        // Remission-specific phrases (not "return" alone - too broad)
        "Remission": ["remission to prison", "remission back to prison", "return to prison", "returned to prison", "prison return", "remit to prison", "remitted to prison"],
        // Release-related terms - use spaces around abbreviations to avoid matching inside words
        "Release": ["earliest release date", " erd ", " erd.", " erd,", "conditional release date", " crd ", " crd.", " crd,", "sentence expiry", "parole", "licence conditions"],
        // Offender manager
        "Offender Manager": ["offender manager", "probation officer", "community offender manager", "nps officer", "national probation service"]
    ]

    // Fitness to Plead (Section 8) - Specific keywords only
    static let fitnessToPlead: [String: [String]] = [
        // Core fitness to plead terms only (not "court", "trial", "capacity" alone - too broad)
        "Fitness": ["fitness to plead", "fit to plead", "unfit to plead", "found unfit", "deemed unfit"],
        // Pritchard criteria
        "Pritchard": ["pritchard criteria", "pritchard test"]
    ]

    /// Categorize text using given keywords dictionary
    static func categorize(_ text: String, using keywords: [String: [String]]) -> [String] {
        let textLower = text.lowercased()
        var matches: [String] = []

        for (category, categoryKeywords) in keywords {
            for keyword in categoryKeywords {
                if textLower.contains(keyword) {
                    if !matches.contains(category) {
                        matches.append(category)
                    }
                    break
                }
            }
        }
        return matches
    }
}

// MARK: - MOJ Leave Form (Leave Application for Restricted Patients)
// Matches desktop structure: 25 sections based on MHCS Leave Application Form
struct MOJLeaveFormData: StatutoryForm, Codable, Equatable {
    let id: UUID
    let formType: FormType = .mojLeave
    var patientInfo: PatientInfo
    var clinicianInfo: ClinicianInfo
    let createdAt: Date
    var modifiedAt: Date

    // ============================================================
    // SECTION 1: Patient Details
    // ============================================================
    var patientName: String = ""
    var patientDOB: Date?
    var patientGender: Gender = .male
    var hospitalNumber: String = ""
    var hospitalName: String = ""
    var wardName: String = ""
    var mhaSection: String = "37/41"  // 37/41, 47/49, 48/49, 45A, Other
    var mojReference: String = ""

    // ============================================================
    // SECTION 2: RC Details
    // ============================================================
    var rcName: String = ""
    var rcEmail: String = ""
    var rcPhone: String = ""

    // ============================================================
    // SECTION 3a: Type of Leave Requested
    // ============================================================
    var compassionateDay: Bool = false
    var compassionateOvernight: Bool = false
    var escortedDay: Bool = false
    var escortedOvernight: Bool = false
    var unescortedDay: Bool = false
    var unescortedOvernight: Bool = false

    // ============================================================
    // SECTION 3b: Documents Reviewed
    // ============================================================
    var docsCPAMinutes: Bool = false
    var docsPsychologyReports: Bool = false
    var docsHCR20: Bool = false
    var docsSARA: Bool = false
    var docsOtherRiskTools: Bool = false
    var docsPreviousReports: Bool = false
    var docsCurrentReports: Bool = false
    var docsPreviousNotes: Bool = false
    var docsCurrentNotes: Bool = false
    var docsOther: String = ""

    // ============================================================
    // SECTION 3c: Purpose of Leave (structured fields matching Desktop)
    // ============================================================
    var purposeText: String = ""
    // Purpose type: starting, continuing, unescorted, rehabilitation
    var purposeType: String = ""
    // Location checkboxes
    var locationGround: Bool = false
    var locationLocal: Bool = false
    var locationCommunity: Bool = false
    var locationFamily: Bool = false
    // Exclusion zone: yes, no, na
    var exclusionZone: String = ""
    // Discharge planning: 0=Not started, 1=Early stages, 2=In progress, 3=Almost completed, 4=Completed
    var dischargePlanningStatus: Int = 0

    // ============================================================
    // SECTION 3d: Unescorted Overnight Leave (structured fields matching Desktop)
    // ============================================================
    var overnightText: String = ""
    // Main toggle: yes, na
    var overnightApplicable: String = ""
    // Accommodation type: 24hr_supported, 9to5_supported, independent, family
    var overnightAccommodationType: String = ""
    var overnightAddress: String = ""
    // Prior to recall: yes, no
    var overnightPriorToRecall: String = ""
    // Linked to index offence: yes, no
    var overnightLinkedToIndex: String = ""
    // Support checkboxes
    var overnightSupportStaff: Bool = false
    var overnightSupportCMHT: Bool = false
    var overnightSupportInpatient: Bool = false
    var overnightSupportFamily: Bool = false
    // Number of nights per week (0-7)
    var overnightNightsPerWeek: Int = 0
    // Discharge to proposed address: yes, no
    var overnightDischargeToAddress: String = ""

    // ============================================================
    // SECTION 3e: Escorted Overnight Leave (structured fields matching Desktop)
    // ============================================================
    var escortedOvernightText: String = ""
    // Main toggle: yes, na
    var escortedOvernightApplicable: String = ""
    // Capacity for residence/leave: yes, no
    var escortedCapacity: String = ""
    // DoLS plan (if no capacity): yes, no
    var escortedDoLSPlan: String = ""
    // Initial testing (if has capacity): yes, no
    var escortedInitialTesting: String = ""
    // Discharge plan checkboxes
    var escortedDischargePlanDoLS: Bool = false
    var escortedDischargePlanUnescorted: Bool = false
    var escortedDischargePlanInitialTesting: Bool = false

    // ============================================================
    // SECTION 3f: Compassionate Leave (structured fields matching Desktop)
    // ============================================================
    var compassionateText: String = ""
    // Main toggle: yes, na
    var compassionateApplicable: String = ""
    // Virtual visit: yes, no
    var compassionateVirtualVisit: String = ""
    // Urgent: yes, no
    var compassionateUrgent: String = ""

    // ============================================================
    // SECTION 3g: Leave Report (using ASRLeaveState for sliders like ASR form)
    // ============================================================
    var leaveReportText: String = ""
    var leaveReportImportedEntries: [ASRImportedEntry] = []
    // Escorted and Unescorted leave states with sliders
    var escortedLeave: ASRLeaveState = ASRLeaveState()
    var unescortedLeave: ASRLeaveState = ASRLeaveState()

    // ============================================================
    // SECTION 3h: Proposed Management / Procedures
    // ============================================================
    var proceduresText: String = ""

    // Escorts / Transport
    var proceduresEscorts: String = ""  // "", "1", "2", "3"
    var proceduresTransportSecure: Bool = false
    var proceduresTransportHospital: Bool = false
    var proceduresTransportTaxi: Bool = false
    var proceduresTransportPublic: Bool = false
    var proceduresHandcuffs: Bool = false
    var proceduresExclusionZone: String = "na"  // "yes", "na"
    var proceduresExclusionDetails: String = ""

    // Pre-leave checkboxes
    var proceduresRiskFree: Bool = false
    var proceduresMentalState: Bool = false
    var proceduresEscortsConfirmed: Bool = false
    var proceduresNoDrugs: Bool = false
    var proceduresTimings: Bool = false

    // On-return checkboxes
    var proceduresSearch: Bool = false
    var proceduresDrugTesting: Bool = false
    var proceduresBreachSuspension: Bool = false
    var proceduresBreachInformMOJ: Bool = false

    // Specific to patient
    var proceduresSpecificToPatient: Bool = false

    // ============================================================
    // SECTION 4a: Past Psychiatric History / Hospital Admissions
    // ============================================================
    var hospitalAdmissionsText: String = ""
    var hospitalAdmissionsImportedEntries: [ASRImportedEntry] = []

    // ============================================================
    // SECTION 4b: Index Offence and Forensic History
    // ============================================================
    var indexOffenceText: String = ""
    var indexOffenceImportedEntries: [ASRImportedEntry] = []

    // ============================================================
    // SECTION 4c: Current Mental Disorder
    // ============================================================
    var mentalDisorderText: String = ""
    var mentalDisorderImportedEntries: [ASRImportedEntry] = []
    // ICD-10 Diagnoses (up to 3)
    var mdDiagnosis1: ICD10Diagnosis = .none
    var mdDiagnosis2: ICD10Diagnosis = .none
    var mdDiagnosis3: ICD10Diagnosis = .none
    var mdClinicalDescription: String = ""
    // Exacerbating Factors
    var mdExacAlcohol: Bool = false
    var mdExacSubstance: Bool = false
    var mdExacNonCompliance: Bool = true  // Default checked per Desktop
    var mdExacFinancial: Bool = false
    var mdExacPersonalRelationships: Bool = false
    var mdExacFamilyStress: Bool = false
    var mdExacPhysicalHealth: Bool = false
    var mdExacWeapons: Bool = false
    // Current Mental State (0=Stable, 1=Minor, 2=Moderate, 3=Significant, 4=Severe)
    var mdMentalStateLevel: Int = 0
    // Insight (0=Nil, 1=Some, 2=Partial, 3=Moderate, 4=Good, 5=Full)
    var mdInsightLevel: Int = 2  // Default Partial
    // Current Observations
    var mdObservations: String = ""  // General, hourly levels, 1:1, etc.
    // Physical Health Impact (0=Minimal, 1=Mild, 2=Some, 3=Moderate, 4=Significant, 5=High)
    var mdPhysicalImpact: Int = 0
    // Physical Health Conditions by category
    var mdPhysCardiac: [String] = []  // diabetes, hypertension, MI, arrhythmias, high cholesterol
    var mdPhysRespiratory: [String] = []  // asthma, COPD, bronchitis
    var mdPhysGastric: [String] = []  // gastric ulcer, GORD, IBS
    var mdPhysNeurological: [String] = []  // MS, Parkinson's, epilepsy
    var mdPhysHepatic: [String] = []  // hepatitis C, fatty liver, ARLD
    var mdPhysRenal: [String] = []  // CKD, ESRD
    var mdPhysCancer: [String] = []  // lung, prostate, bladder, etc.

    // ============================================================
    // SECTION 4d: Attitude and Behaviour
    // ============================================================
    var attitudeBehaviourText: String = ""
    var attitudeBehaviourImportedEntries: [ASRImportedEntry] = []
    // Treatment Understanding & Compliance (values: "", "good", "fair", "poor" / "", "full", "reasonable", "partial", "nil")
    var attMedicalUnderstanding: String = ""
    var attMedicalCompliance: String = ""
    var attNursingUnderstanding: String = ""
    var attNursingCompliance: String = ""
    var attPsychologyUnderstanding: String = ""
    var attPsychologyCompliance: String = ""
    var attOTUnderstanding: String = ""
    var attOTCompliance: String = ""
    var attSocialWorkUnderstanding: String = ""
    var attSocialWorkCompliance: String = ""
    // Ward Rules & Conflict
    var attWardRules: String = ""  // "", "Compliant", "Mostly compliant", "Partially compliant", "Non-compliant"
    var attConflictResponse: String = ""  // "", "Avoids", "De-escalates", "Neutral", "Escalates", "Aggressive"
    // Relationships (0-4 scale: Limited, Some, Good, Close, Very good)
    var attRelStaff: Int = 2
    var attRelPeers: Int = 2
    var attRelFamily: Int = 2
    var attRelFriends: Int = 2
    // Attitudes to Engagement - OT Groups
    var engOTBreakfast: Bool = false
    var engOTCooking: Bool = false
    var engOTCurrentAffairs: Bool = false
    var engOTSelfCare: Bool = false
    var engOTMusic: Bool = false
    var engOTArt: Bool = false
    var engOTGym: Bool = false
    var engOTHorticulture: Bool = false
    var engOTWoodwork: Bool = false
    var engOTWalking: Bool = false
    var engOTLevel: Int = 2  // 0-5: Limited, Mixed, Reasonable, Good, Very Good, Excellent
    // Attitudes to Engagement - Psychology
    var engPsych1to1: Bool = false
    var engPsychRisk: Bool = false
    var engPsychInsight: Bool = false
    var engPsychPsychoed: Bool = false
    var engPsychEmotions: Bool = false
    var engPsychDrugsAlcohol: Bool = false
    var engPsychDischarge: Bool = false
    var engPsychRelapseGroup: Bool = false
    var engPsychRelapse1to1: Bool = false
    var engPsychLevel: Int = 2  // 0-5: Limited, Mixed, Reasonable, Good, Very Good, Excellent
    // Behaviour - Behavioural concerns (last 12 months)
    var behVerbalPhysical: String = ""  // "yes", "no", ""
    var behVerbalPhysicalDetails: String = ""
    var behSubstanceAbuse: String = ""
    var behSubstanceAbuseDetails: String = ""
    var behSelfHarm: String = ""
    var behSelfHarmDetails: String = ""
    var behFireSetting: String = ""
    var behFireSettingDetails: String = ""
    var behIntimidation: String = ""
    var behIntimidationDetails: String = ""
    var behSecretive: String = ""
    var behSecretiveDetails: String = ""
    var behSubversive: String = ""
    var behSubversiveDetails: String = ""
    var behSexuallyInappropriate: String = ""
    var behSexuallyInappropriateDetails: String = ""
    var behExtremist: String = ""
    var behExtremistDetails: String = ""
    var behSeclusion: String = ""
    var behSeclusionDetails: String = ""

    // ============================================================
    // SECTION 4e: Risk Factors
    // ============================================================
    var riskFactorsText: String = ""
    var riskFactorsImportedEntries: [ASRImportedEntry] = []
    // Current Risk Levels (0=None, 1=Low, 2=Medium, 3=High)
    var riskCurrentViolenceOthers: Int = 0
    var riskCurrentViolenceProperty: Int = 0
    var riskCurrentSelfHarm: Int = 0
    var riskCurrentSuicide: Int = 0
    var riskCurrentSelfNeglect: Int = 0
    var riskCurrentSexual: Int = 0
    var riskCurrentExploitation: Int = 0
    var riskCurrentSubstance: Int = 0
    var riskCurrentStalking: Int = 0
    var riskCurrentVulnerability: Int = 0
    var riskCurrentExtremism: Int = 0
    var riskCurrentDeterioration: Int = 0
    var riskCurrentNonCompliance: Int = 0
    // Historical Risk Levels
    var riskHistoricalViolenceOthers: Int = 0
    var riskHistoricalViolenceProperty: Int = 0
    var riskHistoricalSelfHarm: Int = 0
    var riskHistoricalSuicide: Int = 0
    var riskHistoricalSelfNeglect: Int = 0
    var riskHistoricalSexual: Int = 0
    var riskHistoricalExploitation: Int = 0
    var riskHistoricalSubstance: Int = 0
    var riskHistoricalStalking: Int = 0
    var riskHistoricalVulnerability: Int = 0
    var riskHistoricalExtremism: Int = 0
    var riskHistoricalDeterioration: Int = 0
    var riskHistoricalNonCompliance: Int = 0

    // Understanding of Risks (level: 0=poor, 1=fair, 2=good; engagement: 0=none, 1=started, 2=ongoing, 3=advanced, 4=complete)
    var riskUnderstandingLevels: [String: Int] = [:]      // risk key -> understanding level
    var riskUnderstandingEngagement: [String: Int] = [:]  // risk key -> engagement level

    // Stabilising/Destabilising Factors
    var stabilisingFactors: [String] = []      // e.g. ["no substance misuse", "strong relationships"]
    var destabilisingFactors: [String] = []    // e.g. ["substance misuse", "poor relationships"]

    // ============================================================
    // SECTION 4f: Medication
    // ============================================================
    var medicationText: String = ""
    var medicationImportedEntries: [ASRImportedEntry] = []
    // Medication entries (stored as JSON-like array of dicts)
    var medicationEntries: [MedicationEntry] = []
    // Capacity to Consent: "select", "hasCapacity", "lacksCapacity"
    var medCapacity: String = "select"
    // MHA paperwork in place: "yes", "no", "" (shown if lacksCapacity)
    var medMHAPaperwork: String = ""
    // SOAD requested: "yes", "no", "" (shown if MHA = no)
    var medSOADRequested: String = ""
    // Sliders (0-5 scale)
    var medCompliance: Int = 3      // 0=poor, 1=minimal, 2=partial, 3=good, 4=very good, 5=full
    var medImpact: Int = 3          // 0=nil, 1=slight, 2=some, 3=moderate, 4=good, 5=excellent
    var medResponse: Int = 3        // 0=limited, 1=slight, 2=some, 3=moderate, 4=good, 5=excellent
    var medInsight: Int = 3         // 0=nil, 1=minimal, 2=some, 3=moderate, 4=good, 5=excellent

    // ============================================================
    // SECTION 4g: Risks and Psychology
    // ============================================================
    var psychologyText: String = ""
    var psychologyImportedEntries: [ASRImportedEntry] = []

    // Section 1: Index Offence Work (0-6: None, Considering, Starting, Engaging, Well Engaged, Almost Complete, Complete)
    var psychIndexEngagement: Int = 0
    var psychIndexDetails: String = ""

    // Section 2: Offending Behaviour
    var psychInsight: Int = 2       // 0-4: Nil, Limited, Partial, Good, Full
    var psychResponsibility: Int = 2 // 0-4: Denies, Minimises, Partial, Mostly, Full
    var psychEmpathy: Int = 2       // 0-4: Nil, Limited, Developing, Good, Full
    var psychOffendingDetails: String = ""

    // Section 3: Attitudes to risk factors
    // Maps risk factor key to attitude level (0-4: Avoids, Limited, Some, Good, Full understanding)
    var psychRiskAttitudes: [String: Int] = [:]

    // Section 4: Treatment for risk factors
    // Maps risk factor key to treatment data (reuses RiskTreatmentData structure)
    var psychTreatments: [String: RiskTreatmentData] = [:]

    // Section 5: Relapse prevention (0-5: Not started, Just started, Ongoing, Significant progression, Almost completed, Completed)
    var psychRelapsePrevention: Int = 0

    // Section 6: Current Engagement
    var psychCurrentEngagement: Set<String> = []

    // Section 7: Outstanding Needs
    var psychOutstandingNeeds: Set<String> = []

    // ============================================================
    // SECTION 4h: Extremism
    // ============================================================
    var extremismText: String = ""
    var extremismConcern: String = "na"  // "yes", "na"
    // If Yes:
    var extremismVulnerability: Int = 0  // 0-4: Nil, Low, Medium, Significant, High
    var extremismViews: Int = 0  // 0-4: Nil, Rare, Some, Often, High
    var extremismCTPolice: Bool = false
    var extremismCTProbation: Bool = false
    // Prevent referral
    var extremismPreventReferral: String = ""  // "yes", "no", ""
    var extremismPreventOutcome: String = ""
    // Conditions and work done
    var extremismConditions: String = ""
    var extremismWorkDone: String = ""
    var extremismImportedEntries: [ASRImportedEntry] = []

    // ============================================================
    // SECTION 4i: Absconding
    // ============================================================
    var abscondingText: String = ""
    var abscondingAWOL: String = "na"  // "yes", "no", "na"
    var abscondingDetails: String = ""
    var abscondingImportedEntries: [ASRImportedEntry] = []

    // ============================================================
    // SECTION 5: MAPPA
    // ============================================================
    var mappaEligible: String = "no"  // "yes", "no"
    var mappaCoordinator: String = ""
    var mappaCategory: Int = 0  // 0=none, 1, 2, 3, 4
    var mappaLevel: Int = 0     // 0=none, 1, 2, 3
    // Level 1 specific
    var mappaL1Notification: String = ""  // "yes", "no" - MAPPA I notification submitted?
    var mappaL1WillSubmit: String = ""    // "yes", "no" - Will submit prior to leave? (if notification=no)
    // Level 2/3 specific
    var mappaL23Notification: String = "" // "yes", "no" - MAPPA notification submitted & response received?
    var mappaLevelReason: String = ""     // Why managed at this level & conditions requested
    var mappaNotesText: String = ""
    var mappaImportedEntries: [ASRImportedEntry] = []

    // ============================================================
    // SECTION 6: Victims
    // ============================================================
    var victimsVLOContact: String = ""
    var victimsContacted: String = ""  // "yes", "no"
    var victimsReplyDate: String = ""
    var victimsConditions: String = ""
    var victimsRiskAssessment: String = ""
    var victimsImportedEntries: [ASRImportedEntry] = []

    // ============================================================
    // SECTION 7: Transferred Prisoners
    // ============================================================
    var prisonersApplicable: String = "na"  // "yes", "na"
    var prisonersOMContact: String = ""
    var prisonersNotified: String = ""  // "yes", "no"
    var prisonersResponse: String = ""
    var prisonersRemissionText: String = ""
    var prisonersImportedEntries: [ASRImportedEntry] = []

    // ============================================================
    // SECTION 8: Fitness to Plead
    // ============================================================
    var fitnessToPlead: String = ""  // Legacy text field
    var fitnessImportedEntries: [ASRImportedEntry] = []
    var fitnessFoundUnfit: String = "no"  // "yes", "no"
    var fitnessNowFit: String = ""  // "yes", "no"
    var fitnessDetails: String = ""

    // ============================================================
    // SECTION 9: Additional Comments
    // ============================================================
    var additionalCommentsText: String = ""
    var discussedWithPatient: Bool = false
    var issuesOfConcern: Bool = false
    var issuesDetails: String = ""

    // ============================================================
    // Signature
    // ============================================================
    var signatureLine: String = ""
    var signatureName: String = ""
    var signatureDate: Date = Date()

    // ============================================================
    // Annex
    // ============================================================
    var annexProgress: String = ""
    var annexWishes: String = ""
    var annexConfirm: String = ""

    init(id: UUID = UUID(), patientInfo: PatientInfo = PatientInfo(), clinicianInfo: ClinicianInfo = ClinicianInfo()) {
        self.id = id
        self.patientInfo = patientInfo
        self.clinicianInfo = clinicianInfo
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.patientName = patientInfo.fullName
        self.patientDOB = patientInfo.dateOfBirth
        self.hospitalNumber = patientInfo.hospitalNumber
        self.rcName = clinicianInfo.fullName
        self.rcEmail = clinicianInfo.email
        self.rcPhone = clinicianInfo.phone
        self.hospitalName = clinicianInfo.hospitalOrg
        self.signatureName = clinicianInfo.fullName
    }

    func validate() -> [FormValidationError] {
        var errors: [FormValidationError] = []
        if patientName.isEmpty { errors.append(FormValidationError(field: "patientName", message: "Patient name required")) }
        if rcName.isEmpty { errors.append(FormValidationError(field: "rcName", message: "RC name required")) }
        return errors
    }

    func toHTML() -> String {
        "<html><body><h1>MOJ Leave Application</h1><p>Patient: \(patientName)</p></body></html>"
    }

    // Helper to get documents as comma-separated string
    func documentsReviewedText() -> String {
        var docs: [String] = []
        if docsCPAMinutes { docs.append("CPA Minutes") }
        if docsPsychologyReports { docs.append("Psychology Reports") }
        if docsHCR20 { docs.append("HCR-20") }
        if docsSARA { docs.append("SARA") }
        if docsOtherRiskTools { docs.append("Other Risk Assessment Tools") }
        if docsPreviousReports { docs.append("Previous Reports") }
        if docsCurrentReports { docs.append("Current Reports") }
        if docsPreviousNotes { docs.append("Previous Notes") }
        if docsCurrentNotes { docs.append("Current Notes") }
        if !docsOther.isEmpty { docs.append(docsOther) }
        return docs.joined(separator: ", ")
    }

    // Helper to get leave type text
    func leaveTypeText() -> String {
        var types: [String] = []
        if compassionateDay { types.append("Compassionate (day)") }
        if compassionateOvernight { types.append("Compassionate (overnight)") }
        if escortedDay { types.append("Escorted community (day)") }
        if escortedOvernight { types.append("Escorted (overnight)") }
        if unescortedDay { types.append("Unescorted community (day)") }
        if unescortedOvernight { types.append("Unescorted community (overnight)") }
        return types.joined(separator: "\n")
    }

    // Helper to append imported notes to text
    func appendImportedNotes(_ entries: [ASRImportedEntry], to text: String) -> String {
        let selectedImports = entries.filter { $0.selected }
        guard !selectedImports.isEmpty else { return text }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"
        var importedTexts: [String] = []
        for entry in selectedImports {
            if let date = entry.date {
                importedTexts.append("[\(dateFormatter.string(from: date))] \(entry.text)")
            } else {
                importedTexts.append(entry.text)
            }
        }

        if text.isEmpty {
            return "--- Imported Notes ---\n\(importedTexts.joined(separator: "\n"))"
        } else {
            return "\(text)\n\n--- Imported Notes ---\n\(importedTexts.joined(separator: "\n"))"
        }
    }
}

enum RestrictionOrderType: String, Codable, CaseIterable, Identifiable {
    case section37_41 = "Section 37/41"
    case section47_49 = "Section 47/49"
    case section48_49 = "Section 48/49"
    case notionalSection37 = "Notional Section 37"

    var id: String { rawValue }
}

enum LeaveType: String, Codable, CaseIterable, Identifiable {
    case escortedGround = "Escorted Ground Leave"
    case unescortedGround = "Unescorted Ground Leave"
    case escortedCommunity = "Escorted Community Leave"
    case unescortedCommunity = "Unescorted Community Leave"
    case overnightLeave = "Overnight Leave"
    case extendedLeave = "Extended Leave"

    var id: String { rawValue }
}

enum EscortType: String, Codable, CaseIterable, Identifiable {
    case qualified = "Qualified Nursing Staff"
    case unqualified = "Unqualified Staff"
    case family = "Family Member"
    case mixed = "Mixed Escort"

    var id: String { rawValue }
}

enum RiskLevel: String, Codable, CaseIterable, Identifiable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    var id: String { rawValue }

    var color: String {
        switch self {
        case .low: return "green"
        case .medium: return "orange"
        case .high: return "red"
        }
    }
}

// MARK: - ASR Helper Types

/// Behaviour category for Section 4
struct ASRBehaviourItem: Codable, Equatable {
    var present: Bool = false
    var details: String = ""
}

/// Understanding/Compliance levels for Section 6
enum UnderstandingLevel: String, Codable, CaseIterable, Identifiable {
    case notSelected = "Select..."
    case good = "good"
    case fair = "fair"
    case poor = "poor"
    var id: String { rawValue }
}

enum ComplianceLevel: String, Codable, CaseIterable, Identifiable {
    case notSelected = "Select..."
    case full = "full"
    case reasonable = "reasonable"
    case partial = "partial"
    case none = "nil"
    var id: String { rawValue }
}

/// Treatment data for a risk factor (Section 5d)
struct RiskTreatmentData: Codable, Equatable {
    var medication: Bool = false
    var medicationEffectiveness: Int = 0  // 0-6: Nil to Excellent
    var psych1to1: Bool = false
    var psych1to1Effectiveness: Int = 0
    var psychGroups: Bool = false
    var psychGroupsEffectiveness: Int = 0
    var nursing: Bool = false
    var nursingEffectiveness: Int = 0
    var otSupport: Bool = false
    var otSupportEffectiveness: Int = 0
    var socialWork: Bool = false
    var socialWorkEffectiveness: Int = 0
    var concernLevel: Int = 2  // 0-4: None to High
    var concernDetails: String = ""
}

/// Treatment understanding/compliance for Section 6
struct ASRTreatmentAttitude: Codable, Equatable {
    var understanding: UnderstandingLevel = .notSelected
    var compliance: ComplianceLevel = .notSelected
}

/// Capacity assessment for Section 7
enum CapacityStatus: String, Codable, CaseIterable, Identifiable {
    case notSelected = "Select..."
    case hasCapacity = "Has capacity"
    case lacksCapacity = "Lacks capacity"
    var id: String { rawValue }
}

/// Prevent Referral status for Section 10
enum PreventReferralStatus: String, Codable, CaseIterable, Identifiable {
    case notSelected = "Select..."
    case yes = "Yes"
    case no = "No"
    case notApplicable = "N/A"
    var id: String { rawValue }
}

/// MAPPA Category for Section 12
enum MAPPACategory: String, Codable, CaseIterable, Identifiable {
    case notApplicable = "Not applicable"
    case category1 = "Category 1"
    case category2 = "Category 2"
    case category3 = "Category 3"
    var id: String { rawValue }
}

/// MAPPA Level for Section 12
enum MAPPALevel: String, Codable, CaseIterable, Identifiable {
    case notApplicable = "N/A"
    case level1 = "Level 1"
    case level2 = "Level 2"
    case level3 = "Level 3"
    var id: String { rawValue }
}

struct ASRCapacityArea: Codable, Equatable {
    var status: CapacityStatus = .notSelected
    // For Residence and Leave
    var bestInterest: Bool = false
    var imca: Bool = false
    var dols: Bool = false
    var cop: Bool = false
    // For Medication
    var mhaPaperwork: Bool? = nil  // nil = not selected, true = yes, false = no
    var soadRequested: Bool? = nil // nil = not selected, true = yes, false = no
    // For Finances
    var financeType: FinanceCapacityType = .none
}

enum FinanceCapacityType: String, Codable, CaseIterable, Identifiable {
    case none = "None"
    case guardianship = "Guardianship"
    case appointeeship = "Appointeeship"
    case informalAppointeeship = "Informal Appointeeship"
    var id: String { rawValue }
}

/// Leave type with weight for Section 14
struct ASRLeaveTypeWeight: Codable, Equatable {
    var enabled: Bool = false
    var weight: Int = 0
}

/// Leave state (escorted or unescorted)
struct ASRLeaveState: Codable, Equatable {
    var leavesPerPeriod: Int = 1
    var frequency: String = "Weekly"
    var duration: String = "2 hours"
    var ground: ASRLeaveTypeWeight = ASRLeaveTypeWeight()
    var local: ASRLeaveTypeWeight = ASRLeaveTypeWeight()
    var community: ASRLeaveTypeWeight = ASRLeaveTypeWeight()
    var extended: ASRLeaveTypeWeight = ASRLeaveTypeWeight()
    var overnight: ASRLeaveTypeWeight = ASRLeaveTypeWeight()
    var medical: Bool = false
    var court: Bool = false
    var compassionate: Bool = false
    var suspended: Bool? = nil
    var suspensionDetails: String = ""
}

// MedicationEntry is defined in SectionPopupView.swift

/// Imported data entry for ASR sections
struct ASRImportedEntry: Codable, Equatable, Identifiable {
    let id: UUID
    var date: Date?
    var text: String
    var categories: [String]
    var selected: Bool
    var snippet: String?

    init(id: UUID = UUID(), date: Date? = nil, text: String, categories: [String] = [], selected: Bool = false, snippet: String? = nil) {
        self.id = id
        self.date = date
        self.text = text
        self.categories = categories
        self.selected = selected
        self.snippet = snippet
    }
}

/// Document type for imports
enum ASRImportDocumentType: String, Codable {
    case reports
    case notes
}

/// Category keywords for ASR section categorization - matches desktop app
struct ASRCategoryKeywords {
    // MARK: - Section 4 (Behaviour) Categories - enhanced to match desktop
    static let behaviour: [String: [String]] = [
        "Compliance": [
            "complian", "adherent", "taking medication", "treatment adherence", "depot",
            "concordant", "cooperat", "willing", "participation"
        ],
        "Noncompliance": [
            "non compliance", "noncompliance", "non-complian", "refused medication", "refused meds",
            "not taking", "stopped taking", "uncooperative", "resistant", "reluctant"
        ],
        "Insight": [
            "insight", "awareness", "understanding", "recogni", "acknowledge", "accept",
            "denial", "denies", "lack of insight", "poor insight", "good insight",
            "partial insight", "limited insight", "believes", "doesn't believe",
            "mental illness", "unwell", "illness awareness"
        ],
        "Engagement": [
            "engag", "disengag", "attend", "did not attend", "dna", "missed appointment",
            "rapport", "therapeutic relationship", "working with", "cooperat",
            "uncooperative", "resistant", "reluctant", "willing", "unwilling",
            "participat", "involved", "motivation", "motivated"
        ],
        "Verbal Aggression": [
            "verbally abusive", "verbal abuse", "verbally aggressive", "verbal aggression",
            "shouting at", "shouted at", "raised voice", "screaming at",
            "swearing at", "swore at", "threatening language", "made threat",
            "name calling", "name-calling", "racial abuse", "racially abusive",
            "spat at", "spitting at", "intimidat", "charged at", "squared up", "got in face"
        ],
        "Physical Aggression": [
            "physically aggressive", "physical aggression", "physically violent",
            "assaulted", "assault on", "attacked", "punched", "kicked", "hit staff",
            "slapped", "struck", "headbutt", "bit staff", "bitten",
            "scratched staff", "grabbed staff", "pushed staff", "shoved",
            "threw at", "lashed out", "violent outburst", "violent episode",
            "restrained", "restraint required", "rapid tranquil", "rt administered",
            "physical altercation", "physical intervention"
        ],
        "Property Damage": [
            "broke window", "broken window", "smashed", "damaged furniture",
            "punched wall", "kicked door", "threw furniture", "destroyed room",
            "vandal", "trashed room", "overturned table", "damage to property"
        ],
        "Self-Harm": [
            "self-harm", "self harm", "selfharm", "cut himself", "cut herself",
            "cutting", "laceration", "head banging", "banged head", "hit head against",
            "hitting self", "scratching self", "ligature", "attempted to hang",
            "overdose", "swallowed object", "threatened to harm himself",
            "threatened to kill himself", "suicidal ideation", "suicidal thoughts"
        ],
        "Sexual Behaviour": [
            "sexual comment", "inappropriate comment", "sexual remark",
            "sexual touch", "inappropriate touch", "grope", "groping",
            "exposed himself", "exposed herself", "exposure", "flashing",
            "masturbat", "naked in", "walking naked", "sexually disinhibit",
            "sexual advance", "inappropriate advance", "tried to kiss"
        ],
        "Bullying": [
            "bullying", "bully peer", "bullied", "targeting vulnerable",
            "took food from", "took cigarette from", "stealing from peer",
            "demanding money", "extort", "exploit", "intimidating peer",
            "coercing", "pressuring peer", "pushing peer", "shoving peer"
        ],
        "Self-Neglect": [
            "unkempt", "dishevelled", "unwashed", "dirty clothes", "soiled clothes",
            "body odour", "malodorous", "refused shower", "declined shower",
            "refused self-care", "poor self-care", "requires prompting",
            "poor room state", "room in mess", "not eating", "refused food",
            "weight loss", "dehydrat"
        ],
        "AWOL": [
            "awol", "absent without leave", "absconded", "absconding",
            "failed to return", "did not return from leave", "went missing",
            "left without permission", "breach of leave", "escaped"
        ],
        "Substance Misuse": [
            "positive drug", "positive urine", "drug test positive",
            "cannabis", "cocaine", "heroin", "amphetamine", "spice",
            "alcohol on breath", "smelt of alcohol", "intoxicated",
            "suspected substance", "illicit substance", "found drugs"
        ]
    ]

    // MARK: - Section 6 (Patient's Attitude) Categories - enhanced to match desktop
    static let patientAttitude: [String: [String]] = [
        "Index Offence": [
            "index offence", "index offense", "original offence", "original offense",
            "manslaughter", "murder", "attempted murder", "gbh", "abh",
            "threats to kill", "wounding", "arson", "rape", "sexual assault",
            "sexual offence", "indecent assault"
        ],
        "Offending Behaviour": [
            "offence", "offense", "conviction", "prison", "court", "police"
        ],
        "Remorse": [
            "remorse", "remorseful", "regret", "sorry", "apologise", "apologize",
            "apology", "guilt", "guilty feelings", "ashamed", "shame", "sorrow",
            "sorry for", "feels bad", "expressed regret", "no remorse", "lack of remorse",
            "doesn't show remorse", "shows no remorse", "callous", "indifferent"
        ],
        "Victim Empathy": [
            "victim empathy", "empathy", "empathic", "victim awareness", "victim impact",
            "understands impact", "effect on victim", "harm caused", "hurt caused",
            "victim's perspective", "put themselves in", "sympathy", "compassion",
            "lack of empathy", "no empathy", "doesn't understand impact",
            "victim work", "victim letter", "restorative", "callous disregard"
        ],
        "Compliance": [
            "complian", "non-complian", "noncomplian", "adherent", "non-adherent",
            "medication", "meds", "depot", "clozapine", "refused", "refusing",
            "taking medication", "not taking", "stopped taking", "concordan",
            "engagement with treatment", "treatment adherence", "cooperat",
            "uncooperative", "resistant", "reluctant", "willing", "participation"
        ]
    ]

    // MARK: - Section 7 (Capacity) Categories
    static let capacity: [String: [String]] = [
        "Capacity": ["capacity", "lacks capacity", "mental capacity", "mca"],
        "Best Interest": ["best interest", "bi meeting", "best interests"],
        "IMCA": ["imca", "independent mental capacity advocate"],
        "DoLS": ["dols", "deprivation of liberty", "liberty protection"],
        "COP": ["court of protection", "cop application", "cop order"],
        "SOAD": ["soad", "second opinion", "treatment certificate"],
        "Appointeeship": ["appointee", "appointeeship", "dwp"],
        "Guardianship": ["guardianship", "guardian"],
        "IMHA": ["imha", "independent mental health advocate"],
        "Finances": ["finances", "money", "benefits", "financial"],
        "Residence": ["residence", "accommodation", "placement", "discharge planning"]
    ]

    // MARK: - Section 8 (Progress) Categories - matches desktop tribunal section 14 keywords
    static let progress: [String: [String]] = [
        "Mental State": [
            "mental state", "mse", "mental status", "presentation",
            "settled", "unsettled", "stable", "unstable", "calm", "agitated",
            "irritable", "anxious", "low mood", "elated", "elevated mood",
            "psychotic", "paranoid", "guarded", "suspicious", "thought disorder",
            "hallucination", "delusion", "voices", "hearing voices"
        ],
        "Positive Progress": [
            "progress", "improvement", "improved", "improving", "better",
            "settled in his mental", "settled in her mental", "bright in mood",
            "appropriate", "pleasant", "cooperative", "engaging well",
            "good rapport", "well presented", "no concerns",
            "no challenging behaviour", "no incidents"
        ],
        "Deterioration": [
            "deteriorat", "decline", "worsening", "relapse", "decompensate",
            "acutely unwell", "becoming unwell", "symptoms returning",
            "more unwell", "less stable", "increased symptoms",
            "inappropriate"
        ],
        "Insight": [
            "insight", "awareness", "understanding", "recogni", "acknowledge",
            "accept", "denial", "denies", "lack of insight", "poor insight",
            "good insight", "partial insight", "limited insight", "believes",
            "doesn't believe", "mental illness", "illness awareness"
        ],
        "Engagement": [
            "engag", "disengag", "attend", "did not attend", "dna",
            "rapport", "therapeutic relationship", "working with", "cooperat",
            "uncooperative", "resistant", "reluctant", "willing", "unwilling",
            "participat", "involved", "motivation", "motivated"
        ],
        "Risk Work": [
            "psychology", "psychologist", "cbt", "dbt", "violence reduction",
            "offence related work", "offending behaviour", "formulation",
            "therapy", "treatment programme", "risk reduction", "ot group",
            "occupational therapy", "meaningful activity"
        ],
        "Leave": [
            "leave", "escorted", "unescorted", "overnight", "ground leave",
            "community leave", "section 17", "s17", "trial leave", "home leave"
        ],
        "Medication": [
            "medication", "clozapine", "depot", "antipsychotic", "olanzapine",
            "risperidone", "aripiprazole", "quetiapine", "haloperidol",
            "concordant", "compliant with medication", "taking medication",
            "refused medication", "declined medication"
        ]
    ]

    // MARK: - Section 9 (Managing Risk) Categories - specific keywords
    // NOTE: "missing" alone removed - use "went missing" to avoid false positives
    static let managingRisk: [String: [String]] = [
        "Violence": ["violence", "violent", "assault", "aggression", "harm to others", "physical aggression"],
        "Self-Harm": ["self-harm", "suicide", "suicidal", "self harm", "overdose", "self-injury"],
        "Abscond": ["abscond", "absconding", "awol", "absent without leave", "went missing", "escaped"],
        "Substance": ["substance misuse", "drug misuse", "alcohol misuse", "illicit substance"],
        "Sexual": ["sexual offence", "sex offence", "indecent", "sexual risk"],
        "Fire": ["fire-setting", "arson", "fire risk"],
        "Vulnerability": ["vulnerable", "exploitation", "safeguarding", "at risk of exploitation"]
    ]

    // MARK: - Section 10 (How Risks Addressed) Categories - matches desktop Section 9 risk types
    static let riskAddressed: [String: [String]] = [
        "Violence": [
            "violen", "aggress", "assault", "attack", "threat", "intimidat",
            "hostil", "physical altercation", "hit", "punch", "weapon",
            "danger to others", "harm to others"
        ],
        "Self-harm": [
            "self-harm", "self harm", "cutting", "self-injur", "self injur",
            "overdose", "ligature", "scratch", "burn", "wound"
        ],
        "Suicide": [
            "suicid", "end my life", "kill myself", "want to die", "death wish",
            "suicidal ideation", "thoughts of death", "plan to end"
        ],
        "Self-neglect": [
            "self-neglect", "self neglect", "poor hygiene", "not eating",
            "weight loss", "dehydrat", "malnutrition", "refusing food",
            "not caring for", "unkempt", "dirty", "neglecting"
        ],
        "Exploitation": [
            "exploit", "vulnerab", "taken advantage", "financial abuse",
            "manipulat", "cuckooing", "coerced", "grooming", "used by others"
        ],
        "Substance": [
            "substance", "drug", "alcohol", "cannabis", "cocaine", "heroin",
            "spice", "intoxicat", "under the influence", "illicit", "misuse",
            "addiction", "drinking", "using drugs", "relapse"
        ],
        "Deterioration": [
            "deteriorat", "relapse", "worsening", "decline", "decompensate",
            "mental state decline", "becoming unwell", "acutely unwell",
            "symptoms returning", "psychotic", "paranoi"
        ],
        "Non-compliance": [
            "non-complia", "noncomplian", "refused medication", "not taking",
            "declined treatment", "disengag", "not engaging", "missed",
            "did not attend", "dna", "non-adherent", "nonadherent"
        ],
        "Absconding": [
            "abscond", "awol", "absent without leave", "went missing", "escaped",
            "left without permission", "failed to return", "unauthorised absence"
        ],
        "Reoffending": [
            "reoffend", "re-offend", "further offence", "new offence", "arrested",
            "charged", "conviction", "criminal", "police involvement", "court"
        ]
    ]

    // MARK: - Section 11 (Abscond) Categories - matching Desktop exactly
    // NOTE: "missing" alone is NOT included - desktop uses "went missing" phrase to avoid false positives like "dose is missing"
    static let abscond: [String: [String]] = [
        "AWOL": [
            "awol", "a.w.o.l", "absent without leave", "absent without official leave",
            "unauthorised absence", "unauthorized absence", "left without permission"
        ],
        "Absconding": [
            "abscond", "absconded", "absconding", "went missing", "absconded from",
            "whereabouts unknown", "failed to return to ward"
        ],
        "Escape": [
            "escape", "escaped", "escaping", "fled", "ran away", "ran off",
            "broke out", "got away", "evaded", "eluded"
        ],
        "Failure to Return": [
            "failed to return", "failure to return", "did not return", "didn't return",
            "did not return from leave", "overdue from leave", "not returned from leave",
            "late returning from leave", "breach of leave", "leave conditions"
        ]
    ]

    // MARK: - Section 12 (MAPPA) Categories - specific keywords matching Desktop
    // MARK: - Section 12 (MAPPA) Categories - matching Desktop exactly
    static let mappa: [String: [String]] = [
        "MAPPA": [
            "mappa", "multi-agency public protection", "multi agency public protection",
            "public protection", "mappa meeting", "mappa level", "mappa category",
            "mappa coordinator", "mappa panel", "mappa review", "mappa notification", "mappa referral",
            "public protection arrangement", "risk management meeting"
        ],
        "Category": [
            "category 1", "category 2", "category 3",
            "registered sex offender", "violent offender", "schedule 15", "other dangerous offender",
            "sex offender"
        ],
        "Level": [
            "level 1", "level 2", "level 3"
        ],
        "Offender Management": [
            "offender manager", "probation", "probation officer", "national probation service",
            "nps", "visor", "police public protection"
        ],
        "Orders": [
            "shpo", "sexual harm prevention order"
        ]
    ]

    // MARK: - Section 13 (Victims) Categories - specific keywords (not "contact" alone - too broad)
    static let victims: [String: [String]] = [
        "VLO": [
            // Use spaces around "vlo" to avoid matching inside words
            " vlo ", " vlo.", " vlo,", " vlo:", "victim liaison officer", "victim liaison"
        ],
        "Victim": [
            "victim contact", "victim notification", "victim conditions", "victim concerns",
            "victim impact", "victim awareness"
        ],
        "Conditions": [
            "exclusion zone", "non-contact order", "victim exclusion", "contact restrictions"
        ]
    ]

    // MARK: - Section 14 (Leave) Categories - SPECIFIC leave terms (matching Desktop)
    // MARK: - Section 14 (Leave Report) Categories - matching Desktop exactly
    static let leaveReport: [String: [String]] = [
        "Leave": ["leave", "leave of absence", "leave granted", "leave request", "leave application", "took leave", "went on leave", "returned from leave", "leave taken"],
        "Ground Leave": ["ground leave", "grounds leave", "leave to grounds"],
        "Local Leave": ["local leave", "local community"],
        "Community Leave": ["community leave", "section 17", "s17", "s.17"],
        "Extended Leave": ["extended leave"],
        "Overnight Leave": ["overnight leave", "overnight stay"],
        "Trial Leave": ["trial leave", "compassionate"],
        "Escorted Leave": ["escorted", "accompanied", "with escort", "staff escort"],
        "Unescorted Leave": ["unescorted", "unaccompanied", "without escort", "independent leave"],
        "Medical/Court": ["medical appointment", "court attendance"],
        "Leave Suspension": ["leave suspended", "suspension", "leave cancelled", "awol", "absconded", "failed to return"]
    ]

    // MARK: - Category Colors
    static let categoryColors: [String: String] = [
        // Section 4 (Behaviour)
        "Compliance": "#059669",
        "Noncompliance": "#dc2626",
        "Insight": "#7c3aed",
        "Engagement": "#2563eb",
        "Verbal Aggression": "#ea580c",
        "Physical Aggression": "#dc2626",
        "Property Damage": "#b45309",
        "Self-Harm": "#be185d",
        "Sexual Behaviour": "#9333ea",
        "Bullying": "#c2410c",
        "Self-Neglect": "#0891b2",
        "AWOL": "#f57c00",
        "Substance Misuse": "#65a30d",
        // Section 6 (Patient Attitude)
        "Index Offence": "#991b1b",
        "Offending Behaviour": "#b91c1c",
        "Remorse": "#059669",
        "Victim Empathy": "#0d9488",
        // Section 7 (Capacity)
        "Capacity": "#7c3aed",
        "Best Interest": "#2563eb",
        "IMCA": "#0891b2",
        "DoLS": "#dc2626",
        "COP": "#9333ea",
        "SOAD": "#ea580c",
        "Appointeeship": "#4f46e5",
        "Guardianship": "#0d9488",
        "IMHA": "#ea580c",
        "Finances": "#6366f1",
        "Residence": "#84cc16",
        // Section 8 (Progress) - matching desktop
        "Mental State": "#7c3aed",
        "Positive Progress": "#059669",
        "Deterioration": "#dc2626",
        "Risk Work": "#d97706",
        "Leave": "#0d9488",
        "Medication": "#be185d",
        // Section 10 (Risk Addressed) - matching desktop risk types
        "Violence": "#dc2626",
        "Self-harm": "#ea580c",
        "Suicide": "#7c3aed",
        "Self-neglect": "#0891b2",
        "Exploitation": "#be185d",
        "Substance": "#059669",
        "Non-compliance": "#4f46e5",
        "Absconding": "#0d9488",
        "Reoffending": "#991b1b",
        // Section 11 (Abscond)
        "Abscond": "#f57c00",
        "Failure to Return": "#d97706",
        // Section 12 (MAPPA)
        "MAPPA": "#7c3aed",
        "Category": "#dc2626",
        "Level": "#059669",
        "Offender Management": "#d97706",
        "Orders": "#be185d",
        // Section 13 (Victims)
        "VLO": "#2563eb",
        "Conditions": "#ea580c",
        // Section 13 (Victims)
        "Victim": "#be185d",
        "Contact": "#2563eb",
        "Restriction": "#dc2626",
        // 4a Past Psychiatric History categories (matching Desktop PSYCH_CATEGORY_COLORS)
        "Admission": "#7c3aed",         // Purple
        "Section": "#dc2626",           // Red
        "Treatment": "#0891b2",         // Cyan
        "Diagnosis": "#059669",         // Green
        "Discharge": "#d97706",         // Amber
        "Hospital": "#3b82f6",          // Blue
        // 4b Index Offence / Forensic categories
        "Sexual Offence": "#be185d",    // Pink
        "Violent Offence": "#dc2626",   // Red
        "Extremism": "#7c3aed",         // Purple
        "Forensic History": "#b45309",  // Brown/Amber
        // 4c Mental Disorder categories
        "Psychosis": "#dc2626",         // Red
        "Mood Disorder": "#7c3aed",     // Purple
        "Personality Disorder": "#be185d", // Pink
        "HPC": "#0891b2",               // Cyan
        "Symptoms": "#d97706",          // Amber
        // Leave categories (matching Desktop CATEGORY_COLORS)
        "Ground Leave": "#059669",      // Green
        "Local Leave": "#0891b2",       // Cyan
        "Community Leave": "#3b82f6",   // Blue
        "Extended Leave": "#7c3aed",    // Purple
        "Overnight Leave": "#6366f1",   // Indigo
        "Escorted Leave": "#d97706",    // Amber
        "Unescorted Leave": "#dc2626",  // Red
        "Leave Progress": "#0d9488",    // Teal
        "Leave Suspension": "#be185d"   // Pink
    ]

    // MARK: - False Positive Phrases (matching Desktop)
    // These phrases before a keyword indicate a false positive match
    // e.g., "no self harm noted" or "denied aggression" should NOT match
    static let falsePositivePhrases: [String] = [
        "was not", "were not", "has not been", "had not been", "wasn't", "weren't",
        "no evidence of", "no signs of", "no indication of", "denied",
        "risk of", "at risk of", "risk assessment", "level of risk",
        "potential for", "possibility of", "likelihood of",
        "remains a risk", "continues to pose", "history of",
        "background of", "previous history", "known history",
        "there was no", "there were no", "nil", "none noted",
        "remained calm", "remained settled", "was calm", "was settled"
    ]

    // MARK: - Whole Word Keywords (matching Desktop)
    // These short keywords require word boundary matching to avoid false positives
    // e.g., "visor" shouldn't match "advisor", "nps" shouldn't match "snps"
    static let wholeWordKeywords: Set<String> = [
        "visor", "mappa", "nps",  // MAPPA section
        "charged"                  // Reoffending section
    ]

    /// Check if a keyword match is a false positive based on context before the keyword
    /// Matches Desktop is_false_positive function - checks 60 chars before keyword
    static func isFalsePositive(_ text: String, keyword: String) -> Bool {
        let textLower = text.lowercased()
        let kwLower = keyword.lowercased()

        // Find position of keyword
        guard let range = textLower.range(of: kwLower) else {
            return false
        }

        let pos = textLower.distance(from: textLower.startIndex, to: range.lowerBound)

        // Get context before the keyword (60 chars)
        let contextStart = max(0, pos - 60)
        let startIndex = textLower.index(textLower.startIndex, offsetBy: contextStart)
        let endIndex = textLower.index(textLower.startIndex, offsetBy: pos)
        let contextBefore = String(textLower[startIndex..<endIndex])

        // Check for false positive phrases in context before
        for fpPhrase in falsePositivePhrases {
            if contextBefore.contains(fpPhrase) {
                return true
            }
        }

        return false
    }

    /// Check if text contains keyword with word boundaries (for short keywords)
    static func containsWholeWord(_ text: String, keyword: String) -> Bool {
        let textLower = text.lowercased()
        let pattern = "\\b\(NSRegularExpression.escapedPattern(for: keyword))\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return false
        }
        let range = NSRange(textLower.startIndex..., in: textLower)
        return regex.firstMatch(in: textLower, options: [], range: range) != nil
    }

    /// Categorize text using the given category keywords dictionary
    /// Now includes false positive filtering and whole word matching (matching Desktop)
    static func categorize(_ text: String, using keywords: [String: [String]], useFalsePositiveFiltering: Bool = false) -> [String] {
        let textLower = text.lowercased()
        var matches: [String] = []

        for (category, categoryKeywords) in keywords {
            for keyword in categoryKeywords {
                var found = false

                // Check if this keyword needs whole-word matching
                if wholeWordKeywords.contains(keyword) {
                    found = containsWholeWord(textLower, keyword: keyword)
                } else {
                    found = textLower.contains(keyword)
                }

                if found {
                    // Apply false positive filtering if enabled (Section 4 uses this)
                    if useFalsePositiveFiltering {
                        if !isFalsePositive(text, keyword: keyword) {
                            if !matches.contains(category) {
                                matches.append(category)
                            }
                        }
                    } else {
                        if !matches.contains(category) {
                            matches.append(category)
                        }
                    }
                    break
                }
            }
        }

        return matches
    }
}

// MARK: - MOJ ASR Form (Annual Statutory Report)
// Matches desktop structure: 17 sections based on MOJ_ASR_template.docx
struct MOJASRFormData: StatutoryForm, Codable, Equatable {
    let id: UUID
    let formType: FormType = .mojASR
    var patientInfo: PatientInfo
    var clinicianInfo: ClinicianInfo
    let createdAt: Date
    var modifiedAt: Date

    // ============================================================
    // SECTION 1: Patient Details
    // ============================================================
    var patientName: String = ""
    var patientDOB: Date?
    var patientGender: Gender = .male
    var hospitalName: String = ""
    var nhsNumber: String = ""
    var mhcsRef: String = ""
    var mhaSection: String = "S37/41"
    var mhaSectionDate: Date?
    var otherDetention: String = ""

    // ============================================================
    // SECTION 2: Responsible Clinician
    // ============================================================
    var rcName: String = ""
    var rcJobTitle: String = ""
    var rcPhone: String = ""
    var rcEmail: String = ""
    var mhaOfficeEmail: String = ""

    // ============================================================
    // SECTION 3: Patient's Mental Disorder (3 ICD-10 diagnoses)
    // ============================================================
    var diagnosis1ICD10: ICD10Diagnosis = .none
    var diagnosis1Custom: String = ""
    var diagnosis2ICD10: ICD10Diagnosis = .none
    var diagnosis2Custom: String = ""
    var diagnosis3ICD10: ICD10Diagnosis = .none
    var diagnosis3Custom: String = ""
    var clinicalDescription: String = ""

    // Computed properties for diagnosis text
    var diagnosis1: String {
        if diagnosis1ICD10 != .none { return diagnosis1ICD10.rawValue }
        return diagnosis1Custom
    }
    var diagnosis2: String {
        if diagnosis2ICD10 != .none { return diagnosis2ICD10.rawValue }
        return diagnosis2Custom
    }
    var diagnosis3: String {
        if diagnosis3ICD10 != .none { return diagnosis3ICD10.rawValue }
        return diagnosis3Custom
    }

    // ============================================================
    // SECTION 4: Attitude & Behaviour (Yes/No categories)
    // ============================================================
    var verbalPhysicalAggression: ASRBehaviourItem = ASRBehaviourItem()
    var substanceAbuse: ASRBehaviourItem = ASRBehaviourItem()
    var selfHarm: ASRBehaviourItem = ASRBehaviourItem()
    var fireSetting: ASRBehaviourItem = ASRBehaviourItem()
    var intimidation: ASRBehaviourItem = ASRBehaviourItem()
    var secretiveManipulative: ASRBehaviourItem = ASRBehaviourItem()
    var subversiveBehaviour: ASRBehaviourItem = ASRBehaviourItem()
    var sexuallyDisinhibited: ASRBehaviourItem = ASRBehaviourItem()
    var extremistBehaviour: ASRBehaviourItem = ASRBehaviourItem()
    var seclusionPeriods: ASRBehaviourItem = ASRBehaviourItem()
    var behaviourNotes: String = ""
    var behaviourImportedEntries: [ASRImportedEntry] = []

    // ============================================================
    // SECTION 5: Addressing Issues
    // ============================================================
    // 5a: Index offence work (0-6: None to Complete)
    var indexOffenceWorkLevel: Int = 0
    var indexOffenceWorkDetails: String = ""

    // 5b: OT Groups (checkboxes)
    var otBreakfastClub: Bool = false
    var otSmoothie: Bool = false
    var otCooking: Bool = false
    var otCurrentAffairs: Bool = false
    var otSelfCare: Bool = false
    var otTrips: Bool = false
    var otMusic: Bool = false
    var otArt: Bool = false
    var otGym: Bool = false
    var otWoodwork: Bool = false
    var otHorticulture: Bool = false
    var otPhysio: Bool = false
    var otEngagementLevel: Int = 2  // 0-5: Limited to Excellent

    // 5c: Psychology (checkboxes)
    var psychOneToOne: Bool = false
    var psychRisk: Bool = false
    var psychInsight: Bool = false
    var psychPsychoeducation: Bool = false
    var psychManagingEmotions: Bool = false
    var psychDrugsAlcohol: Bool = false
    var psychCarePathway: Bool = false
    var psychDischargePlanning: Bool = false
    var psychEngagementLevel: Int = 2  // 0-5: Limited to Excellent

    // 5d: Risk factors with attitudes (0-4: Avoids to Fully understands)
    var riskViolenceOthers: Bool = false
    var riskViolenceOthersAttitude: Int = 2
    var riskViolenceProperty: Bool = false
    var riskViolencePropertyAttitude: Int = 2
    var riskVerbalAggression: Bool = false
    var riskVerbalAggressionAttitude: Int = 2
    var riskSubstanceMisuse: Bool = false
    var riskSubstanceMisuseAttitude: Int = 2
    var riskSelfHarm: Bool = false
    var riskSelfHarmAttitude: Int = 2
    var riskSelfNeglect: Bool = false
    var riskSelfNeglectAttitude: Int = 2
    var riskStalking: Bool = false
    var riskStalkingAttitude: Int = 2
    var riskThreateningBehaviour: Bool = false
    var riskThreateningBehaviourAttitude: Int = 2
    var riskSexuallyInappropriate: Bool = false
    var riskSexuallyInappropriateAttitude: Int = 2
    var riskVulnerability: Bool = false
    var riskVulnerabilityAttitude: Int = 2
    var riskBullyingVictimisation: Bool = false
    var riskBullyingVictimisationAttitude: Int = 2
    var riskAbsconding: Bool = false
    var riskAbscondingAttitude: Int = 2
    var riskReoffending: Bool = false
    var riskReoffendingAttitude: Int = 2

    // 5e: Treatment data per risk factor
    // Each risk factor can have treatments with effectiveness levels
    var treatmentData: [String: RiskTreatmentData] = [:]

    // 5f: Relapse prevention (0-5: Not started to Completed)
    var relapsePreventionLevel: Int = 0

    var addressingIssuesNotes: String = ""

    // ============================================================
    // SECTION 6: Patient's Attitude
    // ============================================================
    var attMedical: ASRTreatmentAttitude = ASRTreatmentAttitude()
    var attNursing: ASRTreatmentAttitude = ASRTreatmentAttitude()
    var attPsychology: ASRTreatmentAttitude = ASRTreatmentAttitude()
    var attOT: ASRTreatmentAttitude = ASRTreatmentAttitude()
    var attSocialWork: ASRTreatmentAttitude = ASRTreatmentAttitude()

    // Offending behaviour
    var offendingInsightLevel: Int = 2  // 0-4: Nil to Full
    var responsibilityLevel: Int = 2    // 0-4: Denies to Full
    var victimEmpathyLevel: Int = 2     // 0-4: Nil to Full
    var offendingDetails: String = ""
    var patientAttitudeImportedEntries: [ASRImportedEntry] = []

    // ============================================================
    // SECTION 7: Capacity Issues
    // ============================================================
    var capResidence: ASRCapacityArea = ASRCapacityArea()
    var capMedication: ASRCapacityArea = ASRCapacityArea()
    var capFinances: ASRCapacityArea = ASRCapacityArea()
    var capLeave: ASRCapacityArea = ASRCapacityArea()
    var capacityNotes: String = ""
    var capacityImportedEntries: [ASRImportedEntry] = []

    // ============================================================
    // SECTION 8: Progress
    // ============================================================
    var mentalStateLevel: Int = 3       // 0-6: Unsettled to Symptom free
    var insightLevel: Int = 2           // 0-5: Remains limited to Full insight
    var engagementLevel: Int = 3        // 0-5: Nil to Full
    var riskReductionLevel: Int = 2     // 0-5: Nil to Completed
    var leaveTypeLevel: Int = 0         // 0-3: No leave to Overnight
    var leaveUsageLevel: Int = 2        // 0-4: Intermittent to Excellent
    var leaveConcernsLevel: Int = 0     // 0-4: No to Significant
    var dischargePlanningLevel: Int = 0 // 0-4: Not started to Completed
    var hasDischargeApplication: Bool = false
    var progressImportedEntries: [ASRImportedEntry] = []

    // ============================================================
    // SECTION 9: Managing Risk
    // ============================================================
    var managingRiskText: String = ""
    var riskImportedEntries: [ASRImportedEntry] = []

    // Current Risk Factors (0=unchecked, 1=Low, 2=Medium, 3=High)
    // Matches Section 5 risk factors
    var currentRiskViolenceOthers: Int = 0
    var currentRiskViolenceProperty: Int = 0
    var currentRiskVerbalAggression: Int = 0
    var currentRiskSubstanceMisuse: Int = 0
    var currentRiskSelfHarm: Int = 0
    var currentRiskSelfNeglect: Int = 0
    var currentRiskStalking: Int = 0
    var currentRiskThreateningBehaviour: Int = 0
    var currentRiskSexuallyInappropriate: Int = 0
    var currentRiskVulnerability: Int = 0
    var currentRiskBullyingVictimisation: Int = 0
    var currentRiskAbsconding: Int = 0
    var currentRiskReoffending: Int = 0

    // Historical Risk Factors (0=unchecked, 1=Low, 2=Medium, 3=High)
    // Matches Section 5 risk factors
    var historicalRiskViolenceOthers: Int = 0
    var historicalRiskViolenceProperty: Int = 0
    var historicalRiskVerbalAggression: Int = 0
    var historicalRiskSubstanceMisuse: Int = 0
    var historicalRiskSelfHarm: Int = 0
    var historicalRiskSelfNeglect: Int = 0
    var historicalRiskStalking: Int = 0
    var historicalRiskThreateningBehaviour: Int = 0
    var historicalRiskSexuallyInappropriate: Int = 0
    var historicalRiskVulnerability: Int = 0
    var historicalRiskBullyingVictimisation: Int = 0
    var historicalRiskAbsconding: Int = 0
    var historicalRiskReoffending: Int = 0

    // ============================================================
    // SECTION 10: How Risks Addressed
    // ============================================================
    var riskAddressedText: String = ""
    var riskProgressText: String = ""           // Progress and issues of concern
    var riskFactorsText: String = ""            // Factors underpinning index offence
    var riskAttitudesText: String = ""          // Attitudes to index offence & victims
    var preventReferral: PreventReferralStatus = .notSelected
    var preventOutcome: String = ""
    var riskAddressedImportedEntries: [ASRImportedEntry] = []

    // ============================================================
    // SECTION 11: Abscond / Escape
    // ============================================================
    var abscondText: String = ""
    var hasAwolIncidents: Bool = false
    var abscondDetails: String = ""
    var abscondImportedEntries: [ASRImportedEntry] = []

    // ============================================================
    // SECTION 12: MAPPA
    // ============================================================
    var mappaText: String = ""
    var mappaCategory: MAPPACategory = .notApplicable
    var mappaLevel: MAPPALevel = .notApplicable
    var mappaDateKnown: Bool = true
    var mappaDate: Date = Date()
    var mappaComments: String = ""
    var mappaCoordinator: String = ""
    var mappaImportedEntries: [ASRImportedEntry] = []

    // ============================================================
    // SECTION 13: Victims
    // ============================================================
    var victimsText: String = ""
    var vloContact: String = ""
    var vloDateKnown: Bool = true
    var vloDate: Date = Date()
    var victimConcerns: String = ""
    var victimsImportedEntries: [ASRImportedEntry] = []

    // ============================================================
    // SECTION 14: Leave Report
    // ============================================================
    var escortedLeave: ASRLeaveState = ASRLeaveState()
    var unescortedLeave: ASRLeaveState = ASRLeaveState()
    var leaveReportImportedEntries: [ASRImportedEntry] = []

    // ============================================================
    // SECTION 15: Additional Comments (Legal Criteria)
    // ============================================================
    var additionalCommentsText: String = ""
    var mentalDisorderPresent: Bool? = nil           // nil=not selected, true=present, false=absent
    var mentalDisorderICD10: ICD10Diagnosis = .none  // ICD-10 diagnosis when present
    var criteriaWarrantingDetention: Bool? = nil     // nil=not selected, true=met, false=not met
    var criteriaByNature: Bool = false
    var natureRelapsing: Bool = false
    var natureTreatmentResistant: Bool = false
    var natureChronic: Bool = false
    var criteriaByDegree: Bool = false
    var degreeSeverity: Int = 2                      // 1-4: Some, Several, Many, Overwhelming
    var degreeDetails: String = ""

    // Necessity section
    var necessity: Bool? = nil                       // nil=not selected, true=yes, false=no
    var healthNecessity: Bool = false
    var mentalHealthNecessity: Bool = false
    var poorCompliance: Bool = false
    var limitedInsight: Bool = false
    var physicalHealthNecessity: Bool = false
    var physicalHealthDetails: String = ""
    var safetyNecessity: Bool = false
    var selfSafety: Bool = false
    var selfSafetyDetails: String = ""
    // Self safety checkboxes (from A3)
    var selfNeglectHistorical: Bool = false
    var selfNeglectCurrent: Bool = false
    var selfRiskyHistorical: Bool = false
    var selfRiskyCurrent: Bool = false
    var selfHarmHistorical: Bool = false
    var selfHarmCurrent: Bool = false

    var othersSafety: Bool = false
    var othersSafetyDetails: String = ""
    // Others safety checkboxes (from A3)
    var violenceHistorical: Bool = false
    var violenceCurrent: Bool = false
    var verbalAggressionHistorical: Bool = false
    var verbalAggressionCurrent: Bool = false
    var sexualViolenceHistorical: Bool = false
    var sexualViolenceCurrent: Bool = false
    var stalkingHistorical: Bool = false
    var stalkingCurrent: Bool = false
    var arsonHistorical: Bool = false
    var arsonCurrent: Bool = false

    // Treatment Available & Least Restrictive
    var treatmentAvailable: Bool = false
    var leastRestrictiveOption: Bool = false

    // ============================================================
    // SECTION 16: Unfit to Plead
    // ============================================================
    var unfitToPleadText: String = ""
    var foundUnfitToPlead: Bool? = nil               // nil=not selected, true=yes, false=no
    var nowFitToPlead: Bool? = nil                   // nil=not selected, true=yes, false=no
    var unfitToPleadDetails: String = ""

    // ============================================================
    // Signature
    // ============================================================
    var signatureDate: Date = Date()

    // ============================================================
    // Import Data Storage
    // ============================================================
    var importDocumentType: ASRImportDocumentType = .notes

    init(id: UUID = UUID(), patientInfo: PatientInfo = PatientInfo(), clinicianInfo: ClinicianInfo = ClinicianInfo()) {
        self.id = id
        self.patientInfo = patientInfo
        self.clinicianInfo = clinicianInfo
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.patientName = patientInfo.fullName
        self.patientDOB = patientInfo.dateOfBirth
        self.patientGender = patientInfo.gender
        self.rcName = clinicianInfo.fullName
        self.rcEmail = clinicianInfo.email
        self.rcPhone = clinicianInfo.phone
        self.rcJobTitle = clinicianInfo.roleTitle
        self.hospitalName = clinicianInfo.hospitalOrg
    }

    func validate() -> [FormValidationError] {
        var errors: [FormValidationError] = []
        if patientName.isEmpty { errors.append(FormValidationError(field: "patientName", message: "Patient name required")) }
        if rcName.isEmpty { errors.append(FormValidationError(field: "rcName", message: "RC name required")) }
        return errors
    }

    func toHTML() -> String {
        "<html><body><h1>MOJ Annual Statutory Report</h1><p>Patient: \(patientName)</p></body></html>"
    }

    // MARK: - Text Generation Helpers

    /// Helper function to append selected imported entries to text
    private func appendImportedNotes(_ entries: [ASRImportedEntry], to text: String) -> String {
        let selectedImports = entries.filter { $0.selected }
        guard !selectedImports.isEmpty else { return text }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"
        var importedTexts: [String] = []
        for entry in selectedImports {
            if let date = entry.date {
                importedTexts.append("[\(dateFormatter.string(from: date))] \(entry.text)")
            } else {
                importedTexts.append(entry.text)
            }
        }

        if text.isEmpty {
            return "--- Imported Notes ---\n\(importedTexts.joined(separator: "\n"))"
        } else {
            return "\(text)\n\n--- Imported Notes ---\n\(importedTexts.joined(separator: "\n"))"
        }
    }

    /// Generate behaviour text from the Yes/No categories
    func generateBehaviourText() -> String {
        // Helper to format lists with "and" before last item (matching desktop)
        func formatList(_ items: [String]) -> String {
            if items.isEmpty { return "" }
            if items.count == 1 { return items[0] }
            if items.count == 2 { return "\(items[0]) and \(items[1])" }
            return items.dropLast().joined(separator: ", ") + " and " + items.last!
        }

        var parts: [String] = []

        let behaviours: [(ASRBehaviourItem, String, String)] = [
            (verbalPhysicalAggression, "verbal/physical aggression or violence", "no verbal or physical aggression"),
            (substanceAbuse, "substance abuse", "no substance abuse"),
            (selfHarm, "self-harm", "no self-harm"),
            (fireSetting, "fire-setting", "no fire-setting"),
            (intimidation, "intimidation/threats", "no intimidation or threats"),
            (secretiveManipulative, "secretive/dishonest/manipulative behaviour", "no secretive or manipulative behaviour"),
            (subversiveBehaviour, "subversive behaviour", "no subversive behaviour"),
            (sexuallyDisinhibited, "sexually disinhibited/inappropriate behaviour", "no sexually disinhibited behaviour"),
            (extremistBehaviour, "extremist/terrorist risk ideology/behaviour", "no extremist behaviour"),
            (seclusionPeriods, "periods of seclusion", "no periods of seclusion")
        ]

        var concerns: [String] = []
        var negatives: [String] = []

        for (item, yesText, noText) in behaviours {
            if item.present {
                if item.details.isEmpty {
                    concerns.append(yesText.lowercased())
                } else {
                    concerns.append("\(yesText.lowercased()) (\(item.details))")
                }
            } else {
                negatives.append(noText)
            }
        }

        // Positive concerns - matching desktop format
        if !concerns.isEmpty {
            let concernsList = formatList(concerns)
            parts.append("In the last 12 months there have been concerns regarding \(concernsList).")
        }

        // Negative statements - matching desktop format
        if !negatives.isEmpty {
            let negativesList = formatList(negatives)
            parts.append("There has been \(negativesList).")
        }

        // Additional notes
        if !behaviourNotes.isEmpty {
            parts.append(behaviourNotes)
        }

        let baseText = parts.joined(separator: " ")
        return appendImportedNotes(behaviourImportedEntries, to: baseText)
    }

    /// Generate progress text from sliders
    func generateProgressText() -> String {
        let pro = patientGender == .male ? "He" : patientGender == .female ? "She" : "They"
        let has = patientGender == .other ? "have" : "has"
        let pos = patientGender == .male ? "his" : patientGender == .female ? "her" : "their"

        let mentalStates = ["unsettled", "often unsettled", "unsettled at times", "stable", "showing some improvement", "showing significant improvement", "symptom free with no concerns"]
        let insights = ["remains limited", "mostly absent but showing some signs", "mild", "moderate", "good", "full"]
        let engagements = ["nil", "some", "partial", "good", "very good", "full"]
        let leaveTypes = ["no leave", "escorted", "unescorted", "overnight"]
        let usages = ["intermittent", "variable", "regular", "frequent", "excellent"]
        let concerns = ["no", "mild", "some", "several", "significant"]
        let discharges = ["not started", "in early stages", "in progress", "almost completed", "completed"]

        var parts: [String] = []
        parts.append("Over the last 12 months, mental state has been \(mentalStates[min(mentalStateLevel, mentalStates.count - 1)]).")
        parts.append("\(pro) \(has) displayed \(insights[min(insightLevel, insights.count - 1)]) insight into \(pos) needs and \(pos) illness.")

        let engagement = engagements[min(engagementLevel, engagements.count - 1)]
        var engagementText = "\(pro.capitalized) engagement with treatment has been \(engagement) overall"

        let leave = leaveTypes[min(leaveTypeLevel, leaveTypes.count - 1)]
        if leave == "no leave" {
            engagementText += " and \(pro.lowercased()) \(has) not been taking any leave."
        } else {
            let usage = usages[min(leaveUsageLevel, usages.count - 1)]
            let concern = concerns[min(leaveConcernsLevel, concerns.count - 1)]
            engagementText += " and \(pro.lowercased()) \(has) been taking \(leave) leave on a \(usage) basis"
            if concern == "no" {
                engagementText += " without concerns."
            } else {
                engagementText += " with \(concern) concerns."
            }
        }
        parts.append(engagementText)

        let discharge = discharges[min(dischargePlanningLevel, discharges.count - 1)]
        parts.append("Currently discharge planning is \(discharge).")

        if hasDischargeApplication {
            parts.append("During this period applications have been made for discharge.")
        } else {
            parts.append("During this period no applications have been made for discharge.")
        }

        let baseText = parts.joined(separator: " ")
        return appendImportedNotes(progressImportedEntries, to: baseText)
    }
}

enum SecurityLevel: String, Codable, CaseIterable, Identifiable {
    case high = "High Secure"
    case medium = "Medium Secure"
    case low = "Low Secure"
    case open = "Open Rehabilitation"

    var id: String { rawValue }
}

enum ASRRecommendation: String, Codable, CaseIterable, Identifiable {
    case continuedDetention = "Continued detention"
    case conditionalDischarge = "Conditional discharge"
    case absoluteDischarge = "Absolute discharge"
    case transferToLowerSecurity = "Transfer to lower security"
    case transferToHigherSecurity = "Transfer to higher security"

    var id: String { rawValue }
}

// MARK: - HCR-20 V3 Risk Assessment Form
// Historical-Clinical-Risk Management 20 Violence Risk Assessment
// 20 items: H1-H10 (Historical), C1-C5 (Clinical), R1-R5 (Risk Management)

/// Presence Rating for HCR-20 items
enum HCR20PresenceRating: String, Codable, CaseIterable, Identifiable {
    case absent = "N"       // No / Absent
    case possible = "P"     // Partially Present / Possible
    case present = "Y"      // Yes / Definitely Present
    case omit = "Omit"      // No reliable information

    var id: String { rawValue }

    var displayText: String {
        switch self {
        case .absent: return "No"
        case .possible: return "Partial"
        case .present: return "Yes"
        case .omit: return "Omit"
        }
    }
}

/// Relevance Rating for HCR-20 items
enum HCR20RelevanceRating: String, Codable, CaseIterable, Identifiable {
    case low = "Low"
    case moderate = "Moderate"
    case high = "High"

    var id: String { rawValue }
}

/// Data structure for each HCR-20 item
struct HCR20ItemData: Codable, Equatable {
    var presence: HCR20PresenceRating = .absent
    var relevance: HCR20RelevanceRating = .low
    var text: String = ""
    var importedEntries: [ASRImportedEntry] = []

    // Subsection text entries (key = subsection label, value = documented text)
    var subsectionTexts: [String: String] = [:]

    // Subsection checkboxes (key = subsection label, value = checked state)
    var subsectionChecks: [String: Bool] = [:]
}

// MARK: - HCR-20 Form Data
struct HCR20FormData: StatutoryForm, Codable, Equatable {
    let id: UUID
    let formType: FormType = .hcr20
    var patientInfo: PatientInfo
    var clinicianInfo: ClinicianInfo
    let createdAt: Date
    var modifiedAt: Date

    // ============================================================
    // Patient Details
    // ============================================================
    var patientName: String = ""
    var patientDOB: Date?
    var patientGender: Gender = .male
    var hospitalNumber: String = ""
    var nhsNumber: String = ""
    var hospitalName: String = ""
    var wardName: String = ""
    var mhaSection: String = ""
    var admissionDate: Date?

    // ============================================================
    // Assessment Details
    // ============================================================
    var assessorName: String = ""
    var assessorRole: String = ""
    var assessorQualifications: String = ""
    var supervisorName: String = ""
    var assessmentDate: Date = Date()
    var assessmentPurpose: String = ""

    // ============================================================
    // Sources of Information
    // ============================================================
    var sourcesOfInformation: String = ""
    var sourcesClinicalNotes: Bool = false
    var sourcesRiskAssessments: Bool = false
    var sourcesForensicHistory: Bool = false
    var sourcesPsychologyReports: Bool = false
    var sourcesMDTDiscussion: Bool = false
    var sourcesPatientInterview: Bool = false
    var sourcesCollateralInfo: Bool = false
    var sourcesOther: String = ""

    // ============================================================
    // HISTORICAL ITEMS (H1-H10) - All notes searched
    // ============================================================
    var h1: HCR20ItemData = HCR20ItemData()  // History of Problems with Violence
    var h2: HCR20ItemData = HCR20ItemData()  // History of Problems with Other Antisocial Behaviour
    var h3: HCR20ItemData = HCR20ItemData()  // History of Problems with Relationships
    var h4: HCR20ItemData = HCR20ItemData()  // History of Problems with Employment
    var h5: HCR20ItemData = HCR20ItemData()  // History of Problems with Substance Use
    var h6: HCR20ItemData = HCR20ItemData()  // History of Problems with Major Mental Disorder
    var h7: HCR20ItemData = HCR20ItemData()  // History of Problems with Personality Disorder
    var h8: HCR20ItemData = HCR20ItemData()  // History of Problems with Traumatic Experiences
    var h9: HCR20ItemData = HCR20ItemData()  // History of Problems with Violent Attitudes
    var h10: HCR20ItemData = HCR20ItemData() // History of Problems with Treatment/Supervision Response

    // ============================================================
    // H7 PERSONALITY DISORDER CHECKBOXES - Matching desktop exactly
    // ============================================================
    // Selected PD type
    var h7SelectedPDType: String = ""  // "Dissocial", "EUPD-B", "EUPD-I", "Paranoid", "Schizoid", "Histrionic", "Anankastic", "Anxious", "Dependent"

    // Dissocial PD (F60.2) traits
    var h7DissocialUnconcern: Bool = false
    var h7DissocialIrresponsibility: Bool = false
    var h7DissocialIncapacityRelations: Bool = false
    var h7DissocialLowFrustration: Bool = false
    var h7DissocialAggression: Bool = false
    var h7DissocialIncapacityGuilt: Bool = false
    var h7DissocialBlameOthers: Bool = false
    var h7DissocialRationalise: Bool = false

    // EUPD Borderline (F60.31) traits
    var h7EupdBAbandonment: Bool = false
    var h7EupdBUnstableRelations: Bool = false
    var h7EupdBIdentity: Bool = false
    var h7EupdBImpulsivity: Bool = false
    var h7EupdBSuicidal: Bool = false
    var h7EupdBAffective: Bool = false
    var h7EupdBEmptiness: Bool = false
    var h7EupdBAnger: Bool = false
    var h7EupdBDissociation: Bool = false

    // EUPD Impulsive (F60.30) traits
    var h7EupdIActUnexpectedly: Bool = false
    var h7EupdIQuarrelsome: Bool = false
    var h7EupdIAngerOutbursts: Bool = false
    var h7EupdINoPersistence: Bool = false
    var h7EupdIUnstableMood: Bool = false

    // Paranoid PD (F60.0) traits
    var h7ParanoidSuspects: Bool = false
    var h7ParanoidDoubtsLoyalty: Bool = false
    var h7ParanoidReluctantConfide: Bool = false
    var h7ParanoidReadsThreats: Bool = false
    var h7ParanoidBearsGrudges: Bool = false
    var h7ParanoidPerceivesAttacks: Bool = false
    var h7ParanoidSuspiciousFidelity: Bool = false

    // Schizoid PD (F60.1) traits
    var h7SchizoidNoPleasure: Bool = false
    var h7SchizoidCold: Bool = false
    var h7SchizoidLimitedWarmth: Bool = false
    var h7SchizoidIndifferent: Bool = false
    var h7SchizoidLittleInterestSex: Bool = false
    var h7SchizoidSolitary: Bool = false
    var h7SchizoidFantasy: Bool = false
    var h7SchizoidNoConfidants: Bool = false
    var h7SchizoidInsensitive: Bool = false

    // Histrionic PD (F60.4) traits
    var h7HistrionicAttention: Bool = false
    var h7HistrionicSeductive: Bool = false
    var h7HistrionicShallowEmotion: Bool = false
    var h7HistrionicAppearance: Bool = false
    var h7HistrionicImpressionistic: Bool = false
    var h7HistrionicDramatic: Bool = false
    var h7HistrionicSuggestible: Bool = false
    var h7HistrionicIntimacy: Bool = false

    // Anankastic PD (F60.5) traits
    var h7AnankasticDoubt: Bool = false
    var h7AnankasticDetail: Bool = false
    var h7AnankasticPerfectionism: Bool = false
    var h7AnankasticConscientious: Bool = false
    var h7AnankasticPleasure: Bool = false
    var h7AnankasticPedantic: Bool = false
    var h7AnankasticRigid: Bool = false
    var h7AnankasticInsistence: Bool = false

    // Anxious PD (F60.6) traits
    var h7AnxiousTension: Bool = false
    var h7AnxiousInferior: Bool = false
    var h7AnxiousCriticism: Bool = false
    var h7AnxiousUnwilling: Bool = false
    var h7AnxiousRestricted: Bool = false
    var h7AnxiousAvoidsActivities: Bool = false

    // Dependent PD (F60.7) traits
    var h7DependentEncourage: Bool = false
    var h7DependentSubordinates: Bool = false
    var h7DependentUnwillingDemands: Bool = false
    var h7DependentHelpless: Bool = false
    var h7DependentAbandonment: Bool = false
    var h7DependentLimitedCapacity: Bool = false

    // H7 Impact on Functioning checkboxes
    var h7ImpactIntimate: Bool = false
    var h7ImpactFamily: Bool = false
    var h7ImpactSocial: Bool = false
    var h7ImpactProfessional: Bool = false
    var h7ImpactJobLoss: Bool = false
    var h7ImpactWorkConflict: Bool = false
    var h7ImpactUnderachievement: Bool = false
    var h7ImpactPoorEngagement: Bool = false
    var h7ImpactStaffConflict: Bool = false
    var h7ImpactNonCompliance: Bool = false
    var h7ImpactManipulation: Bool = false
    var h7ImpactAggressionPattern: Bool = false
    var h7ImpactInstrumental: Bool = false
    var h7ImpactReactive: Bool = false
    var h7ImpactVictimTargeting: Bool = false

    // ============================================================
    // H8 TRAUMATIC EXPERIENCES CHECKBOXES - Matching desktop exactly
    // ============================================================
    // Childhood - Abuse
    var h8PhysicalAbuse: Bool = false
    var h8SexualAbuseChild: Bool = false
    var h8EmotionalAbuse: Bool = false
    var h8WitnessedDV: Bool = false
    // Childhood - Neglect & Deprivation
    var h8EmotionalNeglect: Bool = false
    var h8PhysicalNeglect: Bool = false
    var h8InconsistentCare: Bool = false
    var h8InstitutionalCare: Bool = false
    var h8ParentalAbandonment: Bool = false
    // Childhood - Adverse Upbringing
    var h8ChaoticHousehold: Bool = false
    var h8ParentalSubstance: Bool = false
    var h8ParentalMentalIllness: Bool = false
    var h8CriminalCaregivers: Bool = false
    var h8PlacementBreakdowns: Bool = false

    // Adult Trauma - Victimisation
    var h8AdultAssault: Bool = false
    var h8SexualAssaultAdult: Bool = false
    var h8RobberyViolence: Bool = false
    var h8StalkingCoercion: Bool = false
    // Adult Trauma - Institutional/Systemic
    var h8PrisonViolence: Bool = false
    var h8SegregationIsolation: Bool = false
    var h8HospitalVictimisation: Bool = false
    var h8BullyingHarassment: Bool = false
    // Adult Trauma - Occupational
    var h8OccupationalViolence: Bool = false
    var h8WitnessedDeath: Bool = false
    var h8ThreatsToLife: Bool = false

    // Loss & Catastrophe
    var h8ViolentDeath: Bool = false
    var h8MultipleBereavements: Bool = false
    var h8WarDisplacement: Bool = false
    var h8ForcedMigration: Bool = false
    var h8SeriousAccidents: Bool = false
    var h8Disasters: Bool = false

    // Psychological Sequelae - Diagnoses/Symptoms
    var h8PtsdCptsd: Bool = false
    var h8Dissociation: Bool = false
    var h8Hypervigilance: Bool = false
    var h8EmotionalDysregulation: Bool = false
    var h8NightmaresFlashbacks: Bool = false
    var h8PersistentAnger: Bool = false
    // Psychological Sequelae - Behavioural Patterns
    var h8TriggeredAggression: Bool = false
    var h8PoorImpulseControl: Bool = false
    var h8SubstanceCoping: Bool = false
    var h8InterpersonalMistrust: Bool = false
    var h8ThreatReactivity: Bool = false

    // Trauma Narratives
    var h8EveryoneHurts: Bool = false
    var h8FightSurvive: Bool = false
    var h8CantTrust: Bool = false
    var h8SystemAbuse: Bool = false
    var h8GrievanceIdentity: Bool = false

    // ============================================================
    // H9 VIOLENT ATTITUDES CHECKBOXES - Matching desktop exactly
    // ============================================================
    // Violent Attitudes - Justification/Endorsement
    var h9JustifiesViolence: Bool = false
    var h9VictimDeserved: Bool = false
    var h9NoChoice: Bool = false
    var h9ViolenceSolves: Bool = false
    // Violent Attitudes - Minimisation/Denial
    var h9MinimisesHarm: Bool = false
    var h9DownplaysSeverity: Bool = false
    var h9DeniesIntent: Bool = false
    // Violent Attitudes - Externalisation/Blame
    var h9BlamesVictim: Bool = false
    var h9BlamesOthers: Bool = false
    var h9ExternalLocus: Bool = false
    // Violent Attitudes - Grievance/Entitlement
    var h9FeelsPersecuted: Bool = false
    var h9EntitledRespect: Bool = false
    var h9HoldsGrudges: Bool = false
    // Violent Attitudes - Lack of Remorse/Empathy
    var h9NoRemorse: Bool = false
    var h9IndifferentHarm: Bool = false
    var h9DismissesImpact: Bool = false

    // Antisocial Attitudes - Criminal Thinking
    var h9RulesDontApply: Bool = false
    var h9EntitledTake: Bool = false
    var h9ExploitsOthers: Bool = false
    // Antisocial Attitudes - Authority Hostility
    var h9HostileAuthority: Bool = false
    var h9SystemCorrupt: Bool = false
    var h9StaffDeserve: Bool = false
    // Antisocial Attitudes - Callousness
    var h9LacksEmpathy: Bool = false
    var h9IndifferentConsequences: Bool = false
    var h9UsesOthers: Bool = false
    // Antisocial Attitudes - Treatment Resistance
    var h9RejectsHelp: Bool = false
    var h9SuperficialCompliance: Bool = false
    var h9UnchangedBeliefs: Bool = false

    // ============================================================
    // H10 TREATMENT RESPONSE CHECKBOXES - Matching desktop exactly
    // ============================================================
    // Medication Non-Adherence
    var h10MedNoncompliant: Bool = false
    var h10MedPoorAdherence: Bool = false
    var h10MedFrequentRefusal: Bool = false
    var h10MedStoppedWithout: Bool = false
    var h10MedIntermittent: Bool = false
    var h10MedRefusedDepot: Bool = false
    var h10MedSelfDiscontinued: Bool = false
    var h10MedRepeatedStopping: Bool = false

    // Disengagement From Services
    var h10DisDna: Bool = false
    var h10DisDisengaged: Bool = false
    var h10DisLostFollowup: Bool = false
    var h10DisPoorEngagement: Bool = false
    var h10DisMinimalMdt: Bool = false
    var h10DisRefusesCommunity: Bool = false
    var h10DisUncontactable: Bool = false

    // Resistance/Hostility Toward Treatment
    var h10HosRefusesEngage: Bool = false
    var h10HosHostileStaff: Bool = false
    var h10HosDismissive: Bool = false
    var h10HosNoInsight: Bool = false
    var h10HosNotNecessary: Bool = false
    var h10HosRejectsPsych: Bool = false
    var h10HosUncooperative: Bool = false
    var h10HosOppositional: Bool = false

    // Failure Under Supervision
    var h10FailBreachConditions: Bool = false
    var h10FailBreachCto: Bool = false
    var h10FailBreachProbation: Bool = false
    var h10FailRecall: Bool = false
    var h10FailReturnedCustody: Bool = false
    var h10FailLicenceBreach: Bool = false
    var h10FailCommunityPlacement: Bool = false
    var h10FailAbsconded: Bool = false
    var h10FailRepeatedRecalls: Bool = false

    // Ineffective Past Interventions
    var h10InefLittleBenefit: Bool = false
    var h10InefLimitedResponse: Bool = false
    var h10InefNoSustained: Bool = false
    var h10InefGainsNotMaintained: Bool = false
    var h10InefRelapseDischarge: Bool = false
    var h10InefRiskEscalated: Bool = false
    var h10InefRepeatedAdmissions: Bool = false

    // Only Complies Under Compulsion
    var h10CompOnlyUnderSection: Bool = false
    var h10CompEngagesDetained: Bool = false
    var h10CompDeterioratesCommunity: Bool = false
    var h10CompLegalFramework: Bool = false
    var h10CompEnforcedOnly: Bool = false

    // ============================================================
    // CLINICAL ITEMS (C1-C5) - Last 6 months only
    // ============================================================
    var c1: HCR20ItemData = HCR20ItemData()  // Recent Problems with Insight
    var c2: HCR20ItemData = HCR20ItemData()  // Recent Problems with Violent Ideation or Intent
    var c3: HCR20ItemData = HCR20ItemData()  // Recent Problems with Symptoms of Major Mental Disorder
    var c4: HCR20ItemData = HCR20ItemData()  // Recent Problems with Instability
    var c5: HCR20ItemData = HCR20ItemData()  // Recent Problems with Treatment/Supervision Response

    // ============================================================
    // C1 INSIGHT CHECKBOXES - Matching desktop exactly
    // ============================================================
    // Insight into Disorder
    var c1DisDeniesIllness: Bool = false
    var c1DisRejectsDiagnosis: Bool = false
    var c1DisExternalAttribution: Bool = false
    var c1DisPoorInsight: Bool = false
    var c1DisNoRecogniseRelapse: Bool = false
    var c1DisAcceptsDiagnosis: Bool = false  // protective
    var c1DisRecognisesSymptoms: Bool = false  // protective

    // Insight into Illness-Risk Link
    var c1LinkDeniesConnection: Bool = false
    var c1LinkMinimisesViolence: Bool = false
    var c1LinkExternalisesBlame: Bool = false
    var c1LinkLacksVictimEmpathy: Bool = false
    var c1LinkNoReflection: Bool = false
    var c1LinkUnderstandsTriggers: Bool = false  // protective
    var c1LinkAcknowledgesUnwell: Bool = false  // protective

    // Insight into Treatment Need
    var c1TxRefusesTreatment: Bool = false
    var c1TxNonConcordant: Bool = false
    var c1TxLacksUnderstanding: Bool = false
    var c1TxOnlyUnderCompulsion: Bool = false
    var c1TxRecurrentDisengagement: Bool = false
    var c1TxAcceptsMedication: Bool = false  // protective
    var c1TxEngagesMDT: Bool = false  // protective
    var c1TxRequestsHelp: Bool = false  // protective

    // Stability/Fluctuation of Insight
    var c1StabFluctuates: Bool = false
    var c1StabImprovesMeds: Bool = false
    var c1StabPoorWhenUnwell: Bool = false
    var c1StabOnlyWhenWell: Bool = false
    var c1StabLostRelapse: Bool = false

    // Behavioural Indicators
    var c1BehStopsMeds: Bool = false
    var c1BehMissesAppts: Bool = false
    var c1BehRejectsFollowup: Bool = false
    var c1BehBlamesServices: Bool = false
    var c1BehRecurrentRelapse: Bool = false
    var c1BehConsistentEngagement: Bool = false  // protective

    // ============================================================
    // C2 VIOLENT IDEATION CHECKBOXES - Matching desktop exactly
    // ============================================================
    // Explicit Violent Ideation
    var c2ExpThoughtsHarm: Bool = false
    var c2ExpViolentThoughts: Bool = false
    var c2ExpHomicidalIdeation: Bool = false
    var c2ExpDesireAssault: Bool = false
    var c2ExpKillFantasies: Bool = false
    var c2ExpSpecificTarget: Bool = false

    // Conditional Violence
    var c2CondIfProvoked: Bool = false
    var c2CondSelfDefence: Bool = false
    var c2CondSnap: Bool = false
    var c2CondSomeoneHurt: Bool = false
    var c2CondDontKnow: Bool = false

    // Justification/Endorsement
    var c2JustDeservedIt: Bool = false
    var c2JustProvoked: Bool = false
    var c2JustNoChoice: Bool = false
    var c2JustAnyoneSame: Bool = false
    var c2JustNecessary: Bool = false

    // Ideation Linked to Mental State
    var c2SymCommandHallucinations: Bool = false
    var c2SymVoicesHarm: Bool = false
    var c2SymParanoidRetaliation: Bool = false
    var c2SymPsychoticViolent: Bool = false
    var c2SymPersecutoryBeliefs: Bool = false

    // Aggressive Rumination
    var c2RumPersistentAnger: Bool = false
    var c2RumGrievance: Bool = false
    var c2RumGrudges: Bool = false
    var c2RumBrooding: Bool = false
    var c2RumRevenge: Bool = false
    var c2RumEscalating: Bool = false

    // Threats
    var c2ThrVerbalThreats: Bool = false
    var c2ThrThreatenedStaff: Bool = false
    var c2ThrThreatenedFamily: Bool = false
    var c2ThrIntimidating: Bool = false
    var c2ThrAggressiveStatements: Bool = false
    var c2ThrNoFollowThrough: Bool = false

    // ============================================================
    // C3 SYMPTOMS CHECKBOXES - Matching desktop exactly
    // ============================================================
    // Psychotic Symptoms
    var c3PsyParanoid: Bool = false
    var c3PsyPersecutory: Bool = false
    var c3PsyCommandHallucinations: Bool = false
    var c3PsyHearingVoices: Bool = false
    var c3PsyGrandiose: Bool = false
    var c3PsyThoughtDisorder: Bool = false
    var c3PsyActivelyPsychotic: Bool = false

    // Mania/Hypomania
    var c3ManManic: Bool = false
    var c3ManHypomanic: Bool = false
    var c3ManElevatedMood: Bool = false
    var c3ManGrandiosity: Bool = false
    var c3ManDisinhibited: Bool = false
    var c3ManReducedSleep: Bool = false

    // Severe Depression
    var c3DepSevere: Bool = false
    var c3DepAgitated: Bool = false
    var c3DepHopelessness: Bool = false
    var c3DepNihilistic: Bool = false
    var c3DepParanoid: Bool = false

    // Affective Instability
    var c3AffLabile: Bool = false
    var c3AffEasilyProvoked: Bool = false
    var c3AffLowFrustration: Bool = false
    var c3AffExplosive: Bool = false
    var c3AffRapidShifts: Bool = false

    // Arousal/Anxiety States
    var c3ArsHypervigilant: Bool = false
    var c3ArsOnEdge: Bool = false
    var c3ArsThreatPerception: Bool = false
    var c3ArsPtsdExacerbated: Bool = false

    // Symptoms Linked to Violence Risk
    var c3LnkSymptomsPrecedeViolence: Bool = false
    var c3LnkDelisionsTargeting: Bool = false
    var c3LnkManiaDriveAggression: Bool = false
    var c3LnkDepressionAnger: Bool = false
    var c3LnkActiveSymptoms: Bool = false

    // ============================================================
    // C4 INSTABILITY CHECKBOXES - Matching desktop exactly
    // ============================================================
    // Affective Instability
    var c4AffMoodSwings: Bool = false
    var c4AffVolatile: Bool = false
    var c4AffLabile: Bool = false
    var c4AffIrritable: Bool = false
    var c4AffEasilyAngered: Bool = false
    var c4AffEmotionalDysreg: Bool = false

    // Behavioural Impulsivity
    var c4ImpActsWithoutThinking: Bool = false
    var c4ImpPoorImpulseControl: Bool = false
    var c4ImpUnpredictable: Bool = false
    var c4ImpErratic: Bool = false
    var c4ImpReckless: Bool = false

    // Anger Dyscontrol
    var c4AngExplosive: Bool = false
    var c4AngAngryOutburst: Bool = false
    var c4AngDifficultyTemper: Bool = false
    var c4AngAgitated: Bool = false
    var c4AngHostile: Bool = false

    // Environmental/Life Instability
    var c4EnvRelationshipBreakdown: Bool = false
    var c4EnvHousingInstability: Bool = false
    var c4EnvJobLoss: Bool = false
    var c4EnvFinancialCrisis: Bool = false
    var c4EnvRecentMove: Bool = false

    // Stability Indicators (Protective)
    var c4StabGoodEmotionalReg: Bool = false
    var c4StabStableMood: Bool = false
    var c4StabSettledLifestyle: Bool = false
    var c4StabConsistentRoutine: Bool = false

    // ============================================================
    // C5 TREATMENT RESPONSE CHECKBOXES - Matching desktop exactly
    // ============================================================
    // Medication Adherence
    var c5MedNonCompliant: Bool = false
    var c5MedStopsDischarge: Bool = false
    var c5MedRefuses: Bool = false
    var c5MedSelective: Bool = false
    var c5MedCovertNonCompliance: Bool = false
    var c5MedAccepts: Bool = false  // protective
    var c5MedConsistent: Bool = false  // protective

    // Engagement with Services
    var c5EngDisengaged: Bool = false
    var c5EngMissesAppts: Bool = false
    var c5EngPoorAttendance: Bool = false
    var c5EngAvoidsReviews: Bool = false
    var c5EngActivelyEngages: Bool = false  // protective

    // Compliance with Conditions
    var c5CmpBreaches: Bool = false
    var c5CmpAbsconded: Bool = false
    var c5CmpRecalled: Bool = false
    var c5CmpOnlyCoerced: Bool = false
    var c5CmpResistsMonitoring: Bool = false
    var c5CmpAcceptsConditions: Bool = false  // protective

    // Pattern Over Time
    var c5PatRepeatedDisengage: Bool = false
    var c5PatHistoryNonCompliance: Bool = false
    var c5PatCycleRelapse: Bool = false
    var c5PatSustainedAdherence: Bool = false  // protective

    // Treatment Responsiveness
    var c5RspTreatmentResistant: Bool = false
    var c5RspNoImprovement: Bool = false
    var c5RspRespondsWell: Bool = false  // protective
    var c5RspBenefitsTherapy: Bool = false  // protective

    // ============================================================
    // RISK MANAGEMENT ITEMS (R1-R5) - Future-oriented
    // ============================================================
    var r1: HCR20ItemData = HCR20ItemData()  // Future Problems with Professional Services and Plans
    var r2: HCR20ItemData = HCR20ItemData()  // Future Problems with Living Situation
    var r3: HCR20ItemData = HCR20ItemData()  // Future Problems with Personal Support
    var r4: HCR20ItemData = HCR20ItemData()  // Future Problems with Treatment/Supervision Response
    var r5: HCR20ItemData = HCR20ItemData()  // Future Problems with Stress or Coping

    // R1-R5 have Hospital vs Community subsections
    var r1Hospital: String = ""
    var r1Community: String = ""
    var r2Hospital: String = ""
    var r2Community: String = ""
    var r3Hospital: String = ""
    var r3Community: String = ""
    var r4Hospital: String = ""
    var r4Community: String = ""
    var r5Hospital: String = ""
    var r5Community: String = ""

    // ============================================================
    // R1 PROFESSIONAL SERVICES CHECKBOXES - Matching desktop exactly
    // ============================================================
    // Plan Quality
    var r1PlnClearPlan: Bool = false
    var r1PlnRiskPlan: Bool = false
    var r1PlnNoPlan: Bool = false
    var r1PlnIncomplete: Bool = false
    var r1PlnGeneric: Bool = false

    // Service Intensity & Adequacy
    var r1SvcAppropriate: Bool = false
    var r1SvcInsufficient: Bool = false
    var r1SvcLimited: Bool = false
    var r1SvcMismatch: Bool = false

    // Transitions & Continuity
    var r1TrnAwaiting: Bool = false
    var r1TrnWaitingList: Bool = false
    var r1TrnNoFollowup: Bool = false
    var r1TrnGap: Bool = false
    var r1TrnTimely: Bool = false  // protective

    // Contingency Planning
    var r1CntCrisisPlan: Bool = false
    var r1CntWarningSigns: Bool = false
    var r1CntEscalation: Bool = false
    var r1CntNoCrisis: Bool = false
    var r1CntNoEscalation: Bool = false

    // ============================================================
    // R2 LIVING SITUATION CHECKBOXES - Matching desktop exactly
    // ============================================================
    // Accommodation Stability
    var r2AccomUnstable: Bool = false
    var r2AccomTemporary: Bool = false
    var r2AccomEvictionRisk: Bool = false
    var r2AccomStable: Bool = false  // protective

    // Who They Live With
    var r2CohabVictim: Bool = false
    var r2CohabConflict: Bool = false
    var r2CohabSubstancePeers: Bool = false
    var r2CohabSupportive: Bool = false  // protective

    // Supervision Level
    var r2SuperSupported: Bool = false
    var r2SuperUnsupervised: Bool = false
    var r2SuperStepDown: Bool = false
    var r2SuperDeteriorates: Bool = false

    // Substance Access
    var r2SubstAccess: Bool = false
    var r2SubstPeers: Bool = false
    var r2SubstFree: Bool = false  // protective

    // ============================================================
    // R3 PERSONAL SUPPORT CHECKBOXES - Matching desktop exactly
    // ============================================================
    // Supportive Relationships
    var r3SupFamily: Bool = false
    var r3SupPartner: Bool = false
    var r3SupRegularContact: Bool = false
    var r3SupCrisisHelp: Bool = false

    // Isolation/Weak Support
    var r3IsoLimited: Bool = false
    var r3IsoEstranged: Bool = false
    var r3IsoLivesAlone: Bool = false
    var r3IsoSuperficial: Bool = false

    // Conflict Within Network
    var r3ConInterpersonal: Bool = false
    var r3ConVolatile: Bool = false
    var r3ConDomestic: Bool = false

    // Antisocial Peers
    var r3PeerAntisocial: Bool = false
    var r3PeerSubstance: Bool = false
    var r3PeerNegative: Bool = false

    // ============================================================
    // R4 TREATMENT/SUPERVISION COMPLIANCE CHECKBOXES - Matching desktop exactly
    // ============================================================
    // Medication Adherence (future-oriented)
    var r4MedLikelyStop: Bool = false
    var r4MedLikelyRefuse: Bool = false
    var r4MedHistoryNoncompliance: Bool = false
    var r4MedLikelyComply: Bool = false  // protective

    // Attendance/Engagement (future-oriented)
    var r4AttLikelyMiss: Bool = false
    var r4AttLikelyDisengage: Bool = false
    var r4AttHistoryDna: Bool = false
    var r4AttLikelyEngage: Bool = false  // protective

    // Supervision Compliance (future-oriented)
    var r4SupLikelyBreach: Bool = false
    var r4SupHistoryBreach: Bool = false
    var r4SupOnlyCoerced: Bool = false
    var r4SupLikelyAccept: Bool = false  // protective

    // Response to Enforcement
    var r4EnfHostile: Bool = false
    var r4EnfResists: Bool = false
    var r4EnfEscalates: Bool = false
    var r4EnfAccepts: Bool = false  // protective

    // ============================================================
    // R5 STRESS OR COPING CHECKBOXES - Matching desktop exactly
    // ============================================================
    // Anticipated Stressors
    var r5StrDischarge: Bool = false
    var r5StrHousing: Bool = false
    var r5StrRelationship: Bool = false
    var r5StrFinancial: Bool = false
    var r5StrReducedSupport: Bool = false

    // Historical Pattern Under Stress
    var r5PatDeteriorates: Bool = false
    var r5PatStrugglesTransitions: Bool = false
    var r5PatStressIncidents: Bool = false

    // Coping Capacity
    var r5CopLimited: Bool = false
    var r5CopRequiresContainment: Bool = false
    var r5CopMaladaptive: Bool = false
    var r5CopEffective: Bool = false  // protective

    // Substance Use as Coping
    var r5SubLikely: Bool = false
    var r5SubRelapseRisk: Bool = false
    var r5SubHistory: Bool = false

    // Protective Factors
    var r5ProtCopingDemonstrated: Bool = false
    var r5ProtHelpSeeking: Bool = false
    var r5ProtCrisisPlan: Bool = false
    var r5ProtStableSupports: Bool = false

    // ============================================================
    // Formulation
    // ============================================================
    var formulationText: String = ""

    // ============================================================
    // Scenario Planning - With checkboxes matching desktop
    // ============================================================

    // Scenario 1: Nature of Risk
    var scenarioNature: String = ""          // Nature of future violence (generated text)
    // Harm Type checkboxes
    var harmPhysicalGeneral: Bool = false
    var harmPhysicalTargeted: Bool = false
    var harmDomestic: Bool = false
    var harmThreatening: Bool = false
    var harmWeapon: Bool = false
    var harmSexual: Bool = false
    var harmArson: Bool = false
    var harmInstitutional: Bool = false
    var harmStalking: Bool = false
    // Potential Victims checkboxes
    var victimKnown: Bool = false
    var victimStrangers: Bool = false
    var victimStaff: Bool = false
    var victimPatients: Bool = false
    var victimAuthority: Bool = false
    var victimChildren: Bool = false
    // Motivation checkboxes
    var motivImpulsive: Bool = false
    var motivInstrumental: Bool = false
    var motivParanoid: Bool = false
    var motivCommand: Bool = false
    var motivGrievance: Bool = false
    var motivTerritorial: Bool = false
    var motivSubstance: Bool = false

    // Scenario 2: Severity
    var scenarioSeverity: String = ""        // Severity of future violence
    var severityLevel: String = ""           // "low", "moderate", "high"
    // Severity factor checkboxes - matching desktop exactly
    var sevHistSerious: Bool = false         // History of assaults involving significant force
    var sevLimitedInhibition: Bool = false   // Limited inhibition when unwell
    var sevWeaponHistory: Bool = false       // Previous weapon use
    var sevVulnerableVictims: Bool = false   // Risk to vulnerable victims
    var sevEscalationPattern: Bool = false   // Pattern of escalation in violence
    var sevLackRemorse: Bool = false         // Lack of remorse following violence

    // Scenario 3: Imminence
    var scenarioImminence: String = ""       // Imminence/Timing
    var imminenceLevel: String = ""          // "imminent", "weeks", "months", "longterm"
    // Trigger status checkboxes
    var trigPresent: Bool = false            // Triggers already present
    var trigEmerging: Bool = false           // Triggers emerging / building
    var trigAbsent: Bool = false             // No current triggers identified
    // Pending transitions checkboxes
    var transDischarge: Bool = false         // Discharge pending
    var transLeave: Bool = false             // Leave / unescorted access pending
    var transReducedSupervision: Bool = false // Supervision reduction pending
    var transAccommodation: Bool = false     // Accommodation change pending
    var transRelationship: Bool = false      // Relationship change anticipated
    var transLegal: Bool = false             // Legal proceedings pending
    // Protective factor changes checkboxes
    var protReducing: Bool = false           // Protective factors about to reduce
    var protStable: Bool = false             // Protective factors stable
    var protIncreasing: Bool = false         // Protective factors increasing

    // Scenario 4: Frequency
    var scenarioFrequency: String = ""       // Frequency/Duration
    var frequencyLevel: String = ""          // "isolated", "occasional", "frequent", "chronic"
    var frequencyPattern: String = ""        // "episodic", "clustered", "persistent", "rare"
    // Context/trigger checkboxes
    var ctxStress: Bool = false              // Acute stress periods
    var ctxRelapse: Bool = false             // Mental health relapse
    var ctxSubstance: Bool = false           // Substance intoxication
    var ctxInterpersonal: Bool = false       // Interpersonal conflict
    var ctxFrustration: Bool = false         // Frustration / goal blocking
    var ctxPerceivedThreat: Bool = false     // Perceived threat or provocation

    // Scenario 5: Likelihood
    var scenarioLikelihood: String = ""      // Likelihood
    var likelihoodLevel: String = ""         // "low", "moderate", "high"
    var likelihoodBaseline: String = ""      // "low", "moderate", "high"
    // Conditions that increase likelihood checkboxes
    var condMedLapse: Bool = false           // Medication adherence lapses
    var condConflict: Bool = false           // Interpersonal conflict escalates
    var condSubstance: Bool = false          // Substance use resumes
    var condSupervisionReduces: Bool = false // Supervision reduces
    var condSymptomsReturn: Bool = false     // Symptoms of mental disorder return
    var condSupportLoss: Bool = false        // Support network weakens
    var condStressIncreases: Bool = false    // Life stressors increase

    // ============================================================
    // Management Recommendations - With checkboxes matching desktop
    // ============================================================

    // Risk-Enhancing Factors (text output)
    var managementRiskEnhancing: String = ""
    // Clinical enhancers
    var enhPoorInsight: Bool = false
    var enhViolentIdeation: Bool = false
    var enhActiveSymptoms: Bool = false
    var enhInstability: Bool = false
    var enhPoorTreatment: Bool = false
    // Situational enhancers
    var enhPoorPlan: Bool = false
    var enhUnstableLiving: Bool = false
    var enhPoorSupport: Bool = false
    var enhNonCompliance: Bool = false
    var enhPoorCoping: Bool = false
    // Other enhancers
    var enhSubstance: Bool = false
    var enhConflict: Bool = false
    var enhAccessVictims: Bool = false
    var enhTransitions: Bool = false
    var enhLossSupervision: Bool = false

    // Protective Factors (text output)
    var managementProtective: String = ""
    // Strong protectors
    var protTreatmentAdherence: Bool = false
    var protStructuredSupervision: Bool = false
    var protSupportiveRelationships: Bool = false
    var protInsightLinked: Bool = false
    var protHelpSeeking: Bool = false
    var protRestrictedAccess: Bool = false
    var protMedicationResponse: Bool = false
    // Weak/conditional protectors
    var protVerbalMotivation: Bool = false
    var protUntestedCoping: Bool = false
    var protConditionalSupport: Bool = false
    var protExternalMotivation: Bool = false
    var protSituationalStability: Bool = false

    // Monitoring Indicators (text output)
    var managementMonitoring: String = ""
    // Behavioural indicators
    var monMissedAppts: Bool = false
    var monMedRefusal: Bool = false
    var monWithdrawal: Bool = false
    var monSubstanceUse: Bool = false
    var monNonCompliance: Bool = false
    var monRuleBreaking: Bool = false
    // Mental state indicators
    var monSleepDisturb: Bool = false
    var monParanoia: Bool = false
    var monIrritability: Bool = false
    var monHostileLanguage: Bool = false
    var monFixation: Bool = false
    var monAgitation: Bool = false

    // ============================================================
    // 9. RISK MANAGEMENT STRATEGIES (Treatment) - Matching desktop
    // ============================================================
    var managementTreatment: String = ""
    // Preventative Strategies
    var mgmtMedAdherence: Bool = false       // Medication adherence
    var mgmtRegularReview: Bool = false      // Regular clinical review
    var mgmtStructuredRoutine: Bool = false  // Structured daily routine
    var mgmtStressManagement: Bool = false   // Stress management interventions
    var mgmtSubstanceControls: Bool = false  // Substance use controls / monitoring
    var mgmtTherapy: Bool = false            // Psychological therapy
    // Containment Strategies
    var mgmtSupervision: Bool = false        // Ongoing supervision
    var mgmtConditions: Bool = false         // Conditions / boundaries
    var mgmtReducedAccess: Bool = false      // Reduced access to triggers
    var mgmtSupportedAccom: Bool = false     // Supported accommodation
    var mgmtCurfew: Bool = false             // Curfew or time restrictions
    var mgmtGeographic: Bool = false         // Geographic restrictions
    // Response Strategies
    var mgmtEscalation: Bool = false         // Clear escalation pathways
    var mgmtCrisisPlan: Bool = false         // Crisis plan in place
    var mgmtRecallThreshold: Bool = false    // Defined recall / admission thresholds
    var mgmtOutOfHours: Bool = false         // Out-of-hours response plan
    var mgmtPoliceProtocol: Bool = false     // Police liaison protocol

    // ============================================================
    // 10. SUPERVISION RECOMMENDATIONS - Matching desktop
    // ============================================================
    var managementSupervision: String = ""
    var supervisionLevel: String = ""        // "informal", "supported", "conditional", "restricted"
    // Contact Requirements
    var supFaceToFace: Bool = false          // Regular face-to-face contact required
    var supMedMonitoring: Bool = false       // Medication adherence monitoring
    var supUrineScreening: Bool = false      // Urine screening for substances
    var supCurfewChecks: Bool = false        // Curfew checks
    var supUnannounced: Bool = false         // Unannounced visits
    var supPhoneCheckins: Bool = false       // Regular phone check-ins
    // Escalation Triggers
    var escEngagementDeteriorates: Bool = false  // Engagement deteriorates
    var escNonCompliance: Bool = false           // Non-compliance with conditions
    var escWarningSigns: Bool = false            // Early warning signs emerge
    var escSubstanceRelapse: Bool = false        // Substance use relapse
    var escMentalState: Bool = false             // Mental state deterioration
    var escThreats: Bool = false                 // Threats or aggressive behaviour

    // ============================================================
    // 11. VICTIM SAFETY & SAFEGUARDING - Matching desktop
    // ============================================================
    var managementVictimSafety: String = ""
    // When There Is an Identified Victim
    var vicSeparation: Bool = false          // Physical separation maintained
    var vicNoContact: Bool = false           // No-contact conditions in place
    var vicThirdParty: Bool = false          // Third-party monitoring
    var vicInfoSharing: Bool = false         // Information sharing between agencies
    var vicVictimInformed: Bool = false      // Victim informed of risk and release
    var vicExclusionZone: Bool = false       // Exclusion zone in place
    // When Victims Are Non-Specific
    var vicEnvControls: Bool = false         // Environmental controls
    var vicStaffSafety: Bool = false         // Staff safety planning
    var vicConflictAvoid: Bool = false       // Conflict avoidance strategies
    var vicDeEscalation: Bool = false        // De-escalation protocols
    var vicRestrictedAccess: Bool = false    // Restricted access to vulnerable groups
    var vicPublicProtection: Bool = false    // Public protection measures

    // ============================================================
    // Overall Risk Judgment
    // ============================================================
    var overallRiskLevel: String = ""        // Low/Moderate/High
    var overallRiskRationale: String = ""

    // ============================================================
    // Signature
    // ============================================================
    var signatureDate: Date = Date()

    // ============================================================
    // Initializer
    // ============================================================
    init(id: UUID = UUID(), patientInfo: PatientInfo = PatientInfo(), clinicianInfo: ClinicianInfo = ClinicianInfo()) {
        self.id = id
        self.patientInfo = patientInfo
        self.clinicianInfo = clinicianInfo
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.patientName = patientInfo.fullName
        self.patientDOB = patientInfo.dateOfBirth
        self.patientGender = patientInfo.gender
        self.assessorName = clinicianInfo.fullName
        self.assessorRole = clinicianInfo.roleTitle
        self.hospitalName = clinicianInfo.hospitalOrg
    }

    func validate() -> [FormValidationError] {
        var errors: [FormValidationError] = []
        if patientName.isEmpty { errors.append(FormValidationError(field: "patientName", message: "Patient name required")) }
        if assessorName.isEmpty { errors.append(FormValidationError(field: "assessorName", message: "Assessor name required")) }
        return errors
    }

    func toHTML() -> String {
        "<html><body><h1>HCR-20 V3 Risk Assessment</h1><p>Patient: \(patientName)</p></body></html>"
    }

    // MARK: - Item Title Helpers
    static let itemTitles: [String: String] = [
        "h1": "H1: History of Problems with Violence",
        "h2": "H2: History of Problems with Other Antisocial Behaviour",
        "h3": "H3: History of Problems with Relationships",
        "h4": "H4: History of Problems with Employment",
        "h5": "H5: History of Problems with Substance Use",
        "h6": "H6: History of Problems with Major Mental Disorder",
        "h7": "H7: History of Problems with Personality Disorder",
        "h8": "H8: History of Problems with Traumatic Experiences",
        "h9": "H9: History of Problems with Violent Attitudes",
        "h10": "H10: History of Problems with Treatment or Supervision Response",
        "c1": "C1: Recent Problems with Insight",
        "c2": "C2: Recent Problems with Violent Ideation or Intent",
        "c3": "C3: Recent Problems with Symptoms of Major Mental Disorder",
        "c4": "C4: Recent Problems with Instability",
        "c5": "C5: Recent Problems with Treatment or Supervision Response",
        "r1": "R1: Future Problems with Professional Services and Plans",
        "r2": "R2: Future Problems with Living Situation",
        "r3": "R3: Future Problems with Personal Support",
        "r4": "R4: Future Problems with Treatment or Supervision Response",
        "r5": "R5: Future Problems with Stress or Coping"
    ]

    // MARK: - Subsection Definitions for each item (label, placeholder) - Matches desktop exactly
    static let itemSubsections: [String: [(String, String)]] = [
        "h1": [
            ("Child (aged 12 and under):", "Document any violence or aggressive behaviour during childhood. Consider fights, bullying, cruelty to animals, destruction of property, fire setting, or other violent acts before age 13."),
            ("Adolescent (aged 13-17):", "Document violence during adolescence. Consider physical fights, assault, weapon use, threats, bullying, property destruction, or involvement with violent groups during teenage years."),
            ("Adult (aged 18+):", "Document adult violence history. Include physical assaults, domestic violence, violence toward staff/professionals, weapons use, threats, and any criminal convictions for violent offences.")
        ],
        "h2": [
            ("Child (aged 12 and under):", "Document antisocial behaviour during childhood. Consider theft, vandalism, truancy, lying, rule-breaking, running away, and other conduct problems before age 13."),
            ("Adolescent (aged 13-17):", "Document antisocial behaviour during adolescence. Include theft, fraud, drug dealing, vandalism, arson (without violence), sexual offences, and other criminal or antisocial conduct."),
            ("Adult (aged 18+):", "Document adult antisocial behaviour. Consider criminal convictions, probation/parole violations, fraud, property offences, and persistent rule-breaking or irresponsible behaviour.")
        ],
        "h3": [
            ("Intimate Relationships:", "Document history of intimate relationships. Consider stability, conflict, domestic abuse (as perpetrator or victim), separation patterns, and quality of romantic partnerships."),
            ("Non-intimate Relationships:", "Document relationships with family, friends, and colleagues. Consider social isolation, interpersonal conflict, exploitation of others, and ability to maintain supportive relationships.")
        ],
        "h4": [
            ("Education:", "Document educational history. Include academic achievement, behavioural problems at school, truancy, suspensions/expulsions, special educational needs, and highest qualification achieved."),
            ("Employment:", "Document employment history. Consider job stability, reasons for job losses, workplace conflicts, longest period of employment, and current vocational status.")
        ],
        "h5": [
            ("Substance Use History:", "Document history of alcohol and drug use. Include age of first use, substances used, patterns of use, periods of abstinence, and relationship between substance use and violent behaviour."),
            ("Treatment History:", "Document any substance misuse treatment. Include detoxification, rehabilitation programmes, AA/NA attendance, and outcomes of previous treatment attempts."),
            ("Current Status:", "Document current substance use status including recent use, current abstinence, relapse patterns, and engagement with recovery support.")
        ],
        "h6": [
            ("General:", "Document history of major mental disorder. Include age of onset, course of illness, periods of remission, and overall impact on functioning."),
            ("Psychotic Disorders:", "Document history of psychotic symptoms including schizophrenia, schizoaffective disorder, delusional disorder. Include nature of delusions/hallucinations and relationship to violence."),
            ("Major Mood Disorders:", "Document history of major depressive disorder, bipolar disorder, or other major mood disorders. Include manic episodes, depressive episodes, and relationship to risk behaviours."),
            ("Other Mental Disorders:", "Document other significant mental health conditions including anxiety disorders, PTSD, OCD, eating disorders, and their impact on risk.")
        ],
        "h7": [
            ("Personality Disorder Features:", "Document history of personality disorder or features. Include formal diagnoses, personality assessments (e.g., PCL-R), and relevant traits such as antisocial, borderline, narcissistic, or paranoid features."),
            ("Impact on Functioning:", "Document how personality difficulties have impacted relationships, employment, treatment engagement, and violent behaviour.")
        ],
        "h8": [
            ("Victimization/Trauma:", "Document history of victimization including physical abuse, sexual abuse, emotional abuse, neglect, bullying, or witnessing domestic violence. Include age at time of trauma and impact."),
            ("Adverse Childrearing Experiences:", "Document adverse childhood experiences including parental separation, parental mental illness, parental substance misuse, parental criminality, poverty, and unstable care arrangements.")
        ],
        "h9": [
            ("Violent Attitudes:", "Document attitudes supportive of violence. Consider beliefs that violence is acceptable or justified, lack of remorse for past violence, positive views about aggression, and attitudes toward specific victim groups."),
            ("Antisocial Attitudes:", "Document broader antisocial attitudes including criminal thinking patterns, disregard for rules/laws, lack of empathy, and sense of entitlement.")
        ],
        "h10": [
            ("Treatment Response:", "Document history of response to treatment. Include engagement with mental health services, medication compliance, participation in psychological interventions, and outcomes."),
            ("Supervision Response:", "Document response to supervision. Include compliance with probation/parole, hospital leave conditions, ward rules, and any breaches or failures.")
        ],
        "c1": [
            ("Insight into Mental Health:", "Does the individual recognise and accept their mental health diagnosis? Do they understand the nature and impact of their mental illness?"),
            ("Insight into Violence Risk:", "Does the individual recognise their risk factors for violence? Do they understand what triggers their violent behaviour and accept responsibility for past violence?"),
            ("Insight into Need for Treatment:", "Does the individual accept the need for treatment? Do they understand why treatment is necessary and show willingness to engage?")
        ],
        "c2": [
            ("Violent Ideation:", "Document current thoughts about violence including fantasies, plans, intentions, or preoccupations with violence. Consider frequency, intensity, and specificity of violent thoughts."),
            ("Violent Intent:", "Document any current stated or implied intent to harm others. Consider threats made, identified targets, and any planning or preparatory behaviours.")
        ],
        "c3": [
            ("Symptoms of Psychotic Disorders:", "Document current psychotic symptoms including delusions, hallucinations (especially command hallucinations), paranoid ideation, and disorganised thinking. Rate severity and relationship to violence risk."),
            ("Symptoms of Major Mood Disorder:", "Document current mood symptoms including depression, mania, mixed states, irritability, and emotional dysregulation. Rate severity and relationship to violence risk.")
        ],
        "c4": [
            ("Affective Instability:", "Document emotional instability including mood swings, irritability, anger outbursts, and difficulty regulating emotions over the past six months."),
            ("Behavioural Instability:", "Document behavioural instability including impulsive actions, risk-taking, self-harm, aggression, and difficulty maintaining consistent behaviour patterns."),
            ("Cognitive Instability:", "Document cognitive instability including concentration difficulties, confusion, disorientation, or rapidly changing beliefs and perceptions.")
        ],
        "c5": [
            ("Treatment Engagement:", "Document current engagement with treatment including attendance at appointments, participation in therapy, and relationship with treatment providers."),
            ("Medication Compliance:", "Document current medication compliance including taking medication as prescribed, attitudes toward medication, and any recent non-compliance."),
            ("Supervision Compliance:", "Document current compliance with supervision requirements including ward rules, leave conditions, and any recent breaches.")
        ],
        "r1": [
            ("Hospital:", "If remaining in hospital, what professional services and plans are in place? Consider care planning, treatment programmes, multidisciplinary input, and adequacy of current arrangements."),
            ("Community:", "If discharged to community, what professional services and plans would be needed? Consider CPA arrangements, community mental health support, and feasibility of proposed plans.")
        ],
        "r2": [
            ("Hospital:", "If remaining in hospital, what is the living situation? Consider ward environment, peer group, level of security, and any environmental risk factors."),
            ("Community:", "If discharged to community, what would the living situation be? Consider housing stability, neighbourhood, proximity to victims or antisocial peers, and access to weapons/substances.")
        ],
        "r3": [
            ("Hospital:", "If remaining in hospital, what personal support is available? Consider family contact, peer relationships on ward, and therapeutic relationships with staff."),
            ("Community:", "If discharged to community, what personal support would be available? Consider family relationships, friendships, support networks, and potential for isolation.")
        ],
        "r4": [
            ("Hospital:", "If remaining in hospital, how likely is compliance with treatment and supervision? Consider current engagement, motivation, and barriers to compliance."),
            ("Community:", "If discharged to community, how likely is compliance with treatment and supervision? Consider history of community compliance and motivation for ongoing engagement.")
        ],
        "r5": [
            ("Hospital:", "If remaining in hospital, what stressors might be encountered? Consider conflicts with peers/staff, boredom, family issues, and coping resources available."),
            ("Community:", "If discharged to community, what stressors might be encountered? Consider housing, finances, relationships, employment, and coping capacity.")
        ]
    ]
}

// MARK: - HCR-20 Category Keywords for Autodetection
/// Keywords for categorizing imported clinical notes into HCR-20 items
/// Ported from desktop hcr20_extractor.py
struct HCR20CategoryKeywords {

    // MARK: - Historical Items (H1-H10) - Search ALL notes

    // H1: History of Problems with Violence - Uses desktop terms INCLUDING subsection keywords
    static let h1: [String: [String]] = [
        "Violence": ["violence", "violent", "assault", "assaulted", "attack", "attacked", "aggression", "aggressive", "hit", "struck", "punch", "punched", "fight", "fighting", "fought", "battery", " abh ", " gbh ", "actual bodily harm", "grievous bodily harm"],
        "Threats": ["threat", "threatening", "intimidat", "physical altercation", "physical aggression", "weapon", "knife", "stabbed"],
        "Self-Harm": ["self-harm", "self harm", "suicide", "suicidal", "overdose", " od ", "cutting", "ligature", "hanging", "attempted suicide", "deliberate self-harm", " dsh ", "nonfatal", "parasuicide", "suicide attempt", "suicidal ideation"],
        "Prior Violence": ["previous violence", "history of violence", "prior assault", "past aggression", "violent offence", "violent offense", "index offence", "index offense", "conviction for violence"]
    ]

    // H2: History of Problems with Other Antisocial Behaviour - Uses desktop terms INCLUDING subsection keywords
    static let h2: [String: [String]] = [
        "Antisocial Behaviour": ["first offence", "first offense", "first violent", "age at first", "juvenile", "youth offend", "young offender", "childhood violence", "adolescent violence", "early onset", "childhood conduct", "conduct disorder", "early behaviour", "early behavior", "school exclusion", "expelled", "antisocial behaviour in childhood"],
        "Age/First Violence": ["first violent incident", "first offence age", "onset of violence", "early violence", "childhood aggression"],
        "Juvenile Offending": ["youth court", "yoi", "youth custody", "borstal", "secure unit", "care order"]
    ]

    // H3: History of Problems with Relationships - Uses desktop terms INCLUDING subsection keywords
    static let h3: [String: [String]] = [
        "Relationships": ["relationship", "partner", "marriage", "married", "divorce", "divorced", "separation", "separated", "domestic", "intimate partner", "boyfriend", "girlfriend", "spouse", "wife", "husband", "family conflict", "estranged", "custody", "children", "parenting", "domestic violence", "domestic abuse", "coercive control", "breakup", "break-up", "split", "acrimonious"],
        "Intimate Relationships": ["intimate", "romantic relationship"],
        "Non-Intimate Relationships": ["family", "friend", "colleague", "neighbour", "acquaintance", "social network", "isolation", "estranged from family"]
    ]

    // H4: History of Problems with Employment - Uses desktop terms INCLUDING subsection keywords
    static let h4: [String: [String]] = [
        "Employment": ["employment", "employed", "unemployed", "job", "work", "working", "occupation", "career", "profession", "vocational", "dismissed", "sacked", "fired", "redundant", "quit"],
        "Education": ["education", "school", "college", "university", "degree", "qualification", "training", "apprentice", "truant", "expelled", "academic", "literacy", "illiterate", "special needs", "special educational needs", "learning difficulty"]
    ]

    // H5: History of Problems with Substance Use - Uses desktop terms INCLUDING subsection keywords
    static let h5: [String: [String]] = [
        "Substances": ["cannabis", "cocaine", "heroin", "crack", "amphetamine", "methamphetamine", "benzodiazepine", "opioid", "opiate", "ecstasy", "mdma", "lsd", "ketamine", "spice", "mamba"],
        "Alcohol": ["alcohol dependence", "alcohol misuse", "alcoholic", "drunk", "intoxicated", "smelling of alcohol", "under the influence", "alcohol withdrawal"],
        "Drug Use": ["addiction", "dependence syndrome", "withdrawal", "detox", "detoxification", "rehab", "rehabilitation", " aa ", " na ", "alcoholics anonymous", "narcotics anonymous", "substance misuse", "substance dependence", "drug misuse", "drug dependence", "illicit substance", "recreational drug", "drug test", "uds positive", "positive for cannabis", "positive for cocaine", "positive for opiates", "admitted using", "admitted smoking cannabis", "found with drugs", "drug test positive", "positive for"],
        "Impact on Risk": ["intoxicated during offence", "drug-related offence", "disinhibition", "substance use and violence", "under the influence when", "admitted using before"]
    ]

    // H6: History of Problems with Major Mental Disorder - Uses ONLY desktop terms (no subsection keywords)
    static let h6: [String: [String]] = [
        "Schizophrenia Spectrum": ["schizophrenia", "paranoid schizophrenia", "hebephrenic schizophrenia", "catatonic schizophrenia", "undifferentiated schizophrenia", "residual schizophrenia", "simple schizophrenia", "schizotypal disorder", "schizoaffective disorder", "schizoaffective"],
        "Mood Disorders": ["bipolar affective disorder", "bipolar disorder", "bipolar i", "bipolar ii", "manic episode", "hypomanic episode", "major depressive disorder", "recurrent depressive disorder", "severe depression", "depressive episode", "cyclothymia", "dysthymia"],
        "Psychotic Disorders": ["persistent delusional disorder", "delusional disorder", "acute psychotic disorder", "brief psychotic disorder", "induced delusional disorder", "folie a deux", "psychotic illness", "first episode psychosis"],
        "Diagnosis": ["diagnosis of schizophrenia", "diagnosed with schizophrenia", "diagnosis of bipolar", "diagnosed with bipolar", "diagnosis of schizoaffective", "diagnosed with schizoaffective"]
    ]

    // H7: History of Problems with Personality Disorder
    static let h7: [String: [String]] = [
        "Personality Disorder": ["personality disorder", "dissocial personality", "emotionally unstable", "borderline personality", "antisocial personality", " aspd ", " eupd ", " bpd ", "paranoid personality", "schizoid personality", "histrionic personality", "narcissistic personality", "avoidant personality", "dependent personality", "cluster a", "cluster b", "cluster c"],
        "Psychopathy": ["psychopathy", "psychopathic", "pcl-r", "pcl score", "psychopathy checklist", "antisocial traits", "borderline traits", "narcissistic traits", "lack of remorse", "lack of empathy", "shallow affect", "impulsive lifestyle", "irresponsible behaviour"],
        "PCL Assessment": ["psychopathy assessment", "factor 1", "factor 2"],
        "Psychopathic Traits": ["manipulative behaviour", "superficial charm", "grandiose sense"]
    ]

    // H8: History of Problems with Traumatic Experiences - Uses ONLY desktop terms (no subsection keywords)
    static let h8: [String: [String]] = [
        "Abuse": ["physical abuse", "sexual abuse", "emotional abuse", "psychological abuse", "child abuse", "childhood abuse", "was abused", "history of abuse", "neglect", "neglected as a child", "childhood neglect", "cruelty"],
        "Trauma PTSD": ["traumatic experience", "traumatic event", "traumatic history", "post-traumatic stress", "ptsd diagnosis", "diagnosed with ptsd", "symptoms of ptsd", "trauma symptoms", "trauma-related", "complex trauma", "developmental trauma", "childhood trauma"],
        "Physical Trauma": ["head injury", "traumatic brain injury", " tbi ", "brain injury", "road traffic accident", " rta ", "car accident", "motor vehicle accident", "serious injury", "physical trauma", "assault victim"],
        "Violence Witness": ["domestic violence", "domestic abuse", "witnessed violence", "violence in the home", "victim of violence", "saw father", "saw mother", "parental violence"],
        "Adverse Childhood": ["adverse childhood", "aces score", "childhood adversity", "foster care", "children's home", "local authority care", "taken into care", "removed from parents", "loss of parent", "parental death", "childhood bereavement", "separation from parent", "abandoned"]
    ]

    // H9: History of Problems with Violent Attitudes
    static let h9: [String: [String]] = [
        "Justification": ["had no choice", "forced my hand", "deserved it", "had it coming", "was justified", "necessary response", "only way to deal with", "people only understand force"],
        "Victim-Blaming": ["they provoked me", "provoked me", "staff caused it", "victim started it", "police exaggerated", "system failed me", "if they hadn't", "their fault"],
        "Grievance": ["treated unfairly", "people are against me", "constantly disrespected", "nobody listens", "everyone is out to get me", "out to get me", "feel victimised", "persecuted"],
        "Pro-Violence Identity": ["don't back down", "won't be pushed around", "pushed around", "people need to know", "have to show strength", "show strength", "i see red", "see red"],
        "Authority Hostility": ["rules don't apply", "staff deserved it", "police were corrupt", "police were wrong", "courts are biased", "court is biased", "can't be trusted", "staff are useless", "people like them", "they're all the same", "all the same"],
        "Lack of Remorse": ["no regret", "not my problem", "they'll get over it", "wasn't a big deal", "don't feel sorry", "no remorse"]
    ]

    // H10: History of Problems with Treatment or Supervision Response - Matches desktop exactly
    static let h10: [String: [String]] = [
        "Medication Non-Adherence": ["non-compliant with medication", "poor adherence", "frequently refuses medication", "stopped medication without medical advice", "intermittent compliance", "declined prescribed treatment", "not concordant with treatment plan", "refused depot", "missed multiple doses", "missed multiple appointments", "self-discontinued medication", "medication non-compliance"],
        "Disengagement From Services": ["dna appointments", "disengaged from services", "lost to follow-up", "poor engagement", "failed to attend repeatedly", "minimal engagement with mdt", "does not attend reviews", "refuses community follow-up", "uncontactable for prolonged periods", "did not attend"],
        "Resistance Hostility": ["refuses to engage", "hostile to staff", "dismissive of treatment", "lacks insight into need for treatment", "does not believe treatment is necessary", "rejects psychological input", "uncooperative with ward rules", "oppositional behaviour toward clinicians", "oppositional behavior"],
        "Failure Under Supervision": ["breach of conditions", "breach of cto", "breach of probation", "recall to hospital", "recalled to hospital", "recalled under cto", "recalled from community", "recalled from leave", "cto recall", "returned to custody", "readmitted following", "non-compliance with licence conditions", "failed community placement", "absconded", "awol", "breach", "breached"],
        "Ineffective Interventions": ["little benefit from treatment", "limited response to interventions", "no sustained improvement", "treatment gains not maintained", "relapse following discharge", "risk escalated despite treatment", "repeated admissions despite support", "treatment resistant"],
        "Complies Under Compulsion": ["only compliant under section", "engages only when detained", "improves under close supervision but deteriorates in community", "compliance contingent on legal framework", "responds only to enforced treatment", "only engages when detained", "deteriorates in community"]
    ]

    // MARK: - Clinical Items (C1-C5) - Last 6 months only - Matches desktop exactly

    // C1: Recent Problems with Insight
    static let c1: [String: [String]] = [
        "Insight": ["insight", "poor insight", "limited insight", "absent insight", "lack of insight", "partial insight", "good insight", "full insight", "acknowledges diagnosis", "accepts diagnosis", "denies illness", "does not believe he is unwell", "does not believe she is unwell", "nothing wrong with me", "attributes difficulties to others", "rejects diagnosis", "voices are part of my illness", "recognises relapse signs", "does not recognise", "does not recognize", "attributes symptoms externally"],
        "Illness-Risk Link": ["was unwell when that happened", "lacks victim empathy", "limited reflection on index offence", "does not link mental state", "minimises violence", "denies link", "externalises blame", "they provoked me", "anyone would have reacted", "no reflection on offence", "understands triggers"],
        "Treatment Insight": ["accepts need for treatment", "refuses treatment", "non-concordant with medication", "lacks understanding of need", "engagement improves under section", "accepts medication", "engages with mdt", "requests help when unwell", "only accepts treatment under compulsion"],
        "Insight Stability": ["insight fluctuates", "insight improves with medication", "poor insight when acutely unwell", "insight only when well", "insight lost during relapse", "disengagement then deterioration"],
        "Behavioural Indicators": ["stops meds after discharge", "misses appointments", "rejects follow-up", "blames services", "recurrent relapse", "disengagement", "non-adherence"]
    ]

    // C2: Recent Problems with Violent Ideation or Intent
    static let c2: [String: [String]] = [
        "Explicit Violent Ideation": ["thoughts of harming others", "violent thoughts", "feels like hurting", "desire to assault", "desire to kill", "homicidal ideation", "violent ideation"],
        "Conditional Violence": ["if they push me", "defend myself", "i'll snap", "someone will get hurt", "don't know what i'll do", "if someone disrespects me"],
        "Justification Endorsement": ["they deserved it", "anyone would've done the same", "provoked me", "violence is part of life", "had to do it", "no choice"],
        "Ideation Linked Symptoms": ["command hallucinations to harm", "voices telling to hurt", "voices telling him to hurt", "voices telling her to hurt", "paranoid with retaliatory", "violent thoughts when paranoid", "believes others trying to harm"],
        "Aggressive Rumination": ["persistent anger", "grievance", "grudge", "brooding", "revenge", "escalating language", "repeated complaints"],
        "Violent Threats": ["threatened staff", "verbal threats", "made threats", "threatening", "aggressive statements", "threatened family", "intimidating", "verbal aggression", "hostile", "hostility"]
    ]

    // C3: Recent Problems with Symptoms of Major Mental Disorder
    static let c3: [String: [String]] = [
        "Psychotic Symptoms": ["paranoid ideation", "persecutory beliefs", "persecutory delusions", "command hallucinations", "hearing voices", "delusional", "hallucinating", "psychotic", "thought disorder", "responding to unseen stimuli", "fixed false beliefs", "thoughts are disorganised", "grandiose delusions", "jealous delusions", "passivity phenomena"],
        "Mania Hypomania": ["manic", "hypomanic", "disinhibited", "overfamiliar", "elevated mood", "grandiosity", "reduced need for sleep", "irritable mood", "poor impulse control"],
        "Severe Depression": ["agitated depression", "hopelessness with anger", "nihilistic", "severe depression", "paranoid depression"],
        "Affective Instability": ["emotionally unstable", "affect labile", "easily provoked", "low frustration tolerance", "explosive anger", "rapid mood shifts", "poor emotional regulation"],
        "Arousal Anxiety": ["hypervigilant", "on edge", "exaggerated threat response", "ptsd symptoms exacerbated", "heightened threat perception"],
        "Symptoms Linked Violence": ["violence occurred during psychosis", "violence linked to relapse", "aggression increases when unwell", "offence in context of"],
        "Recency": ["currently experiencing", "recent deterioration", "ongoing symptoms", "acute relapse", "actively psychotic", "acutely unwell"],
        "Remission": ["no evidence of psychosis", "euthymic", "symptoms in remission", "stable on medication", "mental state stable"]
    ]

    // C4: Recent Problems with Instability
    static let c4: [String: [String]] = [
        "Behavioral Impulsivity": ["impulsive", "impulsivity", "impetuous", "unpredictable", "erratic", "volatile", "labile", "poor impulse control", "acts without thinking"],
        "Lifestyle Impulsivity": ["reckless", "impulsive spending", "risky behaviour", "dangerous activities", "thrill-seeking"],
        "Anger Management": ["angry outburst", "outburst", "explosive", "mood swing", "irritable", "agitated", "anger", "angry", "temper", "difficulty managing anger", "anger management"],
        "ADHD": ["restless", "distractible", "hyperactive", "adhd", "attention deficit", "concentration problems"]
    ]

    // C5: Recent Problems with Treatment or Supervision Response
    static let c5: [String: [String]] = [
        "Treatment Acceptance": ["treatment", "therapy", "medication", "accepts treatment", "refuses", "declines", "agrees to", "declines medication", "voluntary", "informal"],
        "Treatment Compliance": ["compliance", "adherence", "compliant", "non-compliant", "noncompliant", "adherent", "takes medication", "refuses medication", "covert non-compliance", "stockpiling", "cheeking", "disengaged", "not engaging", "poor engagement", "does not attend", "missed appointment", "side effects"],
        "Treatment Responsiveness": ["response to treatment", "responding to treatment", "treatment resistant", "refractory", "no improvement", "tried multiple medications"]
    ]

    // MARK: - Risk Management Items (R1-R5) - Matches desktop exactly

    // R1: Future Problems with Professional Services and Plans
    static let r1: [String: [String]] = [
        "Plan Clarity": ["care plan", "treatment plan", "risk management plan", "no clear plan", "plan not finalised", "discharge planning incomplete", "discharge plan", " cpa ", "risk plan", "crisis plan", "contingency plan", "safety plan"],
        "Risk Informed": ["risk not addressed", "does not reflect risks", "triggers addressed", "relapse indicators", "historical risks", "no relapse indicators", "no escalation strategy", "triggers not addressed"],
        "Service Adequacy": ["insufficient support", "limited community input", "appropriate services", "matched to risk", "service intensity", "high intensity", "low intensity", "contact inadequate"],
        "Transitions": ["awaiting allocation", "on waiting list", "gap in care", "transition", "handover", "transfer of care", "no confirmed follow-up", "care to be transferred"],
        "Contingency Planning": ["crisis plan", "contingency plan", "early warning signs", "escalation pathway", "recall criteria", "out-of-hours", "crisis response", "threshold for admission"],
        "Multi-Agency": ["mdt involvement", "information sharing", "defined roles", "fragmented care", "disputes between services", "unclear responsibility"],
        "Protective": ["robust care plan", "risk well managed", "comprehensive plan", "services in place", "timely follow-up", "personalised plan"]
    ]

    // R2: Future Problems with Living Situation - Uses ONLY desktop terms (no subsection keywords)
    static let r2: [String: [String]] = [
        "Accommodation": ["no fixed abode", "accommodation not identified", "unstable housing", "at risk of eviction", "temporary accommodation", "emergency housing", "frequent moves", "sofa-surfing", "homeless", "nfa"],
        "Cohabitants": ["living with victim", "conflictual family", "volatile relationships", "returns to conflict environment", "domestic conflict", "history of violence"],
        "Environment": ["overcrowding", "lack of privacy", "chaotic environment", "overwhelming", "shared accommodation", "high-demand"],
        "Supervision": ["supported accommodation", "staffed setting", "on-site monitoring", "unsupervised living", "step-down", "deteriorates without support", "requires supported living", "unable to manage independently"],
        "Substance Access": ["access to substances", "peers use drugs", "peers use alcohol", "environment not substance-free", "local triggers"],
        "Living Transitions": ["pending move", "recently relocated", "placement breakdown", "discharge accommodation", "moving to"],
        "Protective": ["stable accommodation", "appropriate supported placement", "environment conducive to stability", "distance from victims", "long-term housing", "calm environment"]
    ]

    // R3: Future Problems with Personal Support - Uses ONLY desktop terms (no subsection keywords)
    static let r3: [String: [String]] = [
        "Supportive Relationships": ["supportive family", "positive relationship", "regular contact", "emotional support", "practical support", "crisis support", "family actively involved", "strong protective relationships", "supportive network in place", "supportive partner", "stable relationships"],
        "Isolation": ["limited social support", "socially isolated", "estranged from family", "superficial contact", "unreliable contact", "no one to turn to", "lives alone", "limited contact"],
        "Quality of Support": ["encourages treatment", "promotes calm", "appropriate boundaries", "recognises warning signs", "reinforces maladaptive", "normalises aggression", "undermines treatment", "colludes with avoidance"],
        "Conflict": ["interpersonal conflict", "volatile relationship", "disputes with family", "recurrent arguments", "domestic violence"],
        "Negative Peers": ["antisocial peers", "criminal peers", "substance-using peers", "negative peer influence", "mixes with", "pressure to"],
        "Reliability": ["support breaks down", "limited availability", "conditional support", "inconsistent support", "withdraws during crises"]
    ]

    // R4: Future Problems with Treatment or Supervision Response
    static let r4: [String: [String]] = [
        "Medication Adherence": ["non-compliant with medication", "stops medication", "refuses medication", "takes medication consistently", "depot", "covert non-compliance", "poor concordance", "selective adherence", "partial adherence", "requires supervision", "accepts medication"],
        "Attendance": ["fails to attend", "poor attendance", "misses appointments", " dna ", "inconsistent attendance", "disengaged from services", "avoidance of reviews", "late attendance"],
        "Supervision Compliance": ["breach of conditions", "required recall", "absconded", "non-compliant with licence", "cto recall", "awol", "enforcement required", "conditional discharge recall"],
        "Pattern": ["repeated disengagement", "history of non-compliance", "pattern of disengagement", "cycle of engagement", "engagement then discharge then disengagement"],
        "Enforcement Response": ["only compliant when detained", "resists monitoring", "hostility to monitoring", "voluntary engagement", "becomes hostile when supervised", "escalation when challenged", "rejects supervision", "lacks understanding of risk management", "denies need"],
        "Protective": ["consistently engaged", "good adherence over time", "actively participates", "insight-driven compliance", "uses services proactively", "sustained adherence"]
    ]

    // R5: Future Problems with Stress or Coping - Uses ONLY desktop terms (no subsection keywords)
    static let r5: [String: [String]] = [
        "Anticipated Stressors": ["upcoming stressors", "likely to face", "transition period", "reduced support planned", "discharge stress", "housing uncertainty", "relationship strain", "legal proceedings", "financial problems", "reduced supervision", "loss of structure"],
        "Stress Pattern": ["deteriorates under stress", "struggles during transitions", "stress preceded incidents", "stress-linked", "stress-triggered", "decompensates under stress", "historically struggles"],
        "Coping Capacity": ["limited coping skills", "requires external containment", "coping strategies unlikely", "limited ability to manage", "independent coping", "reliance on others", "coping only in structured"],
        "Maladaptive Coping": ["likely to revert", "history suggests", "risk of relapse", "anger as coping", "intimidation", "withdrawal and rumination", "blame fixation", "grievance fixation"],
        "Substance Coping": ["substance use likely", "relapse risk high", "uses substances to manage", "stress-linked substance use", "copes with alcohol", "copes with drugs"],
        "Protective": ["demonstrated ability to cope", "effective coping strategies", "seeks support early", "rehearsed crisis plan", "help-seeking", "coping skills used successfully", "stable supports available"],
        "General": ["stress", "stressor", "overwhelmed", "pressure", "anxious", "coping", "resilience", "cannot cope"]
    ]

    // MARK: - Category Colors - Updated for exact desktop term categories
    static let categoryColors: [String: String] = [
        // H1 - Violence
        "Violence": "#dc2626",
        "Threats": "#ea580c",
        "Self-Harm": "#be185d",
        // H2 - Antisocial (single category)
        "Antisocial Behaviour": "#7c3aed",
        // H3 - Relationships (single category)
        "Relationships": "#d946ef",
        // H4 - Employment
        "Employment": "#2563eb",
        "Education": "#0891b2",
        // H5 - Substance
        "Substances": "#65a30d",
        "Alcohol": "#b45309",
        "Drug Use": "#7c3aed",
        // H6 - Mental Disorder
        "Schizophrenia Spectrum": "#dc2626",
        "Mood Disorders": "#2563eb",
        "Psychotic Disorders": "#9333ea",
        "Diagnosis": "#059669",
        // H7 - Personality
        "Personality Disorder": "#be185d",
        "Psychopathy": "#dc2626",
        // H8 - Trauma
        "Abuse": "#be185d",
        "Trauma PTSD": "#7c3aed",
        "Physical Trauma": "#ea580c",
        "Violence Witness": "#dc2626",
        "Adverse Childhood": "#d97706",
        // H9 - Attitudes
        "Justification": "#dc2626",
        "Victim-Blaming": "#b45309",
        "Grievance": "#ea580c",
        "Pro-Violence Identity": "#991b1b",
        "Authority Hostility": "#b45309",
        "Lack of Remorse": "#991b1b",
        // H10 - Treatment Response
        "Medication Non-Adherence": "#dc2626",
        "Disengagement From Services": "#ea580c",
        "Resistance Hostility": "#b45309",
        "Failure Under Supervision": "#991b1b",
        "Ineffective Interventions": "#d97706",
        "Complies Under Compulsion": "#7c3aed",
        // C1 - Insight
        "Insight": "#2563eb",
        "Illness-Risk Link": "#7c3aed",
        "Treatment Insight": "#0891b2",
        "Insight Stability": "#059669",
        "Behavioural Indicators": "#ea580c",
        // C2 - Violent Ideation
        "Explicit Violent Ideation": "#dc2626",
        "Conditional Violence": "#ea580c",
        "Justification Endorsement": "#b45309",
        "Ideation Linked Symptoms": "#9333ea",
        "Aggressive Rumination": "#991b1b",
        "Violent Threats": "#ea580c",
        // C3 - Symptoms
        "Psychotic Symptoms": "#9333ea",
        "Mania Hypomania": "#ea580c",
        "Severe Depression": "#2563eb",
        "Affective Instability": "#b45309",
        "Arousal Anxiety": "#d97706",
        "Symptoms Linked Violence": "#dc2626",
        "Recency": "#059669",
        "Remission": "#10b981",
        // C4 - Instability (single category)
        "Instability": "#ea580c",
        // C5 - Treatment (single category)
        "Treatment Response": "#0891b2",
        // R1 - Services
        "Plan Clarity": "#2563eb",
        "Risk Informed": "#dc2626",
        "Service Adequacy": "#0891b2",
        "Transitions": "#d97706",
        "Contingency Planning": "#059669",
        "Multi-Agency": "#7c3aed",
        "Protective": "#10b981",
        // R2 - Living
        "Accommodation": "#7c3aed",
        "Cohabitants": "#be185d",
        "Environment": "#ea580c",
        "Supervision": "#2563eb",
        "Substance Access": "#dc2626",
        "Living Transitions": "#d97706",
        // R3 - Support
        "Supportive Relationships": "#059669",
        "Isolation": "#dc2626",
        "Quality of Support": "#0891b2",
        "Conflict": "#ea580c",
        "Negative Peers": "#b45309",
        "Reliability": "#d97706",
        // R4 - Compliance
        "Medication Adherence": "#0891b2",
        "Attendance": "#ea580c",
        "Supervision Compliance": "#dc2626",
        "Pattern": "#7c3aed",
        "Enforcement Response": "#b45309",
        // R5 - Stress
        "Anticipated Stressors": "#d97706",
        "Stress Pattern": "#ea580c",
        "Coping Capacity": "#059669",
        "Maladaptive Coping": "#dc2626",
        "Substance Coping": "#b45309",
        "General": "#6b7280"
    ]

    /// Categorize text using the given category keywords dictionary
    static func categorize(_ text: String, using keywords: [String: [String]]) -> [String] {
        let textLower = text.lowercased()
        var matches: [String] = []

        for (category, categoryKeywords) in keywords {
            for keyword in categoryKeywords {
                if textLower.contains(keyword) {
                    if !matches.contains(category) {
                        matches.append(category)
                    }
                    break
                }
            }
        }

        return matches
    }

    /// Get keywords dictionary for a specific HCR-20 item
    static func keywordsFor(item: String) -> [String: [String]] {
        switch item.lowercased() {
        case "h1": return h1
        case "h2": return h2
        case "h3": return h3
        case "h4": return h4
        case "h5": return h5
        case "h6": return h6
        case "h7": return h7
        case "h8": return h8
        case "h9": return h9
        case "h10": return h10
        case "c1": return c1
        case "c2": return c2
        case "c3": return c3
        case "c4": return c4
        case "c5": return c5
        case "r1": return r1
        case "r2": return r2
        case "r3": return r3
        case "r4": return r4
        case "r5": return r5
        default: return [:]
        }
    }

    /// Get scope for an item (historical, clinical, or risk_management)
    static func scopeFor(item: String) -> String {
        let itemLower = item.lowercased()
        if itemLower.hasPrefix("h") { return "historical" }
        if itemLower.hasPrefix("c") { return "clinical" }
        if itemLower.hasPrefix("r") { return "risk_management" }
        return "historical"
    }
}

// MARK: - GPR Population Result (for async background processing)

struct GPRPopulationResult {
    var psychiatricHistoryImported: [GPRImportedEntry] = []
    var riskImportedEntries: [GPRImportedEntry] = []
    var backgroundImportedEntries: [GPRImportedEntry] = []
    var medicalHistoryImported: [GPRImportedEntry] = []
    var substanceUseImported: [GPRImportedEntry] = []
    var forensicHistoryImported: [GPRImportedEntry] = []
    var medicationImported: [GPRImportedEntry] = []
    var circumstancesImported: [GPRImportedEntry] = []
    var admissionsTableData: [GPRAdmissionEntry] = []
    var clerkingNotes: [GPRImportedEntry] = []
    var medications: [GPRMedicationEntry] = []
    // Diagnosis
    var diagnosisImported: [GPRImportedEntry] = []
    var diagnosis1ICD10: ICD10Diagnosis = .none
    var diagnosis2ICD10: ICD10Diagnosis = .none
    var diagnosis3ICD10: ICD10Diagnosis = .none
}

// MARK: - General Psychiatric Report Form Data
// Matches desktop general_psychiatric_report_page.py structure (13 sections)

struct GPRFormData: Codable, Equatable {
    let id: UUID
    var createdAt: Date
    var modifiedAt: Date

    // ============================================================
    // SECTION 1: Patient Details
    // ============================================================
    var patientName: String = ""
    var patientGender: Gender = .male
    var patientDOB: Date?
    var mhaSection: String = "Section 3"
    var admissionDate: Date?
    var currentLocation: String = ""  // Hospital/Ward
    var reportBy: String = ""
    var dateSeen: Date?

    // ============================================================
    // SECTION 2: Report Based On (Document Sources)
    // ============================================================
    var sourceMedicalReports: Bool = false
    var sourceNursingInterviews: Bool = false
    var sourcePatientInterviews: Bool = false
    var sourceCurrentPlacementNotes: Bool = false
    var sourceOtherPlacementNotes: Bool = false
    var sourcePsychologyReports: Bool = false
    var sourceSocialWorkReports: Bool = false
    var sourceOTReports: Bool = false

    // ============================================================
    // SECTION 3: Psychiatric History
    // ============================================================
    var admissionsTableData: [GPRAdmissionEntry] = []
    var clerkingNotes: [GPRImportedEntry] = []
    var psychiatricHistoryImported: [GPRImportedEntry] = []
    var includeAdmissionsTable: Bool = true

    // ============================================================
    // SECTION 4: Risk Assessment
    // ============================================================
    // Current Risks (12 types with severity)
    var currentRisks: [GPRRiskType: GPRRiskLevel] = [:]
    // Historical Risks (same 12 types)
    var historicalRisks: [GPRRiskType: GPRRiskLevel] = [:]
    var riskImportedEntries: [GPRImportedEntry] = []

    // ============================================================
    // SECTION 5: Background (Family & Childhood History)
    // Matching desktop background_history_popup.py structure
    // ============================================================
    var backgroundImportedEntries: [GPRImportedEntry] = []

    // --- Early Development ---
    // Birth: Normal, Premature, Complicated, Unknown
    var backgroundBirth: String = "Unknown"
    // Milestones: Normal, Delayed, Walking delayed, Talking delayed, Learning delayed, Unknown, Other
    var backgroundMilestones: String = "Unknown"

    // --- Family & Childhood ---
    // Family history: No significant, Mood disorders, Schizophrenia, Substance misuse, Personality disorder, Other
    var backgroundFamilyHistoryType: String = "No significant family history of mental illness"
    // Childhood abuse severity: None reported, Suspected, Confirmed
    var backgroundAbuseSeverity: String = "None reported"
    // Childhood abuse types (checkboxes)
    var backgroundAbusePhysical: Bool = false
    var backgroundAbuseSexual: Bool = false
    var backgroundAbuseEmotional: Bool = false
    var backgroundAbuseNeglect: Bool = false

    // --- Education & Work ---
    // Schooling severity: No problems, Moderate problems, Severe problems
    var backgroundSchoolingSeverity: String = "No problems"
    // Schooling issues (checkboxes)
    var backgroundSchoolingLearningDifficulties: Bool = false
    var backgroundSchoolingADHD: Bool = false
    var backgroundSchoolingBullied: Bool = false
    var backgroundSchoolingExcluded: Bool = false
    var backgroundSchoolingTruancy: Bool = false
    // Qualifications: None, CSE, GCSE, A-Level, NVQ, HND, Degree, Postgraduate, Unknown
    var backgroundQualifications: String = "Unknown"
    // Work history pattern: Continuous, Intermittent, Rarely, Never, Unknown
    var backgroundWorkPattern: String = "Unknown"
    // Last worked: Currently, <1 year, 1-5 years, 5-10 years, >10 years, Never, Unknown
    var backgroundLastWorked: String = "Unknown"

    // --- Identity & Relationships ---
    // Sexual orientation: Heterosexual, Homosexual, Bisexual, Other, Not documented
    var backgroundSexualOrientation: String = "Not documented"
    // Children count: None, 1, 2, 3, 4+, Unknown
    var backgroundChildrenCount: String = "Unknown"
    // Children age band: Pre-school, Primary, Secondary, Adult, Mixed, N/A
    var backgroundChildrenAgeBand: String = "N/A"
    // Children composition: Male only, Female only, Mixed, Unknown, N/A
    var backgroundChildrenComposition: String = "N/A"
    // Relationships status: Single, In relationship, Married, Divorced, Widowed, Unknown
    var backgroundRelationshipStatus: String = "Unknown"
    // Relationships duration: <1 year, 1-5 years, 5-10 years, 10+ years, Unknown, N/A
    var backgroundRelationshipDuration: String = "N/A"

    // Legacy childhood risk history dropdown (kept for compatibility)
    var childhoodRiskHistory: String = "No significant risk behavior in childhood reported"

    // Legacy text fields (now secondary - controls above are primary)
    var backgroundFamilyHistory: String = ""
    var backgroundChildhoodHistory: String = ""
    var backgroundEducation: String = ""
    var backgroundRelationships: String = ""

    // ============================================================
    // SECTION 6: Medical History (Physical Health)
    // Matching desktop physical_health_popup.py structure
    // 8 categories with 30+ conditions
    // ============================================================

    // --- Cardiac Conditions ---
    var medicalCardiacHypertension: Bool = false
    var medicalCardiacMI: Bool = false
    var medicalCardiacArrhythmias: Bool = false
    var medicalCardiacHighCholesterol: Bool = false
    var medicalCardiacHeartFailure: Bool = false

    // --- Endocrine Conditions ---
    var medicalEndocrineDiabetes: Bool = false
    var medicalEndocrineThyroidDisorder: Bool = false
    var medicalEndocrinePCOS: Bool = false

    // --- Respiratory Conditions ---
    var medicalRespiratoryAsthma: Bool = false
    var medicalRespiratoryCOPD: Bool = false
    var medicalRespiratoryBronchitis: Bool = false

    // --- Gastric Conditions ---
    var medicalGastricUlcer: Bool = false
    var medicalGastricGORD: Bool = false
    var medicalGastricIBS: Bool = false

    // --- Neurological Conditions ---
    var medicalNeurologicalMS: Bool = false
    var medicalNeurologicalParkinsons: Bool = false
    var medicalNeurologicalEpilepsy: Bool = false

    // --- Hepatic Conditions ---
    var medicalHepaticHepC: Bool = false
    var medicalHepaticFattyLiver: Bool = false
    var medicalHepaticAlcoholRelated: Bool = false

    // --- Renal Conditions ---
    var medicalRenalCKD: Bool = false
    var medicalRenalESRD: Bool = false

    // --- Cancer History ---
    var medicalCancerLung: Bool = false
    var medicalCancerProstate: Bool = false
    var medicalCancerBladder: Bool = false
    var medicalCancerUterine: Bool = false
    var medicalCancerBreast: Bool = false
    var medicalCancerBrain: Bool = false
    var medicalCancerKidney: Bool = false

    // Legacy dictionary (kept for compatibility)
    var physicalHealthConditions: [String: Bool] = [:]
    var medicalHistoryImported: [GPRImportedEntry] = []

    // ============================================================
    // SECTION 7: Substance Use
    // Matching desktop drugs_alcohol_popup.py structure
    // ============================================================

    // --- Alcohol ---
    // Age options: None, early teens, mid-teens, early adulthood, 30s and 40s, 50s, later adulthood
    var alcoholAgeStarted: String = "None"
    // Amount options: None, 1-5 units/week, 5-10, 10-20, 20-35, 35-50, >50
    var alcoholCurrentUse: String = "None"

    // --- Smoking ---
    var smokingAgeStarted: String = "None"
    // Amount options: None, 1-5 cigs/day, 5-10, 10-20, 20-30, >30
    var smokingCurrentUse: String = "None"

    // --- Illicit Drugs ---
    // 10 drug types with per-drug tracking
    var drugCannabisUsed: Bool = false
    var drugCannabisAge: String = "None"
    var drugCannabisSpend: String = "None"

    var drugCocaineUsed: Bool = false
    var drugCocaineAge: String = "None"
    var drugCocaineSpend: String = "None"

    var drugCrackUsed: Bool = false
    var drugCrackAge: String = "None"
    var drugCrackSpend: String = "None"

    var drugHeroinUsed: Bool = false
    var drugHeroinAge: String = "None"
    var drugHeroinSpend: String = "None"

    var drugEcstasyUsed: Bool = false
    var drugEcstasyAge: String = "None"
    var drugEcstasySpend: String = "None"

    var drugLSDUsed: Bool = false
    var drugLSDAge: String = "None"
    var drugLSDSpend: String = "None"

    var drugSpiceUsed: Bool = false
    var drugSpiceAge: String = "None"
    var drugSpiceSpend: String = "None"

    var drugAmphetaminesUsed: Bool = false
    var drugAmphetaminesAge: String = "None"
    var drugAmphetaminesSpend: String = "None"

    var drugKetamineUsed: Bool = false
    var drugKetamineAge: String = "None"
    var drugKetamineSpend: String = "None"

    var drugBenzodiazepinesUsed: Bool = false
    var drugBenzodiazepinesAge: String = "None"
    var drugBenzodiazepinesSpend: String = "None"

    // Legacy fields (kept for compatibility)
    var alcoholStartAge: Int = 0
    var smokingStartAge: Int = 0
    var drugsStartAge: Int = 0
    var alcoholAmount: Int = 0
    var smokingAmount: Int = 0
    var drugsAmount: Int = 0
    var primaryDrug: String = ""
    var substanceUseImported: [GPRImportedEntry] = []

    // ============================================================
    // SECTION 8: Medication
    // ============================================================
    var medications: [GPRMedicationEntry] = []
    var medicationImported: [GPRImportedEntry] = []

    // ============================================================
    // SECTION 9: Diagnosis (ICD-10)
    // Using ICD10Diagnosis enum with dropdown picker
    // ============================================================
    var diagnosis1ICD10: ICD10Diagnosis = .none
    var diagnosis2ICD10: ICD10Diagnosis = .none
    var diagnosis3ICD10: ICD10Diagnosis = .none
    // Legacy text fields (kept for custom diagnoses)
    var diagnosis1: String = ""
    var diagnosis1Code: String = ""
    var diagnosis2: String = ""
    var diagnosis2Code: String = ""
    var diagnosis3: String = ""
    var diagnosis3Code: String = ""
    var diagnosisImported: [GPRImportedEntry] = []

    // ============================================================
    // SECTION 12: Legal Criteria for Detention
    // Uses ClinicalReasonsData - same as A3 form
    // ============================================================
    var legalClinicalReasons: ClinicalReasonsData = ClinicalReasonsData()

    // Legacy fields (kept for compatibility with old code)
    var legalMentalDisorderPresent: Bool? = nil
    var legalMentalDisorderICD10: ICD10Diagnosis = .none
    var legalCriteriaWarrantingDetention: Bool? = nil
    var legalCriteriaByNature: Bool = false
    var legalNatureRelapsing: Bool = false
    var legalNatureTreatmentResistant: Bool = false
    var legalNatureChronic: Bool = false
    var legalCriteriaByDegree: Bool = false
    var legalSymptomSeverity: Int = 2
    var legalSymptomsDescription: String = ""
    var legalNecessity: Bool? = nil
    var legalNecessityHealth: Bool = false
    var legalNecessityHealthMental: Bool = false
    var legalNecessityHealthMentalPoorCompliance: Bool = false
    var legalNecessityHealthMentalLimitedInsight: Bool = false
    var legalNecessityHealthPhysical: Bool = false
    var legalNecessityHealthPhysicalDetails: String = ""
    var legalNecessitySafety: Bool = false
    var legalNecessitySafetySelf: Bool = false
    var legalNecessitySafetySelfDetails: String = ""
    var legalNecessitySafetyOthers: Bool = false
    var legalNecessitySafetyOthersDetails: String = ""
    var legalTreatmentAvailable: Bool = false
    var legalLeastRestrictiveOption: Bool = false

    // Legacy fields (kept for compatibility)
    var mentalDisorderPresent: Bool = true
    var criteriaWarrantingDetention: Bool = true
    var natureOfDisorder: Bool = false
    var degreeOfDisorder: Bool = false
    var natureRelapsing: Bool = false
    var natureTreatmentResistant: Bool = false
    var natureChronic: Bool = false
    var symptomSeverity: Int = 2
    var symptomsDescription: String = ""
    var necessityPsychological: Bool = false
    var necessityPharmacological: Bool = false
    var necessityNursing: Bool = false
    var necessityOther: Bool = false
    var necessityOtherDescription: String = ""
    var treatmentSetting: String = "Psychiatric hospital"
    var legalCriteriaImported: [GPRImportedEntry] = []

    // ============================================================
    // SECTION 11: Strengths
    // ============================================================
    var strengthEngagementStaff: Bool = false
    var strengthEngagementPeers: Bool = false
    var strengthOT: Bool = false
    var strengthNursing: Bool = false
    var strengthPsychology: Bool = false
    var strengthAffect: Bool = false
    var strengthHumour: Bool = false
    var strengthWarmth: Bool = false
    var strengthFriendly: Bool = false
    var strengthCaring: Bool = false
    var strengthsImported: [GPRImportedEntry] = []

    // ============================================================
    // SECTION 9: Forensic History
    // Matching desktop forensic_history_popup.py structure
    // ============================================================
    // Convictions: declined, none, some
    var forensicConvictionsStatus: String = "none"
    var forensicConvictionCount: Int = 0  // 0-10+ slider
    var forensicOffenceCount: Int = 0     // 0-10+ slider
    // Prison: declined, never, yes
    var forensicPrisonStatus: String = "never"
    var forensicPrisonDuration: String = "None"  // <6mo, 6-12mo, 1-2yr, 2-5yr, >5yr
    var forensicIndexOffence: String = ""
    var forensicHistoryImported: [GPRImportedEntry] = []

    // ============================================================
    // SECTION 3: Circumstances to this Admission
    // ============================================================
    var circumstancesImported: [GPRImportedEntry] = []

    // ============================================================
    // SECTION 14: Signature
    // ============================================================
    var signatureName: String = ""
    var signatureDesignation: String = ""
    var signatureQualifications: String = ""
    var signatureRegNumber: String = ""
    var signatureDate: Date = Date()

    init() {
        self.id = UUID()
        self.createdAt = Date()
        self.modifiedAt = Date()
        // Initialize all risk types to none
        for riskType in GPRRiskType.allCases {
            currentRisks[riskType] = .none
            historicalRisks[riskType] = .none
        }
    }

    // Validation
    func validate() -> [FormValidationError] {
        var errors: [FormValidationError] = []
        if patientName.isEmpty {
            errors.append(FormValidationError(field: "Patient Name", message: "Patient name is required"))
        }
        if signatureName.isEmpty {
            errors.append(FormValidationError(field: "Signature", message: "Clinician name is required"))
        }
        return errors
    }
}

// MARK: - GPR Supporting Types

struct GPRAdmissionEntry: Codable, Equatable, Identifiable {
    let id: UUID
    var admissionDate: Date?
    var dischargeDate: Date?
    var duration: String = ""

    init(id: UUID = UUID(), admissionDate: Date? = nil, dischargeDate: Date? = nil, duration: String = "") {
        self.id = id
        self.admissionDate = admissionDate
        self.dischargeDate = dischargeDate
        self.duration = duration
    }
}

struct GPRImportedEntry: Codable, Equatable, Identifiable {
    let id: UUID
    var date: Date?
    var text: String
    var snippet: String?
    var categories: [String]
    var selected: Bool

    init(id: UUID = UUID(), date: Date? = nil, text: String, snippet: String? = nil, categories: [String] = [], selected: Bool = false) {
        self.id = id
        self.date = date
        self.text = text
        self.snippet = snippet
        self.categories = categories
        self.selected = selected
    }
}

struct GPRMedicationEntry: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String
    var dose: String
    var frequency: String

    init(id: UUID = UUID(), name: String = "", dose: String = "", frequency: String = "") {
        self.id = id
        self.name = name
        self.dose = dose
        self.frequency = frequency
    }
}

enum GPRRiskType: String, Codable, CaseIterable, Hashable {
    case violence = "Violence to others"
    case verbalAggression = "Verbal aggression"
    case selfHarm = "Self-harm"
    case suicide = "Suicide"
    case selfNeglect = "Self-neglect"
    case exploitation = "Exploitation by others"
    case sexuallyInappropriate = "Sexually inappropriate behaviour"
    case substanceMisuse = "Substance misuse"
    case propertyDamage = "Property damage"
    case awol = "AWOL/Absconding"
    case mentalHealthDeterioration = "Mental health deterioration"
    case nonCompliance = "Non-compliance with treatment"
}

enum GPRRiskLevel: String, Codable, CaseIterable {
    case none = "None"
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    var color: String {
        switch self {
        case .none: return "808080"  // Gray
        case .low: return "22C55E"   // Green
        case .medium: return "F59E0B" // Orange
        case .high: return "EF4444"   // Red
        }
    }
}

// MARK: - GPR Category Keywords (for imported data categorization)

struct GPRCategoryKeywords {
    // Psychiatric History keywords
    static let psychiatricHistory: [String: [String]] = [
        "Admission": ["admitted", "admission", "sectioned", "detained", "transferred", "presented"],
        "Discharge": ["discharged", "discharge", "left hospital", "released"],
        "Relapse": ["relapse", "deteriorat", "decompensation", "crisis"],
        "Treatment Response": ["treatment", "therapy", "medication", "intervention"]
    ]

    // Risk keywords
    static let risk: [String: [String]] = [
        "Violence": ["violen", "aggress", "assault", "attack", "hit", "punch", "kick", "threaten"],
        "Self-harm": ["self-harm", "self harm", "cutting", "overdose", "self-injur"],
        "Suicide": ["suicid", "end my life", "kill myself", "want to die"],
        "Absconding": ["abscond", "awol", "missing", "escaped", "left without"],
        "Substance": ["drug", "alcohol", "intoxicat", "substance", "cannabis", "cocaine"]
    ]

    // Background keywords
    static let background: [String: [String]] = [
        "Family": ["family", "mother", "father", "parent", "sibling", "brother", "sister", "childhood"],
        "Education": ["school", "education", "college", "university", "qualification"],
        "Relationships": ["relationship", "partner", "married", "divorced", "children"]
    ]

    // Medical history keywords
    static let medicalHistory: [String: [String]] = [
        "Cardiovascular": ["heart", "cardiac", "hypertension", "blood pressure", "cholesterol"],
        "Respiratory": ["asthma", "copd", "breathing", "lung"],
        "Metabolic": ["diabetes", "thyroid", "weight", "bmi", "metabolic"],
        "Neurological": ["epilepsy", "seizure", "stroke", "head injury"]
    ]

    // Substance use keywords
    static let substanceUse: [String: [String]] = [
        "Alcohol": ["alcohol", "drinking", "drunk", "beer", "wine", "spirits"],
        "Cannabis": ["cannabis", "marijuana", "weed", "skunk"],
        "Stimulants": ["cocaine", "crack", "amphetamine", "meth"],
        "Opioids": ["heroin", "opioid", "morphine", "methadone"],
        "Tobacco": ["smoking", "cigarette", "tobacco", "nicotine"]
    ]

    // Medication keywords
    static let medication: [String: [String]] = [
        "Antipsychotic": ["clozapine", "olanzapine", "risperidone", "quetiapine", "aripiprazole", "haloperidol"],
        "Antidepressant": ["sertraline", "fluoxetine", "mirtazapine", "venlafaxine", "citalopram"],
        "Mood Stabilizer": ["lithium", "valproate", "carbamazepine", "lamotrigine"],
        "Anxiolytic": ["diazepam", "lorazepam", "clonazepam", "promethazine"]
    ]

    // Diagnosis keywords
    static let diagnosis: [String: [String]] = [
        "Schizophrenia": ["schizophren", "psychosis", "psychotic"],
        "Bipolar": ["bipolar", "manic", "hypomania"],
        "Depression": ["depress", "low mood", "anhedonia"],
        "Personality": ["personality disorder", "bpd", "eupd", "aspd", "antisocial"]
    ]

    // Strengths keywords
    static let strengths: [String: [String]] = [
        "Engagement": ["engag", "attend", "participat", "cooperat"],
        "Progress": ["progress", "improv", "positive", "better"],
        "Relationships": ["rapport", "relationship", "connect", "support"]
    ]

    // Forensic History keywords (matches Physical Aggression, Property Damage, Sexual Behaviour)
    static let forensicHistory: [String: [String]] = [
        "Physical Aggression": ["assault", "attack", "hit", "punch", "kick", "violen", "aggress", "restrain", "physical altercation", "threw", "pushed", "struck"],
        "Property Damage": ["property damage", "smashed", "broke", "destroyed", "vandal", "criminal damage", "set fire", "arson"],
        "Sexual Behaviour": ["sexual", "indecent", "inappropriate sexual", "exposure", "sexual assault", "rape"]
    ]

    // Circumstances keywords
    static let circumstances: [String: [String]] = [
        "Precipitant": ["led to", "resulted in", "caused", "triggered", "prior to admission"],
        "Police": ["police", "arrested", "custody", "136", "place of safety"],
        "Crisis": ["crisis", "emergency", "deteriorat", "relapse"]
    ]

    // Legal Criteria keywords
    static let legalCriteria: [String: [String]] = [
        "Detention": ["detention", "detained", "sectioned", "mental health act", "mha"],
        "Legal Treatment": ["appropriate treatment", "treatment available", "treatability"],
        "Legal Risk": ["risk to self", "risk to others", "safety", "protection"]
    ]

    static func categorize(_ text: String, using keywords: [String: [String]]) -> [String] {
        let textLower = text.lowercased()
        var matches: [String] = []

        for (category, categoryKeywords) in keywords {
            for keyword in categoryKeywords {
                if textLower.contains(keyword) {
                    if !matches.contains(category) {
                        matches.append(category)
                    }
                    break
                }
            }
        }

        return matches
    }

    // Risk incident regex patterns matching desktop risk_overview_panel.py
    // These patterns require contextual matches (e.g. "punch + staff") not just keywords
    static let riskIncidentRegexPatterns: [String: [String]] = [
        "Physical Aggression": [
            // Assault on Staff
            "\\b(punch\\w*|kick\\w*|hit|slap\\w*|struck|attack\\w*)\\s+(a\\s+)?(staff|nurse|hca|doctor|member\\s+of\\s+staff)\\b",
            "\\bassault\\w*\\s+(a\\s+)?(staff|nurse|hca|doctor)\\b",
            "\\b(head.?butt\\w*|headbutt\\w*)\\s+(a\\s+)?(staff|nurse)\\b",
            "\\b(bit|biting|bitten)\\s+(a\\s+)?(staff|nurse)\\b",
            // Assault on Peer
            "\\b(punch\\w*|kick\\w*|hit|slap\\w*|struck|attack\\w*)\\s+(a\\s+)?(peer|patient|another\\s+patient)\\b",
            "\\bassault\\w*\\s+(a\\s+)?(peer|patient|another)\\b",
            "\\bphysical\\s+altercation\\b",
            // Physical Aggression general
            "\\bphysical(ly)?\\s+aggress\\w*",
            "\\blashed\\s+out\\s+(at|physically)\\b",
            "\\b(became|becoming|was)\\s+physically\\s+violent\\b",
            "\\bviolent\\s+(outburst|episode|incident)\\b",
            // Restraint
            "\\b(restrain\\w*|restraint)\\s+(was\\s+)?(required|needed|used|applied)\\b",
            "\\b(prone|supine)\\s+restraint\\b",
            "\\brequired\\s+(physical\\s+)?intervention\\b",
            "\\b(rapi?d\\s+tranquil|rt\\s+administered|given\\s+rt|rt\\s+given)"
        ],
        "Verbal Aggression": [
            "\\bverbally\\s+(abusive|aggressive|hostile)\\b",
            "\\bverbal(ly)?\\s+abus\\w*",
            "\\babusive\\s+(language|towards|to\\s+staff)\\b",
            "\\b(was|became|being)\\s+abusive\\b",
            "\\bshouting\\s+(at|and)\\b",
            "\\bthreateni?n?g?\\s+(staff|peer|behaviour|language)\\b",
            "\\b(made?|making)\\s+(a\\s+)?threat\\b",
            "\\bspat\\s+(at|on|towards)\\b",
            "\\bspit(ting)?\\s+(at|on|towards)\\b",
            "\\bintimidati\\w+"
        ],
        "Self-Harm": [
            // Cutting with context
            "\\b(he|she|patient|resident)\\s+(cut|cuts|cutting)\\s+(his|her)\\s+(arm|wrist|leg|body|skin|face)\\b",
            "\\bself[\\s-]?cut\\w*\\s+(today|this|during)\\b",
            // Head banging
            "\\b(he|she|patient)\\s+(was|started|began)?\\s*bang\\w*\\s+(his|her)\\s*head\\b",
            "\\bhead[\\s-]?bang\\w*\\s+(incident|episode|observed|witnessed)\\b",
            // Hitting self
            "\\b(he|she|patient)\\s+(hit|hitting|hits|struck|punched|punching)\\s+(himself|herself)\\b",
            // Ligature
            "\\b(made|tied|created|found\\s+with|attempted)\\s+(a\\s+)?ligature\\b",
            "\\bligature\\s+(incident|attempt|found|discovered)\\b",
            // Overdose
            "\\b(he|she|patient)\\s+(took|taken|has\\s+taken)\\s+(an?\\s+)?overdose\\b",
            "\\boverdose\\s+(incident|attempt|today|this)\\b",
            // Self-harm act
            "\\b(he|she|patient)\\s+self[\\s-]?harmed\\b",
            "\\bself[\\s-]?harm\\s+(incident|episode|act)\\s+(today|this|occurred|reported)\\b",
            "\\b(engaged?|engaging)\\s+in\\s+self[\\s-]?harm\\w*\\b"
        ],
        "Suicide": [
            "\\b(attempted?|attempt\\w*|tried)\\s+to\\s+hang\\s+(himself|herself)\\b",
            "\\bsuicid\\w*\\s+(attempt|ideation|thought|gesture|intent)\\b",
            "\\b(express\\w*|report\\w*)\\s+(suicid|wish\\w*\\s+to\\s+die)\\b"
        ],
        "Property Damage": [
            "\\b(broke|broken|breaking|smash\\w*|damag\\w*)\\s+(the\\s+)?(window|door|furniture|tv|television|chair|table)\\b",
            "\\bdamag\\w+\\s+(to\\s+)?(property|furniture|equipment)\\b",
            "\\b(punch\\w*|kick\\w*|hit)\\s+(the\\s+)?(wall|door|window)\\b",
            "\\b(threw|thrown|throwing)\\s+.{0,15}(furniture|chair|table|object|item)\\b",
            "\\b(destroy\\w*|wreck\\w*)\\s+(his|her|the)\\s+(room|property|belongings)\\b"
        ],
        "AWOL": [
            "\\bawol\\b",
            "\\babsent\\s+without\\s+leave\\b",
            "\\babscond\\w*",
            "\\bfailed\\s+to\\s+return\\b",
            "\\bdid\\s+not\\s+return\\s+from\\s+leave\\b",
            "\\b(escaped?|escaping)\\s+from\\b",
            "\\bleft\\s+without\\s+permission\\b"
        ],
        "Sexual Behaviour": [
            "\\b(sexual|inappropriate)\\s+(comment|remark)\\b",
            "\\b(inappropriately?\\s+)?touch\\w*\\s+(staff|breast|buttock|bottom|groin)\\b",
            "\\b(grope|groping|groped)\\b",
            "\\bexpos(ed?|ing)\\s+(himself|herself|genitals?)\\b",
            "\\bmasturbat\\w+",
            "\\bsexual(ly)?\\s+disinhibit\\w*",
            "\\b(sexual|inappropriate)\\s+advance\\b"
        ],
        "Self-Neglect": [
            "\\b(looked?|appear\\w*|present\\w*)\\s+(very\\s+)?(unkempt|dishevelled|unwashed|neglected)\\b",
            "\\bclothes?\\s+(were?|was|is|are)\\s+(dirty|soiled|stained)\\b",
            "\\bbody\\s+odou?r\\b",
            "\\b(declined?|refused?)\\s+to\\s+(shower|wash|bathe|change)\\b",
            "\\bpoor\\s+(dietary|fluid|food)\\s+(and\\s+fluid\\s+)?intake\\b",
            "\\b(declined?|refused?)\\s+(all\\s+)?(food|meals?|to\\s+eat)\\b"
        ],
        "Substance Misuse": [
            "\\b(tested|test)\\s+(came\\s+back\\s+)?positive\\s+(for\\s+)?(drug|cannabis|thc|cocaine|amphet|opiates?|benzo)\\b",
            "\\bpositive\\s+(drug|uds|urine)\\s+(test|screen|result)\\b",
            "\\buds\\s+(was\\s+|came\\s+back\\s+)?positive\\b",
            "\\b(smell\\w*|smelt)\\s+(of|like)\\s+(cannabis|alcohol|weed|spice|marijuana)\\b",
            "\\b(appear\\w*|seem\\w*|present\\w*)\\s+(to\\s+be\\s+)?(intoxicated|drunk|under\\s+the\\s+influence)\\b",
            "\\b(admitted|disclosed)\\s+(to\\s+)?(using|smoking|taking|drinking)\\s+(cannabis|spice|drugs|alcohol|cocaine)\\b",
            "\\bfound\\s+(with\\s+)?(drugs|substances|cannabis|alcohol)\\b"
        ],
        "Bullying": [
            "\\b(was|been|observed|witnessed|seen)\\s+(to\\s+)?(be\\s+)?(bully|bullying)\\b",
            "\\b(bully|bullying)\\s+(peer|patient|another|other)\\b",
            "\\b(target|targeting|targeted)\\s+(vulnerable|other)?\\s*(patient|peer)\\b",
            "\\b(intimidat\\w+)\\s+(peer|patient|another|other)\\b"
        ]
    ]

    /// Helper to check if text matches a regex pattern
    private static func matchesRegex(_ text: String, pattern: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return false
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }

    /// Check if a match has negative context (nil, no, denied, etc.) - matching desktop logic
    private static func hasNegativeContext(_ text: String, pattern: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return false
        }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              let swiftRange = Range(match.range, in: text) else {
            return false
        }

        let matchStart = text.distance(from: text.startIndex, to: swiftRange.lowerBound)
        let matchEnd = text.distance(from: text.startIndex, to: swiftRange.upperBound)

        // Get context around the match (50 chars before and after)
        let contextStart = max(0, matchStart - 50)
        let contextEnd = min(text.count, matchEnd + 50)

        let startIndex = text.index(text.startIndex, offsetBy: contextStart)
        let matchStartIndex = text.index(text.startIndex, offsetBy: matchStart)
        let matchEndIndex = text.index(text.startIndex, offsetBy: min(matchEnd, text.count))
        let endIndex = text.index(text.startIndex, offsetBy: min(contextEnd, text.count))

        let beforeText = String(text[startIndex..<matchStartIndex]).lowercased()
        let afterText = String(text[matchEndIndex..<endIndex]).lowercased()

        // Negative patterns before the match
        let negativeBefore = [
            "\\b(no|nil|none|denies?|denied|without|lacks?)\\s*$",
            "\\b(no|nil|none|denies?|denied|without|lacks?)\\s+(any|all|the|a)?\\s*$",
            "\\b(no\\s+evidence|no\\s+history|no\\s+signs?|no\\s+indication)\\s+of\\s*$",
            "\\b(has\\s+not|did\\s+not|does\\s+not|hasn't|didn't|doesn't)\\s*$",
            "\\b(not\\s+noted|not\\s+reported|not\\s+observed)\\s*$",
            "\\bdenied\\s+(any|all)?\\s*(thoughts?\\s+of|ideation\\s+of|intent\\s+to|intention\\s+to)?\\s*$",
            "\\b(not|never)\\s+express(ing|ed)?\\s*(any)?\\s*$",
            "\\bno\\s+(current|recent|active|new)?\\s*(thoughts?|episodes?|ideation|urges?|intent)\\s+(of|to)\\s*$",
            "\\b(doesn't|does\\s+not|don't|do\\s+not)\\s+have\\s+(\\w+\\s+)*$",
            "\\b(there\\s+)?(were|was|are|is)\\s+no\\s+(episode|evidence|history|indication)s?\\s+(of)?\\s*$",
            "\\bno\\s+\\w+\\s+of\\s*$",
            "\\bwith\\s+no\\s*$",
            "\\bor\\s+(urges?\\s+to|thoughts?\\s+of|intent\\s+to)?\\s*$",
            "\\b(was|were|is|are)\\s+not\\s*$"
        ]

        for negPattern in negativeBefore {
            if matchesRegex(beforeText, pattern: negPattern) {
                return true
            }
        }

        // Broader negation patterns
        let broaderNegation = [
            "\\b(no|not|nil|none|denied|denies|without)\\b.{0,40}\\bor\\b",
            "\\b(doesn't|does\\s+not|don't)\\s+have\\b"
        ]
        for negPattern in broaderNegation {
            if matchesRegex(beforeText, pattern: negPattern) {
                return true
            }
        }

        // Negative patterns after the match
        let negativeAfter = [
            "^\\s*(nil|none|denied|not\\s+noted|not\\s+reported)\\b",
            "^\\s*-\\s*(nil|no|none|denied)\\b",
            "^\\s*(were|was|are|is)?\\s*(not\\s+present|not\\s+identified|not\\s+expressed|absent)\\b",
            "^\\s*(were|was|are|is)?\\s*not\\s+(noted|reported|observed|evident|identified)\\b",
            "^\\s*(thoughts?|ideation)?\\s*(were|was|are|is)?\\s*(not\\s+present|absent|not\\s+expressed|denied)\\b",
            "^\\s*(was|were|is|are)?\\s*not\\s+(required|needed|necessary|indicated)\\b"
        ]

        for negPattern in negativeAfter {
            if matchesRegex(afterText, pattern: negPattern) {
                return true
            }
        }

        // Check full context for assessment/documentation language with negation
        let fullContext = String(text[startIndex..<endIndex]).lowercased()
        let assessmentPatterns = [
            "\\brisk\\s+(assessment|screen|factor)",
            "\\b(asked|enquired|assessed)\\s+about\\b",
            "\\bqueried\\s+(re|regarding|about)\\b"
        ]

        for assessPattern in assessmentPatterns {
            if matchesRegex(fullContext, pattern: assessPattern) {
                // Only exclude if also has negative indicator
                if matchesRegex(fullContext, pattern: "\\b(no|nil|denied|denies|negative)\\b") {
                    return true
                }
            }
        }

        return false
    }

    /// Helper to highlight all regex matches in text with [[...]] markers (excluding negated matches)
    private static func highlightMatches(in text: String, pattern: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return text
        }
        let range = NSRange(text.startIndex..., in: text)
        var result = text

        // Find all matches and replace with highlighted version (process in reverse to preserve indices)
        let matches = regex.matches(in: text, options: [], range: range)
        for match in matches.reversed() {
            if let swiftRange = Range(match.range, in: text) {
                let matchedText = String(text[swiftRange])
                result.replaceSubrange(swiftRange, with: "[[" + matchedText + "]]")
            }
        }
        return result
    }

    /// Check if pattern matches without negative context
    private static func matchesWithoutNegation(_ text: String, pattern: String) -> Bool {
        guard matchesRegex(text, pattern: pattern) else { return false }
        return !hasNegativeContext(text, pattern: pattern)
    }

    /// Categorizes text for risk incidents using desktop-style regex patterns (with negation filter)
    static func categorizeRiskIncident(_ text: String) -> [String] {
        var matches: [String] = []

        for (category, patterns) in riskIncidentRegexPatterns {
            for pattern in patterns {
                // Use negation filter to exclude "no self-harm", "denied suicidal thoughts", etc.
                if matchesWithoutNegation(text, pattern: pattern) {
                    if !matches.contains(category) {
                        matches.append(category)
                    }
                    break
                }
            }
        }

        return matches
    }

    /// Categorizes text for risk incidents and extracts relevant context (matched line + 2 before/after)
    /// Highlights matched text with [[...]] markers
    /// Uses negation filter to exclude "no self-harm", "denied suicidal thoughts", etc.
    static func categorizeRiskIncidentWithContext(_ text: String) -> (categories: [String], context: String)? {
        let lines = text.components(separatedBy: .newlines)

        var matches: [String] = []
        var matchedLineIndices: Set<Int> = []
        var lineToPatterns: [Int: [String]] = [:] // Track which patterns matched each line

        // Find all categories and their matched line indices using regex with negation filter
        for (category, patterns) in riskIncidentRegexPatterns {
            for pattern in patterns {
                // Find which line matches this regex pattern (excluding negated context)
                for (index, line) in lines.enumerated() {
                    if matchesWithoutNegation(line, pattern: pattern) {
                        if !matches.contains(category) {
                            matches.append(category)
                        }
                        matchedLineIndices.insert(index)
                        // Store the pattern that matched this line
                        if lineToPatterns[index] == nil {
                            lineToPatterns[index] = []
                        }
                        lineToPatterns[index]?.append(pattern)
                        break // Found this pattern, move to next
                    }
                }
                if matches.contains(category) {
                    break // Already found this category
                }
            }
        }

        guard !matches.isEmpty else { return nil }

        // Build context: for each matched line, include 2 before and 2 after
        var contextLineIndices: Set<Int> = []
        for matchedIndex in matchedLineIndices {
            let start = max(0, matchedIndex - 2)
            let end = min(lines.count - 1, matchedIndex + 2)
            for i in start...end {
                contextLineIndices.insert(i)
            }
        }

        // Build context string from sorted line indices, highlighting matched text
        let sortedIndices = contextLineIndices.sorted()
        var contextLines: [String] = []
        var previousIndex = -10

        for index in sortedIndices {
            // Add separator if there's a gap in lines
            if index > previousIndex + 1 && previousIndex >= 0 {
                contextLines.append("...")
            }

            var line = lines[index]
            // If this line had matches, highlight them
            if let patterns = lineToPatterns[index] {
                for pattern in patterns {
                    line = highlightMatches(in: line, pattern: pattern)
                }
            }
            contextLines.append(line)
            previousIndex = index
        }

        let context = contextLines.joined(separator: "\n")
        return (categories: matches, context: context)
    }

    // Substance use regex patterns for contextual matching
    static let substanceUseRegexPatterns: [String: [String]] = [
        "Alcohol": [
            "\\b(alcohol|drinking|drunk|intoxicated|beer|wine|spirits|vodka|whisky|lager)\\b",
            "\\b(drink\\w*\\s+alcohol|alcoholic|alcohol\\s+use|alcohol\\s+misuse|alcohol\\s+abuse)\\b",
            "\\b(units?\\s+of\\s+alcohol|standard\\s+drinks?|binge\\s+drink)\\b",
            "\\bbreathalys\\w*|blood\\s+alcohol\\b"
        ],
        "Cannabis": [
            "\\b(cannabis|marijuana|weed|skunk|hash|hashish|spliff|joint|thc)\\b",
            "\\b(smok\\w+\\s+(cannabis|weed|marijuana)|using\\s+cannabis)\\b",
            "\\bpositive\\s+(for\\s+)?cannabis|cannabis\\s+positive\\b"
        ],
        "Stimulants": [
            "\\b(cocaine|crack|amphetamine|meth|methamphetamine|speed|mdma|ecstasy)\\b",
            "\\b(using\\s+(cocaine|crack|amphetamine|meth|speed))\\b",
            "\\bpositive\\s+(for\\s+)?(cocaine|amphetamine)\\b"
        ],
        "Opioids": [
            "\\b(heroin|opioid|morphine|methadone|buprenorphine|subutex|fentanyl|codeine|tramadol)\\b",
            "\\b(opiate|opiates|iv\\s+drug|intravenous\\s+drug|injecting\\s+drug)\\b",
            "\\bpositive\\s+(for\\s+)?opiate\\b"
        ],
        "Benzodiazepines": [
            "\\b(benzodiazepine|benzo|diazepam|valium|temazepam|lorazepam|clonazepam|xanax|alprazolam)\\b",
            "\\bpositive\\s+(for\\s+)?benzo\\b"
        ],
        "Novel Psychoactive": [
            "\\b(spice|mamba|black\\s+mamba|synthetic\\s+cannabis|legal\\s+high|nps|novel\\s+psychoactive)\\b",
            "\\b(bath\\s+salts|k2|kronic)\\b"
        ],
        "Tobacco": [
            "\\b(smoking|cigarette|tobacco|nicotine|vaping|e-cigarette)\\b",
            "\\b(smokes?\\s+\\d+|pack\\s+year|roll-?up)\\b"
        ]
    ]

    /// Categorizes text for substance use and extracts relevant context (matched line + 2 before/after)
    /// Highlights matched text with [[...]] markers
    static func categorizeSubstanceWithContext(_ text: String) -> (categories: [String], context: String)? {
        let lines = text.components(separatedBy: .newlines)

        var matches: [String] = []
        var matchedLineIndices: Set<Int> = []
        var lineToPatterns: [Int: [String]] = [:]

        // Find all categories and their matched line indices using regex
        for (category, patterns) in substanceUseRegexPatterns {
            for pattern in patterns {
                for (index, line) in lines.enumerated() {
                    if matchesRegex(line, pattern: pattern) {
                        // Check for negation context
                        if !hasSubstanceNegativeContext(line, pattern: pattern) {
                            if !matches.contains(category) {
                                matches.append(category)
                            }
                            matchedLineIndices.insert(index)
                            if lineToPatterns[index] == nil {
                                lineToPatterns[index] = []
                            }
                            lineToPatterns[index]?.append(pattern)
                            break
                        }
                    }
                }
                if matches.contains(category) {
                    break
                }
            }
        }

        guard !matches.isEmpty else { return nil }

        // Build context: for each matched line, include 2 before and 2 after
        var contextLineIndices: Set<Int> = []
        for matchedIndex in matchedLineIndices {
            let start = max(0, matchedIndex - 2)
            let end = min(lines.count - 1, matchedIndex + 2)
            for i in start...end {
                contextLineIndices.insert(i)
            }
        }

        // Build context string with highlighting
        let sortedIndices = contextLineIndices.sorted()
        var contextLines: [String] = []
        var previousIndex = -10

        for index in sortedIndices {
            if index > previousIndex + 1 && previousIndex >= 0 {
                contextLines.append("...")
            }

            var line = lines[index]
            if let patterns = lineToPatterns[index] {
                for pattern in patterns {
                    line = highlightMatches(in: line, pattern: pattern)
                }
            }
            contextLines.append(line)
            previousIndex = index
        }

        let context = contextLines.joined(separator: "\n")
        return (categories: matches, context: context)
    }

    /// Check for negative context in substance use mentions
    private static func hasSubstanceNegativeContext(_ text: String, pattern: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return false
        }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              let swiftRange = Range(match.range, in: text) else {
            return false
        }

        let matchStart = text.distance(from: text.startIndex, to: swiftRange.lowerBound)
        let contextStart = max(0, matchStart - 40)
        let startIndex = text.index(text.startIndex, offsetBy: contextStart)
        let matchStartIndex = text.index(text.startIndex, offsetBy: matchStart)
        let beforeText = String(text[startIndex..<matchStartIndex]).lowercased()

        // Negative patterns for substance use
        let negativePatterns = [
            "\\b(no|nil|none|denies?|denied|without)\\s*$",
            "\\b(no\\s+history|no\\s+current|never\\s+used)\\s*$",
            "\\b(abstinent|abstinence|clean|drug-?free)\\b",
            "\\b(negative\\s+for|tested\\s+negative)\\b",
            "\\bnot\\s+using\\s*$",
            "\\bstopped\\s+(using)?\\s*$"
        ]

        for negPattern in negativePatterns {
            if matchesRegex(beforeText, pattern: negPattern) {
                return true
            }
        }

        return false
    }

    // Forensic history relevant risk categories (matching desktop)
    static let forensicRiskCategories = ["Physical Aggression", "Property Damage", "Sexual Behaviour"]

    /// Categorizes text for forensic history incidents (Physical Aggression, Property Damage, Sexual Behaviour)
    /// Uses the same risk incident patterns with context extraction and highlighting
    static func categorizeForensicWithContext(_ text: String) -> (categories: [String], context: String)? {
        let lines = text.components(separatedBy: .newlines)

        var matches: [String] = []
        var matchedLineIndices: Set<Int> = []
        var lineToPatterns: [Int: [String]] = [:]

        // Only check forensic-relevant categories
        for (category, patterns) in riskIncidentRegexPatterns {
            guard forensicRiskCategories.contains(category) else { continue }

            for pattern in patterns {
                for (index, line) in lines.enumerated() {
                    if matchesWithoutNegation(line, pattern: pattern) {
                        if !matches.contains(category) {
                            matches.append(category)
                        }
                        matchedLineIndices.insert(index)
                        if lineToPatterns[index] == nil {
                            lineToPatterns[index] = []
                        }
                        lineToPatterns[index]?.append(pattern)
                        break
                    }
                }
                if matches.contains(category) {
                    break
                }
            }
        }

        guard !matches.isEmpty else { return nil }

        // Build context: for each matched line, include 2 before and 2 after
        var contextLineIndices: Set<Int> = []
        for matchedIndex in matchedLineIndices {
            let start = max(0, matchedIndex - 2)
            let end = min(lines.count - 1, matchedIndex + 2)
            for i in start...end {
                contextLineIndices.insert(i)
            }
        }

        // Build context string with highlighting
        let sortedIndices = contextLineIndices.sorted()
        var contextLines: [String] = []
        var previousIndex = -10

        for index in sortedIndices {
            if index > previousIndex + 1 && previousIndex >= 0 {
                contextLines.append("...")
            }

            var line = lines[index]
            if let patterns = lineToPatterns[index] {
                for pattern in patterns {
                    line = highlightMatches(in: line, pattern: pattern)
                }
            }
            contextLines.append(line)
            previousIndex = index
        }

        let context = contextLines.joined(separator: "\n")
        return (categories: matches, context: context)
    }

    // Category colors for badges
    static let categoryColors: [String: String] = [
        // Psychiatric History
        "Admission": "3B82F6",
        "Discharge": "10B981",
        "Relapse": "EF4444",
        "Treatment Response": "8B5CF6",
        // Risk Incidents (matching desktop risk_overview_panel colors)
        "Physical Aggression": "B71C1C",
        "Verbal Aggression": "9E9E9E",
        "Self-Harm": "FF5722",
        "Suicide": "7C3AED",
        "Property Damage": "E53935",
        "AWOL": "FF9800",
        "Sexual Behaviour": "00BCD4",
        "Self-Neglect": "607D8B",
        "Substance Misuse": "4CAF50",
        "Fire Risk": "F44336",
        // Legacy Risk
        "Violence": "DC2626",
        "Self-harm": "F59E0B",
        "Absconding": "F97316",
        "Substance": "06B6D4",
        // Background
        "Family": "EC4899",
        "Education": "6366F1",
        "Relationships": "14B8A6",
        // Medical
        "Cardiovascular": "EF4444",
        "Respiratory": "3B82F6",
        "Metabolic": "F59E0B",
        "Neurological": "8B5CF6",
        // Substance
        "Alcohol": "F59E0B",
        "Cannabis": "22C55E",
        "Stimulants": "EF4444",
        "Opioids": "7C3AED",
        "Tobacco": "6B7280",
        // Medication
        "Antipsychotic": "3B82F6",
        "Antidepressant": "10B981",
        "Mood Stabilizer": "F59E0B",
        "Anxiolytic": "8B5CF6",
        // Diagnosis
        "Schizophrenia": "DC2626",
        "Bipolar": "F59E0B",
        "Depression": "6366F1",
        "Personality": "EC4899",
        // Strengths
        "Engagement": "22C55E",
        "Progress": "10B981",
        // Circumstances
        "Precipitant": "F59E0B",
        "Police": "3B82F6",
        "Crisis": "EF4444",
        // Forensic History (unique categories only - others covered by Risk Incidents)
        "Forensic": "DC2626",
        // Legal Criteria
        "Detention": "7C3AED",
        "Legal Treatment": "10B981",
        "Legal Risk": "EF4444"
    ]
}

// MARK: - ═══════════════════════════════════════════════════════════════
// MARK: - TRIBUNAL REPORT DATA MODELS
// MARK: - ═══════════════════════════════════════════════════════════════

/// Shared imported entry for tribunal reports
struct TribunalImportedEntry: Codable, Equatable, Identifiable {
    var id = UUID()
    var date: Date?
    var text: String
    var snippet: String?
    var selected: Bool = false
    var categories: [String] = []
}

/// Admission entry for tribunal reports (matches GPRAdmissionEntry)
struct TribunalAdmissionEntry: Codable, Equatable, Identifiable {
    let id: UUID
    var admissionDate: Date?
    var dischargeDate: Date?
    var duration: String = ""

    init(id: UUID = UUID(), admissionDate: Date? = nil, dischargeDate: Date? = nil, duration: String = "") {
        self.id = id
        self.admissionDate = admissionDate
        self.dischargeDate = dischargeDate
        self.duration = duration
    }
}

/// Shared medication entry for tribunal reports
struct TribunalMedicationEntry: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String = ""
    var dose: String = ""
    var frequency: String = ""
}

// MARK: - Psychiatric Tribunal Report Form Data
struct PsychTribunalFormData: Codable, Equatable {
    var id = UUID()

    // Section 1: Patient Details
    var patientName: String = ""
    var patientDOB: Date?
    var patientGender: Gender = .male
    var hospitalNumber: String = ""
    var nhsNumber: String = ""
    var currentLocation: String = ""
    var mhaSection: String = "Section 3"
    var admissionDate: Date?

    // Section 2: Responsible Clinician
    var rcName: String = ""
    var rcRoleTitle: String = ""
    var rcDiscipline: String = ""
    var rcRegNumber: String = ""
    var rcEmail: String = ""
    var rcPhone: String = ""

    // Section 3: Factors affecting hearing - Desktop uses single radio selection
    var hasFactorsAffectingHearing: Bool = false
    var selectedFactor: String = "" // "Autism", "Learning Disability", "Low frustration tolerance"
    var factorsDetails: String = ""

    // Section 4: Adjustments - Desktop uses single radio selection
    var hasAdjustmentsNeeded: Bool = false
    var selectedAdjustment: String = "" // "Explanation", "Breaks", "More time"
    var adjustmentsOther: String = ""

    // Section 5: Forensic History
    var indexOffence: String = ""
    var indexOffenceDate: Date?
    var forensicHistoryNarrative: String = ""
    var forensicImported: [TribunalImportedEntry] = []

    // Section 5: Convictions & Prison History (matching desktop ForensicHistoryPopup)
    var convictionsStatus: String = "" // "declined", "none", "some"
    var convictionCountIndex: Int = 0 // 0-10 (one to more than ten)
    var offenceCountIndex: Int = 0 // 0-10 (one to more than ten)
    var prisonStatus: String = "" // "declined", "never", "yes"
    var prisonDurationIndex: Int = 0 // 0-4 (less than 6 months to more than 5 years)

    // Section 6 & 7: Previous MH (matching GPR Past Psychiatric History structure)
    var admissionsTableData: [TribunalAdmissionEntry] = []
    var clerkingNotes: [TribunalImportedEntry] = []
    var previousMHImported: [TribunalImportedEntry] = []
    var previousAdmissionReasons: String = ""
    var includeAdmissionsTable: Bool = true

    // Section 8: Current Admission
    var currentAdmissionNarrative: String = ""
    var admissionImported: [TribunalImportedEntry] = []

    // Section 9: Diagnosis (using ICD-10) - Desktop has Yes/No for mental disorder first
    var hasMentalDisorder: Bool = true
    var diagnosis1: ICD10Diagnosis?
    var diagnosis2: ICD10Diagnosis?
    var diagnosis3: ICD10Diagnosis?

    // Section 10: Learning Disability
    var hasLearningDisability: Bool = false
    var learningDisabilityDetails: String = ""

    // Section 11: Detention Required
    var detentionAppropriate: Bool = true
    var detentionExplanation: String = ""

    // Section 12: Treatment - Medical Treatment
    var medications: [TribunalMedicationEntry] = []
    // Section 12: Treatment - Nursing (checkbox + dropdown)
    var nursingEnabled: Bool = true
    var nursingType: String = "Inpatient" // Inpatient, Community
    // Section 12: Treatment - Psychology (checkbox + radio + dropdown)
    var psychologyEnabled: Bool = false
    var psychologyStatus: String = "Continue" // Continue, Start, Refused
    var psychologyTherapyType: String = "CBT" // CBT, Trauma-focussed, DBT, Psychodynamic, Supportive
    // Section 12: Treatment - OT (checkbox + text)
    var otEnabled: Bool = false
    var otDetails: String = ""
    // Section 12: Treatment - Social Work (checkbox + dropdown)
    var socialWorkEnabled: Bool = false
    var socialWorkType: String = "Inpatient" // Inpatient, Community
    // Section 12: Treatment - Care Pathway (checkbox + dropdown)
    var carePathwayEnabled: Bool = false
    var carePathwayType: String = "inpatient - less restrictive" // inpatient - less restrictive, inpatient - discharge, outpatient - stepdown, outpatient - independent
    var treatmentImported: [TribunalImportedEntry] = []

    // Section 13: Strengths
    var strengthsNarrative: String = ""
    var strengthsImported: [TribunalImportedEntry] = []

    // Section 14: Progress
    var progressNarrative: String = ""
    var progressImported: [TribunalImportedEntry] = []

    // Section 15: Compliance - Grid structure (Desktop options)
    // Understanding: good, fair, poor
    // Compliance: full, reasonable, partial, nil
    var medicalUnderstanding: String = "" // good, fair, poor
    var medicalCompliance: String = "" // full, reasonable, partial, nil
    var nursingUnderstanding: String = ""
    var nursingCompliance: String = ""
    var psychologyUnderstanding: String = ""
    var psychologyCompliance: String = ""
    var otUnderstanding: String = ""
    var otCompliance: String = ""
    var socialWorkUnderstanding: String = ""
    var socialWorkCompliance: String = ""
    var complianceImported: [TribunalImportedEntry] = []

    // Section 16: MCA DoL
    var dolsInPlace: Bool = false
    var copOrder: Bool = false
    var standardAuthorisation: Bool = false
    var floatingProvision: String = "Not applicable"
    var mcaDetails: String = ""

    // Section 17: Risk Harm
    var harmAssaultStaff: Bool = false
    var harmAssaultPatients: Bool = false
    var harmAssaultPublic: Bool = false
    var harmVerbalAggression: Bool = false
    var harmSelfHarm: Bool = false
    var harmSuicidal: Bool = false
    var riskHarmImported: [TribunalImportedEntry] = []

    // Section 18: Risk Property
    var propertyWard: Bool = false
    var propertyPersonal: Bool = false
    var propertyFire: Bool = false
    var propertyVehicle: Bool = false
    var riskPropertyImported: [TribunalImportedEntry] = []

    // Section 19: S2 Detention
    var s2DetentionJustified: Bool = true
    var s2Explanation: String = ""

    // Section 20: Other Detention
    var otherDetentionJustified: Bool = true
    var otherDetentionExplanation: String = ""

    // Section 21: Discharge Risk
    var dischargeRiskViolence: Bool = false
    var dischargeRiskSelfHarm: Bool = false
    var dischargeRiskNeglect: Bool = false
    var dischargeRiskExploitation: Bool = false
    var dischargeRiskRelapse: Bool = false
    var dischargeRiskNonCompliance: Bool = false
    var dischargeRiskDetails: String = ""

    // Section 22: Community Management
    var cmhtInvolvement: String = "Not required"
    var cpaInPlace: Bool = false
    var careCoordinator: Bool = false
    var section117: Bool = false
    var mappaInvolved: Bool = false
    var mappaLevel: String = "Level 1"
    var communityPlanDetails: String = ""

    // Section 23: Recommendations / Legal Criteria
    // Mental Disorder
    var recMdPresent: Bool? = nil          // nil = not yet selected
    var recDiagnosis1: ICD10Diagnosis? = nil
    var recDiagnosis2: ICD10Diagnosis? = nil
    var recDiagnosis3: ICD10Diagnosis? = nil
    // Criteria Warranting Detention
    var recCwdMet: Bool? = nil             // nil = not yet selected
    var recNature: Bool = false
    var recRelapsing: Bool = false
    var recTreatmentResistant: Bool = false
    var recChronic: Bool = false
    var recDegree: Bool = false
    var recDegreeLevel: Int = 2            // 1=Some, 2=Several, 3=Many, 4=Overwhelming
    var recDegreeDetails: String = ""
    // Necessity
    var recNecessary: Bool? = nil           // nil = not yet selected
    var recHealth: Bool = false
    var recMentalHealth: Bool = false
    var recPoorCompliance: Bool = false
    var recLimitedInsight: Bool = false
    var recPhysicalHealth: Bool = false
    var recPhysicalHealthDetails: String = ""
    var recSafety: Bool = false
    var recSafetySelf: Bool = false
    var recSelfDetails: String = ""
    var recOthers: Bool = false
    var recOthersDetails: String = ""
    // Treatment & Least Restrictive
    var recTreatmentAvailable: Bool = false
    var recLeastRestrictive: Bool = false
    var recommendationsImported: [TribunalImportedEntry] = []

    // Section 24: Signature
    var signatureName: String = ""
    var signatureDesignation: String = ""
    var signatureQualifications: String = ""
    var signatureRegNumber: String = ""
    var signatureDate: Date = Date()

    func validate() -> [FormValidationError] {
        var errors: [FormValidationError] = []
        if patientName.isEmpty { errors.append(FormValidationError(field: "Patient Name", message: "Required")) }
        if signatureName.isEmpty { errors.append(FormValidationError(field: "Signature Name", message: "Required")) }
        return errors
    }
}

// MARK: - Nursing Tribunal Report Form Data
struct NursingTribunalFormData: Codable, Equatable {
    var id = UUID()

    // Section 1: Patient Details
    var patientName: String = ""
    var patientDOB: Date?
    var patientGender: Gender = .male
    var hospitalNumber: String = ""
    var nhsNumber: String = ""
    var currentLocation: String = ""
    var mhaSection: String = "Section 3"
    var admissionDate: Date?

    // Section 2: Factors affecting hearing - Desktop uses single radio selection
    var hasFactorsAffectingHearing: Bool = false
    var selectedFactor: String = "" // "Autism", "Learning Disability", "Low frustration tolerance"
    var factorsDetails: String = ""

    // Section 3: Adjustments - Desktop uses single radio selection
    var hasAdjustmentsNeeded: Bool = false
    var selectedAdjustment: String = "" // "Explanation", "Breaks", "More time"
    var adjustmentsOther: String = ""

    // Section 4: Nature of nursing care
    var nursingCareLevel: String = "General inpatient"
    var medications: [TribunalMedicationEntry] = []
    var nursingCareImported: [TribunalImportedEntry] = []

    // Section 5: Level of observation
    var observationLevel: String = "General"
    var observationDetails: String = ""
    var observationImported: [TribunalImportedEntry] = []

    // Section 6: Contact with relatives/friends
    var contactRelativesType: String = "Regular"
    var contactRelativesCount: Int = 0
    var contactRelativesLevel: Int = 2
    var hasFriends: Bool = false
    var contactFriendsLevel: Int = 0
    var hasPatientContact: Bool = true
    var contactPatientsLevel: Int = 2
    var contactImported: [TribunalImportedEntry] = []

    // Section 7: Community support
    var familySupportType: String = "None"
    var familySupportLevel: Int = 0
    var cmhtInvolved: Bool = false
    var treatmentPlanInPlace: Bool = false
    var accommodationType: String = "Supported"
    var communitySupportImported: [TribunalImportedEntry] = []

    // Section 8: Strengths
    var strengthsNarrative: String = ""
    var strengthsImported: [TribunalImportedEntry] = []

    // Section 9: Progress
    var progressNarrative: String = ""
    var progressImported: [TribunalImportedEntry] = []

    // Section 10: AWOL
    var awolNarrative: String = ""
    var awolImported: [TribunalImportedEntry] = []

    // Section 11: Compliance
    var complianceLevel: String = "Partial"
    var complianceNarrative: String = ""
    var complianceImported: [TribunalImportedEntry] = []

    // Section 12: Risk Harm
    var harmAssaultStaff: Bool = false
    var harmAssaultPatients: Bool = false
    var harmAssaultPublic: Bool = false
    var harmVerbalAggression: Bool = false
    var harmSelfHarm: Bool = false
    var harmSuicidal: Bool = false
    var riskHarmImported: [TribunalImportedEntry] = []

    // Section 13: Risk Property
    var propertyWard: Bool = false
    var propertyPersonal: Bool = false
    var propertyFire: Bool = false
    var propertyVehicle: Bool = false
    var riskPropertyImported: [TribunalImportedEntry] = []

    // Section 14: Seclusion/Restraint
    var seclusionUsed: Bool = false
    var restraintUsed: Bool = false
    var seclusionDetails: String = ""
    var seclusionImported: [TribunalImportedEntry] = []

    // Section 15: S2 Detention
    var s2DetentionJustified: Bool = true
    var s2Explanation: String = ""

    // Section 16: Other Detention
    var otherDetentionJustified: Bool = true
    var otherDetentionExplanation: String = ""

    // Section 17: Discharge Risk
    var dischargeRiskViolence: Bool = false
    var dischargeRiskSelfHarm: Bool = false
    var dischargeRiskNeglect: Bool = false
    var dischargeRiskExploitation: Bool = false
    var dischargeRiskRelapse: Bool = false
    var dischargeRiskNonCompliance: Bool = false
    var dischargeRiskDetails: String = ""

    // Section 18: Community Management
    var cmhtInvolvement: String = "Not required"
    var cpaInPlace: Bool = false
    var careCoordinator: Bool = false
    var section117: Bool = false
    var communityPlanDetails: String = ""
    var communityImported: [TribunalImportedEntry] = []

    // Section 19: Other Info
    var otherInfoNarrative: String = ""

    // Section 20: Recommendations / Legal Criteria
    var recMdPresent: Bool? = nil
    var recDiagnosis1: ICD10Diagnosis? = nil
    var recDiagnosis2: ICD10Diagnosis? = nil
    var recDiagnosis3: ICD10Diagnosis? = nil
    var recCwdMet: Bool? = nil
    var recNature: Bool = false
    var recRelapsing: Bool = false
    var recTreatmentResistant: Bool = false
    var recChronic: Bool = false
    var recDegree: Bool = false
    var recDegreeLevel: Int = 2
    var recDegreeDetails: String = ""
    var recNecessary: Bool? = nil
    var recHealth: Bool = false
    var recMentalHealth: Bool = false
    var recPoorCompliance: Bool = false
    var recLimitedInsight: Bool = false
    var recPhysicalHealth: Bool = false
    var recPhysicalHealthDetails: String = ""
    var recSafety: Bool = false
    var recSafetySelf: Bool = false
    var recSelfDetails: String = ""
    var recOthers: Bool = false
    var recOthersDetails: String = ""
    var recTreatmentAvailable: Bool = false
    var recLeastRestrictive: Bool = false
    var recommendationsImported: [TribunalImportedEntry] = []

    // Section 21: Signature
    var signatureName: String = ""
    var signatureDesignation: String = ""
    var signatureQualifications: String = ""
    var signatureRegNumber: String = ""
    var signatureDate: Date = Date()

    func validate() -> [FormValidationError] {
        var errors: [FormValidationError] = []
        if patientName.isEmpty { errors.append(FormValidationError(field: "Patient Name", message: "Required")) }
        if signatureName.isEmpty { errors.append(FormValidationError(field: "Signature Name", message: "Required")) }
        return errors
    }
}

// MARK: - Social Tribunal Report Form Data
struct SocialTribunalFormData: Codable, Equatable {
    var id = UUID()

    // Section 1: Patient Details
    var patientName: String = ""
    var patientDOB: Date?
    var patientGender: Gender = .male
    var hospitalNumber: String = ""
    var nhsNumber: String = ""
    var currentLocation: String = ""
    var mhaSection: String = "Section 3"
    var admissionDate: Date?

    // Section 2: Factors affecting hearing - Desktop uses single radio selection
    var hasFactorsAffectingHearing: Bool = false
    var selectedFactor: String = "" // "Autism", "Learning Disability", "Low frustration tolerance"
    var factorsDetails: String = ""

    // Section 3: Adjustments - Desktop uses single radio selection
    var hasAdjustmentsNeeded: Bool = false
    var selectedAdjustment: String = "" // "Explanation", "Breaks", "More time"
    var adjustmentsOther: String = ""

    // Section 4: Forensic History
    var indexOffence: String = ""
    var indexOffenceDate: Date?
    var forensicHistoryNarrative: String = ""
    var forensicImported: [TribunalImportedEntry] = []

    // Section 5: Previous MH
    var previousMHImported: [TribunalImportedEntry] = []
    var previousMHNarrative: String = ""

    // Section 6: Home and Family
    var homeFamilyNarrative: String = ""
    var homeFamilyImported: [TribunalImportedEntry] = []

    // Section 7: Housing
    var housingNarrative: String = ""
    var housingImported: [TribunalImportedEntry] = []

    // Section 8: Financial
    var financialNarrative: String = ""
    var financialImported: [TribunalImportedEntry] = []

    // Section 9: Employment
    var hasEmploymentOpportunities: Bool = false
    var employmentDetails: String = ""

    // Section 10: Previous Community Support
    var previousCommunityNarrative: String = ""

    // Section 11: Care Pathway
    var carePathwayNarrative: String = ""

    // Section 12: Proposed Care Plan
    var carePlanNarrative: String = ""

    // Section 13: Care Plan Adequacy
    var carePlanAdequacy: String = "Adequate"
    var carePlanAdequacyDetails: String = ""

    // Section 14: Care Plan Funding
    var carePlanFunding: String = "Confirmed"
    var carePlanFundingDetails: String = ""

    // Section 15: Strengths
    var strengthsNarrative: String = ""
    var strengthsImported: [TribunalImportedEntry] = []

    // Section 16: Progress
    var progressNarrative: String = ""
    var progressImported: [TribunalImportedEntry] = []

    // Section 17: Risk Harm
    var harmAssaultStaff: Bool = false
    var harmAssaultPatients: Bool = false
    var harmAssaultPublic: Bool = false
    var harmVerbalAggression: Bool = false
    var harmSelfHarm: Bool = false
    var harmSuicidal: Bool = false
    var riskHarmImported: [TribunalImportedEntry] = []

    // Section 18: Risk Property
    var propertyWard: Bool = false
    var propertyPersonal: Bool = false
    var propertyFire: Bool = false
    var propertyVehicle: Bool = false
    var riskPropertyImported: [TribunalImportedEntry] = []

    // Section 19: Patient Views
    var patientViewsDischarge: String = "Ambivalent"
    var patientViewsNarrative: String = ""
    var patientConcerns: String = ""
    var patientHopes: String = ""

    // Section 20: Nearest Relative
    var nearestRelativeName: String = ""
    var nearestRelativeRelationship: String = ""
    var nearestRelativeViews: String = ""

    // Section 21: NR Inappropriate
    var nrInappropriateReason: String = ""

    // Section 22: Carer Views
    var carerName: String = ""
    var carerRole: String = ""
    var carerViews: String = ""

    // Section 23: MAPPA
    var mappaInvolved: Bool = false
    var mappaLevel: String = "Level 1"
    var mappaNarrative: String = ""

    // Section 24: MCA DoL
    var dolsInPlace: Bool = false
    var floatingProvision: String = "Not applicable"
    var mcaDetails: String = ""

    // Section 25: S2 Detention
    var s2DetentionJustified: Bool = true
    var s2Explanation: String = ""

    // Section 26: Other Detention
    var otherDetentionJustified: Bool = true
    var otherDetentionExplanation: String = ""

    // Section 27: Discharge Risk
    var dischargeRiskViolence: Bool = false
    var dischargeRiskSelfHarm: Bool = false
    var dischargeRiskNeglect: Bool = false
    var dischargeRiskExploitation: Bool = false
    var dischargeRiskRelapse: Bool = false
    var dischargeRiskNonCompliance: Bool = false
    var dischargeRiskDetails: String = ""

    // Section 28: Community Management
    var cmhtInvolvement: String = "Not required"
    var cpaInPlace: Bool = false
    var careCoordinator: Bool = false
    var section117: Bool = false
    var communityPlanDetails: String = ""

    // Section 29: Other Info
    var otherInfoNarrative: String = ""

    // Section 30: Recommendations / Legal Criteria
    var recMdPresent: Bool? = nil
    var recDiagnosis1: ICD10Diagnosis? = nil
    var recDiagnosis2: ICD10Diagnosis? = nil
    var recDiagnosis3: ICD10Diagnosis? = nil
    var recCwdMet: Bool? = nil
    var recNature: Bool = false
    var recRelapsing: Bool = false
    var recTreatmentResistant: Bool = false
    var recChronic: Bool = false
    var recDegree: Bool = false
    var recDegreeLevel: Int = 2
    var recDegreeDetails: String = ""
    var recNecessary: Bool? = nil
    var recHealth: Bool = false
    var recMentalHealth: Bool = false
    var recPoorCompliance: Bool = false
    var recLimitedInsight: Bool = false
    var recPhysicalHealth: Bool = false
    var recPhysicalHealthDetails: String = ""
    var recSafety: Bool = false
    var recSafetySelf: Bool = false
    var recSelfDetails: String = ""
    var recOthers: Bool = false
    var recOthersDetails: String = ""
    var recTreatmentAvailable: Bool = false
    var recLeastRestrictive: Bool = false
    var recommendationsImported: [TribunalImportedEntry] = []

    // Section 31: Signature
    var signatureName: String = ""
    var signatureDesignation: String = ""
    var signatureQualifications: String = ""
    var signatureRegNumber: String = ""
    var signatureDate: Date = Date()

    func validate() -> [FormValidationError] {
        var errors: [FormValidationError] = []
        if patientName.isEmpty { errors.append(FormValidationError(field: "Patient Name", message: "Required")) }
        if signatureName.isEmpty { errors.append(FormValidationError(field: "Signature Name", message: "Required")) }
        return errors
    }
}

// MARK: - NarrativeGenerator Types
// These types are used by various report views for narrative generation

struct NarrativeEntry {
    let date: Date?
    let content: String
    let type: String
    let originator: String
    var score: Int = 0
    var drivers: [(String, Int)] = []

    var contentLower: String { content.lowercased() }
}

struct NarrativeResult {
    let plainText: String
    let htmlText: String
    let dateRange: String
    let entryCount: Int
}

enum NarrativePeriod: String {
    case all = "all"
    case oneYear = "1_year"
    case sixMonths = "6_months"
    case lastAdmission = "last_admission"
}

class NarrativeGenerator {
    private var riskDict: [String: Int] = [:]
    private var entries: [NarrativeEntry] = []
    private var referenceCounter: Int = 0
    private var references: [String: [String: Any]] = [:]

    private let excludedTerms: Set<String> = [
        "high", "low", "reduce", "good", "bad", "well", "poor",
        "can", "will", "may", "has", "had", "was", "were",
        "new", "old", "some", "any", "all", "one", "two",
        "time", "day", "week", "said", "told", "asked", "noted"
    ]

    init() { loadRiskDictionary() }

    func generateNarrative(from entries: [NarrativeEntry], period: NarrativePeriod = .oneYear, patientName: String? = nil, gender: String? = nil) -> NarrativeResult {
        let filteredEntries = filterEntries(entries, by: period)
        if filteredEntries.isEmpty {
            return NarrativeResult(plainText: "", htmlText: "", dateRange: "No entries", entryCount: 0)
        }
        resetReferenceTracker()
        var scoredEntries = filteredEntries.map { entry -> NarrativeEntry in
            var mutableEntry = entry
            let (score, drivers) = scoreEntry(entry.content)
            mutableEntry.score = score
            mutableEntry.drivers = drivers
            return mutableEntry
        }
        scoredEntries.sort { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
        self.entries = scoredEntries
        let pronouns = getPronouns(for: gender)
        let name = patientName?.components(separatedBy: " ").first ?? "The patient"
        let (plainText, htmlText) = buildNarrative(name: name, pronouns: pronouns, entries: scoredEntries)
        let dateRange = getDateRangeInfo(entries: filteredEntries, period: period)
        return NarrativeResult(plainText: plainText, htmlText: htmlText, dateRange: dateRange, entryCount: filteredEntries.count)
    }

    private func filterEntries(_ entries: [NarrativeEntry], by period: NarrativePeriod) -> [NarrativeEntry] {
        guard !entries.isEmpty else { return [] }
        switch period {
        case .all: return entries
        case .oneYear:
            guard let mostRecent = entries.compactMap({ $0.date }).max() else { return entries }
            let cutoff = Calendar.current.date(byAdding: .day, value: -365, to: mostRecent) ?? mostRecent
            return entries.filter { ($0.date ?? .distantPast) >= cutoff }
        case .sixMonths:
            guard let mostRecent = entries.compactMap({ $0.date }).max() else { return entries }
            let cutoff = Calendar.current.date(byAdding: .day, value: -180, to: mostRecent) ?? mostRecent
            return entries.filter { ($0.date ?? .distantPast) >= cutoff }
        case .lastAdmission: return entries
        }
    }

    struct Pronouns { let subject: String; let object: String; let possessive: String; let subjectCap: String; let possessiveCap: String }

    private func getPronouns(for gender: String?) -> Pronouns {
        let g = (gender ?? "").lowercased()
        switch g {
        case "female", "f": return Pronouns(subject: "she", object: "her", possessive: "her", subjectCap: "She", possessiveCap: "Her")
        case "male", "m": return Pronouns(subject: "he", object: "him", possessive: "his", subjectCap: "He", possessiveCap: "His")
        default: return Pronouns(subject: "they", object: "them", possessive: "their", subjectCap: "They", possessiveCap: "Their")
        }
    }

    private func loadRiskDictionary() {
        riskDict = ["suicide": 15, "suicidal": 15, "self-harm": 14, "overdose": 14, "violence": 13, "assault": 13, "aggression": 12, "seclusion": 12, "restraint": 11, "awol": 11, "police": 10, "paranoid": 8, "delusion": 8, "psychosis": 9, "manic": 8, "agitated": 7, "threatening": 8, "incident": 5]
    }

    private func scoreEntry(_ content: String) -> (Int, [(String, Int)]) {
        let contentLower = content.lowercased()
        var totalScore = 0
        var drivers: [(String, Int)] = []
        for (term, score) in riskDict {
            if excludedTerms.contains(term) || term.count <= 2 { continue }
            if contentLower.contains(term) { totalScore += score; drivers.append((term, score)) }
        }
        drivers.sort { $0.1 > $1.1 }
        return (totalScore, Array(drivers.prefix(5)))
    }

    private func buildNarrative(name: String, pronouns: Pronouns, entries: [NarrativeEntry]) -> (String, String) {
        guard !entries.isEmpty else {
            return ("No information found.", "No information found.")
        }

        // Sort entries by date (oldest first for chronological narrative)
        let sortedEntries = entries.sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }

        // Group entries by date
        var groupedByDate: [String: [NarrativeEntry]] = [:]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMM yyyy"

        for entry in sortedEntries {
            let key: String
            if let date = entry.date {
                key = dateFormatter.string(from: date)
            } else {
                key = "Unknown Date"
            }
            groupedByDate[key, default: []].append(entry)
        }

        // Build bullet-point narrative grouped by date
        var plainParts: [String] = []
        var htmlParts: [String] = []

        // Sort date keys chronologically
        let sortedDates = groupedByDate.keys.sorted { key1, key2 in
            let date1 = dateFormatter.date(from: key1) ?? .distantPast
            let date2 = dateFormatter.date(from: key2) ?? .distantPast
            return date1 < date2
        }

        for dateKey in sortedDates {
            guard let entriesForDate = groupedByDate[dateKey] else { continue }

            // Combine all content for this date
            let combinedContent = entriesForDate.map { cleanText($0.content) }.joined(separator: " ")

            // Split into sentences
            let sentences = splitIntoSentences(combinedContent)

            // Plain text format
            plainParts.append("• \(dateKey)")
            for sentence in sentences.prefix(5) { // Limit to 5 sentences per date
                plainParts.append("   — \(sentence)")
            }
            plainParts.append("")

            // HTML format
            htmlParts.append("<b>\(dateKey)</b><br>")
            for sentence in sentences.prefix(5) {
                htmlParts.append("&nbsp;&nbsp;&nbsp;&nbsp;— \(sentence)<br>")
            }
            htmlParts.append("<br>")
        }

        let plainText = plainParts.joined(separator: "\n")
        let htmlText = htmlParts.joined()

        return (plainText, htmlText)
    }

    /// Clean text by removing excessive whitespace and normalizing
    private func cleanText(_ text: String) -> String {
        var cleaned = text.replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // Collapse multiple spaces
        while cleaned.contains("  ") {
            cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
        }
        return cleaned
    }

    /// Split text into sentences for bullet points
    private func splitIntoSentences(_ text: String) -> [String] {
        guard !text.isEmpty else { return [] }

        // Split on sentence-ending punctuation or semicolons
        let pattern = #"(?<=[.!?])\s+|;\s*(?=[A-Z])"#
        let parts: [String]
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let nsText = text as NSString
            var results: [String] = []
            var lastEnd = 0

            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
            for match in matches {
                let range = NSRange(location: lastEnd, length: match.range.location - lastEnd)
                let part = nsText.substring(with: range).trimmingCharacters(in: .whitespaces)
                if !part.isEmpty && part.count > 3 {
                    results.append(part)
                }
                lastEnd = match.range.location + match.range.length
            }

            // Add remaining text
            if lastEnd < nsText.length {
                let remaining = nsText.substring(from: lastEnd).trimmingCharacters(in: .whitespaces)
                if !remaining.isEmpty && remaining.count > 3 {
                    results.append(remaining)
                }
            }

            parts = results
        } else {
            // Fallback: simple split
            parts = text.components(separatedBy: ". ").filter { $0.count > 3 }
        }

        // Clean up each sentence
        return parts.map { sentence in
            var s = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            // Remove trailing period if present
            if s.hasSuffix(".") { s = String(s.dropLast()) }
            return s
        }.filter { !$0.isEmpty }
    }

    private func resetReferenceTracker() { referenceCounter = 0; references = [:] }

    private func getDateRangeInfo(entries: [NarrativeEntry], period: NarrativePeriod) -> String {
        let dates = entries.compactMap { $0.date }
        guard let earliest = dates.min(), let latest = dates.max() else { return "No dated entries" }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return "\(formatter.string(from: earliest)) - \(formatter.string(from: latest))"
    }
}

extension NarrativeEntry {
    init?(from dict: [String: Any]) {
        guard let content = dict["content"] as? String ?? dict["text"] as? String else { return nil }
        var date: Date? = nil
        if let dateVal = dict["date"] {
            if let d = dateVal as? Date { date = d }
            else if let dateStr = dateVal as? String {
                let formatter = DateFormatter()
                for format in ["yyyy-MM-dd", "dd/MM/yyyy"] {
                    formatter.dateFormat = format
                    if let d = formatter.date(from: String(dateStr.prefix(10))) { date = d; break }
                }
            }
        }
        self.date = date; self.content = content; self.type = dict["type"] as? String ?? ""; self.originator = dict["originator"] as? String ?? ""
    }
}
