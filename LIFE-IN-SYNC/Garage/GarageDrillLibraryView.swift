import SwiftData
import SwiftUI

@MainActor
struct GarageDrillLibraryView: View {
    @Query(sort: \PracticeTemplate.title) private var savedTemplates: [PracticeTemplate]

    @State private var selectedRoutine: GarageLibraryRoutineDescriptor?
    @State private var selectedDrill: GarageDrill?

    let onStartSession: (ActivePracticeSession) -> Void

    var body: some View {
        GarageProScaffold(bottomPadding: 28) {
            pageHeader
            heroCard
            routinesSection

            if savedTemplates.isEmpty == false {
                savedRoutinesSection
            }

            drillDictionarySection
        }
        .navigationTitle("Drill Library")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedRoutine) { routine in
            GarageRoutineDetailSheet(
                routine: routine,
                onStartSession: onStartSession
            )
        }
        .sheet(item: $selectedDrill) { drill in
            GarageDrillDetailSheet(
                drill: drill,
                onStartSession: onStartSession
            )
        }
    }

    private var pageHeader: some View {
        GarageCompactPageHeader(
            eyebrow: "Drill Library",
            title: "Drill Library",
            subtitle: "Predefined routines first, reference drills second."
        ) {
            GarageCompactStatBadge(
                value: "\(DrillVault.masterPlaybook.count)",
                label: "Drills"
            )
        }
    }

    private var heroCard: some View {
        GarageProCard(isActive: true, cornerRadius: 22, padding: 14) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(GarageProTheme.accent)
                    .frame(width: 42, height: 42)
                    .background(GarageProTheme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 7) {
                    Text("Routines by environment")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(GarageProTheme.textPrimary)

                    Text("Start predefined work, review saved routines, or open a drill for instruction.")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(GarageProTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var routinesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            GarageProSectionHeader(
                eyebrow: "Predefined",
                title: "Routines By Environment"
            )

            ForEach(PracticeEnvironment.allCases) { environment in
                let routines = DrillVault.routines(in: environment)
                if routines.isEmpty == false {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(environment.displayName)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(GarageProTheme.textPrimary)

                        ForEach(routines) { routine in
                            Button {
                                garageTriggerSelection()
                                selectedRoutine = GarageLibraryRoutineDescriptor(routine: routine)
                            } label: {
                                GarageRoutinePreviewCard(
                                    title: routine.title,
                                    subtitle: routine.purpose,
                                    detailText: "\(routine.drillIDs.count) drills - \(routine.estimatedMinutesText)",
                                    badgeText: "Built-In Routine",
                                    systemImage: environment.systemImage
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var savedRoutinesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            GarageProSectionHeader(
                eyebrow: "Saved",
                title: "Saved Routines"
            )

            ForEach(savedTemplates, id: \.id) { template in
                Button {
                    garageTriggerSelection()
                    selectedRoutine = GarageLibraryRoutineDescriptor(template: template)
                } label: {
                    GarageRoutinePreviewCard(
                        title: template.title,
                        subtitle: template.drills.first?.focusArea ?? "Saved routine",
                        detailText: "\(template.drills.count) drills - \(template.garageEstimatedMinutesText)",
                        badgeText: "Saved Routine",
                        systemImage: "bookmark.fill"
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var drillDictionarySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            GarageProSectionHeader(
                eyebrow: "Reference",
                title: "All Drills"
            )

            ForEach(GarageDrillLibraryCategory.allCases) { category in
                let drills = DrillVault.masterPlaybook.filter { $0.libraryCategory == category }
                if drills.isEmpty == false {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(category.displayName)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(GarageProTheme.textPrimary)

                        ForEach(drills) { drill in
                            Button {
                                garageTriggerSelection()
                                selectedDrill = drill
                            } label: {
                                GarageDrillRowCard(drill: drill)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

private struct GarageRoutinePreviewCard: View {
    let title: String
    let subtitle: String
    let detailText: String
    let badgeText: String
    let systemImage: String

    var body: some View {
        GarageProCard(cornerRadius: 20, padding: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(GarageProTheme.accent)
                    .frame(width: 42, height: 42)
                    .background(GarageProTheme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(badgeText)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .textCase(.uppercase)
                        .tracking(1.4)
                        .foregroundStyle(GarageProTheme.accent.opacity(0.9))

                    Text(title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(GarageProTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(subtitle)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(GarageProTheme.textSecondary)
                        .lineLimit(2)

                    Text(detailText)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(GarageProTheme.textSecondary)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(GarageProTheme.textSecondary)
            }
        }
    }
}

private struct GarageDrillRowCard: View {
    let drill: GarageDrill

    var body: some View {
        let catalog = GarageDrillCatalog.content(for: drill)
        let detail = GarageDrillFocusDetails.detail(for: drill)
        GarageProCard(cornerRadius: 20, padding: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: drill.environment.systemImage)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(GarageProTheme.accent)
                    .frame(width: 42, height: 42)
                    .background(GarageProTheme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(drill.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(GarageProTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(detail.purpose)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(GarageProTheme.textSecondary)
                        .lineLimit(2)

                GarageDrillDirectoryMetaRow(catalog: catalog, clubFamily: drill.clubRange.garageCompactDisplayName)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(GarageProTheme.textSecondary)
            }
        }
    }
}

private struct GarageRoutineDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    let routine: GarageLibraryRoutineDescriptor
    let onStartSession: (ActivePracticeSession) -> Void

    var body: some View {
        NavigationStack {
            GarageProScaffold(bottomPadding: 28) {
                GarageProHeroCard(
                    eyebrow: routine.sourceLabel,
                    title: routine.title,
                    subtitle: routine.purpose,
                    value: "\(routine.estimatedMinutes)",
                    valueLabel: "Minutes"
                ) {
                    Image(systemName: routine.environment.systemImage)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(GarageProTheme.accent)
                        .frame(width: 64, height: 64)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(GarageProTheme.accent.opacity(0.3), lineWidth: 1)
                        )
                }

                GarageProCard(cornerRadius: 24, padding: 18) {
                    Text("Routine Stack")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .textCase(.uppercase)
                        .tracking(2)
                        .foregroundStyle(GarageProTheme.accent)

                    ForEach(routine.drillRows) { row in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.title)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(GarageProTheme.textPrimary)

                            Text(row.summary)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(GarageProTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 4)
                    }
                }

                GarageProPrimaryButton(
                    title: "Start Routine",
                    systemImage: "play.fill"
                ) {
                    onStartSession(ActivePracticeSession(template: routine.launchTemplate))
                    dismiss()
                }
            }
            .navigationTitle(routine.environment.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct GarageDrillDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var launchDraft: GarageDrillLaunchDraft

    let drill: GarageDrill
    let onStartSession: (ActivePracticeSession) -> Void

    private var detail: GarageDrillFocusDetail {
        GarageDrillFocusDetails.detail(for: drill)
    }

    private var catalog: GarageDrillCatalogContent {
        GarageDrillCatalog.content(for: drill)
    }

    private var routineTitles: String {
        let titles = DrillVault.routines(containing: drill).map(\.title)
        return titles.isEmpty ? "Reference drill" : titles.joined(separator: " • ")
    }

    init(
        drill: GarageDrill,
        onStartSession: @escaping (ActivePracticeSession) -> Void
    ) {
        self.drill = drill
        self.onStartSession = onStartSession
        _launchDraft = State(initialValue: GarageDrillLaunchDraft(drill: drill))
    }

    var body: some View {
        NavigationStack {
            GarageProScaffold(bottomPadding: 28) {
                GarageProHeroCard(
                    eyebrow: drill.libraryCategory.displayName,
                    title: drill.title,
                    subtitle: drill.purpose,
                    value: catalog.difficulty.rawValue,
                    valueLabel: "Difficulty"
                ) {
                    Image(systemName: drill.environment.systemImage)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(GarageProTheme.accent)
                        .frame(width: 64, height: 64)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(GarageProTheme.accent.opacity(0.3), lineWidth: 1)
                        )
                }

                GarageProCard(cornerRadius: 24, padding: 18) {
                    Text("Primary Cue")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .textCase(.uppercase)
                        .tracking(2)
                        .foregroundStyle(GarageProTheme.accent)

                    Text(drill.abstractFeelCue)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(GarageProTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("\(catalog.category) • \(drill.clubRange.garageCompactDisplayName) • \(GarageDrillCatalog.defaultPrescription(for: drill.makeGeneratedPracticeTemplateDrill(seedKey: "detail-meta-\(drill.id)")).mode.directoryLabel)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(GarageProTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                GarageProCard(cornerRadius: 24, padding: 18) {
                    Text("What It Trains")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .textCase(.uppercase)
                        .tracking(2)
                        .foregroundStyle(GarageProTheme.accent)

                    Text(catalog.richInstructionContent.whatItTrains)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(GarageProTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Why It Matters")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .textCase(.uppercase)
                        .tracking(2)
                        .foregroundStyle(GarageProTheme.accent)

                    Text(catalog.richInstructionContent.whyItMatters)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(GarageProTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                GarageProCard(cornerRadius: 24, padding: 18) {
                    Text("Setup Walkthrough")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .textCase(.uppercase)
                        .tracking(2)
                        .foregroundStyle(GarageProTheme.accent)

                    ForEach(catalog.richInstructionContent.setupWalkthrough, id: \.self) { item in
                        Text(item)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(GarageProTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                GarageProCard(cornerRadius: 24, padding: 18) {
                    Text("Key Cues")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .textCase(.uppercase)
                        .tracking(2)
                        .foregroundStyle(GarageProTheme.accent)

                    ForEach(catalog.richInstructionContent.keyCues, id: \.self) { item in
                        Text(item)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(GarageProTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                GarageProCard(cornerRadius: 24, padding: 18) {
                    Text("Common Mistakes")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .textCase(.uppercase)
                        .tracking(2)
                        .foregroundStyle(GarageProTheme.accent)

                    ForEach(catalog.richInstructionContent.commonMistakes, id: \.self) { item in
                        Text(item)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(GarageProTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                GarageDrillLaunchConfigCard(draft: $launchDraft, catalog: catalog)

                GarageProPrimaryButton(
                    title: "Start Drill",
                    systemImage: "play.fill"
                ) {
                    onStartSession(launchDraft.makeSession(for: drill))
                    dismiss()
                }
            }
            .navigationTitle(drill.environment.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct GarageLibraryRoutineDescriptor: Identifiable {
    let id: String
    let title: String
    let purpose: String
    let environment: PracticeEnvironment
    let sourceLabel: String
    let totalRepCount: Int
    let estimatedMinutes: Int
    let drillRows: [GarageLibraryRoutineDrillRow]
    let launchTemplate: PracticeTemplate

    init(routine: GarageRoutine) {
        let launchTemplate = routine.makePracticeTemplate()
        let resolvedDrills = DrillVault.drills(for: routine)

        self.id = "built-in:\(routine.id)"
        self.title = routine.title
        self.purpose = routine.purpose
        self.environment = routine.environment
        self.sourceLabel = "Built-In Routine"
        self.totalRepCount = launchTemplate.drills.reduce(0) { $0 + $1.defaultRepCount }
        self.estimatedMinutes = resolvedDrills.reduce(0) { $0 + GarageDrillFocusDetails.detail(for: $1).estimatedMinutes }
        self.drillRows = resolvedDrills.map {
            return GarageLibraryRoutineDrillRow(
                id: $0.id,
                title: $0.title,
                summary: "\($0.libraryCategory.displayName) • \($0.clubRange.garageCompactDisplayName) • \(GarageDrillCatalog.defaultPrescription(for: $0.makeGeneratedPracticeTemplateDrill(seedKey: "routine-row-\($0.id)")).mode.directoryLabel)"
            )
        }
        self.launchTemplate = launchTemplate
    }

    init(template: PracticeTemplate) {
        self.id = "saved:\(template.id.uuidString)"
        self.title = template.title
        self.purpose = template.drills.first?.focusArea ?? "Saved routine"
        self.environment = template.environmentValue
        self.sourceLabel = "Saved Routine"
        self.totalRepCount = template.drills.reduce(0) { $0 + $1.defaultRepCount }
        self.estimatedMinutes = template.drills.reduce(0) { partialResult, drill in
            partialResult + GarageDrillFocusDetails.detail(for: drill).estimatedMinutes
        }
        self.drillRows = template.drills.map { drill in
            return GarageLibraryRoutineDrillRow(
                id: drill.id.uuidString,
                title: drill.title,
                summary: drill.metadataSummary
            )
        }
        self.launchTemplate = template
    }

    var estimatedMinutesText: String {
        "\(estimatedMinutes) min"
    }
}

private struct GarageLibraryRoutineDrillRow: Identifiable {
    let id: String
    let title: String
    let summary: String
}

private struct GarageDrillDirectoryMetaRow: View {
    let catalog: GarageDrillCatalogContent
    let clubFamily: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                GarageDrillMetaPill(title: catalog.category)
                GarageDrillMetaPill(title: clubFamily)
                if let mode = catalog.supportedModes.first {
                    GarageDrillMetaPill(title: mode.directoryLabel)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(catalog.equipment.prefix(2), id: \.self) { item in
                        GarageDrillMetaPill(title: item)
                    }
                }
            }
        }
    }
}

private struct GarageDrillMetaPill: View {
    let title: String
    var isAccent = false

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(isAccent ? GarageProTheme.accent : GarageProTheme.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background((isAccent ? GarageProTheme.accent.opacity(0.14) : GarageProTheme.insetSurface), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(isAccent ? GarageProTheme.accent.opacity(0.22) : GarageProTheme.border, lineWidth: 1)
            )
    }
}

private struct GarageDrillLaunchConfigCard: View {
    @Binding var draft: GarageDrillLaunchDraft
    let catalog: GarageDrillCatalogContent

    var body: some View {
        GarageProCard(cornerRadius: 24, padding: 18) {
            Text("Launch Config")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .textCase(.uppercase)
                .tracking(2)
                .foregroundStyle(GarageProTheme.accent)

            GarageLaunchTextField(title: "Club", text: $draft.selectedClub, prompt: catalog.suggestedClubs.first ?? "Optional")

            VStack(alignment: .leading, spacing: 8) {
                Text("Mode")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(GarageProTheme.textSecondary)

                Picker("Mode", selection: $draft.mode) {
                    ForEach(catalog.supportedModes, id: \.self) { mode in
                        Text(mode.directoryLabel).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            HStack(spacing: 12) {
                GarageLaunchStepperCard(title: "Minutes", value: $draft.durationMinutes, range: 1...20)
                GarageLaunchStepperCard(title: "Target", value: $draft.targetCount, range: 1...20)
            }

            GarageLaunchTextField(title: "Goal", text: $draft.goalText, prompt: "Define today's goal")
            GarageLaunchTextField(title: "Active Cue", text: $draft.activeCue, prompt: "One compact cue")
            GarageLaunchTextField(title: "Setup Reminder", text: $draft.activeSetupReminder, prompt: "One setup reminder")
        }
    }
}

private struct GarageLaunchTextField: View {
    let title: String
    @Binding var text: String
    let prompt: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(GarageProTheme.textSecondary)

            TextField(prompt, text: $text)
                .textInputAutocapitalization(.sentences)
                .foregroundStyle(GarageProTheme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(GarageProTheme.insetSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(GarageProTheme.border, lineWidth: 1)
                )
        }
    }
}

private struct GarageLaunchStepperCard: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        Stepper(value: $value, in: range) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(GarageProTheme.textSecondary)

                Text("\(value)")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(GarageProTheme.textPrimary)
            }
        }
        .padding(12)
        .background(GarageProTheme.insetSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(GarageProTheme.border, lineWidth: 1)
        )
    }
}

private struct GarageDrillLaunchDraft {
    var selectedClub: String
    var mode: GarageDrillSessionMode
    var durationMinutes: Int
    var targetCount: Int
    var goalText: String
    var activeCue: String
    var activeSetupReminder: String

    init(drill: GarageDrill) {
        let practiceDrill = drill.makeGeneratedPracticeTemplateDrill(seedKey: "library-launch-\(drill.id)")
        let prescription = GarageDrillCatalog.defaultPrescription(for: practiceDrill)
        self.selectedClub = prescription.selectedClub ?? ""
        self.mode = prescription.mode
        self.durationMinutes = max((prescription.durationSeconds ?? 300) / 60, 1)
        self.targetCount = max(prescription.targetCount ?? max(practiceDrill.defaultRepCount, 1), 1)
        self.goalText = prescription.goalText
        self.activeCue = prescription.activeCue ?? ""
        self.activeSetupReminder = prescription.activeSetupReminder ?? ""
    }

    func makeSession(for drill: GarageDrill) -> ActivePracticeSession {
        let template = drill.makePracticeTemplate()
        let drills = template.drills
        let prescriptions = Dictionary(uniqueKeysWithValues: drills.enumerated().map { offset, practiceDrill in
            let base = GarageDrillCatalog.defaultPrescription(for: practiceDrill, sessionOrder: offset)
            let isPrimary = offset == 0
            let customized = GarageDrillPrescription(
                drillID: practiceDrill.id,
                selectedClub: isPrimary ? selectedClub.nilIfBlank : base.selectedClub,
                mode: isPrimary ? mode : base.mode,
                durationSeconds: isPrimary && mode == .timed ? max(durationMinutes, 1) * 60 : base.durationSeconds,
                targetCount: isPrimary && mode != .timed ? max(targetCount, 1) : base.targetCount,
                goalText: isPrimary ? goalText.fallback(to: base.goalText) : base.goalText,
                intensity: base.intensity,
                activeCue: isPrimary ? activeCue.nilIfBlank ?? base.activeCue : base.activeCue,
                activeSetupReminder: isPrimary ? activeSetupReminder.nilIfBlank ?? base.activeSetupReminder : base.activeSetupReminder,
                scoringBehavior: isPrimary ? mode.scoringBehavior : base.scoringBehavior,
                progressionNotes: base.progressionNotes,
                sessionOrder: offset
            )
            return (practiceDrill.id, customized)
        })

        return ActivePracticeSession(template: template, prescriptionsByDrillID: prescriptions)
    }
}

private extension GarageRoutine {
    var estimatedMinutesText: String {
        let minutes = DrillVault.drills(for: self).reduce(0) { partialResult, drill in
            partialResult + GarageDrillFocusDetails.detail(for: drill).estimatedMinutes
        }

        return "\(minutes) min"
    }
}

private extension PracticeTemplate {
    var garageEstimatedMinutesText: String {
        let minutes = drills.reduce(0) { partialResult, drill in
            partialResult + GarageDrillFocusDetails.detail(for: drill).estimatedMinutes
        }

        return "\(minutes) min"
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func fallback(to value: String) -> String {
        nilIfBlank ?? value
    }
}

private extension GarageDrillSessionMode {
    var scoringBehavior: GarageDrillScoringBehavior {
        switch self {
        case .timed:
            return .timedCompletion
        case .reps:
            return .repCompletion
        case .goal:
            return .goalCompletion
        case .challenge:
            return .challengeCompletion
        case .checklist:
            return .checklistCompletion
        }
    }
}

#Preview("Garage Drill Library") {
    NavigationStack {
        GarageDrillLibraryView { _ in }
    }
    .modelContainer(PreviewCatalog.populatedApp)
}
