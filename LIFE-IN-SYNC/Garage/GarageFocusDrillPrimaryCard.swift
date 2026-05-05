import SwiftUI

struct GarageFocusDrillPrimaryCard: View {
    let drillTitle: String
    let drillMetadata: String
    let objective: String
    let executionCommand: String
    let passCheck: String
    let repTarget: String
    let setup: [String]
    let commonMisses: [String]
    let resetCue: String
    let equipment: [String]
    let isCompleted: Bool
    let isDetailExpanded: Bool
    let onToggleDetail: () -> Void

    var body: some View {
        GarageProCard(isActive: true, cornerRadius: 26, padding: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(drillTitle)
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(GarageProTheme.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)

                    if drillMetadata.isEmpty == false {
                        Text(drillMetadata)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(GarageProTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 8)

                Text(isCompleted ? GarageFocusRoomCopy.focusRoomRailCompletedLabel : GarageFocusRoomCopy.focusRoomRailCurrentLabel)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .textCase(.uppercase)
                    .tracking(1.6)
                    .foregroundStyle(isCompleted ? GarageProTheme.textSecondary : GarageProTheme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(GarageProTheme.insetSurface, in: Capsule(style: .continuous))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(isCompleted ? GarageProTheme.border : GarageProTheme.accent.opacity(0.3), lineWidth: 1)
                    )
            }

            GarageFocusDrillLabelValue(
                label: GarageFocusRoomCopy.focusRoomObjectiveLabel,
                value: objective,
                emphasized: false
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

            HStack(spacing: 8) {
                Text(GarageFocusRoomCopy.focusRoomRepTargetLabel)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .textCase(.uppercase)
                    .tracking(1.6)
                    .foregroundStyle(GarageProTheme.textSecondary)

                Text(repTarget)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(GarageProTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer(minLength: 8)
            }
            .padding(12)
            .background(GarageProTheme.insetSurface.opacity(0.72), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(GarageProTheme.border, lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 10) {
                Button(action: onToggleDetail) {
                    HStack(spacing: 10) {
                        Text(GarageFocusRoomCopy.focusRoomDetailRegionLabel)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(GarageProTheme.textPrimary)

                        Spacer(minLength: 8)

                        Image(systemName: isDetailExpanded ? "chevron.up.circle.fill" : "chevron.down.circle")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(isDetailExpanded ? GarageProTheme.accent : GarageProTheme.textSecondary)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(GarageProTheme.insetSurface.opacity(isDetailExpanded ? 0.9 : 0.72))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(isDetailExpanded ? GarageProTheme.accent.opacity(0.34) : GarageProTheme.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                if isDetailExpanded {
                    VStack(alignment: .leading, spacing: 10) {
                        GarageFocusDrillDetailBlock(label: GarageFocusRoomCopy.focusRoomDetailSetupLabel, values: setup)
                        GarageFocusDrillDetailBlock(label: GarageFocusRoomCopy.focusRoomDetailCommonMissLabel, values: commonMisses)
                        GarageFocusDrillDetailBlock(label: GarageFocusRoomCopy.focusRoomDetailResetCueLabel, values: [resetCue], isCue: true)
                        GarageFocusDrillDetailBlock(label: GarageFocusRoomCopy.focusRoomDetailEquipmentLabel, values: equipment)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }
}

private struct GarageFocusDrillLabelValue: View {
    let label: String
    let value: String
    let emphasized: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
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

private struct GarageFocusDrillDetailBlock: View {
    let label: String
    let values: [String]
    var isCue = false

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .textCase(.uppercase)
                .tracking(1.6)
                .foregroundStyle(GarageProTheme.textSecondary)

            ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                HStack(alignment: .top, spacing: 8) {
                    if values.count > 1 {
                        Circle()
                            .fill(GarageProTheme.accent)
                            .frame(width: 5, height: 5)
                            .padding(.top, 7)
                    }

                    Text(value)
                        .font(isCue ? .subheadline.weight(.bold) : .subheadline.weight(.medium))
                        .foregroundStyle(isCue ? GarageProTheme.accent : GarageProTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
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
