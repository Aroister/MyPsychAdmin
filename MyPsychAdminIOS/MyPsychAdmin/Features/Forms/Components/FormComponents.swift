//
//  FormComponents.swift
//  MyPsychAdmin
//
//  Reusable form field components
//

import SwiftUI

// MARK: - Form Section Card
struct FormSectionCard<Content: View>: View {
    let title: String
    let isActive: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(isActive ? .blue : .primary)

                Spacer()

                Image(systemName: isActive ? "chevron.up" : "chevron.down")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }

            if isActive {
                Divider()
                content()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isActive ? Color.blue.opacity(0.5) : Color(.systemGray4), lineWidth: 1)
        )
    }
}

// MARK: - Form Text Field
struct FormTextField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var keyboardType: UIKeyboardType = .default
    var isRequired: Bool = false
    var hasError: Bool = false
    var fieldId: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(hasError ? .red : .secondary)

                if isRequired {
                    Text("*")
                        .foregroundColor(.red)
                }

                if hasError {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }

            TextField(placeholder.isEmpty ? label : placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .keyboardType(keyboardType)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(hasError ? Color.red : Color.clear, lineWidth: 2)
                )
                .background(hasError ? Color.red.opacity(0.05) : Color.clear)
                .cornerRadius(6)
        }
        .id(fieldId ?? label)
    }
}

// MARK: - Form Text Editor
struct FormTextEditor: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var minHeight: CGFloat = 80
    var isRequired: Bool = false
    var hasError: Bool = false
    var fieldId: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(hasError ? .red : .secondary)

                if isRequired {
                    Text("*")
                        .foregroundColor(.red)
                }

                if hasError {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder.isEmpty ? label : placeholder)
                        .foregroundColor(.gray.opacity(0.5))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 12)
                }

                TextEditor(text: $text)
                    .frame(minHeight: minHeight)
                    .scrollContentBackground(.hidden)
                    .background(hasError ? Color.red.opacity(0.05) : Color(.systemGray6))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(hasError ? Color.red : Color.clear, lineWidth: 2)
                    )
            }
        }
        .id(fieldId ?? label)
    }
}

// MARK: - Form Date Picker
struct FormDatePicker: View {
    let label: String
    @Binding var date: Date
    var includeTime: Bool = false
    var isRequired: Bool = false
    var maxDate: Date? = nil  // If set, prevents selecting dates after this
    var minDate: Date? = nil  // If set, prevents selecting dates before this

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if isRequired {
                    Text("*")
                        .foregroundColor(.red)
                }
            }

            if let min = minDate, let max = maxDate {
                DatePicker(
                    "",
                    selection: $date,
                    in: min...max,
                    displayedComponents: includeTime ? [.date, .hourAndMinute] : [.date]
                )
                .labelsHidden()
                .datePickerStyle(.compact)
            } else if let max = maxDate {
                DatePicker(
                    "",
                    selection: $date,
                    in: ...max,
                    displayedComponents: includeTime ? [.date, .hourAndMinute] : [.date]
                )
                .labelsHidden()
                .datePickerStyle(.compact)
            } else if let min = minDate {
                DatePicker(
                    "",
                    selection: $date,
                    in: min...,
                    displayedComponents: includeTime ? [.date, .hourAndMinute] : [.date]
                )
                .labelsHidden()
                .datePickerStyle(.compact)
            } else {
                DatePicker(
                    "",
                    selection: $date,
                    displayedComponents: includeTime ? [.date, .hourAndMinute] : [.date]
                )
                .labelsHidden()
                .datePickerStyle(.compact)
            }
        }
    }
}

// MARK: - Form Time Picker
struct FormTimePicker: View {
    let label: String
    @Binding var date: Date
    var isRequired: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                if isRequired {
                    Text("*")
                        .foregroundColor(.red)
                }
            }
            DatePicker(
                "",
                selection: $date,
                displayedComponents: [.hourAndMinute]
            )
            .labelsHidden()
            .datePickerStyle(.compact)
        }
    }
}

// MARK: - Form Optional Date Picker
struct FormOptionalDatePicker: View {
    let label: String
    @Binding var date: Date?
    var includeTime: Bool = false
    var maxDate: Date? = nil  // If set, prevents selecting dates after this
    var minDate: Date? = nil  // If set, prevents selecting dates before this
    var defaultDate: Date? = nil  // If set, used as initial value when toggled on

    @State private var hasDate: Bool = false

    private var dateBinding: Binding<Date> {
        Binding(
            get: { date ?? defaultDate ?? Date() },
            set: { date = $0 }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(label, isOn: $hasDate)
                .font(.subheadline)

            if hasDate {
                if let min = minDate, let max = maxDate {
                    DatePicker("", selection: dateBinding, in: min...max,
                               displayedComponents: includeTime ? [.date, .hourAndMinute] : [.date])
                        .labelsHidden()
                        .datePickerStyle(.compact)
                } else if let max = maxDate {
                    DatePicker("", selection: dateBinding, in: ...max,
                               displayedComponents: includeTime ? [.date, .hourAndMinute] : [.date])
                        .labelsHidden()
                        .datePickerStyle(.compact)
                } else if let min = minDate {
                    DatePicker("", selection: dateBinding, in: min...,
                               displayedComponents: includeTime ? [.date, .hourAndMinute] : [.date])
                        .labelsHidden()
                        .datePickerStyle(.compact)
                } else {
                    DatePicker("", selection: dateBinding,
                               displayedComponents: includeTime ? [.date, .hourAndMinute] : [.date])
                        .labelsHidden()
                        .datePickerStyle(.compact)
                }
            }
        }
        .onAppear {
            hasDate = date != nil
        }
        .onChange(of: hasDate) { _, newValue in
            if newValue && date == nil {
                date = defaultDate ?? Date()
            } else if !newValue {
                date = nil
            }
        }
    }
}

// MARK: - Form Toggle
struct FormToggle: View {
    let label: String
    @Binding var isOn: Bool
    var description: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(label, isOn: $isOn)
                .font(.subheadline)

            if let description = description {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Form Picker
struct FormPicker<T: Hashable & Identifiable & CustomStringConvertible>: View {
    let label: String
    @Binding var selection: T
    let options: [T]
    var isRequired: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if isRequired {
                    Text("*")
                        .foregroundColor(.red)
                }
            }

            Picker("", selection: $selection) {
                ForEach(options) { option in
                    Text(option.description).tag(option)
                }
            }
            .pickerStyle(.menu)
        }
    }
}

// MARK: - Form Section Header
struct FormSectionHeader: View {
    let title: String
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            if let systemImage = systemImage {
                Image(systemName: systemImage)
                    .foregroundColor(.blue)
            }

            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
        }
        .padding(.top, 8)
    }
}

// MARK: - Form Divider
struct FormDivider: View {
    var body: some View {
        Divider()
            .padding(.vertical, 8)
    }
}

// MARK: - Form Validation Error View
struct FormValidationErrorView: View {
    let errors: [FormValidationError]
    var onErrorTap: ((FormValidationError) -> Void)? = nil

    var body: some View {
        if !errors.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(errors) { error in
                    if let onTap = onErrorTap {
                        Button {
                            onTap(error)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.caption)

                                Text(error.message)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.leading)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundColor(.red.opacity(0.6))
                                    .font(.caption2)
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
                                .font(.caption)

                            Text(error.message)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

// MARK: - Form Action Button
struct FormActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(color)
    }
}

// MARK: - Form Preview Card
struct FormPreviewCard: View {
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            Text(content.isEmpty ? "Not entered" : content)
                .font(.subheadline)
                .foregroundColor(content.isEmpty ? .secondary : .primary)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Custom String Convertible Extensions
extension Gender: CustomStringConvertible {
    var description: String { rawValue }
}

extension NRConsultationStatus: CustomStringConvertible {
    var description: String { rawValue }
}

extension PreviousAcquaintanceType: CustomStringConvertible {
    var description: String { rawValue }
}

extension DoctorStatus: CustomStringConvertible {
    var description: String { rawValue }
}

extension CurrentDetentionSection: CustomStringConvertible {
    var description: String { rawValue }
}

extension RenewalPeriod: CustomStringConvertible {
    var description: String { rawValue }
}

extension CTOExtensionPeriod: CustomStringConvertible {
    var description: String { rawValue }
}

extension RestrictionOrderType: CustomStringConvertible {
    var description: String { rawValue }
}

extension LeaveType: CustomStringConvertible {
    var description: String { rawValue }
}

extension EscortType: CustomStringConvertible {
    var description: String { rawValue }
}

extension RiskLevel: CustomStringConvertible {
    var description: String { rawValue }
}

extension SecurityLevel: CustomStringConvertible {
    var description: String { rawValue }
}

extension ASRRecommendation: CustomStringConvertible {
    var description: String { rawValue }
}

// MARK: - Section Navigation Button (for NavigationSplitView style forms)
struct SectionNavButton: View {
    let title: String
    let icon: String
    let isActive: Bool
    let preview: String
    let color: Color
    var isComplete: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(isActive ? .white : (isComplete ? .green : color))
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline).fontWeight(.medium).foregroundColor(isActive ? .white : .primary)
                    Text(preview).font(.caption).foregroundColor(isActive ? .white.opacity(0.8) : (isComplete ? .green : .secondary)).lineLimit(1)
                }
                Spacer()
                if isComplete && !isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundColor(isActive ? .white.opacity(0.8) : .secondary)
                        .font(.caption)
                }
            }
            .padding()
            .background(isActive ? color : Color.yellow.opacity(0.15))
            .cornerRadius(12)
            .shadow(color: isActive ? color.opacity(0.2) : .yellow.opacity(0.15), radius: 4, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isActive ? Color.clear : Color.yellow.opacity(0.5), lineWidth: isActive ? 0 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Form Section Card with Completion State (for popup-based forms)
struct FormSectionCardWithStatus: View {
    let title: String
    let icon: String
    let preview: String
    let color: Color
    var hasError: Bool = false
    var isComplete: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(isComplete ? .green : color)
                        .font(.title2)
                    Spacer()
                    if hasError {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.red)
                    } else if isComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text(preview)
                    .font(.caption)
                    .foregroundColor(isComplete ? .green : .secondary)
                    .lineLimit(2)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.yellow.opacity(0.15))
            .cornerRadius(12)
            .shadow(color: .yellow.opacity(0.15), radius: 4, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(hasError ? Color.red : Color.yellow.opacity(0.5), lineWidth: hasError ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Info Box
struct InfoBox: View {
    let text: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon).foregroundColor(color)
            Text(text).font(.caption).foregroundColor(.secondary)
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - DateFormatter Extension
extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()
}

// MARK: - ICD-10 Psychiatric Diagnoses
enum ICD10Diagnosis: String, Codable, CaseIterable, Identifiable {
    case none = "Select diagnosis..."

    // Schizophrenia & Psychotic Disorders (F20-F29)
    case f200 = "F20.0 Paranoid schizophrenia"
    case f201 = "F20.1 Hebephrenic schizophrenia"
    case f202 = "F20.2 Catatonic schizophrenia"
    case f203 = "F20.3 Undifferentiated schizophrenia"
    case f205 = "F20.5 Residual schizophrenia"
    case f206 = "F20.6 Simple schizophrenia"
    case f209 = "F20.9 Schizophrenia, unspecified"
    case f21 = "F21 Schizotypal disorder"
    case f22 = "F22 Persistent delusional disorders"
    case f23 = "F23 Acute and transient psychotic disorders"
    case f250 = "F25.0 Schizoaffective disorder, manic type"
    case f251 = "F25.1 Schizoaffective disorder, depressive type"
    case f252 = "F25.2 Schizoaffective disorder, mixed type"
    case f259 = "F25.9 Schizoaffective disorder, unspecified"
    case f29 = "F29 Unspecified nonorganic psychosis"

    // Mood Disorders (F30-F39)
    case f300 = "F30.0 Hypomania"
    case f301 = "F30.1 Mania without psychotic symptoms"
    case f302 = "F30.2 Mania with psychotic symptoms"
    case f310 = "F31.0 Bipolar disorder, current episode hypomanic"
    case f311 = "F31.1 Bipolar disorder, current episode manic without psychosis"
    case f312 = "F31.2 Bipolar disorder, current episode manic with psychosis"
    case f313 = "F31.3 Bipolar disorder, current episode mild/moderate depression"
    case f314 = "F31.4 Bipolar disorder, current episode severe depression without psychosis"
    case f315 = "F31.5 Bipolar disorder, current episode severe depression with psychosis"
    case f316 = "F31.6 Bipolar disorder, current episode mixed"
    case f317 = "F31.7 Bipolar disorder, currently in remission"
    case f319 = "F31.9 Bipolar disorder, unspecified"
    case f320 = "F32.0 Mild depressive episode"
    case f321 = "F32.1 Moderate depressive episode"
    case f322 = "F32.2 Severe depressive episode without psychosis"
    case f323 = "F32.3 Severe depressive episode with psychosis"
    case f329 = "F32.9 Depressive episode, unspecified"
    case f330 = "F33.0 Recurrent depression, current episode mild"
    case f331 = "F33.1 Recurrent depression, current episode moderate"
    case f332 = "F33.2 Recurrent depression, current episode severe without psychosis"
    case f333 = "F33.3 Recurrent depression, current episode severe with psychosis"
    case f339 = "F33.9 Recurrent depressive disorder, unspecified"

    // Anxiety Disorders (F40-F48)
    case f400 = "F40.0 Agoraphobia"
    case f401 = "F40.1 Social phobias"
    case f402 = "F40.2 Specific (isolated) phobias"
    case f410 = "F41.0 Panic disorder"
    case f411 = "F41.1 Generalized anxiety disorder"
    case f412 = "F41.2 Mixed anxiety and depressive disorder"
    case f42 = "F42 Obsessive-compulsive disorder"
    case f430 = "F43.0 Acute stress reaction"
    case f431 = "F43.1 Post-traumatic stress disorder"
    case f432 = "F43.2 Adjustment disorders"

    // Eating Disorders (F50)
    case f500 = "F50.0 Anorexia nervosa"
    case f502 = "F50.2 Bulimia nervosa"

    // Personality Disorders (F60)
    case f600 = "F60.0 Paranoid personality disorder"
    case f601 = "F60.1 Schizoid personality disorder"
    case f602 = "F60.2 Dissocial personality disorder"
    case f603 = "F60.3 Emotionally unstable personality disorder"
    case f604 = "F60.4 Histrionic personality disorder"
    case f605 = "F60.5 Anankastic personality disorder"
    case f606 = "F60.6 Anxious personality disorder"
    case f607 = "F60.7 Dependent personality disorder"
    case f609 = "F60.9 Personality disorder, unspecified"

    // Intellectual Disability (F70-F79)
    case f70 = "F70 Mild intellectual disability"
    case f71 = "F71 Moderate intellectual disability"
    case f72 = "F72 Severe intellectual disability"
    case f79 = "F79 Unspecified intellectual disability"

    // Organic (F00-F09)
    case f00 = "F00 Dementia in Alzheimer's disease"
    case f01 = "F01 Vascular dementia"
    case f03 = "F03 Unspecified dementia"
    case f05 = "F05 Delirium"
    case f06 = "F06 Other mental disorders due to brain damage"

    // Substance Use (F10-F19)
    case f10 = "F10 Mental disorders due to alcohol"
    case f11 = "F11 Mental disorders due to opioids"
    case f12 = "F12 Mental disorders due to cannabinoids"
    case f14 = "F14 Mental disorders due to cocaine"
    case f15 = "F15 Mental disorders due to stimulants"
    case f19 = "F19 Mental disorders due to multiple drug use"

    var id: String { rawValue }

    var diagnosisName: String {
        if self == .none { return "" }
        // Extract just the name part after the code
        let parts = rawValue.split(separator: " ", maxSplits: 1)
        return parts.count > 1 ? String(parts[1]) : rawValue
    }

    var code: String {
        if self == .none { return "" }
        let parts = rawValue.split(separator: " ", maxSplits: 1)
        return parts.count > 0 ? String(parts[0]) : ""
    }

    static var groupedDiagnoses: [(String, [ICD10Diagnosis])] {
        [
            ("Schizophrenia & Psychosis", [.f200, .f201, .f202, .f203, .f205, .f206, .f209, .f21, .f22, .f23, .f250, .f251, .f252, .f259, .f29]),
            ("Mood Disorders - Bipolar", [.f300, .f301, .f302, .f310, .f311, .f312, .f313, .f314, .f315, .f316, .f317, .f319]),
            ("Mood Disorders - Depression", [.f320, .f321, .f322, .f323, .f329, .f330, .f331, .f332, .f333, .f339]),
            ("Anxiety Disorders", [.f400, .f401, .f402, .f410, .f411, .f412, .f42, .f430, .f431, .f432]),
            ("Eating Disorders", [.f500, .f502]),
            ("Personality Disorders", [.f600, .f601, .f602, .f603, .f604, .f605, .f606, .f607, .f609]),
            ("Intellectual Disability", [.f70, .f71, .f72, .f79]),
            ("Organic Disorders", [.f00, .f01, .f03, .f05, .f06]),
            ("Substance Use Disorders", [.f10, .f11, .f12, .f14, .f15, .f19])
        ]
    }

    /// Match an ICD-10 code string to enum case
    /// Handles formats like "F20.0", "F20", "F200", "f20.0"
    static func from(code: String) -> ICD10Diagnosis? {
        let normalizedCode = code.uppercased().trimmingCharacters(in: .whitespaces)

        // Try exact match first
        for diagnosis in ICD10Diagnosis.allCases where diagnosis != .none {
            if diagnosis.code.uppercased() == normalizedCode {
                return diagnosis
            }
        }

        // Try without decimal point (e.g., "F200" -> "F20.0")
        let withDecimal = normalizedCode.count >= 3 ? String(normalizedCode.prefix(3)) + "." + String(normalizedCode.dropFirst(3)) : normalizedCode
        for diagnosis in ICD10Diagnosis.allCases where diagnosis != .none {
            if diagnosis.code.uppercased() == withDecimal {
                return diagnosis
            }
        }

        // Try prefix match for general codes (e.g., "F20" matches "F20.0")
        for diagnosis in ICD10Diagnosis.allCases where diagnosis != .none {
            if diagnosis.code.uppercased().hasPrefix(normalizedCode) {
                return diagnosis
            }
        }

        return nil
    }

    /// Extract all ICD-10 diagnoses from text
    /// Returns array of (diagnosis, matchedText, context) tuples sorted by specificity
    static func extractFromText(_ text: String) -> [(diagnosis: ICD10Diagnosis, matchedText: String, context: String)] {
        var results: [(diagnosis: ICD10Diagnosis, matchedText: String, context: String)] = []

        // Regex pattern for ICD-10 F codes: F followed by digits, optional decimal and more digits
        // Matches: F20, F20.0, F31.2, F600, etc.
        let pattern = #"(?i)\b(F\d{2}(?:\.\d{1,2})?)\b"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return results
        }

        let nsText = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))

        var seenCodes: Set<String> = []

        for match in matches {
            let matchedCode = nsText.substring(with: match.range(at: 1))

            // Skip duplicates
            let normalizedCode = matchedCode.uppercased()
            if seenCodes.contains(normalizedCode) { continue }

            if let diagnosis = ICD10Diagnosis.from(code: matchedCode) {
                seenCodes.insert(normalizedCode)

                // Extract context (line containing the match)
                let lines = text.components(separatedBy: .newlines)
                var context = matchedCode
                for line in lines {
                    if line.uppercased().contains(normalizedCode) {
                        context = line.trimmingCharacters(in: .whitespaces)
                        break
                    }
                }

                results.append((diagnosis: diagnosis, matchedText: matchedCode, context: context))
            }
        }

        // Also search for diagnosis names (e.g., "paranoid schizophrenia", "bipolar disorder")
        let textLower = text.lowercased()
        for diagnosis in ICD10Diagnosis.allCases where diagnosis != .none {
            let name = diagnosis.diagnosisName.lowercased()
            if name.count > 5 && textLower.contains(name) {
                let normalizedCode = diagnosis.code.uppercased()
                if !seenCodes.contains(normalizedCode) {
                    seenCodes.insert(normalizedCode)

                    // Find context line
                    let lines = text.components(separatedBy: .newlines)
                    var context = diagnosis.rawValue
                    for line in lines {
                        if line.lowercased().contains(name) {
                            context = line.trimmingCharacters(in: .whitespaces)
                            break
                        }
                    }

                    results.append((diagnosis: diagnosis, matchedText: diagnosis.rawValue, context: context))
                }
            }
        }

        return results
    }
}

// MARK: - Clinical Reasons Data Model
struct ClinicalReasonsData: Codable, Equatable {
    // Diagnosis - now using ICD-10 picker
    var primaryDiagnosisICD10: ICD10Diagnosis = .none
    var secondaryDiagnosisICD10: ICD10Diagnosis = .none
    var primaryDiagnosisCustom: String = ""  // For custom entry if needed
    var secondaryDiagnosisCustom: String = "" // For custom entry if needed

    // Legacy fields for compatibility
    var primaryDiagnosis: String {
        get {
            if primaryDiagnosisICD10 != .none {
                return primaryDiagnosisICD10.rawValue
            }
            return primaryDiagnosisCustom
        }
        set {
            primaryDiagnosisCustom = newValue
        }
    }
    var secondaryDiagnosis: String {
        get {
            if secondaryDiagnosisICD10 != .none {
                return secondaryDiagnosisICD10.rawValue
            }
            return secondaryDiagnosisCustom
        }
        set {
            secondaryDiagnosisCustom = newValue
        }
    }

    // Editable text - user can override the generated text
    var editedText: String = ""
    var useEditedText: Bool = false

    // Nature of Mental Disorder
    var natureEnabled: Bool = false
    var natureRelapsing: Bool = false
    var natureTreatmentResistant: Bool = false
    var natureChronic: Bool = false

    // Degree of Mental Disorder
    var degreeEnabled: Bool = false
    var degreeSeverity: Int = 2  // 1-4 scale
    var degreeSymptoms: String = ""

    // Necessity - Health
    var healthEnabled: Bool = false
    var mentalHealthEnabled: Bool = false
    var mentalHealthPoorCompliance: Bool = false
    var mentalHealthLimitedInsight: Bool = false
    var physicalHealthEnabled: Bool = false
    var physicalHealthDetails: String = ""

    // Necessity - Safety
    var safetyEnabled: Bool = false

    // Safety - Self
    var safetySelfEnabled: Bool = false
    var selfNeglectHistorical: Bool = false
    var selfNeglectCurrent: Bool = false
    var selfRiskyHistorical: Bool = false
    var selfRiskyCurrent: Bool = false
    var selfHarmHistorical: Bool = false
    var selfHarmCurrent: Bool = false

    // Safety - Others
    var safetyOthersEnabled: Bool = false
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

    // Informal Not Appropriate
    var informalNotAppropriateEnabled: Bool = false
    var informalTriedFailed: Bool = false
    var informalLackInsight: Bool = false
    var informalComplianceIssues: Bool = false
    var informalNeedsMHASupervision: Bool = false

    /// The text that should be displayed - either edited or generated
    var displayText: String {
        if useEditedText && !editedText.isEmpty {
            return editedText
        }
        return generatedText
    }

    /// Generates clinical text with patient-specific introduction (matches desktop format)
    func generateTextWithPatient(_ patient: PatientInfo) -> String {
        var parts: [String] = []
        let patientName = patient.fullName.isEmpty ? "The patient" : patient.fullName

        // Diagnosis sentence - matches desktop format
        if !primaryDiagnosis.isEmpty {
            let hasDemo = patient.age != nil || patient.gender != .notSpecified || patient.ethnicity != .notSpecified
            if hasDemo {
                // Build demographic string: "39 year old Asian Chinese man"
                var demoParts: [String] = []
                if let age = patient.age { demoParts.append("\(age) year old") }
                // Add ethnicity (use short description to drop "Other" suffix)
                if patient.ethnicity != .notSpecified && !patient.ethnicity.shortDescription.isEmpty {
                    demoParts.append(patient.ethnicity.shortDescription)
                }
                // Add gender noun (man/woman/person)
                demoParts.append(patient.gender.genderNoun)
                let demoStr = demoParts.joined(separator: " ")

                // Use "an" before vowel sounds, "a" otherwise
                let article = demoStr.first.map { "aeiouAEIOU".contains($0) } == true ? "an" : "a"

                if secondaryDiagnosis.isEmpty {
                    parts.append("\(patientName) is \(article) \(demoStr) who suffers from \(primaryDiagnosis) which is a mental disorder as defined by the Mental Health Act.")
                } else {
                    parts.append("\(patientName) is \(article) \(demoStr) who suffers from \(primaryDiagnosis) and \(secondaryDiagnosis) which are mental disorders as defined by the Mental Health Act.")
                }
            } else {
                if secondaryDiagnosis.isEmpty {
                    parts.append("\(patientName) suffers from \(primaryDiagnosis) which is a mental disorder as defined by the Mental Health Act.")
                } else {
                    parts.append("\(patientName) suffers from \(primaryDiagnosis) and \(secondaryDiagnosis) which are mental disorders as defined by the Mental Health Act.")
                }
            }

            // Nature and degree warrant statement - matches desktop format
            if natureEnabled && degreeEnabled {
                parts.append("The disorder is both of a nature and degree to warrant detention.")
            } else if natureEnabled {
                parts.append("The disorder is of a nature to warrant detention.")
            } else if degreeEnabled {
                parts.append("The disorder is of a degree to warrant detention.")
            }
        }

        // Add rest of the clinical text with patient context
        let shortName = patient.shortName  // e.g., "Mr Doe"
        parts.append(contentsOf: generateClinicalDetails(pronouns: patient.pronouns, shortName: shortName, diagnosisName: primaryDiagnosis))

        return parts.joined(separator: " ")
    }

    /// Generate clinical details with appropriate pronouns and patient name (matches desktop format)
    private func generateClinicalDetails(pronouns: Pronouns, shortName: String = "the patient", diagnosisName: String = "") -> [String] {
        var parts: [String] = []
        let patientRef = shortName.isEmpty ? "the patient" : shortName

        // Nature - matches desktop format
        if natureEnabled {
            var natureTypes: [String] = []
            if natureRelapsing { natureTypes.append("relapsing and remitting") }
            if natureTreatmentResistant { natureTypes.append("treatment resistant") }
            if natureChronic { natureTypes.append("chronic and enduring") }
            if !natureTypes.isEmpty {
                let natureStr = natureTypes.count == 1 ? natureTypes[0] : natureTypes.dropLast().joined(separator: ", ") + " and " + natureTypes.last!
                parts.append("The nature of the illness is \(natureStr).")
            }
        }

        // Degree - matches desktop format
        if degreeEnabled {
            let severityWords = ["some", "several", "many", "overwhelming"]
            let severity = severityWords[min(degreeSeverity - 1, 3)]
            // Extract short diagnosis name for degree sentence
            var dxName = "the disorder"
            if !diagnosisName.isEmpty {
                // Remove ICD code and clean up
                dxName = diagnosisName.replacingOccurrences(of: "F\\d+\\.?\\d*\\s*", with: "", options: .regularExpression).lowercased()
                // Truncate at "disorder" if present
                if let range = dxName.range(of: "disorder") {
                    dxName = String(dxName[...range.upperBound])
                }
                // Handle schizophrenia specifically
                if dxName.hasPrefix("schizophrenia") || dxName.contains("schizophrenia") {
                    dxName = "schizophrenia"
                }
            }
            if !degreeSymptoms.isEmpty {
                parts.append("The degree is evidenced by the presence of \(severity) symptoms of \(dxName) including \(degreeSymptoms).")
            } else {
                parts.append("The degree is evidenced by the presence of \(severity) symptoms of \(dxName).")
            }
        }

        // Build necessity statement - matches desktop format
        var necessityItems: [String] = []
        if healthEnabled {
            necessityItems.append("\(pronouns.possessive) health")
        }
        if safetyEnabled && safetySelfEnabled {
            necessityItems.append("\(pronouns.possessive) own safety")
        }
        if safetyEnabled && safetyOthersEnabled {
            necessityItems.append("safety of others")
        }

        if !necessityItems.isEmpty {
            let necessityText = formatList(necessityItems)
            parts.append("Detention is necessary due to risks to \(necessityText).")
        }

        // Health concerns - matches desktop format
        if healthEnabled && mentalHealthEnabled {
            var mhReasons: [String] = []
            if mentalHealthPoorCompliance { mhReasons.append("non compliance") }
            if mentalHealthLimitedInsight { mhReasons.append("limited insight") }

            if !mhReasons.isEmpty {
                let reasonsStr = mhReasons.joined(separator: "/")
                parts.append("Regarding health we would be concerned about \(pronouns.possessive) mental health deteriorating due to \(reasonsStr).")
            } else {
                parts.append("Regarding health we would be concerned about \(pronouns.possessive) mental health deteriorating.")
            }
        }

        if healthEnabled && physicalHealthEnabled {
            if !physicalHealthDetails.isEmpty {
                parts.append("We are also concerned about \(pronouns.possessive) physical health: \(physicalHealthDetails).")
            } else {
                parts.append("We are also concerned about \(pronouns.possessive) physical health.")
            }
        }

        // Risk to self - matches desktop format
        if safetyEnabled && safetySelfEnabled {
            let riskTypes: [(String, Bool, Bool)] = [
                ("self neglect", selfNeglectHistorical, selfNeglectCurrent),
                ("placing of \(pronouns.reflexive) in risky situations", selfRiskyHistorical, selfRiskyCurrent),
                ("self harm", selfHarmHistorical, selfHarmCurrent)
            ]

            var bothItems: [String] = []
            var histOnly: [String] = []
            var currOnly: [String] = []

            for (riskName, isHist, isCurr) in riskTypes {
                if isHist && isCurr { bothItems.append(riskName) }
                else if isHist { histOnly.append(riskName) }
                else if isCurr { currOnly.append(riskName) }
            }

            var selfParts: [String] = []
            if !bothItems.isEmpty { selfParts.append("historical and current \(bothItems.joined(separator: ", "))") }
            if !histOnly.isEmpty { selfParts.append("historical \(histOnly.joined(separator: ", "))") }
            if !currOnly.isEmpty { selfParts.append("current \(currOnly.joined(separator: ", "))") }

            if !selfParts.isEmpty {
                parts.append("With respect to \(pronouns.possessive) own safety we are concerned about \(selfParts.joined(separator: ", and ")).")
            }
        }

        // Risk to others - matches desktop format
        if safetyEnabled && safetyOthersEnabled {
            let riskTypes: [(String, Bool, Bool)] = [
                ("violence to others", violenceHistorical, violenceCurrent),
                ("verbal aggression", verbalAggressionHistorical, verbalAggressionCurrent),
                ("sexual violence", sexualViolenceHistorical, sexualViolenceCurrent),
                ("stalking", stalkingHistorical, stalkingCurrent),
                ("arson", arsonHistorical, arsonCurrent)
            ]

            var bothItems: [String] = []
            var histOnly: [String] = []
            var currOnly: [String] = []

            for (riskName, isHist, isCurr) in riskTypes {
                if isHist && isCurr { bothItems.append(riskName) }
                else if isHist { histOnly.append(riskName) }
                else if isCurr { currOnly.append(riskName) }
            }

            var othersParts: [String] = []
            if !bothItems.isEmpty { othersParts.append("historical and current \(bothItems.joined(separator: ", "))") }
            if !histOnly.isEmpty { othersParts.append("historical \(histOnly.joined(separator: ", "))") }
            if !currOnly.isEmpty { othersParts.append("current \(currOnly.joined(separator: ", "))") }

            if !othersParts.isEmpty {
                parts.append("With respect to risk to others we are concerned about the risk of \(othersParts.joined(separator: " and of ")).")
            }
        }

        // Informal not appropriate - matches desktop format
        if informalNotAppropriateEnabled {
            var informalParts: [String] = []

            if informalTriedFailed {
                informalParts.append("Previous attempts at informal admissions have not been successful and we would likewise be concerned about this recurring in this instance hence we do not believe informal admission currently would be appropriate.")
            }

            if informalLackInsight {
                informalParts.append("\(pronouns.possessive.capitalized) lack of insight is a significant concern and should \(pronouns.subject) be discharged from section, we believe this would significantly impair \(pronouns.possessive) compliance if informal.")
            }

            if informalComplianceIssues {
                if informalParts.isEmpty {
                    informalParts.append("Compliance with treatment has been a significant issue and we do not believe \(pronouns.subject) would comply if informal.")
                } else {
                    informalParts.append("Compliance with treatment has also been a significant issue and we do not believe \(pronouns.subject) would comply if informal.")
                }
            }

            if informalNeedsMHASupervision {
                informalParts.append("We believe \(patientRef) needs careful community monitoring under the supervision afforded by the Mental Health Act and we do not believe such supervision would be complied with should \(pronouns.subject) remain in the community informally.")
            }

            parts.append(contentsOf: informalParts)
        }

        return parts
    }

    /// Format a list with proper grammar (a, b and c)
    private func formatList(_ items: [String]) -> String {
        guard !items.isEmpty else { return "" }
        if items.count == 1 { return items[0] }
        if items.count == 2 { return "\(items[0]) and \(items[1])" }
        return items.dropLast().joined(separator: ", ") + " and " + items.last!
    }

    /// Generates clinical text addressed directly to the patient using "you/your" (for CTO3 recall notice)
    func generateTextAsYou(_ patient: PatientInfo) -> String {
        var parts: [String] = []

        // Diagnosis sentence - addressed to patient as "You are suffering from..."
        if !primaryDiagnosis.isEmpty {
            // Extract clean diagnosis name (without ICD code)
            let cleanDx = primaryDiagnosis.replacingOccurrences(of: "F\\d+\\.?\\d*\\s*", with: "", options: .regularExpression).lowercased()

            if secondaryDiagnosis.isEmpty {
                parts.append("You are suffering from \(cleanDx) which is a mental disorder as defined by the Mental Health Act.")
            } else {
                let cleanSecondary = secondaryDiagnosis.replacingOccurrences(of: "F\\d+\\.?\\d*\\s*", with: "", options: .regularExpression).lowercased()
                parts.append("You are suffering from \(cleanDx) and \(cleanSecondary) which are mental disorders as defined by the Mental Health Act.")
            }

            // Nature and degree warrant statement
            if natureEnabled && degreeEnabled {
                parts.append("Your disorder is both of a nature and degree to warrant detention.")
            } else if natureEnabled {
                parts.append("Your disorder is of a nature to warrant detention.")
            } else if degreeEnabled {
                parts.append("Your disorder is of a degree to warrant detention.")
            }
        }

        // Add clinical details using "you/your"
        parts.append(contentsOf: generateClinicalDetailsAsYou(diagnosisName: primaryDiagnosis))

        return parts.joined(separator: " ")
    }

    /// Generate clinical details addressed to patient using "you/your" (for CTO3)
    private func generateClinicalDetailsAsYou(diagnosisName: String = "") -> [String] {
        var parts: [String] = []

        // Nature
        if natureEnabled {
            var natureTypes: [String] = []
            if natureRelapsing { natureTypes.append("relapsing and remitting") }
            if natureTreatmentResistant { natureTypes.append("treatment resistant") }
            if natureChronic { natureTypes.append("chronic and enduring") }
            if !natureTypes.isEmpty {
                let natureStr = natureTypes.count == 1 ? natureTypes[0] : natureTypes.dropLast().joined(separator: ", ") + " and " + natureTypes.last!
                parts.append("The nature of your illness is \(natureStr).")
            }
        }

        // Degree
        if degreeEnabled {
            let severityWords = ["some", "several", "many", "overwhelming"]
            let severity = severityWords[min(degreeSeverity - 1, 3)]
            var dxName = "your disorder"
            if !diagnosisName.isEmpty {
                dxName = diagnosisName.replacingOccurrences(of: "F\\d+\\.?\\d*\\s*", with: "", options: .regularExpression).lowercased()
                if let range = dxName.range(of: "disorder") {
                    dxName = String(dxName[...range.upperBound])
                }
                if dxName.hasPrefix("schizophrenia") || dxName.contains("schizophrenia") {
                    dxName = "schizophrenia"
                }
            }
            if !degreeSymptoms.isEmpty {
                parts.append("The degree of your illness is evidenced by the presence of \(severity) symptoms of \(dxName) including \(degreeSymptoms).")
            } else {
                parts.append("The degree of your illness is evidenced by the presence of \(severity) symptoms of \(dxName).")
            }
        }

        // Build necessity statement
        var necessityItems: [String] = []
        if healthEnabled {
            necessityItems.append("your health")
        }
        if safetyEnabled && safetySelfEnabled {
            necessityItems.append("your own safety")
        }
        if safetyEnabled && safetyOthersEnabled {
            necessityItems.append("safety of others")
        }

        if !necessityItems.isEmpty {
            let necessityText = formatList(necessityItems)
            parts.append("Detention is necessary due to risks to \(necessityText).")
        }

        // Health concerns
        if healthEnabled && mentalHealthEnabled {
            var mhReasons: [String] = []
            if mentalHealthPoorCompliance { mhReasons.append("non compliance") }
            if mentalHealthLimitedInsight { mhReasons.append("limited insight") }

            if !mhReasons.isEmpty {
                let reasonsStr = mhReasons.joined(separator: "/")
                parts.append("Regarding your health we would be concerned about your mental health deteriorating due to \(reasonsStr).")
            } else {
                parts.append("Regarding your health we would be concerned about your mental health deteriorating.")
            }
        }

        if healthEnabled && physicalHealthEnabled {
            if !physicalHealthDetails.isEmpty {
                parts.append("We are also concerned about your physical health: \(physicalHealthDetails).")
            } else {
                parts.append("We are also concerned about your physical health.")
            }
        }

        // Risk to self
        if safetyEnabled && safetySelfEnabled {
            let riskTypes: [(String, Bool, Bool)] = [
                ("self neglect", selfNeglectHistorical, selfNeglectCurrent),
                ("placing yourself in risky situations", selfRiskyHistorical, selfRiskyCurrent),
                ("self harm", selfHarmHistorical, selfHarmCurrent)
            ]

            var bothItems: [String] = []
            var histOnly: [String] = []
            var currOnly: [String] = []

            for (riskName, isHist, isCurr) in riskTypes {
                if isHist && isCurr { bothItems.append(riskName) }
                else if isHist { histOnly.append(riskName) }
                else if isCurr { currOnly.append(riskName) }
            }

            var selfParts: [String] = []
            if !bothItems.isEmpty { selfParts.append("historical and current \(bothItems.joined(separator: ", "))") }
            if !histOnly.isEmpty { selfParts.append("historical \(histOnly.joined(separator: ", "))") }
            if !currOnly.isEmpty { selfParts.append("current \(currOnly.joined(separator: ", "))") }

            if !selfParts.isEmpty {
                parts.append("With respect to your own safety we are concerned about \(selfParts.joined(separator: ", and ")).")
            }
        }

        // Risk to others
        if safetyEnabled && safetyOthersEnabled {
            let riskTypes: [(String, Bool, Bool)] = [
                ("violence to others", violenceHistorical, violenceCurrent),
                ("verbal aggression", verbalAggressionHistorical, verbalAggressionCurrent),
                ("sexual violence", sexualViolenceHistorical, sexualViolenceCurrent),
                ("stalking", stalkingHistorical, stalkingCurrent),
                ("arson", arsonHistorical, arsonCurrent)
            ]

            var bothItems: [String] = []
            var histOnly: [String] = []
            var currOnly: [String] = []

            for (riskName, isHist, isCurr) in riskTypes {
                if isHist && isCurr { bothItems.append(riskName) }
                else if isHist { histOnly.append(riskName) }
                else if isCurr { currOnly.append(riskName) }
            }

            var othersParts: [String] = []
            if !bothItems.isEmpty { othersParts.append("historical and current \(bothItems.joined(separator: ", "))") }
            if !histOnly.isEmpty { othersParts.append("historical \(histOnly.joined(separator: ", "))") }
            if !currOnly.isEmpty { othersParts.append("current \(currOnly.joined(separator: ", "))") }

            if !othersParts.isEmpty {
                parts.append("With respect to risk to others we are concerned about the risk of \(othersParts.joined(separator: " and of ")).")
            }
        }

        return parts
    }

    // Generated text (basic version without patient info) - matches desktop format
    var generatedText: String {
        var parts: [String] = []

        // Diagnosis - matches desktop format
        if !primaryDiagnosis.isEmpty {
            if secondaryDiagnosis.isEmpty {
                parts.append("The patient suffers from \(primaryDiagnosis) which is a mental disorder as defined by the Mental Health Act.")
            } else {
                parts.append("The patient suffers from \(primaryDiagnosis) and \(secondaryDiagnosis) which are mental disorders as defined by the Mental Health Act.")
            }

            // Nature and degree warrant statement
            if natureEnabled && degreeEnabled {
                parts.append("The disorder is both of a nature and degree to warrant detention.")
            } else if natureEnabled {
                parts.append("The disorder is of a nature to warrant detention.")
            } else if degreeEnabled {
                parts.append("The disorder is of a degree to warrant detention.")
            }
        }

        // Nature - matches desktop format
        if natureEnabled {
            var natureTypes: [String] = []
            if natureRelapsing { natureTypes.append("relapsing and remitting") }
            if natureTreatmentResistant { natureTypes.append("treatment resistant") }
            if natureChronic { natureTypes.append("chronic and enduring") }
            if !natureTypes.isEmpty {
                let natureStr = natureTypes.count == 1 ? natureTypes[0] : natureTypes.dropLast().joined(separator: ", ") + " and " + natureTypes.last!
                parts.append("The nature of the illness is \(natureStr).")
            }
        }

        // Degree - matches desktop format
        if degreeEnabled {
            let severityWords = ["some", "several", "many", "overwhelming"]
            let severity = severityWords[min(degreeSeverity - 1, 3)]
            if !degreeSymptoms.isEmpty {
                parts.append("The degree is evidenced by the presence of \(severity) symptoms including \(degreeSymptoms).")
            } else {
                parts.append("The degree is evidenced by the presence of \(severity) symptoms.")
            }
        }

        // Necessity - matches desktop format
        var necessityItems: [String] = []
        if healthEnabled { necessityItems.append("their health") }
        if safetyEnabled && safetySelfEnabled { necessityItems.append("their own safety") }
        if safetyEnabled && safetyOthersEnabled { necessityItems.append("safety of others") }

        if !necessityItems.isEmpty {
            parts.append("Detention is necessary due to risks to \(formatList(necessityItems)).")
        }

        // Health concerns - matches desktop format
        if healthEnabled && mentalHealthEnabled {
            var mhReasons: [String] = []
            if mentalHealthPoorCompliance { mhReasons.append("non compliance") }
            if mentalHealthLimitedInsight { mhReasons.append("limited insight") }

            if !mhReasons.isEmpty {
                parts.append("Regarding health we would be concerned about their mental health deteriorating due to \(mhReasons.joined(separator: "/")).")
            } else {
                parts.append("Regarding health we would be concerned about their mental health deteriorating.")
            }
        }

        if healthEnabled && physicalHealthEnabled {
            if !physicalHealthDetails.isEmpty {
                parts.append("We are also concerned about their physical health: \(physicalHealthDetails).")
            } else {
                parts.append("We are also concerned about their physical health.")
            }
        }

        // Risk to self - matches desktop format
        if safetyEnabled && safetySelfEnabled {
            let riskTypes: [(String, Bool, Bool)] = [
                ("self neglect", selfNeglectHistorical, selfNeglectCurrent),
                ("placing of themselves in risky situations", selfRiskyHistorical, selfRiskyCurrent),
                ("self harm", selfHarmHistorical, selfHarmCurrent)
            ]

            var bothItems: [String] = []
            var histOnly: [String] = []
            var currOnly: [String] = []

            for (riskName, isHist, isCurr) in riskTypes {
                if isHist && isCurr { bothItems.append(riskName) }
                else if isHist { histOnly.append(riskName) }
                else if isCurr { currOnly.append(riskName) }
            }

            var selfParts: [String] = []
            if !bothItems.isEmpty { selfParts.append("historical and current \(bothItems.joined(separator: ", "))") }
            if !histOnly.isEmpty { selfParts.append("historical \(histOnly.joined(separator: ", "))") }
            if !currOnly.isEmpty { selfParts.append("current \(currOnly.joined(separator: ", "))") }

            if !selfParts.isEmpty {
                parts.append("With respect to their own safety we are concerned about \(selfParts.joined(separator: ", and ")).")
            }
        }

        // Risk to others - matches desktop format
        if safetyEnabled && safetyOthersEnabled {
            let riskTypes: [(String, Bool, Bool)] = [
                ("violence to others", violenceHistorical, violenceCurrent),
                ("verbal aggression", verbalAggressionHistorical, verbalAggressionCurrent),
                ("sexual violence", sexualViolenceHistorical, sexualViolenceCurrent),
                ("stalking", stalkingHistorical, stalkingCurrent),
                ("arson", arsonHistorical, arsonCurrent)
            ]

            var bothItems: [String] = []
            var histOnly: [String] = []
            var currOnly: [String] = []

            for (riskName, isHist, isCurr) in riskTypes {
                if isHist && isCurr { bothItems.append(riskName) }
                else if isHist { histOnly.append(riskName) }
                else if isCurr { currOnly.append(riskName) }
            }

            var othersParts: [String] = []
            if !bothItems.isEmpty { othersParts.append("historical and current \(bothItems.joined(separator: ", "))") }
            if !histOnly.isEmpty { othersParts.append("historical \(histOnly.joined(separator: ", "))") }
            if !currOnly.isEmpty { othersParts.append("current \(currOnly.joined(separator: ", "))") }

            if !othersParts.isEmpty {
                parts.append("With respect to risk to others we are concerned about the risk of \(othersParts.joined(separator: " and of ")).")
            }
        }

        // Informal not appropriate - matches desktop format
        if informalNotAppropriateEnabled {
            if informalTriedFailed {
                parts.append("Previous attempts at informal admissions have not been successful and we would likewise be concerned about this recurring in this instance hence we do not believe informal admission currently would be appropriate.")
            }

            if informalLackInsight {
                parts.append("Their lack of insight is a significant concern and should they be discharged from section, we believe this would significantly impair their compliance if informal.")
            }

            if informalComplianceIssues {
                parts.append("Compliance with treatment has been a significant issue and we do not believe they would comply if informal.")
            }

            if informalNeedsMHASupervision {
                parts.append("We believe the patient needs careful community monitoring under the supervision afforded by the Mental Health Act and we do not believe such supervision would be complied with should they remain in the community informally.")
            }
        }

        return parts.joined(separator: " ")
    }
}

// MARK: - H1 Reasons Data Model
struct H1ReasonsData: Codable, Equatable {
    var diagnosisICD10: ICD10Diagnosis = .none
    var diagnosisCustom: String = ""

    var diagnosis: String {
        get {
            if diagnosisICD10 != .none {
                return diagnosisICD10.rawValue
            }
            return diagnosisCustom
        }
        set {
            diagnosisCustom = newValue
        }
    }

    // Reasons
    var refusingToRemain: Bool = false
    var veryUnwell: Bool = false
    var acuteDeteriouration: Bool = false

    // Risk
    var riskToSelf: Bool = false
    var riskToOthers: Bool = false

    // Editable text
    var editedText: String = ""
    var useEditedText: Bool = false

    var displayText: String {
        if useEditedText && !editedText.isEmpty {
            return editedText
        }
        return generatedText
    }

    func generateTextWithPatient(_ patient: PatientInfo) -> String {
        var parts: [String] = []
        let pronouns = patient.pronouns
        let shortName = patient.shortName.isEmpty ? "the patient" : patient.shortName

        // Introduction with diagnosis
        if !patient.fullName.isEmpty {
            let intro = patient.clinicalIntroduction
            if !diagnosis.isEmpty {
                // Strip ICD code for cleaner narrative
                let cleanDiagnosis = diagnosis.replacingOccurrences(of: "F\\d+\\.?\\d*\\s*", with: "", options: .regularExpression).lowercased()
                parts.append("\(intro) who is diagnosed with \(cleanDiagnosis).")
            } else {
                parts.append("\(intro).")
            }
        } else if !diagnosis.isEmpty {
            parts.append("The patient is suffering from \(diagnosis).")
        }

        // Clinical presentation
        var presentationDetails: [String] = []
        if refusingToRemain { presentationDetails.append("refusing to remain in hospital voluntarily") }
        if veryUnwell { presentationDetails.append("acutely unwell and requires urgent assessment") }
        if acuteDeteriouration { presentationDetails.append("experiencing acute deterioration in \(pronouns.possessive) mental state") }

        if !presentationDetails.isEmpty {
            let capitalizedSubject = pronouns.subject.prefix(1).uppercased() + pronouns.subject.dropFirst()
            parts.append("\(capitalizedSubject) \(pronouns.bePresent) \(presentationDetails.joined(separator: ", and ")).")
        }

        // Risk statement - more elegant
        if riskToSelf || riskToOthers {
            var riskParts: [String] = []
            if riskToSelf { riskParts.append("\(shortName)'s own safety") }
            if riskToOthers { riskParts.append("the safety of others") }
            parts.append("Holding powers are necessary due to significant risk to \(riskParts.joined(separator: " and ")).")
        }

        return parts.joined(separator: " ")
    }

    var generatedText: String {
        var parts: [String] = []

        if !diagnosis.isEmpty {
            parts.append("The patient is suffering from \(diagnosis).")
        }

        var reasons: [String] = []
        if refusingToRemain { reasons.append("refusing to remain in hospital for assessment") }
        if veryUnwell { reasons.append("very unwell and requires urgent assessment") }
        if acuteDeteriouration { reasons.append("experiencing acute deterioration") }

        if !reasons.isEmpty {
            parts.append("The patient is \(reasons.joined(separator: ", ")).")
        }

        var risks: [String] = []
        if riskToSelf { risks.append("themselves") }
        if riskToOthers { risks.append("others") }

        if !risks.isEmpty {
            parts.append("There is significant risk to \(risks.joined(separator: " and ")).")
        }

        return parts.joined(separator: " ")
    }
}

// MARK: - T2 Medication Entry (for T2 treatment form)
struct T2MedicationEntry: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String = ""
    var isAboveBNF: Bool = false  // false = BNF dose, true = Above BNF
}

// MARK: - T2 Treatment Data Model
struct T2TreatmentData: Codable, Equatable {
    var regularMedications: [T2MedicationEntry] = []
    var prnMedications: [T2MedicationEntry] = []

    // Editable text
    var editedText: String = ""
    var useEditedText: Bool = false

    var displayText: String {
        if useEditedText && !editedText.isEmpty {
            return editedText
        }
        return generatedText
    }

    var generatedText: String {
        var parts: [String] = []

        // Regular medications
        let regularMeds = regularMedications.filter { !$0.name.isEmpty }
        if !regularMeds.isEmpty {
            let medNames = regularMeds.map { $0.name }
            parts.append("Regular: \(medNames.joined(separator: ", "))")
        }

        // PRN medications
        let prnMeds = prnMedications.filter { !$0.name.isEmpty }
        if !prnMeds.isEmpty {
            let medNames = prnMeds.map { $0.name }
            parts.append("PRN: \(medNames.joined(separator: ", "))")
        }

        // Dosage note
        let allMeds = regularMedications + prnMedications
        let aboveBNF = allMeds.filter { !$0.name.isEmpty && $0.isAboveBNF }

        if !allMeds.filter({ !$0.name.isEmpty }).isEmpty {
            if aboveBNF.isEmpty {
                parts.append("All medication at BNF doses.")
            } else {
                let aboveNames = aboveBNF.map { $0.name }
                parts.append("All at BNF doses except \(aboveNames.joined(separator: ", ")) which is/are above BNF.")
            }
        }

        return parts.joined(separator: " ")
    }
}

// MARK: - Clinical Form Type
enum ClinicalFormType {
    case assessment  // A3, A4 - "assessment"
    case treatment   // A7, A8 - "treatment"
    case renewal     // H5 - "renewal"
    case cto         // CTO forms
}

// MARK: - Clinical Reasons View
struct ClinicalReasonsView: View {
    @Binding var data: ClinicalReasonsData
    var patientInfo: PatientInfo? = nil
    var showInformalSection: Bool = true
    var formType: ClinicalFormType = .assessment
    var useYouForm: Bool = false  // For CTO3 - address patient directly with "you/your"

    @State private var isEditingText: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Generated Text Preview (Editable)
            clinicalGeneratedTextSection

            Divider()

            // Diagnosis Section
            clinicalDiagnosisSection

            Divider()

            // Nature Section
            clinicalNatureSection

            Divider()

            // Degree Section
            clinicalDegreeSection

            Divider()

            // Health Section
            clinicalHealthSection

            Divider()

            // Safety Section
            clinicalSafetySection

            if showInformalSection {
                Divider()
                clinicalInformalSection
            }
        }
    }

    // MARK: - Sections

    private var currentGeneratedText: String {
        if let patient = patientInfo {
            // For CTO3, use "you/your" form addressing the patient directly
            if useYouForm {
                return data.generateTextAsYou(patient)
            }
            return data.generateTextWithPatient(patient)
        }
        return data.generatedText
    }

    private var clinicalGeneratedTextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Clinical Opinion", systemImage: "text.quote")
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
                // Editable text area
                TextEditor(text: Binding(
                    get: { data.useEditedText ? data.editedText : currentGeneratedText },
                    set: { newValue in
                        data.editedText = newValue
                        data.useEditedText = true
                    }
                ))
                .font(.subheadline)
                .frame(minHeight: 150)
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
                // Display text with tap to edit
                VStack(alignment: .leading, spacing: 4) {
                    Text(data.displayText.isEmpty ? currentGeneratedText : (data.useEditedText ? data.editedText : currentGeneratedText))
                        .font(.subheadline)
                        .foregroundColor(currentGeneratedText.isEmpty ? .secondary : .primary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .onTapGesture {
                            if !data.useEditedText {
                                data.editedText = currentGeneratedText
                            }
                            isEditingText = true
                        }

                    HStack {
                        Image(systemName: "hand.tap")
                            .foregroundColor(.secondary)
                        Text("Tap to edit")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            if currentGeneratedText.isEmpty && !data.useEditedText {
                Text("Select options below to generate clinical text...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var clinicalDiagnosisSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Mental Disorder", systemImage: "brain.head.profile")
                .font(.headline)
                .foregroundColor(.green)

            // Primary Diagnosis - ICD-10 Picker
            VStack(alignment: .leading, spacing: 4) {
                Text("Primary Diagnosis")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Menu {
                    Button("Clear selection") {
                        data.primaryDiagnosisICD10 = .none
                        data.primaryDiagnosisCustom = ""
                    }

                    ForEach(ICD10Diagnosis.groupedDiagnoses, id: \.0) { group, diagnoses in
                        Menu(group) {
                            ForEach(diagnoses) { diagnosis in
                                Button(diagnosis.rawValue) {
                                    data.primaryDiagnosisICD10 = diagnosis
                                    data.primaryDiagnosisCustom = ""
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(data.primaryDiagnosisICD10 == .none ?
                             (data.primaryDiagnosisCustom.isEmpty ? "Select ICD-10 diagnosis..." : data.primaryDiagnosisCustom) :
                                data.primaryDiagnosisICD10.rawValue)
                            .foregroundColor(data.primaryDiagnosis.isEmpty ? .secondary : .primary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }

                // Custom entry option
                if data.primaryDiagnosisICD10 == .none {
                    FormTextField(label: "Or enter custom diagnosis", text: $data.primaryDiagnosisCustom, placeholder: "Type diagnosis if not in list")
                }
            }

            // Secondary Diagnosis - ICD-10 Picker
            VStack(alignment: .leading, spacing: 4) {
                Text("Secondary Diagnosis (Optional)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Menu {
                    Button("Clear selection") {
                        data.secondaryDiagnosisICD10 = .none
                        data.secondaryDiagnosisCustom = ""
                    }

                    ForEach(ICD10Diagnosis.groupedDiagnoses, id: \.0) { group, diagnoses in
                        Menu(group) {
                            ForEach(diagnoses) { diagnosis in
                                Button(diagnosis.rawValue) {
                                    data.secondaryDiagnosisICD10 = diagnosis
                                    data.secondaryDiagnosisCustom = ""
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(data.secondaryDiagnosisICD10 == .none ?
                             (data.secondaryDiagnosisCustom.isEmpty ? "Select ICD-10 diagnosis..." : data.secondaryDiagnosisCustom) :
                                data.secondaryDiagnosisICD10.rawValue)
                            .foregroundColor(data.secondaryDiagnosis.isEmpty ? .secondary : .primary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }

                if data.secondaryDiagnosisICD10 == .none {
                    FormTextField(label: "Or enter custom diagnosis", text: $data.secondaryDiagnosisCustom, placeholder: "Type diagnosis if not in list")
                }
            }
        }
    }

    private var clinicalNatureSection: some View {
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

    private var clinicalDegreeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $data.degreeEnabled) {
                Label("Degree of Mental Disorder", systemImage: "chart.bar")
                    .font(.headline)
                    .foregroundColor(.purple)
            }

            if data.degreeEnabled {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Severity: \(clinicalSeverityLabel)")
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

    private var clinicalSeverityLabel: String {
        switch data.degreeSeverity {
        case 1: return "Some symptoms"
        case 2: return "Several symptoms"
        case 3: return "Many symptoms"
        case 4: return "Overwhelming symptoms"
        default: return "Several symptoms"
        }
    }

    private var clinicalHealthSection: some View {
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

    private var clinicalSafetySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $data.safetyEnabled) {
                Label("Necessity - Safety", systemImage: "shield.checkered")
                    .font(.headline)
                    .foregroundColor(.orange)
            }

            if data.safetyEnabled {
                VStack(alignment: .leading, spacing: 16) {
                    // Safety to Self
                    clinicalSafetySelfSection

                    // Safety to Others
                    clinicalSafetyOthersSection
                }
                .padding(.leading)
            }
        }
    }

    private var clinicalSafetySelfSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $data.safetySelfEnabled) {
                Text("Risk to Self")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            if data.safetySelfEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    ClinicalRiskRow(label: "Self-neglect", historical: $data.selfNeglectHistorical, current: $data.selfNeglectCurrent)
                    ClinicalRiskRow(label: "Risky situations", historical: $data.selfRiskyHistorical, current: $data.selfRiskyCurrent)
                    ClinicalRiskRow(label: "Self-harm", historical: $data.selfHarmHistorical, current: $data.selfHarmCurrent)
                }
                .padding(.leading)
            }
        }
    }

    private var clinicalSafetyOthersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $data.safetyOthersEnabled) {
                Text("Risk to Others")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            if data.safetyOthersEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    ClinicalRiskRow(label: "Violence", historical: $data.violenceHistorical, current: $data.violenceCurrent)
                    ClinicalRiskRow(label: "Verbal aggression", historical: $data.verbalAggressionHistorical, current: $data.verbalAggressionCurrent)
                    ClinicalRiskRow(label: "Sexual violence", historical: $data.sexualViolenceHistorical, current: $data.sexualViolenceCurrent)
                    ClinicalRiskRow(label: "Stalking", historical: $data.stalkingHistorical, current: $data.stalkingCurrent)
                    ClinicalRiskRow(label: "Arson", historical: $data.arsonHistorical, current: $data.arsonCurrent)
                }
                .padding(.leading)
            }
        }
    }

    private var clinicalInformalSection: some View {
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

// MARK: - Clinical Risk Row Component
struct ClinicalRiskRow: View {
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

// MARK: - H1 Reasons View
struct H1ReasonsView: View {
    @Binding var data: H1ReasonsData
    var patientInfo: PatientInfo? = nil

    @State private var isEditingText: Bool = false

    private var currentGeneratedText: String {
        if let patient = patientInfo {
            return data.generateTextWithPatient(patient)
        }
        return data.generatedText
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Generated Text Preview (Editable)
            h1GeneratedTextSection

            Divider()

            // Diagnosis
            h1DiagnosisSection

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

    private var h1GeneratedTextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Reasons for Holding", systemImage: "text.quote")
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
                    get: { data.useEditedText ? data.editedText : currentGeneratedText },
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
                    Text(data.displayText.isEmpty ? currentGeneratedText : (data.useEditedText ? data.editedText : currentGeneratedText))
                        .font(.subheadline)
                        .foregroundColor(currentGeneratedText.isEmpty ? .secondary : .primary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .onTapGesture {
                            if !data.useEditedText {
                                data.editedText = currentGeneratedText
                            }
                            isEditingText = true
                        }

                    HStack {
                        Image(systemName: "hand.tap")
                            .foregroundColor(.secondary)
                        Text("Tap to edit")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            if currentGeneratedText.isEmpty && !data.useEditedText {
                Text("Select options below to generate text...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var h1DiagnosisSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Diagnosis", systemImage: "brain.head.profile")
                .font(.headline)
                .foregroundColor(.green)

            VStack(alignment: .leading, spacing: 4) {
                Text("Primary Diagnosis")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Menu {
                    Button("Clear selection") {
                        data.diagnosisICD10 = .none
                        data.diagnosisCustom = ""
                    }

                    ForEach(ICD10Diagnosis.groupedDiagnoses, id: \.0) { group, diagnoses in
                        Menu(group) {
                            ForEach(diagnoses) { diagnosis in
                                Button(diagnosis.rawValue) {
                                    data.diagnosisICD10 = diagnosis
                                    data.diagnosisCustom = ""
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(data.diagnosisICD10 == .none ?
                             (data.diagnosisCustom.isEmpty ? "Select ICD-10 diagnosis..." : data.diagnosisCustom) :
                                data.diagnosisICD10.rawValue)
                            .foregroundColor(data.diagnosis.isEmpty ? .secondary : .primary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }

                if data.diagnosisICD10 == .none {
                    FormTextField(label: "Or enter custom diagnosis", text: $data.diagnosisCustom, placeholder: "Type diagnosis if not in list")
                }
            }
        }
    }
}

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
