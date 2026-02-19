//
//  PatientInfo.swift
//  MyPsychAdmin
//

import Foundation

struct PatientInfo: Codable, Equatable {
    var firstName: String = ""
    var lastName: String = ""
    var dateOfBirth: Date?
    var manualAge: Int?  // For forms like H5 where age is entered directly
    var nhsNumber: String = ""
    var hospitalNumber: String = ""
    var gender: Gender = .notSpecified
    var address: String = ""
    var ethnicity: Ethnicity = .notSpecified
    var nationality: String = ""
    var maritalStatus: String = ""
    var occupation: String = ""
    var religion: String = ""
    var gpName: String = ""
    var gpAddress: String = ""

    var fullName: String {
        let name = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        return name
    }

    /// Short name for narrative references: "Mr Doe" or "Ms Smith"
    var shortName: String {
        let title = gender.title
        if title.isEmpty {
            return lastName.isEmpty ? "" : lastName
        }
        return lastName.isEmpty ? "" : "\(title) \(lastName)"
    }

    var age: Int? {
        // Use manual age if set (for H5 forms), otherwise compute from DOB
        if let manual = manualAge { return manual }
        guard let dob = dateOfBirth else { return nil }
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: dob, to: Date())
        return ageComponents.year
    }

    var pronouns: Pronouns {
        switch gender {
        case .male:
            return Pronouns(subject: "he", object: "him", possessive: "his", reflexive: "himself",
                            bePast: "was", bePresent: "is", havePresent: "has")
        case .female:
            return Pronouns(subject: "she", object: "her", possessive: "her", reflexive: "herself",
                            bePast: "was", bePresent: "is", havePresent: "has")
        case .other, .notSpecified:
            return Pronouns(subject: "they", object: "them", possessive: "their", reflexive: "themselves",
                            bePast: "were", bePresent: "are", havePresent: "have")
        }
    }

    var formattedDOB: String {
        guard let dob = dateOfBirth else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: dob)
    }

    /// Generates clinical introduction: "Mr John Smith is a 43 year old Caucasian man who..."
    var clinicalIntroduction: String {
        var parts: [String] = []

        // Title and name (e.g., "Mr John Smith")
        let title = gender.title
        let nameWithTitle = title.isEmpty ? fullName : "\(title) \(fullName)"
        parts.append(nameWithTitle)

        // Age if available
        if let patientAge = age {
            parts.append("is a \(patientAge) year old")
        } else {
            parts.append("is a")
        }

        // Ethnicity (short form)
        let ethnicityDesc = ethnicity.shortDescription
        if !ethnicityDesc.isEmpty {
            parts.append(ethnicityDesc)
        }

        // Gender noun (man/woman/person)
        parts.append(gender.genderNoun)

        return parts.joined(separator: " ")
    }
}

enum Gender: String, Codable, CaseIterable, Identifiable {
    case male = "Male"
    case female = "Female"
    case other = "Other"
    case notSpecified = "Not Specified"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .male: return "Mr"
        case .female: return "Ms"
        case .other, .notSpecified: return ""
        }
    }

    var genderNoun: String {
        switch self {
        case .male: return "man"
        case .female: return "woman"
        case .other, .notSpecified: return "person"
        }
    }
}

// MARK: - Ethnicity
enum Ethnicity: String, Codable, CaseIterable, Identifiable {
    // White
    case whiteBritish = "White British"
    case whiteIrish = "White Irish"
    case whiteOther = "White Other"

    // Mixed
    case mixedWhiteBlackCaribbean = "Mixed White and Black Caribbean"
    case mixedWhiteBlackAfrican = "Mixed White and Black African"
    case mixedWhiteAsian = "Mixed White and Asian"
    case mixedOther = "Mixed Other"

    // Asian
    case asianIndian = "Asian Indian"
    case asianPakistani = "Asian Pakistani"
    case asianBangladeshi = "Asian Bangladeshi"
    case asianChinese = "Asian Chinese"
    case asianOther = "Asian Other"

    // Black
    case blackCaribbean = "Black Caribbean"
    case blackAfrican = "Black African"
    case blackOther = "Black Other"

    // Other
    case arab = "Middle-Eastern"
    case otherEthnic = "Other Ethnic Group"
    case notStated = "Not Stated"
    case notSpecified = "Not Specified"

    var id: String { rawValue }

    var shortDescription: String {
        switch self {
        case .whiteBritish, .whiteIrish, .whiteOther: return "White"
        case .mixedWhiteBlackCaribbean, .mixedWhiteBlackAfrican, .mixedWhiteAsian, .mixedOther: return "mixed heritage"
        case .asianIndian, .asianPakistani, .asianBangladeshi: return "South Asian"
        case .asianChinese: return "Chinese"
        case .asianOther: return "Asian"
        case .blackCaribbean, .blackAfrican, .blackOther: return "Black"
        case .arab: return "Middle-Eastern"
        case .otherEthnic, .notStated, .notSpecified: return ""
        }
    }
}

struct Pronouns {
    let subject: String      // he, she, they
    let object: String       // him, her, them
    let possessive: String   // his, her, their
    let reflexive: String    // himself, herself, themselves
    let bePast: String       // was, was, were (past tense of "to be")
    let bePresent: String    // is, is, are (present tense of "to be")
    let havePresent: String  // has, has, have

    // Capitalized versions
    var Subject: String { subject.capitalized }
    var Object: String { object.capitalized }
    var Possessive: String { possessive.capitalized }
    var Reflexive: String { reflexive.capitalized }
}

// MARK: - Second Practitioner (for joint recommendation forms A3, A7)
struct SecondPractitionerInfo: Codable, Equatable {
    var name: String = ""
    var email: String = ""
    var address: String = ""
    var examinationDate: Date = Date()
}

// MARK: - Nearest Relative (synced across A2, A6, M2)
struct NearestRelativeInfo: Codable, Equatable {
    var name: String = ""
    var address: String = ""
    var relationship: String = ""
}
