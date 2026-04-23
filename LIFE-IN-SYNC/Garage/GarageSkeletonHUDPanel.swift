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
    var overlayStatus: GarageOverlayMetricStatus = .optimal
    var overlayMode: GarageOverlayMode = .clean
    var isModeToggleEnabled = false
    var onSelectMode: (GarageOverlayMode) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.white)
                        .lineLimit(2)

                    Text(detail)
                        .font(.system(.caption2, design: .rounded).weight(.semibold))
                        .foregroundStyle(overlayStatus.tint.opacity(overlayStatus == .insufficientData ? 0.86 : 0.96))
                        .lineLimit(2)
                }

                Spacer(minLength: 4)

                if isModeToggleEnabled {
                    modeToggle
                }
            }

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

    private var modeToggle: some View {
        HStack(spacing: 3) {
            ForEach(GarageOverlayMode.allCases) { mode in
                Button {
                    guard mode != overlayMode else { return }
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        onSelectMode(mode)
                    }
                    garageTriggerImpact(.light)
                } label: {
                    Text(mode.title)
                        .font(.system(.caption2, design: .rounded).weight(.bold))
                        .foregroundStyle(mode == overlayMode ? Color.white : Color.white.opacity(0.58))
                        .padding(.horizontal, 7)
                        .frame(minHeight: 22)
                        .background(
                            Capsule()
                                .fill(mode == overlayMode ? overlayStatus.tint.opacity(0.22) : Color.clear)
                                .overlay(
                                    Capsule()
                                        .stroke(
                                            mode == overlayMode ? overlayStatus.tint.opacity(0.42) : Color.white.opacity(0.08),
                                            lineWidth: 0.6
                                        )
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.black.opacity(0.28), in: Capsule())
    }

    @ViewBuilder
    private func severityRow(_ severity: GarageSkeletonHUDSeverity) -> some View {
        HStack(spacing: 6) {
            Image(systemName: severity.symbolName)
                .font(.system(.caption2, design: .rounded).weight(.semibold))

            Text(severity.label)
                .font(.system(.caption2, design: .rounded).weight(.semibold))
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
