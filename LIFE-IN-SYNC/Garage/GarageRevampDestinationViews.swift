import Foundation
import AVFoundation
import Combine
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
    let prescriptionsByDrillID: [UUID: GarageDrillPrescription]
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
        self.prescriptionsByDrillID = [:]
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
        self.prescriptionsByDrillID = generatedPlan.prescriptionsByDrillID
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

    func makeActivePracticeSession() -> ActivePracticeSession {
        ActivePracticeSession(
            template: makePracticeTemplate(),
            prescriptionsByDrillID: prescriptionsByDrillID.isEmpty ? nil : prescriptionsByDrillID
        )
    }
}

@MainActor
struct GarageEnvironmentDrillPlansView: View {
    @Query(sort: \PracticeSessionRecord.date, order: .reverse) private var records: [PracticeSessionRecord]

    @State private var prompt = ""
    @State private var selectedDrillIDs: Set<String> = []
    @State private var isPresentingDrillDirectory = false

    let environment: PracticeEnvironment
    let onOpenSavedRoutines: () -> Void
    let onGenerateRoutine: () -> Void
    let onBuildRoutine: () -> Void
    let onReviewManualSelection: (GarageRoutineReviewPlan) -> Void

    private var allManualDrills: [GarageManualPlanDrill] {
        GarageManualPlanDrill.directoryDrills()
    }

    private var selectedDrills: [GarageManualPlanDrill] {
        allManualDrills.filter { selectedDrillIDs.contains($0.id) }
    }

    var body: some View {
        ZStack {
            GaragePracticeAtmosphereBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    GaragePlanGeneratorHeader()

                    VStack(alignment: .leading, spacing: 6) {
                        Text("What's today's focus?")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Color(red: 0.45, green: 1.0, blue: 0.55))

                        Text("Describe the session you want. Garage will build a local, reviewable routine before anything starts.")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(GarageProTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    GaragePlanPromptField(text: $prompt)

                    GaragePlanConstraintRow(environment: environment)

                    GaragePlanGenerateButton(action: generatePlan)

                    GarageManualDivider()

                    GarageManualBuildSection(
                        selectedDrills: selectedDrills,
                        selectedCount: selectedDrills.count,
                        onBrowse: presentDrillDirectory,
                        onRemove: removeManualDrill
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 132)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .tint(GarageProTheme.accent)
        .safeAreaInset(edge: .bottom) {
            GarageReviewSelectionDock(
                selectionCount: selectedDrills.count,
                isEnabled: selectedDrills.isEmpty == false,
                action: reviewManualSelection
            )
        }
        .sheet(isPresented: $isPresentingDrillDirectory) {
            GarageDrillDirectoryPicker(
                drills: allManualDrills,
                selectedDrillIDs: $selectedDrillIDs
            )
        }
    }

    private func presentDrillDirectory() {
        garageTriggerSelection()
        isPresentingDrillDirectory = true
    }

    private func removeManualDrill(_ drill: GarageManualPlanDrill) {
        garageTriggerSelection()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            _ = selectedDrillIDs.remove(drill.id)
        }
    }

    private func reviewManualSelection() {
        let selected = selectedDrills

        guard selected.isEmpty == false else {
            return
        }

        garageTriggerImpact(.heavy)

        // Full-directory picks still launch under the current route environment to avoid mixed-environment persistence changes.
        let plan = GarageGeneratedPracticePlan(
            title: "\(environment.displayName) Manual Routine",
            environment: environment,
            objective: "Manual routine compiled from the full Garage drill directory.",
            coachNote: "Review the selected drills, then start the session when the sequence matches the work you want.",
            drills: selected.map { $0.practiceDrill },
            prescriptionsByDrillID: Dictionary(uniqueKeysWithValues: selected.enumerated().map { offset, drill in
                (drill.practiceDrill.id, GarageDrillCatalog.defaultPrescription(for: drill.practiceDrill, sessionOrder: offset))
            }),
            plannedDurationMinutes: selected.reduce(0) { partialResult, drill in
                partialResult + GarageDrillFocusDetails.detail(for: drill.practiceDrill).estimatedMinutes
            }
        )

        onReviewManualSelection(GarageRoutineReviewPlan(generatedPlan: plan))
    }

    private func generatePlan() {
        garageTriggerImpact(.heavy)

        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let plan = GarageLocalCoachPlanner.generatePlan(
            for: environment,
            recentRecords: records,
            promptText: trimmedPrompt
        )

        onReviewManualSelection(GarageRoutineReviewPlan(generatedPlan: plan))
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
        ZStack {
            GaragePracticeAtmosphereBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    pageHeader
                    overviewStrip
                    drillListSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 132)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Review Routine")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            actionSection
        }
        .alert("Unable To Save Routine", isPresented: saveErrorAlertIsPresented) {
            Button("OK", role: .cancel) {
                saveErrorMessage = nil
            }
        } message: {
            Text(saveErrorMessage ?? "An unexpected error occurred.")
        }
    }

    private var pageHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Review Routine")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(GarageProTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)

                Text(reviewPlan.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(GarageProTheme.textSecondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(reviewPlan.drillCount) \(reviewPlan.drillCount == 1 ? "Drill" : "Drills")")
                .font(.system(size: 11, weight: .black))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(GaragePremiumPalette.gold)
                .padding(.horizontal, 10)
                .frame(minHeight: 28)
                .background(Color.black.opacity(0.24), in: Capsule())
                .overlay(Capsule().stroke(GaragePremiumPalette.gold.opacity(0.38), lineWidth: 1))
        }
    }

    private var overviewStrip: some View {
        HStack(spacing: 0) {
            GarageRoutineOverviewMetric(title: "Est. Time", value: "\(reviewPlan.estimatedDurationMinutes) min", systemImage: "clock")
            GarageRoutineOverviewDivider()
            GarageRoutineOverviewMetric(title: "Environment", value: reviewPlan.environment.displayName, systemImage: reviewPlan.environment.systemImage)
            GarageRoutineOverviewDivider()
            GarageRoutineOverviewMetric(title: "Drills", value: "\(reviewPlan.drillCount)", systemImage: "list.number")
        }
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .background(GaragePremiumPalette.emeraldGlass.opacity(0.52), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.09), lineWidth: 1)
        )
    }

    private var drillListSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if reviewPlan.drills.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No drills in this routine.")
                        .font(.system(.headline, design: .rounded).weight(.black))
                        .foregroundStyle(GarageProTheme.textPrimary)

                    Text("Add drills before starting a Focus Room session.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(GarageProTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 18)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(reviewPlan.drills.prefix(5).enumerated()), id: \.element.id) { offset, drill in
                        GarageRoutineReviewDrillRow(index: offset + 1, drill: drill)
                    }

                    if reviewPlan.drills.count > 5 {
                        Text("+ \(reviewPlan.drills.count - 5) more drills")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(GarageProTheme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 14)
                    }
                }
            }
        }
        .padding(.top, 6)
    }

    private var actionSection: some View {
        VStack(spacing: 10) {
            if reviewPlan.canStart == false {
                Text("This routine needs at least one drill before it can start.")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(GarageProTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                GarageGoldButton(
                    title: "Start Training",
                    systemImage: "play.fill",
                    isEnabled: reviewPlan.canStart
                ) {
                    onStartRoutine(reviewPlan)
                }
                .frame(maxWidth: .infinity)

                if reviewPlan.source.canSave {
                    GarageRoutineReviewSaveButton(
                        didSave: didSaveRoutine,
                        action: saveRoutine
                    )
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 18)
        .background(.ultraThinMaterial)
        .background(Color(red: 0.006, green: 0.024, blue: 0.018).opacity(0.88))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(GarageProTheme.border)
                .frame(height: 1)
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

private struct GarageManualPlanDrill: Identifiable, Hashable {
    let id: String
    let title: String
    let focus: String
    let environment: PracticeEnvironment
    let category: GarageDrillLibraryCategory
    let club: ClubRange
    let mode: GarageDrillSessionMode
    let systemImage: String
    let practiceDrill: PracticeTemplateDrill

    var directorySubtitle: String {
        "\(category.displayName) • \(club.garageCompactDisplayName) • \(mode.directoryLabel)"
    }

    var compactMetadata: String {
        "\(category.displayName) • \(club.garageCompactDisplayName) • \(mode.directoryLabel)"
    }

    func matches(_ query: String) -> Bool {
        let normalizedQuery = query.lowercased()
        return title.lowercased().contains(normalizedQuery)
            || focus.lowercased().contains(normalizedQuery)
            || environment.displayName.lowercased().contains(normalizedQuery)
            || category.displayName.lowercased().contains(normalizedQuery)
            || club.displayName.lowercased().contains(normalizedQuery)
    }

    static func directoryDrills() -> [GarageManualPlanDrill] {
        DrillVault.masterPlaybook
            .sorted { lhs, rhs in
                if lhs.environment != rhs.environment {
                    return lhs.environment.rawValue < rhs.environment.rawValue
                }

                if lhs.libraryCategory != rhs.libraryCategory {
                    return lhs.libraryCategory.rawValue < rhs.libraryCategory.rawValue
                }

                return lhs.title < rhs.title
            }
            .map { drill in
                GarageManualPlanDrill(
                    id: drill.id,
                    title: drill.title,
                    focus: drill.libraryCategory.displayName,
                    environment: drill.environment,
                    category: drill.libraryCategory,
                    club: drill.clubRange,
                    mode: GarageDrillCatalog.defaultPrescription(
                        for: drill.makeGeneratedPracticeTemplateDrill(seedKey: "manual-directory-mode-\(drill.id)")
                    ).mode,
                    systemImage: systemImage(for: drill),
                    practiceDrill: drill.makeGeneratedPracticeTemplateDrill(seedKey: "manual-directory-\(drill.id)")
                )
            }
    }

    private static func systemImage(for drill: GarageDrill) -> String {
        switch drill.libraryCategory {
        case .contact:
            return "scope"
        case .delivery:
            return "bolt.horizontal"
        case .rotation:
            return "figure.golf"
        case .faceControl:
            return "viewfinder"
        case .tempo:
            return "metronome.fill"
        case .distanceControl:
            return "arrow.left.and.right"
        case .pressure:
            return "target"
        case .putting:
            return "circle.grid.cross"
        }
    }
}

private struct GarageManualBuildSection: View {
    let selectedDrills: [GarageManualPlanDrill]
    let selectedCount: Int
    let onBrowse: () -> Void
    let onRemove: (GarageManualPlanDrill) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GarageManualBrowseButton(action: onBrowse)

            if selectedDrills.isEmpty == false {
                GarageSelectedDrillQueue(
                    drills: selectedDrills,
                    onRemove: onRemove
                )
                .padding(.top, 2)
            } else {
                Text("\(selectedCount) \(selectedCount == 1 ? "drill" : "drills") selected")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(GarageProTheme.textSecondary.opacity(0.7))
                    .padding(.horizontal, 4)
            }
        }
    }
}

private struct GarageManualBrowseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "bag.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(GaragePremiumPalette.gold)
                    .frame(width: 42, height: 42)
                    .background(GaragePremiumPalette.emerald.opacity(0.28), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Build Manually")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(GarageProTheme.textPrimary)

                    Text("Browse the drill directory and create your own plan.")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(GarageProTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(GaragePremiumPalette.gold)
                    .frame(width: 28, height: 28)
            }
            .padding(12)
            .background(GaragePremiumPalette.emeraldGlass.opacity(0.34), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct GarageManualEmptySelectionState: View {
    let onBrowse: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "plus.viewfinder")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(GarageProTheme.textSecondary)
                .frame(width: 38, height: 38)
                .background(GarageProTheme.insetSurface.opacity(0.82), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text("No drills selected yet.")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(GarageProTheme.textPrimary)

                Text("Open the directory to assemble this practice.")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(GarageProTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onBrowse) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(ModuleTheme.garageSurfaceDark)
                    .frame(width: 34, height: 34)
                    .background(ModuleTheme.garageAccent, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(GarageProTheme.insetSurface.opacity(0.62), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(GarageProTheme.border, lineWidth: 1)
        )
    }
}

private struct GarageSelectedDrillQueue: View {
    let drills: [GarageManualPlanDrill]
    let onRemove: (GarageManualPlanDrill) -> Void

    private var visibleDrills: [GarageManualPlanDrill] {
        Array(drills.prefix(5))
    }

    var body: some View {
        VStack(spacing: 8) {
            ForEach(visibleDrills) { drill in
                GarageSelectedDrillRow(drill: drill) {
                    onRemove(drill)
                }
            }

            if drills.count > visibleDrills.count {
                Text("+ \(drills.count - visibleDrills.count) more selected")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(GarageProTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
            }
        }
    }
}

private struct GarageSelectedDrillRow: View {
    let drill: GarageManualPlanDrill
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: drill.systemImage)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(ModuleTheme.garageAccent)
                .frame(width: 34, height: 34)
                .background(GarageProTheme.insetSurface.opacity(0.82), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(drill.title)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .foregroundStyle(GarageProTheme.textPrimary)

                Text(drill.compactMetadata)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.66)
                    .foregroundStyle(GarageProTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(GarageProTheme.textSecondary)
                    .frame(width: 30, height: 30)
                    .background(GarageProTheme.insetSurface.opacity(0.88), in: Circle())
                    .overlay(
                        Circle()
                            .stroke(GarageProTheme.border, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(drill.title)")
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: 54)
        .background(GarageProTheme.insetSurface.opacity(0.54), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(GarageProTheme.border, lineWidth: 1)
        )
    }
}

private struct GarageDrillDirectoryPicker: View {
    @Environment(\.dismiss) private var dismiss

    let drills: [GarageManualPlanDrill]
    @Binding var selectedDrillIDs: Set<String>

    @State private var searchText = ""
    @State private var selectedCategory: GarageDrillLibraryCategory?

    private var visibleDrills: [GarageManualPlanDrill] {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        return drills.filter { drill in
            let matchesCategory = selectedCategory.map { drill.category == $0 } ?? true
            let matchesSearch = trimmedSearch.isEmpty || drill.matches(trimmedSearch)
            return matchesCategory && matchesSearch
        }
    }

    private var availableCategories: [GarageDrillLibraryCategory] {
        let categories = Set(drills.map(\.category))
        return GarageDrillLibraryCategory.allCases.filter { categories.contains($0) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ModuleTheme.garageBackground
                    .ignoresSafeArea()

                LinearGradient(
                    colors: [
                        ModuleTheme.garageTurfBackground.opacity(0.98),
                        ModuleTheme.garageTurfSurface.opacity(0.96),
                        ModuleTheme.garageSurfaceDark.opacity(0.94)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Browse Drill Directory")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundStyle(GarageProTheme.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)

                        GarageManualSearchField(text: $searchText)

                        GarageManualCategoryRail(
                            categories: availableCategories,
                            selectedCategory: $selectedCategory
                        )

                        if visibleDrills.isEmpty {
                            GarageDirectoryEmptyState()
                        } else {
                            LazyVStack(spacing: 8) {
                                ForEach(visibleDrills) { drill in
                                    GarageDirectoryDrillRow(
                                        drill: drill,
                                        isSelected: selectedDrillIDs.contains(drill.id)
                                    ) {
                                        toggle(drill)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 104)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                GarageDirectoryDoneDock(
                    selectedCount: selectedDrillIDs.count,
                    action: { dismiss() }
                )
            }
        }
        .tint(GarageProTheme.accent)
    }

    private func toggle(_ drill: GarageManualPlanDrill) {
        garageTriggerSelection()

        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            if selectedDrillIDs.contains(drill.id) {
                selectedDrillIDs.remove(drill.id)
            } else {
                selectedDrillIDs.insert(drill.id)
            }
        }
    }
}

private struct GarageManualSearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(GarageProTheme.textSecondary)

            TextField("Search drills", text: $text)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(GarageProTheme.textPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if text.isEmpty == false {
                Button {
                    garageTriggerSelection()
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(GarageProTheme.textSecondary.opacity(0.82))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(GarageProTheme.insetSurface.opacity(0.74), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
    }
}

private struct GarageManualCategoryRail: View {
    let categories: [GarageDrillLibraryCategory]
    @Binding var selectedCategory: GarageDrillLibraryCategory?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                GarageManualCategoryChip(
                    title: "All",
                    isSelected: selectedCategory == nil
                ) {
                    setCategory(nil)
                }

                ForEach(categories) { category in
                    GarageManualCategoryChip(
                        title: category.displayName,
                        isSelected: selectedCategory == category
                    ) {
                        setCategory(category)
                    }
                }
            }
            .padding(.vertical, 1)
        }
    }

    private func setCategory(_ category: GarageDrillLibraryCategory?) {
        garageTriggerSelection()

        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            selectedCategory = category
        }
    }
}

private struct GarageManualCategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .foregroundStyle(isSelected ? ModuleTheme.garageSurfaceDark : GarageProTheme.textSecondary)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(
                    isSelected ? ModuleTheme.garageAccent : GarageProTheme.insetSurface.opacity(0.74),
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.white.opacity(0.18) : GarageProTheme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct GarageDirectoryEmptyState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No matching drills.")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(GarageProTheme.textPrimary)

            Text("Clear the search or switch categories.")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(GarageProTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .background(GarageProTheme.insetSurface.opacity(0.72), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(GarageProTheme.border, lineWidth: 1)
        )
    }
}

private struct GarageDirectoryDrillRow: View {
    let drill: GarageManualPlanDrill
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: drill.systemImage)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(isSelected ? ModuleTheme.garageAccent : GarageProTheme.textSecondary.opacity(0.92))
                    .frame(width: 36, height: 36)
                    .background(GarageProTheme.insetSurface.opacity(0.64), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(drill.title)
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                        .foregroundStyle(GarageProTheme.textPrimary)

                    Text(drill.directorySubtitle)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.66)
                        .foregroundStyle(GarageProTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(isSelected ? ModuleTheme.garageAccent : GarageProTheme.textSecondary.opacity(0.56))
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(
                ModuleTheme.garageTurfSurface.opacity(isSelected ? 0.70 : 0.46),
                in: RoundedRectangle(cornerRadius: 17, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(isSelected ? ModuleTheme.garageAccent.opacity(0.72) : Color.white.opacity(0.06), lineWidth: isSelected ? 1.1 : 1)
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isSelected)
    }
}

private struct GarageDirectoryDoneDock: View {
    let selectedCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(selectionSummary)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(ModuleTheme.garageSurfaceDark.opacity(0.78))

                Spacer(minLength: 8)

                Label("Done", systemImage: "checkmark")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(ModuleTheme.garageSurfaceDark)
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(ModuleTheme.garageAccent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: AppModule.garage.theme.shadowDark.opacity(0.36), radius: 12, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .background(ModuleTheme.garageSurfaceDark.opacity(0.76))
    }

    private var selectionSummary: String {
        "\(selectedCount) \(selectedCount == 1 ? "drill" : "drills") selected"
    }
}

private struct GaragePlanPromptField: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 0.01, green: 0.055, blue: 0.038).opacity(0.84))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(isFocused ? GaragePremiumPalette.gold.opacity(0.42) : Color.white.opacity(0.09), lineWidth: 1)
                )

            if text.isEmpty {
                Text("E.g. 30 minutes on driver start line")
                    .font(.system(size: 15, weight: .medium))
                    .lineSpacing(4)
                    .foregroundStyle(GarageProTheme.textSecondary.opacity(0.76))
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $text)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(GarageProTheme.textPrimary)
                .scrollContentBackground(.hidden)
                .focused($isFocused)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.clear)
                .frame(minHeight: 92)

            Text("\(text.count)/120")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(GarageProTheme.textSecondary.opacity(0.72))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 16)
                .padding(.bottom, 12)
        }
        .frame(minHeight: 92)
    }
}

private struct GaragePlanGenerateButton: View {
    let action: () -> Void

    var body: some View {
        Button {
            garageTriggerImpact(.heavy)
            action()
        } label: {
            Label("Generate My Plan", systemImage: "sparkles")
                .font(.system(size: 19, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(GaragePremiumPalette.emeraldDeep)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.86, blue: 0.27),
                            GaragePremiumPalette.gold,
                            GaragePremiumPalette.goldDeep
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                )
                .shadow(color: GaragePremiumPalette.gold.opacity(0.16), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
}

private struct GarageManualDivider: View {
    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(ModuleTheme.garageDivider.opacity(0.42))
                .frame(height: 1)

            Text("OR")
                .font(.system(size: 11, weight: .bold))
                .textCase(.uppercase)
                .tracking(1.6)
                .foregroundStyle(GarageProTheme.textSecondary.opacity(0.68))
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Rectangle()
                .fill(ModuleTheme.garageDivider.opacity(0.42))
                .frame(height: 1)
        }
    }
}

private struct GaragePlanGeneratorHeader: View {
    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("AI Plan Generator")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(GarageProTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Label("AI", systemImage: "sparkles")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(GaragePremiumPalette.gold)
                .padding(.horizontal, 10)
                .frame(minHeight: 30)
                .background(Color.black.opacity(0.24), in: Capsule())
                .overlay(Capsule().stroke(GaragePremiumPalette.gold.opacity(0.36), lineWidth: 1))
        }
    }
}

private struct GaragePlanConstraintRow: View {
    let environment: PracticeEnvironment

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Constraints (optional)")
                .font(.system(size: 10, weight: .bold))
                .textCase(.uppercase)
                .tracking(1.8)
                .foregroundStyle(GaragePremiumPalette.mintText)

            HStack(spacing: 7) {
                GaragePlanConstraintPill(title: "30 min", systemImage: "clock")
                GaragePlanConstraintPill(title: environment.displayName, systemImage: environment.systemImage)
                GaragePlanConstraintPill(title: "Driver", systemImage: "figure.golf")
                GaragePlanConstraintPill(title: environment == .net ? "Indoor" : "Outdoor", systemImage: environment == .net ? "house" : "flag")
            }
        }
    }
}

private struct GaragePlanConstraintPill: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 12, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .foregroundStyle(GaragePremiumPalette.mintText)
            .padding(.horizontal, 10)
            .frame(minHeight: 34)
            .background(GaragePremiumPalette.emeraldGlass.opacity(0.5), in: Capsule())
            .overlay(Capsule().stroke(Color(red: 0.32, green: 1.0, blue: 0.5).opacity(0.22), lineWidth: 1))
    }
}

private struct GarageReviewSelectionDock: View {
    let selectionCount: Int
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button {
                guard isEnabled else {
                    return
                }

                action()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isEnabled ? "checkmark.seal.fill" : "checkmark.seal")
                        .font(.system(size: 16, weight: .bold))

                    Text("Review Practice")
                        .font(.system(size: 17, weight: .black, design: .rounded))

                    Spacer(minLength: 8)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.76)
                .foregroundStyle(isEnabled ? ModuleTheme.garageSurfaceDark : GarageProTheme.textSecondary.opacity(0.82))
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity, minHeight: 62)
                .background(
                    isEnabled ? ModuleTheme.garageAccent : GarageProTheme.insetSurface.opacity(0.9),
                    in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(isEnabled ? Color.white.opacity(0.18) : GarageProTheme.border, lineWidth: 1)
                )
                .shadow(color: AppModule.garage.theme.shadowDark.opacity(isEnabled ? 0.42 : 0.24), radius: 14, x: 0, y: 9)
                .shadow(color: isEnabled ? GarageProTheme.glow.opacity(0.18) : .clear, radius: 14, x: 0, y: 0)
            }
            .buttonStyle(.plain)
            .disabled(isEnabled == false)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .background(ModuleTheme.garageSurfaceDark.opacity(0.76))
    }

}

private struct GarageRoutineOverviewMetric: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(GaragePremiumPalette.gold)

            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(GarageProTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.68)

            Text(title)
                .font(.system(size: 10, weight: .bold))
                .textCase(.uppercase)
                .tracking(1.1)
                .foregroundStyle(GarageProTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 6)
    }
}

private struct GarageRoutineOverviewDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 1, height: 48)
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
        HStack(alignment: .top, spacing: 14) {
            Text("\(index)")
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundStyle(index == 1 ? GaragePremiumPalette.emeraldDeep : GaragePremiumPalette.gold)
                .frame(width: 34, height: 34)
                .background(index == 1 ? GaragePremiumPalette.gold : GaragePremiumPalette.emeraldGlass.opacity(0.72), in: Circle())
                .overlay(Circle().stroke(index == 1 ? GaragePremiumPalette.gold.opacity(0.55) : Color.white.opacity(0.09), lineWidth: 1))
                .shadow(color: index == 1 ? GaragePremiumPalette.gold.opacity(0.2) : .clear, radius: 12, x: 0, y: 4)

            VStack(alignment: .leading, spacing: 5) {
                Text(drill.title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(GarageProTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(drill.metadataSummary)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(GarageProTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(index == 1 ? GaragePremiumPalette.emeraldGlass.opacity(0.72) : Color.white.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(index == 1 ? GaragePremiumPalette.gold.opacity(0.42) : Color.white.opacity(0.07), lineWidth: 1)
        )
        .shadow(color: index == 1 ? GaragePremiumPalette.gold.opacity(0.12) : .clear, radius: 16, x: 0, y: 6)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.clear)
                .frame(height: 1)
        }
        .padding(.bottom, 10)
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

private enum GarageTempoRunState: Equatable {
    case ready
    case running
    case paused

    var label: String {
        switch self {
        case .ready:
            return "Ready"
        case .running:
            return "Running"
        case .paused:
            return "Paused"
        }
    }
}

private enum GarageTempoLoopPhase: Equatable {
    case setupWait
    case backswing
    case downswing
    case reset

    var label: String {
        switch self {
        case .setupWait:
            return "Setup"
        case .backswing:
            return "Backswing"
        case .downswing:
            return "Downswing"
        case .reset:
            return "Reset"
        }
    }
}

private enum GarageTempoProfile: String, CaseIterable, Identifiable {
    case fullSwing
    case shortGame
    case putting

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fullSwing:
            return "Full Swing"
        case .shortGame:
            return "Short Game"
        case .putting:
            return "Putting"
        }
    }

    var tempoDefaults: (beatsPerMinute: Double, setupDelay: Double) {
        switch self {
        case .fullSwing:
            return (beatsPerMinute: 72, setupDelay: 5)
        case .shortGame:
            return (beatsPerMinute: 66, setupDelay: 4)
        case .putting:
            return (beatsPerMinute: 78, setupDelay: 3)
        }
    }
}

private enum GarageTempoCue {
    case start
    case top
    case impact
}

private struct GarageTempoConfiguration: Equatable {
    var beatsPerMinute: Double = 72
    var setupDelay: Double = 5
    var audioEnabled = true
    var hapticsEnabled = true

    var backswingRatio: Double {
        0.75
    }

    var downswingRatio: Double {
        0.25
    }

    var swingDuration: TimeInterval {
        (60 / beatsPerMinute) * 4
    }

    var backswingDuration: TimeInterval {
        swingDuration * backswingRatio
    }

    var downswingDuration: TimeInterval {
        swingDuration * downswingRatio
    }

    var loopDuration: TimeInterval {
        setupDelay + swingDuration
    }

    var bpmText: String {
        "\(Int(beatsPerMinute.rounded()))"
    }

    var ratioText: String {
        "3:1"
    }

    var setupDelayText: String {
        "\(Int(setupDelay.rounded()))s"
    }

    var cueSummaryText: String {
        switch (audioEnabled, hapticsEnabled) {
        case (true, true):
            return "Audio + haptics"
        case (true, false):
            return "Audio only"
        case (false, true):
            return "Haptics only"
        case (false, false):
            return "Silent cues"
        }
    }
}

@MainActor
private final class GarageTempoAudioCuePlayer {
    private let engine = AVAudioEngine()
    private let startPlayer = AVAudioPlayerNode()
    private let topPlayer = AVAudioPlayerNode()
    private let impactPlayer = AVAudioPlayerNode()
    private let sampleRate: Double = 44_100
    private var isPrepared = false
    private var startBuffer: AVAudioPCMBuffer?
    private var topBuffer: AVAudioPCMBuffer?
    private var impactBuffer: AVAudioPCMBuffer?

    func startSession() {
        prepareIfNeeded()
    }

    func play(_ cue: GarageTempoCue) {
        prepareIfNeeded()

        guard engine.isRunning else {
            return
        }

        guard let buffer = buffer(for: cue) else {
            return
        }

        let player = player(for: cue)
        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)

        if player.isPlaying == false {
            player.play()
        }
    }

    func stop() {
        startPlayer.stop()
        topPlayer.stop()
        impactPlayer.stop()
        engine.pause()
    }

    private func prepareIfNeeded() {
        guard isPrepared == false else {
            if engine.isRunning == false {
                try? engine.start()
            }
            return
        }

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            return
        }

        [startPlayer, topPlayer, impactPlayer].forEach { player in
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
        }

        startBuffer = makeToneBuffer(for: .start, format: format)
        topBuffer = makeToneBuffer(for: .top, format: format)
        impactBuffer = makeToneBuffer(for: .impact, format: format)

        try? engine.start()
        isPrepared = true
    }

    private func toneProfile(for cue: GarageTempoCue) -> (frequency: Double, duration: Double, gain: Float) {
        switch cue {
        case .start:
            return (frequency: 392, duration: 0.075, gain: 0.28)
        case .top:
            return (frequency: 587.33, duration: 0.065, gain: 0.34)
        case .impact:
            return (frequency: 880, duration: 0.09, gain: 0.48)
        }
    }

    private func player(for cue: GarageTempoCue) -> AVAudioPlayerNode {
        switch cue {
        case .start:
            return startPlayer
        case .top:
            return topPlayer
        case .impact:
            return impactPlayer
        }
    }

    private func buffer(for cue: GarageTempoCue) -> AVAudioPCMBuffer? {
        switch cue {
        case .start:
            return startBuffer
        case .top:
            return topBuffer
        case .impact:
            return impactBuffer
        }
    }

    private func makeToneBuffer(for cue: GarageTempoCue, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let profile = toneProfile(for: cue)
        let frequency = profile.frequency
        let duration = profile.duration
        let gain = profile.gain
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channel = buffer.floatChannelData?[0] else {
            return nil
        }

        buffer.frameLength = frameCount

        for frame in 0..<Int(frameCount) {
            let position = Double(frame) / sampleRate
            let progress = Double(frame) / Double(max(Int(frameCount) - 1, 1))
            let fadeIn = min(progress / 0.14, 1)
            let fadeOut = min((1 - progress) / 0.22, 1)
            let envelope = pow(min(fadeIn, fadeOut), 2)
            let wave = sin(2 * Double.pi * frequency * position)
            let sample = Float(wave) * Float(envelope) * gain
            channel[frame] = sample
        }

        return buffer
    }
}

@MainActor
private final class GarageTempoEngine: NSObject, ObservableObject {
    @Published private(set) var state: GarageTempoRunState = .ready
    @Published private(set) var progress: Double = 0
    @Published private(set) var cycleCount = 0
    @Published private(set) var impactPulseID = 0
    @Published private(set) var configuration = GarageTempoConfiguration()
    @Published private(set) var loopPhase: GarageTempoLoopPhase = .setupWait

    private var timer: Timer?
    private var loopStartDate: Date?
    private var preciseProgress: Double = 0
    private var preciseLoopProgress: TimeInterval = 0
    private var pausedLoopProgress: TimeInterval = 0
    private let audioCuePlayer = GarageTempoAudioCuePlayer()
    private var didPlayStartCue = false
    private var didPlayTopCue = false
    private var didPlayImpactCue = false
    private var lastVisualProgressPublishDate: Date?

    private let visualProgressPublishInterval: TimeInterval = 1.0 / 30.0

    var phaseLabel: String {
        switch state {
        case .ready:
            return "Setup"
        case .paused:
            return "Paused"
        case .running:
            return loopPhase.label
        }
    }

    func start(configuration: GarageTempoConfiguration) {
        self.configuration = configuration
        preciseProgress = 0
        preciseLoopProgress = 0
        progress = 0
        pausedLoopProgress = 0
        cycleCount = 0
        loopPhase = .setupWait
        resetCueFlags()
        lastVisualProgressPublishDate = nil
        state = .running
        loopStartDate = .now
        if configuration.audioEnabled {
            audioCuePlayer.startSession()
        }
        startTimer()
    }

    func resume() {
        guard state == .paused else { return }
        state = .running
        loopStartDate = Date().addingTimeInterval(-pausedLoopProgress)
        restoreCueFlagsForResume()
        if configuration.audioEnabled {
            audioCuePlayer.startSession()
        }
        startTimer()
    }

    func pause() {
        guard state == .running else { return }
        pausedLoopProgress = preciseLoopProgress
        state = .paused
        stopTimer()
        audioCuePlayer.stop()
    }

    func stop() {
        state = .ready
        preciseProgress = 0
        preciseLoopProgress = 0
        progress = 0
        pausedLoopProgress = 0
        cycleCount = 0
        loopPhase = .setupWait
        loopStartDate = nil
        resetCueFlags()
        lastVisualProgressPublishDate = nil
        stopTimer()
        audioCuePlayer.stop()
    }

    func stopForDisappear() {
        stop()
    }

    func updateConfiguration(_ nextConfiguration: GarageTempoConfiguration) {
        let currentLoopProgress = preciseLoopProgress
        let normalizedLoopProgress = configuration.loopDuration > 0 ? currentLoopProgress / configuration.loopDuration : 0
        configuration = nextConfiguration

        if nextConfiguration.audioEnabled == false {
            audioCuePlayer.stop()
        } else if state == .running || state == .paused {
            audioCuePlayer.startSession()
        }

        if state == .running {
            let nextLoopProgress = normalizedLoopProgress * nextConfiguration.loopDuration
            preciseLoopProgress = min(nextLoopProgress, nextConfiguration.loopDuration)
            loopStartDate = Date().addingTimeInterval(-preciseLoopProgress)
            restoreCueFlagsForCurrentPhase()
        } else if state == .paused {
            pausedLoopProgress = min(normalizedLoopProgress * nextConfiguration.loopDuration, nextConfiguration.loopDuration)
            preciseLoopProgress = pausedLoopProgress
            restoreCueFlagsForCurrentPhase()
        }
    }

    func triggerImpactPulse() {
        impactPulseID += 1
        playAudioCue(.impact)
        triggerHaptic(.medium)
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            self?.timerDidFire(timer)
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick(now: Date = .now) {
        guard state == .running, let loopStartDate else { return }

        let elapsed = now.timeIntervalSince(loopStartDate)
        let duration = max(configuration.loopDuration, 0.1)
        let elapsedCycles = Int(elapsed / duration)
        let cycleElapsed = elapsed.truncatingRemainder(dividingBy: duration)
        let nextPhase = phase(for: cycleElapsed)
        let nextProgress = swingProgress(for: cycleElapsed)

        if elapsedCycles > cycleCount {
            fireImpactCueIfNeeded()
            cycleCount = elapsedCycles
            resetCueFlags()
        }

        preciseLoopProgress = cycleElapsed
        preciseProgress = nextProgress
        loopPhase = nextPhase
        fireStartCueIfNeeded(phase: nextPhase)
        fireTopCueIfNeeded(phase: nextPhase, progress: nextProgress)
        fireImpactCueIfNeeded(phase: nextPhase, progress: nextProgress)
        publishVisualProgress(nextProgress, at: now)
    }

    private func timerDidFire(_ timer: Timer) {
        tick()
    }

    private func publishVisualProgress(_ nextProgress: Double, at now: Date, force: Bool = false) {
        if force == false,
           let lastVisualProgressPublishDate,
           now.timeIntervalSince(lastVisualProgressPublishDate) < visualProgressPublishInterval {
            return
        }

        progress = nextProgress
        lastVisualProgressPublishDate = now
    }

    private func resetCueFlags() {
        didPlayStartCue = false
        didPlayTopCue = false
        didPlayImpactCue = false
    }

    private func restoreCueFlagsForResume() {
        restoreCueFlagsForCurrentPhase()
    }

    private func restoreCueFlagsForCurrentPhase() {
        let phase = phase(for: preciseLoopProgress)
        let currentProgress = swingProgress(for: preciseLoopProgress)
        loopPhase = phase
        preciseProgress = currentProgress
        progress = currentProgress
        didPlayStartCue = phase != .setupWait
        didPlayTopCue = currentProgress >= configuration.backswingRatio
        didPlayImpactCue = false
    }

    private func fireStartCueIfNeeded(phase: GarageTempoLoopPhase) {
        guard state == .running,
              phase != .setupWait,
              didPlayStartCue == false else { return }
        didPlayStartCue = true
        playAudioCue(.start)
    }

    private func fireTopCueIfNeeded(phase: GarageTempoLoopPhase, progress: Double) {
        guard state == .running,
              phase == .downswing,
              didPlayTopCue == false,
              progress >= configuration.backswingRatio else {
            return
        }

        didPlayTopCue = true
        playAudioCue(.top)
    }

    private func fireImpactCueIfNeeded(phase: GarageTempoLoopPhase? = nil, progress: Double = 1) {
        if let phase, phase != .reset, progress < 0.995 {
            return
        }

        guard state == .running, didPlayImpactCue == false else { return }
        didPlayImpactCue = true
        impactPulseID += 1
        playAudioCue(.impact)
        triggerHaptic(.light)
    }

    private func phase(for loopElapsed: TimeInterval) -> GarageTempoLoopPhase {
        if loopElapsed < configuration.setupDelay {
            return .setupWait
        }

        let swingElapsed = loopElapsed - configuration.setupDelay
        if swingElapsed < configuration.backswingDuration {
            return .backswing
        }

        if swingElapsed < configuration.swingDuration {
            return .downswing
        }

        return .reset
    }

    private func swingProgress(for loopElapsed: TimeInterval) -> Double {
        guard loopElapsed >= configuration.setupDelay else {
            return 0
        }

        let swingElapsed = min(max(loopElapsed - configuration.setupDelay, 0), configuration.swingDuration)
        return min(max(swingElapsed / configuration.swingDuration, 0), 1)
    }

    private func playAudioCue(_ cue: GarageTempoCue) {
        guard configuration.audioEnabled else { return }
        audioCuePlayer.startSession()
        audioCuePlayer.play(cue)
    }

    private func triggerHaptic(_ weight: GarageImpactWeight) {
        guard configuration.hapticsEnabled else { return }
        garageTriggerImpact(weight)
    }
}

@MainActor
struct GarageTempoBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var engine = GarageTempoEngine()
    @State private var configuration = GarageTempoConfiguration()
    @State private var profile: GarageTempoProfile = .fullSwing
    @State private var showsMoreControls = false

    var body: some View {
        ZStack {
            GarageTempoCockpitBackground()

            GeometryReader { proxy in
                let horizontalPadding: CGFloat = 12
                let bottomPadding = max(proxy.safeAreaInsets.bottom - 12, 4)

                Group {
                    switch engine.state {
                    case .ready:
                        GarageTempoReadyLayout(
                            size: proxy.size,
                            configuration: $configuration,
                            profile: $profile,
                            progress: engine.progress,
                            loopPhase: engine.loopPhase,
                            phaseLabel: engine.phaseLabel,
                            cycleCount: engine.cycleCount,
                            hapticsEnabled: configuration.hapticsEnabled,
                            onBack: closeBuilder,
                            onConfigurationChange: engine.updateConfiguration,
                            onStart: handlePrimaryAction,
                            onMore: { showsMoreControls = true }
                        )

                    case .running:
                        GarageTempoActiveLayout(
                            size: proxy.size,
                            configuration: $configuration,
                            profile: $profile,
                            progress: engine.progress,
                            loopPhase: engine.loopPhase,
                            phaseLabel: engine.phaseLabel,
                            cycleCount: engine.cycleCount,
                            impactPulseID: engine.impactPulseID,
                            hapticsEnabled: configuration.hapticsEnabled,
                            onBack: closeBuilder,
                            onConfigurationChange: engine.updateConfiguration,
                            onPause: handlePrimaryAction,
                            onStop: resetSet
                        )

                    case .paused:
                        GarageTempoPausedLayout(
                            size: proxy.size,
                            configuration: $configuration,
                            profile: $profile,
                            progress: engine.progress,
                            loopPhase: engine.loopPhase,
                            phaseLabel: engine.phaseLabel,
                            cycleCount: engine.cycleCount,
                            impactPulseID: engine.impactPulseID,
                            hapticsEnabled: configuration.hapticsEnabled,
                            onBack: closeBuilder,
                            onConfigurationChange: engine.updateConfiguration,
                            onResume: handlePrimaryAction,
                            onStop: resetSet,
                            onAdjust: { showsMoreControls = true }
                        )
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 10)
                .padding(.bottom, bottomPadding)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: engine.state)
            }
        }
        .sheet(isPresented: $showsMoreControls) {
            GarageTempoMoreControlsSheet(
                configuration: $configuration,
                profile: $profile,
                engineState: engine.state,
                onConfigurationChange: engine.updateConfiguration,
                onReset: resetSet,
                onPulse: engine.triggerImpactPulse
            )
            .presentationDetents([.height(420), .medium])
            .presentationDragIndicator(.visible)
        }
        .onDisappear {
            engine.stopForDisappear()
        }
        .navigationBarBackButtonHidden(true)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func closeBuilder() {
        engine.stopForDisappear()
        dismiss()
    }

    private func handlePrimaryAction() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            switch engine.state {
            case .running:
                engine.pause()
            case .paused:
                engine.resume()
            case .ready:
                engine.start(configuration: configuration)
            }
        }
    }

    private func resetSet() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            engine.stop()
        }
    }

}

private struct GarageTempoReadyLayout: View {
    let size: CGSize
    @Binding var configuration: GarageTempoConfiguration
    @Binding var profile: GarageTempoProfile
    let progress: Double
    let loopPhase: GarageTempoLoopPhase
    let phaseLabel: String
    let cycleCount: Int
    let hapticsEnabled: Bool
    let onBack: () -> Void
    let onConfigurationChange: (GarageTempoConfiguration) -> Void
    let onStart: () -> Void
    let onMore: () -> Void

    private var dialSize: CGFloat {
        garageTempoInstrumentSize(for: size)
    }

    var body: some View {
        VStack(spacing: 9) {
            GarageTempoTopBar(profile: profile, hapticsEnabled: hapticsEnabled, onBack: onBack)
                .frame(height: 40)

            GarageTempoHeroReadout(
                configuration: configuration,
                runState: .ready,
                phaseLabel: phaseLabel,
                cycleCount: cycleCount
            )
            .frame(height: 76)

            GarageTempoDialCard(
                configuration: configuration,
                progress: progress,
                loopPhase: loopPhase,
                phaseLabel: phaseLabel,
                runState: .ready,
                cycleCount: cycleCount,
                impactPulseID: 0
            )
            .frame(width: dialSize, height: dialSize)
            .frame(maxWidth: .infinity)

            Spacer(minLength: 6)

            GarageTempoSetupPanel(
                configuration: $configuration,
                profile: $profile,
                hapticsEnabled: hapticsEnabled,
                onConfigurationChange: onConfigurationChange
            )

            GarageTempoActionBar(
                primaryTitle: "Start",
                primaryIcon: "play.fill",
                isPrimaryActive: true,
                showsStop: false,
                showsMore: true,
                hapticsEnabled: hapticsEnabled,
                onPrimaryAction: onStart,
                onStop: {},
                onMore: onMore
            )
        }
    }
}

private struct GarageTempoActiveLayout: View {
    let size: CGSize
    @Binding var configuration: GarageTempoConfiguration
    @Binding var profile: GarageTempoProfile
    let progress: Double
    let loopPhase: GarageTempoLoopPhase
    let phaseLabel: String
    let cycleCount: Int
    let impactPulseID: Int
    let hapticsEnabled: Bool
    let onBack: () -> Void
    let onConfigurationChange: (GarageTempoConfiguration) -> Void
    let onPause: () -> Void
    let onStop: () -> Void

    private var dialSize: CGFloat {
        garageTempoInstrumentSize(for: size)
    }

    var body: some View {
        VStack(spacing: 9) {
            GarageTempoTopBar(profile: profile, hapticsEnabled: hapticsEnabled, onBack: onBack)
                .frame(height: 40)

            GarageTempoExecutionReadout(
                configuration: configuration,
                runState: .running,
                phaseLabel: phaseLabel,
                cycleCount: cycleCount,
                isActive: true
            )
            .frame(height: 86)

            GarageTempoDialCard(
                configuration: configuration,
                progress: progress,
                loopPhase: loopPhase,
                phaseLabel: phaseLabel,
                runState: .running,
                cycleCount: cycleCount,
                impactPulseID: impactPulseID
            )
            .frame(width: dialSize, height: dialSize)
            .frame(maxWidth: .infinity)

            GarageTempoLiveTuneDock(
                configuration: $configuration,
                profile: $profile,
                hapticsEnabled: hapticsEnabled,
                onConfigurationChange: onConfigurationChange
            )

            Spacer(minLength: 6)

            GarageTempoActionBar(
                primaryTitle: "Pause",
                primaryIcon: "pause.fill",
                isPrimaryActive: false,
                stopTitle: "Stop",
                showsStop: true,
                showsMore: false,
                hapticsEnabled: hapticsEnabled,
                onPrimaryAction: onPause,
                onStop: onStop,
                onMore: {}
            )
        }
    }
}

private struct GarageTempoPausedLayout: View {
    let size: CGSize
    @Binding var configuration: GarageTempoConfiguration
    @Binding var profile: GarageTempoProfile
    let progress: Double
    let loopPhase: GarageTempoLoopPhase
    let phaseLabel: String
    let cycleCount: Int
    let impactPulseID: Int
    let hapticsEnabled: Bool
    let onBack: () -> Void
    let onConfigurationChange: (GarageTempoConfiguration) -> Void
    let onResume: () -> Void
    let onStop: () -> Void
    let onAdjust: () -> Void

    private var dialSize: CGFloat {
        garageTempoInstrumentSize(for: size)
    }

    var body: some View {
        VStack(spacing: 10) {
            GarageTempoTopBar(profile: profile, hapticsEnabled: hapticsEnabled, onBack: onBack)
                .frame(height: 44)

            GarageTempoPausedStatus(
                configuration: configuration,
                phaseLabel: phaseLabel,
                cycleCount: cycleCount
            )

            GarageTempoDialCard(
                configuration: configuration,
                progress: progress,
                loopPhase: loopPhase,
                phaseLabel: phaseLabel,
                runState: .paused,
                cycleCount: cycleCount,
                impactPulseID: impactPulseID
            )
            .frame(width: dialSize, height: dialSize)
            .frame(maxWidth: .infinity)

            GarageTempoSetupPanel(
                configuration: $configuration,
                profile: $profile,
                hapticsEnabled: hapticsEnabled,
                onConfigurationChange: onConfigurationChange
            )

            GarageTempoActionBar(
                primaryTitle: "Resume",
                primaryIcon: "play.fill",
                isPrimaryActive: true,
                stopTitle: "Stop",
                moreTitle: "More",
                showsStop: true,
                showsMore: true,
                hapticsEnabled: hapticsEnabled,
                onPrimaryAction: onResume,
                onStop: onStop,
                onMore: onAdjust
            )
        }
    }
}

private func garageTempoInstrumentSize(for size: CGSize) -> CGFloat {
    min(size.width - 24, size.height * 0.39)
}

private struct GarageTempoExecutionReadout: View {
    let configuration: GarageTempoConfiguration
    let runState: GarageTempoRunState
    let phaseLabel: String
    let cycleCount: Int
    let isActive: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(alignment: .lastTextBaseline, spacing: 7) {
                Text(configuration.bpmText)
                    .font(.system(size: isActive ? 58 : 44, weight: .black, design: .rounded))
                    .foregroundStyle(GarageProTheme.textPrimary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text("BPM")
                    .font(.system(size: isActive ? 14 : 12, weight: .black, design: .rounded))
                    .foregroundStyle(GaragePremiumPalette.gold)
                    .padding(.bottom, isActive ? 9 : 7)
            }
            .layoutPriority(1)

            VStack(spacing: 8) {
                GarageTempoReadoutChip(title: "CYCLES", value: "\(cycleCount)")
                GarageTempoReadoutChip(title: "PHASE", value: phaseLabel)
            }
            .frame(maxWidth: 156)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(GarageProTheme.insetSurface.opacity(isActive ? 0.38 : 0.54), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isActive ? GaragePremiumPalette.gold.opacity(0.16) : GarageProTheme.border, lineWidth: 1)
        )
    }
}

private struct GarageTempoPausedStatus: View {
    let configuration: GarageTempoConfiguration
    let phaseLabel: String
    let cycleCount: Int

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                GarageTempoTrayLabel("Paused")

                Text("Reset. Adjust. Resume.")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(GarageProTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                GarageTempoMicroReadout(title: "BPM", value: configuration.bpmText)
                GarageTempoMicroReadout(title: "CYCLES", value: "\(cycleCount)")
                GarageTempoMicroReadout(title: "PHASE", value: phaseLabel)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .background(GarageProTheme.insetSurface.opacity(0.46), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(GaragePremiumPalette.gold.opacity(0.16), lineWidth: 1)
        )
    }
}

private struct GarageTempoMicroReadout: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(GarageProTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.68)

            Text(title)
                .font(.system(size: 8, weight: .black, design: .rounded))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(GarageProTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(width: 54, height: 34)
        .background(GarageProTheme.insetSurface.opacity(0.62), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(GarageProTheme.border.opacity(0.64), lineWidth: 1)
        )
    }
}

private struct GarageTempoCockpitBackground: View {
    var body: some View {
        ZStack {
            Color(red: 0.004, green: 0.018, blue: 0.014)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color(red: 0.018, green: 0.068, blue: 0.046),
                    Color(red: 0.006, green: 0.024, blue: 0.018),
                    ModuleTheme.garageSurfaceDark.opacity(0.98)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    GarageProTheme.accent.opacity(0.22),
                    GaragePremiumPalette.emerald.opacity(0.12),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 420
            )
            .ignoresSafeArea()
        }
    }
}

private struct GarageTempoTopBar: View {
    let profile: GarageTempoProfile
    let hapticsEnabled: Bool
    let onBack: () -> Void

    var body: some View {
        HStack {
            Button {
                if hapticsEnabled {
                    garageTriggerSelection()
                }
                onBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(GarageProTheme.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(GarageProTheme.insetSurface.opacity(0.74), in: Circle())
                    .overlay(Circle().stroke(GarageProTheme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            Spacer()

            Text("Tempo Builder")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(GarageProTheme.textPrimary)

            Spacer()

            Text(profile.title)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .foregroundStyle(GaragePremiumPalette.gold)
                .padding(.trailing, 12)
                .frame(width: 94, height: 30, alignment: .trailing)
                .background(GaragePremiumPalette.gold.opacity(0.08), in: Capsule())
                .overlay(Capsule().stroke(GaragePremiumPalette.gold.opacity(0.18), lineWidth: 1))
        }
    }
}

private struct GarageTempoHeroReadout: View {
    let configuration: GarageTempoConfiguration
    let runState: GarageTempoRunState
    let phaseLabel: String
    let cycleCount: Int

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .lastTextBaseline, spacing: 10) {
                Text(configuration.bpmText)
                    .font(.system(size: 58, weight: .black, design: .rounded))
                    .foregroundStyle(GarageProTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text("BPM")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(GaragePremiumPalette.gold)
                    .padding(.bottom, 12)
            }

            HStack(spacing: 10) {
                GarageTempoReadoutChip(title: "Ratio", value: configuration.ratioText)
                GarageTempoReadoutChip(title: "Cycles", value: "\(cycleCount)")
                GarageTempoReadoutChip(title: "Phase", value: runState == .ready ? "Ready" : phaseLabel)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct GarageTempoReadoutChip: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(GarageProTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(.system(size: 9, weight: .black, design: .rounded))
                .tracking(0.4)
                .foregroundStyle(GarageProTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 32)
        .background(GarageProTheme.insetSurface.opacity(0.42), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(GarageProTheme.border.opacity(0.72), lineWidth: 1)
        )
    }
}

private struct GarageTempoDialCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let configuration: GarageTempoConfiguration
    let progress: Double
    let loopPhase: GarageTempoLoopPhase
    let phaseLabel: String
    let runState: GarageTempoRunState
    let cycleCount: Int
    let impactPulseID: Int

    @State private var impactPulse = false

    var body: some View {
        GarageTempoJArcInstrument(
            bpmText: configuration.bpmText,
            progress: progress,
            loopPhase: loopPhase,
            isRunning: runState == .running,
            reduceMotion: reduceMotion,
            impactPulse: impactPulse && reduceMotion == false
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tempo J arc")
        .accessibilityValue("\(phaseLabel), \(configuration.ratioText) ratio, \(cycleCount) cycles")
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(runState == .running ? 0.58 : 0.34)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(runState == .running ? GaragePremiumPalette.gold.opacity(0.22) : GarageProTheme.border, lineWidth: 1)
        )
        .shadow(color: GaragePremiumPalette.gold.opacity(runState == .running ? 0.18 : 0.08), radius: 28, x: 0, y: 18)
        .shadow(color: GarageProTheme.glow.opacity(runState == .running ? 0.18 : 0.10), radius: 18, x: 0, y: 0)
        .onChange(of: impactPulseID) { _, newValue in
            guard newValue > 0 else { return }
            impactPulse = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                impactPulse = false
            }
        }
    }
}

private struct GarageTempoJArcInstrument: View {
    let bpmText: String
    let progress: Double
    let loopPhase: GarageTempoLoopPhase
    let isRunning: Bool
    let reduceMotion: Bool
    let impactPulse: Bool

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    private var pathProgress: CGFloat {
        switch loopPhase {
        case .setupWait, .reset:
            return 0
        case .backswing:
            return CGFloat(min(max(clampedProgress / 0.75, 0), 1))
        case .downswing:
            let downswingProgress = min(max((clampedProgress - 0.75) / 0.25, 0), 1)
            return CGFloat(1 - downswingProgress)
        }
    }

    private var displayedPathProgress: CGFloat {
        guard reduceMotion else { return pathProgress }

        switch loopPhase {
        case .setupWait, .reset:
            return 0
        case .backswing:
            return 1
        case .downswing:
            return 0
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let rect = proxy.frame(in: .local).insetBy(dx: proxy.size.width * 0.14, dy: proxy.size.height * 0.13)
            let addressPoint = point(at: 0, in: rect)
            let topPoint = point(at: 1, in: rect)
            let dotPoint = point(at: displayedPathProgress, in: rect)

            ZStack {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                GarageProTheme.accent.opacity(0.22),
                                GaragePremiumPalette.emerald.opacity(0.18),
                                GarageProTheme.insetSurface.opacity(0.92)
                            ],
                            center: .center,
                            startRadius: 8,
                            endRadius: min(proxy.size.width, proxy.size.height) * 0.82
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(GaragePremiumPalette.mintText.opacity(0.07), lineWidth: 1)
                    )
                    .padding(3)
                    .shadow(color: GarageProTheme.glow.opacity(0.18), radius: 28, x: 0, y: 18)

                jArcPath(in: rect)
                    .stroke(GaragePremiumPalette.mintText.opacity(0.15), style: StrokeStyle(lineWidth: 17, lineCap: .round, lineJoin: .round))

                progressPath(to: displayedPathProgress, in: rect)
                    .stroke(
                        LinearGradient(
                            colors: [
                                GaragePremiumPalette.gold.opacity(isRunning ? 0.92 : 0.62),
                                GarageProTheme.accent.opacity(isRunning ? 0.82 : 0.42)
                            ],
                            startPoint: .bottom,
                            endPoint: .topTrailing
                        ),
                        style: StrokeStyle(lineWidth: 11, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: GaragePremiumPalette.gold.opacity(isRunning ? 0.28 : 0.10), radius: 14, x: 0, y: 0)

                GarageTempoJArcMarker(point: addressPoint, title: "Address", role: .address, labelOffset: CGSize(width: -8, height: 34))
                GarageTempoJArcMarker(point: topPoint, title: "Top", role: .top, labelOffset: CGSize(width: -28, height: -30))
                GarageTempoJArcMarker(point: addressPoint, title: "Impact", role: .impact, isPulsing: impactPulse, labelOffset: CGSize(width: 64, height: 2))

                Circle()
                    .fill(GarageProTheme.textPrimary)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .stroke(GarageProTheme.accent.opacity(0.78), lineWidth: 5)
                    )
                    .shadow(color: GarageProTheme.glow.opacity(isRunning ? 0.38 : 0.18), radius: 12, x: 0, y: 0)
                    .position(dotPoint)
                    .animation(reduceMotion ? nil : .linear(duration: 1.0 / 30.0), value: displayedPathProgress)

                VStack(spacing: 1) {
                    Text(bpmText)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(GarageProTheme.textPrimary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text("BPM")
                        .font(.system(size: 7, weight: .black, design: .rounded))
                        .tracking(1.1)
                        .foregroundStyle(GaragePremiumPalette.gold.opacity(0.84))
                }
                .frame(width: 58, height: 42)
                .background(GarageProTheme.insetSurface.opacity(0.46), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(GaragePremiumPalette.gold.opacity(0.12), lineWidth: 1)
                )
                .position(x: rect.minX + 30, y: rect.minY + 22)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func jArcPath(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: point(at: 0, in: rect))
            path.addCurve(
                to: point(at: 0.46, in: rect),
                control1: CGPoint(x: rect.minX + rect.width * 0.26, y: rect.maxY + rect.height * 0.05),
                control2: CGPoint(x: rect.minX + rect.width * 0.04, y: rect.maxY - rect.height * 0.17)
            )
            path.addCurve(
                to: point(at: 1, in: rect),
                control1: CGPoint(x: rect.minX + rect.width * 0.36, y: rect.minY + rect.height * 0.42),
                control2: CGPoint(x: rect.minX + rect.width * 0.70, y: rect.minY + rect.height * 0.12)
            )
        }
    }

    private func progressPath(to progress: CGFloat, in rect: CGRect) -> Path {
        let clamped = min(max(progress, 0), 1)
        return Path { path in
            path.move(to: point(at: 0, in: rect))

            guard clamped > 0 else { return }

            for index in 1...48 {
                let segmentProgress = min(CGFloat(index) / 48, clamped)
                path.addLine(to: point(at: segmentProgress, in: rect))
                if segmentProgress >= clamped {
                    break
                }
            }
        }
    }

    private func point(at progress: CGFloat, in rect: CGRect) -> CGPoint {
        let clamped = min(max(progress, 0), 1)
        if clamped <= 0.46 {
            let local = clamped / 0.46
            return cubicPoint(
                t: local,
                start: CGPoint(x: rect.midX, y: rect.maxY - rect.height * 0.16),
                control1: CGPoint(x: rect.minX + rect.width * 0.26, y: rect.maxY + rect.height * 0.05),
                control2: CGPoint(x: rect.minX + rect.width * 0.04, y: rect.maxY - rect.height * 0.17),
                end: CGPoint(x: rect.minX + rect.width * 0.30, y: rect.midY + rect.height * 0.08)
            )
        }

        let local = (clamped - 0.46) / 0.54
        return cubicPoint(
            t: local,
            start: CGPoint(x: rect.minX + rect.width * 0.30, y: rect.midY + rect.height * 0.08),
            control1: CGPoint(x: rect.minX + rect.width * 0.36, y: rect.minY + rect.height * 0.42),
            control2: CGPoint(x: rect.minX + rect.width * 0.70, y: rect.minY + rect.height * 0.12),
            end: CGPoint(x: rect.maxX - rect.width * 0.08, y: rect.minY + rect.height * 0.08)
        )
    }

    private func cubicPoint(t: CGFloat, start: CGPoint, control1: CGPoint, control2: CGPoint, end: CGPoint) -> CGPoint {
        let inverse = 1 - t
        let x = pow(inverse, 3) * start.x
            + 3 * pow(inverse, 2) * t * control1.x
            + 3 * inverse * pow(t, 2) * control2.x
            + pow(t, 3) * end.x
        let y = pow(inverse, 3) * start.y
            + 3 * pow(inverse, 2) * t * control1.y
            + 3 * inverse * pow(t, 2) * control2.y
            + pow(t, 3) * end.y
        return CGPoint(x: x, y: y)
    }
}

private struct GarageTempoJArcMarker: View {
    let point: CGPoint
    let title: String
    var role: GarageTempoMarkerRole = .address
    var isPulsing = false
    var labelOffset = CGSize(width: 0, height: 22)

    var body: some View {
        ZStack {
            Circle()
                .stroke(role.color.opacity(isPulsing ? 0.58 : (role == .address ? 0.20 : 0.30)), lineWidth: role == .impact ? 3 : 1.6)
                .frame(
                    width: isPulsing ? role.haloSize + 18 : role.haloSize,
                    height: isPulsing ? role.haloSize + 18 : role.haloSize
                )
                .shadow(color: role.color.opacity(role == .impact ? 0.32 : 0.16), radius: role == .impact ? 10 : 6, x: 0, y: 0)
                .animation(.spring(response: 0.24, dampingFraction: 0.68), value: isPulsing)

            Circle()
                .fill(role.color)
                .frame(width: role.markerSize, height: role.markerSize)
        }
        .overlay {
            Text(title)
                .font(.system(size: role == .impact ? 11 : 10, weight: .black, design: .rounded))
                .textCase(.uppercase)
                .tracking(role == .top ? 1.25 : 1.45)
                .foregroundStyle(role == .impact ? GarageProTheme.accent.opacity(role.labelOpacity) : GarageProTheme.textPrimary.opacity(role.labelOpacity))
                .fixedSize()
                .offset(labelOffset)
                .shadow(color: role.color.opacity(role == .impact ? 0.28 : 0.14), radius: 5, x: 0, y: 0)
        }
        .position(point)
    }
}

private struct GarageTempoLandmarkGate: View {
    let progress: Double
    let color: Color
    let lineWidth: CGFloat
    let span: Double

    var body: some View {
        Circle()
            .trim(from: max(progress - span / 2, 0), to: min(progress + span / 2, 1))
            .stroke(
                color.opacity(0.84),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
            .shadow(color: color.opacity(0.32), radius: 8, x: 0, y: 0)
    }
}

private enum GarageTempoMarkerRole: Equatable {
    case address
    case top
    case impact

    var color: Color {
        switch self {
        case .address:
            return GaragePremiumPalette.gold
        case .top:
            return GaragePremiumPalette.gold.opacity(0.82)
        case .impact:
            return GarageProTheme.accent
        }
    }

    var markerSize: CGFloat {
        switch self {
        case .address:
            return 11
        case .top:
            return 15
        case .impact:
            return 23
        }
    }

    var haloSize: CGFloat {
        switch self {
        case .address:
            return 24
        case .top:
            return 32
        case .impact:
            return 54
        }
    }

    var labelOpacity: Double {
        switch self {
        case .address:
            return 0.88
        case .top:
            return 0.80
        case .impact:
            return 0.96
        }
    }
}

private struct GarageTempoMarker: View {
    let point: CGPoint
    let title: String
    var role: GarageTempoMarkerRole = .address
    var isPulsing = false
    var labelOffset = CGSize(width: 0, height: 22)

    var body: some View {
        ZStack {
            Circle()
                .stroke(role.color.opacity(isPulsing ? 0.58 : (role == .address ? 0.18 : 0.28)), lineWidth: role == .impact ? 3 : 1.6)
                .frame(
                    width: isPulsing ? role.haloSize + 20 : role.haloSize,
                    height: isPulsing ? role.haloSize + 20 : role.haloSize
                )
                .shadow(color: role.color.opacity(role == .impact ? 0.34 : 0.18), radius: role == .impact ? 10 : 6, x: 0, y: 0)
                .animation(.spring(response: 0.24, dampingFraction: 0.68), value: isPulsing)

            Circle()
                .fill(role.color)
                .frame(width: role.markerSize, height: role.markerSize)
        }
        .overlay(alignment: .bottom) {
                Text(title)
                    .font(.system(size: role == .impact ? 11 : 10, weight: .black, design: .rounded))
                    .textCase(.uppercase)
                    .tracking(role == .top ? 1.25 : 1.45)
                    .foregroundStyle(role == .impact ? GarageProTheme.accent.opacity(role.labelOpacity) : GarageProTheme.textPrimary.opacity(role.labelOpacity))
                    .fixedSize()
                    .offset(labelOffset)
                    .shadow(color: role.color.opacity(role == .impact ? 0.28 : 0.14), radius: 5, x: 0, y: 0)
        }
        .position(point)
    }
}

private struct GarageTempoSetupPanel: View {
    @Binding var configuration: GarageTempoConfiguration
    @Binding var profile: GarageTempoProfile
    let hapticsEnabled: Bool
    let onConfigurationChange: (GarageTempoConfiguration) -> Void

    var body: some View {
        VStack(spacing: 7) {
            GarageTempoSliderControlCard(
                title: "BPM",
                valueText: configuration.bpmText,
                value: Binding(
                    get: { configuration.beatsPerMinute },
                    set: { nextValue in
                        configuration.beatsPerMinute = nextValue.rounded()
                        onConfigurationChange(configuration)
                    }
                ),
                bounds: 60...90,
                step: 1
            )

            GarageTempoSliderControlCard(
                title: "Setup",
                valueText: configuration.setupDelayText,
                value: Binding(
                    get: { configuration.setupDelay },
                    set: { nextValue in
                        configuration.setupDelay = nextValue.rounded()
                        onConfigurationChange(configuration)
                    }
                ),
                bounds: 3...10,
                step: 1
            )

            GarageTempoProfileUtilityCard(
                profile: $profile,
                configuration: $configuration,
                hapticsEnabled: hapticsEnabled,
                onConfigurationChange: onConfigurationChange
            )
        }
    }
}

private struct GarageTempoLiveTuneDock: View {
    @Binding var configuration: GarageTempoConfiguration
    @Binding var profile: GarageTempoProfile
    let hapticsEnabled: Bool
    let onConfigurationChange: (GarageTempoConfiguration) -> Void

    var body: some View {
        HStack(spacing: 7) {
            GarageTempoCompactSliderCard(
                title: "BPM",
                value: configuration.bpmText,
                sliderValue: Binding(
                    get: { configuration.beatsPerMinute },
                    set: { nextValue in
                        configuration.beatsPerMinute = nextValue.rounded()
                        onConfigurationChange(configuration)
                    }
                ),
                bounds: 60...90,
                step: 1
            )

            GarageTempoCompactSliderCard(
                title: "Setup",
                value: configuration.setupDelayText,
                sliderValue: Binding(
                    get: { configuration.setupDelay },
                    set: { nextValue in
                        configuration.setupDelay = nextValue.rounded()
                        onConfigurationChange(configuration)
                    }
                ),
                bounds: 3...10,
                step: 1
            )

            GarageTempoProfileDockCard(
                profile: $profile,
                configuration: $configuration,
                hapticsEnabled: hapticsEnabled,
                onConfigurationChange: onConfigurationChange
            )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .background(GarageProTheme.insetSurface.opacity(0.42), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(GaragePremiumPalette.gold.opacity(0.13), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Live tune dock")
    }
}

private struct GarageTempoSliderControlCard: View {
    let title: String
    let valueText: String
    @Binding var value: Double
    let bounds: ClosedRange<Double>
    let step: Double

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(GarageProTheme.textSecondary)

                Text(valueText)
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundStyle(GaragePremiumPalette.gold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: 82, alignment: .leading)

            Slider(value: $value, in: bounds, step: step)
                .tint(GaragePremiumPalette.gold)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(GarageProTheme.insetSurface.opacity(0.42), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(GaragePremiumPalette.gold.opacity(0.10), lineWidth: 1)
        )
    }
}

private struct GarageTempoCompactSliderCard: View {
    let title: String
    let value: String
    @Binding var sliderValue: Double
    let bounds: ClosedRange<Double>
    let step: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 8, weight: .black, design: .rounded))
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .foregroundStyle(GarageProTheme.textSecondary)

                Spacer(minLength: 2)

                Text(value)
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(GaragePremiumPalette.gold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
            }

            Slider(value: $sliderValue, in: bounds, step: step)
                .tint(GaragePremiumPalette.gold)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, minHeight: 54)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .background(GarageProTheme.insetSurface.opacity(0.54), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(GaragePremiumPalette.gold.opacity(0.13), lineWidth: 1)
        )
    }
}

private struct GarageTempoProfileUtilityCard: View {
    @Binding var profile: GarageTempoProfile
    @Binding var configuration: GarageTempoConfiguration
    let hapticsEnabled: Bool
    let onConfigurationChange: (GarageTempoConfiguration) -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Profile")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(GarageProTheme.textSecondary)

                Text(profile.title)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(GaragePremiumPalette.gold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer(minLength: 8)

            GarageTempoIconButton(systemImage: "chevron.left", size: 34, hapticsEnabled: hapticsEnabled, action: selectPreviousProfile)
            GarageTempoIconButton(systemImage: "chevron.right", size: 34, hapticsEnabled: hapticsEnabled, action: selectNextProfile)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(GarageProTheme.insetSurface.opacity(0.42), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(GaragePremiumPalette.gold.opacity(0.10), lineWidth: 1)
        )
    }

    private func selectPreviousProfile() {
        selectProfile(offset: -1)
    }

    private func selectNextProfile() {
        selectProfile(offset: 1)
    }

    private func selectProfile(offset: Int) {
        let profiles = GarageTempoProfile.allCases
        guard let currentIndex = profiles.firstIndex(of: profile) else { return }
        let nextIndex = (currentIndex + offset + profiles.count) % profiles.count
        profile = profiles[nextIndex]
        let defaults = profile.tempoDefaults
        configuration.beatsPerMinute = defaults.beatsPerMinute
        configuration.setupDelay = defaults.setupDelay
        onConfigurationChange(configuration)
    }
}

private struct GarageTempoProfileDockCard: View {
    @Binding var profile: GarageTempoProfile
    @Binding var configuration: GarageTempoConfiguration
    let hapticsEnabled: Bool
    let onConfigurationChange: (GarageTempoConfiguration) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Profile")
                .font(.system(size: 8, weight: .black, design: .rounded))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(GarageProTheme.textSecondary)

            HStack(spacing: 3) {
                GarageTempoIconButton(systemImage: "chevron.left", size: 25, hapticsEnabled: hapticsEnabled, action: selectPreviousProfile)

                Text(profile.title)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(GaragePremiumPalette.gold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.52)
                    .frame(maxWidth: .infinity)

                GarageTempoIconButton(systemImage: "chevron.right", size: 25, hapticsEnabled: hapticsEnabled, action: selectNextProfile)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, minHeight: 54)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .background(GarageProTheme.insetSurface.opacity(0.54), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(GaragePremiumPalette.gold.opacity(0.13), lineWidth: 1)
        )
    }

    private func selectPreviousProfile() {
        selectProfile(offset: -1)
    }

    private func selectNextProfile() {
        selectProfile(offset: 1)
    }

    private func selectProfile(offset: Int) {
        let profiles = GarageTempoProfile.allCases
        guard let currentIndex = profiles.firstIndex(of: profile) else { return }
        let nextIndex = (currentIndex + offset + profiles.count) % profiles.count
        profile = profiles[nextIndex]
        let defaults = profile.tempoDefaults
        configuration.beatsPerMinute = defaults.beatsPerMinute
        configuration.setupDelay = defaults.setupDelay
        onConfigurationChange(configuration)
    }
}

private struct GarageTempoActionBar: View {
    let primaryTitle: String
    let primaryIcon: String
    let isPrimaryActive: Bool
    var stopTitle = "Stop"
    var moreTitle = "More"
    var showsStop = true
    var showsMore = true
    var canStop = true
    let hapticsEnabled: Bool
    let onPrimaryAction: () -> Void
    let onStop: () -> Void
    let onMore: () -> Void

    var body: some View {
        VStack(spacing: 7) {
            Button {
                if hapticsEnabled {
                    garageTriggerSelection()
                }
                onPrimaryAction()
            } label: {
                Label(primaryTitle, systemImage: primaryIcon)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(ModuleTheme.garageSurfaceDark)
                    .frame(maxWidth: .infinity, minHeight: 62)
                    .background(
                        LinearGradient(
                            colors: [
                                GaragePremiumPalette.gold,
                                GaragePremiumPalette.gold.opacity(isPrimaryActive ? 0.76 : 0.62),
                                GarageProTheme.accent.opacity(0.54)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.white.opacity(0.24), lineWidth: 1)
                    )
                    .shadow(color: GaragePremiumPalette.gold.opacity(isPrimaryActive ? 0.24 : 0.12), radius: 16, x: 0, y: 8)
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                Spacer(minLength: 0)

                if showsStop {
                    GarageTempoAuxiliaryButton(
                        title: stopTitle,
                        systemImage: "stop.fill",
                        isEnabled: canStop,
                        hapticsEnabled: hapticsEnabled,
                        action: onStop
                    )
                }

                if showsMore {
                    GarageTempoAuxiliaryButton(
                        title: moreTitle,
                        systemImage: "ellipsis",
                        isEnabled: true,
                        hapticsEnabled: hapticsEnabled,
                        action: onMore
                    )
                }
            }
        }
    }
}

private struct GarageTempoAuxiliaryButton: View {
    let title: String
    let systemImage: String
    let isEnabled: Bool
    let hapticsEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button {
            guard isEnabled else { return }
            if hapticsEnabled {
                garageTriggerSelection()
            }
            action()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .black))

                Text(title)
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }
            .foregroundStyle(GarageProTheme.textPrimary.opacity(isEnabled ? 0.92 : 0.42))
            .frame(minWidth: 76, minHeight: 32)
            .padding(.horizontal, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .background(GarageProTheme.insetSurface.opacity(0.46), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(GarageProTheme.border.opacity(0.72), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isEnabled == false)
    }
}

private struct GarageTempoTrayLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .black, design: .rounded))
            .textCase(.uppercase)
            .tracking(2)
            .foregroundStyle(GaragePremiumPalette.gold.opacity(0.86))
    }
}

private struct GarageTempoChip: View {
    let title: String
    let isSelected: Bool
    var hapticsEnabled = true
    let action: () -> Void

    var body: some View {
        Button {
            guard isSelected == false else { return }
            if hapticsEnabled {
                garageTriggerSelection()
            }
            action()
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .foregroundStyle(isSelected ? GarageProTheme.textPrimary : GarageProTheme.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(isSelected ? GarageProTheme.accent.opacity(0.18) : GarageProTheme.insetSurface.opacity(0.72), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? GarageProTheme.accent.opacity(0.42) : GarageProTheme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct GarageTempoIconButton: View {
    let systemImage: String
    var size: CGFloat = 36
    var isEnabled = true
    var hapticsEnabled = true
    let action: () -> Void

    var body: some View {
        Button {
            guard isEnabled else { return }
            if hapticsEnabled {
                garageTriggerSelection()
            }
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(GarageProTheme.textPrimary)
                .frame(width: size, height: size)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(GarageProTheme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(isEnabled == false)
    }
}

private struct GarageTempoMoreControlsSheet: View {
    @Binding var configuration: GarageTempoConfiguration
    @Binding var profile: GarageTempoProfile

    let engineState: GarageTempoRunState
    let onConfigurationChange: (GarageTempoConfiguration) -> Void
    let onReset: () -> Void
    let onPulse: () -> Void

    var body: some View {
        ZStack {
            GarageTempoCockpitBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    GarageProSectionHeader(eyebrow: "More", title: "Cue Setup")

                    GarageProCard(cornerRadius: 22, padding: 14) {
                        VStack(alignment: .leading, spacing: 12) {
                            GarageTempoTrayLabel("Profile")

                            HStack(spacing: 8) {
                                ForEach(GarageTempoProfile.allCases) { option in
                                    GarageTempoChip(
                                        title: option.title,
                                        isSelected: profile == option,
                                        hapticsEnabled: configuration.hapticsEnabled
                                    ) {
                                        profile = option
                                        let defaults = option.tempoDefaults
                                        configuration.beatsPerMinute = defaults.beatsPerMinute
                                        configuration.setupDelay = defaults.setupDelay
                                        onConfigurationChange(configuration)
                                    }
                                }
                            }
                        }
                    }

                    GarageProCard(cornerRadius: 22, padding: 14) {
                        Toggle("Audio cues", isOn: Binding(
                            get: { configuration.audioEnabled },
                            set: { isEnabled in
                                configuration.audioEnabled = isEnabled
                                onConfigurationChange(configuration)
                            }
                        ))
                            .font(.headline.weight(.bold))
                            .foregroundStyle(GarageProTheme.textPrimary)

                        Toggle("Haptics", isOn: Binding(
                            get: { configuration.hapticsEnabled },
                            set: { isEnabled in
                                configuration.hapticsEnabled = isEnabled
                                onConfigurationChange(configuration)
                            }
                        ))
                            .font(.headline.weight(.bold))
                            .foregroundStyle(GarageProTheme.textPrimary)
                    }

                    GarageProCard(cornerRadius: 22, padding: 14) {
                        GarageTempoSliderRow(
                            title: "Advanced BPM",
                            valueText: configuration.bpmText,
                            rangeText: "Fine pace control",
                            value: Binding(
                                get: { configuration.beatsPerMinute },
                                set: { nextValue in
                                    configuration.beatsPerMinute = nextValue.rounded()
                                    onConfigurationChange(configuration)
                                }
                            ),
                            bounds: 60...90,
                            step: 1
                        )

                        GarageTempoSliderRow(
                            title: "Setup Wait",
                            valueText: configuration.setupDelayText,
                            rangeText: "Silent address reset",
                            value: Binding(
                                get: { configuration.setupDelay },
                                set: { nextValue in
                                    configuration.setupDelay = nextValue.rounded()
                                    onConfigurationChange(configuration)
                                }
                            ),
                            bounds: 3...10,
                            step: 1
                        )
                    }

                    HStack(spacing: 10) {
                        GarageTempoSecondaryButton(
                            title: "Test cue",
                            systemImage: "checkmark.seal.fill",
                            isEnabled: true,
                            hapticsEnabled: configuration.hapticsEnabled,
                            action: onPulse
                        )

                        GarageTempoSecondaryButton(
                            title: "Reset",
                            systemImage: "arrow.counterclockwise",
                            isEnabled: engineState != .ready,
                            hapticsEnabled: configuration.hapticsEnabled,
                            action: onReset
                        )
                    }

                    GarageTempoFoundationCard(configuration: configuration)
                }
                .padding(18)
            }
            .scrollIndicators(.hidden)
        }
    }
}

private struct GarageTempoSliderRow: View {
    let title: String
    let valueText: String
    let rangeText: String
    @Binding var value: Double
    let bounds: ClosedRange<Double>
    let step: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline.weight(.black))
                        .foregroundStyle(GarageProTheme.textPrimary)

                    Text(rangeText)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(GarageProTheme.textSecondary)
                }

                Spacer(minLength: 12)

                Text(valueText)
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundStyle(GaragePremiumPalette.gold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Slider(value: $value, in: bounds, step: step)
                .tint(GarageProTheme.accent)
        }
        .padding(14)
        .background(GarageProTheme.insetSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(GarageProTheme.border, lineWidth: 1)
        )
    }
}

private struct GarageTempoSecondaryButton: View {
    let title: String
    let systemImage: String
    let isEnabled: Bool
    var isProminent = false
    var hapticsEnabled = true
    let action: () -> Void

    var body: some View {
        Button {
            guard isEnabled else { return }
            if hapticsEnabled {
                garageTriggerSelection()
            }
            action()
        } label: {
            Label(title, systemImage: systemImage)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .foregroundStyle(isProminent ? ModuleTheme.garageSurfaceDark : GarageProTheme.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(GarageProTheme.insetSurface.opacity(0.9))

                    if isProminent {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        GaragePremiumPalette.gold,
                                        GarageProTheme.accent.opacity(0.82)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(isProminent ? Color.white.opacity(0.22) : GarageProTheme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.44)
        .disabled(isEnabled == false)
    }
}

private struct GarageTempoFoundationCard: View {
    let configuration: GarageTempoConfiguration

    var body: some View {
        GarageProCard(cornerRadius: 24, padding: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(GarageProTheme.accent)
                    .frame(width: 44, height: 44)
                    .background(GarageProTheme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 15, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text("Local rehearsal tool")
                        .font(.headline.weight(.black))
                        .foregroundStyle(GarageProTheme.textPrimary)

                    Text("No camera, mic, AI, or sensor-based claims. History and saved fingerprints stay behind a later persistence gate.")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(GarageProTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("\(configuration.bpmText) BPM - \(configuration.setupDelayText) setup - \(configuration.ratioText) tempo")
                        .font(.caption.weight(.black))
                        .foregroundStyle(GaragePremiumPalette.gold)
                }
            }
        }
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
            onBuildRoutine: {},
            onReviewManualSelection: { _ in }
        )
    }
    .modelContainer(PreviewCatalog.populatedApp)
}
