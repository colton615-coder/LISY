import SwiftData
import SwiftUI

@main
struct LifeInSyncApp: App {
    private var sharedModelContainer: ModelContainer = {
        let configuration = ModelConfiguration(schema: LISYPersistence.schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(
                for: LISYPersistence.schema,
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
