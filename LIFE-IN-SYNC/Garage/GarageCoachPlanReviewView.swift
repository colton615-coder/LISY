import SwiftUI

@MainActor
struct GarageCoachPlanReviewView: View {
    @State private var draftPlan: GarageGeneratedPracticePlan

    let onStartSession: (GarageGeneratedPracticePlan) -> Void

    init(
        plan: GarageGeneratedPracticePlan,
        onStartSession: @escaping (GarageGeneratedPracticePlan) -> Void
    ) {
        _draftPlan = State(initialValue: plan)
        self.onStartSession = onStartSession
    }

    var body: some View {
        GarageProScaffold(bottomPadding: 56) {
            pageHeader
            summaryCard
            objectiveCard
            drillListSection
            startSessionAction
        }
        .navigationTitle("Coach Plan")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var pageHeader: some View {
        GarageCompactPageHeader(
            eyebrow: "Local Coach Plan",
            title: "Coach Plan",
            subtitle: "Review the sequence before entering Focus Room."
        ) {
            GarageCompactStatBadge(
                value: "\(draftPlan.drills.count)",
                label: draftPlan.drills.count == 1 ? "Drill" : "Drills"
            )
        }
    }

    private var summaryCard: some View {
        GarageProCard(isActive: true, cornerRadius: 22, padding: 14) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: draftPlan.environment.systemImage)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(GarageProTheme.accent)
                    .frame(width: 42, height: 42)
                    .background(GarageProTheme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 7) {
                    Text(draftPlan.title)
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(GarageProTheme.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)

                    HStack(spacing: 8) {
                        GarageCompactMetaPill(title: draftPlan.environment.displayName, systemImage: draftPlan.environment.systemImage)
                        GarageCompactMetaPill(title: "\(draftPlan.drills.count) drills", systemImage: "list.number")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var objectiveCard: some View {
        GarageProCard(cornerRadius: 22, padding: 14) {
            Text("Objective")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .textCase(.uppercase)
                .tracking(2)
                .foregroundStyle(GarageProTheme.accent)

            Text(draftPlan.objective)
                .font(.headline.weight(.black))
                .foregroundStyle(GarageProTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(draftPlan.coachNote)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(GarageProTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var drillListSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            GaragePlanReviewHeader(
                eyebrow: "Editable Review",
                title: "Drill Order"
            )

            VStack(spacing: 12) {
                ForEach(Array(draftPlan.drills.enumerated()), id: \.element.id) { offset, drill in
                    GaragePlanReviewDrillRow(
                        index: offset + 1,
                        drill: drill,
                        canRemove: draftPlan.drills.count > 1,
                        onRemove: {
                            garageTriggerImpact(.medium)
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                draftPlan.removeDrill(id: drill.id)
                            }
                        }
                    )
                }
            }
        }
    }

    private var startSessionAction: some View {
        HStack {
            GarageProPrimaryButton(
                title: "Start Session",
                systemImage: "play.fill",
                isEnabled: draftPlan.canStart
            ) {
                onStartSession(draftPlan)
            }
        }
    }
}

private struct GaragePlanReviewMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(GarageProTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .textCase(.uppercase)
                .tracking(1.5)
                .foregroundStyle(GarageProTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(GarageProTheme.insetSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(GarageProTheme.border, lineWidth: 1)
                )
        )
    }
}

private struct GaragePlanReviewHeader: View {
    let eyebrow: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(eyebrow)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .textCase(.uppercase)
                .tracking(2)
                .foregroundStyle(GarageProTheme.accent)

            Text(title)
                .font(.system(.title2, design: .rounded).weight(.black))
                .foregroundStyle(GarageProTheme.textPrimary)
        }
    }
}

private struct GaragePlanReviewDrillRow: View {
    let index: Int
    let drill: PracticeTemplateDrill
    let canRemove: Bool
    let onRemove: () -> Void

    var body: some View {
        GarageProCard(isActive: true, cornerRadius: 20, padding: 12) {
            HStack(alignment: .top, spacing: 12) {
                Text("\(index)")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundStyle(GarageProTheme.accent)
                    .frame(width: 34, height: 34)
                    .background(GarageProTheme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(GarageProTheme.accent.opacity(0.24), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 5) {
                    Text(drill.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(GarageProTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(drill.metadataSummary)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(GarageProTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                if canRemove {
                    Button(action: onRemove) {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(GarageProTheme.textSecondary)
                            .frame(width: 40, height: 40)
                            .background(GarageProTheme.insetSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(GarageProTheme.border, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove \(drill.title)")
                }
            }
        }
    }
}

#Preview("Garage Coach Plan Review") {
    NavigationStack {
        GarageCoachPlanReviewView(
            plan: GarageLocalCoachPlanner.generatePlan(for: .range, recentRecords: []),
            onStartSession: { _ in }
        )
    }
}
