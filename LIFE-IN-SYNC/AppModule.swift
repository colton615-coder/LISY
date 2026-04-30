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
        ModuleTheme.puttingGreen
    }

    var tintColor: Color { theme.primary }
}
