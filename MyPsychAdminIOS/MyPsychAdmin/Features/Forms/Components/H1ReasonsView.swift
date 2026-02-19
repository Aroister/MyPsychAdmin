//
//  H1ReasonsView.swift
//  MyPsychAdmin
//
//  Simplified reasons view for H1 (Section 5(2) holding power)
//

import SwiftUI

// Data model is in Models/Forms/ClinicalDataModels.swift

// MARK: - H1 Reasons View
struct H1ReasonsView: View {
    @Binding var data: H1ReasonsData

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Generated Text Preview
            VStack(alignment: .leading, spacing: 8) {
                Label("Generated Text", systemImage: "text.quote")
                    .font(.headline)
                    .foregroundColor(.blue)

                Text(data.generatedText.isEmpty ? "Select options below to generate text..." : data.generatedText)
                    .font(.subheadline)
                    .foregroundColor(data.generatedText.isEmpty ? .secondary : .primary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }

            Divider()

            // Diagnosis
            VStack(alignment: .leading, spacing: 12) {
                Label("Diagnosis", systemImage: "brain.head.profile")
                    .font(.headline)
                    .foregroundColor(.green)

                FormTextField(label: "Primary Diagnosis (ICD-10)", text: $data.diagnosis, placeholder: "e.g., F20.0 Paranoid schizophrenia")
            }

            Divider()

            // Reasons
            VStack(alignment: .leading, spacing: 12) {
                Label("Reasons for Detention", systemImage: "exclamationmark.triangle")
                    .font(.headline)
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Refusing to remain in hospital", isOn: $data.refusingToRemain)
                    Toggle("Very unwell - requires urgent assessment", isOn: $data.veryUnwell)
                    Toggle("Acute deterioration", isOn: $data.acuteDeteriouration)
                }
                .font(.subheadline)
            }

            Divider()

            // Risk
            VStack(alignment: .leading, spacing: 12) {
                Label("Significant Risk To", systemImage: "shield.checkered")
                    .font(.headline)
                    .foregroundColor(.red)

                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Self", isOn: $data.riskToSelf)
                    Toggle("Others", isOn: $data.riskToOthers)
                }
                .font(.subheadline)
            }
        }
    }
}

#Preview {
    ScrollView {
        H1ReasonsView(data: .constant(H1ReasonsData()))
            .padding()
    }
}
