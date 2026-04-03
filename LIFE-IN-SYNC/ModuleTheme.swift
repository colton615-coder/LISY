import SwiftUI

struct ModuleTheme {
    let primary: Color
    let secondary: Color
    let backgroundTop: Color
    let backgroundBottom: Color
    let accentText: Color

    var heroGradient: LinearGradient {
        LinearGradient(
            colors: [primary.opacity(0.30), secondary.opacity(0.18)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var screenGradient: LinearGradient {
        LinearGradient(
            colors: [canvasTop, backgroundTop.opacity(0.78), canvasBase],
            startPoint: .topLeading,
            endPoint: .bottom
        )
    }

    var chipBackground: Color {
        primary.opacity(0.14)
    }

    var canvasBase: Color {
        Color(red: 0.02, green: 0.06, blue: 0.11)
    }

    var canvasTop: Color {
        Color(red: 0.06, green: 0.16, blue: 0.28)
    }

    var surfacePrimary: Color {
        Color.white.opacity(0.11)
    }

    var surfaceSecondary: Color {
        Color.white.opacity(0.07)
    }

    var surfaceInteractive: Color {
        Color.white.opacity(0.15)
    }

    var borderSubtle: Color {
        Color.white.opacity(0.08)
    }

    var borderStrong: Color {
        primary.opacity(0.24)
    }

    var textPrimary: Color {
        Color.white.opacity(0.96)
    }

    var textSecondary: Color {
        Color.white.opacity(0.68)
    }

    var textMuted: Color {
        Color.white.opacity(0.46)
    }

    var accent: Color {
        primary
    }

    var accentSoft: Color {
        primary.opacity(0.16)
    }

    var accentGlow: Color {
        secondary.opacity(0.22)
    }

    var progressTrack: Color {
        Color.white.opacity(0.10)
    }
}
