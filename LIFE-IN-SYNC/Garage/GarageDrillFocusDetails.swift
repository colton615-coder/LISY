import Foundation

enum GarageDrillFocusMode: String, Hashable {
    case reps
    case time
    case goal
    case challenge
    case checklist

    var controlLabel: String {
        switch self {
        case .reps:
            return "Reps"
        case .time:
            return "Timer"
        case .goal:
            return "Target"
        case .challenge:
            return "Challenge"
        case .checklist:
            return "Checklist"
        }
    }

    var trackerLabel: String {
        switch self {
        case .reps:
            return "Rep Counter"
        case .time:
            return "Time Block"
        case .goal:
            return "Goal Progress"
        case .challenge:
            return "Challenge Tracker"
        case .checklist:
            return "Checklist"
        }
    }
}

struct GarageDrillFocusMetadata: Hashable {
    let mode: GarageDrillFocusMode
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
        "\(max(drill.defaultRepCount, 0)) planned reps"
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
                mode: .challenge,
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
                mode: .time,
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
                mode: .challenge,
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
                mode: .goal,
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
                mode: .goal,
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
                mode: .goal,
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
                mode: .checklist,
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
                mode: .challenge,
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
                mode: .challenge,
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
                mode: .goal,
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
                mode: .challenge,
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
                mode: .checklist,
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
                mode: .challenge,
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
                mode: .reps,
                commandCopy: firstExecution,
                setupLine: firstSetup,
                executionCue: cleanLine(detail.resetCue) ?? firstSuccess,
                teachingDetail: detail.purpose,
                reviewSummary: firstSuccess,
                targetMetric: "\(drill.defaultRepCount) clean reps",
                quickTags: quickTags,
                diagramKey: drill.id
            )
        }
    }

    static func detail(for drill: GarageDrill) -> GarageDrillFocusDetail {
        switch drill.id {
        case "n1":
            GarageDrillFocusDetail(
                purpose: "Train low-point control so the club reaches the ball before the ground. The towel gives immediate strike feedback without needing ball flight.",
                setup: ["Place a towel roughly two inches behind the ball.", "Use a scoring iron and a net-safe ball.", "Start at half speed before building pace."],
                execution: ["Make a controlled swing without touching the towel.", "Hold the finish for one count.", "Count only clean strikes where the towel stays still."],
                successCriteria: ["Ball-first contact.", "Towel remains untouched.", "Balanced finish with no scoop."],
                commonMisses: ["Clipping the towel first.", "Standing up to avoid the towel.", "Flipping the clubhead past the hands."],
                resetCue: "Chest stays down. Handle wins.",
                equipment: ["Towel", "Ball or foam ball", "Scoring iron", "Net"],
                estimatedMinutes: 8
            )
        case "n2":
            GarageDrillFocusDetail(
                purpose: "Teach the hands and clubhead to arrive in the correct order so impact feels compressed instead of scooped.",
                setup: ["Use a wedge.", "Separate the hands on the grip by roughly three inches.", "Begin with waist-to-waist swings at half speed."],
                execution: ["Take the split-hand grip.", "Swing through while the handle leads.", "Hold the finish with the clubhead trailing the hands."],
                successCriteria: ["Handle leads through impact.", "Clubhead does not pass the hands early.", "Contact feels heavy and controlled."],
                commonMisses: ["Trail hand takes over.", "Transition gets rushed.", "Finish collapses after impact."],
                resetCue: "Handle leads. Clubhead stays heavy behind you.",
                equipment: ["Wedge", "Ball or foam ball", "Net"],
                estimatedMinutes: 7
            )
        case "n3":
            GarageDrillFocusDetail(
                purpose: "Keep space through the turn by training hip depth and posture control instead of thrusting toward the ball.",
                setup: ["Stand with the trail hip a few inches from a wall or safe vertical surface.", "Use no ball at first.", "Keep the rehearsal slow and balanced."],
                execution: ["Rehearse the backswing while keeping hip depth.", "Turn through without lunging toward the ball.", "Add a club only after the body pattern holds."],
                successCriteria: ["Posture stays athletic.", "Hips rotate instead of crowding the ball.", "Chest finishes fully turned."],
                commonMisses: ["Trail hip drives toward the ball.", "Chest lifts early.", "Weight falls into the toes."],
                resetCue: "Turn the pockets behind you.",
                equipment: ["Wall or safe vertical reference", "Club optional", "Net area optional"],
                estimatedMinutes: 7
            )
        case "n4":
            GarageDrillFocusDetail(
                purpose: "Train clubface awareness by matching the face to a narrow start window before speed is added.",
                setup: ["Set an alignment stick or visual rail just outside the ball.", "Use a scoring iron.", "Pick a tiny net start window."],
                execution: ["Make smooth swings through the same window.", "Freeze only when the face feels centered.", "Restart the set after a clear face miss."],
                successCriteria: ["Face returns through the chosen window.", "Start line feels predictable.", "Tempo stays smooth."],
                commonMisses: ["Steering the clubface late.", "Changing the window after each miss.", "Adding speed before face control is stable."],
                resetCue: "Small window. Quiet face.",
                equipment: ["Alignment stick or visual rail", "Ball or foam ball", "Scoring iron", "Net"],
                estimatedMinutes: 7
            )
        case "n5":
            GarageDrillFocusDetail(
                purpose: "Expose sway and rushed tempo by narrowing the base so centered rotation and balance become non-negotiable.",
                setup: ["Use a wood or hybrid.", "Set the feet close together.", "Start at roughly sixty percent speed."],
                execution: ["Make a smooth backswing while staying centered.", "Swing through without falling off balance.", "Hold the finish for a full two-count."],
                successCriteria: ["Balanced finish.", "No major sway.", "Rhythm stays smooth from start to finish."],
                commonMisses: ["Over-swinging.", "Falling toward the ball.", "Rushing from the top."],
                resetCue: "Swing inside a phone booth.",
                equipment: ["Wood or hybrid", "Ball or foam ball", "Net"],
                estimatedMinutes: 8
            )
        case "n6":
            GarageDrillFocusDetail(
                purpose: "Calm the transition and sequence the downswing from the ground before the arms fire.",
                setup: ["Use a wedge or short iron.", "Choose a net-safe ball.", "Commit to a clear one-beat pause at the top."],
                execution: ["Make a full backswing and pause.", "Shift pressure forward before the arms unwind.", "Hit soft shots while keeping the pause honest."],
                successCriteria: ["Pause is visible.", "Pressure moves forward before the throw.", "Finish stays balanced."],
                commonMisses: ["Fake pause while still drifting.", "Arms fire first.", "Tempo speeds up after one good rep."],
                resetCue: "Pause. Pressure. Then club.",
                equipment: ["Wedge or short iron", "Ball or foam ball", "Net"],
                estimatedMinutes: 7
            )
        case "n7":
            GarageDrillFocusDetail(
                purpose: "Replace a thrown clubhead with a shallower exit and continued chest rotation through impact.",
                setup: ["Use a wood or hybrid.", "Place a headcover just outside the ball line after impact.", "Start with controlled half-speed swings."],
                execution: ["Brush through impact without clipping the headcover.", "Keep the chest turning.", "Count only reps with a low, clean exit."],
                successCriteria: ["Headcover stays untouched.", "Exit stays low and shallow.", "Chest keeps rotating."],
                commonMisses: ["Throwing the club at the ball.", "Stopping the chest.", "Lifting the handle to avoid the object."],
                resetCue: "Turn through the low window.",
                equipment: ["Wood or hybrid", "Headcover", "Ball or foam ball", "Net"],
                estimatedMinutes: 8
            )
        case "n8":
            GarageDrillFocusDetail(
                purpose: "Stabilize strike location by teaching the trail hand to brush the same spot without excess hit.",
                setup: ["Use a scoring iron.", "Begin with trail-hand-only half swings.", "Pick a brush point just after the ball position."],
                execution: ["Swing with the trail hand only.", "Listen for a crisp brush after the ball.", "Add the lead hand back once the brush point repeats."],
                successCriteria: ["Brush point repeats.", "Contact is crisp.", "The added lead hand does not change the bottom."],
                commonMisses: ["Trail hand slaps at the ball.", "Brush point moves behind the ball.", "Player speeds up before control appears."],
                resetCue: "Brush the same blade of grass.",
                equipment: ["Scoring iron", "Ball or foam ball", "Net"],
                estimatedMinutes: 7
            )
        case "r10":
            GarageDrillFocusDetail(
                purpose: "Separate start-line control from curve so driver face delivery can be read honestly.",
                setup: ["Pick a narrow gate about ten yards in front.", "Use driver.", "Choose the same launch gate for the whole set."],
                execution: ["Hit five shots through the same gate.", "Judge start line before final curve.", "Reset if the target keeps changing."],
                successCriteria: ["Ball starts through the intended gate.", "Finish is balanced.", "Miss is identified by start direction first."],
                commonMisses: ["Reacting only to curve.", "Changing target after each miss.", "Swinging harder to fix direction."],
                resetCue: "Own the first ten yards.",
                equipment: ["Driver", "Range balls", "Downrange start gate"],
                estimatedMinutes: 9
            )
        case "r11":
            GarageDrillFocusDetail(
                purpose: "Train long-iron start-line discipline by sending the ball through a defined window before judging curve.",
                setup: ["Use a long iron.", "Pick a ten-by-ten downrange window.", "Use an alignment reference if available."],
                execution: ["Commit to the same target window.", "Hit the shot and read start direction immediately.", "Only then observe curve."],
                successCriteria: ["Ball starts through or near the window.", "Setup stays consistent.", "Misses are logged honestly."],
                commonMisses: ["Reacting to curve first.", "Steering the club.", "Swinging harder because it is a long iron."],
                resetCue: "Face sends it. Path bends it.",
                equipment: ["Long iron", "Range balls", "Downrange target", "Alignment stick optional"],
                estimatedMinutes: 9
            )
        case "r12":
            GarageDrillFocusDetail(
                purpose: "Connect strike quality to carry control so contact stays stable across a target ladder.",
                setup: ["Choose one scoring iron.", "Pick three carry targets.", "Use the same pre-shot routine for each ball."],
                execution: ["Hit one ball to each target.", "Restart the ladder if contact gets heavy or thin.", "Keep tempo constant across distances."],
                successCriteria: ["Contact stays centered.", "Carry window is repeatable.", "Tempo does not change under pressure."],
                commonMisses: ["Chasing distance with speed.", "Ignoring strike quality.", "Changing target after a poor contact."],
                resetCue: "Strike first. Distance second.",
                equipment: ["Scoring iron", "Range balls", "Three carry targets"],
                estimatedMinutes: 10
            )
        case "r13":
            GarageDrillFocusDetail(
                purpose: "Calibrate wedge carry numbers by changing swing length while rhythm stays stable.",
                setup: ["Use wedges.", "Pick three carry numbers such as fifty, sixty-five, and eighty yards.", "Track carry result, not rollout."],
                execution: ["Hit one ball to the short number.", "Hit one ball to the middle number.", "Hit one ball to the long number.", "Adjust swing length, not tempo."],
                successCriteria: ["Ball lands near the intended carry.", "Rhythm stays consistent.", "Player knows which swing length produced the distance."],
                commonMisses: ["Swinging harder for longer wedges.", "Decelerating on short wedges.", "Changing both speed and length."],
                resetCue: "Same rhythm. Different volume knob.",
                equipment: ["Wedges", "Range balls", "Known yardage targets"],
                estimatedMinutes: 10
            )
        case "r14":
            GarageDrillFocusDetail(
                purpose: "Build flight control by changing launch window while effort and rhythm stay constant.",
                setup: ["Pick one wedge distance.", "Choose low, stock, and high windows.", "Use the same ball position reference for the set."],
                execution: ["Hit low, stock, and high windows in order.", "Keep effort the same.", "Change finish height and face feel deliberately."],
                successCriteria: ["All three windows are distinct.", "Distance remains playable.", "Tempo does not spike."],
                commonMisses: ["Adding effort for the high shot.", "De-lofting the low shot into a dig.", "Losing the target while chasing trajectory."],
                resetCue: "Change the window, not the engine.",
                equipment: ["Wedge", "Range balls", "Single carry target"],
                estimatedMinutes: 10
            )
        case "r15":
            GarageDrillFocusDetail(
                purpose: "Make driver practice measurable by requiring a fairway-sized start gate and a held finish.",
                setup: ["Use driver.", "Pick a fairway-width landing picture.", "Define what counts as inside the gate before swinging."],
                execution: ["Hit only when the target is clear.", "Hold the finish for two counts.", "Reset after any start outside the gate."],
                successCriteria: ["Start line fits the chosen fairway.", "Finish holds in balance.", "Player does not chase speed after a miss."],
                commonMisses: ["Overswinging.", "Changing the fairway picture.", "Ignoring balance because the ball flew far."],
                resetCue: "Fairway first. Speed second.",
                equipment: ["Driver", "Range balls", "Fairway target"],
                estimatedMinutes: 9
            )
        case "r16":
            GarageDrillFocusDetail(
                purpose: "Improve handle structure and flighted contact through a shorter nine-to-three motion.",
                setup: ["Use a mid or scoring iron.", "Pick a boring flight window.", "Start with a shorter backswing and finish."],
                execution: ["Make nine-to-three swings.", "Hold the handle forward through the exit.", "Lengthen only after the flight stays controlled."],
                successCriteria: ["Flight is lower and stable.", "Handle stays organized.", "Contact feels compressed."],
                commonMisses: ["Flipping to help the ball up.", "Making a full swing too soon.", "Stopping rotation after impact."],
                resetCue: "Heavy club. Boring flight.",
                equipment: ["Mid iron or scoring iron", "Range balls", "Target window"],
                estimatedMinutes: 8
            )
        case "r17":
            GarageDrillFocusDetail(
                purpose: "Add target pressure while preserving rotation, posture, and fairway discipline.",
                setup: ["Use a wood or hybrid.", "Choose three fairway targets of increasing difficulty.", "Define restart rules before the ladder starts."],
                execution: ["Start with the easiest fairway target.", "Advance after a balanced finish inside the window.", "Restart if the body stalls or crowds the ball."],
                successCriteria: ["Finish remains athletic.", "Body keeps turning.", "Ball starts inside the current window."],
                commonMisses: ["Adding pressure by swinging harder.", "Standing up through impact.", "Skipping restart rules."],
                resetCue: "Pressure only counts if posture holds.",
                equipment: ["Wood or hybrid", "Range balls", "Three fairway targets"],
                estimatedMinutes: 10
            )
        case "p1":
            GarageDrillFocusDetail(
                purpose: "Train end-over-end roll and face stability by using the ball line as immediate feedback.",
                setup: ["Draw or use a visible line on the ball.", "Start from roughly five feet.", "Pick a straight or mostly straight putt."],
                execution: ["Aim the ball line at the target.", "Stroke the putt while watching the roll.", "Count only stable end-over-end rolls."],
                successCriteria: ["Ball rolls end-over-end.", "Start line is stable.", "Stroke finish is calm."],
                commonMisses: ["Wobbly roll from off-center strike.", "Face twists open or closed.", "Peeking early."],
                resetCue: "Roll the coin, do not slap it.",
                equipment: ["Putter", "Ball with line", "Marker", "Coin or start-line reference optional"],
                estimatedMinutes: 7
            )
        case "p2":
            GarageDrillFocusDetail(
                purpose: "Build lag putting touch by requiring each ball to finish slightly past the previous one.",
                setup: ["Use multiple balls.", "Start around ten feet and work toward thirty.", "Choose a consistent target corridor."],
                execution: ["Putt the first ball to the starting distance.", "Roll each next ball one foot past the previous ball.", "Restart if a ball finishes short or races too far."],
                successCriteria: ["Each ball finishes slightly farther.", "Distance gaps stay controlled.", "Stroke rhythm remains smooth."],
                commonMisses: ["First ball hit too far.", "Decelerating to guide the ball.", "Obsessing over line instead of pace."],
                resetCue: "Paint the distance with stroke length.",
                equipment: ["Putter", "Multiple balls", "Putting green", "Optional tees or markers"],
                estimatedMinutes: 8
            )
        case "p3":
            GarageDrillFocusDetail(
                purpose: "Tighten putting start line by forcing the ball and putter through a small gate.",
                setup: ["Set two tees just wider than the putter head.", "Start from four feet.", "Choose a straight putt or clear start line."],
                execution: ["Stroke the putt through the gate.", "Count only clean starts that avoid both tees.", "Reset if the stroke gets steered."],
                successCriteria: ["Putter moves through the gate.", "Ball starts online.", "Face stays quiet."],
                commonMisses: ["Clipping a tee.", "Guiding the face late.", "Short jab under pressure."],
                resetCue: "Gate first. Hole second.",
                equipment: ["Putter", "Ball", "Two tees", "Putting green"],
                estimatedMinutes: 7
            )
        case "p4":
            GarageDrillFocusDetail(
                purpose: "Blend pace control and changing reads while preserving one repeatable stroke tempo.",
                setup: ["Place tees at four distances around one hole.", "Use one ball from each station.", "Choose distances that require different stroke lengths."],
                execution: ["Putt one ball from each spot.", "Keep the same rhythm as distance changes.", "Restart if pace jumps or the stroke gets jabby."],
                successCriteria: ["Pace finishes near the hole.", "Tempo stays consistent.", "Distance changes come from stroke length."],
                commonMisses: ["Rushing longer putts.", "Babying shorter putts.", "Letting read complexity change rhythm."],
                resetCue: "Same tempo around the clock.",
                equipment: ["Putter", "Balls", "Four tees", "Putting green"],
                estimatedMinutes: 9
            )
        case "p5":
            GarageDrillFocusDetail(
                purpose: "Let the lead hand organize the putter face so the stroke starts online without extra hit.",
                setup: ["Use short putts.", "Remove the trail hand from the club.", "Pick a narrow start line."],
                execution: ["Hit short putts with the lead hand only.", "Keep the face square through the hitting zone.", "Add the trail hand back when start line holds."],
                successCriteria: ["Face stays square.", "Start line holds.", "Trail hand returns without adding hit."],
                commonMisses: ["Lead wrist breaks down.", "Stroke gets jabby.", "Trail hand dominates when added back."],
                resetCue: "Lead hand owns the face.",
                equipment: ["Putter", "Ball", "Putting green"],
                estimatedMinutes: 7
            )
        case "p6":
            GarageDrillFocusDetail(
                purpose: "Improve pace discipline by landing three balls in the same stop zone without one racing or dying early.",
                setup: ["Pick a stop zone two feet past the hole.", "Use three balls.", "Choose a putt long enough to require pace control."],
                execution: ["Roll all three balls toward the stop zone.", "Restart if any ball finishes outside the zone.", "Keep the stroke length matched to the same finish picture."],
                successCriteria: ["All three balls finish in the zone.", "No ball races well past.", "Stroke length feels repeatable."],
                commonMisses: ["First putt hit defensively.", "Third putt over-corrected.", "Changing target after one miss."],
                resetCue: "Brake at the same finish line.",
                equipment: ["Putter", "Three balls", "Putting green", "Stop-zone markers optional"],
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
        let mode: GarageDrillFocusMode = defaultCount > 0 ? .reps : .time
        let setupLine = cleanLine(detail.setup.first) ?? "Set a safe station before starting."
        let executionCue = cleanLine(detail.execution.first) ?? "Run the task without changing the goal mid-set."
        let targetMetric = defaultCount > 0 ? "\(defaultCount) honest attempts" : "\(detail.estimatedMinutes)-minute block"

        return GarageDrillFocusMetadata(
            mode: mode,
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
}
