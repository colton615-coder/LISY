import SwiftData
import SwiftUI

@main
struct LifeInSyncApp: App {
    private var sharedModelContainer: ModelContainer = {
        let schema = Schema([
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
            SwingRecord.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
