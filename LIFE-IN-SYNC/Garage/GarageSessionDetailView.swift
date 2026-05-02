import SwiftData
import SwiftUI

@MainActor
struct GarageSessionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PracticeSessionRecord.date, order: .reverse) private var records: [PracticeSessionRecord]

    let record: PracticeSessionRecord
    let allowsInsightGeneration: Bool

    @State private var insight: GarageCoachingInsight?
    @State private var isLoadingInsight = false
    @State private var insightErrorMessage: String?

    private var performanceState: GarageVaultPerformanceState {
        GarageVaultPerformanceState(efficiency: record.aggregateEfficiency)
    }

    private var auditSnapshot: GarageCoachingAuditSnapshot? {
        records.coachingAuditSnapshot(for: record)
    }

    private var previousTemplateSession: PracticeSessionRecord? {
        records.previousTemplateSession(for: record)
    }

    private var canGenerateInsight: Bool {
        records.latestTemplateSession(named: record.templateName)?.id == record.id
    }

    init(record: PracticeSessionRecord, allowsInsightGeneration: Bool = false) {
        self.record = record
        self.allowsInsightGeneration = allowsInsightGeneration
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ModuleSpacing.large) {
                coachCornerCard
                heroCard
                drillResultsSection
                notesSection
            }
            .padding(.horizontal, ModuleSpacing.large)
            .padding(.top, ModuleSpacing.large)
            .padding(.bottom, 40)
        }
        .background(AppModule.garage.theme.screenGradient.ignoresSafeArea())
        .navigationTitle(record.templateName)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: record.id) {
            await loadInsightIfNeeded()
        }
    }

    private var coachCornerCard: some View {
        VStack(alignment: .leading, spacing: ModuleSpacing.medium) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Coach's Corner")
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundStyle(AppModule.garage.theme.textPrimary)

                if let auditSnapshot {
                    GarageCoachingDeltaBadge(snapshot: auditSnapshot)
                }
            }

            if let auditSnapshot {
                Text(coachingImpactText(for: auditSnapshot))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(GarageVaultPalette.impact)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if isLoadingInsight {
                Text("Synthesizing tactical cues from your rep patterns...")
                    .font(.subheadline)
                    .foregroundStyle(AppModule.garage.theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let insight {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(insight.keyCues.enumerated()), id: \.offset) { index, cue in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(index + 1)")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(GarageVaultPalette.emerald)
                                .frame(width: 22, alignment: .leading)

                            Text(cue)
                                .font(.body.weight(.medium))
                                .foregroundStyle(AppModule.garage.theme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            } else if let insightErrorMessage {
                Text(insightErrorMessage)
                    .font(.subheadline)
                    .foregroundStyle(AppModule.garage.theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("No coaching insight is available for this session yet.")
                    .font(.subheadline)
                    .foregroundStyle(AppModule.garage.theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ModuleSpacing.large)
        .background(
            RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            ModuleTheme.garageSurfaceRaised.opacity(0.98),
                            ModuleTheme.garageSurface.opacity(0.98),
                            ModuleTheme.garageSurfaceInset.opacity(0.96)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous)
                        .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous)
                        .stroke(GarageVaultPalette.emerald.opacity(0.42), lineWidth: 0.7)
                )
                .shadow(color: Color.black.opacity(0.24), radius: 10, x: 0, y: 8)
                .shadow(color: GarageVaultPalette.emerald.opacity(0.16), radius: 18, x: 0, y: 0)
        )
    }

    private var heroCard: some View {
        GarageTelemetrySurface(isActive: performanceState.shouldGlow) {
            Text("SESSION READBACK")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .kerning(2.6)
                .foregroundStyle(AppModule.garage.theme.textSecondary)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(record.aggregateEfficiencyText)
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundStyle(performanceState.tint)

                Text(record.environmentDisplayName)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppModule.garage.theme.textSecondary)
            }

            GarageSessionEfficiencyBar(
                efficiency: record.aggregateEfficiency,
                tint: performanceState.tint
            )
            .frame(height: 12)

            Text("\(record.totalSuccessfulReps)/\(record.totalAttemptedReps) successful reps on \(record.date.formatted(date: .abbreviated, time: .omitted))")
                .font(.subheadline)
                .foregroundStyle(AppModule.garage.theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var drillResultsSection: some View {
        VStack(alignment: .leading, spacing: ModuleSpacing.medium) {
            Text("Per-Drill Readback")
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppModule.garage.theme.textPrimary)

            ForEach(record.drillResults) { result in
                GarageSessionDrillResultCard(result: result)
            }
        }
    }

    @ViewBuilder
    private var notesSection: some View {
        if record.sessionFeelNote.isEmpty == false || record.aggregatedNotes.isEmpty == false {
            GarageTelemetrySurface {
                Text("NOTES")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .kerning(2.4)
                    .foregroundStyle(AppModule.garage.theme.textSecondary)

                if record.sessionFeelNote.isEmpty == false {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Session Feel")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppModule.garage.theme.textPrimary)

                        Text(record.sessionFeelNote)
                            .font(.subheadline)
                            .foregroundStyle(AppModule.garage.theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if record.aggregatedNotes.isEmpty == false {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Drill Notes")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppModule.garage.theme.textPrimary)

                        Text(record.aggregatedNotes)
                            .font(.subheadline)
                            .foregroundStyle(AppModule.garage.theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func loadInsightIfNeeded() async {
        if let existing = GarageCoachingInsight.decode(from: record.aiCoachingInsight) {
            insight = existing
            return
        }

        guard allowsInsightGeneration else {
            return
        }

        if isLoadingInsight {
            return
        }

        guard canGenerateInsight else {
            insightErrorMessage = "Coach's Corner only synthesizes the latest session for each template."
            return
        }

        isLoadingInsight = true
        insightErrorMessage = nil

        let previousInsight = GarageCoachingInsight.decode(from: previousTemplateSession?.aiCoachingInsight)

        let input = GarageCoachingInsightInput(
            templateName: record.templateName,
            environmentName: record.environmentDisplayName,
            sessionFeelNote: record.sessionFeelNote,
            drillResults: record.drillResults,
            previousSessionEfficiencyPercentage: previousTemplateSession?.aggregateEfficiencyPercentage,
            currentSessionEfficiencyPercentage: record.aggregateEfficiencyPercentage,
            previousCue: previousInsight?.primaryCue
        )

        do {
            let jsonString = try await Task.detached(priority: .utility) {
                try await GarageIntelligenceService.shared.generateInsight(for: input)
            }.value

            record.aiCoachingInsight = jsonString
            try modelContext.save()
            insight = GarageCoachingInsight.decode(from: jsonString)
        } catch GarageIntelligenceError.missingAPIKey {
            insightErrorMessage = "Add `GEMINI_API_KEY` to generate Coach's Corner insights."
        } catch {
            insightErrorMessage = "Garage couldn't generate a coaching cue for this session."
        }

        isLoadingInsight = false
    }

    private func coachingImpactText(for snapshot: GarageCoachingAuditSnapshot) -> String {
        if let leadingDelta = snapshot.leadingDelta {
            return "Previous cue moved \(leadingDelta.name) \(leadingDelta.deltaText) since the last session."
        }

        return "Previous cue landed at \(snapshot.deltaBadgeText) versus the last session."
    }
}

@MainActor
private struct GarageCoachingDeltaBadge: View {
    let snapshot: GarageCoachingAuditSnapshot

    private var tint: Color {
        snapshot.averageDelta > 0 ? GarageVaultPalette.impact : AppModule.garage.theme.textSecondary
    }

    private var iconName: String {
        if snapshot.averageDelta > 0 {
            return "arrow.up.right"
        }

        if snapshot.averageDelta < 0 {
            return "arrow.down.right"
        }

        return "arrow.right"
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.caption.weight(.bold))

            Text(snapshot.deltaBadgeText)
                .font(.caption.weight(.bold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(ModuleTheme.garageSurfaceInset.opacity(0.94))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(tint.opacity(0.72), lineWidth: 1)
                )
                .shadow(color: tint.opacity(0.16), radius: 8, x: 0, y: 0)
        )
    }
}

@MainActor
private struct GarageSessionDrillResultCard: View {
    let result: DrillResult

    private var performanceState: GarageVaultPerformanceState {
        GarageVaultPerformanceState(efficiency: result.successRatio)
    }

    var body: some View {
        GarageTelemetrySurface(isActive: performanceState.shouldGlow) {
            HStack(alignment: .firstTextBaseline, spacing: ModuleSpacing.medium) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(result.name)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppModule.garage.theme.textPrimary)

                    Text("\(result.successfulReps)/\(result.totalReps) successful reps")
                        .font(.subheadline)
                        .foregroundStyle(AppModule.garage.theme.textSecondary)
                }

                Spacer()

                Text(result.successRatioText)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(performanceState.tint)
            }

            GarageSessionEfficiencyBar(
                efficiency: result.successRatio,
                tint: performanceState.tint
            )
            .frame(height: 12)
        }
    }
}

struct GarageSessionEfficiencyBar: View {
    let efficiency: Double
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            let clampedEfficiency = min(max(efficiency, 0), 1)
            let fillWidth = proxy.size.width * clampedEfficiency

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous)
                    .fill(ModuleTheme.garageSurfaceInset.opacity(0.94))
                    .overlay(
                        RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous)
                            .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
                    )

                RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                tint.opacity(0.82),
                                tint
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(fillWidth, clampedEfficiency == 0 ? 0 : 10))
                    .shadow(color: tint.opacity(0.24), radius: 8, x: 0, y: 0)
            }
        }
    }
}

private extension DrillResult {
    var successRatioText: String {
        "\(Int((successRatio * 100).rounded()))%"
    }
}

#Preview("Garage Session Detail") {
    NavigationStack {
        GarageSessionDetailView(
            record: PracticeSessionRecord(
                templateName: "Short Putt Ladder",
                environment: PracticeEnvironment.puttingGreen.rawValue,
                completedDrills: 2,
                totalDrills: 2,
                drillResults: [
                    DrillResult(name: "Short Putts", successfulReps: 8, totalReps: 10),
                    DrillResult(name: "Around-The-World", successfulReps: 4, totalReps: 5)
                ],
                sessionFeelNote: "Setup stayed stable when I softened grip pressure.",
                aiCoachingInsight: "{\"keyCues\":[\"Keep the grip pressure soft so your start line stays stable.\",\"Open the next session with short-putt ladders before broadening the circle.\"],\"focusDrills\":[\"Short Putts\"]}",
                coachingEfficacyScore: 0.12,
                aggregatedNotes: "Short Putts: Strong face control\nAround-The-World: Broke down on left edge putts."
            )
        )
    }
}
