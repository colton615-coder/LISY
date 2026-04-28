import Foundation
import SwiftData

@preconcurrency
@Model
@MainActor
final class GarageRoundSession {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var sessionTitle: String
    var courseName: String
    var sessionDate: Date
    var notes: String

    @Relationship(deleteRule: .cascade, inverse: \GarageHoleMap.session)
    var holes: [GarageHoleMap]

    @Relationship(deleteRule: .cascade, inverse: \GarageTacticalShot.session)
    var shots: [GarageTacticalShot]

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        sessionTitle: String,
        courseName: String,
        sessionDate: Date = .now,
        notes: String = "",
        holes: [GarageHoleMap] = [],
        shots: [GarageTacticalShot] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sessionTitle = sessionTitle
        self.courseName = courseName
        self.sessionDate = sessionDate
        self.notes = notes
        self.holes = holes
        self.shots = shots
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

    var playedHoleCount: Int {
        Set(shots.map(\.holeNumber)).count
    }

    var lastShot: GarageTacticalShot? {
        sortedShots.last
    }
}
