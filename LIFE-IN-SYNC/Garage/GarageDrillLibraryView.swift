import SwiftData
import SwiftUI

@MainActor
struct GarageDrillLibraryView: View {
    @Query(sort: \PracticeTemplate.title) private var savedTemplates: [PracticeTemplate]

    @State private var selectedRoutine: GarageLibraryRoutineDescriptor?
    @State private var selectedDrill: GarageDrill?

    let onStartRoutine: (PracticeTemplate) -> Void

    var body: some View {
        GarageProScaffold(bottomPadding: 28) {
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
                onStartRoutine: onStartRoutine
            )
        }
        .sheet(item: $selectedDrill) { drill in
            GarageDrillDetailSheet(drill: drill)
        }
    }

    private var heroCard: some View {
        GarageProHeroCard(
            eyebrow: "Drills",
            title: "Routines first. Reference second.",
            subtitle: "Start a predefined routine, review saved routines, or open any drill for the full instruction stack.",
            value: "\(DrillVault.masterPlaybook.count)",
            valueLabel: "Library Drills"
        ) {
            Image(systemName: "book.closed.fill")
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
                                    detailText: "\(routine.drillIDs.count) drills • \(routine.makePracticeTemplate().drills.reduce(0) { $0 + $1.defaultRepCount }) planned reps",
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
                        detailText: "\(template.drills.count) drills • \(template.drills.reduce(0) { $0 + $1.defaultRepCount }) planned reps",
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
        GarageProCard(cornerRadius: 24, padding: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(GarageProTheme.accent)
                    .frame(width: 52, height: 52)
                    .background(GarageProTheme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 17, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(badgeText)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .textCase(.uppercase)
                        .tracking(1.7)
                        .foregroundStyle(GarageProTheme.accent.opacity(0.9))

                    Text(title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(GarageProTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(subtitle)
                        .font(.subheadline.weight(.medium))
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
        GarageProCard(cornerRadius: 22, padding: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: drill.environment.systemImage)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(GarageProTheme.accent)
                    .frame(width: 48, height: 48)
                    .background(GarageProTheme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(drill.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(GarageProTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(drill.purpose)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(GarageProTheme.textSecondary)
                        .lineLimit(2)

                    Text("\(drill.environment.displayName) • \(drill.defaultRepCount) reps • \(drill.clubRange.displayName)")
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

private struct GarageRoutineDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    let routine: GarageLibraryRoutineDescriptor
    let onStartRoutine: (PracticeTemplate) -> Void

    var body: some View {
        NavigationStack {
            GarageProScaffold(bottomPadding: 28) {
                GarageProHeroCard(
                    eyebrow: routine.sourceLabel,
                    title: routine.title,
                    subtitle: routine.purpose,
                    value: "\(routine.totalRepCount)",
                    valueLabel: "Planned Reps"
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
                    onStartRoutine(routine.launchTemplate)
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

    let drill: GarageDrill

    private var detail: GarageDrillFocusDetail {
        GarageDrillFocusDetails.detail(for: drill)
    }

    private var routineTitles: String {
        let titles = DrillVault.routines(containing: drill).map(\.title)
        return titles.isEmpty ? "Reference drill" : titles.joined(separator: " • ")
    }

    var body: some View {
        NavigationStack {
            GarageProScaffold(bottomPadding: 28) {
                GarageProHeroCard(
                    eyebrow: drill.libraryCategory.displayName,
                    title: drill.title,
                    subtitle: drill.purpose,
                    value: "\(drill.defaultRepCount)",
                    valueLabel: "Default Reps"
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

                    Text("\(drill.environment.displayName) • \(drill.clubRange.displayName) • \(routineTitles)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(GarageProTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                GarageProCard(cornerRadius: 24, padding: 18) {
                    Text("Setup")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .textCase(.uppercase)
                        .tracking(2)
                        .foregroundStyle(GarageProTheme.accent)

                    ForEach(detail.setup, id: \.self) { item in
                        Text(item)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(GarageProTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                GarageProCard(cornerRadius: 24, padding: 18) {
                    Text("Execution")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .textCase(.uppercase)
                        .tracking(2)
                        .foregroundStyle(GarageProTheme.accent)

                    ForEach(detail.execution, id: \.self) { item in
                        Text(item)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(GarageProTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                GarageProCard(cornerRadius: 24, padding: 18) {
                    Text("Success Standard")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .textCase(.uppercase)
                        .tracking(2)
                        .foregroundStyle(GarageProTheme.accent)

                    ForEach(detail.successCriteria, id: \.self) { item in
                        Text(item)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(GarageProTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
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
        self.drillRows = resolvedDrills.map {
            GarageLibraryRoutineDrillRow(
                id: $0.id,
                title: $0.title,
                summary: $0.purpose
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
        self.drillRows = template.drills.map { drill in
            let summary = DrillVault.canonicalDrill(for: drill)?.purpose ?? drill.focusArea
            return GarageLibraryRoutineDrillRow(
                id: drill.id.uuidString,
                title: drill.title,
                summary: summary.isEmpty ? "\(drill.defaultRepCount) planned reps" : summary
            )
        }
        self.launchTemplate = template
    }
}

private struct GarageLibraryRoutineDrillRow: Identifiable {
    let id: String
    let title: String
    let summary: String
}

#Preview("Garage Drill Library") {
    NavigationStack {
        GarageDrillLibraryView { _ in }
    }
    .modelContainer(PreviewCatalog.populatedApp)
}
