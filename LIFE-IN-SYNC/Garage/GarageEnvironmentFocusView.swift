import SwiftData
import SwiftUI

@MainActor
struct GarageEnvironmentFocusView: View {
    @Query(sort: \PracticeTemplate.title) private var allTemplates: [PracticeTemplate]
    @Query(sort: \PracticeSessionRecord.date, order: .reverse) private var records: [PracticeSessionRecord]

    let environment: PracticeEnvironment
    let onGeneratePlan: (GarageGeneratedPracticePlan) -> Void
    let onSelectTemplate: (PracticeTemplate) -> Void
    let onOpenDiagnostic: () -> Void

    private var environmentRecords: [PracticeSessionRecord] {
        records.filter { $0.environment == environment.rawValue }
    }

    private var latestRecord: PracticeSessionRecord? {
        environmentRecords.first
    }

    private var savedTemplates: [PracticeTemplate] {
        allTemplates.filter { $0.environment == environment.rawValue }
    }

    private var builtInRoutines: [GarageRoutine] {
        DrillVault.predefinedRoutines.filter { $0.environment == environment }
    }

    var body: some View {
        GarageProScaffold(bottomPadding: 56) {
            headerCard
            generateCard
            carryForwardCard
            routineAccessSection
            diagnosticSection
        }
        .navigationTitle(environment.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerCard: some View {
        GarageProHeroCard(
            eyebrow: "Practice Environment",
            title: environment.displayName,
            subtitle: environment.description,
            value: "\(DrillVault.drillCount(in: environment))",
            valueLabel: "Drills Available"
        ) {
            Image(systemName: environment.systemImage)
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

    private var generateCard: some View {
        GarageProCard(isActive: true, cornerRadius: 26, padding: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Coach-Led Session")
                    .font(.system(.title3, design: .rounded).weight(.black))
                    .foregroundStyle(GarageProTheme.textPrimary)

                Text("Generate a local plan from the \(environment.displayName.lowercased()) drill catalog and your latest carry-forward note.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(GarageProTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            GarageEnvironmentFocusMetricStrip(
                sessionCount: environmentRecords.count,
                routineCount: builtInRoutines.count + savedTemplates.count,
                latestEfficiency: latestRecord?.aggregateEfficiencyText ?? "--"
            )

            GarageProPrimaryButton(
                title: "Generate Practice Session",
                systemImage: "sparkles"
            ) {
                generatePlan()
            }
        }
    }

    @ViewBuilder
    private var carryForwardCard: some View {
        if let latestRecord {
            GarageProCard(isActive: true, cornerRadius: 24, padding: 18) {
                Text("Carry Forward")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .textCase(.uppercase)
                    .tracking(2)
                    .foregroundStyle(GarageProTheme.accent)

                Text(latestRecord.templateName)
                    .font(.system(.headline, design: .rounded).weight(.black))
                    .foregroundStyle(GarageProTheme.textPrimary)

                if let note = latestRecord.primaryEnvironmentFocusNote {
                    Text(note)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(GarageProTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Last session saved without a cue. The generated plan will start from the environment baseline.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(GarageProTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text("\(latestRecord.aggregateEfficiencyText) efficiency - \(latestRecord.practiceReadbackSummary)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(GarageProTheme.accent.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            GarageProCard(cornerRadius: 24, padding: 18) {
                Text("No Carry Forward Yet")
                    .font(.system(.headline, design: .rounded).weight(.black))
                    .foregroundStyle(GarageProTheme.textPrimary)

                Text("The first generated plan will create a baseline for \(environment.displayName.lowercased()) practice.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(GarageProTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var routineAccessSection: some View {
        if builtInRoutines.isEmpty == false || savedTemplates.isEmpty == false {
            VStack(alignment: .leading, spacing: 12) {
                GarageEnvironmentFocusHeader(
                    eyebrow: "Secondary",
                    title: "Existing Routines"
                )

                VStack(spacing: 12) {
                    ForEach(builtInRoutines) { routine in
                        Button {
                            garageTriggerSelection()
                            onSelectTemplate(routine.makePracticeTemplate())
                        } label: {
                            GarageEnvironmentFocusRoutineRow(
                                title: routine.title,
                                subtitle: routine.purpose,
                                detail: "\(routine.drillIDs.count) drills - built-in",
                                systemImage: environment.systemImage
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    ForEach(savedTemplates, id: \.id) { template in
                        Button {
                            garageTriggerSelection()
                            onSelectTemplate(template)
                        } label: {
                            GarageEnvironmentFocusRoutineRow(
                                title: template.title,
                                subtitle: template.drills.first?.focusArea ?? "Saved routine",
                                detail: "\(template.drills.count) drills - saved",
                                systemImage: "bookmark.fill"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var diagnosticSection: some View {
        Button {
            garageTriggerSelection()
            onOpenDiagnostic()
        } label: {
            GarageProCard(cornerRadius: 22, padding: 16) {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(GarageProTheme.accent)
                        .frame(width: 54, height: 54)
                        .background(GarageProTheme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Need A Specific Prescription?")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(GarageProTheme.textPrimary)

                        Text("Use the existing diagnostic path when the main plan needs a fault-specific starting point.")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(GarageProTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(GarageProTheme.textSecondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func generatePlan() {
        let plan = GarageLocalCoachPlanner.generatePlan(
            for: environment,
            recentRecords: records
        )
        onGeneratePlan(plan)
    }
}

private struct GarageEnvironmentFocusMetricStrip: View {
    let sessionCount: Int
    let routineCount: Int
    let latestEfficiency: String

    var body: some View {
        HStack(spacing: 10) {
            GarageEnvironmentFocusMetric(title: "Sessions", value: "\(sessionCount)")
            GarageEnvironmentFocusMetric(title: "Routines", value: "\(routineCount)")
            GarageEnvironmentFocusMetric(title: "Latest", value: latestEfficiency)
        }
    }
}

private struct GarageEnvironmentFocusMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .black, design: .monospaced))
                .foregroundStyle(GarageProTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .textCase(.uppercase)
                .tracking(1.5)
                .foregroundStyle(GarageProTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
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

private struct GarageEnvironmentFocusHeader: View {
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

private struct GarageEnvironmentFocusRoutineRow: View {
    let title: String
    let subtitle: String
    let detail: String
    let systemImage: String

    var body: some View {
        GarageProCard(cornerRadius: 22, padding: 16) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(GarageProTheme.accent)
                    .frame(width: 54, height: 54)
                    .background(GarageProTheme.accent.opacity(0.13), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(GarageProTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(subtitle)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(GarageProTheme.textSecondary)
                        .lineLimit(2)

                    Text(detail)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(GarageProTheme.accent.opacity(0.85))
                }

                Spacer(minLength: 8)

                Image(systemName: "play.fill")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(GarageProTheme.accent)
            }
        }
    }
}

private extension PracticeSessionRecord {
    var practiceReadbackSummary: String {
        var parts = ["\(completedDrills)/\(totalDrills) drills completed"]

        if totalAttemptedReps > 0 {
            parts.append("\(totalSuccessfulReps)/\(totalAttemptedReps) successful reps")
        }

        return parts.joined(separator: " - ")
    }

    var primaryEnvironmentFocusNote: String? {
        if let cue = GarageCoachingInsight.decode(from: aiCoachingInsight)?
            .primaryCue?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            cue.isEmpty == false {
            return cue
        }

        let feel = sessionFeelNote.trimmingCharacters(in: .whitespacesAndNewlines)
        if feel.isEmpty == false {
            return feel
        }

        let aggregated = aggregatedNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        return aggregated.isEmpty ? nil : aggregated
    }
}

#Preview("Garage Environment Focus") {
    NavigationStack {
        GarageEnvironmentFocusView(
            environment: .net,
            onGeneratePlan: { _ in },
            onSelectTemplate: { _ in },
            onOpenDiagnostic: { }
        )
    }
    .modelContainer(PreviewCatalog.populatedApp)
}
