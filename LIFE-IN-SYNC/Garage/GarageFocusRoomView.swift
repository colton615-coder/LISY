import Combine
import Foundation
import SwiftUI

struct GarageFocusDrillPresentation {
    let id: UUID
    let content: GarageDrillFocusContent
    let isCompleted: Bool
}

struct GarageFocusCompletionPayload {
    let elapsedSeconds: Int
    let trackerValue: Int
    let mode: GarageDrillFocusMode
    let goal: GarageDrillGoal
    let goalMet: Bool
}

struct GarageFocusRoomView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isRoutineVisible = false
    @State private var activeDrillID: UUID?
    @State private var elapsedSeconds = 0
    @State private var trackerValue = 0
    @State private var selectedQuickTags: Set<String> = []

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    let sessionTitle: String
    let environment: PracticeEnvironment
    let drillPositionText: String
    let completedCount: Int
    let totalCount: Int
    let drill: GarageFocusDrillPresentation?
    let railItems: [GarageFocusDrillRailItem]
    let isDetailExpanded: Bool
    let noteTitle: String
    let primaryCtaTitle: String
    let onToggleDetail: () -> Void
    let onSelectRailDrill: (Int) -> Void
    let onNote: () -> Void
    let onPrimary: (GarageFocusCompletionPayload) -> Void
    let onExitEmptyRoutine: () -> Void

    var body: some View {
        if let drill {
            ZStack {
                FocusRoomBackground()

                VStack(spacing: 0) {
                    FocusRoomHeader(
                        drillTitle: drill.content.title,
                        drillPositionText: drillPositionText,
                        completedCount: completedCount,
                        totalCount: totalCount,
                        isRoutineVisible: isRoutineVisible,
                        onBack: { dismiss() },
                        onToggleRoutine: toggleRoutineVisibility
                    )

                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            GarageFocusHeroContainer(
                                content: drill.content,
                                elapsedSeconds: elapsedSeconds,
                                trackerValue: trackerValue,
                                completionState: completionState(for: drill),
                                selectedQuickTags: selectedQuickTags,
                                onAdvance: recordGoalProgress,
                                onSubtract: subtractGoalProgress,
                                onReset: resetGoalProgress,
                                onToggleQuickTag: toggleQuickTag
                            )

                            if drill.content.hasTeachingDetails || drill.content.watchFor?.isEmpty == false {
                                FocusRoomTeachingDetailsCard(
                                    isExpanded: isDetailExpanded,
                                    setupLine: drill.content.setupLine,
                                    executionCue: drill.content.executionCue,
                                    teachingDetail: drill.content.teachingDetail,
                                    reviewSummary: drill.content.reviewSummary,
                                    watchFor: drill.content.watchFor,
                                    onToggle: onToggleDetail
                                )
                            }

                            if isRoutineVisible {
                                GarageFocusDrillStackRail(
                                    items: railItems,
                                    onSelectDrill: onSelectRailDrill
                                )
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .padding(.horizontal, 22)
                        .padding(.top, 10)
                        .padding(.bottom, GarageFocusRoomLayout.contentBottomInset)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .tint(FocusRoomPalette.green)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                let state = completionState(for: drill)
                FocusRoomBottomActions(
                    noteTitle: noteTitle,
                    primaryTitle: state.primaryTitle(goal: drill.content.goal, fallback: primaryCtaTitle),
                    statusText: statusText(for: drill.content.goal, state: state),
                    isNextEnabled: state.canConfirm,
                    onNote: onNote,
                    onNext: {
                        onPrimary(
                            GarageFocusCompletionPayload(
                                elapsedSeconds: elapsedSeconds,
                                trackerValue: trackerValue,
                                mode: drill.content.mode,
                                goal: drill.content.goal,
                                goalMet: isGoalMet(drill.content.goal)
                            )
                        )
                    }
                )
            }
            .onAppear {
                resetStateIfNeeded(for: drill.id)
            }
            .onChange(of: drill.id) { _, newValue in
                resetStateIfNeeded(for: newValue)
            }
            .onReceive(timer) { _ in
                guard drill.isCompleted == false else {
                    return
                }

                elapsedSeconds += 1
            }
        } else {
            GarageProScaffold(bottomPadding: 40) {
                GarageProCard(isActive: true) {
                    Text("No drills in this routine")
                        .font(.system(.title3, design: .rounded).weight(.black))
                        .foregroundStyle(GarageProTheme.textPrimary)

                    Text("Return to Garage and choose a routine with at least one drill.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(GarageProTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    GarageProPrimaryButton(
                        title: GarageFocusRoomCopy.focusRoomBackCta,
                        systemImage: "chevron.left",
                        action: onExitEmptyRoutine
                    )
                }
            }
        }
    }
}


private enum GarageFocusRoomLayout {
    static let contentBottomInset: CGFloat = 246
}

private enum FocusRoomPalette {
    static let background = Color(red: 0.012, green: 0.035, blue: 0.026)
    static let backgroundLift = Color(red: 0.025, green: 0.105, blue: 0.07)
    static let panel = Color(red: 0.025, green: 0.082, blue: 0.058)
    static let green = Color(red: 0.23, green: 0.96, blue: 0.49)
    static let greenSoft = Color(red: 0.47, green: 0.91, blue: 0.59)
    static let yellow = Color(red: 1.0, green: 0.78, blue: 0.22)
    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.68)
    static let border = Color(red: 0.23, green: 0.96, blue: 0.49).opacity(0.18)
}

private extension GarageFocusRoomView {
    func resetStateIfNeeded(for drillID: UUID) {
        guard activeDrillID != drillID else {
            return
        }

        activeDrillID = drillID
        elapsedSeconds = 0
        trackerValue = 0
        selectedQuickTags = []
        isRoutineVisible = false
    }

    func toggleRoutineVisibility() {
        garageTriggerSelection()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isRoutineVisible.toggle()
        }
    }

    func recordGoalProgress() {
        garageTriggerSelection()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
            trackerValue += 1
        }
    }

    func subtractGoalProgress() {
        garageTriggerSelection()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
            trackerValue = max(trackerValue - 1, 0)
        }
    }

    func resetGoalProgress() {
        garageTriggerSelection()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
            trackerValue = 0
        }
    }

    func toggleQuickTag(_ tag: String) {
        garageTriggerSelection()
        if selectedQuickTags.contains(tag) {
            selectedQuickTags.remove(tag)
        } else {
            selectedQuickTags.insert(tag)
        }
    }

    func completionState(for drill: GarageFocusDrillPresentation) -> GarageFocusCompletionState {
        if drill.isCompleted {
            return .completed
        }

        if isGoalMet(drill.content.goal) {
            return .ready
        }

        if hasStarted(drill.content.goal) {
            return .inProgress
        }

        return .notStarted
    }

    func isGoalMet(_ goal: GarageDrillGoal) -> Bool {
        switch goal {
        case .timed(let durationSeconds):
            return elapsedSeconds >= max(durationSeconds, 1)
        case .repTarget(let count, _), .streak(let count, _):
            return trackerValue >= max(count, 1)
        case .timeTrial(let targetCount, _):
            return trackerValue >= max(targetCount, 1)
        case .ladder(let steps):
            return trackerValue >= max(steps.count, 1)
        case .checklist(let items):
            return trackerValue >= max(items.count, 1)
        case .manual:
            return trackerValue > 0
        }
    }

    func hasStarted(_ goal: GarageDrillGoal) -> Bool {
        switch goal {
        case .timed:
            return elapsedSeconds > 0
        case .repTarget, .streak, .timeTrial, .ladder, .checklist, .manual:
            return trackerValue > 0
        }
    }

    func statusText(for goal: GarageDrillGoal, state: GarageFocusCompletionState) -> String {
        if state == .completed {
            return "Confirmed"
        }

        if state == .ready {
            return "Ready when the drill is complete"
        }

        switch goal {
        case .timed(let durationSeconds):
            return "Work through \(formattedTime(durationSeconds))"
        case .repTarget(let count, _), .streak(let count, _):
            return "Log \(count) clean reps"
        case .timeTrial(let targetCount, _):
            return "Record \(targetCount) clean attempts"
        case .ladder(let steps):
            return "Complete \(steps.count) ladder steps"
        case .checklist(let items):
            return "Complete \(items.count) checklist items"
        case .manual:
            return "Mark the goal complete"
        }
    }
}

private enum GarageFocusCompletionState: Hashable {
    case notStarted
    case inProgress
    case ready
    case completed

    var label: String {
        switch self {
        case .notStarted:
            return "Not started"
        case .inProgress:
            return "In progress"
        case .ready:
            return "Ready to complete"
        case .completed:
            return "Completed"
        }
    }

    var canConfirm: Bool {
        switch self {
        case .ready, .completed:
            return true
        case .notStarted, .inProgress:
            return false
        }
    }

    var bottomStatusText: String {
        switch self {
        case .notStarted:
            return "Timer starts automatically"
        case .inProgress:
            return "Keep going"
        case .ready:
            return "Ready when the drill is complete"
        case .completed:
            return "Confirmed"
        }
    }

    func primaryTitle(goal: GarageDrillGoal, fallback: String) -> String {
        guard fallback != GarageFocusRoomCopy.focusRoomEnterReviewCta else {
            return fallback
        }

        switch goal {
        case .timed:
            return "Confirm Time"
        case .repTarget:
            return "Confirm Reps"
        case .streak, .timeTrial:
            return "Confirm Challenge"
        case .ladder, .manual:
            return "Confirm Goal"
        case .checklist:
            return "Confirm Checklist"
        }
    }
}

private struct FocusRoomBackground: View {
    var body: some View {
        ZStack {
            FocusRoomPalette.background
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    FocusRoomPalette.backgroundLift.opacity(0.88),
                    FocusRoomPalette.background,
                    ModuleTheme.garageCanvas.opacity(0.72)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }
}

private struct FocusRoomHeader: View {
    let drillTitle: String
    let drillPositionText: String
    let completedCount: Int
    let totalCount: Int
    let isRoutineVisible: Bool
    let onBack: () -> Void
    let onToggleRoutine: () -> Void

    var body: some View {
        ZStack {
            HStack {
                Button {
                    garageTriggerSelection()
                    onBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(FocusRoomPalette.primaryText)
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    onToggleRoutine()
                } label: {
                    Image(systemName: isRoutineVisible ? "list.bullet.rectangle.fill" : "list.bullet.rectangle")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(isRoutineVisible ? FocusRoomPalette.green : FocusRoomPalette.secondaryText)
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 3) {
                Text(drillTitle)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(FocusRoomPalette.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                HStack(spacing: 8) {
                    Text(drillPositionText)
                    Text("\(completedCount)/\(totalCount) complete")
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(FocusRoomPalette.secondaryText)
            }
            .padding(.horizontal, 58)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
}

private struct GarageFocusHeroContainer: View {
    let content: GarageDrillFocusContent
    let elapsedSeconds: Int
    let trackerValue: Int
    let completionState: GarageFocusCompletionState
    let selectedQuickTags: Set<String>
    let onAdvance: () -> Void
    let onSubtract: () -> Void
    let onReset: () -> Void
    let onToggleQuickTag: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    FocusRoomModeBadge(mode: content.mode, state: completionState)

                    Text(content.title)
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(FocusRoomPalette.primaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(content.targetMetric.garageFocusRoomSentenceTrimmed)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .textCase(.uppercase)
                        .tracking(1.2)
                        .foregroundStyle(FocusRoomPalette.green)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 10)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(completionState.label)
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .textCase(.uppercase)
                        .tracking(1)
                        .foregroundStyle(completionState == .ready || completionState == .completed ? FocusRoomPalette.green : FocusRoomPalette.yellow)
                        .multilineTextAlignment(.trailing)

                    Text(progressText)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(FocusRoomPalette.secondaryText)
                        .multilineTextAlignment(.trailing)
                }
            }

            FocusRoomInstructionList(instructions: instructionLines)

            modeBody

            if content.quickTags.isEmpty == false {
                FocusRoomQuickTagStrip(
                    tags: content.quickTags,
                    selectedTags: selectedQuickTags,
                    onToggle: onToggleQuickTag
                )
            }

            FocusRoomStopwatchPanel(
                elapsedSeconds: elapsedSeconds,
                personalBestText: stopwatchCaption
            )
        }
        .padding(16)
        .background(FocusRoomPalette.panel.opacity(0.52), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(FocusRoomPalette.border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.32), radius: 20, x: 0, y: 14)
    }

    private var instructionLines: [String] {
        [
            content.setupLine,
            content.executionCue,
            content.finishRule
        ]
        .map(\.garageFocusRoomSentenceTrimmed)
        .filter { $0.isEmpty == false }
    }

    @ViewBuilder
    private var modeBody: some View {
        switch content.mode {
        case .reps:
            RepDrillHero(
                goal: content.goal,
                trackerValue: trackerValue,
                onAdvance: onAdvance,
                onSubtract: onSubtract
            )
        case .time:
            TimeDrillHero(
                goal: content.goal,
                elapsedSeconds: elapsedSeconds,
                isReady: completionState == .ready || completionState == .completed
            )
        case .goal:
            GoalDrillHero(
                goal: content.goal,
                trackerValue: trackerValue,
                onAdvance: onAdvance,
                onReset: onReset
            )
        case .challenge:
            ChallengeDrillHero(
                goal: content.goal,
                elapsedSeconds: elapsedSeconds,
                trackerValue: trackerValue,
                onAdvance: onAdvance,
                onReset: onReset
            )
        case .checklist:
            ChecklistDrillHero(
                goal: content.goal,
                trackerValue: trackerValue,
                onAdvance: onAdvance,
                onReset: onReset
            )
        }
    }

    private var progressText: String {
        switch content.goal {
        case .timed(let durationSeconds):
            return "\(formattedTime(elapsedSeconds)) / \(formattedTime(durationSeconds))"
        case .repTarget(let count, _), .streak(let count, _):
            return "\(min(trackerValue, count)) / \(count)"
        case .timeTrial(let targetCount, _):
            return "\(min(trackerValue, targetCount)) / \(targetCount)"
        case .ladder(let steps):
            return "\(min(trackerValue, steps.count)) / \(steps.count)"
        case .checklist(let items):
            return "\(min(trackerValue, items.count)) / \(items.count)"
        case .manual(let label):
            return trackerValue > 0 ? "Ready" : label
        }
    }

    private var stopwatchCaption: String {
        switch content.mode {
        case .time:
            return "Time goal is active"
        case .reps, .goal, .challenge, .checklist:
            return "Session clock running"
        }
    }
}

private struct FocusRoomInstructionList: View {
    let instructions: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(instructions.prefix(3).enumerated()), id: \.offset) { index, instruction in
                FocusRoomInstructionRow(index: index + 1, instruction: instruction)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}

private struct FocusRoomInstructionRow: View {
    let index: Int
    let instruction: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(index)")
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .foregroundStyle(FocusRoomPalette.yellow)
                .frame(width: 22, alignment: .leading)

            Text(instruction)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(FocusRoomPalette.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct FocusRoomStopwatchPanel: View {
    let elapsedSeconds: Int
    let personalBestText: String

    var body: some View {
        VStack(spacing: 8) {
            Text("Elapsed Time")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .textCase(.uppercase)
                .tracking(1.8)
                .foregroundStyle(FocusRoomPalette.secondaryText)

            Text(formattedTime(elapsedSeconds))
                .font(.system(size: 46, weight: .black, design: .monospaced))
                .foregroundStyle(FocusRoomPalette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(personalBestText)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(FocusRoomPalette.yellow)
                .lineLimit(1)
                .minimumScaleFactor(0.74)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(FocusRoomPalette.border, lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Elapsed time \(formattedTime(elapsedSeconds)). \(personalBestText).")
    }
}

private struct FocusRoomModeBadge: View {
    let mode: GarageDrillFocusMode
    let state: GarageFocusCompletionState

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(state == .ready || state == .completed ? FocusRoomPalette.green : FocusRoomPalette.yellow)
                .frame(width: 7, height: 7)

            Text(mode.controlLabel)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .textCase(.uppercase)
                .tracking(1.4)
                .foregroundStyle(FocusRoomPalette.primaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.2), in: Capsule())
        .overlay(
            Capsule()
                .stroke(FocusRoomPalette.border, lineWidth: 1)
        )
    }
}

private struct FocusRoomCommandSummary: View {
    let setupLine: String
    let executionCue: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            FocusRoomInlineCommand(label: "Setup", text: setupLine, systemImage: "mappin.and.ellipse")
            FocusRoomInlineCommand(label: "Cue", text: executionCue, systemImage: "bolt.fill")
        }
        .padding(12)
        .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct FocusRoomInlineCommand: View {
    let label: String
    let text: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(FocusRoomPalette.green)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(FocusRoomPalette.secondaryText)

                Text(text.garageFocusRoomSentenceTrimmed)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(FocusRoomPalette.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct RepDrillHero: View {
    let goal: GarageDrillGoal
    let trackerValue: Int
    let onAdvance: () -> Void
    let onSubtract: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            FocusRoomHeroMetricRow(
                leadingValue: "\(min(trackerValue, targetCount))",
                leadingLabel: "Clean reps",
                trailingValue: "\(targetCount)",
                trailingLabel: "Target"
            )

            HStack(spacing: 10) {
                FocusRoomActionButton(title: "Subtract", systemImage: "minus.circle.fill", isProminent: false, action: onSubtract)
                    .disabled(trackerValue <= 0)
                    .opacity(trackerValue <= 0 ? 0.48 : 1)

                FocusRoomActionButton(title: "Add Clean Rep", systemImage: "plus.circle.fill", isProminent: true, action: onAdvance)
            }
        }
    }

    private var targetCount: Int {
        switch goal {
        case .repTarget(let count, _):
            return max(count, 1)
        default:
            return 1
        }
    }
}

private struct TimeDrillHero: View {
    let goal: GarageDrillGoal
    let elapsedSeconds: Int
    let isReady: Bool

    var body: some View {
        FocusRoomTimerHeroPanel(
            elapsedSeconds: elapsedSeconds,
            progress: progress,
            isCompleted: isReady,
            statusText: isReady ? "Time target reached" : "Timer running"
        )
    }

    private var durationSeconds: Int {
        switch goal {
        case .timed(let durationSeconds):
            return max(durationSeconds, 1)
        default:
            return 1
        }
    }

    private var progress: Double {
        min(max(Double(elapsedSeconds) / Double(durationSeconds), 0), 1)
    }
}

private struct GoalDrillHero: View {
    let goal: GarageDrillGoal
    let trackerValue: Int
    let onAdvance: () -> Void
    let onReset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch goal {
            case .ladder(let steps):
                FocusRoomStepTracker(
                    currentIndex: trackerValue,
                    steps: steps,
                    completedLabel: "Goal complete",
                    buttonTitle: "Step Done",
                    onAdvance: onAdvance
                )
            case .manual(let label):
                FocusRoomManualTracker(
                    isComplete: trackerValue > 0,
                    label: label,
                    onAdvance: onAdvance
                )
            default:
                FocusRoomTrackerStrip(
                    goal: goal,
                    mode: .goal,
                    elapsedSeconds: 0,
                    trackerValue: trackerValue,
                    onAdvance: onAdvance,
                    onReset: onReset
                )
            }

            FocusRoomActionButton(title: "Reset Goal", systemImage: "arrow.counterclockwise", isProminent: false, action: onReset)
                .opacity(trackerValue > 0 ? 1 : 0.52)
        }
    }
}

private struct ChallengeDrillHero: View {
    let goal: GarageDrillGoal
    let elapsedSeconds: Int
    let trackerValue: Int
    let onAdvance: () -> Void
    let onReset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch goal {
            case .streak(let count, let unit):
                FocusRoomStreakTracker(
                    count: trackerValue,
                    target: count,
                    unit: unit,
                    onAdvance: onAdvance,
                    onReset: onReset
                )
            case .timeTrial(let targetCount, let unit):
                HStack(alignment: .center, spacing: 12) {
                    FocusRoomTimerMetric(value: formattedTime(elapsedSeconds), label: "Elapsed")
                    FocusRoomCountingButton(count: trackerValue, title: unit, onAdvance: onAdvance)
                    FocusRoomTimerMetric(value: "\(targetCount)", label: "Target")
                }

                FocusRoomActionButton(title: "Reset Attempt", systemImage: "arrow.counterclockwise", isProminent: false, action: onReset)
            case .ladder(let steps):
                FocusRoomStepTracker(
                    currentIndex: trackerValue,
                    steps: steps,
                    completedLabel: "Challenge complete",
                    buttonTitle: "Advance",
                    onAdvance: onAdvance
                )

                FocusRoomActionButton(title: "Miss / Restart", systemImage: "arrow.counterclockwise", isProminent: false, action: onReset)
            default:
                FocusRoomTrackerStrip(
                    goal: goal,
                    mode: .challenge,
                    elapsedSeconds: elapsedSeconds,
                    trackerValue: trackerValue,
                    onAdvance: onAdvance,
                    onReset: onReset
                )
            }
        }
    }
}

private struct ChecklistDrillHero: View {
    let goal: GarageDrillGoal
    let trackerValue: Int
    let onAdvance: () -> Void
    let onReset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if case .checklist(let items) = goal {
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        FocusRoomChecklistRow(
                            index: index,
                            text: item,
                            isChecked: index < trackerValue,
                            isNext: index == trackerValue,
                            onTap: {
                                guard index == trackerValue else {
                                    return
                                }

                                onAdvance()
                            }
                        )
                    }
                }
            } else {
                FocusRoomManualTracker(
                    isComplete: trackerValue > 0,
                    label: "Complete the required checklist.",
                    onAdvance: onAdvance
                )
            }

            FocusRoomActionButton(title: "Reset Checklist", systemImage: "arrow.counterclockwise", isProminent: false, action: onReset)
                .opacity(trackerValue > 0 ? 1 : 0.52)
        }
    }
}

private struct FocusRoomChecklistRow: View {
    let index: Int
    let text: String
    let isChecked: Bool
    let isNext: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(isChecked ? FocusRoomPalette.green : isNext ? FocusRoomPalette.yellow : FocusRoomPalette.secondaryText)
                    .frame(width: 24, height: 24)

                Text(text.garageFocusRoomSentenceTrimmed)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(isChecked || isNext ? FocusRoomPalette.primaryText : FocusRoomPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .padding(12)
            .background(isNext ? FocusRoomPalette.green.opacity(0.1) : Color.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isNext ? FocusRoomPalette.green.opacity(0.24) : FocusRoomPalette.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isNext == false)
    }
}

private struct FocusRoomHeroMetricRow: View {
    let leadingValue: String
    let leadingLabel: String
    let trailingValue: String
    let trailingLabel: String

    var body: some View {
        HStack(spacing: 12) {
            FocusRoomTimerMetric(value: leadingValue, label: leadingLabel)
            FocusRoomTimerMetric(value: trailingValue, label: trailingLabel)
        }
        .padding(12)
        .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct FocusRoomQuickTagStrip: View {
    let tags: [String]
    let selectedTags: Set<String>
    let onToggle: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Quick Tags")
                .font(.system(size: 10, weight: .black, design: .rounded))
                .textCase(.uppercase)
                .tracking(1.4)
                .foregroundStyle(FocusRoomPalette.secondaryText)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        Button {
                            onToggle(tag)
                        } label: {
                            Text(tag)
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundStyle(selectedTags.contains(tag) ? FocusRoomPalette.background : FocusRoomPalette.primaryText)
                                .lineLimit(1)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 8)
                                .background(selectedTags.contains(tag) ? FocusRoomPalette.green : Color.black.opacity(0.2), in: Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(selectedTags.contains(tag) ? Color.white.opacity(0.18) : FocusRoomPalette.border, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct FocusRoomTimerHeroPanel: View {
    let elapsedSeconds: Int
    let progress: Double
    let isCompleted: Bool
    let statusText: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(FocusRoomPalette.panel.opacity(0.42))

            LinearGradient(
                colors: [
                    FocusRoomPalette.green.opacity(0.14),
                    Color.black.opacity(0.08),
                    Color.black.opacity(0.24)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 14) {
                FocusRoomCircularTimer(
                    elapsedSeconds: elapsedSeconds,
                    progress: progress,
                    isCompleted: isCompleted
                )
                .frame(width: 188, height: 188)

                HStack(spacing: 8) {
                    Circle()
                        .fill(isCompleted ? FocusRoomPalette.green : FocusRoomPalette.yellow)
                        .frame(width: 7, height: 7)
                        .shadow(color: (isCompleted ? FocusRoomPalette.green : FocusRoomPalette.yellow).opacity(0.4), radius: 8)

                    Text(statusText)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .textCase(.uppercase)
                        .tracking(1.2)
                        .foregroundStyle(FocusRoomPalette.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.74)
                }
            }
            .padding(.vertical, 18)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 250)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(FocusRoomPalette.border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.32), radius: 20, x: 0, y: 14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Elapsed time \(formattedTime(elapsedSeconds)). \(statusText).")
    }
}

private struct FocusRoomCircularTimer: View {
    let elapsedSeconds: Int
    let progress: Double
    let isCompleted: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            FocusRoomPalette.green.opacity(0.12),
                            FocusRoomPalette.panel.opacity(0.7),
                            Color.black.opacity(0.4)
                        ],
                        center: .center,
                        startRadius: 8,
                        endRadius: 102
                    )
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.4), radius: 18, x: 0, y: 12)

            Circle()
                .stroke(FocusRoomPalette.green.opacity(0.13), lineWidth: 13)

            Circle()
                .trim(from: 0, to: max(progress, 0.035))
                .stroke(
                    timerStroke,
                    style: StrokeStyle(lineWidth: 13, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: FocusRoomPalette.green.opacity(isCompleted ? 0.38 : 0.22), radius: 12)
                .animation(.spring(response: 0.35, dampingFraction: 0.82), value: progress)

            Circle()
                .stroke(Color.black.opacity(0.35), lineWidth: 1)
                .padding(18)

            VStack(spacing: 7) {
                Text("Elapsed")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .textCase(.uppercase)
                    .tracking(1.6)
                    .foregroundStyle(FocusRoomPalette.secondaryText)

                Text(formattedTime(elapsedSeconds))
                    .font(.system(size: 42, weight: .black, design: .monospaced))
                    .foregroundStyle(FocusRoomPalette.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)

                Text(isCompleted ? "Done" : "In session")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(isCompleted ? FocusRoomPalette.green : FocusRoomPalette.yellow)
                    .lineLimit(1)
            }
            .padding(.horizontal, 18)
        }
    }

    private var timerStroke: AngularGradient {
        AngularGradient(
            colors: [
                FocusRoomPalette.green,
                FocusRoomPalette.greenSoft,
                isCompleted ? FocusRoomPalette.green : FocusRoomPalette.yellow,
                FocusRoomPalette.green
            ],
            center: .center
        )
    }
}

private func formattedTime(_ value: Int) -> String {
    let clampedValue = max(value, 0)
    let minutes = clampedValue / 60
    let seconds = clampedValue % 60
    return "\(minutes):\(String(format: "%02d", seconds))"
}

private struct FocusRoomSectionLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .black, design: .rounded))
            .textCase(.uppercase)
            .tracking(1.7)
            .foregroundStyle(FocusRoomPalette.green)
    }
}

private struct FocusRoomTrackerStrip: View {
    let goal: GarageDrillGoal
    let mode: GarageDrillFocusMode
    let elapsedSeconds: Int
    let trackerValue: Int
    let onAdvance: () -> Void
    let onReset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FocusRoomSectionLabel(title: mode.trackerLabel)

            switch goal {
            case .timed(let durationSeconds):
                HStack(alignment: .center, spacing: 12) {
                    FocusRoomTimerMetric(value: formattedTime(elapsedSeconds), label: "Elapsed")
                    FocusRoomTimerMetric(value: formattedTime(max(durationSeconds - elapsedSeconds, 0)), label: "Remaining")
                    FocusRoomTimerMetric(value: formattedTime(durationSeconds), label: "Allotted")
                }
            case .repTarget(let count, let unit):
                FocusRoomCountingTracker(
                    count: trackerValue,
                    target: count,
                    actionTitle: "Clean",
                    unit: unit,
                    onAdvance: onAdvance
                )
            case .streak(let count, let unit):
                FocusRoomStreakTracker(
                    count: trackerValue,
                    target: count,
                    unit: unit,
                    onAdvance: onAdvance,
                    onReset: onReset
                )
            case .timeTrial(let targetCount, let unit):
                HStack(alignment: .center, spacing: 12) {
                    FocusRoomTimerMetric(value: formattedTime(elapsedSeconds), label: "Elapsed")
                    FocusRoomCountingButton(count: trackerValue, title: unit, onAdvance: onAdvance)
                    FocusRoomTimerMetric(value: "\(targetCount)", label: "Target")
                }
            case .ladder(let steps):
                FocusRoomStepTracker(
                    currentIndex: trackerValue,
                    steps: steps,
                    completedLabel: "Ladder complete",
                    buttonTitle: "Step Done",
                    onAdvance: onAdvance
                )
            case .checklist(let items):
                FocusRoomStepTracker(
                    currentIndex: trackerValue,
                    steps: items,
                    completedLabel: "Checklist complete",
                    buttonTitle: "Done",
                    onAdvance: onAdvance
                )
            case .manual(let label):
                FocusRoomManualTracker(
                    isComplete: trackerValue > 0,
                    label: label,
                    onAdvance: onAdvance
                )
            }
        }
        .padding(12)
        .background(FocusRoomPalette.panel.opacity(0.78), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(FocusRoomPalette.border, lineWidth: 1)
        )
    }

    private func formattedTime(_ value: Int) -> String {
        let clampedValue = max(value, 0)
        let minutes = clampedValue / 60
        let seconds = clampedValue % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
}

private struct FocusRoomCountingTracker: View {
    let count: Int
    let target: Int
    let actionTitle: String
    let unit: String
    let onAdvance: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            FocusRoomTimerMetric(value: "\(count)", label: unit)
            FocusRoomCountingButton(count: count, title: actionTitle, onAdvance: onAdvance)
            FocusRoomTimerMetric(value: "\(target)", label: "Target")
        }
    }
}

private struct FocusRoomStreakTracker: View {
    let count: Int
    let target: Int
    let unit: String
    let onAdvance: () -> Void
    let onReset: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                FocusRoomTimerMetric(value: "\(count)", label: "Current Streak")
                FocusRoomTimerMetric(value: "\(target)", label: "Target Streak")
            }

            HStack(spacing: 10) {
                FocusRoomActionButton(title: unit, systemImage: "plus.circle.fill", isProminent: true, action: onAdvance)
                FocusRoomActionButton(title: "Miss", systemImage: "arrow.counterclockwise", isProminent: false, action: onReset)
            }
        }
    }
}

private struct FocusRoomCountingButton: View {
    let count: Int
    let title: String
    let onAdvance: () -> Void

    var body: some View {
        Button {
            onAdvance()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18, weight: .black))

                Text("\(count)")
                    .font(.system(size: 24, weight: .black, design: .monospaced))

                Text(title)
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .textCase(.uppercase)
                    .tracking(0.9)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .foregroundStyle(FocusRoomPalette.background)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(FocusRoomPalette.yellow, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct FocusRoomStepTracker: View {
    let currentIndex: Int
    let steps: [String]
    let completedLabel: String
    let buttonTitle: String
    let onAdvance: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                FocusRoomTimerMetric(value: "\(min(currentIndex + 1, max(steps.count, 1)))", label: "Current")
                FocusRoomTimerMetric(value: "\(steps.count)", label: "Total")
            }

            Text(currentStepText)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(FocusRoomPalette.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            FocusRoomActionButton(
                title: isComplete ? "Complete" : buttonTitle,
                systemImage: isComplete ? "checkmark.seal.fill" : "checkmark.circle.fill",
                isProminent: true,
                action: {
                    guard isComplete == false else {
                        return
                    }

                    onAdvance()
                }
            )
            .opacity(isComplete ? 0.72 : 1)
        }
    }

    private var isComplete: Bool {
        currentIndex >= max(steps.count, 1)
    }

    private var currentStepText: String {
        guard isComplete == false else {
            return completedLabel
        }

        guard steps.indices.contains(currentIndex) else {
            return "Complete the current step."
        }

        return steps[currentIndex].garageFocusRoomSentenceTrimmed
    }
}

private struct FocusRoomManualTracker: View {
    let isComplete: Bool
    let label: String
    let onAdvance: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label.garageFocusRoomSentenceTrimmed)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(FocusRoomPalette.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            FocusRoomActionButton(
                title: isComplete ? "Complete" : "Mark Complete",
                systemImage: isComplete ? "checkmark.seal.fill" : "checkmark.circle.fill",
                isProminent: true,
                action: {
                    guard isComplete == false else {
                        return
                    }

                    onAdvance()
                }
            )
        }
    }
}

private struct FocusRoomActionButton: View {
    let title: String
    let systemImage: String
    let isProminent: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .foregroundStyle(isProminent ? FocusRoomPalette.background : FocusRoomPalette.primaryText)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(isProminent ? FocusRoomPalette.yellow : FocusRoomPalette.panel, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(isProminent ? Color.white.opacity(0.18) : FocusRoomPalette.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct FocusRoomTimerMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 26, weight: .black, design: .monospaced))
                .foregroundStyle(FocusRoomPalette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.system(size: 9, weight: .black, design: .rounded))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundStyle(FocusRoomPalette.secondaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct FocusRoomTeachingDetailsCard: View {
    let isExpanded: Bool
    let setupLine: String
    let executionCue: String
    let teachingDetail: String?
    let reviewSummary: String?
    let watchFor: String?
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                garageTriggerSelection()
                onToggle()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isExpanded ? "chevron.down.circle.fill" : "chevron.right.circle.fill")
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(FocusRoomPalette.green)

                    Text("Teaching Details")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .textCase(.uppercase)
                        .tracking(1.4)
                        .foregroundStyle(FocusRoomPalette.primaryText)

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    FocusRoomTeachingLine(title: "Setup Detail", text: setupLine)
                    FocusRoomTeachingLine(title: "Cue", text: executionCue)

                    if let teachingDetail,
                       teachingDetail.isEmpty == false {
                        FocusRoomTeachingLine(title: "Why It Matters", text: teachingDetail)
                    }

                    if let watchFor,
                       watchFor.isEmpty == false {
                        FocusRoomTeachingLine(title: "Watch For", text: watchFor)
                    }

                    if let reviewSummary,
                       reviewSummary.isEmpty == false {
                        FocusRoomTeachingLine(title: "Review Cue", text: reviewSummary, isEmphasized: true)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(FocusRoomPalette.border, lineWidth: 1)
        )
    }
}

private struct FocusRoomTeachingLine: View {
    let title: String
    let text: String
    var isEmphasized = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9, weight: .black, design: .rounded))
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(isEmphasized ? FocusRoomPalette.green : FocusRoomPalette.secondaryText)

            Text(text.garageFocusRoomSentenceTrimmed)
                .font(.system(size: isEmphasized ? 14 : 13, weight: .semibold, design: .rounded))
                .foregroundStyle(isEmphasized ? FocusRoomPalette.greenSoft : FocusRoomPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct FocusRoomBottomActions: View {
    let noteTitle: String
    let primaryTitle: String
    let statusText: String
    let isNextEnabled: Bool
    let onNote: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button {
                garageTriggerSelection()
                onNote()
            } label: {
                Label(noteTitle, systemImage: noteTitle == GarageFocusRoomCopy.focusRoomNoteAddCta ? "square.and.pencil" : "note.text")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .foregroundStyle(FocusRoomPalette.primaryText)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(FocusRoomPalette.panel.opacity(0.88), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .stroke(FocusRoomPalette.border, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            HStack(spacing: 12) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(primaryTitle)
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(FocusRoomPalette.primaryText)
                        .lineLimit(1)

                    Text(statusText.garageFocusRoomSentenceTrimmed)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(FocusRoomPalette.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Button {
                    guard isNextEnabled else {
                        return
                    }

                    garageTriggerImpact(.medium)
                    onNext()
                } label: {
                    Image(systemName: "chevron.forward.2")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(isNextEnabled ? FocusRoomPalette.background : FocusRoomPalette.secondaryText)
                        .frame(width: 52, height: 52)
                        .background(isNextEnabled ? FocusRoomPalette.green : FocusRoomPalette.panel.opacity(0.9), in: Circle())
                        .overlay(
                            Circle()
                                .stroke(isNextEnabled ? Color.white.opacity(0.16) : FocusRoomPalette.border, lineWidth: 1)
                        )
                        .shadow(color: isNextEnabled ? FocusRoomPalette.green.opacity(0.28) : .clear, radius: 14, x: 0, y: 0)
                }
                .buttonStyle(.plain)
                .disabled(isNextEnabled == false)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(
            LinearGradient(
                colors: [
                    FocusRoomPalette.background.opacity(0),
                    FocusRoomPalette.background.opacity(0.96),
                    FocusRoomPalette.background
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

private extension String {
    var garageFocusRoomSentenceTrimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }
}

private enum GarageFocusRoomPreviewData {
    static func presentation(for mode: GarageDrillFocusMode) -> GarageFocusDrillPresentation {
        GarageFocusDrillPresentation(
            id: UUID(),
            content: GarageDrillFocusContent(
                title: previewTitle(for: mode),
                task: "Execute the assigned drill standard.",
                setupLine: "Set the station before the first attempt.",
                executionCue: "Only count clean executions that match the cue.",
                goal: previewGoal(for: mode),
                mode: mode,
                targetMetric: previewGoal(for: mode).goalText,
                watchFor: "Loss of rhythm between attempts.",
                finishRule: "Complete the drill requirement before advancing.",
                teachingDetail: "Keep posture and tempo stable through the full set.",
                reviewSummary: "Track what produced the cleanest outcome.",
                quickTags: ["Tempo", "Contact", "Start Line"],
                diagramKey: nil
            ),
            isCompleted: false
        )
    }

    static var railItems: [GarageFocusDrillRailItem] {
        [
            GarageFocusDrillRailItem(
                id: UUID(),
                index: 0,
                title: "Preview Drill",
                metadata: "Mode QA",
                status: .current,
                isSelectable: false
            )
        ]
    }

    private static func previewGoal(for mode: GarageDrillFocusMode) -> GarageDrillGoal {
        switch mode {
        case .reps:
            return .repTarget(count: 8, unit: "clean reps")
        case .time:
            return .timed(durationSeconds: 120)
        case .goal:
            return .ladder(steps: ["Step one", "Step two", "Step three"])
        case .challenge:
            return .streak(count: 5, unit: "clean starts")
        case .checklist:
            return .checklist(items: ["Setup", "Cue", "Finish"])
        }
    }

    private static func previewTitle(for mode: GarageDrillFocusMode) -> String {
        switch mode {
        case .reps:
            return "Rep Mode Preview"
        case .time:
            return "Time Mode Preview"
        case .goal:
            return "Goal Mode Preview"
        case .challenge:
            return "Challenge Mode Preview"
        case .checklist:
            return "Checklist Mode Preview"
        }
    }
}

#Preview("Focus Room - Reps") {
    GarageFocusRoomView(
        sessionTitle: "Preview Session",
        environment: .range,
        drillPositionText: "Drill 1 of 1",
        completedCount: 0,
        totalCount: 1,
        drill: GarageFocusRoomPreviewData.presentation(for: .reps),
        railItems: GarageFocusRoomPreviewData.railItems,
        isDetailExpanded: false,
        noteTitle: GarageFocusRoomCopy.focusRoomNoteAddCta,
        primaryCtaTitle: GarageFocusRoomCopy.focusRoomMarkCompleteCta,
        onToggleDetail: {},
        onSelectRailDrill: { _ in },
        onNote: {},
        onPrimary: { _ in },
        onExitEmptyRoutine: {}
    )
}

#Preview("Focus Room - Time") {
    GarageFocusRoomView(
        sessionTitle: "Preview Session",
        environment: .range,
        drillPositionText: "Drill 1 of 1",
        completedCount: 0,
        totalCount: 1,
        drill: GarageFocusRoomPreviewData.presentation(for: .time),
        railItems: GarageFocusRoomPreviewData.railItems,
        isDetailExpanded: false,
        noteTitle: GarageFocusRoomCopy.focusRoomNoteAddCta,
        primaryCtaTitle: GarageFocusRoomCopy.focusRoomMarkCompleteCta,
        onToggleDetail: {},
        onSelectRailDrill: { _ in },
        onNote: {},
        onPrimary: { _ in },
        onExitEmptyRoutine: {}
    )
}

#Preview("Focus Room - Goal") {
    GarageFocusRoomView(
        sessionTitle: "Preview Session",
        environment: .range,
        drillPositionText: "Drill 1 of 1",
        completedCount: 0,
        totalCount: 1,
        drill: GarageFocusRoomPreviewData.presentation(for: .goal),
        railItems: GarageFocusRoomPreviewData.railItems,
        isDetailExpanded: false,
        noteTitle: GarageFocusRoomCopy.focusRoomNoteAddCta,
        primaryCtaTitle: GarageFocusRoomCopy.focusRoomMarkCompleteCta,
        onToggleDetail: {},
        onSelectRailDrill: { _ in },
        onNote: {},
        onPrimary: { _ in },
        onExitEmptyRoutine: {}
    )
}

#Preview("Focus Room - Challenge") {
    GarageFocusRoomView(
        sessionTitle: "Preview Session",
        environment: .range,
        drillPositionText: "Drill 1 of 1",
        completedCount: 0,
        totalCount: 1,
        drill: GarageFocusRoomPreviewData.presentation(for: .challenge),
        railItems: GarageFocusRoomPreviewData.railItems,
        isDetailExpanded: false,
        noteTitle: GarageFocusRoomCopy.focusRoomNoteAddCta,
        primaryCtaTitle: GarageFocusRoomCopy.focusRoomMarkCompleteCta,
        onToggleDetail: {},
        onSelectRailDrill: { _ in },
        onNote: {},
        onPrimary: { _ in },
        onExitEmptyRoutine: {}
    )
}

#Preview("Focus Room - Checklist") {
    GarageFocusRoomView(
        sessionTitle: "Preview Session",
        environment: .range,
        drillPositionText: "Drill 1 of 1",
        completedCount: 0,
        totalCount: 1,
        drill: GarageFocusRoomPreviewData.presentation(for: .checklist),
        railItems: GarageFocusRoomPreviewData.railItems,
        isDetailExpanded: false,
        noteTitle: GarageFocusRoomCopy.focusRoomNoteAddCta,
        primaryCtaTitle: GarageFocusRoomCopy.focusRoomMarkCompleteCta,
        onToggleDetail: {},
        onSelectRailDrill: { _ in },
        onNote: {},
        onPrimary: { _ in },
        onExitEmptyRoutine: {}
    )
}
