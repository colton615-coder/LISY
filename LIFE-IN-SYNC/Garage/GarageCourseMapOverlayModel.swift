import Combine
import CoreGraphics
import Foundation
import SwiftUI
import UIKit

enum GarageCourseMapOverlayDragTarget: Equatable {
    case shot(UUID?)
    case anchor(GarageMapAnchorKind)
}

struct GarageCourseCalibrationAnchorDescriptor: Identifiable, Equatable {
    let kind: GarageMapAnchorKind
    let title: String
    let anchor: GarageMapAnchor?
    let point: CGPoint?
    let isActive: Bool

    var id: GarageMapAnchorKind { kind }

    var isPlaced: Bool {
        anchor != nil
    }
}

struct GarageCourseMapPrecisionReadout: Equatable {
    let normalizedX: Double
    let normalizedY: Double

    var formattedX: String {
        Self.format(normalizedX)
    }

    var formattedY: String {
        Self.format(normalizedY)
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.3f", value)
    }
}

@MainActor
final class GarageCourseMapOverlayModel: ObservableObject {
    @Published private(set) var selectedShotID: UUID?
    @Published private(set) var activeDragTarget: GarageCourseMapOverlayDragTarget?
    @Published private(set) var activeShotPlacement: GarageShotPlacement?
    @Published private(set) var activeAnchor: GarageMapAnchor?
    @Published private(set) var isInteracting = false

    private var shotDragOriginPlacement: GarageShotPlacement?
    private var anchorDragOrigin: GarageMapAnchor?

    var isDraggingShot: Bool {
        guard case .shot = activeDragTarget else { return false }
        return isInteracting
    }

    var isDraggingAnchor: Bool {
        guard case .anchor = activeDragTarget else { return false }
        return isInteracting
    }

    var activeShotReadout: GarageCourseMapPrecisionReadout? {
        precisionReadout(for: activeShotPlacement)
    }

    var activeAnchorReadout: GarageCourseMapPrecisionReadout? {
        precisionReadout(for: activeAnchor)
    }

    func selectShot(_ shotID: UUID?) {
        selectedShotID = shotID
    }

    func clearSelection() {
        selectedShotID = nil
    }

    func syncDraftPlacement(_ placement: GarageShotPlacement?) {
        activeShotPlacement = placement
    }

    func clearDraftPlacement() {
        activeShotPlacement = nil
    }

    func beginShotDrag(initialPlacement: GarageShotPlacement, shotID: UUID?) {
        shotDragOriginPlacement = initialPlacement
        activeShotPlacement = initialPlacement
        activeDragTarget = .shot(shotID)
        isInteracting = true
    }

    func updateShotDrag(location: CGPoint, in rect: CGRect) -> GarageShotPlacement? {
        guard case .shot = activeDragTarget else { return nil }
        let placement = Self.placement(from: location, in: rect)
        activeShotPlacement = placement
        return placement
    }

    func updateShotDrag(translation: CGSize, in rect: CGRect) -> GarageShotPlacement? {
        guard let originPlacement = shotDragOriginPlacement else { return nil }
        let origin = Self.point(for: originPlacement, in: rect)
        return updateShotDrag(
            location: CGPoint(
                x: origin.x + translation.width,
                y: origin.y + translation.height
            ),
            in: rect
        )
    }

    func placeShot(at location: CGPoint, shotID: UUID?, in rect: CGRect) -> GarageShotPlacement {
        let placement = Self.placement(from: location, in: rect)
        activeDragTarget = .shot(shotID)
        activeShotPlacement = placement
        return placement
    }

    func endShotDrag() -> GarageShotPlacement? {
        let placement = activeShotPlacement
        shotDragOriginPlacement = nil
        activeDragTarget = nil
        isInteracting = false
        return placement
    }

    func beginAnchorDrag(_ anchor: GarageMapAnchor) {
        anchorDragOrigin = anchor
        activeAnchor = anchor
        activeDragTarget = .anchor(anchor.kind)
        isInteracting = true
    }

    func updateAnchorDrag(location: CGPoint, kind: GarageMapAnchorKind, in rect: CGRect) -> GarageMapAnchor? {
        guard activeDragTarget == .anchor(kind) else { return nil }
        let anchor = Self.anchor(kind: kind, at: location, in: rect)
        activeAnchor = anchor
        return anchor
    }

    func updateAnchorDrag(translation: CGSize, kind: GarageMapAnchorKind, in rect: CGRect) -> GarageMapAnchor? {
        guard let originAnchor = anchorDragOrigin, originAnchor.kind == kind else { return nil }
        let origin = Self.point(for: originAnchor, in: rect)
        return updateAnchorDrag(
            location: CGPoint(
                x: origin.x + translation.width,
                y: origin.y + translation.height
            ),
            kind: kind,
            in: rect
        )
    }

    func placeAnchor(kind: GarageMapAnchorKind, at location: CGPoint, in rect: CGRect) -> GarageMapAnchor {
        let anchor = Self.anchor(kind: kind, at: location, in: rect)
        activeAnchor = anchor
        activeDragTarget = .anchor(kind)
        return anchor
    }

    func endAnchorDrag() -> GarageMapAnchor? {
        let anchor = activeAnchor
        anchorDragOrigin = nil
        activeDragTarget = nil
        isInteracting = false
        return anchor
    }

    func isDragging(shotID: UUID?) -> Bool {
        guard case let .shot(activeShotID) = activeDragTarget else { return false }
        return isInteracting && activeShotID == shotID
    }

    func isDragging(kind: GarageMapAnchorKind) -> Bool {
        guard case let .anchor(activeKind) = activeDragTarget else { return false }
        return isInteracting && activeKind == kind
    }

    func precisionReadout(for placement: GarageShotPlacement?) -> GarageCourseMapPrecisionReadout? {
        guard let placement else { return nil }
        return GarageCourseMapPrecisionReadout(
            normalizedX: placement.normalizedX,
            normalizedY: placement.normalizedY
        )
    }

    func precisionReadout(for anchor: GarageMapAnchor?) -> GarageCourseMapPrecisionReadout? {
        guard let anchor else { return nil }
        return GarageCourseMapPrecisionReadout(
            normalizedX: anchor.normalizedX,
            normalizedY: anchor.normalizedY
        )
    }

    func calibrationAnchorDescriptors(
        teeAnchor: GarageMapAnchor?,
        fairwayCheckpointAnchor: GarageMapAnchor?,
        greenCenterAnchor: GarageMapAnchor?,
        activeKind: GarageMapAnchorKind,
        in rect: CGRect
    ) -> [GarageCourseCalibrationAnchorDescriptor] {
        GarageMapAnchorKind.allCases.map { kind in
            let anchor = switch kind {
            case .tee:
                teeAnchor
            case .fairwayCheckpoint:
                fairwayCheckpointAnchor
            case .greenCenter:
                greenCenterAnchor
            }

            return GarageCourseCalibrationAnchorDescriptor(
                kind: kind,
                title: kind.title,
                anchor: anchor,
                point: anchor.map { Self.point(for: $0, in: rect) },
                isActive: kind == activeKind
            )
        }
    }

    static func placement(from location: CGPoint, in rect: CGRect) -> GarageShotPlacement {
        let width = max(rect.width, 1)
        let height = max(rect.height, 1)
        let normalizedX = min(max((location.x - rect.minX) / width, 0), 1)
        let normalizedY = min(max((location.y - rect.minY) / height, 0), 1)
        return GarageShotPlacement(normalizedX: normalizedX, normalizedY: normalizedY)
    }

    static func anchor(kind: GarageMapAnchorKind, at location: CGPoint, in rect: CGRect) -> GarageMapAnchor {
        let placement = placement(from: location, in: rect)
        return GarageMapAnchor(
            kind: kind,
            normalizedX: placement.normalizedX,
            normalizedY: placement.normalizedY
        )
    }

    static func point(for placement: GarageShotPlacement, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.minX + (rect.width * placement.normalizedX),
            y: rect.minY + (rect.height * placement.normalizedY)
        )
    }

    static func point(for anchor: GarageMapAnchor, in rect: CGRect) -> CGPoint {
        point(
            for: GarageShotPlacement(
                normalizedX: anchor.normalizedX,
                normalizedY: anchor.normalizedY
            ),
            in: rect
        )
    }
}

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
        GarageCourseMapOverlayModel.point(for: placement, in: rect)
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

func garageLoadCourseMapImage(at localAssetPath: String?) -> UIImage? {
    guard
        let localAssetPath,
        FileManager.default.fileExists(atPath: localAssetPath),
        let image = UIImage(contentsOfFile: localAssetPath)
    else {
        return nil
    }

    return image
}

func garageAspectFitRect(container: CGSize, aspectRatio: CGFloat) -> CGRect {
    guard container.width > 0, container.height > 0, aspectRatio > 0 else {
        return CGRect(origin: .zero, size: container)
    }

    let containerAspectRatio = container.width / container.height
    let size: CGSize
    if containerAspectRatio > aspectRatio {
        let height = container.height
        size = CGSize(width: height * aspectRatio, height: height)
    } else {
        let width = container.width
        size = CGSize(width: width, height: width / aspectRatio)
    }

    return CGRect(
        x: (container.width - size.width) * 0.5,
        y: (container.height - size.height) * 0.5,
        width: size.width,
        height: size.height
    )
}
