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

    static let rootBackground = Color(hex: "#2D7A3E")
    static let elevatedSurface = Color(hex: "#236331")
    static let divider = Color.white.opacity(0.25)
    static let secondaryText = Color(hex: "#A1E4B5")
    static let accent = Color(hex: "#FDE047")
    static let primaryText = Color.white

    static let mediaBlack = Color.black
    static let mediaOverlay = Color.black.opacity(0.82)

    static let puttingGreen = ModuleTheme(
        primary: ModuleTheme.accent,
        secondary: ModuleTheme.accent.opacity(0.78),
        backgroundTop: ModuleTheme.rootBackground,
        backgroundBottom: ModuleTheme.rootBackground,
        accentText: ModuleTheme.accent,
        textPrimary: ModuleTheme.primaryText,
        textSecondary: ModuleTheme.secondaryText,
        textMuted: ModuleTheme.secondaryText.opacity(0.88),
        surfaceBase: ModuleTheme.elevatedSurface,
        surfaceElevated: ModuleTheme.elevatedSurface,
        glow: ModuleTheme.accent,
        shadowLight: Color.white.opacity(0.08),
        shadowDark: Color.black.opacity(0.18)
    )

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

    static let electricCyan = accent
    static let garageBackground = rootBackground
    static let garageBackgroundLift = elevatedSurface
    static let garageSurface = elevatedSurface
    static let garageSurfaceRaised = elevatedSurface
    static let garageSurfaceInset = elevatedSurface
    static let garageSurfaceDark = elevatedSurface
    static let garageCanvas = mediaBlack
    static let garageTrack = elevatedSurface
    static let garageTextPrimary = primaryText
    static let garageTextSecondary = secondaryText
    static let garageTextMuted = secondaryText.opacity(0.88)
    static let garageShadowLight = Color.white.opacity(0.08)
    static let garageShadowDark = Color.black.opacity(0.18)

    var heroGradient: LinearGradient {
        LinearGradient(
            colors: [backgroundTop, backgroundBottom],
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
        ModuleTheme.elevatedSurface
    }

    var surfaceSecondary: Color {
        surfaceBaseOverride ?? ModuleTheme.elevatedSurface
    }

    var surfaceInteractive: Color {
        surfaceElevatedOverride ?? ModuleTheme.elevatedSurface
    }

    var borderSubtle: Color {
        ModuleTheme.divider
    }

    var borderStrong: Color {
        ModuleTheme.divider
    }

    var textPrimary: Color {
        textPrimaryOverride ?? ModuleTheme.primaryText
    }

    var textSecondary: Color {
        textSecondaryOverride ?? ModuleTheme.secondaryText
    }

    var textMuted: Color {
        textMutedOverride ?? ModuleTheme.secondaryText.opacity(0.88)
    }

    var electricGlow: Color {
        glowOverride ?? ModuleTheme.accent
    }

    var shadowLight: Color {
        shadowLightOverride ?? Color.white.opacity(0.08)
    }

    var shadowDark: Color {
        shadowDarkOverride ?? Color.black.opacity(0.18)
    }
}
