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
    let noteTitle: String
    let primaryCtaTitle: String
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
                        isRoutineVisible: isRoutineVisible,
                        onBack: { dismiss() },
                        onToggleRoutine: toggleRoutineVisibility
                    )

                    ViewThatFits(in: .vertical) {
                        FocusRoomExecutionSurface(
                            drill: drill,
                            elapsedSeconds: elapsedSeconds,
                            completionState: completionState(for: drill),
                            isTimerRunning: isTimerRunning,
                            nextDrill: nextRailItem(after: drill),
                            onResetTimer: resetTimer,
                            onNext: {
                                onPrimary(completionPayload(for: drill))
                            }
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        .padding(.bottom, GarageFocusRoomLayout.contentBottomInset)

                        ScrollView {
                            FocusRoomExecutionSurface(
                                drill: drill,
                                elapsedSeconds: elapsedSeconds,
                                completionState: completionState(for: drill),
                                isTimerRunning: isTimerRunning,
                                nextDrill: nextRailItem(after: drill),
                                onResetTimer: resetTimer,
                                onNext: {
                                    onPrimary(completionPayload(for: drill))
                                }
                            )
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                            .padding(.bottom, GarageFocusRoomLayout.contentBottomInset)
                        }
                        .scrollIndicators(.hidden)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .tint(FocusRoomPalette.green)
            .sheet(isPresented: $isRoutineVisible) {
                ScrollView {
                    GarageFocusDrillStackRail(
                        items: railItems,
                        onSelectDrill: { index in
                            isRoutineVisible = false
                            onSelectRailDrill(index)
                        }
                    )
                    .padding(16)
                }
                .scrollIndicators(.hidden)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(FocusRoomPalette.background)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                let state = completionState(for: drill)
                FocusRoomBottomActions(
                    noteTitle: noteTitle,
                    primaryTitle: primaryDockTitle(state: state),
                    primarySystemImage: primaryDockSymbol(state: state),
                    onNote: onNote,
                    onSkip: {
                        onSkip(completionPayload(for: drill))
                    },
                    onPrimary: {
                        if shouldDriveTimerFromDock(state: state) {
                            toggleTimer()
                            return
                        }
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
    static let contentBottomInset: CGFloat = 98
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
            goalMet: isGoalMet(durationSeconds: drill.content.durationSeconds)
        )
    }

    func completionState(for drill: GarageFocusDrillPresentation) -> GarageFocusCompletionState {
        if drill.isCompleted {
            return .completed
        }

        if isGoalMet(durationSeconds: drill.content.durationSeconds) {
            return .ready
        }

        if hasStarted {
            return .inProgress
        }

        return .notStarted
    }

    func isGoalMet(durationSeconds: Int) -> Bool {
        elapsedSeconds >= max(durationSeconds, 1)
    }

    var hasStarted: Bool {
        elapsedSeconds > 0
    }

    func shouldDriveTimerFromDock(state: GarageFocusCompletionState) -> Bool {
        return state == .notStarted || state == .inProgress
    }

    func nextRailItem(after drill: GarageFocusDrillPresentation) -> GarageFocusDrillRailItem? {
        guard let currentIndex = railItems.firstIndex(where: { $0.id == drill.id }) else {
            return railItems.first { $0.status == .upcoming }
        }

        return railItems[(currentIndex + 1)...].first { $0.status == .upcoming }
            ?? railItems.first { $0.status == .upcoming }
    }

    func primaryDockTitle(state: GarageFocusCompletionState) -> String {
        if state == .completed || state == .ready {
            return GarageFocusRoomCopy.focusRoomMarkCompleteCta
        }

        if isTimerRunning {
            return "Pause"
        }

        return elapsedSeconds > 0 ? "Resume" : "Start"
    }

    func primaryDockSymbol(state: GarageFocusCompletionState) -> String {
        if state == .completed || state == .ready {
            return "checkmark"
        }

        return isTimerRunning ? "pause.fill" : "play.fill"
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

    var bottomStatusText: String {
        switch self {
        case .notStarted:
            return "Ready"
        case .inProgress:
            return "In progress"
        case .ready:
            return "Timer complete"
        case .completed:
            return "Confirmed"
        }
    }
}

private enum FocusHeroVisualState: Hashable {
    case idle
    case running
    case paused
    case completed
    case skipped

    init(
        completionState: GarageFocusCompletionState,
        isTimerRunning: Bool,
        elapsedSeconds: Int
    ) {
        switch completionState {
        case .completed, .ready:
            self = .completed
        case .inProgress:
            self = isTimerRunning ? .running : .paused
        case .notStarted:
            self = elapsedSeconds > 0 ? .paused : .idle
        }
    }

    var style: FocusHeroStyle {
        switch self {
        case .idle:
            return FocusHeroStyle(
                ringLineWidth: 24,
                trackOpacity: 0.22,
                ringOpacity: 0.88,
                heroOpacity: 1,
                elapsedFont: .system(size: 52, weight: .black, design: .monospaced),
                targetFont: .system(size: 15, weight: .black, design: .rounded),
                statusFont: .system(size: 11, weight: .black, design: .rounded),
                progressFont: .system(size: 12, weight: .bold, design: .rounded),
                shouldAnimateRing: false,
                showsCompletionPrompt: false,
                showsNextDrillCard: false
            )
        case .running:
            return FocusHeroStyle(
                ringLineWidth: 28,
                trackOpacity: 0.18,
                ringOpacity: 1,
                heroOpacity: 1,
                elapsedFont: .system(size: 56, weight: .black, design: .monospaced),
                targetFont: .system(size: 15, weight: .black, design: .rounded),
                statusFont: .system(size: 11, weight: .black, design: .rounded),
                progressFont: .system(size: 12, weight: .bold, design: .rounded),
                shouldAnimateRing: true,
                showsCompletionPrompt: false,
                showsNextDrillCard: false
            )
        case .paused:
            return FocusHeroStyle(
                ringLineWidth: 26,
                trackOpacity: 0.16,
                ringOpacity: 0.7,
                heroOpacity: 0.74,
                elapsedFont: .system(size: 54, weight: .black, design: .monospaced),
                targetFont: .system(size: 15, weight: .black, design: .rounded),
                statusFont: .system(size: 11, weight: .black, design: .rounded),
                progressFont: .system(size: 12, weight: .bold, design: .rounded),
                shouldAnimateRing: false,
                showsCompletionPrompt: false,
                showsNextDrillCard: false
            )
        case .completed:
            return FocusHeroStyle(
                ringLineWidth: 28,
                trackOpacity: 0.14,
                ringOpacity: 1,
                heroOpacity: 1,
                elapsedFont: .system(size: 56, weight: .black, design: .monospaced),
                targetFont: .system(size: 15, weight: .black, design: .rounded),
                statusFont: .system(size: 11, weight: .black, design: .rounded),
                progressFont: .system(size: 12, weight: .bold, design: .rounded),
                shouldAnimateRing: false,
                showsCompletionPrompt: true,
                showsNextDrillCard: true
            )
        case .skipped:
            return FocusHeroStyle(
                ringLineWidth: 24,
                trackOpacity: 0.16,
                ringOpacity: 0.78,
                heroOpacity: 0.9,
                elapsedFont: .system(size: 52, weight: .black, design: .monospaced),
                targetFont: .system(size: 15, weight: .black, design: .rounded),
                statusFont: .system(size: 11, weight: .black, design: .rounded),
                progressFont: .system(size: 12, weight: .bold, design: .rounded),
                shouldAnimateRing: false,
                showsCompletionPrompt: false,
                showsNextDrillCard: true
            )
        }
    }
}

private struct FocusHeroStyle {
    let ringLineWidth: CGFloat
    let trackOpacity: Double
    let ringOpacity: Double
    let heroOpacity: Double
    let elapsedFont: Font
    let targetFont: Font
    let statusFont: Font
    let progressFont: Font
    let shouldAnimateRing: Bool
    let showsCompletionPrompt: Bool
    let showsNextDrillCard: Bool
}

private struct FocusRoomBackground: View {
    var body: some View {
        ZStack {
            GaragePracticeAtmosphereBackground()

            RadialGradient(
                colors: [
                    FocusRoomPalette.green.opacity(0.24),
                    .clear
                ],
                center: .center,
                startRadius: 32,
                endRadius: 330
            )
            .ignoresSafeArea()
        }
    }
}

private struct FocusRoomHeader: View {
    let drillTitle: String
    let drillPositionText: String
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
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(FocusRoomPalette.primaryText)
                        .frame(width: 38, height: 38)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    onToggleRoutine()
                } label: {
                    Image(systemName: isRoutineVisible ? "list.bullet.rectangle.fill" : "list.bullet.rectangle")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(isRoutineVisible ? FocusRoomPalette.green : FocusRoomPalette.secondaryText)
                        .frame(width: 38, height: 38)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 3) {
                Text(drillTitle)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(FocusRoomPalette.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                HStack(spacing: 8) {
                    Text(drillPositionText)
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(FocusRoomPalette.green)
            }
            .padding(.horizontal, 58)
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 4)
    }
}

private struct FocusRoomExecutionSurface: View {
    let drill: GarageFocusDrillPresentation
    let elapsedSeconds: Int
    let completionState: GarageFocusCompletionState
    let isTimerRunning: Bool
    let nextDrill: GarageFocusDrillRailItem?
    let onResetTimer: () -> Void
    let onNext: () -> Void

    private var visualState: FocusHeroVisualState {
        FocusHeroVisualState(
            completionState: completionState,
            isTimerRunning: isTimerRunning,
            elapsedSeconds: elapsedSeconds
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FocusRoomModeTabs()

            FocusRoomTeachingSection(
                setupSteps: drill.content.setupSteps,
                cueSteps: drill.content.cueSteps,
                modeLabel: drill.content.mode.controlLabel,
                durationText: formattedTime(drill.content.durationSeconds)
            )

            GarageFocusHeroContainer(
                durationSeconds: drill.content.durationSeconds,
                elapsedSeconds: elapsedSeconds,
                completionState: completionState,
                isTimerRunning: isTimerRunning,
                onReset: onResetTimer
            )

            if visualState.style.showsCompletionPrompt {
                FocusRoomCompletionPrompt()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if visualState.style.showsNextDrillCard {
                FocusRoomNextDrillCard(
                    nextDrill: nextDrill,
                    action: onNext
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.88), value: visualState)
    }
}

private struct GarageFocusHeroContainer: View {
    let durationSeconds: Int
    let elapsedSeconds: Int
    let completionState: GarageFocusCompletionState
    let isTimerRunning: Bool
    let onReset: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            GarageDominantTimerHero(
                durationSeconds: durationSeconds,
                elapsedSeconds: elapsedSeconds,
                completionState: completionState,
                isTimerRunning: isTimerRunning
            )

            resetButton
                .padding(14)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var resetButton: some View {
        if elapsedSeconds > 0 {
            Button {
                onReset()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(FocusRoomPalette.primaryText)
                    .frame(width: 34, height: 34)
                    .background(FocusRoomPalette.panel.opacity(0.95), in: Circle())
                    .overlay(Circle().stroke(FocusRoomPalette.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Reset timer")
        }
    }
}

private struct GarageDominantTimerHero: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let durationSeconds: Int
    let elapsedSeconds: Int
    let completionState: GarageFocusCompletionState
    let isTimerRunning: Bool

    private var visualState: FocusHeroVisualState {
        FocusHeroVisualState(
            completionState: completionState,
            isTimerRunning: isTimerRunning,
            elapsedSeconds: elapsedSeconds
        )
    }

    private var style: FocusHeroStyle {
        visualState.style
    }

    private var progress: Double {
        focusRoomTimerProgress(elapsedSeconds: elapsedSeconds, durationSeconds: durationSeconds)
    }

    private var progressPercentText: String {
        "\(Int((progress * 100).rounded()))% complete"
    }

    private var statusText: String {
        switch visualState {
        case .completed:
            return "Confirmed"
        case .running:
            return "Running"
        case .paused:
            return "Paused"
        case .skipped:
            return "Skipped"
        case .idle:
            return "Timer"
        }
    }

    private var accessibilityValue: String {
        [
            "\(formattedTime(elapsedSeconds)) elapsed",
            "of \(formattedTime(durationSeconds))",
            statusText,
            progressPercentText
        ].joined(separator: ". ")
    }

    var body: some View {
        GeometryReader { proxy in
            let diameter = max(min(proxy.size.width - 8, proxy.size.height - 4), 1)

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                FocusRoomPalette.panel.opacity(0.98),
                                FocusRoomPalette.backgroundLift.opacity(0.76),
                                Color.black.opacity(0.2)
                            ],
                            center: .center,
                            startRadius: diameter * 0.12,
                            endRadius: diameter * 0.54
                        )
                    )

                Circle()
                    .stroke(FocusRoomPalette.green.opacity(style.trackOpacity), lineWidth: style.ringLineWidth)
                    .padding(style.ringLineWidth / 2)

                Circle()
                    .trim(from: 0, to: max(progress, 0.035))
                    .stroke(
                        visualState == .completed ? FocusRoomPalette.green.opacity(style.ringOpacity) : FocusRoomPalette.yellow.opacity(style.ringOpacity),
                        style: StrokeStyle(lineWidth: style.ringLineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .padding(style.ringLineWidth / 2)
                    .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.86), value: progress)
                    .overlay {
                        if style.shouldAnimateRing, reduceMotion == false {
                            RunningSweepHighlight(
                                progress: progress,
                                lineWidth: style.ringLineWidth
                            )
                            .padding(style.ringLineWidth / 2)
                        }
                    }

                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    .padding(34)

                Circle()
                    .stroke(Color.black.opacity(0.32), lineWidth: 1)
                    .padding(18)

                VStack(spacing: 8) {
                    Text(formattedTime(elapsedSeconds))
                        .font(style.elapsedFont)
                        .monospacedDigit()
                        .foregroundStyle(FocusRoomPalette.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.52)
                        .shadow(color: FocusRoomPalette.green.opacity(0.2), radius: 10, x: 0, y: 0)

                    Text("Target \(formattedTime(durationSeconds))")
                        .font(style.targetFont)
                        .foregroundStyle(FocusRoomPalette.yellow)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text(statusText)
                        .font(style.statusFont)
                        .textCase(.uppercase)
                        .tracking(1.7)
                        .foregroundStyle(visualState == .paused ? FocusRoomPalette.secondaryText : FocusRoomPalette.green)
                        .lineLimit(1)

                    Text(progressPercentText)
                        .font(style.progressFont)
                        .foregroundStyle(FocusRoomPalette.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 5)
                        .background(Color.black.opacity(0.22), in: Capsule())
                        .overlay(Capsule().stroke(FocusRoomPalette.border, lineWidth: 1))
                }
                .padding(.horizontal, 40)
            }
            .opacity(style.heroOpacity)
            .frame(width: diameter, height: diameter)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 380)
        .shadow(color: FocusRoomPalette.green.opacity(0.26), radius: 28, x: 0, y: 14)
        .shadow(color: Color.black.opacity(0.4), radius: 18, x: 0, y: 12)
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.88), value: visualState)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Focus timer")
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(accessibilityHint)
    }

    private var accessibilityHint: String {
        switch visualState {
        case .running:
            return "Timer is active."
        case .paused:
            return "Timer is paused. Resume is available in the bottom controls."
        case .completed:
            return "Timer is complete. Continue is available below."
        case .skipped:
            return "Current drill was skipped."
        case .idle:
            return "Timer is ready."
        }
    }
}

private struct RunningSweepHighlight: View {
    let progress: Double
    let lineWidth: CGFloat

    @State private var pulse = false

    var body: some View {
        Circle()
            .trim(from: max(progress - 0.055, 0), to: max(progress, 0.035))
            .stroke(
                Color.white.opacity(pulse ? 0.35 : 0.16),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)
            .onAppear {
                pulse = true
            }
    }
}

private struct FocusRoomTeachingSection: View {
    let setupSteps: [String]
    let cueSteps: [String]
    let modeLabel: String
    let durationText: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                FocusRoomBulletBlock(
                    title: "SETUP",
                    tint: FocusRoomPalette.green,
                    steps: Array(setupSteps.prefix(3))
                )
                Divider().overlay(FocusRoomPalette.border.opacity(0.8))
                FocusRoomBulletBlock(
                    title: "STEPS",
                    tint: FocusRoomPalette.yellow,
                    steps: Array(cueSteps.prefix(2))
                )
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            VStack(spacing: 8) {
                FocusRoomMiniMetric(value: modeLabel, title: "Mode", systemImage: "flag")
                FocusRoomMiniMetric(value: durationText, title: "Goal", systemImage: "timer")
            }
            .frame(width: 92)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .background(FocusRoomPalette.panel.opacity(0.48), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct FocusRoomModeTabs: View {
    private let tabs = ["Overview", "Steps", "Keys"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.self) { tab in
                Text(tab)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tab == "Overview" ? FocusRoomPalette.primaryText : FocusRoomPalette.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 38)
                    .background {
                        if tab == "Overview" {
                            Capsule()
                                .fill(FocusRoomPalette.green.opacity(0.18))
                                .overlay(Capsule().stroke(FocusRoomPalette.green.opacity(0.18), lineWidth: 1))
                        }
                    }
            }
        }
        .padding(4)
        .background(Color.black.opacity(0.22), in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.07), lineWidth: 1))
        .accessibilityHidden(true)
    }
}

private struct FocusRoomMiniMetric: View {
    let value: String
    let title: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(FocusRoomPalette.yellow)

            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(FocusRoomPalette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.62)

            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(FocusRoomPalette.secondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 68)
        .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
    }
}

private struct FocusRoomCompletionPrompt: View {
    var body: some View {
        VStack(spacing: 4) {
            Text("Timer complete.")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(FocusRoomPalette.primaryText)

            Text("Log the rep, then move cleanly into the next drill.")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(FocusRoomPalette.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
        .accessibilityElement(children: .combine)
    }
}

private struct FocusRoomNextDrillCard: View {
    let nextDrill: GarageFocusDrillRailItem?
    let action: () -> Void

    private var title: String {
        nextDrill?.title ?? "Finish Routine"
    }

    private var subtitle: String {
        nextDrill?.metadata ?? "Review the session and save the work."
    }

    var body: some View {
        Button {
            garageTriggerImpact(.medium)
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: nextDrill == nil ? "checkmark.seal.fill" : "arrow.forward.circle.fill")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(FocusRoomPalette.background)
                    .frame(width: 44, height: 44)
                    .background(FocusRoomPalette.green, in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.16), lineWidth: 1))
                    .shadow(color: FocusRoomPalette.green.opacity(0.24), radius: 12, x: 0, y: 6)

                VStack(alignment: .leading, spacing: 3) {
                    Text(nextDrill == nil ? "Routine Complete" : "Next Drill")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .textCase(.uppercase)
                        .tracking(1.4)
                        .foregroundStyle(FocusRoomPalette.green)

                    Text(title)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(FocusRoomPalette.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.74)

                    Text(subtitle)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(FocusRoomPalette.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(FocusRoomPalette.secondaryText)
            }
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .background(FocusRoomPalette.panel.opacity(0.62), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(FocusRoomPalette.border.opacity(0.95), lineWidth: 1)
            )
            .shadow(color: FocusRoomPalette.green.opacity(0.16), radius: 18, x: 0, y: 8)
            .shadow(color: Color.black.opacity(0.34), radius: 14, x: 0, y: 10)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(nextDrill == nil ? "Finish routine" : "Next drill, \(title)")
        .accessibilityValue(subtitle)
    }
}

private struct FocusRoomBulletBlock: View {
    let title: String
    let tint: Color
    let steps: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 11, weight: .black))
                .textCase(.uppercase)
                .tracking(1.3)
                .foregroundStyle(tint)

            ForEach(Array(steps.enumerated()), id: \.offset) { _, step in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("•")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(tint)
                    Text(step.garageFocusRoomSentenceTrimmed)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(FocusRoomPalette.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
            }
        }
    }
}

private func formattedTime(_ value: Int) -> String {
    let clampedValue = max(value, 0)
    let minutes = clampedValue / 60
    let seconds = clampedValue % 60
    return "\(minutes):\(String(format: "%02d", seconds))"
}

private func focusRoomTimerProgress(elapsedSeconds: Int, durationSeconds: Int) -> Double {
    let total = max(durationSeconds, 1)
    return min(max(Double(elapsedSeconds) / Double(total), 0), 1)
}

private struct FocusRoomBottomActions: View {
    let noteTitle: String
    let primaryTitle: String
    let primarySystemImage: String
    let onNote: () -> Void
    let onSkip: () -> Void
    let onPrimary: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            HStack(spacing: 8) {
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
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                garageTriggerImpact(.medium)
                onPrimary()
            } label: {
                Image(systemName: primarySystemImage)
                    .font(.system(size: 21, weight: .black))
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(GaragePremiumPalette.emeraldDeep)
                    .frame(width: 58, height: 58)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.86, blue: 0.27),
                                GaragePremiumPalette.gold,
                                GaragePremiumPalette.goldDeep
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: Circle()
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                    .shadow(color: GaragePremiumPalette.gold.opacity(0.34), radius: 14, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(primaryTitle)
            .accessibilityIdentifier("garage-focus-primary")
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 8)
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
        .overlay(alignment: .top) {
            Rectangle()
                .fill(FocusRoomPalette.border.opacity(0.7))
                .frame(height: 1)
        }
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
                .font(.system(size: 13, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.68)
                .foregroundStyle(FocusRoomPalette.primaryText)
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(FocusRoomPalette.panel.opacity(0.78), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
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

    var garageFocusRoomCompactLabel: String {
        garageFocusRoomSentenceTrimmed.garageFocusRoomLimitedWords(4)
    }

    func garageFocusRoomLimitedWords(_ limit: Int) -> String {
        let words = split(whereSeparator: \.isWhitespace).map(String.init)
        guard words.count > limit else {
            return garageFocusRoomSentenceTrimmed
        }
        return words.prefix(limit).joined(separator: " ")
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
                setupSteps: ["Set the station before the first attempt."],
                cueSteps: ["Only count clean executions that match the cue."],
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
        noteTitle: GarageFocusRoomCopy.focusRoomNoteAddCta,
        primaryCtaTitle: GarageFocusRoomCopy.focusRoomMarkCompleteCta,
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
        noteTitle: GarageFocusRoomCopy.focusRoomNoteAddCta,
        primaryCtaTitle: GarageFocusRoomCopy.focusRoomMarkCompleteCta,
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
        noteTitle: GarageFocusRoomCopy.focusRoomNoteAddCta,
        primaryCtaTitle: GarageFocusRoomCopy.focusRoomMarkCompleteCta,
        onSelectRailDrill: { _ in },
        onNote: {},
        onPrimary: { _ in },
        onSkip: { _ in },
        onExitEmptyRoutine: {}
    )
}
