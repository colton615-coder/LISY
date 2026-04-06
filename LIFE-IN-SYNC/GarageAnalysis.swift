import AVFoundation
import CoreImage
import Foundation
import OSLog
import Vision

struct GarageAnalysisOutput {
    let frameRate: Double
    let decodedFrames: [DecodedFrameRecord]
    let decodedFrameTimestamps: [Double]
    let swingFrames: [SwingFrame]
    let keyFrames: [KeyFrame]
    let analysisResult: AnalysisResult
}

let garageFrameLogger = Logger(subsystem: "LIFE_IN_SYNC", category: "GarageFrameNavigation")

struct GarageRenderedFrameResult {
    let image: CGImage
    let requestedDecodedFrameIndex: Int
    let renderedDecodedFrameIndex: Int
    let renderedTimestamp: Double
    let imageSource: String
    let fallbackUsed: Bool
    let fallbackReason: String?
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

enum GarageCaptureSeverity: String, Equatable {
    case good = "Good"
    case review = "Review"
    case poor = "Poor"
}

struct GarageCaptureFinding: Identifiable, Equatable {
    let title: String
    let detail: String
    let severity: GarageCaptureSeverity

    var id: String { title }
}

struct GarageCaptureQualityReport: Equatable {
    let status: GarageCaptureSeverity
    let headline: String
    let summary: String
    let benchmark: String
    let findings: [GarageCaptureFinding]
    let primaryCause: String
}

struct GarageEvaluationPhaseSnapshot: Identifiable, Codable, Equatable {
    let phase: String
    let reviewTitle: String
    let frameIndex: Int
    let timestamp: Double
    let source: String
    let health: String
    let notes: [String]

    var id: String { phase }
}

struct GarageEvaluationSnapshot: Codable, Equatable {
    let title: String
    let mediaFilename: String?
    let frameRate: Double
    let sampledFrameCount: Int
    let keyframeValidationStatus: String
    let reliabilityStatus: String
    let reliabilityScore: Int
    let captureStatus: String
    let capturePrimaryCause: String
    let captureBenchmark: String
    let issues: [String]
    let weakestPhases: [String]
    let phases: [GarageEvaluationPhaseSnapshot]
}

enum GaragePhaseHealth: String, Codable, Equatable {
    case strong = "Strong"
    case review = "Review"
    case weak = "Weak"
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
        let frameIndexes = orderedKeyframes.map { resolvedVideoFrameIndex(for: $0, in: record) }
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
        guard let keyFrame = record.keyFrames.first(where: { $0.phase == phase }) else {
            return nil
        }
        return resolvedTimestamp(for: keyFrame, in: record)
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
        guard let keyFrame = record.keyFrames.first(where: { $0.phase == phase }) else {
            return nil
        }
        return resolvedPoseFrame(for: keyFrame, in: record)
    }

    private static func formattedSeconds(_ value: Double) -> String {
        String(format: "%.2fs", value)
    }

    private static func uniqueStrings(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}

enum GarageCaptureQuality {
    static func report(for record: SwingRecord) -> GarageCaptureQualityReport {
        guard record.swingFrames.isEmpty == false else {
            return GarageCaptureQualityReport(
                status: .poor,
                headline: "Garage could not sample the swing.",
                summary: "There are not enough pose frames to judge framing or checkpoint quality.",
                benchmark: "Below the clean 8-frame benchmark.",
                findings: [
                    GarageCaptureFinding(
                        title: "No pose coverage",
                        detail: "Garage needs readable body pose frames before it can judge capture quality.",
                        severity: .poor
                    )
                ],
                primaryCause: "Missing pose coverage"
            )
        }

        var findings: [GarageCaptureFinding] = []

        let bodyHeights = record.swingFrames.compactMap { bodyHeight(in: $0) }
        let averageBodyHeight = bodyHeights.isEmpty ? 0 : bodyHeights.reduce(0, +) / Double(bodyHeights.count)
        if averageBodyHeight < 0.58 {
            findings.append(
                GarageCaptureFinding(
                    title: "Golfer looks small in frame",
                    detail: "The body occupies a limited share of the image, which makes the 8 checkpoints harder to separate cleanly.",
                    severity: .review
                )
            )
        }

        if let topFrame = phaseFrame(.topOfBackswing, in: record),
           highestTrackedPointY(in: topFrame) < 0.08 {
            findings.append(
                GarageCaptureFinding(
                    title: "Top of swing is crowding the upper edge",
                    detail: "The hands or club proxy approach the top border at the top of the swing, so backswing framing may be tight.",
                    severity: .review
                )
            )
        }

        if let followThroughFrame = phaseFrame(.followThrough, in: record),
           highestTrackedPointY(in: followThroughFrame) < 0.05 {
            findings.append(
                GarageCaptureFinding(
                    title: "Finish frame is tight",
                    detail: "The follow-through reaches close to the top edge, which can make the finish checkpoint less readable.",
                    severity: .review
                )
            )
        }

        if let topFrame = phaseFrame(.topOfBackswing, in: record),
           horizontalMargin(in: topFrame) < 0.08 {
            findings.append(
                GarageCaptureFinding(
                    title: "Swing is nearing the side edge",
                    detail: "The hands get close to the left or right border, which can weaken checkpoint spacing and path quality.",
                    severity: .review
                )
            )
        }

        if let addressFrame = phaseFrame(.address, in: record),
           lowestTrackedPointY(in: addressFrame) > 0.98 {
            findings.append(
                GarageCaptureFinding(
                    title: "Feet are near the bottom edge",
                    detail: "Full-body visibility is tight near the ground, so setup scale may be too constrained.",
                    severity: .review
                )
            )
        }

        let averageConfidence = record.swingFrames.map(\.confidence).reduce(0, +) / Double(record.swingFrames.count)
        if averageConfidence < 0.6 {
            findings.append(
                GarageCaptureFinding(
                    title: "Pose confidence is weak",
                    detail: "Low pose confidence usually points to lighting, background clutter, or a hard-to-read angle.",
                    severity: .poor
                )
            )
        }

        let spacingReport = keyframeSpacingReport(for: record)
        if let spacingFinding = spacingReport.finding {
            findings.append(spacingFinding)
        }

        let adjustedFrames = record.keyFrames.filter { $0.source == .adjusted }.count
        if adjustedFrames >= 3 {
            findings.append(
                GarageCaptureFinding(
                    title: "Analyzer needed heavy manual rescue",
                    detail: "\(adjustedFrames) checkpoints were manually moved, so the default pass is not yet trustworthy enough on its own.",
                    severity: .poor
                )
            )
        }

        if findings.isEmpty {
            findings.append(
                GarageCaptureFinding(
                    title: "Capture looks usable",
                    detail: "Body scale, frame coverage, and phase spacing are close to the standard needed for a clean 8-frame sequence.",
                    severity: .good
                )
            )
        }

        let status: GarageCaptureSeverity
        if findings.contains(where: { $0.severity == .poor }) {
            status = .poor
        } else if findings.contains(where: { $0.severity == .review }) {
            status = .review
        } else {
            status = .good
        }

        let primaryCause = findings
            .sorted { severityRank($0.severity) > severityRank($1.severity) }
            .first?.title ?? "Capture looks usable"

        let headline: String
        let summary: String
        let benchmark: String

        switch status {
        case .good:
            headline = "This swing is close to a believable 8-frame benchmark."
            summary = "Garage sees enough framing quality and phase separation to support a cleaner checkpoint sequence."
            benchmark = "Comparable to a clean 8-frame grid."
        case .review:
            headline = "This swing needs review before the 8 positions can be trusted."
            summary = "Garage sees one or more capture or spacing risks that can make the sequence look approximate rather than clean."
            benchmark = "Below the clean 8-frame benchmark."
        case .poor:
            headline = "Garage does not trust this 8-frame result yet."
            summary = "The current result is likely being hurt by capture quality, weak detection, or collapsed phase spacing."
            benchmark = "Well below the clean 8-frame benchmark."
        }

        return GarageCaptureQualityReport(
            status: status,
            headline: headline,
            summary: summary,
            benchmark: benchmark,
            findings: findings,
            primaryCause: primaryCause
        )
    }

    private static func severityRank(_ severity: GarageCaptureSeverity) -> Int {
        switch severity {
        case .poor:
            3
        case .review:
            2
        case .good:
            1
        }
    }

    private static func keyframeSpacingReport(for record: SwingRecord) -> (finding: GarageCaptureFinding?, minimumGap: Int) {
        let ordered = record.keyFrames.sorted { lhs, rhs in
            (SwingPhase.allCases.firstIndex(of: lhs.phase) ?? 0) < (SwingPhase.allCases.firstIndex(of: rhs.phase) ?? 0)
        }
        let indexes = ordered.map { resolvedVideoFrameIndex(for: $0, in: record) }
        guard indexes.count >= 2 else {
            return (nil, 0)
        }

        let gaps = zip(indexes, indexes.dropFirst()).map { max($1 - $0, 0) }
        let minimumGap = gaps.min() ?? 0
        let lateSwingGaps = Array(gaps.suffix(3))

        if lateSwingGaps.contains(where: { $0 <= 1 }) || minimumGap <= 1 {
            return (
                GarageCaptureFinding(
                    title: "Late swing positions are collapsing together",
                    detail: "Several checkpoints are nearly adjacent, especially in transition, downswing, impact, or finish. That usually means weak detection or poor clip framing.",
                    severity: .poor
                ),
                minimumGap
            )
        }

        if minimumGap <= 2 {
            return (
                GarageCaptureFinding(
                    title: "Some checkpoints are tightly packed",
                    detail: "The 8-frame progression is present, but a few positions are still closer together than a clean reference sequence.",
                    severity: .review
                ),
                minimumGap
            )
        }

        return (nil, minimumGap)
    }

    private static func bodyHeight(in frame: SwingFrame) -> Double? {
        let nose = point(named: .nose, in: frame)
        let leftAnkle = point(named: .leftAnkle, in: frame)
        let rightAnkle = point(named: .rightAnkle, in: frame)
        guard nose != .zero, leftAnkle != .zero || rightAnkle != .zero else {
            return nil
        }

        let ankleY = max(leftAnkle.y, rightAnkle.y)
        return max(ankleY - nose.y, 0)
    }

    private static func highestTrackedPointY(in frame: SwingFrame) -> Double {
        let points = [point(named: .nose, in: frame), point(named: .leftWrist, in: frame), point(named: .rightWrist, in: frame)]
            .filter { $0 != .zero }
        guard let minY = points.map(\.y).min() else {
            return 0
        }
        return Double(minY)
    }

    private static func lowestTrackedPointY(in frame: SwingFrame) -> Double {
        let points = [point(named: .leftAnkle, in: frame), point(named: .rightAnkle, in: frame), point(named: .leftHip, in: frame), point(named: .rightHip, in: frame)]
            .filter { $0 != .zero }
        guard let maxY = points.map(\.y).max() else {
            return 1
        }
        return Double(maxY)
    }

    private static func horizontalMargin(in frame: SwingFrame) -> Double {
        let points = [point(named: .leftWrist, in: frame), point(named: .rightWrist, in: frame), point(named: .nose, in: frame)]
            .filter { $0 != .zero }
        guard let minX = points.map(\.x).min(), let maxX = points.map(\.x).max() else {
            return 0
        }
        return Double(min(minX, 1 - maxX))
    }

    private static func point(named name: SwingJointName, in frame: SwingFrame) -> CGPoint {
        frame.point(named: name)
    }

    private static func phaseFrame(_ phase: SwingPhase, in record: SwingRecord) -> SwingFrame? {
        guard let keyFrame = record.keyFrames.first(where: { $0.phase == phase }) else {
            return nil
        }

        return resolvedPoseFrame(for: keyFrame, in: record)
    }
}

enum GarageEvaluationHarness {
    static func snapshot(for record: SwingRecord) -> GarageEvaluationSnapshot {
        let reliabilityReport = GarageReliability.report(for: record)
        let captureReport = GarageCaptureQuality.report(for: record)
        let orderedPhases = record.keyFrames.sorted { lhs, rhs in
            (SwingPhase.allCases.firstIndex(of: lhs.phase) ?? 0) < (SwingPhase.allCases.firstIndex(of: rhs.phase) ?? 0)
        }
        let phaseDiagnostics = phaseDiagnostics(for: record, orderedPhases: orderedPhases)

        let phaseSnapshots = orderedPhases.map { keyFrame in
            let diagnostics = phaseDiagnostics[keyFrame.phase] ?? PhaseDiagnostic(health: .review, notes: ["No phase diagnostics available."])
            return GarageEvaluationPhaseSnapshot(
                phase: keyFrame.phase.rawValue,
                reviewTitle: keyFrame.phase.reviewTitle,
                frameIndex: resolvedVideoFrameIndex(for: keyFrame, in: record),
                timestamp: phaseTimestamp(for: keyFrame.phase, in: record) ?? 0,
                source: keyFrame.source.rawValue,
                health: diagnostics.health.rawValue,
                notes: diagnostics.notes
            )
        }

        let issues = captureReport.findings
            .filter { $0.severity != .good }
            .map(\.detail)
        let weakestPhases = phaseSnapshots
            .filter { $0.health != GaragePhaseHealth.strong.rawValue }
            .sorted { healthRank($0.health) > healthRank($1.health) }
            .map(\.reviewTitle)

        return GarageEvaluationSnapshot(
            title: record.title,
            mediaFilename: record.mediaFilename,
            frameRate: record.frameRate,
            sampledFrameCount: record.swingFrames.count,
            keyframeValidationStatus: record.keyframeValidationStatus.rawValue,
            reliabilityStatus: reliabilityReport.status.rawValue,
            reliabilityScore: reliabilityReport.score,
            captureStatus: captureReport.status.rawValue,
            capturePrimaryCause: captureReport.primaryCause,
            captureBenchmark: captureReport.benchmark,
            issues: issues,
            weakestPhases: weakestPhases,
            phases: phaseSnapshots
        )
    }

    private static func phaseTimestamp(for phase: SwingPhase, in record: SwingRecord) -> Double? {
        guard let keyFrame = record.keyFrames.first(where: { $0.phase == phase }) else {
            return nil
        }

        return resolvedTimestamp(for: keyFrame, in: record)
    }

    private static func phaseFrame(for phase: SwingPhase, in record: SwingRecord) -> SwingFrame? {
        guard let keyFrame = record.keyFrames.first(where: { $0.phase == phase }) else {
            return nil
        }

        return resolvedPoseFrame(for: keyFrame, in: record)
    }

    private static func phaseDiagnostics(
        for record: SwingRecord,
        orderedPhases: [KeyFrame]
    ) -> [SwingPhase: PhaseDiagnostic] {
        let indexes = orderedPhases.map { resolvedVideoFrameIndex(for: $0, in: record) }
        let averageConfidence = record.swingFrames.isEmpty
            ? 0
            : record.swingFrames.map(\.confidence).reduce(0, +) / Double(record.swingFrames.count)

        var diagnostics: [SwingPhase: PhaseDiagnostic] = [:]

        for (position, keyFrame) in orderedPhases.enumerated() {
            var notes: [String] = []
            let currentIndex = resolvedVideoFrameIndex(for: keyFrame, in: record)
            let previousGap = position > 0 ? currentIndex - indexes[position - 1] : nil
            let nextGap = position < indexes.count - 1 ? indexes[position + 1] - currentIndex : nil
            let localConfidence = phaseFrame(for: keyFrame.phase, in: record)?.confidence ?? averageConfidence

            if let previousGap, previousGap <= 1 {
                notes.append("This checkpoint is nearly collapsed into the previous phase.")
            } else if let previousGap, previousGap <= 2 {
                notes.append("This checkpoint is tightly packed against the previous phase.")
            }

            if let nextGap, nextGap <= 1 {
                notes.append("This checkpoint is nearly collapsed into the next phase.")
            } else if let nextGap, nextGap <= 2 {
                notes.append("This checkpoint is tightly packed against the next phase.")
            }

            if localConfidence < 0.55 {
                notes.append("Pose confidence is weak here, so the frame may not be stable.")
            }

            if keyFrame.source == .adjusted {
                notes.append("This frame was manually adjusted after auto-detection.")
            }

            if notes.isEmpty {
                notes.append("This checkpoint looks meaningfully separated from adjacent phases.")
            }

            let health: GaragePhaseHealth
            if notes.contains(where: { $0.contains("nearly collapsed") || $0.contains("weak") }) {
                health = .weak
            } else if notes.contains(where: { $0.contains("tightly packed") || $0.contains("adjusted") }) {
                health = .review
            } else {
                health = .strong
            }

            diagnostics[keyFrame.phase] = PhaseDiagnostic(health: health, notes: notes)
        }

        return diagnostics
    }

    private static func healthRank(_ health: String) -> Int {
        switch health {
        case GaragePhaseHealth.weak.rawValue:
            3
        case GaragePhaseHealth.review.rawValue:
            2
        default:
            1
        }
    }
}

private struct PhaseDiagnostic {
    let health: GaragePhaseHealth
    let notes: [String]
}

enum GarageReliability {
    static func report(for record: SwingRecord) -> GarageReliabilityReport {
        let captureReport = GarageCaptureQuality.report(for: record)
        let videoAvailable = GarageMediaStore.persistedVideoURL(for: record.mediaFilename) != nil
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
                title: "Capture Quality",
                passed: captureReport.status == .good,
                detail: captureReport.status == .good
                    ? "Capture framing and sequence spacing are close to the clean 8-frame benchmark."
                    : captureReport.primaryCause
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

        let weightedChecks: [(GarageReliabilityCheck, Int)] = Array(zip(checks, [12, 16, 17, 18, 20, 9, 8]))
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
        let hasVideoReference = record.mediaFilename?.isEmpty == false
        let hasFrames = record.swingFrames.isEmpty == false
        let resolvedURL = GarageMediaStore.persistedVideoURL(for: record.mediaFilename)

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
        let captureReport = GarageCaptureQuality.report(for: record)

        let status: GarageWorkflowStatus
        let summary: String
        let actionLabel: String

        if hasAllKeyframes == false {
            status = .incomplete
            summary = "Garage needs all 8 swing checkpoints before the rest of the workflow can be trusted."
            actionLabel = "Finish keyframes"
        } else if record.keyframeValidationStatus == .flagged || keyframesMonotonic == false || captureReport.status != .good {
            status = .needsAttention
            summary = captureReport.status == .good
                ? "Review the saved keyframes before trusting anchors or downstream insights."
                : "The 8-frame sequence is not yet trustworthy enough. Check capture quality and phase spacing before continuing."
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
        let frameIndexes = ordered.map(\.decodedFrameIndex)
        return frameIndexes == frameIndexes.sorted()
    }
}

enum GarageAnalysisError: LocalizedError {
    case missingVideoTrack
    case insufficientPoseFrames
    case failedToPersistVideo
    case unsupportedInSimulator

    var errorDescription: String? {
        switch self {
        case .missingVideoTrack:
            "The selected file does not contain a readable video track."
        case .insufficientPoseFrames:
            "The video did not produce enough pose frames for keyframe detection."
        case .failedToPersistVideo:
            "The selected video could not be copied into local storage."
        case .unsupportedInSimulator:
            "Golf Garage pose analysis is not available in iPhone Simulator. Run this flow on a physical iPhone."
        }
    }
}

enum GarageMediaStore {
    private static let frameContext = CIContext(options: nil)

    static func persistVideo(from sourceURL: URL) throws -> URL {
        let directoryURL = try garageDirectoryURL()
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

    static func persistedVideoURL(for filename: String?) -> URL? {
        guard let filename, filename.isEmpty == false else {
            return nil
        }

        guard let directoryURL = try? garageDirectoryURL() else {
            return nil
        }

        let url = directoryURL.appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    static func thumbnail(
        for videoURL: URL,
        decodedFrameIndex: Int,
        maximumSize: CGSize = CGSize(width: 480, height: 480)
    ) async -> GarageRenderedFrameResult? {
        guard let exactFrame = await exactDecodedThumbnail(
            for: videoURL,
            decodedFrameIndex: decodedFrameIndex,
            maximumSize: maximumSize
        ) else {
            return nil
        }

        garageFrameLogger.log(
            """
            frame-render requestedFrameIndex=\(decodedFrameIndex) requestedTimestamp=\(exactFrame.timestamp, format: .fixed(precision: 6)) actualReturnedTimestamp=\(exactFrame.timestamp, format: .fixed(precision: 6)) decodedFrameIndex=\(decodedFrameIndex) exactDecode=true roi=(0.0,0.0,1.0,1.0) landmarkDisplacement=0.000000
            """
        )
        return GarageRenderedFrameResult(
            image: exactFrame.image,
            requestedDecodedFrameIndex: decodedFrameIndex,
            renderedDecodedFrameIndex: exactFrame.decodedFrameIndex,
            renderedTimestamp: exactFrame.timestamp,
            imageSource: "sequential_decode",
            fallbackUsed: false,
            fallbackReason: nil
        )
    }

    private static func exactDecodedThumbnail(
        for videoURL: URL,
        decodedFrameIndex: Int,
        maximumSize: CGSize
    ) async -> (image: CGImage, timestamp: Double, decodedFrameIndex: Int)? {
        let asset = AVURLAsset(url: videoURL)
        guard let track = try? await asset.loadTracks(withMediaType: .video).first else {
            return nil
        }

        guard let reader = try? AVAssetReader(asset: asset) else {
            return nil
        }

        let output = AVAssetReaderVideoCompositionOutput(
            videoTracks: [track],
            videoSettings: [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        )
        output.alwaysCopiesSampleData = false
        output.videoComposition = AVMutableVideoComposition(propertiesOf: asset)

        guard reader.canAdd(output) else {
            return nil
        }

        reader.add(output)
        guard reader.startReading() else {
            return nil
        }

        var currentFrameIndex = 0
        while reader.status == .reading, let sampleBuffer = output.copyNextSampleBuffer() {
            defer { CMSampleBufferInvalidate(sampleBuffer) }

            guard currentFrameIndex == decodedFrameIndex else {
                currentFrameIndex += 1
                continue
            }

            guard
                let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
                let cgImage = cgImage(
                    from: imageBuffer,
                    maximumSize: maximumSize
                )
            else {
                return nil
            }

            return (
                cgImage,
                CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds,
                currentFrameIndex
            )
        }

        return nil
    }

    private static func cgImage(
        from pixelBuffer: CVPixelBuffer,
        maximumSize: CGSize
    ) -> CGImage? {
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        let normalizedExtent = image.extent.integral
        guard normalizedExtent.isEmpty == false else {
            return nil
        }

        let scale = min(maximumSize.width / normalizedExtent.width, maximumSize.height / normalizedExtent.height, 1)
        let outputImage = scale < 1
            ? image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            : image
        return frameContext.createCGImage(outputImage, from: outputImage.extent.integral)
    }

    private static func garageDirectoryURL() throws -> URL {
        let baseURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let garageURL = baseURL.appendingPathComponent("GarageSwingVideos", isDirectory: true)
        if FileManager.default.fileExists(atPath: garageURL.path) == false {
            try FileManager.default.createDirectory(at: garageURL, withIntermediateDirectories: true)
        }
        return garageURL
    }
}

private func resolvedTimestamp(for keyFrame: KeyFrame, in record: SwingRecord) -> Double? {
    if record.decodedFrames.indices.contains(keyFrame.decodedFrameIndex) {
        return record.decodedFrames[keyFrame.decodedFrameIndex].presentationTimestamp
    }

    guard record.swingFrames.indices.contains(keyFrame.decodedFrameIndex) else {
        garageFrameLogger.log(
            "fallback-trace path=resolvedTimestamp record=\(record.mediaFilename ?? record.title, privacy: .public) phase=\(keyFrame.phase.rawValue, privacy: .public) decodedFrameIndex=\(keyFrame.decodedFrameIndex) result=nil reason=missingCanonicalAndSparseFrame"
        )
        return nil
    }

    let fallbackTimestamp = record.swingFrames[keyFrame.decodedFrameIndex].timestamp
    garageFrameLogger.log(
        "fallback-trace path=resolvedTimestamp record=\(record.mediaFilename ?? record.title, privacy: .public) phase=\(keyFrame.phase.rawValue, privacy: .public) decodedFrameIndex=\(keyFrame.decodedFrameIndex) resultTimestamp=\(fallbackTimestamp, format: .fixed(precision: 6)) reason=sparseFrameIndexFallback"
    )
    return fallbackTimestamp
}

private func resolvedVideoFrameIndex(for keyFrame: KeyFrame, in record: SwingRecord) -> Int {
    if record.decodedFrames.indices.contains(keyFrame.decodedFrameIndex) {
        return record.decodedFrames[keyFrame.decodedFrameIndex].decodedFrameIndex
    }

    if let timestamp = resolvedTimestamp(for: keyFrame, in: record) {
        let reconstructedIndex = max(Int(round(timestamp * max(record.frameRate, 1))), 0)
        garageFrameLogger.log(
            "fallback-trace path=resolvedVideoFrameIndex record=\(record.mediaFilename ?? record.title, privacy: .public) phase=\(keyFrame.phase.rawValue, privacy: .public) inputTimestamp=\(timestamp, format: .fixed(precision: 6)) outputDecodedFrameIndex=\(reconstructedIndex) reason=timestampTimesFrameRate"
        )
        return reconstructedIndex
    }

    garageFrameLogger.log(
        "fallback-trace path=resolvedVideoFrameIndex record=\(record.mediaFilename ?? record.title, privacy: .public) phase=\(keyFrame.phase.rawValue, privacy: .public) outputDecodedFrameIndex=\(keyFrame.decodedFrameIndex) reason=rawDecodedFrameIndexFallback"
    )
    return keyFrame.decodedFrameIndex
}

private func resolvedPoseFrame(for keyFrame: KeyFrame, in record: SwingRecord) -> SwingFrame? {
    if record.decodedFrames.indices.contains(keyFrame.decodedFrameIndex),
       let poseSample = record.decodedFrames[keyFrame.decodedFrameIndex].poseSample {
        return SwingFrame(
            timestamp: record.decodedFrames[keyFrame.decodedFrameIndex].presentationTimestamp,
            joints: poseSample.joints,
            confidence: poseSample.confidence
        )
    }

    guard record.swingFrames.isEmpty == false else {
        garageFrameLogger.log(
            "fallback-trace path=resolvedPoseFrame record=\(record.mediaFilename ?? record.title, privacy: .public) phase=\(keyFrame.phase.rawValue, privacy: .public) result=nil reason=noCanonicalPoseAndNoSparseFrames"
        )
        return nil
    }

    guard let timestamp = resolvedTimestamp(for: keyFrame, in: record) else {
        let fallbackFrame = record.swingFrames.indices.contains(keyFrame.decodedFrameIndex) ? record.swingFrames[keyFrame.decodedFrameIndex] : nil
        garageFrameLogger.log(
            "fallback-trace path=resolvedPoseFrame record=\(record.mediaFilename ?? record.title, privacy: .public) phase=\(keyFrame.phase.rawValue, privacy: .public) outputTimestamp=\(fallbackFrame?.timestamp ?? -1, format: .fixed(precision: 6)) reason=sparseFrameIndexFallback"
        )
        return fallbackFrame
    }

    let matchedFrame = record.swingFrames.min { lhs, rhs in
        abs(lhs.timestamp - timestamp) < abs(rhs.timestamp - timestamp)
    }
    garageFrameLogger.log(
        "fallback-trace path=resolvedPoseFrame record=\(record.mediaFilename ?? record.title, privacy: .public) phase=\(keyFrame.phase.rawValue, privacy: .public) inputTimestamp=\(timestamp, format: .fixed(precision: 6)) outputTimestamp=\(matchedFrame?.timestamp ?? -1, format: .fixed(precision: 6)) reason=nearestSparseTimestamp"
    )
    return matchedFrame
}

enum GarageDecodedFrameNavigation {
    static func decodedFrameCount(timestamps: [Double], fallbackDuration: Double, fallbackFrameRate: Double) -> Int {
        if timestamps.isEmpty == false {
            return timestamps.count
        }

        return max(Int(round(fallbackDuration * max(fallbackFrameRate, 1))) + 1, 1)
    }

    static func timestamp(
        for decodedFrameIndex: Int,
        timestamps: [Double],
        fallbackFrameRate: Double,
        fallbackDuration: Double
    ) -> Double {
        guard timestamps.isEmpty == false else {
            return min(Double(decodedFrameIndex) / max(fallbackFrameRate, 1), fallbackDuration)
        }

        let safeIndex = min(max(decodedFrameIndex, 0), timestamps.count - 1)
        return timestamps[safeIndex]
    }

    static func nearestDecodedFrameIndex(to timestamp: Double, timestamps: [Double], fallbackFrameRate: Double) -> Int {
        guard timestamps.isEmpty == false else {
            return max(Int(round(timestamp * max(fallbackFrameRate, 1))), 0)
        }

        return timestamps.enumerated().min { lhs, rhs in
            abs(lhs.element - timestamp) < abs(rhs.element - timestamp)
        }?.offset ?? 0
    }

    static func continuityError(timestampDelta: Double, landmarkDisplacement: Double, decodedFrameTimestamps: [Double], fallbackFrameRate: Double) -> Bool {
        let expectedDelta: Double
        if decodedFrameTimestamps.count >= 2 {
            let deltas = zip(decodedFrameTimestamps, decodedFrameTimestamps.dropFirst())
                .map { $1 - $0 }
                .filter { $0 > 0.0001 }
                .sorted()
            expectedDelta = deltas.isEmpty ? (1 / max(fallbackFrameRate, 1)) : deltas[deltas.count / 2]
        } else {
            expectedDelta = 1 / max(fallbackFrameRate, 1)
        }

        return timestampDelta > (expectedDelta * 1.5) || landmarkDisplacement > 0.12
    }
}

enum GarageAnalysisPipeline {
    static func analyzeVideo(at videoURL: URL) async throws -> GarageAnalysisOutput {
        if isRunningInSimulator {
            throw GarageAnalysisError.unsupportedInSimulator
        }

        let asset = AVURLAsset(url: videoURL)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = tracks.first else {
            throw GarageAnalysisError.missingVideoTrack
        }

        let duration = try await asset.load(.duration)
        let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
        let decodedFrameTimestamps = try decodedFrameTimeline(from: asset, track: videoTrack)
        let decodedFrames = decodedFrameTimestamps.enumerated().map { index, timestamp in
            DecodedFrameRecord(
                decodedFrameIndex: index,
                presentationTimestamp: timestamp,
                renderAssetKey: nil,
                poseSample: nil,
                assignedPhase: nil,
                continuity: nil
            )
        }
        let videoFrameRate = resolvedDecodedFrameRate(from: decodedFrameTimestamps, fallbackNominalRate: nominalFrameRate)
        let samplingFrameRate = resolvedSamplingFrameRate(from: nominalFrameRate)
        let timestamps = sampledTimestamps(duration: duration, frameRate: samplingFrameRate)
        let extractedFrames = try extractPoseFrames(from: asset, timestamps: timestamps)
        let smoothedFrames = smooth(frames: extractedFrames)

        guard smoothedFrames.count >= SwingPhase.allCases.count else {
            throw GarageAnalysisError.insufficientPoseFrames
        }

        let keyFrames = detectKeyFrames(
            from: smoothedFrames,
            videoFrameRate: videoFrameRate,
            decodedFrameTimestamps: decodedFrameTimestamps
        )
        let annotatedDecodedFrames = attachPoseSamples(smoothedFrames, to: decodedFrames)
        let analysisResult = AnalysisResult(
            issues: [],
            highlights: ["Eight deterministic keyframes detected from normalized pose frames."],
            summary: "Processed \(smoothedFrames.count) frames at \(Int(samplingFrameRate.rounded())) FPS and mapped all eight swing phases."
        )

        return GarageAnalysisOutput(
            frameRate: videoFrameRate,
            decodedFrames: annotatedDecodedFrames,
            decodedFrameTimestamps: decodedFrameTimestamps,
            swingFrames: smoothedFrames,
            keyFrames: keyFrames,
            analysisResult: analysisResult
        )
    }

    private static func resolvedSamplingFrameRate(from nominalFrameRate: Float) -> Double {
        let baseRate = nominalFrameRate > 0 ? Double(nominalFrameRate) : 30
        return min(max(baseRate, 60), 120)
    }

    private static var isRunningInSimulator: Bool {
        ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil
    }

    private static func decodedFrameTimeline(from asset: AVAsset, track: AVAssetTrack) throws -> [Double] {
        let reader = try AVAssetReader(asset: asset)
        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        output.alwaysCopiesSampleData = false

        guard reader.canAdd(output) else {
            return []
        }

        reader.add(output)
        guard reader.startReading() else {
            return []
        }

        var timestamps: [Double] = []
        while let sampleBuffer = output.copyNextSampleBuffer() {
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
            if timestamp.isFinite {
                timestamps.append(timestamp)
            }
        }

        return timestamps
    }

    private static func resolvedDecodedFrameRate(from timestamps: [Double], fallbackNominalRate: Float) -> Double {
        guard timestamps.count >= 2 else {
            return fallbackNominalRate > 0 ? Double(fallbackNominalRate) : 30
        }

        let deltas = zip(timestamps, timestamps.dropFirst())
            .map { $1 - $0 }
            .filter { $0 > 0.0001 && $0.isFinite }
            .sorted()

        guard deltas.isEmpty == false else {
            return fallbackNominalRate > 0 ? Double(fallbackNominalRate) : 30
        }

        let medianDelta = deltas[deltas.count / 2]

        return 1 / medianDelta
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

        for jointName in SwingJointName.allCases {
            guard
                let visionName = jointName.visionName,
                let recognizedPoint = recognizedPoints[visionName],
                recognizedPoint.confidence >= 0.15
            else {
                continue
            }

            joints.append(
                SwingJoint(
                    name: jointName,
                    x: Double(recognizedPoint.location.x),
                    y: Double(1 - recognizedPoint.location.y),
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

    private static func smooth(frames: [SwingFrame], alpha: Double = 0.35) -> [SwingFrame] {
        var previousPoints: [SwingJointName: SwingJoint] = [:]
        return frames.map { frame in
            let smoothedJoints = frame.joints.map { joint -> SwingJoint in
                guard let previous = previousPoints[joint.name] else {
                    previousPoints[joint.name] = joint
                    return joint
                }

                let smoothed = SwingJoint(
                    name: joint.name,
                    x: previous.x + alpha * (joint.x - previous.x),
                    y: previous.y + alpha * (joint.y - previous.y),
                    confidence: previous.confidence + alpha * (joint.confidence - previous.confidence)
                )
                previousPoints[joint.name] = smoothed
                return smoothed
            }

            return SwingFrame(timestamp: frame.timestamp, joints: smoothedJoints, confidence: frame.confidence)
        }
    }

    static func detectKeyFrames(
        from frames: [SwingFrame],
        videoFrameRate: Double = 60,
        decodedFrameTimestamps: [Double] = []
    ) -> [KeyFrame] {
        let addressIndex = addressIndex(in: frames)
        let topIndex = topOfBackswingIndex(in: frames, addressIndex: addressIndex)
        let rawTransitionIndex = transitionIndex(
            in: frames,
            topIndex: topIndex,
            fallbackIndex: min(topIndex + 1, max(frames.count - 1, 0))
        )
        let rawImpactIndex = impactIndex(in: frames, addressIndex: addressIndex, transitionIndex: rawTransitionIndex)
        let rawFollowThroughIndex = followThroughIndex(in: frames, impactIndex: rawImpactIndex)
        let spacedLateIndices = normalizedLateSwingIndices(
            frameCount: frames.count,
            topIndex: topIndex,
            transitionIndex: rawTransitionIndex,
            impactIndex: rawImpactIndex,
            followThroughIndex: rawFollowThroughIndex
        )
        let takeawayIndex = takeawayIndex(in: frames, addressIndex: addressIndex, topIndex: topIndex)
        let shaftParallelIndex = shaftParallelIndex(in: frames, addressIndex: addressIndex, takeawayIndex: takeawayIndex, topIndex: topIndex)
        let transitionIndex = transitionIndex(in: frames, topIndex: topIndex, fallbackIndex: spacedLateIndices.transition)
        let impactIndex = spacedLateIndices.impact
        let earlyDownswingIndex = earlyDownswingIndex(in: frames, transitionIndex: transitionIndex, impactIndex: impactIndex)
        let followThroughIndex = spacedLateIndices.followThrough

        return [
            makeKeyFrame(for: .address, sampleIndex: addressIndex, in: frames, videoFrameRate: videoFrameRate, decodedFrameTimestamps: decodedFrameTimestamps),
            makeKeyFrame(for: .takeaway, sampleIndex: takeawayIndex, in: frames, videoFrameRate: videoFrameRate, decodedFrameTimestamps: decodedFrameTimestamps),
            makeKeyFrame(for: .shaftParallel, sampleIndex: shaftParallelIndex, in: frames, videoFrameRate: videoFrameRate, decodedFrameTimestamps: decodedFrameTimestamps),
            makeKeyFrame(for: .topOfBackswing, sampleIndex: topIndex, in: frames, videoFrameRate: videoFrameRate, decodedFrameTimestamps: decodedFrameTimestamps),
            makeKeyFrame(for: .transition, sampleIndex: transitionIndex, in: frames, videoFrameRate: videoFrameRate, decodedFrameTimestamps: decodedFrameTimestamps),
            makeKeyFrame(for: .earlyDownswing, sampleIndex: earlyDownswingIndex, in: frames, videoFrameRate: videoFrameRate, decodedFrameTimestamps: decodedFrameTimestamps),
            makeKeyFrame(for: .impact, sampleIndex: impactIndex, in: frames, videoFrameRate: videoFrameRate, decodedFrameTimestamps: decodedFrameTimestamps),
            makeKeyFrame(for: .followThrough, sampleIndex: followThroughIndex, in: frames, videoFrameRate: videoFrameRate, decodedFrameTimestamps: decodedFrameTimestamps)
        ]
    }

    private static func attachPoseSamples(_ frames: [SwingFrame], to decodedFrames: [DecodedFrameRecord]) -> [DecodedFrameRecord] {
        guard decodedFrames.isEmpty == false else {
            return decodedFrames
        }

        var updatedFrames = decodedFrames
        for (analysisSampleIndex, frame) in frames.enumerated() {
            guard let decodedFrameIndex = nearestDecodedFrameIndex(to: frame.timestamp, decodedFrameTimestamps: decodedFrames.map(\.presentationTimestamp)) else {
                garageFrameLogger.log(
                    "fallback-trace path=attachPoseSamples analysisSampleIndex=\(analysisSampleIndex) sampleTimestamp=\(frame.timestamp, format: .fixed(precision: 6)) outputDecodedFrameIndex=nil reason=noDecodedFrameMatch"
                )
                continue
            }

            garageFrameLogger.log(
                "fallback-trace path=attachPoseSamples analysisSampleIndex=\(analysisSampleIndex) sampleTimestamp=\(frame.timestamp, format: .fixed(precision: 6)) outputDecodedFrameIndex=\(decodedFrameIndex) reason=nearestDecodedTimestampBridge"
            )
            updatedFrames[decodedFrameIndex].poseSample = PoseSampleAttachment(
                analysisSampleIndex: analysisSampleIndex,
                confidence: frame.confidence,
                joints: frame.joints
            )
        }

        return updatedFrames
    }

    private static func makeKeyFrame(
        for phase: SwingPhase,
        sampleIndex: Int,
        in frames: [SwingFrame],
        videoFrameRate: Double,
        decodedFrameTimestamps: [Double]
    ) -> KeyFrame {
        let safeIndex = min(max(sampleIndex, 0), max(frames.count - 1, 0))
        let timestamp = frames.indices.contains(safeIndex) ? frames[safeIndex].timestamp : 0
        let bridgedDecodedFrameIndex = nearestDecodedFrameIndex(to: timestamp, decodedFrameTimestamps: decodedFrameTimestamps)
        let frameNumber = bridgedDecodedFrameIndex
            ?? max(Int(round(timestamp * max(videoFrameRate, 1))), 0)
        garageFrameLogger.log(
            "fallback-trace path=makeKeyFrame phase=\(phase.rawValue, privacy: .public) sampleIndex=\(sampleIndex) sampleTimestamp=\(timestamp, format: .fixed(precision: 6)) outputDecodedFrameIndex=\(frameNumber) reason=\((bridgedDecodedFrameIndex == nil ? "timestampTimesFrameRateFallback" : "nearestDecodedTimestampBridge"), privacy: .public)"
        )
        return KeyFrame(
            phase: phase,
            decodedFrameIndex: frameNumber
        )
    }

    private static func nearestDecodedFrameIndex(to timestamp: Double, decodedFrameTimestamps: [Double]) -> Int? {
        guard decodedFrameTimestamps.isEmpty == false else {
            return nil
        }

        return decodedFrameTimestamps.enumerated().min { lhs, rhs in
            abs(lhs.element - timestamp) < abs(rhs.element - timestamp)
        }?.offset
    }

    private static func addressIndex(in frames: [SwingFrame]) -> Int {
        let searchEnd = min(max(Int(Double(frames.count) * 0.25), 1), max(frames.count - 1, 0))
        guard searchEnd > 0 else {
            return 0
        }

        let handSpeeds = handSpeeds(in: frames)
        let baseScale = bodyScale(in: frames[0])
        let motionThreshold = max(0.01, baseScale * 0.12)
        let swingStart = handSpeeds.firstIndex(where: { $0 >= motionThreshold }) ?? searchEnd
        let candidateUpperBound = min(max(swingStart, 1), searchEnd)
        let candidateRange = 0...candidateUpperBound

        let candidate = candidateRange.max { lhs, rhs in
            let lhsStillness = quietFrameScore(at: lhs, frames: frames, speeds: handSpeeds)
            let rhsStillness = quietFrameScore(at: rhs, frames: frames, speeds: handSpeeds)
            return lhsStillness < rhsStillness
        }

        return candidate ?? 0
    }

    private static func topOfBackswingIndex(in frames: [SwingFrame], addressIndex: Int) -> Int {
        let searchStart = min(max(addressIndex + 2, 1), max(frames.count - 2, 0))
        let searchEnd = min(max(Int((Double(frames.count - 1)) * 0.62), searchStart + 2), max(frames.count - 3, searchStart))
        let searchRange = searchStart...searchEnd
        guard searchRange.isEmpty == false else {
            return min(max(searchStart, frames.count / 3), max(frames.count - 3, 0))
        }

        let torsoHeight = max(torsoHeight(in: frames[addressIndex]), 0.0001)
        let reversalThreshold = max(0.004, torsoHeight * 0.015)
        let localMinimumCandidates = searchRange.filter { index in
            guard index > searchStart, index + 2 < frames.count else {
                return false
            }

            let previousY = handCenter(in: frames[index - 1]).y
            let currentY = handCenter(in: frames[index]).y
            let nextY = handCenter(in: frames[index + 1]).y
            let nextNextY = handCenter(in: frames[index + 2]).y

            let intoTopRise = previousY - currentY
            let outOfTopDrop = nextY - currentY
            let sustainedDrop = nextNextY - nextY

            return intoTopRise >= reversalThreshold
                && outOfTopDrop >= reversalThreshold
                && sustainedDrop >= (-reversalThreshold * 0.25)
        }

        if let candidate = localMinimumCandidates.min(by: { lhs, rhs in
            topOfBackswingScore(at: lhs, frames: frames, searchStart: searchStart)
                < topOfBackswingScore(at: rhs, frames: frames, searchStart: searchStart)
        }) {
            return candidate
        }

        let fallbackCandidate = searchRange.min { lhs, rhs in
            handCenter(in: frames[lhs]).y < handCenter(in: frames[rhs]).y
        }
        return fallbackCandidate ?? min(max(searchStart, frames.count / 3), max(frames.count - 3, 0))
    }

    private static func takeawayIndex(in frames: [SwingFrame], addressIndex: Int, topIndex: Int) -> Int {
        guard addressIndex + 1 < topIndex else {
            return min(addressIndex + 1, topIndex)
        }

        let addressHands = handCenter(in: frames[addressIndex])
        let topHands = handCenter(in: frames[topIndex])
        let shoulderWidth = max(bodyScale(in: frames[addressIndex]), 0.0001)
        let totalRise = max(addressHands.y - topHands.y, 0.0001)
        let cumulativeTravel = cumulativeHandTravel(in: frames)
        let backswingTravel = max(cumulativeTravel[topIndex] - cumulativeTravel[addressIndex], 0.0001)
        let speeds = handSpeeds(in: frames)
        let range = (addressIndex + 1)..<topIndex

        let candidate = range.min { lhs, rhs in
            takeawayScore(
                at: lhs,
                frames: frames,
                addressIndex: addressIndex,
                topIndex: topIndex,
                addressHands: addressHands,
                shoulderWidth: shoulderWidth,
                totalRise: totalRise,
                cumulativeTravel: cumulativeTravel,
                backswingTravel: backswingTravel,
                speeds: speeds
            ) < takeawayScore(
                at: rhs,
                frames: frames,
                addressIndex: addressIndex,
                topIndex: topIndex,
                addressHands: addressHands,
                shoulderWidth: shoulderWidth,
                totalRise: totalRise,
                cumulativeTravel: cumulativeTravel,
                backswingTravel: backswingTravel,
                speeds: speeds
            )
        }

        return candidate ?? min(addressIndex + 1, topIndex)
    }

    private static func shaftParallelIndex(in frames: [SwingFrame], addressIndex: Int, takeawayIndex: Int, topIndex: Int) -> Int {
        guard takeawayIndex + 1 < topIndex else {
            return min(takeawayIndex + 1, topIndex)
        }

        let addressHands = handCenter(in: frames[addressIndex])
        let topHands = handCenter(in: frames[topIndex])
        let totalRise = max(addressHands.y - topHands.y, 0.0001)
        let cumulativeTravel = cumulativeHandTravel(in: frames)
        let backswingTravel = max(cumulativeTravel[topIndex] - cumulativeTravel[addressIndex], 0.0001)

        let range = (takeawayIndex + 1)..<topIndex
        return range.min { lhs, rhs in
            shaftParallelScore(
                at: lhs,
                frames: frames,
                addressIndex: addressIndex,
                topIndex: topIndex,
                addressHands: addressHands,
                totalRise: totalRise,
                cumulativeTravel: cumulativeTravel,
                backswingTravel: backswingTravel
            ) < shaftParallelScore(
                at: rhs,
                frames: frames,
                addressIndex: addressIndex,
                topIndex: topIndex,
                addressHands: addressHands,
                totalRise: totalRise,
                cumulativeTravel: cumulativeTravel,
                backswingTravel: backswingTravel
            )
        } ?? min(takeawayIndex + 1, topIndex)
    }

    private static func motionProgressIndex(
        in frames: [SwingFrame],
        startIndex: Int,
        endIndex: Int,
        targetProgress: Double,
        fallbackIndex: Int
    ) -> Int {
        guard startIndex < endIndex, frames.indices.contains(startIndex), frames.indices.contains(endIndex) else {
            return fallbackIndex
        }

        let cumulativeTravel = cumulativeHandTravel(in: frames)
        let startTravel = cumulativeTravel[startIndex]
        let endTravel = cumulativeTravel[endIndex]
        let totalTravel = endTravel - startTravel
        guard totalTravel > 0.0001 else {
            return fallbackIndex
        }

        let targetTravel = startTravel + (totalTravel * targetProgress)
        let range = startIndex...endIndex

        let candidate = range.min { lhs, rhs in
            let lhsDelta = abs(cumulativeTravel[lhs] - targetTravel)
            let rhsDelta = abs(cumulativeTravel[rhs] - targetTravel)
            return lhsDelta < rhsDelta
        }

        return candidate ?? fallbackIndex
    }

    private static func transitionIndex(in frames: [SwingFrame], topIndex: Int, fallbackIndex: Int) -> Int {
        guard topIndex + 1 < frames.count else {
            return min(topIndex + 1, max(frames.count - 1, 0))
        }

        let topHands = handCenter(in: frames[topIndex])
        let torsoHeight = torsoHeight(in: frames[topIndex])
        let downwardThreshold = max(0.006, torsoHeight * 0.02)
        let searchEnd = min(frames.count - 1, topIndex + max(4, Int(round(Double(frames.count) * 0.05))))

        for index in (topIndex + 1)...searchEnd {
            let handY = handCenter(in: frames[index]).y
            let nextIndex = min(index + 1, frames.count - 1)
            let sustainedDrop = handCenter(in: frames[nextIndex]).y - handY
            if handY - topHands.y >= downwardThreshold, sustainedDrop >= 0 {
                return index
            }
        }

        return min(max(fallbackIndex, topIndex + 1), frames.count - 1)
    }

    private static func earlyDownswingIndex(in frames: [SwingFrame], transitionIndex: Int, impactIndex: Int) -> Int {
        guard transitionIndex + 1 < impactIndex else {
            return min(transitionIndex + 1, impactIndex)
        }

        let transitionHands = handCenter(in: frames[transitionIndex])
        let impactHands = handCenter(in: frames[impactIndex])
        let targetDistance = distance(from: transitionHands, to: impactHands) * 0.42

        let range = (transitionIndex + 1)..<impactIndex
        return range.min { lhs, rhs in
            let lhsDelta = abs(distance(from: transitionHands, to: handCenter(in: frames[lhs])) - targetDistance)
            let rhsDelta = abs(distance(from: transitionHands, to: handCenter(in: frames[rhs])) - targetDistance)
            return lhsDelta < rhsDelta
        } ?? min(transitionIndex + 1, impactIndex)
    }

    private static func impactIndex(in frames: [SwingFrame], addressIndex: Int, transitionIndex: Int) -> Int {
        let addressHands = handCenter(in: frames[addressIndex])
        let searchStart = min(transitionIndex + 1, frames.count - 1)
        let searchEnd = min(
            bottomOfArcIndex(in: frames, transitionIndex: transitionIndex),
            max(searchStart, Int(round(Double(frames.count - 1) * 0.68)))
        )
        let range = searchStart...max(searchEnd, searchStart)
        let handSpeeds = handSpeeds(in: frames)

        let candidate = range.max { lhs, rhs in
            impactScore(at: lhs, frames: frames, addressHands: addressHands, handSpeeds: handSpeeds)
                < impactScore(at: rhs, frames: frames, addressHands: addressHands, handSpeeds: handSpeeds)
        }

        return candidate ?? min(searchEnd, frames.count - 1)
    }

    private static func followThroughIndex(in frames: [SwingFrame], impactIndex: Int) -> Int {
        guard impactIndex + 1 < frames.count else {
            return impactIndex
        }

        let range = (impactIndex + 1)..<frames.count
        let impactHands = handCenter(in: frames[impactIndex])
        let candidate = range.max { lhs, rhs in
            followThroughScore(in: frames[lhs], impactHands: impactHands) < followThroughScore(in: frames[rhs], impactHands: impactHands)
        }

        return candidate ?? frames.count - 1
    }

    private static func bottomOfArcIndex(in frames: [SwingFrame], transitionIndex: Int) -> Int {
        guard transitionIndex + 1 < frames.count else {
            return transitionIndex
        }

        let searchEnd = min(frames.count - 1, max(transitionIndex + 2, Int(round(Double(frames.count - 1) * 0.68))))
        let range = (transitionIndex + 1)...searchEnd
        let candidate = range.max { lhs, rhs in
            handCenter(in: frames[lhs]).y < handCenter(in: frames[rhs]).y
        }
        return candidate ?? min(searchEnd, frames.count - 1)
    }

    private static func followThroughScore(in frame: SwingFrame, impactHands: CGPoint) -> Double {
        let hands = handCenter(in: frame)
        let rise = max(0.8 - hands.y, 0)
        let travel = distance(from: hands, to: impactHands)
        return (rise * 1.8) + travel
    }

    private static func normalizedLateSwingIndices(
        frameCount: Int,
        topIndex: Int,
        transitionIndex: Int,
        impactIndex: Int,
        followThroughIndex: Int
    ) -> (transition: Int, impact: Int, followThrough: Int) {
        guard frameCount >= 4 else {
            return (
                transition: min(max(transitionIndex, topIndex), max(frameCount - 2, topIndex)),
                impact: min(max(impactIndex, transitionIndex), max(frameCount - 1, 0)),
                followThrough: min(max(followThroughIndex, impactIndex), max(frameCount - 1, 0))
            )
        }

        let minimumGap = max(1, Int(round(Double(frameCount) * 0.04)))
        let lastIndex = frameCount - 1

        let transition = min(max(transitionIndex, topIndex + minimumGap), lastIndex - (minimumGap * 2))
        var impact = min(max(impactIndex, transition + minimumGap), lastIndex - minimumGap)
        var followThrough = max(followThroughIndex, impact + minimumGap)

        if followThrough > lastIndex {
            followThrough = lastIndex
            impact = min(impact, max(lastIndex - minimumGap, transition))
        }

        if impact - transition < minimumGap {
            impact = min(max(transition + minimumGap, impact), max(lastIndex - minimumGap, transition))
        }

        if followThrough - impact < minimumGap {
            followThrough = min(max(impact + minimumGap, followThrough), lastIndex)
        }

        if followThrough <= impact {
            let fallbackImpact = max(min(lastIndex - minimumGap, impact), transition + minimumGap)
            impact = fallbackImpact
            followThrough = min(max(impact + minimumGap, followThrough), lastIndex)
        }

        return (transition, impact, followThrough)
    }

    private static func cumulativeHandTravel(in frames: [SwingFrame]) -> [Double] {
        guard frames.isEmpty == false else {
            return []
        }

        var cumulative: [Double] = [0]
        for index in 1..<frames.count {
            let previous = handCenter(in: frames[index - 1])
            let current = handCenter(in: frames[index])
            cumulative.append(cumulative[index - 1] + distance(from: previous, to: current))
        }
        return cumulative
    }

    private static func handSpeeds(in frames: [SwingFrame]) -> [Double] {
        guard frames.isEmpty == false else {
            return []
        }

        var speeds: [Double] = [0]
        for index in 1..<frames.count {
            speeds.append(distance(from: handCenter(in: frames[index - 1]), to: handCenter(in: frames[index])))
        }
        return speeds
    }

    private static func quietFrameScore(at index: Int, frames: [SwingFrame], speeds: [Double]) -> Double {
        let localSpeed = speeds[min(index, speeds.count - 1)]
        let nextSpeed = speeds[min(index + 1, speeds.count - 1)]
        let hands = handCenter(in: frames[index])
        return (localSpeed * -2.0) + (nextSpeed * -1.0) + Double(hands.y * 0.35)
    }

    private static func topOfBackswingScore(at index: Int, frames: [SwingFrame], searchStart: Int) -> Double {
        let handsY = handCenter(in: frames[index]).y
        let earlyBias = Double(index - searchStart) * 0.003
        return handsY + earlyBias
    }

    private static func takeawayScore(
        at index: Int,
        frames: [SwingFrame],
        addressIndex: Int,
        topIndex: Int,
        addressHands: CGPoint,
        shoulderWidth: Double,
        totalRise: Double,
        cumulativeTravel: [Double],
        backswingTravel: Double,
        speeds: [Double]
    ) -> Double {
        let hands = handCenter(in: frames[index])
        let travelProgress = (cumulativeTravel[index] - cumulativeTravel[addressIndex]) / backswingTravel
        let riseProgress = max(addressHands.y - hands.y, 0) / totalRise
        let horizontalShift = abs(hands.x - addressHands.x) / shoulderWidth
        let candidateSpeed = speeds[min(index, speeds.count - 1)]
        let topSpeed = speeds[min(topIndex, speeds.count - 1)]

        return abs(travelProgress - 0.14) * 4.0
            + abs(riseProgress - 0.16) * 2.0
            + abs(horizontalShift - 0.12) * 1.4
            + abs(candidateSpeed - topSpeed * 0.35)
    }

    private static func shaftParallelScore(
        at index: Int,
        frames: [SwingFrame],
        addressIndex: Int,
        topIndex: Int,
        addressHands: CGPoint,
        totalRise: Double,
        cumulativeTravel: [Double],
        backswingTravel: Double
    ) -> Double {
        let hands = handCenter(in: frames[index])
        let travelProgress = (cumulativeTravel[index] - cumulativeTravel[addressIndex]) / backswingTravel
        let riseProgress = max(addressHands.y - hands.y, 0) / totalRise

        return abs(travelProgress - 0.38) * 3.8
            + abs(riseProgress - 0.48) * 1.8
            + abs(Double(index - addressIndex) / max(Double(topIndex - addressIndex), 1) - 0.45) * 0.8
    }

    private static func impactScore(
        at index: Int,
        frames: [SwingFrame],
        addressHands: CGPoint,
        handSpeeds: [Double]
    ) -> Double {
        let hands = handCenter(in: frames[index])
        let proximityToAddress = max(0.4 - distance(from: hands, to: addressHands), 0)
        let handSpeed = handSpeeds[min(index, handSpeeds.count - 1)]
        let lowHandsBonus = max(hands.y - 0.45, 0)
        return (proximityToAddress * 3.0) + (handSpeed * 1.8) + Double(lowHandsBonus * 0.7)
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

    static func generatePathPoints(from anchors: [HandAnchor], samplesPerSegment: Int = 16) -> [PathPoint] {
        let orderedAnchors = SwingPhase.allCases.compactMap { phase in
            anchors.first(where: { $0.phase == phase })
        }

        guard orderedAnchors.count >= 2 else {
            return []
        }

        var points: [PathPoint] = []
        var sequence = 0

        for index in 0..<(orderedAnchors.count - 1) {
            let previous = point(for: orderedAnchors[max(index - 1, 0)])
            let start = point(for: orderedAnchors[index])
            let end = point(for: orderedAnchors[index + 1])
            let next = point(for: orderedAnchors[min(index + 2, orderedAnchors.count - 1)])
            let sampleCount = max(samplesPerSegment, 2)

            for sample in 0..<sampleCount {
                let t = Double(sample) / Double(sampleCount)
                let resolved = catmullRomPoint(
                    previous: previous,
                    start: start,
                    end: end,
                    next: next,
                    t: t
                )
                let x = min(max(resolved.x, 0), 1)
                let y = min(max(resolved.y, 0), 1)
                points.append(PathPoint(sequence: sequence, x: x, y: y))
                sequence += 1
            }
        }

        if let finalAnchor = orderedAnchors.last {
            points.append(PathPoint(sequence: sequence, x: finalAnchor.x, y: finalAnchor.y))
        }

        return points
    }

    private static func point(for anchor: HandAnchor) -> CGPoint {
        CGPoint(x: anchor.x, y: anchor.y)
    }

    private static func catmullRomPoint(
        previous: CGPoint,
        start: CGPoint,
        end: CGPoint,
        next: CGPoint,
        t: Double
    ) -> CGPoint {
        let squared = t * t
        let cubed = squared * t

        let x = 0.5 * (
            (2 * start.x) +
            (-previous.x + end.x) * t +
            (2 * previous.x - 5 * start.x + 4 * end.x - next.x) * squared +
            (-previous.x + 3 * start.x - 3 * end.x + next.x) * cubed
        )
        let y = 0.5 * (
            (2 * start.y) +
            (-previous.y + end.y) * t +
            (2 * previous.y - 5 * start.y + 4 * end.y - next.y) * squared +
            (-previous.y + 3 * start.y - 3 * end.y + next.y) * cubed
        )

        return CGPoint(x: x, y: y)
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

private extension SwingFrame {
    func point(named name: SwingJointName) -> CGPoint {
        guard let joint = joints.first(where: { $0.name == name }) else {
            return .zero
        }
        return CGPoint(x: joint.x, y: joint.y)
    }
}
