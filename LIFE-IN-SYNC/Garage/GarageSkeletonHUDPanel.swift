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
    var selectedLens: GarageOverlayLens = .posture
    var isModeToggleEnabled = false
    var onSelectMode: (GarageOverlayMode) -> Void = { _ in }
    var onSelectLens: (GarageOverlayLens) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(detail)
                        .font(.system(.caption2, design: .rounded).weight(.semibold))
                        .foregroundStyle(overlayStatus.tint.opacity(overlayStatus == .insufficientData ? 0.86 : 0.96))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }

                Spacer(minLength: 4)

                if isModeToggleEnabled {
                    modeToggle
                }
            }

            if overlayMode == .pro {
                lensPicker
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
                                .fill(mode == overlayMode ? garageReviewAccent.opacity(0.20) : Color.clear)
                                .overlay(
                                    Capsule()
                                        .stroke(
                                            mode == overlayMode ? garageReviewAccent.opacity(0.42) : Color.white.opacity(0.08),
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

    private var lensPicker: some View {
        HStack(spacing: 6) {
            ForEach(GarageOverlayLens.allCases) { lens in
                Button {
                    guard lens != selectedLens else { return }
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        onSelectLens(lens)
                    }
                    garageTriggerImpact(.light)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: lens.symbolName)
                            .font(.system(size: 11, weight: .semibold))
                        Text(lens.title)
                            .font(.system(.caption2, design: .rounded).weight(.semibold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(lens == selectedLens ? Color.white : Color.white.opacity(0.5))
                    .padding(.horizontal, 8)
                    .frame(minHeight: 26)
                    .background(
                        Capsule(style: .continuous)
                            .fill(lens == selectedLens ? Color.white.opacity(0.14) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
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
