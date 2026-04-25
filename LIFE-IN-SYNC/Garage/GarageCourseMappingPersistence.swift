import Foundation
import SwiftData

enum GarageCourseMappingPersistenceError: LocalizedError, Equatable {
    case missingHoleAsset
    case invalidSourceReference
    case invalidImageDimensions(width: Double, height: Double)
    case mapNotCalibrated
    case coordinateOutOfBounds(field: String, x: Double, y: Double)
    case unresolvedHoleNumber(label: String)

    var errorDescription: String? {
        switch self {
        case .missingHoleAsset:
            return "Garage needs a real hole image before this map can be calibrated or used for shot logging."
        case .invalidSourceReference:
            return "Garage rejected this hole import because the source reference is missing or unreadable."
        case let .invalidImageDimensions(width, height):
            return "Garage rejected this hole import because the image dimensions are invalid (\(Int(width)) x \(Int(height)))."
        case .mapNotCalibrated:
            return "This hole is still unpinned. Drop the tee, checkpoint, and green anchors before logging a shot."
        case let .coordinateOutOfBounds(field, x, y):
            return "\(field) is outside the 0...1 map bounds (\(String(format: "%.3f", x)), \(String(format: "%.3f", y)))."
        case let .unresolvedHoleNumber(label):
            return "Garage could not resolve a valid hole number from \"\(label)\"."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .missingHoleAsset:
            return "Upload a static hole image or a rendered PDF page, then return to anchor setup."
        case .invalidSourceReference:
            return "Retry the import with a valid URL or local asset reference."
        case .invalidImageDimensions:
            return "Retry with a source that reports non-zero pixel dimensions."
        case .mapNotCalibrated:
            return "Complete anchor setup first. Shot entry stays locked until the map is calibrated."
        case .coordinateOutOfBounds:
            return "Fix the upstream coordinate math and try again."
        case .unresolvedHoleNumber:
            return "Correct the hole label before persisting this map."
        }
    }
}

enum GarageCourseMappingPersistence {
    @MainActor
    static func resolveActiveSession(
        for metadata: GarageCourseMetadata,
        in modelContext: ModelContext
    ) throws -> GarageRoundSession {
        let courseName = metadata.courseName.trimmingCharacters(in: .whitespacesAndNewlines)
        var descriptor = FetchDescriptor<GarageRoundSession>(
            predicate: #Predicate<GarageRoundSession> { session in
                session.courseName == courseName
            },
            sortBy: [
                SortDescriptor(\GarageRoundSession.updatedAt, order: .reverse),
                SortDescriptor(\GarageRoundSession.createdAt, order: .reverse)
            ]
        )
        descriptor.fetchLimit = 1

        if let existingSession = try modelContext.fetch(descriptor).first {
            return existingSession
        }

        let session = GarageRoundSession(
            sessionTitle: "\(courseName) Round",
            courseName: courseName
        )
        modelContext.insert(session)
        try modelContext.save()
        return session
    }

    @MainActor
    static func resolveHole(
        for metadata: GarageCourseMetadata,
        session: GarageRoundSession,
        in modelContext: ModelContext
    ) throws -> GarageHoleMap {
        guard let assetDescriptor = metadata.assetDescriptor else {
            throw GarageCourseMappingPersistenceError.missingHoleAsset
        }
        try assetDescriptor.validate()

        let holeNumber = try metadata.resolvedHoleNumber

        if let existingHole = session.holes.first(where: {
            $0.holeNumber == holeNumber && $0.sourceReference == assetDescriptor.sourceReference
        }) {
            existingHole.updatedAt = .now
            existingHole.holeName = metadata.holeName
            existingHole.par = metadata.par
            existingHole.yardageLabel = metadata.yardageLabel
            existingHole.sourceType = assetDescriptor.sourceType
            existingHole.sourceReference = assetDescriptor.sourceReference
            existingHole.localAssetPath = assetDescriptor.localAssetPath
            existingHole.imagePixelWidth = assetDescriptor.imagePixelWidth
            existingHole.imagePixelHeight = assetDescriptor.imagePixelHeight
            try existingHole.validateForPersistence()
            try modelContext.save()
            return existingHole
        }

        let hole = GarageHoleMap(
            holeNumber: holeNumber,
            holeName: metadata.holeName,
            par: metadata.par,
            yardageLabel: metadata.yardageLabel,
            sourceType: assetDescriptor.sourceType,
            sourceReference: assetDescriptor.sourceReference,
            localAssetPath: assetDescriptor.localAssetPath,
            imagePixelWidth: assetDescriptor.imagePixelWidth,
            imagePixelHeight: assetDescriptor.imagePixelHeight,
            session: session
        )
        try hole.validateForPersistence()

        modelContext.insert(hole)
        if session.holes.contains(where: { $0.id == hole.id }) == false {
            session.holes.append(hole)
        }
        session.updatedAt = .now

        try modelContext.save()
        return hole
    }

    @MainActor
    static func reindexShots(in session: GarageRoundSession) {
        for (index, shot) in session.sortedShots.enumerated() {
            shot.sequenceIndex = index + 1
            if let hole = shot.hole {
                shot.holeNumber = hole.holeNumber
                hole.updatedAt = .now
            }
            shot.updatedAt = .now
        }

        session.updatedAt = .now
    }
}

extension GarageCourseMetadata {
    var resolvedHoleNumber: Int {
        get throws {
            let digits = holeLabel.filter(\.isNumber)
            guard let value = Int(digits), value > 0 else {
                throw GarageCourseMappingPersistenceError.unresolvedHoleNumber(label: holeLabel)
            }
            return value
        }
    }
}

extension GarageCourseAssetDescriptor {
    func validate() throws {
        let trimmedReference = sourceReference.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedReference.isEmpty == false else {
            throw GarageCourseMappingPersistenceError.invalidSourceReference
        }

        guard imagePixelWidth > 0, imagePixelHeight > 0 else {
            throw GarageCourseMappingPersistenceError.invalidImageDimensions(
                width: imagePixelWidth,
                height: imagePixelHeight
            )
        }
    }
}

extension GarageMapAnchor {
    func validate(fieldName: String) throws {
        guard isNormalizedInBounds else {
            throw GarageCourseMappingPersistenceError.coordinateOutOfBounds(
                field: fieldName,
                x: normalizedX,
                y: normalizedY
            )
        }
    }
}

extension GarageShotPlacement {
    func validate(fieldName: String) throws {
        guard isNormalizedInBounds else {
            throw GarageCourseMappingPersistenceError.coordinateOutOfBounds(
                field: fieldName,
                x: normalizedX,
                y: normalizedY
            )
        }
    }
}

extension GarageHoleMap {
    func validateForPersistence() throws {
        let trimmedReference = sourceReference.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedReference.isEmpty == false else {
            throw GarageCourseMappingPersistenceError.invalidSourceReference
        }

        guard imagePixelWidth > 0, imagePixelHeight > 0 else {
            throw GarageCourseMappingPersistenceError.invalidImageDimensions(
                width: imagePixelWidth,
                height: imagePixelHeight
            )
        }

        try teeAnchor?.validate(fieldName: "Tee anchor")
        try fairwayCheckpointAnchor?.validate(fieldName: "Fairway checkpoint")
        try greenCenterAnchor?.validate(fieldName: "Green center")
    }

    func validateForShotLogging() throws {
        try validateForPersistence()
        guard isCalibrated else {
            throw GarageCourseMappingPersistenceError.mapNotCalibrated
        }
    }
}
