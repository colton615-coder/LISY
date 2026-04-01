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
}
