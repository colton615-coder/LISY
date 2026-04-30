import SwiftData

@MainActor
enum GarageAchievementService {
    static func refreshPersonalRecordState(
        for newRecord: PracticeSessionRecord,
        in modelContext: ModelContext
    ) throws -> Bool {
        let templateRecords = try modelContext
            .fetch(FetchDescriptor<PracticeSessionRecord>())
            .filter { $0.templateName == newRecord.templateName }

        let previousBestEfficiency = templateRecords
            .filter { $0.id != newRecord.id }
            .map { $0.aggregateEfficiency }
            .max() ?? 0

        let personalRecordHolder = templateRecords.personalRecordHolder(for: newRecord.templateName)

        for record in templateRecords {
            record.isPersonalRecord = record.id == personalRecordHolder?.id
        }

        return newRecord.aggregateEfficiency > previousBestEfficiency
    }
}
