//
//  ClinicianDetailsModel.swift
//  MyPsychAdmin
//
//  SwiftData model for persistent clinician profile storage
//

import SwiftData
import Foundation

@Model
final class ClinicianDetailsModel {
    @Attribute(.unique) var id: Int = 1  // Singleton pattern - only one record

    var fullName: String = ""
    var roleTitle: String = ""
    var discipline: String = ""
    var registrationBody: String = ""
    var registrationNumber: String = ""
    var phone: String = ""
    var email: String = ""
    var teamService: String = ""
    var hospitalOrg: String = ""
    var wardDepartment: String = ""
    var signatureBlock: String = ""
    var signatureImageData: Data?

    init() {}

    init(
        fullName: String = "",
        roleTitle: String = "",
        discipline: String = "",
        registrationBody: String = "",
        registrationNumber: String = "",
        phone: String = "",
        email: String = "",
        teamService: String = "",
        hospitalOrg: String = "",
        wardDepartment: String = "",
        signatureBlock: String = "",
        signatureImageData: Data? = nil
    ) {
        self.fullName = fullName
        self.roleTitle = roleTitle
        self.discipline = discipline
        self.registrationBody = registrationBody
        self.registrationNumber = registrationNumber
        self.phone = phone
        self.email = email
        self.teamService = teamService
        self.hospitalOrg = hospitalOrg
        self.wardDepartment = wardDepartment
        self.signatureBlock = signatureBlock
        self.signatureImageData = signatureImageData
    }

    var formattedSignature: String {
        var lines: [String] = []

        if !fullName.isEmpty {
            lines.append(fullName)
        }

        if !roleTitle.isEmpty {
            lines.append(roleTitle)
        }

        if !registrationBody.isEmpty && !registrationNumber.isEmpty {
            lines.append("\(registrationBody): \(registrationNumber)")
        } else if !registrationBody.isEmpty {
            lines.append(registrationBody)
        } else if !registrationNumber.isEmpty {
            lines.append(registrationNumber)
        }

        if !teamService.isEmpty {
            lines.append(teamService)
        }

        if !hospitalOrg.isEmpty {
            lines.append(hospitalOrg)
        }

        return lines.joined(separator: "\n")
    }

    var hasRequiredFields: Bool {
        !fullName.isEmpty && !roleTitle.isEmpty
    }
}

// MARK: - Clinician Info for in-memory use
struct ClinicianInfo: Codable, Equatable {
    var fullName: String = ""
    var roleTitle: String = ""
    var discipline: String = ""
    var registrationBody: String = ""
    var registrationNumber: String = ""
    var phone: String = ""
    var email: String = ""
    var teamService: String = ""
    var hospitalOrg: String = ""
    var wardDepartment: String = ""
    var signatureBlock: String = ""

    init() {}

    init(from model: ClinicianDetailsModel) {
        self.fullName = model.fullName
        self.roleTitle = model.roleTitle
        self.discipline = model.discipline
        self.registrationBody = model.registrationBody
        self.registrationNumber = model.registrationNumber
        self.phone = model.phone
        self.email = model.email
        self.teamService = model.teamService
        self.hospitalOrg = model.hospitalOrg
        self.wardDepartment = model.wardDepartment
        self.signatureBlock = model.signatureBlock
    }
}
