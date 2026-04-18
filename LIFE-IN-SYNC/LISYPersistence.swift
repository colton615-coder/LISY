import SwiftData

/// Centralized model list so schema versions stay aligned for non-breaking model additions.
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
        SwingRecord.self
    ]
}

enum LISYSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version = .init(1, 0, 0)
    static var models: [any PersistentModel.Type] { LISYModelRegistry.models }
}

enum LISYSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version = .init(2, 0, 0)
    static var models: [any PersistentModel.Type] { LISYModelRegistry.models }
}

enum LISYMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [LISYSchemaV1.self, LISYSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [
            .custom(
                fromVersion: LISYSchemaV1.self,
                toVersion: LISYSchemaV2.self,
                willMigrate: { _ in },
                didMigrate: { context in
                    let records = try context.fetch(FetchDescriptor<SwingRecord>())
                    for record in records where record.decodedDerivedPayload == nil {
                        if let legacyPayload = record.legacyDerivedPayloadFallback {
                            record.persistDerivedPayload(legacyPayload)
                        } else if record.repairReason == nil {
                            record.clearDerivedPayload(repairReason: .missingDerivedPayload)
                        }
                    }

                    if context.hasChanges {
                        try context.save()
                    }
                }
            )
        ]
    }
}
