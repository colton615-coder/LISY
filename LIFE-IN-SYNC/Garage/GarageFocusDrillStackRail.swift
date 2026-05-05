import SwiftUI

enum GarageFocusDrillRailStatus {
    case current
    case upcoming
    case completed

    var label: String {
        switch self {
        case .current:
            return GarageFocusRoomCopy.focusRoomRailCurrentLabel
        case .upcoming:
            return GarageFocusRoomCopy.focusRoomRailUpcomingLabel
        case .completed:
            return GarageFocusRoomCopy.focusRoomRailCompletedLabel
        }
    }
}

struct GarageFocusDrillRailItem: Identifiable {
    let id: UUID
    let index: Int
    let title: String
    let metadata: String
    let status: GarageFocusDrillRailStatus
    let isSelectable: Bool
}

struct GarageFocusDrillStackRail: View {
    let items: [GarageFocusDrillRailItem]
    let onSelectDrill: (Int) -> Void

    var body: some View {
        GarageProCard(cornerRadius: 22, padding: 14) {
            Text("Drill Stack")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .textCase(.uppercase)
                .tracking(1.8)
                .foregroundStyle(GarageProTheme.textSecondary)

            VStack(spacing: 8) {
                ForEach(items) { item in
                    if item.isSelectable {
                        Button {
                            onSelectDrill(item.index)
                        } label: {
                            GarageFocusDrillRailRow(item: item)
                        }
                        .buttonStyle(.plain)
                    } else {
                        GarageFocusDrillRailRow(item: item)
                    }
                }
            }
        }
    }
}

private struct GarageFocusDrillRailRow: View {
    let item: GarageFocusDrillRailItem

    var body: some View {
        HStack(spacing: 10) {
            Text("\(item.index + 1)")
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(GarageProTheme.accent)
                .frame(width: 28, height: 28)
                .background(GarageProTheme.insetSurface, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(GarageProTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if item.metadata.isEmpty == false {
                    Text(item.metadata)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(GarageProTheme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }

            Spacer(minLength: 8)

            Text(item.status.label)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .textCase(.uppercase)
                .tracking(1.6)
                .foregroundStyle(statusColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(GarageProTheme.insetSurface, in: Capsule(style: .continuous))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(statusColor.opacity(0.36), lineWidth: 1)
                )
        }
        .padding(10)
        .background(GarageProTheme.insetSurface.opacity(0.62), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(GarageProTheme.border, lineWidth: 1)
        )
    }

    private var statusColor: Color {
        switch item.status {
        case .current:
            return GarageProTheme.accent
        case .upcoming:
            return GarageProTheme.textSecondary
        case .completed:
            return Color(hex: "#10B981")
        }
    }
}
