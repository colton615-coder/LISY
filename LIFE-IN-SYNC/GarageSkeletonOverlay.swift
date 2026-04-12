import SwiftUI

struct GarageSkeletonOverlay: View {
    let drawRect: CGRect
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
        .rightShoulder,
        .nose
    ]

    private static let emphasizedJoints: Set<SwingJointName> = [
        .nose,
        .leftShoulder,
        .rightShoulder,
        .leftHip,
        .rightHip
    ]

    var body: some View {
        Canvas { context, _ in
            guard
                drawRect.isEmpty == false,
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

                let startPoint = garageSkeletonMappedPoint(start, in: drawRect)
                let endPoint = garageSkeletonMappedPoint(end, in: drawRect)
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

            if
                let nose = currentFrame.point(named: .nose, minimumConfidence: 0.5),
                let leftShoulder = currentFrame.point(named: .leftShoulder, minimumConfidence: 0.5),
                let rightShoulder = currentFrame.point(named: .rightShoulder, minimumConfidence: 0.5)
            {
                let shoulderMidpoint = CGPoint(
                    x: (leftShoulder.x + rightShoulder.x) / 2,
                    y: (leftShoulder.y + rightShoulder.y) / 2
                )
                let startPoint = garageSkeletonMappedPoint(nose, in: drawRect)
                let endPoint = garageSkeletonMappedPoint(shoulderMidpoint, in: drawRect)
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
                    in: drawRect
                )
                let isEmphasized = Self.emphasizedJoints.contains(jointName)
                let radius = isEmphasized ? 6.5 : 5.0
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
                                radius: isEmphasized ? 6 : 4,
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

private func garageSkeletonMappedPoint(_ point: CGPoint, in rect: CGRect) -> CGPoint {
    CGPoint(
        x: rect.minX + (rect.width * point.x),
        y: rect.minY + (rect.height * point.y)
    )
}
