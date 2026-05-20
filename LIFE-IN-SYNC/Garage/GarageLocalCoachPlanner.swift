import Foundation

struct GarageGeneratedPracticePlan: Identifiable, Hashable {
    let id: UUID
    var title: String
    let environment: PracticeEnvironment
    var objective: String
    var coachNote: String
    var carryForwardNote: String?
    var drills: [PracticeTemplateDrill]
    var prescriptionsByDrillID: [UUID: GarageDrillPrescription]
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
        prescriptionsByDrillID: [UUID: GarageDrillPrescription] = [:],
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
        self.prescriptionsByDrillID = prescriptionsByDrillID
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
        "\(drills.count) drills - \(estimatedDurationMinutes) min"
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

    func makeActivePracticeSession() -> ActivePracticeSession {
        ActivePracticeSession(
            template: makePracticeTemplate(),
            prescriptionsByDrillID: prescriptionsByDrillID
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
        let authoritativeRoster = DrillVault.drills(in: environment)
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
        let selectedDrills = gatekeeperSelectedDrills(
            from: selection,
            authoritativeRoster: authoritativeRoster,
            environment: environment,
            environmentRecords: environmentRecords,
            desiredDrillCount: desiredDrillCount
        )
        let plannedDrills = selectedDrills.enumerated().map { offset, selectedDrill in
            let templateDrill = selectedDrill.drill.makeGeneratedPracticeTemplateDrill(
                seedKey: "local-plan:\(environment.rawValue):\(offset):\(selectedDrill.drill.id)",
                prescribedRepCount: selectedDrill.prescribedRepCount
            )
            let basePrescription = GarageDrillCatalog.defaultPrescription(
                for: templateDrill,
                sessionOrder: offset
            )
            let customizedPrescription = GarageDrillPrescription(
                drillID: templateDrill.id,
                selectedClub: selectedDrill.drill.clubRange.displayName,
                mode: basePrescription.mode,
                durationSeconds: desiredDurationMinutes.flatMap { selectedDrills.isEmpty ? nil : max(Int((Double($0) / Double(selectedDrills.count) * 60.0).rounded()), 60) } ?? basePrescription.durationSeconds,
                targetCount: selectedDrill.prescribedRepCount,
                goalText: basePrescription.goalText,
                intensity: basePrescription.intensity,
                activeCue: basePrescription.activeCue,
                activeSetupReminder: basePrescription.activeSetupReminder,
                scoringBehavior: basePrescription.scoringBehavior,
                progressionNotes: basePrescription.progressionNotes,
                sessionOrder: offset
            )
            return (templateDrill, customizedPrescription)
        }
        let templateDrills = plannedDrills.map(\.0)
        let prescriptionsByDrillID = Dictionary(uniqueKeysWithValues: plannedDrills.map { ($0.0.id, $0.1) })
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
            prescriptionsByDrillID: prescriptionsByDrillID,
            plannedDurationMinutes: selection.estimatedDurationMinutes,
            coachRead: coachRead
        )
    }

    private static let balancedNetFallbackIDs = ["N-01", "N-06", "N-02", "N-10"]
    private static let lowFeelSuccessThreshold = 0.6
    private static let recentHistoryLimit = 10

    private static func gatekeeperSelectedDrills(
        from selection: GaragePracticePlanSelection,
        authoritativeRoster: [GarageDrill],
        environment: PracticeEnvironment,
        environmentRecords: [PracticeSessionRecord],
        desiredDrillCount: Int?
    ) -> [GarageSelectedPracticeDrill] {
        guard authoritativeRoster.isEmpty == false else {
            return []
        }

        let rosterIDs = Set(authoritativeRoster.map(\.id))
        let rosterByID = Dictionary(uniqueKeysWithValues: authoritativeRoster.map { ($0.id, $0) })
        let validSelectedDrills = selection.selectedDrills.filter { rosterIDs.contains($0.drill.id) }
        let fallbackTargetCount = min(balancedNetFallbackIDs.count, authoritativeRoster.count)
        let targetCount = min(
            max(desiredDrillCount ?? max(validSelectedDrills.count, fallbackTargetCount), 1),
            authoritativeRoster.count
        )

        guard environment == .net else {
            return validSelectedDrills
        }

        if environmentRecords.isEmpty {
            return balancedNetFallbackDrills(from: rosterByID)
        }

        var selectedDrills: [GarageSelectedPracticeDrill] = []
        var selectedIDs = Set<String>()

        for drill in lowFeelSuccessPriorityDrills(
            from: environmentRecords,
            authoritativeRoster: authoritativeRoster
        ) {
            guard selectedDrills.count < targetCount else {
                break
            }

            guard selectedIDs.insert(drill.id).inserted else {
                continue
            }

            if let existingSelection = validSelectedDrills.first(where: { $0.drill.id == drill.id }) {
                selectedDrills.append(existingSelection)
            } else {
                selectedDrills.append(selectedPracticeDrill(for: drill))
            }
        }

        for selectedDrill in validSelectedDrills where selectedIDs.insert(selectedDrill.drill.id).inserted {
            guard selectedDrills.count < targetCount else {
                break
            }

            selectedDrills.append(selectedDrill)
        }

        if selectedDrills.isEmpty {
            return balancedNetFallbackDrills(from: rosterByID)
        }

        for fallbackDrillID in balancedNetFallbackIDs where selectedIDs.insert(fallbackDrillID).inserted {
            guard selectedDrills.count < targetCount,
                  let fallbackDrill = rosterByID[fallbackDrillID] else {
                continue
            }

            selectedDrills.append(selectedPracticeDrill(for: fallbackDrill))
        }

        return selectedDrills
    }

    private static func balancedNetFallbackDrills(
        from rosterByID: [String: GarageDrill]
    ) -> [GarageSelectedPracticeDrill] {
        balancedNetFallbackIDs.compactMap { drillID in
            rosterByID[drillID].map { selectedPracticeDrill(for: $0) }
        }
    }

    private static func lowFeelSuccessPriorityDrills(
        from records: [PracticeSessionRecord],
        authoritativeRoster: [GarageDrill]
    ) -> [GarageDrill] {
        let rosterIDs = Set(authoritativeRoster.map(\.id))
        let firstRosterDrillByCategory = Dictionary(
            authoritativeRoster.map { (DrillVault.metadata(for: $0).primaryCategory, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var buckets: [String: GarageFeelSuccessBucket] = [:]

        for record in records.prefix(recentHistoryLimit) {
            for result in record.drillResults where result.totalReps > 0 {
                guard let drill = gatekeeperDrill(
                    for: result,
                    rosterIDs: rosterIDs,
                    firstRosterDrillByCategory: firstRosterDrillByCategory
                ) else {
                    continue
                }

                buckets[drill.id, default: GarageFeelSuccessBucket(drill: drill)].record(result)
            }
        }

        return buckets.values
            .filter { $0.successRatio < lowFeelSuccessThreshold }
            .sorted { lhs, rhs in
                if lhs.successRatio == rhs.successRatio {
                    return lhs.totalReps > rhs.totalReps
                }

                return lhs.successRatio < rhs.successRatio
            }
            .map(\.drill)
    }

    private static func gatekeeperDrill(
        for result: DrillResult,
        rosterIDs: Set<String>,
        firstRosterDrillByCategory: [GarageDrillLibraryCategory: GarageDrill]
    ) -> GarageDrill? {
        if let drill = DrillVault.canonicalDrill(for: result.name) {
            if rosterIDs.contains(drill.id) {
                return drill
            }

            let metadata = DrillVault.metadata(for: drill)
            if let categoryEquivalent = firstRosterDrillByCategory[metadata.primaryCategory] {
                return categoryEquivalent
            }
        }

        if let snapshot = result.garageMetadataSnapshot {
            return firstRosterDrillByCategory[snapshot.primaryCategory]
        }

        return nil
    }

    private static func selectedPracticeDrill(for drill: GarageDrill) -> GarageSelectedPracticeDrill {
        let metadata = DrillVault.metadata(for: drill)

        return GarageSelectedPracticeDrill(
            drill: drill,
            metadata: metadata,
            prescribedRepCount: min(max(drill.defaultRepCount, metadata.minReps), metadata.maxReps),
            selectionScore: 0
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

private struct GarageFeelSuccessBucket {
    let drill: GarageDrill
    private(set) var successfulReps: Int = 0
    private(set) var totalReps: Int = 0

    var successRatio: Double {
        guard totalReps > 0 else {
            return 1
        }

        return Double(successfulReps) / Double(totalReps)
    }

    mutating func record(_ result: DrillResult) {
        successfulReps += result.successfulReps
        totalReps += result.totalReps
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
