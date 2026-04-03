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
    }

    @Test func garageKeyframeDetectionReturnsCanonicalPhaseOrder() async throws {
        let frames = makeSyntheticSwingFrames()

        let keyFrames = GarageAnalysisPipeline.detectKeyFrames(from: frames)

        #expect(keyFrames.count == SwingPhase.allCases.count)
        #expect(keyFrames.map(\.phase) == SwingPhase.allCases)
        #expect(keyFrames.map(\.frameIndex) == keyFrames.map(\.frameIndex).sorted())
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
private func joint(_ name: SwingJointName, x: Double, y: Double, confidence: Double = 0.9) -> SwingJoint {
    SwingJoint(name: name, x: x, y: y, confidence: confidence)
}
