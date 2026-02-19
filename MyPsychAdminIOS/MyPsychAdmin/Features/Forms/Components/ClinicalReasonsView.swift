//
//  ClinicalReasonsView.swift
//  MyPsychAdmin
//
//  Shared clinical reasons component with checkboxes and structured input
//  Used by A3, A4, A7, A8, H5, CTO1, CTO3, CTO5, CTO7, M2
//

import SwiftUI

// Data model is in Models/Forms/ClinicalDataModels.swift

// MARK: - Clinical Reasons View
struct ClinicalReasonsView: View {
    @Binding var data: ClinicalReasonsData
    var showInformalSection: Bool = true
    var formType: ClinicalFormType = .assessment

    enum ClinicalFormType {
        case assessment  // A3, A4 - "assessment"
        case treatment   // A7, A8 - "treatment"
        case renewal     // H5 - "renewal"
        case cto         // CTO forms
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Generated Text Preview
            generatedTextSection

            Divider()

            // Diagnosis Section
            diagnosisSection

            Divider()

            // Nature Section
            natureSection

            Divider()

            // Degree Section
            degreeSection

            Divider()

            // Health Section
            healthSection

            Divider()

            // Safety Section
            safetySection

            if showInformalSection {
                Divider()
                informalSection
            }
        }
    }

    // MARK: - Sections

    private var generatedTextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Generated Text", systemImage: "text.quote")
                .font(.headline)
                .foregroundColor(.blue)

            Text(data.generatedText.isEmpty ? "Select options below to generate clinical text..." : data.generatedText)
                .font(.subheadline)
                .foregroundColor(data.generatedText.isEmpty ? .secondary : .primary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
    }

    private var diagnosisSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Mental Disorder", systemImage: "brain.head.profile")
                .font(.headline)
                .foregroundColor(.green)

            FormTextField(label: "Primary Diagnosis (ICD-10)", text: $data.primaryDiagnosis, placeholder: "e.g., F20.0 Paranoid schizophrenia")
            FormTextField(label: "Secondary Diagnosis", text: $data.secondaryDiagnosis, placeholder: "Optional")
        }
    }

    private var natureSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $data.natureEnabled) {
                Label("Nature of Mental Disorder", systemImage: "waveform.path")
                    .font(.headline)
                    .foregroundColor(.blue)
            }

            if data.natureEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Relapsing and remitting", isOn: $data.natureRelapsing)
                    Toggle("Treatment resistant", isOn: $data.natureTreatmentResistant)
                    Toggle("Chronic and enduring", isOn: $data.natureChronic)
                }
                .padding(.leading)
                .font(.subheadline)
            }
        }
    }

    private var degreeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $data.degreeEnabled) {
                Label("Degree of Mental Disorder", systemImage: "chart.bar")
                    .font(.headline)
                    .foregroundColor(.purple)
            }

            if data.degreeEnabled {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Severity: \(severityLabel)")
                            .font(.subheadline)
                        Slider(value: Binding(
                            get: { Double(data.degreeSeverity) },
                            set: { data.degreeSeverity = Int($0) }
                        ), in: 1...4, step: 1)
                        HStack {
                            Text("Some").font(.caption2)
                            Spacer()
                            Text("Several").font(.caption2)
                            Spacer()
                            Text("Many").font(.caption2)
                            Spacer()
                            Text("Overwhelming").font(.caption2)
                        }
                        .foregroundColor(.secondary)
                    }

                    FormTextField(label: "Symptom Details", text: $data.degreeSymptoms, placeholder: "Describe specific symptoms")
                }
                .padding(.leading)
            }
        }
    }

    private var severityLabel: String {
        switch data.degreeSeverity {
        case 1: return "Some symptoms"
        case 2: return "Several symptoms"
        case 3: return "Many symptoms"
        case 4: return "Overwhelming symptoms"
        default: return "Several symptoms"
        }
    }

    private var healthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $data.healthEnabled) {
                Label("Necessity - Health", systemImage: "heart.text.square")
                    .font(.headline)
                    .foregroundColor(.red)
            }

            if data.healthEnabled {
                VStack(alignment: .leading, spacing: 12) {
                    // Mental Health
                    Toggle(isOn: $data.mentalHealthEnabled) {
                        Text("Mental Health")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    if data.mentalHealthEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Poor compliance with treatment", isOn: $data.mentalHealthPoorCompliance)
                            Toggle("Limited insight into condition", isOn: $data.mentalHealthLimitedInsight)
                        }
                        .padding(.leading)
                        .font(.subheadline)
                    }

                    // Physical Health
                    Toggle(isOn: $data.physicalHealthEnabled) {
                        Text("Physical Health")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    if data.physicalHealthEnabled {
                        FormTextField(label: "Details", text: $data.physicalHealthDetails, placeholder: "Describe physical health concerns")
                            .padding(.leading)
                    }
                }
                .padding(.leading)
            }
        }
    }

    private var safetySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $data.safetyEnabled) {
                Label("Necessity - Safety", systemImage: "shield.checkered")
                    .font(.headline)
                    .foregroundColor(.orange)
            }

            if data.safetyEnabled {
                VStack(alignment: .leading, spacing: 16) {
                    // Safety to Self
                    safetySelfSection

                    // Safety to Others
                    safetyOthersSection
                }
                .padding(.leading)
            }
        }
    }

    private var safetySelfSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $data.safetySelfEnabled) {
                Text("Risk to Self")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            if data.safetySelfEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    RiskRow(label: "Self-neglect", historical: $data.selfNeglectHistorical, current: $data.selfNeglectCurrent)
                    RiskRow(label: "Risky situations", historical: $data.selfRiskyHistorical, current: $data.selfRiskyCurrent)
                    RiskRow(label: "Self-harm", historical: $data.selfHarmHistorical, current: $data.selfHarmCurrent)
                }
                .padding(.leading)
            }
        }
    }

    private var safetyOthersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $data.safetyOthersEnabled) {
                Text("Risk to Others")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            if data.safetyOthersEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    RiskRow(label: "Violence", historical: $data.violenceHistorical, current: $data.violenceCurrent)
                    RiskRow(label: "Verbal aggression", historical: $data.verbalAggressionHistorical, current: $data.verbalAggressionCurrent)
                    RiskRow(label: "Sexual violence", historical: $data.sexualViolenceHistorical, current: $data.sexualViolenceCurrent)
                    RiskRow(label: "Stalking", historical: $data.stalkingHistorical, current: $data.stalkingCurrent)
                    RiskRow(label: "Arson", historical: $data.arsonHistorical, current: $data.arsonCurrent)
                }
                .padding(.leading)
            }
        }
    }

    private var informalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $data.informalNotAppropriateEnabled) {
                Label("Informal Admission Not Appropriate", systemImage: "xmark.circle")
                    .font(.headline)
                    .foregroundColor(.gray)
            }

            if data.informalNotAppropriateEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Tried informal - failed", isOn: $data.informalTriedFailed)
                    Toggle("Lack of insight", isOn: $data.informalLackInsight)
                    Toggle("Compliance issues", isOn: $data.informalComplianceIssues)
                    Toggle("Needs MHA supervision", isOn: $data.informalNeedsMHASupervision)
                }
                .padding(.leading)
                .font(.subheadline)
            }
        }
    }
}

// MARK: - Risk Row Component
struct RiskRow: View {
    let label: String
    @Binding var historical: Bool
    @Binding var current: Bool

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .frame(width: 120, alignment: .leading)

            Spacer()

            Toggle("Hist", isOn: $historical)
                .toggleStyle(.button)
                .font(.caption)

            Toggle("Curr", isOn: $current)
                .toggleStyle(.button)
                .font(.caption)
                .tint(.red)
        }
    }
}

// MARK: - Preview
#Preview {
    ScrollView {
        ClinicalReasonsView(data: .constant(ClinicalReasonsData()))
            .padding()
    }
}
