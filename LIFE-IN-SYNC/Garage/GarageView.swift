import SwiftData
import SwiftUI

@MainActor
struct GarageView: View {
    @Query(sort: \PracticeTemplate.title) private var userTemplates: [PracticeTemplate]
    @Query(sort: \PracticeSessionRecord.date, order: .reverse) private var records: [PracticeSessionRecord]

    @State private var path: [GarageNavigationDestination] = []
    @State private var isShowingTemplateBuilder = false

    private var averageEfficiencyText: String {
        let attempts = records.reduce(0) { $0 + $1.totalAttemptedReps }
        guard attempts > 0 else { return "--" }

        let success = records.reduce(0) { $0 + $1.totalSuccessfulReps }
        return "\(Int((Double(success) / Double(attempts) * 100).rounded()))%"
    }

    private var displayedRoutineCount: Int {
        DrillVault.predefinedRoutines.count + userTemplates.count
    }

    var body: some View {
        NavigationStack(path: $path) {
            GarageProScaffold {
                heroCard
                metricGrid
                environmentSection
                vaultCard
            }
            .navigationTitle("Garage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomActionBar
            }
            .navigationDestination(for: GarageNavigationDestination.self) { destination in
                switch destination {
                case let .environment(environment):
                    environmentDashboard(for: environment)
                case let .diagnostic(environment):
                    GarageDiagnosticView(initialEnvironment: environment) { drill in
                        garageTriggerSelection()
                        path.append(.activeSession(ActivePracticeSession(template: drill.makePracticeTemplate())))
                    }
                case let .activeSession(session):
                    GarageActiveSessionView(
                        session: session,
                        onEndSession: { path.removeAll() }
                    )
                case .skillVault:
                    GarageSkillVaultView()
                }
            }
            .sheet(isPresented: $isShowingTemplateBuilder) {
                GarageTemplateBuilderWizard()
            }
        }
        .garagePuttingGreenSheetChrome()
    }

    private var heroCard: some View {
        GarageProHeroCard(
            eyebrow: "Dark Masters Practice",
            title: "Garage",
            subtitle: "Choose the training environment, launch a routine, then write the finished session into the Skill Vault.",
            value: "\(displayedRoutineCount)",
            valueLabel: "Routines"
        ) {
            Button {
                garageTriggerSelection()
                path.append(.skillVault)
            } label: {
                Image(systemName: "archivebox.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(GarageProTheme.accent)
                    .frame(width: 60, height: 60)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(GarageProTheme.accent.opacity(0.3), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open Skill Vault")
        }
    }

    private var metricGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            GarageProMetricCard(
                title: "Sessions",
                value: "\(records.count)",
                systemImage: "checkmark.seal.fill",
                isActive: records.isEmpty == false
            )

            GarageProMetricCard(
                title: "Efficiency",
                value: averageEfficiencyText,
                systemImage: "scope",
                isActive: records.isEmpty == false
            )
        }
    }

    private var environmentSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            GarageProSectionHeader(
                eyebrow: "Practice Environment",
                title: "Pick The Surface"
            )

            VStack(spacing: 14) {
                ForEach(PracticeEnvironment.allCases) { environment in
                    Button {
                        garageTriggerSelection()
                        path.append(.environment(environment))
                    } label: {
                        GarageProEnvironmentCard(
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

    private var vaultCard: some View {
        Button {
            garageTriggerSelection()
            path.append(.skillVault)
        } label: {
            GarageProCard(isActive: records.isEmpty == false) {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(GarageProTheme.accent)
                        .frame(width: 60, height: 60)
                        .background(GarageProTheme.accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Skill Vault")
                            .font(.system(.title3, design: .rounded).weight(.black))
                            .foregroundStyle(GarageProTheme.textPrimary)

                        Text(records.isEmpty ? "Completed sessions land here." : "\(records.count) sessions tracked across Garage.")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(GarageProTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(GarageProTheme.textSecondary)
                }
                .frame(minHeight: 60)
            }
        }
        .buttonStyle(.plain)
    }

    private var bottomActionBar: some View {
        HStack {
            Spacer()

            GarageProPrimaryButton(
                title: "New Routine",
                systemImage: "plus"
            ) {
                isShowingTemplateBuilder = true
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private func environmentDashboard(for environment: PracticeEnvironment) -> some View {
        switch environment {
        case .net:
            GarageNetDashboardView(
                onSelectTemplate: { template in
                    path.append(.activeSession(ActivePracticeSession(template: template)))
                },
                onOpenDiagnostic: {
                    path.append(.diagnostic(.net))
                }
            )
        case .range:
            GarageRangeDashboardView(
                onSelectTemplate: { template in
                    path.append(.activeSession(ActivePracticeSession(template: template)))
                },
                onOpenDiagnostic: {
                    path.append(.diagnostic(.range))
                }
            )
        case .puttingGreen:
            GaragePuttingDashboardView(
                onSelectTemplate: { template in
                    path.append(.activeSession(ActivePracticeSession(template: template)))
                },
                onOpenDiagnostic: {
                    path.append(.diagnostic(.puttingGreen))
                }
            )
        }
    }

    private func routineCount(for environment: PracticeEnvironment) -> Int {
        DrillVault.routineCount(in: environment) +
            userTemplates.filter { $0.environment == environment.rawValue }.count
    }
}

@MainActor
struct GarageNetDashboardView: View {
    let onSelectTemplate: (PracticeTemplate) -> Void
    let onOpenDiagnostic: () -> Void

    var body: some View {
        GarageEnvironmentDashboardView(
            environment: .net,
            onSelectTemplate: onSelectTemplate,
            onOpenDiagnostic: onOpenDiagnostic
        )
    }
}

@MainActor
struct GarageRangeDashboardView: View {
    let onSelectTemplate: (PracticeTemplate) -> Void
    let onOpenDiagnostic: () -> Void

    var body: some View {
        GarageEnvironmentDashboardView(
            environment: .range,
            onSelectTemplate: onSelectTemplate,
            onOpenDiagnostic: onOpenDiagnostic
        )
    }
}

@MainActor
struct GaragePuttingDashboardView: View {
    let onSelectTemplate: (PracticeTemplate) -> Void
    let onOpenDiagnostic: () -> Void

    var body: some View {
        GarageEnvironmentDashboardView(
            environment: .puttingGreen,
            onSelectTemplate: onSelectTemplate,
            onOpenDiagnostic: onOpenDiagnostic
        )
    }
}

@MainActor
private struct GarageEnvironmentDashboardView: View {
    @Query(sort: \PracticeTemplate.title) private var allTemplates: [PracticeTemplate]
    @Query(sort: \PracticeSessionRecord.date, order: .reverse) private var records: [PracticeSessionRecord]

    let environment: PracticeEnvironment
    let onSelectTemplate: (PracticeTemplate) -> Void
    let onOpenDiagnostic: () -> Void

    private var builtInRoutines: [GarageDisplayedRoutine] {
        DrillVault.predefinedRoutines
            .filter { $0.environment == environment }
            .map(GarageDisplayedRoutine.init(routine:))
    }

    private var savedRoutines: [GarageDisplayedRoutine] {
        allTemplates
            .filter { $0.environment == environment.rawValue }
            .map(GarageDisplayedRoutine.init(template:))
    }

    private var displayedRoutines: [GarageDisplayedRoutine] {
        builtInRoutines + savedRoutines
    }

    private var environmentRecords: [PracticeSessionRecord] {
        records.filter { $0.environment == environment.rawValue }
    }

    private var catalogDrillCount: Int {
        DrillVault.drillCount(in: environment)
    }

    var body: some View {
        GarageProScaffold {
            GarageProHeroCard(
                eyebrow: "Environment",
                title: environment.displayName,
                subtitle: environment.description,
                value: "\(displayedRoutines.count)",
                valueLabel: "Routines"
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

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                GarageProMetricCard(title: "Drills", value: "\(catalogDrillCount)", systemImage: "list.bullet.clipboard")
                GarageProMetricCard(title: "Sessions", value: "\(environmentRecords.count)", systemImage: "chart.bar.xaxis")
            }

            Button {
                garageTriggerSelection()
                onOpenDiagnostic()
            } label: {
                GaragePrescriptionLaunchCard(environment: environment)
            }
            .buttonStyle(.plain)

            GarageProSectionHeader(
                eyebrow: "Launch Routine",
                title: "Routines"
            )

            if displayedRoutines.isEmpty {
                GarageProCard {
                    Text("No routines available")
                        .font(.system(.title3, design: .rounded).weight(.black))
                        .foregroundStyle(GarageProTheme.textPrimary)

                    Text("Built-in routines should appear here for \(environment.displayName).")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(GarageProTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                VStack(spacing: 14) {
                    ForEach(displayedRoutines) { routine in
                        Button {
                            garageTriggerImpact(.heavy)
                            onSelectTemplate(routine.launchTemplate)
                        } label: {
                            GarageProRoutineCard(routine: routine)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle(environment.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct GarageDisplayedRoutine: Identifiable {
    let id: String
    let title: String
    let environment: PracticeEnvironment
    let drillCount: Int
    let detailText: String
    let sourceLabel: String
    let launchTemplate: PracticeTemplate
    let accentStyle: Color

    init(routine: GarageRoutine) {
        let launchTemplate = routine.makePracticeTemplate()

        self.id = "built-in:\(routine.id)"
        self.title = routine.title
        self.environment = routine.environment
        self.drillCount = launchTemplate.drills.count
        self.detailText = routine.purpose
        self.sourceLabel = "Built-in routine"
        self.launchTemplate = launchTemplate
        self.accentStyle = GarageProTheme.accent.opacity(0.9)
    }

    init(template: PracticeTemplate) {
        self.id = "saved:\(template.id.uuidString)"
        self.title = template.title
        self.environment = template.environmentValue
        self.drillCount = template.drills.count
        self.detailText = template.drills.first?.title ?? "Saved routine"
        self.sourceLabel = "Saved routine"
        self.launchTemplate = template
        self.accentStyle = GarageProTheme.textSecondary
    }
}

private struct GaragePrescriptionLaunchCard: View {
    let environment: PracticeEnvironment

    var body: some View {
        GarageProCard(isActive: true) {
            HStack(alignment: .center, spacing: 16) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(GarageProTheme.accent)
                    .frame(width: 60, height: 60)
                    .background(GarageProTheme.accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                VStack(alignment: .leading, spacing: 7) {
                    Text("Need A Prescription?")
                        .font(.system(.title3, design: .rounded).weight(.black))
                        .foregroundStyle(GarageProTheme.textPrimary)

                    Text("Answer three vibe-based questions for \(environment.displayName), then jump straight into a guided rehearsal.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(GarageProTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Coach-led launch")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(GarageProTheme.accent.opacity(0.9))
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(GarageProTheme.textSecondary)
            }
            .frame(minHeight: 60)
        }
    }
}

private struct GarageProSectionHeader: View {
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

private struct GarageProEnvironmentCard: View {
    let environment: PracticeEnvironment
    let routineCount: Int
    let sessionCount: Int

    var body: some View {
        GarageProCard(isActive: routineCount > 0) {
            HStack(alignment: .center, spacing: 16) {
                Image(systemName: environment.systemImage)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(GarageProTheme.accent)
                    .frame(width: 60, height: 60)
                    .background(GarageProTheme.accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                VStack(alignment: .leading, spacing: 7) {
                    Text(environment.displayName)
                        .font(.system(.title3, design: .rounded).weight(.black))
                        .foregroundStyle(GarageProTheme.textPrimary)

                    Text(environment.description)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(GarageProTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("\(routineCount) routines • \(sessionCount) sessions")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(GarageProTheme.accent.opacity(0.9))
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(GarageProTheme.textSecondary)
            }
            .frame(minHeight: 60)
        }
    }
}

private struct GarageProRoutineCard: View {
    let routine: GarageDisplayedRoutine

    var body: some View {
        GarageProCard(isActive: routine.drillCount > 0) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: routine.environment.systemImage)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(GarageProTheme.accent)
                    .frame(width: 60, height: 60)
                    .background(GarageProTheme.accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Text(routine.title)
                        .font(.system(.title3, design: .rounded).weight(.black))
                        .foregroundStyle(GarageProTheme.textPrimary)
                        .multilineTextAlignment(.leading)

                    Text("\(routine.drillCount) drills • \(routine.environment.displayName)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(GarageProTheme.textSecondary)

                    Text(routine.detailText)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(GarageProTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(routine.sourceLabel)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(routine.accentStyle)
                }

                Spacer(minLength: 8)

                Image(systemName: "play.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(GarageProTheme.accent)
            }
            .frame(minHeight: 60)
        }
    }
}

#Preview("Garage Environment Selector") {
    GarageView()
        .modelContainer(PreviewCatalog.populatedApp)
}

#Preview("Garage Net Dashboard") {
    NavigationStack {
        GarageNetDashboardView(
            onSelectTemplate: { _ in },
            onOpenDiagnostic: { }
        )
    }
    .modelContainer(PreviewCatalog.populatedApp)
}

private enum GarageNavigationDestination: Hashable {
    case environment(PracticeEnvironment)
    case diagnostic(PracticeEnvironment?)
    case activeSession(ActivePracticeSession)
    case skillVault
}
