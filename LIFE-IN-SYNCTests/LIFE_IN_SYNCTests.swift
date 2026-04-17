//
//  LIFE_IN_SYNCTests.swift
//  LIFE-IN-SYNCTests
//
//  Created by Colton Thomas on 3/31/26.
//

import CoreGraphics
import CoreMedia
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

    @Test func swingRecordDefaultsImportStatusToComplete() async throws {
        let record = SwingRecord(title: "Baseline import")

        #expect(record.importStatus == .complete)
        #expect(record.isImportComplete)
    }

    @Test func swingRecordSupportsPendingToCompleteImportTransition() async throws {
        let record = SwingRecord(title: "Pending import", importStatus: .pending)

        #expect(record.importStatus == .pending)
        #expect(record.isImportComplete == false)

        record.importStatus = .complete

        #expect(record.importStatus == .complete)
        #expect(record.isImportComplete)
    }

    @Test func garageRetryClassifierOnlyRetriesCodeNegative54() async throws {
        let retryError = NSError(domain: "com.apple.SwiftData", code: -54)
        let wrappedRetryError = NSError(
            domain: "Garage.Import",
            code: 1001,
            userInfo: [NSUnderlyingErrorKey: retryError]
        )
        let nonRetryError = NSError(domain: "com.apple.SwiftData", code: -1)

        #expect(garageImportRetryErrorCode(from: retryError) == -54)
        #expect(garageImportRetryErrorCode(from: wrappedRetryError) == -54)
        #expect(garageShouldRetryImportAfterFailure(retryError))
        #expect(garageShouldRetryImportAfterFailure(wrappedRetryError))
        #expect(garageShouldRetryImportAfterFailure(nonRetryError) == false)
    }

    @Test func garageProgressUpdatesTrackSampledFrameTotals() async throws {
        let timestamps = GarageAnalysisPipeline.sampledTimestamps(
            duration: CMTime(seconds: 0.12, preferredTimescale: 600),
            frameRate: 30
        )
        let totalFrames = timestamps.count
        let samplingUpdate = GarageAnalysisProgressUpdate(step: .samplingFrames, totalFrames: totalFrames)
        let extractionUpdates = timestamps.indices.map { index in
            GarageAnalysisProgressUpdate(
                step: .detectingBody,
                frameCount: index + 1,
                totalFrames: totalFrames
            )
        }

        #expect(totalFrames > 0)
        #expect(samplingUpdate.totalFrames == totalFrames)
        #expect(samplingUpdate.frameCount == 0)
        #expect(extractionUpdates.map(\.frameCount) == Array(1...totalFrames))
        #expect(extractionUpdates.last?.totalFrames == totalFrames)
    }

    @Test func analysisResultRoundTripsCurrentPerspectivePayload() async throws {
        let encoded = try JSONEncoder().encode(makeGarageAnalysisResult(perspectivePayload: .dtl))
        let decoded = try JSONDecoder().decode(AnalysisResult.self, from: encoded)

        #expect(decoded.scorecard?.timestamps.perspective == .dtl)
        #expect(decoded.normalizedForPersistence.scorecard?.timestamps.perspective == .dtl)
    }

    @Test func analysisResultDecodesLegacyPerspectiveWrapperPayload() async throws {
        let decoded = try JSONDecoder().decode(
            AnalysisResult.self,
            from: makeGarageAnalysisResultJSON(perspectiveJSON: #"{"rawValue":"dtl"}"#)
        )

        #expect(decoded.scorecard?.timestamps.perspective == .dtl)
    }

    @Test func analysisResultFallsBackSafelyForMissingOrInvalidPerspective() async throws {
        let missingPerspective = try JSONDecoder().decode(
            AnalysisResult.self,
            from: makeGarageAnalysisResultJSON(omitPerspective: true)
        )
        let invalidPerspective = try JSONDecoder().decode(
            AnalysisResult.self,
            from: makeGarageAnalysisResultJSON(perspectiveJSON: #""face_on""#)
        )

        #expect(missingPerspective.scorecard?.timestamps.perspective == .dtl)
        #expect(invalidPerspective.scorecard?.timestamps.perspective == .dtl)
    }

    @Test func analysisResultNormalizationReencodesPerspectiveInCurrentForm() async throws {
        let decoded = try JSONDecoder().decode(
            AnalysisResult.self,
            from: makeGarageAnalysisResultJSON(perspectiveJSON: #"{"value":"dtl"}"#)
        )
        let normalized = decoded.normalizedForPersistence
        let reencoded = try JSONEncoder().encode(normalized)
        let reencodedString = String(decoding: reencoded, as: UTF8.self)

        #expect(reencodedString.contains(#""perspective":"dtl""#))
    }

    @Test func analysisResultLossilyDropsMalformedNestedPayloads() async throws {
        let decoded = try JSONDecoder().decode(
            AnalysisResult.self,
            from: makeMalformedGarageAnalysisResultJSON()
        )

        #expect(decoded.issues.isEmpty)
        #expect(decoded.highlights == ["Legacy-safe decode"])
        #expect(decoded.summary == "Synthetic analysis payload.")
        #expect(decoded.scorecard == nil)
        #expect(decoded.syncFlow?.status == .unavailable)
        #expect(decoded.recoveredFromCorruption)
        #expect(decoded.recoveryDiagnostics.isEmpty == false)
    }

    @Test func analysisResultNormalizationClearsRecoveryDiagnostics() async throws {
        let decoded = try JSONDecoder().decode(
            AnalysisResult.self,
            from: makeMalformedGarageAnalysisResultJSON()
        )
        let normalized = decoded.normalizedForPersistence

        #expect(decoded.recoveredFromCorruption)
        #expect(normalized.recoveredFromCorruption == false)
        #expect(normalized.recoveryDiagnostics.isEmpty)
        #expect(normalized.syncFlow?.status == .unavailable)
    }

    @Test func garageResolvedSamplingFrameRateNeverExceedsThirtyFPS() async throws {
        #expect(GarageAnalysisPipeline.resolvedSamplingFrameRate(from: 60) == 30)
        #expect(GarageAnalysisPipeline.resolvedSamplingFrameRate(from: 30) == 30)
        #expect(GarageAnalysisPipeline.resolvedSamplingFrameRate(from: 24) == 24)
    }

    @Test func garageSampledTimestampsCapAtOneHundredTwentyFramesAndPreserveClipCoverage() async throws {
        let timestamps = GarageAnalysisPipeline.sampledTimestamps(
            duration: CMTime(seconds: 10, preferredTimescale: 600),
            frameRate: 30
        )

        #expect(timestamps.count == 120)
        #expect((timestamps.first ?? -1) == 0)
        #expect((timestamps.last ?? 0) >= 9.9)
        #expect((timestamps.last ?? 0) <= 10.0)
        #expect(timestamps.contains(where: { $0 >= 4.9 && $0 <= 5.1 }))
    }

    @Test func analysisResultDropsScorecardWhenTimestampsAreUnreadable() async throws {
        let decoded = try JSONDecoder().decode(
            AnalysisResult.self,
            from: makeGarageAnalysisResultJSON(startJSON: #""broken""#)
        )

        #expect(decoded.scorecard == nil)
        #expect(decoded.recoveredFromCorruption)
        #expect(decoded.recoveryDiagnostics.contains(where: { $0.contains("scorecard") }))
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

    @Test func garageSampledPresentationTimestampsStayOrderedWhenTargetsOversampleSourceFrames() async throws {
        let desired = stride(from: 0.0, through: 0.1333, by: 1.0 / 30.0).map { $0 }
        let presentationTimes = [0.0, 0.0417, 0.0833, 0.1250]

        let sampled = GarageAnalysisPipeline.sampledPresentationTimestamps(
            from: presentationTimes,
            matching: desired
        )

        #expect(sampled == presentationTimes)
    }

    @Test func swingFrameDecodingDefaults3DJointPayloadToEmpty() async throws {
        let json = """
        {
          "timestamp": 0.2,
          "joints": [
            { "name": "leftShoulder", "x": 0.4, "y": 0.3, "confidence": 0.9 }
          ],
          "confidence": 0.91
        }
        """.data(using: .utf8)!

        let frame = try JSONDecoder().decode(SwingFrame.self, from: json)

        #expect(frame.joints3D.isEmpty)
        #expect(frame.joints.count == 1)
    }

    @Test func garageVelocityRibbonPaletteWarmsAndWidensAsSpeedIncreases() async throws {
        let cool = garageVelocityRibbonPalette(normalizedSpeed: 0.1, segment: .backswing)
        let hot = garageVelocityRibbonPalette(normalizedSpeed: 0.95, segment: .downswing)

        #expect(hot.innerWidth > cool.innerWidth)
        #expect(hot.outerWidth > cool.outerWidth)
        #expect(hot.fill.x > cool.fill.x)
        #expect(hot.fill.z < cool.fill.z)
    }

    @Test func garageLoupeCropRectClampsNearImageEdges() async throws {
        let topLeft = garageLoupeCropRect(
            anchorPoint: CGPoint(x: -0.2, y: -0.1),
            imageSize: CGSize(width: 320, height: 180),
            sampleSize: 120
        )
        let bottomRight = garageLoupeCropRect(
            anchorPoint: CGPoint(x: 1.4, y: 1.2),
            imageSize: CGSize(width: 320, height: 180),
            sampleSize: 120
        )

        #expect(topLeft.minX == 0)
        #expect(topLeft.minY == 0)
        #expect(bottomRight.maxX == 320)
        #expect(bottomRight.maxY == 180)
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

    @Test func garageKeyframeDetectionUsesEarliestValidDownswingThresholdCrossing() async throws {
        let frames = makeEarlyThresholdCrossingSwingFrames()

        let keyFrames = GarageAnalysisPipeline.detectKeyFrames(from: frames)
        let earlyDownswing = try #require(keyFrames.first(where: { $0.phase == .earlyDownswing }))
        let impact = try #require(keyFrames.first(where: { $0.phase == .impact }))
        let transition = try #require(keyFrames.first(where: { $0.phase == .transition }))

        #expect(transition.frameIndex == 5)
        #expect(earlyDownswing.frameIndex == 7)
        #expect(earlyDownswing.frameIndex > transition.frameIndex)
        #expect(impact.frameIndex > earlyDownswing.frameIndex)
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

        #expect(top.frameIndex == 5)
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

    @Test func garageKeyframeDetectionFindsTakeawayDuringMostlyVerticalEarlyBackswing() async throws {
        let frames = makeVerticalTakeawaySwingFrames()

        let keyFrames = GarageAnalysisPipeline.detectKeyFrames(from: frames)
        let address = try #require(keyFrames.first(where: { $0.phase == .address }))
        let takeaway = try #require(keyFrames.first(where: { $0.phase == .takeaway }))
        let top = try #require(keyFrames.first(where: { $0.phase == .topOfBackswing }))

        #expect(takeaway.frameIndex > address.frameIndex)
        #expect(takeaway.frameIndex <= 2)
        #expect(takeaway.frameIndex < top.frameIndex)
    }

    @Test func garageKeyframeDetectionDoesNotPromoteLateFinishPauseToTop() async throws {
        let frames = makeLatePauseSwingFrames()

        let keyFrames = GarageAnalysisPipeline.detectKeyFrames(from: frames)
        let top = try #require(keyFrames.first(where: { $0.phase == .topOfBackswing }))
        let transition = try #require(keyFrames.first(where: { $0.phase == .transition }))
        let follow = try #require(keyFrames.first(where: { $0.phase == .followThrough }))

        #expect(top.frameIndex <= 4)
        #expect(top.frameIndex < transition.frameIndex)
        #expect(follow.frameIndex > top.frameIndex)
    }

    @Test func garageKeyframeDetectionStaysOrderedForMirroredSwingPath() async throws {
        let mirroredFrames = makeMirroredSwingFrames(from: makeSyntheticSwingFrames())

        let keyFrames = GarageAnalysisPipeline.detectKeyFrames(from: mirroredFrames)
        let takeaway = try #require(keyFrames.first(where: { $0.phase == .takeaway }))
        let shaftParallel = try #require(keyFrames.first(where: { $0.phase == .shaftParallel }))
        let top = try #require(keyFrames.first(where: { $0.phase == .topOfBackswing }))
        let transition = try #require(keyFrames.first(where: { $0.phase == .transition }))

        #expect(takeaway.frameIndex < shaftParallel.frameIndex)
        #expect(shaftParallel.frameIndex < top.frameIndex)
        #expect(top.frameIndex < transition.frameIndex)
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
private func makeVerticalTakeawaySwingFrames() -> [SwingFrame] {
    let wristPairs: [(Double, Double, Double, Double)] = [
        (0.34, 0.72, 0.38, 0.72),
        (0.35, 0.66, 0.39, 0.66),
        (0.36, 0.57, 0.40, 0.57),
        (0.37, 0.47, 0.41, 0.47),
        (0.38, 0.35, 0.42, 0.35),
        (0.37, 0.40, 0.41, 0.40),
        (0.35, 0.50, 0.39, 0.50),
        (0.33, 0.67, 0.37, 0.67),
        (0.44, 0.32, 0.48, 0.32)
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
            confidence: 0.92
        )
    }
}

@MainActor
private func makeLatePauseSwingFrames() -> [SwingFrame] {
    let wristPairs: [(Double, Double, Double, Double)] = [
        (0.30, 0.73, 0.34, 0.73),
        (0.33, 0.68, 0.37, 0.68),
        (0.39, 0.58, 0.43, 0.58),
        (0.45, 0.45, 0.49, 0.45),
        (0.51, 0.32, 0.55, 0.32),
        (0.49, 0.38, 0.53, 0.38),
        (0.42, 0.52, 0.46, 0.52),
        (0.36, 0.68, 0.40, 0.68),
        (0.54, 0.27, 0.58, 0.27),
        (0.55, 0.26, 0.59, 0.26),
        (0.55, 0.26, 0.59, 0.26)
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
            confidence: 0.91
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
private func makeEarlyThresholdCrossingSwingFrames() -> [SwingFrame] {
    let wristPairs: [(Double, Double, Double, Double)] = [
        (0.30, 0.72, 0.34, 0.72),
        (0.33, 0.68, 0.37, 0.68),
        (0.38, 0.60, 0.42, 0.60),
        (0.45, 0.49, 0.49, 0.49),
        (0.52, 0.36, 0.56, 0.36), // top
        (0.50, 0.40, 0.54, 0.40), // transition
        (0.49, 0.44, 0.53, 0.44), // downward, below threshold
        (0.46, 0.50, 0.50, 0.50), // earliest threshold crossing
        (0.42, 0.58, 0.46, 0.58), // later crossing
        (0.38, 0.66, 0.42, 0.66), // impact neighborhood
        (0.56, 0.28, 0.60, 0.28)  // follow through
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
private func makeMirroredSwingFrames(from frames: [SwingFrame]) -> [SwingFrame] {
    frames.map { frame in
        SwingFrame(
            timestamp: frame.timestamp,
            joints: frame.joints.map { joint in
                SwingJoint(
                    name: joint.name,
                    x: 1 - joint.x,
                    y: joint.y,
                    confidence: joint.confidence
                )
            },
            confidence: frame.confidence
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
private func makeGarageAnalysisResult(perspectivePayload: GarageCameraPerspective) -> AnalysisResult {
    AnalysisResult(
        issues: [],
        highlights: ["Legacy-safe decode"],
        summary: "Synthetic analysis payload.",
        scorecard: GarageSwingScorecard(
            timestamps: GarageSwingTimestamps(
                perspective: perspectivePayload,
                start: 0,
                top: 0.5,
                impact: 1.0
            ),
            metrics: GarageSwingMetrics(
                tempo: GarageTempoMetric(ratio: 3.0),
                spine: GarageSpineAngleMetric(deltaDegrees: 2.0),
                pelvicDepth: GaragePelvicDepthMetric(driftInches: 1.1),
                kneeFlex: GarageKneeFlexMetric(leftDeltaDegrees: 5.0, rightDeltaDegrees: 6.0),
                headStability: GarageHeadStabilityMetric(swayInches: 1.0, dipInches: 0.5)
            ),
            domainScores: [
                GarageSwingDomainScore(
                    id: "tempo",
                    title: "Tempo Ratio",
                    score: 90,
                    grade: .good,
                    displayValue: "3.0x"
                )
            ],
            totalScore: 88
        ),
        syncFlow: GarageSyncFlowReport(
            status: .ready,
            headline: "Ready",
            primaryIssue: nil,
            markers: [],
            consequence: nil,
            summary: "Synthetic sync flow."
        )
    )
}

@MainActor
private func makeGarageAnalysisResultJSON(
    perspectiveJSON: String = #""dtl""#,
    omitPerspective: Bool = false,
    startJSON: String = "0.0",
    topJSON: String = "0.5",
    impactJSON: String = "1.0"
) -> Data {
    let perspectiveField = omitPerspective ? "" : #""perspective":\#(perspectiveJSON),"#
    let json = """
    {
      "issues": [],
      "highlights": ["Legacy-safe decode"],
      "summary": "Synthetic analysis payload.",
      "scorecard": {
        "timestamps": {
          \(perspectiveField)
          "start": \(startJSON),
          "top": \(topJSON),
          "impact": \(impactJSON)
        },
        "metrics": {
          "tempo": { "ratio": 3.0 },
          "spine": { "deltaDegrees": 2.0 },
          "pelvicDepth": { "driftInches": 1.1 },
          "kneeFlex": { "leftDeltaDegrees": 5.0, "rightDeltaDegrees": 6.0 },
          "headStability": { "swayInches": 1.0, "dipInches": 0.5 }
        },
        "domainScores": [
          {
            "id": "tempo",
            "title": "Tempo Ratio",
            "score": 90,
            "grade": "good",
            "displayValue": "3.0x"
          }
        ],
        "totalScore": 88
      },
      "syncFlow": {
        "status": "ready",
        "headline": "Ready",
        "primaryIssue": null,
        "markers": [],
        "consequence": null,
        "summary": "Synthetic sync flow."
      }
    }
    """

    return Data(json.utf8)
}

@MainActor
private func makeMalformedGarageAnalysisResultJSON() -> Data {
    let json = """
    {
      "issues": "broken",
      "highlights": ["Legacy-safe decode"],
      "summary": "Synthetic analysis payload.",
      "scorecard": {
        "timestamps": {
          "perspective": "dtl",
          "start": 0.0,
          "top": 0.5,
          "impact": 1.0
        },
        "metrics": "broken",
        "domainScores": [
          {
            "id": "tempo",
            "title": "Tempo Ratio",
            "score": 90,
            "grade": "mystery",
            "displayValue": "3.0x"
          }
        ],
        "totalScore": 88
      },
      "syncFlow": {
        "status": "mystery",
        "headline": "Ready",
        "primaryIssue": null,
        "markers": [],
        "consequence": null,
        "summary": "Synthetic sync flow."
      }
    }
    """

    return Data(json.utf8)
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
