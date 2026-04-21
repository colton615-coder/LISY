import SwiftUI

enum GarageSkeletonHUDSeverity: Equatable {
    case neutral(String)
    case warning(String)
    case critical(String)

    var label: String {
        switch self {
        case .neutral(let label), .warning(let label), .critical(let label):
            label
        }
    }

    var symbolName: String {
        switch self {
        case .neutral:
            "exclamationmark.circle.fill"
        case .warning, .critical:
            "exclamationmark.triangle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .neutral:
            Color.white.opacity(0.72)
        case .warning:
            Color.orange.opacity(0.94)
        case .critical:
            Color.red.opacity(0.96)
        }
    }
}

struct GarageSkeletonHUDPanel: View {
    let title: String
    let detail: String
    let severity: GarageSkeletonHUDSeverity?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.white)
                .lineLimit(2)

            Text(detail)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Color.white.opacity(0.82))
                .lineLimit(2)

            if let severity {
                severityRow(severity)
                    .transition(.opacity)
            }
        }
        .dynamicTypeSize(.xSmall ... .medium)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(panelBackground)
        .shadow(color: Color.black.opacity(0.34), radius: 16, x: 0, y: 10)
    }

    @ViewBuilder
    private func severityRow(_ severity: GarageSkeletonHUDSeverity) -> some View {
        HStack(spacing: 6) {
            Image(systemName: severity.symbolName)
                .font(.caption2.weight(.semibold))

            Text(severity.label)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .foregroundStyle(severity.tint)
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.vibeSurface.opacity(0.26))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 0.75)
            }
    }
}

#Preview {
    ZStack(alignment: .bottomLeading) {
        Color.vibeBackground
            .ignoresSafeArea()

        GarageSkeletonHUDPanel(
            title: "Energy leak: pelvis moved in",
            detail: "Pelvic depth drifted toward the ball late in the swing. That narrows space through impact.",
            severity: .critical("Strike consistency risk")
        )
        .padding(16)
    }
}
