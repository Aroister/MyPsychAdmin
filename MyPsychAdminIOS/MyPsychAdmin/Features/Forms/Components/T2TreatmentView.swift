//
//  T2TreatmentView.swift
//  MyPsychAdmin
//
//  Treatment/Medication entry for T2 form (Certificate of Consent to Treatment)
//

import SwiftUI

// Data models are in FormComponents.swift (ClinicalReasonsData, T2MedicationEntry, T2TreatmentData)

// MARK: - T2 Treatment View
struct T2TreatmentView: View {
    @Binding var data: T2TreatmentData

    @State private var isEditingText: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Generated Text Preview (Editable)
            t2GeneratedTextSection

            Divider()

            // Regular Medications
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Regular Medications", systemImage: "pills")
                        .font(.headline)
                        .foregroundColor(.green)

                    Spacer()

                    Button {
                        data.regularMedications.append(T2MedicationEntry())
                    } label: {
                        Label("Add", systemImage: "plus.circle.fill")
                            .font(.subheadline)
                    }
                }

                if data.regularMedications.isEmpty {
                    Text("No regular medications added")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach($data.regularMedications) { $med in
                        T2MedicationRow(medication: $med) {
                            data.regularMedications.removeAll { $0.id == med.id }
                        }
                    }
                }
            }

            Divider()

            // PRN Medications
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("PRN Medications", systemImage: "pills.circle")
                        .font(.headline)
                        .foregroundColor(.orange)

                    Spacer()

                    Button {
                        data.prnMedications.append(T2MedicationEntry())
                    } label: {
                        Label("Add", systemImage: "plus.circle.fill")
                            .font(.subheadline)
                    }
                }

                if data.prnMedications.isEmpty {
                    Text("No PRN medications added")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach($data.prnMedications) { $med in
                        T2MedicationRow(medication: $med) {
                            data.prnMedications.removeAll { $0.id == med.id }
                        }
                    }
                }
            }

            // Common Medications Quick Add
            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Add Common Medications")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        T2QuickAddButton(name: "Olanzapine") { addRegular($0) }
                        T2QuickAddButton(name: "Risperidone") { addRegular($0) }
                        T2QuickAddButton(name: "Aripiprazole") { addRegular($0) }
                        T2QuickAddButton(name: "Haloperidol") { addRegular($0) }
                        T2QuickAddButton(name: "Clozapine") { addRegular($0) }
                        T2QuickAddButton(name: "Quetiapine") { addRegular($0) }
                        T2QuickAddButton(name: "Lorazepam") { addPRN($0) }
                        T2QuickAddButton(name: "Diazepam") { addPRN($0) }
                        T2QuickAddButton(name: "Promethazine") { addPRN($0) }
                    }
                }
            }
        }
    }

    private func addRegular(_ name: String) {
        data.regularMedications.append(T2MedicationEntry(name: name))
    }

    private func addPRN(_ name: String) {
        data.prnMedications.append(T2MedicationEntry(name: name))
    }

    private var t2GeneratedTextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Treatment Description", systemImage: "text.quote")
                    .font(.headline)
                    .foregroundColor(.blue)

                Spacer()

                if data.useEditedText {
                    Button {
                        data.useEditedText = false
                        data.editedText = ""
                    } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                }
            }

            if isEditingText || data.useEditedText {
                TextEditor(text: Binding(
                    get: { data.useEditedText ? data.editedText : data.generatedText },
                    set: { newValue in
                        data.editedText = newValue
                        data.useEditedText = true
                    }
                ))
                .font(.subheadline)
                .frame(minHeight: 120)
                .padding(8)
                .background(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue.opacity(0.5), lineWidth: 2)
                )
                .cornerRadius(8)

                HStack {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundColor(.blue)
                    Text("Editing mode - changes will be saved")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Button {
                    isEditingText = false
                } label: {
                    Text("Done Editing")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(data.displayText.isEmpty ? "Add medications below to generate description..." : data.displayText)
                        .font(.subheadline)
                        .foregroundColor(data.generatedText.isEmpty ? .secondary : .primary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .onTapGesture {
                            if !data.useEditedText && !data.generatedText.isEmpty {
                                data.editedText = data.generatedText
                            }
                            isEditingText = true
                        }

                    if !data.generatedText.isEmpty {
                        HStack {
                            Image(systemName: "hand.tap")
                                .foregroundColor(.secondary)
                            Text("Tap to edit")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - T2 Medication Row
struct T2MedicationRow: View {
    @Binding var medication: T2MedicationEntry
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            TextField("Medication name", text: $medication.name)
                .textFieldStyle(.roundedBorder)

            Picker("Dose", selection: $medication.isAboveBNF) {
                Text("BNF").tag(false)
                Text("Above BNF").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(width: 140)

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - T2 Quick Add Button
struct T2QuickAddButton: View {
    let name: String
    var action: (String) -> Void

    var body: some View {
        Button {
            action(name)
        } label: {
            Text(name)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(.systemGray5))
                .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ScrollView {
        T2TreatmentView(data: .constant(T2TreatmentData()))
            .padding()
    }
}
