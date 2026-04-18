import SwiftData
import SwiftUI

@main
struct LifeInSyncApp: App {
    private var sharedModelContainer: ModelContainer = {
        let schema = Schema(LISYSchemaV2.models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: LISYMigrationPlan.self,
                configurations: [configuration]
            )
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
