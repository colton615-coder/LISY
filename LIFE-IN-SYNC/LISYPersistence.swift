import SwiftData

/// Centralized model list so app, previews, and future persistence helpers share one schema source of truth.
enum LISYModelRegistry {
    static let models: [any PersistentModel.Type] = [
        CompletionRecord.self,
        TagRecord.self,
        NoteRecord.self,
        Habit.self,
        HabitEntry.self,
        TaskItem.self,
        CalendarEvent.self,
        SupplyItem.self,
        ExpenseRecord.self,
        BudgetRecord.self,
        WorkoutTemplate.self,
        WorkoutSession.self,
        StudyEntry.self,
        SwingRecord.self,
        GarageRoundSession.self,
        GarageHoleMap.self,
        GarageTacticalShot.self
    ]
}

enum LISYPersistence {
    static let schema = Schema(LISYModelRegistry.models)
}
