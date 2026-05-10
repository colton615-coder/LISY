import Foundation

struct GarageDrillFocusContent: Hashable {
    let title: String
    let task: String
    let setupLine: String
    let executionCue: String
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
        let durationSeconds = metadata.durationSecondsOverride ?? max(detail.estimatedMinutes, 1) * 60
        let goal = goal(
            for: drill,
            canonicalDrill: canonicalDrill,
            metadata: metadata,
            durationSeconds: durationSeconds
        )
        let mode = focusMode(for: drill, metadata: metadata)
        let watchFor = firstCleanLine(detail.commonMisses)
        let guidanceText = suggestedVolumeText(for: drill, canonicalDrill: canonicalDrill)

        return GarageDrillFocusContent(
            title: title,
            task: metadata.commandCopy,
            setupLine: metadata.setupLine,
            executionCue: metadata.executionCue,
            goal: goal,
            mode: mode,
            durationSeconds: durationSeconds,
            targetMetric: metadata.targetMetric,
            guidanceText: guidanceText,
            watchFor: watchFor,
            finishRule: finishRule(forDurationSeconds: durationSeconds),
            teachingDetail: metadata.teachingDetail,
            reviewSummary: metadata.reviewSummary,
            diagramKey: metadata.diagramKey
        )
    }

    private static func suggestedVolumeText(
        for drill: PracticeTemplateDrill,
        canonicalDrill: GarageDrill?
    ) -> String? {
        let count = drill.defaultRepCount > 0 ? drill.defaultRepCount : (canonicalDrill?.defaultRepCount ?? 0)
        guard count > 0 else {
            return nil
        }

        let lowerBound = max(count, 1)
        let upperBound = max(lowerBound + 5, Int((Double(lowerBound) * 1.4).rounded()))
        return "Suggested volume: \(lowerBound)-\(upperBound) focused swings."
    }

    private static func finishRule(forDurationSeconds durationSeconds: Int) -> String {
        "Suggested: \(formattedDuration(durationSeconds)) of focused work."
    }

    private static func goal(
        for drill: PracticeTemplateDrill,
        canonicalDrill: GarageDrill?,
        metadata: GarageDrillFocusMetadata,
        durationSeconds: Int
    ) -> GarageDrillGoal {
        if let authorityGoal = metadata.authorityGoal {
            return drillGoal(from: authorityGoal, durationSeconds: durationSeconds)
        }

        switch metadata.mode {
        case .process:
            let count = max(drill.defaultRepCount, canonicalDrill?.defaultRepCount ?? 0)
            return count > 0 ? .repTarget(count: count, unit: "honest attempts") : .timed(durationSeconds: durationSeconds)
        case .target:
            return .repTarget(
                count: max(drill.defaultRepCount, canonicalDrill?.defaultRepCount ?? 1, 1),
                unit: "target reps"
            )
        case .pressureTest:
            return .streak(
                count: max(drill.defaultRepCount, canonicalDrill?.defaultRepCount ?? 1, 1),
                unit: "pressure reps"
            )
        }
    }

    private static func drillGoal(
        from authorityGoal: GarageDrillAuthorityGoal,
        durationSeconds: Int
    ) -> GarageDrillGoal {
        switch authorityGoal {
        case .timed:
            return .timed(durationSeconds: durationSeconds)
        case .reps(let count, let unit):
            return .repTarget(count: max(count, 1), unit: unit)
        case .goal(let count, let unit):
            return .repTarget(count: max(count, 1), unit: unit)
        case .challenge(let count, let unit):
            return .streak(count: max(count, 1), unit: unit)
        case .checklist(let items):
            return .checklist(items: items.isEmpty ? ["Complete the drill standard"] : items)
        }
    }

    private static func focusMode(
        for drill: PracticeTemplateDrill,
        metadata: GarageDrillFocusMetadata
    ) -> GarageDrillFocusMode {
        return metadata.mode
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
}
