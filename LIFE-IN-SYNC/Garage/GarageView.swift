import SwiftData
import SwiftUI

@MainActor
struct GarageView: View {
    @Query(sort: \PracticeTemplate.title) private var userTemplates: [PracticeTemplate]
    @Query(sort: \PracticeSessionRecord.date, order: .reverse) private var records: [PracticeSessionRecord]

    @State private var path: [GarageNavigationDestination] = []

    private var averageEfficiencyText: String {
        let attempts = records.reduce(0) { $0 + $1.totalAttemptedReps }
        guard attempts > 0 else { return "--" }

        let success = records.reduce(0) { $0 + $1.totalSuccessfulReps }
        return "\(Int((Double(success) / Double(attempts) * 100).rounded()))%"
    }

    private var displayedRoutineCount: Int {
        DrillVault.predefinedRoutines.count + userTemplates.count
    }

    private var latestRecord: PracticeSessionRecord? {
        records.first
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollViewReader { proxy in
                garageHomeScaffold {
                    homeSummaryCard
                    carryForwardSection
                    environmentSection
                    vaultCard
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    bottomActionBar {
                        garageTriggerSelection()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            proxy.scrollTo(GarageHomeScrollTarget.environments, anchor: .top)
                        }
                    }
                }
            }
            .navigationTitle("Garage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
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
                case let .sessionRecord(record):
                    GarageSessionDetailView(
                        record: record,
                        allowsInsightGeneration: false
                    )
                case .skillVault:
                    GarageSkillVaultView()
                }
            }
        }
        .garagePuttingGreenSheetChrome()
    }

    @ViewBuilder
    private func garageHomeScaffold<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            GarageProTheme.background
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    ModuleTheme.garageBackgroundLift.opacity(0.96),
                    ModuleTheme.garageBackground.opacity(0.98),
                    ModuleTheme.garageSurfaceDark.opacity(0.92)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    content()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 96)
            }
            .scrollIndicators(.hidden)
        }
        .tint(GarageProTheme.accent)
    }

    private var homeSummaryCard: some View {
        GarageProCard(isActive: records.isEmpty == false, cornerRadius: 24, padding: 18) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("GARAGE")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .textCase(.uppercase)
                        .tracking(2.2)
                        .foregroundStyle(GarageProTheme.accent)

                    Text("Calm reps. Clear feedback. Ready routines.")
                        .font(.system(.title2, design: .rounded).weight(.black))
                        .foregroundStyle(GarageProTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Open the last lesson, choose an environment, and keep practice moving.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(GarageProTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Button {
                    garageTriggerSelection()
                    path.append(.skillVault)
                } label: {
                    Image(systemName: "archivebox.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(GarageProTheme.accent)
                        .frame(width: 56, height: 56)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(GarageProTheme.accent.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open Skill Vault")
            }

            HStack(alignment: .top, spacing: 12) {
                GarageHomeMetricPill(
                    title: "Routines",
                    value: "\(displayedRoutineCount)",
                    isActive: displayedRoutineCount > 0
                )

                GarageHomeMetricPill(
                    title: "Sessions",
                    value: "\(records.count)",
                    isActive: records.isEmpty == false
                )

                GarageHomeMetricPill(
                    title: "Efficiency",
                    value: averageEfficiencyText,
                    isActive: records.isEmpty == false
                )
            }
        }
    }

    private var carryForwardSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            GarageProSectionHeader(
                eyebrow: "Carry Forward",
                title: "What Did I Learn Last Time?"
            )

            if let latestRecord {
                Button {
                    garageTriggerSelection()
                    path.append(.sessionRecord(latestRecord))
                } label: {
                    GarageHomeCarryForwardCard(record: latestRecord)
                }
                .buttonStyle(.plain)
            } else {
                GarageHomeCarryForwardEmptyCard(
                    title: "No completed sessions yet",
                    message: "Finish a routine to build your carry forward."
                )
            }
        }
    }

    private var environmentSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            GarageProSectionHeader(
                eyebrow: "Practice Environment",
                title: "Choose Environment"
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
        .id(GarageHomeScrollTarget.environments)
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

    private func bottomActionBar(onChooseEnvironment: @escaping () -> Void) -> some View {
        HStack {
            Spacer()

            GarageProPrimaryButton(
                title: "Choose Environment",
                systemImage: "flag.pattern.checkered"
            ) {
                onChooseEnvironment()
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

    private var latestRecord: PracticeSessionRecord? {
        environmentRecords.first
    }

    private var environmentEfficiencyText: String {
        let attempts = environmentRecords.reduce(0) { $0 + $1.totalAttemptedReps }
        guard attempts > 0 else { return "--" }

        let success = environmentRecords.reduce(0) { $0 + $1.totalSuccessfulReps }
        return "\(Int((Double(success) / Double(attempts) * 100).rounded()))%"
    }

    private var headerFootnote: String {
        var parts = ["\(catalogDrillCount) library drills"]

        if savedRoutines.isEmpty == false {
            let label = savedRoutines.count == 1 ? "saved routine" : "saved routines"
            parts.append("\(savedRoutines.count) \(label)")
        }

        return parts.joined(separator: " • ")
    }

    var body: some View {
        GarageProScaffold {
            environmentHeaderCard
            carryForwardSection
            builtInRoutineSection
            savedRoutineSection
            secondaryActionSection
            archiveSection
        }
        .navigationTitle(environment.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var environmentHeaderCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            GarageProHeroCard(
                eyebrow: "Environment Hub",
                title: environment.displayName,
                subtitle: environment.description,
                value: "\(displayedRoutines.count)",
                valueLabel: displayedRoutines.count == 1 ? "Routine Ready" : "Routines Ready"
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

            GarageProCard(isActive: latestRecord != nil, cornerRadius: 22, padding: 16) {
                HStack(alignment: .top, spacing: 12) {
                    GarageEnvironmentStatBlock(
                        title: "Built-In",
                        value: "\(builtInRoutines.count)"
                    )

                    GarageEnvironmentStatDivider()

                    GarageEnvironmentStatBlock(
                        title: "Completed",
                        value: "\(environmentRecords.count)"
                    )

                    GarageEnvironmentStatDivider()

                    GarageEnvironmentStatBlock(
                        title: "Efficiency",
                        value: environmentEfficiencyText
                    )
                }

                Text(headerFootnote)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(GarageProTheme.textSecondary)
            }
        }
    }

    private var carryForwardSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            GarageProSectionHeader(
                eyebrow: "Carry Forward",
                title: "Last Completed Session"
            )

            GarageEnvironmentCarryForwardCard(
                record: latestRecord,
                environment: environment
            )
        }
    }

    private var builtInRoutineSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            GarageProSectionHeader(
                eyebrow: "Built-In Routine",
                title: "Start Here"
            )

            if builtInRoutines.isEmpty {
                GarageProCard {
                    Text("No built-in routines available")
                        .font(.system(.title3, design: .rounded).weight(.black))
                        .foregroundStyle(GarageProTheme.textPrimary)

                    Text("Built-in routines should appear here for \(environment.displayName).")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(GarageProTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                VStack(spacing: 14) {
                    ForEach(builtInRoutines) { routine in
                        routineLaunchButton(for: routine)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var savedRoutineSection: some View {
        if savedRoutines.isEmpty == false {
            VStack(alignment: .leading, spacing: 14) {
                GarageProSectionHeader(
                    eyebrow: "Saved Routine",
                    title: "Your Routines"
                )

                VStack(spacing: 14) {
                    ForEach(savedRoutines) { routine in
                        routineLaunchButton(for: routine)
                    }
                }
            }
        }
    }

    private var secondaryActionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            GarageProSectionHeader(
                eyebrow: "Coach-Led Option",
                title: "Need A Different Starting Point?"
            )

            Button {
                garageTriggerSelection()
                onOpenDiagnostic()
            } label: {
                GaragePrescriptionLaunchCard(environment: environment)
            }
            .buttonStyle(.plain)
        }
    }

    private var archiveSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            GarageProSectionHeader(
                eyebrow: "Completed Sessions",
                title: "Archive"
            )

            if environmentRecords.isEmpty {
                GarageEnvironmentArchiveEmptyState()
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(environmentRecords, id: \.id) { record in
                        NavigationLink {
                            GarageSessionDetailView(
                                record: record,
                                allowsInsightGeneration: false
                            )
                        } label: {
                            GarageEnvironmentArchiveCard(record: record)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func routineLaunchButton(for routine: GarageDisplayedRoutine) -> some View {
        Button {
            garageTriggerImpact(.heavy)
            onSelectTemplate(routine.launchTemplate)
        } label: {
            GarageProRoutineCard(routine: routine)
        }
        .buttonStyle(.plain)
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
    let estimatedRepCount: Int

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
        self.estimatedRepCount = launchTemplate.drills.reduce(0) { $0 + $1.defaultRepCount }
    }

    init(template: PracticeTemplate) {
        self.id = "saved:\(template.id.uuidString)"
        self.title = template.title
        self.environment = template.environmentValue
        self.drillCount = template.drills.count
        self.detailText = template.drills.first?.focusArea ?? template.drills.first?.title ?? "Saved routine"
        self.sourceLabel = "Your routine"
        self.launchTemplate = template
        self.accentStyle = GarageProTheme.textSecondary
        self.estimatedRepCount = template.drills.reduce(0) { $0 + $1.defaultRepCount }
    }

    var workSummary: String {
        if estimatedRepCount > 0 {
            return "\(drillCount) drills • \(estimatedRepCount) planned reps"
        }

        return "\(drillCount) drills"
    }
}

private struct GaragePrescriptionLaunchCard: View {
    let environment: PracticeEnvironment

    var body: some View {
        GarageProCard {
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

                    Text("Answer a few practice questions for \(environment.displayName), then launch a coach-led routine without leaving Garage.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(GarageProTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Secondary launch option")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(GarageProTheme.textSecondary)
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

                    Text(routine.workSummary)
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

                VStack(alignment: .trailing, spacing: 10) {
                    Image(systemName: "play.fill")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(GarageProTheme.accent)

                    Text("Start Routine")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(GarageProTheme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(GarageProTheme.accent.opacity(0.14))
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(GarageProTheme.accent.opacity(0.28), lineWidth: 1)
                                )
                        )
                }
            }
            .frame(minHeight: 60)
        }
    }
}

private struct GarageHomeMetricPill: View {
    let title: String
    let value: String
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .textCase(.uppercase)
                .tracking(1.6)
                .foregroundStyle(GarageProTheme.textSecondary)

            Text(value)
                .font(.system(size: 22, weight: .black, design: .monospaced))
                .foregroundStyle(GarageProTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(GarageProTheme.insetSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(isActive ? GarageProTheme.accent.opacity(0.24) : GarageProTheme.border, lineWidth: 1)
                )
        )
    }
}

private struct GarageHomeCarryForwardCard: View {
    let record: PracticeSessionRecord

    var body: some View {
        GarageProCard(isActive: true, cornerRadius: 26, padding: 20) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(record.carryForwardRelativeDateText)
                        .font(.caption.weight(.bold))
                        .tracking(1.6)
                        .foregroundStyle(GarageProTheme.accent.opacity(0.92))

                    Text(record.templateName)
                        .font(.system(.title3, design: .rounded).weight(.black))
                        .foregroundStyle(GarageProTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(record.environmentDisplayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(GarageProTheme.textSecondary)
                }

                Spacer(minLength: 8)

                GarageEnvironmentEfficiencyBadge(value: record.aggregateEfficiencyText)
            }

            VStack(alignment: .leading, spacing: 6) {
                if let directiveTitle = record.carryForwardDirectiveTitle {
                    Text(directiveTitle)
                        .font(.caption.weight(.bold))
                        .tracking(1.4)
                        .foregroundStyle(GarageProTheme.textSecondary)
                }

                Text(record.carryForwardDirectiveText)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(GarageProTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(record.practiceReadbackSummary)
                .font(.footnote.weight(.bold))
                .foregroundStyle(GarageProTheme.accent.opacity(0.9))

            HStack {
                Text("Open last session")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(GarageProTheme.accent)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(GarageProTheme.textSecondary)
            }
        }
    }
}

private struct GarageHomeCarryForwardEmptyCard: View {
    let title: String
    let message: String

    var body: some View {
        GarageProCard {
            Text(title)
                .font(.system(.title3, design: .rounded).weight(.black))
                .foregroundStyle(GarageProTheme.textPrimary)

            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(GarageProTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct GarageEnvironmentStatBlock: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .textCase(.uppercase)
                .tracking(1.8)
                .foregroundStyle(GarageProTheme.textSecondary)

            Text(value)
                .font(.system(size: 28, weight: .black, design: .monospaced))
                .foregroundStyle(GarageProTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct GarageEnvironmentStatDivider: View {
    var body: some View {
        Rectangle()
            .fill(GarageProTheme.border)
            .frame(width: 1)
            .padding(.vertical, 2)
    }
}

private struct GarageEnvironmentCarryForwardCard: View {
    let record: PracticeSessionRecord?
    let environment: PracticeEnvironment

    var body: some View {
        GarageProCard(isActive: record != nil) {
            if let record {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(record.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption.weight(.bold))
                                .textCase(.uppercase)
                                .tracking(1.6)
                                .foregroundStyle(GarageProTheme.accent.opacity(0.9))

                            Text(record.templateName)
                                .font(.system(.title3, design: .rounded).weight(.black))
                                .foregroundStyle(GarageProTheme.textPrimary)

                            Text("Routine • \(environment.displayName)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(GarageProTheme.textSecondary)
                        }

                        Spacer(minLength: 8)

                        GarageEnvironmentEfficiencyBadge(value: record.aggregateEfficiencyText)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        if let directiveTitle = record.carryForwardDirectiveTitle {
                            Text(directiveTitle)
                                .font(.caption.weight(.bold))
                                .tracking(1.4)
                                .foregroundStyle(GarageProTheme.textSecondary)
                        }

                        Text(record.carryForwardDirectiveText)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(GarageProTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text(record.practiceReadbackSummary)
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(GarageProTheme.accent.opacity(0.9))
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No completed sessions yet")
                        .font(.system(.title3, design: .rounded).weight(.black))
                        .foregroundStyle(GarageProTheme.textPrimary)

                    Text("Start a routine to build your practice history.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(GarageProTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct GarageEnvironmentArchiveEmptyState: View {
    var body: some View {
        GarageProCard {
            Text("No completed sessions yet")
                .font(.system(.title3, design: .rounded).weight(.black))
                .foregroundStyle(GarageProTheme.textPrimary)

            Text("Completed sessions for this environment will appear here once you finish a routine.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(GarageProTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct GarageEnvironmentArchiveCard: View {
    let record: PracticeSessionRecord

    var body: some View {
        GarageProCard(isActive: true, cornerRadius: 22, padding: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(record.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                        .tracking(1.6)
                        .foregroundStyle(GarageProTheme.accent.opacity(0.9))

                    Text(record.templateName)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(GarageProTheme.textPrimary)

                    Text("Routine • \(record.environmentDisplayName)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(GarageProTheme.textSecondary)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 10) {
                    GarageEnvironmentEfficiencyBadge(value: record.aggregateEfficiencyText)

                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(GarageProTheme.textSecondary)
                }
            }

            if let noteText = record.primarySessionNoteText {
                Text(noteText)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(GarageProTheme.textSecondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(record.practiceReadbackSummary)
                .font(.footnote.weight(.bold))
                .foregroundStyle(GarageProTheme.accent.opacity(0.9))
        }
    }
}

private struct GarageEnvironmentEfficiencyBadge: View {
    let value: String

    var body: some View {
        Text(value)
            .font(.system(size: 15, weight: .black, design: .rounded))
            .foregroundStyle(GarageProTheme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(GarageProTheme.insetSurface)
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(GarageProTheme.border, lineWidth: 1)
                    )
            )
    }
}

private extension PracticeSessionRecord {
    var primarySessionNoteText: String? {
        let feel = sessionFeelNote.trimmingCharacters(in: .whitespacesAndNewlines)
        if feel.isEmpty == false {
            return feel
        }

        let aggregated = aggregatedNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        if aggregated.isEmpty == false {
            return aggregated
        }

        return nil
    }

    var practiceReadbackSummary: String {
        var parts = ["\(completedDrills)/\(totalDrills) drills completed"]

        if totalAttemptedReps > 0 {
            parts.append("\(totalSuccessfulReps)/\(totalAttemptedReps) successful reps")
        }

        return parts.joined(separator: " • ")
    }
}

private enum GarageHomeScrollTarget: Hashable {
    case environments
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
    case sessionRecord(PracticeSessionRecord)
    case skillVault
}
