import Foundation
import SwiftData
import SwiftUI

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
struct GarageHomeTabView: View {
    @Query(sort: \PracticeSessionRecord.date, order: .reverse) private var records: [PracticeSessionRecord]
    @State private var selectedRoutineIDs: [String: String] = [:]
    @Binding var selectedTab: GarageRootTab

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
        .toolbar(.hidden, for: .navigationBar)
    }

    private var environmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            GarageProSectionHeader(
                eyebrow: "Start Here",
                title: "Choose Environment"
            )

            VStack(spacing: 8) {
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
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Last Session • Today"
        }

        if calendar.isDateInYesterday(date) {
            return "Last Session • Yesterday"
        }

        let dayDelta = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: date),
            to: calendar.startOfDay(for: .now)
        ).day ?? 0

        if dayDelta >= 2 {
            return "Last Session • \(dayDelta) days ago"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Last Session • \(formatter.localizedString(for: date, relativeTo: .now).lowercased())"
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

    var body: some View {
        GarageCompactEnvironmentCardSurface {
            GarageEnvironmentCardHeader(
                environment: environment,
                sessionCount: sessionCount,
                routineCount: routines.count
            )

            GarageRoutineChipRow(
                routines: routines,
                selectedRoutineID: selectedRoutine.id,
                onSelectRoutine: onSelectRoutine
            )

            GarageRoutineDetailSummary(routine: selectedRoutine)

            GarageRoutineActionRow(
                onGenerateRoutine: onGenerateRoutine,
                onStartRoutine: onStartRoutine
            )
        }
    }
}

private struct GarageCompactEnvironmentCardSurface<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(GarageProTheme.elevatedSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(GarageProTheme.accent.opacity(0.28), lineWidth: 1)
        )
        .shadow(color: GarageProTheme.darkShadow, radius: 12, x: 0, y: 8)
        .shadow(color: GarageProTheme.glow.opacity(0.16), radius: 12, x: 0, y: 0)
    }
}

private struct GarageEnvironmentCardHeader: View {
    let environment: PracticeEnvironment
    let sessionCount: Int
    let routineCount: Int

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: environment.systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(GarageProTheme.accent)
                .frame(width: 34, height: 34)
                .background(GarageProTheme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(environment.displayName)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(GarageProTheme.textPrimary)
                    .lineLimit(1)

                Text(environment.description)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(GarageProTheme.textSecondary)
                    .lineLimit(2)

                Text("\(routineCount) preset routines • \(sessionCount) saved sessions")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(GarageProTheme.accent.opacity(0.88))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
        }
    }
}

private struct GarageRoutineChipRow: View {
    let routines: [GarageRoutine]
    let selectedRoutineID: String
    let onSelectRoutine: (GarageRoutine) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Preset Routines")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .textCase(.uppercase)
                .tracking(1.4)
                .foregroundStyle(GarageProTheme.accent)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
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
                .padding(.vertical, 0.5)
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
            HStack(spacing: 3) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 7, weight: .black))
                }

                Text(routine.title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(isSelected ? ModuleTheme.garageSurfaceDark : GarageProTheme.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .fixedSize(horizontal: true, vertical: false)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? GarageProTheme.accent : ModuleTheme.garageTurfSurface.opacity(0.22))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? GarageProTheme.accent.opacity(0.34) : GarageProTheme.accent.opacity(0.22), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct GarageRoutineDetailSummary: View {
    let routine: GarageRoutine

    private var drillCount: Int {
        routine.drillIDs.count
    }

    private var totalRepCount: Int {
        DrillVault.drills(for: routine).reduce(0) { $0 + $1.defaultRepCount }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Aims to help with")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .textCase(.uppercase)
                .tracking(1.1)
                .foregroundStyle(GarageProTheme.textSecondary)

            Text(routine.title)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(GarageProTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Text(routine.purpose)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(GarageProTheme.textSecondary)
                .lineLimit(2)

            Text("\(routine.estimatedMinutes) min • \(drillCount) drills • \(routine.difficulty.displayName) • \(totalRepCount) reps")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(GarageProTheme.accent.opacity(0.86))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 2)
        .padding(.bottom, 1)
    }
}

private struct GarageRoutineActionRow: View {
    let onGenerateRoutine: () -> Void
    let onStartRoutine: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            GarageHomeSecondaryButton(
                title: "AI Generate",
                systemImage: "sparkles",
                action: onGenerateRoutine
            )

            GarageHomeCompactPrimaryButton(
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
    let action: () -> Void

    var body: some View {
        Button {
            garageTriggerSelection()
            action()
        } label: {
            Label(title, systemImage: systemImage)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .multilineTextAlignment(.leading)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .foregroundStyle(GarageProTheme.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
                .padding(.horizontal, 11)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(GarageProTheme.insetSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(GarageProTheme.accent.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct GarageHomeCompactPrimaryButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button {
            garageTriggerImpact(.heavy)
            action()
        } label: {
            Label(title, systemImage: systemImage)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .foregroundStyle(ModuleTheme.garageSurfaceDark)
                .frame(maxWidth: .infinity, minHeight: 46)
                .padding(.horizontal, 10)
                .background(
                    LinearGradient(
                        colors: [
                            GarageProTheme.accent,
                            GarageProTheme.accent.opacity(0.76)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .shadow(color: GarageProTheme.glow.opacity(0.28), radius: 10, x: 0, y: 6)
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

struct GarageInternalTabBar: View {
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
