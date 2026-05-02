import Foundation

struct GarageGeneratedPracticePlan: Identifiable, Hashable {
    let id: UUID
    var title: String
    let environment: PracticeEnvironment
    var objective: String
    var coachNote: String
    var carryForwardNote: String?
    var drills: [PracticeTemplateDrill]

    init(
        id: UUID = UUID(),
        title: String,
        environment: PracticeEnvironment,
        objective: String,
        coachNote: String,
        carryForwardNote: String? = nil,
        drills: [PracticeTemplateDrill]
    ) {
        self.id = id
        self.title = title
        self.environment = environment
        self.objective = objective
        self.coachNote = coachNote
        self.carryForwardNote = carryForwardNote
        self.drills = drills
    }

    var totalRepCount: Int {
        drills.reduce(0) { $0 + $1.defaultRepCount }
    }

    var estimatedDurationMinutes: Int {
        max(12, drills.count * 6)
    }

    var workSummary: String {
        "\(drills.count) drills - \(totalRepCount) reps - \(estimatedDurationMinutes) min"
    }

    var canStart: Bool {
        drills.isEmpty == false
    }

    mutating func removeDrill(id drillID: UUID) {
        guard drills.count > 1 else {
            return
        }

        drills.removeAll { $0.id == drillID }
    }

    func makePracticeTemplate() -> PracticeTemplate {
        PracticeTemplate(
            id: id,
            title: title,
            environment: environment.rawValue,
            drills: drills
        )
    }
}

enum GarageLocalCoachPlanner {
    static func generatePlan(
        for environment: PracticeEnvironment,
        recentRecords: [PracticeSessionRecord]
    ) -> GarageGeneratedPracticePlan {
        let environmentRecords = recentRecords
            .filter { $0.environment == environment.rawValue }
            .sorted { $0.date > $1.date }
        let carryForwardCue = environmentRecords.first?.garagePlannerCarryForwardCue
        let selectedDrills = selectedDrills(
            for: environment,
            environmentRecords: environmentRecords
        )
        let templateDrills = selectedDrills.enumerated().map { offset, drill in
            drill.makeGeneratedPracticeTemplateDrill(seedKey: "local-plan:\(environment.rawValue):\(offset):\(drill.id)")
        }

        return GarageGeneratedPracticePlan(
            title: title(for: environment, hasHistory: environmentRecords.isEmpty == false),
            environment: environment,
            objective: objective(for: environment, carryForwardCue: carryForwardCue),
            coachNote: coachNote(for: environment, records: environmentRecords, carryForwardCue: carryForwardCue),
            carryForwardNote: carryForwardCue,
            drills: templateDrills
        )
    }

    private static func selectedDrills(
        for environment: PracticeEnvironment,
        environmentRecords: [PracticeSessionRecord]
    ) -> [GarageDrill] {
        let environmentDrills = DrillVault.masterPlaybook.filter { $0.environment == environment }
        guard environmentDrills.isEmpty == false else {
            return Array(DrillVault.masterPlaybook.prefix(3))
        }

        var selected: [GarageDrill] = []

        if let weakDrill = weakestRecentDrill(
            for: environment,
            environmentRecords: environmentRecords,
            environmentDrills: environmentDrills
        ) {
            if let remedialDrillID = weakDrill.remedialDrillID,
               let remedialDrill = DrillVault.drill(for: remedialDrillID),
               remedialDrill.environment == environment {
                append(remedialDrill, to: &selected)
            }

            append(weakDrill, to: &selected)
        }

        let defaultRoutineDrills = DrillVault.predefinedRoutines
            .first { $0.environment == environment }
            .map { DrillVault.drills(for: $0) } ?? []

        for drill in defaultRoutineDrills {
            append(drill, to: &selected)
        }

        for drill in environmentDrills {
            append(drill, to: &selected)
        }

        return Array(selected.prefix(3))
    }

    private static func weakestRecentDrill(
        for environment: PracticeEnvironment,
        environmentRecords: [PracticeSessionRecord],
        environmentDrills: [GarageDrill]
    ) -> GarageDrill? {
        let recentResults = environmentRecords
            .prefix(3)
            .flatMap(\.drillResults)
            .filter { $0.totalReps > 0 }

        guard let weakestResult = recentResults.sorted(by: weakestResultSort).first else {
            return nil
        }

        return environmentDrills.first {
            $0.title.caseInsensitiveCompare(weakestResult.name) == .orderedSame
        }
    }

    nonisolated private static func weakestResultSort(_ lhs: DrillResult, _ rhs: DrillResult) -> Bool {
        if lhs.successRatio == rhs.successRatio {
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }

        return lhs.successRatio < rhs.successRatio
    }

    private static func append(_ drill: GarageDrill, to selected: inout [GarageDrill]) {
        guard selected.contains(where: { $0.id == drill.id }) == false else {
            return
        }

        selected.append(drill)
    }

    private static func title(for environment: PracticeEnvironment, hasHistory: Bool) -> String {
        if hasHistory {
            return "\(environment.displayName) Coach Plan"
        }

        return "\(environment.displayName) Foundation Session"
    }

    private static func objective(
        for environment: PracticeEnvironment,
        carryForwardCue: String?
    ) -> String {
        if carryForwardCue != nil {
            return "Turn the last useful cue into measured, repeatable reps."
        }

        switch environment {
        case .net:
            return "Build clean contact and body control before chasing speed."
        case .range:
            return "Stabilize start line, carry window, and finish balance."
        case .puttingGreen:
            return "Train start line and pace with simple feedback loops."
        }
    }

    private static func coachNote(
        for environment: PracticeEnvironment,
        records: [PracticeSessionRecord],
        carryForwardCue: String?
    ) -> String {
        if let carryForwardCue {
            return "Carry this forward: \(carryForwardCue)"
        }

        if records.isEmpty {
            return "No history yet. Start with a balanced \(environment.displayName.lowercased()) baseline and log the rep quality honestly."
        }

        return "No clear carry-forward cue was saved. Use this session to create one reliable note for the next practice."
    }
}

private extension PracticeSessionRecord {
    var garagePlannerCarryForwardCue: String? {
        if let cue = GarageCoachingInsight.decode(from: aiCoachingInsight)?
            .primaryCue?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            cue.isEmpty == false {
            return cue
        }

        let feel = sessionFeelNote.trimmingCharacters(in: .whitespacesAndNewlines)
        if feel.isEmpty == false {
            return feel
        }

        let aggregated = aggregatedNotes
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let aggregated, aggregated.isEmpty == false {
            return aggregated
        }

        return nil
    }
}
