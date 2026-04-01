import Foundation
import SwiftData

@Model
final class CompletionRecord {
    var completedAt: Date
    var sourceModuleID: String

    init(completedAt: Date = .now, sourceModuleID: String) {
        self.completedAt = completedAt
        self.sourceModuleID = sourceModuleID
    }
}

@Model
final class TagRecord {
    var name: String

    init(name: String) {
        self.name = name
    }
}

@Model
final class NoteRecord {
    var body: String
    var createdAt: Date

    init(body: String, createdAt: Date = .now) {
        self.body = body
        self.createdAt = createdAt
    }
}

@Model
final class Habit {
    var id: UUID
    var name: String
    var targetCount: Int
    var createdAt: Date

    init(id: UUID = UUID(), name: String, targetCount: Int = 1, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.targetCount = targetCount
        self.createdAt = createdAt
    }
}

@Model
final class HabitEntry {
    var habitID: UUID
    var habitName: String
    var count: Int
    var loggedAt: Date

    init(habitID: UUID, habitName: String, count: Int = 1, loggedAt: Date = .now) {
        self.habitID = habitID
        self.habitName = habitName
        self.count = count
        self.loggedAt = loggedAt
    }
}

@Model
final class TaskItem {
    var id: UUID
    var title: String
    var priority: String
    var dueDate: Date?
    var isCompleted: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        priority: String = TaskPriority.medium.rawValue,
        dueDate: Date? = nil,
        isCompleted: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.priority = priority
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.createdAt = createdAt
    }
}

@Model
final class CalendarEvent {
    var title: String
    var startDate: Date
    var endDate: Date

    init(title: String, startDate: Date, endDate: Date) {
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
    }
}

@Model
final class SupplyItem {
    var title: String
    var category: String
    var isPurchased: Bool

    init(title: String, category: String = "General", isPurchased: Bool = false) {
        self.title = title
        self.category = category
        self.isPurchased = isPurchased
    }
}

@Model
final class ExpenseRecord {
    var title: String
    var amount: Double
    var category: String
    var recordedAt: Date

    init(title: String, amount: Double, category: String, recordedAt: Date = .now) {
        self.title = title
        self.amount = amount
        self.category = category
        self.recordedAt = recordedAt
    }
}

@Model
final class BudgetRecord {
    var title: String
    var limitAmount: Double
    var periodLabel: String

    init(title: String, limitAmount: Double, periodLabel: String = "Monthly") {
        self.title = title
        self.limitAmount = limitAmount
        self.periodLabel = periodLabel
    }
}

@Model
final class WorkoutTemplate {
    var name: String
    var createdAt: Date

    init(name: String, createdAt: Date = .now) {
        self.name = name
        self.createdAt = createdAt
    }
}

@Model
final class WorkoutSession {
    var templateName: String
    var performedAt: Date
    var durationMinutes: Int

    init(templateName: String, performedAt: Date = .now, durationMinutes: Int = 0) {
        self.templateName = templateName
        self.performedAt = performedAt
        self.durationMinutes = durationMinutes
    }
}

@Model
final class StudyEntry {
    var title: String
    var passageReference: String
    var notes: String
    var createdAt: Date

    init(title: String, passageReference: String, notes: String = "", createdAt: Date = .now) {
        self.title = title
        self.passageReference = passageReference
        self.notes = notes
        self.createdAt = createdAt
    }
}

@Model
final class SwingRecord {
    var title: String
    var createdAt: Date
    var mediaFilename: String?
    var notes: String

    init(title: String, createdAt: Date = .now, mediaFilename: String? = nil, notes: String = "") {
        self.title = title
        self.createdAt = createdAt
        self.mediaFilename = mediaFilename
        self.notes = notes
    }
}
