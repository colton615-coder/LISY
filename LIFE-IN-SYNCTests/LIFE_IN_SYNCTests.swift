//
//  LIFE_IN_SYNCTests.swift
//  LIFE-IN-SYNCTests
//
//  Created by Colton Thomas on 3/31/26.
//

import AVFoundation
import CoreGraphics
import CoreMedia
import CoreVideo
import Foundation
import SwiftData
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

    @Test func garageCanonicalDrillBuildsDefaultPrescriptionWithoutMutatingCatalogTruth() async throws {
        let drill = try #require(DrillVault.drill(for: "r13"))
        let practiceDrill = drill.makeGeneratedPracticeTemplateDrill(seedKey: "test:r13")
        let prescription = GarageDrillCatalog.defaultPrescription(for: practiceDrill)

        #expect(prescription.selectedClub == drill.clubRange.displayName)
        #expect(prescription.mode == .goal)
        #expect(prescription.targetCount == 3)
        #expect(prescription.goalText.contains("3 wedge carry numbers"))
    }

    @Test func garageCustomDrillFallsBackToTransientPrescriptionLayer() async throws {
        let customDrill = PracticeTemplateDrill(
            title: "Custom Contact Builder",
            focusArea: "Contact",
            targetClub: "7 Iron",
            defaultRepCount: 12
        )
        let prescription = GarageDrillCatalog.defaultPrescription(for: customDrill)

        #expect(prescription.selectedClub == "7 Iron")
        #expect(prescription.mode == .reps)
        #expect(prescription.targetCount == 12)
        #expect(prescription.goalText.contains("12"))
    }

    @Test func garageDirectorySummaryStaysCompactAndAvoidsLegacySessionCopy() async throws {
        let drill = try #require(DrillVault.drill(for: "n1"))
        let practiceDrill = drill.makeGeneratedPracticeTemplateDrill(seedKey: "test:n1")
        let summary = practiceDrill.metadataSummary.lowercased()

        #expect(summary.contains("min") == false)
        #expect(summary.contains("pass") == false)
        #expect(summary.contains("towel") == false)
    }

    @Test func garageFocusRoomContentUsesPrescriptionGoalAndCompactExecutionFields() async throws {
        let drill = try #require(DrillVault.drill(for: "r15"))
        let practiceDrill = drill.makeGeneratedPracticeTemplateDrill(seedKey: "test:r15")
        let base = GarageDrillCatalog.defaultPrescription(for: practiceDrill)
        let prescription = GarageDrillPrescription(
            drillID: practiceDrill.id,
            selectedClub: "Driver",
            mode: .challenge,
            durationSeconds: nil,
            targetCount: 4,
            goalText: "Own 4 fairway starts.",
            intensity: .high,
            activeCue: "Hold the finish.",
            activeSetupReminder: "Pick one fairway gate.",
            scoringBehavior: .challengeCompletion,
            progressionNotes: "Reset if the finish gets loose.",
            sessionOrder: 0
        )
        let detail = GarageDrillFocusDetails.detail(for: practiceDrill)
        let content = GarageDrillFocusContentAdapter.content(
            for: practiceDrill,
            detail: detail,
            prescription: prescription
        )

        #expect(content.targetMetric == "Own 4 fairway starts.")
        #expect(content.setupLine == "Pick one fairway gate.")
        #expect(content.executionCue == "Hold the finish.")
        #expect(content.finishRule.lowercased().contains("pass") == false)
        #expect(content.goal.goalText == "Reach 4 goal reps in a row.")
        _ = base
    }

    @Test func garageGeneratedPlanKeepsPrescriptionSidecarSeparateFromDrillDefinitions() async throws {
        let plan = GarageLocalCoachPlanner.generatePlan(
            for: .range,
            recentRecords: [],
            desiredDurationMinutes: 24,
            desiredDrillCount: 3
        )
        let session = plan.makeActivePracticeSession()

        #expect(plan.drills.isEmpty == false)
        #expect(plan.prescriptionsByDrillID.count == plan.drills.count)
        #expect(session.drills.count == plan.drills.count)
        #expect(session.drills.allSatisfy { session.prescriptionsByDrillID[$0.id] != nil })
        #expect(plan.drills.map(\.title) == session.drills.map(\.title))
    }

    @Test func garageCourseMappingReusesTheActiveSessionLedger() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let existingSession = GarageRoundSession(
            sessionTitle: "North Ridge Links Round",
            courseName: "North Ridge Links"
        )

        context.insert(existingSession)
        try context.save()

        let resolvedSession = try GarageCourseMappingPersistence.resolveActiveSession(
            for: makeCourseMetadata(),
            in: context
        )

        #expect(resolvedSession.id == existingSession.id)
    }

    @Test func garageCourseMappingRejectsZeroDimensionHoleImports() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let session = GarageRoundSession(
            sessionTitle: "North Ridge Links Round",
            courseName: "North Ridge Links"
        )

        context.insert(session)
        try context.save()

        do {
            _ = try GarageCourseMappingPersistence.resolveHole(
                for: makeCourseMetadata(
                    assetDescriptor: GarageCourseAssetDescriptor(
                        sourceType: .assistedWebImport,
                        sourceReference: "https://example.com/course/hole-14",
                        localAssetPath: nil,
                        imagePixelWidth: 0,
                        imagePixelHeight: 1668
                    )
                ),
                session: session,
                in: context
            )
            Issue.record("Expected zero-dimension hole imports to be rejected.")
        } catch let error as GarageCourseMappingPersistenceError {
            #expect(error == .invalidImageDimensions(width: 0, height: 1668))
        }
    }

    @Test func garageCourseMappingRejectsOutOfBoundsCoordinates() async throws {
        let anchor = GarageMapAnchor(
            kind: .tee,
            normalizedX: 1.2,
            normalizedY: 0.5
        )
        let placement = GarageShotPlacement(
            normalizedX: 0.5,
            normalizedY: -0.1
        )

        do {
            try anchor.validate(fieldName: "Tee anchor")
            Issue.record("Expected the tee anchor validation to fail.")
        } catch let error as GarageCourseMappingPersistenceError {
            #expect(error == .coordinateOutOfBounds(field: "Tee anchor", x: 1.2, y: 0.5))
        }

        do {
            try placement.validate(fieldName: "Shot placement")
            Issue.record("Expected the shot placement validation to fail.")
        } catch let error as GarageCourseMappingPersistenceError {
            #expect(error == .coordinateOutOfBounds(field: "Shot placement", x: 0.5, y: -0.1))
        }
    }

    @Test func garageCourseMappingReindexesShotTimelineIntoAContiguousSequence() async throws {
        let session = GarageRoundSession(
            sessionTitle: "North Ridge Links Round",
            courseName: "North Ridge Links"
        )
        let hole = GarageHoleMap(
            holeNumber: 14,
            holeName: "Cliffside Splitter",
            par: 4,
            yardageLabel: "434",
            sourceType: .assistedWebImport,
            sourceReference: "https://example.com/course/hole-14",
            localAssetPath: nil,
            imagePixelWidth: 1668,
            imagePixelHeight: 2388,
            teeAnchor: GarageMapAnchor(kind: .tee, normalizedX: 0.5, normalizedY: 0.88),
            fairwayCheckpointAnchor: GarageMapAnchor(kind: .fairwayCheckpoint, normalizedX: 0.5, normalizedY: 0.48),
            greenCenterAnchor: GarageMapAnchor(kind: .greenCenter, normalizedX: 0.52, normalizedY: 0.14),
            session: session
        )
        let laterShot = GarageTacticalShot(
            sequenceIndex: 5,
            holeNumber: hole.holeNumber,
            placement: GarageShotPlacement(normalizedX: 0.5, normalizedY: 0.66),
            club: .driver,
            shotType: .teeShot,
            intendedTarget: "Center Line",
            lieBeforeShot: .tee,
            actualResult: .onTarget,
            session: session,
            hole: hole
        )
        let earlierShot = GarageTacticalShot(
            sequenceIndex: 2,
            holeNumber: hole.holeNumber,
            placement: GarageShotPlacement(normalizedX: 0.54, normalizedY: 0.38),
            club: .sevenIron,
            shotType: .approach,
            intendedTarget: "Right Window",
            lieBeforeShot: .fairway,
            actualResult: .rightMiss,
            session: session,
            hole: hole
        )

        session.holes = [hole]
        session.shots = [laterShot, earlierShot]
        hole.shots = [laterShot, earlierShot]

        GarageCourseMappingPersistence.reindexShots(in: session)

        #expect(session.shots.map(\.sequenceIndex).sorted() == [1, 2])
        #expect(laterShot.sequenceIndex == 2)
        #expect(earlierShot.sequenceIndex == 1)
    }

    @Test func garageSpatialHelpersRoundTripCoordinatesInsideAspectFitRect() async throws {
        let container = CGRect(x: 0, y: 0, width: 390, height: 844)
        let imageRect = garageAspectFitRect(
            contentSize: CGSize(width: 1170, height: 2532),
            in: container
        )
        let mappedPoint = garageMappedPoint(x: 0.25, y: 0.8, in: imageRect)
        let normalizedPoint = try #require(garageNormalizedPoint(from: mappedPoint, in: imageRect))

        #expect(abs(normalizedPoint.x - 0.25) < 0.0001)
        #expect(abs(normalizedPoint.y - 0.8) < 0.0001)
    }

    @Test func garageSpatialHelpersRejectLocationsOutsideTheImageRect() async throws {
        let imageRect = CGRect(x: 32, y: 64, width: 260, height: 520)

        #expect(garageNormalizedPoint(from: CGPoint(x: imageRect.minX - 1, y: imageRect.midY), in: imageRect) == nil)
        #expect(garageNormalizedPoint(from: CGPoint(x: imageRect.midX, y: imageRect.maxY + 12), in: imageRect) == nil)
    }

    @Test func garageCourseMappingSavesCalibrationAnchorsThroughThePersistenceSeam() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let session = GarageRoundSession(
            sessionTitle: "North Ridge Links Round",
            courseName: "North Ridge Links"
        )
        let hole = GarageHoleMap(
            holeNumber: 14,
            holeName: "Cliffside Splitter",
            par: 4,
            yardageLabel: "434",
            sourceType: .assistedWebImport,
            sourceReference: "https://example.com/course/hole-14",
            localAssetPath: nil,
            imagePixelWidth: 1668,
            imagePixelHeight: 2388,
            session: session
        )

        context.insert(session)
        context.insert(hole)
        session.holes = [hole]
        try context.save()

        let updatedHole = try GarageCourseMappingPersistence.saveCalibrationAnchors(
            teeAnchor: GarageMapAnchor(kind: .tee, normalizedX: 0.5, normalizedY: 0.88),
            fairwayCheckpointAnchor: GarageMapAnchor(kind: .fairwayCheckpoint, normalizedX: 0.48, normalizedY: 0.44),
            greenCenterAnchor: GarageMapAnchor(kind: .greenCenter, normalizedX: 0.52, normalizedY: 0.14),
            for: hole,
            in: context
        )

        #expect(updatedHole.isCalibrated)
        #expect(updatedHole.teeAnchor?.normalizedY == 0.88)
        #expect(updatedHole.fairwayCheckpointAnchor?.normalizedX == 0.48)
        #expect(updatedHole.greenCenterAnchor?.normalizedY == 0.14)
    }

    @Test func garageCourseMappingUpsertsShotsWithSlimDockDefaults() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let session = GarageRoundSession(
            sessionTitle: "North Ridge Links Round",
            courseName: "North Ridge Links"
        )
        let hole = GarageHoleMap(
            holeNumber: 14,
            holeName: "Cliffside Splitter",
            par: 4,
            yardageLabel: "434",
            sourceType: .assistedWebImport,
            sourceReference: "https://example.com/course/hole-14",
            localAssetPath: nil,
            imagePixelWidth: 1668,
            imagePixelHeight: 2388,
            teeAnchor: GarageMapAnchor(kind: .tee, normalizedX: 0.5, normalizedY: 0.88),
            fairwayCheckpointAnchor: GarageMapAnchor(kind: .fairwayCheckpoint, normalizedX: 0.5, normalizedY: 0.48),
            greenCenterAnchor: GarageMapAnchor(kind: .greenCenter, normalizedX: 0.52, normalizedY: 0.14),
            session: session
        )

        context.insert(session)
        context.insert(hole)
        session.holes = [hole]
        try context.save()

        let createdShot = try GarageCourseMappingPersistence.upsertShot(
            editingShotID: nil,
            draft: GarageCourseShotSaveDraft(
                placement: GarageShotPlacement(normalizedX: 0.51, normalizedY: 0.58),
                club: .sandWedge,
                lieBeforeShot: .bunker,
                actualResult: .onTarget
            ),
            session: session,
            hole: hole,
            in: context
        )

        #expect(createdShot.shotType == .recovery)
        #expect(createdShot.intendedTarget == "Center Line")
        #expect(createdShot.flightShape == .straight)
        #expect(createdShot.strikeQuality == .pure)
        #expect(session.totalShots == 1)
        #expect(hole.totalShots == 1)

        let updatedShot = try GarageCourseMappingPersistence.upsertShot(
            editingShotID: createdShot.id,
            draft: GarageCourseShotSaveDraft(
                placement: GarageShotPlacement(normalizedX: 0.52, normalizedY: 0.16),
                club: .putter,
                lieBeforeShot: .green,
                actualResult: .holed
            ),
            session: session,
            hole: hole,
            in: context
        )

        #expect(updatedShot.id == createdShot.id)
        #expect(updatedShot.shotType == .putt)
        #expect(updatedShot.club == .putter)
        #expect(updatedShot.actualResult == .holed)
        #expect(updatedShot.sequenceIndex == 1)
    }

    @Test func garageCourseMapOverlayClampsDraftShotPlacementIntoVisibleBounds() async throws {
        let overlayModel = GarageCourseMapOverlayModel()
        let rect = CGRect(x: 20, y: 40, width: 200, height: 300)

        overlayModel.beginShotDrag(
            initialPlacement: GarageShotPlacement(normalizedX: 0.5, normalizedY: 0.5),
            shotID: nil
        )
        let updatedPlacement = try #require(
            overlayModel.updateShotDrag(
                location: CGPoint(x: rect.maxX + 120, y: rect.minY - 80),
                in: rect
            )
        )
        let finalizedPlacement = try #require(overlayModel.endShotDrag())

        #expect(updatedPlacement.normalizedX == 1)
        #expect(updatedPlacement.normalizedY == 0)
        #expect(finalizedPlacement == updatedPlacement)
    }

    @Test func garageCourseMapOverlayBuildsPlacedCalibrationDescriptorsInCanvasSpace() async throws {
        let overlayModel = GarageCourseMapOverlayModel()
        let rect = CGRect(x: 0, y: 0, width: 300, height: 450)
        let teeAnchor = GarageMapAnchor(kind: .tee, normalizedX: 0.25, normalizedY: 0.8)
        let greenAnchor = GarageMapAnchor(kind: .greenCenter, normalizedX: 0.55, normalizedY: 0.18)

        let descriptors = overlayModel.calibrationAnchorDescriptors(
            teeAnchor: teeAnchor,
            fairwayCheckpointAnchor: nil,
            greenCenterAnchor: greenAnchor,
            activeKind: .fairwayCheckpoint,
            in: rect
        )

        let teeDescriptor = try #require(descriptors.first(where: { $0.kind == .tee }))
        let checkpointDescriptor = try #require(descriptors.first(where: { $0.kind == .fairwayCheckpoint }))
        let greenDescriptor = try #require(descriptors.first(where: { $0.kind == .greenCenter }))

        #expect(teeDescriptor.isPlaced)
        #expect(teeDescriptor.point == CGPoint(x: 75, y: 360))
        #expect(checkpointDescriptor.isPlaced == false)
        #expect(checkpointDescriptor.isActive)
        #expect(greenDescriptor.point == CGPoint(x: 165, y: 81))
    }

    @Test func garageCourseMapOverlayExposesShotDragStateAndPrecisionReadout() async throws {
        let overlayModel = GarageCourseMapOverlayModel()
        let shotID = UUID()

        overlayModel.beginShotDrag(
            initialPlacement: GarageShotPlacement(normalizedX: 0.33, normalizedY: 0.61),
            shotID: shotID
        )

        let readout = try #require(overlayModel.activeShotReadout)

        #expect(overlayModel.isDraggingShot)
        #expect(overlayModel.isDragging(shotID: shotID))
        #expect(readout.normalizedX == 0.33)
        #expect(readout.normalizedY == 0.61)
        #expect(readout.formattedX == "0.330")
        #expect(readout.formattedY == "0.610")

        _ = overlayModel.endShotDrag()

        #expect(overlayModel.isDraggingShot == false)
        #expect(overlayModel.isDragging(shotID: shotID) == false)
    }

    @Test func garageCourseMapOverlayExposesAnchorDragStateAndPrecisionReadout() async throws {
        let overlayModel = GarageCourseMapOverlayModel()
        let anchor = GarageMapAnchor(kind: .greenCenter, normalizedX: 0.74, normalizedY: 0.16)

        overlayModel.beginAnchorDrag(anchor)

        let readout = try #require(overlayModel.activeAnchorReadout)

        #expect(overlayModel.isDraggingAnchor)
        #expect(overlayModel.isDragging(kind: .greenCenter))
        #expect(readout.normalizedX == 0.74)
        #expect(readout.normalizedY == 0.16)
        #expect(readout.formattedX == "0.740")
        #expect(readout.formattedY == "0.160")

        _ = overlayModel.endAnchorDrag()

        #expect(overlayModel.isDraggingAnchor == false)
        #expect(overlayModel.isDragging(kind: .greenCenter) == false)
    }

    @Test func garageTacticalShotDefaultsTrajectoryToStraightAndPure() async throws {
        let shot = GarageTacticalShot(
            sequenceIndex: 1,
            holeNumber: 14,
            placement: GarageShotPlacement(normalizedX: 0.5, normalizedY: 0.6),
            club: .driver,
            shotType: .teeShot,
            intendedTarget: "Center Line",
            lieBeforeShot: .tee,
            actualResult: .onTarget
        )

        #expect(shot.flightShape == .straight)
        #expect(shot.strikeQuality == .pure)
    }

    @Test func garageTacticalShotStoresCustomTrajectoryClassification() async throws {
        let shot = GarageTacticalShot(
            sequenceIndex: 2,
            holeNumber: 14,
            placement: GarageShotPlacement(normalizedX: 0.42, normalizedY: 0.3),
            club: .sevenIron,
            shotType: .approach,
            intendedTarget: "Right Window",
            lieBeforeShot: .fairway,
            actualResult: .rightMiss,
            flightShape: .fade,
            strikeQuality: .thin
        )

        #expect(shot.flightShape == .fade)
        #expect(shot.strikeQuality == .thin)
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

    @Test func swingRecordFailedImportsRemainAnalyzerVisibleAndRecoverable() async throws {
        let record = SwingRecord(
            title: "Failed import",
            importStatus: .failed,
            reviewMasterFilename: "failed-import.mov"
        )
        record.clearDerivedPayload(repairReason: .importFailed)

        #expect(record.isImportComplete == false)
        #expect(record.isReviewableRecord == false)
        #expect(record.isRecoverableFailedImport)
        #expect(record.isAnalyzerVisible)
        #expect(record.reviewAvailability == .needsReanalysis)
    }

    @Test func swingRecordReconcilesStrandedPendingImportIntoRecoverableFailure() async throws {
        let record = SwingRecord(
            title: "Stranded import",
            importStatus: .pending,
            reviewMasterFilename: "stranded.mov"
        )
        record.frameRate = 30
        record.analysisResult = makeGarageAnalysisResult(perspectivePayload: .dtl)

        let didReconcile = record.reconcileStrandedImportIfNeeded(isActiveImportRecord: false)

        #expect(didReconcile)
        #expect(record.importStatus == .failed)
        #expect(record.repairReason == .importFailed)
        #expect(record.frameRate == 0)
        #expect(record.analysisResult == nil)
        #expect(record.isRecoverableFailedImport)
    }

    @Test func swingRecordLeavesActiveOrCompleteImportsUntouchedDuringReconciliation() async throws {
        let activeRecord = SwingRecord(title: "Active import", importStatus: .retrying, reviewMasterFilename: "active.mov")
        let completeRecord = SwingRecord(title: "Complete import", importStatus: .complete, reviewMasterFilename: "complete.mov")

        #expect(activeRecord.reconcileStrandedImportIfNeeded(isActiveImportRecord: true) == false)
        #expect(activeRecord.importStatus == .retrying)
        #expect(completeRecord.reconcileStrandedImportIfNeeded(isActiveImportRecord: false) == false)
        #expect(completeRecord.importStatus == .complete)
    }

    @Test func garageRetryClassifierWhitelistsTransientLocalPersistenceFailures() async throws {
        let retryError = NSError(domain: "com.apple.SwiftData", code: -54)
        let wrappedRetryError = NSError(
            domain: "Garage.Import",
            code: 1001,
            userInfo: [NSUnderlyingErrorKey: retryError]
        )
        let connectionInterruptedError = NSError(domain: NSCocoaErrorDomain, code: 4097)
        let sqliteLockedError = NSError(domain: "NSSQLiteErrorDomain", code: 5)
        let nonRetryError = NSError(domain: "com.apple.SwiftData", code: -1)
        let analysisError = NSError(domain: "Garage.Analysis", code: 12)

        #expect(garageImportRetryErrorCode(from: retryError) == -54)
        #expect(garageImportRetryErrorCode(from: wrappedRetryError) == -54)
        #expect(garageImportRetryErrorCode(from: connectionInterruptedError) == 4097)
        #expect(garageImportRetryErrorCode(from: sqliteLockedError) == 5)
        #expect(garageShouldRetryImportAfterFailure(retryError))
        #expect(garageShouldRetryImportAfterFailure(wrappedRetryError))
        #expect(garageShouldRetryImportAfterFailure(connectionInterruptedError))
        #expect(garageShouldRetryImportAfterFailure(sqliteLockedError))
        #expect(garageShouldRetryImportAfterFailure(nonRetryError) == false)
        #expect(garageShouldRetryImportAfterFailure(analysisError) == false)
    }

    @Test func garageRetryHelperRetriesExactlyOnceForRetryableFailure() async throws {
        let retryError = NSError(domain: "com.apple.SwiftData", code: -54)
        var attempts = 0
        var sleptNanoseconds: [UInt64] = []

        let result: Int = try await garagePerformRetryableOperation(
            delayNanoseconds: 123,
            sleep: { value in
                sleptNanoseconds.append(value)
            }
        ) {
            attempts += 1
            if attempts == 1 {
                throw retryError
            }
            return 42
        }

        #expect(result == 42)
        #expect(attempts == 2)
        #expect(sleptNanoseconds == [123])
    }

    @Test func garageRetryHelperDoesNotRetryNonRetryableFailure() async throws {
        let nonRetryError = NSError(domain: "Garage.Analysis", code: 12)
        var attempts = 0
        var sleptNanoseconds: [UInt64] = []

        do {
            let _: Int = try await garagePerformRetryableOperation(
                delayNanoseconds: 123,
                sleep: { value in
                    sleptNanoseconds.append(value)
                }
            ) {
                attempts += 1
                throw nonRetryError
            }
            Issue.record("Expected non-retryable error to escape immediately.")
        } catch {
            #expect((error as NSError).domain == nonRetryError.domain)
            #expect((error as NSError).code == nonRetryError.code)
        }

        #expect(attempts == 1)
        #expect(sleptNanoseconds.isEmpty)
    }

    @Test func garageRetryHelperStopsAfterSecondRetryableFailure() async throws {
        let retryError = NSError(domain: "com.apple.SwiftData", code: -54)
        var attempts = 0

        do {
            let _: Int = try await garagePerformRetryableOperation(
                delayNanoseconds: 123,
                sleep: { _ in }
            ) {
                attempts += 1
                throw retryError
            }
            Issue.record("Expected second retryable failure to surface.")
        } catch {
            #expect(garageImportRetryErrorCode(from: error) == -54)
        }

        #expect(attempts == 2)
    }

    @Test func swingRecordPendingImportFactoryStagesLocalReviewMasterAndExportHydration() async throws {
        let reviewMasterURL = URL(fileURLWithPath: "/tmp/review-master.mov")
        let reviewBookmark = Data([1, 2, 3])
        let exportBookmark = Data([4, 5, 6])
        let record = SwingRecord.pendingImportRecord(
            title: "Pending import",
            clubType: "Driver",
            isLeftHanded: true,
            cameraAngle: "Face On",
            reviewMasterURL: reviewMasterURL,
            reviewMasterBookmark: reviewBookmark
        )

        #expect(record.importStatus == .pending)
        #expect(record.reviewMasterFilename == "review-master.mov")
        #expect(record.mediaFilename == "review-master.mov")
        #expect(record.reviewMasterBookmark == reviewBookmark)
        #expect(record.isImportComplete == false)

        record.hydrateExportDerivative(
            filename: "review-master-export.mp4",
            bookmark: exportBookmark
        )

        #expect(record.exportAssetFilename == "review-master-export.mp4")
        #expect(record.exportAssetBookmark == exportBookmark)
        #expect(record.reviewMasterFilename == "review-master.mov")
        #expect(record.importStatus == .pending)
    }

    @Test func swingRecordRepairFailureHelperPreservesRecoverableFailedImports() async throws {
        let record = SwingRecord(
            title: "Repair target",
            importStatus: .complete,
            reviewMasterFilename: "repair.mov",
            frameRate: 60,
            swingFrames: makeSyntheticSwingFrames(),
            keyFrames: GarageAnalysisPipeline.detectKeyFrames(from: makeSyntheticSwingFrames()),
            analysisResult: makeGarageAnalysisResult(perspectivePayload: .dtl)
        )

        record.markRepairFailure(
            fallbackStatus: .failed,
            repairReason: .importFailed
        )

        #expect(record.importStatus == .failed)
        #expect(record.repairReason == .importFailed)
        #expect(record.swingFrames.isEmpty)
        #expect(record.keyFrames.isEmpty)
        #expect(record.analysisResult == nil)
        #expect(record.isRecoverableFailedImport)
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
        #expect(decoded.syncFlow == nil)
        #expect(decoded.recoveredFromCorruption)
        #expect(decoded.recoveryDiagnostics.isEmpty == false)
    }

    @Test func analysisResultNormalizationPreservesRecoveryDiagnostics() async throws {
        let decoded = try JSONDecoder().decode(
            AnalysisResult.self,
            from: makeMalformedGarageAnalysisResultJSON()
        )
        let normalized = decoded.normalizedForPersistence

        #expect(decoded.recoveredFromCorruption)
        #expect(normalized.recoveredFromCorruption)
        #expect(normalized.recoveryDiagnostics == decoded.recoveryDiagnostics)
        #expect(normalized.syncFlow == nil)
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

    @Test func analysisResultDropsSyncFlowWhenEnumsAreUnknown() async throws {
        let json = """
        {
          "issues": [],
          "highlights": ["Legacy-safe decode"],
          "summary": "Synthetic analysis payload.",
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
        let decoded = try JSONDecoder().decode(AnalysisResult.self, from: Data(json.utf8))

        #expect(decoded.syncFlow == nil)
        #expect(decoded.recoveredFromCorruption)
        #expect(decoded.recoveryDiagnostics.contains(where: { $0.contains("syncFlow") }))
    }

    @Test func garageLongClipTrimHelpersRequireManualWindowAndClampBounds() async throws {
        #expect(garageRequiresManualTrim(for: 47.26))
        #expect(garageRequiresManualTrim(for: 7.99) == false)

        let defaultWindow = garageDefaultTrimWindow(for: 47.26)
        #expect(abs(defaultWindow.lowerBound - 21.63) < 0.02)
        #expect(abs(defaultWindow.upperBound - 25.63) < 0.02)

        let normalized = garageNormalizedTrimWindow(start: 0.2, end: 12.0, duration: 47.26)
        #expect(abs((normalized.upperBound - normalized.lowerBound) - garageMaximumTrimWindowDuration) < 0.01)

        let shortClipWindow = garageNormalizedTrimWindow(start: 0, end: 0.2, duration: 2.0)
        #expect(abs((shortClipWindow.upperBound - shortClipWindow.lowerBound) - garageMinimumTrimWindowDuration) < 0.01)
    }

    @Test func garageAutomaticWorkingRangeTargetsMotionWithoutFixedFourSecondClamp() async throws {
        let frames = scaledSwingFrames(makePrerollSwingFrames(), targetDuration: 18)
        let workingRange = try #require(GarageAnalysisPipeline.automaticWorkingRange(for: frames, duration: 18))
        let keyFrames = GarageAnalysisPipeline.detectKeyFrames(from: frames)
        let impactIndex = try #require(keyFrames.first(where: { $0.phase == .impact })?.frameIndex)
        let impactTimestamp = frames[impactIndex].timestamp

        #expect(workingRange.lowerBound > 0.5)
        #expect(workingRange.upperBound <= 18)
        #expect(workingRange.contains(impactTimestamp))
        #expect(abs((workingRange.upperBound - workingRange.lowerBound) - 4.0) > 0.25)
    }

    @Test func garageMediaStoreRecreatesReviewMasterAndExportDirectories() async throws {
        try removeGarageManagedAssetDirectory()
        let sourceVideoURL = try await makeGaragePlayableVideoFixture()
        let reviewMasterURL = try GarageMediaStore.persistReviewMaster(from: sourceVideoURL)
        let exportURL = try #require(await GarageMediaStore.createExportDerivative(from: reviewMasterURL))

        #expect(FileManager.default.fileExists(atPath: reviewMasterURL.path))
        #expect(FileManager.default.fileExists(atPath: exportURL.path))
        #expect(reviewMasterURL.path.contains("/GarageSwingVideos/ReviewMasters/"))
        #expect(exportURL.path.contains("/GarageSwingVideos/Exports/"))
    }

    @Test func garageDerivedPayloadRoundTripsAndDrivesReviewAvailability() async throws {
        let frames = makeSyntheticSwingFrames()
        let keyFrames = GarageAnalysisPipeline.detectKeyFrames(from: frames)
        let anchors = GarageAnalysisPipeline.deriveHandAnchors(from: frames, keyFrames: keyFrames)
        let pathPoints = GarageAnalysisPipeline.generatePathPoints(from: anchors, samplesPerSegment: 4)
        let filename = "derived-ready.mov"
        makePersistedGarageVideoFixture(named: filename)

        let record = SwingRecord(
            title: "Derived Ready",
            reviewMasterFilename: filename,
            frameRate: 60,
            swingFrames: frames,
            keyFrames: keyFrames,
            handAnchors: anchors,
            pathPoints: pathPoints
        )
        record.persistDerivedPayload(
            GarageDerivedPayload(
                frameRate: 60,
                swingFrames: frames,
                keyFrames: keyFrames,
                handAnchors: anchors,
                pathPoints: pathPoints,
                analysisResult: makeGarageAnalysisResult(perspectivePayload: .dtl)
            )
        )

        #expect(record.decodedDerivedPayload?.swingFrames.count == frames.count)
        #expect(record.reviewAvailability == .ready)
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
        record.persistDerivedPayload(
            GarageDerivedPayload(
                frameRate: 60,
                swingFrames: frames,
                keyFrames: keyFrames,
                handAnchors: anchors,
                pathPoints: pathPoints,
                analysisResult: AnalysisResult(
                    issues: [],
                    highlights: ["Synthetic baseline"],
                    summary: "Processed synthetic swing frames."
                )
            )
        )

        let report = GarageInsights.report(for: record)
        let hasAnchorCoverageMetric = report.metrics.contains { metric in
            metric.title == "Anchor Coverage" && metric.value == "100%"
        }

        #expect(report.isReady)
        #expect(report.metrics.contains(where: { $0.title == "Tempo" }))
        #expect(report.metrics.contains(where: { $0.title == "Impact Return" }))
        #expect(hasAnchorCoverageMetric)
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
private func makeInMemoryContainer() throws -> ModelContainer {
    try ModelContainer(
        for: LISYPersistence.schema,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
}

private func makeCourseMetadata(
    assetDescriptor: GarageCourseAssetDescriptor? = GarageCourseAssetDescriptor(
        sourceType: .assistedWebImport,
        sourceReference: "https://example.com/course/hole-14",
        localAssetPath: nil,
        imagePixelWidth: 1668,
        imagePixelHeight: 2388
    )
) -> GarageCourseMetadata {
    GarageCourseMetadata(
        courseName: "North Ridge Links",
        holeLabel: "Hole 14",
        holeName: "Cliffside Splitter",
        par: 4,
        yardageLabel: "434",
        playerIntent: "Survey the safest aggressive line before committing to the tee shape.",
        contextNote: "Course Mapping stays tactical and local-first.",
        dominantWind: "Wind NNE 8 mph",
        region: GarageCourseRegion(
            center: GarageMapCoordinate(latitude: 36.5686, longitude: -121.9503),
            latitudinalMeters: 880,
            longitudinalMeters: 880
        ),
        assetDescriptor: assetDescriptor
    )
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

    let record = SwingRecord(
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
    record.persistDerivedPayload(
        GarageDerivedPayload(
            frameRate: 60,
            swingFrames: frames,
            keyFrames: keyFrames,
            handAnchors: anchors,
            pathPoints: pathPoints,
            analysisResult: AnalysisResult(
                issues: [],
                highlights: ["Workflow baseline"],
                summary: "Processed synthetic swing frames."
            )
        )
    )
    return record
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

@MainActor
private func removeGarageManagedAssetDirectory() throws {
    let fileManager = FileManager.default
    let baseURL = try fileManager.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
    )
    let garageURL = baseURL.appendingPathComponent("GarageSwingVideos", isDirectory: true)

    if fileManager.fileExists(atPath: garageURL.path) {
        try fileManager.removeItem(at: garageURL)
    }
}

private func scaledSwingFrames(_ frames: [SwingFrame], targetDuration: Double) -> [SwingFrame] {
    guard let lastTimestamp = frames.last?.timestamp, lastTimestamp > 0 else {
        return frames
    }

    let scale = targetDuration / lastTimestamp
    return frames.map { frame in
        SwingFrame(
            timestamp: frame.timestamp * scale,
            joints: frame.joints,
            confidence: frame.confidence
        )
    }
}

private func makeGaragePlayableVideoFixture() async throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("garage-playable-\(UUID().uuidString).mov")
    let writer = try AVAssetWriter(url: url, fileType: .mov)
    let size = CGSize(width: 32, height: 32)
    let settings: [String: Any] = [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: size.width,
        AVVideoHeightKey: size.height
    ]
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
    input.expectsMediaDataInRealTime = false

    let attributes: [String: Any] = [
        kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
        kCVPixelBufferWidthKey as String: Int(size.width),
        kCVPixelBufferHeightKey as String: Int(size.height)
    ]
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(
        assetWriterInput: input,
        sourcePixelBufferAttributes: attributes
    )

    guard writer.canAdd(input) else {
        throw NSError(domain: "GarageTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to attach test writer input."])
    }

    writer.add(input)
    guard writer.startWriting() else {
        throw writer.error ?? NSError(domain: "GarageTests", code: 5, userInfo: [NSLocalizedDescriptionKey: "Unable to start test writer."])
    }
    writer.startSession(atSourceTime: .zero)

    while input.isReadyForMoreMediaData == false {
        await Task.yield()
    }

    let firstFrame = try makeFilledPixelBuffer(size: size, color: 0x2C)
    let secondFrame = try makeFilledPixelBuffer(size: size, color: 0x66)

    guard adaptor.append(firstFrame, withPresentationTime: .zero) else {
        throw writer.error ?? NSError(domain: "GarageTests", code: 6, userInfo: [NSLocalizedDescriptionKey: "Unable to append first test frame."])
    }
    guard adaptor.append(secondFrame, withPresentationTime: CMTime(seconds: 0.2, preferredTimescale: 600)) else {
        throw writer.error ?? NSError(domain: "GarageTests", code: 7, userInfo: [NSLocalizedDescriptionKey: "Unable to append second test frame."])
    }

    input.markAsFinished()

    await withCheckedContinuation { continuation in
        writer.finishWriting {
            continuation.resume()
        }
    }

    guard writer.status == .completed else {
        throw writer.error ?? NSError(domain: "GarageTests", code: 2, userInfo: [NSLocalizedDescriptionKey: "Playable video fixture export failed."])
    }

    return url
}

private func makeFilledPixelBuffer(size: CGSize, color: UInt8) throws -> CVPixelBuffer {
    var maybeBuffer: CVPixelBuffer?
    let status = CVPixelBufferCreate(
        kCFAllocatorDefault,
        Int(size.width),
        Int(size.height),
        kCVPixelFormatType_32ARGB,
        nil,
        &maybeBuffer
    )

    guard status == kCVReturnSuccess, let buffer = maybeBuffer else {
        throw NSError(domain: "GarageTests", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unable to allocate pixel buffer."])
    }

    CVPixelBufferLockBaseAddress(buffer, [])
    defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

    guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else {
        throw NSError(domain: "GarageTests", code: 4, userInfo: [NSLocalizedDescriptionKey: "Pixel buffer missing base address."])
    }

    memset(baseAddress, Int32(color), CVPixelBufferGetDataSize(buffer))
    return buffer
}
