import Foundation

enum PracticeEnvironment: String, CaseIterable, Codable, Identifiable, Hashable {
    case net
    case range
    case puttingGreen

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .net:
            return "Net"
        case .range:
            return "Range"
        case .puttingGreen:
            return "Putting Green"
        }
    }

    var systemImage: String {
        switch self {
        case .net:
            return "figure.golf"
        case .range:
            return "flag.pattern.checkered"
        case .puttingGreen:
            return "circle.grid.2x2"
        }
    }

    var description: String {
        switch self {
        case .net:
            return "Tight feedback loops for mechanics, contact, and rehearsal."
        case .range:
            return "Ball-flight practice with target windows and club-specific patterns."
        case .puttingGreen:
            return "Start line, pace control, and green-reading reps."
        }
    }
}

struct PracticeDrill: Identifiable, Hashable, Codable {
    let id: UUID
    let title: String
    let detail: String

    init(
        id: UUID = UUID(),
        title: String,
        detail: String
    ) {
        self.id = id
        self.title = title
        self.detail = detail
    }
}

struct PracticeTemplate: Identifiable, Hashable, Codable {
    let id: UUID
    let title: String
    let environments: [PracticeEnvironment]
    let drills: [PracticeDrill]

    init(
        id: UUID = UUID(),
        title: String,
        environments: [PracticeEnvironment],
        drills: [PracticeDrill]
    ) {
        self.id = id
        self.title = title
        self.environments = environments
        self.drills = drills
    }

    static let starterTemplates: [PracticeTemplate] = [
        PracticeTemplate(
            title: "Net Start-Line Calibration",
            environments: [.net],
            drills: [
                PracticeDrill(
                    title: "Nine-ball setup check",
                    detail: "Hit three stock shots each with wedge, 8-iron, and driver while holding the same start-line gate."
                ),
                PracticeDrill(
                    title: "Face-to-path rehearsal",
                    detail: "Alternate one slow-motion rehearsal with one live swing for six reps."
                ),
                PracticeDrill(
                    title: "Miss pattern note",
                    detail: "Write one sentence on the most common start direction before ending the block."
                )
            ]
        ),
        PracticeTemplate(
            title: "100-Yard Wedge Matrix",
            environments: [.range],
            drills: [
                PracticeDrill(
                    title: "Carry ladder",
                    detail: "Hit five balls each to 80, 90, 100, and 110 yards with one wedge."
                ),
                PracticeDrill(
                    title: "Window discipline",
                    detail: "Keep every shot inside one launch-window intention: low, stock, or high."
                ),
                PracticeDrill(
                    title: "Distance audit",
                    detail: "Record the best and worst carry numbers from the set."
                )
            ]
        ),
        PracticeTemplate(
            title: "Pressure Putting Ladder",
            environments: [.puttingGreen],
            drills: [
                PracticeDrill(
                    title: "Three-foot circle",
                    detail: "Make 12 in a row before moving back."
                ),
                PracticeDrill(
                    title: "Six-foot gate",
                    detail: "Roll 10 putts through a start-line gate with matching pace."
                ),
                PracticeDrill(
                    title: "One-ball finish",
                    detail: "End with one putt from your weakest distance and document the result."
                )
            ]
        ),
        PracticeTemplate(
            title: "Tempo and Contact Reset",
            environments: [.net, .range],
            drills: [
                PracticeDrill(
                    title: "Metronome block",
                    detail: "Match backswing and downswing cadence for eight reps before removing the cue."
                ),
                PracticeDrill(
                    title: "Center-face check",
                    detail: "Hit 10 shots focusing only on strike location, not result."
                ),
                PracticeDrill(
                    title: "Commitment rep",
                    detail: "Finish with three full-routine swings at game speed."
                )
            ]
        ),
        PracticeTemplate(
            title: "Short Game Landing Spot Circuit",
            environments: [.range, .puttingGreen],
            drills: [
                PracticeDrill(
                    title: "Landing towel",
                    detail: "Choose one landing spot and hit eight chips or pitches trying to land on it."
                ),
                PracticeDrill(
                    title: "Release pattern",
                    detail: "Alternate low-checking and higher-releasing trajectories for six reps each."
                ),
                PracticeDrill(
                    title: "Up-and-down finish",
                    detail: "Simulate three one-ball save attempts with full routine."
                )
            ]
        ),
        PracticeTemplate(
            title: "Pre-Round Readiness",
            environments: [.net, .range, .puttingGreen],
            drills: [
                PracticeDrill(
                    title: "Body and grip reset",
                    detail: "Take five unrushed rehearsals with alignment and grip pressure awareness."
                ),
                PracticeDrill(
                    title: "One-club confidence rep",
                    detail: "Choose the club or stroke you trust most and bank five clean executions."
                ),
                PracticeDrill(
                    title: "Single intention close",
                    detail: "Leave with one simple swing or stroke cue for the next session."
                )
            ]
        )
    ]
}

struct PracticeDrillProgress: Hashable, Codable {
    let drillID: UUID
    var isCompleted: Bool
    var note: String

    init(
        drillID: UUID,
        isCompleted: Bool = false,
        note: String = ""
    ) {
        self.drillID = drillID
        self.isCompleted = isCompleted
        self.note = note
    }
}

struct ActivePracticeSession: Identifiable, Hashable, Codable {
    let id: UUID
    let template: PracticeTemplate
    let environment: PracticeEnvironment
    let startedAt: Date
    var endedAt: Date?
    var drillProgress: [PracticeDrillProgress]

    init(
        id: UUID = UUID(),
        template: PracticeTemplate,
        environment: PracticeEnvironment,
        startedAt: Date = .now,
        endedAt: Date? = nil,
        drillProgress: [PracticeDrillProgress]? = nil
    ) {
        self.id = id
        self.template = template
        self.environment = environment
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.drillProgress = drillProgress ?? template.drills.map {
            PracticeDrillProgress(drillID: $0.id)
        }
    }
}
