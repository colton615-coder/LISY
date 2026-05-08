import Foundation

struct GarageGeneratedPracticePlan: Identifiable, Hashable {
    let id: UUID
    var title: String
    let environment: PracticeEnvironment
    var objective: String
    var coachNote: String
    var carryForwardNote: String?
    var drills: [PracticeTemplateDrill]
    var plannedDurationMinutes: Int?
    var coachRead: GarageCoachRead?

    init(
        id: UUID = UUID(),
        title: String,
        environment: PracticeEnvironment,
        objective: String,
        coachNote: String,
        carryForwardNote: String? = nil,
        drills: [PracticeTemplateDrill],
        plannedDurationMinutes: Int? = nil,
        coachRead: GarageCoachRead? = nil
    ) {
        self.id = id
        self.title = title
        self.environment = environment
        self.objective = objective
        self.coachNote = coachNote
        self.carryForwardNote = carryForwardNote
        self.drills = drills
        self.plannedDurationMinutes = plannedDurationMinutes
        self.coachRead = coachRead
    }

    var totalRepCount: Int {
        drills.reduce(0) { $0 + $1.defaultRepCount }
    }

    var estimatedDurationMinutes: Int {
        plannedDurationMinutes ?? max(12, drills.count * 6)
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
        recentRecords: [PracticeSessionRecord],
        promptText: String = "",
        availableEquipment: Set<GarageEquipmentRequirement>? = nil,
        blockedSafetyConstraints: Set<GarageSafetyConstraint> = [],
        desiredDurationMinutes: Int? = nil,
        desiredDrillCount: Int? = nil
    ) -> GarageGeneratedPracticePlan {
        let environmentRecords = recentRecords
            .filter { $0.environment == environment.rawValue }
            .sorted { $0.date > $1.date }
        let carryForwardCue = environmentRecords.first?.garagePlannerCarryForwardCue
        let skillProfile = GaragePracticeHistoryAnalyzer.skillProfile(
            from: recentRecords,
            environment: environment
        )
        let adaptiveRecommendations = GarageAdaptiveRecommendationEngine.recommendations(
            for: skillProfile,
            environment: environment
        )
        let coachRead = GarageAdaptiveRecommendationEngine.coachRead(
            for: skillProfile,
            recommendations: adaptiveRecommendations,
            environment: environment
        )
        let selection = GaragePracticePlanSelector.selectPlan(
            for: GaragePracticePlanInput(
                environment: environment,
                promptText: promptText,
                availableEquipment: availableEquipment,
                blockedSafetyConstraints: blockedSafetyConstraints,
                desiredDurationMinutes: desiredDurationMinutes,
                desiredDrillCount: desiredDrillCount,
                recentRecords: recentRecords,
                adaptiveRecommendations: adaptiveRecommendations
            )
        )
        let templateDrills = selection.selectedDrills.enumerated().map { offset, selectedDrill in
            selectedDrill.drill.makeGeneratedPracticeTemplateDrill(
                seedKey: "local-plan:\(environment.rawValue):\(offset):\(selectedDrill.drill.id)",
                prescribedRepCount: selectedDrill.prescribedRepCount
            )
        }
        let trimmedPrompt = promptText.trimmingCharacters(in: .whitespacesAndNewlines)

        return GarageGeneratedPracticePlan(
            title: title(for: environment, hasHistory: environmentRecords.isEmpty == false),
            environment: environment,
            objective: objective(
                for: environment,
                promptText: trimmedPrompt,
                carryForwardCue: carryForwardCue
            ),
            coachNote: coachNote(
                for: environment,
                records: environmentRecords,
                promptText: trimmedPrompt,
                promptMatched: selection.promptMatched,
                carryForwardCue: carryForwardCue,
                coachRead: coachRead
            ),
            carryForwardNote: carryForwardCue,
            drills: templateDrills,
            plannedDurationMinutes: selection.estimatedDurationMinutes,
            coachRead: coachRead
        )
    }

    private static func title(for environment: PracticeEnvironment, hasHistory: Bool) -> String {
        if hasHistory {
            return "\(environment.displayName) Coach Plan"
        }

        return "\(environment.displayName) Foundation Session"
    }

    private static func objective(
        for environment: PracticeEnvironment,
        promptText: String,
        carryForwardCue: String?
    ) -> String {
        if promptText.isEmpty == false {
            return promptText
        }

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
        promptText: String,
        promptMatched: Bool,
        carryForwardCue: String?,
        coachRead: GarageCoachRead
    ) -> String {
        let adaptivePrefix = "Coach read: \(coachRead.summary) \(coachRead.recommendation)"

        if promptText.isEmpty == false {
            if promptMatched {
                return "\(adaptivePrefix) Prompt matched after environment, metadata, and safety gates."
            }

            return "\(adaptivePrefix) No direct prompt match; using the closest safe \(environment.displayName.lowercased()) categories."
        }

        if let carryForwardCue {
            return "\(adaptivePrefix) Carry this forward: \(carryForwardCue)"
        }

        if records.isEmpty {
            return "\(adaptivePrefix)"
        }

        return "\(adaptivePrefix) No clear carry-forward cue was saved. Use this session to create one reliable note for the next practice."
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
