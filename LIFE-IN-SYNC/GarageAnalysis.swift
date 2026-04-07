import AVFoundation
import Foundation
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

        return SwingFrame(timestamp: frame.timestamp, joints: smoothedJoints, confidence: frame.confidence)
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
    let analysisResult: AnalysisResult
}

struct GarageVideoAssetMetadata: Equatable {
    let duration: Double
    let frameRate: Double
    let naturalSize: CGSize
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

enum GarageReliability {
    static func report(for record: SwingRecord) -> GarageReliabilityReport {
        let videoAvailable = GarageMediaStore.resolvedReviewVideoURL(for: record) != nil
        let hasFrames = record.swingFrames.isEmpty == false
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

        let checks = [
            GarageReliabilityCheck(
                title: "Video Source",
                passed: videoAvailable && hasFrames,
                detail: videoAvailable && hasFrames
                    ? "Stored video and sampled pose frames are available."
                    : "Garage cannot fully verify this swing until the stored video and sampled frames are available."
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

        let sortedCues = cues.sorted { lhs, rhs in
            severityPriority(lhs.severity) > severityPriority(rhs.severity)
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
            nextBestAction = "Keep building comparable swings so the strongest patterns become easier to trust."
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
        let hasFrames = record.swingFrames.isEmpty == false
        let resolvedURL = GarageMediaStore.resolvedReviewVideoURL(for: record)

        let status: GarageWorkflowStatus
        let summary: String
        let actionLabel: String

        if hasVideoReference == false {
            status = .incomplete
            summary = "Import one swing video to initialize Garage."
            actionLabel = "Import video"
        } else if resolvedURL == nil || hasFrames == false {
            status = .needsAttention
            summary = "The video reference exists, but Garage cannot currently use it for the workflow."
            actionLabel = "Re-import video"
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

    static func resolvedReviewVideoURL(for record: SwingRecord) -> URL? {
        if let reviewFilename = record.reviewMasterFilename,
           let url = persistedAssetURL(for: reviewFilename, kind: .reviewMaster) {
            return url
        }

        if let legacyFilename = record.mediaFilename,
           let url = persistedAssetURL(for: legacyFilename, kind: .legacyRoot) {
            return url
        }

        return nil
    }

    static func resolvedExportVideoURL(for record: SwingRecord) -> URL? {
        guard let exportFilename = record.preferredExportFilename else {
            return nil
        }

        return persistedAssetURL(for: exportFilename, kind: .exportAsset)
    }

    static func thumbnail(for videoURL: URL, at timestamp: Double, maximumSize: CGSize = CGSize(width: 480, height: 480)) async -> CGImage? {
        await withCheckedContinuation { continuation in
            let asset = AVURLAsset(url: videoURL)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = maximumSize
            generator.requestedTimeToleranceAfter = .zero
            generator.requestedTimeToleranceBefore = .zero

            let time = CMTime(seconds: timestamp, preferredTimescale: 600)
            generator.generateCGImageAsynchronously(for: time) { image, _, _ in
                continuation.resume(returning: image.flatMap(normalizedDisplayImage(from:)))
            }
        }
    }

    static func assetMetadata(for videoURL: URL) async -> GarageVideoAssetMetadata? {
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

            return GarageVideoAssetMetadata(
                duration: max(CMTimeGetSeconds(duration), 0),
                frameRate: nominalFrameRate > 0 ? Double(nominalFrameRate) : 0,
                naturalSize: CGSize(width: abs(transformedSize.width), height: abs(transformedSize.height))
            )
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

    static func analyzeVideo(at videoURL: URL) async throws -> GarageAnalysisOutput {
        let asset = AVURLAsset(url: videoURL)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = tracks.first else {
            throw GarageAnalysisError.missingVideoTrack
        }

        let duration = try await asset.load(.duration)
        let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
        let samplingFrameRate = resolvedSamplingFrameRate(from: nominalFrameRate)
        let timestamps = sampledTimestamps(duration: duration, frameRate: samplingFrameRate)
        let extractedFrames = try extractPoseFrames(from: asset, timestamps: timestamps)
        let smoothedFrames = smooth(frames: extractedFrames)

        guard smoothedFrames.count >= SwingPhase.allCases.count else {
            throw GarageAnalysisError.insufficientPoseFrames
        }

        let keyFrames = detectKeyFrames(from: smoothedFrames)
        let handAnchors = deriveHandAnchors(from: smoothedFrames, keyFrames: keyFrames)
        let pathPoints = generatePathPoints(from: smoothedFrames, samplesPerSegment: 8)
        let analysisResult = AnalysisResult(
            issues: [],
            highlights: [
                "Eight deterministic keyframes detected from normalized pose frames.",
                "\(handAnchors.count) hand checkpoints are aligned to the saved review phases."
            ],
            summary: "Processed \(smoothedFrames.count) frames at \(Int(samplingFrameRate.rounded())) FPS, mapped all eight swing phases, and prepared a review-ready hand path."
        )

        return GarageAnalysisOutput(
            frameRate: samplingFrameRate,
            swingFrames: smoothedFrames,
            keyFrames: keyFrames,
            handAnchors: handAnchors,
            pathPoints: pathPoints,
            analysisResult: analysisResult
        )
    }

    private static func resolvedSamplingFrameRate(from nominalFrameRate: Float) -> Double {
        let baseRate = nominalFrameRate > 0 ? Double(nominalFrameRate) : 30
        return min(max(baseRate, 30), 60)
    }

    private static func sampledTimestamps(duration: CMTime, frameRate: Double) -> [Double] {
        let seconds = max(CMTimeGetSeconds(duration), 0)
        guard seconds > 0 else { return [] }

        let interval = 1 / frameRate
        var timestamps: [Double] = []
        var current: Double = 0
        while current < seconds {
            timestamps.append(current)
            current += interval
        }

        if let last = timestamps.last, seconds - last > 0.01 {
            timestamps.append(seconds)
        }

        return timestamps
    }

    private static func extractPoseFrames(from asset: AVAsset, timestamps: [Double]) throws -> [SwingFrame] {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 960, height: 960)
        generator.requestedTimeToleranceAfter = .zero
        generator.requestedTimeToleranceBefore = .zero

        var frames: [SwingFrame] = []
        for timestamp in timestamps {
            let time = CMTime(seconds: timestamp, preferredTimescale: 600)
            guard let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) else {
                continue
            }

            if let frame = try detectPoseFrame(from: cgImage, timestamp: timestamp) {
                frames.append(frame)
            }
        }

        return frames
    }

    private static func detectPoseFrame(from cgImage: CGImage, timestamp: Double) throws -> SwingFrame? {
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
        try handler.perform([request])

        guard let observation = request.results?.first else {
            return nil
        }

        let recognizedPoints = try observation.recognizedPoints(.all)
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

        let confidence = joints.map(\.confidence).reduce(0, +) / Double(joints.count)
        return SwingFrame(timestamp: timestamp, joints: joints, confidence: confidence)
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
        let addressIndex = 0
        let topIndex = topOfBackswingIndex(in: frames, fallbackStart: addressIndex + 2)
        let takeawayIndex = takeawayIndex(in: frames, addressIndex: addressIndex, topIndex: topIndex)
        let shaftParallelIndex = shaftParallelIndex(in: frames, addressIndex: addressIndex, takeawayIndex: takeawayIndex, topIndex: topIndex)
        let transitionIndex = transitionIndex(in: frames, topIndex: topIndex)
        let impactIndex = impactIndex(in: frames, addressIndex: addressIndex, transitionIndex: transitionIndex)
        let earlyDownswingIndex = earlyDownswingIndex(in: frames, transitionIndex: transitionIndex, impactIndex: impactIndex)
        let followThroughIndex = followThroughIndex(in: frames, impactIndex: impactIndex)

        return [
            KeyFrame(phase: .address, frameIndex: addressIndex),
            KeyFrame(phase: .takeaway, frameIndex: takeawayIndex),
            KeyFrame(phase: .shaftParallel, frameIndex: shaftParallelIndex),
            KeyFrame(phase: .topOfBackswing, frameIndex: topIndex),
            KeyFrame(phase: .transition, frameIndex: transitionIndex),
            KeyFrame(phase: .earlyDownswing, frameIndex: earlyDownswingIndex),
            KeyFrame(phase: .impact, frameIndex: impactIndex),
            KeyFrame(phase: .followThrough, frameIndex: followThroughIndex)
        ]
    }

    static func deriveHandAnchors(from frames: [SwingFrame], keyFrames: [KeyFrame]) -> [HandAnchor] {
        let orderedKeyFrames = keyFrames.sorted { lhs, rhs in
            (SwingPhase.allCases.firstIndex(of: lhs.phase) ?? 0) < (SwingPhase.allCases.firstIndex(of: rhs.phase) ?? 0)
        }

        return orderedKeyFrames.compactMap { keyFrame in
            guard frames.indices.contains(keyFrame.frameIndex) else {
                return nil
            }

            let center = handCenter(in: frames[keyFrame.frameIndex])
            return HandAnchor(phase: keyFrame.phase, x: center.x, y: center.y)
        }
    }

    private static func topOfBackswingIndex(in frames: [SwingFrame], fallbackStart: Int) -> Int {
        let samples = handKinematics(from: frames)
        guard samples.count >= 4 else {
            return min(max(fallbackStart, frames.count / 3), max(frames.count - 3, 0))
        }

        let searchStart = min(max(fallbackStart, 1), samples.count - 2)
        let searchEnd = max(searchStart + 1, samples.count - 1)
        let range = searchStart..<searchEnd

        let candidate = range.first { index in
            let previous = samples[index - 1].velocity.dx
            let current = samples[index].velocity.dx
            let vertical = abs(samples[index].velocity.dy)
            return previous > KinematicThresholds.reversalVelocityEpsilon
                && current < -KinematicThresholds.reversalVelocityEpsilon
                && vertical < KinematicThresholds.reversalVelocityEpsilon * 2
        }

        if let candidate {
            return samples[candidate - 1].index
        }

        let fallback = range.min { lhs, rhs in
            abs(samples[lhs].velocity.dy) < abs(samples[rhs].velocity.dy)
        }

        return fallback.map { samples[$0].index } ?? min(max(fallbackStart, frames.count / 3), max(frames.count - 3, 0))
    }

    private static func takeawayIndex(in frames: [SwingFrame], addressIndex: Int, topIndex: Int) -> Int {
        let addressHands = handCenter(in: frames[addressIndex])
        let shoulderWidth = bodyScale(in: frames[addressIndex])
        let horizontalThreshold = max(0.03, shoulderWidth * 0.18)

        for index in (addressIndex + 1)..<max(topIndex, addressIndex + 2) {
            let horizontalDisplacement = abs(handCenter(in: frames[index]).x - addressHands.x)
            if horizontalDisplacement >= horizontalThreshold {
                return index
            }
        }

        return min(addressIndex + 1, max(topIndex - 1, addressIndex))
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

    private static func transitionIndex(in frames: [SwingFrame], topIndex: Int) -> Int {
        let topHands = handCenter(in: frames[topIndex])
        let torsoHeight = torsoHeight(in: frames[topIndex])
        let downwardThreshold = max(0.015, torsoHeight * 0.06)

        for index in (topIndex + 1)..<frames.count {
            let handY = handCenter(in: frames[index]).y
            if handY - topHands.y >= downwardThreshold {
                return index
            }
        }

        return min(topIndex + 1, frames.count - 1)
    }

    private static func earlyDownswingIndex(in frames: [SwingFrame], transitionIndex: Int, impactIndex: Int) -> Int {
        guard transitionIndex + 1 < impactIndex else {
            return min(transitionIndex + 1, impactIndex)
        }

        let transitionHands = handCenter(in: frames[transitionIndex])
        let impactHands = handCenter(in: frames[impactIndex])
        let targetDistance = distance(from: transitionHands, to: impactHands) * 0.35

        let range = (transitionIndex + 1)..<impactIndex
        return range.min { lhs, rhs in
            let lhsDelta = abs(distance(from: transitionHands, to: handCenter(in: frames[lhs])) - targetDistance)
            let rhsDelta = abs(distance(from: transitionHands, to: handCenter(in: frames[rhs])) - targetDistance)
            return lhsDelta < rhsDelta
        } ?? min(transitionIndex + 1, impactIndex)
    }

    private static func impactIndex(in frames: [SwingFrame], addressIndex _: Int, transitionIndex: Int) -> Int {
        let samples = handKinematics(from: frames)
        guard samples.count >= 4 else { return frames.count - 1 }

        let searchStart = max(transitionIndex + 1, 1)
        guard searchStart < samples.count else { return frames.count - 1 }

        let candidateSamples = Array(samples[searchStart..<samples.count])
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
        let left = frame.point(named: .leftWrist)
        let right = frame.point(named: .rightWrist)
        return CGPoint(x: (left.x + right.x) / 2, y: (left.y + right.y) / 2)
    }

    static func bodyScale(in frame: SwingFrame) -> Double {
        distance(from: frame.point(named: .leftShoulder), to: frame.point(named: .rightShoulder))
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
        let stabilizedPoints = frames.map { handCenter(in: $0) }
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

        var samples: [GarageHandKinematicSample] = []
        samples.reserveCapacity(frames.count - 1)
        var previousCenter = handCenter(in: frames[0])
        var previousTime = frames[0].timestamp

        for index in 1..<frames.count {
            let currentCenter = handCenter(in: frames[index])
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

extension SwingFrame {
    func point(named name: SwingJointName) -> CGPoint {
        guard let joint = joints.first(where: { $0.name == name }) else {
            return .zero
        }
        return CGPoint(x: joint.x, y: joint.y)
    }
}
