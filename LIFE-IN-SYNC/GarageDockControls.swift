import SwiftUI

struct GarageDockSurface<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 12) {
            content
        }
        .padding(.horizontal, ModuleSpacing.large)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .background(
            GarageRaisedPanelBackground(
                shape: RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous),
                fill: garageReviewSurface
            )
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(garageReviewStroke.opacity(0.92))
                    .frame(height: 1)
            }
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [garageReviewShadowLight.opacity(0.22), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 20)
                .clipShape(RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous))
            }
            .ignoresSafeArea(edges: .bottom)
        )
    }
}

struct GarageDockWideButton: View {
    let title: String
    let systemImage: String
    let isPrimary: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button {
            guard isEnabled else { return }
            garageTriggerImpact(isPrimary ? .medium : .light)
            action()
        } label: {
            HStack(spacing: 12) {
                iconCapsule

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)
            }
            .foregroundStyle(foregroundStyle)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
            .background(buttonBackground)
        }
        .buttonStyle(.plain)
        .disabled(isEnabled == false)
    }

    private var foregroundStyle: Color {
        if isEnabled == false {
            return isPrimary ? garageReviewReadableText.opacity(0.78) : garageReviewMutedText.opacity(0.92)
        }

        return isPrimary ? garageReviewCanvasFill : garageReviewReadableText
    }

    private var iconForegroundStyle: Color {
        if isEnabled == false {
            return isPrimary ? garageReviewReadableText.opacity(0.68) : garageReviewMutedText.opacity(0.82)
        }

        return isPrimary ? garageReviewCanvasFill : garageReviewReadableText
    }

    private var iconCapsuleFill: Color {
        if isPrimary {
            return isEnabled ? garageReviewCanvasFill.opacity(0.16) : garageReviewSurfaceRaised.opacity(0.96)
        }

        return isEnabled ? garageReviewSurfaceDark.opacity(0.92) : garageReviewSurfaceDark.opacity(0.98)
    }

    private var iconCapsuleStroke: Color {
        if isPrimary {
            return isEnabled ? garageReviewCanvasFill.opacity(0.22) : garageReviewStroke.opacity(0.55)
        }

        return isEnabled ? garageReviewStroke.opacity(0.95) : garageReviewStroke.opacity(0.7)
    }

    private var iconCapsule: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(iconCapsuleFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(iconCapsuleStroke, lineWidth: 0.9)
                )

            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(iconForegroundStyle)
        }
        .frame(width: 40, height: 40)
        .shadow(
            color: isPrimary && isEnabled ? garageReviewAccent.opacity(0.16) : garageReviewShadowDark.opacity(isEnabled ? 0.18 : 0.1),
            radius: isPrimary && isEnabled ? 8 : 6,
            x: 0,
            y: 4
        )
    }

    @ViewBuilder
    private var buttonBackground: some View {
        GarageRaisedPanelBackground(
            shape: RoundedRectangle(cornerRadius: 20, style: .continuous),
            fill: buttonFill,
            stroke: buttonStroke,
            glow: isPrimary && isEnabled ? garageReviewAccent : nil
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(isEnabled ? 0.05 : 0.03), lineWidth: 0.5)
        }
    }

    private var buttonFill: Color {
        if isPrimary {
            return isEnabled ? garageReviewAccent : garageReviewAccent.opacity(0.34)
        }

        return isEnabled ? garageReviewSurfaceRaised : garageReviewSurfaceDark.opacity(0.98)
    }

    private var buttonStroke: Color {
        if isPrimary {
            return isEnabled ? garageReviewAccent.opacity(0.38) : garageReviewAccent.opacity(0.16)
        }

        return garageReviewStroke.opacity(isEnabled ? 0.98 : 0.68)
    }
}

private struct GarageDockControlsPreviewSurface: View {
    var body: some View {
        VStack(spacing: 20) {
            GarageDockSurface {
                GarageDockWideButton(
                    title: "Review Hand Path",
                    systemImage: "play.fill",
                    isPrimary: true,
                    isEnabled: true,
                    action: {}
                )

                GarageDockWideButton(
                    title: "Review SyncFlow",
                    systemImage: "figure.walk",
                    isPrimary: false,
                    isEnabled: true,
                    action: {}
                )
            }

            GarageDockSurface {
                GarageDockWideButton(
                    title: "Slow Motion Review Unavailable",
                    systemImage: "exclamationmark.triangle.fill",
                    isPrimary: true,
                    isEnabled: false,
                    action: {}
                )

                GarageDockWideButton(
                    title: "Recheck Frames",
                    systemImage: "arrow.counterclockwise",
                    isPrimary: false,
                    isEnabled: true,
                    action: {}
                )
            }
        }
        .padding()
        .background(garageReviewBackground.ignoresSafeArea())
    }
}

#Preview("Garage Dock Controls") {
    PreviewScreenContainer {
        GarageDockControlsPreviewSurface()
    }
    .preferredColorScheme(.dark)
}
