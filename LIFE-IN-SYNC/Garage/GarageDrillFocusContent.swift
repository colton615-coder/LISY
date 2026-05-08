import Foundation

struct GarageDrillFocusContent: Hashable {
    let title: String
    let task: String
    let setupSteps: [String]
    let goal: GarageDrillGoal
    let watchFor: String?
    let finishRule: String
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
    static func content(
        for drill: PracticeTemplateDrill,
        detail: GarageDrillFocusDetail
    ) -> GarageDrillFocusContent {
        let canonicalDrill = DrillVault.canonicalDrill(for: drill)

        switch canonicalDrill?.id {
        case "n1":
            return heavyTowelStrikeContent(title: drill.title)
        case "r13":
            return distanceLadderContent(title: drill.title)
        case "p3":
            return gateStartBuilderContent(title: drill.title)
        default:
            return fallbackContent(
                for: drill,
                detail: detail,
                canonicalDrill: canonicalDrill
            )
        }
    }

    private static func heavyTowelStrikeContent(title: String) -> GarageDrillFocusContent {
        GarageDrillFocusContent(
            title: cleanTitle(title, fallback: "Heavy Towel Strike"),
            task: "Strike the ball without touching the towel behind it.",
            setupSteps: [
                "Place a towel 2 inches behind the ball.",
                "Use a wedge or short iron.",
                "Start with controlled swings."
            ],
            goal: .streak(count: 5, unit: "clean strikes"),
            watchFor: "Towel contact before ball contact.",
            finishRule: "Finish when you flush 5 clean strikes in a row."
        )
    }

    private static func distanceLadderContent(title: String) -> GarageDrillFocusContent {
        GarageDrillFocusContent(
            title: cleanTitle(title, fallback: "Distance Ladder"),
            task: "Carry the ball to each wedge number without changing rhythm.",
            setupSteps: [
                "Pick carry numbers at 50, 65, and 80 yards.",
                "Use the same wedge routine before every ball.",
                "Track carry distance, not rollout."
            ],
            goal: .ladder(steps: [
                "Land one ball at 50 yards.",
                "Land one ball at 65 yards.",
                "Land one ball at 80 yards.",
                "Repeat the ladder once with the same rhythm."
            ]),
            watchFor: "Swinging harder instead of changing swing length.",
            finishRule: "Finish after the ladder is complete without tempo spikes."
        )
    }

    private static func gateStartBuilderContent(title: String) -> GarageDrillFocusContent {
        GarageDrillFocusContent(
            title: cleanTitle(title, fallback: "Gate Start Builder"),
            task: "Roll the ball through the tee gate on your start line.",
            setupSteps: [
                "Set two tees just wider than the putter head.",
                "Start from 4 feet on a clear start line.",
                "Use the same stroke rhythm each attempt."
            ],
            goal: .timeTrial(targetCount: 6, unit: "clean starts"),
            watchFor: "Clipping a tee or steering the face late.",
            finishRule: "Finish when 6 clean starts are recorded."
        )
    }

    private static func fallbackContent(
        for drill: PracticeTemplateDrill,
        detail: GarageDrillFocusDetail,
        canonicalDrill: GarageDrill?
    ) -> GarageDrillFocusContent {
        let title = cleanTitle(drill.title, fallback: canonicalDrill?.title ?? "Practice Drill")
        let task = firstCleanLine(
            detail.execution,
            canonicalDrill?.executionSteps ?? []
        ) ?? firstCleanOptional([
            canonicalDrill?.abstractFeelCue,
            canonicalDrill?.purpose,
            drill.focusArea
        ]) ?? "Complete the assigned task with honest feedback."
        let setupSteps = cleanSetupSteps(for: drill, detail: detail, canonicalDrill: canonicalDrill)
        let goal = fallbackGoal(for: drill, detail: detail, canonicalDrill: canonicalDrill)
        let watchFor = firstCleanLine(detail.commonMisses) ?? "Rushing the task or counting unclear reps."

        return GarageDrillFocusContent(
            title: title,
            task: task,
            setupSteps: setupSteps,
            goal: goal,
            watchFor: watchFor,
            finishRule: finishRule(for: goal)
        )
    }

    private static func fallbackGoal(
        for drill: PracticeTemplateDrill,
        detail: GarageDrillFocusDetail,
        canonicalDrill: GarageDrill?
    ) -> GarageDrillGoal {
        let title = (canonicalDrill?.title ?? drill.title).lowercased()
        let executionSteps = cleanLines(canonicalDrill?.executionSteps ?? detail.execution)

        if title.contains("ladder"), executionSteps.isEmpty == false {
            return .ladder(steps: executionSteps)
        }

        if drill.defaultRepCount <= 0 {
            return .timed(durationSeconds: max(detail.estimatedMinutes, 5) * 60)
        }

        return .repTarget(count: max(drill.defaultRepCount, 1), unit: "clean reps")
    }

    private static func cleanSetupSteps(
        for drill: PracticeTemplateDrill,
        detail: GarageDrillFocusDetail,
        canonicalDrill: GarageDrill?
    ) -> [String] {
        let setup = cleanLines(detail.setup)
        if setup.isEmpty == false {
            return Array(setup.prefix(3))
        }

        let execution = cleanLines(canonicalDrill?.executionSteps ?? detail.execution)
        if execution.isEmpty == false {
            return Array(execution.prefix(3))
        }

        let targetClub = drill.targetClub.garageFocusContentTrimmed
        return [
            targetClub.isEmpty ? "Use the assigned club or tool." : "Use \(targetClub).",
            "Prepare the station safely.",
            "Keep the task narrow and measurable."
        ]
    }

    private static func finishRule(for goal: GarageDrillGoal) -> String {
        switch goal {
        case .timed(let durationSeconds):
            return "Finish when the \(formattedDuration(durationSeconds)) block is complete."
        case .repTarget(let count, let unit):
            return "Finish after \(count) \(unit)."
        case .streak(let count, let unit):
            return "Finish when you reach \(count) \(unit) in a row."
        case .timeTrial(let targetCount, let unit):
            return "Finish when \(targetCount) \(unit) are recorded."
        case .ladder:
            return "Finish when every ladder step is complete."
        case .checklist:
            return "Finish when every checklist item is complete."
        case .manual(let label):
            return label
        }
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

    private static func firstCleanLine(_ groups: [String]...) -> String? {
        for group in groups {
            if let value = cleanLines(group).first {
                return value
            }
        }

        return nil
    }

    private static func firstCleanOptional(_ values: [String?]) -> String? {
        values
            .compactMap { $0?.garageFocusContentTrimmed }
            .first { $0.isEmpty == false }
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
            return "\(GarageDrillGoalFormat.duration(durationSeconds)) timed"
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
            return "Work for \(GarageDrillGoalFormat.duration(durationSeconds))."
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
}
