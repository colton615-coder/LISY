import AVFoundation
import Foundation
import ImageIO
import simd
import Vision

private struct GaragePoseCoordinateMapper {
    let isMirrored: Bool
    let invertY: Bool

    init(isMirrored: Bool = false, invertY: Bool = true) {
        self.isMirrored = isMirrored
        self.invertY = invertY
    }

    func map(_ location: CGPoint) -> CGPoint {
        let clampedX = min(max(location.x, 0), 1)
        let clampedY = min(max(location.y, 0), 1)
        let mappedX = isMirrored ? (1 - clampedX) : clampedX
        let mappedY = invertY ? (1 - clampedY) : clampedY
        return CGPoint(x: mappedX, y: mappedY)
    }
}

private struct GarageWeightedPointSmoother {
    private let weights: [Double]
    private let lowConfidencePenalty: Double
    private var history: [SwingJointName: [SwingJoint]] = [:]

    init(weights: [Double] = [1, 2, 3, 2, 1], lowConfidencePenalty: Double = 0.35) {
        self.weights = weights
        self.lowConfidencePenalty = lowConfidencePenalty
    }

    mutating func smooth(frame: SwingFrame) -> SwingFrame {
        var smoothedJoints: [SwingJoint] = []
        smoothedJoints.reserveCapacity(frame.joints.count)

        for joint in frame.joints {
            var samples = history[joint.name, default: []]
            samples.append(joint)
            if samples.count > weights.count {
                samples.removeFirst(samples.count - weights.count)
            }

            history[joint.name] = samples
            smoothedJoints.append(weightedAverage(for: joint.name, with: samples))
        }

        return SwingFrame(
            timestamp: frame.timestamp,
            joints: smoothedJoints,
            joints3D: frame.joints3D,
            confidence: frame.confidence
        )
    }

    private func weightedAverage(for name: SwingJointName, with samples: [SwingJoint]) -> SwingJoint {
        var x = 0.0
        var y = 0.0
        var confidence = 0.0
        var totalWeight = 0.0
        let weightSlice = Array(weights.suffix(samples.count))

        for (sample, baseWeight) in zip(samples, weightSlice) {
            let confidenceScale = max(lowConfidencePenalty, sample.confidence)
            let weight = baseWeight * confidenceScale
            x += sample.x * weight
            y += sample.y * weight
            confidence += sample.confidence * weight
            totalWeight += weight
        }

        guard totalWeight > 0 else {
            return samples.last ?? SwingJoint(name: name, x: 0, y: 0, confidence: 0)
        }

        return SwingJoint(
            name: name,
            x: x / totalWeight,
            y: y / totalWeight,
            confidence: confidence / totalWeight
        )
    }
}

private struct GarageHandKinematicSample {
    let index: Int
    let position: CGPoint
    let velocity: CGVector
    let speed: Double
}

private struct GaragePoseExtractionMetadata {
    let usedZeroCopyReader: Bool
    let includes3DFrames: Bool
}

private enum GarageGripEstimateSource {
    case fused
    case singleWrist
    case bridged
}

private struct GarageGripEstimate {
    let point: CGPoint
    let confidence: Double
    let source: GarageGripEstimateSource
}

private enum GaragePathBuilder {
    static func centripetalCatmullRom(points: [CGPoint], samplesPerSegment: Int = 10) -> [CGPoint] {
        guard points.count >= 2 else { return points }
        guard points.count > 2 else { return points }

        var output: [CGPoint] = []
        output.reserveCapacity((points.count - 1) * samplesPerSegment)

        for i in 0..<(points.count - 1) {
            let p0 = points[max(i - 1, 0)]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = points[min(i + 2, points.count - 1)]
            let segment = centripetalSegment(p0: p0, p1: p1, p2: p2, p3: p3, samples: max(samplesPerSegment, 2))
            if i > 0 {
                output.append(contentsOf: segment.dropFirst())
            } else {
                output.append(contentsOf: segment)
            }
        }

        return output
    }

    private static func centripetalSegment(
        p0: CGPoint,
        p1: CGPoint,
        p2: CGPoint,
        p3: CGPoint,
        samples: Int
    ) -> [CGPoint] {
        let alpha = 0.5
        let t0 = 0.0
        let t1 = t0 + parameterDistance(from: p0, to: p1, alpha: alpha)
        let t2 = t1 + parameterDistance(from: p1, to: p2, alpha: alpha)
        let t3 = t2 + parameterDistance(from: p2, to: p3, alpha: alpha)
        guard t1 < t2, t0 < t1, t2 < t3 else { return [p1, p2] }

        var points: [CGPoint] = []
        points.reserveCapacity(samples + 1)
        for step in 0...samples {
            let tau = Double(step) / Double(samples)
            let t = t1 + ((t2 - t1) * tau)
            let a1 = lerp(from: p0, to: p1, t0: t0, t1: t1, t: t)
            let a2 = lerp(from: p1, to: p2, t0: t1, t1: t2, t: t)
            let a3 = lerp(from: p2, to: p3, t0: t2, t1: t3, t: t)
            let b1 = lerp(from: a1, to: a2, t0: t0, t1: t2, t: t)
            let b2 = lerp(from: a2, to: a3, t0: t1, t1: t3, t: t)
            points.append(lerp(from: b1, to: b2, t0: t1, t1: t2, t: t))
        }
        return points
    }

    private static func parameterDistance(from start: CGPoint, to end: CGPoint, alpha: Double) -> Double {
        let distance = max(GarageAnalysisPipeline.distance(from: start, to: end), 1e-6)
        return pow(distance, alpha)
    }

    private static func lerp(from start: CGPoint, to end: CGPoint, t0: Double, t1: Double, t: Double) -> CGPoint {
        guard abs(t1 - t0) > 1e-9 else { return start }
        let weight = (t - t0) / (t1 - t0)
        return CGPoint(x: start.x + (end.x - start.x) * weight, y: start.y + (end.y - start.y) * weight)
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
}

enum GarageAnalysisProgressStep: Equatable {
    case loadingVideo
    case samplingFrames
    case detectingBody
    case mappingCheckpoints
    case savingSwing

    var title: String {
        switch self {
        case .loadingVideo:
            "Loading video"
        case .samplingFrames:
            "Sampling frames"
        case .detectingBody:
            "Detecting body"
        case .mappingCheckpoints:
            "Mapping checkpoints"
        case .savingSwing:
            "Saving swing"
        }
    }

    var detail: String {
        switch self {
        case .loadingVideo:
            "Preparing the selected swing for analysis."
        case .samplingFrames:
            "Sampling the review frames that will power checkpoint validation."
        case .detectingBody:
            "Running pose detection to establish the hand path and body landmarks."
        case .mappingCheckpoints:
            "Placing the swing checkpoints and preparing the review surface."
        case .savingSwing:
            "Saving the analyzed swing and routing it into review."
        }
    }
}

struct GarageAnalysisProgressUpdate: Equatable {
    let step: GarageAnalysisProgressStep
    let frameCount: Int
    let totalFrames: Int

    init(
        step: GarageAnalysisProgressStep,
        frameCount: Int = 0,
        totalFrames: Int = 0
    ) {
        self.step = step
        self.totalFrames = max(totalFrames, 0)
        self.frameCount = min(max(frameCount, 0), self.totalFrames == 0 ? max(frameCount, 0) : self.totalFrames)
    }
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

enum GarageInsights {
    static func report(for record: SwingRecord) -> GarageInsightReport {
        let baseSummary = record.analysisResult?.summary ?? "Swing analysis is in progress."
        let baseHighlights = record.analysisResult?.highlights ?? []
        var highlights = baseHighlights
        var issues = record.analysisResult?.issues ?? []

        let keyframeCount = record.keyFrames.count
        let anchorCount = record.handAnchors.count
        let adjustedCount = record.keyFrames.filter { $0.source == .adjusted }.count
        let pathReady = record.pathPoints.isEmpty == false

        let readiness: String
        if keyframeCount < SwingPhase.allCases.count {
            readiness = "Keyframes Incomplete"
            issues.append("The detected swing phases are incomplete, so timing metrics are partial.")
        } else if anchorCount < SwingPhase.allCases.count {
            readiness = "Awaiting Anchors"
            issues.append("Complete all eight grip anchors to unlock full path-derived measurements.")
        } else if pathReady == false {
            readiness = "Path Unavailable"
            issues.append("All anchors are present, but the path was not generated.")
        } else if record.keyframeValidationStatus == .flagged {
            readiness = "Review Flagged"
            issues.append("Keyframe validation is flagged, so treat the derived metrics as provisional.")
        } else {
            readiness = "Ready"
        }

        if adjustedCount > 0 {
            highlights.append("\(adjustedCount) keyframe\(adjustedCount == 1 ? "" : "s") manually refined after auto-detection.")
        }

        let orderedKeyframes = record.keyFrames.sorted { lhs, rhs in
            (SwingPhase.allCases.firstIndex(of: lhs.phase) ?? 0) < (SwingPhase.allCases.firstIndex(of: rhs.phase) ?? 0)
        }
        let frameIndexes = orderedKeyframes.map(\.frameIndex)
        if frameIndexes != frameIndexes.sorted() {
            issues.append("The saved keyframe order is no longer strictly increasing. Recheck the swing checkpoints.")
        }

        let timingMetrics = timingMetrics(for: record)
        let anchorMetrics = anchorMetrics(for: record)
        let coverageMetrics = coverageMetrics(for: record)
        let metrics = timingMetrics + anchorMetrics + coverageMetrics

        if let tempoMetric = metrics.first(where: { $0.title == "Tempo" }) {
            highlights.append("Current tempo profile is \(tempoMetric.value) with the existing checkpoints.")
        }

        if let returnMetric = metrics.first(where: { $0.title == "Impact Return" }) {
            highlights.append("Hands return to \(returnMetric.value) at impact relative to the address position.")
        }

        let summary: String
        if readiness == "Ready" {
            summary = "\(baseSummary) Full anchor coverage and path generation are complete, so the output layer is ready for review."
        } else if anchorCount > 0 {
            summary = "\(baseSummary) \(anchorCount) of \(SwingPhase.allCases.count) grip anchors are saved so far."
        } else {
            summary = baseSummary
        }

        return GarageInsightReport(
            readiness: readiness,
            summary: summary,
            highlights: uniqueStrings(highlights),
            issues: uniqueStrings(issues),
            metrics: metrics
        )
    }

    private static func timingMetrics(for record: SwingRecord) -> [GarageInsightMetric] {
        let backswing = duration(from: .address, to: .topOfBackswing, in: record)
        let downswing = duration(from: .topOfBackswing, to: .impact, in: record)
        let takeaway = duration(from: .address, to: .takeaway, in: record)

        var metrics: [GarageInsightMetric] = []
        metrics.append(
            GarageInsightMetric(
                title: "Takeaway",
                value: formattedSeconds(takeaway),
                detail: "Time from setup to takeaway."
            )
        )
        metrics.append(
            GarageInsightMetric(
                title: "Backswing",
                value: formattedSeconds(backswing),
                detail: "Time from address to the top of the swing."
            )
        )
        metrics.append(
            GarageInsightMetric(
                title: "Downswing",
                value: formattedSeconds(downswing),
                detail: "Time from the top of the swing to impact."
            )
        )

        if downswing > 0 {
            let tempo = backswing / downswing
            metrics.append(
                GarageInsightMetric(
                    title: "Tempo",
                    value: String(format: "%.2f:1", tempo),
                    detail: "Backswing to downswing timing ratio."
                )
            )
        }

        let averageConfidence = record.swingFrames.isEmpty
            ? 0
            : record.swingFrames.map(\.confidence).reduce(0, +) / Double(record.swingFrames.count)
        metrics.append(
            GarageInsightMetric(
                title: "Pose Confidence",
                value: String(format: "%.0f%%", averageConfidence * 100),
                detail: "Average confidence across sampled pose frames."
            )
        )
        return metrics
    }

    private static func anchorMetrics(for record: SwingRecord) -> [GarageInsightMetric] {
        guard record.pathPoints.isEmpty == false else {
            return []
        }

        var metrics: [GarageInsightMetric] = []
        if let span = pathSpan(for: record.pathPoints) {
            metrics.append(
                GarageInsightMetric(
                    title: "Path Window",
                    value: "\(span.width)% × \(span.height)%",
                    detail: "Normalized width and height of the traced grip path."
                )
            )
        }

        if let impactReturn = impactReturn(for: record) {
            metrics.append(
                GarageInsightMetric(
                    title: "Impact Return",
                    value: "\(impactReturn)%",
                    detail: "Distance between address and impact hand centers, scaled by shoulder width."
                )
            )
        }

        return metrics
    }

    private static func coverageMetrics(for record: SwingRecord) -> [GarageInsightMetric] {
        let totalPhases = SwingPhase.allCases.count
        let anchorCoverage = Int((Double(record.handAnchors.count) / Double(totalPhases)) * 100)
        let adjustedCount = record.keyFrames.filter { $0.source == .adjusted }.count
        return [
            GarageInsightMetric(
                title: "Anchor Coverage",
                value: "\(anchorCoverage)%",
                detail: "\(record.handAnchors.count) of \(totalPhases) grip checkpoints saved."
            ),
            GarageInsightMetric(
                title: "Adjusted Frames",
                value: "\(adjustedCount)",
                detail: "Keyframes manually moved after the automatic pass."
            )
        ]
    }

    private static func duration(from start: SwingPhase, to end: SwingPhase, in record: SwingRecord) -> Double {
        guard
            let startTime = timestamp(for: start, in: record),
            let endTime = timestamp(for: end, in: record)
        else {
            return 0
        }
        return max(endTime - startTime, 0)
    }

    private static func timestamp(for phase: SwingPhase, in record: SwingRecord) -> Double? {
        guard
            let keyFrame = record.keyFrames.first(where: { $0.phase == phase }),
            record.swingFrames.indices.contains(keyFrame.frameIndex)
        else {
            return nil
        }
        return record.swingFrames[keyFrame.frameIndex].timestamp
    }

    private static func pathSpan(for pathPoints: [PathPoint]) -> (width: Int, height: Int)? {
        guard
            let minX = pathPoints.map(\.x).min(),
            let maxX = pathPoints.map(\.x).max(),
            let minY = pathPoints.map(\.y).min(),
            let maxY = pathPoints.map(\.y).max()
        else {
            return nil
        }

        return (
            width: Int(((maxX - minX) * 100).rounded()),
            height: Int(((maxY - minY) * 100).rounded())
        )
    }

    private static func impactReturn(for record: SwingRecord) -> Int? {
        guard
            let addressFrame = frame(for: .address, in: record),
            let impactFrame = frame(for: .impact, in: record)
        else {
            return nil
        }

        let addressHands = GarageAnalysisPipeline.handCenter(in: addressFrame)
        let impactHands = GarageAnalysisPipeline.handCenter(in: impactFrame)
        let shoulderWidth = GarageAnalysisPipeline.bodyScale(in: addressFrame)
        guard shoulderWidth > 0 else {
            return nil
        }

        let returnDistance = GarageAnalysisPipeline.distance(from: addressHands, to: impactHands)
        return Int(((returnDistance / shoulderWidth) * 100).rounded())
    }

    private static func frame(for phase: SwingPhase, in record: SwingRecord) -> SwingFrame? {
        guard
            let keyFrame = record.keyFrames.first(where: { $0.phase == phase }),
            record.swingFrames.indices.contains(keyFrame.frameIndex)
        else {
            return nil
        }
        return record.swingFrames[keyFrame.frameIndex]
    }

    private static func formattedSeconds(_ value: Double) -> String {
        String(format: "%.2fs", value)
    }

    private static func uniqueStrings(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}

enum GarageStability {
    static func score(for record: SwingRecord) -> Int? {
        guard let scoringWindow = scoringWindow(in: record) else {
            return nil
        }

        let frames = Array(record.swingFrames[scoringWindow])
        guard
            let addressFrame = frames.first,
            let addressHead = addressFrame.point(named: .nose, minimumConfidence: 0.5),
            let addressPelvis = pelvisCenter(in: addressFrame, minimumConfidence: 0.5)
        else {
            return nil
        }

        let shoulderWidth = GarageAnalysisPipeline.bodyScale(in: addressFrame)
        guard shoulderWidth > 0 else {
            return nil
        }

        var unreliableFrameCount = 0
        var maxHeadHorizontalDrift = 0.0
        var maxHeadVerticalDrift = 0.0
        var maxPelvisHorizontalDrift = 0.0
        var maxPelvisVerticalDrift = 0.0

        for frame in frames {
            guard
                let head = frame.point(named: .nose, minimumConfidence: 0.5),
                let pelvis = pelvisCenter(in: frame, minimumConfidence: 0.5)
            else {
                unreliableFrameCount += 1
                continue
            }

            maxHeadHorizontalDrift = max(maxHeadHorizontalDrift, abs(head.x - addressHead.x))
            maxHeadVerticalDrift = max(maxHeadVerticalDrift, abs(head.y - addressHead.y))
            maxPelvisHorizontalDrift = max(maxPelvisHorizontalDrift, abs(pelvis.x - addressPelvis.x))
            maxPelvisVerticalDrift = max(maxPelvisVerticalDrift, abs(pelvis.y - addressPelvis.y))
        }

        let unreliableRatio = Double(unreliableFrameCount) / Double(frames.count)
        guard unreliableRatio <= 0.3 else {
            return nil
        }

        let headHorizontalRatio = min(maxHeadHorizontalDrift / shoulderWidth, 1)
        let headVerticalRatio = min(maxHeadVerticalDrift / shoulderWidth, 1)
        let pelvisHorizontalRatio = min(maxPelvisHorizontalDrift / shoulderWidth, 1)
        let pelvisVerticalRatio = min(maxPelvisVerticalDrift / shoulderWidth, 1)

        let totalPenalty = min(
            100,
            (headHorizontalRatio * 90) +
                (headVerticalRatio * 72) +
                (pelvisHorizontalRatio * 80) +
                (pelvisVerticalRatio * 56)
        )

        return Int((100 - totalPenalty).rounded())
    }

    private static func scoringWindow(in record: SwingRecord) -> ClosedRange<Int>? {
        guard
            let addressIndex = keyFrameIndex(for: .address, in: record),
            let impactIndex = keyFrameIndex(for: .impact, in: record),
            addressIndex <= impactIndex
        else {
            return nil
        }

        return addressIndex...impactIndex
    }

    private static func keyFrameIndex(for phase: SwingPhase, in record: SwingRecord) -> Int? {
        guard
            let keyFrame = record.keyFrames.first(where: { $0.phase == phase }),
            record.swingFrames.indices.contains(keyFrame.frameIndex)
        else {
            return nil
        }

        return keyFrame.frameIndex
    }

    private static func pelvisCenter(in frame: SwingFrame, minimumConfidence: Double) -> CGPoint? {
        guard
            let leftHip = frame.point(named: .leftHip, minimumConfidence: minimumConfidence),
            let rightHip = frame.point(named: .rightHip, minimumConfidence: minimumConfidence)
        else {
            return nil
        }

        return CGPoint(x: (leftHip.x + rightHip.x) / 2, y: (leftHip.y + rightHip.y) / 2)
    }
}

enum GarageReliability {
    static func report(for record: SwingRecord) -> GarageReliabilityReport {
        let reviewSource = GarageMediaStore.reviewFrameSource(for: record)
        let hasFrames = record.swingFrames.isEmpty == false
        let reviewReady = reviewSource != .recoveryNeeded && hasFrames
        let hasAllKeyframes = record.keyFrames.count == SwingPhase.allCases.count
        let monotonicKeyframes = GarageWorkflow.keyframeSequenceIsMonotonic(record.keyFrames)
        let validationApproved = record.keyframeValidationStatus == .approved
        let fullAnchorCoverage = record.handAnchors.count == SwingPhase.allCases.count
        let pathGenerated = record.pathPoints.isEmpty == false
        let averageConfidence = record.swingFrames.isEmpty
            ? 0
            : record.swingFrames.map(\.confidence).reduce(0, +) / Double(record.swingFrames.count)
        let confidenceStrong = averageConfidence >= 0.55
        let adjustedFrames = record.keyFrames.filter { $0.source == .adjusted }.count
        let limitedManualAdjustment = adjustedFrames <= 2
        let videoSourceDetail: String

        switch reviewSource {
        case .video:
            videoSourceDetail = "Stored video and sampled pose frames are available."
        case .poseFallback:
            videoSourceDetail = "Stored video is missing, but sampled pose frames can still power checkpoint review."
        case .recoveryNeeded:
            videoSourceDetail = "Garage cannot fully verify this swing until either the stored video or fallback-ready pose frames are available."
        }

        let checks = [
            GarageReliabilityCheck(
                title: "Video Source",
                passed: reviewReady,
                detail: videoSourceDetail
            ),
            GarageReliabilityCheck(
                title: "Keyframe Coverage",
                passed: hasAllKeyframes && monotonicKeyframes,
                detail: hasAllKeyframes && monotonicKeyframes
                    ? "All 8 checkpoints are present in the expected swing order."
                    : "One or more swing checkpoints are missing or out of order."
            ),
            GarageReliabilityCheck(
                title: "Review Status",
                passed: validationApproved,
                detail: validationApproved
                    ? "The keyframe review is approved."
                    : "The keyframe review still needs confirmation before this swing should be treated as trustworthy."
            ),
            GarageReliabilityCheck(
                title: "Grip Coverage",
                passed: fullAnchorCoverage && pathGenerated,
                detail: fullAnchorCoverage && pathGenerated
                    ? "All 8 grip anchors are saved and the path is generated."
                    : "Anchor coverage or path generation is incomplete."
            ),
            GarageReliabilityCheck(
                title: "Pose Confidence",
                passed: confidenceStrong,
                detail: confidenceStrong
                    ? "Average pose confidence is \(String(format: "%.0f%%", averageConfidence * 100))."
                    : "Average pose confidence is only \(String(format: "%.0f%%", averageConfidence * 100)), so detections may be noisy."
            ),
            GarageReliabilityCheck(
                title: "Manual Adjustments",
                passed: limitedManualAdjustment,
                detail: limitedManualAdjustment
                    ? "Manual keyframe changes are limited."
                    : "\(adjustedFrames) checkpoints were manually adjusted, which lowers trust in the automatic pass."
            )
        ]

        let weightedChecks: [(GarageReliabilityCheck, Int)] = Array(zip(checks, [15, 20, 20, 25, 10, 10]))
        let score = weightedChecks.reduce(0) { partial, item in
            partial + (item.0.passed ? item.1 : 0)
        }
        let status: GarageReliabilityStatus
        if score >= 84 {
            status = .trusted
        } else if score >= 50 {
            status = .review
        } else {
            status = .provisional
        }

        let summary: String
        switch status {
        case .trusted:
            summary = "This swing has strong coverage across video, checkpoints, anchors, and path generation."
        case .review:
            summary = "This swing is usable, but one or more checks still need review before you trust the output fully."
        case .provisional:
            summary = "This swing is still provisional. Fix the failed checks before relying on the analysis."
        }

        return GarageReliabilityReport(score: score, status: status, summary: summary, checks: checks)
    }
}

enum GarageCoaching {
    static func report(for record: SwingRecord) -> GarageCoachingReport {
        let insightReport = GarageInsights.report(for: record)
        let reliabilityReport = GarageReliability.report(for: record)
        let syncFlow = record.analysisResult?.syncFlow

        if reliabilityReport.status == .provisional {
            return GarageCoachingReport(
                headline: "Hold interpretation until the swing is more complete.",
                confidenceLabel: reliabilityReport.status.rawValue,
                cues: [],
                blockers: provisionalBlockers(from: reliabilityReport, insightReport: insightReport),
                nextBestAction: "Fix the failed reliability checks before using coaching cues."
            )
        }

        var cues: [GarageCoachingCue] = []
        var syncFlowCue: GarageCoachingCue?

        if let syncFlow, syncFlow.status == .ready {
            if let primaryIssue = syncFlow.primaryIssue {
                syncFlowCue = GarageCoachingCue(
                    title: primaryIssue.title,
                    message: primaryIssue.detail,
                    severity: .caution
                )
            } else {
                syncFlowCue = GarageCoachingCue(
                    title: "Flow Looks Clean",
                    message: syncFlow.summary,
                    severity: .positive
                )
            }
        }

        if let tempo = metricValue(named: "Tempo", in: insightReport),
           let tempoValue = Double(tempo.replacingOccurrences(of: ":1", with: "")) {
            if tempoValue >= 2.7 && tempoValue <= 3.3 {
                cues.append(
                    GarageCoachingCue(
                        title: "Tempo Is Balanced",
                        message: "Backswing-to-downswing timing is staying in a stable range. Preserve this rhythm as you refine the rest of the motion.",
                        severity: .positive
                    )
                )
            } else if tempoValue > 3.3 {
                cues.append(
                    GarageCoachingCue(
                        title: "Backswing Is Running Long",
                        message: "The current tempo suggests the backswing is taking too long relative to the downswing. Shorten the top slightly before adding more speed.",
                        severity: .caution
                    )
                )
            } else {
                cues.append(
                    GarageCoachingCue(
                        title: "Transition Looks Rushed",
                        message: "The current tempo is compressed. Give the backswing more time so the downswing does not feel abrupt.",
                        severity: .caution
                    )
                )
            }
        }

        if let impactReturn = metricPercentValue(named: "Impact Return", in: insightReport) {
            if impactReturn <= 25 {
                cues.append(
                    GarageCoachingCue(
                        title: "Impact Return Is Tight",
                        message: "Your hands are returning close to the address position at impact. Keep that repeatable reference while refining other pieces.",
                        severity: .positive
                    )
                )
            } else if impactReturn >= 45 {
                cues.append(
                    GarageCoachingCue(
                        title: "Impact Return Is Drifting",
                        message: "Hand return at impact is far from address. Recheck setup and transition control before trusting strike-direction feedback.",
                        severity: .caution
                    )
                )
            } else {
                cues.append(
                    GarageCoachingCue(
                        title: "Impact Return Is Usable",
                        message: "The current return distance is workable, but it still leaves room for a tighter delivery into impact.",
                        severity: .info
                    )
                )
            }
        }

        if let pathWindow = metricWindow(named: "Path Window", in: insightReport) {
            if pathWindow.width >= 35 || pathWindow.height >= 55 {
                cues.append(
                    GarageCoachingCue(
                        title: "Hand Path Is Expanding",
                        message: "The current grip path window is relatively large. Keep the motion simpler before layering in more speed or shape changes.",
                        severity: .caution
                    )
                )
            } else if pathWindow.width <= 18 && pathWindow.height <= 28 {
                cues.append(
                    GarageCoachingCue(
                        title: "Hand Path Looks Compact",
                        message: "The current path stays fairly compact through the measured checkpoints. That gives you a clean baseline to repeat.",
                        severity: .positive
                    )
                )
            } else {
                cues.append(
                    GarageCoachingCue(
                        title: "Hand Path Needs Monitoring",
                        message: "The current path shape is readable, but keep comparing it against future swings before making a bigger change from this alone.",
                        severity: .info
                    )
                )
            }
        }

        if let adjustedFrames = metricIntegerValue(named: "Adjusted Frames", in: insightReport), adjustedFrames >= 3 {
            cues.append(
                GarageCoachingCue(
                    title: "Heavy Manual Review",
                    message: "\(adjustedFrames) keyframes were manually adjusted. Treat this coaching as directional until the automatic pass becomes more stable.",
                    severity: .caution
                )
            )
        }

        let blockers = reliabilityReport.status == .review
            ? reviewBlockers(from: reliabilityReport, insightReport: insightReport)
            : []

        var sortedCues = cues.sorted { lhs, rhs in
            severityPriority(lhs.severity) > severityPriority(rhs.severity)
        }
        if let syncFlowCue {
            sortedCues.removeAll(where: { $0.title == syncFlowCue.title && $0.message == syncFlowCue.message })
            sortedCues.insert(syncFlowCue, at: 0)
        }

        let headline: String
        if let topCue = sortedCues.first {
            headline = topCue.title
        } else {
            headline = "The swing has usable data, but no strong coaching cue stands out yet."
        }

        let nextBestAction: String
        if reliabilityReport.status == .review {
            nextBestAction = "Use the cues directionally, but resolve the review notes before treating them as final."
        } else if let cautionCue = sortedCues.first(where: { $0.severity == .caution }) {
            nextBestAction = cautionCue.message
        } else {
            nextBestAction = "Keep building comparable swings so SyncFlow can confirm the strongest movement patterns."
        }

        return GarageCoachingReport(
            headline: headline,
            confidenceLabel: reliabilityReport.status.rawValue,
            cues: Array(sortedCues.prefix(3)),
            blockers: blockers,
            nextBestAction: nextBestAction
        )
    }

    private static func provisionalBlockers(
        from reliabilityReport: GarageReliabilityReport,
        insightReport: GarageInsightReport
    ) -> [String] {
        let failedChecks = reliabilityReport.checks
            .filter { $0.passed == false }
            .map(\.detail)
        return Array((failedChecks + insightReport.issues).prefix(3))
    }

    private static func reviewBlockers(
        from reliabilityReport: GarageReliabilityReport,
        insightReport: GarageInsightReport
    ) -> [String] {
        let failedChecks = reliabilityReport.checks
            .filter { $0.passed == false }
            .map(\.detail)
        return Array((failedChecks + insightReport.issues).prefix(2))
    }

    private static func metricValue(named title: String, in report: GarageInsightReport) -> String? {
        report.metrics.first(where: { $0.title == title })?.value
    }

    private static func metricPercentValue(named title: String, in report: GarageInsightReport) -> Int? {
        guard let value = metricValue(named: title, in: report)?
            .replacingOccurrences(of: "%", with: "") else {
            return nil
        }
        return Int(value)
    }

    private static func metricIntegerValue(named title: String, in report: GarageInsightReport) -> Int? {
        guard let value = metricValue(named: title, in: report) else {
            return nil
        }
        return Int(value)
    }

    private static func metricWindow(named title: String, in report: GarageInsightReport) -> (width: Int, height: Int)? {
        guard let value = metricValue(named: title, in: report) else {
            return nil
        }
        let pieces = value.components(separatedBy: "×").map {
            $0.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)
        }
        guard pieces.count == 2, let width = Int(pieces[0]), let height = Int(pieces[1]) else {
            return nil
        }
        return (width, height)
    }

    private static func severityPriority(_ severity: GarageCoachingSeverity) -> Int {
        switch severity {
        case .caution:
            3
        case .positive:
            2
        case .info:
            1
        }
    }
}

enum GarageWorkflow {
    static func progress(for record: SwingRecord) -> GarageWorkflowProgress {
        let insightReport = GarageInsights.report(for: record)
        let reliabilityReport = GarageReliability.report(for: record)
        let stages = [
            importStage(for: record),
            keyframeStage(for: record),
            anchorStage(for: record),
            insightStage(for: record, insightReport: insightReport, reliabilityReport: reliabilityReport)
        ]

        let prioritizedStage = stages.first(where: { $0.status == .needsAttention })
            ?? stages.first(where: { $0.status == .incomplete })

        let nextAction: GarageWorkflowNextAction
        if let prioritizedStage {
            nextAction = GarageWorkflowNextAction(
                title: prioritizedStage.stage.title,
                body: prioritizedStage.summary,
                actionLabel: prioritizedStage.actionLabel,
                stage: prioritizedStage.stage
            )
        } else {
            nextAction = GarageWorkflowNextAction(
                title: "Workflow Complete",
                body: "All four Garage stages are complete. Review the current insight output and only revisit earlier stages if reliability issues appear.",
                actionLabel: "Review insights",
                stage: .reviewInsights
            )
        }

        return GarageWorkflowProgress(stages: stages, nextAction: nextAction)
    }

    private static func importStage(for record: SwingRecord) -> GarageWorkflowStageState {
        let hasVideoReference = record.preferredReviewFilename != nil
            || record.reviewMasterBookmark != nil
            || record.mediaFileBookmark != nil
            || record.exportAssetBookmark != nil
        let hasFrames = record.swingFrames.isEmpty == false
        let reviewSource = GarageMediaStore.reviewFrameSource(for: record)

        let status: GarageWorkflowStatus
        let summary: String
        let actionLabel: String

        if hasVideoReference == false, hasFrames == false {
            status = .incomplete
            summary = "Import one swing video to initialize Garage."
            actionLabel = "Import video"
        } else if hasFrames == false {
            status = .needsAttention
            summary = "The video reference exists, but Garage cannot currently use it for the workflow."
            actionLabel = "Re-import video"
        } else if reviewSource == .recoveryNeeded {
            status = .complete
            summary = "Sampled pose frames are still available, so Garage can review checkpoints with a fallback pose view while the stored video is recovered."
            actionLabel = "Pose fallback ready"
        } else {
            status = .complete
            summary = "A swing video is available and sampled pose frames were generated."
            actionLabel = "Video ready"
        }

        return GarageWorkflowStageState(stage: .importVideo, status: status, summary: summary, actionLabel: actionLabel)
    }

    private static func keyframeStage(for record: SwingRecord) -> GarageWorkflowStageState {
        let hasAllKeyframes = record.keyFrames.count == SwingPhase.allCases.count
        let keyframesMonotonic = keyframeSequenceIsMonotonic(record.keyFrames)

        let status: GarageWorkflowStatus
        let summary: String
        let actionLabel: String

        if hasAllKeyframes == false {
            status = .incomplete
            summary = "Garage needs all 8 swing checkpoints before the rest of the workflow can be trusted."
            actionLabel = "Finish keyframes"
        } else if record.keyframeValidationStatus == .flagged || keyframesMonotonic == false {
            status = .needsAttention
            summary = "Review the saved keyframes before trusting anchors or downstream insights."
            actionLabel = "Review keyframes"
        } else if record.keyframeValidationStatus == .approved {
            status = .complete
            summary = "All 8 keyframes are present and the current checkpoint review is approved."
            actionLabel = "Keyframes approved"
        } else {
            status = .incomplete
            summary = "All 8 keyframes exist, but they are still pending review."
            actionLabel = "Approve keyframes"
        }

        return GarageWorkflowStageState(stage: .validateKeyframes, status: status, summary: summary, actionLabel: actionLabel)
    }

    private static func anchorStage(for record: SwingRecord) -> GarageWorkflowStageState {
        let uniquePhases = Set(record.handAnchors.map(\.phase))
        let hasAllAnchors = record.handAnchors.count == SwingPhase.allCases.count
        let uniqueCoverage = uniquePhases.count == record.handAnchors.count

        let status: GarageWorkflowStatus
        let summary: String
        let actionLabel: String

        if hasAllAnchors == false {
            let remaining = max(SwingPhase.allCases.count - record.handAnchors.count, 0)
            status = .incomplete
            summary = "\(remaining) grip anchor\(remaining == 1 ? "" : "s") still need to be marked."
            actionLabel = "Place anchors"
        } else if uniqueCoverage == false || record.pathPoints.isEmpty {
            status = .needsAttention
            summary = "Anchor coverage is inconsistent or the path did not generate after all 8 anchors were placed."
            actionLabel = "Review anchors"
        } else {
            status = .complete
            summary = "All 8 grip anchors are saved and the hand path is ready for review."
            actionLabel = "Anchors complete"
        }

        return GarageWorkflowStageState(stage: .markAnchors, status: status, summary: summary, actionLabel: actionLabel)
    }

    private static func insightStage(
        for record: SwingRecord,
        insightReport: GarageInsightReport,
        reliabilityReport: GarageReliabilityReport
    ) -> GarageWorkflowStageState {
        let priorStagesComplete = importStage(for: record).status == .complete
            && keyframeStage(for: record).status == .complete
            && anchorStage(for: record).status == .complete

        let status: GarageWorkflowStatus
        let summary: String
        let actionLabel: String

        if priorStagesComplete == false {
            status = .incomplete
            summary = "Insights unlock after the earlier workflow stages are complete."
            actionLabel = "Finish earlier steps"
        } else if insightReport.isReady == false || insightReport.issues.isEmpty == false || reliabilityReport.needsAttention {
            status = .needsAttention
            summary = "Insights are available, but reliability checks still need review before you treat them as final."
            actionLabel = "Review insight notes"
        } else {
            status = .complete
            summary = "The workflow is complete and the current insight output is ready for review."
            actionLabel = "Review insights"
        }

        return GarageWorkflowStageState(stage: .reviewInsights, status: status, summary: summary, actionLabel: actionLabel)
    }

    static func keyframeSequenceIsMonotonic(_ keyFrames: [KeyFrame]) -> Bool {
        let ordered = keyFrames.sorted { lhs, rhs in
            (SwingPhase.allCases.firstIndex(of: lhs.phase) ?? 0) < (SwingPhase.allCases.firstIndex(of: rhs.phase) ?? 0)
        }
        let frameIndexes = ordered.map(\.frameIndex)
        return frameIndexes == frameIndexes.sorted()
    }
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
            "The video did not produce enough pose frames for keyframe detection."
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
        let directoryURL = try garageDirectoryURL(for: .reviewMaster)
        let ext = sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension
        let destinationURL = directoryURL.appendingPathComponent("\(UUID().uuidString).\(ext)")

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        do {
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            return destinationURL
        } catch {
            throw GarageAnalysisError.failedToPersistVideo
        }
    }

    static func createExportDerivative(from reviewMasterURL: URL) async -> URL? {
        let asset = AVURLAsset(url: reviewMasterURL)
        guard
            let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetMediumQuality),
            exportSession.supportedFileTypes.contains(.mp4)
        else {
            return nil
        }

        guard let directoryURL = try? garageDirectoryURL(for: .exportAsset) else {
            return nil
        }

        let destinationURL = directoryURL.appendingPathComponent("\(UUID().uuidString).mp4")
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try? FileManager.default.removeItem(at: destinationURL)
        }

        exportSession.outputURL = destinationURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true

        await withCheckedContinuation { continuation in
            exportSession.exportAsynchronously {
                continuation.resume()
            }
        }

        switch exportSession.status {
        case .completed:
            return destinationURL
        default:
            try? FileManager.default.removeItem(at: destinationURL)
            return nil
        }
    }

    static func persistedVideoURL(for filename: String?) -> URL? {
        guard let filename, filename.isEmpty == false else {
            return nil
        }

        for kind in [GarageStoredAssetKind.reviewMaster, .legacyRoot, .exportAsset] {
            if let url = persistedAssetURL(for: filename, kind: kind) {
                return url
            }
        }

        return nil
    }

    static func bookmarkData(for url: URL) -> Data? {
        try? url.bookmarkData()
    }

    static func resolvedReviewVideo(for record: SwingRecord) -> GarageResolvedReviewVideo? {
        let candidates: [(GarageResolvedReviewVideoOrigin, URL?)] = [
            (.reviewMasterStorage, record.reviewMasterFilename.flatMap { persistedAssetURL(for: $0, kind: .reviewMaster) }),
            (.reviewMasterBookmark, resolvedBookmarkURL(from: record.reviewMasterBookmark)),
            (.legacyMediaStorage, record.mediaFilename.flatMap { persistedAssetURL(for: $0, kind: .legacyRoot) }),
            (.legacyMediaBookmark, resolvedBookmarkURL(from: record.mediaFileBookmark)),
            (.exportStorage, record.preferredExportFilename.flatMap { persistedAssetURL(for: $0, kind: .exportAsset) }),
            (.exportBookmark, resolvedBookmarkURL(from: record.exportAssetBookmark))
        ]

        for (origin, url) in candidates {
            if let url {
                return GarageResolvedReviewVideo(url: url, origin: origin)
            }
        }

        return nil
    }

    static func resolvedReviewVideoURL(for record: SwingRecord) -> URL? {
        resolvedReviewVideo(for: record)?.url
    }

    static func reviewFrameSource(for record: SwingRecord) -> GarageReviewFrameSourceState {
        if resolvedReviewVideo(for: record) != nil {
            return .video
        }

        if record.swingFrames.isEmpty == false {
            return .poseFallback
        }

        return .recoveryNeeded
    }

    static func resolvedExportVideoURL(for record: SwingRecord) -> URL? {
        if let exportFilename = record.preferredExportFilename,
           let persistedURL = persistedAssetURL(for: exportFilename, kind: .exportAsset) {
            return persistedURL
        }

        return resolvedBookmarkURL(from: record.exportAssetBookmark)
    }

    static func thumbnail(
        for videoURL: URL,
        at timestamp: Double,
        maximumSize: CGSize = CGSize(width: 480, height: 480),
        priority: GarageThumbnailLoadPriority = .normal,
        exactFrame: Bool = false
    ) async -> CGImage? {
        let requestKey = garageThumbnailCacheKey(
            videoURL: videoURL,
            timestamp: timestamp,
            maximumSize: maximumSize,
            exactFrame: exactFrame
        )

        if let cachedImage = await GarageMediaStoreCache.shared.cachedThumbnail(for: requestKey) {
            return cachedImage
        }

        await GarageMediaStoreCache.shared.acquireThumbnailPermit(priority: priority)
        let image = await withCheckedContinuation { continuation in
            Task {
                let generator = await GarageMediaStoreCache.shared.imageGenerator(
                    for: videoURL,
                    maximumSize: maximumSize,
                    exactFrame: exactFrame
                )
                let time = CMTime(seconds: timestamp, preferredTimescale: 600)
                generator.generateCGImageAsynchronously(for: time) { image, _, _ in
                    continuation.resume(returning: image.flatMap(normalizedDisplayImage(from:)))
                }
            }
        }
        await GarageMediaStoreCache.shared.releaseThumbnailPermit()

        await GarageMediaStoreCache.shared.storeThumbnail(image, for: requestKey)
        return image
    }

    static func prefetchThumbnails(
        for videoURL: URL,
        requests: [GarageThumbnailRequest],
        priority: GarageThumbnailLoadPriority = .low
    ) async {
        var seen = Set<GarageThumbnailRequest>()

        for request in requests where seen.insert(request).inserted {
            guard Task.isCancelled == false else { return }
            _ = await thumbnail(
                for: videoURL,
                at: request.timestamp,
                maximumSize: request.maximumSize,
                priority: priority
            )
        }
    }

    static func assetMetadata(for videoURL: URL) async -> GarageVideoAssetMetadata? {
        if let cachedMetadata = await GarageMediaStoreCache.shared.assetMetadata(for: videoURL) {
            return cachedMetadata
        }

        do {
            let asset = AVURLAsset(url: videoURL)
            let duration = try await asset.load(.duration)
            let tracks = try await asset.loadTracks(withMediaType: .video)
            guard let track = tracks.first else {
                return nil
            }

            let naturalSize = try await track.load(.naturalSize)
            let transform = try await track.load(.preferredTransform)
            let transformedSize = naturalSize.applying(transform)
            let nominalFrameRate = try await track.load(.nominalFrameRate)

            let metadata = GarageVideoAssetMetadata(
                duration: max(CMTimeGetSeconds(duration), 0),
                frameRate: nominalFrameRate > 0 ? Double(nominalFrameRate) : 0,
                naturalSize: CGSize(width: abs(transformedSize.width), height: abs(transformedSize.height))
            )
            await GarageMediaStoreCache.shared.storeAssetMetadata(metadata, for: videoURL)
            return metadata
        } catch {
            return nil
        }
    }

    private static func persistedAssetURL(for filename: String, kind: GarageStoredAssetKind) -> URL? {
        guard let directoryURL = try? garageDirectoryURL(for: kind) else {
            return nil
        }

        let url = directoryURL.appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private static func resolvedBookmarkURL(from bookmarkData: Data?) -> URL? {
        guard let bookmarkData else {
            return nil
        }

        var isStale = false
        guard let resolvedURL = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withoutUI, .withoutMounting],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return nil
        }

        return FileManager.default.fileExists(atPath: resolvedURL.path) ? resolvedURL : nil
    }

    private static func garageDirectoryURL(for kind: GarageStoredAssetKind) throws -> URL {
        let baseURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let rootURL = baseURL.appendingPathComponent("GarageSwingVideos", isDirectory: true)
        let garageURL: URL
        switch kind {
        case .legacyRoot:
            garageURL = rootURL
        case .reviewMaster:
            garageURL = rootURL.appendingPathComponent("ReviewMasters", isDirectory: true)
        case .exportAsset:
            garageURL = rootURL.appendingPathComponent("Exports", isDirectory: true)
        }
        if FileManager.default.fileExists(atPath: garageURL.path) == false {
            try FileManager.default.createDirectory(at: garageURL, withIntermediateDirectories: true)
        }
        return garageURL
    }

    nonisolated private static func normalizedDisplayImage(from image: CGImage) -> CGImage? {
        let colorSpace = image.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        guard
            let context = CGContext(
                data: nil,
                width: image.width,
                height: image.height,
                bitsPerComponent: image.bitsPerComponent,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: image.bitmapInfo.rawValue
            )
        else {
            return image
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return context.makeImage() ?? image
    }
    private static func garageThumbnailCacheKey(videoURL: URL, timestamp: Double, maximumSize: CGSize) -> String {
        garageThumbnailCacheKey(videoURL: videoURL, timestamp: timestamp, maximumSize: maximumSize, exactFrame: false)
    }

    private static func garageThumbnailCacheKey(
        videoURL: URL,
        timestamp: Double,
        maximumSize: CGSize,
        exactFrame: Bool
    ) -> String {
        let timestampBucket = Int((timestamp * 30).rounded())
        let maxPixelWidth = Int(maximumSize.width.rounded())
        let maxPixelHeight = Int(maximumSize.height.rounded())
        let frameMode = exactFrame ? "exact" : "approx"
        return "\(videoURL.absoluteString)#\(timestampBucket)#\(maxPixelWidth)x\(maxPixelHeight)#\(frameMode)"
    }
}

private actor GarageMediaStoreCache {
    static let shared = GarageMediaStoreCache()

    private var generators: [String: AVAssetImageGenerator] = [:]
    private var thumbnailCache: [String: CGImage] = [:]
    private var thumbnailCacheOrder: [String] = []
    private var assetMetadataCache: [URL: GarageVideoAssetMetadata] = [:]
    private var availableThumbnailPermits = 2
    private var highPriorityThumbnailWaiters: [CheckedContinuation<Void, Never>] = []
    private var normalPriorityThumbnailWaiters: [CheckedContinuation<Void, Never>] = []
    private var lowPriorityThumbnailWaiters: [CheckedContinuation<Void, Never>] = []

    func cachedThumbnail(for requestKey: String) -> CGImage? {
        thumbnailCache[requestKey]
    }

    func storeThumbnail(_ image: CGImage?, for requestKey: String) {
        guard let image else { return }

        if thumbnailCache[requestKey] == nil {
            thumbnailCacheOrder.append(requestKey)
        }

        if thumbnailCacheOrder.count > 96 {
            let oldestKey = thumbnailCacheOrder.removeFirst()
            thumbnailCache.removeValue(forKey: oldestKey)
        }
        thumbnailCache[requestKey] = image
    }

    func acquireThumbnailPermit(priority: GarageThumbnailLoadPriority) async {
        guard availableThumbnailPermits == 0 else {
            availableThumbnailPermits -= 1
            return
        }

        await withCheckedContinuation { continuation in
            switch priority {
            case .high:
                highPriorityThumbnailWaiters.append(continuation)
            case .normal:
                normalPriorityThumbnailWaiters.append(continuation)
            case .low:
                lowPriorityThumbnailWaiters.append(continuation)
            }
        }
    }

    func releaseThumbnailPermit() {
        if highPriorityThumbnailWaiters.isEmpty == false {
            let continuation = highPriorityThumbnailWaiters.removeFirst()
            continuation.resume()
            return
        }

        if normalPriorityThumbnailWaiters.isEmpty == false {
            let continuation = normalPriorityThumbnailWaiters.removeFirst()
            continuation.resume()
            return
        }

        if lowPriorityThumbnailWaiters.isEmpty == false {
            let continuation = lowPriorityThumbnailWaiters.removeFirst()
            continuation.resume()
            return
        }

        availableThumbnailPermits += 1
    }

    func imageGenerator(for videoURL: URL, maximumSize: CGSize, exactFrame: Bool) -> AVAssetImageGenerator {
        let generatorKey = [
            videoURL.absoluteString,
            "\(Int(maximumSize.width.rounded()))x\(Int(maximumSize.height.rounded()))",
            exactFrame ? "exact" : "approx"
        ].joined(separator: "#")

        if let existingGenerator = generators[generatorKey] {
            return existingGenerator
        }

        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = maximumSize
        if exactFrame {
            generator.requestedTimeToleranceAfter = .zero
            generator.requestedTimeToleranceBefore = .zero
        } else {
            generator.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 30)
            generator.requestedTimeToleranceBefore = CMTime(value: 1, timescale: 30)
        }

        generators[generatorKey] = generator
        return generator
    }

    func assetMetadata(for videoURL: URL) -> GarageVideoAssetMetadata? {
        assetMetadataCache[videoURL]
    }

    func storeAssetMetadata(_ metadata: GarageVideoAssetMetadata, for videoURL: URL) {
        assetMetadataCache[videoURL] = metadata
    }
}

private enum GarageStoredAssetKind {
    case legacyRoot
    case reviewMaster
    case exportAsset
}

enum GarageAnalysisPipeline {
    private enum KinematicThresholds {
        static let reversalVelocityEpsilon = 0.015
        static let impactSpeedQuantile = 0.82
        static let impactLowerPathQuantile = 0.62
        static let impactWindow = 2
    }

    private static let maximumSamplingFrameRate = 30.0
    private static let maximumSampledFrameCount = 120

    static func analyzeVideo(
        at videoURL: URL,
        progress: (@MainActor @Sendable (GarageAnalysisProgressUpdate) async -> Void)? = nil
    ) async throws -> GarageAnalysisOutput {
        await progress?(GarageAnalysisProgressUpdate(step: .loadingVideo))
        let asset = AVURLAsset(url: videoURL)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = tracks.first else {
            throw GarageAnalysisError.missingVideoTrack
        }

        let duration = try await asset.load(.duration)
        let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
        let samplingFrameRate = resolvedSamplingFrameRate(from: nominalFrameRate)
        let timestamps = sampledTimestamps(duration: duration, frameRate: samplingFrameRate)
        let totalFrames = timestamps.count
        await progress?(GarageAnalysisProgressUpdate(step: .samplingFrames, totalFrames: totalFrames))
        await progress?(GarageAnalysisProgressUpdate(step: .detectingBody, totalFrames: totalFrames))
        let extraction = try await extractPoseFrames(from: asset, timestamps: timestamps) { processedFrameCount in
            await progress?(
                GarageAnalysisProgressUpdate(
                    step: .detectingBody,
                    frameCount: processedFrameCount,
                    totalFrames: totalFrames
                )
            )
        }
        let extractedFrames = extraction.frames
        let smoothedFrames = smooth(frames: extractedFrames)

        guard smoothedFrames.count >= SwingPhase.allCases.count else {
            throw GarageAnalysisError.insufficientPoseFrames
        }

        await progress?(
            GarageAnalysisProgressUpdate(
                step: .mappingCheckpoints,
                frameCount: totalFrames,
                totalFrames: totalFrames
            )
        )
        let keyFrames = detectKeyFrames(from: smoothedFrames)
        let handAnchors = deriveHandAnchors(from: smoothedFrames, keyFrames: keyFrames)
        let pathPoints = generatePathPoints(from: smoothedFrames, samplesPerSegment: 8)
        let handPathReviewReport = handPathReviewReport(for: smoothedFrames, keyFrames: keyFrames)
        let scorecard = GarageScorecardEngine.generate(frames: smoothedFrames, keyFrames: keyFrames)
        let syncFlow = GarageSyncFlowEngine.generate(
            frames: smoothedFrames,
            keyFrames: keyFrames,
            scorecard: scorecard
        )
        let analysisIssues = scorecard == nil
            ? [GarageScorecardEngine.unavailableMessage]
            : []
        var analysisHighlights = [
            "Eight deterministic keyframes detected from normalized pose frames.",
            "\(handAnchors.count) hand checkpoints are aligned to the saved review phases."
        ]
        if extraction.metadata.usedZeroCopyReader {
            analysisHighlights.append("Pose extraction used the zero-copy AVAssetReader pipeline.")
        }
        if extraction.metadata.includes3DFrames {
            analysisHighlights.append("3D pose enrichment was available for depth-sensitive analysis.")
        }

        let analysisResult = AnalysisResult(
            issues: analysisIssues,
            highlights: analysisHighlights,
            summary: "Processed \(smoothedFrames.count) frames at \(Int(samplingFrameRate.rounded())) FPS and prepared a DTL scorecard for Step 2.",
            scorecard: scorecard,
            syncFlow: syncFlow
        )

        return GarageAnalysisOutput(
            frameRate: samplingFrameRate,
            swingFrames: smoothedFrames,
            keyFrames: keyFrames,
            handAnchors: handAnchors,
            pathPoints: pathPoints,
            handPathReviewReport: handPathReviewReport,
            analysisResult: analysisResult,
            syncFlow: syncFlow
        )
    }

    static func resolvedSamplingFrameRate(from nominalFrameRate: Float) -> Double {
        let baseRate = nominalFrameRate > 0 ? Double(nominalFrameRate) : 30
        return min(baseRate, maximumSamplingFrameRate)
    }

    static func sampledTimestamps(duration: CMTime, frameRate: Double) -> [Double] {
        let seconds = max(CMTimeGetSeconds(duration), 0)
        guard seconds > 0 else { return [] }

        let interval = 1 / max(frameRate, 1)
        var timestamps: [Double] = []
        var current: Double = 0
        while current < seconds {
            timestamps.append(current)
            current += interval
        }

        if let last = timestamps.last, seconds - last > 0.01 {
            timestamps.append(seconds)
        }

        if timestamps.count > maximumSampledFrameCount {
            let startIndex = max((timestamps.count - maximumSampledFrameCount) / 2, 0)
            timestamps = Array(timestamps[startIndex..<(startIndex + maximumSampledFrameCount)])
        }

        return timestamps
    }

    private static func extractPoseFrames(
        from asset: AVAsset,
        timestamps: [Double],
        progress: (@MainActor @Sendable (Int) async -> Void)? = nil
    ) async throws -> (frames: [SwingFrame], metadata: GaragePoseExtractionMetadata) {
        guard timestamps.isEmpty == false else {
            return (
                [],
                GaragePoseExtractionMetadata(usedZeroCopyReader: false, includes3DFrames: false)
            )
        }

        // The zero-copy AVAssetReader path has been the most likely source of on-device
        // allocator aborts during Garage import. Prefer the more conservative generator path
        // until the lower-level memory issue is isolated.
        let fallbackFrames = try await extractPoseFramesUsingGenerator(
            from: asset,
            timestamps: timestamps,
            progress: progress
        )
        return (
            fallbackFrames,
            GaragePoseExtractionMetadata(
                usedZeroCopyReader: false,
                includes3DFrames: fallbackFrames.contains(where: { $0.joints3D.isEmpty == false })
            )
        )
    }

    private static func extractPoseFramesZeroCopy(
        from asset: AVAsset,
        timestamps: [Double],
        progress: (@MainActor @Sendable (Int) async -> Void)? = nil
    ) async throws -> [SwingFrame] {
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = tracks.first else {
            throw GarageAnalysisError.missingVideoTrack
        }

        let transform = try await videoTrack.load(.preferredTransform)
        let orientation = cgImageOrientation(for: transform)
        let reader = try AVAssetReader(asset: asset)
        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ]
        let trackOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: outputSettings)
        trackOutput.alwaysCopiesSampleData = false
        guard reader.canAdd(trackOutput) else {
            throw GarageAnalysisError.insufficientPoseFrames
        }
        reader.add(trackOutput)

        guard reader.startReading() else {
            throw reader.error ?? GarageAnalysisError.insufficientPoseFrames
        }

        var frames: [SwingFrame] = []
        frames.reserveCapacity(timestamps.count)
        var nextTimestampIndex = 0

        while let sampleBuffer = trackOutput.copyNextSampleBuffer(), nextTimestampIndex < timestamps.count {
            await Task.yield()
            let priorTimestampIndex = nextTimestampIndex
            let extractedFrame: SwingFrame? = try autoreleasepool {
                try Task.checkCancellation()
                let presentationTimestamp = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
                guard presentationTimestamp.isFinite else {
                    return nil
                }

                let desiredTimestamp = timestamps[nextTimestampIndex]
                if presentationTimestamp + 0.0001 < desiredTimestamp {
                    return nil
                }

                guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                    nextTimestampIndex = advancedTimestampIndex(
                        from: nextTimestampIndex,
                        actualTimestamp: presentationTimestamp,
                        desiredTimestamps: timestamps
                    )
                    return nil
                }

                let detectedFrame = try detectPoseFrame(
                    from: pixelBuffer,
                    timestamp: presentationTimestamp,
                    orientation: orientation
                )

                nextTimestampIndex = advancedTimestampIndex(
                    from: nextTimestampIndex,
                    actualTimestamp: presentationTimestamp,
                    desiredTimestamps: timestamps
                )
                return detectedFrame
            }

            if let extractedFrame {
                frames.append(extractedFrame)
            }
            if nextTimestampIndex != priorTimestampIndex {
                await progress?(nextTimestampIndex)
            }
            await Task.yield()
        }

        if case .failed = reader.status, let error = reader.error {
            throw error
        }

        await progress?(timestamps.count)

        return frames
    }

    private static func extractPoseFramesUsingGenerator(
        from asset: AVAsset,
        timestamps: [Double],
        progress: (@MainActor @Sendable (Int) async -> Void)? = nil
    ) async throws -> [SwingFrame] {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 960, height: 960)
        generator.requestedTimeToleranceAfter = .zero
        generator.requestedTimeToleranceBefore = .zero

        var frames: [SwingFrame] = []
        for (index, timestamp) in timestamps.enumerated() {
            await Task.yield()
            let extractedFrame: SwingFrame? = try autoreleasepool {
                try Task.checkCancellation()
                let time = CMTime(seconds: timestamp, preferredTimescale: 600)
                guard let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) else {
                    return nil
                }

                return try detectPoseFrame(from: cgImage, timestamp: timestamp)
            }

            if let extractedFrame {
                frames.append(extractedFrame)
            }
            await progress?(index + 1)
            await Task.yield()
        }

        return frames
    }

    static func sampledPresentationTimestamps(
        from presentationTimes: [Double],
        matching desiredTimestamps: [Double]
    ) -> [Double] {
        guard presentationTimes.isEmpty == false, desiredTimestamps.isEmpty == false else {
            return []
        }

        var matched: [Double] = []
        matched.reserveCapacity(desiredTimestamps.count)
        var nextTimestampIndex = 0

        for presentationTime in presentationTimes {
            guard nextTimestampIndex < desiredTimestamps.count else { break }
            guard presentationTime + 0.0001 >= desiredTimestamps[nextTimestampIndex] else {
                continue
            }

            matched.append(presentationTime)
            nextTimestampIndex = advancedTimestampIndex(
                from: nextTimestampIndex,
                actualTimestamp: presentationTime,
                desiredTimestamps: desiredTimestamps
            )
        }

        return matched
    }

    private static func advancedTimestampIndex(
        from currentIndex: Int,
        actualTimestamp: Double,
        desiredTimestamps: [Double]
    ) -> Int {
        var nextIndex = currentIndex
        while nextIndex < desiredTimestamps.count, desiredTimestamps[nextIndex] <= actualTimestamp + 0.0001 {
            nextIndex += 1
        }
        return nextIndex
    }

    private static func detectPoseFrame(from cgImage: CGImage, timestamp: Double) throws -> SwingFrame? {
        try autoreleasepool {
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
            return try detectPoseFrame(with: handler, timestamp: timestamp)
        }
    }

    private static func detectPoseFrame(
        from pixelBuffer: CVPixelBuffer,
        timestamp: Double,
        orientation: CGImagePropertyOrientation
    ) throws -> SwingFrame? {
        try autoreleasepool {
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation)
            return try detectPoseFrame(with: handler, timestamp: timestamp)
        }
    }

    private static func detectPoseFrame(
        with handler: VNImageRequestHandler,
        timestamp: Double
    ) throws -> SwingFrame? {
        let request = VNDetectHumanBodyPoseRequest()
        // The 3D body-pose request has been unstable on-device during Garage import,
        // producing repeated orientation warnings followed by allocator aborts.
        // Keep the extraction pipeline on the proven 2D request so swing analysis completes reliably.
        try handler.perform([request])
        return try makeSwingFrame(timestamp: timestamp, observation2D: request.results?.first, observation3D: nil)
    }

    private static func makeSwingFrame(
        timestamp: Double,
        observation2D: VNHumanBodyPoseObservation?,
        observation3D: VNHumanBodyPose3DObservation?
    ) throws -> SwingFrame? {
        guard let observation2D else {
            return nil
        }

        let recognizedPoints = try observation2D.recognizedPoints(.all)
        var joints: [SwingJoint] = []

        let mapper = GaragePoseCoordinateMapper(isMirrored: false, invertY: true)
        for jointName in SwingJointName.allCases {
            guard
                let visionName = jointName.visionName,
                let recognizedPoint = recognizedPoints[visionName],
                recognizedPoint.confidence >= 0.15
            else {
                continue
            }
            let mappedPoint = mapper.map(recognizedPoint.location)

            joints.append(
                SwingJoint(
                    name: jointName,
                    x: Double(mappedPoint.x),
                    y: Double(mappedPoint.y),
                    confidence: Double(recognizedPoint.confidence)
                )
            )
        }

        guard hasMinimumDetectionSet(in: joints) else {
            return nil
        }

        let joints3D = try extract3DJoints(from: observation3D)
        let confidence = joints.map(\.confidence).reduce(0, +) / Double(joints.count)
        return SwingFrame(timestamp: timestamp, joints: joints, joints3D: joints3D, confidence: confidence)
    }

    private static func hasMinimumDetectionSet(in joints: [SwingJoint]) -> Bool {
        let names = Set(joints.map(\.name))
        let required: Set<SwingJointName> = [.leftShoulder, .rightShoulder, .leftHip, .rightHip, .leftWrist, .rightWrist]
        return required.isSubset(of: names)
    }

    private static func smooth(frames: [SwingFrame]) -> [SwingFrame] {
        var smoother = GarageWeightedPointSmoother()
        return frames.map { smoother.smooth(frame: $0) }
    }

    static func detectKeyFrames(from frames: [SwingFrame]) -> [KeyFrame] {
        let addressIndex = addressIndex(in: frames)
        let preliminaryImpactIndex = preliminaryImpactIndex(in: frames, addressIndex: addressIndex)
        let takeawayIndex = takeawayIndex(
            in: frames,
            addressIndex: addressIndex,
            preliminaryImpactIndex: preliminaryImpactIndex
        )
        let topIndex = topOfBackswingIndex(
            in: frames,
            addressIndex: addressIndex,
            takeawayIndex: takeawayIndex,
            preliminaryImpactIndex: preliminaryImpactIndex
        )
        let shaftParallelIndex = shaftParallelIndex(in: frames, addressIndex: addressIndex, takeawayIndex: takeawayIndex, topIndex: topIndex)
        let transitionIndex = transitionIndex(
            in: frames,
            topIndex: topIndex,
            latestPossibleIndex: preliminaryImpactIndex
        )
        let impactIndex = impactIndex(in: frames, addressIndex: addressIndex, transitionIndex: transitionIndex)
        let earlyDownswingIndex = earlyDownswingIndex(in: frames, transitionIndex: transitionIndex, impactIndex: impactIndex)
        let followThroughIndex = followThroughIndex(in: frames, impactIndex: impactIndex)
        let orderedIndices = strictlyOrderedFrameIndices(
            [
                addressIndex,
                takeawayIndex,
                shaftParallelIndex,
                topIndex,
                transitionIndex,
                earlyDownswingIndex,
                impactIndex,
                followThroughIndex
            ],
            frameCount: frames.count
        )

        return [
            KeyFrame(phase: .address, frameIndex: orderedIndices[0]),
            KeyFrame(phase: .takeaway, frameIndex: orderedIndices[1]),
            KeyFrame(phase: .shaftParallel, frameIndex: orderedIndices[2]),
            KeyFrame(phase: .topOfBackswing, frameIndex: orderedIndices[3]),
            KeyFrame(phase: .transition, frameIndex: orderedIndices[4]),
            KeyFrame(phase: .earlyDownswing, frameIndex: orderedIndices[5]),
            KeyFrame(phase: .impact, frameIndex: orderedIndices[6]),
            KeyFrame(phase: .followThrough, frameIndex: orderedIndices[7])
        ]
    }

    static func deriveHandAnchors(from frames: [SwingFrame], keyFrames: [KeyFrame]) -> [HandAnchor] {
        let orderedKeyFrames = keyFrames.sorted { lhs, rhs in
            (SwingPhase.allCases.firstIndex(of: lhs.phase) ?? 0) < (SwingPhase.allCases.firstIndex(of: rhs.phase) ?? 0)
        }
        let gripEstimates = gripEstimates(from: frames)

        return orderedKeyFrames.compactMap { keyFrame in
            guard gripEstimates.indices.contains(keyFrame.frameIndex) else {
                return nil
            }

            let center = gripEstimates[keyFrame.frameIndex].point
            return HandAnchor(phase: keyFrame.phase, x: center.x, y: center.y)
        }
    }

    static func mergedHandAnchors(
        preserving existingAnchors: [HandAnchor],
        from frames: [SwingFrame],
        keyFrames: [KeyFrame]
    ) -> [HandAnchor] {
        let derivedAnchors = Dictionary(uniqueKeysWithValues: deriveHandAnchors(from: frames, keyFrames: keyFrames).map { ($0.phase, $0) })
        let existingAnchorsByPhase = Dictionary(uniqueKeysWithValues: existingAnchors.map { ($0.phase, $0) })

        return SwingPhase.allCases.compactMap { phase in
            if let existingAnchor = existingAnchorsByPhase[phase], existingAnchor.source == .manual {
                return existingAnchor
            }

            return derivedAnchors[phase] ?? existingAnchorsByPhase[phase]
        }
    }

    static func upsertingHandAnchor(_ anchor: HandAnchor, into anchors: [HandAnchor]) -> [HandAnchor] {
        var updatedAnchors = anchors.filter { $0.phase != anchor.phase }
        updatedAnchors.append(anchor)
        updatedAnchors.sort { lhs, rhs in
            (SwingPhase.allCases.firstIndex(of: lhs.phase) ?? 0) < (SwingPhase.allCases.firstIndex(of: rhs.phase) ?? 0)
        }
        return updatedAnchors
    }

    static func handPathReviewReport(for frames: [SwingFrame], keyFrames: [KeyFrame]) -> GarageHandPathReviewReport {
        guard frames.isEmpty == false, keyFrames.isEmpty == false else {
            return GarageHandPathReviewReport(
                score: 0,
                requiresManualReview: true,
                weakestPhase: nil,
                weakPhases: [],
                continuityScore: 0
            )
        }

        let estimates = gripEstimates(from: frames)
        let orderedKeyFrames = keyFrames.sorted { lhs, rhs in
            (SwingPhase.allCases.firstIndex(of: lhs.phase) ?? 0) < (SwingPhase.allCases.firstIndex(of: rhs.phase) ?? 0)
        }

        let phaseConfidences: [(phase: SwingPhase, confidence: Double)] = orderedKeyFrames.map { keyFrame in
            guard estimates.indices.contains(keyFrame.frameIndex) else {
                return (keyFrame.phase, 0)
            }
            return (keyFrame.phase, phaseConfidence(for: estimates[keyFrame.frameIndex]))
        }

        let weakPhases = phaseConfidences
            .filter { $0.confidence < 0.24 }
            .map(\.phase)
        let continuityScore = gripContinuityScore(estimates: estimates, frames: frames)
        let averagePhaseConfidence = phaseConfidences.map(\.confidence).reduce(0, +) / Double(max(phaseConfidences.count, 1))
        let averageEstimateConfidence = estimates.map { phaseConfidence(for: $0) }.reduce(0, +) / Double(max(estimates.count, 1))
        let normalizedScore = min(
            max(
                (averagePhaseConfidence * 0.58)
                    + (averageEstimateConfidence * 0.27)
                    + (continuityScore * 0.15),
                0
            ),
            1
        )
        let score = Int((normalizedScore * 100).rounded())
        let weakestPhase = phaseConfidences.min { lhs, rhs in
            lhs.confidence < rhs.confidence
        }?.phase
        let requiresManualReview = weakPhases.isEmpty == false || continuityScore < 0.24 || score < 48

        return GarageHandPathReviewReport(
            score: score,
            requiresManualReview: requiresManualReview,
            weakestPhase: weakPhases.first ?? weakestPhase,
            weakPhases: weakPhases,
            continuityScore: continuityScore
        )
    }

    static func autoApprovedKeyFrames(from keyFrames: [KeyFrame], reviewReport: GarageHandPathReviewReport) -> [KeyFrame] {
        guard reviewReport.requiresManualReview == false else {
            return keyFrames
        }

        return keyFrames.map { keyFrame in
            var approvedKeyFrame = keyFrame
            approvedKeyFrame.reviewStatus = .approved
            return approvedKeyFrame
        }
    }

    static func segmentedHandPathSamples(
        from frames: [SwingFrame],
        keyFrames: [KeyFrame],
        samplesPerSegment: Int = 12
    ) -> [GarageSegmentedPathSample] {
        guard
            frames.count >= 2,
            let topIndex = keyFrames.first(where: { $0.phase == .topOfBackswing })?.frameIndex,
            let impactIndex = keyFrames.first(where: { $0.phase == .impact })?.frameIndex,
            topIndex >= 0,
            impactIndex >= 1,
            topIndex < frames.count,
            impactIndex < frames.count,
            topIndex < impactIndex
        else {
            return []
        }

        let truncatedFrames = Array(frames[0...impactIndex])
        let stabilizedPoints = gripEstimates(from: truncatedFrames).map(\.point)
        guard stabilizedPoints.count >= 2 else {
            return []
        }

        let splinePoints = GaragePathBuilder.centripetalCatmullRom(
            points: stabilizedPoints,
            samplesPerSegment: samplesPerSegment
        )
        guard splinePoints.count >= 2 else {
            return []
        }

        let topTimestamp = frames[topIndex].timestamp
        var samples: [GarageSegmentedPathSample] = []
        samples.reserveCapacity(splinePoints.count)

        for (index, point) in splinePoints.enumerated() {
            let priorIndex = max(index - 1, 0)
            let nextIndex = min(index + 1, splinePoints.count - 1)
            let speed = distance(from: splinePoints[priorIndex], to: splinePoints[nextIndex])
            let normalizedT = Double(index) / Double(max(splinePoints.count - 1, 1))
            let sourceFrame = min(Int((Double(truncatedFrames.count - 1) * normalizedT).rounded()), truncatedFrames.count - 1)
            let timestamp = truncatedFrames[sourceFrame].timestamp

            samples.append(
                GarageSegmentedPathSample(
                    timestamp: timestamp,
                    x: point.x,
                    y: point.y,
                    speed: speed,
                    segment: timestamp <= topTimestamp ? .backswing : .downswing
                )
            )
        }

        return samples
    }

    private static func addressIndex(in frames: [SwingFrame]) -> Int {
        guard frames.count > 1 else {
            return 0
        }

        let searchEnd = min(max(6, frames.count / 4), frames.count - 1)
        let openingFrames = Array(frames[0...searchEnd])
        let kinematicSamples = handKinematics(from: openingFrames)
        let speedByIndex = Dictionary(uniqueKeysWithValues: kinematicSamples.map { ($0.index, $0.speed) })
        let maxSpeed = max(kinematicSamples.map(\.speed).max() ?? 0.001, 0.001)
        let handYs = openingFrames.map { handCenter(in: $0).y }
        let maxHandY = handYs.max() ?? 0
        let minHandY = handYs.min() ?? 0
        let handYSpan = max(maxHandY - minHandY, 0.0001)
        let maxConfidence = max(openingFrames.map(\.confidence).max() ?? 1, 0.0001)

        var bestIndex = 0
        var bestScore = Double.greatestFiniteMagnitude

        for index in 0...searchEnd {
            let frame = frames[index]
            let handCenterPoint = handCenter(in: frame)
            let normalizedSpeed = min((speedByIndex[index] ?? 0) / maxSpeed, 1)
            let raisedHandsPenalty = min(max((maxHandY - handCenterPoint.y) / handYSpan, 0), 1)
            let confidencePenalty = 1 - min(max(frame.confidence / maxConfidence, 0), 1)
            let latenessPenalty = Double(index) / Double(max(searchEnd, 1))
            let score = (normalizedSpeed * 0.50)
                + (raisedHandsPenalty * 0.28)
                + (confidencePenalty * 0.17)
                + (latenessPenalty * 0.05)

            if score < bestScore {
                bestScore = score
                bestIndex = index
            }
        }

        return bestIndex
    }

    private static func preliminaryImpactIndex(in frames: [SwingFrame], addressIndex: Int) -> Int {
        let motionSpan = max(frames.count - addressIndex - 1, 2)
        let delayedSearchStart = addressIndex + max(2, Int(Double(motionSpan) * 0.45))
        return impactIndex(in: frames, searchStart: min(delayedSearchStart, frames.count - 1))
    }

    private static func topOfBackswingIndex(
        in frames: [SwingFrame],
        addressIndex: Int,
        takeawayIndex: Int,
        preliminaryImpactIndex: Int
    ) -> Int {
        let searchStart = min(max(takeawayIndex + 1, addressIndex + 2), max(preliminaryImpactIndex - 1, addressIndex + 2))
        let tentativeUpperBound = min(preliminaryImpactIndex - 1, frames.count - 2)
        guard searchStart <= tentativeUpperBound else {
            return min(max(searchStart, addressIndex + 2), max(frames.count - 3, 0))
        }

        let limitedUpperBound = min(
            tentativeUpperBound,
            addressIndex + max(4, Int(Double(max(preliminaryImpactIndex - addressIndex, 4)) * 0.72))
        )
        let searchEnd = max(searchStart, limitedUpperBound)
        let kinematics = Dictionary(uniqueKeysWithValues: handKinematics(from: frames).map { ($0.index, $0) })
        let yValues = (searchStart...searchEnd).map { handCenter(in: frames[$0]).y }
        let minY = yValues.min() ?? handCenter(in: frames[searchStart]).y
        let maxY = yValues.max() ?? handCenter(in: frames[searchEnd]).y
        let ySpan = max(maxY - minY, 0.0001)
        let maxSpeed = max(
            (searchStart...searchEnd).compactMap { kinematics[$0]?.speed }.max() ?? 0.001,
            0.001
        )

        var bestIndex = searchStart
        var bestScore = -Double.greatestFiniteMagnitude

        for index in searchStart...searchEnd {
            let point = handCenter(in: frames[index])
            let previousPoint = handCenter(in: frames[max(index - 1, searchStart)])
            let nextPoint = handCenter(in: frames[min(index + 1, searchEnd)])
            let currentSpeed = kinematics[index]?.speed ?? maxSpeed
            let previousDy = kinematics[index]?.velocity.dy ?? (point.y - previousPoint.y)
            let nextDy = kinematics[index + 1]?.velocity.dy ?? (nextPoint.y - point.y)
            let heightScore = (maxY - point.y) / ySpan
            let speedScore = 1 - min(currentSpeed / maxSpeed, 1)
            let reversalScore: Double
            if previousDy < -KinematicThresholds.reversalVelocityEpsilon
                && nextDy > KinematicThresholds.reversalVelocityEpsilon {
                reversalScore = 1
            } else if point.y <= previousPoint.y && point.y <= nextPoint.y {
                reversalScore = 0.45
            } else {
                reversalScore = 0
            }
            let progress = Double(index - searchStart) / Double(max(searchEnd - searchStart, 1))
            let latenessPenalty = progress * 0.35
            let nearImpactPenalty = index >= preliminaryImpactIndex - 1 ? 0.45 : 0
            let score = (heightScore * 0.55)
                + (speedScore * 0.25)
                + (reversalScore * 0.35)
                - latenessPenalty
                - nearImpactPenalty

            if score > bestScore {
                bestScore = score
                bestIndex = index
            }
        }

        if bestScore < 0.2 {
            return (searchStart...searchEnd).min { lhs, rhs in
                let lhsY = handCenter(in: frames[lhs]).y
                let rhsY = handCenter(in: frames[rhs]).y
                let lhsPenalty = Double(lhs - searchStart) * 0.0025
                let rhsPenalty = Double(rhs - searchStart) * 0.0025
                return (lhsY + lhsPenalty) < (rhsY + rhsPenalty)
            } ?? bestIndex
        }

        return bestIndex
    }

    private static func takeawayIndex(
        in frames: [SwingFrame],
        addressIndex: Int,
        preliminaryImpactIndex: Int
    ) -> Int {
        let addressHands = handCenter(in: frames[addressIndex])
        let shoulderWidth = bodyScale(in: frames[addressIndex])
        let searchUpperBound = min(max(addressIndex + 2, preliminaryImpactIndex - 1), frames.count - 1)
        guard addressIndex + 1 <= searchUpperBound else {
            return min(addressIndex + 1, frames.count - 1)
        }

        let kinematics = Dictionary(uniqueKeysWithValues: handKinematics(from: frames).map { ($0.index, $0) })
        let maxPreImpactSpeed = max(
            ((addressIndex + 1)...searchUpperBound).compactMap { kinematics[$0]?.speed }.max() ?? 0.001,
            0.001
        )
        let movementThreshold = max(0.024, shoulderWidth * 0.12)
        let persistenceThreshold = movementThreshold * 0.88
        let speedThreshold = max(maxPreImpactSpeed * 0.12, 0.001)
        let searchLimit = min(
            searchUpperBound,
            addressIndex + max(3, Int(Double(max(preliminaryImpactIndex - addressIndex, 3)) * 0.45))
        )

        for index in (addressIndex + 1)...searchLimit {
            let windowEnd = min(index + 1, searchUpperBound)
            let currentDistance = distance(from: addressHands, to: handCenter(in: frames[index]))
            let windowDistances = (index...windowEnd).map { distance(from: addressHands, to: handCenter(in: frames[$0])) }
            let windowMaxSpeed = (index...windowEnd).compactMap { kinematics[$0]?.speed }.max() ?? 0

            if currentDistance >= movementThreshold,
               windowDistances.allSatisfy({ $0 >= persistenceThreshold }),
               windowMaxSpeed >= speedThreshold {
                return index
            }
        }

        return ((addressIndex + 1)...searchUpperBound).min { lhs, rhs in
            let lhsDistance = distance(from: addressHands, to: handCenter(in: frames[lhs]))
            let rhsDistance = distance(from: addressHands, to: handCenter(in: frames[rhs]))
            let lhsScore = abs(lhsDistance - movementThreshold) + (Double(lhs - addressIndex) * 0.002)
            let rhsScore = abs(rhsDistance - movementThreshold) + (Double(rhs - addressIndex) * 0.002)
            return lhsScore < rhsScore
        } ?? min(addressIndex + 1, frames.count - 1)
    }

    private static func shaftParallelIndex(in frames: [SwingFrame], addressIndex: Int, takeawayIndex: Int, topIndex: Int) -> Int {
        guard takeawayIndex + 1 < topIndex else {
            return min(takeawayIndex + 1, topIndex)
        }

        let addressHands = handCenter(in: frames[addressIndex])
        let topHands = handCenter(in: frames[topIndex])
        let targetDistance = distance(from: addressHands, to: topHands) * 0.5

        let range = (takeawayIndex + 1)..<topIndex
        return range.min { lhs, rhs in
            let lhsDelta = abs(distance(from: addressHands, to: handCenter(in: frames[lhs])) - targetDistance)
            let rhsDelta = abs(distance(from: addressHands, to: handCenter(in: frames[rhs])) - targetDistance)
            return lhsDelta < rhsDelta
        } ?? min(takeawayIndex + 1, topIndex)
    }

    private static func transitionIndex(in frames: [SwingFrame], topIndex: Int, latestPossibleIndex: Int) -> Int {
        let topHands = handCenter(in: frames[topIndex])
        let torsoHeight = torsoHeight(in: frames[topIndex])
        let downwardThreshold = max(0.015, torsoHeight * 0.06)
        let searchEnd = min(max(topIndex + 1, latestPossibleIndex), frames.count - 1)

        for index in (topIndex + 1)...searchEnd {
            let handY = handCenter(in: frames[index]).y
            if handY - topHands.y >= downwardThreshold {
                return index
            }
        }

        return min(topIndex + 1, searchEnd)
    }

    private static func earlyDownswingIndex(in frames: [SwingFrame], transitionIndex: Int, impactIndex: Int) -> Int {
        guard transitionIndex + 1 < impactIndex else {
            return max(transitionIndex, impactIndex - 1)
        }

        let latestAllowed = impactIndex - 1
        let transitionHands = handCenter(in: frames[transitionIndex])
        let impactHands = handCenter(in: frames[impactIndex])
        let transitionToImpactDistance = distance(from: transitionHands, to: impactHands)
        let targetDistance = transitionToImpactDistance * 0.35
        let maxDistanceBeforeImpact = transitionToImpactDistance * 0.90
        let impactHandY = impactHands.y
        let kinematicByIndex = Dictionary(uniqueKeysWithValues: handKinematics(from: frames).map { ($0.index, $0) })

        let candidateRange = (transitionIndex + 1)...latestAllowed
        if let depthDrivenCandidate = earliestDepthDrivenDownswingIndex(
            in: frames,
            candidateRange: candidateRange,
            transitionHands: transitionHands,
            impactHands: impactHands,
            targetDistance: targetDistance,
            maxDistanceBeforeImpact: maxDistanceBeforeImpact,
            impactHandY: impactHandY,
            kinematicByIndex: kinematicByIndex
        ) {
            return depthDrivenCandidate
        }

        if let earliestThresholdCrossing = candidateRange.first(where: { index in
            let point = handCenter(in: frames[index])
            let traveledDistance = distance(from: transitionHands, to: point)
            guard traveledDistance >= targetDistance, traveledDistance <= maxDistanceBeforeImpact else {
                return false
            }

            // Keep early-downswing prior to the near-impact region.
            if point.y > impactHandY * 0.98 {
                return false
            }

            // Require directional commitment into downswing.
            guard let sample = kinematicByIndex[index], sample.velocity.dy > 0 else {
                return false
            }

            return true
        }) {
            return earliestThresholdCrossing
        }

        if let earliestDownwardCandidate = candidateRange.first(where: { index in
            let point = handCenter(in: frames[index])
            let traveledDistance = distance(from: transitionHands, to: point)
            guard traveledDistance > 0, traveledDistance <= maxDistanceBeforeImpact else {
                return false
            }

            if point.y > impactHandY * 0.98 {
                return false
            }

            guard let sample = kinematicByIndex[index], sample.velocity.dy > 0 else {
                return false
            }

            return true
        }) {
            return earliestDownwardCandidate
        }

        return min(transitionIndex + 1, latestAllowed)
    }

    private static func earliestDepthDrivenDownswingIndex(
        in frames: [SwingFrame],
        candidateRange: ClosedRange<Int>,
        transitionHands: CGPoint,
        impactHands: CGPoint,
        targetDistance: Double,
        maxDistanceBeforeImpact: Double,
        impactHandY: Double,
        kinematicByIndex: [Int: GarageHandKinematicSample]
    ) -> Int? {
        guard
            let transitionDepth = handDepth(in: frames[candidateRange.lowerBound - 1]),
            let impactDepth = handDepth(in: frames[candidateRange.upperBound + 1]),
            abs(impactDepth - transitionDepth) >= 0.001
        else {
            return nil
        }

        return candidateRange.first(where: { index in
            let point = handCenter(in: frames[index])
            let traveledDistance = distance(from: transitionHands, to: point)
            guard traveledDistance >= targetDistance, traveledDistance <= maxDistanceBeforeImpact else {
                return false
            }

            if point.y > impactHandY * 0.98 {
                return false
            }

            guard let sample = kinematicByIndex[index], sample.velocity.dy > 0 else {
                return false
            }

            guard let currentDepth = handDepth(in: frames[index]) else {
                return false
            }

            let depthProgress = (currentDepth - transitionDepth) / (impactDepth - transitionDepth)
            return depthProgress >= 0.20 && depthProgress <= 0.95
        })
    }

    private static func impactIndex(in frames: [SwingFrame], addressIndex: Int, transitionIndex: Int) -> Int {
        impactIndex(in: frames, searchStart: max(transitionIndex + 1, addressIndex + 2))
    }

    private static func impactIndex(in frames: [SwingFrame], searchStart: Int) -> Int {
        let samples = handKinematics(from: frames)
        guard samples.count >= 4 else { return frames.count - 1 }

        let resolvedSearchStart = max(searchStart, 1)
        guard resolvedSearchStart < samples.count else { return frames.count - 1 }

        let candidateSamples = Array(samples[resolvedSearchStart..<samples.count])
        let speeds = candidateSamples.map(\.speed).sorted()
        let yValues = candidateSamples.map { Double($0.position.y) }.sorted()
        guard
            let speedThreshold = quantile(fromSortedValues: speeds, quantile: KinematicThresholds.impactSpeedQuantile),
            let lowerPathY = quantile(fromSortedValues: yValues, quantile: KinematicThresholds.impactLowerPathQuantile)
        else {
            return frames.count - 1
        }

        let validCandidates = candidateSamples.filter { sample in
            sample.speed >= speedThreshold && sample.position.y >= lowerPathY
        }

        if let best = validCandidates.max(by: { smoothedSpeed(at: $0.index, in: samples) < smoothedSpeed(at: $1.index, in: samples) }) {
            return best.index
        }

        return candidateSamples.max(by: { $0.speed < $1.speed })?.index ?? frames.count - 1
    }

    private static func followThroughIndex(in frames: [SwingFrame], impactIndex: Int) -> Int {
        guard impactIndex + 1 < frames.count else {
            return impactIndex
        }

        let range = (impactIndex + 1)..<frames.count
        let candidate = range.min { lhs, rhs in
            handCenter(in: frames[lhs]).y < handCenter(in: frames[rhs]).y
        }

        return candidate ?? frames.count - 1
    }

    static func handCenter(in frame: SwingFrame) -> CGPoint {
        rawGripEstimate(in: frame)?.point ?? legacyHandCenter(in: frame)
    }

    static func handDepth(in frame: SwingFrame) -> Double? {
        let wrists = frame.joints3D.filter { joint in
            joint.name == .leftWrist || joint.name == .rightWrist
        }
        guard wrists.isEmpty == false else {
            return nil
        }
        let totalDepth = wrists.reduce(0.0) { $0 + $1.z }
        return totalDepth / Double(wrists.count)
    }

    static func bodyScale(in frame: SwingFrame) -> Double {
        distance(from: frame.point(named: .leftShoulder), to: frame.point(named: .rightShoulder))
    }

    static func headCircle(in frame: SwingFrame) -> GarageSkeletonHeadCircle? {
        guard
            let nose = frame.point(named: .nose, minimumConfidence: 0.5),
            let leftShoulder = frame.point(named: .leftShoulder, minimumConfidence: 0.5),
            let rightShoulder = frame.point(named: .rightShoulder, minimumConfidence: 0.5)
        else {
            return nil
        }

        let shoulderMidpoint = midpoint(leftShoulder, rightShoulder)
        let headAxis = CGVector(dx: nose.x - shoulderMidpoint.x, dy: nose.y - shoulderMidpoint.y)
        let torsoScale = max(bodyScale(in: frame), distance(from: nose, to: shoulderMidpoint))
        let radius = min(
            max(distance(from: nose, to: shoulderMidpoint) * 0.58, torsoScale * 0.18),
            torsoScale * 0.34
        )
        let center = CGPoint(
            x: nose.x + (headAxis.dx * 0.12),
            y: nose.y + (headAxis.dy * 0.18)
        )

        return GarageSkeletonHeadCircle(center: center, radius: radius)
    }

    private static func torsoHeight(in frame: SwingFrame) -> Double {
        let shoulders = midpoint(frame.point(named: .leftShoulder), frame.point(named: .rightShoulder))
        let hips = midpoint(frame.point(named: .leftHip), frame.point(named: .rightHip))
        return abs(hips.y - shoulders.y)
    }

    private static func midpoint(_ lhs: CGPoint, _ rhs: CGPoint) -> CGPoint {
        CGPoint(x: (lhs.x + rhs.x) / 2, y: (lhs.y + rhs.y) / 2)
    }

    static func distance(from lhs: CGPoint, to rhs: CGPoint) -> Double {
        let dx = lhs.x - rhs.x
        let dy = lhs.y - rhs.y
        return sqrt((dx * dx) + (dy * dy))
    }

    static func generatePathPoints(from frames: [SwingFrame], samplesPerSegment: Int = 16) -> [PathPoint] {
        let stabilizedPoints = gripEstimates(from: frames).map(\.point)
        guard stabilizedPoints.count >= 2 else {
            return []
        }

        let splinePoints = GaragePathBuilder.centripetalCatmullRom(
            points: stabilizedPoints,
            samplesPerSegment: samplesPerSegment
        )

        return splinePoints.enumerated().map { sequence, point in
            PathPoint(sequence: sequence, x: point.x, y: point.y)
        }
    }

    nonisolated private static func legacyHandCenter(in frame: SwingFrame) -> CGPoint {
        let left = frame.point(named: .leftWrist)
        let right = frame.point(named: .rightWrist)
        return CGPoint(x: (left.x + right.x) / 2, y: (left.y + right.y) / 2)
    }

    nonisolated private static func rawGripEstimate(in frame: SwingFrame) -> GarageGripEstimate? {
        let minimumReliableConfidence = 0.32
        let singleWristConfidence = 0.48
        let leftWrist = frame.joint(named: .leftWrist)
        let rightWrist = frame.joint(named: .rightWrist)

        let validLeft = leftWrist.flatMap { $0.confidence >= minimumReliableConfidence ? $0 : nil }
        let validRight = rightWrist.flatMap { $0.confidence >= minimumReliableConfidence ? $0 : nil }

        if let validLeft, let validRight {
            let totalConfidence = max(validLeft.confidence + validRight.confidence, 0.0001)
            let point = CGPoint(
                x: ((validLeft.x * validLeft.confidence) + (validRight.x * validRight.confidence)) / totalConfidence,
                y: ((validLeft.y * validLeft.confidence) + (validRight.y * validRight.confidence)) / totalConfidence
            )
            return GarageGripEstimate(
                point: point,
                confidence: min(totalConfidence / 2, 1),
                source: .fused
            )
        }

        if let validLeft, validLeft.confidence >= singleWristConfidence {
            return GarageGripEstimate(
                point: CGPoint(x: validLeft.x, y: validLeft.y),
                confidence: min(validLeft.confidence * 0.88, 1),
                source: .singleWrist
            )
        }

        if let validRight, validRight.confidence >= singleWristConfidence {
            return GarageGripEstimate(
                point: CGPoint(x: validRight.x, y: validRight.y),
                confidence: min(validRight.confidence * 0.88, 1),
                source: .singleWrist
            )
        }

        return nil
    }

    private static func gripEstimates(from frames: [SwingFrame]) -> [GarageGripEstimate] {
        guard frames.isEmpty == false else { return [] }

        let rawEstimates = frames.map(rawGripEstimate)
        var resolvedEstimates: [GarageGripEstimate] = []
        resolvedEstimates.reserveCapacity(frames.count)

        for index in frames.indices {
            let current = resolvedGripEstimate(
                at: index,
                rawEstimates: rawEstimates,
                previousResolved: resolvedEstimates.last
            )
            resolvedEstimates.append(current)
        }

        return smoothedGripEstimates(resolvedEstimates)
    }

    private static func resolvedGripEstimate(
        at index: Int,
        rawEstimates: [GarageGripEstimate?],
        previousResolved: GarageGripEstimate?
    ) -> GarageGripEstimate {
        if let rawEstimate = rawEstimates[index] {
            return rawEstimate
        }

        let previousSlice = rawEstimates.prefix(index)
        let nextSlice = index + 1 < rawEstimates.count ? Array(rawEstimates.suffix(from: index + 1)) : []
        let previousValid = previousResolved ?? previousSlice.compactMap { $0 }.last
        let nextValid = nextSlice.compactMap { $0 }.first

        if let previousValid, let nextValid {
            let previousIndex = previousSlice.lastIndex(where: { $0 != nil }) ?? max(index - 1, 0)
            let nextIndex = rawEstimates[(index + 1)..<rawEstimates.count].firstIndex(where: { $0 != nil }) ?? min(index + 1, rawEstimates.count - 1)
            let totalSpan = max(nextIndex - previousIndex, 1)
            let progress = Double(index - previousIndex) / Double(totalSpan)
            let point = CGPoint(
                x: previousValid.point.x + ((nextValid.point.x - previousValid.point.x) * progress),
                y: previousValid.point.y + ((nextValid.point.y - previousValid.point.y) * progress)
            )
            return GarageGripEstimate(
                point: point,
                confidence: min(previousValid.confidence, nextValid.confidence) * 0.58,
                source: .bridged
            )
        }

        if let previousValid {
            return GarageGripEstimate(
                point: previousValid.point,
                confidence: previousValid.confidence * 0.45,
                source: .bridged
            )
        }

        if let nextValid {
            return GarageGripEstimate(
                point: nextValid.point,
                confidence: nextValid.confidence * 0.45,
                source: .bridged
            )
        }

        return GarageGripEstimate(point: .zero, confidence: 0, source: .bridged)
    }

    private static func smoothedGripEstimates(_ estimates: [GarageGripEstimate]) -> [GarageGripEstimate] {
        guard estimates.count >= 2 else { return estimates }

        var smoothed: [GarageGripEstimate] = []
        smoothed.reserveCapacity(estimates.count)

        for estimate in estimates {
            guard let previous = smoothed.last else {
                smoothed.append(estimate)
                continue
            }

            let baseAlpha = min(max(0.42 + (estimate.confidence * 0.4), 0.2), 0.9)
            let alpha: Double
            switch estimate.source {
            case .fused:
                alpha = baseAlpha
            case .singleWrist:
                alpha = baseAlpha * 0.86
            case .bridged:
                alpha = baseAlpha * 0.72
            }

            let point = CGPoint(
                x: previous.point.x + ((estimate.point.x - previous.point.x) * alpha),
                y: previous.point.y + ((estimate.point.y - previous.point.y) * alpha)
            )
            smoothed.append(
                GarageGripEstimate(
                    point: point,
                    confidence: estimate.confidence,
                    source: estimate.source
                )
            )
        }

        return smoothed
    }

    private static func phaseConfidence(for estimate: GarageGripEstimate) -> Double {
        let sourceWeight: Double
        switch estimate.source {
        case .fused:
            sourceWeight = 1.0
        case .singleWrist:
            sourceWeight = 0.9
        case .bridged:
            sourceWeight = 0.62
        }

        return min(max(estimate.confidence * sourceWeight, 0), 1)
    }

    private static func gripContinuityScore(estimates: [GarageGripEstimate], frames: [SwingFrame]) -> Double {
        guard estimates.count >= 2 else { return 0 }

        var continuityTotal = 0.0
        var continuitySamples = 0

        for index in 1..<estimates.count {
            let previous = estimates[index - 1]
            let current = estimates[index]
            let scale = max(bodyScale(in: frames[min(index, frames.count - 1)]), 0.08)
            let normalizedJump = distance(from: previous.point, to: current.point) / scale
            let jumpPenalty = max(normalizedJump - 0.42, 0)
            let sourcePenalty: Double
            switch current.source {
            case .fused:
                sourcePenalty = 0
            case .singleWrist:
                sourcePenalty = 0.08
            case .bridged:
                sourcePenalty = 0.18
            }
            continuityTotal += max(0, 1 - min((jumpPenalty * 0.7) + sourcePenalty, 1))
            continuitySamples += 1
        }

        return continuityTotal / Double(max(continuitySamples, 1))
    }

    static func generatePathPoints(from anchors: [HandAnchor], samplesPerSegment: Int = 16) -> [PathPoint] {
        let stabilizedPoints = anchors.compactMap { point(from: $0) }
        guard stabilizedPoints.count >= 2 else {
            return []
        }

        let splinePoints = GaragePathBuilder.centripetalCatmullRom(
            points: stabilizedPoints,
            samplesPerSegment: samplesPerSegment
        )

        return splinePoints.enumerated().map { sequence, point in
            PathPoint(sequence: sequence, x: point.x, y: point.y)
        }
    }

    private static func point(from anchor: HandAnchor) -> CGPoint? {
        point(fromValue: anchor)
    }

    private static func point(fromValue value: Any) -> CGPoint? {
        if let point = value as? CGPoint {
            return point
        }

        let mirror = Mirror(reflecting: value)
        var xValue: CGFloat?
        var yValue: CGFloat?

        for child in mirror.children {
            if let point = point(fromValue: child.value) {
                return point
            }

            switch child.label {
            case "x":
                xValue = cgFloat(from: child.value)
            case "y":
                yValue = cgFloat(from: child.value)
            default:
                continue
            }
        }

        if let xValue, let yValue {
            return CGPoint(x: xValue, y: yValue)
        }

        return nil
    }

    private static func cgFloat(from value: Any) -> CGFloat? {
        if let value = value as? CGFloat {
            return value
        }
        if let value = value as? Double {
            return CGFloat(value)
        }
        if let value = value as? Float {
            return CGFloat(value)
        }
        if let value = value as? Int {
            return CGFloat(value)
        }
        return nil
    }
    private static func handKinematics(from frames: [SwingFrame]) -> [GarageHandKinematicSample] {
        guard frames.count >= 2 else { return [] }

        let gripEstimates = gripEstimates(from: frames)
        var samples: [GarageHandKinematicSample] = []
        samples.reserveCapacity(frames.count - 1)
        var previousCenter = gripEstimates[0].point
        var previousTime = frames[0].timestamp

        for index in 1..<frames.count {
            let currentCenter = gripEstimates[index].point
            let currentTime = frames[index].timestamp
            let dt = max(currentTime - previousTime, 1.0 / 240.0)
            let vx = (currentCenter.x - previousCenter.x) / dt
            let vy = (currentCenter.y - previousCenter.y) / dt
            let speed = sqrt((vx * vx) + (vy * vy))
            samples.append(
                GarageHandKinematicSample(
                    index: index,
                    position: currentCenter,
                    velocity: CGVector(dx: vx, dy: vy),
                    speed: speed
                )
            )
            previousCenter = currentCenter
            previousTime = currentTime
        }

        return samples
    }

    private static func quantile(fromSortedValues values: [Double], quantile: Double) -> Double? {
        guard values.isEmpty == false else { return nil }
        let q = min(max(quantile, 0), 1)
        let index = Int((Double(values.count - 1) * q).rounded(.down))
        return values[index]
    }

    private static func smoothedSpeed(at index: Int, in samples: [GarageHandKinematicSample]) -> Double {
        guard let position = samples.firstIndex(where: { $0.index == index }) else { return 0 }
        let start = max(0, position - KinematicThresholds.impactWindow)
        let end = min(samples.count - 1, position + KinematicThresholds.impactWindow)
        let window = samples[start...end]
        let total = window.reduce(0) { $0 + $1.speed }
        return total / Double(window.count)
    }

    private static func strictlyOrderedFrameIndices(_ rawIndices: [Int], frameCount: Int) -> [Int] {
        guard rawIndices.isEmpty == false else { return [] }

        let maxIndex = max(frameCount - 1, 0)
        let earliestStart = max(maxIndex - (rawIndices.count - 1), 0)
        var ordered: [Int] = Array(repeating: 0, count: rawIndices.count)
        ordered[0] = min(max(rawIndices[0], 0), earliestStart)

        for index in 1..<rawIndices.count {
            let remaining = rawIndices.count - 1 - index
            let latestAllowed = max(maxIndex - remaining, ordered[index - 1] + 1)
            ordered[index] = min(max(rawIndices[index], ordered[index - 1] + 1), latestAllowed)
        }

        return ordered
    }

    private static func cgImageOrientation(for transform: CGAffineTransform) -> CGImagePropertyOrientation {
        switch (transform.a, transform.b, transform.c, transform.d) {
        case (0, 1, -1, 0):
            return .right
        case (0, -1, 1, 0):
            return .left
        case (-1, 0, 0, -1):
            return .down
        default:
            return .up
        }
    }

    private static func extract3DJoints(from observation: VNHumanBodyPose3DObservation?) throws -> [SwingJoint3D] {
        guard #available(iOS 17.0, *), let observation else {
            return []
        }

        let jointConfidence = Double(observation.confidence)
        var joints: [SwingJoint3D] = []
        joints.reserveCapacity(SwingJoint3DName.allCases.count)

        for jointName in SwingJoint3DName.allCases {
            guard
                let visionName = jointName.visionName,
                observation.availableJointNames.contains(visionName),
                let recognizedPoint = try? observation.recognizedPoint(visionName)
            else {
                continue
            }

            let translation = recognizedPoint.position.columns.3
            joints.append(
                SwingJoint3D(
                    name: jointName,
                    x: Double(translation.x),
                    y: Double(translation.y),
                    z: Double(translation.z),
                    confidence: jointConfidence
                )
            )
        }

        return joints
    }
}

private extension SwingJointName {
    var visionName: VNHumanBodyPoseObservation.JointName? {
        switch self {
        case .nose:
            .nose
        case .leftShoulder:
            .leftShoulder
        case .rightShoulder:
            .rightShoulder
        case .leftElbow:
            .leftElbow
        case .rightElbow:
            .rightElbow
        case .leftWrist:
            .leftWrist
        case .rightWrist:
            .rightWrist
        case .leftHip:
            .leftHip
        case .rightHip:
            .rightHip
        case .leftKnee:
            .leftKnee
        case .rightKnee:
            .rightKnee
        case .leftAnkle:
            .leftAnkle
        case .rightAnkle:
            .rightAnkle
        }
    }
}

@available(iOS 17.0, *)
private extension SwingJoint3DName {
    var visionName: VNHumanBodyPose3DObservation.JointName? {
        switch self {
        case .centerShoulder:
            .centerShoulder
        case .leftShoulder:
            .leftShoulder
        case .rightShoulder:
            .rightShoulder
        case .leftElbow:
            .leftElbow
        case .rightElbow:
            .rightElbow
        case .leftWrist:
            .leftWrist
        case .rightWrist:
            .rightWrist
        case .root:
            .root
        case .spine:
            .spine
        case .leftHip:
            .leftHip
        case .rightHip:
            .rightHip
        case .leftKnee:
            .leftKnee
        case .rightKnee:
            .rightKnee
        case .leftAnkle:
            .leftAnkle
        case .rightAnkle:
            .rightAnkle
        }
    }
}

extension SwingFrame {
    nonisolated func joint(named name: SwingJointName) -> SwingJoint? {
        joints.first(where: { $0.name == name })
    }

    nonisolated func point(named name: SwingJointName, minimumConfidence: Double) -> CGPoint? {
        guard
            let joint = joint(named: name),
            joint.confidence >= minimumConfidence
        else {
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
        guard
            let joint = joint3D(named: name),
            joint.confidence >= minimumConfidence
        else {
            return nil
        }

        return SIMD3<Double>(joint.x, joint.y, joint.z)
    }
}
enum GarageCameraPerspective: String, Codable, Hashable {
    case dtl

    private enum LegacyCodingKeys: String, CodingKey {
        case rawValue
        case value
        case perspective
    }

    init(from decoder: Decoder) throws {
        if let singleValueContainer = try? decoder.singleValueContainer() {
            if singleValueContainer.decodeNil() {
                self = .dtl
                return
            }

            if let rawValue = try? singleValueContainer.decode(String.self) {
                self = GarageCameraPerspective(legacyValue: rawValue)
                return
            }
        }

        if let container = try? decoder.container(keyedBy: LegacyCodingKeys.self) {
            let rawValue = (try? container.decodeIfPresent(String.self, forKey: .rawValue)) ?? nil
            let value = (try? container.decodeIfPresent(String.self, forKey: .value)) ?? nil
            let nestedPerspective = (try? container.decodeIfPresent(String.self, forKey: .perspective)) ?? nil
            let normalizedSource = rawValue ?? value ?? nestedPerspective
            self = GarageCameraPerspective(legacyValue: normalizedSource)
            return
        }

        self = .dtl
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    private init(legacyValue: String?) {
        let normalizedValue = legacyValue?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        self = GarageCameraPerspective(rawValue: normalizedValue ?? "") ?? .dtl
    }
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

    private enum CodingKeys: String, CodingKey {
        case perspective
        case start
        case top
        case impact
    }

    init(
        perspective: GarageCameraPerspective,
        start: Double,
        top: Double,
        impact: Double
    ) {
        self.perspective = perspective
        self.start = start
        self.top = top
        self.impact = impact
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        perspective = try container.decodeIfPresent(GarageCameraPerspective.self, forKey: .perspective) ?? .dtl
        start = try container.decode(Double.self, forKey: .start)
        top = try container.decode(Double.self, forKey: .top)
        impact = try container.decode(Double.self, forKey: .impact)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(perspective, forKey: .perspective)
        try container.encode(start, forKey: .start)
        try container.encode(top, forKey: .top)
        try container.encode(impact, forKey: .impact)
    }

    var normalizedForPersistence: GarageSwingTimestamps {
        GarageSwingTimestamps(perspective: perspective, start: start, top: top, impact: impact)
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
        case .excellent: "Excellent"
        case .good: "Good"
        case .fair: "Fair"
        case .needsWork: "Needs Work"
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
        GarageSwingScorecard(
            timestamps: timestamps.normalizedForPersistence,
            metrics: metrics,
            domainScores: domainScores,
            totalScore: totalScore
        )
    }
}

struct GarageTimestampDetection: Hashable {
    let timestamps: GarageSwingTimestamps
    let startFrameIndex: Int
    let topFrameIndex: Int
    let impactFrameIndex: Int
}

enum GarageTimestampDetector {
    static func detect(from frames: [SwingFrame], keyFrames: [KeyFrame]) -> GarageTimestampDetection? {
        guard
            let addressIndex = keyFrames.first(where: { $0.phase == .address })?.frameIndex,
            let topIndex = keyFrames.first(where: { $0.phase == .topOfBackswing })?.frameIndex,
            let impactIndex = keyFrames.first(where: { $0.phase == .impact })?.frameIndex,
            frames.indices.contains(addressIndex),
            frames.indices.contains(topIndex),
            frames.indices.contains(impactIndex),
            addressIndex < topIndex,
            topIndex < impactIndex
        else {
            return nil
        }

        return GarageTimestampDetection(
            timestamps: GarageSwingTimestamps(
                perspective: .dtl,
                start: frames[addressIndex].timestamp,
                top: frames[topIndex].timestamp,
                impact: frames[impactIndex].timestamp
            ),
            startFrameIndex: addressIndex,
            topFrameIndex: topIndex,
            impactFrameIndex: impactIndex
        )
    }
}

struct GarageScoreNormalizationProfile: Hashable {
    struct Bounds: Hashable {
        let ideal: Double
        let upperBound: Double
    }

    let assumedShoulderWidthInches: Double
    let tempoRatio: Bounds
    let spineDeltaDegrees: Bounds
    let pelvicDepthInches: Bounds
    let kneeFlexDeltaDegrees: Bounds
    let headCompositeInches: Bounds

    static let dtlV1 = GarageScoreNormalizationProfile(
        assumedShoulderWidthInches: 18.0,
        tempoRatio: Bounds(ideal: 0.0, upperBound: 1.5),
        spineDeltaDegrees: Bounds(ideal: 2.0, upperBound: 20.0),
        pelvicDepthInches: Bounds(ideal: 1.2, upperBound: 8.0),
        kneeFlexDeltaDegrees: Bounds(ideal: 5.0, upperBound: 30.0),
        headCompositeInches: Bounds(ideal: 1.0, upperBound: 6.0)
    )

    func normalizedScore(for domain: GarageSwingDomain, metrics: GarageSwingMetrics) -> Double {
        switch domain {
        case .tempo:
            return linearScore(distance: abs(metrics.tempo.ratio - 3.0), bounds: tempoRatio)
        case .spine:
            return linearScore(distance: metrics.spine.deltaDegrees, bounds: spineDeltaDegrees)
        case .pelvis:
            return linearScore(distance: metrics.pelvicDepth.driftInches, bounds: pelvicDepthInches)
        case .knee:
            let combinedDelta = (metrics.kneeFlex.leftDeltaDegrees + metrics.kneeFlex.rightDeltaDegrees) / 2
            return linearScore(distance: combinedDelta, bounds: kneeFlexDeltaDegrees)
        case .head:
            let composite = (metrics.headStability.swayInches * 0.6) + (metrics.headStability.dipInches * 0.4)
            return linearScore(distance: composite, bounds: headCompositeInches)
        }
    }

    private func linearScore(distance: Double, bounds: Bounds) -> Double {
        guard bounds.upperBound > bounds.ideal else { return 0 }
        if distance <= bounds.ideal { return 1 }
        if distance >= bounds.upperBound { return 0 }
        return 1 - ((distance - bounds.ideal) / (bounds.upperBound - bounds.ideal))
    }
}

enum GarageSwingMeasurementEngine {
    private static let minimumJointConfidence = 0.45

    static func measure(
        frames: [SwingFrame],
        detection: GarageTimestampDetection,
        profile: GarageScoreNormalizationProfile = .dtlV1
    ) -> GarageSwingMetrics? {
        let addressFrame = frames[detection.startFrameIndex]
        let topFrame = frames[detection.topFrameIndex]
        let impactFrame = frames[detection.impactFrameIndex]

        let shoulderWidth = GarageAnalysisPipeline.bodyScale(in: addressFrame)
        guard shoulderWidth > 0 else {
            return nil
        }

        let addressSpineAngle = spineAngle3D(in: addressFrame) ?? spineAngle2D(in: addressFrame)
        let impactSpineAngle = spineAngle3D(in: impactFrame) ?? spineAngle2D(in: impactFrame)

        guard
            let addressSpineAngle,
            let impactSpineAngle,
            let addressPelvis = pelvisCenter(in: addressFrame),
            let impactPelvis = pelvisCenter(in: impactFrame),
            let addressHead = addressFrame.point(named: .nose, minimumConfidence: minimumJointConfidence),
            let topHead = topFrame.point(named: .nose, minimumConfidence: minimumJointConfidence),
            let impactHead = impactFrame.point(named: .nose, minimumConfidence: minimumJointConfidence),
            let leftAddressKnee = kneeAngle(in: addressFrame, side: .left),
            let rightAddressKnee = kneeAngle(in: addressFrame, side: .right),
            let leftImpactKnee = kneeAngle(in: impactFrame, side: .left),
            let rightImpactKnee = kneeAngle(in: impactFrame, side: .right)
        else {
            return nil
        }

        let backswingDuration = max(topFrame.timestamp - addressFrame.timestamp, 0.0001)
        let downswingDuration = max(impactFrame.timestamp - topFrame.timestamp, 0.0001)
        let tempoRatio = backswingDuration / downswingDuration

        let spineDelta = abs(impactSpineAngle - addressSpineAngle)
        let pelvicDepthDrift = pointsToInches(
            abs(impactPelvis.x - addressPelvis.x),
            shoulderWidth: shoulderWidth,
            profile: profile
        )

        let leftKneeDelta = abs(leftImpactKnee - leftAddressKnee)
        let rightKneeDelta = abs(rightImpactKnee - rightAddressKnee)

        let sway = max(abs(topHead.x - addressHead.x), abs(impactHead.x - addressHead.x))
        let dip = max(abs(topHead.y - addressHead.y), abs(impactHead.y - addressHead.y))
        let headSwayInches = pointsToInches(sway, shoulderWidth: shoulderWidth, profile: profile)
        let headDipInches = pointsToInches(dip, shoulderWidth: shoulderWidth, profile: profile)

        return GarageSwingMetrics(
            tempo: GarageTempoMetric(ratio: tempoRatio),
            spine: GarageSpineAngleMetric(deltaDegrees: spineDelta),
            pelvicDepth: GaragePelvicDepthMetric(driftInches: pelvicDepthDrift),
            kneeFlex: GarageKneeFlexMetric(leftDeltaDegrees: leftKneeDelta, rightDeltaDegrees: rightKneeDelta),
            headStability: GarageHeadStabilityMetric(swayInches: headSwayInches, dipInches: headDipInches)
        )
    }

    private static func pointsToInches(
        _ points: Double,
        shoulderWidth: Double,
        profile: GarageScoreNormalizationProfile
    ) -> Double {
        (points / max(shoulderWidth, 0.0001)) * profile.assumedShoulderWidthInches
    }

    private static func pelvisCenter(in frame: SwingFrame) -> CGPoint? {
        guard
            let leftHip = frame.point(named: .leftHip, minimumConfidence: minimumJointConfidence),
            let rightHip = frame.point(named: .rightHip, minimumConfidence: minimumJointConfidence)
        else {
            return nil
        }
        return CGPoint(x: (leftHip.x + rightHip.x) / 2, y: (leftHip.y + rightHip.y) / 2)
    }

    private static func spineAngle2D(in frame: SwingFrame) -> Double? {
        guard
            let leftShoulder = frame.point(named: .leftShoulder, minimumConfidence: minimumJointConfidence),
            let rightShoulder = frame.point(named: .rightShoulder, minimumConfidence: minimumJointConfidence),
            let pelvis = pelvisCenter(in: frame)
        else {
            return nil
        }
        let shoulderMid = CGPoint(x: (leftShoulder.x + rightShoulder.x) / 2, y: (leftShoulder.y + rightShoulder.y) / 2)
        let spineVector = CGVector(dx: shoulderMid.x - pelvis.x, dy: shoulderMid.y - pelvis.y)
        guard abs(spineVector.dy) > 0.0001 else { return nil }
        let radiansFromVertical = atan2(spineVector.dx, -spineVector.dy)
        return abs(radiansFromVertical * 180 / .pi)
    }

    private static func spineAngle3D(in frame: SwingFrame) -> Double? {
        guard
            let root = frame.point3D(named: .root, minimumConfidence: minimumJointConfidence),
            let centerShoulder = frame.point3D(named: .centerShoulder, minimumConfidence: minimumJointConfidence)
        else {
            return nil
        }

        let spineVector = centerShoulder - root
        let magnitude = simd_length(spineVector)
        guard magnitude > 0.0001 else {
            return nil
        }

        let normalized = spineVector / magnitude
        let verticalAlignment = min(max(abs(simd_dot(normalized, SIMD3<Double>(0, 1, 0))), 0), 1)
        return acos(verticalAlignment) * 180 / .pi
    }

    private enum KneeSide {
        case left
        case right
    }

    private static func kneeAngle(in frame: SwingFrame, side: KneeSide) -> Double? {
        let hipName: SwingJointName = side == .left ? .leftHip : .rightHip
        let kneeName: SwingJointName = side == .left ? .leftKnee : .rightKnee
        let ankleName: SwingJointName = side == .left ? .leftAnkle : .rightAnkle

        guard
            let hip = frame.point(named: hipName, minimumConfidence: minimumJointConfidence),
            let knee = frame.point(named: kneeName, minimumConfidence: minimumJointConfidence),
            let ankle = frame.point(named: ankleName, minimumConfidence: minimumJointConfidence)
        else {
            return nil
        }

        let upper = CGVector(dx: hip.x - knee.x, dy: hip.y - knee.y)
        let lower = CGVector(dx: ankle.x - knee.x, dy: ankle.y - knee.y)
        let upperMagnitude = sqrt((upper.dx * upper.dx) + (upper.dy * upper.dy))
        let lowerMagnitude = sqrt((lower.dx * lower.dx) + (lower.dy * lower.dy))
        guard upperMagnitude > 0.0001, lowerMagnitude > 0.0001 else { return nil }

        let dot = (upper.dx * lower.dx) + (upper.dy * lower.dy)
        let cosine = min(max(dot / (upperMagnitude * lowerMagnitude), -1), 1)
        return acos(cosine) * 180 / .pi
    }
}

enum GarageSyncFlowEngine {
    private struct KinematicSample: Hashable {
        let frameIndex: Int
        let timestamp: Double
        let point: CGPoint
        let speed: Double
    }

    private struct CandidateIssue: Hashable {
        let issue: GarageSyncFlowIssue
        let segmentPriority: Int
    }

    private nonisolated static let minimumJointConfidence = 0.45
    private nonisolated static let minimumFrameConfidence = 0.48
    private nonisolated static let assumedShoulderWidthInches = 18.0
    private nonisolated static let earlyHandsLeadTime = 0.03
    private nonisolated static let sameWindowTolerance = 0.045

    static func generate(
        frames: [SwingFrame],
        keyFrames: [KeyFrame],
        scorecard: GarageSwingScorecard?
    ) -> GarageSyncFlowReport {
        guard
            let detection = GarageTimestampDetector.detect(from: frames, keyFrames: keyFrames),
            frames.indices.contains(detection.startFrameIndex),
            frames.indices.contains(detection.topFrameIndex),
            frames.indices.contains(detection.impactFrameIndex),
            detection.topFrameIndex < detection.impactFrameIndex
        else {
            return GarageSyncFlowReport(
                status: .unavailable,
                headline: "SyncFlow unavailable for this swing.",
                primaryIssue: nil,
                markers: [],
                consequence: nil,
                summary: "Garage could not map enough checkpoints to build a movement-sequence story."
            )
        }

        let addressFrame = frames[detection.startFrameIndex]
        let topFrame = frames[detection.topFrameIndex]
        let impactFrame = frames[detection.impactFrameIndex]
        let downswingIndexes = Array(detection.topFrameIndex...detection.impactFrameIndex)

        guard hasReliableSyncFlowCoverage(frames: frames, downswingIndexes: downswingIndexes) else {
            return GarageSyncFlowReport(
                status: .limited,
                headline: "SyncFlow needs steadier pose tracking.",
                primaryIssue: nil,
                markers: [],
                consequence: nil,
                summary: "The body outline is visible, but the key pelvis, hand, or head landmarks were not stable enough for a trustworthy sequence call."
            )
        }

        let pelvisSamples = kinematicSamples(frames: frames, indexes: downswingIndexes, pointResolver: pelvisCenter(in:))
        let torsoSamples = kinematicSamples(frames: frames, indexes: downswingIndexes, pointResolver: torsoCenter(in:))
        let handSamples = kinematicSamples(frames: frames, indexes: downswingIndexes) { frame in
            GarageAnalysisPipeline.handCenter(in: frame)
        }

        var candidates: [CandidateIssue] = []

        if let candidate = earlyHandsCandidate(
            handSamples: handSamples,
            pelvisSamples: pelvisSamples,
            torsoSamples: torsoSamples
        ) {
            candidates.append(candidate)
        }

        if let candidate = hipStallCandidate(
            pelvisSamples: pelvisSamples,
            handSamples: handSamples,
            impactTimestamp: impactFrame.timestamp
        ) {
            candidates.append(candidate)
        }

        if let candidate = earlyExtensionCandidate(
            addressFrame: addressFrame,
            impactFrame: impactFrame,
            detection: detection,
            scorecard: scorecard
        ) {
            candidates.append(candidate)
        }

        if let candidate = unstableHeadCandidate(
            addressFrame: addressFrame,
            topFrame: topFrame,
            impactFrame: impactFrame,
            detection: detection,
            scorecard: scorecard
        ) {
            candidates.append(candidate)
        }

        let primaryIssue = selectPrimaryIssue(from: candidates.map(\.issue))
        let markers = primaryIssue.map {
            [
                GarageSyncFlowMarker(
                    segment: $0.segment,
                    jointName: $0.jointName,
                    timestamp: $0.timestamp,
                    title: $0.title,
                    detail: $0.detail
                )
            ]
        } ?? []
        let consequence = primaryIssue.map { issue in
            let impactWindow = max(impactFrame.timestamp - topFrame.timestamp, 0.12) * 0.2
            return GarageSyncFlowConsequence(
                riskPhrase: issue.kind.riskPhrase,
                detail: consequenceDetail(for: issue.kind),
                startTimestamp: max(impactFrame.timestamp - impactWindow, 0),
                endTimestamp: impactFrame.timestamp + impactWindow
            )
        }

        if let primaryIssue {
            return GarageSyncFlowReport(
                status: .ready,
                headline: primaryIssue.title,
                primaryIssue: primaryIssue,
                markers: markers,
                consequence: consequence,
                summary: primaryIssue.detail
            )
        }

        return GarageSyncFlowReport(
            status: .ready,
            headline: "Flow looks clean through impact.",
            primaryIssue: nil,
            markers: [],
            consequence: nil,
            summary: "Garage did not find a dominant sequence break in the current swing window. Use this as direction, not judgment."
        )
    }

    private static func hasReliableSyncFlowCoverage(
        frames: [SwingFrame],
        downswingIndexes: [Int]
    ) -> Bool {
        guard downswingIndexes.isEmpty == false else { return false }

        let downswingFrames = downswingIndexes.compactMap { frames.indices.contains($0) ? frames[$0] : nil }
        guard downswingFrames.isEmpty == false else { return false }

        let averageFrameConfidence = downswingFrames.map(\.confidence).reduce(0, +) / Double(downswingFrames.count)
        guard averageFrameConfidence >= minimumFrameConfidence else { return false }

        let requiredSignals: [[SwingJointName]] = [
            [.leftHip, .rightHip],
            [.leftShoulder, .rightShoulder],
            [.leftWrist, .rightWrist],
            [.nose]
        ]

        return requiredSignals.allSatisfy { jointNames in
            let reliableCount = downswingFrames.reduce(into: 0) { partialResult, frame in
                let hasReliableJoint = jointNames.contains { jointName in
                    frame.joint(named: jointName)?.confidence ?? 0 >= minimumJointConfidence
                }
                if hasReliableJoint {
                    partialResult += 1
                }
            }
            return Double(reliableCount) / Double(downswingFrames.count) >= 0.6
        }
    }

    private static func kinematicSamples(
        frames: [SwingFrame],
        indexes: [Int],
        pointResolver: (SwingFrame) -> CGPoint?
    ) -> [KinematicSample] {
        var samples: [KinematicSample] = []
        var previousIndex: Int?
        var previousTimestamp: Double?
        var previousPoint: CGPoint?

        for index in indexes where frames.indices.contains(index) {
            let frame = frames[index]
            guard let point = pointResolver(frame) else { continue }

            let speed: Double
            if
                let previousIndex,
                let previousTimestamp,
                let previousPoint,
                previousIndex != index
            {
                let deltaTime = max(frame.timestamp - previousTimestamp, 0.0001)
                speed = GarageAnalysisPipeline.distance(from: previousPoint, to: point) / deltaTime
            } else {
                speed = 0
            }

            samples.append(
                KinematicSample(
                    frameIndex: index,
                    timestamp: frame.timestamp,
                    point: point,
                    speed: speed
                )
            )
            previousIndex = index
            previousTimestamp = frame.timestamp
            previousPoint = point
        }

        return samples
    }

    private static func earlyHandsCandidate(
        handSamples: [KinematicSample],
        pelvisSamples: [KinematicSample],
        torsoSamples: [KinematicSample]
    ) -> CandidateIssue? {
        guard
            let handOnset = onsetSample(in: handSamples),
            let pelvisOnset = onsetSample(in: pelvisSamples),
            let torsoOnset = onsetSample(in: torsoSamples)
        else {
            return nil
        }

        let leadThreshold = min(pelvisOnset.timestamp, torsoOnset.timestamp) - earlyHandsLeadTime
        guard handOnset.timestamp <= leadThreshold else { return nil }

        let issue = GarageSyncFlowIssue(
            kind: .earlyHands,
            segment: .hands,
            jointName: .rightWrist,
            timestamp: handOnset.timestamp,
            title: "Sequence break: hands jumped first",
            detail: "The hands accelerated before the pelvis and torso could organize the downswing. That usually makes release timing harder to repeat."
        )
        return CandidateIssue(issue: issue, segmentPriority: segmentPriority(for: .hands))
    }

    private static func hipStallCandidate(
        pelvisSamples: [KinematicSample],
        handSamples: [KinematicSample],
        impactTimestamp: Double
    ) -> CandidateIssue? {
        guard
            pelvisSamples.count >= 3,
            handSamples.count >= 3,
            let peakPelvis = pelvisSamples.max(by: { $0.speed < $1.speed }),
            let latePelvisAverage = trailingAverageSpeed(in: pelvisSamples, count: 2),
            let lateHandAverage = trailingAverageSpeed(in: handSamples, count: 2)
        else {
            return nil
        }

        let hasEarlyPeak = peakPelvis.timestamp < impactTimestamp - 0.05
        let pelvisStalled = latePelvisAverage < max(peakPelvis.speed * 0.4, 0.01)
        let handsStillWorking = lateHandAverage > max(latePelvisAverage * 1.45, 0.03)
        guard hasEarlyPeak, pelvisStalled, handsStillWorking else { return nil }

        let issue = GarageSyncFlowIssue(
            kind: .hipStall,
            segment: .pelvis,
            jointName: .rightHip,
            timestamp: peakPelvis.timestamp,
            title: "Sequence break: hips stalled",
            detail: "Power slowed in the pelvis before the hands delivered through impact. The swing had to finish with the handle instead of the pivot."
        )
        return CandidateIssue(issue: issue, segmentPriority: segmentPriority(for: .pelvis))
    }

    private static func earlyExtensionCandidate(
        addressFrame: SwingFrame,
        impactFrame: SwingFrame,
        detection: GarageTimestampDetection,
        scorecard: GarageSwingScorecard?
    ) -> CandidateIssue? {
        let driftInches = scorecard?.metrics.pelvicDepth.driftInches
            ?? pelvicDepthDriftInches(addressFrame: addressFrame, impactFrame: impactFrame)
        guard driftInches >= 3.25 else { return nil }

        let issue = GarageSyncFlowIssue(
            kind: .earlyExtension,
            segment: .pelvis,
            jointName: .rightHip,
            timestamp: detection.timestamps.impact,
            title: "Energy leak: pelvis moved in",
            detail: "Pelvic depth drifted toward the ball late in the swing. That narrows space through impact and makes strike quality harder to stabilize."
        )
        return CandidateIssue(issue: issue, segmentPriority: segmentPriority(for: .pelvis))
    }

    private static func unstableHeadCandidate(
        addressFrame: SwingFrame,
        topFrame: SwingFrame,
        impactFrame: SwingFrame,
        detection: GarageTimestampDetection,
        scorecard: GarageSwingScorecard?
    ) -> CandidateIssue? {
        let headComposite = scorecard.map {
            ($0.metrics.headStability.swayInches * 0.6) + ($0.metrics.headStability.dipInches * 0.4)
        } ?? headCompositeInches(addressFrame: addressFrame, topFrame: topFrame, impactFrame: impactFrame)

        guard headComposite >= 3.0 else { return nil }

        let issue = GarageSyncFlowIssue(
            kind: .unstableHead,
            segment: .head,
            jointName: .nose,
            timestamp: detection.timestamps.impact,
            title: "Flow check: head lost stability",
            detail: "Head sway and dip increased late in the motion, so Garage is treating the strike picture as less stable than the rest of the swing."
        )
        return CandidateIssue(issue: issue, segmentPriority: segmentPriority(for: .head))
    }

    static func selectPrimaryIssue(from issues: [GarageSyncFlowIssue]) -> GarageSyncFlowIssue? {
        issues.sorted(by: compareIssues).first
    }

    private nonisolated static func compareIssues(lhs: GarageSyncFlowIssue, rhs: GarageSyncFlowIssue) -> Bool {
        let timeDelta = lhs.timestamp - rhs.timestamp
        if abs(timeDelta) <= sameWindowTolerance {
            let lhsPriority = segmentPriority(for: lhs.segment)
            let rhsPriority = segmentPriority(for: rhs.segment)
            if lhsPriority != rhsPriority {
                return lhsPriority < rhsPriority
            }
            return lhs.kind.rawValue < rhs.kind.rawValue
        }

        return lhs.timestamp < rhs.timestamp
    }

    private static func onsetSample(in samples: [KinematicSample]) -> KinematicSample? {
        guard let peakSpeed = samples.map(\.speed).max(), peakSpeed > 0 else {
            return nil
        }

        let threshold = max(peakSpeed * 0.45, 0.02)
        return samples.dropFirst().first(where: { $0.speed >= threshold })
    }

    private static func trailingAverageSpeed(in samples: [KinematicSample], count: Int) -> Double? {
        let tail = samples.suffix(max(count, 1))
        guard tail.isEmpty == false else { return nil }
        return tail.map(\.speed).reduce(0, +) / Double(tail.count)
    }

    private nonisolated static func pelvisCenter(in frame: SwingFrame) -> CGPoint? {
        guard
            let leftHip = frame.point(named: .leftHip, minimumConfidence: minimumJointConfidence),
            let rightHip = frame.point(named: .rightHip, minimumConfidence: minimumJointConfidence)
        else {
            return nil
        }

        return CGPoint(x: (leftHip.x + rightHip.x) / 2, y: (leftHip.y + rightHip.y) / 2)
    }

    private nonisolated static func torsoCenter(in frame: SwingFrame) -> CGPoint? {
        guard
            let leftShoulder = frame.point(named: .leftShoulder, minimumConfidence: minimumJointConfidence),
            let rightShoulder = frame.point(named: .rightShoulder, minimumConfidence: minimumJointConfidence)
        else {
            return nil
        }

        return CGPoint(x: (leftShoulder.x + rightShoulder.x) / 2, y: (leftShoulder.y + rightShoulder.y) / 2)
    }

    private static func pelvicDepthDriftInches(addressFrame: SwingFrame, impactFrame: SwingFrame) -> Double {
        guard
            let addressPelvis = pelvisCenter(in: addressFrame),
            let impactPelvis = pelvisCenter(in: impactFrame)
        else {
            return 0
        }

        let shoulderWidth = max(GarageAnalysisPipeline.bodyScale(in: addressFrame), 0.0001)
        return (abs(impactPelvis.x - addressPelvis.x) / shoulderWidth) * assumedShoulderWidthInches
    }

    private static func headCompositeInches(
        addressFrame: SwingFrame,
        topFrame: SwingFrame,
        impactFrame: SwingFrame
    ) -> Double {
        guard
            let addressHead = addressFrame.point(named: .nose, minimumConfidence: minimumJointConfidence),
            let topHead = topFrame.point(named: .nose, minimumConfidence: minimumJointConfidence),
            let impactHead = impactFrame.point(named: .nose, minimumConfidence: minimumJointConfidence)
        else {
            return 0
        }

        let shoulderWidth = max(GarageAnalysisPipeline.bodyScale(in: addressFrame), 0.0001)
        let sway = max(abs(topHead.x - addressHead.x), abs(impactHead.x - addressHead.x))
        let dip = max(abs(topHead.y - addressHead.y), abs(impactHead.y - addressHead.y))
        let swayInches = (sway / shoulderWidth) * assumedShoulderWidthInches
        let dipInches = (dip / shoulderWidth) * assumedShoulderWidthInches
        return (swayInches * 0.6) + (dipInches * 0.4)
    }

    private static func consequenceDetail(for kind: GarageSyncFlowIssueKind) -> String {
        switch kind {
        case .earlyHands:
            "The release may outrun the body unless the pivot starts the downswing first."
        case .hipStall:
            "If the pelvis slows too early, the hands have to rescue impact timing."
        case .earlyExtension:
            "Losing depth late reduces space and makes strike quality less repeatable."
        case .unstableHead:
            "When the head drifts late, contact tends to get harder to stabilize."
        }
    }

    private nonisolated static func segmentPriority(for segment: GarageSyncFlowSegment) -> Int {
        switch segment {
        case .base:
            0
        case .pelvis:
            1
        case .torso:
            2
        case .hands:
            3
        case .head:
            4
        }
    }
}

enum GarageScorecardEngine {
    static let unavailableMessage = "Garage couldn't confirm stable DTL landmarks at address, top, and impact."

    static func generate(frames: [SwingFrame], keyFrames: [KeyFrame]) -> GarageSwingScorecard? {
        guard let detection = GarageTimestampDetector.detect(from: frames, keyFrames: keyFrames) else {
            return nil
        }

        let normalizationProfile = GarageScoreNormalizationProfile.dtlV1
        guard let metrics = GarageSwingMeasurementEngine.measure(
            frames: frames,
            detection: detection,
            profile: normalizationProfile
        ) else {
            return nil
        }

        let domains = scoreDomains(for: metrics, profile: normalizationProfile)
        let total = Int((Double(domains.map(\.score).reduce(0, +))).rounded())

        return GarageSwingScorecard(
            timestamps: detection.timestamps,
            metrics: metrics,
            domainScores: domains,
            totalScore: min(max(total, 0), 100)
        )
    }

    private static func scoreDomains(
        for metrics: GarageSwingMetrics,
        profile: GarageScoreNormalizationProfile
    ) -> [GarageSwingDomainScore] {
        GarageSwingDomain.allCases.map { domain in
            let normalized = profile.normalizedScore(for: domain, metrics: metrics)
            let score = Int((normalized * 20).rounded())
            return GarageSwingDomainScore(
                id: domain.rawValue,
                title: domain.title,
                score: min(max(score, 0), 20),
                grade: .from(score: normalized),
                displayValue: displayValue(for: domain, metrics: metrics)
            )
        }
    }

    private static func displayValue(for domain: GarageSwingDomain, metrics: GarageSwingMetrics) -> String {
        switch domain {
        case .tempo:
            return String(format: "%.1f : 1", metrics.tempo.ratio)
        case .spine:
            return String(format: "%.1f°", metrics.spine.deltaDegrees)
        case .pelvis:
            return String(format: "%.1f in", metrics.pelvicDepth.driftInches)
        case .knee:
            return String(
                format: "Left %.0f° / Right %.0f°",
                metrics.kneeFlex.leftDeltaDegrees,
                metrics.kneeFlex.rightDeltaDegrees
            )
        case .head:
            return String(format: "Sway %.1f in · Dip %.1f in", metrics.headStability.swayInches, metrics.headStability.dipInches)
        }
    }
}
