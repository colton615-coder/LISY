import Foundation
import SwiftData
import SwiftUI

@main
struct LifeInSyncApp: App {
    private var sharedModelContainer: ModelContainer = {
        let schema = Schema(LISYSchemaV4.models)
        let isRunningForPreviews = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isRunningForPreviews)

        do {
            if isRunningForPreviews {
                return try ModelContainer(for: schema, configurations: [configuration])
            }

            return try ModelContainer(for: schema, migrationPlan: LISYMigrationPlan.self, configurations: [configuration])
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
