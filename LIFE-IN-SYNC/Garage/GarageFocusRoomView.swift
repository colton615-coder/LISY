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
    let mode: GarageDrillFocusMode
    let goal: GarageDrillGoal
    let durationSeconds: Int
    let goalMet: Bool
}

struct GarageFocusRoomView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isRoutineVisible = false
    @State private var activeDrillID: UUID?
    @State private var elapsedSeconds = 0
    @State private var isTimerRunning = false

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
    let onSkip: (GarageFocusCompletionPayload) -> Void
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
                                completionState: completionState(for: drill),
                                isTimerRunning: isTimerRunning,
                                onStartPause: toggleTimer,
                                onReset: resetTimer
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
                    onNote: onNote,
                    onSkip: {
                        onSkip(completionPayload(for: drill))
                    },
                    onNext: {
                        onPrimary(completionPayload(for: drill))
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
                guard drill.isCompleted == false, isTimerRunning else {
                    return
                }

                elapsedSeconds += 1
                if elapsedSeconds >= drill.content.durationSeconds {
                    isTimerRunning = false
                }
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
        isTimerRunning = false
        isRoutineVisible = false
    }

    func toggleRoutineVisibility() {
        garageTriggerSelection()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isRoutineVisible.toggle()
        }
    }

    func toggleTimer() {
        garageTriggerSelection()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
            isTimerRunning.toggle()
        }
    }

    func resetTimer() {
        garageTriggerSelection()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
            elapsedSeconds = 0
            isTimerRunning = false
        }
    }

    func completionPayload(for drill: GarageFocusDrillPresentation) -> GarageFocusCompletionPayload {
        GarageFocusCompletionPayload(
            elapsedSeconds: elapsedSeconds,
            mode: drill.content.mode,
            goal: drill.content.goal,
            durationSeconds: drill.content.durationSeconds,
            goalMet: isGoalMet(drill.content.goal)
        )
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
        case .repTarget, .streak, .timeTrial, .ladder, .checklist, .manual:
            return false
        }
    }

    func hasStarted(_ goal: GarageDrillGoal) -> Bool {
        switch goal {
        case .timed:
            return elapsedSeconds > 0
        case .repTarget, .streak, .timeTrial, .ladder, .checklist, .manual:
            return elapsedSeconds > 0
        }
    }

    func statusText(for goal: GarageDrillGoal, state: GarageFocusCompletionState) -> String {
        if state == .completed {
            return "Confirmed"
        }

        if state == .ready {
            return "Target reached"
        }

        switch goal {
        case .timed(let durationSeconds):
            return "Suggested: \(formattedTime(durationSeconds))"
        case .repTarget, .streak, .timeTrial, .ladder, .checklist:
            return "Resolve honestly when ready"
        case .manual:
            return "Resolve honestly when ready"
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
        true
    }

    var bottomStatusText: String {
        switch self {
        case .notStarted:
            return "Ready"
        case .inProgress:
            return "In progress"
        case .ready:
            return "Target reached"
        case .completed:
            return "Confirmed"
        }
    }

    func primaryTitle(goal: GarageDrillGoal, fallback: String) -> String {
        guard fallback != GarageFocusRoomCopy.focusRoomEnterReviewCta else {
            return fallback
        }

        return GarageFocusRoomCopy.focusRoomMarkCompleteCta
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
                    Text("\(completedCount)/\(totalCount) targets met")
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
    let completionState: GarageFocusCompletionState
    let isTimerRunning: Bool
    let onStartPause: () -> Void
    let onReset: () -> Void

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

            TimeDrillHero(
                goal: content.goal,
                elapsedSeconds: elapsedSeconds,
                isReady: completionState == .ready || completionState == .completed
            )

            FocusRoomTimerControls(
                isRunning: isTimerRunning,
                hasStarted: elapsedSeconds > 0,
                isComplete: completionState == .ready || completionState == .completed,
                onStartPause: onStartPause,
                onReset: onReset
            )

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

    private var progressText: String {
        switch content.goal {
        case .timed(let durationSeconds):
            return "\(formattedTime(elapsedSeconds)) / \(formattedTime(durationSeconds))"
        case .repTarget, .streak, .timeTrial, .ladder, .checklist:
            return formattedTime(elapsedSeconds)
        case .manual(let label):
            return label
        }
    }

    private var stopwatchCaption: String {
        content.guidanceText ?? "Suggested structure"
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

private struct TimeDrillHero: View {
    let goal: GarageDrillGoal
    let elapsedSeconds: Int
    let isReady: Bool

    var body: some View {
        FocusRoomTimerHeroPanel(
            elapsedSeconds: elapsedSeconds,
            progress: progress,
            isCompleted: isReady,
            statusText: isReady ? "Time target reached" : "Suggested structure"
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

private struct FocusRoomTimerControls: View {
    let isRunning: Bool
    let hasStarted: Bool
    let isComplete: Bool
    let onStartPause: () -> Void
    let onReset: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            FocusRoomActionButton(
                title: primaryTitle,
                systemImage: primarySystemImage,
                isProminent: true,
                action: {
                    guard isComplete == false else {
                        return
                    }

                    onStartPause()
                }
            )
            .opacity(isComplete ? 0.7 : 1)

            FocusRoomActionButton(
                title: "Reset",
                systemImage: "arrow.counterclockwise",
                isProminent: false,
                action: onReset
            )
            .disabled(hasStarted == false)
            .opacity(hasStarted ? 1 : 0.46)
        }
    }

    private var primaryTitle: String {
        if isComplete {
            return "Target Reached"
        }

        if isRunning {
            return "Pause"
        }

        return hasStarted ? "Resume" : "Start"
    }

    private var primarySystemImage: String {
        if isComplete {
            return "checkmark.seal.fill"
        }

        return isRunning ? "pause.fill" : "play.fill"
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
    let onNote: () -> Void
    let onSkip: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            FocusRoomDockButton(
                title: noteTitle,
                systemImage: noteTitle == GarageFocusRoomCopy.focusRoomNoteAddCta ? "square.and.pencil" : "note.text",
                action: onNote
            )

            FocusRoomDockButton(
                title: "Skip Drill",
                systemImage: "forward.end.fill",
                action: onSkip
            )

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
                    garageTriggerImpact(.medium)
                    onNext()
                } label: {
                    Image(systemName: "chevron.forward.2")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(FocusRoomPalette.background)
                        .frame(width: 52, height: 52)
                        .background(FocusRoomPalette.green, in: Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.16), lineWidth: 1)
                        )
                        .shadow(color: FocusRoomPalette.green.opacity(0.28), radius: 14, x: 0, y: 0)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(primaryTitle)
                .accessibilityIdentifier("garage-focus-next")
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

private struct FocusRoomDockButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button {
            garageTriggerSelection()
            action()
        } label: {
            Label(title, systemImage: systemImage)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.68)
                .foregroundStyle(FocusRoomPalette.primaryText)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(FocusRoomPalette.panel.opacity(0.88), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .stroke(FocusRoomPalette.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("garage-focus-\(title.lowercased().replacingOccurrences(of: " ", with: "-"))")
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
        let durationSeconds = 420
        return GarageFocusDrillPresentation(
            id: UUID(),
            content: GarageDrillFocusContent(
                title: previewTitle(for: mode),
                task: "Execute the assigned drill standard.",
                setupLine: "Set the station before the first attempt.",
                executionCue: "Only count clean executions that match the cue.",
                goal: .timed(durationSeconds: durationSeconds),
                mode: mode,
                durationSeconds: durationSeconds,
                targetMetric: previewTarget(for: mode),
                guidanceText: "Suggested volume: 12-18 focused swings.",
                watchFor: "Loss of rhythm between attempts.",
                finishRule: "Suggested: 7 minutes of focused work.",
                teachingDetail: "Keep posture and tempo stable through the full set.",
                reviewSummary: "Track what produced the cleanest outcome.",
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

    private static func previewTarget(for mode: GarageDrillFocusMode) -> String {
        switch mode {
        case .process:
            return "Hold the cue through the full block"
        case .target:
            return "Start the ball through the window"
        case .pressureTest:
            return "Pass the pressure standard"
        }
    }

    private static func previewTitle(for mode: GarageDrillFocusMode) -> String {
        switch mode {
        case .process:
            return "Process Block Preview"
        case .target:
            return "Target Block Preview"
        case .pressureTest:
            return "Pressure Test Preview"
        }
    }
}

#Preview("Focus Room - Process") {
    GarageFocusRoomView(
        sessionTitle: "Preview Session",
        environment: .range,
        drillPositionText: "Drill 1 of 1",
        completedCount: 0,
        totalCount: 1,
        drill: GarageFocusRoomPreviewData.presentation(for: .process),
        railItems: GarageFocusRoomPreviewData.railItems,
        isDetailExpanded: false,
        noteTitle: GarageFocusRoomCopy.focusRoomNoteAddCta,
        primaryCtaTitle: GarageFocusRoomCopy.focusRoomMarkCompleteCta,
        onToggleDetail: {},
        onSelectRailDrill: { _ in },
        onNote: {},
        onPrimary: { _ in },
        onSkip: { _ in },
        onExitEmptyRoutine: {}
    )
}

#Preview("Focus Room - Target") {
    GarageFocusRoomView(
        sessionTitle: "Preview Session",
        environment: .range,
        drillPositionText: "Drill 1 of 1",
        completedCount: 0,
        totalCount: 1,
        drill: GarageFocusRoomPreviewData.presentation(for: .target),
        railItems: GarageFocusRoomPreviewData.railItems,
        isDetailExpanded: false,
        noteTitle: GarageFocusRoomCopy.focusRoomNoteAddCta,
        primaryCtaTitle: GarageFocusRoomCopy.focusRoomMarkCompleteCta,
        onToggleDetail: {},
        onSelectRailDrill: { _ in },
        onNote: {},
        onPrimary: { _ in },
        onSkip: { _ in },
        onExitEmptyRoutine: {}
    )
}

#Preview("Focus Room - Pressure Test") {
    GarageFocusRoomView(
        sessionTitle: "Preview Session",
        environment: .range,
        drillPositionText: "Drill 1 of 1",
        completedCount: 0,
        totalCount: 1,
        drill: GarageFocusRoomPreviewData.presentation(for: .pressureTest),
        railItems: GarageFocusRoomPreviewData.railItems,
        isDetailExpanded: false,
        noteTitle: GarageFocusRoomCopy.focusRoomNoteAddCta,
        primaryCtaTitle: GarageFocusRoomCopy.focusRoomMarkCompleteCta,
        onToggleDetail: {},
        onSelectRailDrill: { _ in },
        onNote: {},
        onPrimary: { _ in },
        onSkip: { _ in },
        onExitEmptyRoutine: {}
    )
}
