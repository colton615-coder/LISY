import Foundation

struct GaragePracticePlanInput {
    let environment: PracticeEnvironment
    let promptText: String
    let availableEquipment: Set<GarageEquipmentRequirement>?
    let blockedSafetyConstraints: Set<GarageSafetyConstraint>
    let desiredDurationMinutes: Int?
    let desiredDrillCount: Int?
    let recentRecords: [PracticeSessionRecord]

    init(
        environment: PracticeEnvironment,
        promptText: String = "",
        availableEquipment: Set<GarageEquipmentRequirement>? = nil,
        blockedSafetyConstraints: Set<GarageSafetyConstraint> = [],
        desiredDurationMinutes: Int? = nil,
        desiredDrillCount: Int? = nil,
        recentRecords: [PracticeSessionRecord] = []
    ) {
        self.environment = environment
        self.promptText = promptText
        self.availableEquipment = availableEquipment
        self.blockedSafetyConstraints = blockedSafetyConstraints
        self.desiredDurationMinutes = desiredDurationMinutes
        self.desiredDrillCount = desiredDrillCount
        self.recentRecords = recentRecords
    }
}

struct GarageSelectedPracticeDrill: Hashable {
    let drill: GarageDrill
    let metadata: GarageDrillMetadata
    let prescribedRepCount: Int
    let selectionScore: Double
}

struct GaragePracticePlanSelection: Hashable {
    let environment: PracticeEnvironment
    let selectedDrills: [GarageSelectedPracticeDrill]
    let promptMatched: Bool
    let estimatedDurationMinutes: Int?

    var isEmpty: Bool {
        selectedDrills.isEmpty
    }
}

enum GaragePracticePlanSelector {
    static func selectPlan(for input: GaragePracticePlanInput) -> GaragePracticePlanSelection {
        let prompt = GaragePromptTokens(input.promptText)
        let environmentDrills = DrillVault.drills(in: input.environment)
        let candidateScores = makeCandidateScores(
            from: environmentDrills,
            input: input,
            prompt: prompt
        )

        guard candidateScores.isEmpty == false else {
            return GaragePracticePlanSelection(
                environment: input.environment,
                selectedDrills: [],
                promptMatched: false,
                estimatedDurationMinutes: input.desiredDurationMinutes
            )
        }

        let targetCount = min(targetDrillCount(for: input, availableCount: candidateScores.count), candidateScores.count)
        let selectedCandidates = selectDiverseCandidates(
            from: candidateScores,
            targetCount: targetCount
        )
        let selectedDrills = selectedCandidates.map { candidate in
            GarageSelectedPracticeDrill(
                drill: candidate.drill,
                metadata: candidate.metadata,
                prescribedRepCount: prescribedRepCount(
                    for: candidate.drill,
                    metadata: candidate.metadata,
                    input: input,
                    selectedCount: max(selectedCandidates.count, 1)
                ),
                selectionScore: candidate.score
            )
        }

        return GaragePracticePlanSelection(
            environment: input.environment,
            selectedDrills: selectedDrills,
            promptMatched: prompt.isEmpty == false && selectedCandidates.contains { $0.promptScore > 0 },
            estimatedDurationMinutes: input.desiredDurationMinutes
        )
    }

    static func validationErrors() -> [String] {
        var errors = DrillVault.validationErrors()

        for environment in PracticeEnvironment.allCases {
            let selection = selectPlan(for: GaragePracticePlanInput(environment: environment))
            if selection.selectedDrills.isEmpty {
                errors.append("Selector returned no fallback drills for \(environment.displayName).")
            }
        }

        return errors
    }

    private static func makeCandidateScores(
        from drills: [GarageDrill],
        input: GaragePracticePlanInput,
        prompt: GaragePromptTokens
    ) -> [GarageScoredPracticeDrill] {
        let weakDrillWeights = weakDrillWeights(
            for: input.environment,
            recentRecords: input.recentRecords
        )
        let defaultRoutineWeights = defaultRoutineWeights(for: input.environment)

        return drills.compactMap { drill in
            let metadata = DrillVault.metadata(for: drill)

            guard passesHardFilters(
                metadata: metadata,
                input: input
            ) else {
                return nil
            }

            let promptScore = promptScore(for: drill, metadata: metadata, prompt: prompt)
            let historyScore = weakDrillWeights[drill.id] ?? 0
            let defaultScore = defaultRoutineWeights[drill.id] ?? 0
            let score = promptScore + historyScore + defaultScore + Double(drill.defaultRepCount) * 0.05

            return GarageScoredPracticeDrill(
                drill: drill,
                metadata: metadata,
                score: score,
                promptScore: promptScore
            )
        }
    }

    private static func passesHardFilters(
        metadata: GarageDrillMetadata,
        input: GaragePracticePlanInput
    ) -> Bool {
        guard metadata.minReps <= metadata.maxReps else {
            return false
        }

        if metadata.safetyConstraints.isDisjoint(with: input.blockedSafetyConstraints) == false {
            return false
        }

        guard let availableEquipment = input.availableEquipment else {
            return true
        }

        guard metadata.equipmentRules.isSubset(of: availableEquipment) else {
            return false
        }

        return metadata.requiredAnyEquipmentGroups.allSatisfy { equipmentGroup in
            equipmentGroup.isDisjoint(with: availableEquipment) == false
        }
    }

    private static func promptScore(
        for drill: GarageDrill,
        metadata: GarageDrillMetadata,
        prompt: GaragePromptTokens
    ) -> Double {
        guard prompt.isEmpty == false else {
            return 0
        }

        var score = 0.0

        score += Double(metadata.promptTags.filter { prompt.matches($0) }.count) * 10
        score += Double(metadata.faultTags.filter { prompt.matches($0) }.count) * 8

        if prompt.matches(drill.title) {
            score += 5
        }

        if prompt.matches(drill.purpose) || prompt.matches(drill.abstractFeelCue) {
            score += 3
        }

        if prompt.matches(metadata.primaryCategory.rawValue) || prompt.matches(drill.faultType.rawValue) {
            score += 2
        }

        return score
    }

    private static func weakDrillWeights(
        for environment: PracticeEnvironment,
        recentRecords: [PracticeSessionRecord]
    ) -> [String: Double] {
        let environmentDrills = DrillVault.drills(in: environment)
        var weights: [String: Double] = [:]

        for result in recentRecords
            .filter({ $0.environment == environment.rawValue })
            .sorted(by: { $0.date > $1.date })
            .prefix(3)
            .flatMap(\.drillResults)
            where result.totalReps > 0 {
            guard let drill = environmentDrills.first(where: { $0.title.caseInsensitiveCompare(result.name) == .orderedSame }) else {
                continue
            }

            if result.successRatio < 0.6 {
                weights[drill.id, default: 0] += 12

                if let remedialDrillID = drill.remedialDrillID,
                   let remedialDrill = DrillVault.drill(for: remedialDrillID),
                   remedialDrill.environment == environment {
                    weights[remedialDrillID, default: 0] += 6
                }
            } else if result.successRatio < 0.8 {
                weights[drill.id, default: 0] += 5
            }
        }

        return weights
    }

    private static func defaultRoutineWeights(for environment: PracticeEnvironment) -> [String: Double] {
        var weights: [String: Double] = [:]
        let routines = DrillVault.predefinedRoutines.filter { $0.environment == environment }

        for (routineIndex, routine) in routines.enumerated() {
            let routineWeight = max(0, 8 - routineIndex * 2)
            for (drillIndex, drillID) in routine.drillIDs.enumerated() {
                weights[drillID, default: 0] += Double(max(0, routineWeight - drillIndex))
            }
        }

        return weights
    }

    private static func selectDiverseCandidates(
        from candidates: [GarageScoredPracticeDrill],
        targetCount: Int
    ) -> [GarageScoredPracticeDrill] {
        var selected: [GarageScoredPracticeDrill] = []
        var remaining = candidates

        while selected.count < targetCount && remaining.isEmpty == false {
            let categoryCounts = Dictionary(grouping: selected, by: \.metadata.primaryCategory)
                .mapValues(\.count)

            let next = remaining
                .map { candidate in
                    let existingCategoryCount = categoryCounts[candidate.metadata.primaryCategory] ?? 0
                    let diversityAdjustment = selected.isEmpty ? 0 : (existingCategoryCount == 0 ? 2.5 : Double(existingCategoryCount) * -3)
                    return (candidate: candidate, adjustedScore: candidate.score + diversityAdjustment)
                }
                .sorted { (lhs: (candidate: GarageScoredPracticeDrill, adjustedScore: Double), rhs: (candidate: GarageScoredPracticeDrill, adjustedScore: Double)) in
                    if lhs.adjustedScore == rhs.adjustedScore {
                        if lhs.candidate.score == rhs.candidate.score {
                            return lhs.candidate.drill.id < rhs.candidate.drill.id
                        }

                        return lhs.candidate.score > rhs.candidate.score
                    }

                    return lhs.adjustedScore > rhs.adjustedScore
                }
                .first?
                .candidate

            guard let next else {
                break
            }

            selected.append(next)
            remaining.removeAll { $0.drill.id == next.drill.id }
        }

        return selected
    }

    private static func targetDrillCount(
        for input: GaragePracticePlanInput,
        availableCount: Int
    ) -> Int {
        if let desiredDrillCount = input.desiredDrillCount {
            return min(max(desiredDrillCount, 1), availableCount)
        }

        guard let duration = input.desiredDurationMinutes else {
            return min(3, availableCount)
        }

        switch duration {
        case ..<16:
            return min(1, availableCount)
        case 16..<25:
            return min(2, availableCount)
        case 25..<40:
            return min(3, availableCount)
        case 40..<56:
            return min(4, availableCount)
        default:
            return min(5, availableCount)
        }
    }

    private static func prescribedRepCount(
        for drill: GarageDrill,
        metadata: GarageDrillMetadata,
        input: GaragePracticePlanInput,
        selectedCount: Int
    ) -> Int {
        guard let duration = input.desiredDurationMinutes else {
            return min(max(drill.defaultRepCount, metadata.minReps), metadata.maxReps)
        }

        let blockMinutes = Double(max(duration, 1)) / Double(max(selectedCount, 1))
        let multiplier: Double

        switch blockMinutes {
        case ..<6:
            multiplier = 0.75
        case ..<11:
            multiplier = 1.5
        case ..<16:
            multiplier = 2.0
        case ..<21:
            multiplier = 2.5
        default:
            multiplier = 3.0
        }

        let scaledReps = Int((Double(drill.defaultRepCount) * multiplier).rounded())
        return min(max(scaledReps, metadata.minReps), metadata.maxReps)
    }
}

private struct GarageScoredPracticeDrill: Hashable {
    let drill: GarageDrill
    let metadata: GarageDrillMetadata
    let score: Double
    let promptScore: Double
}

private struct GaragePromptTokens {
    let rawText: String
    let tokens: Set<String>
    let normalizedText: String

    init(_ rawText: String) {
        self.rawText = rawText
        self.tokens = Set(Self.tokens(from: rawText))
        self.normalizedText = Self.tokens(from: rawText).joined(separator: " ")
    }

    var isEmpty: Bool {
        tokens.isEmpty
    }

    func matches(_ value: String) -> Bool {
        let valueTokens = Set(Self.tokens(from: value.replacingOccurrences(of: "_", with: " ")))
        guard valueTokens.isEmpty == false else {
            return false
        }

        if valueTokens.isSubset(of: tokens) {
            return true
        }

        let valueText = valueTokens.joined(separator: " ")
        return normalizedText.contains(valueText) || valueTokens.contains { tokens.contains($0) }
    }

    private static func tokens(from value: String) -> [String] {
        value
            .lowercased()
            .replacingOccurrences(of: "&", with: " ")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.isEmpty == false }
    }
}
