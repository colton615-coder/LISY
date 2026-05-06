import Foundation
import SwiftData
import SwiftUI

struct GarageRoutineReviewPlan: Identifiable, Hashable {
    enum Source: Hashable {
        case saved
        case generated

        var eyebrow: String {
            switch self {
            case .saved:
                return "Saved Routine"
            case .generated:
                return "Generated Routine"
            }
        }

        var canSave: Bool {
            switch self {
            case .saved:
                return false
            case .generated:
                return true
            }
        }
    }

    let id: UUID
    let title: String
    let environment: PracticeEnvironment
    let purpose: String
    let note: String?
    let drills: [PracticeTemplateDrill]
    let source: Source
    let createdAt: Date

    init(template: PracticeTemplate, selectedEnvironment: PracticeEnvironment) {
        let environment = PracticeEnvironment(rawValue: template.environment) ?? selectedEnvironment
        let fallbackPurpose = template.drills.first?.focusArea.trimmingCharacters(in: .whitespacesAndNewlines)

        self.id = template.id
        self.title = template.title
        self.environment = environment
        self.purpose = fallbackPurpose?.isEmpty == false ? fallbackPurpose ?? "Saved routine" : "Saved routine"
        self.note = nil
        self.drills = template.drills
        self.source = .saved
        self.createdAt = template.createdAt
    }

    init(generatedPlan: GarageGeneratedPracticePlan) {
        let note = generatedPlan.coachNote.trimmingCharacters(in: .whitespacesAndNewlines)

        self.id = generatedPlan.id
        self.title = generatedPlan.title
        self.environment = generatedPlan.environment
        self.purpose = generatedPlan.objective
        self.note = note.isEmpty ? nil : note
        self.drills = generatedPlan.drills
        self.source = .generated
        self.createdAt = .now
    }

    var drillCount: Int {
        drills.count
    }

    var totalRepCount: Int {
        drills.reduce(0) { $0 + $1.defaultRepCount }
    }

    var estimatedDurationMinutes: Int {
        guard drills.isEmpty == false else {
            return 0
        }

        let detailedMinutes = drills.reduce(0) { partialResult, drill in
            partialResult + GarageDrillFocusDetails.detail(for: drill).estimatedMinutes
        }

        return max(12, detailedMinutes)
    }

    var canStart: Bool {
        drills.isEmpty == false
    }

    func makePracticeTemplate() -> PracticeTemplate {
        PracticeTemplate(
            id: id,
            title: title,
            environment: environment.rawValue,
            drills: drills,
            createdAt: createdAt
        )
    }
}

@MainActor
struct GarageEnvironmentDrillPlansView: View {
    let environment: PracticeEnvironment
    let onOpenSavedRoutines: () -> Void
    let onGenerateRoutine: () -> Void
    let onBuildRoutine: () -> Void

    var body: some View {
        GarageProScaffold(bottomPadding: 48) {
            GarageProHeroCard(
                eyebrow: "Drill Plans",
                title: environment.displayName,
                subtitle: "Choose how this \(environment.displayName.lowercased()) routine should start.",
                value: "\(DrillVault.drillCount(in: environment))",
                valueLabel: "Drills"
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

            VStack(spacing: 14) {
                GarageDrillPlanChoiceButton(
                    title: "Saved Routines",
                    subtitle: "Open repeatable routines already saved for \(environment.displayName.lowercased()).",
                    systemImage: "bookmark.fill",
                    action: onOpenSavedRoutines
                )

                GarageDrillPlanChoiceButton(
                    title: "Generate New Routine",
                    subtitle: "Create a focused local plan from the \(environment.displayName.lowercased()) drill library.",
                    systemImage: "sparkles",
                    action: onGenerateRoutine
                )

                GarageDrillPlanChoiceButton(
                    title: "Build My Own",
                    subtitle: "Manually assemble a routine from reusable Garage drills.",
                    systemImage: "slider.horizontal.3",
                    action: onBuildRoutine
                )
            }
        }
        .navigationTitle("\(environment.displayName) Drill Plans")
        .navigationBarTitleDisplayMode(.inline)
    }
}

@MainActor
struct GarageSavedRoutinesView: View {
    @Query(sort: \PracticeTemplate.title) private var allTemplates: [PracticeTemplate]
    @Query(sort: \PracticeSessionRecord.date, order: .reverse) private var records: [PracticeSessionRecord]

    let environment: PracticeEnvironment
    let onReviewRoutine: (GarageRoutineReviewPlan) -> Void
    let onGenerateRoutine: () -> Void
    let onBuildRoutine: () -> Void

    private var savedTemplates: [PracticeTemplate] {
        allTemplates.filter { $0.environment == environment.rawValue }
    }

    private var environmentRecords: [PracticeSessionRecord] {
        records.filter { $0.environment == environment.rawValue }
    }

    var body: some View {
        GarageProScaffold(bottomPadding: 48) {
            GarageProHeroCard(
                eyebrow: "Saved Routines",
                title: environment.displayName,
                subtitle: "Real saved routines for this environment only.",
                value: "\(savedTemplates.count)",
                valueLabel: "Saved"
            )

            if savedTemplates.isEmpty {
                emptyState
            } else {
                savedRoutineList
            }

            preservedAccessSection
        }
        .navigationTitle("Saved Routines")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var emptyState: some View {
        GarageProCard(cornerRadius: 26, padding: 20) {
            Text("No saved routines for this environment yet.")
                .font(.system(.title3, design: .rounded).weight(.black))
                .foregroundStyle(GarageProTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Generate a new routine or build your own to start creating repeatable practice plans.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(GarageProTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                GarageSecondaryRouteButton(
                    title: "Generate Routine",
                    systemImage: "sparkles",
                    action: onGenerateRoutine
                )

                GarageSecondaryRouteButton(
                    title: "Build My Own",
                    systemImage: "slider.horizontal.3",
                    action: onBuildRoutine
                )
            }
        }
    }

    private var savedRoutineList: some View {
        VStack(alignment: .leading, spacing: 14) {
            GarageProSectionHeader(
                eyebrow: "Ready",
                title: "Choose Routine"
            )

            ForEach(savedTemplates, id: \.id) { template in
                Button {
                    garageTriggerImpact(.heavy)
                    onReviewRoutine(GarageRoutineReviewPlan(template: template, selectedEnvironment: environment))
                } label: {
                    GarageSavedRoutineCard(template: template)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var preservedAccessSection: some View {
        GarageProCard(cornerRadius: 24, padding: 16) {
            Text("Garage Library")
                .font(.system(.headline, design: .rounded).weight(.black))
                .foregroundStyle(GarageProTheme.textPrimary)

            Text("\(environmentRecords.count) completed \(environment.displayName.lowercased()) sessions remain available in Garage history.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(GarageProTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

@MainActor
struct GarageGenerateRoutineView: View {
    @Query(sort: \PracticeSessionRecord.date, order: .reverse) private var records: [PracticeSessionRecord]

    let environment: PracticeEnvironment
    let onReviewPlan: (GarageGeneratedPracticePlan) -> Void
    let onOpenSavedRoutines: () -> Void

    private var environmentRecords: [PracticeSessionRecord] {
        records.filter { $0.environment == environment.rawValue }
    }

    var body: some View {
        GarageProScaffold(bottomPadding: 48) {
            GarageProHeroCard(
                eyebrow: "Generate New Routine",
                title: "Generate \(environment.displayName)",
                subtitle: "Build a local routine from the selected environment and real Garage drills.",
                value: "\(DrillVault.drillCount(in: environment))",
                valueLabel: "Drills"
            )

            GarageProCard(isActive: true, cornerRadius: 26, padding: 18) {
                Text("Local Routine Setup")
                    .font(.system(.title3, design: .rounded).weight(.black))
                    .foregroundStyle(GarageProTheme.textPrimary)

                Text("Garage will assemble a reviewable \(environment.displayName.lowercased()) routine. Nothing is saved until you choose to save or complete a session.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(GarageProTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                GarageGenerateRoutineMetaRow(
                    environment: environment,
                    drillCount: DrillVault.drillCount(in: environment),
                    sessionCount: environmentRecords.count
                )

                GarageProPrimaryButton(
                    title: "Generate",
                    systemImage: "sparkles"
                ) {
                    onReviewPlan(
                        GarageLocalCoachPlanner.generatePlan(
                            for: environment,
                            recentRecords: records
                        )
                    )
                }

                GarageSecondaryRouteButton(
                    title: "View Saved",
                    systemImage: "bookmark.fill",
                    action: onOpenSavedRoutines
                )
            }
        }
        .navigationTitle("Generate New Routine")
        .navigationBarTitleDisplayMode(.inline)
    }
}

@MainActor
struct GarageRoutineReviewView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var didSaveRoutine = false
    @State private var saveErrorMessage: String?

    let reviewPlan: GarageRoutineReviewPlan
    let onStartRoutine: (GarageRoutineReviewPlan) -> Void

    var body: some View {
        GarageProScaffold(bottomPadding: 44) {
            routineHeader
            whySelectedBlock
            drillListSection
            actionSection
        }
        .navigationTitle("Review Routine")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Unable To Save Routine", isPresented: saveErrorAlertIsPresented) {
            Button("OK", role: .cancel) {
                saveErrorMessage = nil
            }
        } message: {
            Text(saveErrorMessage ?? "An unexpected error occurred.")
        }
    }

    private var routineHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(reviewPlan.source.eyebrow)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .textCase(.uppercase)
                        .tracking(1.8)
                        .foregroundStyle(GarageProTheme.accent)

                    Text(reviewPlan.title)
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(GarageProTheme.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.74)

                    Label(reviewPlan.environment.displayName, systemImage: reviewPlan.environment.systemImage)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(GarageProTheme.textSecondary)
                }

                Spacer(minLength: 10)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(reviewPlan.drillCount)")
                        .font(.system(size: 28, weight: .black, design: .monospaced))
                        .foregroundStyle(GarageProTheme.accent)

                    Text(reviewPlan.drillCount == 1 ? "Drill" : "Drills")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .textCase(.uppercase)
                        .tracking(1.6)
                        .foregroundStyle(GarageProTheme.textSecondary)
                }
            }

            HStack(spacing: 10) {
                GarageRoutineReviewMetric(
                    title: "Estimated",
                    value: "\(reviewPlan.estimatedDurationMinutes)m",
                    systemImage: "timer"
                )

                GarageRoutineReviewMetric(
                    title: "Reps",
                    value: "\(reviewPlan.totalRepCount)",
                    systemImage: "repeat"
                )
            }
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .background(GarageProTheme.surface, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(GarageProTheme.border, lineWidth: 1)
        )
    }

    private var whySelectedBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Selected because")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .textCase(.uppercase)
                .tracking(1.8)
                .foregroundStyle(GarageProTheme.accent)

            Text(reviewPlan.purpose)
                .font(.headline.weight(.bold))
                .foregroundStyle(GarageProTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if let note = reviewPlan.note {
                Text(note)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(GarageProTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
    }

    private var drillListSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            GarageProSectionHeader(
                eyebrow: "Preview",
                title: "Drill List"
            )

            if reviewPlan.drills.isEmpty {
                GarageProCard(cornerRadius: 22, padding: 16) {
                    Text("No drills in this routine.")
                        .font(.system(.headline, design: .rounded).weight(.black))
                        .foregroundStyle(GarageProTheme.textPrimary)

                    Text("Add drills before starting a Focus Room session.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(GarageProTheme.textSecondary)
                }
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(reviewPlan.drills.prefix(5).enumerated()), id: \.element.id) { offset, drill in
                        GarageRoutineReviewDrillRow(index: offset + 1, drill: drill)
                    }

                    if reviewPlan.drills.count > 5 {
                        Text("+ \(reviewPlan.drills.count - 5) more drills")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(GarageProTheme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private var actionSection: some View {
        VStack(spacing: 12) {
            if reviewPlan.canStart == false {
                Text("This routine needs at least one drill before it can start.")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(GarageProTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            GarageProPrimaryButton(
                title: "Start Routine",
                systemImage: "play.fill",
                isEnabled: reviewPlan.canStart
            ) {
                onStartRoutine(reviewPlan)
            }

            if reviewPlan.source.canSave {
                GarageRoutineReviewSaveButton(
                    didSave: didSaveRoutine,
                    action: saveRoutine
                )
            }
        }
    }

    private var saveErrorAlertIsPresented: Binding<Bool> {
        Binding(
            get: { saveErrorMessage != nil },
            set: { isPresented in
                if isPresented == false {
                    saveErrorMessage = nil
                }
            }
        )
    }

    private func saveRoutine() {
        guard reviewPlan.source.canSave, didSaveRoutine == false else {
            return
        }

        let template = reviewPlan.makePracticeTemplate()
        modelContext.insert(template)

        do {
            try modelContext.save()
            didSaveRoutine = true
            garageTriggerImpact(.medium)
        } catch {
            modelContext.delete(template)
            saveErrorMessage = error.localizedDescription
        }
    }
}

private struct GarageGenerateRoutineMetaRow: View {
    let environment: PracticeEnvironment
    let drillCount: Int
    let sessionCount: Int

    var body: some View {
        HStack(spacing: 10) {
            GarageGenerateRoutineMetaPill(
                title: environment.displayName,
                systemImage: environment.systemImage
            )

            GarageGenerateRoutineMetaPill(
                title: "\(drillCount) drills",
                systemImage: "square.grid.2x2.fill"
            )

            GarageGenerateRoutineMetaPill(
                title: "\(sessionCount) sessions",
                systemImage: "clock.arrow.circlepath"
            )
        }
    }
}

private struct GarageGenerateRoutineMetaPill: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .foregroundStyle(GarageProTheme.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 38)
            .padding(.horizontal, 8)
            .background(GarageProTheme.insetSurface.opacity(0.82), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(GarageProTheme.border, lineWidth: 1)
            )
    }
}

private struct GarageRoutineReviewMetric: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(GarageProTheme.accent)

            Text(value)
                .font(.system(size: 17, weight: .black, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(GarageProTheme.textPrimary)

            Text(title)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .textCase(.uppercase)
                .tracking(1.4)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .foregroundStyle(GarageProTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
        .padding(12)
        .background(GarageProTheme.insetSurface.opacity(0.82), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(GarageProTheme.border, lineWidth: 1)
        )
    }
}

private struct GarageRoutineReviewDrillRow: View {
    let index: Int
    let drill: PracticeTemplateDrill

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
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct GarageRoutineReviewSaveButton: View {
    let didSave: Bool
    let action: () -> Void

    var body: some View {
        Button {
            guard didSave == false else {
                return
            }

            garageTriggerSelection()
            action()
        } label: {
            Label(didSave ? "Routine Saved" : "Save Routine", systemImage: didSave ? "checkmark.seal.fill" : "bookmark.fill")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .foregroundStyle(didSave ? GarageProTheme.accent : GarageProTheme.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(GarageProTheme.insetSurface.opacity(0.86), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .stroke(didSave ? GarageProTheme.accent.opacity(0.34) : GarageProTheme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(didSave)
    }
}

@MainActor
struct GarageTempoBuilderView: View {
    @State private var isRunning = false

    var body: some View {
        GarageProScaffold(bottomPadding: 48) {
            GarageProHeroCard(
                eyebrow: "Tempo Builder",
                title: "Rhythm Work",
                subtitle: "A focused space for swing timing, rehearsal pace, and repeatable tempo.",
                value: isRunning ? "On" : "Ready",
                valueLabel: "State"
            ) {
                Image(systemName: "metronome.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(GarageProTheme.accent)
                    .frame(width: 60, height: 60)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(GarageProTheme.accent.opacity(0.3), lineWidth: 1)
                    )
            }

            GarageProCard(isActive: isRunning, cornerRadius: 28, padding: 20) {
                Text(isRunning ? "Tempo Session Active" : "Tempo Session")
                    .font(.system(.title3, design: .rounded).weight(.black))
                    .foregroundStyle(GarageProTheme.textPrimary)

                Text(isRunning ? "Keep the movement smooth and repeatable." : "Start a simple rhythm block without adding analysis or saved data.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(GarageProTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                GarageProPrimaryButton(
                    title: isRunning ? "Stop" : "Start",
                    systemImage: isRunning ? "stop.fill" : "play.fill"
                ) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        isRunning.toggle()
                    }
                }
            }
        }
        .navigationTitle("Tempo Builder")
        .navigationBarTitleDisplayMode(.inline)
    }
}

@MainActor
struct GarageJournalNewEntryView: View {
    private let entryTypes = [
        "Swing Feel",
        "Scorecard Note",
        "Course Management",
        "Drill Discovery",
        "Setup / Equipment",
        "Coach Cue",
        "General Note"
    ]

    var body: some View {
        GarageProScaffold(bottomPadding: 48) {
            GarageProHeroCard(
                eyebrow: "Journal",
                title: "New Entry",
                subtitle: "Capture the golf notes worth carrying into the next practice.",
                value: "\(entryTypes.count)",
                valueLabel: "Types"
            )

            VStack(alignment: .leading, spacing: 14) {
                GarageProSectionHeader(
                    eyebrow: "Entry Type",
                    title: "Choose A Note"
                )

                ForEach(entryTypes, id: \.self) { entryType in
                    GarageJournalTypeRow(title: entryType)
                }
            }
        }
        .navigationTitle("New Entry")
        .navigationBarTitleDisplayMode(.inline)
    }
}

@MainActor
struct GarageJournalArchiveView: View {
    var body: some View {
        GarageProScaffold(bottomPadding: 48) {
            GarageProHeroCard(
                eyebrow: "Journal",
                title: "Archive",
                subtitle: "A calm home for saved swing feels, course notes, coach cues, and practice takeaways.",
                value: "0",
                valueLabel: "Entries"
            )

            GarageProCard(cornerRadius: 26, padding: 20) {
                Text("No journal entries yet.")
                    .font(.system(.title3, design: .rounded).weight(.black))
                    .foregroundStyle(GarageProTheme.textPrimary)

                Text("New Entry will become the capture path once journal persistence is approved.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(GarageProTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .navigationTitle("Archive")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct GarageDrillPlanChoiceButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button {
            garageTriggerSelection()
            action()
        } label: {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(GarageProTheme.accent)
                    .frame(width: 54, height: 54)
                    .background(GarageProTheme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(.headline, design: .rounded).weight(.black))
                        .foregroundStyle(GarageProTheme.textPrimary)

                    Text(subtitle)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(GarageProTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.black))
                    .foregroundStyle(GarageProTheme.textSecondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .background(GarageProTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(GarageProTheme.border, lineWidth: 1)
            )
            .shadow(color: GarageProTheme.darkShadow, radius: 14, x: 0, y: 10)
        }
        .buttonStyle(.plain)
    }
}

private struct GarageSavedRoutineCard: View {
    let template: PracticeTemplate

    var body: some View {
        GarageProCard(cornerRadius: 24, padding: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(GarageProTheme.accent)
                    .frame(width: 52, height: 52)
                    .background(GarageProTheme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 17, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(template.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(GarageProTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(template.drills.first?.focusArea ?? "Saved routine")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(GarageProTheme.textSecondary)
                        .lineLimit(2)

                    Text("\(template.drills.count) drills - \(template.drills.reduce(0) { $0 + $1.defaultRepCount }) planned reps")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(GarageProTheme.accent.opacity(0.88))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "play.fill")
                    .font(.footnote.weight(.black))
                    .foregroundStyle(GarageProTheme.textSecondary)
            }
        }
    }
}

private struct GarageSecondaryRouteButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button {
            garageTriggerSelection()
            action()
        } label: {
            Label(title, systemImage: systemImage)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .foregroundStyle(GarageProTheme.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(GarageProTheme.insetSurface.opacity(0.86), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .stroke(GarageProTheme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct GarageJournalTypeRow: View {
    let title: String

    var body: some View {
        GarageProCard(cornerRadius: 22, padding: 16) {
            HStack(spacing: 14) {
                Image(systemName: "note.text")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(GarageProTheme.accent)
                    .frame(width: 48, height: 48)
                    .background(GarageProTheme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(GarageProTheme.textPrimary)

                Spacer(minLength: 8)
            }
        }
    }
}

#Preview("Garage Drill Plans") {
    NavigationStack {
        GarageEnvironmentDrillPlansView(
            environment: .net,
            onOpenSavedRoutines: {},
            onGenerateRoutine: {},
            onBuildRoutine: {}
        )
    }
    .modelContainer(PreviewCatalog.populatedApp)
}
