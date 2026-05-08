import Combine
import Foundation
import SwiftUI

struct GarageFocusDrillPresentation {
    let id: UUID
    let content: GarageDrillFocusContent
    let diagram: GarageDrillDiagram
    let isCompleted: Bool
}

struct GarageFocusRoomView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isRoutineVisible = false
    @State private var activeDrillID: UUID?
    @State private var elapsedSeconds = 0
    @State private var trackerValue = 0

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
    let onPrimary: () -> Void
    let onExitEmptyRoutine: () -> Void

    var body: some View {
        if let drill {
            ZStack {
                FocusRoomBackground()

                VStack(spacing: 0) {
                    FocusRoomHeader(
                        isRoutineVisible: isRoutineVisible,
                        onBack: { dismiss() },
                        onToggleRoutine: toggleRoutineVisibility
                    )

                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            FocusRoomDrillHero(
                                drillTitle: drill.content.title,
                                drillPositionText: drillPositionText,
                                completedCount: completedCount,
                                totalCount: totalCount,
                                diagram: drill.diagram
                            )

                            FocusRoomTaskCard(task: drill.content.task)

                            FocusRoomSetupSteps(steps: drill.content.setupSteps)

                            FocusRoomGoalCard(
                                goal: drill.content.goal,
                                goalText: drill.content.goal.goalText,
                                finishRule: drill.content.finishRule,
                                elapsedSeconds: elapsedSeconds,
                                trackerValue: trackerValue,
                                onAdvance: recordGoalProgress,
                                onReset: resetGoalProgress
                            )

                            if let watchFor = drill.content.watchFor,
                               watchFor.isEmpty == false {
                                FocusRoomWatchForBand(text: watchFor)
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
                FocusRoomBottomActions(
                    noteTitle: noteTitle,
                    primaryTitle: primaryCtaTitle,
                    finishRule: drill.content.finishRule,
                    isNextEnabled: drill.isCompleted || isGoalMet(drill.content.goal),
                    onNote: onNote,
                    onNext: onPrimary
                )
            }
            .onAppear {
                resetStateIfNeeded(for: drill.id)
            }
            .onChange(of: drill.id) { _, newValue in
                resetStateIfNeeded(for: newValue)
            }
            .onReceive(timer) { _ in
                guard drill.isCompleted == false,
                      isGoalMet(drill.content.goal) == false else {
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
    static let contentBottomInset: CGFloat = 184
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

    func resetGoalProgress() {
        garageTriggerSelection()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
            trackerValue = 0
        }
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
                    Color.black.opacity(0.72)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(FocusRoomPalette.green.opacity(0.15))
                .frame(width: 320, height: 320)
                .blur(radius: 90)
                .offset(x: -150, y: -260)

            Circle()
                .fill(FocusRoomPalette.green.opacity(0.08))
                .frame(width: 260, height: 260)
                .blur(radius: 100)
                .offset(x: 170, y: 220)
        }
    }
}

private struct FocusRoomHeader: View {
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

            Text("Focus Room")
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(FocusRoomPalette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
}

private struct FocusRoomDrillHero: View {
    let drillTitle: String
    let drillPositionText: String
    let completedCount: Int
    let totalCount: Int
    let diagram: GarageDrillDiagram

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(drillTitle)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(FocusRoomPalette.primaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.74)

                HStack(spacing: 8) {
                    Text(drillPositionText)
                    Text("\(completedCount)/\(totalCount) complete")
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(FocusRoomPalette.secondaryText)
            }

            GarageDrillDiagramView(diagram: diagram)
                .frame(maxWidth: .infinity)
                .frame(height: 218)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(FocusRoomPalette.border, lineWidth: 1)
                )
        }
    }
}

private struct FocusRoomTaskCard: View {
    let task: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FocusRoomSectionLabel(title: "Task")

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "scope")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(FocusRoomPalette.green)
                    .frame(width: 34, height: 34)
                    .background(FocusRoomPalette.green.opacity(0.12), in: Circle())

                Text(task.garageFocusRoomSentenceTrimmed)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(FocusRoomPalette.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .background(FocusRoomPalette.panel.opacity(0.58), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(FocusRoomPalette.border, lineWidth: 1)
            )
        }
    }
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

private struct FocusRoomSetupSteps: View {
    let steps: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            FocusRoomSectionLabel(title: "Setup")

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .foregroundStyle(FocusRoomPalette.background)
                            .frame(width: 25, height: 25)
                            .background(FocusRoomPalette.green, in: Circle())

                        Text(step.garageFocusRoomSentenceTrimmed)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(FocusRoomPalette.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }
}

private struct FocusRoomGoalCard: View {
    let goal: GarageDrillGoal
    let goalText: String
    let finishRule: String
    let elapsedSeconds: Int
    let trackerValue: Int
    let onAdvance: () -> Void
    let onReset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Rectangle()
                .fill(FocusRoomPalette.green.opacity(0.32))
                .frame(height: 1)

            FocusRoomSectionLabel(title: "Goal")

            HStack(alignment: .top, spacing: 13) {
                Image(systemName: "target")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(FocusRoomPalette.green)

                VStack(alignment: .leading, spacing: 4) {
                    Text(goalText.garageFocusRoomSentenceTrimmed)
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .foregroundStyle(FocusRoomPalette.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(finishRule.garageFocusRoomSentenceTrimmed)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(FocusRoomPalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            FocusRoomTrackerStrip(
                goal: goal,
                elapsedSeconds: elapsedSeconds,
                trackerValue: trackerValue,
                onAdvance: onAdvance,
                onReset: onReset
            )
        }
    }
}

private struct FocusRoomTrackerStrip: View {
    let goal: GarageDrillGoal
    let elapsedSeconds: Int
    let trackerValue: Int
    let onAdvance: () -> Void
    let onReset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FocusRoomSectionLabel(title: "Tracker")

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

private struct FocusRoomWatchForBand: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(FocusRoomPalette.yellow)

            VStack(alignment: .leading, spacing: 4) {
                Text("Watch For")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .foregroundStyle(FocusRoomPalette.yellow)

                Text(text.garageFocusRoomSentenceTrimmed)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(FocusRoomPalette.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(FocusRoomPalette.yellow.opacity(0.16), lineWidth: 1)
        )
    }
}

private struct FocusRoomBottomActions: View {
    let noteTitle: String
    let primaryTitle: String
    let finishRule: String
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

                    Text(finishRule.garageFocusRoomSentenceTrimmed)
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
        .padding(.bottom, 8)
        .background(FocusRoomPalette.background.opacity(0.94))
    }
}

private extension String {
    var garageFocusRoomSentenceTrimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }
}
