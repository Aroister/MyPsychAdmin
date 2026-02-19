//
//  FormsListView.swift
//  MyPsychAdmin
//

import SwiftUI

struct FormsListView: View {
    @Environment(AppStore.self) private var appStore
    @State private var selectedFormType: FormType?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // MHA Forms Card
                    FormCategoryCard(
                        title: "Mental Health Act Forms",
                        subtitle: "Statutory forms for detention and treatment",
                        categories: [.socialWork, .medicalJoint, .medicalSingle, .holdingPower, .treatmentTransfer],
                        selectedFormType: $selectedFormType
                    )

                    // CTO Forms Card
                    FormCategoryCard(
                        title: "Community Treatment Orders",
                        subtitle: "Forms for community treatment and recall",
                        categories: [.ctoInitialExtend, .ctoRecallRevoke],
                        selectedFormType: $selectedFormType
                    )

                    // Other Forms Card
                    FormCategoryCard(
                        title: "Other Forms",
                        subtitle: "MOJ forms for restricted patients",
                        categories: [.moj],
                        selectedFormType: $selectedFormType
                    )

                    // Risk Assessment Forms Card
                    FormCategoryCard(
                        title: "Risk Assessment Forms",
                        subtitle: "Structured risk assessment tools",
                        categories: [.riskAssessment],
                        selectedFormType: $selectedFormType
                    )
                }
                .padding()
            }
            .navigationTitle("Forms")
            .sheet(item: $selectedFormType) { formType in
                FormEditorView(formType: formType)
            }
        }
    }
}

// MARK: - Form Category Card
struct FormCategoryCard: View {
    let title: String
    let subtitle: String
    let categories: [FormCategory]
    @Binding var selectedFormType: FormType?

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()

                ForEach(categories) { category in
                    FormCategorySection(
                        category: category,
                        selectedFormType: $selectedFormType
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
    }
}

// MARK: - Form Category Section
struct FormCategorySection: View {
    let category: FormCategory
    @Binding var selectedFormType: FormType?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Category header
            HStack(spacing: 8) {
                Image(systemName: category.iconName)
                    .foregroundColor(category.color)

                Text(category.rawValue)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(category.color)
            }

            // Form buttons
            FlowLayout(spacing: 8) {
                ForEach(category.forms) { form in
                    FormButton(
                        form: form,
                        color: category.color
                    ) {
                        selectedFormType = form
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Form Button
struct FormButton: View {
    let form: FormType
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(form.rawValue)
                    .font(.caption)
                    .fontWeight(.bold)

                if let section = form.sectionNumber {
                    Text(section)
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(color)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Flow Layout (for wrapping buttons)
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                       y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: currentX, y: currentY))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

// MARK: - Form Editor View (Routes to specific form)
struct FormEditorView: View {
    let formType: FormType

    var body: some View {
        FormRouterView(formType: formType)
    }
}

#Preview {
    FormsListView()
        .environment(AppStore())
        .environment(SharedDataStore.shared)
}
