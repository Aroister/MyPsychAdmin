//
//  SettingsView.swift
//  MyPsychAdmin
//
//  App settings for appearance and accessibility
//

import SwiftUI

// MARK: - App Settings Store
@Observable
class AppSettings {
    static let shared = AppSettings()

    // Appearance
    var appearanceMode: AppearanceMode {
        didSet {
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: "appearanceMode")
        }
    }

    // Text Size
    var textSizeMultiplier: Double {
        didSet {
            UserDefaults.standard.set(textSizeMultiplier, forKey: "textSizeMultiplier")
        }
    }

    private init() {
        // Load saved settings
        let savedAppearance = UserDefaults.standard.string(forKey: "appearanceMode") ?? "system"
        self.appearanceMode = AppearanceMode(rawValue: savedAppearance) ?? .system

        let savedTextSize = UserDefaults.standard.double(forKey: "textSizeMultiplier")
        self.textSizeMultiplier = savedTextSize > 0 ? savedTextSize : 1.0
    }

    var colorScheme: ColorScheme? {
        switch appearanceMode {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var settings = AppSettings.shared

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Appearance Section
                Section {
                    ForEach(AppearanceMode.allCases) { mode in
                        Button {
                            withAnimation {
                                settings.appearanceMode = mode
                            }
                        } label: {
                            HStack {
                                Image(systemName: mode.icon)
                                    .foregroundColor(mode == .dark ? .purple : (mode == .light ? .orange : .blue))
                                    .frame(width: 24)

                                Text(mode.displayName)
                                    .foregroundColor(.primary)

                                Spacer()

                                if settings.appearanceMode == mode {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("Choose how MyPsychAdmin looks. System follows your device settings.")
                }

                // MARK: - Text Size Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Text Size")
                            Spacer()
                            Text(textSizeLabel)
                                .foregroundColor(.secondary)
                        }

                        HStack(spacing: 12) {
                            Image(systemName: "textformat.size.smaller")
                                .foregroundColor(.secondary)

                            Slider(
                                value: $settings.textSizeMultiplier,
                                in: 0.8...1.5,
                                step: 0.1
                            )
                            .tint(.blue)

                            Image(systemName: "textformat.size.larger")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    // Preview
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preview")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("This is how text will appear throughout the app.")
                            .font(.system(size: 15 * settings.textSizeMultiplier))

                        Text("Clinical notes and patient history use this size.")
                            .font(.system(size: 13 * settings.textSizeMultiplier))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)

                    Button {
                        withAnimation {
                            settings.textSizeMultiplier = 1.0
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text("Reset to Default")
                                .foregroundColor(.blue)
                            Spacer()
                        }
                    }
                    .disabled(settings.textSizeMultiplier == 1.0)
                } header: {
                    Text("Text Size")
                } footer: {
                    Text("Adjust text size for better readability. This affects most text in the app.")
                }

                // MARK: - About Section
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var textSizeLabel: String {
        let percentage = Int(settings.textSizeMultiplier * 100)
        if percentage == 100 {
            return "Default"
        } else if percentage < 100 {
            return "\(percentage)%"
        } else {
            return "\(percentage)%"
        }
    }
}

// MARK: - Text Size Modifier
struct ScaledFont: ViewModifier {
    @State private var settings = AppSettings.shared
    let baseSize: CGFloat

    func body(content: Content) -> some View {
        content
            .font(.system(size: baseSize * settings.textSizeMultiplier))
    }
}

extension View {
    func scaledFont(size: CGFloat) -> some View {
        modifier(ScaledFont(baseSize: size))
    }
}

#Preview {
    SettingsView()
}
