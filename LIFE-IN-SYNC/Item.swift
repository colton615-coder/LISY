import Foundation
import SwiftData

enum TaskPriority: String, Codable, CaseIterable, Identifiable {
    case low
    case medium
    case high

    var id: String { rawValue }
}

enum SwingPhase: String, Codable, CaseIterable, Identifiable {
    case address
    case takeaway
    case shaftParallel
    case topOfBackswing
    case transition
    case earlyDownswing
    case impact
    case followThrough

    var id: String { rawValue }

    var title: String {
        switch self {
        case .address:
            "Address"
        case .takeaway:
            "Takeaway"
        case .shaftParallel:
            "Shaft Parallel"
        case .topOfBackswing:
            "Top of Backswing"
        case .transition:
            "Transition"
        case .earlyDownswing:
            "Early Downswing"
        case .impact:
            "Impact"
        case .followThrough:
            "Follow Through"
        }
    }

    var reviewTitle: String {
        switch self {
        case .address:
            "Setup"
        case .takeaway:
            "Takeaway Start"
        case .shaftParallel:
            "Lead Arm Parallel"
        case .topOfBackswing:
            "Top of Swing"
        case .transition:
            "Transition"
        case .earlyDownswing:
            "Early Downswing"
        case .impact:
            "Impact"
        case .followThrough:
            "Finish"
        }
    }
}

enum KeyframeValidationStatus: String, Codable, CaseIterable, Identifiable {
    case pending
    case approved
    case flagged

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pending:
            "Pending"
        case .approved:
            "Approved"
        case .flagged:
            "Flagged"
        }
    }
}

enum SwingJointName: String, Codable, CaseIterable, Identifiable {
    case nose
    case leftShoulder
    case rightShoulder
    case leftElbow
    case rightElbow
    case leftWrist
    case rightWrist
    case leftHip
    case rightHip
    case leftKnee
    case rightKnee
    case leftAnkle
    case rightAnkle

    var id: String { rawValue }
}

struct SwingJoint: Codable, Hashable, Identifiable {
    var name: SwingJointName
    var x: Double
    var y: Double
    var confidence: Double

    var id: SwingJointName { name }
}

struct SwingFrame: Codable, Hashable, Identifiable {
    var timestamp: Double
    var joints: [SwingJoint]
    var confidence: Double

    var id: Double { timestamp }
}

struct KeyFrame: Codable, Hashable, Identifiable {
    var phase: SwingPhase
    var frameIndex: Int
    var source: KeyFrameSource = .automatic
    var reviewStatus: KeyframeValidationStatus = .pending

    var id: SwingPhase { phase }

    init(
        phase: SwingPhase,
        frameIndex: Int,
        source: KeyFrameSource = .automatic,
        reviewStatus: KeyframeValidationStatus = .pending
    ) {
        self.phase = phase
        self.frameIndex = frameIndex
        self.source = source
        self.reviewStatus = reviewStatus
    }

    private enum CodingKeys: String, CodingKey {
        case phase
        case frameIndex
        case source
        case reviewStatus
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        phase = try container.decode(SwingPhase.self, forKey: .phase)
        frameIndex = try container.decode(Int.self, forKey: .frameIndex)
        source = try container.decodeIfPresent(KeyFrameSource.self, forKey: .source) ?? .automatic
        reviewStatus = try container.decodeIfPresent(KeyframeValidationStatus.self, forKey: .reviewStatus) ?? .pending
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(phase, forKey: .phase)
        try container.encode(frameIndex, forKey: .frameIndex)
        try container.encode(source, forKey: .source)
        try container.encode(reviewStatus, forKey: .reviewStatus)
    }
}

enum KeyFrameSource: String, Codable, CaseIterable, Identifiable {
    case automatic
    case adjusted

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic:
            "Auto"
        case .adjusted:
            "Adjusted"
        }
    }
}

enum HandAnchorSource: String, Codable, CaseIterable, Identifiable {
    case automatic
    case manual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic:
            "Auto"
        case .manual:
            "Manual"
        }
    }
}

struct HandAnchor: Codable, Hashable, Identifiable {
    var phase: SwingPhase
    var x: Double
    var y: Double
    var source: HandAnchorSource = .automatic

    var id: SwingPhase { phase }

    init(
        phase: SwingPhase,
        x: Double,
        y: Double,
        source: HandAnchorSource = .automatic
    ) {
        self.phase = phase
        self.x = x
        self.y = y
        self.source = source
    }

    private enum CodingKeys: String, CodingKey {
        case phase
        case x
        case y
        case source
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        phase = try container.decode(SwingPhase.self, forKey: .phase)
        x = try container.decode(Double.self, forKey: .x)
        y = try container.decode(Double.self, forKey: .y)
        source = try container.decodeIfPresent(HandAnchorSource.self, forKey: .source) ?? .automatic
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(phase, forKey: .phase)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
        try container.encode(source, forKey: .source)
    }
}

struct PathPoint: Codable, Hashable, Identifiable {
    var sequence: Int
    var x: Double
    var y: Double

    var id: Int { sequence }
}

struct AnalysisResult: Codable, Hashable {
    var issues: [String]
    var highlights: [String]
    var summary: String
    var scorecard: GarageSwingScorecard?

    init(
        issues: [String],
        highlights: [String],
        summary: String,
        scorecard: GarageSwingScorecard? = nil
    ) {
        self.issues = issues
        self.highlights = highlights
        self.summary = summary
        self.scorecard = scorecard
    }
}

@Model
final class CompletionRecord {
    var completedAt: Date
    var sourceModuleID: String

    init(completedAt: Date = .now, sourceModuleID: String) {
        self.completedAt = completedAt
        self.sourceModuleID = sourceModuleID
    }
}

@Model
final class TagRecord {
    var name: String

    init(name: String) {
        self.name = name
    }
}

@Model
final class NoteRecord {
    var body: String
    var createdAt: Date

    init(body: String, createdAt: Date = .now) {
        self.body = body
        self.createdAt = createdAt
    }
}

@Model
final class Habit {
    var id: UUID
    var name: String
    var targetCount: Int
    var createdAt: Date

    init(id: UUID = UUID(), name: String, targetCount: Int = 1, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.targetCount = targetCount
        self.createdAt = createdAt
    }
}

@Model
final class HabitEntry {
    var habitID: UUID
    var habitName: String
    var count: Int
    var loggedAt: Date

    init(habitID: UUID, habitName: String, count: Int = 1, loggedAt: Date = .now) {
        self.habitID = habitID
        self.habitName = habitName
        self.count = count
        self.loggedAt = loggedAt
    }
}

@Model
final class TaskItem {
    var id: UUID
    var title: String
    var priority: String
    var dueDate: Date?
    var isCompleted: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        priority: String = TaskPriority.medium.rawValue,
        dueDate: Date? = nil,
        isCompleted: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.priority = priority
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.createdAt = createdAt
    }
}

@Model
final class CalendarEvent {
    var title: String
    var startDate: Date
    var endDate: Date

    init(title: String, startDate: Date, endDate: Date) {
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
    }
}

@Model
final class SupplyItem {
    var title: String
    var category: String
    var isPurchased: Bool

    init(title: String, category: String = "General", isPurchased: Bool = false) {
        self.title = title
        self.category = category
        self.isPurchased = isPurchased
    }
}

@Model
final class ExpenseRecord {
    var title: String
    var amount: Double
    var category: String
    var recordedAt: Date

    init(title: String, amount: Double, category: String, recordedAt: Date = .now) {
        self.title = title
        self.amount = amount
        self.category = category
        self.recordedAt = recordedAt
    }
}

@Model
final class BudgetRecord {
    var title: String
    var limitAmount: Double
    var periodLabel: String

    init(title: String, limitAmount: Double, periodLabel: String = "Monthly") {
        self.title = title
        self.limitAmount = limitAmount
        self.periodLabel = periodLabel
    }
}

@Model
final class WorkoutTemplate {
    var name: String
    var createdAt: Date

    init(name: String, createdAt: Date = .now) {
        self.name = name
        self.createdAt = createdAt
    }
}

@Model
final class WorkoutSession {
    var templateName: String
    var performedAt: Date
    var durationMinutes: Int

    init(templateName: String, performedAt: Date = .now, durationMinutes: Int = 0) {
        self.templateName = templateName
        self.performedAt = performedAt
        self.durationMinutes = durationMinutes
    }
}

@Model
final class StudyEntry {
    var title: String
    var passageReference: String
    var notes: String
    var createdAt: Date

    init(title: String, passageReference: String, notes: String = "", createdAt: Date = .now) {
        self.title = title
        self.passageReference = passageReference
        self.notes = notes
        self.createdAt = createdAt
    }
}

@Model
final class SwingRecord {
    var title: String
    var createdAt: Date
    var mediaFilename: String?
    var mediaFileBookmark: Data?
    var reviewMasterFilename: String?
    var reviewMasterBookmark: Data?
    var exportAssetFilename: String?
    var exportAssetBookmark: Data?
    var notes: String
    var frameRate: Double
    var swingFrames: [SwingFrame]
    var keyFrames: [KeyFrame]
    var keyframeValidationStatus: KeyframeValidationStatus
    var handAnchors: [HandAnchor]
    var pathPoints: [PathPoint]
    var analysisResult: AnalysisResult?

    init(
        title: String,
        createdAt: Date = .now,
        mediaFilename: String? = nil,
        mediaFileBookmark: Data? = nil,
        reviewMasterFilename: String? = nil,
        reviewMasterBookmark: Data? = nil,
        exportAssetFilename: String? = nil,
        exportAssetBookmark: Data? = nil,
        notes: String = "",
        frameRate: Double = 0,
        swingFrames: [SwingFrame] = [],
        keyFrames: [KeyFrame] = [],
        keyframeValidationStatus: KeyframeValidationStatus = .pending,
        handAnchors: [HandAnchor] = [],
        pathPoints: [PathPoint] = [],
        analysisResult: AnalysisResult? = nil
    ) {
        self.title = title
        self.createdAt = createdAt
        self.mediaFilename = mediaFilename
        self.mediaFileBookmark = mediaFileBookmark
        self.reviewMasterFilename = reviewMasterFilename
        self.reviewMasterBookmark = reviewMasterBookmark
        self.exportAssetFilename = exportAssetFilename
        self.exportAssetBookmark = exportAssetBookmark
        self.notes = notes
        self.frameRate = frameRate
        self.swingFrames = swingFrames
        self.keyFrames = keyFrames
        self.keyframeValidationStatus = keyframeValidationStatus
        self.handAnchors = handAnchors
        self.pathPoints = pathPoints
        self.analysisResult = analysisResult
    }

    var preferredReviewFilename: String? {
        normalizedFilename(reviewMasterFilename) ?? normalizedFilename(mediaFilename)
    }

    var preferredExportFilename: String? {
        normalizedFilename(exportAssetFilename)
    }

    var isUsingLegacySingleAsset: Bool {
        normalizedFilename(reviewMasterFilename) == nil && normalizedFilename(mediaFilename) != nil
    }

    private func normalizedFilename(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func reviewStatus(for phase: SwingPhase) -> KeyframeValidationStatus {
        keyFrames.first(where: { $0.phase == phase })?.reviewStatus ?? .pending
    }

    var approvedCheckpointCount: Int {
        SwingPhase.allCases.filter { reviewStatus(for: $0) == .approved }.count
    }

    var flaggedCheckpointCount: Int {
        SwingPhase.allCases.filter { reviewStatus(for: $0) == .flagged }.count
    }

    var pendingCheckpointCount: Int {
        max(SwingPhase.allCases.count - approvedCheckpointCount - flaggedCheckpointCount, 0)
    }

    var allCheckpointsApproved: Bool {
        keyFrames.count == SwingPhase.allCases.count && SwingPhase.allCases.allSatisfy { reviewStatus(for: $0) == .approved }
    }

    func refreshKeyframeValidationStatus() {
        if allCheckpointsApproved {
            keyframeValidationStatus = .approved
        } else if flaggedCheckpointCount > 0 {
            keyframeValidationStatus = .flagged
        } else {
            keyframeValidationStatus = .pending
        }
    }

    func hydrateCheckpointStatusesFromAggregateIfNeeded() {
        guard
            keyFrames.isEmpty == false,
            keyframeValidationStatus != .pending,
            keyFrames.allSatisfy({ $0.reviewStatus == .pending })
        else {
            return
        }

        for index in keyFrames.indices {
            keyFrames[index].reviewStatus = keyframeValidationStatus
        }
    }
}
