import Foundation
import SwiftData

@Model
final class GarageRoundSession {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var sessionTitle: String
    var courseName: String
    var sessionDate: Date
    var notes: String

    var holes: [GarageHoleMap]

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
}
