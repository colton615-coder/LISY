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
                VStack(alignment: .leading, spacing: 18) {
                    GaragePlanGeneratorHeader()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("What's today's focus?")
                            .font(.system(size: 18, weight: .bold))
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
                .padding(.top, 20)
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
            HStack(spacing: 14) {
                Image(systemName: "bag.fill")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(GaragePremiumPalette.gold)
                    .frame(width: 48, height: 48)
                    .background(GaragePremiumPalette.emerald.opacity(0.42), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

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
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(GaragePremiumPalette.gold)
                    .frame(width: 38, height: 38)
                    .background(Color.black.opacity(0.24), in: Circle())
                    .overlay(Circle().stroke(GaragePremiumPalette.gold.opacity(0.32), lineWidth: 1))
            }
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .background(GaragePremiumPalette.emeraldGlass.opacity(0.55), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.09), lineWidth: 1)
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
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Browse Drill Directory")
                            .font(.system(size: 26, weight: .black, design: .rounded))
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
                    .padding(.top, 22)
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
        .frame(maxWidth: .infinity, minHeight: 46)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .background(GarageProTheme.insetSurface.opacity(0.82), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct GarageManualCategoryRail: View {
    let categories: [GarageDrillLibraryCategory]
    @Binding var selectedCategory: GarageDrillLibraryCategory?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
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
            .padding(.vertical, 2)
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
                .padding(.horizontal, 14)
                .frame(height: 34)
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
            HStack(spacing: 12) {
                Image(systemName: drill.systemImage)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(isSelected ? ModuleTheme.garageAccent : GarageProTheme.textSecondary.opacity(0.92))
                    .frame(width: 40, height: 40)
                    .background(GarageProTheme.insetSurface.opacity(0.82), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(drill.title)
                        .font(.system(size: 16, weight: .black, design: .rounded))
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
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(isSelected ? ModuleTheme.garageAccent : GarageProTheme.textSecondary.opacity(0.56))
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
            .background(
                ModuleTheme.garageTurfSurface.opacity(isSelected ? 0.76 : 0.58),
                in: RoundedRectangle(cornerRadius: 19, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .stroke(isSelected ? ModuleTheme.garageAccent.opacity(0.82) : Color.white.opacity(0.08), lineWidth: isSelected ? 1.2 : 1)
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
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(ModuleTheme.garageAccent, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: AppModule.garage.theme.shadowDark.opacity(0.36), radius: 12, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.top, 10)
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
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color(red: 0.01, green: 0.055, blue: 0.038).opacity(0.84))
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(isFocused ? GaragePremiumPalette.gold.opacity(0.42) : Color.white.opacity(0.09), lineWidth: 1)
                )
                .overlay(alignment: .trailing) {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    .clear,
                                    Color(red: 0.29, green: 1.0, blue: 0.46).opacity(0.42),
                                    GaragePremiumPalette.gold.opacity(0.18),
                                    .clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 220, height: 7)
                        .blur(radius: 9)
                        .rotationEffect(.degrees(-22))
                        .offset(x: -10, y: 26)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                        .blur(radius: 1)
                        .mask(
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [.white, .clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                )
                .shadow(color: AppModule.garage.theme.shadowDark.opacity(0.34), radius: 12, x: 0, y: 8)

            if text.isEmpty {
                Text("E.g. 30 minutes on shallowing the club and driver consistency")
                    .font(.system(size: 16, weight: .medium))
                    .lineSpacing(4)
                    .foregroundStyle(GarageProTheme.textSecondary.opacity(0.76))
                    .padding(.horizontal, 22)
                    .padding(.top, 22)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $text)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(GarageProTheme.textPrimary)
                .scrollContentBackground(.hidden)
                .focused($isFocused)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.clear)
                .frame(minHeight: 118)

            Text("\(text.count)/120")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(GarageProTheme.textSecondary.opacity(0.72))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 18)
                .padding(.bottom, 14)
        }
        .frame(minHeight: 118)
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
                .frame(maxWidth: .infinity, minHeight: 58)
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
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                )
                .shadow(color: GaragePremiumPalette.gold.opacity(0.24), radius: 16, x: 0, y: 8)
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
                    .font(.system(size: 31, weight: .heavy))
                    .foregroundStyle(GarageProTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Label("AI", systemImage: "sparkles")
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(GaragePremiumPalette.gold)
                .padding(.horizontal, 11)
                .frame(minHeight: 34)
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

            HStack(spacing: 8) {
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
            onBuildRoutine: {},
            onReviewManualSelection: { _ in }
        )
    }
    .modelContainer(PreviewCatalog.populatedApp)
}
