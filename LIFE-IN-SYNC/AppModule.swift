import SwiftUI

enum AppModule: String, CaseIterable, Identifiable {
    case dashboard
    case capitalCore
    case ironTemple
    case garage
    case habitStack
    case taskProtocol
    case calendar
    case bibleStudy
    case supplyList

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard:
            "Dashboard"
        case .capitalCore:
            "Capital Core"
        case .ironTemple:
            "Iron Temple"
        case .garage:
            "Garage"
        case .habitStack:
            "Habit Stack"
        case .taskProtocol:
            "Task Protocol"
        case .calendar:
            "Calendar"
        case .bibleStudy:
            "Bible Study"
        case .supplyList:
            "Supply List"
        }
    }

    var navigationTitle: String {
        switch self {
        case .dashboard:
            "Life In Sync"
        default:
            title
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard:
            "house"
        case .capitalCore:
            "dollarsign.circle"
        case .ironTemple:
            "dumbbell"
        case .garage:
            "figure.golf"
        case .habitStack:
            "checklist"
        case .taskProtocol:
            "checkmark.circle"
        case .calendar:
            "calendar"
        case .bibleStudy:
            "book.closed"
        case .supplyList:
            "cart"
        }
    }

    var summary: String {
        switch self {
        case .dashboard:
            "Today overview and fast routing."
        case .capitalCore:
            "Track expenses, budgets, and current financial position."
        case .ironTemple:
            "Plan workouts and log sessions."
        case .garage:
            "Temporary shell for the next Garage direction."
        case .habitStack:
            "Manage recurring habits and streaks."
        case .taskProtocol:
            "Capture and complete one-time tasks."
        case .calendar:
            "Plan your day and upcoming events."
        case .bibleStudy:
            "Save passages, notes, and study history."
        case .supplyList:
            "Build shopping lists and track purchased items."
        }
    }

    var theme: ModuleTheme {
        switch self {
        case .dashboard:
            ModuleTheme(
                primary: .blue,
                secondary: .cyan,
                backgroundTop: .blue.opacity(0.18),
                backgroundBottom: .clear,
                accentText: .blue
            )
        case .capitalCore:
            ModuleTheme(
                primary: .green,
                secondary: .mint,
                backgroundTop: .green.opacity(0.18),
                backgroundBottom: .clear,
                accentText: .green
            )
        case .ironTemple:
            ModuleTheme(
                primary: .orange,
                secondary: .yellow,
                backgroundTop: .orange.opacity(0.18),
                backgroundBottom: .clear,
                accentText: .orange
            )
        case .garage:
            ModuleTheme(
                primary: ModuleTheme.electricCyan,
                secondary: ModuleTheme.electricCyan.opacity(0.78),
                backgroundTop: ModuleTheme.garageBackgroundLift,
                backgroundBottom: ModuleTheme.garageBackground,
                accentText: ModuleTheme.electricCyan,
                textPrimary: ModuleTheme.garageTextPrimary,
                textSecondary: ModuleTheme.garageTextSecondary,
                textMuted: ModuleTheme.garageTextMuted,
                surfaceBase: ModuleTheme.garageSurface,
                surfaceElevated: ModuleTheme.garageSurfaceRaised,
                glow: ModuleTheme.electricCyan,
                shadowLight: ModuleTheme.garageShadowLight,
                shadowDark: ModuleTheme.garageShadowDark
            )
        case .habitStack:
            ModuleTheme(
                primary: .indigo,
                secondary: .purple,
                backgroundTop: .indigo.opacity(0.2),
                backgroundBottom: .clear,
                accentText: .indigo
            )
        case .taskProtocol:
            ModuleTheme(
                primary: .teal,
                secondary: .cyan,
                backgroundTop: .teal.opacity(0.18),
                backgroundBottom: .clear,
                accentText: .teal
            )
        case .calendar:
            ModuleTheme(
                primary: .red,
                secondary: .pink,
                backgroundTop: .red.opacity(0.18),
                backgroundBottom: .clear,
                accentText: .red
            )
        case .bibleStudy:
            ModuleTheme(
                primary: .brown,
                secondary: .orange,
                backgroundTop: .brown.opacity(0.18),
                backgroundBottom: .clear,
                accentText: .brown
            )
        case .supplyList:
            ModuleTheme(
                primary: .pink,
                secondary: .red,
                backgroundTop: .pink.opacity(0.18),
                backgroundBottom: .clear,
                accentText: .pink
            )
        }
    }

    var tintColor: Color { theme.primary }
}
