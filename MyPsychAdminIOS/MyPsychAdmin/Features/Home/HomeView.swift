//
//  HomeView.swift
//  MyPsychAdmin
//

import SwiftUI

struct HomeView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(SharedDataStore.self) private var sharedData
    @State private var showSettings = false
    @State private var showNotes = false
    @State private var showLetters = false
    @State private var showForms = false
    @State private var showReports = false
    @State private var showMyDetails = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // App Banner
                    HomeBannerView()

                    // Quick Actions
                    QuickActionsSection(
                        showNotes: $showNotes,
                        showLetters: $showLetters,
                        showForms: $showForms,
                        showReports: $showReports,
                        showMyDetails: $showMyDetails
                    )

                    // Current Patient Summary
                    if sharedData.hasNotes || !sharedData.patientInfo.fullName.isEmpty {
                        CurrentPatientSection()
                    }

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .navigationTitle("MyPsychAdmin")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .navigationDestination(isPresented: $showNotes) {
                NotesView()
            }
            .navigationDestination(isPresented: $showLetters) {
                LetterWriterView()
            }
            .navigationDestination(isPresented: $showForms) {
                FormsListView()
            }
            .navigationDestination(isPresented: $showReports) {
                ReportsListView()
            }
            .navigationDestination(isPresented: $showMyDetails) {
                MyDetailsView()
            }
        }
    }
}

// MARK: - Home Banner (Desktop-style frosted glass banner)
struct HomeBannerView: View {
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.13, green: 0.59, blue: 0.53).opacity(0.15),
                    Color(red: 0.20, green: 0.70, blue: 0.65).opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Content
            VStack(spacing: 10) {
                // Icon with glow effect
                ZStack {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 36))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(red: 0.13, green: 0.59, blue: 0.53), Color(red: 0.20, green: 0.70, blue: 0.65)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .blur(radius: 12)
                        .opacity(0.5)

                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 36))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(red: 0.13, green: 0.59, blue: 0.53), Color(red: 0.20, green: 0.70, blue: 0.65)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                VStack(spacing: 4) {
                    Text("MyPsychAdmin")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(red: 0.10, green: 0.50, blue: 0.45), Color(red: 0.15, green: 0.60, blue: 0.55)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    Text("Psychiatric Documentation Made Simple")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 16)
        }
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(red: 0.13, green: 0.59, blue: 0.53).opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Quick Actions
struct QuickActionsSection: View {
    @Binding var showNotes: Bool
    @Binding var showLetters: Bool
    @Binding var showForms: Bool
    @Binding var showReports: Bool
    @Binding var showMyDetails: Bool

    var body: some View {
        VStack(spacing: 12) {
            // Top row
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                LiquidActionButton(
                    title: "New Letter",
                    icon: "envelope.badge.fill",
                    color: Color(red: 0.20, green: 0.67, blue: 0.63),
                    animationDelay: 0.0
                ) {
                    showLetters = true
                }

                LiquidActionButton(
                    title: "View Notes",
                    icon: "doc.text.magnifyingglass",
                    color: Color(red: 0.22, green: 0.56, blue: 0.24),
                    animationDelay: 0.3
                ) {
                    showNotes = true
                }
            }

            // Center button
            LiquidActionButton(
                title: "My Details",
                icon: "person.crop.circle.badge.checkmark",
                color: Color(red: 0.58, green: 0.24, blue: 0.75),
                animationDelay: 0.6
            ) {
                showMyDetails = true
            }
            .frame(maxWidth: .infinity)

            // Bottom row
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                LiquidActionButton(
                    title: "Fill Form",
                    icon: "doc.on.clipboard.fill",
                    color: Color(red: 0.15, green: 0.39, blue: 0.92),
                    animationDelay: 0.9
                ) {
                    showForms = true
                }

                LiquidActionButton(
                    title: "Create Report",
                    icon: "doc.text.fill",
                    color: Color(red: 0.48, green: 0.23, blue: 0.93),
                    animationDelay: 1.2
                ) {
                    showReports = true
                }
            }
        }
    }
}

// MARK: - Liquid Action Button
struct LiquidActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let animationDelay: Double
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var rotationAngle: Double = 0

    private let circleSize: CGFloat = 72

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    // Rotating angular gradient circle
                    Circle()
                        .fill(
                            AngularGradient(
                                colors: [
                                    color,
                                    color.opacity(0.6),
                                    color.opacity(0.8),
                                    color
                                ],
                                center: .center,
                                angle: .degrees(rotationAngle)
                            )
                        )
                        .frame(width: circleSize, height: circleSize)

                    // Glassy convex highlight
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.45),
                                    Color.white.opacity(0.1),
                                    Color.clear
                                ],
                                center: .topLeading,
                                startRadius: 0,
                                endRadius: circleSize * 0.7
                            )
                        )
                        .frame(width: circleSize, height: circleSize)

                    // White icon
                    Image(systemName: icon)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                }
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.6 : 0.18), radius: colorScheme == .dark ? 14 : 6, y: colorScheme == .dark ? 8 : 5)
                .shadow(color: color.opacity(colorScheme == .dark ? 0.7 : 0.45), radius: colorScheme == .dark ? 16 : 10, y: colorScheme == .dark ? 8 : 6)

                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(LiquidRippleButtonStyle(color: color))
        .onAppear {
            withAnimation(
                .linear(duration: 8)
                .repeatForever(autoreverses: false)
                .delay(animationDelay)
            ) {
                rotationAngle = 360
            }
        }
    }
}

// MARK: - Liquid Ripple Button Style
struct LiquidRippleButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        LiquidRippleContent(configuration: configuration, color: color)
    }
}

private struct LiquidRippleContent: View {
    let configuration: ButtonStyleConfiguration
    let color: Color

    @State private var rippleID = 0
    @State private var showRipple = false

    var body: some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.6), value: configuration.isPressed)
            .overlay(
                Circle()
                    .fill(color.opacity(configuration.isPressed ? 0.25 : 0))
                    .blur(radius: 20)
                    .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
            )
            .overlay(
                ZStack {
                    if showRipple {
                        RippleRing(color: color, delay: 0, startScale: 0.6, endScale: 1.7,
                                   duration: 0.6, startOpacity: 0.6, lineWidth: 2.5)
                            .id("ring1-\(rippleID)")

                        RippleRing(color: color, delay: 0.15, startScale: 0.7, endScale: 1.9,
                                   duration: 0.5, startOpacity: 0.4, lineWidth: 1.5)
                            .id("ring2-\(rippleID)")
                    }
                }
            )
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed {
                    rippleID += 1
                    showRipple = false
                    DispatchQueue.main.async {
                        showRipple = true
                    }
                }
            }
    }
}

private struct RippleRing: View {
    let color: Color
    let delay: Double
    let startScale: CGFloat
    let endScale: CGFloat
    let duration: Double
    let startOpacity: Double
    let lineWidth: CGFloat

    @State private var animate = false

    var body: some View {
        Circle()
            .stroke(color, lineWidth: lineWidth)
            .scaleEffect(animate ? endScale : startScale)
            .opacity(animate ? 0 : startOpacity)
            .onAppear {
                withAnimation(.easeOut(duration: duration).delay(delay)) {
                    animate = true
                }
            }
    }
}

// MARK: - Current Patient Section
struct CurrentPatientSection: View {
    @Environment(SharedDataStore.self) private var sharedData

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Current Patient")
                    .font(.headline)

                Spacer()

                Button("Clear") {
                    sharedData.clearAll()
                }
                .font(.caption)
                .foregroundColor(.red)
            }

            VStack(alignment: .leading, spacing: 8) {
                if !sharedData.patientInfo.fullName.isEmpty {
                    InfoRow(label: "Name", value: sharedData.patientInfo.fullName)
                }

                if let dob = sharedData.patientInfo.dateOfBirth {
                    InfoRow(label: "DOB", value: formatDate(dob))
                }

                if !sharedData.patientInfo.nhsNumber.isEmpty {
                    InfoRow(label: "NHS", value: sharedData.patientInfo.nhsNumber)
                }

                if sharedData.hasNotes {
                    InfoRow(label: "Notes", value: "\(sharedData.notesCount) imported")
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .leading)

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    HomeView()
        .environment(AppStore())
        .environment(SharedDataStore.shared)
}
