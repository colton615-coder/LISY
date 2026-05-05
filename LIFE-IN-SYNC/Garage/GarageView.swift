import Foundation
import SwiftData
import SwiftUI

@MainActor
struct GarageView: View {
    @State private var path: [GarageNavigationDestination] = []
    @State private var selectedTab: GarageRootTab = .home

    var body: some View {
        NavigationStack(path: $path) {
            tabRoot
                .navigationDestination(for: GarageNavigationDestination.self) { destination in
                    switch destination {
                    case let .environment(environment):
                        GarageEnvironmentFocusView(
                            environment: environment,
                            onGeneratePlan: { plan in
                                garageTriggerSelection()
                                path.append(.coachPlan(plan))
                            },
                            onSelectTemplate: { template in
                                garageTriggerSelection()
                                path.append(.activeSession(ActivePracticeSession(template: template)))
                            },
                            onOpenDiagnostic: {
                                garageTriggerSelection()
                                path.append(.diagnostic(environment))
                            }
                        )
                    case let .coachPlan(plan):
                        GarageCoachPlanReviewView(plan: plan) { reviewedPlan in
                            garageTriggerSelection()
                            path.append(.activeSession(ActivePracticeSession(template: reviewedPlan.makePracticeTemplate())))
                        }
                    case let .diagnostic(environment):
                        GarageDiagnosticView(initialEnvironment: environment) { drill in
                            garageTriggerSelection()
                            path.append(.activeSession(ActivePracticeSession(template: drill.makePracticeTemplate())))
                        }
                    case let .activeSession(session):
                        GarageActiveSessionView(
                            session: session,
                            onEndSession: {
                                path.removeAll()
                                selectedTab = .vault
                            }
                        )
                    case let .sessionRecord(record):
                        GarageSessionDetailView(
                            record: record,
                            allowsInsightGeneration: false
                        )
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if path.isEmpty && selectedTab != .home {
                        GarageInternalTabBar(selectedTab: $selectedTab)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 8)
                    }
                }
        }
        .garagePuttingGreenSheetChrome()
    }

    @ViewBuilder
    private var tabRoot: some View {
        switch selectedTab {
        case .home:
            GarageHomeTabView(
                selectedTab: $selectedTab,
                onOpenEnvironment: { environment in
                    garageTriggerSelection()
                    path.append(.environment(environment))
                },
                onStartRoutine: { routine in
                    garageTriggerSelection()
                    path.append(.activeSession(ActivePracticeSession(template: routine.makePracticeTemplate())))
                },
                onGenerateRoutine: { environment, recentRecords in
                    garageTriggerSelection()
                    path.append(.coachPlan(GarageLocalCoachPlanner.generatePlan(for: environment, recentRecords: recentRecords)))
                },
                onOpenLatestSession: { record in
                    garageTriggerSelection()
                    path.append(.sessionRecord(record))
                }
            )
        case .vault:
            GarageSkillVaultView()
        case .drills:
            GarageDrillLibraryView { template in
                garageTriggerSelection()
                path.append(.activeSession(ActivePracticeSession(template: template)))
            }
        }
    }
}

private enum GarageNavigationDestination: Hashable {
    case environment(PracticeEnvironment)
    case coachPlan(GarageGeneratedPracticePlan)
    case diagnostic(PracticeEnvironment?)
    case activeSession(ActivePracticeSession)
    case sessionRecord(PracticeSessionRecord)
}

private enum GarageRootTab: String, CaseIterable, Identifiable {
    case home
    case vault
    case drills

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:
            "Home"
        case .vault:
            "Vault"
        case .drills:
            "Drills"
        }
    }

    var navigationTitle: String {
        switch self {
        case .home:
            "Garage"
        case .vault:
            "Skill Vault"
        case .drills:
            "Drill Library"
        }
    }

    var systemImage: String {
        switch self {
        case .home:
            "house.fill"
        case .vault:
            "archivebox.fill"
        case .drills:
            "book.closed.fill"
        }
    }
}

struct GarageProSectionHeader: View {
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

@MainActor
private struct GarageHomeTabView: View {
    @Query(sort: \PracticeSessionRecord.date, order: .reverse) private var records: [PracticeSessionRecord]
    @State private var selectedRoutineIDs: [String: String] = [:]
    @Binding var selectedTab: GarageRootTab

    let onOpenEnvironment: (PracticeEnvironment) -> Void
    let onStartRoutine: (GarageRoutine) -> Void
    let onGenerateRoutine: (PracticeEnvironment, [PracticeSessionRecord]) -> Void
    let onOpenLatestSession: (PracticeSessionRecord) -> Void

    private var latestRecord: PracticeSessionRecord? {
        records.first
    }

    var body: some View {
        GarageProScaffold(bottomPadding: 40) {
            environmentSection
            carryForwardSection
            librarySection
        }
        .navigationTitle("Garage")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var environmentSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            GarageProSectionHeader(
                eyebrow: "Start Here",
                title: "Choose Environment"
            )

            VStack(spacing: 14) {
                ForEach(PracticeEnvironment.allCases) { environment in
                    GarageHomeEnvironmentCard(
                        environment: environment,
                        sessionCount: records.filter { $0.environment == environment.rawValue }.count,
                        selectedRoutine: selectedRoutine(for: environment),
                        routines: DrillVault.routines(in: environment),
                        onSelectRoutine: { routine in
                            selectedRoutineIDs[environment.rawValue] = routine.id
                        },
                        onStartRoutine: {
                            onStartRoutine(selectedRoutine(for: environment))
                        },
                        onGenerateRoutine: {
                            onGenerateRoutine(environment, records)
                        },
                        onBrowseAll: {
                            onOpenEnvironment(environment)
                        }
                    )
                }
            }
        }
    }

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            GarageProSectionHeader(
                eyebrow: "More Garage",
                title: "Vault + Drills"
            )

            GarageInlineTabSwitcher(selectedTab: $selectedTab)
        }
    }

    private var carryForwardSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            GarageProSectionHeader(
                eyebrow: "Carry Forward",
                title: "What did I learn last time?"
            )

            if let latestRecord {
                Button {
                    onOpenLatestSession(latestRecord)
                } label: {
                    GarageProCard(isActive: true, cornerRadius: 24, padding: 18) {
                        Text(relativeSessionText(for: latestRecord.date))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .textCase(.uppercase)
                            .tracking(2)
                            .foregroundStyle(GarageProTheme.accent)

                        Text(latestRecord.templateName)
                            .font(.system(.headline, design: .rounded).weight(.black))
                            .foregroundStyle(GarageProTheme.textPrimary)

                        Text(carryForwardNote(for: latestRecord))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(GarageProTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("\(latestRecord.aggregateEfficiencyText) efficiency • \(latestRecord.totalSuccessfulReps)/\(latestRecord.totalAttemptedReps) successful reps")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(GarageProTheme.accent.opacity(0.88))
                    }
                }
                .buttonStyle(.plain)
            } else {
                GarageProCard(cornerRadius: 24, padding: 18) {
                    Text("No completed sessions yet")
                        .font(.system(.headline, design: .rounded).weight(.black))
                        .foregroundStyle(GarageProTheme.textPrimary)

                    Text("Finish a routine and Garage will bring the most useful cue back here.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(GarageProTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func selectedRoutine(for environment: PracticeEnvironment) -> GarageRoutine {
        let routines = DrillVault.routines(in: environment)
        let storedID = selectedRoutineIDs[environment.rawValue]

        if let storedID,
           let matched = routines.first(where: { $0.id == storedID }) {
            return matched
        }

        return routines.first ?? DrillVault.predefinedRoutines.first(where: { $0.environment == environment }) ?? DrillVault.predefinedRoutines[0]
    }

    private func carryForwardNote(for record: PracticeSessionRecord) -> String {
        if let cue = GarageCoachingInsight.decode(from: record.aiCoachingInsight)?
            .primaryCue?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           cue.isEmpty == false {
            return cue
        }

        let feel = record.sessionFeelNote.trimmingCharacters(in: .whitespacesAndNewlines)
        if feel.isEmpty == false {
            return feel
        }

        let notes = record.aggregatedNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        return notes.isEmpty ? "No cue recorded yet. Open the session to review the full readback." : notes
    }

    private func relativeSessionText(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Last Session • \(formatter.localizedString(for: date, relativeTo: .now).capitalized)"
    }
}

private struct GarageHomeEnvironmentCard: View {
    let environment: PracticeEnvironment
    let sessionCount: Int
    let selectedRoutine: GarageRoutine
    let routines: [GarageRoutine]
    let onSelectRoutine: (GarageRoutine) -> Void
    let onStartRoutine: () -> Void
    let onGenerateRoutine: () -> Void
    let onBrowseAll: () -> Void

    var body: some View {
        GarageProCard(isActive: true, cornerRadius: 26, padding: 16) {
            GarageEnvironmentCardHeader(
                environment: environment,
                sessionCount: sessionCount,
                routineCount: routines.count,
                onBrowseAll: onBrowseAll
            )

            GarageRoutineChipRow(
                routines: routines,
                selectedRoutineID: selectedRoutine.id,
                onSelectRoutine: onSelectRoutine
            )

            GarageRoutineDetailGrid(routine: selectedRoutine)

            GarageRoutineActionRow(
                onGenerateRoutine: onGenerateRoutine,
                onStartRoutine: onStartRoutine
            )
        }
    }
}

private struct GarageEnvironmentCardHeader: View {
    let environment: PracticeEnvironment
    let sessionCount: Int
    let routineCount: Int
    let onBrowseAll: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: environment.systemImage)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(GarageProTheme.accent)
                .frame(width: 48, height: 48)
                .background(GarageProTheme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(environment.displayName)
                    .font(.system(.title3, design: .rounded).weight(.black))
                    .foregroundStyle(GarageProTheme.textPrimary)

                Text(environment.description)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(GarageProTheme.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text("\(routineCount) preset routines • \(sessionCount) saved sessions")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(GarageProTheme.accent.opacity(0.88))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button(action: onBrowseAll) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(GarageProTheme.textSecondary)
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(GarageProTheme.insetSurface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(GarageProTheme.border, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open \(environment.displayName)")
        }
    }
}

private struct GarageRoutineChipRow: View {
    let routines: [GarageRoutine]
    let selectedRoutineID: String
    let onSelectRoutine: (GarageRoutine) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preset Routines")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .textCase(.uppercase)
                .tracking(2)
                .foregroundStyle(GarageProTheme.accent)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(routines) { routine in
                        GarageRoutineChip(
                            routine: routine,
                            isSelected: routine.id == selectedRoutineID,
                            action: {
                                onSelectRoutine(routine)
                            }
                        )
                    }
                }
                .padding(.vertical, 1)
            }
        }
    }
}

private struct GarageRoutineChip: View {
    let routine: GarageRoutine
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            guard isSelected == false else { return }
            garageTriggerSelection()
            action()
        } label: {
            HStack(spacing: 6) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .black))
                }

                Text(routine.title)
                    .lineLimit(1)
            }
            .font(.footnote.weight(.bold))
            .foregroundStyle(isSelected ? ModuleTheme.garageSurfaceDark : GarageProTheme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? GarageProTheme.accent : GarageProTheme.insetSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? GarageProTheme.accent.opacity(0.34) : GarageProTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct GarageRoutineDetailGrid: View {
    let routine: GarageRoutine

    private var drillCount: Int {
        routine.drillIDs.count
    }

    private var totalRepCount: Int {
        DrillVault.drills(for: routine).reduce(0) { $0 + $1.defaultRepCount }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            GarageRoutineSummaryPanel(routine: routine)
            GarageRoutineMetricsPanel(
                routine: routine,
                drillCount: drillCount,
                totalRepCount: totalRepCount
            )
        }
    }
}

private struct GarageRoutineSummaryPanel: View {
    let routine: GarageRoutine

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Aims to help with")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .textCase(.uppercase)
                .tracking(1.4)
                .foregroundStyle(GarageProTheme.textSecondary)

            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(routine.title)
                        .font(.headline.weight(.black))
                        .foregroundStyle(GarageProTheme.textPrimary)
                        .lineLimit(2)

                    Text(routine.purpose)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(GarageProTheme.textSecondary)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.up.right")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(GarageProTheme.textSecondary.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(GarageProTheme.insetSurface.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(GarageProTheme.border, lineWidth: 1)
                )
        )
    }
}

private struct GarageRoutineMetricsPanel: View {
    let routine: GarageRoutine
    let drillCount: Int
    let totalRepCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GarageCompactMetricBlock(
                title: "Est. Time",
                primaryValue: "\(routine.estimatedMinutes) min",
                secondaryValue: "\(drillCount) drills"
            )

            GarageDifficultyMetric(
                title: "Difficulty",
                difficulty: routine.difficulty,
                totalRepCount: totalRepCount
            )
        }
        .frame(width: 132, alignment: .topLeading)
    }
}

private struct GarageCompactMetricBlock: View {
    let title: String
    let primaryValue: String
    let secondaryValue: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .textCase(.uppercase)
                .tracking(1.6)
                .foregroundStyle(GarageProTheme.textSecondary)

            Text(primaryValue)
                .font(.footnote.weight(.bold))
                .foregroundStyle(GarageProTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(secondaryValue)
                .font(.caption.weight(.bold))
                .foregroundStyle(GarageProTheme.accent.opacity(0.82))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(GarageProTheme.surface.opacity(0.66))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(GarageProTheme.border, lineWidth: 1)
                )
        )
    }
}

private struct GarageDifficultyMetric: View {
    let title: String
    let difficulty: GarageRoutineDifficulty
    let totalRepCount: Int

    private var barCount: Int {
        switch difficulty {
        case .foundation:
            1
        case .build:
            2
        case .pressure:
            3
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .textCase(.uppercase)
                .tracking(1.6)
                .foregroundStyle(GarageProTheme.textSecondary)

            Text(difficulty.displayName)
                .font(.footnote.weight(.bold))
                .foregroundStyle(GarageProTheme.textPrimary)

            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(index < barCount ? GarageProTheme.accent : GarageProTheme.border.opacity(0.7))
                        .frame(width: 22, height: 6)
                }
            }

            Text("\(totalRepCount) reps")
                .font(.caption.weight(.bold))
                .foregroundStyle(GarageProTheme.accent.opacity(0.82))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(GarageProTheme.surface.opacity(0.66))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(GarageProTheme.border, lineWidth: 1)
                )
        )
    }
}

private struct GarageRoutineActionRow: View {
    let onGenerateRoutine: () -> Void
    let onStartRoutine: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            GarageHomeSecondaryButton(
                title: "AI Generate New Routine",
                systemImage: "sparkles",
                helperText: "Describe what you want to work on...",
                action: onGenerateRoutine
            )

            GarageProPrimaryButton(
                title: "Start Routine",
                systemImage: "play.fill",
                action: onStartRoutine
            )
        }
    }
}

private struct GarageHomeSecondaryButton: View {
    let title: String
    let systemImage: String
    let helperText: String
    let action: () -> Void

    var body: some View {
        Button {
            garageTriggerSelection()
            action()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Label(title, systemImage: systemImage)
                    .font(.footnote.weight(.bold))
                    .multilineTextAlignment(.leading)

                Text(helperText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(GarageProTheme.textSecondary)
                    .lineLimit(2)
            }
            .foregroundStyle(GarageProTheme.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(GarageProTheme.insetSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(GarageProTheme.accent.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct GarageInlineTabSwitcher: View {
    @Binding var selectedTab: GarageRootTab

    var body: some View {
        HStack(spacing: 10) {
            ForEach(GarageRootTab.allCases.filter { $0 != .home }) { tab in
                Button {
                    garageTriggerSelection()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 14, weight: .bold))

                        Text(tab.title)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(GarageProTheme.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(GarageProTheme.insetSurface.opacity(0.84))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(GarageProTheme.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.navigationTitle)
            }
        }
    }
}

private struct GarageInternalTabBar: View {
    @Binding var selectedTab: GarageRootTab

    var body: some View {
        HStack(spacing: 10) {
            ForEach(GarageRootTab.allCases) { tab in
                Button {
                    garageTriggerSelection()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 16, weight: .bold))
                        Text(tab.title)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(selectedTab == tab ? ModuleTheme.garageSurfaceDark : GarageProTheme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(selectedTab == tab ? GarageProTheme.accent : GarageProTheme.insetSurface.opacity(0.72))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(selectedTab == tab ? GarageProTheme.accent.opacity(0.28) : GarageProTheme.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.navigationTitle)
            }
        }
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(GarageProTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(GarageProTheme.border, lineWidth: 1)
        )
        .shadow(color: GarageProTheme.darkShadow, radius: 16, x: 0, y: 10)
        .shadow(color: GarageProTheme.glow.opacity(0.18), radius: 18, x: 0, y: 0)
    }
}

#Preview("Garage v2 Root") {
    GarageView()
        .modelContainer(PreviewCatalog.populatedApp)
}
