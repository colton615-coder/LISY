import SwiftUI

struct GarageFocusDrillPresentation {
    let title: String
    let metadata: String
    let objective: String
    let executionCommand: String
    let passCheck: String
    let repTarget: String
    let visualKind: GarageFocusDrillVisualKind
    let setup: [String]
    let commonMisses: [String]
    let resetCue: String
    let equipment: [String]
    let isCompleted: Bool
}

enum GarageFocusDrillVisualKind: Hashable {
    case towel
    case putting
    case range
    case net

    init(drill: PracticeTemplateDrill) {
        let title = drill.title.localizedLowercase

        if title.contains("towel") {
            self = .towel
            return
        }

        if DrillVault.canonicalDrill(for: drill)?.environment == .puttingGreen || title.contains("putt") || title.contains("gate") {
            self = .putting
            return
        }

        if DrillVault.canonicalDrill(for: drill)?.environment == .range {
            self = .range
            return
        }

        self = .net
    }
}

struct GarageFocusRoomView: View {
    @State private var isRoutineVisible = false

    let sessionTitle: String
    let drillPositionText: String
    let completedCount: Int
    let totalCount: Int
    let drill: GarageFocusDrillPresentation?
    let railItems: [GarageFocusDrillRailItem]
    let isDetailExpanded: Bool
    let noteTitle: String
    let primaryCtaTitle: String
    let backEnabled: Bool
    let onToggleDetail: () -> Void
    let onSelectRailDrill: (Int) -> Void
    let onBack: () -> Void
    let onNote: () -> Void
    let onPrimary: () -> Void
    let onExitEmptyRoutine: () -> Void

    var body: some View {
        if let drill {
            GarageProScaffold(bottomPadding: GarageFocusRoomLayout.contentBottomInset) {
                GarageFocusRoomHeader(
                    sessionTitle: sessionTitle,
                    drillPositionText: drillPositionText,
                    completedCount: completedCount,
                    totalCount: totalCount
                )

                GarageFocusDrillPrimaryCard(
                    drillTitle: drill.title,
                    drillMetadata: drill.metadata,
                    objective: drill.objective,
                    executionCommand: drill.executionCommand,
                    passCheck: drill.passCheck,
                    repTarget: drill.repTarget,
                    visualKind: drill.visualKind,
                    setup: drill.setup,
                    commonMisses: drill.commonMisses,
                    resetCue: drill.resetCue,
                    equipment: drill.equipment,
                    isCompleted: drill.isCompleted,
                    isDetailExpanded: isDetailExpanded,
                    onToggleDetail: onToggleDetail
                )

                GarageRoutineDisclosureButton(isExpanded: isRoutineVisible) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isRoutineVisible.toggle()
                    }
                }

                if isRoutineVisible {
                    GarageFocusDrillStackRail(
                        items: railItems,
                        onSelectDrill: onSelectRailDrill
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                GarageFocusDrillActionDock(
                    noteTitle: noteTitle,
                    primaryTitle: primaryCtaTitle,
                    onNote: onNote,
                    onPrimary: onPrimary
                )
                .background(
                    LinearGradient(
                        colors: [
                            ModuleTheme.garageBackground.opacity(0.0),
                            ModuleTheme.garageBackground.opacity(0.92)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        } else {
            GarageProScaffold(bottomPadding: 40) {
                GarageProCard(isActive: true) {
                    Text("No drills in this routine")
                        .font(.system(.title3, design: .rounded).weight(.black))
                        .foregroundStyle(GarageProTheme.textPrimary)

                    Text("Return to Garage and choose a routine with at least one drill.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(GarageProTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    GarageProPrimaryButton(
                        title: GarageFocusRoomCopy.focusRoomBackCta,
                        systemImage: "chevron.left",
                        action: onExitEmptyRoutine
                    )
                }
            }
        }
    }
}

private enum GarageFocusRoomLayout {
    static let contentBottomInset: CGFloat = 128
}

private struct GarageRoutineDisclosureButton: View {
    let isExpanded: Bool
    let action: () -> Void

    var body: some View {
        Button {
            garageTriggerSelection()
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "list.bullet.rectangle")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(GarageProTheme.accent)
                    .frame(width: 42, height: 42)
                    .background(GarageProTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                Text("View Routine")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(GarageProTheme.textPrimary)

                Spacer(minLength: 8)

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(GarageProTheme.textSecondary)
            }
            .padding(14)
            .background(GarageProTheme.insetSurface.opacity(0.72), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(GarageProTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
