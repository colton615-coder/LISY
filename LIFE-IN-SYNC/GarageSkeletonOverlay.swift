import SwiftUI

struct GarageSkeletonOverlay: View {
    let drawSize: CGSize
    let currentFrame: SwingFrame?

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

    var body: some View {
        Canvas { context, _ in
            guard
                drawSize.width > 0,
                drawSize.height > 0,
                let currentFrame
            else {
                return
            }

            for (startName, endName) in Self.skeletonLinks {
                guard
                    let start = currentFrame.point(named: startName, minimumConfidence: 0.5),
                    let end = currentFrame.point(named: endName, minimumConfidence: 0.5)
                else {
                    continue
                }

                let startPoint = garageSkeletonMappedPoint(start, in: drawSize)
                let endPoint = garageSkeletonMappedPoint(end, in: drawSize)
                var path = Path()
                path.move(to: startPoint)
                path.addLine(to: endPoint)

                context.stroke(
                    path,
                    with: .linearGradient(
                        Gradient(colors: [
                            ModuleTheme.garageTextPrimary.opacity(0.18),
                            ModuleTheme.electricCyan.opacity(0.22)
                        ]),
                        startPoint: startPoint,
                        endPoint: endPoint
                    ),
                    style: StrokeStyle(lineWidth: 2.1, lineCap: .round, lineJoin: .round)
                )
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
                    with: .color(ModuleTheme.electricCyan.opacity(0.58)),
                    style: StrokeStyle(lineWidth: 1.8)
                )
                context.fill(
                    Ellipse().path(in: circleRect),
                    with: .color(ModuleTheme.electricCyan.opacity(0.08))
                )
            }

            if
                let nose = currentFrame.point(named: .nose, minimumConfidence: 0.5),
                let leftShoulder = currentFrame.point(named: .leftShoulder, minimumConfidence: 0.5),
                let rightShoulder = currentFrame.point(named: .rightShoulder, minimumConfidence: 0.5)
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
                    with: .color(ModuleTheme.electricCyan.opacity(0.26)),
                    style: StrokeStyle(lineWidth: 1.8, lineCap: .round)
                )
            }

            for jointName in Self.renderOrder {
                guard
                    let joint = currentFrame.joint(named: jointName),
                    joint.confidence >= 0.5
                else {
                    continue
                }

                let mappedPoint = garageSkeletonMappedPoint(
                    CGPoint(x: joint.x, y: joint.y),
                    in: drawSize
                )
                let isEmphasized = Self.emphasizedJoints.contains(jointName)
                let radius = isEmphasized ? 5.0 : 3.6
                let circleRect = CGRect(
                    x: mappedPoint.x - radius,
                    y: mappedPoint.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )

                if joint.confidence >= 0.8 {
                    context.drawLayer { layer in
                        layer.addFilter(
                            .shadow(
                                color: ModuleTheme.electricCyan.opacity(isEmphasized ? 0.65 : 0.45),
                                radius: isEmphasized ? 4 : 2.5,
                                x: 0,
                                y: 0
                            )
                        )
                        layer.fill(
                            Ellipse().path(in: circleRect),
                            with: .color(ModuleTheme.electricCyan)
                        )
                    }
                } else {
                    context.fill(
                        Ellipse().path(in: circleRect),
                        with: .color(Color(red: 0.72, green: 0.84, blue: 0.89).opacity(0.72))
                    )
                }
            }
        }
    }
}

private func garageSkeletonMappedPoint(_ point: CGPoint, in size: CGSize) -> CGPoint {
    CGPoint(
        x: size.width * point.x,
        y: size.height * point.y
    )
}
