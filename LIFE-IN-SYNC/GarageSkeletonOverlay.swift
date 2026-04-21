import SwiftUI

struct GarageSkeletonOverlay: View {
    let drawSize: CGSize
    let currentFrame: SwingFrame?
    let currentTime: Double
    let pulseProgress: Double
    let syncFlow: GarageSyncFlowReport?

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

    private var primaryIssue: GarageSyncFlowIssue? {
        syncFlow?.primaryIssue
    }

    private var consequence: GarageSyncFlowConsequence? {
        syncFlow?.consequence
    }

    private var showsConsequence: Bool {
        guard let consequence else { return false }
        return currentTime >= consequence.startTimestamp && currentTime <= consequence.endTimestamp
    }

    private var captionTitle: String? {
        if let primaryIssue {
            return primaryIssue.title
        }

        if syncFlow?.status == .limited {
            return syncFlow?.headline
        }

        return nil
    }

    private var captionDetail: String? {
        if let primaryIssue {
            return primaryIssue.detail
        }

        if syncFlow?.status == .limited {
            return syncFlow?.summary
        }

        return nil
    }

    private var hudSeverity: GarageSkeletonHUDSeverity? {
        guard captionTitle != nil, captionDetail != nil else { return nil }

        if showsConsequence, let consequence {
            return .critical(consequence.riskPhrase)
        }

        if syncFlow?.status == .limited {
            return .warning("Pose tracking limited")
        }

        if let consequence, !consequence.riskPhrase.isEmpty {
            return .warning(consequence.riskPhrase)
        }

        if syncFlow?.status == .ready {
            return .neutral("Sequence view active")
        }

        return nil
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Canvas { context, _ in
                guard
                    drawSize.width > 0,
                    drawSize.height > 0,
                    let currentFrame
                else {
                    return
                }

                drawStructure(in: &context, currentFrame: currentFrame)
                drawFlow(in: &context, currentFrame: currentFrame)
                drawTruth(in: &context, currentFrame: currentFrame)
            }

            if let captionTitle, let captionDetail {
                GarageSkeletonHUDPanel(
                    title: captionTitle,
                    detail: captionDetail,
                    severity: hudSeverity
                )
                .padding(12)
                .transition(.opacity)
            }
        }
    }

    private func drawStructure(in context: inout GraphicsContext, currentFrame: SwingFrame) {
        for (startName, endName) in Self.skeletonLinks {
            guard
                let startJoint = currentFrame.joint(named: startName),
                let endJoint = currentFrame.joint(named: endName),
                max(startJoint.confidence, endJoint.confidence) >= 0.2
            else {
                continue
            }

            let startPoint = garageSkeletonMappedPoint(CGPoint(x: startJoint.x, y: startJoint.y), in: drawSize)
            let endPoint = garageSkeletonMappedPoint(CGPoint(x: endJoint.x, y: endJoint.y), in: drawSize)
            let confidence = (startJoint.confidence + endJoint.confidence) / 2
            var path = Path()
            path.move(to: startPoint)
            path.addLine(to: endPoint)

            if confidence < 0.55 {
                context.drawLayer { layer in
                    layer.addFilter(.blur(radius: 1.2))
                    layer.stroke(
                        path,
                        with: .linearGradient(
                            Gradient(colors: [
                                ModuleTheme.garageTextPrimary.opacity(0.10 + (confidence * 0.12)),
                                ModuleTheme.electricCyan.opacity(0.12 + (confidence * 0.18))
                            ]),
                            startPoint: startPoint,
                            endPoint: endPoint
                        ),
                        style: StrokeStyle(lineWidth: 1.5 + (confidence * 1.1), lineCap: .round, lineJoin: .round)
                    )
                }
            } else {
                context.stroke(
                    path,
                    with: .linearGradient(
                        Gradient(colors: [
                            ModuleTheme.garageTextPrimary.opacity(0.18 + (confidence * 0.08)),
                            ModuleTheme.electricCyan.opacity(0.20 + (confidence * 0.38))
                        ]),
                        startPoint: startPoint,
                        endPoint: endPoint
                    ),
                    style: StrokeStyle(lineWidth: 1.8 + (confidence * 1.0), lineCap: .round, lineJoin: .round)
                )
            }
        }

        if let headCircle = GarageAnalysisPipeline.headCircle(in: currentFrame) {
            let mappedCenter = garageSkeletonMappedPoint(headCircle.center, in: drawSize)
            let mappedRadius = min(drawSize.width, drawSize.height) * headCircle.radius
            let circleRect = CGRect(
                x: mappedCenter.x - mappedRadius,
                y: mappedCenter.y - mappedRadius,
                width: mappedRadius * 2,
                height: mappedRadius * 2
            )
            context.stroke(
                Ellipse().path(in: circleRect),
                with: .color(ModuleTheme.electricCyan.opacity(0.40)),
                style: StrokeStyle(lineWidth: 1.5)
            )
        }

        if
            let nose = currentFrame.point(named: .nose, minimumConfidence: 0.35),
            let leftShoulder = currentFrame.point(named: .leftShoulder, minimumConfidence: 0.35),
            let rightShoulder = currentFrame.point(named: .rightShoulder, minimumConfidence: 0.35)
        {
            let shoulderMidpoint = CGPoint(
                x: (leftShoulder.x + rightShoulder.x) / 2,
                y: (leftShoulder.y + rightShoulder.y) / 2
            )
            let startPoint = garageSkeletonMappedPoint(nose, in: drawSize)
            let endPoint = garageSkeletonMappedPoint(shoulderMidpoint, in: drawSize)
            var connector = Path()
            connector.move(to: startPoint)
            connector.addLine(to: endPoint)

            context.stroke(
                connector,
                with: .color(ModuleTheme.electricCyan.opacity(0.20)),
                style: StrokeStyle(lineWidth: 1.4, lineCap: .round)
            )
        }

        for jointName in Self.renderOrder {
            guard let joint = currentFrame.joint(named: jointName), joint.confidence >= 0.2 else {
                continue
            }

            let mappedPoint = garageSkeletonMappedPoint(
                CGPoint(x: joint.x, y: joint.y),
                in: drawSize
            )
            let isEmphasized = Self.emphasizedJoints.contains(jointName)
            let radius = isEmphasized ? 4.8 : 3.4
            let circleRect = CGRect(
                x: mappedPoint.x - radius,
                y: mappedPoint.y - radius,
                width: radius * 2,
                height: radius * 2
            )

            if joint.confidence >= 0.75 {
                context.drawLayer { layer in
                    layer.addFilter(
                        .shadow(
                            color: ModuleTheme.electricCyan.opacity(isEmphasized ? 0.62 : 0.4),
                            radius: isEmphasized ? 4 : 2.5,
                            x: 0,
                            y: 0
                        )
                    )
                    layer.fill(
                        Ellipse().path(in: circleRect),
                        with: .color(ModuleTheme.electricCyan.opacity(0.94))
                    )
                }
            } else {
                context.drawLayer { layer in
                    layer.addFilter(.blur(radius: 0.8))
                    layer.fill(
                        Ellipse().path(in: circleRect),
                        with: .color(Color(red: 0.72, green: 0.84, blue: 0.89).opacity(0.30 + (joint.confidence * 0.42)))
                    )
                }
            }
        }
    }

    private func drawFlow(in context: inout GraphicsContext, currentFrame: SwingFrame) {
        let chainPoints = syncFlowChainPoints(from: currentFrame)
        guard chainPoints.count >= 2 else { return }

        var chainPath = Path()
        chainPath.move(to: chainPoints[0])
        for point in chainPoints.dropFirst() {
            chainPath.addLine(to: point)
        }

        context.stroke(
            chainPath,
            with: .color(ModuleTheme.electricCyan.opacity(0.10)),
            style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
        )

        if let pulsePoint = garageSyncFlowPulsePoint(progress: pulseProgress, along: chainPoints) {
            let outerRect = CGRect(x: pulsePoint.x - 10, y: pulsePoint.y - 10, width: 20, height: 20)
            let innerRect = CGRect(x: pulsePoint.x - 5, y: pulsePoint.y - 5, width: 10, height: 10)

            context.drawLayer { layer in
                layer.addFilter(.shadow(color: Color.white.opacity(0.55), radius: 12, x: 0, y: 0))
                layer.fill(Ellipse().path(in: outerRect), with: .color(Color.white.opacity(0.75)))
                layer.fill(Ellipse().path(in: innerRect), with: .color(ModuleTheme.electricCyan))
            }
        }
    }

    private func drawTruth(in context: inout GraphicsContext, currentFrame: SwingFrame) {
        guard
            let primaryIssue,
            let markedPoint = currentFrame.point(named: primaryIssue.jointName, minimumConfidence: 0.2)
        else {
            return
        }

        let mappedPoint = garageSkeletonMappedPoint(markedPoint, in: drawSize)
        let outerRect = CGRect(x: mappedPoint.x - 13, y: mappedPoint.y - 13, width: 26, height: 26)
        let innerRect = CGRect(x: mappedPoint.x - 5.5, y: mappedPoint.y - 5.5, width: 11, height: 11)

        context.drawLayer { layer in
            layer.addFilter(.shadow(color: Color.orange.opacity(0.72), radius: 10, x: 0, y: 0))
            layer.stroke(
                Ellipse().path(in: outerRect),
                with: .color(Color.orange.opacity(0.95)),
                style: StrokeStyle(lineWidth: 2.4)
            )
            layer.fill(Ellipse().path(in: innerRect), with: .color(Color.orange.opacity(0.95)))
        }
    }

    private func syncFlowChainPoints(from frame: SwingFrame) -> [CGPoint] {
        var points: [CGPoint] = []

        if let base = garageSyncFlowBaseCenter(in: frame) {
            points.append(garageSkeletonMappedPoint(base, in: drawSize))
        }

        if let pelvis = garageSyncFlowMidpoint(.leftHip, .rightHip, in: frame) {
            points.append(garageSkeletonMappedPoint(pelvis, in: drawSize))
        }

        if let torso = garageSyncFlowMidpoint(.leftShoulder, .rightShoulder, in: frame) {
            points.append(garageSkeletonMappedPoint(torso, in: drawSize))
        }

        let hands = GarageAnalysisPipeline.handCenter(in: frame)
        if hands != .zero {
            points.append(garageSkeletonMappedPoint(hands, in: drawSize))
        }

        return points
    }
}

private func garageSkeletonMappedPoint(_ point: CGPoint, in size: CGSize) -> CGPoint {
    CGPoint(
        x: size.width * point.x,
        y: size.height * point.y
    )
}

private func garageSyncFlowMidpoint(
    _ left: SwingJointName,
    _ right: SwingJointName,
    in frame: SwingFrame
) -> CGPoint? {
    guard
        let leftPoint = frame.point(named: left, minimumConfidence: 0.2),
        let rightPoint = frame.point(named: right, minimumConfidence: 0.2)
    else {
        return nil
    }

    return CGPoint(x: (leftPoint.x + rightPoint.x) / 2, y: (leftPoint.y + rightPoint.y) / 2)
}

private func garageSyncFlowBaseCenter(in frame: SwingFrame) -> CGPoint? {
    guard
        let leftAnkle = frame.point(named: .leftAnkle, minimumConfidence: 0.2),
        let rightAnkle = frame.point(named: .rightAnkle, minimumConfidence: 0.2)
    else {
        return nil
    }

    return CGPoint(x: (leftAnkle.x + rightAnkle.x) / 2, y: (leftAnkle.y + rightAnkle.y) / 2)
}

private func garageSyncFlowPulsePoint(progress: Double, along points: [CGPoint]) -> CGPoint? {
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
