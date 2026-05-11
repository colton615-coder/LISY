import Foundation

enum GarageDrillSessionMode: String, Codable, CaseIterable, Hashable {
    case timed
    case reps
    case goal
    case challenge
    case checklist

    var directoryLabel: String {
        switch self {
        case .timed:
            return "Timed"
        case .reps:
            return "Reps"
        case .goal:
            return "Goal"
        case .challenge:
            return "Challenge"
        case .checklist:
            return "Checklist"
        }
    }

    var focusMode: GarageDrillFocusMode {
        switch self {
        case .timed, .reps, .checklist:
            return .process
        case .goal:
            return .target
        case .challenge:
            return .pressureTest
        }
    }
}

enum GarageDrillIntensity: String, Codable, CaseIterable, Hashable {
    case low
    case medium
    case high

    var displayName: String { rawValue.capitalized }
}

enum GarageDrillScoringBehavior: String, Codable, CaseIterable, Hashable {
    case timedCompletion
    case repCompletion
    case goalCompletion
    case challengeCompletion
    case checklistCompletion
    case honestResolution
}

struct GarageDrillPrescription: Identifiable, Codable, Hashable {
    let drillID: UUID
    var selectedClub: String?
    var mode: GarageDrillSessionMode
    var durationSeconds: Int?
    var targetCount: Int?
    var goalText: String
    var intensity: GarageDrillIntensity
    var activeCue: String?
    var activeSetupReminder: String?
    var scoringBehavior: GarageDrillScoringBehavior
    var progressionNotes: String?
    var sessionOrder: Int?

    var id: UUID { drillID }

    var projectedAttemptCount: Int {
        switch mode {
        case .timed:
            return max(Int(ceil(Double(max(durationSeconds ?? 60, 60)) / 60.0)), 1)
        case .reps, .goal, .challenge:
            return max(targetCount ?? 1, 1)
        case .checklist:
            return max(targetCount ?? 1, 1)
        }
    }

    var modeSummaryText: String {
        switch mode {
        case .timed:
            return durationSeconds.map { GarageDrillPrescriptionFormat.duration($0) } ?? mode.directoryLabel
        case .reps, .goal, .challenge, .checklist:
            return targetCount.map { "\($0) \(mode.directoryLabel.lowercased())" } ?? mode.directoryLabel
        }
    }
}

enum GarageDrillCatalogDifficulty: String, Codable, CaseIterable, Hashable {
    case foundation = "Foundation"
    case build = "Build"
    case pressure = "Pressure"
}

struct GarageDrillCatalogContent: Hashable {
    let canonicalDrillID: String?
    let title: String
    let category: String
    let primarySkill: String
    let faultTargets: [String]
    let equipment: [String]
    let difficulty: GarageDrillCatalogDifficulty
    let supportedModes: [GarageDrillSessionMode]
    let shortDescription: String
    let setupSummary: String
    let coreAction: String
    let keyCueCandidates: [String]
    let commonMistakes: [String]
    let suggestedClubs: [String]
    let variations: [String]
    let richInstructionContent: GarageDrillInstructionContent
}

enum GarageDrillAuditDisposition: String, Codable, Hashable {
    case keep = "KEEP"
    case merge = "MERGE"
    case split = "SPLIT"
    case demote = "DEMOTE"
    case kill = "KILL"
    case convert = "CONVERT"
}

struct GarageDrillAuditEntry: Hashable {
    let drillID: String
    let disposition: GarageDrillAuditDisposition
    let rationale: String
}

struct GarageDrillInstructionContent: Hashable {
    let whatItTrains: String
    let whyItMatters: String
    let setupWalkthrough: [String]
    let keyCues: [String]
    let commonMistakes: [String]
    let variations: [String]
    let suggestedClubs: [String]
    let supportedModes: [GarageDrillSessionMode]
    let recommendedUseCases: [String]
}

enum GarageDrillCatalog {
    static func content(for drill: GarageDrill) -> GarageDrillCatalogContent {
        let detail = GarageDrillFocusDetails.detail(for: drill)
        let metadata = GarageDrillFocusDetails.metadata(for: drill, detail: detail)
        let instruction = GarageDrillFocusDetails.instructionContent(for: drill, detail: detail)
        return content(
            title: drill.title,
            category: drill.libraryCategory.displayName,
            primarySkill: drill.purpose,
            faultTargets: [drill.faultType.sensoryDescription],
            equipment: detail.equipment,
            difficulty: difficulty(for: metadata),
            supportedModes: supportedModes(for: metadata),
            shortDescription: drill.purpose,
            setupSummary: metadata.setupLine,
            coreAction: metadata.commandCopy,
            keyCueCandidates: instruction.keyCues,
            commonMistakes: instruction.commonMistakes,
            suggestedClubs: instruction.suggestedClubs,
            variations: instruction.variations,
            richInstructionContent: instruction,
            canonicalDrillID: drill.id
        )
    }

    static func content(for drill: PracticeTemplateDrill) -> GarageDrillCatalogContent {
        if let canonicalDrill = DrillVault.canonicalDrill(for: drill) {
            return content(for: canonicalDrill)
        }

        let detail = GarageDrillFocusDetails.detail(for: drill)
        let instruction = GarageDrillFocusDetails.instructionContent(for: drill, detail: detail)
        let summary = detail.setup.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Set the station and define the goal before starting."
        return content(
            title: drill.title,
            category: "Custom",
            primarySkill: drill.focusArea.isEmpty ? "Custom practice" : drill.focusArea,
            faultTargets: drill.focusArea.isEmpty ? [] : [drill.focusArea],
            equipment: detail.equipment,
            difficulty: .build,
            supportedModes: instruction.supportedModes,
            shortDescription: instruction.whatItTrains,
            setupSummary: summary,
            coreAction: detail.execution.first ?? "Run the assigned drill honestly.",
            keyCueCandidates: instruction.keyCues,
            commonMistakes: instruction.commonMistakes,
            suggestedClubs: instruction.suggestedClubs,
            variations: instruction.variations,
            richInstructionContent: instruction,
            canonicalDrillID: nil
        )
    }

    static func defaultPrescription(
        for drill: PracticeTemplateDrill,
        sessionOrder: Int? = nil
    ) -> GarageDrillPrescription {
        let detail = GarageDrillFocusDetails.detail(for: drill)
        let metadata = GarageDrillFocusDetails.metadata(for: drill, detail: detail)
        let authorityGoal = metadata.authorityGoal
        let mode = sessionMode(from: metadata)
        let count = suggestedTargetCount(for: authorityGoal, fallback: max(drill.defaultRepCount, 0))
        let durationSeconds = metadata.durationSecondsOverride ?? max(detail.estimatedMinutes, 1) * 60

        return GarageDrillPrescription(
            drillID: drill.id,
            selectedClub: drill.targetClub.nilIfBlank,
            mode: mode,
            durationSeconds: mode == .timed ? durationSeconds : nil,
            targetCount: mode == .timed ? nil : count,
            goalText: goalText(
                from: authorityGoal,
                fallbackMode: mode,
                fallbackTargetCount: count,
                durationSeconds: durationSeconds
            ),
            intensity: defaultIntensity(for: mode),
            activeCue: metadata.executionCue.nilIfBlank,
            activeSetupReminder: metadata.setupLine.nilIfBlank,
            scoringBehavior: scoringBehavior(for: mode),
            progressionNotes: metadata.reviewSummary?.nilIfBlank,
            sessionOrder: sessionOrder
        )
    }

    static func auditEntry(for drill: GarageDrill) -> GarageDrillAuditEntry {
        let disposition: GarageDrillAuditDisposition
        let rationale: String

        switch drill.id {
        case "r14", "p2", "p6":
            disposition = .convert
            rationale = "The drill is strongest when framed by the active session mode instead of fixed stored copy."
        default:
            disposition = .keep
            rationale = "Strong drill concept. Clean separation is enough; no deletion or merge required in this pass."
        }

        return GarageDrillAuditEntry(
            drillID: drill.id,
            disposition: disposition,
            rationale: rationale
        )
    }

    private static func content(
        title: String,
        category: String,
        primarySkill: String,
        faultTargets: [String],
        equipment: [String],
        difficulty: GarageDrillCatalogDifficulty,
        supportedModes: [GarageDrillSessionMode],
        shortDescription: String,
        setupSummary: String,
        coreAction: String,
        keyCueCandidates: [String],
        commonMistakes: [String],
        suggestedClubs: [String],
        variations: [String],
        richInstructionContent: GarageDrillInstructionContent,
        canonicalDrillID: String?
    ) -> GarageDrillCatalogContent {
        GarageDrillCatalogContent(
            canonicalDrillID: canonicalDrillID,
            title: title,
            category: category,
            primarySkill: primarySkill,
            faultTargets: faultTargets.filter { $0.isEmpty == false },
            equipment: equipment.filter { $0.isEmpty == false },
            difficulty: difficulty,
            supportedModes: supportedModes.isEmpty ? [.timed] : supportedModes,
            shortDescription: shortDescription,
            setupSummary: setupSummary,
            coreAction: coreAction,
            keyCueCandidates: keyCueCandidates.filter { $0.isEmpty == false },
            commonMistakes: commonMistakes.filter { $0.isEmpty == false },
            suggestedClubs: suggestedClubs.filter { $0.isEmpty == false },
            variations: variations.filter { $0.isEmpty == false },
            richInstructionContent: richInstructionContent
        )
    }

    private static func supportedModes(for metadata: GarageDrillFocusMetadata) -> [GarageDrillSessionMode] {
        if let authorityGoal = metadata.authorityGoal {
            return [sessionMode(from: authorityGoal)]
        }

        return [sessionMode(from: metadata)]
    }

    private static func sessionMode(from metadata: GarageDrillFocusMetadata) -> GarageDrillSessionMode {
        if let authorityGoal = metadata.authorityGoal {
            return sessionMode(from: authorityGoal)
        }

        switch metadata.mode {
        case .process:
            return .timed
        case .target:
            return .goal
        case .pressureTest:
            return .challenge
        }
    }

    private static func sessionMode(from authorityGoal: GarageDrillAuthorityGoal) -> GarageDrillSessionMode {
        switch authorityGoal {
        case .timed:
            return .timed
        case .reps:
            return .reps
        case .goal:
            return .goal
        case .challenge:
            return .challenge
        case .checklist:
            return .checklist
        }
    }

    private static func suggestedTargetCount(for authorityGoal: GarageDrillAuthorityGoal?, fallback: Int) -> Int? {
        switch authorityGoal {
        case .reps(let count, _), .goal(let count, _), .challenge(let count, _):
            return max(count, 1)
        case .checklist(let items):
            return max(items.count, 1)
        case .timed, .none:
            return fallback > 0 ? fallback : nil
        }
    }

    private static func goalText(
        from authorityGoal: GarageDrillAuthorityGoal?,
        fallbackMode: GarageDrillSessionMode,
        fallbackTargetCount: Int?,
        durationSeconds: Int
    ) -> String {
        if let authorityGoal {
            switch authorityGoal {
            case .timed:
                return "Stay with the drill for \(GarageDrillPrescriptionFormat.duration(durationSeconds))."
            case .reps(let count, let unit):
                return "Complete \(max(count, 1)) \(unit)."
            case .goal(let count, let unit):
                return "Reach \(max(count, 1)) \(unit)."
            case .challenge(let count, let unit):
                return "Hit \(max(count, 1)) \(unit) under pressure."
            case .checklist(let items):
                return items.isEmpty ? "Complete the drill standard." : "Complete \(items.count) checklist items."
            }
        }

        switch fallbackMode {
        case .timed:
            return "Stay with the drill for \(GarageDrillPrescriptionFormat.duration(durationSeconds))."
        case .reps, .goal, .challenge, .checklist:
            let count = max(fallbackTargetCount ?? 1, 1)
            return "Complete \(count) focused reps."
        }
    }

    private static func defaultIntensity(for mode: GarageDrillSessionMode) -> GarageDrillIntensity {
        switch mode {
        case .timed, .reps:
            return .medium
        case .goal:
            return .medium
        case .challenge:
            return .high
        case .checklist:
            return .low
        }
    }

    private static func scoringBehavior(for mode: GarageDrillSessionMode) -> GarageDrillScoringBehavior {
        switch mode {
        case .timed:
            return .timedCompletion
        case .reps:
            return .repCompletion
        case .goal:
            return .goalCompletion
        case .challenge:
            return .challengeCompletion
        case .checklist:
            return .checklistCompletion
        }
    }

    private static func difficulty(for metadata: GarageDrillFocusMetadata) -> GarageDrillCatalogDifficulty {
        if metadata.mode == .pressureTest {
            return .pressure
        }

        if case .checklist = metadata.authorityGoal {
            return .foundation
        }

        return metadata.mode == .target ? .build : .foundation
    }
}

private enum GarageDrillPrescriptionFormat {
    static func duration(_ seconds: Int) -> String {
        let minutes = max(seconds, 0) / 60
        let remainder = max(seconds, 0) % 60

        if minutes > 0, remainder == 0 {
            return "\(minutes) min"
        }

        if minutes > 0 {
            return "\(minutes)m \(String(format: "%02d", remainder))s"
        }

        return "\(remainder)s"
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
