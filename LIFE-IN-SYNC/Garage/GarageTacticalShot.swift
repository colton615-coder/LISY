import Foundation
import SwiftData

@preconcurrency
@Model
@MainActor
final class GarageTacticalShot {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var sequenceIndex: Int
    var holeNumber: Int
    var placement: GarageShotPlacement
    var club: GarageTacticalClub
    var shotType: GarageTacticalShotType
    var intendedTarget: String
    var lieBeforeShot: GarageTacticalLie
    var actualResult: GarageTacticalResult
    var flightShape: GarageShotFlightShape
    var strikeQuality: GarageShotStrikeQuality
    var tempo: Double?
    var backswingDuration: Double?
    var downswingDuration: Double?
    var handSpeed: Double?

    var session: GarageRoundSession?

    var hole: GarageHoleMap?

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        sequenceIndex: Int,
        holeNumber: Int,
        placement: GarageShotPlacement,
        club: GarageTacticalClub,
        shotType: GarageTacticalShotType,
        intendedTarget: String,
        lieBeforeShot: GarageTacticalLie,
        actualResult: GarageTacticalResult,
        flightShape: GarageShotFlightShape = .straight,
        strikeQuality: GarageShotStrikeQuality = .pure,
        tempo: Double? = nil,
        backswingDuration: Double? = nil,
        downswingDuration: Double? = nil,
        handSpeed: Double? = nil,
        session: GarageRoundSession? = nil,
        hole: GarageHoleMap? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sequenceIndex = sequenceIndex
        self.holeNumber = holeNumber
        self.placement = placement
        self.club = club
        self.shotType = shotType
        self.intendedTarget = intendedTarget
        self.lieBeforeShot = lieBeforeShot
        self.actualResult = actualResult
        self.flightShape = flightShape
        self.strikeQuality = strikeQuality
        self.tempo = tempo
        self.backswingDuration = backswingDuration
        self.downswingDuration = downswingDuration
        self.handSpeed = handSpeed
        self.session = session
        self.hole = hole
    }
}
