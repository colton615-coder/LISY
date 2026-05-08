import SwiftUI

enum GarageDrillDiagramType: Hashable {
    case netContact
    case netDelivery
    case rangeStartWindow
    case puttingGate
    case puttingPaceControl
    case general
}

struct GarageDrillDiagram: Hashable {
    let type: GarageDrillDiagramType
    let setupObjects: [GarageDrillDiagramObject]
    let motionArrows: [GarageDrillMotionArrow]
    let zones: [GarageDrillDiagramZone]
    let caption: String
}

struct GarageDiagramPoint: Hashable {
    let x: CGFloat
    let y: CGFloat
}

struct GarageDiagramSize: Hashable {
    let width: CGFloat
    let height: CGFloat
}

enum GarageDrillDiagramObjectKind: Hashable {
    case golferStance
    case ball
    case towel
    case targetLine
    case puttingGate
    case startLineWindow
    case landingZone
    case avoidZone
    case successZone
}

struct GarageDrillDiagramObject: Hashable {
    let kind: GarageDrillDiagramObjectKind
    let position: GarageDiagramPoint
    let size: GarageDiagramSize
    let angleDegrees: Double
    let label: String?
}

struct GarageDrillMotionArrow: Hashable {
    let start: GarageDiagramPoint
    let end: GarageDiagramPoint
    let label: String?
}

enum GarageDrillDiagramZoneKind: Hashable {
    case avoid
    case pass
    case landing
}

struct GarageDrillDiagramZone: Hashable {
    let kind: GarageDrillDiagramZoneKind
    let position: GarageDiagramPoint
    let size: GarageDiagramSize
    let angleDegrees: Double
    let label: String?
}

enum GarageDrillDiagramLibrary {
    static func diagram(
        for drill: PracticeTemplateDrill,
        environment: PracticeEnvironment
    ) -> GarageDrillDiagram {
        guard let canonicalDrill = DrillVault.canonicalDrill(for: drill) else {
            return fallbackDiagram(for: environment)
        }

        switch canonicalDrill.id {
        case "n1":
            return heavyTowelStrike
        case "n2":
            return splitHandDelivery
        case "n8":
            return trailHandBrush
        case "r10", "r11":
            return rangeStartLineWindow
        case "p3":
            return puttingGateStartLine
        case "p2", "p6":
            return puttingPaceControl
        default:
            return fallbackDiagram(for: canonicalDrill.environment)
        }
    }

    private static let heavyTowelStrike = GarageDrillDiagram(
        type: .netContact,
        setupObjects: [
            .golfer(at: .init(x: 0.25, y: 0.66)),
            .targetLine(from: .init(x: 0.3, y: 0.54), size: .init(width: 0.5, height: 0.02)),
            .towel(at: .init(x: 0.42, y: 0.55), angleDegrees: -2),
            .ball(at: .init(x: 0.62, y: 0.55))
        ],
        motionArrows: [
            .clubPath(from: .init(x: 0.28, y: 0.76), to: .init(x: 0.68, y: 0.47), label: "Brush after ball")
        ],
        zones: [
            .avoid(at: .init(x: 0.42, y: 0.55), size: .init(width: 0.28, height: 0.17), label: "Avoid towel"),
            .pass(at: .init(x: 0.7, y: 0.51), size: .init(width: 0.18, height: 0.12), label: "Clean strike")
        ],
        caption: "Set up like this: towel two inches behind the ball; pass if the strike misses the towel and finishes balanced."
    )

    private static let trailHandBrush = GarageDrillDiagram(
        type: .netContact,
        setupObjects: [
            .golfer(at: .init(x: 0.25, y: 0.67)),
            .targetLine(from: .init(x: 0.32, y: 0.56), size: .init(width: 0.52, height: 0.02)),
            .ball(at: .init(x: 0.58, y: 0.56))
        ],
        motionArrows: [
            .clubPath(from: .init(x: 0.29, y: 0.75), to: .init(x: 0.68, y: 0.54), label: "Trail-hand brush")
        ],
        zones: [
            .pass(at: .init(x: 0.66, y: 0.58), size: .init(width: 0.24, height: 0.12), label: "Brush point"),
            .avoid(at: .init(x: 0.47, y: 0.58), size: .init(width: 0.16, height: 0.1), label: "Early bottom")
        ],
        caption: "Set up like this: trail hand only, ball forward of the brush point, and a shallow path through the turf."
    )

    private static let splitHandDelivery = GarageDrillDiagram(
        type: .netDelivery,
        setupObjects: [
            .golfer(at: .init(x: 0.27, y: 0.66)),
            .targetLine(from: .init(x: 0.34, y: 0.55), size: .init(width: 0.5, height: 0.02)),
            .ball(at: .init(x: 0.58, y: 0.55)),
            .startLineWindow(at: .init(x: 0.75, y: 0.43), size: .init(width: 0.18, height: 0.25))
        ],
        motionArrows: [
            .clubPath(from: .init(x: 0.26, y: 0.74), to: .init(x: 0.65, y: 0.49), label: "Handle leads")
        ],
        zones: [
            .pass(at: .init(x: 0.63, y: 0.53), size: .init(width: 0.22, height: 0.12), label: "Forward handle"),
            .avoid(at: .init(x: 0.52, y: 0.63), size: .init(width: 0.17, height: 0.11), label: "Flip")
        ],
        caption: "Set up like this: split the hands on the grip and move waist-to-waist with the handle arriving first."
    )

    private static let rangeStartLineWindow = GarageDrillDiagram(
        type: .rangeStartWindow,
        setupObjects: [
            .golfer(at: .init(x: 0.19, y: 0.76)),
            .ball(at: .init(x: 0.28, y: 0.68)),
            .targetLine(from: .init(x: 0.32, y: 0.66), size: .init(width: 0.54, height: 0.018), angleDegrees: -24),
            .startLineWindow(at: .init(x: 0.58, y: 0.42), size: .init(width: 0.18, height: 0.24)),
            .landingZone(at: .init(x: 0.82, y: 0.28), size: .init(width: 0.22, height: 0.16), label: "Target")
        ],
        motionArrows: [
            .clubPath(from: .init(x: 0.24, y: 0.78), to: .init(x: 0.36, y: 0.62), label: "Launch")
        ],
        zones: [
            .pass(at: .init(x: 0.58, y: 0.42), size: .init(width: 0.2, height: 0.27), label: "Start window"),
            .landing(at: .init(x: 0.82, y: 0.28), size: .init(width: 0.24, height: 0.18), label: "Landing picture")
        ],
        caption: "Set up like this: choose one start window and judge the first part of flight before reacting to curve."
    )

    private static let puttingGateStartLine = GarageDrillDiagram(
        type: .puttingGate,
        setupObjects: [
            .golfer(at: .init(x: 0.18, y: 0.66)),
            .ball(at: .init(x: 0.3, y: 0.58)),
            .targetLine(from: .init(x: 0.33, y: 0.58), size: .init(width: 0.48, height: 0.014)),
            .puttingGate(at: .init(x: 0.47, y: 0.58), size: .init(width: 0.16, height: 0.28)),
            .startLineWindow(at: .init(x: 0.68, y: 0.58), size: .init(width: 0.14, height: 0.2)),
            .landingZone(at: .init(x: 0.82, y: 0.58), size: .init(width: 0.13, height: 0.13), label: "Hole")
        ],
        motionArrows: [
            .clubPath(from: .init(x: 0.24, y: 0.67), to: .init(x: 0.49, y: 0.58), label: "Quiet face")
        ],
        zones: [
            .pass(at: .init(x: 0.47, y: 0.58), size: .init(width: 0.18, height: 0.3), label: "Clean gate"),
            .avoid(at: .init(x: 0.47, y: 0.58), size: .init(width: 0.3, height: 0.42), label: "Tee contact")
        ],
        caption: "Set up like this: two tees just wider than the putter head, with the ball starting through the gate."
    )

    private static let puttingPaceControl = GarageDrillDiagram(
        type: .puttingPaceControl,
        setupObjects: [
            .golfer(at: .init(x: 0.18, y: 0.7)),
            .ball(at: .init(x: 0.29, y: 0.65)),
            .ball(at: .init(x: 0.35, y: 0.59), size: 0.052),
            .ball(at: .init(x: 0.41, y: 0.53), size: 0.052),
            .targetLine(from: .init(x: 0.32, y: 0.64), size: .init(width: 0.5, height: 0.014), angleDegrees: -16),
            .landingZone(at: .init(x: 0.78, y: 0.43), size: .init(width: 0.24, height: 0.18), label: "Stop zone")
        ],
        motionArrows: [
            .clubPath(from: .init(x: 0.24, y: 0.72), to: .init(x: 0.42, y: 0.55), label: "Same rhythm")
        ],
        zones: [
            .pass(at: .init(x: 0.78, y: 0.43), size: .init(width: 0.26, height: 0.2), label: "Pass zone"),
            .avoid(at: .init(x: 0.91, y: 0.36), size: .init(width: 0.1, height: 0.3), label: "Too long")
        ],
        caption: "Set up like this: roll multiple balls to one stop zone; pass if pace groups inside the finish window."
    )

    private static func fallbackDiagram(for environment: PracticeEnvironment) -> GarageDrillDiagram {
        switch environment {
        case .net:
            return GarageDrillDiagram(
                type: .general,
                setupObjects: [
                    .golfer(at: .init(x: 0.25, y: 0.68)),
                    .ball(at: .init(x: 0.55, y: 0.58)),
                    .targetLine(from: .init(x: 0.32, y: 0.58), size: .init(width: 0.46, height: 0.018)),
                    .startLineWindow(at: .init(x: 0.76, y: 0.45), size: .init(width: 0.2, height: 0.28))
                ],
                motionArrows: [
                    .clubPath(from: .init(x: 0.27, y: 0.76), to: .init(x: 0.64, y: 0.53), label: nil)
                ],
                zones: [
                    .pass(at: .init(x: 0.65, y: 0.55), size: .init(width: 0.22, height: 0.14), label: "Pass zone")
                ],
                caption: "Set up like this: keep the goal narrow, use the assigned club, and count only clear reps."
            )
        case .range:
            return rangeStartLineWindow
        case .puttingGreen:
            return puttingGateStartLine
        }
    }
}

struct GarageDrillDiagramView: View {
    let diagram: GarageDrillDiagram

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                GarageDiagramBackground(type: diagram.type)

                ForEach(diagram.zones.indices, id: \.self) { index in
                    GarageDiagramZonePrimitive(zone: diagram.zones[index])
                        .frame(
                            width: size.width * diagram.zones[index].size.width,
                            height: size.height * diagram.zones[index].size.height
                        )
                        .rotationEffect(.degrees(diagram.zones[index].angleDegrees))
                        .position(point(diagram.zones[index].position, in: size))
                }

                ForEach(diagram.setupObjects.indices, id: \.self) { index in
                    GarageDiagramObjectPrimitive(object: diagram.setupObjects[index])
                        .frame(
                            width: size.width * diagram.setupObjects[index].size.width,
                            height: size.height * diagram.setupObjects[index].size.height
                        )
                        .rotationEffect(.degrees(diagram.setupObjects[index].angleDegrees))
                        .position(point(diagram.setupObjects[index].position, in: size))
                }

                ForEach(diagram.motionArrows.indices, id: \.self) { index in
                    GarageClubPathArrowPrimitive(arrow: diagram.motionArrows[index], canvasSize: size)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(diagram.caption)
    }

    private func point(_ point: GarageDiagramPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: size.width * point.x, y: size.height * point.y)
    }
}

private struct GarageDiagramBackground: View {
    let type: GarageDrillDiagramType

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 0.012, green: 0.04, blue: 0.028))

            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.25, blue: 0.15).opacity(0.72),
                    Color(red: 0.012, green: 0.04, blue: 0.028).opacity(0.98),
                    Color.black.opacity(0.42)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color(red: 0.18, green: 0.9, blue: 0.42).opacity(0.16))
                .frame(width: 260, height: 260)
                .blur(radius: 64)
                .offset(x: -120, y: -70)

            if type == .puttingGate || type == .puttingPaceControl {
                GaragePuttingGrainLines()
            } else {
                GarageRangeDepthLines()
            }
        }
    }
}

private struct GaragePuttingGrainLines: View {
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            Path { path in
                for offset in stride(from: -height, through: height * 1.6, by: 22) {
                    path.move(to: CGPoint(x: 0, y: offset))
                    path.addLine(to: CGPoint(x: width, y: offset + height * 0.35))
                }
            }
            .stroke(GarageProTheme.textSecondary.opacity(0.09), lineWidth: 1)
        }
    }
}

private struct GarageRangeDepthLines: View {
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            Path { path in
                for yValue in [0.32, 0.48, 0.64, 0.8] {
                    path.move(to: CGPoint(x: width * 0.08, y: height * yValue))
                    path.addLine(to: CGPoint(x: width * 0.92, y: height * (yValue - 0.08)))
                }
            }
            .stroke(GarageProTheme.textSecondary.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [6, 8]))
        }
    }
}

private struct GarageDiagramObjectPrimitive: View {
    let object: GarageDrillDiagramObject

    var body: some View {
        switch object.kind {
        case .golferStance:
            GarageGolferStanceMarker()
        case .ball:
            GarageBallPrimitive()
        case .towel:
            GarageTowelPrimitive(label: object.label)
        case .targetLine:
            GarageTargetLinePrimitive()
        case .puttingGate:
            GaragePuttingGatePrimitive()
        case .startLineWindow:
            GarageStartLineWindowPrimitive(label: object.label)
        case .landingZone:
            GarageLandingZonePrimitive(label: object.label)
        case .avoidZone:
            GarageDiagramZonePrimitive(zone: .avoid(at: object.position, size: object.size, label: object.label))
        case .successZone:
            GarageDiagramZonePrimitive(zone: .pass(at: object.position, size: object.size, label: object.label))
        }
    }
}

private struct GarageGolferStanceMarker: View {
    var body: some View {
        ZStack {
            Capsule(style: .continuous)
                .fill(Color(red: 0.24, green: 0.96, blue: 0.5).opacity(0.72))
                .frame(width: 12, height: 46)
                .offset(x: -13, y: 15)
                .rotationEffect(.degrees(-8))

            Capsule(style: .continuous)
                .fill(Color(red: 0.24, green: 0.96, blue: 0.5).opacity(0.72))
                .frame(width: 12, height: 46)
                .offset(x: 13, y: 15)
                .rotationEffect(.degrees(8))

            Image(systemName: "figure.golf")
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(Color(red: 0.24, green: 0.96, blue: 0.5))
                .shadow(color: Color(red: 0.24, green: 0.96, blue: 0.5).opacity(0.36), radius: 10)
                .offset(y: -16)
        }
    }
}

private struct GarageBallPrimitive: View {
    var body: some View {
        Circle()
            .fill(GarageProTheme.textPrimary)
            .overlay(
                Circle()
                    .stroke(GarageProTheme.accent.opacity(0.55), lineWidth: 2)
            )
            .shadow(color: GarageProTheme.glow.opacity(0.22), radius: 8)
    }
}

private struct GarageTowelPrimitive: View {
    let label: String?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color.white.opacity(0.84))
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(Color.white.opacity(0.55), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                )
                .shadow(color: Color.white.opacity(0.18), radius: 10)

            if let label {
                Text(label)
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .textCase(.uppercase)
                    .tracking(0.9)
                    .foregroundStyle(GarageProTheme.textPrimary.opacity(0.7))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .padding(.horizontal, 4)
            }
        }
    }
}

private struct GarageTargetLinePrimitive: View {
    var body: some View {
        Capsule(style: .continuous)
            .fill(GarageProTheme.accent.opacity(0.46))
            .overlay(
                Capsule(style: .continuous)
                    .stroke(GarageProTheme.textPrimary.opacity(0.24), lineWidth: 1)
            )
            .shadow(color: GarageProTheme.glow.opacity(0.2), radius: 8)
    }
}

private struct GaragePuttingGatePrimitive: View {
    var body: some View {
        HStack {
            Capsule(style: .continuous)
                .fill(GarageProTheme.textPrimary.opacity(0.82))

            Spacer(minLength: 0)

            Capsule(style: .continuous)
                .fill(GarageProTheme.textPrimary.opacity(0.82))
        }
        .padding(.horizontal, 8)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(GarageProTheme.accent.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
        )
    }
}

private struct GarageStartLineWindowPrimitive: View {
    let label: String?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(GarageProTheme.accent.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(GarageProTheme.accent.opacity(0.74), style: StrokeStyle(lineWidth: 3, dash: [8, 7]))
                )

            if let label {
                GarageDiagramLabel(label)
            }
        }
    }
}

private struct GarageLandingZonePrimitive: View {
    let label: String?

    var body: some View {
        ZStack {
            Ellipse()
                .fill(GarageProTheme.accent.opacity(0.13))
                .overlay(
                    Ellipse()
                        .stroke(GarageProTheme.accent.opacity(0.56), style: StrokeStyle(lineWidth: 2, dash: [7, 6]))
                )

            Image(systemName: "flag.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(GarageProTheme.accent)

            if let label {
                GarageDiagramLabel(label)
                    .offset(y: 28)
            }
        }
    }
}

private struct GarageDiagramZonePrimitive: View {
    let zone: GarageDrillDiagramZone

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(fillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(strokeColor, style: StrokeStyle(lineWidth: 2, dash: [7, 6]))
                )

            if let label = zone.label {
                GarageDiagramLabel(label)
            }
        }
    }

    private var fillColor: Color {
        switch zone.kind {
        case .avoid:
            return Color.red.opacity(0.16)
        case .pass:
            return GarageProTheme.accent.opacity(0.14)
        case .landing:
            return GarageProTheme.textPrimary.opacity(0.08)
        }
    }

    private var strokeColor: Color {
        switch zone.kind {
        case .avoid:
            return Color.red.opacity(0.5)
        case .pass:
            return GarageProTheme.accent.opacity(0.62)
        case .landing:
            return GarageProTheme.textSecondary.opacity(0.44)
        }
    }
}

private struct GarageClubPathArrowPrimitive: View {
    let arrow: GarageDrillMotionArrow
    let canvasSize: CGSize

    var body: some View {
        let start = point(arrow.start)
        let end = point(arrow.end)
        let angle = Angle(radians: Double(atan2(end.y - start.y, end.x - start.x)))

        ZStack {
            Path { path in
                path.move(to: start)
                path.addLine(to: end)
            }
            .stroke(Color(red: 1.0, green: 0.78, blue: 0.22), style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [12, 8]))
            .shadow(color: Color(red: 1.0, green: 0.78, blue: 0.22).opacity(0.32), radius: 10)

            Image(systemName: "arrowtriangle.right.fill")
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(Color(red: 1.0, green: 0.78, blue: 0.22))
                .rotationEffect(angle)
                .position(end)

            if let label = arrow.label {
                GarageDiagramLabel(label)
                    .position(CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2 - 18))
            }
        }
    }

    private func point(_ point: GarageDiagramPoint) -> CGPoint {
        CGPoint(x: canvasSize.width * point.x, y: canvasSize.height * point.y)
    }
}

private struct GarageDiagramLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .black, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.58)
            .foregroundStyle(GarageProTheme.textPrimary)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(.thinMaterial, in: Capsule(style: .continuous))
            .overlay(
                Capsule(style: .continuous)
                    .stroke(GarageProTheme.border, lineWidth: 1)
            )
    }
}

private extension GarageDrillDiagramObject {
    static func golfer(at position: GarageDiagramPoint) -> GarageDrillDiagramObject {
        GarageDrillDiagramObject(
            kind: .golferStance,
            position: position,
            size: .init(width: 0.2, height: 0.34),
            angleDegrees: 0,
            label: nil
        )
    }

    static func ball(at position: GarageDiagramPoint, size: CGFloat = 0.06) -> GarageDrillDiagramObject {
        GarageDrillDiagramObject(
            kind: .ball,
            position: position,
            size: .init(width: size, height: size),
            angleDegrees: 0,
            label: nil
        )
    }

    static func towel(at position: GarageDiagramPoint, angleDegrees: Double = 0) -> GarageDrillDiagramObject {
        GarageDrillDiagramObject(
            kind: .towel,
            position: position,
            size: .init(width: 0.3, height: 0.07),
            angleDegrees: angleDegrees,
            label: "Towel"
        )
    }

    static func targetLine(
        from position: GarageDiagramPoint,
        size: GarageDiagramSize,
        angleDegrees: Double = 0
    ) -> GarageDrillDiagramObject {
        GarageDrillDiagramObject(
            kind: .targetLine,
            position: position,
            size: size,
            angleDegrees: angleDegrees,
            label: nil
        )
    }

    static func puttingGate(
        at position: GarageDiagramPoint,
        size: GarageDiagramSize
    ) -> GarageDrillDiagramObject {
        GarageDrillDiagramObject(
            kind: .puttingGate,
            position: position,
            size: size,
            angleDegrees: 0,
            label: nil
        )
    }

    static func startLineWindow(
        at position: GarageDiagramPoint,
        size: GarageDiagramSize
    ) -> GarageDrillDiagramObject {
        GarageDrillDiagramObject(
            kind: .startLineWindow,
            position: position,
            size: size,
            angleDegrees: 0,
            label: nil
        )
    }

    static func landingZone(
        at position: GarageDiagramPoint,
        size: GarageDiagramSize,
        label: String?
    ) -> GarageDrillDiagramObject {
        GarageDrillDiagramObject(
            kind: .landingZone,
            position: position,
            size: size,
            angleDegrees: 0,
            label: label
        )
    }
}

private extension GarageDrillMotionArrow {
    static func clubPath(
        from start: GarageDiagramPoint,
        to end: GarageDiagramPoint,
        label: String?
    ) -> GarageDrillMotionArrow {
        GarageDrillMotionArrow(start: start, end: end, label: label)
    }
}

private extension GarageDrillDiagramZone {
    static func avoid(
        at position: GarageDiagramPoint,
        size: GarageDiagramSize,
        angleDegrees: Double = 0,
        label: String?
    ) -> GarageDrillDiagramZone {
        GarageDrillDiagramZone(
            kind: .avoid,
            position: position,
            size: size,
            angleDegrees: angleDegrees,
            label: label
        )
    }

    static func pass(
        at position: GarageDiagramPoint,
        size: GarageDiagramSize,
        angleDegrees: Double = 0,
        label: String?
    ) -> GarageDrillDiagramZone {
        GarageDrillDiagramZone(
            kind: .pass,
            position: position,
            size: size,
            angleDegrees: angleDegrees,
            label: label
        )
    }

    static func landing(
        at position: GarageDiagramPoint,
        size: GarageDiagramSize,
        angleDegrees: Double = 0,
        label: String?
    ) -> GarageDrillDiagramZone {
        GarageDrillDiagramZone(
            kind: .landing,
            position: position,
            size: size,
            angleDegrees: angleDegrees,
            label: label
        )
    }
}
