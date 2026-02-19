//
//  LicenseManager.swift
//  MyPsychAdmin
//
//  License validation system matching desktop app
//  Uses ECDSA (P256/NIST256p) for cryptographic verification
//

import Foundation
import CryptoKit
import UIKit

// MARK: - License Info
struct LicenseInfo: Codable {
    let customer: String
    let expires: String
    let type: String
    let issued: String
    var platform: String?
    var deviceId: String?

    enum CodingKeys: String, CodingKey {
        case customer, expires, type, issued, platform
        case deviceId = "device_id"
    }

    var expiryDate: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: expires)
    }

    var isExpired: Bool {
        guard let expiry = expiryDate else { return true }
        return expiry < Date()
    }

    var formattedExpiry: String {
        guard let expiry = expiryDate else { return expires }
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: expiry)
    }

    var typeDisplayName: String {
        switch type.lowercased() {
        case "trial": return "Trial"
        case "standard": return "Standard"
        case "professional": return "Professional"
        case "lifetime": return "Lifetime"
        default: return type.capitalized
        }
    }

    var isValidPlatform: Bool {
        guard let p = platform?.lowercased() else { return true }
        return p == "ios" || p == "universal"
    }

    func isValidDevice(currentDeviceId: String) -> Bool {
        guard let boundDeviceId = deviceId else { return true }
        return boundDeviceId == currentDeviceId
    }
}

// MARK: - Activation Data
struct ActivationData: Codable {
    let machineId: String
    let licenseHash: String
    let activatedAt: String
    let customer: String
    let expires: String
    let type: String
}

// MARK: - License Result
enum LicenseResult {
    case valid(LicenseInfo)
    case invalid(String)
    case notFound
    case expired(LicenseInfo)
    case wrongDevice(LicenseInfo)
    case wrongPlatform(LicenseInfo)
}

// MARK: - License Manager
class LicenseManager {
    static let shared = LicenseManager()

    // ECDSA Public Key (P256/NIST256p) - same as desktop app
    private let publicKeyPEM = """
    -----BEGIN PUBLIC KEY-----
    MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEGga/zcEERaFr89tGx6YXDvUKZHTCu+sOHJNHQ+pR
    rsFmq1lYpyqxcOBFxLQfmXHsIRHoVvL6F7ul5/0rN/hyvA==
    -----END PUBLIC KEY-----
    """

    private var cachedLicenseInfo: LicenseInfo?

    private init() {}

    // MARK: - File Paths
    private var licenseURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("MyPsychAdmin", isDirectory: true)
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        return appFolder.appendingPathComponent("license.key")
    }

    private var activationURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("MyPsychAdmin", isDirectory: true)
        return appFolder.appendingPathComponent("activation.json")
    }

    // MARK: - Machine ID
    func getMachineId() -> String {
        // Use identifierForVendor for iOS (unique per app/vendor combination)
        if let vendorId = UIDevice.current.identifierForVendor?.uuidString {
            // Hash it to match desktop format (32 char hex)
            let data = Data(vendorId.utf8)
            let hash = SHA256.hash(data: data)
            return hash.prefix(16).map { String(format: "%02x", $0) }.joined()
        }
        return "unknown-device"
    }

    // MARK: - License Validation
    func isLicenseValid() -> LicenseResult {
        // Load license token
        guard let token = loadLicense() else {
            return .notFound
        }

        // Verify signature and get payload
        guard let licenseInfo = verifySignedLicense(token: token) else {
            return .invalid("Invalid license signature")
        }

        // Check platform
        if !licenseInfo.isValidPlatform {
            return .wrongPlatform(licenseInfo)
        }

        // Check expiry
        if licenseInfo.isExpired {
            return .expired(licenseInfo)
        }

        // Check device binding (from license itself)
        let currentDevice = getMachineId()
        if !licenseInfo.isValidDevice(currentDeviceId: currentDevice) {
            return .wrongDevice(licenseInfo)
        }

        cachedLicenseInfo = licenseInfo
        return .valid(licenseInfo)
    }

    // MARK: - Activate License
    func activateLicense(key: String) -> (success: Bool, message: String, info: LicenseInfo?) {
        let cleanKey = key.trimmingCharacters(in: .whitespacesAndNewlines)

        // Verify the license
        guard let licenseInfo = verifySignedLicense(token: cleanKey) else {
            return (false, "Invalid license key. Please check and try again.", nil)
        }

        // Check platform
        if !licenseInfo.isValidPlatform {
            let platformName = licenseInfo.platform ?? "unknown"
            return (false, "This license is for \(platformName) only, not iOS.", licenseInfo)
        }

        // Check device binding
        let currentDevice = getMachineId()
        if !licenseInfo.isValidDevice(currentDeviceId: currentDevice) {
            return (false, "This license is locked to a different device. Contact support to transfer your license.", licenseInfo)
        }

        // Check expiry
        if licenseInfo.isExpired {
            return (false, "This license has expired on \(licenseInfo.formattedExpiry).", licenseInfo)
        }

        // Save the license
        do {
            try cleanKey.write(to: licenseURL, atomically: true, encoding: .utf8)
        } catch {
            return (false, "Failed to save license: \(error.localizedDescription)", nil)
        }

        // Create activation data
        let machineId = getMachineId()
        let licenseHash = SHA256.hash(data: Data(cleanKey.utf8))
            .map { String(format: "%02x", $0) }.joined()

        let formatter = ISO8601DateFormatter()
        let activation = ActivationData(
            machineId: machineId,
            licenseHash: licenseHash,
            activatedAt: formatter.string(from: Date()),
            customer: licenseInfo.customer,
            expires: licenseInfo.expires,
            type: licenseInfo.type
        )

        // Save activation data
        do {
            let data = try JSONEncoder().encode(activation)
            try data.write(to: activationURL)
        } catch {
            return (false, "Failed to save activation: \(error.localizedDescription)", nil)
        }

        cachedLicenseInfo = licenseInfo

        // Send notification email (fire and forget)
        sendActivationNotification(licenseInfo: licenseInfo, machineId: machineId)

        return (true, "License activated successfully!", licenseInfo)
    }

    // MARK: - Deactivate License
    func deactivateLicense() -> Bool {
        do {
            try? FileManager.default.removeItem(at: licenseURL)
            try? FileManager.default.removeItem(at: activationURL)
            cachedLicenseInfo = nil
            return true
        }
    }

    // MARK: - Get License Info
    func getLicenseInfo() -> LicenseInfo? {
        if let cached = cachedLicenseInfo {
            return cached
        }

        if case .valid(let info) = isLicenseValid() {
            return info
        }

        return nil
    }

    // MARK: - Private Methods

    private func loadLicense() -> String? {
        try? String(contentsOf: licenseURL, encoding: .utf8)
    }

    private func loadActivationData() -> ActivationData? {
        guard let data = try? Data(contentsOf: activationURL) else { return nil }
        return try? JSONDecoder().decode(ActivationData.self, from: data)
    }

    private func verifySignedLicense(token: String) -> LicenseInfo? {
        // Clean the token (remove whitespace/newlines that might be added during copy-paste)
        let cleanToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: " ", with: "")

        // Decode base64
        guard let rawData = Data(base64Encoded: cleanToken) else {
            print("License: Failed to decode base64")
            return nil
        }

        // Find "||" separator in binary data (must be binary search, not string)
        let separator = Data("||".utf8)
        guard let separatorRange = rawData.range(of: separator) else {
            print("License: No || separator found in data")
            return nil
        }

        let payloadData = rawData[..<separatorRange.lowerBound]
        let signatureData = rawData[separatorRange.upperBound...]

        print("License: Payload size: \(payloadData.count), Signature size: \(signatureData.count)")

        // Verify signature (signature should be 64 bytes for P256)
        guard verifyECDSASignature(payload: Data(payloadData), signature: Data(signatureData)) else {
            print("License: Signature verification failed")
            return nil
        }

        // Parse payload
        return parseLicensePayload(Data(payloadData))
    }

    private func parseLicensePayload(_ data: Data) -> LicenseInfo? {
        do {
            return try JSONDecoder().decode(LicenseInfo.self, from: data)
        } catch {
            print("License: Failed to parse payload: \(error)")
            return nil
        }
    }

    private func verifyECDSASignature(payload: Data, signature: Data) -> Bool {
        // Parse public key from PEM
        guard let publicKey = parsePublicKeyFromPEM() else {
            print("License: Failed to parse public key")
            return false
        }

        // Try to verify with the signature
        do {
            // The signature from Python ecdsa library is in raw format (r||s)
            let ecdsaSignature = try P256.Signing.ECDSASignature(rawRepresentation: signature)
            return publicKey.isValidSignature(ecdsaSignature, for: payload)
        } catch {
            // Try DER format
            do {
                let ecdsaSignature = try P256.Signing.ECDSASignature(derRepresentation: signature)
                return publicKey.isValidSignature(ecdsaSignature, for: payload)
            } catch {
                print("License: Signature format error: \(error)")
                return false
            }
        }
    }

    private func parsePublicKeyFromPEM() -> P256.Signing.PublicKey? {
        // Extract base64 content from PEM
        let lines = publicKeyPEM.components(separatedBy: "\n")
        let base64Content = lines.filter {
            !$0.hasPrefix("-----") && !$0.isEmpty
        }.joined()

        guard let derData = Data(base64Encoded: base64Content) else {
            return nil
        }

        // Parse the SPKI format (SubjectPublicKeyInfo)
        // For P256, the raw key is the last 65 bytes (04 || x || y)
        do {
            return try P256.Signing.PublicKey(derRepresentation: derData)
        } catch {
            print("License: Failed to create public key: \(error)")
            return nil
        }
    }

    // MARK: - Activation Notification
    private func sendActivationNotification(licenseInfo: LicenseInfo, machineId: String) {
        // Fire and forget - don't block UI
        Task {
            let deviceName = await UIDevice.current.name
            let systemVersion = await UIDevice.current.systemVersion

            let message = """
            iOS App Activation

            Customer: \(licenseInfo.customer)
            License Type: \(licenseInfo.type)
            Expires: \(licenseInfo.expires)
            Machine ID: \(machineId)
            Device: \(deviceName)
            iOS Version: \(systemVersion)
            Time: \(Date())
            """

            // Use Web3Forms API (same as desktop)
            let url = URL(string: "https://api.web3forms.com/submit")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: Any] = [
                "access_key": "41cfe486-d50d-4f89-aa54-7aabdd252fef",
                "subject": "MyPsychAdmin iOS Activation - \(licenseInfo.customer)",
                "from_name": "MyPsychAdmin iOS",
                "message": message
            ]

            request.httpBody = try? JSONSerialization.data(withJSONObject: body)

            _ = try? await URLSession.shared.data(for: request)
        }
    }
}
