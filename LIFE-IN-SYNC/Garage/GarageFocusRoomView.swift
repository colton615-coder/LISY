import SwiftUI

struct GarageFocusDrillPresentation {
    let title: String
    let metadata: String
    let objective: String
    let executionCommand: String
    let passCheck: String
    let repTarget: String
    let setup: [String]
    let commonMisses: [String]
    let resetCue: String
    let equipment: [String]
    let isCompleted: Bool
}

struct GarageFocusRoomView: View {
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
                    setup: drill.setup,
                    commonMisses: drill.commonMisses,
                    resetCue: drill.resetCue,
                    equipment: drill.equipment,
                    isCompleted: drill.isCompleted,
                    isDetailExpanded: isDetailExpanded,
                    onToggleDetail: onToggleDetail
                )

                GarageFocusDrillStackRail(
                    items: railItems,
                    onSelectDrill: onSelectRailDrill
                )
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                GarageFocusDrillActionDock(
                    backEnabled: backEnabled,
                    noteTitle: noteTitle,
                    primaryTitle: primaryCtaTitle,
                    onBack: onBack,
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
    static let contentBottomInset: CGFloat = 196
}
