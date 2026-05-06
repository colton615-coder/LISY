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
    let visualKind: GarageFocusDrillVisualKind
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
                kind: visualKind,
                title: visualTitle,
                caption: setup.first ?? "Set the drill before counting reps."
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
                objective: objective
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
        }
    }

    private var visualTitle: String {
        switch visualKind {
        case .towel:
            return "Ball, towel line, clean path"
        case .putting:
            return "Gate, start line, pace window"
        case .range:
            return "Target window and launch lane"
        case .net:
            return "Net lane and club path"
        }
    }
}

private struct GarageDrillSetupVisualPanel: View {
    let kind: GarageFocusDrillVisualKind
    let title: String
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Visual Setup")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .textCase(.uppercase)
                    .tracking(1.6)
                    .foregroundStyle(GarageProTheme.textSecondary)

                Spacer()

                Text(title)
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .foregroundStyle(GarageProTheme.accent)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(GarageProTheme.insetSurface.opacity(0.86))

                switch kind {
                case .towel:
                    GarageTowelSetupDiagram()
                case .putting:
                    GaragePuttingSetupDiagram()
                case .range:
                    GarageRangeSetupDiagram()
                case .net:
                    GarageNetSetupDiagram()
                }
            }
            .frame(maxWidth: .infinity, minHeight: 176)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(GarageProTheme.border, lineWidth: 1)
            )

            Text(caption)
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
}

private struct GarageTowelSetupDiagram: View {
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let centerY = height * 0.55

            ZStack {
                Capsule(style: .continuous)
                    .fill(GarageProTheme.accent.opacity(0.16))
                    .frame(width: width * 0.5, height: 16)
                    .position(x: width * 0.35, y: centerY + 34)

                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(GarageProTheme.textSecondary.opacity(0.28))
                    .frame(width: width * 0.38, height: 10)
                    .position(x: width * 0.42, y: centerY)

                Circle()
                    .fill(GarageProTheme.textPrimary)
                    .frame(width: 24, height: 24)
                    .shadow(color: GarageProTheme.glow.opacity(0.24), radius: 8)
                    .position(x: width * 0.65, y: centerY)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 38, weight: .black))
                    .foregroundStyle(GarageProTheme.accent)
                    .position(x: width * 0.64, y: centerY + 42)
            }
        }
    }
}

private struct GaragePuttingSetupDiagram: View {
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let centerY = height * 0.52

            ZStack {
                Rectangle()
                    .fill(GarageProTheme.accent.opacity(0.32))
                    .frame(width: width * 0.62, height: 3)
                    .position(x: width * 0.52, y: centerY)

                ForEach([0.42, 0.58], id: \.self) { xValue in
                    Capsule(style: .continuous)
                        .fill(GarageProTheme.textPrimary.opacity(0.78))
                        .frame(width: 8, height: 44)
                        .position(x: width * xValue, y: centerY - 28)
                }

                Circle()
                    .fill(GarageProTheme.textPrimary)
                    .frame(width: 22, height: 22)
                    .position(x: width * 0.24, y: centerY)

                Image(systemName: "circle.dashed")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(GarageProTheme.accent.opacity(0.7))
                    .position(x: width * 0.78, y: centerY)
            }
        }
    }
}

private struct GarageRangeSetupDiagram: View {
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(GarageProTheme.accent.opacity(0.74), style: StrokeStyle(lineWidth: 3, dash: [8, 7]))
                    .frame(width: width * 0.36, height: height * 0.34)
                    .position(x: width * 0.72, y: height * 0.38)

                Path { path in
                    path.move(to: CGPoint(x: width * 0.18, y: height * 0.78))
                    path.addLine(to: CGPoint(x: width * 0.72, y: height * 0.38))
                }
                .stroke(GarageProTheme.accent.opacity(0.5), style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [10, 8]))

                Circle()
                    .fill(GarageProTheme.textPrimary)
                    .frame(width: 24, height: 24)
                    .position(x: width * 0.18, y: height * 0.78)

                Image(systemName: "flag.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(GarageProTheme.accent)
                    .position(x: width * 0.72, y: height * 0.38)
            }
        }
    }
}

private struct GarageNetSetupDiagram: View {
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let laneY = height * 0.58

            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(GarageProTheme.textSecondary.opacity(0.34), lineWidth: 3)
                    .frame(width: width * 0.3, height: height * 0.48)
                    .position(x: width * 0.76, y: height * 0.44)

                Rectangle()
                    .fill(GarageProTheme.accent.opacity(0.32))
                    .frame(width: width * 0.48, height: 4)
                    .position(x: width * 0.45, y: laneY)

                Circle()
                    .fill(GarageProTheme.textPrimary)
                    .frame(width: 24, height: 24)
                    .position(x: width * 0.26, y: laneY)

                Image(systemName: "figure.golf")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(GarageProTheme.accent)
                    .position(x: width * 0.22, y: laneY + 42)
            }
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

private struct GarageFocusDrillFeedbackRow: View {
    let repTarget: String
    let objective: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label(repTarget, systemImage: "repeat")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(GarageProTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Spacer(minLength: 8)

                Text("Feedback Signal")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .textCase(.uppercase)
                    .tracking(1.4)
                    .foregroundStyle(GarageProTheme.accent)
            }

            Text(objective)
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
