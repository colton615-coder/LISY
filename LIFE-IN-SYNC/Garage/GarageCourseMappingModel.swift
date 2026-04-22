import Combine
import CoreLocation
import Foundation
import MapKit
import SwiftUI

struct GarageMapCoordinate: Hashable, Codable {
    let latitude: Double
    let longitude: Double

    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct GarageCourseRegion: Hashable, Codable {
    let center: GarageMapCoordinate
    let latitudinalMeters: CLLocationDistance
    let longitudinalMeters: CLLocationDistance

    var mkRegion: MKCoordinateRegion {
        MKCoordinateRegion(
            center: center.clCoordinate,
            latitudinalMeters: latitudinalMeters,
            longitudinalMeters: longitudinalMeters
        )
    }
}

struct GarageCourseAssetDescriptor: Equatable {
    let sourceType: GarageHoleSourceType
    let sourceReference: String
    let localAssetPath: String?
    let imagePixelWidth: Double
    let imagePixelHeight: Double
}

struct GarageCourseMetadata: Equatable {
    let courseName: String
    let holeLabel: String
    let holeName: String
    let par: Int
    let yardageLabel: String
    let playerIntent: String
    let contextNote: String
    let dominantWind: String
    let region: GarageCourseRegion
    let assetDescriptor: GarageCourseAssetDescriptor?
}

enum GarageCourseNodeKind: String, CaseIterable, Codable, Identifiable {
    case tee
    case checkpoint
    case layup
    case landingZone
    case hazard
    case target

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .tee:
            "flag.pattern.checkered.2.crossed"
        case .checkpoint:
            "scope"
        case .layup:
            "arrow.turn.down.right"
        case .landingZone:
            "smallcircle.filled.circle"
        case .hazard:
            "exclamationmark.triangle.fill"
        case .target:
            "flag.fill"
        }
    }

    var isPrimaryNode: Bool {
        switch self {
        case .tee, .target:
            true
        case .checkpoint, .layup, .landingZone, .hazard:
            false
        }
    }
}

struct GarageCourseNode: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let kind: GarageCourseNodeKind
    let coordinate: GarageMapCoordinate
    let distanceLabel: String?
}

struct GarageCourseRouteStats: Equatable {
    let totalYardage: Int
    let carryYardage: Int
    let hazardCount: Int
    let nodeCount: Int
    let expectedClub: String
}

struct GarageCourseRoute: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let coordinates: [GarageMapCoordinate]
    let nodes: [GarageCourseNode]
    let stats: GarageCourseRouteStats
    let isPrimary: Bool
    let cameraRegion: GarageCourseRegion?
}

@MainActor
final class GarageCourseMappingModel: ObservableObject {
    @Published var metadata: GarageCourseMetadata
    @Published var routes: [GarageCourseRoute]
    @Published var activeRouteID: String
    @Published var selectedNodeID: String?
    @Published var cameraPosition: MapCameraPosition

    init(
        metadata: GarageCourseMetadata,
        routes: [GarageCourseRoute],
        activeRouteID: String? = nil,
        selectedNodeID: String? = nil
    ) {
        let resolvedRouteID = activeRouteID ?? routes.first(where: \.isPrimary)?.id ?? routes.first?.id ?? ""

        self.metadata = metadata
        self.routes = routes
        self.activeRouteID = resolvedRouteID
        self.selectedNodeID = selectedNodeID
        self.cameraPosition = MapCameraPosition.region(metadata.region.mkRegion)

        if self.selectedNodeID == nil {
            self.selectedNodeID = activeRoute?.nodes.first(where: { $0.kind.isPrimaryNode })?.id ?? activeRoute?.nodes.first?.id
        }

        focusActiveRoute()
    }

    var activeRoute: GarageCourseRoute? {
        routes.first(where: { $0.id == activeRouteID }) ?? routes.first
    }

    var selectedNode: GarageCourseNode? {
        activeRoute?.nodes.first(where: { $0.id == selectedNodeID })
    }

    var headline: String {
        "\(metadata.holeLabel) • Par \(metadata.par)"
    }

    var activeSummary: String {
        guard let activeRoute else {
            return metadata.playerIntent
        }

        return "\(activeRoute.stats.totalYardage) yd • \(activeRoute.stats.expectedClub) • \(metadata.dominantWind)"
    }

    func selectRoute(_ routeID: String) {
        guard routes.contains(where: { $0.id == routeID }) else { return }
        activeRouteID = routeID
        selectedNodeID = activeRoute?.nodes.first(where: { $0.kind.isPrimaryNode })?.id ?? activeRoute?.nodes.first?.id
        focusActiveRoute()
    }

    func selectNode(_ nodeID: String?) {
        selectedNodeID = nodeID
    }

    func focusActiveRoute() {
        let region = activeRoute?.cameraRegion ?? metadata.region
        cameraPosition = MapCameraPosition.region(region.mkRegion)
    }
}

extension GarageCourseMappingModel {
    static var preview: GarageCourseMappingModel {
        let region = GarageCourseRegion(
            center: GarageMapCoordinate(latitude: 36.5686, longitude: -121.9503),
            latitudinalMeters: 880,
            longitudinalMeters: 880
        )

        let metadata = GarageCourseMetadata(
            courseName: "North Ridge Links",
            holeLabel: "Hole 14",
            holeName: "Cliffside Splitter",
            par: 4,
            yardageLabel: "434",
            playerIntent: "Survey the safest aggressive line before committing to the tee shape.",
            contextNote: "Course Mapping is now the Garage environmental routing seam. Keep the surface tactical, compact, and local-first.",
            dominantWind: "Wind NNE 8 mph",
            region: region,
            assetDescriptor: GarageCourseAssetDescriptor(
                sourceType: .assistedWebImport,
                sourceReference: "https://example.com/courses/north-ridge-links/hole-14",
                localAssetPath: nil,
                imagePixelWidth: 1668,
                imagePixelHeight: 2388
            )
        )

        let primaryRoute = GarageCourseRoute(
            id: "primary-line",
            title: "Primary Line",
            subtitle: "Aggressive center-right window",
            coordinates: [
                GarageMapCoordinate(latitude: 36.5668, longitude: -121.9515),
                GarageMapCoordinate(latitude: 36.5675, longitude: -121.9507),
                GarageMapCoordinate(latitude: 36.5685, longitude: -121.9498),
                GarageMapCoordinate(latitude: 36.5692, longitude: -121.9488)
            ],
            nodes: [
                GarageCourseNode(
                    id: "primary-tee",
                    title: "Tee Box",
                    subtitle: "Commit to the high-right launch window.",
                    kind: .tee,
                    coordinate: GarageMapCoordinate(latitude: 36.5668, longitude: -121.9515),
                    distanceLabel: nil
                ),
                GarageCourseNode(
                    id: "primary-carry",
                    title: "Carry Gate",
                    subtitle: "Clear the left bunker lip before the fairway narrows.",
                    kind: .checkpoint,
                    coordinate: GarageMapCoordinate(latitude: 36.5675, longitude: -121.9507),
                    distanceLabel: "242 yd carry"
                ),
                GarageCourseNode(
                    id: "primary-landing",
                    title: "Landing Zone",
                    subtitle: "Best angle into the green if the tee ball holds center-right.",
                    kind: .landingZone,
                    coordinate: GarageMapCoordinate(latitude: 36.5685, longitude: -121.9498),
                    distanceLabel: "286 yd total"
                ),
                GarageCourseNode(
                    id: "primary-target",
                    title: "Approach Window",
                    subtitle: "Target the open right half to avoid the cliffside front edge.",
                    kind: .target,
                    coordinate: GarageMapCoordinate(latitude: 36.5692, longitude: -121.9488),
                    distanceLabel: "148 yd in"
                )
            ],
            stats: GarageCourseRouteStats(
                totalYardage: 434,
                carryYardage: 242,
                hazardCount: 2,
                nodeCount: 4,
                expectedClub: "Driver"
            ),
            isPrimary: true,
            cameraRegion: GarageCourseRegion(
                center: GarageMapCoordinate(latitude: 36.5681, longitude: -121.9502),
                latitudinalMeters: 700,
                longitudinalMeters: 700
            )
        )

        let conservativeRoute = GarageCourseRoute(
            id: "safety-line",
            title: "Safety Line",
            subtitle: "Layup short of the pinch point",
            coordinates: [
                GarageMapCoordinate(latitude: 36.5668, longitude: -121.9515),
                GarageMapCoordinate(latitude: 36.5673, longitude: -121.9510),
                GarageMapCoordinate(latitude: 36.5680, longitude: -121.9502),
                GarageMapCoordinate(latitude: 36.5687, longitude: -121.9493)
            ],
            nodes: [
                GarageCourseNode(
                    id: "safety-tee",
                    title: "Tee Box",
                    subtitle: "Aim inside the left-center tree line and take the bunker out.",
                    kind: .tee,
                    coordinate: GarageMapCoordinate(latitude: 36.5668, longitude: -121.9515),
                    distanceLabel: nil
                ),
                GarageCourseNode(
                    id: "safety-layup",
                    title: "Layup Shelf",
                    subtitle: "Leaves a fuller number with the fairway fully exposed.",
                    kind: .layup,
                    coordinate: GarageMapCoordinate(latitude: 36.5673, longitude: -121.9510),
                    distanceLabel: "228 yd total"
                ),
                GarageCourseNode(
                    id: "safety-hazard",
                    title: "Bunker Edge",
                    subtitle: "Primary miss to avoid on the conservative shape.",
                    kind: .hazard,
                    coordinate: GarageMapCoordinate(latitude: 36.5680, longitude: -121.9502),
                    distanceLabel: "Front-right bunker"
                ),
                GarageCourseNode(
                    id: "safety-target",
                    title: "Green Entry",
                    subtitle: "Preferred angle for a controlled wedge into the center shelf.",
                    kind: .target,
                    coordinate: GarageMapCoordinate(latitude: 36.5687, longitude: -121.9493),
                    distanceLabel: "174 yd in"
                )
            ],
            stats: GarageCourseRouteStats(
                totalYardage: 434,
                carryYardage: 210,
                hazardCount: 1,
                nodeCount: 4,
                expectedClub: "3 Wood"
            ),
            isPrimary: false,
            cameraRegion: GarageCourseRegion(
                center: GarageMapCoordinate(latitude: 36.5678, longitude: -121.9504),
                latitudinalMeters: 760,
                longitudinalMeters: 760
            )
        )

        return GarageCourseMappingModel(
            metadata: metadata,
            routes: [primaryRoute, conservativeRoute]
        )
    }
}
