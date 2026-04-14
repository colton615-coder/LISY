import Foundation
import XCTest
@testable import LIFE_IN_SYNC

@MainActor
final class GarageDerivedReportsXCTests: XCTestCase {
    func testGarageReliabilityReportIsTrustedForApprovedCompleteSwing() {
        let anchors = makeFullAnchorSet()
        let record = makeWorkflowRecord(
            keyframeValidationStatus: .approved,
            anchors: anchors,
            pathPoints: GarageAnalysisPipeline.generatePathPoints(from: anchors, samplesPerSegment: 4)
        )

        let report = GarageReliability.report(for: record)

        XCTAssertEqual(report.status, .trusted)
        XCTAssertGreaterThanOrEqual(report.score, 84)
        XCTAssertTrue(report.checks.allSatisfy(\.passed))
    }

    func testGarageReliabilityReportStaysReviewableWhenPoseFallbackKeepsCoverageAlive() {
        let frames = makeSyntheticSwingFrames()
        let keyFrames = GarageAnalysisPipeline.detectKeyFrames(from: frames)
        let record = SwingRecord(
            title: "Weak Reliability",
            mediaFilename: nil,
            frameRate: 60,
            swingFrames: frames,
            keyFrames: keyFrames,
            keyframeValidationStatus: .flagged,
            handAnchors: [],
            pathPoints: [],
            analysisResult: AnalysisResult(issues: [], highlights: [], summary: "Synthetic weak case.")
        )

        let report = GarageReliability.report(for: record)

        XCTAssertEqual(report.status, .review)
        XCTAssertGreaterThanOrEqual(report.score, 50)
        XCTAssertLessThan(report.score, 84)
        XCTAssertTrue(report.checks.contains(where: { $0.title == "Review Status" && $0.passed == false }))
        XCTAssertTrue(report.checks.contains(where: { $0.title == "Grip Coverage" && $0.passed == false }))
        XCTAssertTrue(report.checks.contains(where: { $0.title == "Video Source" && $0.passed == true }))
    }

    func testGarageCoachingReportProvidesActionableCueForTrustedSwing() {
        let anchors = makeFullAnchorSet()
        let record = makeWorkflowRecord(
            keyframeValidationStatus: .approved,
            anchors: anchors,
            pathPoints: GarageAnalysisPipeline.generatePathPoints(from: anchors, samplesPerSegment: 4)
        )

        let report = GarageCoaching.report(for: record)

        XCTAssertEqual(report.confidenceLabel, GarageReliabilityStatus.trusted.rawValue)
        XCTAssertFalse(report.cues.isEmpty)
        XCTAssertTrue(report.blockers.isEmpty)
    }

    func testGarageCoachingReportUsesReviewBlockersWhenPoseFallbackLeavesSwingInReview() {
        let frames = makeSyntheticSwingFrames()
        let keyFrames = GarageAnalysisPipeline.detectKeyFrames(from: frames)
        let record = SwingRecord(
            title: "Weak Coaching",
            mediaFilename: nil,
            frameRate: 60,
            swingFrames: frames,
            keyFrames: keyFrames,
            keyframeValidationStatus: .flagged,
            handAnchors: [],
            pathPoints: [],
            analysisResult: AnalysisResult(issues: [], highlights: [], summary: "Synthetic weak case.")
        )

        let report = GarageCoaching.report(for: record)

        XCTAssertEqual(report.confidenceLabel, GarageReliabilityStatus.review.rawValue)
        XCTAssertFalse(report.cues.isEmpty)
        XCTAssertFalse(report.blockers.isEmpty)
    }

    func testGarageCoachingReportFlagsLongTempoAsCaution() {
        let frames = makeSyntheticSwingFrames()
        let keyFrames = [
            KeyFrame(phase: .address, frameIndex: 0),
            KeyFrame(phase: .takeaway, frameIndex: 1),
            KeyFrame(phase: .shaftParallel, frameIndex: 2),
            KeyFrame(phase: .topOfBackswing, frameIndex: 8),
            KeyFrame(phase: .transition, frameIndex: 9),
            KeyFrame(phase: .earlyDownswing, frameIndex: 9),
            KeyFrame(phase: .impact, frameIndex: 9),
            KeyFrame(phase: .followThrough, frameIndex: 9)
        ]
        let anchors = makeFullAnchorSet()
        let record = SwingRecord(
            title: "Tempo Caution",
            mediaFilename: "workflow.mov",
            frameRate: 60,
            swingFrames: frames,
            keyFrames: keyFrames,
            keyframeValidationStatus: .approved,
            handAnchors: anchors,
            pathPoints: GarageAnalysisPipeline.generatePathPoints(from: anchors, samplesPerSegment: 4),
            analysisResult: AnalysisResult(issues: [], highlights: [], summary: "Synthetic tempo case.")
        )

        let report = GarageCoaching.report(for: record)

        XCTAssertTrue(report.cues.contains(where: { $0.title == "Backswing Is Running Long" && $0.severity == GarageCoachingSeverity.caution }))
    }

    func testGarageTimestampDetectorProjectsAddressTopAndImpactForStep2() throws {
        let frames = makeFullBodyDTLSwingFrames()
        let keyFrames = makeStep2KeyFrames()

        let detection = try XCTUnwrap(GarageTimestampDetector.detect(from: frames, keyFrames: keyFrames))

        XCTAssertEqual(detection.timestamps.perspective, .dtl)
        XCTAssertEqual(detection.startFrameIndex, 0)
        XCTAssertEqual(detection.topFrameIndex, 6)
        XCTAssertEqual(detection.impactFrameIndex, 8)
        XCTAssertLessThan(detection.timestamps.start, detection.timestamps.top)
        XCTAssertLessThan(detection.timestamps.top, detection.timestamps.impact)
    }

    func testGarageScorecardGeneratesFiveStep2DomainsForFullBodyDTLSwing() throws {
        let frames = makeFullBodyDTLSwingFrames()
        let keyFrames = makeStep2KeyFrames()

        let scorecard = try XCTUnwrap(GarageScorecardEngine.generate(frames: frames, keyFrames: keyFrames))

        XCTAssertEqual(scorecard.timestamps.perspective, .dtl)
        XCTAssertEqual(scorecard.domainScores.map(\.id), GarageSwingDomain.allCases.map(\.rawValue))
        XCTAssertEqual(scorecard.domainScores.count, 5)
        XCTAssertGreaterThan(scorecard.metrics.tempo.ratio, 0)
        XCTAssertGreaterThan(scorecard.metrics.spine.deltaDegrees, 0)
        XCTAssertGreaterThan(scorecard.metrics.pelvicDepth.driftInches, 0)
        XCTAssertGreaterThan(scorecard.metrics.kneeFlex.leftDeltaDegrees, 0)
        XCTAssertGreaterThan(scorecard.metrics.kneeFlex.rightDeltaDegrees, 0)
        XCTAssertGreaterThanOrEqual(scorecard.totalScore, 0)
        XCTAssertLessThanOrEqual(scorecard.totalScore, 100)
        XCTAssertTrue(scorecard.domainScores.contains(where: { $0.id == GarageSwingDomain.knee.rawValue && $0.displayValue.contains("Left") }))
    }

    func testGarageScorecardReturnsNilWhenCriticalStep2LandmarksAreUnreliable() {
        let frames = makeFullBodyDTLSwingFrames(missingCriticalImpactJoints: true)
        let keyFrames = makeStep2KeyFrames()

        let scorecard = GarageScorecardEngine.generate(frames: frames, keyFrames: keyFrames)

        XCTAssertNil(scorecard)
    }

    func testGarageStep2PresentationBuildsFiveCardsWithoutSpeedLanguage() throws {
        let scorecard = try XCTUnwrap(
            GarageScorecardEngine.generate(
                frames: makeFullBodyDTLSwingFrames(),
                keyFrames: makeStep2KeyFrames()
            )
        )

        let presentation = GarageStep2Presentation.make(scorecard: scorecard)

        guard case let .ready(score, metrics) = presentation else {
            return XCTFail("Expected Step 2 presentation to be ready")
        }

        XCTAssertEqual(score.scoreLimit, "/100")
        XCTAssertEqual(metrics.count, 5)
        XCTAssertEqual(metrics.map(\.title), ["Tempo", "Spine Delta", "Pelvic Depth", "Knee Flex", "Head Stability"])
        XCTAssertFalse(metrics.contains(where: {
            let combined = "\($0.title) \($0.value)".lowercased()
            return combined.contains("speed") || combined.contains("mph") || combined.contains("m/s")
        }))
    }

    func testDetectKeyFramesMaintainsStrictPhaseOrdering() {
        let keyFrames = GarageAnalysisPipeline.detectKeyFrames(from: makeSyntheticSwingFrames())
        let byPhase = Dictionary(uniqueKeysWithValues: keyFrames.map { ($0.phase, $0.frameIndex) })

        let orderedPairs: [(SwingPhase, SwingPhase)] = [
            (.address, .takeaway),
            (.takeaway, .shaftParallel),
            (.shaftParallel, .topOfBackswing),
            (.topOfBackswing, .transition),
            (.transition, .earlyDownswing),
            (.earlyDownswing, .impact),
            (.impact, .followThrough)
        ]

        for (lhs, rhs) in orderedPairs {
            guard let lhsIndex = byPhase[lhs], let rhsIndex = byPhase[rhs] else {
                XCTFail("Missing expected phases: \(lhs) or \(rhs)")
                return
            }

            XCTAssertLessThanOrEqual(lhsIndex, rhsIndex, "Expected \(lhs) to be at or before \(rhs)")
        }
    }

    func testEarlyDownswingStaysBeforeImpactForLateDownswingProfile() {
        let keyFrames = GarageAnalysisPipeline.detectKeyFrames(from: makeLateDownswingDriftFrames())
        let byPhase = Dictionary(uniqueKeysWithValues: keyFrames.map { ($0.phase, $0.frameIndex) })

        guard
            let transition = byPhase[.transition],
            let earlyDownswing = byPhase[.earlyDownswing],
            let impact = byPhase[.impact]
        else {
            XCTFail("Missing key phases for late-downswing profile")
            return
        }

        XCTAssertGreaterThan(earlyDownswing, transition)
        XCTAssertLessThan(earlyDownswing, impact)
    }

    func testGarageReviewSummaryPresentationUsesGoodPoseQualityWhenConfidenceAndStabilityAreStrong() {
        let presentation = GarageReviewSummaryPresentation.make(
            reviewMode: .handPath,
            handPathReviewReport: GarageHandPathReviewReport(
                score: 82,
                requiresManualReview: false,
                weakestPhase: nil,
                weakPhases: [],
                continuityScore: 0.9
            ),
            stabilityScore: 88,
            reviewFrameSource: .video
        )

        XCTAssertEqual(presentation.reviewTitle, "Hand Path Review")
        XCTAssertEqual(presentation.poseQuality, .good)
        XCTAssertNil(presentation.stabilityDetail)
        XCTAssertEqual(presentation.stabilityValueText, "88")
    }

    func testGarageReviewSummaryPresentationFallsBackToLimitedWhenSkeletonStabilityIsUnavailable() {
        let presentation = GarageReviewSummaryPresentation.make(
            reviewMode: .skeleton,
            handPathReviewReport: GarageHandPathReviewReport(
                score: 79,
                requiresManualReview: false,
                weakestPhase: nil,
                weakPhases: [],
                continuityScore: 0.88
            ),
            stabilityScore: nil,
            reviewFrameSource: .video
        )

        XCTAssertEqual(presentation.reviewTitle, "Skeleton Review")
        XCTAssertEqual(presentation.poseQuality, .limited)
        XCTAssertEqual(presentation.stabilityStatusText, "Stability unavailable")
        XCTAssertEqual(
            presentation.stabilityDetail,
            "Body outline is visible, but head and hip tracking were too weak for a stable score."
        )
    }

    func testGarageReviewSummaryPresentationUsesModeSpecificContextCopy() {
        let skeletonPresentation = GarageReviewSummaryPresentation.make(
            reviewMode: .skeleton,
            handPathReviewReport: GarageHandPathReviewReport(
                score: 60,
                requiresManualReview: false,
                weakestPhase: nil,
                weakPhases: [],
                continuityScore: 0.7
            ),
            stabilityScore: 74,
            reviewFrameSource: .video
        )

        XCTAssertEqual(skeletonPresentation.reviewSubtitle, "Checking body alignment and stability through impact")

        let handPathPresentation = GarageReviewSummaryPresentation.make(
            reviewMode: .handPath,
            handPathReviewReport: GarageHandPathReviewReport(
                score: 60,
                requiresManualReview: false,
                weakestPhase: nil,
                weakPhases: [],
                continuityScore: 0.7
            ),
            stabilityScore: 74,
            reviewFrameSource: .video
        )

        XCTAssertEqual(handPathPresentation.reviewSubtitle, "Reviewing the detected grip path from setup to impact")
    }

    func testGarageReviewSummaryPresentationExplainsPoseFallbackSource() {
        let presentation = GarageReviewSummaryPresentation.make(
            reviewMode: .handPath,
            handPathReviewReport: GarageHandPathReviewReport(
                score: 58,
                requiresManualReview: false,
                weakestPhase: nil,
                weakPhases: [],
                continuityScore: 0.64
            ),
            stabilityScore: 66,
            reviewFrameSource: .poseFallback
        )

        XCTAssertEqual(presentation.poseQualityDetail, "Reviewing sampled pose data because the stored video is unavailable.")
    }

    func testGarageStabilityScoreStaysHighForStableCoreAnchors() {
        let frames = makeStabilityFrames(
            headOffsets: [
                CGPoint(x: 0.000, y: 0.000),
                CGPoint(x: 0.004, y: 0.003),
                CGPoint(x: 0.006, y: 0.004),
                CGPoint(x: 0.005, y: 0.003),
                CGPoint(x: 0.003, y: 0.002),
                CGPoint(x: 0.002, y: 0.002)
            ],
            pelvisOffsets: [
                CGPoint(x: 0.000, y: 0.000),
                CGPoint(x: 0.003, y: 0.002),
                CGPoint(x: 0.004, y: 0.003),
                CGPoint(x: 0.004, y: 0.002),
                CGPoint(x: 0.002, y: 0.001),
                CGPoint(x: 0.001, y: 0.001)
            ]
        )

        let score = GarageStability.score(for: makeStabilityRecord(frames: frames))

        XCTAssertNotNil(score)
        XCTAssertGreaterThanOrEqual(score ?? 0, 85)
    }

    func testGarageStabilityScoreDropsWhenHeadAndPelvisDriftWidely() {
        let frames = makeStabilityFrames(
            headOffsets: [
                CGPoint(x: 0.000, y: 0.000),
                CGPoint(x: 0.035, y: 0.020),
                CGPoint(x: 0.060, y: 0.040),
                CGPoint(x: 0.090, y: 0.065),
                CGPoint(x: 0.110, y: 0.080),
                CGPoint(x: 0.125, y: 0.095)
            ],
            pelvisOffsets: [
                CGPoint(x: 0.000, y: 0.000),
                CGPoint(x: 0.025, y: 0.015),
                CGPoint(x: 0.045, y: 0.025),
                CGPoint(x: 0.065, y: 0.040),
                CGPoint(x: 0.085, y: 0.050),
                CGPoint(x: 0.100, y: 0.060)
            ]
        )

        let score = GarageStability.score(for: makeStabilityRecord(frames: frames))

        XCTAssertNotNil(score)
        XCTAssertLessThanOrEqual(score ?? 100, 50)
    }

    func testGarageStabilityScoreReturnsNilWhenCoreJointsLoseConfidence() {
        let frames = makeStabilityFrames(
            headOffsets: Array(repeating: CGPoint.zero, count: 10),
            pelvisOffsets: Array(repeating: CGPoint.zero, count: 10),
            lowConfidenceIndices: [1, 3, 5, 7]
        )

        let score = GarageStability.score(for: makeStabilityRecord(frames: frames))

        XCTAssertNil(score)
    }

    func testGarageStabilityScoreReturnsNilWithoutImpactCheckpoint() {
        let frames = makeStabilityFrames(
            headOffsets: Array(repeating: CGPoint.zero, count: 6),
            pelvisOffsets: Array(repeating: CGPoint.zero, count: 6)
        )

        let score = GarageStability.score(
            for: makeStabilityRecord(frames: frames, includeImpact: false)
        )

        XCTAssertNil(score)
    }

    func testAutomaticHandPathAutoApprovesReliableSwing() {
        let frames = makeReliableAutomaticHandPathFrames()
        let keyFrames = GarageAnalysisPipeline.detectKeyFrames(from: frames)

        let report = GarageAnalysisPipeline.handPathReviewReport(for: frames, keyFrames: keyFrames)
        let autoApproved = GarageAnalysisPipeline.autoApprovedKeyFrames(from: keyFrames, reviewReport: report)

        XCTAssertFalse(report.requiresManualReview)
        XCTAssertGreaterThanOrEqual(report.score, 70)
        XCTAssertGreaterThanOrEqual(report.continuityScore, 0.8)
        XCTAssertTrue(autoApproved.allSatisfy { $0.reviewStatus == .approved })
    }

    func testAutomaticHandPathStaysUsableWhenOneWristDropsOutBriefly() {
        let frames = makeSingleWristDropoutSwingFrames()
        let keyFrames = GarageAnalysisPipeline.detectKeyFrames(from: frames)

        let report = GarageAnalysisPipeline.handPathReviewReport(for: frames, keyFrames: keyFrames)
        let segmentedSamples = GarageAnalysisPipeline.segmentedHandPathSamples(from: frames, keyFrames: keyFrames, samplesPerSegment: 4)
        let fallbackFrameIndex = 3
        let rightWrist = frames[fallbackFrameIndex].point(named: .rightWrist, minimumConfidence: 0.5)
        let estimatedGrip = GarageAnalysisPipeline.handCenter(in: frames[fallbackFrameIndex])

        XCTAssertFalse(report.requiresManualReview)
        XCTAssertGreaterThanOrEqual(report.score, 55)
        XCTAssertFalse(segmentedSamples.isEmpty)
        XCTAssertNotNil(rightWrist)
        if let rightWrist {
            XCTAssertLessThan(GarageAnalysisPipeline.distance(from: estimatedGrip, to: rightWrist), 0.02)
        }
    }

    func testAutomaticHandPathFallsBackWhenWristConfidenceCollapses() {
        let frames = makeSeverelyBrokenHandPathFrames()
        let keyFrames = GarageAnalysisPipeline.detectKeyFrames(from: frames)

        let report = GarageAnalysisPipeline.handPathReviewReport(for: frames, keyFrames: keyFrames)

        XCTAssertTrue(report.requiresManualReview)
        XCTAssertLessThan(report.score, 65)
        XCTAssertFalse(report.weakPhases.isEmpty)
        XCTAssertNotNil(report.weakestPhase)
    }

    func testSegmentedHandPathStopsAtImpactAndExcludesFollowThroughDrawing() {
        let frames = makeReliableAutomaticHandPathFrames()
        let keyFrames = GarageAnalysisPipeline.detectKeyFrames(from: frames)
        let samples = GarageAnalysisPipeline.segmentedHandPathSamples(from: frames, keyFrames: keyFrames, samplesPerSegment: 4)

        guard
            let topIndex = keyFrames.first(where: { $0.phase == .topOfBackswing })?.frameIndex,
            let impactIndex = keyFrames.first(where: { $0.phase == .impact })?.frameIndex,
            let followThroughIndex = keyFrames.first(where: { $0.phase == .followThrough })?.frameIndex
        else {
            return XCTFail("Missing expected checkpoints for segmented hand-path test.")
        }

        let topTimestamp = frames[topIndex].timestamp
        let impactTimestamp = frames[impactIndex].timestamp

        XCTAssertFalse(samples.isEmpty)
        XCTAssertGreaterThan(followThroughIndex, impactIndex)
        XCTAssertTrue(samples.contains(where: { $0.segment == .backswing && $0.timestamp <= topTimestamp }))
        XCTAssertTrue(samples.contains(where: { $0.segment == .downswing && $0.timestamp > topTimestamp }))
        XCTAssertTrue(samples.allSatisfy { $0.timestamp <= impactTimestamp + 0.0001 })
    }

    func testSkeletonHeadCircleResolvesFromReliableHeadReferences() {
        let frame = makeHeadCircleFrame()
        let headCircle = GarageAnalysisPipeline.headCircle(in: frame)

        XCTAssertNotNil(headCircle)
        XCTAssertGreaterThan(headCircle?.radius ?? 0, 0.03)
        XCTAssertLessThan(headCircle?.center.y ?? 1, 0.22)
    }

    func testSkeletonHeadCircleReturnsNilWhenHeadReferencesAreWeak() {
        let frame = makeHeadCircleFrame(noseConfidence: 0.3)

        XCTAssertNil(GarageAnalysisPipeline.headCircle(in: frame))
    }
}

@MainActor
private func makeSyntheticSwingFrames() -> [SwingFrame] {
    let wristPairs: [(Double, Double, Double, Double)] = [
        (0.30, 0.72, 0.34, 0.72),
        (0.32, 0.71, 0.36, 0.71),
        (0.36, 0.67, 0.40, 0.67),
        (0.42, 0.58, 0.46, 0.58),
        (0.48, 0.46, 0.52, 0.46),
        (0.54, 0.34, 0.58, 0.34),
        (0.52, 0.39, 0.56, 0.39),
        (0.46, 0.50, 0.50, 0.50),
        (0.34, 0.70, 0.38, 0.70),
        (0.56, 0.28, 0.60, 0.28)
    ]

    return wristPairs.enumerated().map { index, wrists in
        let (leftWristX, leftWristY, rightWristX, rightWristY) = wrists
        return SwingFrame(
            timestamp: Double(index) * 0.1,
            joints: [
                joint(.leftShoulder, x: 0.40, y: 0.34),
                joint(.rightShoulder, x: 0.60, y: 0.34),
                joint(.leftHip, x: 0.44, y: 0.60),
                joint(.rightHip, x: 0.58, y: 0.60),
                joint(.leftWrist, x: leftWristX, y: leftWristY),
                joint(.rightWrist, x: rightWristX, y: rightWristY)
            ],
            confidence: 0.9
        )
    }
}

@MainActor
private func makeLateDownswingDriftFrames() -> [SwingFrame] {
    let wristPairs: [(Double, Double, Double, Double)] = [
        (0.30, 0.72, 0.34, 0.72),
        (0.33, 0.68, 0.37, 0.68),
        (0.38, 0.60, 0.42, 0.60),
        (0.45, 0.49, 0.49, 0.49),
        (0.52, 0.36, 0.56, 0.36), // top
        (0.50, 0.40, 0.54, 0.40), // transition
        (0.48, 0.46, 0.52, 0.46),
        (0.44, 0.56, 0.48, 0.56), // early downswing candidate
        (0.39, 0.66, 0.43, 0.66), // impact neighborhood
        (0.56, 0.30, 0.60, 0.30)  // follow through
    ]

    return wristPairs.enumerated().map { index, wrists in
        let (leftWristX, leftWristY, rightWristX, rightWristY) = wrists
        return SwingFrame(
            timestamp: Double(index) * 0.1,
            joints: [
                joint(.leftShoulder, x: 0.40, y: 0.34),
                joint(.rightShoulder, x: 0.60, y: 0.34),
                joint(.leftHip, x: 0.44, y: 0.60),
                joint(.rightHip, x: 0.58, y: 0.60),
                joint(.leftWrist, x: leftWristX, y: leftWristY),
                joint(.rightWrist, x: rightWristX, y: rightWristY)
            ],
            confidence: 0.9
        )
    }
}

@MainActor
private func makeFullBodyDTLSwingFrames(missingCriticalImpactJoints: Bool = false) -> [SwingFrame] {
    struct BodyState {
        let noseX: Double
        let noseY: Double
        let pelvisShiftX: Double
        let pelvisShiftY: Double
        let leftKneeX: Double
        let rightKneeX: Double
    }

    let wristPairs: [(Double, Double, Double, Double)] = [
        (0.30, 0.72, 0.34, 0.72),
        (0.32, 0.71, 0.36, 0.71),
        (0.36, 0.67, 0.40, 0.67),
        (0.42, 0.58, 0.46, 0.58),
        (0.47, 0.47, 0.51, 0.47),
        (0.51, 0.38, 0.55, 0.38),
        (0.54, 0.32, 0.58, 0.32),
        (0.48, 0.46, 0.52, 0.46),
        (0.34, 0.70, 0.38, 0.70),
        (0.56, 0.28, 0.60, 0.28)
    ]

    let bodyStates: [BodyState] = [
        BodyState(noseX: 0.500, noseY: 0.200, pelvisShiftX: 0.000, pelvisShiftY: 0.000, leftKneeX: 0.460, rightKneeX: 0.560),
        BodyState(noseX: 0.501, noseY: 0.201, pelvisShiftX: 0.002, pelvisShiftY: 0.000, leftKneeX: 0.460, rightKneeX: 0.560),
        BodyState(noseX: 0.503, noseY: 0.202, pelvisShiftX: 0.003, pelvisShiftY: 0.000, leftKneeX: 0.461, rightKneeX: 0.559),
        BodyState(noseX: 0.506, noseY: 0.204, pelvisShiftX: 0.004, pelvisShiftY: 0.000, leftKneeX: 0.462, rightKneeX: 0.558),
        BodyState(noseX: 0.508, noseY: 0.205, pelvisShiftX: 0.005, pelvisShiftY: 0.001, leftKneeX: 0.464, rightKneeX: 0.556),
        BodyState(noseX: 0.510, noseY: 0.206, pelvisShiftX: 0.006, pelvisShiftY: 0.001, leftKneeX: 0.466, rightKneeX: 0.554),
        BodyState(noseX: 0.512, noseY: 0.206, pelvisShiftX: 0.007, pelvisShiftY: 0.001, leftKneeX: 0.468, rightKneeX: 0.552),
        BodyState(noseX: 0.507, noseY: 0.207, pelvisShiftX: 0.010, pelvisShiftY: 0.001, leftKneeX: 0.472, rightKneeX: 0.548),
        BodyState(noseX: 0.495, noseY: 0.209, pelvisShiftX: 0.018, pelvisShiftY: 0.002, leftKneeX: 0.490, rightKneeX: 0.540),
        BodyState(noseX: 0.490, noseY: 0.208, pelvisShiftX: 0.014, pelvisShiftY: 0.001, leftKneeX: 0.486, rightKneeX: 0.542)
    ]

    return wristPairs.enumerated().map { index, wrists in
        let (leftWristX, leftWristY, rightWristX, rightWristY) = wrists
        let state = bodyStates[index]
        let isImpact = index == 8
        let criticalConfidence = missingCriticalImpactJoints && isImpact ? 0.2 : 0.96
        let leftHipX = 0.45 + state.pelvisShiftX
        let rightHipX = 0.55 + state.pelvisShiftX
        let pelvisY = 0.60 + state.pelvisShiftY

        return SwingFrame(
            timestamp: Double(index) * 0.1,
            joints: [
                joint(.nose, x: state.noseX, y: state.noseY, confidence: criticalConfidence),
                joint(.leftShoulder, x: 0.42 + (state.pelvisShiftX * 0.4), y: 0.34),
                joint(.rightShoulder, x: 0.58 + (state.pelvisShiftX * 0.4), y: 0.34),
                joint(.leftElbow, x: leftWristX - 0.03, y: leftWristY - 0.10),
                joint(.rightElbow, x: rightWristX - 0.03, y: rightWristY - 0.10),
                joint(.leftHip, x: leftHipX, y: pelvisY),
                joint(.rightHip, x: rightHipX, y: pelvisY),
                joint(.leftKnee, x: state.leftKneeX, y: 0.78, confidence: criticalConfidence),
                joint(.rightKnee, x: state.rightKneeX, y: 0.78, confidence: criticalConfidence),
                joint(.leftAnkle, x: 0.46, y: 0.94, confidence: criticalConfidence),
                joint(.rightAnkle, x: 0.56, y: 0.94, confidence: criticalConfidence),
                joint(.leftWrist, x: leftWristX, y: leftWristY),
                joint(.rightWrist, x: rightWristX, y: rightWristY)
            ],
            confidence: missingCriticalImpactJoints && isImpact ? 0.62 : 0.96
        )
    }
}

@MainActor
private func joint(_ name: SwingJointName, x: Double, y: Double, confidence: Double = 0.9) -> SwingJoint {
    SwingJoint(name: name, x: x, y: y, confidence: confidence)
}

@MainActor
private func makeStep2KeyFrames() -> [KeyFrame] {
    [
        KeyFrame(phase: .address, frameIndex: 0),
        KeyFrame(phase: .takeaway, frameIndex: 1),
        KeyFrame(phase: .shaftParallel, frameIndex: 3),
        KeyFrame(phase: .topOfBackswing, frameIndex: 6),
        KeyFrame(phase: .transition, frameIndex: 7),
        KeyFrame(phase: .earlyDownswing, frameIndex: 7),
        KeyFrame(phase: .impact, frameIndex: 8),
        KeyFrame(phase: .followThrough, frameIndex: 9)
    ]
}

@MainActor
private func makeFullAnchorSet() -> [HandAnchor] {
    [
        HandAnchor(phase: .address, x: 0.30, y: 0.72),
        HandAnchor(phase: .takeaway, x: 0.35, y: 0.68),
        HandAnchor(phase: .shaftParallel, x: 0.42, y: 0.56),
        HandAnchor(phase: .topOfBackswing, x: 0.52, y: 0.34),
        HandAnchor(phase: .transition, x: 0.50, y: 0.39),
        HandAnchor(phase: .earlyDownswing, x: 0.43, y: 0.50),
        HandAnchor(phase: .impact, x: 0.32, y: 0.70),
        HandAnchor(phase: .followThrough, x: 0.58, y: 0.26)
    ]
}

@MainActor
private func makeWorkflowRecord(
    keyframeValidationStatus: KeyframeValidationStatus,
    anchors: [HandAnchor],
    pathPoints: [PathPoint]
) -> SwingRecord {
    let filename = "workflow.mov"
    makePersistedGarageVideoFixture(named: filename)
    let frames = makeSyntheticSwingFrames()
    let keyFrames = GarageAnalysisPipeline.detectKeyFrames(from: frames)

    return SwingRecord(
        title: "Workflow Record",
        mediaFilename: filename,
        frameRate: 60,
        swingFrames: frames,
        keyFrames: keyFrames,
        keyframeValidationStatus: keyframeValidationStatus,
        handAnchors: anchors,
        pathPoints: pathPoints,
        analysisResult: AnalysisResult(
            issues: [],
            highlights: ["Workflow baseline"],
            summary: "Processed synthetic swing frames."
        )
    )
}

@MainActor
private func makeStabilityFrames(
    headOffsets: [CGPoint],
    pelvisOffsets: [CGPoint],
    lowConfidenceIndices: Set<Int> = []
) -> [SwingFrame] {
    precondition(headOffsets.count == pelvisOffsets.count)

    let baseNose = CGPoint(x: 0.50, y: 0.20)
    let baseLeftShoulder = CGPoint(x: 0.42, y: 0.34)
    let baseRightShoulder = CGPoint(x: 0.58, y: 0.34)
    let baseLeftHip = CGPoint(x: 0.45, y: 0.60)
    let baseRightHip = CGPoint(x: 0.55, y: 0.60)

    return headOffsets.enumerated().map { index, headOffset in
        let pelvisOffset = pelvisOffsets[index]
        let coreConfidence = lowConfidenceIndices.contains(index) ? 0.3 : 0.95

        return SwingFrame(
            timestamp: Double(index) * 0.1,
            joints: [
                joint(.nose, x: baseNose.x + headOffset.x, y: baseNose.y + headOffset.y, confidence: coreConfidence),
                joint(.leftShoulder, x: baseLeftShoulder.x, y: baseLeftShoulder.y),
                joint(.rightShoulder, x: baseRightShoulder.x, y: baseRightShoulder.y),
                joint(.leftHip, x: baseLeftHip.x + pelvisOffset.x, y: baseLeftHip.y + pelvisOffset.y, confidence: coreConfidence),
                joint(.rightHip, x: baseRightHip.x + pelvisOffset.x, y: baseRightHip.y + pelvisOffset.y, confidence: coreConfidence),
                joint(.leftWrist, x: 0.36 + pelvisOffset.x, y: 0.72),
                joint(.rightWrist, x: 0.40 + pelvisOffset.x, y: 0.72)
            ],
            confidence: lowConfidenceIndices.contains(index) ? 0.55 : 0.95
        )
    }
}

@MainActor
private func makeStabilityRecord(frames: [SwingFrame], includeImpact: Bool = true) -> SwingRecord {
    let lastIndex = max(frames.count - 1, 0)
    var keyFrames = [
        KeyFrame(phase: .address, frameIndex: 0)
    ]

    if includeImpact {
        keyFrames.append(KeyFrame(phase: .impact, frameIndex: lastIndex))
    }

    return SwingRecord(
        title: "Stability Record",
        frameRate: 60,
        swingFrames: frames,
        keyFrames: keyFrames,
        analysisResult: AnalysisResult(
            issues: [],
            highlights: [],
            summary: "Synthetic stability case."
        )
    )
}

@MainActor
private func makeReliableAutomaticHandPathFrames() -> [SwingFrame] {
    let wristPairs: [(Double, Double, Double, Double)] = [
        (0.31, 0.73, 0.35, 0.73),
        (0.33, 0.71, 0.37, 0.71),
        (0.37, 0.66, 0.41, 0.66),
        (0.43, 0.57, 0.47, 0.57),
        (0.49, 0.46, 0.53, 0.46),
        (0.53, 0.37, 0.57, 0.37),
        (0.50, 0.42, 0.54, 0.42),
        (0.45, 0.51, 0.49, 0.51),
        (0.38, 0.63, 0.42, 0.63),
        (0.34, 0.71, 0.38, 0.71),
        (0.55, 0.31, 0.59, 0.31)
    ]

    return wristPairs.enumerated().map { index, wrists in
        let (leftWristX, leftWristY, rightWristX, rightWristY) = wrists
        return SwingFrame(
            timestamp: Double(index) * 0.08,
            joints: [
                joint(.nose, x: 0.50, y: 0.21),
                joint(.leftShoulder, x: 0.41, y: 0.34),
                joint(.rightShoulder, x: 0.59, y: 0.34),
                joint(.leftHip, x: 0.45, y: 0.59),
                joint(.rightHip, x: 0.57, y: 0.59),
                joint(.leftWrist, x: leftWristX, y: leftWristY),
                joint(.rightWrist, x: rightWristX, y: rightWristY)
            ],
            confidence: 0.95
        )
    }
}

@MainActor
private func makeSingleWristDropoutSwingFrames() -> [SwingFrame] {
    let wristPairs: [(Double, Double, Double, Double, Double, Double)] = [
        (0.31, 0.73, 0.35, 0.73, 0.95, 0.95),
        (0.34, 0.70, 0.38, 0.70, 0.95, 0.95),
        (0.39, 0.63, 0.43, 0.63, 0.20, 0.95),
        (0.45, 0.55, 0.49, 0.55, 0.18, 0.96),
        (0.50, 0.45, 0.54, 0.45, 0.95, 0.95),
        (0.53, 0.38, 0.57, 0.38, 0.95, 0.95),
        (0.49, 0.43, 0.53, 0.43, 0.22, 0.94),
        (0.43, 0.53, 0.47, 0.53, 0.95, 0.95),
        (0.37, 0.65, 0.41, 0.65, 0.95, 0.95),
        (0.33, 0.72, 0.37, 0.72, 0.95, 0.95),
        (0.55, 0.31, 0.59, 0.31, 0.95, 0.95)
    ]

    return wristPairs.enumerated().map { index, wrists in
        let (leftWristX, leftWristY, rightWristX, rightWristY, leftConfidence, rightConfidence) = wrists
        return SwingFrame(
            timestamp: Double(index) * 0.08,
            joints: [
                joint(.nose, x: 0.50, y: 0.21),
                joint(.leftShoulder, x: 0.41, y: 0.34),
                joint(.rightShoulder, x: 0.59, y: 0.34),
                joint(.leftHip, x: 0.45, y: 0.59),
                joint(.rightHip, x: 0.57, y: 0.59),
                joint(.leftWrist, x: leftWristX, y: leftWristY, confidence: leftConfidence),
                joint(.rightWrist, x: rightWristX, y: rightWristY, confidence: rightConfidence)
            ],
            confidence: 0.9
        )
    }
}

@MainActor
private func makeSeverelyBrokenHandPathFrames() -> [SwingFrame] {
    let wristPairs: [(Double, Double, Double, Double, Double, Double)] = [
        (0.31, 0.73, 0.35, 0.73, 0.95, 0.95),
        (0.33, 0.70, 0.37, 0.70, 0.10, 0.10),
        (0.44, 0.44, 0.48, 0.44, 0.10, 0.10),
        (0.18, 0.18, 0.22, 0.18, 0.10, 0.10),
        (0.54, 0.35, 0.58, 0.35, 0.95, 0.95),
        (0.24, 0.82, 0.28, 0.82, 0.10, 0.10),
        (0.49, 0.44, 0.53, 0.44, 0.10, 0.10),
        (0.41, 0.55, 0.45, 0.55, 0.10, 0.10),
        (0.34, 0.69, 0.38, 0.69, 0.10, 0.10),
        (0.56, 0.29, 0.60, 0.29, 0.95, 0.95)
    ]

    return wristPairs.enumerated().map { index, wrists in
        let (leftWristX, leftWristY, rightWristX, rightWristY, leftConfidence, rightConfidence) = wrists
        return SwingFrame(
            timestamp: Double(index) * 0.08,
            joints: [
                joint(.leftShoulder, x: 0.41, y: 0.34),
                joint(.rightShoulder, x: 0.59, y: 0.34),
                joint(.leftHip, x: 0.45, y: 0.59),
                joint(.rightHip, x: 0.57, y: 0.59),
                joint(.leftWrist, x: leftWristX, y: leftWristY, confidence: leftConfidence),
                joint(.rightWrist, x: rightWristX, y: rightWristY, confidence: rightConfidence)
            ],
            confidence: 0.45
        )
    }
}

@MainActor
private func makeHeadCircleFrame(noseConfidence: Double = 0.95, shoulderConfidence: Double = 0.95) -> SwingFrame {
    SwingFrame(
        timestamp: 0,
        joints: [
            joint(.nose, x: 0.50, y: 0.20, confidence: noseConfidence),
            joint(.leftShoulder, x: 0.42, y: 0.34, confidence: shoulderConfidence),
            joint(.rightShoulder, x: 0.58, y: 0.34, confidence: shoulderConfidence),
            joint(.leftHip, x: 0.45, y: 0.60),
            joint(.rightHip, x: 0.55, y: 0.60)
        ],
        confidence: 0.95
    )
}

@MainActor
private func makePersistedGarageVideoFixture(named filename: String) {
    let fileManager = FileManager.default
    guard
        let baseURL = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
    else {
        return
    }

    let garageURL = baseURL.appendingPathComponent("GarageSwingVideos", isDirectory: true)
    let fileURL = garageURL.appendingPathComponent(filename)

    if fileManager.fileExists(atPath: fileURL.path) {
        return
    }

    try? fileManager.createDirectory(at: garageURL, withIntermediateDirectories: true)
    fileManager.createFile(atPath: fileURL.path, contents: Data())
}
