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
private func joint(_ name: SwingJointName, x: Double, y: Double, confidence: Double = 0.9) -> SwingJoint {
    SwingJoint(name: name, x: x, y: y, confidence: confidence)
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
