import Foundation

struct GarageDrillFocusContent: Hashable {
    let title: String
    let task: String
    let setupLine: String
    let executionCue: String
    let setupSteps: [String]
    let cueSteps: [String]
    let goal: GarageDrillGoal
    let mode: GarageDrillFocusMode
    let durationSeconds: Int
    let targetMetric: String
    let guidanceText: String?
    let watchFor: String?
    let finishRule: String
    let teachingDetail: String?
    let reviewSummary: String?
    let diagramKey: String?
}

struct GarageCompactDrillCopy: Hashable {
    let title: String
    let environment: PracticeEnvironment
    let feelCategory: String
    let clubGroup: String
    let shortIntent: String
    let setupBullets: [String]
    let executionBullets: [String]
    let target: String
    let suggestedTime: String
    let club: String
    let resetCue: String?
}

extension GarageDrillFocusContent {
    var hasTeachingDetails: Bool {
        teachingDetail?.isEmpty == false || reviewSummary?.isEmpty == false
    }
}

enum GarageDrillGoal: Hashable {
    case timed(durationSeconds: Int)
    case repTarget(count: Int, unit: String)
    case streak(count: Int, unit: String)
    case timeTrial(targetCount: Int, unit: String)
    case ladder(steps: [String])
    case checklist(items: [String])
    case manual(label: String)
}

enum GarageDrillFocusContentAdapter {
    static func compactCopy(
        for drill: PracticeTemplateDrill,
        detail: GarageDrillFocusDetail,
        prescription: GarageDrillPrescription? = nil,
        environment fallbackEnvironment: PracticeEnvironment? = nil
    ) -> GarageCompactDrillCopy {
        let canonicalDrill = DrillVault.canonicalDrill(for: drill)
        let metadata = GarageDrillFocusDetails.metadata(for: drill, detail: detail)
        let resolvedPrescription = prescription ?? GarageDrillCatalog.defaultPrescription(for: drill)
        let durationSeconds = resolvedPrescription.durationSeconds
            ?? metadata.durationSecondsOverride
            ?? max(detail.estimatedMinutes, 1) * 60
        let environment = canonicalDrill?.environment ?? fallbackEnvironment ?? .net
        let clubGroup = compactClubGroup(canonicalDrill: canonicalDrill, drill: drill)

        return GarageCompactDrillCopy(
            title: cleanTitle(canonicalDrill?.title ?? drill.title, fallback: "Practice Drill"),
            environment: environment,
            feelCategory: compactFeelCategory(canonicalDrill: canonicalDrill, drill: drill),
            clubGroup: clubGroup,
            shortIntent: compactIntent(canonicalDrill: canonicalDrill, detail: detail),
            setupBullets: compactBullets(
                detail.setup,
                fallback: resolvedPrescription.activeSetupReminder ?? metadata.setupLine,
                limit: 2,
                maxWords: 9
            ),
            executionBullets: compactBullets(
                detail.execution,
                fallback: resolvedPrescription.activeCue ?? metadata.executionCue,
                limit: 3,
                maxWords: 10
            ),
            target: compactTarget(from: resolvedPrescription.goalText, detail: detail),
            suggestedTime: GarageDrillGoalFormat.duration(durationSeconds),
            club: compactSelectedClub(prescription: resolvedPrescription, canonicalDrill: canonicalDrill, fallbackClubGroup: clubGroup),
            resetCue: compactResetCue(detail.resetCue)
        )
    }

    static func content(
        for drill: PracticeTemplateDrill,
        detail: GarageDrillFocusDetail,
        prescription: GarageDrillPrescription? = nil
    ) -> GarageDrillFocusContent {
        let canonicalDrill = DrillVault.canonicalDrill(for: drill)
        let metadata = GarageDrillFocusDetails.metadata(for: drill, detail: detail)

        return content(
            for: drill,
            detail: detail,
            canonicalDrill: canonicalDrill,
            metadata: metadata,
            prescription: prescription ?? GarageDrillCatalog.defaultPrescription(for: drill)
        )
    }

    private static func content(
        for drill: PracticeTemplateDrill,
        detail: GarageDrillFocusDetail,
        canonicalDrill: GarageDrill?,
        metadata: GarageDrillFocusMetadata,
        prescription: GarageDrillPrescription
    ) -> GarageDrillFocusContent {
        let title = cleanTitle(canonicalDrill?.title ?? drill.title, fallback: "Practice Drill")
        let durationSeconds = prescription.durationSeconds ?? metadata.durationSecondsOverride ?? max(detail.estimatedMinutes, 1) * 60
        let goal = goal(
            prescription: prescription,
            durationSeconds: durationSeconds
        )
        let mode = focusMode(for: prescription)
        let watchFor = firstCleanLine(detail.commonMisses)
        let guidanceText = guidanceText(for: prescription)

        return GarageDrillFocusContent(
            title: title,
            task: metadata.commandCopy,
            setupLine: prescription.activeSetupReminder ?? metadata.setupLine,
            executionCue: prescription.activeCue ?? metadata.executionCue,
            setupSteps: setupSteps(detail: detail, prescription: prescription, fallback: metadata.setupLine),
            cueSteps: cueSteps(detail: detail, prescription: prescription, fallback: metadata.executionCue),
            goal: goal,
            mode: mode,
            durationSeconds: durationSeconds,
            targetMetric: prescription.goalText,
            guidanceText: guidanceText,
            watchFor: watchFor,
            finishRule: finishRule(for: prescription, durationSeconds: durationSeconds),
            teachingDetail: metadata.teachingDetail,
            reviewSummary: prescription.progressionNotes ?? metadata.reviewSummary,
            diagramKey: metadata.diagramKey
        )
    }

    private static func guidanceText(for prescription: GarageDrillPrescription) -> String? {
        switch prescription.mode {
        case .timed:
            return "Stay disciplined for the full timer."
        case .reps:
            return prescription.targetCount.map { "Complete \($0) honest reps before moving on." }
        case .goal:
            return "Judge success by the stated goal, not by speed."
        case .challenge:
            return "Pressure only counts when the standard stays honest."
        case .checklist:
            return prescription.targetCount.map { "Work through \($0) checklist items with no skipped setup." }
        }
    }

    private static func finishRule(for prescription: GarageDrillPrescription, durationSeconds: Int) -> String {
        switch prescription.mode {
        case .timed:
            return "Finish the full \(formattedDuration(durationSeconds)) block."
        case .reps:
            return "Stop when the rep target is honest."
        case .goal:
            return "Stop when the goal is met or the standard breaks down."
        case .challenge:
            return "If the pressure standard breaks, reset honestly."
        case .checklist:
            return "Close the drill only after each checklist item is covered."
        }
    }

    private static func goal(
        prescription: GarageDrillPrescription,
        durationSeconds: Int
    ) -> GarageDrillGoal {
        switch prescription.mode {
        case .timed:
            return .timed(durationSeconds: durationSeconds)
        case .reps:
            return .repTarget(count: max(prescription.targetCount ?? 1, 1), unit: "reps")
        case .goal:
            return .manual(label: prescription.goalText)
        case .challenge:
            return .streak(count: max(prescription.targetCount ?? 1, 1), unit: "goal reps")
        case .checklist:
            return .checklist(items: (prescription.targetCount ?? 1) > 1 ? Array(repeating: "Checkpoint", count: prescription.targetCount ?? 1) : [prescription.goalText])
        }
    }

    private static func focusMode(for prescription: GarageDrillPrescription) -> GarageDrillFocusMode {
        prescription.mode.focusMode
    }

    private static func cleanTitle(_ value: String, fallback: String) -> String {
        let cleaned = value.garageFocusContentTrimmed
        return cleaned.isEmpty ? fallback : cleaned
    }

    private static func cleanLines(_ values: [String]) -> [String] {
        values
            .map(\.garageFocusContentTrimmed)
            .filter { $0.isEmpty == false }
    }

    private static func setupSteps(
        detail: GarageDrillFocusDetail,
        prescription: GarageDrillPrescription,
        fallback: String
    ) -> [String] {
        let source = cleanLines(detail.setup)
        if source.isEmpty == false {
            return conciseSteps(Array(source.prefix(3)), maxWords: 9)
        }

        let reminder = prescription.activeSetupReminder?.garageFocusContentTrimmed ?? ""
        if reminder.isEmpty == false {
            return conciseSteps(Array(bulletSteps(from: reminder).prefix(3)), maxWords: 9)
        }

        return conciseSteps(Array(bulletSteps(from: fallback).prefix(3)), maxWords: 9)
    }

    private static func cueSteps(
        detail: GarageDrillFocusDetail,
        prescription: GarageDrillPrescription,
        fallback: String
    ) -> [String] {
        let source = cleanLines(detail.execution)
        if source.isEmpty == false {
            return conciseSteps(Array(source.prefix(1)), maxWords: 8)
        }

        let reminder = prescription.activeCue?.garageFocusContentTrimmed ?? ""
        if reminder.isEmpty == false {
            return conciseSteps(Array(bulletSteps(from: reminder).prefix(1)), maxWords: 8)
        }

        return conciseSteps(Array(bulletSteps(from: fallback).prefix(1)), maxWords: 8)
    }

    private static func bulletSteps(from value: String) -> [String] {
        let trimmed = value.garageFocusContentTrimmed
        if trimmed.isEmpty {
            return []
        }

        let split = trimmed
            .split(whereSeparator: { [".", ";", "|", "\n", "•", "·", "-"].contains($0) })
            .map { String($0).garageFocusContentTrimmed }
            .filter { $0.isEmpty == false }
        if split.isEmpty {
            return [trimmed]
        }
        return Array(split.prefix(5))
    }

    private static func conciseSteps(_ steps: [String], maxWords: Int) -> [String] {
        let cleaned = steps
            .map { step in
                let words = step
                    .split(whereSeparator: \.isWhitespace)
                    .map(String.init)
                if words.count <= maxWords {
                    return step.garageFocusContentTrimmed
                }
                return words.prefix(maxWords).joined(separator: " ")
            }
            .map(\.garageFocusContentTrimmed)
            .filter { $0.isEmpty == false }

        if cleaned.isEmpty {
            return ["Hold the drill standard."]
        }
        return cleaned
    }

    private static func firstCleanLine(_ groups: [String]...) -> String? {
        for group in groups {
            if let value = cleanLines(group).first {
                return value
            }
        }

        return nil
    }

    private static func compactFeelCategory(canonicalDrill: GarageDrill?, drill: PracticeTemplateDrill) -> String {
        if let canonicalDrill {
            return canonicalDrill.libraryCategory.displayName
        }

        let focus = drill.focusArea.garageFocusContentTrimmed
        return focus.isEmpty ? "Practice" : focus.garageFocusContentSentenceLimited(maxWords: 4)
    }

    private static func compactClubGroup(canonicalDrill: GarageDrill?, drill: PracticeTemplateDrill) -> String {
        if let canonicalDrill {
            return canonicalDrill.clubRange.displayName
        }

        let targetClub = drill.targetClub.garageFocusContentTrimmed
        return targetClub.isEmpty ? "Club" : targetClub.garageFocusContentSentenceLimited(maxWords: 5)
    }

    private static func compactIntent(canonicalDrill: GarageDrill?, detail: GarageDrillFocusDetail) -> String {
        let source = firstCleanLine([canonicalDrill?.purpose ?? "", detail.purpose]) ?? "Run the drill with one clear goal."
        return compactPlayerCopy(source, maxWords: 10)
    }

    private static func compactTarget(from goalText: String, detail: GarageDrillFocusDetail) -> String {
        if goalText.garageFocusContentTrimmed.isEmpty == false {
            return compactPlayerCopy(goalText, maxWords: 10)
        }

        let fallback = firstCleanLine(detail.successCriteria) ?? "Complete the drill with clean intent."
        return compactPlayerCopy(fallback, maxWords: 10)
    }

    private static func compactSelectedClub(
        prescription: GarageDrillPrescription,
        canonicalDrill: GarageDrill?,
        fallbackClubGroup: String
    ) -> String {
        let selectedClub = prescription.selectedClub?.garageFocusContentTrimmed ?? ""
        if selectedClub.isEmpty == false {
            return selectedClub.garageFocusContentSentenceLimited(maxWords: 5)
        }

        return canonicalDrill?.clubRange.displayName ?? fallbackClubGroup
    }

    private static func compactResetCue(_ value: String) -> String? {
        let cleaned = compactPlayerCopy(value, maxWords: 6)
        return cleaned.isEmpty ? nil : cleaned
    }

    private static func compactBullets(
        _ source: [String],
        fallback: String,
        limit: Int,
        maxWords: Int
    ) -> [String] {
        let sourceLines = cleanLines(source)
        let candidates = sourceLines.isEmpty ? bulletSteps(from: fallback) : sourceLines
        let cleaned = candidates
            .prefix(limit)
            .map { compactPlayerCopy($0, maxWords: maxWords) }
            .filter { $0.isEmpty == false }

        if cleaned.isEmpty {
            return ["Set a clear station."]
        }

        return cleaned
    }

    private static func compactPlayerCopy(_ value: String, maxWords: Int) -> String {
        value
            .garageFocusContentPlayerSanitized
            .garageFocusContentSentenceLimited(maxWords: maxWords)
    }

    private static func formattedDuration(_ seconds: Int) -> String {
        let clampedSeconds = max(seconds, 0)
        let minutes = clampedSeconds / 60
        let remainingSeconds = clampedSeconds % 60

        if minutes > 0, remainingSeconds == 0 {
            return "\(minutes)-minute"
        }

        if minutes > 0 {
            return "\(minutes)m \(remainingSeconds)s"
        }

        return "\(remainingSeconds)-second"
    }
}

extension GarageDrillGoal {
    var railSummary: String {
        switch self {
        case .timed(let durationSeconds):
            return GarageDrillGoalFormat.duration(durationSeconds)
        case .repTarget(let count, let unit):
            return "\(count) \(unit)"
        case .streak(let count, let unit):
            return "\(count) \(unit) in a row"
        case .timeTrial(let targetCount, let unit):
            return "\(targetCount) \(unit) time trial"
        case .ladder(let steps):
            return "\(steps.count) ladder steps"
        case .checklist(let items):
            return "\(items.count) checklist items"
        case .manual(let label):
            return label
        }
    }

    var goalText: String {
        switch self {
        case .timed(let durationSeconds):
            return "Suggested: \(GarageDrillGoalFormat.duration(durationSeconds))."
        case .repTarget(let count, let unit):
            return "Complete \(count) \(unit)."
        case .streak(let count, let unit):
            return "Reach \(count) \(unit) in a row."
        case .timeTrial(let targetCount, let unit):
            return "Track how long it takes to record \(targetCount) \(unit)."
        case .ladder(let steps):
            return "Complete \(steps.count) ladder steps."
        case .checklist(let items):
            return "Complete \(items.count) checklist items."
        case .manual(let label):
            return label
        }
    }
}

private enum GarageDrillGoalFormat {
    static func duration(_ seconds: Int) -> String {
        let clampedSeconds = max(seconds, 0)
        let minutes = clampedSeconds / 60
        let remainingSeconds = clampedSeconds % 60

        if minutes > 0, remainingSeconds == 0 {
            return "\(minutes) min"
        }

        if minutes > 0 {
            return "\(minutes)m \(String(format: "%02d", remainingSeconds))s"
        }

        return "\(remainingSeconds)s"
    }
}

private extension String {
    var garageFocusContentTrimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }

    var garageFocusContentPlayerSanitized: String {
        var cleaned = garageFocusContentTrimmed
        let replacements: [(String, String)] = [
            ("Pressure Test", "Target"),
            ("pressure test", "target"),
            ("pressure standard", "target"),
            ("Process Block", "Practice Block"),
            ("process block", "practice block"),
            ("Target Block", "Target"),
            ("target block", "target"),
            ("authority", "practice"),
            ("Authority", "Practice"),
            ("fallback", "backup"),
            ("Fallback", "Backup"),
            ("remedial", "backup"),
            ("Remedial", "Backup"),
            ("diagnostic", "practice"),
            ("Diagnostic", "Practice"),
            ("challenge", "target"),
            ("Challenge", "Target"),
            ("Mode", "Style"),
            ("mode", "style")
        ]

        for replacement in replacements {
            cleaned = cleaned.replacingOccurrences(of: replacement.0, with: replacement.1)
        }

        return cleaned.garageFocusContentTrimmed
    }

    func garageFocusContentSentenceLimited(maxWords: Int) -> String {
        let sentence = garageFocusContentTrimmed
            .split(separator: ".", maxSplits: 1, omittingEmptySubsequences: true)
            .first
            .map(String.init)?
            .garageFocusContentTrimmed ?? garageFocusContentTrimmed
        let words = sentence
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)

        guard words.count > maxWords else {
            return sentence
        }

        return words.prefix(maxWords).joined(separator: " ")
    }
}
