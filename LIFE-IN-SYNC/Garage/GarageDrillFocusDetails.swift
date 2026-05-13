import Foundation

enum GarageDrillFocusMode: String, Hashable {
    case process
    case target
    case pressureTest

    init(legacyValue: String) {
        switch legacyValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "goal", "target":
            self = .target
        case "challenge", "pressuretest", "pressure test", "pressure_test":
            self = .pressureTest
        case "timed", "time", "timer", "reps", "rep", "checklist", "process":
            self = .process
        default:
            self = .process
        }
    }

    var controlLabel: String {
        switch self {
        case .process:
            return "Process"
        case .target:
            return "Target"
        case .pressureTest:
            return "Pressure Test"
        }
    }

    var trackerLabel: String {
        switch self {
        case .process:
            return "Process Block"
        case .target:
            return "Target Block"
        case .pressureTest:
            return "Pressure Test Block"
        }
    }
}

enum GarageDrillAuthorityGoal: Hashable {
    case timed
    case reps(count: Int, unit: String)
    case goal(count: Int, unit: String)
    case challenge(count: Int, unit: String)
    case checklist(items: [String])
}

struct GarageDrillFocusMetadata: Hashable {
    let mode: GarageDrillFocusMode
    let authorityGoal: GarageDrillAuthorityGoal?
    let durationSecondsOverride: Int?
    let commandCopy: String
    let setupLine: String
    let executionCue: String
    let teachingDetail: String?
    let reviewSummary: String?
    let targetMetric: String
    let quickTags: [String]
    let diagramKey: String?

    init(
        mode: GarageDrillFocusMode,
        authorityGoal: GarageDrillAuthorityGoal? = nil,
        durationSecondsOverride: Int? = nil,
        commandCopy: String,
        setupLine: String,
        executionCue: String,
        teachingDetail: String? = nil,
        reviewSummary: String? = nil,
        targetMetric: String,
        quickTags: [String] = [],
        diagramKey: String? = nil
    ) {
        self.mode = mode
        self.authorityGoal = authorityGoal
        self.durationSecondsOverride = durationSecondsOverride
        self.commandCopy = commandCopy
        self.setupLine = setupLine
        self.executionCue = executionCue
        self.teachingDetail = teachingDetail
        self.reviewSummary = reviewSummary
        self.targetMetric = targetMetric
        self.quickTags = quickTags
        self.diagramKey = diagramKey
    }
}

struct GarageDrillFocusDetail: Hashable {
    let purpose: String
    let setup: [String]
    let execution: [String]
    let successCriteria: [String]
    let commonMisses: [String]
    let resetCue: String
    let equipment: [String]
    let estimatedMinutes: Int

    func repTargetText(for drill: PracticeTemplateDrill) -> String {
        "\(max(drill.defaultRepCount, 0)) suggested attempts"
    }
}

enum GarageDrillFocusDetails {
    static func detail(for drill: PracticeTemplateDrill) -> GarageDrillFocusDetail {
        guard let canonicalDrill = DrillVault.canonicalDrill(for: drill) else {
            #if DEBUG
            DrillVault.auditUnresolvedTemplateDrill(drill, context: "focus-detail")
            #endif
            return customDetail(for: drill)
        }

        return detail(for: canonicalDrill)
    }

    static func metadata(
        for drill: PracticeTemplateDrill,
        detail: GarageDrillFocusDetail
    ) -> GarageDrillFocusMetadata {
        #if DEBUG
        if let qaMetadata = GarageDrillAuthorityQAIdentifiers.metadata(for: drill, detail: detail) {
            return qaMetadata
        }
        #endif

        guard let canonicalDrill = DrillVault.canonicalDrill(for: drill) else {
            #if DEBUG
            DrillVault.auditUnresolvedTemplateDrill(drill, context: "focus-metadata")
            #endif
            return customMetadata(for: drill, detail: detail)
        }

        return metadata(for: canonicalDrill, detail: detail)
    }

    static func metadata(
        for drill: GarageDrill,
        detail: GarageDrillFocusDetail
    ) -> GarageDrillFocusMetadata {
        let firstSetup = cleanLine(detail.setup.first) ?? "Set a safe station before the first rep."
        let firstExecution = cleanLine(detail.execution.first) ?? drill.abstractFeelCue
        let firstSuccess = cleanLine(detail.successCriteria.first) ?? drill.purpose
        let quickTags = quickTags(for: drill)

        switch drill.id {
        case "n1":
            return GarageDrillFocusMetadata(
                mode: .pressureTest,
                authorityGoal: .challenge(count: 5, unit: "clean strikes"),
                commandCopy: "Strike the ball without touching the towel behind it.",
                setupLine: "Place a towel about 2 inches behind the ball.",
                executionCue: "Count only ball-first strikes where the towel stays still.",
                teachingDetail: detail.purpose,
                reviewSummary: "Clean strikes should feel ball-first with no towel contact.",
                targetMetric: "5 clean strikes in a row",
                quickTags: quickTags,
                diagramKey: "towel-strike"
            )
        case "n3":
            return GarageDrillFocusMetadata(
                mode: .process,
                authorityGoal: .timed,
                commandCopy: "Rehearse hip depth without lunging toward the ball.",
                setupLine: firstSetup,
                executionCue: "Move slowly enough that posture stays intact.",
                teachingDetail: detail.purpose,
                reviewSummary: "You should finish with hip depth and athletic posture still present.",
                targetMetric: "\(detail.estimatedMinutes)-minute rehearsal block",
                quickTags: quickTags,
                diagramKey: "wall-turn"
            )
        case "n7":
            return GarageDrillFocusMetadata(
                mode: .pressureTest,
                authorityGoal: .challenge(count: 6, unit: "clean exits"),
                commandCopy: "Exit low without clipping the headcover.",
                setupLine: firstSetup,
                executionCue: "Keep the chest turning through the low window.",
                teachingDetail: detail.purpose,
                reviewSummary: "Clean reps avoid the headcover and keep the exit shallow.",
                targetMetric: "6 clean exits",
                quickTags: quickTags,
                diagramKey: "low-exit-window"
            )
        case "r10":
            return GarageDrillFocusMetadata(
                mode: .target,
                authorityGoal: .goal(count: 5, unit: "start-line reads"),
                commandCopy: "Start the ball through the same launch gate.",
                setupLine: firstSetup,
                executionCue: "Judge the first 10 yards before judging curve.",
                teachingDetail: detail.purpose,
                reviewSummary: "Success is a predictable start line, not a perfect final curve.",
                targetMetric: "5 start-line reads",
                quickTags: quickTags,
                diagramKey: "start-line-gate"
            )
        case "r12":
            return GarageDrillFocusMetadata(
                mode: .target,
                authorityGoal: .goal(count: 3, unit: "carry windows"),
                commandCopy: "Move through three carry targets while contact stays clean.",
                setupLine: firstSetup,
                executionCue: "Restart the ladder if strike gets heavy or thin.",
                teachingDetail: detail.purpose,
                reviewSummary: "The carry ladder only counts when strike quality holds.",
                targetMetric: "3 carry windows",
                quickTags: quickTags,
                diagramKey: "carry-ladder"
            )
        case "r13":
            return GarageDrillFocusMetadata(
                mode: .target,
                authorityGoal: .goal(count: 3, unit: "wedge carry numbers"),
                commandCopy: "Carry the ball to each wedge number without changing rhythm.",
                setupLine: "Pick three carry numbers such as 50, 65, and 80 yards.",
                executionCue: "Adjust swing length, not tempo.",
                teachingDetail: detail.purpose,
                reviewSummary: "You should know which swing length produced each carry.",
                targetMetric: "3 wedge carry numbers",
                quickTags: quickTags,
                diagramKey: "distance-ladder"
            )
        case "r14":
            return GarageDrillFocusMetadata(
                mode: .process,
                authorityGoal: .checklist(items: ["Low window", "Stock window", "High window"]),
                commandCopy: "Hit low, stock, and high windows with the same effort.",
                setupLine: firstSetup,
                executionCue: "Change finish height and face feel, not effort.",
                teachingDetail: detail.purpose,
                reviewSummary: "All three windows should look distinct without a tempo spike.",
                targetMetric: "low, stock, high",
                quickTags: quickTags,
                diagramKey: "flight-matrix"
            )
        case "r15":
            return GarageDrillFocusMetadata(
                mode: .pressureTest,
                authorityGoal: .challenge(count: 5, unit: "fairway starts"),
                commandCopy: "Launch driver through a fairway-sized start gate.",
                setupLine: firstSetup,
                executionCue: "Hold the finish for two counts before judging the shot.",
                teachingDetail: detail.purpose,
                reviewSummary: "Fairway discipline comes before extra speed.",
                targetMetric: "5 fairway starts",
                quickTags: quickTags,
                diagramKey: "fairway-gate"
            )
        case "r17":
            return GarageDrillFocusMetadata(
                mode: .pressureTest,
                authorityGoal: .challenge(count: 3, unit: "pressure windows"),
                commandCopy: "Advance through the fairway ladder without losing posture.",
                setupLine: firstSetup,
                executionCue: "Restart if the body stalls or crowds the ball.",
                teachingDetail: detail.purpose,
                reviewSummary: "Pressure only counts when posture and turn hold up.",
                targetMetric: "3 pressure windows",
                quickTags: quickTags,
                diagramKey: "pressure-fairway-ladder"
            )
        case "p2":
            return GarageDrillFocusMetadata(
                mode: .target,
                authorityGoal: .goal(count: 1, unit: "distance ladder"),
                commandCopy: "Roll each next ball slightly farther than the last.",
                setupLine: firstSetup,
                executionCue: "Control the gap with stroke length, not a jab.",
                teachingDetail: detail.purpose,
                reviewSummary: "Good pace creates small, predictable distance gaps.",
                targetMetric: "leapfrog distance ladder",
                quickTags: quickTags,
                diagramKey: "leapfrog-lag"
            )
        case "p3":
            return GarageDrillFocusMetadata(
                mode: .pressureTest,
                authorityGoal: .challenge(count: 6, unit: "clean starts"),
                commandCopy: "Roll the ball through the tee gate on your start line.",
                setupLine: "Set two tees just wider than the putter head.",
                executionCue: "Count only starts that miss both tees cleanly.",
                teachingDetail: detail.purpose,
                reviewSummary: "Clean starts should pass through the gate without steering.",
                targetMetric: "6 clean starts",
                quickTags: quickTags,
                diagramKey: "putting-gate"
            )
        case "p4":
            return GarageDrillFocusMetadata(
                mode: .process,
                authorityGoal: .checklist(items: ["Station 1", "Station 2", "Station 3", "Station 4"]),
                commandCopy: "Putt from each station while tempo stays the same.",
                setupLine: firstSetup,
                executionCue: "Change stroke length as distance changes.",
                teachingDetail: detail.purpose,
                reviewSummary: "Pace should finish near the hole without rhythm changing.",
                targetMetric: "4 stations",
                quickTags: quickTags,
                diagramKey: "around-the-world"
            )
        case "p6":
            return GarageDrillFocusMetadata(
                mode: .pressureTest,
                authorityGoal: .challenge(count: 3, unit: "balls in the zone"),
                commandCopy: "Stop three balls inside the same pace zone.",
                setupLine: firstSetup,
                executionCue: "Restart if one races long or dies short.",
                teachingDetail: detail.purpose,
                reviewSummary: "The stop zone should tighten across all three balls.",
                targetMetric: "3 balls in the zone",
                quickTags: quickTags,
                diagramKey: "brake-test"
            )
        default:
            return GarageDrillFocusMetadata(
                mode: .process,
                commandCopy: firstExecution,
                setupLine: firstSetup,
                executionCue: cleanLine(detail.resetCue) ?? firstSuccess,
                teachingDetail: detail.purpose,
                reviewSummary: firstSuccess,
                targetMetric: "\(drill.defaultRepCount) suggested clean swings",
                quickTags: quickTags,
                diagramKey: drill.id
            )
        }
    }

    static func instructionContent(
        for drill: GarageDrill,
        detail: GarageDrillFocusDetail
    ) -> GarageDrillInstructionContent {
        let metadata = metadata(for: drill, detail: detail)
        return GarageDrillInstructionContent(
            whatItTrains: detail.purpose,
            whyItMatters: cleanLine(detail.successCriteria.first) ?? drill.purpose,
            setupWalkthrough: detail.setup,
            keyCues: [drill.abstractFeelCue] + detail.execution.prefix(2),
            commonMistakes: detail.commonMisses,
            variations: detail.successCriteria,
            suggestedClubs: [drill.clubRange.displayName],
            supportedModes: GarageDrillCatalog.defaultPrescription(
                for: drill.makeGeneratedPracticeTemplateDrill(seedKey: "instruction:\(drill.id)")
            ).mode.mapToArray,
            recommendedUseCases: recommendedUseCases(for: drill, metadata: metadata)
        )
    }

    static func instructionContent(
        for drill: PracticeTemplateDrill,
        detail: GarageDrillFocusDetail
    ) -> GarageDrillInstructionContent {
        if let canonicalDrill = DrillVault.canonicalDrill(for: drill) {
            return instructionContent(for: canonicalDrill, detail: detail)
        }

        let mode = GarageDrillCatalog.defaultPrescription(for: drill).mode
        let targetClub = drill.targetClub.trimmingCharacters(in: .whitespacesAndNewlines)
        return GarageDrillInstructionContent(
            whatItTrains: detail.purpose,
            whyItMatters: cleanLine(detail.successCriteria.first) ?? "Clarifies the custom practice standard before launch.",
            setupWalkthrough: detail.setup,
            keyCues: detail.execution,
            commonMistakes: detail.commonMisses,
            variations: detail.successCriteria,
            suggestedClubs: targetClub.isEmpty ? [] : [targetClub],
            supportedModes: [mode],
            recommendedUseCases: [
                "Use when you already know the drill and only need a clean execution setup.",
                "Promote into a saved routine only after the goal and setup stay consistent."
            ]
        )
    }

    static func detail(for drill: GarageDrill) -> GarageDrillFocusDetail {
        switch drill.id {
        case "n1":
            GarageDrillFocusDetail(
                purpose: "Clean contact",
                setup: ["Scoring iron + net-safe ball", "Folded towel about 2 inches behind the ball", "Start with relaxed half swings"],
                execution: ["Swing smooth", "Brush the ball before the towel", "Hold the finish for one count"],
                successCriteria: [],
                commonMisses: [],
                resetCue: "Brush the ball before the towel",
                equipment: ["Scoring iron", "Net-safe ball", "Folded towel"],
                estimatedMinutes: 8
            )
        case "n2":
            GarageDrillFocusDetail(
                purpose: "Handle-first feel",
                setup: ["Wedge or short iron", "Hands split about 3 inches on the grip", "Waist-to-waist swings only"],
                execution: ["Let the handle lead", "Keep the clubhead quiet behind your hands", "Finish small and balanced"],
                successCriteria: [],
                commonMisses: [],
                resetCue: "Let the handle lead",
                equipment: ["Wedge or short iron"],
                estimatedMinutes: 7
            )
        case "n3":
            GarageDrillFocusDetail(
                purpose: "Stay in posture",
                setup: ["Stand with trail hip near a wall", "No ball at first", "Move slowly enough to stay balanced"],
                execution: ["Turn back without drifting into the wall", "Turn through without standing up", "Add the club only when the body feels stable"],
                successCriteria: [],
                commonMisses: [],
                resetCue: "Turn through without standing up",
                equipment: ["Wall", "Club optional"],
                estimatedMinutes: 7
            )
        case "n4":
            GarageDrillFocusDetail(
                purpose: "Aim the face",
                setup: ["Scoring iron", "Pick a tiny net start window", "Use a stick or visual rail if helpful"],
                execution: ["Swing through the same window", "Keep the face quiet", "Restart if the window changes"],
                successCriteria: [],
                commonMisses: [],
                resetCue: "Keep the face quiet",
                equipment: ["Scoring iron", "Stick or visual rail"],
                estimatedMinutes: 7
            )
        case "n5":
            GarageDrillFocusDetail(
                purpose: "Balance and rhythm",
                setup: ["Wood or hybrid", "Feet close together", "Start around 60% speed"],
                execution: ["Make a smooth backswing", "Swing without swaying", "Hold the finish for two counts"],
                successCriteria: [],
                commonMisses: [],
                resetCue: "Hold the finish for two counts",
                equipment: ["Wood or hybrid"],
                estimatedMinutes: 8
            )
        case "n6":
            GarageDrillFocusDetail(
                purpose: "Calm transition",
                setup: ["Wedge or short iron", "Commit to a clear pause at the top", "Keep the shot soft"],
                execution: ["Pause at the top", "Shift pressure forward", "Then let the club fall through"],
                successCriteria: [],
                commonMisses: [],
                resetCue: "Pause at the top",
                equipment: ["Wedge or short iron"],
                estimatedMinutes: 7
            )
        case "n7":
            GarageDrillFocusDetail(
                purpose: "Low exit",
                setup: ["Wood or hybrid", "Headcover just outside the line after impact", "Start at half speed"],
                execution: ["Brush through the ball", "Keep the chest turning", "Exit low without clipping the headcover"],
                successCriteria: [],
                commonMisses: [],
                resetCue: "Exit low without clipping the headcover",
                equipment: ["Wood or hybrid", "Headcover"],
                estimatedMinutes: 8
            )
        case "n8":
            GarageDrillFocusDetail(
                purpose: "Repeat the brush",
                setup: ["Scoring iron", "Trail-hand-only half swings", "Pick a brush point just after the ball"],
                execution: ["Swing with the trail hand only", "Listen for the same crisp brush", "Add the lead hand when the brush repeats"],
                successCriteria: [],
                commonMisses: [],
                resetCue: "Listen for the same crisp brush",
                equipment: ["Scoring iron"],
                estimatedMinutes: 7
            )
        case "r10":
            GarageDrillFocusDetail(
                purpose: "First 10 yards",
                setup: ["Driver", "Pick one narrow launch gate", "Keep the same gate for the whole set"],
                execution: ["Hit through the gate", "Read the start line first", "Ignore curve until after the start is clear"],
                successCriteria: [],
                commonMisses: [],
                resetCue: "Read the start line first",
                equipment: ["Driver", "Range balls", "Launch gate"],
                estimatedMinutes: 9
            )
        case "r11":
            GarageDrillFocusDetail(
                purpose: "Launch window",
                setup: ["Long iron", "Pick one downrange window", "Use the same setup every ball"],
                execution: ["Commit to the window", "Strike without steering", "Read start direction before curve"],
                successCriteria: [],
                commonMisses: [],
                resetCue: "Read start direction before curve",
                equipment: ["Long iron", "Range balls", "Downrange window"],
                estimatedMinutes: 9
            )
        case "r12":
            GarageDrillFocusDetail(
                purpose: "Strike before distance",
                setup: ["One scoring iron", "Three carry targets", "Same pre-shot routine each ball"],
                execution: ["Hit one ball to each target", "Keep tempo the same", "Restart the ladder if contact gets sloppy"],
                successCriteria: [],
                commonMisses: [],
                resetCue: "Keep tempo the same",
                equipment: ["Scoring iron", "Range balls", "Three carry targets"],
                estimatedMinutes: 10
            )
        case "r13":
            GarageDrillFocusDetail(
                purpose: "Carry numbers",
                setup: ["Wedges", "Pick three carry numbers", "Track carry, not rollout"],
                execution: ["Hit short, middle, then long", "Change swing length only", "Keep the same rhythm"],
                successCriteria: [],
                commonMisses: [],
                resetCue: "Change swing length only",
                equipment: ["Wedges", "Range balls", "Known carry targets"],
                estimatedMinutes: 10
            )
        case "r14":
            GarageDrillFocusDetail(
                purpose: "Low, stock, high",
                setup: ["One wedge distance", "Choose low, stock, and high windows", "Use the same ball position reference"],
                execution: ["Hit low, stock, then high", "Keep effort the same", "Change the window, not the engine"],
                successCriteria: [],
                commonMisses: [],
                resetCue: "Keep effort the same",
                equipment: ["Wedge", "Range balls", "Single carry target"],
                estimatedMinutes: 10
            )
        case "r15":
            GarageDrillFocusDetail(
                purpose: "Start it in play",
                setup: ["Driver", "Pick a fairway-sized start gate", "Define the gate before swinging"],
                execution: ["Swing only when the target is clear", "Start the ball inside the gate", "Hold the finish for two counts"],
                successCriteria: [],
                commonMisses: [],
                resetCue: "Start the ball inside the gate",
                equipment: ["Driver", "Range balls", "Fairway start gate"],
                estimatedMinutes: 9
            )
        case "r16":
            GarageDrillFocusDetail(
                purpose: "Short swing, solid flight",
                setup: ["Mid iron or scoring iron", "Pick a boring flight window", "Use a shorter backswing and finish"],
                execution: ["Swing from nine to three", "Keep the handle organized", "Lengthen only when flight stays solid"],
                successCriteria: [],
                commonMisses: [],
                resetCue: "Swing from nine to three",
                equipment: ["Mid iron or scoring iron", "Range balls", "Flight window"],
                estimatedMinutes: 8
            )
        case "r17":
            GarageDrillFocusDetail(
                purpose: "Fairway target under pressure",
                setup: ["Wood or hybrid", "Choose three fairway targets", "Start with the easiest target"],
                execution: ["Advance after one balanced shot in the window", "Restart when posture or target discipline breaks", "Keep the swing speed honest"],
                successCriteria: [],
                commonMisses: [],
                resetCue: "Keep the swing speed honest",
                equipment: ["Wood or hybrid", "Range balls", "Three fairway targets"],
                estimatedMinutes: 10
            )
        case "p1":
            GarageDrillFocusDetail(
                purpose: "True roll",
                setup: ["Putter", "Ball line aimed at target", "Start around 5 feet"],
                execution: ["Stroke the ball on the line", "Watch the roll, not the hole", "Keep the finish quiet"],
                successCriteria: [],
                commonMisses: [],
                resetCue: "Watch the roll, not the hole",
                equipment: ["Putter", "Ball with line"],
                estimatedMinutes: 7
            )
        case "p2":
            GarageDrillFocusDetail(
                purpose: "Distance feel",
                setup: ["Multiple balls", "Start around 10 feet", "Use one clear distance corridor"],
                execution: ["Roll the first ball to the starting spot", "Roll each next ball slightly past the last", "Restart if one comes up short or races too far"],
                successCriteria: [],
                commonMisses: [],
                resetCue: "Roll each next ball slightly past the last",
                equipment: ["Putter", "Multiple balls"],
                estimatedMinutes: 8
            )
        case "p3":
            GarageDrillFocusDetail(
                purpose: "Start line",
                setup: ["Two tees just wider than the putter head", "Straight or mostly straight putt", "Start around 4 feet"],
                execution: ["Stroke through the gate", "Let the ball start on line", "Restart if the stroke gets steered"],
                successCriteria: [],
                commonMisses: [],
                resetCue: "Let the ball start on line",
                equipment: ["Putter", "Ball", "Two tees"],
                estimatedMinutes: 7
            )
        case "p4":
            GarageDrillFocusDetail(
                purpose: "Same tempo, different lengths",
                setup: ["Four stations around one hole", "One ball per station", "Choose different distances"],
                execution: ["Putt once from each station", "Change stroke length, not tempo", "Restart if the stroke gets jabby"],
                successCriteria: [],
                commonMisses: [],
                resetCue: "Change stroke length, not tempo",
                equipment: ["Putter", "Balls", "Four tees"],
                estimatedMinutes: 9
            )
        case "p5":
            GarageDrillFocusDetail(
                purpose: "Quiet face",
                setup: ["Short putts", "Lead hand only", "Pick a narrow start line"],
                execution: ["Stroke with the lead hand only", "Keep the face stable", "Add the trail hand when start line holds"],
                successCriteria: [],
                commonMisses: [],
                resetCue: "Keep the face stable",
                equipment: ["Putter", "Ball"],
                estimatedMinutes: 7
            )
        case "p6":
            GarageDrillFocusDetail(
                purpose: "Stop zone",
                setup: ["Three balls", "Stop zone about 2 feet past the hole", "Choose a putt long enough to need touch"],
                execution: ["Roll all three balls to the same zone", "Keep the same finish picture", "Restart if one leaves the zone"],
                successCriteria: [],
                commonMisses: [],
                resetCue: "Keep the same finish picture",
                equipment: ["Putter", "Three balls", "Stop-zone markers optional"],
                estimatedMinutes: 8
            )
        default:
            customDetail(for: PracticeTemplateDrill(
                title: drill.title,
                focusArea: drill.faultType.sensoryDescription,
                targetClub: drill.clubRange.displayName,
                defaultRepCount: drill.defaultRepCount
            ))
        }
    }

    private static func customDetail(for drill: PracticeTemplateDrill) -> GarageDrillFocusDetail {
        let focus = drill.focusArea.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetClub = drill.targetClub.trimmingCharacters(in: .whitespacesAndNewlines)

        return GarageDrillFocusDetail(
            purpose: focus.isEmpty ? "Run the assigned practice task with one clear success standard." : "Work the stated focus area: \(focus).",
            setup: [
                targetClub.isEmpty ? "Choose the exact club or tool before starting." : "Commit to \(targetClub) for the full set.",
                focus.isEmpty ? "Define the success standard before the first attempt." : "Tie each attempt to \(focus.lowercased()).",
                "Reset after any attempt you would not honestly count."
            ],
            execution: [
                "Run the task without changing the goal mid-set.",
                "Count only attempts that meet the standard.",
                "Log the dominant feel or miss before moving on."
            ],
            successCriteria: [
                "Attempt matches the stated focus.",
                "Contact, start line, or pace is honest enough to count.",
                "You can describe what improved or failed."
            ],
            commonMisses: [
                "Rushing just to finish.",
                "Counting unclear attempts as successful.",
                "Changing the goal halfway through the set."
            ],
            resetCue: "Slow down. Make the count mean something.",
            equipment: [
                targetClub.isEmpty ? "Assigned club or tool" : targetClub,
                "Environment-appropriate practice setup"
            ],
            estimatedMinutes: max(5, min(12, Int(ceil(Double(max(drill.defaultRepCount, 1)) * 0.75))))
        )
    }

    private static func customMetadata(
        for drill: PracticeTemplateDrill,
        detail: GarageDrillFocusDetail
    ) -> GarageDrillFocusMetadata {
        let defaultCount = max(drill.defaultRepCount, 0)
        let mode: GarageDrillFocusMode = .process
        let setupLine = cleanLine(detail.setup.first) ?? "Set a safe station before starting."
        let executionCue = cleanLine(detail.execution.first) ?? "Run the task without changing the goal mid-set."
        let targetMetric = defaultCount > 0 ? "\(defaultCount) honest attempts" : "\(detail.estimatedMinutes)-minute block"

        return GarageDrillFocusMetadata(
            mode: mode,
            authorityGoal: defaultCount > 0 ? .reps(count: defaultCount, unit: "honest attempts") : .timed,
            commandCopy: cleanLine(detail.purpose) ?? "Complete the assigned practice task.",
            setupLine: setupLine,
            executionCue: executionCue,
            teachingDetail: nil,
            reviewSummary: nil,
            targetMetric: targetMetric,
            quickTags: ["Clean", "Rushed", "Heavy"],
            diagramKey: nil
        )
    }

    private static func quickTags(for drill: GarageDrill) -> [String] {
        switch drill.libraryCategory {
        case .contact:
            return ["Thin", "Fat", "Clean", "Heavy", "Rushed"]
        case .tempo:
            return ["Fast", "Smooth", "Late", "Balanced"]
        case .putting:
            return ["Pulled", "Pushed", "Good speed", "Short", "Long"]
        case .distanceControl:
            return ["Short", "Long", "Pin high", "Rushed", "Smooth"]
        case .pressure:
            return ["Inside", "Outside", "Balanced", "Tense"]
        case .faceControl:
            return ["Pulled", "Pushed", "Square", "Steered"]
        case .delivery:
            return ["Flipped", "Compressed", "Heavy", "Late"]
        case .rotation:
            return ["Crowded", "Deep turn", "Balanced", "Early lift"]
        }
    }

    private static func cleanLine(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let cleaned = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return cleaned.isEmpty ? nil : cleaned
    }

    private static func recommendedUseCases(
        for drill: GarageDrill,
        metadata: GarageDrillFocusMetadata
    ) -> [String] {
        var useCases = [
            "Use when \(drill.faultType.sensoryDescription.lowercased()) keeps showing up in practice."
        ]

        switch metadata.mode {
        case .process:
            useCases.append("Best for rehearsals, clean contact blocks, and low-friction station work.")
        case .target:
            useCases.append("Best when you want measurable windows, start lines, or carry numbers.")
        case .pressureTest:
            useCases.append("Best late in the session when you want honest consequence and tighter standards.")
        }

        return useCases
    }
}

private extension GarageDrillSessionMode {
    var mapToArray: [GarageDrillSessionMode] { [self] }
}

#if DEBUG
enum GarageDrillAuthorityQAIdentifiers {
    static let timedDefinitionID = UUID(uuidString: "9F9F2E62-6C2C-4D6C-ADE6-41E0F78CC101")!
    static let pressureDefinitionID = UUID(uuidString: "9F9F2E62-6C2C-4D6C-ADE6-41E0F78CC102")!
    static let repsDefinitionID = UUID(uuidString: "9F9F2E62-6C2C-4D6C-ADE6-41E0F78CC103")!
    static let timedTargetDefinitionID = UUID(uuidString: "9F9F2E62-6C2C-4D6C-ADE6-41E0F78CC104")!

    static let timedDrillID = UUID(uuidString: "9F9F2E62-6C2C-4D6C-ADE6-41E0F78CD101")!
    static let pressureDrillID = UUID(uuidString: "9F9F2E62-6C2C-4D6C-ADE6-41E0F78CD102")!
    static let repsDrillID = UUID(uuidString: "9F9F2E62-6C2C-4D6C-ADE6-41E0F78CD103")!
    static let timedTargetDrillID = UUID(uuidString: "9F9F2E62-6C2C-4D6C-ADE6-41E0F78CD104")!

    static func metadata(
        for drill: PracticeTemplateDrill,
        detail: GarageDrillFocusDetail
    ) -> GarageDrillFocusMetadata? {
        switch drill.definitionID {
        case timedDefinitionID:
            return GarageDrillFocusMetadata(
                mode: .process,
                authorityGoal: .timed,
                durationSecondsOverride: 30,
                commandCopy: "Run the timed authority block.",
                setupLine: "Use the QA timed station.",
                executionCue: "Let the timer start before resolving the drill.",
                teachingDetail: nil,
                reviewSummary: nil,
                targetMetric: "30-second QA timer",
                quickTags: [],
                diagramKey: nil
            )
        case timedTargetDefinitionID:
            return GarageDrillFocusMetadata(
                mode: .process,
                authorityGoal: .timed,
                durationSecondsOverride: 2,
                commandCopy: "Run the timed authority target block.",
                setupLine: "Use the QA timed target station.",
                executionCue: "Let the timer reach target before resolving the drill.",
                teachingDetail: nil,
                reviewSummary: nil,
                targetMetric: "2-second QA timer",
                quickTags: [],
                diagramKey: nil
            )
        case pressureDefinitionID:
            return GarageDrillFocusMetadata(
                mode: .pressureTest,
                authorityGoal: .challenge(count: 1, unit: "pressure standard"),
                durationSecondsOverride: 2,
                commandCopy: "Run the QA pressure standard.",
                setupLine: "Use the QA pressure station.",
                executionCue: "Do not mark the standard complete before resolving early.",
                teachingDetail: nil,
                reviewSummary: nil,
                targetMetric: "1 pressure standard",
                quickTags: [],
                diagramKey: nil
            )
        case repsDefinitionID:
            return GarageDrillFocusMetadata(
                mode: .target,
                authorityGoal: .reps(count: 1, unit: "clean rep"),
                durationSecondsOverride: 2,
                commandCopy: "Run the QA reps standard.",
                setupLine: "Use the QA reps station.",
                executionCue: "Resolve early before the clean rep is marked complete.",
                teachingDetail: nil,
                reviewSummary: nil,
                targetMetric: "1 clean rep",
                quickTags: [],
                diagramKey: nil
            )
        default:
            return nil
        }
    }
}
#endif
