import Foundation
import SwiftData

@preconcurrency
@Model
@MainActor
final class GarageHoleMap {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var holeNumber: Int
    var holeName: String
    var par: Int
    var yardageLabel: String
    var sourceType: GarageHoleSourceType
    var sourceReference: String
    var localAssetPath: String?
    var imagePixelWidth: Double
    var imagePixelHeight: Double
    var teeAnchor: GarageMapAnchor?
    var fairwayCheckpointAnchor: GarageMapAnchor?
    var greenCenterAnchor: GarageMapAnchor?

    var session: GarageRoundSession?

    @Relationship(deleteRule: .cascade, inverse: \GarageTacticalShot.hole)
    var shots: [GarageTacticalShot]

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        holeNumber: Int,
        holeName: String = "",
        par: Int,
        yardageLabel: String = "",
        sourceType: GarageHoleSourceType,
        sourceReference: String,
        localAssetPath: String? = nil,
        imagePixelWidth: Double = 0,
        imagePixelHeight: Double = 0,
        teeAnchor: GarageMapAnchor? = nil,
        fairwayCheckpointAnchor: GarageMapAnchor? = nil,
        greenCenterAnchor: GarageMapAnchor? = nil,
        session: GarageRoundSession? = nil,
        shots: [GarageTacticalShot] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.holeNumber = holeNumber
        self.holeName = holeName
        self.par = par
        self.yardageLabel = yardageLabel
        self.sourceType = sourceType
        self.sourceReference = sourceReference
        self.localAssetPath = localAssetPath
        self.imagePixelWidth = imagePixelWidth
        self.imagePixelHeight = imagePixelHeight
        self.teeAnchor = teeAnchor
        self.fairwayCheckpointAnchor = fairwayCheckpointAnchor
        self.greenCenterAnchor = greenCenterAnchor
        self.session = session
        self.shots = shots
    }

    var isCalibrated: Bool {
        teeAnchor != nil && fairwayCheckpointAnchor != nil && greenCenterAnchor != nil
    }

    var totalShots: Int {
        shots.count
    }

    var sortedShots: [GarageTacticalShot] {
        shots.sorted { lhs, rhs in
            if lhs.sequenceIndex != rhs.sequenceIndex {
                return lhs.sequenceIndex < rhs.sequenceIndex
            }
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    var lastShot: GarageTacticalShot? {
        sortedShots.last
    }
}
