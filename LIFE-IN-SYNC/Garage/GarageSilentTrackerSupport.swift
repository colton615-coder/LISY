import CoreGraphics
import Foundation
import SwiftUI

enum GarageSkeletonHUDSeverity: Equatable {
    case neutral(String)
    case warning(String)
    case critical(String)

    var label: String {
        switch self {
        case .neutral(let label), .warning(let label), .critical(let label):
            label
        }
    }

    var symbolName: String {
        switch self {
        case .neutral:
            "exclamationmark.circle.fill"
        case .warning, .critical:
            "exclamationmark.triangle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .neutral:
            Color.white.opacity(0.72)
        case .warning:
            Color.orange.opacity(0.94)
        case .critical:
            Color.red.opacity(0.96)
        }
    }
}

struct GarageAnalysisOutput {
    let frameRate: Double
    let swingFrames: [SwingFrame]
    let keyFrames: [KeyFrame]
    let handAnchors: [HandAnchor]
    let pathPoints: [PathPoint]
    let handPathReviewReport: GarageHandPathReviewReport
    let analysisResult: AnalysisResult
    let syncFlow: GarageSyncFlowReport
}

extension SwingFrame {
    nonisolated func joint(named name: SwingJointName) -> SwingJoint? {
        joints.first(where: { $0.name == name })
    }

    nonisolated func point(named name: SwingJointName, minimumConfidence: Double) -> CGPoint? {
        guard let joint = joint(named: name), joint.confidence >= minimumConfidence else {
            return nil
        }
        return CGPoint(x: joint.x, y: joint.y)
    }

    nonisolated func point(named name: SwingJointName) -> CGPoint {
        point(named: name, minimumConfidence: 0) ?? .zero
    }

    nonisolated func joint3D(named name: SwingJoint3DName) -> SwingJoint3D? {
        joints3D.first(where: { $0.name == name })
    }

    nonisolated func point3D(named name: SwingJoint3DName, minimumConfidence: Double = 0) -> SIMD3<Double>? {
        guard let joint = joint3D(named: name), joint.confidence >= minimumConfidence else {
            return nil
        }
        return SIMD3<Double>(joint.x, joint.y, joint.z)
    }
}

enum GarageHandPathSegmentKind: String, Equatable {
    case backswing
    case downswing
}

struct GarageSegmentedPathSample: Equatable {
    let timestamp: Double
    let x: Double
    let y: Double
    let speed: Double
    let segment: GarageHandPathSegmentKind
}

struct GarageHandPathReviewReport: Equatable {
    let score: Int
    let requiresManualReview: Bool
    let weakestPhase: SwingPhase?
    let weakPhases: [SwingPhase]
    let continuityScore: Double
}

struct GarageSkeletonHeadCircle: Equatable {
    let center: CGPoint
    let radius: Double
}

enum GarageSyncFlowStatus: String, Codable, Hashable {
    case ready
    case limited
    case unavailable
}

enum GarageSyncFlowSegment: String, Codable, Hashable {
    case base
    case pelvis
    case torso
    case hands
    case head
}

enum GarageSyncFlowIssueKind: String, Codable, Hashable {
    case earlyHands
    case hipStall
    case earlyExtension
    case unstableHead

    var riskPhrase: String {
        switch self {
        case .earlyHands:
            "Release timing risk"
        case .hipStall:
            "Flip risk"
        case .earlyExtension:
            "Strike consistency risk"
        case .unstableHead:
            "Contact stability risk"
        }
    }
}

struct GarageSyncFlowIssue: Codable, Hashable {
    let kind: GarageSyncFlowIssueKind
    let segment: GarageSyncFlowSegment
    let jointName: SwingJointName
    let timestamp: Double
    let title: String
    let detail: String
}

struct GarageSyncFlowMarker: Codable, Hashable {
    let segment: GarageSyncFlowSegment
    let jointName: SwingJointName
    let timestamp: Double
    let title: String
    let detail: String
}

struct GarageSyncFlowConsequence: Codable, Hashable {
    let riskPhrase: String
    let detail: String
    let startTimestamp: Double
    let endTimestamp: Double
}

struct GarageSyncFlowReport: Codable, Hashable {
    let status: GarageSyncFlowStatus
    let headline: String
    let primaryIssue: GarageSyncFlowIssue?
    let markers: [GarageSyncFlowMarker]
    let consequence: GarageSyncFlowConsequence?
    let summary: String

    var isReady: Bool {
        status == .ready
    }

    static let silentTracker = GarageSyncFlowReport(
        status: .limited,
        headline: "Silent tracker active",
        primaryIssue: nil,
        markers: [],
        consequence: nil,
        summary: "Active biomechanical swing tracking is disabled for the Silent Tracker pivot."
    )
}

struct GarageVideoAssetMetadata: Equatable {
    let duration: Double
    let frameRate: Double
    let naturalSize: CGSize
}

struct GarageThumbnailRequest: Hashable {
    let timestamp: Double
    let maximumSize: CGSize
}

enum GarageThumbnailLoadPriority {
    case high
    case normal
    case low
}

enum GarageReviewFrameSourceState: Equatable {
    case video
    case poseFallback
    case recoveryNeeded
}

enum GarageResolvedReviewVideoOrigin: String, Equatable {
    case reviewMasterStorage
    case reviewMasterBookmark
    case legacyMediaStorage
    case legacyMediaBookmark
    case exportStorage
    case exportBookmark
}

struct GarageResolvedReviewVideo: Equatable {
    let url: URL
    let origin: GarageResolvedReviewVideoOrigin
}

struct GarageInsightMetric: Identifiable, Equatable {
    let title: String
    let value: String
    let detail: String

    var id: String { title }
}

struct GarageInsightReport: Equatable {
    let readiness: String
    let summary: String
    let highlights: [String]
    let issues: [String]
    let metrics: [GarageInsightMetric]

    var isReady: Bool {
        readiness == "Ready"
    }
}

struct GarageStep2ScorePresentation: Equatable {
    let title: String
    let subtitle: String
    let scoreValue: String
    let scoreLimit: String
}

struct GarageStep2MetricPresentation: Identifiable, Equatable {
    let id: String
    let title: String
    let value: String
    let grade: GarageMetricGrade
}

struct GarageStep2UnavailablePresentation: Equatable {
    let title: String
    let message: String
}

enum GarageStep2Presentation: Equatable {
    case ready(score: GarageStep2ScorePresentation, metrics: [GarageStep2MetricPresentation])
    case unavailable(GarageStep2UnavailablePresentation)

    static func make(scorecard: GarageSwingScorecard?) -> GarageStep2Presentation {
        .unavailable(
            GarageStep2UnavailablePresentation(
                title: "Silent Tracker active",
                message: GarageScorecardEngine.unavailableMessage
            )
        )
    }
}

enum GarageWorkflowStatus: String, Equatable {
    case incomplete = "Incomplete"
    case complete = "Complete"
    case needsAttention = "Needs Attention"
}

enum GarageWorkflowStage: String, CaseIterable, Identifiable {
    case importVideo
    case validateKeyframes
    case markAnchors
    case reviewInsights

    var id: String { rawValue }

    var title: String {
        switch self {
        case .importVideo:
            "Import Video"
        case .validateKeyframes:
            "Validate Keyframes"
        case .markAnchors:
            "Mark 8 Grip Anchors"
        case .reviewInsights:
            "Review Insights"
        }
    }
}

struct GarageWorkflowStageState: Identifiable, Equatable {
    let stage: GarageWorkflowStage
    let status: GarageWorkflowStatus
    let summary: String
    let actionLabel: String

    var id: GarageWorkflowStage { stage }
}

struct GarageWorkflowNextAction: Equatable {
    let title: String
    let body: String
    let actionLabel: String
    let stage: GarageWorkflowStage?
}

struct GarageWorkflowProgress: Equatable {
    let stages: [GarageWorkflowStageState]
    let nextAction: GarageWorkflowNextAction

    var completedCount: Int {
        stages.filter { $0.status == .complete }.count
    }
}

enum GarageReliabilityStatus: String, Equatable {
    case trusted = "Trusted"
    case review = "Review"
    case provisional = "Provisional"
}

struct GarageReliabilityCheck: Identifiable, Equatable {
    let title: String
    let passed: Bool
    let detail: String

    var id: String { title }
}

struct GarageReliabilityReport: Equatable {
    let score: Int
    let status: GarageReliabilityStatus
    let summary: String
    let checks: [GarageReliabilityCheck]

    var needsAttention: Bool {
        status != .trusted
    }
}

enum GarageCoachingSeverity: String, Equatable {
    case positive
    case info
    case caution
}

struct GarageCoachingCue: Identifiable, Equatable {
    let title: String
    let message: String
    let severity: GarageCoachingSeverity

    var id: String { title }
}

struct GarageCoachingReport: Equatable {
    let headline: String
    let confidenceLabel: String
    let cues: [GarageCoachingCue]
    let blockers: [String]
    let nextBestAction: String
}

enum GarageCameraPerspective: String, Codable, Hashable {
    case dtl
}

enum GarageSwingDomain: String, Codable, CaseIterable, Hashable {
    case tempo
    case spine
    case pelvis
    case knee
    case head

    var title: String {
        switch self {
        case .tempo:
            "Tempo Ratio"
        case .spine:
            "Spine Angle Delta"
        case .pelvis:
            "Pelvic Depth"
        case .knee:
            "Knee Flex Retention"
        case .head:
            "Head Stability"
        }
    }
}

struct GarageSwingTimestamps: Codable, Hashable {
    let perspective: GarageCameraPerspective
    let start: Double
    let top: Double
    let impact: Double

    var normalizedForPersistence: GarageSwingTimestamps {
        self
    }
}

enum GarageMetricGrade: String, Codable, Hashable {
    case excellent
    case good
    case fair
    case needsWork

    static func from(score: Double) -> GarageMetricGrade {
        switch score {
        case 0.85...:
            .excellent
        case 0.65..<0.85:
            .good
        case 0.45..<0.65:
            .fair
        default:
            .needsWork
        }
    }

    var label: String {
        switch self {
        case .excellent:
            "Excellent"
        case .good:
            "Good"
        case .fair:
            "Fair"
        case .needsWork:
            "Needs Work"
        }
    }
}

struct GarageTempoMetric: Codable, Hashable {
    let ratio: Double
}

struct GarageSpineAngleMetric: Codable, Hashable {
    let deltaDegrees: Double
}

struct GaragePelvicDepthMetric: Codable, Hashable {
    let driftInches: Double
}

struct GarageKneeFlexMetric: Codable, Hashable {
    let leftDeltaDegrees: Double
    let rightDeltaDegrees: Double
}

struct GarageHeadStabilityMetric: Codable, Hashable {
    let swayInches: Double
    let dipInches: Double
}

struct GarageSwingMetrics: Codable, Hashable {
    let tempo: GarageTempoMetric
    let spine: GarageSpineAngleMetric
    let pelvicDepth: GaragePelvicDepthMetric
    let kneeFlex: GarageKneeFlexMetric
    let headStability: GarageHeadStabilityMetric
}

struct GarageSwingDomainScore: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let score: Int
    let grade: GarageMetricGrade
    let displayValue: String
}

struct GarageSwingScorecard: Codable, Hashable {
    let timestamps: GarageSwingTimestamps
    let metrics: GarageSwingMetrics
    let domainScores: [GarageSwingDomainScore]
    let totalScore: Int

    var normalizedForPersistence: GarageSwingScorecard {
        self
    }
}

struct GarageTimestampDetection: Hashable {
    let timestamps: GarageSwingTimestamps
    let startFrameIndex: Int
    let topFrameIndex: Int
    let impactFrameIndex: Int
}

enum GarageAnalysisError: LocalizedError {
    case missingVideoTrack
    case insufficientPoseFrames
    case failedToPersistVideo

    var errorDescription: String? {
        switch self {
        case .missingVideoTrack:
            "The selected file does not contain a readable video track."
        case .insufficientPoseFrames:
            "Silent Tracker no longer runs active biomechanical swing analysis."
        case .failedToPersistVideo:
            "The selected video could not be copied into local storage."
        }
    }
}

enum GarageMediaStore {
    static func persistVideo(from sourceURL: URL) throws -> URL {
        try persistReviewMaster(from: sourceURL)
    }

    static func persistReviewMaster(from sourceURL: URL) throws -> URL {
        let directoryURL = try preparedGarageDirectoryURL(named: "ReviewMasters")
        let fileExtension = sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension
        let destinationURL = directoryURL.appendingPathComponent("\(UUID().uuidString).\(fileExtension)")

        do {
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            return destinationURL
        } catch {
            throw GarageAnalysisError.failedToPersistVideo
        }
    }

    static func persistTrimmedReviewMaster(from sourceURL: URL, startTime: Double, endTime: Double) async throws -> URL {
        try persistReviewMaster(from: sourceURL)
    }

    static func createExportDerivative(from reviewMasterURL: URL) async -> URL? {
        try? persistReviewMaster(from: reviewMasterURL)
    }

    static func persistedVideoURL(for filename: String?) -> URL? {
        guard let filename, filename.isEmpty == false else { return nil }
        for folder in ["ReviewMasters", "Exports", "Garage"] {
            if let directoryURL = try? preparedGarageDirectoryURL(named: folder) {
                let candidate = directoryURL.appendingPathComponent(filename)
                if FileManager.default.fileExists(atPath: candidate.path) {
                    return candidate
                }
            }
        }
        return nil
    }

    static func bookmarkData(for url: URL) -> Data? {
        try? url.bookmarkData()
    }

    static func resolvedReviewVideo(for record: SwingRecord) -> GarageResolvedReviewVideo? {
        return nil
    }

    static func resolvedReviewVideoURL(for record: SwingRecord) -> URL? {
        resolvedReviewVideo(for: record)?.url
    }

    static func reviewFrameSource(for record: SwingRecord) -> GarageReviewFrameSourceState {
        if record.swingFrames.isEmpty == false {
            return .poseFallback
        }

        return .recoveryNeeded
    }

    static func resolvedExportVideoURL(for record: SwingRecord) -> URL? {
        nil
    }

    static func purgeManagedAssets(for record: SwingRecord) -> [String] {
        []
    }

    static func thumbnail(
        for videoURL: URL,
        at timestamp: Double,
        maximumSize: CGSize = CGSize(width: 480, height: 480),
        priority: GarageThumbnailLoadPriority = .normal,
        exactFrame: Bool = false
    ) async -> CGImage? {
        nil
    }

    static func prefetchThumbnails(
        for videoURL: URL,
        requests: [GarageThumbnailRequest],
        priority: GarageThumbnailLoadPriority = .low
    ) async {
    }

    static func assetMetadata(for videoURL: URL) async -> GarageVideoAssetMetadata? {
        nil
    }

    private static func preparedGarageDirectoryURL(named folderName: String) throws -> URL {
        let rootURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        .appendingPathComponent("Garage", isDirectory: true)
        .appendingPathComponent(folderName, isDirectory: true)

        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        return rootURL
    }

    private static func resolvedBookmarkURL(from bookmarkData: Data?) -> URL? {
        guard let bookmarkData else { return nil }
        var isStale = false
        return try? URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
    }
}

enum GarageAnalysisPipeline {
    static func analyzeVideo(
        at videoURL: URL
    ) async throws -> GarageAnalysisOutput {
        let report = GarageHandPathReviewReport(
            score: 0,
            requiresManualReview: false,
            weakestPhase: nil,
            weakPhases: [],
            continuityScore: 0
        )
        let result = AnalysisResult(
            issues: [],
            highlights: ["Silent Tracker captured the local media reference."],
            summary: "Active biomechanical analysis is disabled.",
            scorecard: nil,
            syncFlow: .silentTracker
        )

        return GarageAnalysisOutput(
            frameRate: 0,
            swingFrames: [],
            keyFrames: [],
            handAnchors: [],
            pathPoints: [],
            handPathReviewReport: report,
            analysisResult: result,
            syncFlow: .silentTracker
        )
    }

    static func detectKeyFrames(from frames: [SwingFrame]) -> [KeyFrame] {
        guard frames.isEmpty == false else { return [] }
        let lastIndex = max(frames.count - 1, 0)
        return SwingPhase.allCases.enumerated().map { offset, phase in
            KeyFrame(
                phase: phase,
                frameIndex: min(lastIndex, Int(Double(lastIndex) * Double(offset) / Double(max(SwingPhase.allCases.count - 1, 1))))
            )
        }
    }

    static func autoApprovedKeyFrames(
        from keyFrames: [KeyFrame],
        reviewReport: GarageHandPathReviewReport
    ) -> [KeyFrame] {
        keyFrames.map { keyFrame in
            KeyFrame(
                phase: keyFrame.phase,
                frameIndex: keyFrame.frameIndex,
                source: keyFrame.source,
                reviewStatus: reviewReport.requiresManualReview ? keyFrame.reviewStatus : .approved
            )
        }
    }

    static func handPathReviewReport(for frames: [SwingFrame], keyFrames: [KeyFrame]) -> GarageHandPathReviewReport {
        GarageHandPathReviewReport(
            score: frames.isEmpty ? 0 : 70,
            requiresManualReview: false,
            weakestPhase: nil,
            weakPhases: [],
            continuityScore: frames.isEmpty ? 0 : 0.7
        )
    }

    static func deriveHandAnchors(from frames: [SwingFrame], keyFrames: [KeyFrame]) -> [HandAnchor] {
        keyFrames.compactMap { keyFrame in
            guard frames.indices.contains(keyFrame.frameIndex) else { return nil }
            let point = handCenter(in: frames[keyFrame.frameIndex])
            return HandAnchor(phase: keyFrame.phase, x: point.x, y: point.y)
        }
    }

    static func mergedHandAnchors(
        automaticAnchors: [HandAnchor],
        manualAnchors: [HandAnchor]
    ) -> [HandAnchor] {
        var merged = automaticAnchors
        for anchor in manualAnchors {
            merged = upsertingHandAnchor(anchor, into: merged)
        }
        return merged.sorted { $0.phase.rawValue < $1.phase.rawValue }
    }

    static func mergedHandAnchors(
        preserving existingAnchors: [HandAnchor],
        from frames: [SwingFrame],
        keyFrames: [KeyFrame]
    ) -> [HandAnchor] {
        let automaticAnchors = deriveHandAnchors(from: frames, keyFrames: keyFrames)
        let manualAnchors = existingAnchors.filter { $0.source == .manual }
        return mergedHandAnchors(automaticAnchors: automaticAnchors, manualAnchors: manualAnchors)
    }

    static func upsertingHandAnchor(_ anchor: HandAnchor, into anchors: [HandAnchor]) -> [HandAnchor] {
        var copy = anchors
        if let index = copy.firstIndex(where: { $0.phase == anchor.phase }) {
            copy[index] = anchor
        } else {
            copy.append(anchor)
        }
        return copy
    }

    static func segmentedHandPathSamples(
        from frames: [SwingFrame],
        keyFrames: [KeyFrame],
        samplesPerSegment: Int = 4
    ) -> [GarageSegmentedPathSample] {
        let points = frames.map { frame in
            (frame.timestamp, handCenter(in: frame))
        }
        return points.enumerated().map { index, item in
            let previous = index > 0 ? points[index - 1] : item
            let deltaTime = max(item.0 - previous.0, 0.001)
            let speed = distance(from: previous.1, to: item.1) / deltaTime
            return GarageSegmentedPathSample(
                timestamp: item.0,
                x: item.1.x,
                y: item.1.y,
                speed: speed,
                segment: index < points.count / 2 ? .backswing : .downswing
            )
        }
    }

    static func sampledTimestamps(duration: Double, frameRate: Double, maxFrames: Int) -> [Double] {
        guard duration > 0, maxFrames > 0 else { return [] }
        let count = min(maxFrames, max(Int(duration * max(frameRate, 1)), 1))
        return (0..<count).map { index in
            duration * Double(index) / Double(max(count - 1, 1))
        }
    }

    static func sampledPresentationTimestamps(duration: Double, frameRate: Double, maxFrames: Int) -> [Double] {
        sampledTimestamps(duration: duration, frameRate: frameRate, maxFrames: maxFrames)
    }

    static func resolvedSamplingFrameRate(from nominalFrameRate: Float) -> Double {
        let frameRate = Double(nominalFrameRate)
        guard frameRate > 0 else { return 30 }
        return min(frameRate, 30)
    }

    static func automaticWorkingRange(for frames: [SwingFrame], duration: Double) -> ClosedRange<Double>? {
        guard duration > 0 else { return nil }
        return 0...duration
    }

    static func handCenter(in frame: SwingFrame) -> CGPoint {
        let wrists = frame.joints.filter { $0.name == .leftWrist || $0.name == .rightWrist }
        guard wrists.isEmpty == false else { return CGPoint(x: 0.5, y: 0.5) }
        let x = wrists.map(\.x).reduce(0, +) / Double(wrists.count)
        let y = wrists.map(\.y).reduce(0, +) / Double(wrists.count)
        return CGPoint(x: x, y: y)
    }

    static func bodyScale(in frame: SwingFrame) -> Double {
        guard
            let leftShoulder = frame.joints.first(where: { $0.name == .leftShoulder }),
            let rightShoulder = frame.joints.first(where: { $0.name == .rightShoulder })
        else {
            return 0.2
        }
        return max(distance(from: CGPoint(x: leftShoulder.x, y: leftShoulder.y), to: CGPoint(x: rightShoulder.x, y: rightShoulder.y)), 0.01)
    }

    static func headCircle(in frame: SwingFrame) -> GarageSkeletonHeadCircle? {
        guard let nose = frame.joints.first(where: { $0.name == .nose }) else { return nil }
        return GarageSkeletonHeadCircle(center: CGPoint(x: nose.x, y: nose.y), radius: bodyScale(in: frame) * 0.22)
    }

    static func distance(from lhs: CGPoint, to rhs: CGPoint) -> Double {
        let dx = lhs.x - rhs.x
        let dy = lhs.y - rhs.y
        return sqrt(Double(dx * dx + dy * dy))
    }

    static func generatePathPoints(from frames: [SwingFrame], samplesPerSegment: Int = 16) -> [PathPoint] {
        frames.enumerated().map { index, frame in
            let point = handCenter(in: frame)
            return PathPoint(sequence: index, x: point.x, y: point.y)
        }
    }

    static func generatePathPoints(from anchors: [HandAnchor], samplesPerSegment: Int = 16) -> [PathPoint] {
        anchors.enumerated().map { index, anchor in
            PathPoint(sequence: index, x: anchor.x, y: anchor.y)
        }
    }
}

enum GarageTimestampDetector {
    static func detect(from frames: [SwingFrame], keyFrames: [KeyFrame]) -> GarageTimestampDetection? {
        guard frames.isEmpty == false else { return nil }
        let start = keyFrames.first(where: { $0.phase == .address })?.frameIndex ?? 0
        let top = keyFrames.first(where: { $0.phase == .topOfBackswing })?.frameIndex ?? start
        let impact = keyFrames.first(where: { $0.phase == .impact })?.frameIndex ?? top
        guard frames.indices.contains(start), frames.indices.contains(top), frames.indices.contains(impact) else { return nil }
        return GarageTimestampDetection(
            timestamps: GarageSwingTimestamps(
                perspective: .dtl,
                start: frames[start].timestamp,
                top: frames[top].timestamp,
                impact: frames[impact].timestamp
            ),
            startFrameIndex: start,
            topFrameIndex: top,
            impactFrameIndex: impact
        )
    }
}

enum GarageScorecardEngine {
    static let unavailableMessage = "Silent Tracker does not run active biomechanical scoring."

    static func generate(frames: [SwingFrame], keyFrames: [KeyFrame]) -> GarageSwingScorecard? {
        nil
    }
}

enum GarageStability {
    static func score(for record: SwingRecord) -> Int? {
        record.swingFrames.isEmpty ? nil : 70
    }
}

enum GarageReliability {
    static func report(for record: SwingRecord) -> GarageReliabilityReport {
        let hasVideo = GarageMediaStore.resolvedReviewVideo(for: record) != nil
        return GarageReliabilityReport(
            score: hasVideo ? 80 : 50,
            status: hasVideo ? .trusted : .provisional,
            summary: hasVideo ? "Local media reference is available." : "Local media reference is missing.",
            checks: [
                GarageReliabilityCheck(
                    title: "Local Media",
                    passed: hasVideo,
                    detail: hasVideo ? "A stored review asset is linked." : "No stored review asset could be resolved."
                )
            ]
        )
    }
}

enum GarageCoaching {
    static func report(for record: SwingRecord) -> GarageCoachingReport {
        GarageCoachingReport(
            headline: "Silent Tracker",
            confidenceLabel: GarageReliability.report(for: record).status.rawValue,
            cues: [
                GarageCoachingCue(
                    title: "Passive round tracking",
                    message: "Use the current hole context instead of active swing mechanics.",
                    severity: .info
                )
            ],
            blockers: [],
            nextBestAction: "Confirm the active hole and keep playing."
        )
    }
}

enum GarageInsights {
    static func report(for record: SwingRecord) -> GarageInsightReport {
        GarageInsightReport(
            readiness: record.isImportComplete ? "Ready" : "Review",
            summary: record.derivedAnalysisResult?.summary ?? "Silent Tracker state is available.",
            highlights: record.derivedAnalysisResult?.highlights ?? [],
            issues: record.derivedAnalysisResult?.issues ?? [],
            metrics: []
        )
    }
}

enum GarageWorkflow {
    static func progress(for record: SwingRecord) -> GarageWorkflowProgress {
        let stages = GarageWorkflowStage.allCases.map { stage in
            GarageWorkflowStageState(
                stage: stage,
                status: stage == .importVideo && record.hasSavedVideoReference ? .complete : .incomplete,
                summary: stage == .importVideo ? "Local media reference" : "Disabled in Silent Tracker",
                actionLabel: "Review"
            )
        }
        return GarageWorkflowProgress(
            stages: stages,
            nextAction: GarageWorkflowNextAction(
                title: "Confirm active hole",
                body: "Silent Tracker only needs course context.",
                actionLabel: "Open Garage",
                stage: .importVideo
            )
        )
    }
}
