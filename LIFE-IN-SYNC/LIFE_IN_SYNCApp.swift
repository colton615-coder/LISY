import SwiftData
import SwiftUI

@main
struct LifeInSyncApp: App {
    private var sharedModelContainer: ModelContainer = {
<<<<<<< ours
        let configuration = ModelConfiguration(schema: LISYPersistence.schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(
                for: LISYPersistence.schema,
=======
        let schema = Schema(LISYSchemaV2.models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(
                for: LISYSchemaV2.self,
                migrationPlan: LISYMigrationPlan.self,
>>>>>>> theirs
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
