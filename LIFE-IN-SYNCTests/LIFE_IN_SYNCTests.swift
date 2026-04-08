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
        #expect(keyFrames.map(\.frameIndex) == keyFrames.map(\.frameIndex).sorted())
        #expect(keyFrames[5].frameIndex <= keyFrames[6].frameIndex)
        #expect(keyFrames[6].frameIndex <= keyFrames[7].frameIndex)
    }

    @Test func garageKeyframeDetectionSkipsQuietPrerollAndFindsAddressNearSwingStart() async throws {
        let frames = makePrerollSwingFrames()

        let keyFrames = GarageAnalysisPipeline.detectKeyFrames(from: frames)

        #expect(keyFrames.first?.phase == .address)
        #expect((keyFrames.first?.frameIndex ?? -1) < (keyFrames[1].frameIndex))
    }

    @Test func garageKeyframeDetectionKeepsImpactDistinctFromEarlyDownswing() async throws {
        let frames = makeSyntheticSwingFrames()

        let keyFrames = GarageAnalysisPipeline.detectKeyFrames(from: frames)

        let earlyDownswing = keyFrames.first(where: { $0.phase == .earlyDownswing })?.frameIndex ?? -1
        let impact = keyFrames.first(where: { $0.phase == .impact })?.frameIndex ?? -1
        #expect(impact > earlyDownswing)
    }

    @Test func garageKeyframeDetectionPlacesEarlyBackswingFramesCloserToTakeawayAndShaftParallel() async throws {
        let frames = makeSyntheticSwingFrames()

        let keyFrames = GarageAnalysisPipeline.detectKeyFrames(from: frames)
        let takeaway = try #require(keyFrames.first(where: { $0.phase == .takeaway }))
        let shaftParallel = try #require(keyFrames.first(where: { $0.phase == .shaftParallel }))
        let top = try #require(keyFrames.first(where: { $0.phase == .topOfBackswing }))

        #expect(takeaway.frameIndex <= 2)
        #expect(shaftParallel.frameIndex <= 4)
        #expect(takeaway.frameIndex < shaftParallel.frameIndex)
        #expect(shaftParallel.frameIndex < top.frameIndex)
    }

    @Test func garageKeyframeDetectionKeepsTransitionNearTopReversal() async throws {
        let frames = makeSyntheticSwingFrames()

        let keyFrames = GarageAnalysisPipeline.detectKeyFrames(from: frames)
        let top = try #require(keyFrames.first(where: { $0.phase == .topOfBackswing }))
        let transition = try #require(keyFrames.first(where: { $0.phase == .transition }))

        #expect(transition.frameIndex >= top.frameIndex + 1)
        #expect(transition.frameIndex <= top.frameIndex + 2)
    }

    @Test func garageKeyframeDetectionCarriesCanonicalDecodedFrameIdentity() async throws {
        let frames = makeSyntheticSwingFrames()
        let decodedFrameTimestamps = frames.map(\.timestamp)

        let keyFrames = GarageAnalysisPipeline.detectKeyFrames(from: frames)
        let top = try #require(keyFrames.first(where: { $0.phase == .topOfBackswing }))

        #expect(top.frameIndex == 6)
        #expect(decodedFrameTimestamps[top.frameIndex] == frames[top.frameIndex].timestamp)
    }

    @Test func garageKeyframeDetectionDoesNotUseLateFinishAsTopOfBackswing() async throws {
        let frames = makeLateFinishSwingFrames()

        let keyFrames = GarageAnalysisPipeline.detectKeyFrames(from: frames)
        let top = keyFrames.first(where: { $0.phase == .topOfBackswing })?.frameIndex ?? -1
        let follow = keyFrames.first(where: { $0.phase == .followThrough })?.frameIndex ?? -1

        #expect(top <= 6)
        #expect(follow > top)
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

    @Test func garageReviewVideoResolverFallsBackToExportAssetWhenReviewMasterIsMissing() async throws {
        let exportFilename = "export-fallback.mp4"
        makePersistedGarageExportFixture(named: exportFilename)

        let record = SwingRecord(
            title: "Export Fallback",
            reviewMasterFilename: "missing-review.mov",
            exportAssetFilename: exportFilename,
            swingFrames: makeSyntheticSwingFrames(),
            keyFrames: GarageAnalysisPipeline.detectKeyFrames(from: makeSyntheticSwingFrames())
        )

        let resolvedVideo = try #require(GarageMediaStore.resolvedReviewVideo(for: record))

        #expect(resolvedVideo.origin == .exportStorage)
        #expect(resolvedVideo.url.lastPathComponent == exportFilename)
    }

    @Test func garageReviewVideoResolverUsesBookmarkWhenStoredFilenameFails() async throws {
        let bookmarkURL = FileManager.default.temporaryDirectory.appendingPathComponent("garage-bookmark-\(UUID().uuidString).mov")
        FileManager.default.createFile(atPath: bookmarkURL.path, contents: Data())

        let record = SwingRecord(
            title: "Bookmark Fallback",
            reviewMasterBookmark: GarageMediaStore.bookmarkData(for: bookmarkURL),
            swingFrames: makeSyntheticSwingFrames(),
            keyFrames: GarageAnalysisPipeline.detectKeyFrames(from: makeSyntheticSwingFrames())
        )

        let resolvedVideo = try #require(GarageMediaStore.resolvedReviewVideo(for: record))

        #expect(resolvedVideo.origin == .reviewMasterBookmark)
        #expect(resolvedVideo.url.lastPathComponent == bookmarkURL.lastPathComponent)
    }

    @Test func garageWorkflowTreatsPoseFallbackAsReviewReadyWhenFramesStillExist() async throws {
        let frames = makeSyntheticSwingFrames()
        let keyFrames = GarageAnalysisPipeline.detectKeyFrames(from: frames)
        let anchors = GarageAnalysisPipeline.deriveHandAnchors(from: frames, keyFrames: keyFrames)
        let record = SwingRecord(
            title: "Pose Fallback",
            swingFrames: frames,
            keyFrames: keyFrames,
            keyframeValidationStatus: .approved,
            handAnchors: anchors,
            pathPoints: GarageAnalysisPipeline.generatePathPoints(from: anchors, samplesPerSegment: 4)
        )

        let progress = GarageWorkflow.progress(for: record)

        #expect(GarageMediaStore.reviewFrameSource(for: record) == .poseFallback)
        #expect(progress.stages.first(where: { $0.stage == .importVideo })?.status == .complete)
    }

    @Test func garageManualAnchorMergePreservesManualPointWhileRefreshingAutomaticAnchors() async throws {
        let frames = makeSyntheticSwingFrames()
        let keyFrames = GarageAnalysisPipeline.detectKeyFrames(from: frames)
        let merged = GarageAnalysisPipeline.mergedHandAnchors(
            preserving: [
                HandAnchor(phase: .address, x: 0.11, y: 0.22, source: .manual)
            ],
            from: frames,
            keyFrames: keyFrames
        )

        let addressAnchor = try #require(merged.first(where: { $0.phase == .address }))
        let impactAnchor = try #require(merged.first(where: { $0.phase == .impact }))

        #expect(addressAnchor.x == 0.11)
        #expect(addressAnchor.y == 0.22)
        #expect(addressAnchor.source == .manual)
        #expect(impactAnchor.source == .automatic)
        #expect(merged.count == SwingPhase.allCases.count)
    }

    @Test func garageKeyframeDetectionChoosesStableAddressAfterNoisyPreroll() async throws {
        let frames = makeNoisyPrerollSwingFrames()

        let keyFrames = GarageAnalysisPipeline.detectKeyFrames(from: frames)
        let address = try #require(keyFrames.first(where: { $0.phase == .address }))

        #expect(address.frameIndex >= 2)
        #expect(address.frameIndex < (keyFrames.first(where: { $0.phase == .takeaway })?.frameIndex ?? Int.max))
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
private func makeNoisyPrerollSwingFrames() -> [SwingFrame] {
    let samples: [(Double, Double, Double, Double, Double)] = [
        (0.24, 0.48, 0.28, 0.48, 0.28),
        (0.26, 0.52, 0.30, 0.52, 0.35),
        (0.30, 0.73, 0.34, 0.73, 0.96),
        (0.31, 0.73, 0.35, 0.73, 0.97),
        (0.33, 0.71, 0.37, 0.71, 0.95),
        (0.39, 0.62, 0.43, 0.62, 0.95),
        (0.47, 0.48, 0.51, 0.48, 0.94),
        (0.54, 0.35, 0.58, 0.35, 0.93),
        (0.50, 0.40, 0.54, 0.40, 0.93),
        (0.38, 0.64, 0.42, 0.64, 0.92),
        (0.33, 0.72, 0.37, 0.72, 0.92),
        (0.57, 0.29, 0.61, 0.29, 0.92)
    ]

    return samples.enumerated().map { index, sample in
        let (leftWristX, leftWristY, rightWristX, rightWristY, confidence) = sample
        return SwingFrame(
            timestamp: Double(index) * 0.1,
            joints: [
                joint(.leftShoulder, x: 0.40, y: 0.34),
                joint(.rightShoulder, x: 0.60, y: 0.34),
                joint(.leftHip, x: 0.44, y: 0.60),
                joint(.rightHip, x: 0.58, y: 0.60),
                joint(.leftWrist, x: leftWristX, y: leftWristY, confidence: confidence),
                joint(.rightWrist, x: rightWristX, y: rightWristY, confidence: confidence)
            ],
            confidence: confidence
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

@MainActor
private func makePersistedGarageExportFixture(named filename: String) {
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

    let exportsURL = baseURL
        .appendingPathComponent("GarageSwingVideos", isDirectory: true)
        .appendingPathComponent("Exports", isDirectory: true)
    let fileURL = exportsURL.appendingPathComponent(filename)

    if fileManager.fileExists(atPath: fileURL.path) {
        return
    }

    try? fileManager.createDirectory(at: exportsURL, withIntermediateDirectories: true)
    fileManager.createFile(atPath: fileURL.path, contents: Data())
}
