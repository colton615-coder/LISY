import CryptoKit
import Foundation

enum ClubRange: String, CaseIterable, Codable, Identifiable, Hashable {
    case driver = "The Big Stick"
    case woods = "Woods & Hybrids"
    case longIrons = "Long Irons"
    case scoringIrons = "Scoring Irons"
    case wedges = "The Short Game"
    case putter = "The Flatstick"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .driver:
            return "The Big Stick (Driver)"
        case .woods:
            return "Woods & Hybrids"
        case .longIrons:
            return "Long Irons (The Hard Ones)"
        case .scoringIrons:
            return "Scoring Irons (7, 8, 9)"
        case .wedges:
            return "The Short Game (Wedges)"
        case .putter:
            return "The Flatstick (Putter)"
        }
    }
}

enum FaultType: String, CaseIterable, Codable, Identifiable, Hashable {
    case earlyExtension
    case casting
    case fatThin
    case faceControl
    case tempo

    var id: String { rawValue }

    var sensoryDescription: String {
        switch self {
        case .earlyExtension:
            return "I feel crowded / Standing up too early"
        case .casting:
            return "I'm throwing the club / Losing power early"
        case .fatThin:
            return "My contact is messy (fat or thin)"
        case .faceControl:
            return "The ball is curving too much (slice or hook)"
        case .tempo:
            return "My rhythm feels rushed or jerky"
        }
    }
}

enum GarageDrillLibraryCategory: String, CaseIterable, Codable, Identifiable, Hashable {
    case ballStriking = "Ball Striking"
    case rotation = "Rotation"
    case sequencing = "Sequencing"
    case tempo = "Tempo"
    case path = "Path"
    case contact = "Contact"
    case delivery = "Delivery"
    case faceControl = "Face Control"
    case distanceControl = "Distance Control"
    case pressure = "Pressure & Accuracy"
    case putting = "Putting Pace"

    var id: String { rawValue }

    var displayName: String { rawValue }
}

enum GarageRoutineDifficulty: String, CaseIterable, Codable, Identifiable, Hashable {
    case foundation = "Foundation"
    case focused = "Focused"
    case advanced = "Advanced"

    var id: String { rawValue }

    var displayName: String { rawValue }
}

enum GarageEquipmentRequirement: String, CaseIterable, Codable, Identifiable, Hashable {
    case towel
    case alignmentStick
    case wall
    case ballBox
    case tee
    case puttingGate
    case puttingMat
    case mirror
    case launchMonitor
    case rangeBucket
    case headcover

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .towel:
            return "Towel"
        case .alignmentStick:
            return "Alignment Stick"
        case .wall:
            return "Wall"
        case .ballBox:
            return "Ball Box"
        case .tee:
            return "Tee"
        case .puttingGate:
            return "Putting Gate"
        case .puttingMat:
            return "Putting Mat"
        case .mirror:
            return "Mirror"
        case .launchMonitor:
            return "Launch Monitor"
        case .rangeBucket:
            return "Range Bucket"
        case .headcover:
            return "Headcover"
        }
    }
}

enum GarageSafetyConstraint: String, CaseIterable, Codable, Identifiable, Hashable {
    case controlledSwingsOnly
    case halfSwingsOnly
    case noFullSpeedSwingsNearWall
    case safeStickPositionRequired
    case stableFootingRequired
    case adequateSpaceRequired
    case lightweightGateObjectsOnly
    case rehearsalPreferred

    var id: String { rawValue }
}

enum GarageRecommendationTrigger: String, Codable, Hashable {
    case lowScore
    case highScore
}

struct GarageRecommendationRule: Codable, Hashable {
    let trigger: GarageRecommendationTrigger
    let threshold: Int
    let action: String
    let relatedDrillIDs: [String]

    init(
        trigger: GarageRecommendationTrigger,
        threshold: Int,
        action: String,
        relatedDrillIDs: [String] = []
    ) {
        self.trigger = trigger
        self.threshold = threshold
        self.action = action
        self.relatedDrillIDs = relatedDrillIDs
    }
}

struct GarageDrillMetadata: Codable, Hashable {
    let drillID: String
    let promptTags: Set<String>
    let faultTags: Set<String>
    let equipmentRules: Set<GarageEquipmentRequirement>
    let requiredAnyEquipmentGroups: [Set<GarageEquipmentRequirement>]
    let optionalEquipment: Set<GarageEquipmentRequirement>
    let safetyConstraints: Set<GarageSafetyConstraint>
    let primaryCategory: GarageDrillLibraryCategory
    let minReps: Int
    let maxReps: Int
    let progressionIDs: [String]
    let regressionIDs: [String]
    let recommendationRules: [GarageRecommendationRule]

    init(
        drillID: String,
        promptTags: Set<String>,
        faultTags: Set<String>,
        equipmentRules: Set<GarageEquipmentRequirement> = [],
        requiredAnyEquipmentGroups: [Set<GarageEquipmentRequirement>] = [],
        optionalEquipment: Set<GarageEquipmentRequirement> = [],
        safetyConstraints: Set<GarageSafetyConstraint> = [],
        primaryCategory: GarageDrillLibraryCategory,
        minReps: Int,
        maxReps: Int,
        progressionIDs: [String] = [],
        regressionIDs: [String] = [],
        recommendationRules: [GarageRecommendationRule] = []
    ) {
        self.drillID = drillID
        self.promptTags = promptTags
        self.faultTags = faultTags
        self.equipmentRules = equipmentRules
        self.requiredAnyEquipmentGroups = requiredAnyEquipmentGroups
        self.optionalEquipment = optionalEquipment
        self.safetyConstraints = safetyConstraints
        self.primaryCategory = primaryCategory
        self.minReps = minReps
        self.maxReps = maxReps
        self.progressionIDs = progressionIDs
        self.regressionIDs = regressionIDs
        self.recommendationRules = recommendationRules
    }
}

struct GarageDrill: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let title: String
    let environment: PracticeEnvironment
    let faultType: FaultType
    let clubRange: ClubRange
    let purpose: String
    let libraryCategory: GarageDrillLibraryCategory
    let abstractFeelCue: String
    let executionSteps: [String]
    let remedialDrillID: String?
    let defaultRepCount: Int

    init(
        id: String,
        title: String,
        environment: PracticeEnvironment,
        faultType: FaultType,
        clubRange: ClubRange,
        purpose: String,
        libraryCategory: GarageDrillLibraryCategory,
        abstractFeelCue: String,
        executionSteps: [String],
        remedialDrillID: String? = nil,
        defaultRepCount: Int = 10
    ) {
        self.id = id
        self.title = title
        self.environment = environment
        self.faultType = faultType
        self.clubRange = clubRange
        self.purpose = purpose
        self.libraryCategory = libraryCategory
        self.abstractFeelCue = abstractFeelCue
        self.executionSteps = executionSteps
        self.remedialDrillID = remedialDrillID
        self.defaultRepCount = defaultRepCount
    }
}

struct GarageRoutine: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let title: String
    let environment: PracticeEnvironment
    let purpose: String
    let drillIDs: [String]
    let estimatedMinutes: Int
    let difficulty: GarageRoutineDifficulty

    init(
        id: String,
        title: String,
        environment: PracticeEnvironment,
        purpose: String,
        drillIDs: [String],
        estimatedMinutes: Int,
        difficulty: GarageRoutineDifficulty
    ) {
        self.id = id
        self.title = title
        self.environment = environment
        self.purpose = purpose
        self.drillIDs = drillIDs
        self.estimatedMinutes = estimatedMinutes
        self.difficulty = difficulty
    }
}

enum DrillVault {
    static var masterPlaybook: [GarageDrill] {
        _ = catalogValidationMarker
        return catalogDrills
    }

    static var predefinedRoutines: [GarageRoutine] {
        _ = catalogValidationMarker
        return catalogRoutines
    }

    static func drill(for id: String) -> GarageDrill? {
        _ = catalogValidationMarker
        return canonicalDrill(for: id)
    }

    static func canonicalDrill(for identifierOrName: String) -> GarageDrill? {
        _ = catalogValidationMarker
        let lookupKey = canonicalLookupKey(for: identifierOrName)
        guard lookupKey.isEmpty == false else {
            return nil
        }

        if let idMatch = catalogDrills.first(where: { canonicalLookupKey(for: $0.id) == lookupKey }) {
            return idMatch
        }

        if let titleMatch = catalogDrills.first(where: { canonicalLookupKey(for: $0.title) == lookupKey }) {
            return titleMatch
        }

        if let aliasID = canonicalDrillAliasIDsByLookupKey[lookupKey] {
            return catalogDrills.first { $0.id == aliasID }
        }

        return nil
    }

    static func drills(in environment: PracticeEnvironment) -> [GarageDrill] {
        _ = catalogValidationMarker
        guard environment == .net else { return [] }
        return catalogDrills
    }

    static func canonicalDrill(for templateDrill: PracticeTemplateDrill) -> GarageDrill? {
        _ = catalogValidationMarker

        if let definitionID = templateDrill.definitionID,
           let matchedDrill = catalogDrills.first(where: { GarageCatalogBridge.uuid(for: "catalog-drill:\($0.id)") == definitionID }) {
            return matchedDrill
        }

        return canonicalDrill(for: templateDrill.title)
    }

    #if DEBUG
    static func auditUnresolvedTemplateDrill(_ drill: PracticeTemplateDrill, context: String) {
        let definitionDescription = drill.definitionID?.uuidString ?? "nil"
        print("[GarageDrillResolution] Unresolved \(context): title=\"\(drill.title)\", definitionID=\(definitionDescription), focus=\"\(drill.focusArea)\", target=\"\(drill.targetClub)\"")
    }
    #endif

    static func routine(for id: String) -> GarageRoutine? {
        _ = catalogValidationMarker
        return catalogRoutines.first(where: { $0.id == id })
    }

    static func routines(in environment: PracticeEnvironment) -> [GarageRoutine] {
        _ = catalogValidationMarker
        guard environment == .net else { return [] }
        return catalogRoutines
    }

    static func drills(for routine: GarageRoutine) -> [GarageDrill] {
        _ = catalogValidationMarker
        return routine.drillIDs.compactMap { drill(for: $0) }
    }

    static func routines(containing drill: GarageDrill) -> [GarageRoutine] {
        _ = catalogValidationMarker
        return catalogRoutines.filter { $0.drillIDs.contains(drill.id) }
    }

    static func drillCount(in environment: PracticeEnvironment) -> Int {
        _ = catalogValidationMarker
        return drills(in: environment).count
    }

    static func routineCount(in environment: PracticeEnvironment) -> Int {
        _ = catalogValidationMarker
        return routines(in: environment).count
    }

    static func metadata(for drillID: String) -> GarageDrillMetadata? {
        _ = catalogValidationMarker
        guard let drill = canonicalDrill(for: drillID) else { return nil }
        return catalogMetadata[drill.id]
    }

    static func metadata(for drill: GarageDrill) -> GarageDrillMetadata {
        _ = catalogValidationMarker
        return catalogMetadata[drill.id] ?? fallbackMetadata(for: drill)
    }

    static func metadata(for templateDrill: PracticeTemplateDrill) -> GarageDrillMetadata? {
        guard let canonicalDrill = canonicalDrill(for: templateDrill) else {
            return nil
        }

        return metadata(for: canonicalDrill)
    }

    static func metadata(forDrillNamed drillName: String) -> GarageDrillMetadata? {
        _ = catalogValidationMarker
        guard let drill = canonicalDrill(for: drillName) else {
            return nil
        }

        return metadata(for: drill)
    }

    static func validationErrors() -> [String] {
        validateCatalog(drills: catalogDrills, routines: catalogRoutines)
            + validateMetadata(drills: catalogDrills, metadataByDrillID: catalogMetadata)
    }

    private static let catalogValidationMarker: Void = {
        #if DEBUG
        let errors = validationErrors()
        assert(errors.isEmpty, errors.joined(separator: "\n"))
        #endif
    }()

    private static let catalogDrills: [GarageDrill] = [
        netDrill(
            id: "N-01",
            title: "Towel Low-Point Contact Drill",
            faultType: .fatThin,
            clubRange: .scoringIrons,
            purpose: "Train low-point awareness and ball-first contact.",
            libraryCategory: .ballStriking,
            abstractFeelCue: "Miss the towel, find the ball first.",
            executionSteps: [
                "Place a towel just behind the ball.",
                "Make controlled swings without brushing the towel.",
                "Count only clean strikes that finish balanced."
            ],
            defaultRepCount: 15,
            equipment: [.towel],
            tags: ["ball_striking", "contact", "low_point", "towel"]
        ),
        netDrill(
            id: "N-02",
            title: "Lead Hip Clearance Stick Drill",
            faultType: .earlyExtension,
            clubRange: .scoringIrons,
            purpose: "Train lead-hip clearance through impact without crowding the ball.",
            libraryCategory: .rotation,
            abstractFeelCue: "Clear the lead hip while the chest keeps turning.",
            executionSteps: [
                "Set an alignment stick outside the lead hip line.",
                "Rehearse the downswing with space opening through impact.",
                "Hit controlled reps only after the clearance pattern is stable."
            ],
            defaultRepCount: 12,
            equipment: [.alignmentStick],
            safety: [.safeStickPositionRequired, .controlledSwingsOnly],
            tags: ["rotation", "lead_hip", "clearance"]
        ),
        netDrill(
            id: "N-03",
            title: "Split-Grip Handle Control Drill",
            faultType: .casting,
            clubRange: .scoringIrons,
            purpose: "Keep the handle organized through delivery.",
            libraryCategory: .ballStriking,
            abstractFeelCue: "Let the handle lead while the clubhead stays patient.",
            executionSteps: [
                "Split the hands on the grip by a few inches.",
                "Make waist-to-waist swings at controlled speed.",
                "Hold the finish with the handle forward."
            ],
            defaultRepCount: 10,
            tags: ["ball_striking", "handle", "delivery", "split_grip"]
        ),
        netDrill(
            id: "N-04",
            title: "Top Pause Sequencing Drill",
            faultType: .tempo,
            clubRange: .scoringIrons,
            purpose: "Train a calmer transition and ordered downswing sequence.",
            libraryCategory: .sequencing,
            abstractFeelCue: "Pause at the top, then start from the ground.",
            executionSteps: [
                "Swing to the top and pause for one beat.",
                "Shift pressure before the arms fire.",
                "Strike the ball only after the sequence feels settled."
            ],
            defaultRepCount: 10,
            safety: [.controlledSwingsOnly],
            tags: ["sequencing", "transition", "top_pause"]
        ),
        netDrill(
            id: "N-05",
            title: "Lead-Hand Extension Drill",
            faultType: .casting,
            clubRange: .scoringIrons,
            purpose: "Build extension through impact without flipping the club.",
            libraryCategory: .ballStriking,
            abstractFeelCue: "Extend the lead hand through the strike.",
            executionSteps: [
                "Make half swings with lead-hand pressure organized.",
                "Extend through the ball without adding a hit.",
                "Hold the finish until the face feels stable."
            ],
            defaultRepCount: 10,
            safety: [.halfSwingsOnly],
            tags: ["ball_striking", "extension", "lead_hand"]
        ),
        netDrill(
            id: "N-06",
            title: "Feet-Together Tempo Drill",
            faultType: .tempo,
            clubRange: .scoringIrons,
            purpose: "Build repeatable rhythm and balanced tempo.",
            libraryCategory: .tempo,
            abstractFeelCue: "Narrow the base and let balance set the speed.",
            executionSteps: [
                "Set both feet together.",
                "Make smooth swings at controlled speed.",
                "Count only reps that finish balanced."
            ],
            defaultRepCount: 15,
            safety: [.controlledSwingsOnly, .stableFootingRequired],
            tags: ["tempo", "balance", "feet_together"]
        ),
        netDrill(
            id: "N-07",
            title: "Head-Stability Rotation Drill",
            faultType: .earlyExtension,
            clubRange: .scoringIrons,
            purpose: "Rotate around a steadier head and posture reference.",
            libraryCategory: .rotation,
            abstractFeelCue: "Turn under a quiet head.",
            executionSteps: [
                "Pick a fixed head reference before the swing.",
                "Rotate back and through without drifting off the reference.",
                "Keep the finish balanced and tall."
            ],
            defaultRepCount: 12,
            safety: [.controlledSwingsOnly],
            tags: ["rotation", "head_stability", "posture"]
        ),
        netDrill(
            id: "N-08",
            title: "Step-Through Sequencing Drill",
            faultType: .tempo,
            clubRange: .scoringIrons,
            purpose: "Connect pressure shift, rotation, and strike order.",
            libraryCategory: .sequencing,
            abstractFeelCue: "Step, turn, strike.",
            executionSteps: [
                "Begin with a narrow stance.",
                "Step toward the target as the downswing begins.",
                "Let the body rotation carry the club through impact."
            ],
            defaultRepCount: 10,
            safety: [.controlledSwingsOnly, .stableFootingRequired],
            tags: ["sequencing", "step_through", "pressure_shift"]
        ),
        netDrill(
            id: "N-09",
            title: "Hover Strike Contact Drill",
            faultType: .fatThin,
            clubRange: .scoringIrons,
            purpose: "Improve strike precision from a hovering setup.",
            libraryCategory: .ballStriking,
            abstractFeelCue: "Hover the club, then find the center.",
            executionSteps: [
                "Hover the club just above the turf at address.",
                "Make a controlled swing without grounding the club first.",
                "Count centered strikes with stable finish only."
            ],
            defaultRepCount: 12,
            safety: [.controlledSwingsOnly],
            tags: ["ball_striking", "hover", "contact"]
        ),
        netDrill(
            id: "N-10",
            title: "Box Gate Path Drill",
            faultType: .faceControl,
            clubRange: .scoringIrons,
            purpose: "Train a cleaner path through a simple net-safe gate.",
            libraryCategory: .path,
            abstractFeelCue: "Deliver the club through the box.",
            executionSteps: [
                "Build a soft gate around the ball line.",
                "Swing through the gate without clipping either side.",
                "Reset after any path strike against the gate."
            ],
            defaultRepCount: 15,
            equipment: [.ballBox],
            safety: [.lightweightGateObjectsOnly, .controlledSwingsOnly],
            tags: ["path", "gate", "box", "ball_striking"]
        )
    ]

    private static let catalogRoutines: [GarageRoutine] = [
        GarageRoutine(
            id: "net-10-contact-foundation",
            title: "Net 10 Contact Foundation",
            environment: .net,
            purpose: "Rebuild strike, low point, and delivery using the Net 10 library.",
            drillIDs: ["N-01", "N-03", "N-05", "N-09"],
            estimatedMinutes: 24,
            difficulty: .foundation
        ),
        GarageRoutine(
            id: "net-10-sequence-rotation",
            title: "Net 10 Sequence & Rotation",
            environment: .net,
            purpose: "Connect body clearance, head stability, and sequencing.",
            drillIDs: ["N-02", "N-04", "N-07", "N-08"],
            estimatedMinutes: 24,
            difficulty: .focused
        ),
        GarageRoutine(
            id: "net-10-tempo-path",
            title: "Net 10 Tempo & Path",
            environment: .net,
            purpose: "Stabilize tempo and club path in a controlled net station.",
            drillIDs: ["N-06", "N-10"],
            estimatedMinutes: 16,
            difficulty: .foundation
        )
    ]

    private static let catalogMetadata: [String: GarageDrillMetadata] = Dictionary(
        uniqueKeysWithValues: catalogDrills.map { drill in
            let baseTags = Set([
                drill.id,
                drill.title,
                drill.libraryCategory.rawValue,
                drill.faultType.rawValue
            ].map(normalizedMetadataToken))
            let metadata = GarageDrillMetadata(
                drillID: drill.id,
                promptTags: baseTags,
                faultTags: Set([drill.faultType.rawValue].map(normalizedMetadataToken)),
                equipmentRules: equipmentRulesByDrillID[drill.id] ?? [],
                optionalEquipment: [],
                safetyConstraints: safetyConstraintsByDrillID[drill.id] ?? [],
                primaryCategory: drill.libraryCategory,
                minReps: max(1, drill.defaultRepCount / 2),
                maxReps: max(drill.defaultRepCount, drill.defaultRepCount * 2),
                recommendationRules: [
                    GarageRecommendationRule(
                        trigger: .lowScore,
                        threshold: 60,
                        action: "Repeat this Net 10 category before advancing.",
                        relatedDrillIDs: []
                    ),
                    GarageRecommendationRule(
                        trigger: .highScore,
                        threshold: 80,
                        action: "Progress to the next Net 10 station when contact stays clean.",
                        relatedDrillIDs: []
                    )
                ]
            )
            return (drill.id, metadata)
        }
    )

    private static let equipmentRulesByDrillID: [String: Set<GarageEquipmentRequirement>] = [
        "N-01": [.towel],
        "N-02": [.alignmentStick],
        "N-10": [.ballBox]
    ]

    private static let safetyConstraintsByDrillID: [String: Set<GarageSafetyConstraint>] = [
        "N-02": [.safeStickPositionRequired, .controlledSwingsOnly],
        "N-04": [.controlledSwingsOnly],
        "N-05": [.halfSwingsOnly],
        "N-06": [.controlledSwingsOnly, .stableFootingRequired],
        "N-07": [.controlledSwingsOnly],
        "N-08": [.controlledSwingsOnly, .stableFootingRequired],
        "N-09": [.controlledSwingsOnly],
        "N-10": [.lightweightGateObjectsOnly, .controlledSwingsOnly]
    ]

    private static func netDrill(
        id: String,
        title: String,
        faultType: FaultType,
        clubRange: ClubRange,
        purpose: String,
        libraryCategory: GarageDrillLibraryCategory,
        abstractFeelCue: String,
        executionSteps: [String],
        defaultRepCount: Int,
        equipment: Set<GarageEquipmentRequirement> = [],
        safety: Set<GarageSafetyConstraint> = [],
        tags: Set<String> = []
    ) -> GarageDrill {
        GarageDrill(
            id: id,
            title: title,
            environment: .net,
            faultType: faultType,
            clubRange: clubRange,
            purpose: purpose,
            libraryCategory: libraryCategory,
            abstractFeelCue: abstractFeelCue,
            executionSteps: executionSteps,
            defaultRepCount: defaultRepCount
        )
    }

    private static func fallbackMetadata(for drill: GarageDrill) -> GarageDrillMetadata {
        GarageDrillMetadata(
            drillID: drill.id,
            promptTags: Set([drill.libraryCategory.rawValue, drill.faultType.rawValue, drill.title].map(normalizedMetadataToken)),
            faultTags: Set([drill.faultType.rawValue].map(normalizedMetadataToken)),
            primaryCategory: drill.libraryCategory,
            minReps: max(1, drill.defaultRepCount / 2),
            maxReps: max(drill.defaultRepCount, drill.defaultRepCount * 2),
            regressionIDs: drill.remedialDrillID.map { [$0] } ?? []
        )
    }

    private static func validateCatalog(
        drills: [GarageDrill],
        routines: [GarageRoutine]
    ) -> [String] {
        var errors: [String] = []

        if drills.count != 10 {
            errors.append("Expected Net 10 catalog but found \(drills.count) drills.")
        }

        let nonNetDrills = drills.filter { $0.environment != .net }
        if nonNetDrills.isEmpty == false {
            errors.append("Net 10 catalog contains non-Net drills: \(nonNetDrills.map(\.id).joined(separator: ", ")).")
        }

        let duplicateDrillIDs = duplicateIDs(in: drills.map(\.id))
        if duplicateDrillIDs.isEmpty == false {
            errors.append("Duplicate drill IDs: \(duplicateDrillIDs.joined(separator: ", ")).")
        }

        let duplicateRoutineIDs = duplicateIDs(in: routines.map(\.id))
        if duplicateRoutineIDs.isEmpty == false {
            errors.append("Duplicate routine IDs: \(duplicateRoutineIDs.joined(separator: ", ")).")
        }

        let drillLookup = Dictionary(uniqueKeysWithValues: drills.map { ($0.id, $0) })
        for routine in routines {
            if routine.environment != .net {
                errors.append("Net 10 shim contains non-Net routine: \(routine.id).")
            }

            if routine.drillIDs.isEmpty {
                errors.append("Routine \(routine.id) has no drills.")
            }

            let missingDrillIDs = routine.drillIDs.filter { drillLookup[$0] == nil }
            if missingDrillIDs.isEmpty == false {
                errors.append("Routine \(routine.id) references missing drills: \(missingDrillIDs.joined(separator: ", ")).")
            }
        }

        return errors
    }

    private static func validateMetadata(
        drills: [GarageDrill],
        metadataByDrillID: [String: GarageDrillMetadata]
    ) -> [String] {
        var errors: [String] = []
        let drillIDs = Set(drills.map(\.id))
        let metadataIDs = Set(metadataByDrillID.keys)

        let missingMetadata = drillIDs.subtracting(metadataIDs).sorted()
        if missingMetadata.isEmpty == false {
            errors.append("Missing metadata for drills: \(missingMetadata.joined(separator: ", ")).")
        }

        let orphanedMetadata = metadataIDs.subtracting(drillIDs).sorted()
        if orphanedMetadata.isEmpty == false {
            errors.append("Metadata references unknown drills: \(orphanedMetadata.joined(separator: ", ")).")
        }

        for metadata in metadataByDrillID.values.sorted(by: { $0.drillID < $1.drillID }) {
            if metadata.minReps > metadata.maxReps {
                errors.append("Metadata \(metadata.drillID) has minReps greater than maxReps.")
            }
        }

        return errors
    }

    private nonisolated static func normalizedMetadataToken(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "&", with: " ")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.isEmpty == false }
            .joined(separator: "_")
    }

    private nonisolated static func canonicalLookupKey(for value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "&", with: " and ")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.isEmpty == false }
            .joined(separator: " ")
    }

    private static let canonicalDrillAliasIDsByLookupKey: [String: String] = {
        let aliasesByID: [String: [String]] = [
            "N-01": ["n1", "n01", "towel low point", "towel contact", "towel strike"],
            "N-02": ["n2", "n02", "lead hip", "hip clearance"],
            "N-03": ["n3", "n03", "split grip", "handle control"],
            "N-04": ["n4", "n04", "top pause", "pause sequencing"],
            "N-05": ["n5", "n05", "lead hand extension"],
            "N-06": ["n6", "n06", "feet together", "tempo drill"],
            "N-07": ["n7", "n07", "head stability", "rotation drill"],
            "N-08": ["n8", "n08", "step through", "sequencing drill"],
            "N-09": ["n9", "n09", "hover strike", "hover contact"],
            "N-10": ["n10", "box gate", "path drill"]
        ]

        return aliasesByID.reduce(into: [:]) { partialResult, entry in
            for alias in entry.value {
                partialResult[canonicalLookupKey(for: alias)] = entry.key
            }
        }
    }()

    private static func duplicateIDs(in values: [String]) -> [String] {
        var seen = Set<String>()
        var duplicates = Set<String>()

        for value in values {
            if seen.insert(value).inserted == false {
                duplicates.insert(value)
            }
        }

        return duplicates.sorted()
    }
}

extension GarageRoutine {
    func makePracticeTemplate() -> PracticeTemplate {
        let resolvedDrills = DrillVault.drills(for: self)
        let templateDrills = resolvedDrills.enumerated().map { offset, drill in
            drill.makePracticeTemplateDrill(seedKey: "\(id):\(offset):\(drill.id)")
        }

        return PracticeTemplate(
            id: GarageCatalogBridge.uuid(for: "routine-template:\(id)"),
            title: title,
            environment: environment.rawValue,
            drills: templateDrills,
            createdAt: Date(timeIntervalSince1970: 0)
        )
    }
}

extension GarageDrill {
    func makeActivePracticeSession() -> ActivePracticeSession {
        let template = makePracticeTemplate()
        let prescriptions = Dictionary(uniqueKeysWithValues: template.drills.enumerated().map { offset, drill in
            (drill.id, GarageDrillCatalog.defaultPrescription(for: drill, sessionOrder: offset))
        })
        return ActivePracticeSession(
            template: template,
            prescriptionsByDrillID: prescriptions
        )
    }

    func makePracticeTemplate() -> PracticeTemplate {
        PracticeTemplate(
            id: GarageCatalogBridge.uuid(for: "prescription-template:\(id)"),
            title: "Prescription • \(title)",
            environment: environment.rawValue,
            drills: makePracticeDrills(),
            createdAt: Date(timeIntervalSince1970: 0)
        )
    }

    private func makePracticeDrills() -> [PracticeTemplateDrill] {
        var drills = [makePracticeTemplateDrill(seedKey: "prescription:\(id):primary")]

        if let remedialDrillID,
           remedialDrillID != id,
           let remedial = DrillVault.drill(for: remedialDrillID) {
            drills.append(remedial.makePracticeTemplateDrill(seedKey: "prescription:\(id):remedial:\(remedial.id)"))
        }

        return drills
    }

    func makeGeneratedPracticeTemplateDrill(seedKey: String) -> PracticeTemplateDrill {
        makePracticeTemplateDrill(seedKey: seedKey)
    }

    func makeGeneratedPracticeTemplateDrill(seedKey: String, prescribedRepCount: Int) -> PracticeTemplateDrill {
        let metadata = DrillVault.metadata(for: self)
        let clampedRepCount = min(max(prescribedRepCount, metadata.minReps), metadata.maxReps)

        return PracticeTemplateDrill(
            id: GarageCatalogBridge.uuid(for: "routine-drill:\(seedKey)"),
            definitionID: GarageCatalogBridge.uuid(for: "catalog-drill:\(id)"),
            title: title,
            focusArea: libraryCategory.displayName,
            targetClub: clubRange.garageCompactDisplayName,
            defaultRepCount: clampedRepCount
        )
    }

    fileprivate func makePracticeTemplateDrill(seedKey: String) -> PracticeTemplateDrill {
        PracticeTemplateDrill(
            id: GarageCatalogBridge.uuid(for: "routine-drill:\(seedKey)"),
            definitionID: GarageCatalogBridge.uuid(for: "catalog-drill:\(id)"),
            title: title,
            focusArea: libraryCategory.displayName,
            targetClub: clubRange.garageCompactDisplayName,
            defaultRepCount: defaultRepCount
        )
    }
}

private enum GarageCatalogBridge {
    private static let namespace = "com.lifeinsync.garage.catalog"

    static func uuid(for seed: String) -> UUID {
        let digest = SHA256.hash(data: Data("\(namespace):\(seed)".utf8))
        let bytes = Array(digest)

        return UUID(uuid: (
            bytes[0],
            bytes[1],
            bytes[2],
            bytes[3],
            bytes[4],
            bytes[5],
            UInt8((bytes[6] & 0x0F) | 0x50),
            bytes[7],
            UInt8((bytes[8] & 0x3F) | 0x80),
            bytes[9],
            bytes[10],
            bytes[11],
            bytes[12],
            bytes[13],
            bytes[14],
            bytes[15]
        ))
    }
}
