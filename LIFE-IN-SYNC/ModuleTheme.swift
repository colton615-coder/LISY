import SwiftUI

struct ModuleTheme {
    let primary: Color
    let secondary: Color
    let backgroundTop: Color
    let backgroundBottom: Color
    let accentText: Color

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
        primary.opacity(0.08)
    }

    var surfaceInteractive: Color {
        primary.opacity(0.14)
    }

    var borderSubtle: Color {
        primary.opacity(0.18)
    }

    var borderStrong: Color {
        primary.opacity(0.4)
    }

    var textPrimary: Color {
        .primary
    }

    var textSecondary: Color {
        .secondary
    }

    var textMuted: Color {
        .secondary.opacity(0.85)
    }
}
