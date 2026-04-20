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
}

func garageTriggerImpact(_ weight: GarageImpactWeight) {
    let style: UIImpactFeedbackGenerator.FeedbackStyle
    switch weight {
    case .light:
        style = .light
    case .medium:
        style = .medium
    }

    let generator = UIImpactFeedbackGenerator(style: style)
    generator.prepare()
    generator.impactOccurred()
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
