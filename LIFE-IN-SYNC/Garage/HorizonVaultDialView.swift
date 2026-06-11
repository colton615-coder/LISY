import AVFoundation
import Combine
import SwiftUI
import UIKit

@MainActor
struct GarageTempoBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var audioEngine = ElasticSlingshotAudioEngine()
    @StateObject private var countdownSpeaker = GarageTempoCountdownSpeaker()

    @AppStorage("garage.tempoBuilder.metronomeBPM") private var metronomeBPM = 60.0
    @AppStorage("garage.tempoBuilder.bpm") private var guidedSwingBPM = 60.0
    @AppStorage("garage.tempoBuilder.metronomeStartSound") private var startClickRawValue = GarageMetronomeClickProfile.woodblock.rawValue
    @AppStorage("garage.tempoBuilder.metronomeImpactSound") private var impactClickRawValue = GarageMetronomeClickProfile.brightSignal.rawValue
    @AppStorage("garage.tempoBuilder.guidedSound") private var guidedRawValue = GarageGuidedSwingProfile.tension.rawValue
    @AppStorage("garage.tempoBuilder.restInterval") private var restInterval = 5.0
    @AppStorage("garage.tempoBuilder.haptics") private var hapticsEnabled = true

    @Namespace private var pageSelectorNamespace
    @State private var selectedPage: GarageTempoPage = .metronome
    @State private var presentedSheet: GarageTempoSheet?
    @State private var showsSwingCapture = false
    @State private var sessionState = GarageTempoSessionState.ready
    @State private var appliedBPM = 60.0
    @State private var countdownValue: Int?
    @State private var hasPendingTempo = false
    @State private var playbackTask: Task<Void, Never>?
    @State private var hapticTask: Task<Void, Never>?

    private var isActive: Bool { sessionState != .ready }
    private var isRunning: Bool { sessionState == .playing }
    private var activeSavedBPM: Double {
        selectedPage == .metronome ? metronomeBPM : guidedSwingBPM
    }

    private var selectedStartClick: GarageMetronomeClickProfile {
        GarageMetronomeClickProfile.migrated(from: startClickRawValue)
    }

    private var selectedImpactClick: GarageMetronomeClickProfile {
        GarageMetronomeClickProfile.migrated(from: impactClickRawValue)
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
        tempoContent
            .onAppear {
                migrateSavedClickSound()
                clampSavedTempos()
            }
            .onChange(of: selectedPage) { _, _ in
                stopPlayback()
            }
            .onChange(of: metronomeBPM) { _, _ in tempoChanged() }
            .onChange(of: guidedSwingBPM) { _, _ in tempoChanged() }
            .sheet(isPresented: settingsPresentation) {
                GarageTempoControlRoom(
                    beatsPerMinute: guidedSwingBPM,
                    selectedStartRawValue: $startClickRawValue,
                    selectedImpactRawValue: $impactClickRawValue,
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

    private var tempoContent: some View {
        ZStack {
            GarageTempoBackground()

            VStack(spacing: 0) {
                GarageTempoTopBar(
                    controlsEnabled: isActive == false,
                    onBack: close,
                    onCapture: { showsSwingCapture = true }
                )

                GarageTempoPageSelector(
                    selectedPage: $selectedPage,
                    controlsEnabled: isActive == false,
                    namespace: pageSelectorNamespace
                )
                .padding(.top, 8)

                tempoPages
                .tabViewStyle(.page(indexDisplayMode: .never))
                .scrollDisabled(isActive)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
        }
    }

    private var tempoPages: some View {
        TabView(selection: $selectedPage) {
            GarageMetronomePage(
                beatsPerMinute: $metronomeBPM,
                selectedRawValue: $startClickRawValue,
                hapticsEnabled: $hapticsEnabled,
                recipe: recipe,
                sessionState: selectedPage == .metronome ? sessionState : .ready,
                reduceMotion: reduceMotion,
                hasPendingTempo: hasPendingTempo,
                playbackProgress: { audioEngine.currentPlaybackProgress() },
                onStart: startPlayback,
                onStop: stopPlayback
            )
            .tag(GarageTempoPage.metronome)

            GarageGuidedSwingPage(
                beatsPerMinute: $guidedSwingBPM,
                appliedBPM: appliedBPM,
                recipe: recipe,
                sessionState: selectedPage == .guidedSwing ? sessionState : .ready,
                reduceMotion: reduceMotion,
                countdownValue: countdownValue,
                hasPendingTempo: hasPendingTempo,
                playbackProgress: { audioEngine.currentPlaybackProgress() },
                onStart: startPlayback,
                onPause: pausePlayback,
                onResume: resumePlayback,
                onControlRoom: { presentedSheet = .settings },
                onStop: stopPlayback
            )
            .tag(GarageTempoPage.guidedSwing)
        }
    }

    private var settingsPresentation: Binding<Bool> {
        Binding(
            get: { selectedPage == .guidedSwing && presentedSheet == .settings },
            set: { if $0 == false { presentedSheet = nil } }
        )
    }

    private func startPlayback() {
        playbackTask?.cancel()
        countdownSpeaker.stop()
        appliedBPM = activeSavedBPM
        hasPendingTempo = false
        if selectedPage == .guidedSwing {
            startGuidedSequence()
        } else {
            startMetronome()
        }
    }

    private func clampSavedTempos() {
        metronomeBPM = GarageSlowTempoLogic.clampedConsumerBPM(metronomeBPM)
        guidedSwingBPM = GarageSlowTempoLogic.clampedConsumerBPM(guidedSwingBPM)
        appliedBPM = activeSavedBPM
    }

    private func migrateSavedClickSound() {
        startClickRawValue = GarageMetronomeClickProfile.migrated(from: startClickRawValue).rawValue
    }

    private func startMetronome() {
        audioEngine.start(
            beatsPerMinute: appliedBPM,
            recipe: recipe,
            soundProfile: selectedGuidedSound.engineProfile,
            metronomeStartProfile: selectedStartClick,
            metronomeImpactProfile: selectedImpactClick,
            guidedClicksEnabled: false,
            instrumentMode: .metronome
        )
        guard audioEngine.playbackState == .playing else {
            sessionState = .ready
            return
        }
        countdownValue = nil
        sessionState = .playing
        startRunningHaptics()
    }

    private func startGuidedSequence() {
        playbackTask = Task { @MainActor in
            await runGuidedCountIn()
            guard Task.isCancelled == false else { return }

            while Task.isCancelled == false {
                applyPendingGuidedTempo()
                countdownValue = nil
                sessionState = .playing
                audioEngine.playOneCycle(
                    beatsPerMinute: appliedBPM,
                    recipe: recipe,
                    soundProfile: selectedGuidedSound.engineProfile,
                    metronomeStartProfile: selectedStartClick,
                    metronomeImpactProfile: selectedImpactClick,
                    guidedClicksEnabled: false,
                    instrumentMode: .build
                )
                startRunningHaptics()
                let swingDuration = recipe.swingDuration(for: appliedBPM) + 0.16
                try? await Task.sleep(nanoseconds: UInt64(swingDuration * 1_000_000_000))
                guard Task.isCancelled == false else { return }
                sessionState = .resting
                try? await Task.sleep(nanoseconds: UInt64(restInterval * 1_000_000_000))
                guard Task.isCancelled == false else { return }
            }
        }
    }

    private func runGuidedCountIn() async {
        sessionState = .countingIn
        for value in [3, 2, 1] {
            guard Task.isCancelled == false else { return }
            countdownValue = value
            countdownSpeaker.speak(value)
            triggerHaptic(.light)
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
    }

    private func applyPendingGuidedTempo() {
        guard appliedBPM != guidedSwingBPM else {
            hasPendingTempo = false
            return
        }
        appliedBPM = guidedSwingBPM
        hasPendingTempo = false
    }

    private func pausePlayback() {
        guard selectedPage == .guidedSwing, isActive else { return }
        playbackTask?.cancel()
        playbackTask = nil
        countdownSpeaker.stop()
        countdownValue = nil
        hapticTask?.cancel()
        hapticTask = nil
        audioEngine.stop()
        sessionState = .paused
    }

    private func resumePlayback() {
        guard selectedPage == .guidedSwing, sessionState == .paused else { return }
        appliedBPM = guidedSwingBPM
        hasPendingTempo = false
        startGuidedSequence()
    }

    private func stopPlayback() {
        playbackTask?.cancel()
        playbackTask = nil
        countdownSpeaker.stop()
        countdownValue = nil
        hapticTask?.cancel()
        hapticTask = nil
        audioEngine.stop()
        sessionState = .ready
        hasPendingTempo = false
    }

    private func tempoChanged() {
        guard isActive else {
            appliedBPM = activeSavedBPM
            return
        }
        if selectedPage == .guidedSwing {
            hasPendingTempo = appliedBPM != guidedSwingBPM
            return
        }
        guard isRunning else { return }
        appliedBPM = metronomeBPM
        hasPendingTempo = false
        audioEngine.update(
            beatsPerMinute: appliedBPM,
            recipe: recipe,
            soundProfile: selectedGuidedSound.engineProfile,
            metronomeStartProfile: selectedStartClick,
            metronomeImpactProfile: selectedImpactClick,
            guidedClicksEnabled: false,
            instrumentMode: .metronome
        )
    }

    private func startRunningHaptics() {
        hapticTask?.cancel()
        guard hapticsEnabled else { return }
        let page = selectedPage
        let bpm = appliedBPM
        hapticTask = Task { @MainActor in
            var lastMetronomeBeatIndex = -1
            while Task.isCancelled == false, sessionState == .playing {
                if page == .metronome {
                    let progress = audioEngine.currentPlaybackProgress()
                    let beatIndex = min(Int(floor(progress * 4)), 3)
                    if beatIndex != lastMetronomeBeatIndex {
                        lastMetronomeBeatIndex = beatIndex
                        triggerHaptic(.light)
                    }
                    try? await Task.sleep(nanoseconds: 8_000_000)
                } else {
                    let topDelay = recipe.takeawayDuration(for: bpm)
                    let impactDelay = recipe.pauseDuration(for: bpm) + recipe.downswingDuration(for: bpm)
                    try? await Task.sleep(nanoseconds: UInt64(topDelay * 1_000_000_000))
                    guard Task.isCancelled == false else { return }
                    triggerHaptic(.light)
                    try? await Task.sleep(nanoseconds: UInt64(impactDelay * 1_000_000_000))
                    guard Task.isCancelled == false else { return }
                    triggerHaptic(.rigid)
                    return
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

    var title: String {
        switch self {
        case .metronome: "Metronome"
        case .guidedSwing: "Guided Swing"
        }
    }

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
    case resting
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

    var body: some View {
        HStack(spacing: 10) {
            GarageTempoIconButton(systemImage: "chevron.left", label: "Back", action: onBack)

            Spacer()

            Text("Tempo Builder")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(GarageProTheme.textPrimary)

            Spacer()

            GarageTempoIconButton(systemImage: "camera.fill", label: "Swing capture", action: onCapture)
            .disabled(controlsEnabled == false)
            .opacity(controlsEnabled ? 1 : 0.34)
        }
        .frame(height: 46)
    }
}

private struct GarageTempoPageSelector: View {
    @Binding var selectedPage: GarageTempoPage
    let controlsEnabled: Bool
    let namespace: Namespace.ID

    var body: some View {
        HStack(spacing: 4) {
            ForEach(GarageTempoPage.allCases) { page in
                Button {
                    guard controlsEnabled else { return }
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                        selectedPage = page
                    }
                } label: {
                    Text(page.title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(page == selectedPage ? Color.white : Color(red: 0.17, green: 0.17, blue: 0.18))
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background {
                            if page == selectedPage {
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .fill(Color(red: 0.11, green: 0.11, blue: 0.12))
                                    .matchedGeometryEffect(id: "selectedTempoPage", in: namespace)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(page.title)
                .accessibilityValue(page == selectedPage ? "Selected" : "")
                .accessibilityAddTraits(page == selectedPage ? .isSelected : [])
            }
        }
        .padding(4)
        .background(GaragePremiumPalette.gold, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .frame(height: 44)
        .disabled(controlsEnabled == false)
        .opacity(controlsEnabled ? 1 : 0.46)
    }
}

private struct GarageMetronomePage: View {
    @Binding var beatsPerMinute: Double
    @Binding var selectedRawValue: String
    @Binding var hapticsEnabled: Bool
    let recipe: ElasticSlingshotRecipe
    let sessionState: GarageTempoSessionState
    let reduceMotion: Bool
    let hasPendingTempo: Bool
    let playbackProgress: () -> Double
    let onStart: () -> Void
    let onStop: () -> Void
    @StateObject private var previewEngine = ElasticSlingshotAudioEngine()
    @State private var showsAllSounds = false

    private var isPlaying: Bool { sessionState == .playing }
    private var controlsEnabled: Bool { sessionState == .ready }
    private var selectedProfile: GarageMetronomeClickProfile {
        GarageMetronomeClickProfile.migrated(from: selectedRawValue)
    }
    private let primaryControlID = "metronome-primary-controls"
    private let quickProfiles: [GarageMetronomeClickProfile] = [
        .crispMarker, .dryClave, .hardwoodClick, .mutedTap, .glassPing, .digitalPulse
    ]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    if isPlaying || hasPendingTempo {
                        GarageTempoStatusLine(text: statusText, isHighlighted: true)
                            .padding(.top, 8)
                            .id(primaryControlID)
                    } else {
                        Color.clear
                            .frame(height: 1)
                            .id(primaryControlID)
                    }

                    GarageMetronomeBPMControl(beatsPerMinute: $beatsPerMinute)

                    TimelineView(.animation(minimumInterval: reduceMotion ? 0.15 : 1 / 60, paused: isPlaying == false)) { _ in
                        GarageTempoPendulum(
                            progress: isPlaying ? pendulumProgress : 0.5,
                            isPlaying: isPlaying,
                            reduceMotion: reduceMotion
                        )
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 148)

                    GarageMetronomeSoundToolbar(
                        profile: selectedProfile,
                        hapticsEnabled: $hapticsEnabled,
                        controlsEnabled: controlsEnabled,
                        showsAllSounds: showsAllSounds,
                        onPreview: { preview(selectedProfile) },
                        onToggleLibrary: {
                            guard controlsEnabled else { return }
                            withAnimation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.86)) {
                                showsAllSounds.toggle()
                            }
                        }
                    )

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(quickProfiles) { profile in
                                GarageMetronomeQuickSoundCard(
                                    profile: profile,
                                    isSelected: profile == selectedProfile,
                                    controlsEnabled: controlsEnabled,
                                    onSelect: { select(profile) },
                                    onPreview: { preview(profile) }
                                )
                                .frame(width: 154)
                            }
                        }
                    }

                    if showsAllSounds {
                        GarageMetronomeInlineSoundLibrary(
                            selectedProfile: selectedProfile,
                            controlsEnabled: controlsEnabled,
                            onSelect: { profile in
                                select(profile)
                                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
                                    showsAllSounds = false
                                    proxy.scrollTo(primaryControlID, anchor: .top)
                                }
                            },
                            onPreview: preview
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.bottom, 92)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            GarageTempoSessionControls(
                state: sessionState,
                reduceMotion: reduceMotion,
                onStart: {
                    previewEngine.stop()
                    onStart()
                },
                onStop: {
                    previewEngine.stop()
                    onStop()
                }
            )
            .padding(.vertical, 10)
            .background(GaragePremiumPalette.emeraldDeep.opacity(0.96))
        }
        .onDisappear {
            previewEngine.stop()
        }
        .onChange(of: sessionState) { _, newState in
            guard newState != .ready else { return }
            previewEngine.stop()
            showsAllSounds = false
        }
    }

    private var statusText: String {
        if hasPendingTempo { return "New tempo applying." }
        return isPlaying ? "Metronome running." : "Steady click. Every beat."
    }

    private var pendulumProgress: Double {
        let beatPosition = playbackProgress() * 4
        let twoBeatPosition = beatPosition.truncatingRemainder(dividingBy: 2)
        return twoBeatPosition <= 1 ? twoBeatPosition : 2 - twoBeatPosition
    }

    private func preview(_ profile: GarageMetronomeClickProfile) {
        guard controlsEnabled else { return }
        previewEngine.playOneCycle(
            beatsPerMinute: beatsPerMinute,
            recipe: recipe,
            soundProfile: .elastic,
            metronomeStartProfile: profile,
            metronomeImpactProfile: profile,
            guidedClicksEnabled: false,
            instrumentMode: .metronome
        )
    }

    private func select(_ profile: GarageMetronomeClickProfile) {
        guard controlsEnabled else { return }
        previewEngine.stop()
        selectedRawValue = profile.rawValue
    }
}

private struct GarageMetronomeBPMControl: View {
    @Binding var beatsPerMinute: Double

    private var range: ClosedRange<Double> { GarageSlowTempoLogic.consumerBPMRange }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 18) {
                stepButton(systemImage: "minus", adjustment: -1, disabled: beatsPerMinute <= range.lowerBound)

                HStack(alignment: .lastTextBaseline, spacing: 7) {
                    Text("\(Int(beatsPerMinute.rounded()))")
                        .font(.system(size: 62, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text("BPM")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(GaragePremiumPalette.gold)
                        .padding(.bottom, 10)
                }
                .foregroundStyle(GarageProTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(Int(beatsPerMinute.rounded())) beats per minute")

                stepButton(systemImage: "plus", adjustment: 1, disabled: beatsPerMinute >= range.upperBound)
            }

            Slider(value: $beatsPerMinute, in: range, step: 1)
                .tint(GaragePremiumPalette.gold)
                .accessibilityLabel("Metronome tempo")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
    }

    private func stepButton(systemImage: String, adjustment: Double, disabled: Bool) -> some View {
        Button {
            beatsPerMinute = min(max(beatsPerMinute + adjustment, range.lowerBound), range.upperBound)
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(disabled ? GarageProTheme.textSecondary : GaragePremiumPalette.gold)
                .frame(width: 42, height: 42)
                .background(GarageProTheme.insetSurface.opacity(0.58), in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityLabel(adjustment > 0 ? "Increase tempo by one" : "Decrease tempo by one")
    }
}

private struct GarageMetronomeSoundToolbar: View {
    let profile: GarageMetronomeClickProfile
    @Binding var hapticsEnabled: Bool
    let controlsEnabled: Bool
    let showsAllSounds: Bool
    let onPreview: () -> Void
    let onToggleLibrary: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onToggleLibrary) {
                HStack(spacing: 8) {
                    Image(systemName: "waveform")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(GaragePremiumPalette.gold)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("SOUND")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .tracking(1)
                            .foregroundStyle(GarageProTheme.textSecondary)
                        Text(profile.title)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(GarageProTheme.textPrimary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    Image(systemName: showsAllSounds ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(GarageProTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 42)
            }
            .buttonStyle(.plain)
            .disabled(controlsEnabled == false)
            .accessibilityLabel("All Sounds")
            .accessibilityValue(showsAllSounds ? "Expanded" : "Collapsed")

            Button(action: onPreview) {
                Image(systemName: "play.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(GaragePremiumPalette.gold)
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(.plain)
            .disabled(controlsEnabled == false)
            .accessibilityLabel("Preview \(profile.title)")

            Button {
                hapticsEnabled.toggle()
            } label: {
                Image(systemName: hapticsEnabled ? "iphone.radiowaves.left.and.right" : "iphone.slash")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(hapticsEnabled ? GaragePremiumPalette.gold : GarageProTheme.textSecondary)
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Haptics")
            .accessibilityValue(hapticsEnabled ? "On" : "Off")
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .background(GarageProTheme.insetSurface.opacity(0.58), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(GarageProTheme.border, lineWidth: 1))
        .opacity(controlsEnabled ? 1 : 0.52)
    }
}

private struct GarageMetronomeSoundSectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .tracking(1.4)
            .foregroundStyle(GarageProTheme.textSecondary)
    }
}

private struct GarageMetronomeQuickSoundCard: View {
    let profile: GarageMetronomeClickProfile
    let isSelected: Bool
    let controlsEnabled: Bool
    let onSelect: () -> Void
    let onPreview: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onSelect) {
                HStack(spacing: 7) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "waveform")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(isSelected ? GaragePremiumPalette.gold : GarageProTheme.textSecondary)
                    Text(profile.title)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(GarageProTheme.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Select \(profile.title)")
            .accessibilityAddTraits(isSelected ? .isSelected : [])

            Button(action: onPreview) {
                Image(systemName: "play.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(GaragePremiumPalette.gold)
                    .frame(width: 32, height: 40)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Preview \(profile.title)")
        }
        .padding(.leading, 10)
        .padding(.trailing, 4)
        .background(GarageProTheme.insetSurface.opacity(isSelected ? 0.88 : 0.48), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isSelected ? GaragePremiumPalette.gold.opacity(0.72) : GarageProTheme.border, lineWidth: 1)
        )
        .disabled(controlsEnabled == false)
        .opacity(controlsEnabled ? 1 : 0.42)
    }
}

private struct GarageMetronomeInlineSoundLibrary: View {
    let selectedProfile: GarageMetronomeClickProfile
    let controlsEnabled: Bool
    let onSelect: (GarageMetronomeClickProfile) -> Void
    let onPreview: (GarageMetronomeClickProfile) -> Void

    private let groups: [(String, [GarageMetronomeClickProfile])] = [
        ("Crisp / Marker", GarageMetronomeClickProfile.crispMarkers),
        ("Soft Practice", GarageMetronomeClickProfile.softPractice),
        ("Signal / Accent", GarageMetronomeClickProfile.signalAccents),
        ("Digital / Synthetic", GarageMetronomeClickProfile.digitalSynthetic)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(groups, id: \.0) { group in
                VStack(alignment: .leading, spacing: 9) {
                    GarageMetronomeSoundSectionHeader(title: group.0)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
                        ForEach(group.1) { profile in
                            GarageMetronomeQuickSoundCard(
                                profile: profile,
                                isSelected: profile == selectedProfile,
                                controlsEnabled: controlsEnabled,
                                onSelect: { onSelect(profile) },
                                onPreview: { onPreview(profile) }
                            )
                        }
                    }
                }
            }
        }
    }
}

private struct GarageGuidedSwingPage: View {
    @Binding var beatsPerMinute: Double
    let appliedBPM: Double
    let recipe: ElasticSlingshotRecipe
    let sessionState: GarageTempoSessionState
    let reduceMotion: Bool
    let countdownValue: Int?
    let hasPendingTempo: Bool
    let playbackProgress: () -> Double
    let onStart: () -> Void
    let onPause: () -> Void
    let onResume: () -> Void
    let onControlRoom: () -> Void
    let onStop: () -> Void

    private var isPlaying: Bool { sessionState == .playing }

    var body: some View {
        VStack(spacing: 0) {
            GarageTempoStatusLine(text: statusText, isHighlighted: hasPendingTempo || sessionState == .countingIn)
                .padding(.top, 14)

            Spacer(minLength: 12)

            TimelineView(.animation(minimumInterval: reduceMotion ? 0.15 : 1 / 60, paused: isPlaying == false)) { _ in
                GarageGuidedSwingTimeline(
                    state: visualState(progress: playbackProgress()),
                    isPlaying: isPlaying,
                    isResting: sessionState == .resting || sessionState == .countingIn,
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

            Text("TEMPO SPEED")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(GarageProTheme.textSecondary)
                .padding(.top, 2)

            Slider(value: $beatsPerMinute, in: GarageSlowTempoLogic.consumerBPMRange, step: 1)
                .tint(GaragePremiumPalette.gold)
                .padding(.horizontal, 8)
                .accessibilityLabel("Guided Swing tempo")

            GarageTempoControlRoomHandle(action: onControlRoom)
                .disabled(sessionState != .ready)
                .opacity(sessionState == .ready ? 1 : 0.34)
                .padding(.top, 12)

            GarageTempoSessionControls(
                state: sessionState,
                reduceMotion: reduceMotion,
                onStart: onStart,
                onPause: onPause,
                onResume: onResume,
                onStop: onStop
            )
                .padding(.top, 12)
                .padding(.bottom, 10)
        }
    }

    private var statusText: String {
        if hasPendingTempo { return "New tempo applies next swing." }
        switch sessionState {
        case .countingIn:
            return "Next swing after the count."
        case .resting:
            return "Reset. Next swing starts after the rest."
        case .playing:
            return "Follow the build to impact."
        case .paused:
            return "Paused. Resume starts with a fresh count."
        case .ready:
            return "Press Start. Settle into your rhythm."
        }
    }

    private func visualState(progress: Double) -> GarageSlowTempoVisualState {
        let elapsed = max(progress, 0) * recipe.swingDuration(for: appliedBPM)
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
        guard isPlaying else { return .degrees(0) }
        guard reduceMotion == false else { return .degrees(0) }

        let normalizedProgress = min(max(progress, 0), 1)
        return .degrees(-29 + (58 * smoothstep(normalizedProgress)))
    }

    var body: some View {
        ZStack(alignment: .top) {
            ZStack(alignment: .top) {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [GaragePremiumPalette.gold, GaragePremiumPalette.goldDeep],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 4, height: 104)
                    .shadow(color: GaragePremiumPalette.gold.opacity(0.22), radius: 10)

                Circle()
                    .fill(GaragePremiumPalette.emeraldDeep)
                    .frame(width: 44, height: 44)
                    .overlay(Circle().stroke(GaragePremiumPalette.gold.opacity(0.54), lineWidth: 2))
                    .shadow(color: GaragePremiumPalette.gold.opacity(isPlaying ? 0.28 : 0.12), radius: 16)
                    .offset(y: 86)
            }
            .frame(height: 132, alignment: .top)
            .rotationEffect(angle, anchor: .top)
            .padding(.top, 18)

            VStack {
                HStack {
                    Text(isPlaying ? "LIVE METRONOME" : "METRONOME")
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

                Text(isPlaying ? "EVERY BEAT" : "READY")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(isPlaying ? GaragePremiumPalette.gold : GarageProTheme.textSecondary)
                    .frame(maxWidth: .infinity)
            }
            .padding(14)
        }
        .accessibilityHidden(true)
    }

    private func smoothstep(_ value: Double) -> Double {
        let clamped = min(max(value, 0), 1)
        return clamped * clamped * (3 - (2 * clamped))
    }
}

private struct GarageGuidedSwingTimeline: View {
    let state: GarageSlowTempoVisualState
    let isPlaying: Bool
    let isResting: Bool
    let reduceMotion: Bool
    let countdownValue: Int?

    var body: some View {
        GeometryReader { proxy in
            let lineStart = proxy.size.width * 0.10
            let lineEnd = proxy.size.width * 0.90
            let lineY = proxy.size.height * 0.52
            let progress = state.isResting ? 0 : min(max(state.cycleProgress, 0), 1)
            let markerX = isResting ? proxy.size.width / 2 : lineStart + ((lineEnd - lineStart) * progress)
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
                } else {
                    Circle()
                        .fill(isResting ? Color.gray.opacity(0.72) : GaragePremiumPalette.gold.opacity(0.82))
                        .frame(width: 18, height: 18)
                        .shadow(color: isResting ? .clear : GaragePremiumPalette.gold.opacity(0.24), radius: 12)
                        .position(x: markerX, y: lineY)
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

private struct GarageTempoStatusLine: View {
    let text: String
    let isHighlighted: Bool

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(isHighlighted ? GaragePremiumPalette.gold : GarageProTheme.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 20)
            .transaction { transaction in
                transaction.animation = nil
            }
        .multilineTextAlignment(.center)
        .accessibilityLabel(text)
    }
}

private struct GarageTempoSessionControls: View {
    let state: GarageTempoSessionState
    let reduceMotion: Bool
    let onStart: () -> Void
    var onPause: (() -> Void)?
    var onResume: (() -> Void)?
    let onStop: () -> Void
    @Namespace private var controlNamespace

    private var isActive: Bool { state != .ready }
    private var supportsPause: Bool { onPause != nil && onResume != nil }

    var body: some View {
        HStack(spacing: 10) {
            Button(action: primaryAction) {
                GarageTempoActionLabel(
                    title: primaryTitle,
                    systemImage: primarySystemImage
                )
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(isActive ? Color.white : GaragePremiumPalette.emeraldDeep)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isActive ? Color(red: 0.11, green: 0.11, blue: 0.12) : GaragePremiumPalette.gold)
                        .shadow(color: isActive ? .clear : GaragePremiumPalette.gold.opacity(0.24), radius: 14, x: 0, y: 8)
                        .matchedGeometryEffect(id: "sessionControlSurface", in: controlNamespace)
                    }
            }
            .buttonStyle(.plain)

            if supportsPause, isActive {
                Button(action: onStop) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(width: 56, height: 56)
                        .background(Color(red: 0.11, green: 0.11, blue: 0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Stop")
            }
        }
        .frame(height: 56)
        .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.84), value: isActive)
    }

    private var primaryTitle: String {
        if state == .paused { return "Resume" }
        if supportsPause, isActive { return "Pause" }
        return isActive ? "Stop" : "Start"
    }

    private var primarySystemImage: String {
        if state == .paused { return "play.fill" }
        if supportsPause, isActive { return "pause.fill" }
        return isActive ? "stop.fill" : "play.fill"
    }

    private func primaryAction() {
        if state == .paused {
            onResume?()
        } else if supportsPause, isActive {
            onPause?()
        } else if isActive {
            onStop()
        } else {
            onStart()
        }
    }
}

private struct GarageTempoActionLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .black))
                .frame(width: 18)

            Text(title)
        }
        .offset(x: -2)
    }
}

private struct GarageTempoControlRoomHandle: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Capsule()
                .fill(GaragePremiumPalette.mintText.opacity(0.38))
                .frame(width: 54, height: 5)
                .frame(maxWidth: .infinity)
                .frame(height: 18)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open Control Room")
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
                            metronomeStartProfile: .woodblock,
                            metronomeImpactProfile: .brightSignal,
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
    let beatsPerMinute: Double
    @Binding var selectedStartRawValue: String
    @Binding var selectedImpactRawValue: String
    @Binding var selectedGuidedRawValue: String
    @Binding var restInterval: Double
    @Binding var hapticsEnabled: Bool
    let recipe: ElasticSlingshotRecipe
    @StateObject private var previewEngine = ElasticSlingshotAudioEngine()
    @State private var soundLibrary: GarageTempoSoundLibrary?

    private var selectedStartSound: GarageMetronomeClickProfile {
        GarageMetronomeClickProfile.migrated(from: selectedStartRawValue)
    }

    private var selectedImpactSound: GarageMetronomeClickProfile {
        GarageMetronomeClickProfile.migrated(from: selectedImpactRawValue)
    }

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
                            Text("Guided Swing")
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

                    GarageTempoSettingsGroup {
                        GarageTempoActionValueRow(title: "Sound Style", value: selectedGuidedSound.title) {
                            soundLibrary = .guided
                        }
                        GarageTempoSettingsDivider()
                        GarageTempoActionRow(title: "Preview Guided Swing", systemImage: "play.fill") {
                            previewEngine.playOneCycle(
                                beatsPerMinute: beatsPerMinute,
                                recipe: recipe,
                                soundProfile: selectedGuidedSound.engineProfile,
                                metronomeStartProfile: selectedStartSound,
                                metronomeImpactProfile: selectedImpactSound,
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
                        GarageTempoReadbackRow(title: "Countdown", value: "Spoken 3 - 2 - 1")
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
        .sheet(item: $soundLibrary) { library in
            switch library {
            case .guided:
                GarageGuidedSoundLibrary(
                    selectedRawValue: $selectedGuidedRawValue,
                    beatsPerMinute: beatsPerMinute,
                    recipe: recipe
                )
            }
        }
    }
}

private enum GarageTempoSoundLibrary: String, Identifiable {
    case guided

    var id: String { rawValue }
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
