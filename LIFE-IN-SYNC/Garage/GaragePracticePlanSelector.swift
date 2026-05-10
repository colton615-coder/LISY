import Foundation

struct GaragePracticePlanInput {
    let environment: PracticeEnvironment
    let promptText: String
    let availableEquipment: Set<GarageEquipmentRequirement>?
    let blockedSafetyConstraints: Set<GarageSafetyConstraint>
    let desiredDurationMinutes: Int?
    let desiredDrillCount: Int?
    let recentRecords: [PracticeSessionRecord]
    let adaptiveRecommendations: [GarageAdaptiveRecommendation]

    init(
        environment: PracticeEnvironment,
        promptText: String = "",
        availableEquipment: Set<GarageEquipmentRequirement>? = nil,
        blockedSafetyConstraints: Set<GarageSafetyConstraint> = [],
        desiredDurationMinutes: Int? = nil,
        desiredDrillCount: Int? = nil,
        recentRecords: [PracticeSessionRecord] = [],
        adaptiveRecommendations: [GarageAdaptiveRecommendation] = []
    ) {
        self.environment = environment
        self.promptText = promptText
        self.availableEquipment = availableEquipment
        self.blockedSafetyConstraints = blockedSafetyConstraints
        self.desiredDurationMinutes = desiredDurationMinutes
        self.desiredDrillCount = desiredDrillCount
        self.recentRecords = recentRecords
        self.adaptiveRecommendations = adaptiveRecommendations
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
            + GaragePracticeHistoryAnalyzer.validationErrors()
            + GarageAdaptiveRecommendationEngine.validationErrors()

        for environment in PracticeEnvironment.allCases {
            let selection = selectPlan(for: GaragePracticePlanInput(environment: environment))
            if selection.selectedDrills.isEmpty {
                errors.append("Selector returned no fallback drills for \(environment.displayName).")
            }
        }

        errors += validateRepeatedWeaknessGate()

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
            let adaptiveScore = adaptiveScore(
                for: drill,
                metadata: metadata,
                recommendations: input.adaptiveRecommendations
            )
            let score = promptScore + historyScore + adaptiveScore + defaultScore + Double(drill.defaultRepCount) * 0.05

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

    private static func adaptiveScore(
        for drill: GarageDrill,
        metadata: GarageDrillMetadata,
        recommendations: [GarageAdaptiveRecommendation]
    ) -> Double {
        recommendations.reduce(0) { partialResult, recommendation in
            var adjustment = 0.0

            if recommendation.drillID == drill.id {
                adjustment += recommendation.scoreImpact
            }

            if recommendation.relatedDrillIDs.contains(drill.id) {
                adjustment += recommendation.scoreImpact * 0.45
            }

            if let category = recommendation.category,
               category == metadata.primaryCategory {
                adjustment += recommendation.scoreImpact * 0.72
            }

            if let faultTag = recommendation.faultTag,
               metadata.faultTags.contains(faultTag) || metadata.promptTags.contains(faultTag) {
                adjustment += recommendation.scoreImpact * 0.64
            }

            if metadata.promptTags.isDisjoint(with: recommendation.focusTags) == false
                || metadata.faultTags.isDisjoint(with: recommendation.focusTags) == false {
                adjustment += recommendation.scoreImpact * 0.5
            }

            switch recommendation.kind {
            case .remedialDrill:
                adjustment += recommendation.drillID == drill.id ? 4 : 0
            case .progressionDrill:
                adjustment += recommendation.drillID == drill.id ? 2 : 0
            case .balancedDietCorrection where recommendation.scoreImpact < 0:
                adjustment += recommendation.category == metadata.primaryCategory ? recommendation.scoreImpact : 0
            case .repeatDrill, .categoryMaintenance, .categoryRecovery, .balancedDietCorrection, .focusTagRecommendation:
                break
            }

            return partialResult + adjustment
        }
    }

    private static func weakDrillWeights(
        for environment: PracticeEnvironment,
        recentRecords: [PracticeSessionRecord]
    ) -> [String: Double] {
        let environmentDrills = DrillVault.drills(in: environment)
        var weights: [String: Double] = [:]

        let recentEnvironmentRecords = recentRecords
            .filter({ $0.environment == environment.rawValue })
            .sorted(by: { $0.date > $1.date })
            .prefix(3)
        var weakSessionCounts: [String: Int] = [:]

        for record in recentEnvironmentRecords {
            var weakDrillsInSession = Set<String>()

            for result in record.drillResults where result.contributesToAdaptiveScoring {
                guard let drill = DrillVault.canonicalDrill(for: result.name),
                      drill.environment == environment,
                      environmentDrills.contains(where: { $0.id == drill.id }) else {
                    continue
                }

                if result.resolvedOutcome == .partial || result.adaptiveSuccessRatio < 0.6 {
                    weights[drill.id, default: 0] += 12
                    weakDrillsInSession.insert(drill.id)
                } else if result.adaptiveSuccessRatio < 0.8 {
                    weights[drill.id, default: 0] += 5
                }
            }

            for drillID in weakDrillsInSession {
                weakSessionCounts[drillID, default: 0] += 1
            }
        }

        for (drillID, weakSessionCount) in weakSessionCounts where weakSessionCount >= 2 {
            if let drill = DrillVault.drill(for: drillID),
               let remedialDrillID = drill.remedialDrillID,
               let remedialDrill = DrillVault.drill(for: remedialDrillID),
               remedialDrill.environment == environment {
                weights[remedialDrillID, default: 0] += 6
            }
        }

        return weights
    }

    private static func validateRepeatedWeaknessGate() -> [String] {
        var errors: [String] = []

        for environment in PracticeEnvironment.allCases {
            guard let drill = DrillVault.drills(in: environment).first(where: { drill in
                guard let remedialDrillID = drill.remedialDrillID,
                      let remedial = DrillVault.drill(for: remedialDrillID) else {
                    return false
                }

                return remedial.environment == environment
            }),
            let remedialDrillID = drill.remedialDrillID else {
                continue
            }

            let firstRecord = weakHistoryRecord(
                drill: drill,
                environment: environment,
                date: Date(timeIntervalSince1970: 0)
            )
            let secondRecord = weakHistoryRecord(
                drill: drill,
                environment: environment,
                date: Date(timeIntervalSince1970: 86_400)
            )
            let singleWeakWeights = weakDrillWeights(
                for: environment,
                recentRecords: [firstRecord]
            )
            if singleWeakWeights[drill.id, default: 0] <= 0 {
                errors.append("Selector did not preserve low-confidence weak-session awareness for \(drill.title).")
            }

            if singleWeakWeights[remedialDrillID] != nil {
                errors.append("Selector applied remedial weighting for a single weak \(environment.displayName) session.")
            }

            let repeatedWeakWeights = weakDrillWeights(
                for: environment,
                recentRecords: [secondRecord, firstRecord]
            )
            if repeatedWeakWeights[remedialDrillID, default: 0] <= 0 {
                errors.append("Selector did not apply remedial weighting after repeated weak \(environment.displayName) sessions.")
            }
        }

        return errors
    }

    private static func weakHistoryRecord(
        drill: GarageDrill,
        environment: PracticeEnvironment,
        date: Date
    ) -> PracticeSessionRecord {
        PracticeSessionRecord(
            date: date,
            templateName: "Weakness Gate Sample",
            environment: environment.rawValue,
            completedDrills: 1,
            totalDrills: 1,
            drillResults: [
                DrillResult(
                    name: drill.title,
                    successfulReps: 2,
                    totalReps: 10
                )
            ]
        )
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
