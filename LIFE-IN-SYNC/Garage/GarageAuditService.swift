import SwiftData
import Foundation

@MainActor
enum GarageAuditService {
    static func refreshCoachingAudit(
        for newRecord: PracticeSessionRecord,
        in modelContext: ModelContext
    ) throws -> GarageCoachingAuditSnapshot? {
        // Extract the name to a local variable so the #Predicate macro can use it safely
        let targetTemplate = newRecord.templateName
        
        // Fetch only the records that match the template directly from the database
        let descriptor = FetchDescriptor<PracticeSessionRecord>(
            predicate: #Predicate { $0.templateName == targetTemplate }
        )
        
        let templateRecords = try modelContext.fetch(descriptor)

        let auditSnapshot = templateRecords.coachingAuditSnapshot(for: newRecord)
        newRecord.coachingEfficacyScore = auditSnapshot?.averageDelta
        return auditSnapshot
    }
}
