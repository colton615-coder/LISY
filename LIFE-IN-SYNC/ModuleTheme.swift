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

    static let electricCyan = Color(hex: "#00F5FF")
    static let garageBackground = Color(hex: "#151B22")
    static let garageBackgroundLift = Color(hex: "#1B232D")
    static let garageSurface = Color(hex: "#222A34")
    static let garageSurfaceRaised = Color(hex: "#2A3441")
    static let garageSurfaceInset = Color(hex: "#101821")
    static let garageSurfaceDark = Color(hex: "#0B1118")
    static let garageCanvas = Color(hex: "#0D141B")
    static let garageTrack = Color(hex: "#17202A")
    static let garageTextPrimary = Color(hex: "#F2FAFF")
    static let garageTextSecondary = Color(hex: "#A7B7C7")
    static let garageTextMuted = Color(hex: "#8092A4")
    static let garageShadowLight = Color.white.opacity(0.06)
    static let garageShadowDark = Color.black.opacity(0.42)

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
