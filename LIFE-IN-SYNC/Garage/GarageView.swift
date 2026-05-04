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
                    if path.isEmpty {
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
                onOpenEnvironment: { environment in
                    garageTriggerSelection()
                    path.append(.environment(environment))
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
    @Query(sort: \PracticeTemplate.title) private var savedRoutines: [PracticeTemplate]
    @Query(sort: \PracticeSessionRecord.date, order: .reverse) private var records: [PracticeSessionRecord]

    let onOpenEnvironment: (PracticeEnvironment) -> Void
    let onOpenLatestSession: (PracticeSessionRecord) -> Void

    private var latestRecord: PracticeSessionRecord? {
        records.first
    }

    private var displayedRoutineCount: Int {
        DrillVault.predefinedRoutines.count + savedRoutines.count
    }

    var body: some View {
        GarageProScaffold(bottomPadding: 28) {
            heroCard
            environmentSection
            carryForwardSection
        }
        .navigationTitle("Garage")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var heroCard: some View {
        GarageProHeroCard(
            eyebrow: "Garage",
            title: "Choose a surface. Start training.",
            subtitle: "Routine-first practice that stays calm, measurable, and easy to review.",
            value: "\(displayedRoutineCount)",
            valueLabel: "Routines Ready"
        ) {
            Image(systemName: "figure.golf")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(GarageProTheme.accent)
                .frame(width: 64, height: 64)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(GarageProTheme.accent.opacity(0.3), lineWidth: 1)
                )
        }
    }

    private var environmentSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            GarageProSectionHeader(
                eyebrow: "Start Here",
                title: "Choose Environment"
            )

            VStack(spacing: 14) {
                ForEach(PracticeEnvironment.allCases) { environment in
                    Button {
                        onOpenEnvironment(environment)
                    } label: {
                        GarageHomeEnvironmentCard(
                            environment: environment,
                            routineCount: routineCount(for: environment),
                            sessionCount: records.filter { $0.environment == environment.rawValue }.count
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
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

    private func routineCount(for environment: PracticeEnvironment) -> Int {
        DrillVault.routineCount(in: environment) +
            savedRoutines.filter { $0.environment == environment.rawValue }.count
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
    let routineCount: Int
    let sessionCount: Int

    var body: some View {
        GarageProCard(isActive: routineCount > 0, cornerRadius: 24, padding: 18) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: environment.systemImage)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(GarageProTheme.accent)
                    .frame(width: 56, height: 56)
                    .background(GarageProTheme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(environment.displayName)
                        .font(.system(.title3, design: .rounded).weight(.black))
                        .foregroundStyle(GarageProTheme.textPrimary)

                    Text(environment.description)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(GarageProTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("\(routineCount) routines ready • \(sessionCount) saved sessions")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(GarageProTheme.accent.opacity(0.88))
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(GarageProTheme.textSecondary)
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
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(selectedTab == tab ? GarageProTheme.accent : GarageProTheme.insetSurface.opacity(0.72))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(selectedTab == tab ? GarageProTheme.accent.opacity(0.28) : GarageProTheme.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.navigationTitle)
            }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(GarageProTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
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
