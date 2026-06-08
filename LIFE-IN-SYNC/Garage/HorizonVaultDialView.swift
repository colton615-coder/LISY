import AVFoundation
import SwiftUI
import UIKit

@MainActor
struct GarageTempoBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var audioEngine = ElasticSlingshotAudioEngine()
    @StateObject private var countdownSpeaker = GarageTempoCountdownSpeaker()

    @AppStorage("garage.tempoBuilder.metronomeBPM") private var metronomeBPM = 60.0
    @AppStorage("garage.tempoBuilder.click") private var clickRawValue = GarageMetronomeClickProfile.hardwood.rawValue
    @AppStorage("garage.tempoBuilder.guidedSound") private var guidedRawValue = GarageGuidedSwingProfile.tension.rawValue
    @AppStorage("garage.tempoBuilder.restInterval") private var restInterval = 5.0
    @AppStorage("garage.tempoBuilder.haptics") private var hapticsEnabled = true

    @State private var selectedPage: GarageTempoPage = .metronome
    @State private var presentedSheet: GarageTempoSheet?
    @State private var showsSwingCapture = false
    @State private var playbackStartDate: Date?
    @State private var sessionState = GarageTempoSessionState.ready
    @State private var appliedBPM = 60.0
    @State private var countdownValue: Int?
    @State private var hasPendingTempo = false
    @State private var playbackTask: Task<Void, Never>?
    @State private var hapticTask: Task<Void, Never>?

    private var isActive: Bool { sessionState == .countingIn || sessionState == .playing }
    private var isRunning: Bool { sessionState == .playing }
    private var activeSavedBPM: Double { metronomeBPM }

    private var selectedClick: GarageMetronomeClickProfile {
        GarageMetronomeClickProfile(rawValue: clickRawValue) ?? .hardwood
    }

    private var selectedGuidedSound: GarageGuidedSwingProfile {
        GarageGuidedSwingProfile(rawValue: guidedRawValue) ?? .tension
    }

    private var recipe: ElasticSlingshotRecipe {
        var recipe = ElasticSlingshotRecipe()
        recipe.restInterval = restInterval
        recipe.subdivisionMultiplier = 1
        return recipe
    }

    var body: some View {
        ZStack {
            GarageTempoBackground()

            VStack(spacing: 0) {
                GarageTempoTopBar(
                    controlsEnabled: isActive == false,
                    onBack: close,
                    onCapture: { showsSwingCapture = true },
                    onSettings: { presentedSheet = .settings }
                )

                TabView(selection: $selectedPage) {
                    GarageMetronomePage(
                        beatsPerMinute: $metronomeBPM,
                        appliedBPM: appliedBPM,
                        sessionState: selectedPage == .metronome ? sessionState : .ready,
                        playbackStartDate: playbackStartDate,
                        reduceMotion: reduceMotion,
                        hasPendingTempo: hasPendingTempo,
                        onStart: startPlayback,
                        onPause: pausePlayback,
                        onStop: stopPlayback
                    )
                    .tag(GarageTempoPage.metronome)

                    GarageGuidedSwingPage(
                        beatsPerMinute: $metronomeBPM,
                        appliedBPM: appliedBPM,
                        recipe: recipe,
                        sessionState: selectedPage == .guidedSwing ? sessionState : .ready,
                        playbackStartDate: playbackStartDate,
                        reduceMotion: reduceMotion,
                        countdownValue: countdownValue,
                        hasPendingTempo: hasPendingTempo,
                        onStart: startPlayback,
                        onPause: pausePlayback,
                        onStop: stopPlayback
                    )
                    .tag(GarageTempoPage.guidedSwing)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .scrollDisabled(isActive)

                GarageTempoPageIndicator(selectedPage: selectedPage)
                    .padding(.bottom, 14)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedPage)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: sessionState)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: countdownValue)
        .onChange(of: selectedPage) { _, _ in
            stopPlayback()
        }
        .onChange(of: metronomeBPM) { _, _ in tempoChanged() }
        .fullScreenCover(isPresented: Binding(
            get: { presentedSheet == .settings },
            set: { if $0 == false { presentedSheet = nil } }
        )) {
            GarageTempoControlRoom(
                page: selectedPage,
                beatsPerMinute: metronomeBPM,
                selectedGuidedRawValue: $guidedRawValue,
                restInterval: $restInterval,
                hapticsEnabled: $hapticsEnabled,
                recipe: recipe
            )
        }
        .fullScreenCover(isPresented: $showsSwingCapture) {
            SwingCaptureView { _ in
                showsSwingCapture = false
            } onCancel: {
                showsSwingCapture = false
            }
        }
        .onDisappear {
            stopPlayback()
        }
        .navigationBarBackButtonHidden(true)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func startPlayback() {
        playbackTask?.cancel()
        countdownSpeaker.stop()
        appliedBPM = activeSavedBPM
        hasPendingTempo = false
        if selectedPage == .guidedSwing {
            startGuidedCountIn()
        } else {
            startEngine()
        }
    }

    private func startEngine() {
        audioEngine.start(
            beatsPerMinute: appliedBPM,
            recipe: recipe,
            soundProfile: selectedGuidedSound.engineProfile,
            metronomeClickProfile: selectedClick,
            guidedClicksEnabled: false,
            instrumentMode: selectedPage.instrumentMode
        )
        guard audioEngine.playbackState == .playing else {
            sessionState = .ready
            return
        }
        playbackStartDate = Date()
        countdownValue = nil
        sessionState = .playing
        startRunningHaptics()
        schedulePendingTempoIfNeeded()
    }

    private func startGuidedCountIn() {
        sessionState = .countingIn
        playbackStartDate = nil
        playbackTask = Task { @MainActor in
            for value in [3, 2, 1] {
                guard Task.isCancelled == false else { return }
                countdownValue = value
                countdownSpeaker.speak(value)
                triggerHaptic(.light)
                try? await Task.sleep(nanoseconds: 850_000_000)
            }
            guard Task.isCancelled == false else { return }
            startEngine()
        }
    }

    private func pausePlayback() {
        playbackTask?.cancel()
        playbackTask = nil
        countdownSpeaker.stop()
        countdownValue = nil
        hapticTask?.cancel()
        hapticTask = nil
        audioEngine.stop()
        playbackStartDate = nil
        sessionState = .paused
    }

    private func stopPlayback() {
        playbackTask?.cancel()
        playbackTask = nil
        countdownSpeaker.stop()
        countdownValue = nil
        hapticTask?.cancel()
        hapticTask = nil
        audioEngine.stop()
        playbackStartDate = nil
        sessionState = .ready
        hasPendingTempo = false
    }

    private func tempoChanged() {
        guard isRunning else {
            appliedBPM = activeSavedBPM
            return
        }
        hasPendingTempo = true
        schedulePendingTempoIfNeeded()
    }

    private func schedulePendingTempoIfNeeded() {
        guard isRunning, hasPendingTempo, let playbackStartDate else { return }
        playbackTask?.cancel()
        let cycleDuration = selectedPage == .guidedSwing
            ? recipe.loopDuration(for: appliedBPM)
            : (60 / max(appliedBPM, 1)) * 4
        let elapsed = Date().timeIntervalSince(playbackStartDate)
        let remaining = cycleDuration - elapsed.truncatingRemainder(dividingBy: cycleDuration)
        playbackTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(max(remaining, 0.01) * 1_000_000_000))
            guard Task.isCancelled == false, sessionState == .playing else { return }
            appliedBPM = activeSavedBPM
            audioEngine.update(
                beatsPerMinute: appliedBPM,
                recipe: recipe,
                soundProfile: selectedGuidedSound.engineProfile,
                metronomeClickProfile: selectedClick,
                guidedClicksEnabled: false,
                instrumentMode: selectedPage.instrumentMode
            )
            self.playbackStartDate = Date()
            hasPendingTempo = false
            startRunningHaptics()
        }
    }

    private func startRunningHaptics() {
        hapticTask?.cancel()
        guard hapticsEnabled else { return }
        let page = selectedPage
        let bpm = appliedBPM
        hapticTask = Task { @MainActor in
            while Task.isCancelled == false, sessionState == .playing {
                if page == .metronome {
                    triggerHaptic(.light)
                    try? await Task.sleep(nanoseconds: UInt64((60 / max(bpm, 1)) * 1_000_000_000))
                } else {
                    let topDelay = recipe.takeawayDuration(for: bpm)
                    let impactDelay = recipe.pauseDuration(for: bpm) + recipe.downswingDuration(for: bpm)
                    let resetDelay = 0.08 + recipe.restInterval
                    try? await Task.sleep(nanoseconds: UInt64(topDelay * 1_000_000_000))
                    guard Task.isCancelled == false else { return }
                    triggerHaptic(.light)
                    try? await Task.sleep(nanoseconds: UInt64(impactDelay * 1_000_000_000))
                    guard Task.isCancelled == false else { return }
                    triggerHaptic(.rigid)
                    try? await Task.sleep(nanoseconds: UInt64(resetDelay * 1_000_000_000))
                }
            }
        }
    }

    private func triggerHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    private func close() {
        stopPlayback()
        dismiss()
    }
}

private enum GarageTempoPage: String, CaseIterable, Identifiable {
    case metronome
    case guidedSwing

    var id: String { rawValue }

    var instrumentMode: GarageTempoInstrumentMode {
        switch self {
        case .metronome: .metronome
        case .guidedSwing: .build
        }
    }
}

private enum GarageTempoSheet: String, Identifiable {
    case settings

    var id: String { rawValue }
}

private enum GarageTempoSessionState: Equatable {
    case ready
    case countingIn
    case playing
    case paused
}

@MainActor
private final class GarageTempoCountdownSpeaker: ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ value: Int) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: "\(value)")
        utterance.rate = 0.46
        utterance.pitchMultiplier = 0.92
        utterance.volume = 0.9
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}

private struct GarageTempoTopBar: View {
    let controlsEnabled: Bool
    let onBack: () -> Void
    let onCapture: () -> Void
    let onSettings: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            GarageTempoIconButton(systemImage: "chevron.left", label: "Back", action: onBack)

            Spacer()

            Text("Tempo Builder")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(GarageProTheme.textPrimary)

            Spacer()

            HStack(spacing: 6) {
                GarageTempoIconButton(systemImage: "camera.fill", label: "Swing capture", action: onCapture)
                GarageTempoIconButton(systemImage: "slider.horizontal.3", label: "Control Room", action: onSettings)
            }
            .disabled(controlsEnabled == false)
            .opacity(controlsEnabled ? 1 : 0.34)
        }
        .frame(height: 46)
    }
}

private struct GarageMetronomePage: View {
    @Binding var beatsPerMinute: Double
    let appliedBPM: Double
    let sessionState: GarageTempoSessionState
    let playbackStartDate: Date?
    let reduceMotion: Bool
    let hasPendingTempo: Bool
    let onStart: () -> Void
    let onPause: () -> Void
    let onStop: () -> Void

    private var isPlaying: Bool { sessionState == .playing }

    var body: some View {
        VStack(spacing: 0) {
            GarageTempoPageTitle(
                title: "Metronome",
                subtitle: isPlaying ? "Golf-rhythm click running." : "Steady golf-rhythm click."
            )
                .padding(.top, 18)

            Spacer(minLength: 12)

            TimelineView(.animation(minimumInterval: reduceMotion ? 0.15 : 1 / 60, paused: isPlaying == false)) { timeline in
                GarageTempoPendulum(
                    progress: progress(at: timeline.date),
                    isPlaying: isPlaying,
                    reduceMotion: reduceMotion
                )
            }
            .frame(maxWidth: .infinity)
            .frame(height: 320)

            Spacer(minLength: 8)

            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text("\(Int(beatsPerMinute.rounded()))")
                    .font(.system(size: 58, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(GarageProTheme.textPrimary)

                Text("BPM")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(GaragePremiumPalette.gold)
                    .padding(.bottom, 9)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(Int(beatsPerMinute.rounded())) beats per minute")

            Text(hasPendingTempo ? "APPLIES NEXT CYCLE" : isPlaying ? "GOLF RHYTHM LOOP" : "TEMPO SPEED")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.6)
                .foregroundStyle(isPlaying || hasPendingTempo ? GaragePremiumPalette.gold : GarageProTheme.textSecondary)
                .padding(.top, 2)

            Slider(value: $beatsPerMinute, in: 40...120, step: 1)
                .tint(GaragePremiumPalette.gold)
                .padding(.horizontal, 8)
                .accessibilityLabel("Metronome tempo")

            GarageTempoSessionControls(
                state: sessionState,
                onStart: onStart,
                onPause: onPause,
                onStop: onStop
            )
                .padding(.top, 14)
                .padding(.bottom, 10)
        }
    }

    private func progress(at date: Date) -> Double {
        guard isPlaying, let playbackStartDate else { return 0.25 }
        let golfRhythmCycle = (60 / max(appliedBPM, 1)) * 4
        return date.timeIntervalSince(playbackStartDate).truncatingRemainder(dividingBy: golfRhythmCycle) / golfRhythmCycle
    }
}

private struct GarageGuidedSwingPage: View {
    @Binding var beatsPerMinute: Double
    let appliedBPM: Double
    let recipe: ElasticSlingshotRecipe
    let sessionState: GarageTempoSessionState
    let playbackStartDate: Date?
    let reduceMotion: Bool
    let countdownValue: Int?
    let hasPendingTempo: Bool
    let onStart: () -> Void
    let onPause: () -> Void
    let onStop: () -> Void

    private var isPlaying: Bool { sessionState == .playing }

    var body: some View {
        VStack(spacing: 0) {
            GarageTempoPageTitle(
                title: "Guided Swing",
                subtitle: subtitle
            )
                .padding(.top, 18)

            Spacer(minLength: 12)

            TimelineView(.animation(minimumInterval: reduceMotion ? 0.15 : 1 / 60, paused: isPlaying == false)) { timeline in
                GarageGuidedSwingTimeline(
                    state: visualState(at: timeline.date),
                    isPlaying: isPlaying,
                    reduceMotion: reduceMotion,
                    countdownValue: countdownValue
                )
            }
            .frame(maxWidth: .infinity)
            .frame(height: 250)

            Spacer(minLength: 12)

            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text("\(Int(beatsPerMinute.rounded()))")
                    .font(.system(size: 58, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(GarageProTheme.textPrimary)

                Text("BPM")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(GaragePremiumPalette.gold)
                    .padding(.bottom, 9)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(Int(beatsPerMinute.rounded())) beats per minute, saved swing tempo")

            Text(hasPendingTempo ? "APPLIES NEXT SWING" : sessionState == .countingIn ? "START CUE" : "SAVED SWING TEMPO")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(hasPendingTempo || sessionState == .countingIn ? GaragePremiumPalette.gold : GarageProTheme.textSecondary)
                .padding(.top, 2)

            Slider(value: $beatsPerMinute, in: 40...120, step: 1)
                .tint(GaragePremiumPalette.gold)
                .padding(.horizontal, 8)
                .disabled(sessionState == .countingIn)
                .accessibilityLabel("Guided Swing tempo")

            GarageTempoSessionControls(
                state: sessionState,
                onStart: onStart,
                onPause: onPause,
                onStop: onStop
            )
                .padding(.top, 14)
                .padding(.bottom, 10)
        }
    }

    private var subtitle: String {
        switch sessionState {
        case .countingIn:
            "Get ready."
        case .playing:
            "Follow the build to impact."
        case .ready, .paused:
            "Press Start. Move after the countdown."
        }
    }

    private func visualState(at date: Date) -> GarageSlowTempoVisualState {
        let elapsed = playbackStartDate.map { date.timeIntervalSince($0) } ?? 0
        return recipe.slowTempoLogic(for: appliedBPM).visualState(
            elapsedTime: elapsed,
            isPlaying: isPlaying,
            recipe: recipe
        )
    }
}

private struct GarageTempoPendulum: View {
    let progress: Double
    let isPlaying: Bool
    let reduceMotion: Bool

    private var angle: Angle {
        guard isPlaying else { return .degrees(-29) }
        guard reduceMotion == false else { return .degrees(0) }

        if progress < 0.75 {
            let backswingProgress = progress / 0.75
            return .degrees(-29 + (29 * smoothstep(backswingProgress)))
        }

        let downswingProgress = min((progress - 0.75) / 0.22, 1)
        return .degrees(29 * smoothstep(downswingProgress))
    }

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(
                    isPlaying
                        ? GaragePremiumPalette.emeraldGlass.opacity(0.72)
                        : GarageProTheme.elevatedSurface.opacity(0.72)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(
                            isPlaying ? GaragePremiumPalette.gold.opacity(0.34) : GarageProTheme.border,
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: isPlaying ? GaragePremiumPalette.gold.opacity(0.14) : GarageProTheme.darkShadow,
                    radius: isPlaying ? 30 : 24,
                    x: 0,
                    y: 18
                )

            ZStack(alignment: .top) {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [GaragePremiumPalette.gold, GaragePremiumPalette.goldDeep],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 5, height: 218)
                    .shadow(color: GaragePremiumPalette.gold.opacity(0.22), radius: 10)

                Circle()
                    .fill(GaragePremiumPalette.gold)
                    .frame(width: 24, height: 24)
                    .overlay(Circle().stroke(Color.white.opacity(0.34), lineWidth: 1))

                Circle()
                    .fill(GaragePremiumPalette.emeraldDeep)
                    .frame(width: 58, height: 58)
                    .overlay(Circle().stroke(GaragePremiumPalette.gold.opacity(0.54), lineWidth: 2))
                    .shadow(color: GaragePremiumPalette.gold.opacity(isPlaying ? 0.28 : 0.12), radius: 16)
                    .offset(y: 190)
            }
            .frame(height: 252, alignment: .top)
            .rotationEffect(angle, anchor: .top)
            .padding(.top, 26)

            Circle()
                .fill(GaragePremiumPalette.gold)
                .frame(width: 12, height: 12)
                .shadow(color: GaragePremiumPalette.gold.opacity(0.36), radius: 8)
                .padding(.top, 20)

            VStack {
                HStack {
                    Text(isPlaying ? "LIVE GOLF RHYTHM" : "GOLF RHYTHM")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(isPlaying ? GaragePremiumPalette.gold : GarageProTheme.textSecondary)

                    Spacer()

                    Circle()
                        .fill(isPlaying ? GaragePremiumPalette.gold : GarageProTheme.textSecondary.opacity(0.32))
                        .frame(width: 7, height: 7)
                        .shadow(color: GaragePremiumPalette.gold.opacity(isPlaying ? 0.5 : 0), radius: 8)
                }

                Spacer()

                GarageTempoPhaseRail(progress: progress, isPlaying: isPlaying)
            }
            .padding(22)
        }
        .accessibilityHidden(true)
    }

    private func smoothstep(_ value: Double) -> Double {
        let clamped = min(max(value, 0), 1)
        return clamped * clamped * (3 - (2 * clamped))
    }
}

private struct GarageTempoPhaseRail: View {
    let progress: Double
    let isPlaying: Bool

    private let phases = ["Start", "Top", "Impact"]

    private var activePhase: Int {
        guard isPlaying else { return 0 }
        if progress < 0.70 { return 0 }
        if progress < 0.94 { return 1 }
        return 2
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(phases.enumerated()), id: \.offset) { index, phase in
                HStack(spacing: 8) {
                    VStack(spacing: 5) {
                        Circle()
                            .fill(index == activePhase ? GaragePremiumPalette.gold : GaragePremiumPalette.mintText.opacity(0.46))
                            .frame(width: index == activePhase ? 8 : 6, height: index == activePhase ? 8 : 6)

                        Text(phase)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(index == activePhase ? GaragePremiumPalette.gold : GarageProTheme.textSecondary)
                    }

                    if index < phases.count - 1 {
                        Capsule()
                            .fill(GaragePremiumPalette.mintText.opacity(0.12))
                            .frame(maxWidth: .infinity)
                            .frame(height: 1)
                    }
                }
            }
        }
    }
}

private struct GarageGuidedSwingTimeline: View {
    let state: GarageSlowTempoVisualState
    let isPlaying: Bool
    let reduceMotion: Bool
    let countdownValue: Int?

    var body: some View {
        GeometryReader { proxy in
            let lineStart = proxy.size.width * 0.10
            let lineEnd = proxy.size.width * 0.90
            let lineY = proxy.size.height * 0.52
            let progress = state.isResting ? 0 : min(max(state.cycleProgress, 0), 1)
            let markerX = lineStart + ((lineEnd - lineStart) * progress)
            let impactActive = isPlaying && state.activeBeat == 3 && state.isResting == false

            ZStack {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(
                        isPlaying
                            ? GaragePremiumPalette.emeraldGlass.opacity(0.72)
                            : GarageProTheme.elevatedSurface.opacity(0.68)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 34, style: .continuous)
                            .stroke(
                                isPlaying ? GaragePremiumPalette.gold.opacity(0.34) : GarageProTheme.border,
                                lineWidth: 1
                            )
                    )
                    .shadow(
                        color: isPlaying ? GaragePremiumPalette.gold.opacity(0.14) : GarageProTheme.darkShadow,
                        radius: isPlaying ? 30 : 24,
                        x: 0,
                        y: 18
                    )

                Capsule()
                    .fill(GaragePremiumPalette.mintText.opacity(0.22))
                    .frame(width: lineEnd - lineStart, height: 3)
                    .position(x: proxy.size.width / 2, y: lineY)

                if isPlaying, state.isResting == false {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [GaragePremiumPalette.emerald, GaragePremiumPalette.gold],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max((lineEnd - lineStart) * progress, 3), height: 5)
                        .position(x: lineStart + max((lineEnd - lineStart) * progress, 3) / 2, y: lineY)

                    Circle()
                        .fill(GaragePremiumPalette.gold)
                        .frame(width: reduceMotion ? 18 : 22, height: reduceMotion ? 18 : 22)
                        .shadow(color: GaragePremiumPalette.gold.opacity(0.46), radius: 18)
                        .position(x: markerX, y: lineY)
                } else if isPlaying == false {
                    Circle()
                        .fill(GaragePremiumPalette.gold.opacity(0.82))
                        .frame(width: 18, height: 18)
                        .shadow(color: GaragePremiumPalette.gold.opacity(0.24), radius: 12)
                        .position(x: lineStart, y: lineY)
                }

                GarageGuidedSwingLandmark(title: "Start", isActive: state.activeBeat == 1 && state.isResting == false, alignment: .leading)
                    .position(x: lineStart, y: lineY + 38)
                GarageGuidedSwingLandmark(title: "Top", isActive: state.activeBeat == 2 && state.isResting == false, alignment: .center)
                    .position(x: lineStart + ((lineEnd - lineStart) * 0.72), y: lineY + 38)
                GarageGuidedSwingLandmark(title: "Impact", isActive: impactActive, alignment: .trailing)
                    .position(x: lineEnd, y: lineY + 38)

                Circle()
                    .fill(GaragePremiumPalette.gold.opacity(impactActive ? 0.18 : 0))
                    .frame(width: impactActive && reduceMotion == false ? 72 : 18, height: impactActive && reduceMotion == false ? 72 : 18)
                    .position(x: lineEnd, y: lineY)

                Circle()
                    .stroke(GaragePremiumPalette.gold.opacity(impactActive ? 0.92 : 0), lineWidth: 4)
                    .frame(width: impactActive && reduceMotion == false ? 58 : 18, height: impactActive && reduceMotion == false ? 58 : 18)
                    .position(x: lineEnd, y: lineY)
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: impactActive)

                VStack(spacing: 3) {
                    Text(countdownValue.map { String($0) } ?? (isPlaying ? state.phaseLabel.uppercased() : "GUIDED SWING"))
                        .font(.system(size: countdownValue == nil ? 11 : 46, weight: .bold, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(GaragePremiumPalette.gold)

                    if countdownValue != nil {
                        Text("MOVE AFTER 1")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(1.3)
                            .foregroundStyle(GarageProTheme.textSecondary)
                    } else if isPlaying {
                        Text(state.phaseCue)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(GarageProTheme.textSecondary)
                    }
                }
                .multilineTextAlignment(.center)
                .position(x: proxy.size.width / 2, y: proxy.size.height * 0.22)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            countdownValue.map { "Guided swing countdown, \($0)" }
                ?? (isPlaying ? "Guided swing running, \(state.phaseLabel)" : "Guided swing ready")
        )
    }
}

private struct GarageGuidedSwingLandmark: View {
    let title: String
    let isActive: Bool
    let alignment: HorizontalAlignment

    var body: some View {
        VStack(alignment: alignment, spacing: 4) {
            Circle()
                .fill(isActive ? GaragePremiumPalette.gold : GaragePremiumPalette.mintText.opacity(0.42))
                .frame(width: isActive ? 11 : 7, height: isActive ? 11 : 7)
                .shadow(color: GaragePremiumPalette.gold.opacity(isActive ? 0.6 : 0), radius: 12)

            Text(title)
                .font(.system(size: 11, weight: isActive ? .bold : .semibold, design: .rounded))
                .foregroundStyle(isActive ? GaragePremiumPalette.gold : GarageProTheme.textSecondary)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isActive)
    }
}

private struct GarageTempoPageTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 5) {
            Text(title)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(GarageProTheme.textPrimary)

            Text(subtitle)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(GarageProTheme.textSecondary)
        }
        .multilineTextAlignment(.center)
    }
}

private struct GarageTempoSessionControls: View {
    let state: GarageTempoSessionState
    let onStart: () -> Void
    let onPause: () -> Void
    let onStop: () -> Void

    var body: some View {
        if state == .ready || state == .paused {
            Button(action: onStart) {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 15, weight: .black))

                    Text(state == .paused ? "Resume" : "Start")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                }
                .foregroundStyle(GaragePremiumPalette.emeraldDeep)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(GaragePremiumPalette.gold)
                        .shadow(color: GaragePremiumPalette.gold.opacity(0.24), radius: 14, x: 0, y: 8)
                )
            }
            .buttonStyle(.plain)
        } else {
            HStack(spacing: 10) {
                GarageTempoSecondaryAction(title: "Pause", systemImage: "pause.fill", action: onPause)
                GarageTempoSecondaryAction(title: "Stop", systemImage: "stop.fill", action: onStop)
            }
        }
    }
}

private struct GarageTempoSecondaryAction: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(title == "Stop" ? GaragePremiumPalette.gold : GarageProTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(GarageProTheme.insetSurface.opacity(0.86), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(GarageProTheme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct GarageTempoPageIndicator: View {
    let selectedPage: GarageTempoPage

    var body: some View {
        HStack(spacing: 12) {
            ForEach(GarageTempoPage.allCases) { page in
                HStack(spacing: 5) {
                    Circle()
                        .fill(page == selectedPage ? GaragePremiumPalette.gold : GarageProTheme.textSecondary.opacity(0.28))
                        .frame(width: 5, height: 5)

                    Text(page == .metronome ? "Metronome" : "Guided Swing")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(page == selectedPage ? GaragePremiumPalette.gold : GarageProTheme.textSecondary)
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedPage)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(selectedPage == .metronome ? "Metronome page, one of two" : "Guided Swing page, two of two")
    }
}

private struct GarageTempoIconButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(GarageProTheme.textPrimary.opacity(0.86))
                .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

private struct GarageGuidedSoundLibrary: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedRawValue: String
    let beatsPerMinute: Double
    let recipe: ElasticSlingshotRecipe
    @StateObject private var previewEngine = ElasticSlingshotAudioEngine()

    var body: some View {
        GarageTempoSheetScaffold(title: "Swing Sounds", onDone: { dismiss() }) {
            VStack(spacing: 12) {
                ForEach(GarageGuidedSwingProfile.allCases) { profile in
                    GarageTempoSoundTile(
                        title: profile.title,
                        subtitle: profile.character,
                        isSelected: selectedRawValue == profile.rawValue
                    ) {
                        selectedRawValue = profile.rawValue
                        previewEngine.playOneCycle(
                            beatsPerMinute: beatsPerMinute,
                            recipe: recipe,
                            soundProfile: profile.engineProfile,
                            metronomeClickProfile: .hardwood,
                            guidedClicksEnabled: false,
                            instrumentMode: .build
                        )
                    }
                }
            }
        }
        .onDisappear { previewEngine.stop() }
    }
}

private struct GarageTempoControlRoom: View {
    @Environment(\.dismiss) private var dismiss
    let page: GarageTempoPage
    let beatsPerMinute: Double
    @Binding var selectedGuidedRawValue: String
    @Binding var restInterval: Double
    @Binding var hapticsEnabled: Bool
    let recipe: ElasticSlingshotRecipe
    @StateObject private var previewEngine = ElasticSlingshotAudioEngine()
    @State private var showsSoundLibrary = false

    private var selectedGuidedSound: GarageGuidedSwingProfile {
        GarageGuidedSwingProfile(rawValue: selectedGuidedRawValue) ?? .tension
    }

    var body: some View {
        ZStack {
            GarageTempoBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Control Room")
                                .font(.system(size: 28, weight: .semibold, design: .rounded))
                                .foregroundStyle(GarageProTheme.textPrimary)
                            Text(page == .guidedSwing ? "Guided Swing" : "Metronome")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(GaragePremiumPalette.gold)
                        }

                        Spacer()

                        Button("Done") { dismiss() }
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(GaragePremiumPalette.gold)
                    }

                    GarageTempoSettingsGroup {
                        GarageTempoReadbackRow(
                            title: "Active BPM",
                            value: "\(Int(beatsPerMinute.rounded())) BPM"
                        )
                    }

                    if page == .guidedSwing {
                        GarageTempoSettingsGroup {
                            GarageTempoActionValueRow(title: "Sound Style", value: selectedGuidedSound.title) {
                                showsSoundLibrary = true
                            }
                            GarageTempoSettingsDivider()
                            GarageTempoActionRow(title: "Preview Guided Swing", systemImage: "play.fill") {
                                previewEngine.playOneCycle(
                                    beatsPerMinute: beatsPerMinute,
                                    recipe: recipe,
                                    soundProfile: selectedGuidedSound.engineProfile,
                                    metronomeClickProfile: .hardwood,
                                    guidedClicksEnabled: false,
                                    instrumentMode: .build
                                )
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("REST BETWEEN SWINGS")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .tracking(1.2)
                                .foregroundStyle(GarageProTheme.textSecondary)

                            HStack(spacing: 8) {
                                ForEach([3.0, 5.0, 8.0, 10.0], id: \.self) { interval in
                                    Button {
                                        restInterval = interval
                                    } label: {
                                        Text("\(Int(interval))s")
                                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                                            .foregroundStyle(restInterval == interval ? GaragePremiumPalette.emeraldDeep : GarageProTheme.textPrimary)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 46)
                                            .background(restInterval == interval ? GaragePremiumPalette.gold : GarageProTheme.insetSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        GarageTempoSettingsGroup {
                            GarageTempoReadbackRow(title: "Start Cue", value: "Three clean ticks")
                        }
                    } else {
                        GarageTempoSettingsGroup {
                            GarageTempoActionRow(title: "Preview Click", systemImage: "play.fill") {
                                previewEngine.playOneCycle(
                                    beatsPerMinute: beatsPerMinute,
                                    recipe: recipe,
                                    soundProfile: .elastic,
                                    metronomeClickProfile: .hardwood,
                                    guidedClicksEnabled: false,
                                    instrumentMode: .metronome
                                )
                            }
                        }
                    }

                    GarageTempoSettingsGroup {
                        Toggle("Haptics", isOn: $hapticsEnabled)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(GarageProTheme.textPrimary)
                            .tint(GaragePremiumPalette.gold)
                            .padding(16)
                    }
                }
                .padding(20)
                .padding(.bottom, 28)
            }
        }
        .onDisappear { previewEngine.stop() }
        .sheet(isPresented: $showsSoundLibrary) {
            GarageGuidedSoundLibrary(
                selectedRawValue: $selectedGuidedRawValue,
                beatsPerMinute: beatsPerMinute,
                recipe: recipe
            )
        }
    }
}

private struct GarageTempoSettingsGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(GarageProTheme.insetSurface.opacity(0.78), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(GarageProTheme.border, lineWidth: 1))
    }
}

private struct GarageTempoReadbackRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(GarageProTheme.textPrimary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(GaragePremiumPalette.gold)
        }
        .padding(16)
    }
}

private struct GarageTempoActionRow: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(GarageProTheme.textPrimary)
                Spacer()
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(GaragePremiumPalette.gold)
            }
            .padding(16)
        }
        .buttonStyle(.plain)
    }
}

private struct GarageTempoActionValueRow: View {
    let title: String
    let value: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(GarageProTheme.textPrimary)
                Spacer()
                Text(value)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(GaragePremiumPalette.gold)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(GarageProTheme.textSecondary)
            }
            .padding(16)
        }
        .buttonStyle(.plain)
    }
}

private struct GarageTempoSettingsDivider: View {
    var body: some View {
        Divider()
            .overlay(GarageProTheme.border)
            .padding(.leading, 16)
    }
}

private struct GarageTempoSheetScaffold<Content: View>: View {
    let title: String
    let onDone: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            GarageTempoBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Text(title)
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                            .foregroundStyle(GarageProTheme.textPrimary)

                        Spacer()

                        Button("Done", action: onDone)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(GaragePremiumPalette.gold)
                    }

                    content
                }
                .padding(20)
                .padding(.bottom, 18)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

private struct GarageTempoSoundTile: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "waveform")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(GaragePremiumPalette.gold)

                    Spacer()

                    Circle()
                        .fill(isSelected ? GaragePremiumPalette.gold : GarageProTheme.textSecondary.opacity(0.22))
                        .frame(width: 8, height: 8)
                }

                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(GarageProTheme.textPrimary)

                Text(subtitle)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(GarageProTheme.textSecondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
            .padding(14)
            .background(
                isSelected ? GaragePremiumPalette.gold.opacity(0.10) : GarageProTheme.insetSurface.opacity(0.76),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? GaragePremiumPalette.gold.opacity(0.42) : GarageProTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint("Plays a preview")
    }
}

private struct GarageTempoBackground: View {
    var body: some View {
        ZStack {
            GarageProTheme.background

            LinearGradient(
                colors: [
                    GaragePremiumPalette.emeraldDeep.opacity(0.74),
                    GarageProTheme.background,
                    Color(red: 0.008, green: 0.012, blue: 0.011)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

#Preview("Tempo Builder Reset") {
    NavigationStack {
        GarageTempoBuilderView()
    }
}
