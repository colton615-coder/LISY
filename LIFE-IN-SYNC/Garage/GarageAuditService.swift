import SwiftData

@MainActor
enum GarageAuditService {
    static func refreshCoachingAudit(
        for newRecord: PracticeSessionRecord,
        in modelContext: ModelContext
    ) throws -> GarageCoachingAuditSnapshot? {
        let templateRecords = try modelContext
            .fetch(FetchDescriptor<PracticeSessionRecord>())
            .filter { $0.templateName == newRecord.templateName }

        let auditSnapshot = templateRecords.coachingAuditSnapshot(for: newRecord)
        newRecord.coachingEfficacyScore = auditSnapshot?.averageDelta
        return auditSnapshot
    }
}
