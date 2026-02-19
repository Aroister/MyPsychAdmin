//
//  ActivationView.swift
//  MyPsychAdmin
//
//  License activation screen matching desktop app
//

import SwiftUI

struct ActivationView: View {
    @Binding var isActivated: Bool
    @State private var licenseKey = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @State private var licenseInfo: LicenseInfo?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Logo/Header
                    VStack(spacing: 12) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue)

                        Text("MyPsychAdmin")
                            .font(.largeTitle.bold())

                        Text("Professional Psychiatric Administration")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 40)

                    // Activation Card
                    VStack(spacing: 20) {
                        VStack(spacing: 8) {
                            Image(systemName: "key.fill")
                                .font(.title)
                                .foregroundStyle(.orange)

                            Text("License Activation")
                                .font(.headline)

                            Text("Enter your license key to activate the app")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        // License Key Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("License Key")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)

                            TextEditor(text: $licenseKey)
                                .font(.system(.body, design: .monospaced))
                                .frame(height: 100)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(.systemGray4), lineWidth: 1)
                                )
                        }

                        // Error Message
                        if let error = errorMessage {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.red)
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        // Activate Button
                        Button {
                            activateLicense()
                        } label: {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "checkmark.seal.fill")
                                    Text("Activate License")
                                }
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(licenseKey.isEmpty ? Color.gray : Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(licenseKey.isEmpty || isLoading)
                    }
                    .padding(24)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                    .padding(.horizontal)

                    // Help Section
                    VStack(spacing: 12) {
                        Text("Need a license?")
                            .font(.subheadline.bold())

                        Text("Contact us to purchase a license for MyPsychAdmin.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        Link(destination: URL(string: "mailto:info@mypsychadmin.com?subject=License%20Request")!) {
                            HStack {
                                Image(systemName: "envelope.fill")
                                Text("Contact Support")
                            }
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                        }
                    }
                    .padding()

                    // Device Info
                    VStack(spacing: 4) {
                        Text("Device ID")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(LicenseManager.shared.getMachineId())
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 20)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
        }
        .alert("License Activated", isPresented: $showSuccess) {
            Button("Continue") {
                isActivated = true
            }
        } message: {
            if let info = licenseInfo {
                Text("Welcome, \(info.customer)!\n\nYour \(info.typeDisplayName) license is valid until \(info.formattedExpiry).")
            }
        }
    }

    private func activateLicense() {
        isLoading = true
        errorMessage = nil

        // Run activation on background thread
        Task {
            let result = LicenseManager.shared.activateLicense(key: licenseKey)

            await MainActor.run {
                isLoading = false

                if result.success {
                    licenseInfo = result.info
                    showSuccess = true
                } else {
                    errorMessage = result.message
                }
            }
        }
    }
}

// MARK: - License Status View (for Settings)
struct LicenseStatusView: View {
    @State private var licenseInfo: LicenseInfo?
    @State private var showDeactivateConfirm = false
    @State private var isDeactivated = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if let info = licenseInfo {
                Section("License Details") {
                    LabeledContent("Customer", value: info.customer)
                    LabeledContent("Type", value: info.typeDisplayName)
                    LabeledContent("Expires", value: info.formattedExpiry)
                    LabeledContent("Status") {
                        HStack {
                            Image(systemName: info.isExpired ? "xmark.circle.fill" : "checkmark.circle.fill")
                                .foregroundStyle(info.isExpired ? .red : .green)
                            Text(info.isExpired ? "Expired" : "Active")
                        }
                    }
                }

                Section("Device") {
                    LabeledContent("Device ID", value: LicenseManager.shared.getMachineId())
                        .font(.system(.body, design: .monospaced))
                }

                Section {
                    Button(role: .destructive) {
                        showDeactivateConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "xmark.circle")
                            Text("Deactivate License")
                        }
                    }
                }
            } else {
                Section {
                    ContentUnavailableView {
                        Label("No License", systemImage: "key.slash")
                    } description: {
                        Text("No active license found on this device.")
                    }
                }
            }
        }
        .navigationTitle("License")
        .onAppear {
            licenseInfo = LicenseManager.shared.getLicenseInfo()
        }
        .alert("Deactivate License?", isPresented: $showDeactivateConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Deactivate", role: .destructive) {
                _ = LicenseManager.shared.deactivateLicense()
                isDeactivated = true
            }
        } message: {
            Text("This will remove the license from this device. You'll need to re-enter your license key to use the app.")
        }
        .onChange(of: isDeactivated) { _, newValue in
            if newValue {
                // Force app restart by dismissing and notifying
                dismiss()
            }
        }
    }
}

#Preview {
    ActivationView(isActivated: .constant(false))
}
