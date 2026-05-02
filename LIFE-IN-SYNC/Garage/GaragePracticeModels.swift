import Foundation
import SwiftData

enum PracticeEnvironment: String, CaseIterable, Codable, Identifiable, Hashable {
    case net
    case range
    case puttingGreen

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .net:
            return "Net"
        case .range:
            return "Range"
        case .puttingGreen:
            return "Putting Green"
        }
    }

    var systemImage: String {
        switch self {
        case .net:
            return "figure.golf"
        case .range:
            return "flag.pattern.checkered"
        case .puttingGreen:
            return "circle.grid.2x2"
        }
    }

    var description: String {
        switch self {
        case .net:
            return "Tight feedback loops for mechanics, contact, and rehearsal."
        case .range:
            return "Ball-flight practice with target windows and club-specific patterns."
        case .puttingGreen:
            return "Start line, pace control, and green-reading reps."
        }
    }
}

@Model
final class PracticeDrillDefinition {
    var id: UUID
    var title: String
    var focusArea: String
    var targetClub: String
    var defaultRepCount: Int

    init(
        id: UUID = UUID(),
        title: String,
        focusArea: String,
        targetClub: String,
        defaultRepCount: Int
    ) {
        self.id = id
        self.title = title
        self.focusArea = focusArea
        self.targetClub = targetClub
        self.defaultRepCount = defaultRepCount
    }
}

struct PracticeTemplateDrill: Identifiable, Hashable, Codable {
    let id: UUID
    let definitionID: UUID?
    let title: String
    let focusArea: String
    let targetClub: String
    let defaultRepCount: Int

    init(
        id: UUID = UUID(),
        definitionID: UUID? = nil,
        title: String,
        focusArea: String,
        targetClub: String,
        defaultRepCount: Int
    ) {
        self.id = id
        self.definitionID = definitionID
        self.title = title
        self.focusArea = focusArea
        self.targetClub = targetClub
        self.defaultRepCount = defaultRepCount
    }

    init(definition: PracticeDrillDefinition) {
        self.init(
            definitionID: definition.id,
            title: definition.title,
            focusArea: definition.focusArea,
            targetClub: definition.targetClub,
            defaultRepCount: definition.defaultRepCount
        )
    }

    var metadataSummary: String {
        var parts: [String] = []

        if focusArea.isEmpty == false {
            parts.append(focusArea)
        }

        if targetClub.isEmpty == false {
            parts.append(targetClub)
        }

        parts.append("\(defaultRepCount) reps")
        return parts.joined(separator: " • ")
    }
}

@Model
final class PracticeTemplate {
    var id: UUID
    var title: String
    var environment: String
    var drills: [PracticeTemplateDrill]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        environment: String,
        drills: [PracticeTemplateDrill],
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.environment = environment
        self.drills = drills
        self.createdAt = createdAt
    }
}

struct PracticeDrillProgress: Hashable, Codable {
    let drillID: UUID
    var isCompleted: Bool
    var note: String

    init(
        drillID: UUID,
        isCompleted: Bool = false,
        note: String = ""
    ) {
        self.drillID = drillID
        self.isCompleted = isCompleted
        self.note = note
    }
}

struct DrillResult: Hashable, Codable, Identifiable, Sendable {
    var name: String
    var successfulReps: Int
    var totalReps: Int

    var id: String { name }

    var successRatio: Double {
        guard totalReps > 0 else {
            return 0
        }

        return Double(successfulReps) / Double(totalReps)
    }
}

struct ActivePracticeSession: Identifiable, Hashable, Codable {
    let id: UUID
    let templateID: UUID?
    let templateName: String
    let environment: PracticeEnvironment
    let startedAt: Date
    var endedAt: Date?
    let drills: [PracticeTemplateDrill]
    var drillProgress: [PracticeDrillProgress]

    init(
        id: UUID = UUID(),
        template: PracticeTemplate,
        startedAt: Date = .now,
        endedAt: Date? = nil,
        drillProgress: [PracticeDrillProgress]? = nil
    ) {
        let environmentValue = PracticeEnvironment(rawValue: template.environment) ?? .net

        self.id = id
        self.templateID = template.id
        self.templateName = template.title
        self.environment = environmentValue
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.drills = template.drills
        self.drillProgress = drillProgress ?? template.drills.map {
            PracticeDrillProgress(drillID: $0.id)
        }
    }
}

@Model
final class PracticeSessionRecord {
    var id: UUID
    var date: Date
    var templateName: String
    var environment: String
    var completedDrills: Int
    var totalDrills: Int
    var drillResults: [DrillResult]
    var sessionFeelNote: String
    var aiCoachingInsight: String?
    var coachingEfficacyScore: Double?
    var isPersonalRecord: Bool
    var aggregatedNotes: String

    init(
        id: UUID = UUID(),
        date: Date = .now,
        templateName: String,
        environment: String,
        completedDrills: Int,
        totalDrills: Int,
        drillResults: [DrillResult] = [],
        sessionFeelNote: String = "",
        aiCoachingInsight: String? = nil,
        coachingEfficacyScore: Double? = nil,
        isPersonalRecord: Bool = false,
        aggregatedNotes: String = ""
    ) {
        self.id = id
        self.date = date
        self.templateName = templateName
        self.environment = environment
        self.completedDrills = completedDrills
        self.totalDrills = totalDrills
        self.drillResults = drillResults
        self.sessionFeelNote = sessionFeelNote
        self.aiCoachingInsight = aiCoachingInsight
        self.coachingEfficacyScore = coachingEfficacyScore
        self.isPersonalRecord = isPersonalRecord
        self.aggregatedNotes = aggregatedNotes
    }
}

extension PracticeTemplate {
    var environmentValue: PracticeEnvironment {
        PracticeEnvironment(rawValue: environment) ?? .net
    }

    var environmentDisplayName: String {
        environmentValue.displayName
    }
}

extension PracticeDrillDefinition {
    var metadataSummary: String {
        PracticeTemplateDrill(definition: self).metadataSummary
    }
}

extension ActivePracticeSession {
    var completedDrillCount: Int {
        drillProgress.filter(\.isCompleted).count
    }

    var totalDrillCount: Int {
        drills.count
    }

    var orderedDrillEntries: [PracticeSessionDrillEntry] {
        drills.map { drill in
            PracticeSessionDrillEntry(
                drill: drill,
                progress: progress(for: drill.id) ?? PracticeDrillProgress(drillID: drill.id)
            )
        }
    }

    mutating func toggleCompletion(for drillID: UUID) {
        guard let index = drillProgress.firstIndex(where: { $0.drillID == drillID }) else {
            return
        }

        drillProgress[index].isCompleted.toggle()
    }

    mutating func updateNote(_ note: String, for drillID: UUID) {
        guard let index = drillProgress.firstIndex(where: { $0.drillID == drillID }) else {
            return
        }

        drillProgress[index].note = note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func progress(for drillID: UUID) -> PracticeDrillProgress? {
        drillProgress.first(where: { $0.drillID == drillID })
    }

    var aggregatedNotes: String {
        orderedDrillEntries
            .compactMap { entry in
                let note = entry.progress.note.trimmingCharacters(in: .whitespacesAndNewlines)
                guard note.isEmpty == false else {
                    return nil
                }

                return "\(entry.drill.title): \(note)"
            }
            .joined(separator: "\n")
    }

    func defaultDrillResults() -> [DrillResult] {
        orderedDrillEntries.map { entry in
            DrillResult(
                name: entry.drill.title,
                successfulReps: entry.progress.isCompleted ? entry.drill.defaultRepCount : 0,
                totalReps: entry.drill.defaultRepCount
            )
        }
    }

    func makeRecord(
        drillResults: [DrillResult],
        sessionFeelNote: String
    ) -> PracticeSessionRecord {
        PracticeSessionRecord(
            templateName: templateName,
            environment: environment.rawValue,
            completedDrills: completedDrillCount,
            totalDrills: totalDrillCount,
            drillResults: drillResults,
            sessionFeelNote: sessionFeelNote.trimmingCharacters(in: .whitespacesAndNewlines),
            aggregatedNotes: aggregatedNotes
        )
    }
}

struct PracticeSessionDrillEntry: Identifiable, Hashable {
    let drill: PracticeTemplateDrill
    let progress: PracticeDrillProgress

    var id: UUID { drill.id }
}

extension PracticeSessionRecord {
    var carryForwardDirectiveTitle: String? {
        carryForwardPrimaryCue == nil ? nil : "Coach's Directive"
    }

    var carryForwardDirectiveText: String {
        if let carryForwardPrimaryCue {
            return carryForwardPrimaryCue
        }

        if let trimmedSessionFeelNote {
            return trimmedSessionFeelNote
        }

        return "No carry-forward note yet. Complete a session to build your next cue."
    }

    var carryForwardRelativeDateText: String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return "Today"
        }

        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: .now)
    }

    var completionRatioText: String {
        "\(completedDrills)/\(totalDrills)"
    }

    var totalSuccessfulReps: Int {
        drillResults.reduce(0) { $0 + $1.successfulReps }
    }

    var totalAttemptedReps: Int {
        drillResults.reduce(0) { $0 + $1.totalReps }
    }

    var aggregateEfficiency: Double {
        guard totalAttemptedReps > 0 else {
            return 0
        }

        return Double(totalSuccessfulReps) / Double(totalAttemptedReps)
    }

    var aggregateEfficiencyPercentage: Int {
        Int((aggregateEfficiency * 100).rounded())
    }

    var aggregateEfficiencyText: String {
        "\(aggregateEfficiencyPercentage)%"
    }

    var environmentDisplayName: String {
        PracticeEnvironment(rawValue: environment)?.displayName ?? environment
    }

    var coachingEfficacyPercentagePoints: Int? {
        coachingEfficacyScore.map { Int(($0 * 100).rounded()) }
    }

    private var carryForwardPrimaryCue: String? {
        GarageCoachingInsight.decode(from: aiCoachingInsight)?.primaryCue
    }

    private var trimmedSessionFeelNote: String? {
        let feel = sessionFeelNote.trimmingCharacters(in: .whitespacesAndNewlines)
        return feel.isEmpty ? nil : feel
    }
}

struct GarageDrillBenchmark: Identifiable, Hashable {
    let name: String
    let averageSuccessRatio: Double
    let sampleCount: Int

    var id: String { name }

    func projectedSuccessfulReps(for totalReps: Int) -> Int {
        let projectedValue = Int((averageSuccessRatio * Double(totalReps)).rounded())
        return min(max(projectedValue, 0), totalReps)
    }
}

struct GarageTemplateBenchmarkSnapshot: Hashable {
    let templateName: String
    let sourceSessionCount: Int
    let totalSuccess: Int
    let totalAttempts: Int
    let drillBenchmarks: [GarageDrillBenchmark]

    var projectedEfficiency: Double {
        guard totalAttempts > 0 else {
            return 0
        }

        return Double(totalSuccess) / Double(totalAttempts)
    }

    var projectedEfficiencyText: String {
        "\(Int((projectedEfficiency * 100).rounded()))%"
    }

    func projectedSuccessfulReps(for drillName: String, totalReps: Int) -> Int? {
        drillBenchmarks
            .first(where: { $0.name == drillName })?
            .projectedSuccessfulReps(for: totalReps)
    }
}

struct GarageDrillDelta: Identifiable, Hashable {
    let name: String
    let previousRatio: Double
    let currentRatio: Double

    var id: String { name }

    var delta: Double {
        currentRatio - previousRatio
    }

    var deltaPercentagePoints: Int {
        Int((delta * 100).rounded())
    }

    var deltaText: String {
        let value = deltaPercentagePoints
        let sign = value > 0 ? "+" : ""
        return "\(sign)\(value)%"
    }

    var improved: Bool {
        delta > 0
    }
}

struct GarageCoachingAuditSnapshot: Identifiable, Hashable {
    let currentRecordID: UUID
    let previousRecordID: UUID
    let templateName: String
    let previousCue: String
    let drillDeltas: [GarageDrillDelta]
    let isPersonalRecord: Bool

    var id: UUID { currentRecordID }

    var leadingDelta: GarageDrillDelta? {
        drillDeltas.max { lhs, rhs in
            abs(lhs.delta) < abs(rhs.delta)
        }
    }

    var averageDelta: Double {
        guard drillDeltas.isEmpty == false else {
            return 0
        }

        let totalDelta = drillDeltas.reduce(0) { partialResult, delta in
            partialResult + delta.delta
        }
        return totalDelta / Double(drillDeltas.count)
    }

    var averageDeltaPercentagePoints: Int {
        Int((averageDelta * 100).rounded())
    }

    var deltaBadgeText: String {
        let sign = averageDeltaPercentagePoints > 0 ? "+" : ""
        return "\(sign)\(averageDeltaPercentagePoints)%"
    }

    var impactDirectionText: String {
        if averageDeltaPercentagePoints > 0 {
            return "Improved"
        }

        if averageDeltaPercentagePoints < 0 {
            return "Slipped"
        }

        return "Held"
    }

    var weightedOutcomeWeight: Double {
        isPersonalRecord ? 1.5 : 1
    }

    var cueGivenText: String {
        previousCue
    }

    var progressSummaryText: String {
        if let leadingDelta {
            return "\(leadingDelta.name) \(leadingDelta.deltaText)"
        }

        return deltaBadgeText
    }
}

struct GarageCoachingImpactDashboard: Hashable {
    let auditSnapshots: [GarageCoachingAuditSnapshot]

    var weightedSuccessRatio: Double {
        let totalWeight = auditSnapshots.reduce(0) { $0 + $1.weightedOutcomeWeight }
        guard totalWeight > 0 else {
            return 0
        }

        let positiveWeight = auditSnapshots.reduce(0) { partialResult, snapshot in
            partialResult + (snapshot.averageDelta > 0 ? snapshot.weightedOutcomeWeight : 0)
        }
        return positiveWeight / totalWeight
    }

    var efficacyPercentage: Int {
        Int((weightedSuccessRatio * 100).rounded())
    }

    var efficacyText: String {
        "\(efficacyPercentage)% of AI cues led to performance gains"
    }
}

extension Array where Element == PracticeSessionRecord {
    func recentTemplateSessions(
        named templateName: String,
        upTo referenceDate: Date = .distantFuture,
        limit: Int = 5
    ) -> [PracticeSessionRecord] {
        filter { record in
            record.templateName == templateName && record.date <= referenceDate
        }
        .sorted { $0.date > $1.date }
        .prefix(limit)
        .map { $0 }
    }

    func benchmarkSnapshot(
        for templateName: String,
        upTo referenceDate: Date = .distantFuture,
        limit: Int = 5
    ) -> GarageTemplateBenchmarkSnapshot? {
        let recentRecords = recentTemplateSessions(
            named: templateName,
            upTo: referenceDate,
            limit: limit
        )

        guard recentRecords.isEmpty == false else {
            return nil
        }

        let totalSuccess = recentRecords.reduce(0) { $0 + $1.totalSuccessfulReps }
        let totalAttempts = recentRecords.reduce(0) { $0 + $1.totalAttemptedReps }

        let groupedBenchmarks: [GarageDrillBenchmark] = Dictionary(grouping: recentRecords.flatMap(\.drillResults), by: \.name)
            .map { drillName, drillResults in
                let totalDrillSuccess = drillResults.reduce(0) { $0 + $1.successfulReps }
                let totalDrillAttempts = drillResults.reduce(0) { $0 + $1.totalReps }
                let averageSuccessRatio: Double

                if totalDrillAttempts > 0 {
                    averageSuccessRatio = Double(totalDrillSuccess) / Double(totalDrillAttempts)
                } else {
                    averageSuccessRatio = 0
                }

                return GarageDrillBenchmark(
                    name: drillName,
                    averageSuccessRatio: averageSuccessRatio,
                    sampleCount: drillResults.count
                )
            }
            .sorted { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }

        return GarageTemplateBenchmarkSnapshot(
            templateName: templateName,
            sourceSessionCount: recentRecords.count,
            totalSuccess: totalSuccess,
            totalAttempts: totalAttempts,
            drillBenchmarks: groupedBenchmarks
        )
    }

    func personalRecordHolder(for templateName: String) -> PracticeSessionRecord? {
        filter { $0.templateName == templateName }
            .max { lhs, rhs in
                if lhs.aggregateEfficiency == rhs.aggregateEfficiency {
                    return lhs.date < rhs.date
                }

                return lhs.aggregateEfficiency < rhs.aggregateEfficiency
            }
    }

    func latestTemplateSession(named templateName: String) -> PracticeSessionRecord? {
        filter { $0.templateName == templateName }
            .max { lhs, rhs in
                lhs.date < rhs.date
            }
    }

    func previousTemplateSession(for record: PracticeSessionRecord) -> PracticeSessionRecord? {
        filter { candidate in
            candidate.templateName == record.templateName &&
            candidate.id != record.id &&
            candidate.date < record.date
        }
        .max { lhs, rhs in
            lhs.date < rhs.date
        }
    }

    func coachingAuditSnapshot(for currentRecord: PracticeSessionRecord) -> GarageCoachingAuditSnapshot? {
        guard let previousRecord = previousTemplateSession(for: currentRecord),
              let previousInsight = GarageCoachingInsight.decode(from: previousRecord.aiCoachingInsight),
              let previousCue = previousInsight.primaryCue else {
            return nil
        }

        let focusDrillNames = previousInsight.focusDrillNames(matching: previousRecord.drillResults)
        let previousResultMap = Dictionary(uniqueKeysWithValues: previousRecord.drillResults.map { ($0.name, $0) })
        let currentResultMap = Dictionary(uniqueKeysWithValues: currentRecord.drillResults.map { ($0.name, $0) })

        let drillDeltas = focusDrillNames.compactMap { drillName -> GarageDrillDelta? in
            guard let previousResult = previousResultMap[drillName],
                  let currentResult = currentResultMap[drillName] else {
                return nil
            }

            return GarageDrillDelta(
                name: drillName,
                previousRatio: previousResult.successRatio,
                currentRatio: currentResult.successRatio
            )
        }

        guard drillDeltas.isEmpty == false else {
            return nil
        }

        return GarageCoachingAuditSnapshot(
            currentRecordID: currentRecord.id,
            previousRecordID: previousRecord.id,
            templateName: currentRecord.templateName,
            previousCue: previousCue,
            drillDeltas: drillDeltas,
            isPersonalRecord: currentRecord.isPersonalRecord
        )
    }

    func coachingImpactDashboard(limit: Int = 5) -> GarageCoachingImpactDashboard {
        let snapshots = sorted { $0.date > $1.date }
            .filter { $0.coachingEfficacyScore != nil }
            .compactMap { coachingAuditSnapshot(for: $0) }
            .prefix(limit)
            .map { $0 }

        return GarageCoachingImpactDashboard(auditSnapshots: snapshots)
    }
}
