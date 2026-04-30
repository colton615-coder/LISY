import SwiftData

/// Centralized model list so app, previews, migrations, and persistence helpers share one schema source of truth.
enum LISYModelRegistry {
    static let legacySharedModels: [any PersistentModel.Type] = [
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
    static let v3Models: [any PersistentModel.Type] = legacySharedModels + [
        PracticeSessionRecord.self
    ]
    static let v4Models: [any PersistentModel.Type] = v3Models + [
        PracticeDrillDefinition.self,
        PracticeTemplate.self
    ]
    static let currentModels: [any PersistentModel.Type] = v4Models
}

enum LISYSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version = .init(1, 0, 0)
    static var models: [any PersistentModel.Type] { LISYModelRegistry.legacySharedModels }
}

enum LISYSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version = .init(2, 0, 0)
    static var models: [any PersistentModel.Type] { LISYModelRegistry.legacySharedModels }
}

enum LISYSchemaV3: VersionedSchema {
    static var versionIdentifier: Schema.Version = .init(3, 0, 0)
    static var models: [any PersistentModel.Type] { LISYModelRegistry.v3Models }
}

enum LISYSchemaV4: VersionedSchema {
    static var versionIdentifier: Schema.Version = .init(4, 0, 0)
    static var models: [any PersistentModel.Type] { LISYModelRegistry.v4Models }
}

enum LISYSchemaV5: VersionedSchema {
    static var versionIdentifier: Schema.Version = .init(5, 0, 0)
    static var models: [any PersistentModel.Type] { LISYModelRegistry.v4Models }
}

enum LISYSchemaV6: VersionedSchema {
    static var versionIdentifier: Schema.Version = .init(6, 0, 0)
    static var models: [any PersistentModel.Type] { LISYModelRegistry.currentModels }
}

enum LISYSchemaV7: VersionedSchema {
    static var versionIdentifier: Schema.Version = .init(7, 0, 0)
    static var models: [any PersistentModel.Type] { LISYModelRegistry.currentModels }
}

enum LISYSchemaV8: VersionedSchema {
    static var versionIdentifier: Schema.Version = .init(8, 0, 0)
    static var models: [any PersistentModel.Type] { LISYModelRegistry.currentModels }
}

enum LISYMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [LISYSchemaV1.self, LISYSchemaV2.self, LISYSchemaV3.self, LISYSchemaV4.self, LISYSchemaV5.self, LISYSchemaV6.self, LISYSchemaV7.self, LISYSchemaV8.self]
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
            ),
            .lightweight(
                fromVersion: LISYSchemaV2.self,
                toVersion: LISYSchemaV3.self
            ),
            .lightweight(
                fromVersion: LISYSchemaV3.self,
                toVersion: LISYSchemaV4.self
            ),
            .lightweight(
                fromVersion: LISYSchemaV4.self,
                toVersion: LISYSchemaV5.self
            ),
            .lightweight(
                fromVersion: LISYSchemaV5.self,
                toVersion: LISYSchemaV6.self
            ),
            .lightweight(
                fromVersion: LISYSchemaV6.self,
                toVersion: LISYSchemaV7.self
            ),
            .lightweight(
                fromVersion: LISYSchemaV7.self,
                toVersion: LISYSchemaV8.self
            )
        ]
    }
}

enum LISYPersistence {
    static let schema = Schema(LISYSchemaV8.models)
}
