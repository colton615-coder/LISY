import Foundation
import SwiftData

@preconcurrency
@Model
@MainActor
final class GarageTacticalShot {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var detectedAt: Date
    var userConfirmedAt: Date?
    var sequenceIndex: Int
    var holeNumber: Int
    var placement: GarageShotPlacement
    var latitude: Double?
    var longitude: Double?
    var locationAccuracy: Double?
    var clubName: String
    var lieState: GarageLieState
    var isPracticeSwing: Bool
    var club: GarageTacticalClub
    var shotType: GarageTacticalShotType
    var intendedTarget: String
    var lieBeforeShot: GarageTacticalLie
    var actualResult: GarageTacticalResult
    var flightShape: GarageShotFlightShape
    var strikeQuality: GarageShotStrikeQuality

    var session: GarageRoundSession?

    var hole: GarageHoleMap?

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        detectedAt: Date = .now,
        userConfirmedAt: Date? = nil,
        sequenceIndex: Int,
        holeNumber: Int,
        placement: GarageShotPlacement,
        latitude: Double? = nil,
        longitude: Double? = nil,
        locationAccuracy: Double? = nil,
        clubName: String = "Unknown",
        lieState: GarageLieState = .unknown,
        isPracticeSwing: Bool = false,
        club: GarageTacticalClub,
        shotType: GarageTacticalShotType,
        intendedTarget: String,
        lieBeforeShot: GarageTacticalLie,
        actualResult: GarageTacticalResult,
        flightShape: GarageShotFlightShape = .straight,
        strikeQuality: GarageShotStrikeQuality = .pure,
        session: GarageRoundSession? = nil,
        hole: GarageHoleMap? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.detectedAt = detectedAt
        self.userConfirmedAt = userConfirmedAt
        self.sequenceIndex = sequenceIndex
        self.holeNumber = holeNumber
        self.placement = placement
        self.latitude = latitude
        self.longitude = longitude
        self.locationAccuracy = locationAccuracy
        self.clubName = clubName
        self.lieState = lieState
        self.isPracticeSwing = isPracticeSwing
        self.club = club
        self.shotType = shotType
        self.intendedTarget = intendedTarget
        self.lieBeforeShot = lieBeforeShot
        self.actualResult = actualResult
        self.flightShape = flightShape
        self.strikeQuality = strikeQuality
        self.session = session
        self.hole = hole
    }
}
