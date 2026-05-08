import Foundation

struct GarageDrillFocusContent: Hashable {
    let title: String
    let task: String
    let setupLine: String
    let executionCue: String
    let goal: GarageDrillGoal
    let mode: GarageDrillFocusMode
    let targetMetric: String
    let watchFor: String?
    let finishRule: String
    let teachingDetail: String?
    let reviewSummary: String?
    let quickTags: [String]
    let diagramKey: String?
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
    static func content(
        for drill: PracticeTemplateDrill,
        detail: GarageDrillFocusDetail
    ) -> GarageDrillFocusContent {
        let canonicalDrill = DrillVault.canonicalDrill(for: drill)
        let metadata = GarageDrillFocusDetails.metadata(for: drill, detail: detail)

        return content(
            for: drill,
            detail: detail,
            canonicalDrill: canonicalDrill,
            metadata: metadata
        )
    }

    private static func content(
        for drill: PracticeTemplateDrill,
        detail: GarageDrillFocusDetail,
        canonicalDrill: GarageDrill?,
        metadata: GarageDrillFocusMetadata
    ) -> GarageDrillFocusContent {
        let title = cleanTitle(canonicalDrill?.title ?? drill.title, fallback: "Practice Drill")
        let goal = goal(for: drill, detail: detail, canonicalDrill: canonicalDrill, metadata: metadata)
        let watchFor = firstCleanLine(detail.commonMisses)

        return GarageDrillFocusContent(
            title: title,
            task: metadata.commandCopy,
            setupLine: metadata.setupLine,
            executionCue: metadata.executionCue,
            goal: goal,
            mode: metadata.mode,
            targetMetric: metadata.targetMetric,
            watchFor: watchFor,
            finishRule: finishRule(for: goal),
            teachingDetail: metadata.teachingDetail,
            reviewSummary: metadata.reviewSummary,
            quickTags: metadata.quickTags,
            diagramKey: metadata.diagramKey
        )
    }

    private static func goal(
        for drill: PracticeTemplateDrill,
        detail: GarageDrillFocusDetail,
        canonicalDrill: GarageDrill?,
        metadata: GarageDrillFocusMetadata
    ) -> GarageDrillGoal {
        let executionSteps = cleanLines(detail.execution)
        let defaultCount = drill.defaultRepCount > 0 ? drill.defaultRepCount : (canonicalDrill?.defaultRepCount ?? 1)

        switch metadata.mode {
        case .reps:
            return .repTarget(count: max(defaultCount, 1), unit: "clean reps")
        case .time:
            return .timed(durationSeconds: max(detail.estimatedMinutes, 1) * 60)
        case .goal:
            if canonicalDrill?.id == "r13" {
                return .ladder(steps: [
                    "Land one ball at the short carry number.",
                    "Land one ball at the middle carry number.",
                    "Land one ball at the long carry number.",
                    "Repeat the ladder with the same rhythm."
                ])
            }

            if canonicalDrill?.id == "p2" {
                return .ladder(steps: [
                    "Roll the first ball to the starting distance.",
                    "Roll the next ball slightly past it.",
                    "Keep each next ball one foot farther.",
                    "Stop before one races outside the corridor."
                ])
            }

            if executionSteps.count > 1 {
                return .ladder(steps: Array(executionSteps.prefix(4)))
            }

            return .manual(label: metadata.targetMetric)
        case .challenge:
            switch canonicalDrill?.id {
            case "n1":
                return .streak(count: 5, unit: "clean strikes")
            case "n7":
                return .repTarget(count: 6, unit: "clean exits")
            case "p3":
                return .timeTrial(targetCount: 6, unit: "clean starts")
            case "r15":
                return .streak(count: 5, unit: "fairway starts")
            case "r17":
                return .ladder(steps: [
                    "Hit the easiest fairway window.",
                    "Hit the middle fairway window.",
                    "Hit the hardest fairway window."
                ])
            case "p6":
                return .streak(count: 3, unit: "balls in the zone")
            default:
                return .repTarget(count: max(defaultCount, 1), unit: "clean attempts")
            }
        case .checklist:
            if canonicalDrill?.id == "r14" {
                return .checklist(items: [
                    "Hit the low window.",
                    "Hit the stock window.",
                    "Hit the high window."
                ])
            }

            if canonicalDrill?.id == "p4" {
                return .checklist(items: [
                    "Complete station one.",
                    "Complete station two.",
                    "Complete station three.",
                    "Complete station four."
                ])
            }

            let items = executionSteps.isEmpty ? [metadata.executionCue] : executionSteps
            return .checklist(items: Array(items.prefix(5)))
        }
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
