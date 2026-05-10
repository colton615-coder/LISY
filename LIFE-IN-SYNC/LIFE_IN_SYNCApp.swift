import Foundation
import SwiftData
import SwiftUI

@main
struct LifeInSyncApp: App {
    private var sharedModelContainer: ModelContainer = {
        let schema = Schema(LISYSchemaV8.models)
        let isRunningForPreviews = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        #if DEBUG
        let isRunningGarageAuthorityQA = ProcessInfo.processInfo.arguments.contains("GARAGE_DRILL_AUTHORITY_QA")
            || ProcessInfo.processInfo.arguments.contains("GARAGE_DRILL_AUTHORITY_QA_SUMMARY")
        #else
        let isRunningGarageAuthorityQA = false
        #endif
        let usesInMemoryStore = isRunningForPreviews || isRunningGarageAuthorityQA
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: usesInMemoryStore)

        do {
            if usesInMemoryStore {
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
