import SwiftUI

struct GarageFocusDrillPrimaryCard: View {
    let drillTitle: String
    let drillMetadata: String
    let environment: PracticeEnvironment
    let drillPositionText: String
    let completedCount: Int
    let totalCount: Int
    let objective: String
    let executionCommand: String
    let passCheck: String
    let repTarget: String
    let diagram: GarageDrillDiagram
    let setup: [String]
    let commonMisses: [String]
    let resetCue: String
    let equipment: [String]
    let isCompleted: Bool
    let isDetailExpanded: Bool
    let onToggleDetail: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            GarageDrillSetupVisualPanel(
                diagram: diagram
            )

            GarageFocusDrillLabelValue(
                label: GarageFocusRoomCopy.focusRoomExecutionCommandLabel,
                value: executionCommand,
                emphasized: true
            )

            GarageFocusDrillLabelValue(
                label: GarageFocusRoomCopy.focusRoomPassCheckLabel,
                value: passCheck,
                emphasized: false
            )

            GarageFocusDrillFeedbackRow(
                repTarget: repTarget,
                watchFor: commonMisses.first ?? "Watch for rushed reps, unclear feedback, or a setup that drifts from the diagram."
            )
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .background(GarageProTheme.surface, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(GarageProTheme.border, lineWidth: 1)
        )
        .shadow(color: GarageProTheme.darkShadow, radius: 18, x: 0, y: 12)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Label(environment.displayName, systemImage: environment.systemImage)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(GarageProTheme.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text(drillTitle)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(GarageProTheme.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(completedCount)/\(totalCount)")
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundStyle(GarageProTheme.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.74)

                    Text("Progress")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .textCase(.uppercase)
                        .tracking(1.6)
                        .foregroundStyle(GarageProTheme.textSecondary)
                }
            }

            HStack(spacing: 10) {
                Text(drillPositionText)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(GarageProTheme.textSecondary)

                Spacer(minLength: 8)

                Text(repTarget)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(GarageProTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(GarageProTheme.insetSurface.opacity(0.66), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(GarageProTheme.border, lineWidth: 1)
            )

            if drillMetadata.isEmpty == false {
                Text(drillMetadata)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(GarageProTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            GarageFocusDrillObjectiveStrip(objective: objective)
        }
    }
}

private struct GarageDrillSetupVisualPanel: View {
    let diagram: GarageDrillDiagram

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Set up like this")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .textCase(.uppercase)
                    .tracking(1.6)
                    .foregroundStyle(GarageProTheme.textSecondary)

                Spacer()

                Text(diagramTypeLabel)
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .foregroundStyle(GarageProTheme.accent)
            }

            GarageDrillDiagramView(diagram: diagram)
                .frame(maxWidth: .infinity, minHeight: 270)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(GarageProTheme.border, lineWidth: 1)
            )

            Text(diagram.caption)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(GarageProTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(GarageProTheme.insetSurface.opacity(0.48), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(GarageProTheme.border, lineWidth: 1)
        )
    }

    private var diagramTypeLabel: String {
        switch diagram.type {
        case .netContact:
            return "Contact map"
        case .netDelivery:
            return "Delivery map"
        case .rangeStartWindow:
            return "Start window"
        case .puttingGate:
            return "Gate line"
        case .puttingPaceControl:
            return "Pace zone"
        case .general:
            return "Practice map"
        }
    }
}

private struct GarageFocusDrillLabelValue: View {
    let label: String
    let value: String
    let emphasized: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .textCase(.uppercase)
                .tracking(1.6)
                .foregroundStyle(GarageProTheme.textSecondary)

            Text(value)
                .font(emphasized ? .headline.weight(.bold) : .subheadline.weight(.medium))
                .foregroundStyle(emphasized ? GarageProTheme.accent : GarageProTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(GarageProTheme.insetSurface.opacity(0.72), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(GarageProTheme.border, lineWidth: 1)
        )
    }
}

private struct GarageFocusDrillObjectiveStrip: View {
    let objective: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(GarageFocusRoomCopy.focusRoomObjectiveLabel)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .textCase(.uppercase)
                .tracking(1.4)
                .foregroundStyle(GarageProTheme.textSecondary)

            Text(objective)
                .font(.footnote.weight(.medium))
                .foregroundStyle(GarageProTheme.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(GarageProTheme.insetSurface.opacity(0.5), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(GarageProTheme.border, lineWidth: 1)
        )
    }
}

private struct GarageFocusDrillFeedbackRow: View {
    let repTarget: String
    let watchFor: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label(repTarget, systemImage: "repeat")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(GarageProTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Spacer(minLength: 8)

                Text("Watch for")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .textCase(.uppercase)
                    .tracking(1.4)
                    .foregroundStyle(GarageProTheme.accent)
            }

            Text(watchFor)
                .font(.footnote.weight(.medium))
                .foregroundStyle(GarageProTheme.textSecondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(GarageProTheme.insetSurface.opacity(0.58), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(GarageProTheme.border, lineWidth: 1)
        )
    }
}
