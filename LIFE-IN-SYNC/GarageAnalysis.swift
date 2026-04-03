import AVFoundation
import Foundation
import Vision

struct GarageAnalysisOutput {
    let frameRate: Double
    let swingFrames: [SwingFrame]
    let keyFrames: [KeyFrame]
    let analysisResult: AnalysisResult
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

    static func thumbnail(for videoURL: URL, at timestamp: Double, maximumSize: CGSize = CGSize(width: 480, height: 480)) async -> CGImage? {
        await withCheckedContinuation { continuation in
            let asset = AVURLAsset(url: videoURL)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = maximumSize

            let time = CMTime(seconds: timestamp, preferredTimescale: 600)
            generator.generateCGImageAsynchronously(for: time) { image, _, _ in
                continuation.resume(returning: image)
            }
        }
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

enum GarageAnalysisPipeline {
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
        let analysisResult = AnalysisResult(
            issues: [],
            highlights: ["Eight deterministic keyframes detected from normalized pose frames."],
            summary: "Processed \(smoothedFrames.count) frames at \(Int(samplingFrameRate.rounded())) FPS and mapped all eight swing phases."
        )

        return GarageAnalysisOutput(
            frameRate: samplingFrameRate,
            swingFrames: smoothedFrames,
            keyFrames: keyFrames,
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

    private static func topOfBackswingIndex(in frames: [SwingFrame], fallbackStart: Int) -> Int {
        let searchRange = fallbackStart..<max(frames.count - 2, fallbackStart + 1)
        let candidate = searchRange.min { lhs, rhs in
            handCenter(in: frames[lhs]).y < handCenter(in: frames[rhs]).y
        }
        return candidate ?? min(max(fallbackStart, frames.count / 3), max(frames.count - 3, 0))
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

    private static func impactIndex(in frames: [SwingFrame], addressIndex: Int, transitionIndex: Int) -> Int {
        let addressHands = handCenter(in: frames[addressIndex])
        let searchStart = min(transitionIndex + 1, frames.count - 1)
        let range = searchStart..<frames.count

        // In phase-one 2D-only analysis, the address hand center is the deterministic ball proxy.
        let candidate = range.min { lhs, rhs in
            distance(from: handCenter(in: frames[lhs]), to: addressHands) < distance(from: handCenter(in: frames[rhs]), to: addressHands)
        }

        return candidate ?? frames.count - 1
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
            let start = orderedAnchors[index]
            let end = orderedAnchors[index + 1]
            let sampleCount = max(samplesPerSegment, 2)

            for sample in 0..<sampleCount {
                let t = Double(sample) / Double(sampleCount)
                let x = start.x + ((end.x - start.x) * t)
                let y = start.y + ((end.y - start.y) * t)
                points.append(PathPoint(sequence: sequence, x: x, y: y))
                sequence += 1
            }
        }

        if let finalAnchor = orderedAnchors.last {
            points.append(PathPoint(sequence: sequence, x: finalAnchor.x, y: finalAnchor.y))
        }

        return points
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
