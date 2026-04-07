//
//  LIFE_IN_SYNCTests.swift
//  LIFE-IN-SYNCTests
//
//  Created by Colton Thomas on 3/31/26.
//

import Foundation
import Testing
@testable import LIFE_IN_SYNC

@MainActor
struct LIFE_IN_SYNCTests {
    @Test func habitModelStoresIdentityAndTarget() async throws {
        let habit = Habit(name: "Water", targetCount: 8)

        #expect(habit.name == "Water")
        #expect(habit.targetCount == 8)
        #expect(habit.id.uuidString.isEmpty == false)
    }

    @Test func taskModelDefaultsToOpenMediumPriority() async throws {
        let task = TaskItem(title: "Call bank")

        #expect(task.isCompleted == false)
        #expect(task.priority == TaskPriority.medium.rawValue)
        #expect(task.id.uuidString.isEmpty == false)
    }

    @Test func studyEntryStoresNotes() async throws {
        let entry = StudyEntry(title: "Morning Study", passageReference: "Psalm 1", notes: "Meditate on the contrast.")

        #expect(entry.title == "Morning Study")
        #expect(entry.passageReference == "Psalm 1")
        #expect(entry.notes == "Meditate on the contrast.")
    }

    @Test func swingRecordStoresOptionalMediaAndNotes() async throws {
        let record = SwingRecord(title: "Driver session", mediaFilename: "swing.mov", notes: "Ball started left.")

        #expect(record.mediaFilename == "swing.mov")
        #expect(record.notes == "Ball started left.")
    }

    @Test func garagePathGenerationIncludesEndpointsAndIntermediateSamples() async throws {
        let anchors = [
            HandAnchor(phase: .address, x: 0.30, y: 0.72),
            HandAnchor(phase: .takeaway, x: 0.35, y: 0.68),
            HandAnchor(phase: .shaftParallel, x: 0.42, y: 0.56),
            HandAnchor(phase: .topOfBackswing, x: 0.52, y: 0.34),
            HandAnchor(phase: .transition, x: 0.50, y: 0.39),
            HandAnchor(phase: .earlyDownswing, x: 0.43, y: 0.50),
            HandAnchor(phase: .impact, x: 0.32, y: 0.70),
            HandAnchor(phase: .followThrough, x: 0.58, y: 0.26)
        ]

        let points = GarageAnalysisPipeline.generatePathPoints(from: anchors, samplesPerSegment: 4)

        #expect(points.count == 29)
        #expect(points.first?.x == anchors.first?.x)
        #expect(points.first?.y == anchors.first?.y)
        #expect(points.last?.x == anchors.last?.x)
        #expect(points.last?.y == anchors.last?.y)
        #expect(points[5].x != 0.3675)
    }

    @Test func garageDeterministicHandPathSampleIDIsStableAcrossRepeatedGeneration() async throws {
        let timestamps: [Double] = [0.0, 0.016667, 0.033333, 0.1, 0.5, 1.25]

        let firstPass = timestamps.enumerated().map { index, timestamp in
            garageDeterministicHandPathSampleID(index: index, timestamp: timestamp)
        }
        let secondPass = timestamps.enumerated().map { index, timestamp in
            garageDeterministicHandPathSampleID(index: index, timestamp: timestamp)
        }

        #expect(firstPass == secondPass)
        #expect(Set(firstPass).count == firstPass.count)
    }

    @Test func garageKeyframeDetectionReturnsCanonicalPhaseOrder() async throws {
        let frames = makeSyntheticSwingFrames()

        let keyFrames = GarageAnalysisPipeline.detectKeyFrames(from: frames)

        #expect(keyFrames.count == SwingPhase.allCases.count)
        #expect(keyFrames.map(\.phase) == SwingPhase.allCases)
        #expect(keyFrames.map(\.decodedFrameIndex) == keyFrames.map(\.decodedFrameIndex).sorted())
        #expect(keyFrames[5].decodedFrameIndex < keyFrames[6].decodedFrameIndex)
        #expect(keyFrames[6].decodedFrameIndex < keyFrames[7].decodedFrameIndex)
    }

    @Test func garageKeyframeDetectionSkipsQuietPrerollAndFindsAddressNearSwingStart() async throws {
        let frames = makePrerollSwingFrames()

        let keyFrames = GarageAnalysisPipeline.detectKeyFrames(from: frames)

        #expect(keyFrames.first?.phase == .address)
        #expect((keyFrames.first?.decodedFrameIndex ?? -1) >= 2)
        #expect((keyFrames.first?.decodedFrameIndex ?? -1) < (keyFrames[1].decodedFrameIndex))
    }

    @Test func garageKeyframeDetectionKeepsImpactDistinctFromEarlyDownswing() async throws {
        let frames = makeSyntheticSwingFrames()

        let keyFrames = GarageAnalysisPipeline.detectKeyFrames(from: frames)

        let earlyDownswing = keyFrames.first(where: { $0.phase == .earlyDownswing })?.decodedFrameIndex ?? -1
        let impact = keyFrames.first(where: { $0.phase == .impact })?.decodedFrameIndex ?? -1
        #expect(impact > earlyDownswing)
    }

    @Test func garageKeyframeDetectionPlacesEarlyBackswingFramesCloserToTakeawayAndShaftParallel() async throws {
        let frames = makeSyntheticSwingFrames()

        let keyFrames = GarageAnalysisPipeline.detectKeyFrames(from: frames)
        let takeaway = try #require(keyFrames.first(where: { $0.phase == .takeaway }))
        let shaftParallel = try #require(keyFrames.first(where: { $0.phase == .shaftParallel }))
        let top = try #require(keyFrames.first(where: { $0.phase == .topOfBackswing }))

        #expect(takeaway.decodedFrameIndex <= 2)
        #expect(shaftParallel.decodedFrameIndex <= 4)
        #expect(takeaway.decodedFrameIndex < shaftParallel.decodedFrameIndex)
        #expect(shaftParallel.decodedFrameIndex < top.decodedFrameIndex)
    }

    @Test func garageKeyframeDetectionKeepsTransitionNearTopReversal() async throws {
        let frames = makeSyntheticSwingFrames()

        let keyFrames = GarageAnalysisPipeline.detectKeyFrames(from: frames)
        let top = try #require(keyFrames.first(where: { $0.phase == .topOfBackswing }))
        let transition = try #require(keyFrames.first(where: { $0.phase == .transition }))

        #expect(transition.decodedFrameIndex >= top.decodedFrameIndex + 1)
        #expect(transition.decodedFrameIndex <= top.decodedFrameIndex + 2)
    }

    @Test func garageKeyframeDetectionCarriesCanonicalDecodedFrameIdentity() async throws {
        let frames = makeSyntheticSwingFrames()
        let decodedFrameTimestamps = frames.map(\.timestamp)

        let keyFrames = GarageAnalysisPipeline.detectKeyFrames(from: frames, videoFrameRate: 120, decodedFrameTimestamps: decodedFrameTimestamps)
        let top = try #require(keyFrames.first(where: { $0.phase == .topOfBackswing }))

        #expect(top.decodedFrameIndex == 5)
        #expect(decodedFrameTimestamps[top.decodedFrameIndex] == frames[5].timestamp)
    }

    @Test func garageKeyframeDetectionDoesNotUseLateFinishAsTopOfBackswing() async throws {
        let frames = makeLateFinishSwingFrames()

        let keyFrames = GarageAnalysisPipeline.detectKeyFrames(from: frames)
        let top = keyFrames.first(where: { $0.phase == .topOfBackswing })?.decodedFrameIndex ?? -1
        let follow = keyFrames.first(where: { $0.phase == .followThrough })?.decodedFrameIndex ?? -1

        #expect(top == 5)
        #expect(follow > top)
    }

    @Test func garageDecodedFrameNavigationUsesAdjacentDecodedFramesWithoutContinuityError() async throws {
        let decodedFrameTimestamps = (0...140).map { Double($0) / 60.0 }

        let frame69Timestamp = GarageDecodedFrameNavigation.timestamp(
            for: 69,
            timestamps: decodedFrameTimestamps,
            fallbackFrameRate: 60,
            fallbackDuration: decodedFrameTimestamps.last ?? 0
        )
        let frame70Timestamp = GarageDecodedFrameNavigation.timestamp(
            for: 70,
            timestamps: decodedFrameTimestamps,
            fallbackFrameRate: 60,
            fallbackDuration: decodedFrameTimestamps.last ?? 0
        )

        #expect(frame69Timestamp == decodedFrameTimestamps[69])
        #expect(frame70Timestamp == decodedFrameTimestamps[70])
        #expect(abs(frame70Timestamp - frame69Timestamp) <= (1.0 / 60.0) + 0.0001)
        #expect(
            GarageDecodedFrameNavigation.continuityError(
                timestampDelta: frame70Timestamp - frame69Timestamp,
                landmarkDisplacement: 0.01,
                decodedFrameTimestamps: decodedFrameTimestamps,
                fallbackFrameRate: 60
            ) == false
        )
    }

    @Test func garageInsightsReportBecomesReadyWhenAnchorsAndPathExist() async throws {
        let frames = makeSyntheticSwingFrames()
        let keyFrames = GarageAnalysisPipeline.detectKeyFrames(from: frames)
        let anchors = [
            HandAnchor(phase: .address, x: 0.30, y: 0.72),
            HandAnchor(phase: .takeaway, x: 0.35, y: 0.68),
            HandAnchor(phase: .shaftParallel, x: 0.42, y: 0.56),
            HandAnchor(phase: .topOfBackswing, x: 0.52, y: 0.34),
            HandAnchor(phase: .transition, x: 0.50, y: 0.39),
            HandAnchor(phase: .earlyDownswing, x: 0.43, y: 0.50),
            HandAnchor(phase: .impact, x: 0.32, y: 0.70),
            HandAnchor(phase: .followThrough, x: 0.58, y: 0.26)
        ]
        let pathPoints = GarageAnalysisPipeline.generatePathPoints(from: anchors, samplesPerSegment: 4)
        let record = SwingRecord(
            title: "7 Iron",
            frameRate: 60,
            decodedFrames: makeDecodedFrames(from: frames),
            decodedFrameTimestamps: frames.map(\.timestamp),
            swingFrames: frames,
            keyFrames: keyFrames,
            keyframeValidationStatus: .approved,
            handAnchors: anchors,
            pathPoints: pathPoints,
            analysisResult: AnalysisResult(
                issues: [],
                highlights: ["Synthetic baseline"],
                summary: "Processed synthetic swing frames."
            )
        )

        let report = GarageInsights.report(for: record)

        #expect(report.isReady)
        #expect(report.metrics.contains(where: { $0.title == "Tempo" }))
        #expect(report.metrics.contains(where: { $0.title == "Impact Return" }))
        #expect(report.metrics.contains(where: { $0.title == "Anchor Coverage" && $0.value == "100%" }))
        #expect(report.highlights.contains(where: { $0.contains("tempo profile") }))
    }

    @Test func garageWorkflowMarksAnchorsIncompleteUntilAllEightArePlaced() async throws {
        let record = makeWorkflowRecord(
            keyframeValidationStatus: .approved,
            anchors: Array(makeFullAnchorSet().prefix(5)),
            pathPoints: []
        )

        let progress = GarageWorkflow.progress(for: record)

        #expect(progress.stages.first(where: { $0.stage == .markAnchors })?.status == .incomplete)
        #expect(progress.nextAction.stage == .markAnchors)
    }

    @Test func garageWorkflowPrioritizesFlaggedKeyframesAsNeedsAttention() async throws {
        let record = makeWorkflowRecord(
            keyframeValidationStatus: .flagged,
            anchors: makeFullAnchorSet(),
            pathPoints: GarageAnalysisPipeline.generatePathPoints(from: makeFullAnchorSet(), samplesPerSegment: 4)
        )

        let progress = GarageWorkflow.progress(for: record)

        #expect(progress.stages.first(where: { $0.stage == .validateKeyframes })?.status == .needsAttention)
        #expect(progress.nextAction.stage == .validateKeyframes)
    }

    @Test func garageCaptureQualityFlagsCollapsedLateSwingAndWeakScale() async throws {
        let frames = makePoorlyFramedSwingFrames()
        let keyFrames = [
            KeyFrame(phase: .address, decodedFrameIndex: 0),
            KeyFrame(phase: .takeaway, decodedFrameIndex: 1),
            KeyFrame(phase: .shaftParallel, decodedFrameIndex: 2),
            KeyFrame(phase: .topOfBackswing, decodedFrameIndex: 3),
            KeyFrame(phase: .transition, decodedFrameIndex: 4),
            KeyFrame(phase: .earlyDownswing, decodedFrameIndex: 5),
            KeyFrame(phase: .impact, decodedFrameIndex: 5),
            KeyFrame(phase: .followThrough, decodedFrameIndex: 6)
        ]
        let record = SwingRecord(
            title: "Poor Capture",
            frameRate: 60,
            decodedFrames: makeDecodedFrames(from: frames),
            decodedFrameTimestamps: frames.map(\.timestamp),
            swingFrames: frames,
            keyFrames: keyFrames,
            keyframeValidationStatus: .pending,
            handAnchors: [],
            pathPoints: [],
            analysisResult: AnalysisResult(issues: [], highlights: [], summary: "Synthetic poor framing case.")
        )

        let report = GarageCaptureQuality.report(for: record)

        #expect(report.status == .poor)
        #expect(report.findings.contains(where: { $0.title.contains("collapsing") }))
        #expect(report.findings.contains(where: { $0.title.contains("small in frame") }))
    }

    @Test func garageWorkflowFlagsKeyframesWhenCaptureQualityIsPoor() async throws {
        let frames = makePoorlyFramedSwingFrames()
        let keyFrames = [
            KeyFrame(phase: .address, decodedFrameIndex: 0),
            KeyFrame(phase: .takeaway, decodedFrameIndex: 1),
            KeyFrame(phase: .shaftParallel, decodedFrameIndex: 2),
            KeyFrame(phase: .topOfBackswing, decodedFrameIndex: 3),
            KeyFrame(phase: .transition, decodedFrameIndex: 4),
            KeyFrame(phase: .earlyDownswing, decodedFrameIndex: 5),
            KeyFrame(phase: .impact, decodedFrameIndex: 5),
            KeyFrame(phase: .followThrough, decodedFrameIndex: 6)
        ]
        let record = SwingRecord(
            title: "Poor Capture Workflow",
            mediaFilename: "workflow.mov",
            frameRate: 60,
            decodedFrames: makeDecodedFrames(from: frames),
            decodedFrameTimestamps: frames.map(\.timestamp),
            swingFrames: frames,
            keyFrames: keyFrames,
            keyframeValidationStatus: .pending,
            handAnchors: [],
            pathPoints: [],
            analysisResult: AnalysisResult(issues: [], highlights: [], summary: "Synthetic poor framing case.")
        )

        let progress = GarageWorkflow.progress(for: record)

        #expect(progress.stages.first(where: { $0.stage == .validateKeyframes })?.status == .needsAttention)
    }

    @Test func garageEvaluationSnapshotIncludesOrderedPhaseRows() async throws {
        let anchors = makeFullAnchorSet()
        let record = makeWorkflowRecord(
            keyframeValidationStatus: .approved,
            anchors: anchors,
            pathPoints: GarageAnalysisPipeline.generatePathPoints(from: anchors, samplesPerSegment: 4)
        )

        let snapshot = GarageEvaluationHarness.snapshot(for: record)

        #expect(snapshot.phases.count == SwingPhase.allCases.count)
        #expect(snapshot.phases.first?.phase == SwingPhase.address.rawValue)
        #expect(snapshot.phases.last?.phase == SwingPhase.followThrough.rawValue)
        #expect(snapshot.reliabilityScore > 0)
    }

    @Test func garageEvaluationSnapshotMarksWeakestPhasesWhenFramesCollapse() async throws {
        let frames = makePoorlyFramedSwingFrames()
        let keyFrames = [
            KeyFrame(phase: .address, decodedFrameIndex: 0),
            KeyFrame(phase: .takeaway, decodedFrameIndex: 1),
            KeyFrame(phase: .shaftParallel, decodedFrameIndex: 2),
            KeyFrame(phase: .topOfBackswing, decodedFrameIndex: 3),
            KeyFrame(phase: .transition, decodedFrameIndex: 4),
            KeyFrame(phase: .earlyDownswing, decodedFrameIndex: 5),
            KeyFrame(phase: .impact, decodedFrameIndex: 5),
            KeyFrame(phase: .followThrough, decodedFrameIndex: 6)
        ]
        let record = SwingRecord(
            title: "Collapsed Phases",
            frameRate: 60,
            decodedFrames: makeDecodedFrames(from: frames),
            decodedFrameTimestamps: frames.map(\.timestamp),
            swingFrames: frames,
            keyFrames: keyFrames,
            keyframeValidationStatus: .pending,
            handAnchors: [],
            pathPoints: [],
            analysisResult: AnalysisResult(issues: [], highlights: [], summary: "Collapsed phase case.")
        )

        let snapshot = GarageEvaluationHarness.snapshot(for: record)

        #expect(snapshot.weakestPhases.isEmpty == false)
        #expect(snapshot.phases.contains(where: { $0.phase == SwingPhase.impact.rawValue && $0.health == GaragePhaseHealth.weak.rawValue }))
    }

    @Test func garageWorkflowBecomesFullyCompleteWhenAllStagesAreReady() async throws {
        let anchors = makeFullAnchorSet()
        let record = makeWorkflowRecord(
            keyframeValidationStatus: .approved,
            anchors: anchors,
            pathPoints: GarageAnalysisPipeline.generatePathPoints(from: anchors, samplesPerSegment: 4)
        )

        let progress = GarageWorkflow.progress(for: record)

        #expect(progress.completedCount == 4)
        #expect(progress.stages.allSatisfy { $0.status == .complete })
        #expect(progress.nextAction.title == "Workflow Complete")
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
private func makePoorlyFramedSwingFrames() -> [SwingFrame] {
    let wristPairs: [(Double, Double, Double, Double)] = [
        (0.44, 0.78, 0.47, 0.78),
        (0.45, 0.75, 0.48, 0.75),
        (0.47, 0.68, 0.50, 0.68),
        (0.49, 0.06, 0.52, 0.06),
        (0.50, 0.08, 0.53, 0.08),
        (0.49, 0.14, 0.52, 0.14),
        (0.50, 0.05, 0.53, 0.05)
    ]

    return wristPairs.enumerated().map { index, wrists in
        let (leftWristX, leftWristY, rightWristX, rightWristY) = wrists
        return SwingFrame(
            timestamp: Double(index) * 0.1,
            joints: [
                joint(.nose, x: 0.48, y: 0.40),
                joint(.leftShoulder, x: 0.44, y: 0.48),
                joint(.rightShoulder, x: 0.54, y: 0.48),
                joint(.leftHip, x: 0.46, y: 0.70),
                joint(.rightHip, x: 0.54, y: 0.70),
                joint(.leftAnkle, x: 0.46, y: 0.93),
                joint(.rightAnkle, x: 0.54, y: 0.93),
                joint(.leftWrist, x: leftWristX, y: leftWristY),
                joint(.rightWrist, x: rightWristX, y: rightWristY)
            ],
            confidence: 0.52
        )
    }
}

@MainActor
private func makeLateFinishSwingFrames() -> [SwingFrame] {
    let wristPairs: [(Double, Double, Double, Double)] = [
        (0.30, 0.74, 0.34, 0.74),
        (0.32, 0.73, 0.36, 0.73),
        (0.35, 0.68, 0.39, 0.68),
        (0.40, 0.58, 0.44, 0.58),
        (0.45, 0.44, 0.49, 0.44),
        (0.50, 0.30, 0.54, 0.30),
        (0.48, 0.36, 0.52, 0.36),
        (0.42, 0.50, 0.46, 0.50),
        (0.36, 0.66, 0.40, 0.66),
        (0.54, 0.22, 0.58, 0.22)
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
private func makePrerollSwingFrames() -> [SwingFrame] {
    let wristPairs: [(Double, Double, Double, Double)] = [
        (0.30, 0.72, 0.34, 0.72),
        (0.30, 0.72, 0.34, 0.72),
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
        decodedFrames: makeDecodedFrames(from: frames),
        decodedFrameTimestamps: frames.map(\.timestamp),
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
private func makeDecodedFrames(from frames: [SwingFrame]) -> [DecodedFrameRecord] {
    frames.enumerated().map { index, frame in
        DecodedFrameRecord(
            decodedFrameIndex: index,
            presentationTimestamp: frame.timestamp,
            renderAssetKey: nil,
            poseSample: PoseSampleAttachment(
                analysisSampleIndex: index,
                confidence: frame.confidence,
                joints: frame.joints
            ),
            assignedPhase: nil,
            continuity: nil
        )
    }
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
