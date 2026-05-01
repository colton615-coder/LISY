import SwiftUI
import UIKit

let garageReviewBackground = ModuleTheme.garageBackground
let garageReviewSurface = ModuleTheme.garageSurface
let garageReviewSurfaceRaised = ModuleTheme.garageSurfaceRaised
let garageReviewSurfaceDark = ModuleTheme.garageSurfaceDark
let garageReviewInsetSurface = ModuleTheme.garageSurfaceInset
let garageReviewCanvasFill = ModuleTheme.garageCanvas
let garageReviewTrackFill = ModuleTheme.garageTrack
let garageReviewAccent = AppModule.garage.theme.primary
let garageManualAnchorAccent = ModuleTheme.electricCyan
let garageReviewReadableText = ModuleTheme.garageTextPrimary
let garageReviewMutedText = ModuleTheme.garageTextMuted
let garageReviewApproved = Color(red: 0.33, green: 0.79, blue: 0.53)
let garageReviewPending = Color.orange
let garageReviewFlagged = Color(red: 0.94, green: 0.38, blue: 0.40)
let garageReviewStroke = Color.white.opacity(0.05)
let garageReviewShadowLight = AppModule.garage.theme.shadowLight
let garageReviewShadowDark = AppModule.garage.theme.shadowDark
let garageReviewShadow = garageReviewShadowDark.opacity(0.5)

struct GarageRaisedPanelBackground<S: Shape>: View {
    let shape: S
    var fill: Color = garageReviewSurface
    var stroke: Color = garageReviewStroke
    var glow: Color?

    init(
        shape: S,
        fill: Color = garageReviewSurface,
        stroke: Color = garageReviewStroke,
        glow: Color? = nil
    ) {
        self.shape = shape
        self.fill = fill
        self.stroke = stroke
        self.glow = glow
    }

    var body: some View {
        shape
            .fill(fill)
            .overlay(
                shape
                    .stroke(stroke, lineWidth: 0.5)
            )
            .overlay(
                shape
                    .stroke(
                        (glow ?? .clear).opacity(glow == nil ? 0 : 0.55),
                        lineWidth: glow == nil ? 0 : 0.5
                    )
            )
            .shadow(color: garageReviewShadowDark.opacity(0.68), radius: 10, x: 0, y: 8)
            .shadow(color: (glow ?? .clear).opacity(glow == nil ? 0 : 0.12), radius: glow == nil ? 0 : 10, x: 0, y: 0)
    }
}

struct GarageInsetPanelBackground<S: Shape>: View {
    let shape: S
    var fill: Color = garageReviewInsetSurface
    var stroke: Color = garageReviewStroke

    var body: some View {
        shape
            .fill(fill)
            .overlay(
                shape
                    .stroke(stroke, lineWidth: 0.5)
            )
            .overlay(
                shape
                    .stroke(garageReviewShadowLight.opacity(0.35), lineWidth: 0.5)
                    .blur(radius: 1)
                    .mask(shape.fill(LinearGradient(colors: [.white, .clear], startPoint: .topLeading, endPoint: .bottomTrailing)))
            )
            .shadow(color: garageReviewShadowDark.opacity(0.44), radius: 8, x: 0, y: 6)
    }
}

enum GarageImpactWeight {
    case light
    case medium
    case heavy
}

func garageTriggerImpact(_ weight: GarageImpactWeight) {
    let style: UIImpactFeedbackGenerator.FeedbackStyle
    switch weight {
    case .light:
        style = .light
    case .medium:
        style = .medium
    case .heavy:
        style = .heavy
    }

    let generator = UIImpactFeedbackGenerator(style: style)
    generator.prepare()
    generator.impactOccurred()
}

func garageTriggerSelection() {
    let generator = UISelectionFeedbackGenerator()
    generator.prepare()
    generator.selectionChanged()
}

enum GarageProTheme {
    static let background = ModuleTheme.garageBackground
    static let surface = ModuleTheme.garageSurface.opacity(0.76)
    static let elevatedSurface = ModuleTheme.garageSurfaceRaised.opacity(0.9)
    static let insetSurface = ModuleTheme.garageSurfaceInset.opacity(0.86)
    static let accent = AppModule.garage.tintColor
    static let glow = AppModule.garage.theme.tintedShadow
    static let textPrimary = AppModule.garage.theme.textPrimary
    static let textSecondary = AppModule.garage.theme.textSecondary
    static let border = Color.white.opacity(0.08)
    static let darkShadow = Color.black.opacity(0.28)
}

struct GarageProScaffold<Content: View>: View {
    var bottomPadding: CGFloat = 96
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            GarageProTheme.background
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    ModuleTheme.garageBackgroundLift.opacity(0.96),
                    ModuleTheme.garageBackground.opacity(0.98),
                    ModuleTheme.garageSurfaceDark.opacity(0.92)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, bottomPadding)
            }
            .scrollIndicators(.hidden)
        }
        .tint(GarageProTheme.accent)
    }
}

struct GarageProCard<Content: View>: View {
    var isActive = false
    var cornerRadius: CGFloat = 24
    var padding: CGFloat = 18
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(padding)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(isActive ? GarageProTheme.elevatedSurface : GarageProTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(isActive ? GarageProTheme.accent.opacity(0.34) : GarageProTheme.border, lineWidth: 1)
        )
        .shadow(color: GarageProTheme.darkShadow, radius: 18, x: 0, y: 12)
        .shadow(color: isActive ? GarageProTheme.glow.opacity(0.22) : .clear, radius: 18, x: 0, y: 0)
    }
}

struct GarageProHeroCard<Trailing: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let value: String?
    let valueLabel: String?
    @ViewBuilder let trailing: Trailing

    init(
        eyebrow: String,
        title: String,
        subtitle: String,
        value: String? = nil,
        valueLabel: String? = nil,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.value = value
        self.valueLabel = valueLabel
        self.trailing = trailing()
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(
                colors: [
                    ModuleTheme.garageTurfSurface.opacity(0.98),
                    ModuleTheme.garageTurfBackground.opacity(0.96),
                    GarageProTheme.accent.opacity(0.68)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 14) {
                Text(eyebrow)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .textCase(.uppercase)
                    .tracking(2.4)
                    .foregroundStyle(GarageProTheme.accent.opacity(0.88))

                Text(title)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(GarageProTheme.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)

                if let value {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(value)
                            .font(.system(size: 48, weight: .black, design: .monospaced))
                            .foregroundStyle(GarageProTheme.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.62)

                        if let valueLabel {
                            Text(valueLabel)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .textCase(.uppercase)
                                .tracking(2.2)
                                .foregroundStyle(GarageProTheme.textPrimary.opacity(0.66))
                        }
                    }
                }

                Text(subtitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(GarageProTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)

            trailing
                .padding(18)
        }
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: GarageProTheme.glow.opacity(0.28), radius: 22, x: 0, y: 16)
        .shadow(color: GarageProTheme.darkShadow, radius: 20, x: 0, y: 14)
    }
}

struct GarageProMetricCard: View {
    let title: String
    let value: String
    var systemImage: String = "chart.bar.fill"
    var isActive = false

    var body: some View {
        GarageProCard(isActive: isActive, cornerRadius: 22, padding: 16) {
            HStack(alignment: .top) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(GarageProTheme.accent)
                    .frame(width: 44, height: 44)
                    .background(GarageProTheme.accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                Spacer(minLength: 8)
            }

            Text(value)
                .font(.system(size: 32, weight: .black, design: .monospaced))
                .tracking(-0.6)
                .foregroundStyle(GarageProTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.66)

            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .textCase(.uppercase)
                .tracking(1.8)
                .foregroundStyle(GarageProTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

struct GarageProPrimaryButton: View {
    let title: String
    let systemImage: String
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button {
            guard isEnabled else { return }
            garageTriggerImpact(.heavy)
            action()
        } label: {
            Label(title, systemImage: systemImage)
                .font(.headline.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .foregroundStyle(ModuleTheme.garageSurfaceDark)
                .padding(.horizontal, 20)
                .frame(minWidth: 60, minHeight: 60)
                .background(
                    LinearGradient(
                        colors: [
                            GarageProTheme.accent,
                            GarageProTheme.accent.opacity(0.76)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.5)
        .grayscale(isEnabled ? 0 : 0.45)
        .shadow(color: GarageProTheme.glow.opacity(isEnabled ? 0.34 : 0), radius: 18, x: 0, y: 12)
        .disabled(isEnabled == false)
    }
}

struct GarageProSegmentedSelector<Option: Identifiable & Hashable, Label: View>: View {
    let options: [Option]
    @Binding var selection: Option
    @ViewBuilder let label: (Option, Bool) -> Label

    var body: some View {
        HStack(spacing: 10) {
            ForEach(options) { option in
                let selected = option == selection
                Button {
                    guard selection != option else { return }
                    garageTriggerSelection()
                    selection = option
                } label: {
                    label(option, selected)
                        .frame(maxWidth: .infinity, minHeight: 60)
                        .padding(.horizontal, 10)
                        .background(selected ? GarageProTheme.accent.opacity(0.18) : GarageProTheme.insetSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(selected ? GarageProTheme.accent.opacity(0.42) : GarageProTheme.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

func garageFormattedPlaybackTime(_ time: Double) -> String {
    let totalSeconds = Int(max(time.rounded(), 0))
    let seconds = totalSeconds % 60
    let minutes = (totalSeconds / 60) % 60
    let hours = totalSeconds / 3600

    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }

    return String(format: "%02d:%02d", minutes, seconds)
}

extension GarageMetricGrade {
    var tint: Color {
        switch self {
        case .excellent:
            Color(red: 0.31, green: 0.78, blue: 0.53)
        case .good:
            Color(red: 0.37, green: 0.72, blue: 0.93)
        case .fair:
            Color(red: 0.89, green: 0.71, blue: 0.32)
        case .needsWork:
            Color(red: 0.86, green: 0.44, blue: 0.44)
        }
    }
}
