import SwiftUI

struct GarageSkeletonOverlay: View {
    let presentation: GarageOverlayPresentationState
    var onSelectMode: (GarageOverlayMode) -> Void = { _ in }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            GarageSkeletonOverlayCanvas(presentation: presentation)
                .equatable()
                .allowsHitTesting(false)

            GarageSkeletonHUDPanel(
                title: presentation.hud.title,
                detail: presentation.hud.detail,
                severity: presentation.hud.severity,
                overlayStatus: presentation.hud.primaryStatus,
                overlayMode: presentation.hud.mode,
                isModeToggleEnabled: presentation.hud.isModeToggleEnabled,
                onSelectMode: onSelectMode
            )
            .padding(12)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: presentation.mode)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: presentation.cleanCues)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: presentation.proJoints)
    }
}

private struct GarageSkeletonOverlayCanvas: View, Equatable {
    let presentation: GarageOverlayPresentationState

    static func == (lhs: GarageSkeletonOverlayCanvas, rhs: GarageSkeletonOverlayCanvas) -> Bool {
        lhs.presentation == rhs.presentation
    }

    var body: some View {
        Canvas { context, _ in
            drawCleanCues(in: &context)

            if presentation.mode == .pro {
                drawProSkeleton(in: &context)
                drawFlow(in: &context)
                drawMarkers(in: &context)
                drawLabels(in: &context)
            }
        }
    }

    private func drawCleanCues(in context: inout GraphicsContext) {
        for cue in presentation.cleanCues {
            guard cue.opacity > 0 else { continue }

            if let polyline = cue.polyline {
                drawPolyline(
                    polyline,
                    status: cue.status,
                    opacity: cue.opacity * 0.62,
                    in: &context
                )
            }

            if let line = cue.line {
                drawLine(line, status: cue.status, opacity: cue.opacity, in: &context)
            }

            if let halo = cue.halo {
                drawHalo(halo, status: cue.status, opacity: cue.opacity, in: &context)
            }
        }
    }

    private func drawProSkeleton(in context: inout GraphicsContext) {
        for segment in presentation.proSegments {
            drawLine(segment, status: .optimal, opacity: 0.58, in: &context)
        }

        if let proHeadHalo = presentation.proHeadHalo {
            drawHalo(proHeadHalo, status: .optimal, opacity: 0.50, in: &context)
        }

        for joint in presentation.proJoints {
            drawJoint(joint, in: &context)
        }
    }

    private func drawFlow(in context: inout GraphicsContext) {
        if let flowPath = presentation.flowPath {
            drawPolyline(flowPath, status: .optimal, opacity: 0.36, in: &context)
        }

        if let pulseMarker = presentation.pulseMarker {
            drawMarker(pulseMarker, in: &context)
        }
    }

    private func drawMarkers(in context: inout GraphicsContext) {
        if let issueMarker = presentation.issueMarker {
            drawMarker(issueMarker, in: &context)
        }
    }

    private func drawLabels(in context: inout GraphicsContext) {
        for label in presentation.labels {
            let text = Text(label.text)
                .font(.system(.caption2, design: .rounded).weight(.semibold))
                .foregroundStyle(label.status.tint.opacity(label.opacity))

            context.draw(text, at: label.anchor, anchor: .topLeading)
        }
    }

    private func drawLine(
        _ line: GarageOverlayLine,
        status: GarageOverlayMetricStatus,
        opacity: Double,
        in context: inout GraphicsContext
    ) {
        var path = Path()
        path.move(to: line.start)
        path.addLine(to: line.end)

        context.drawLayer { layer in
            layer.addFilter(.shadow(color: Color.black.opacity(0.62 * opacity), radius: 5, x: 0, y: 1))
            layer.stroke(
                path,
                with: .color(status.tint.opacity(0.24 * opacity)),
                style: StrokeStyle(lineWidth: line.outerWidth, lineCap: .round, lineJoin: .round)
            )
            layer.stroke(
                path,
                with: .color(status.tint.opacity(0.92 * opacity)),
                style: StrokeStyle(lineWidth: line.coreWidth, lineCap: .round, lineJoin: .round)
            )
        }
    }

    private func drawPolyline(
        _ polyline: GarageOverlayPolyline,
        status: GarageOverlayMetricStatus,
        opacity: Double,
        in context: inout GraphicsContext
    ) {
        guard let firstPoint = polyline.points.first, polyline.points.count >= 2 else {
            return
        }

        var path = Path()
        path.move(to: firstPoint)
        for point in polyline.points.dropFirst() {
            path.addLine(to: point)
        }

        context.drawLayer { layer in
            layer.addFilter(.shadow(color: Color.black.opacity(0.52 * opacity), radius: 5, x: 0, y: 1))
            layer.stroke(
                path,
                with: .color(status.tint.opacity(0.20 * opacity)),
                style: StrokeStyle(lineWidth: polyline.outerWidth, lineCap: .round, lineJoin: .round)
            )
            layer.stroke(
                path,
                with: .color(status.tint.opacity(0.82 * opacity)),
                style: StrokeStyle(lineWidth: polyline.coreWidth, lineCap: .round, lineJoin: .round)
            )
        }
    }

    private func drawHalo(
        _ halo: GarageOverlayHalo,
        status: GarageOverlayMetricStatus,
        opacity: Double,
        in context: inout GraphicsContext
    ) {
        let path = Ellipse().path(in: halo.rect)

        context.drawLayer { layer in
            layer.addFilter(.shadow(color: Color.black.opacity(0.54 * opacity), radius: 5, x: 0, y: 1))
            layer.stroke(
                path,
                with: .color(status.tint.opacity(0.18 * opacity)),
                style: StrokeStyle(lineWidth: halo.outerWidth, lineCap: .round, dash: halo.dash)
            )
            layer.stroke(
                path,
                with: .color(status.tint.opacity(0.84 * opacity)),
                style: StrokeStyle(lineWidth: halo.coreWidth, lineCap: .round, dash: halo.dash)
            )
        }
    }

    private func drawJoint(_ joint: GarageOverlayJoint, in context: inout GraphicsContext) {
        let rect = CGRect(
            x: joint.center.x - joint.radius,
            y: joint.center.y - joint.radius,
            width: joint.radius * 2,
            height: joint.radius * 2
        )

        context.drawLayer { layer in
            layer.addFilter(.shadow(color: joint.status.tint.opacity(0.52 * joint.opacity), radius: 4, x: 0, y: 0))
            layer.fill(
                Ellipse().path(in: rect.insetBy(dx: -2, dy: -2)),
                with: .color(Color.black.opacity(0.36 * joint.opacity))
            )
            layer.fill(
                Ellipse().path(in: rect),
                with: .color(joint.status.tint.opacity(0.92 * joint.opacity))
            )
        }
    }

    private func drawMarker(_ marker: GarageOverlayMarker, in context: inout GraphicsContext) {
        let outerRect = CGRect(
            x: marker.center.x - marker.outerRadius,
            y: marker.center.y - marker.outerRadius,
            width: marker.outerRadius * 2,
            height: marker.outerRadius * 2
        )
        let innerRect = CGRect(
            x: marker.center.x - marker.innerRadius,
            y: marker.center.y - marker.innerRadius,
            width: marker.innerRadius * 2,
            height: marker.innerRadius * 2
        )

        context.drawLayer { layer in
            layer.addFilter(.shadow(color: marker.status.tint.opacity(0.72 * marker.opacity), radius: 10, x: 0, y: 0))
            layer.stroke(
                Ellipse().path(in: outerRect),
                with: .color(marker.status.tint.opacity(0.95 * marker.opacity)),
                style: StrokeStyle(lineWidth: 2.2)
            )
            layer.fill(
                Ellipse().path(in: innerRect),
                with: .color(marker.status.tint.opacity(0.96 * marker.opacity))
            )
        }
    }
}

private enum GarageSkeletonOverlayPreviewFixture {
    static let drawSize = CGSize(width: 320, height: 460)

    static let frame = SwingFrame(
        timestamp: 0,
        joints: [
            SwingJoint(name: .nose, x: 0.50, y: 0.18, confidence: 0.95),
            SwingJoint(name: .leftShoulder, x: 0.41, y: 0.34, confidence: 0.96),
            SwingJoint(name: .rightShoulder, x: 0.59, y: 0.34, confidence: 0.96),
            SwingJoint(name: .leftElbow, x: 0.36, y: 0.48, confidence: 0.92),
            SwingJoint(name: .rightElbow, x: 0.55, y: 0.48, confidence: 0.92),
            SwingJoint(name: .leftWrist, x: 0.34, y: 0.64, confidence: 0.94),
            SwingJoint(name: .rightWrist, x: 0.42, y: 0.64, confidence: 0.94),
            SwingJoint(name: .leftHip, x: 0.45, y: 0.60, confidence: 0.95),
            SwingJoint(name: .rightHip, x: 0.55, y: 0.60, confidence: 0.95),
            SwingJoint(name: .leftKnee, x: 0.47, y: 0.78, confidence: 0.92),
            SwingJoint(name: .rightKnee, x: 0.57, y: 0.78, confidence: 0.92),
            SwingJoint(name: .leftAnkle, x: 0.47, y: 0.94, confidence: 0.90),
            SwingJoint(name: .rightAnkle, x: 0.57, y: 0.94, confidence: 0.90)
        ],
        confidence: 0.95
    )

    static let limitedFrame = SwingFrame(
        timestamp: 0,
        joints: [
            SwingJoint(name: .nose, x: 0.50, y: 0.18, confidence: 0.24),
            SwingJoint(name: .leftShoulder, x: 0.41, y: 0.34, confidence: 0.22),
            SwingJoint(name: .rightShoulder, x: 0.59, y: 0.34, confidence: 0.22)
        ],
        confidence: 0.26
    )

    static let keyFrames = [
        KeyFrame(phase: .address, frameIndex: 0),
        KeyFrame(phase: .impact, frameIndex: 0)
    ]

    static let scorecard = GarageSwingScorecard(
        timestamps: GarageSwingTimestamps(perspective: .dtl, start: 0, top: 0.4, impact: 0.8),
        metrics: GarageSwingMetrics(
            tempo: GarageTempoMetric(ratio: 3.0),
            spine: GarageSpineAngleMetric(deltaDegrees: 4.0),
            pelvicDepth: GaragePelvicDepthMetric(driftInches: 1.4),
            kneeFlex: GarageKneeFlexMetric(leftDeltaDegrees: 5, rightDeltaDegrees: 6),
            headStability: GarageHeadStabilityMetric(swayInches: 0.7, dipInches: 0.4)
        ),
        domainScores: [
            GarageSwingDomainScore(id: GarageSwingDomain.tempo.rawValue, title: "Tempo", score: 92, grade: .excellent, displayValue: "3.0 : 1"),
            GarageSwingDomainScore(id: GarageSwingDomain.spine.rawValue, title: "Spine", score: 88, grade: .excellent, displayValue: "4.0°"),
            GarageSwingDomainScore(id: GarageSwingDomain.pelvis.rawValue, title: "Pelvis", score: 82, grade: .good, displayValue: "1.4 in"),
            GarageSwingDomainScore(id: GarageSwingDomain.knee.rawValue, title: "Knee", score: 78, grade: .good, displayValue: "Left 5° / Right 6°"),
            GarageSwingDomainScore(id: GarageSwingDomain.head.rawValue, title: "Head", score: 90, grade: .excellent, displayValue: "Sway 0.7 in")
        ],
        totalScore: 86
    )

    static func presentation(mode: GarageOverlayMode) -> GarageOverlayPresentationState {
        GarageOverlayAdapter.makePresentation(
            mode: mode,
            drawSize: drawSize,
            frames: [frame],
            currentFrameIndex: 0,
            currentFrame: frame,
            keyFrames: keyFrames,
            currentTime: 0,
            pulseProgress: 0.7,
            scorecard: scorecard,
            syncFlow: nil
        )
    }

    static var limitedPresentation: GarageOverlayPresentationState {
        GarageOverlayAdapter.makePresentation(
            mode: .clean,
            drawSize: drawSize,
            frames: [limitedFrame],
            currentFrameIndex: 0,
            currentFrame: limitedFrame,
            keyFrames: [],
            currentTime: 0,
            pulseProgress: 0,
            scorecard: nil,
            syncFlow: nil
        )
    }
}

private struct GarageSkeletonOverlayPreviewSurface: View {
    let presentation: GarageOverlayPresentationState

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    garageReviewCanvasFill,
                    garageReviewSurfaceDark,
                    Color.black.opacity(0.82)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(0.22)
                .frame(width: 180, height: 360)
                .rotationEffect(.degrees(-7))

            GarageSkeletonOverlay(presentation: presentation)
        }
        .frame(width: GarageSkeletonOverlayPreviewFixture.drawSize.width, height: GarageSkeletonOverlayPreviewFixture.drawSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .padding()
        .background(Color.vibeBackground)
    }
}

#Preview("Garage Overlay Clean") {
    GarageSkeletonOverlayPreviewSurface(
        presentation: GarageSkeletonOverlayPreviewFixture.presentation(mode: .clean)
    )
}

#Preview("Garage Overlay Pro") {
    GarageSkeletonOverlayPreviewSurface(
        presentation: GarageSkeletonOverlayPreviewFixture.presentation(mode: .pro)
    )
}

#Preview("Garage Overlay Limited") {
    GarageSkeletonOverlayPreviewSurface(
        presentation: GarageSkeletonOverlayPreviewFixture.limitedPresentation
    )
}
