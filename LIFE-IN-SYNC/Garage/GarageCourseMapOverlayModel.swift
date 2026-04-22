import CoreGraphics
import SwiftUI

struct GarageCourseShotOverlayDescriptor: Identifiable, Equatable {
    let id: UUID
    let sequenceIndex: Int
    let clubTitle: String
    let shotTypeTitle: String
    let resultTitle: String
    let flightShape: GarageShotFlightShape
    let strikeQuality: GarageShotStrikeQuality
    let startPlacement: GarageShotPlacement
    let endPlacement: GarageShotPlacement

    var title: String {
        "Shot \(sequenceIndex) • \(clubTitle)"
    }

    var subtitle: String {
        "\(shotTypeTitle) • \(flightShape.title) • \(resultTitle)"
    }

    var detailLine: String {
        "\(strikeQuality.title) strike"
    }
}

enum GarageCourseMapOverlayRenderer {
    static func descriptors(for hole: GarageHoleMap) -> [GarageCourseShotOverlayDescriptor] {
        let sortedShots = hole.shots.sorted { lhs, rhs in
            if lhs.sequenceIndex != rhs.sequenceIndex {
                return lhs.sequenceIndex < rhs.sequenceIndex
            }
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }

        return sortedShots.enumerated().map { index, shot in
            let startPlacement: GarageShotPlacement
            if index > 0 {
                startPlacement = sortedShots[index - 1].placement
            } else if let teeAnchor = hole.teeAnchor {
                startPlacement = GarageShotPlacement(
                    normalizedX: teeAnchor.normalizedX,
                    normalizedY: teeAnchor.normalizedY
                )
            } else if let checkpoint = hole.fairwayCheckpointAnchor {
                startPlacement = GarageShotPlacement(
                    normalizedX: checkpoint.normalizedX,
                    normalizedY: checkpoint.normalizedY
                )
            } else {
                startPlacement = GarageShotPlacement(normalizedX: 0.5, normalizedY: 0.88)
            }

            return GarageCourseShotOverlayDescriptor(
                id: shot.id,
                sequenceIndex: shot.sequenceIndex,
                clubTitle: shot.club.title,
                shotTypeTitle: shot.shotType.title,
                resultTitle: shot.actualResult.title,
                flightShape: shot.flightShape,
                strikeQuality: shot.strikeQuality,
                startPlacement: startPlacement,
                endPlacement: shot.placement
            )
        }
    }

    static func point(for placement: GarageShotPlacement, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.minX + (rect.width * placement.normalizedX),
            y: rect.minY + (rect.height * placement.normalizedY)
        )
    }

    static func sequencePath(
        for descriptors: [GarageCourseShotOverlayDescriptor],
        in rect: CGRect
    ) -> Path {
        var path = Path()
        guard let first = descriptors.first else { return path }

        path.move(to: point(for: first.startPlacement, in: rect))
        for descriptor in descriptors {
            path.addLine(to: point(for: descriptor.endPlacement, in: rect))
        }
        return path
    }

    static func flightPath(
        for descriptor: GarageCourseShotOverlayDescriptor,
        in rect: CGRect
    ) -> Path {
        let start = point(for: descriptor.startPlacement, in: rect)
        let end = point(for: descriptor.endPlacement, in: rect)
        let vector = CGPoint(x: end.x - start.x, y: end.y - start.y)
        let distance = max(hypot(vector.x, vector.y), 1)
        let direction = CGPoint(x: vector.x / distance, y: vector.y / distance)
        let perpendicular = CGPoint(x: -direction.y, y: direction.x)
        let midpoint = CGPoint(x: (start.x + end.x) * 0.5, y: (start.y + end.y) * 0.5)

        let lateralBias: CGFloat
        switch descriptor.flightShape {
        case .straight:
            lateralBias = 0
        case .fade:
            lateralBias = min(distance * 0.08, rect.width * 0.08)
        case .draw:
            lateralBias = max(-distance * 0.08, -rect.width * 0.08)
        case .slice:
            lateralBias = min(distance * 0.16, rect.width * 0.12)
        case .hook:
            lateralBias = max(-distance * 0.16, -rect.width * 0.12)
        }

        let verticalLift: CGFloat
        switch descriptor.strikeQuality {
        case .pure:
            verticalLift = distance * 0.12
        case .thin, .skull:
            verticalLift = distance * 0.04
        case .fat, .chunk:
            verticalLift = distance * 0.18
        }

        let control = CGPoint(
            x: midpoint.x + (perpendicular.x * lateralBias),
            y: midpoint.y + (perpendicular.y * lateralBias) - verticalLift
        )

        var path = Path()
        path.move(to: start)
        path.addQuadCurve(to: end, control: control)
        return path
    }
}
