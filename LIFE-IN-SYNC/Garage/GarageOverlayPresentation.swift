import SwiftUI

enum GarageOverlayMode: String, CaseIterable, Identifiable, Equatable {
    case clean
    case pro

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clean:
            "Clean"
        case .pro:
            "Pro"
        }
    }
}

enum GarageOverlayMetricStatus: Equatable {
    case optimal
    case warning
    case critical
    case insufficientData

    var label: String {
        switch self {
        case .optimal:
            "Solid"
        case .warning:
            "Watch"
        case .critical:
            "Needs work"
        case .insufficientData:
            "Limited"
        }
    }

    var tint: Color {
        switch self {
        case .optimal:
            garageReviewApproved
        case .warning:
            garageReviewPending
        case .critical:
            garageReviewFlagged
        case .insufficientData:
            garageReviewMutedText
        }
    }

    var opacityScale: Double {
        switch self {
        case .optimal:
            1.0
        case .warning:
            0.92
        case .critical:
            0.96
        case .insufficientData:
            0.34
        }
    }
}

enum GarageOverlayConfidenceLevel: Equatable {
    case high
    case moderate
    case low
    case insufficientData

    var opacityScale: Double {
        switch self {
        case .high:
            1.0
        case .moderate:
            0.76
        case .low:
            0.44
        case .insufficientData:
            0.22
        }
    }
}

enum GarageOverlayCueKind: String, Equatable {
    case spine
    case pelvis
    case head
}

struct GarageOverlayLine: Equatable {
    let start: CGPoint
    let end: CGPoint
    let outerWidth: CGFloat
    let coreWidth: CGFloat
}

struct GarageOverlayPolyline: Equatable {
    let points: [CGPoint]
    let outerWidth: CGFloat
    let coreWidth: CGFloat
}

struct GarageOverlayHalo: Equatable {
    let rect: CGRect
    let outerWidth: CGFloat
    let coreWidth: CGFloat
    let dash: [CGFloat]
}

struct GarageOverlayCue: Equatable {
    let kind: GarageOverlayCueKind
    let title: String
    let status: GarageOverlayMetricStatus
    let confidence: GarageOverlayConfidenceLevel
    let opacity: Double
    let line: GarageOverlayLine?
    let polyline: GarageOverlayPolyline?
    let halo: GarageOverlayHalo?
}

struct GarageOverlayJoint: Equatable {
    let name: SwingJointName
    let center: CGPoint
    let radius: CGFloat
    let status: GarageOverlayMetricStatus
    let confidence: GarageOverlayConfidenceLevel
    let opacity: Double
}

struct GarageOverlayMarker: Equatable {
    let center: CGPoint
    let status: GarageOverlayMetricStatus
    let outerRadius: CGFloat
    let innerRadius: CGFloat
    let opacity: Double
}

struct GarageOverlayLabel: Equatable {
    let id: String
    let text: String
    let anchor: CGPoint
    let status: GarageOverlayMetricStatus
    let opacity: Double
}

struct GarageOverlayHUDPresentation: Equatable {
    let title: String
    let detail: String
    let severity: GarageSkeletonHUDSeverity?
    let primaryStatus: GarageOverlayMetricStatus
    let mode: GarageOverlayMode
    let isModeToggleEnabled: Bool

    static let unavailable = GarageOverlayHUDPresentation(
        title: "Pose overlay unavailable",
        detail: "Garage does not have enough frame data to draw a trustworthy body overlay.",
        severity: .warning("Pose data limited"),
        primaryStatus: .insufficientData,
        mode: .clean,
        isModeToggleEnabled: false
    )
}

struct GarageOverlayPresentationState: Equatable {
    let mode: GarageOverlayMode
    let cleanCues: [GarageOverlayCue]
    let proSegments: [GarageOverlayLine]
    let proJoints: [GarageOverlayJoint]
    let proHeadHalo: GarageOverlayHalo?
    let flowPath: GarageOverlayPolyline?
    let pulseMarker: GarageOverlayMarker?
    let issueMarker: GarageOverlayMarker?
    let labels: [GarageOverlayLabel]
    let hud: GarageOverlayHUDPresentation

    static let unavailable = GarageOverlayPresentationState(
        mode: .clean,
        cleanCues: [],
        proSegments: [],
        proJoints: [],
        proHeadHalo: nil,
        flowPath: nil,
        pulseMarker: nil,
        issueMarker: nil,
        labels: [],
        hud: .unavailable
    )
}

enum GarageOverlayAdapter {
    private static let minimumGeometryConfidence = 0.2
    private static let minimumMetricConfidence = 0.45
    private static let minimumFrameConfidence = 0.48
    private static let confidenceWindowRadius = 2

    private static let skeletonLinks: [(SwingJointName, SwingJointName)] = [
        (.leftShoulder, .rightShoulder),
        (.leftShoulder, .leftElbow),
        (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow),
        (.rightElbow, .rightWrist),
        (.leftShoulder, .leftHip),
        (.rightShoulder, .rightHip),
        (.leftHip, .rightHip),
        (.leftHip, .leftKnee),
        (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee),
        (.rightKnee, .rightAnkle)
    ]

    private static let renderOrder: [SwingJointName] = [
        .leftAnkle,
        .rightAnkle,
        .leftKnee,
        .rightKnee,
        .leftHip,
        .rightHip,
        .leftWrist,
        .rightWrist,
        .leftElbow,
        .rightElbow,
        .leftShoulder,
        .rightShoulder
    ]

    private static let emphasizedJoints: Set<SwingJointName> = [
        .leftShoulder,
        .rightShoulder,
        .leftHip,
        .rightHip
    ]

    static func makePresentation(
        mode: GarageOverlayMode,
        drawSize: CGSize,
        frames: [SwingFrame],
        currentFrameIndex: Int?,
        currentFrame: SwingFrame?,
        keyFrames: [KeyFrame],
        currentTime: Double,
        pulseProgress: Double,
        scorecard: GarageSwingScorecard?,
        syncFlow: GarageSyncFlowReport?
    ) -> GarageOverlayPresentationState {
        guard drawSize.width > 0, drawSize.height > 0 else {
            return GarageOverlayPresentationState.unavailable
        }

        let resolvedFrame = currentFrame ?? resolvedFrame(from: frames, currentFrameIndex: currentFrameIndex)
        guard let resolvedFrame else {
            return GarageOverlayPresentationState.unavailable
        }

        let safeFrameIndex = currentFrameIndex ?? frames.firstIndex(of: resolvedFrame)
        let cleanCues = cleanOverlayCues(
            drawSize: drawSize,
            frames: frames,
            currentFrameIndex: safeFrameIndex,
            currentFrame: resolvedFrame,
            keyFrames: keyFrames,
            scorecard: scorecard,
            syncFlow: syncFlow
        )
        let proSegments = mode == .pro ? skeletonSegments(drawSize: drawSize, frame: resolvedFrame) : []
        let proJoints = mode == .pro ? skeletonJoints(drawSize: drawSize, frame: resolvedFrame) : []
        let proHeadHalo = mode == .pro ? headHalo(drawSize: drawSize, frame: resolvedFrame, status: .optimal) : nil
        let flowPath = mode == .pro ? flowPolyline(drawSize: drawSize, frame: resolvedFrame) : nil
        let pulseMarker = mode == .pro ? pulseMarker(progress: pulseProgress, polyline: flowPath) : nil
        let resolvedIssueMarker = mode == .pro
            ? issueMarker(
                drawSize: drawSize,
                frame: resolvedFrame,
                currentTime: currentTime,
                syncFlow: syncFlow
            )
            : nil
        let labels = mode == .pro ? rawLabels(drawSize: drawSize, scorecard: scorecard, syncFlow: syncFlow) : []
        let hud = hudPresentation(mode: mode, cleanCues: cleanCues, scorecard: scorecard, syncFlow: syncFlow)

        return GarageOverlayPresentationState(
            mode: mode,
            cleanCues: cleanCues,
            proSegments: proSegments,
            proJoints: proJoints,
            proHeadHalo: proHeadHalo,
            flowPath: flowPath,
            pulseMarker: pulseMarker,
            issueMarker: resolvedIssueMarker,
            labels: labels,
            hud: hud
        )
    }

    private static func cleanOverlayCues(
        drawSize: CGSize,
        frames: [SwingFrame],
        currentFrameIndex: Int?,
        currentFrame: SwingFrame,
        keyFrames: [KeyFrame],
        scorecard: GarageSwingScorecard?,
        syncFlow: GarageSyncFlowReport?
    ) -> [GarageOverlayCue] {
        let spineStatus = status(for: .spine, scorecard: scorecard)
        let pelvisStatus = pelvisStatus(scorecard: scorecard, syncFlow: syncFlow)
        let headStatus = headStatus(scorecard: scorecard, syncFlow: syncFlow)
        let cues = [
            spineCue(
                drawSize: drawSize,
                frames: frames,
                currentFrameIndex: currentFrameIndex,
                frame: currentFrame,
                status: spineStatus
            ),
            pelvisCue(
                drawSize: drawSize,
                frames: frames,
                currentFrameIndex: currentFrameIndex,
                frame: currentFrame,
                keyFrames: keyFrames,
                status: pelvisStatus
            ),
            headCue(
                drawSize: drawSize,
                frames: frames,
                currentFrameIndex: currentFrameIndex,
                frame: currentFrame,
                status: headStatus
            )
        ]

        return cues.map { cue in
            guard cue.confidence == .insufficientData else { return cue }
            return GarageOverlayCue(
                kind: cue.kind,
                title: cue.title,
                status: .insufficientData,
                confidence: cue.confidence,
                opacity: opacity(status: .insufficientData, confidence: cue.confidence),
                line: cue.line,
                polyline: cue.polyline,
                halo: cue.halo
            )
        }
    }

    private static func spineCue(
        drawSize: CGSize,
        frames: [SwingFrame],
        currentFrameIndex: Int?,
        frame: SwingFrame,
        status: GarageOverlayMetricStatus
    ) -> GarageOverlayCue {
        let confidence = rollingConfidenceLevel(
            frames: frames,
            currentFrameIndex: currentFrameIndex,
            fallbackFrame: frame,
            jointNames: [.leftShoulder, .rightShoulder, .leftHip, .rightHip]
        )
        let line: GarageOverlayLine?

        if
            let shoulderMidpoint = midpoint(.leftShoulder, .rightShoulder, in: frame, minimumConfidence: minimumGeometryConfidence),
            let pelvis = pelvisCenter(in: frame, minimumConfidence: minimumGeometryConfidence)
        {
            line = GarageOverlayLine(
                start: mappedPoint(pelvis, in: drawSize),
                end: mappedPoint(shoulderMidpoint, in: drawSize),
                outerWidth: 7,
                coreWidth: 2.4
            )
        } else {
            line = nil
        }

        return GarageOverlayCue(
            kind: .spine,
            title: "Posture",
            status: line == nil ? .insufficientData : status,
            confidence: line == nil ? .insufficientData : confidence,
            opacity: opacity(status: line == nil ? .insufficientData : status, confidence: confidence),
            line: line,
            polyline: nil,
            halo: nil
        )
    }

    private static func pelvisCue(
        drawSize: CGSize,
        frames: [SwingFrame],
        currentFrameIndex: Int?,
        frame: SwingFrame,
        keyFrames: [KeyFrame],
        status: GarageOverlayMetricStatus
    ) -> GarageOverlayCue {
        let confidence = rollingConfidenceLevel(
            frames: frames,
            currentFrameIndex: currentFrameIndex,
            fallbackFrame: frame,
            jointNames: [.leftHip, .rightHip]
        )
        let line: GarageOverlayLine?
        if
            let leftHip = frame.point(named: .leftHip, minimumConfidence: minimumGeometryConfidence),
            let rightHip = frame.point(named: .rightHip, minimumConfidence: minimumGeometryConfidence)
        {
            line = GarageOverlayLine(
                start: mappedPoint(leftHip, in: drawSize),
                end: mappedPoint(rightHip, in: drawSize),
                outerWidth: 8,
                coreWidth: 2.6
            )
        } else {
            line = nil
        }

        let polyline: GarageOverlayPolyline?
        if
            let addressPelvis = addressPelvisCenter(frames: frames, keyFrames: keyFrames),
            let currentPelvis = pelvisCenter(in: frame, minimumConfidence: minimumGeometryConfidence)
        {
            let start = mappedPoint(addressPelvis, in: drawSize)
            let end = mappedPoint(currentPelvis, in: drawSize)
            polyline = GarageOverlayPolyline(points: [start, end], outerWidth: 5, coreWidth: 1.8)
        } else {
            polyline = nil
        }

        return GarageOverlayCue(
            kind: .pelvis,
            title: "Depth",
            status: line == nil ? .insufficientData : status,
            confidence: line == nil ? .insufficientData : confidence,
            opacity: opacity(status: line == nil ? .insufficientData : status, confidence: confidence),
            line: line,
            polyline: polyline,
            halo: nil
        )
    }

    private static func headCue(
        drawSize: CGSize,
        frames: [SwingFrame],
        currentFrameIndex: Int?,
        frame: SwingFrame,
        status: GarageOverlayMetricStatus
    ) -> GarageOverlayCue {
        let confidence = rollingConfidenceLevel(
            frames: frames,
            currentFrameIndex: currentFrameIndex,
            fallbackFrame: frame,
            jointNames: [.nose, .leftShoulder, .rightShoulder]
        )
        let halo = headHalo(drawSize: drawSize, frame: frame, status: status)

        return GarageOverlayCue(
            kind: .head,
            title: "Head",
            status: halo == nil ? .insufficientData : status,
            confidence: halo == nil ? .insufficientData : confidence,
            opacity: opacity(status: halo == nil ? .insufficientData : status, confidence: confidence),
            line: nil,
            polyline: nil,
            halo: halo
        )
    }

    private static func skeletonSegments(drawSize: CGSize, frame: SwingFrame) -> [GarageOverlayLine] {
        skeletonLinks.compactMap { startName, endName in
            guard
                let startJoint = frame.joint(named: startName),
                let endJoint = frame.joint(named: endName),
                max(startJoint.confidence, endJoint.confidence) >= minimumGeometryConfidence
            else {
                return nil
            }

            let confidence = confidenceLevel((startJoint.confidence + endJoint.confidence) / 2)
            return GarageOverlayLine(
                start: mappedPoint(CGPoint(x: startJoint.x, y: startJoint.y), in: drawSize),
                end: mappedPoint(CGPoint(x: endJoint.x, y: endJoint.y), in: drawSize),
                outerWidth: confidence == .low || confidence == .insufficientData ? 5.0 : 6.5,
                coreWidth: confidence == .low || confidence == .insufficientData ? 1.4 : 2.0
            )
        }
    }

    private static func skeletonJoints(drawSize: CGSize, frame: SwingFrame) -> [GarageOverlayJoint] {
        renderOrder.compactMap { jointName in
            guard let joint = frame.joint(named: jointName), joint.confidence >= minimumGeometryConfidence else {
                return nil
            }

            let confidence = confidenceLevel(joint.confidence)
            let isEmphasized = emphasizedJoints.contains(jointName)
            return GarageOverlayJoint(
                name: jointName,
                center: mappedPoint(CGPoint(x: joint.x, y: joint.y), in: drawSize),
                radius: isEmphasized ? 4.8 : 3.4,
                status: confidence == .insufficientData ? .insufficientData : .optimal,
                confidence: confidence,
                opacity: confidence.opacityScale
            )
        }
    }

    private static func headHalo(
        drawSize: CGSize,
        frame: SwingFrame,
        status: GarageOverlayMetricStatus
    ) -> GarageOverlayHalo? {
        guard let headCircle = GarageAnalysisPipeline.headCircle(in: frame) else {
            return nil
        }

        let mappedCenter = mappedPoint(headCircle.center, in: drawSize)
        let mappedRadius = min(drawSize.width, drawSize.height) * headCircle.radius
        return GarageOverlayHalo(
            rect: CGRect(
                x: mappedCenter.x - mappedRadius,
                y: mappedCenter.y - mappedRadius,
                width: mappedRadius * 2,
                height: mappedRadius * 2
            ),
            outerWidth: status == .insufficientData ? 3.4 : 5.0,
            coreWidth: status == .insufficientData ? 1.1 : 1.8,
            dash: [8, 6]
        )
    }

    private static func flowPolyline(drawSize: CGSize, frame: SwingFrame) -> GarageOverlayPolyline? {
        let points = syncFlowChainPoints(from: frame).map { mappedPoint($0, in: drawSize) }
        guard points.count >= 2 else { return nil }
        return GarageOverlayPolyline(points: points, outerWidth: 7, coreWidth: 2.2)
    }

    private static func pulseMarker(progress: Double, polyline: GarageOverlayPolyline?) -> GarageOverlayMarker? {
        guard let polyline, let point = point(progress: progress, along: polyline.points) else {
            return nil
        }

        return GarageOverlayMarker(
            center: point,
            status: .optimal,
            outerRadius: 10,
            innerRadius: 5,
            opacity: 0.82
        )
    }

    private static func issueMarker(
        drawSize: CGSize,
        frame: SwingFrame,
        currentTime: Double,
        syncFlow: GarageSyncFlowReport?
    ) -> GarageOverlayMarker? {
        guard
            let issue = syncFlow?.primaryIssue,
            let markedPoint = frame.point(named: issue.jointName, minimumConfidence: minimumGeometryConfidence)
        else {
            return nil
        }

        let status: GarageOverlayMetricStatus
        if
            let consequence = syncFlow?.consequence,
            currentTime >= consequence.startTimestamp,
            currentTime <= consequence.endTimestamp
        {
            status = .critical
        } else {
            status = .warning
        }

        return GarageOverlayMarker(
            center: mappedPoint(markedPoint, in: drawSize),
            status: status,
            outerRadius: 13,
            innerRadius: 5.5,
            opacity: 0.94
        )
    }

    private static func rawLabels(
        drawSize: CGSize,
        scorecard: GarageSwingScorecard?,
        syncFlow: GarageSyncFlowReport?
    ) -> [GarageOverlayLabel] {
        var labels: [GarageOverlayLabel] = []
        let left = max(min(drawSize.width * 0.04, drawSize.width - 120), 10)
        var y = max(drawSize.height * 0.08, 14)

        if let scorecard {
            labels.append(
                GarageOverlayLabel(
                    id: "spine",
                    text: String(format: "Spine %.1f°", scorecard.metrics.spine.deltaDegrees),
                    anchor: CGPoint(x: left, y: y),
                    status: status(for: .spine, scorecard: scorecard),
                    opacity: 0.96
                )
            )
            y += 22
            labels.append(
                GarageOverlayLabel(
                    id: "pelvis",
                    text: String(format: "Depth %.1f in", scorecard.metrics.pelvicDepth.driftInches),
                    anchor: CGPoint(x: left, y: y),
                    status: pelvisStatus(scorecard: scorecard, syncFlow: syncFlow),
                    opacity: 0.96
                )
            )
            y += 22
            let headComposite = (scorecard.metrics.headStability.swayInches * 0.6) + (scorecard.metrics.headStability.dipInches * 0.4)
            labels.append(
                GarageOverlayLabel(
                    id: "head",
                    text: String(format: "Head %.1f in", headComposite),
                    anchor: CGPoint(x: left, y: y),
                    status: headStatus(scorecard: scorecard, syncFlow: syncFlow),
                    opacity: 0.96
                )
            )
            y += 22
        }

        if let issue = syncFlow?.primaryIssue {
            labels.append(
                GarageOverlayLabel(
                    id: "syncflow",
                    text: issue.kind.riskPhrase,
                    anchor: CGPoint(x: left, y: y),
                    status: .warning,
                    opacity: 0.96
                )
            )
        }

        return labels
    }

    private static func hudPresentation(
        mode: GarageOverlayMode,
        cleanCues: [GarageOverlayCue],
        scorecard: GarageSwingScorecard?,
        syncFlow: GarageSyncFlowReport?
    ) -> GarageOverlayHUDPresentation {
        let actionableCue = cleanCues.first { $0.status == .critical }
            ?? cleanCues.first { $0.status == .warning }
            ?? cleanCues.first { $0.status == .optimal }
        let unavailableCount = cleanCues.filter { $0.status == .insufficientData }.count

        let severity: GarageSkeletonHUDSeverity?
        if let consequence = syncFlow?.consequence, let issue = syncFlow?.primaryIssue {
            severity = .critical(consequence.riskPhrase.isEmpty ? issue.kind.riskPhrase : consequence.riskPhrase)
        } else if syncFlow?.status == .limited || unavailableCount == cleanCues.count {
            severity = .warning("Pose confidence limited")
        } else if let issue = syncFlow?.primaryIssue {
            severity = .warning(issue.kind.riskPhrase)
        } else {
            severity = .neutral("Clean overlay active")
        }

        let title: String
        let detail: String
        let primaryStatus: GarageOverlayMetricStatus

        if mode == .pro {
            title = "Pro overlay"
            detail = scorecard == nil
                ? "Full skeleton visible. Scorecard metrics are unavailable for this frame set."
                : "Full skeleton, SyncFlow, and raw DTL metrics are visible."
            primaryStatus = .optimal
        } else if unavailableCount == cleanCues.count {
            title = "Clean overlay limited"
            detail = "Garage can inspect raw pose in Pro Mode, but Clean Mode is hiding uncertain cues."
            primaryStatus = .insufficientData
        } else if let actionableCue {
            title = "\(actionableCue.title): \(actionableCue.status.label)"
            detail = cleanDetail(for: actionableCue, syncFlow: syncFlow)
            primaryStatus = actionableCue.status
        } else {
            title = "Clean overlay ready"
            detail = "Garage is showing only the most defensible DTL cues."
            primaryStatus = .optimal
        }

        return GarageOverlayHUDPresentation(
            title: title,
            detail: detail,
            severity: severity,
            primaryStatus: primaryStatus,
            mode: mode,
            isModeToggleEnabled: true
        )
    }

    private static func cleanDetail(for cue: GarageOverlayCue, syncFlow: GarageSyncFlowReport?) -> String {
        switch cue.kind {
        case .spine:
            switch cue.status {
            case .optimal:
                return "Posture is staying within the current DTL target window."
            case .warning:
                return "Posture is near the edge of the current DTL target window."
            case .critical:
                return "Spine angle is drifting enough to affect repeatability."
            case .insufficientData:
                return "Shoulder and hip landmarks are not stable enough for posture guidance."
            }
        case .pelvis:
            if let issue = syncFlow?.primaryIssue, issue.segment == .pelvis {
                return issue.detail
            }
            switch cue.status {
            case .optimal:
                return "Pelvic depth is staying stable enough through impact."
            case .warning:
                return "Depth is getting close to the warning boundary."
            case .critical:
                return "Pelvic depth is crowding the strike window."
            case .insufficientData:
                return "Hip landmarks are not stable enough for depth guidance."
            }
        case .head:
            if syncFlow?.primaryIssue?.kind == .unstableHead {
                return syncFlow?.primaryIssue?.detail ?? "Head stability is limiting confidence."
            }
            switch cue.status {
            case .optimal:
                return "Head position is stable enough for the current review."
            case .warning:
                return "Head movement is close to the caution range."
            case .critical:
                return "Head drift is large enough to reduce contact stability."
            case .insufficientData:
                return "Head and shoulder landmarks are not stable enough for this cue."
            }
        }
    }

    private static func status(for domain: GarageSwingDomain, scorecard: GarageSwingScorecard?) -> GarageOverlayMetricStatus {
        guard let grade = scorecard?.domainScores.first(where: { $0.id == domain.rawValue })?.grade else {
            return .insufficientData
        }

        switch grade {
        case .excellent, .good:
            return .optimal
        case .fair:
            return .warning
        case .needsWork:
            return .critical
        }
    }

    private static func pelvisStatus(
        scorecard: GarageSwingScorecard?,
        syncFlow: GarageSyncFlowReport?
    ) -> GarageOverlayMetricStatus {
        if let issue = syncFlow?.primaryIssue, issue.segment == .pelvis {
            return .critical
        }

        return status(for: .pelvis, scorecard: scorecard)
    }

    private static func headStatus(
        scorecard: GarageSwingScorecard?,
        syncFlow: GarageSyncFlowReport?
    ) -> GarageOverlayMetricStatus {
        if syncFlow?.primaryIssue?.kind == .unstableHead {
            return .critical
        }

        return status(for: .head, scorecard: scorecard)
    }

    private static func opacity(
        status: GarageOverlayMetricStatus,
        confidence: GarageOverlayConfidenceLevel
    ) -> Double {
        min(max(status.opacityScale * confidence.opacityScale, 0.16), 1.0)
    }

    private static func rollingConfidenceLevel(
        frames: [SwingFrame],
        currentFrameIndex: Int?,
        fallbackFrame: SwingFrame,
        jointNames: [SwingJointName]
    ) -> GarageOverlayConfidenceLevel {
        let samples: [Double]
        if
            let currentFrameIndex,
            frames.indices.contains(currentFrameIndex),
            frames.isEmpty == false
        {
            let lowerBound = max(frames.startIndex, currentFrameIndex - confidenceWindowRadius)
            let upperBound = min(frames.endIndex - 1, currentFrameIndex + confidenceWindowRadius)
            samples = (lowerBound...upperBound).map { confidenceScore(frame: frames[$0], jointNames: jointNames) }
        } else {
            samples = [confidenceScore(frame: fallbackFrame, jointNames: jointNames)]
        }

        let average = samples.reduce(0, +) / Double(max(samples.count, 1))
        return confidenceLevel(average)
    }

    private static func confidenceScore(frame: SwingFrame, jointNames: [SwingJointName]) -> Double {
        guard frame.confidence >= minimumFrameConfidence else {
            return min(frame.confidence, minimumFrameConfidence)
        }

        let jointConfidences = jointNames.map { frame.joint(named: $0)?.confidence ?? 0 }
        let lowestJointConfidence = jointConfidences.min() ?? 0
        return min(frame.confidence, lowestJointConfidence)
    }

    private static func confidenceLevel(_ confidence: Double) -> GarageOverlayConfidenceLevel {
        switch confidence {
        case 0.78...:
            return .high
        case 0.55..<0.78:
            return .moderate
        case minimumMetricConfidence..<0.55:
            return .low
        default:
            return .insufficientData
        }
    }

    private static func addressPelvisCenter(frames: [SwingFrame], keyFrames: [KeyFrame]) -> CGPoint? {
        let addressIndex = keyFrames.first(where: { $0.phase == .address })?.frameIndex ?? frames.startIndex
        guard frames.indices.contains(addressIndex) else { return nil }
        return pelvisCenter(in: frames[addressIndex], minimumConfidence: minimumGeometryConfidence)
    }

    private static func pelvisCenter(in frame: SwingFrame, minimumConfidence: Double) -> CGPoint? {
        midpoint(.leftHip, .rightHip, in: frame, minimumConfidence: minimumConfidence)
    }

    private static func midpoint(
        _ left: SwingJointName,
        _ right: SwingJointName,
        in frame: SwingFrame,
        minimumConfidence: Double
    ) -> CGPoint? {
        guard
            let leftPoint = frame.point(named: left, minimumConfidence: minimumConfidence),
            let rightPoint = frame.point(named: right, minimumConfidence: minimumConfidence)
        else {
            return nil
        }

        return CGPoint(x: (leftPoint.x + rightPoint.x) / 2, y: (leftPoint.y + rightPoint.y) / 2)
    }

    private static func syncFlowChainPoints(from frame: SwingFrame) -> [CGPoint] {
        var points: [CGPoint] = []

        if let base = syncFlowBaseCenter(in: frame) {
            points.append(base)
        }

        if let pelvis = midpoint(.leftHip, .rightHip, in: frame, minimumConfidence: minimumGeometryConfidence) {
            points.append(pelvis)
        }

        if let torso = midpoint(.leftShoulder, .rightShoulder, in: frame, minimumConfidence: minimumGeometryConfidence) {
            points.append(torso)
        }

        let hands = GarageAnalysisPipeline.handCenter(in: frame)
        if hands != .zero {
            points.append(hands)
        }

        return points
    }

    private static func syncFlowBaseCenter(in frame: SwingFrame) -> CGPoint? {
        midpoint(.leftAnkle, .rightAnkle, in: frame, minimumConfidence: minimumGeometryConfidence)
    }

    private static func point(progress: Double, along points: [CGPoint]) -> CGPoint? {
        guard points.count >= 2 else { return points.first }

        let clampedProgress = min(max(progress, 0), 1)
        let segmentLengths = zip(points, points.dropFirst()).map { start, end in
            hypot(end.x - start.x, end.y - start.y)
        }
        let totalLength = segmentLengths.reduce(0, +)
        guard totalLength > 0.0001 else { return points.last }

        var target = totalLength * clampedProgress
        for (index, segmentLength) in segmentLengths.enumerated() {
            if target <= segmentLength || index == segmentLengths.count - 1 {
                let start = points[index]
                let end = points[index + 1]
                let localProgress = segmentLength > 0 ? target / segmentLength : 0
                return CGPoint(
                    x: start.x + ((end.x - start.x) * localProgress),
                    y: start.y + ((end.y - start.y) * localProgress)
                )
            }
            target -= segmentLength
        }

        return points.last
    }

    private static func mappedPoint(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: size.width * point.x, y: size.height * point.y)
    }

    private static func resolvedFrame(from frames: [SwingFrame], currentFrameIndex: Int?) -> SwingFrame? {
        guard let currentFrameIndex, frames.indices.contains(currentFrameIndex) else {
            return frames.first
        }

        return frames[currentFrameIndex]
    }
}
