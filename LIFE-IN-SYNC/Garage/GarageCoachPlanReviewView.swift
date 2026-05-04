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
            heroCard
            objectiveCard
            drillListSection
            startSessionAction
        }
        .navigationTitle("Coach Plan")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var heroCard: some View {
        GarageProHeroCard(
            eyebrow: "Local Coach Plan",
            title: draftPlan.title,
            subtitle: draftPlan.environment.displayName,
            value: "\(draftPlan.drills.count)",
            valueLabel: draftPlan.drills.count == 1 ? "Drill" : "Drills"
        ) {
            Image(systemName: draftPlan.environment.systemImage)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(GarageProTheme.accent)
                .frame(width: 60, height: 60)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(GarageProTheme.accent.opacity(0.3), lineWidth: 1)
                )
        }
    }

    private var objectiveCard: some View {
        GarageProCard(isActive: true, cornerRadius: 24, padding: 18) {
            Text("Objective")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .textCase(.uppercase)
                .tracking(2)
                .foregroundStyle(GarageProTheme.accent)

            Text(draftPlan.objective)
                .font(.system(.title3, design: .rounded).weight(.black))
                .foregroundStyle(GarageProTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(draftPlan.coachNote)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(GarageProTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                GaragePlanReviewMetric(title: "Work", value: "\(draftPlan.totalRepCount) reps")
                GaragePlanReviewMetric(title: "Time", value: "\(draftPlan.estimatedDurationMinutes) min")
            }
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
        GarageProCard(isActive: true, cornerRadius: 22, padding: 16) {
            HStack(alignment: .top, spacing: 14) {
                Text("\(index)")
                    .font(.system(size: 17, weight: .black, design: .monospaced))
                    .foregroundStyle(GarageProTheme.accent)
                    .frame(width: 42, height: 42)
                    .background(GarageProTheme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .stroke(GarageProTheme.accent.opacity(0.24), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 7) {
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
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(GarageProTheme.textSecondary)
                            .frame(width: 44, height: 44)
                            .background(GarageProTheme.insetSurface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 15, style: .continuous)
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
