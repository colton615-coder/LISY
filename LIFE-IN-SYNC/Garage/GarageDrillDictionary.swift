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
    case contact = "Contact"
    case delivery = "Delivery"
    case rotation = "Rotation"
    case faceControl = "Face Control"
    case tempo = "Tempo & Balance"
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
        return catalogDrills.first(where: { $0.id == id })
    }

    static func drills(in environment: PracticeEnvironment) -> [GarageDrill] {
        _ = catalogValidationMarker
        return catalogDrills.filter { $0.environment == environment }
    }

    static func canonicalDrill(for templateDrill: PracticeTemplateDrill) -> GarageDrill? {
        _ = catalogValidationMarker

        if let definitionID = templateDrill.definitionID,
           let matchedDrill = catalogDrills.first(where: { GarageCatalogBridge.uuid(for: "catalog-drill:\($0.id)") == definitionID }) {
            return matchedDrill
        }

        return catalogDrills.first {
            $0.title.caseInsensitiveCompare(templateDrill.title) == .orderedSame
        } ?? canonicalDrillMatchingAlias(for: templateDrill.title)
    }

    private static func canonicalDrillMatchingAlias(for title: String) -> GarageDrill? {
        let normalizedTitle = title
            .lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .joined(separator: " ")

        let aliasID: String?
        switch normalizedTitle {
        case "carry ladder", "wedge carry ladder", "wedge distance ladder":
            aliasID = "r13"
        case "tempo rehearsal", "pause tempo rehearsal":
            aliasID = "n6"
        default:
            aliasID = nil
        }

        guard let aliasID else {
            return nil
        }

        return catalogDrills.first { $0.id == aliasID }
    }

    static func routine(for id: String) -> GarageRoutine? {
        _ = catalogValidationMarker
        return catalogRoutines.first(where: { $0.id == id })
    }

    static func routines(in environment: PracticeEnvironment) -> [GarageRoutine] {
        _ = catalogValidationMarker
        return catalogRoutines.filter { $0.environment == environment }
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
        return catalogDrills.filter { $0.environment == environment }.count
    }

    static func routineCount(in environment: PracticeEnvironment) -> Int {
        _ = catalogValidationMarker
        return catalogRoutines.filter { $0.environment == environment }.count
    }

    static func metadata(for drillID: String) -> GarageDrillMetadata? {
        _ = catalogValidationMarker
        return catalogMetadata[drillID]
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
        guard let drill = catalogDrills.first(where: { $0.title.caseInsensitiveCompare(drillName) == .orderedSame }) else {
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
        GarageDrill(
            id: "n1",
            title: "Heavy Towel Strike",
            environment: .net,
            faultType: .fatThin,
            clubRange: .scoringIrons,
            purpose: "Train cleaner ball-first contact and low-point control before speed.",
            libraryCategory: .contact,
            abstractFeelCue: "Sharpen strike without letting the club bottom out early.",
            executionSteps: [
                "Place a towel two inches behind the ball.",
                "Make ten swings without touching the towel.",
                "Stay down through the strike until the turf wins."
            ],
            remedialDrillID: "n2",
            defaultRepCount: 10
        ),
        GarageDrill(
            id: "n2",
            title: "Split-Hand Delivery",
            environment: .net,
            faultType: .casting,
            clubRange: .wedges,
            purpose: "Reduce early throwaway and feel the handle lead through impact.",
            libraryCategory: .delivery,
            abstractFeelCue: "Keep the handle leading while the clubhead stays patient.",
            executionSteps: [
                "Separate your hands on the grip by three inches.",
                "Make waist-to-waist swings at half speed.",
                "Hold the finish with the handle ahead of the clubhead."
            ],
            defaultRepCount: 8
        ),
        GarageDrill(
            id: "n3",
            title: "Wall Turn Rehearsal",
            environment: .net,
            faultType: .earlyExtension,
            clubRange: .driver,
            purpose: "Rehearse turning without losing posture or standing up early.",
            libraryCategory: .rotation,
            abstractFeelCue: "Keep your turn deep so the hips do not crowd the ball.",
            executionSteps: [
                "Stand with your trail hip a few inches from a wall.",
                "Rehearse back-and-through swings without bumping the wall.",
                "Finish balanced with your chest fully turned."
            ],
            defaultRepCount: 8
        ),
        GarageDrill(
            id: "n4",
            title: "Start-Line Mirror",
            environment: .net,
            faultType: .faceControl,
            clubRange: .scoringIrons,
            purpose: "Train a centered face and predictable launch through a tight visual window.",
            libraryCategory: .faceControl,
            abstractFeelCue: "Match the clubface to a tiny start window before adding speed.",
            executionSteps: [
                "Set an alignment stick just outside the ball.",
                "Make smooth swings that send the face through the same window.",
                "Freeze the finish only when the start line feels centered."
            ],
            remedialDrillID: "n2",
            defaultRepCount: 8
        ),
        GarageDrill(
            id: "n5",
            title: "The Pillar Pivot",
            environment: .net,
            faultType: .tempo,
            clubRange: .woods,
            purpose: "Build rhythm and balance with a narrowed base and patient finish.",
            libraryCategory: .tempo,
            abstractFeelCue: "Swing inside a phone booth and own the finish.",
            executionSteps: [
                "Set your feet together to narrow the base.",
                "Make smooth swings at sixty percent speed.",
                "Finish in balance for a full two-count."
            ],
            defaultRepCount: 10
        ),
        GarageDrill(
            id: "n6",
            title: "Pause-To-Pressure",
            environment: .net,
            faultType: .tempo,
            clubRange: .wedges,
            purpose: "Sequence the downswing from the ground up instead of rushing from the top.",
            libraryCategory: .tempo,
            abstractFeelCue: "Pause at the top so the downswing starts from the ground up.",
            executionSteps: [
                "Make a full backswing and pause for one beat.",
                "Shift pressure forward before the arms unwind.",
                "Hit soft shots while keeping the pause honest."
            ],
            remedialDrillID: "n5",
            defaultRepCount: 8
        ),
        GarageDrill(
            id: "n7",
            title: "Exit Low Window",
            environment: .net,
            faultType: .casting,
            clubRange: .woods,
            purpose: "Replace a thrown clubhead with a shallower exit and continued chest turn.",
            libraryCategory: .delivery,
            abstractFeelCue: "Send the club through a low exit instead of throwing it at the ball.",
            executionSteps: [
                "Place a headcover just outside the ball line after impact.",
                "Brush past impact without clipping the headcover.",
                "Keep the chest turning so the exit stays shallow."
            ],
            remedialDrillID: "n2",
            defaultRepCount: 8
        ),
        GarageDrill(
            id: "n8",
            title: "Trail-Hand Brush",
            environment: .net,
            faultType: .fatThin,
            clubRange: .scoringIrons,
            purpose: "Stabilize brush point and strike location with one-hand contact rehearsal.",
            libraryCategory: .contact,
            abstractFeelCue: "Brush the turf in the same spot every time with one hand.",
            executionSteps: [
                "Hit half swings using only the trail hand.",
                "Listen for a crisp brush after the ball position.",
                "Add the lead hand back only after the brush point holds."
            ],
            remedialDrillID: "n1",
            defaultRepCount: 8
        ),
        GarageDrill(
            id: "r10",
            title: "Start-Line Split",
            environment: .range,
            faultType: .faceControl,
            clubRange: .driver,
            purpose: "Separate start-line control from curve so driver practice stays honest.",
            libraryCategory: .pressure,
            abstractFeelCue: "Own the first few feet of flight before judging curve.",
            executionSteps: [
                "Pick a narrow gate ten yards in front of you.",
                "Hit five shots through the same launch gate.",
                "Judge the rep by start line first, not final finish."
            ],
            remedialDrillID: "n4",
            defaultRepCount: 5
        ),
        GarageDrill(
            id: "r11",
            title: "Pierce The Window",
            environment: .range,
            faultType: .faceControl,
            clubRange: .longIrons,
            purpose: "Start the ball through a small window before judging curve or height.",
            libraryCategory: .pressure,
            abstractFeelCue: "Squeeze the ball under a low branch and through a tiny window.",
            executionSteps: [
                "Pick a ten-by-ten target window.",
                "Hit five balls that start through the same gate.",
                "Track the start line before you judge the curve."
            ],
            remedialDrillID: "n1",
            defaultRepCount: 5
        ),
        GarageDrill(
            id: "r12",
            title: "Strike Window Ladder",
            environment: .range,
            faultType: .fatThin,
            clubRange: .scoringIrons,
            purpose: "Match strike quality to a repeating carry ladder instead of chasing one swing.",
            libraryCategory: .contact,
            abstractFeelCue: "Match strike quality to a repeating carry window.",
            executionSteps: [
                "Choose three targets with one club.",
                "Hit one ball to each target without changing tempo.",
                "Restart the ladder if contact gets heavy or thin."
            ],
            remedialDrillID: "n8",
            defaultRepCount: 9
        ),
        GarageDrill(
            id: "r13",
            title: "Distance Ladder",
            environment: .range,
            faultType: .tempo,
            clubRange: .wedges,
            purpose: "Calibrate wedge carry numbers with one repeatable rhythm.",
            libraryCategory: .distanceControl,
            abstractFeelCue: "Dial the volume knob: four, six, eight.",
            executionSteps: [
                "Pick carry numbers at fifty, sixty-five, and eighty yards.",
                "Land one ball at each number before repeating the ladder.",
                "Keep the rhythm constant while the length of swing changes."
            ],
            remedialDrillID: "n2",
            defaultRepCount: 9
        ),
        GarageDrill(
            id: "r14",
            title: "Three-Flight Wedge Matrix",
            environment: .range,
            faultType: .tempo,
            clubRange: .wedges,
            purpose: "Own low, stock, and high windows without changing effort or pace.",
            libraryCategory: .distanceControl,
            abstractFeelCue: "Own low, stock, and high windows without changing effort.",
            executionSteps: [
                "Pick one wedge distance.",
                "Hit low, stock, and high windows in that order.",
                "Keep the same rhythm while the finish height changes."
            ],
            remedialDrillID: "r13",
            defaultRepCount: 9
        ),
        GarageDrill(
            id: "r15",
            title: "Fairway Gate Driver",
            environment: .range,
            faultType: .faceControl,
            clubRange: .driver,
            purpose: "Make driver practice measurable with a fairway-sized start gate and held finish.",
            libraryCategory: .pressure,
            abstractFeelCue: "Launch driver through a fairway-sized start gate with balance.",
            executionSteps: [
                "Pick a fairway-width landing picture.",
                "Hit driver only when the finish holds for two counts.",
                "Reset after any shot that starts outside the gate."
            ],
            remedialDrillID: "n3",
            defaultRepCount: 6
        ),
        GarageDrill(
            id: "r16",
            title: "Nine-To-Three Flight",
            environment: .range,
            faultType: .casting,
            clubRange: .scoringIrons,
            purpose: "Train a shorter, flighted motion that keeps the handle organized through impact.",
            libraryCategory: .delivery,
            abstractFeelCue: "Keep the club heavy and flight the ball from a shorter swing.",
            executionSteps: [
                "Make nine-to-three swings with a mid iron.",
                "Hold the handle forward through the exit.",
                "Only lengthen the motion after the flight stays boring."
            ],
            remedialDrillID: "n7",
            defaultRepCount: 8
        ),
        GarageDrill(
            id: "r17",
            title: "Pressure Fairway Ladder",
            environment: .range,
            faultType: .earlyExtension,
            clubRange: .woods,
            purpose: "Add target pressure only when posture, turn, and balance still hold up.",
            libraryCategory: .pressure,
            abstractFeelCue: "Add pressure only if the body keeps turning through the shot.",
            executionSteps: [
                "Choose three fairway targets of increasing difficulty.",
                "Advance only after a balanced finish inside the window.",
                "Restart the ladder if the body stalls or crowds the ball."
            ],
            remedialDrillID: "n3",
            defaultRepCount: 6
        ),
        GarageDrill(
            id: "p1",
            title: "The Coin Roll",
            environment: .puttingGreen,
            faultType: .fatThin,
            clubRange: .putter,
            purpose: "Train cleaner end-over-end roll and face stability from short range.",
            libraryCategory: .putting,
            abstractFeelCue: "Roll the ball end-over-end like a perfectly spun coin.",
            executionSteps: [
                "Draw a line on the ball.",
                "Putt from five feet and watch for a stable roll.",
                "Restart the set if the line wobbles."
            ],
            defaultRepCount: 10
        ),
        GarageDrill(
            id: "p2",
            title: "Leapfrog Lag",
            environment: .puttingGreen,
            faultType: .tempo,
            clubRange: .putter,
            purpose: "Build lag putting touch by making each next ball finish slightly farther.",
            libraryCategory: .putting,
            abstractFeelCue: "Paint the green with increasingly longer strokes.",
            executionSteps: [
                "Putt the first ball ten feet.",
                "Each next ball must roll one foot past the previous ball.",
                "Continue until you reach thirty feet without racing it."
            ],
            remedialDrillID: "p1",
            defaultRepCount: 6
        ),
        GarageDrill(
            id: "p3",
            title: "Gate Start Builder",
            environment: .puttingGreen,
            faultType: .faceControl,
            clubRange: .putter,
            purpose: "Tighten putting start line by forcing the face and ball through a gate.",
            libraryCategory: .putting,
            abstractFeelCue: "Roll the ball through a tiny gate before reading break.",
            executionSteps: [
                "Set two tees just wider than the putter head.",
                "Roll putts through the gate from four feet.",
                "Count only reps that start clean and stay online."
            ],
            remedialDrillID: "p1",
            defaultRepCount: 10
        ),
        GarageDrill(
            id: "p4",
            title: "Around-The-World Pace",
            environment: .puttingGreen,
            faultType: .tempo,
            clubRange: .putter,
            purpose: "Keep stroke tempo steady while the required distance changes around the hole.",
            libraryCategory: .putting,
            abstractFeelCue: "Keep the same tempo while distance changes around the circle.",
            executionSteps: [
                "Place tees at four distances around one hole.",
                "Putt one ball from each spot without pausing the rhythm.",
                "Restart if the pace jumps or the stroke gets jabby."
            ],
            remedialDrillID: "p2",
            defaultRepCount: 8
        ),
        GarageDrill(
            id: "p5",
            title: "Lead-Hand Face Check",
            environment: .puttingGreen,
            faultType: .faceControl,
            clubRange: .putter,
            purpose: "Let the lead hand organize the face so the stroke starts online without extra hit.",
            libraryCategory: .putting,
            abstractFeelCue: "Let the lead hand control the face without extra hit.",
            executionSteps: [
                "Hit short putts with the trail hand off the club.",
                "Keep the face square through the hitting zone.",
                "Add the trail hand back only when the start line holds."
            ],
            remedialDrillID: "p3",
            defaultRepCount: 8
        ),
        GarageDrill(
            id: "p6",
            title: "Three-Ball Brake Test",
            environment: .puttingGreen,
            faultType: .fatThin,
            clubRange: .putter,
            purpose: "Improve pace discipline by landing multiple putts in the same stop zone.",
            libraryCategory: .putting,
            abstractFeelCue: "Land pace in the same stop zone three times in a row.",
            executionSteps: [
                "Pick a stop zone two feet past the hole.",
                "Roll three balls that all finish inside the zone.",
                "Restart the set after any ball that races or dies early."
            ],
            remedialDrillID: "p2",
            defaultRepCount: 6
        )
    ]

    private static let catalogRoutines: [GarageRoutine] = [
        GarageRoutine(
            id: "net-contact-reset",
            title: "Contact Reset",
            environment: .net,
            purpose: "Sharpen strike and low-point control before speed.",
            drillIDs: ["n1", "n8", "n2"],
            estimatedMinutes: 18,
            difficulty: .foundation
        ),
        GarageRoutine(
            id: "net-tempo-balance",
            title: "Tempo & Balance",
            environment: .net,
            purpose: "Slow the motion down and own the finish.",
            drillIDs: ["n5", "n6", "n4"],
            estimatedMinutes: 20,
            difficulty: .foundation
        ),
        GarageRoutine(
            id: "net-rotation-check",
            title: "Rotation Check",
            environment: .net,
            purpose: "Keep the body turning so space stays open through impact.",
            drillIDs: ["n3", "n4", "n7"],
            estimatedMinutes: 19,
            difficulty: .focused
        ),
        GarageRoutine(
            id: "range-wedge-distance-ladder",
            title: "Wedge Distance Ladder",
            environment: .range,
            purpose: "Calibrate carry numbers with one repeatable rhythm.",
            drillIDs: ["r13", "r14", "r12"],
            estimatedMinutes: 24,
            difficulty: .focused
        ),
        GarageRoutine(
            id: "range-start-line-control",
            title: "Start-Line Control",
            environment: .range,
            purpose: "Own launch direction before chasing shape.",
            drillIDs: ["r10", "r11", "r16"],
            estimatedMinutes: 22,
            difficulty: .focused
        ),
        GarageRoutine(
            id: "range-driver-control",
            title: "Driver Control",
            environment: .range,
            purpose: "Launch driver on line and keep the finish athletic.",
            drillIDs: ["r15", "r17", "r10"],
            estimatedMinutes: 24,
            difficulty: .advanced
        ),
        GarageRoutine(
            id: "green-start-line-builder",
            title: "Start Line Builder",
            environment: .puttingGreen,
            purpose: "Train a cleaner face and more predictable roll.",
            drillIDs: ["p1", "p3", "p5"],
            estimatedMinutes: 17,
            difficulty: .foundation
        ),
        GarageRoutine(
            id: "green-pace-control",
            title: "Pace Control",
            environment: .puttingGreen,
            purpose: "Match stroke length to distance without racing putts.",
            drillIDs: ["p2", "p4", "p6"],
            estimatedMinutes: 19,
            difficulty: .focused
        )
    ]

    private static let catalogMetadata: [String: GarageDrillMetadata] = Dictionary(
        uniqueKeysWithValues: [
            metadata(
                drillID: "n1",
                promptTags: ["contact", "fat_shots", "low_point", "heavy_contact", "ball_first"],
                faultTags: ["fat_shots", "thin_shots", "poor_low_point_control"],
                equipmentRules: [.towel],
                primaryCategory: .contact,
                minReps: 8,
                maxReps: 30,
                progressionIDs: ["n8"],
                regressionIDs: ["n2"]
            ),
            metadata(
                drillID: "n2",
                promptTags: ["casting", "handle_forward", "compression", "delivery", "scoop"],
                faultTags: ["casting", "flipping", "scooping", "weak_contact"],
                primaryCategory: .delivery,
                minReps: 6,
                maxReps: 24,
                progressionIDs: ["n7", "r16"],
                regressionIDs: []
            ),
            metadata(
                drillID: "n3",
                promptTags: ["rotation", "early_extension", "posture", "hip_depth", "standing_up"],
                faultTags: ["early_extension", "loss_of_posture", "crowded_impact"],
                requiredAnyEquipmentGroups: [[.wall, .alignmentStick]],
                safetyConstraints: [.noFullSpeedSwingsNearWall, .rehearsalPreferred],
                primaryCategory: .rotation,
                minReps: 6,
                maxReps: 22,
                progressionIDs: ["r17"],
                regressionIDs: []
            ),
            metadata(
                drillID: "n4",
                promptTags: ["face", "start_line", "alignment", "slice", "hook", "curving"],
                faultTags: ["face_control", "open_face", "closed_face", "start_line_miss"],
                equipmentRules: [.alignmentStick],
                safetyConstraints: [.safeStickPositionRequired],
                primaryCategory: .faceControl,
                minReps: 6,
                maxReps: 24,
                progressionIDs: ["r10", "r11"],
                regressionIDs: ["n2"]
            ),
            metadata(
                drillID: "n5",
                promptTags: ["tempo", "balance", "sway", "rhythm", "centered"],
                faultTags: ["poor_balance", "sway", "rushed_tempo"],
                safetyConstraints: [.controlledSwingsOnly],
                primaryCategory: .tempo,
                minReps: 8,
                maxReps: 30,
                progressionIDs: ["n6"],
                regressionIDs: []
            ),
            metadata(
                drillID: "n6",
                promptTags: ["tempo", "transition", "rushing", "sequencing", "pressure_shift"],
                faultTags: ["quick_transition", "arms_first_downswing", "poor_sequence"],
                safetyConstraints: [.controlledSwingsOnly],
                primaryCategory: .tempo,
                minReps: 6,
                maxReps: 24,
                progressionIDs: ["n8", "r16"],
                regressionIDs: ["n5"]
            ),
            metadata(
                drillID: "n7",
                promptTags: ["shallow", "exit", "casting", "delivery", "chest_turn"],
                faultTags: ["casting", "over_the_top", "stalled_rotation"],
                optionalEquipment: [.headcover],
                safetyConstraints: [.controlledSwingsOnly],
                primaryCategory: .delivery,
                minReps: 6,
                maxReps: 24,
                progressionIDs: ["r16"],
                regressionIDs: ["n2"]
            ),
            metadata(
                drillID: "n8",
                promptTags: ["contact", "brush", "strike_location", "fat_shots", "thin_shots"],
                faultTags: ["fat_shots", "thin_shots", "inconsistent_contact"],
                safetyConstraints: [.halfSwingsOnly],
                primaryCategory: .contact,
                minReps: 6,
                maxReps: 24,
                progressionIDs: ["n1", "r12"],
                regressionIDs: ["n5"]
            ),
            metadata(
                drillID: "r10",
                promptTags: ["driver", "start_line", "face", "fairway", "slice"],
                faultTags: ["face_control", "start_line_miss", "driver_dispersion"],
                primaryCategory: .pressure,
                minReps: 4,
                maxReps: 18,
                progressionIDs: ["r15"],
                regressionIDs: ["n4"]
            ),
            metadata(
                drillID: "r11",
                promptTags: ["long_iron", "start_line", "face", "window", "trajectory"],
                faultTags: ["face_control", "start_line_miss", "long_iron_dispersion"],
                primaryCategory: .pressure,
                minReps: 4,
                maxReps: 18,
                progressionIDs: ["r10"],
                regressionIDs: ["n4"]
            ),
            metadata(
                drillID: "r12",
                promptTags: ["contact", "carry", "strike", "distance", "fat_shots", "thin_shots"],
                faultTags: ["fat_shots", "thin_shots", "carry_inconsistency"],
                primaryCategory: .contact,
                minReps: 6,
                maxReps: 27,
                progressionIDs: ["r13"],
                regressionIDs: ["n8"]
            ),
            metadata(
                drillID: "r13",
                promptTags: ["wedge", "distance", "carry", "ladder", "tempo"],
                faultTags: ["distance_control", "wedge_carry_miss", "deceleration"],
                primaryCategory: .distanceControl,
                minReps: 6,
                maxReps: 27,
                progressionIDs: ["r14"],
                regressionIDs: ["n2"]
            ),
            metadata(
                drillID: "r14",
                promptTags: ["wedge", "flight", "trajectory", "distance", "window"],
                faultTags: ["distance_control", "trajectory_control", "wedge_carry_miss"],
                primaryCategory: .distanceControl,
                minReps: 6,
                maxReps: 27,
                progressionIDs: ["r13"],
                regressionIDs: ["r13"]
            ),
            metadata(
                drillID: "r15",
                promptTags: ["driver", "fairway", "start_line", "balance", "pressure"],
                faultTags: ["driver_dispersion", "overswinging", "poor_balance"],
                primaryCategory: .pressure,
                minReps: 4,
                maxReps: 18,
                progressionIDs: ["r17"],
                regressionIDs: ["r10"]
            ),
            metadata(
                drillID: "r16",
                promptTags: ["flighted", "handle", "compression", "casting", "contact"],
                faultTags: ["casting", "flipping", "weak_contact"],
                primaryCategory: .delivery,
                minReps: 6,
                maxReps: 24,
                progressionIDs: ["r12"],
                regressionIDs: ["n7", "n2"]
            ),
            metadata(
                drillID: "r17",
                promptTags: ["pressure", "fairway", "rotation", "posture", "woods"],
                faultTags: ["early_extension", "loss_of_posture", "pressure_miss"],
                primaryCategory: .pressure,
                minReps: 4,
                maxReps: 18,
                progressionIDs: ["r15"],
                regressionIDs: ["n3"]
            ),
            metadata(
                drillID: "p1",
                promptTags: ["putting", "roll", "face", "start_line", "short_putts"],
                faultTags: ["wobbly_roll", "face_control", "poor_start_line"],
                optionalEquipment: [.puttingMat],
                primaryCategory: .putting,
                minReps: 6,
                maxReps: 30,
                progressionIDs: ["p3", "p5"],
                regressionIDs: []
            ),
            metadata(
                drillID: "p2",
                promptTags: ["putting", "speed", "lag", "pace", "distance"],
                faultTags: ["poor_pace", "lag_putting", "distance_control"],
                primaryCategory: .putting,
                minReps: 4,
                maxReps: 18,
                progressionIDs: ["p4", "p6"],
                regressionIDs: ["p1"]
            ),
            metadata(
                drillID: "p3",
                promptTags: ["putting", "gate", "start_line", "face", "short_putts"],
                faultTags: ["poor_start_line", "face_control", "pushed_putts", "pulled_putts"],
                equipmentRules: [.tee],
                optionalEquipment: [.puttingGate],
                safetyConstraints: [.lightweightGateObjectsOnly],
                primaryCategory: .putting,
                minReps: 6,
                maxReps: 30,
                progressionIDs: ["p5"],
                regressionIDs: ["p1"]
            ),
            metadata(
                drillID: "p4",
                promptTags: ["putting", "tempo", "pace", "around_the_world", "speed"],
                faultTags: ["poor_pace", "rushed_tempo", "jabby_stroke"],
                equipmentRules: [.tee],
                primaryCategory: .putting,
                minReps: 6,
                maxReps: 24,
                progressionIDs: ["p6"],
                regressionIDs: ["p2"]
            ),
            metadata(
                drillID: "p5",
                promptTags: ["putting", "lead_hand", "face", "start_line", "release"],
                faultTags: ["face_control", "poor_start_line", "trail_hand_hit"],
                primaryCategory: .putting,
                minReps: 6,
                maxReps: 24,
                progressionIDs: ["p3"],
                regressionIDs: ["p1"]
            ),
            metadata(
                drillID: "p6",
                promptTags: ["putting", "speed", "pace", "stop_zone", "lag"],
                faultTags: ["poor_pace", "distance_control", "lag_putting"],
                optionalEquipment: [.tee],
                primaryCategory: .putting,
                minReps: 4,
                maxReps: 18,
                progressionIDs: ["p4"],
                regressionIDs: ["p2"]
            )
        ].map { ($0.drillID, $0) }
    )

    private static func metadata(
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
        regressionIDs: [String] = []
    ) -> GarageDrillMetadata {
        GarageDrillMetadata(
            drillID: drillID,
            promptTags: promptTags,
            faultTags: faultTags,
            equipmentRules: equipmentRules,
            requiredAnyEquipmentGroups: requiredAnyEquipmentGroups,
            optionalEquipment: optionalEquipment,
            safetyConstraints: safetyConstraints,
            primaryCategory: primaryCategory,
            minReps: minReps,
            maxReps: maxReps,
            progressionIDs: progressionIDs,
            regressionIDs: regressionIDs,
            recommendationRules: [
                GarageRecommendationRule(
                    trigger: .lowScore,
                    threshold: 60,
                    action: "Repeat this category soon or use the listed regression.",
                    relatedDrillIDs: regressionIDs
                ),
                GarageRecommendationRule(
                    trigger: .highScore,
                    threshold: 80,
                    action: "Allow progression or shift toward an adjacent category.",
                    relatedDrillIDs: progressionIDs
                )
            ]
        )
    }

    private static func fallbackMetadata(for drill: GarageDrill) -> GarageDrillMetadata {
        GarageDrillMetadata(
            drillID: drill.id,
            promptTags: Set([drill.libraryCategory.rawValue, drill.faultType.rawValue, drill.title].map(normalizedMetadataToken)),
            faultTags: Set([drill.faultType.rawValue].map(normalizedMetadataToken)),
            primaryCategory: drill.libraryCategory,
            minReps: max(1, drill.defaultRepCount / 2),
            maxReps: max(drill.defaultRepCount, drill.defaultRepCount * 3),
            regressionIDs: drill.remedialDrillID.map { [$0] } ?? []
        )
    }

    private static func validateCatalog(
        drills: [GarageDrill],
        routines: [GarageRoutine]
    ) -> [String] {
        var errors: [String] = []

        let drillCounts = Dictionary(grouping: drills, by: \.environment).mapValues(\.count)
        let routineCounts = Dictionary(grouping: routines, by: \.environment).mapValues(\.count)

        if drills.count != 22 {
            errors.append("Expected 22 drills but found \(drills.count).")
        }

        if drillCounts[.net] != 8 {
            errors.append("Expected 8 net drills but found \(drillCounts[.net] ?? 0).")
        }

        if drillCounts[.range] != 8 {
            errors.append("Expected 8 range drills but found \(drillCounts[.range] ?? 0).")
        }

        if drillCounts[.puttingGreen] != 6 {
            errors.append("Expected 6 putting green drills but found \(drillCounts[.puttingGreen] ?? 0).")
        }

        if routines.count != 8 {
            errors.append("Expected 8 routines but found \(routines.count).")
        }

        if routineCounts[.net] != 3 {
            errors.append("Expected 3 net routines but found \(routineCounts[.net] ?? 0).")
        }

        if routineCounts[.range] != 3 {
            errors.append("Expected 3 range routines but found \(routineCounts[.range] ?? 0).")
        }

        if routineCounts[.puttingGreen] != 2 {
            errors.append("Expected 2 putting green routines but found \(routineCounts[.puttingGreen] ?? 0).")
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
            if routine.drillIDs.isEmpty {
                errors.append("Routine \(routine.id) has no drills.")
            }

            let duplicateRoutineDrillIDs = duplicateIDs(in: routine.drillIDs)
            if duplicateRoutineDrillIDs.isEmpty == false {
                errors.append("Routine \(routine.id) repeats drill IDs: \(duplicateRoutineDrillIDs.joined(separator: ", ")).")
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

            let relatedIDs = metadata.progressionIDs + metadata.regressionIDs + metadata.recommendationRules.flatMap(\.relatedDrillIDs)
            let missingRelatedIDs = relatedIDs.filter { drillIDs.contains($0) == false }
            if missingRelatedIDs.isEmpty == false {
                errors.append("Metadata \(metadata.drillID) references missing related drills: \(missingRelatedIDs.joined(separator: ", ")).")
            }
        }

        for environment in PracticeEnvironment.allCases {
            let environmentHasMetadata = drills.contains { drill in
                drill.environment == environment && metadataByDrillID[drill.id] != nil
            }

            if environmentHasMetadata == false {
                errors.append("No metadata-backed drills available for \(environment.displayName).")
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
            focusArea: faultType.sensoryDescription,
            targetClub: clubRange.displayName,
            defaultRepCount: clampedRepCount
        )
    }

    fileprivate func makePracticeTemplateDrill(seedKey: String) -> PracticeTemplateDrill {
        PracticeTemplateDrill(
            id: GarageCatalogBridge.uuid(for: "routine-drill:\(seedKey)"),
            definitionID: GarageCatalogBridge.uuid(for: "catalog-drill:\(id)"),
            title: title,
            focusArea: faultType.sensoryDescription,
            targetClub: clubRange.displayName,
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
