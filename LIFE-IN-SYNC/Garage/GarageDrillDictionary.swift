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

struct GarageDrill: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let title: String
    let environment: PracticeEnvironment
    let faultType: FaultType
    let clubRange: ClubRange
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

    init(
        id: String,
        title: String,
        environment: PracticeEnvironment,
        purpose: String,
        drillIDs: [String]
    ) {
        self.id = id
        self.title = title
        self.environment = environment
        self.purpose = purpose
        self.drillIDs = drillIDs
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

    static func routine(for id: String) -> GarageRoutine? {
        _ = catalogValidationMarker
        return catalogRoutines.first(where: { $0.id == id })
    }

    static func drills(for routine: GarageRoutine) -> [GarageDrill] {
        _ = catalogValidationMarker
        return routine.drillIDs.compactMap { drill(for: $0) }
    }

    static func drillCount(in environment: PracticeEnvironment) -> Int {
        _ = catalogValidationMarker
        return catalogDrills.filter { $0.environment == environment }.count
    }

    static func routineCount(in environment: PracticeEnvironment) -> Int {
        _ = catalogValidationMarker
        return catalogRoutines.filter { $0.environment == environment }.count
    }

    static func validationErrors() -> [String] {
        validateCatalog(drills: catalogDrills, routines: catalogRoutines)
    }

    private static let catalogValidationMarker: Void = {
        #if DEBUG
        let errors = validateCatalog(drills: catalogDrills, routines: catalogRoutines)
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
            drillIDs: ["n1", "n8", "n2"]
        ),
        GarageRoutine(
            id: "net-tempo-balance",
            title: "Tempo & Balance",
            environment: .net,
            purpose: "Slow the motion down and own the finish.",
            drillIDs: ["n5", "n6", "n4"]
        ),
        GarageRoutine(
            id: "net-rotation-check",
            title: "Rotation Check",
            environment: .net,
            purpose: "Keep the body turning so space stays open through impact.",
            drillIDs: ["n3", "n4", "n7"]
        ),
        GarageRoutine(
            id: "range-wedge-distance-ladder",
            title: "Wedge Distance Ladder",
            environment: .range,
            purpose: "Calibrate carry numbers with one repeatable rhythm.",
            drillIDs: ["r13", "r14", "r12"]
        ),
        GarageRoutine(
            id: "range-start-line-control",
            title: "Start-Line Control",
            environment: .range,
            purpose: "Own launch direction before chasing shape.",
            drillIDs: ["r10", "r11", "r16"]
        ),
        GarageRoutine(
            id: "range-driver-control",
            title: "Driver Control",
            environment: .range,
            purpose: "Launch driver on line and keep the finish athletic.",
            drillIDs: ["r15", "r17", "r10"]
        ),
        GarageRoutine(
            id: "green-start-line-builder",
            title: "Start Line Builder",
            environment: .puttingGreen,
            purpose: "Train a cleaner face and more predictable roll.",
            drillIDs: ["p1", "p3", "p5"]
        ),
        GarageRoutine(
            id: "green-pace-control",
            title: "Pace Control",
            environment: .puttingGreen,
            purpose: "Match stroke length to distance without racing putts.",
            drillIDs: ["p2", "p4", "p6"]
        )
    ]

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
