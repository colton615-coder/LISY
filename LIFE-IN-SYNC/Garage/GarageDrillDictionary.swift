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

enum DrillVault {
    static let masterPlaybook: [GarageDrill] = [
        GarageDrill(
            id: "n1",
            title: "Heavy Towel Strike",
            environment: .net,
            faultType: .fatThin,
            clubRange: .scoringIrons,
            abstractFeelCue: "Feel the clubhead drag through thick mud.",
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
            abstractFeelCue: "Let the handle lead while the clubhead stays heavy behind you.",
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
            abstractFeelCue: "Keep your hips turning behind you instead of crashing toward the ball.",
            executionSteps: [
                "Stand with your trail hip a few inches from a wall.",
                "Rehearse back-and-through swings without bumping the wall.",
                "Finish balanced with your chest fully turned."
            ],
            defaultRepCount: 8
        ),
        GarageDrill(
            id: "n5",
            title: "The Pillar Pivot",
            environment: .net,
            faultType: .tempo,
            clubRange: .woods,
            abstractFeelCue: "Swing inside a phone booth.",
            executionSteps: [
                "Set your feet together to narrow the base.",
                "Make smooth swings at sixty percent speed.",
                "Finish in balance for a full two-count."
            ],
            defaultRepCount: 10
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
        )
    ]

    static func drill(for id: String) -> GarageDrill? {
        masterPlaybook.first(where: { $0.id == id })
    }
}

extension GarageDrill {
    func makePracticeTemplate() -> PracticeTemplate {
        PracticeTemplate(
            title: "Prescription • \(title)",
            environment: environment.rawValue,
            drills: makePracticeDrills()
        )
    }

    private func makePracticeDrills() -> [PracticeTemplateDrill] {
        var drills = [asPracticeTemplateDrill]

        if let remedialDrillID,
           remedialDrillID != id,
           let remedial = DrillVault.drill(for: remedialDrillID) {
            drills.append(remedial.asPracticeTemplateDrill)
        }

        return drills
    }

    private var asPracticeTemplateDrill: PracticeTemplateDrill {
        PracticeTemplateDrill(
            title: title,
            focusArea: faultType.sensoryDescription,
            targetClub: clubRange.displayName,
            defaultRepCount: defaultRepCount
        )
    }
}
