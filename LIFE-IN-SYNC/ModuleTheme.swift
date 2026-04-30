import SwiftUI

struct ModuleTheme {
    let primary: Color
    let secondary: Color
    let backgroundTop: Color
    let backgroundBottom: Color
    let accentText: Color
    private let textPrimaryOverride: Color?
    private let textSecondaryOverride: Color?
    private let textMutedOverride: Color?
    private let surfaceBaseOverride: Color?
    private let surfaceElevatedOverride: Color?
    private let glowOverride: Color?
    private let shadowLightOverride: Color?
    private let shadowDarkOverride: Color?

    init(
        primary: Color,
        secondary: Color,
        backgroundTop: Color,
        backgroundBottom: Color,
        accentText: Color,
        textPrimary: Color? = nil,
        textSecondary: Color? = nil,
        textMuted: Color? = nil,
        surfaceBase: Color? = nil,
        surfaceElevated: Color? = nil,
        glow: Color? = nil,
        shadowLight: Color? = nil,
        shadowDark: Color? = nil
    ) {
        self.primary = primary
        self.secondary = secondary
        self.backgroundTop = backgroundTop
        self.backgroundBottom = backgroundBottom
        self.accentText = accentText
        self.textPrimaryOverride = textPrimary
        self.textSecondaryOverride = textSecondary
        self.textMutedOverride = textMuted
        self.surfaceBaseOverride = surfaceBase
        self.surfaceElevatedOverride = surfaceElevated
        self.glowOverride = glow
        self.shadowLightOverride = shadowLight
        self.shadowDarkOverride = shadowDark
    }

    static let garageAccent = Color(hex: "#FDE047")
    static let garageTurfBackground = Color(hex: "#2D7A3E")
    static let garageTurfSurface = Color(hex: "#236331")
    static let garageDivider = Color.white.opacity(0.25)
    static let garageSupportText = Color(hex: "#A1E4B5")

    static let electricCyan = garageAccent
    static let garageBackground = garageTurfBackground
    static let garageBackgroundLift = garageTurfSurface
    static let garageSurface = garageTurfSurface
    static let garageSurfaceRaised = garageTurfSurface
    static let garageSurfaceInset = garageTurfSurface
    static let garageSurfaceDark = garageTurfSurface
    static let garageCanvas = Color(hex: "#0D141B")
    static let garageTrack = garageTurfSurface
    static let garageTextPrimary = Color.white
    static let garageTextSecondary = garageSupportText
    static let garageTextMuted = garageSupportText.opacity(0.88)
    static let garageShadowLight = Color.white.opacity(0.08)
    static let garageShadowDark = Color.black.opacity(0.18)

    var heroGradient: LinearGradient {
        LinearGradient(
            colors: [primary.opacity(0.32), secondary.opacity(0.18)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var screenGradient: LinearGradient {
        LinearGradient(
            colors: [backgroundTop, backgroundBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var chipBackground: Color {
        primary.opacity(0.14)
    }

    var surfaceSecondary: Color {
        surfaceBaseOverride ?? primary.opacity(0.08)
    }

    var surfaceInteractive: Color {
        surfaceElevatedOverride ?? primary.opacity(0.14)
    }

    var borderSubtle: Color {
        primary.opacity(0.18)
    }

    var borderStrong: Color {
        primary.opacity(0.4)
    }

    var textPrimary: Color {
        textPrimaryOverride ?? .primary
    }

    var textSecondary: Color {
        textSecondaryOverride ?? .secondary
    }

    var textMuted: Color {
        textMutedOverride ?? .secondary.opacity(0.85)
    }

    var electricGlow: Color {
        glowOverride ?? primary
    }

    var shadowLight: Color {
        shadowLightOverride ?? Color.white.opacity(0.04)
    }

    var shadowDark: Color {
        shadowDarkOverride ?? Color.black.opacity(0.25)
    }
}
