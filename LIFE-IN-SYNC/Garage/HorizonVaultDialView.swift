import AVFoundation
import Combine
import SwiftUI
import UIKit

@MainActor
struct GarageTempoBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var session = GarageTempoSessionController()

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

    private var isActive: Bool { session.isActive }
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

    private var sessionConfiguration: GarageTempoSessionConfiguration {
        GarageTempoSessionConfiguration(
            page: selectedPage,
            beatsPerMinute: activeSavedBPM,
            recipe: recipe,
            guidedSound: selectedGuidedSound,
            startClick: selectedStartClick,
            impactClick: selectedImpactClick,
            hapticsEnabled: hapticsEnabled
        )
    }

    var body: some View {
        tempoContent
            .onAppear {
                migrateSavedClickSound()
                clampSavedTempos()
            }
            .onChange(of: selectedPage) { _, _ in
                session.stop()
                session.synchronizeReadyBPM(activeSavedBPM)
            }
            .onChange(of: metronomeBPM) { _, _ in session.configurationChanged(sessionConfiguration) }
            .onChange(of: guidedSwingBPM) { _, _ in session.configurationChanged(sessionConfiguration) }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active {
                    session.stop()
                }
            }
            .fullScreenCover(isPresented: settingsPresentation) {
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
                session.stop()
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
                    showsControlRoom: selectedPage == .guidedSwing,
                    onBack: close,
                    onControlRoom: { presentedSheet = .settings },
                    onCapture: { showsSwingCapture = true }
                )
                .accessibilityIdentifier("tempo-builder-top-bar")

                GarageTempoPageSelector(
                    selectedPage: $selectedPage,
                    controlsEnabled: isActive == false,
                    namespace: pageSelectorNamespace
                )
                .padding(.top, 8)
                .accessibilityIdentifier("tempo-builder-mode-selector")

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
                sessionState: selectedPage == .metronome ? session.state : .ready,
                reduceMotion: reduceMotion,
                hasPendingTempo: session.hasPendingTempo,
                playbackProgress: session.currentPlaybackProgress,
                onStart: { session.start(sessionConfiguration) },
                onStop: session.stop
            )
            .tag(GarageTempoPage.metronome)

            GarageGuidedSwingPage(
                beatsPerMinute: $guidedSwingBPM,
                appliedBPM: session.appliedBPM,
                recipe: recipe,
                sessionState: selectedPage == .guidedSwing ? session.state : .ready,
                reduceMotion: reduceMotion,
                countdownValue: session.countdownValue,
                restProgress: session.restProgress,
                hasPendingTempo: session.hasPendingTempo,
                playbackProgress: session.currentPlaybackProgress,
                onStart: { session.start(sessionConfiguration) },
                onRestart: { session.restartGuidedSwing(sessionConfiguration) },
                onStop: session.stop
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

    private func clampSavedTempos() {
        metronomeBPM = GarageSlowTempoLogic.clampedConsumerBPM(metronomeBPM)
        guidedSwingBPM = GarageSlowTempoLogic.clampedConsumerBPM(guidedSwingBPM)
        session.synchronizeReadyBPM(activeSavedBPM)
    }

    private func migrateSavedClickSound() {
        startClickRawValue = GarageMetronomeClickProfile.migrated(from: startClickRawValue).rawValue
    }

    private func close() {
        session.stop()
        dismiss()
    }
}

private enum GarageTempoSheet: String, Identifiable {
    case settings

    var id: String { rawValue }
}

private struct GarageTempoTopBar: View {
    let controlsEnabled: Bool
    let showsControlRoom: Bool
    let onBack: () -> Void
    let onControlRoom: () -> Void
    let onCapture: () -> Void

    var body: some View {
        ZStack {
            Text("Tempo Builder")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(GarageProTheme.textPrimary)

            HStack(spacing: 8) {
                GarageTempoIconButton(systemImage: "chevron.left", label: "Back", action: onBack)

                Spacer()

                if showsControlRoom {
                    GarageTempoIconButton(
                        systemImage: "slider.horizontal.3",
                        label: "Open Control Room",
                        action: onControlRoom
                    )
                    .disabled(controlsEnabled == false)
                    .opacity(controlsEnabled ? 1 : 0.65)
                    .accessibilityIdentifier("tempo-builder-control-room")
                }

                GarageTempoIconButton(systemImage: "camera.fill", label: "Swing capture", action: onCapture)
                    .disabled(controlsEnabled == false)
                    .opacity(controlsEnabled ? 1 : 0.65)
            }
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
                        .foregroundStyle(page == selectedPage ? Color.white : GaragePremiumPalette.mintText.opacity(0.72))
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background {
                            if page == selectedPage {
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .fill(Color.black.opacity(0.62))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                                            .stroke(GaragePremiumPalette.gold.opacity(0.48), lineWidth: 1)
                                    )
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
        .background(GaragePremiumPalette.emeraldGlass.opacity(0.72), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(GaragePremiumPalette.mintText.opacity(0.16), lineWidth: 1)
        )
        .frame(height: 44)
        .disabled(controlsEnabled == false)
        .opacity(controlsEnabled ? 1 : 0.68)
    }
}

private struct GarageMetronomePage: View {
    @Binding var beatsPerMinute: Double
    @Binding var selectedRawValue: String
    let sessionState: GarageTempoSessionState
    let reduceMotion: Bool
    let hasPendingTempo: Bool
    let playbackProgress: () -> Double
    let onStart: () -> Void
    let onStop: () -> Void
    private var isPlaying: Bool { sessionState == .playing }
    private var controlsEnabled: Bool { sessionState == .ready }
    private var selectedProfile: GarageMetronomeClickProfile {
        GarageMetronomeClickProfile.migrated(from: selectedRawValue)
    }

    var body: some View {
        VStack(spacing: 0) {
            GarageTempoStatusLine(
                text: isPlaying || hasPendingTempo ? statusText : "",
                isHighlighted: isPlaying || hasPendingTempo
            )
                .padding(.top, 8)

            GarageMetronomeBPMControl(beatsPerMinute: $beatsPerMinute)
                .padding(.top, 4)

            TimelineView(.animation(minimumInterval: reduceMotion ? 0.15 : 1 / 60, paused: isPlaying == false)) { _ in
                GarageTempoPendulum(
                    progress: isPlaying ? pendulumProgress : 0.5,
                    isPlaying: isPlaying,
                    reduceMotion: reduceMotion,
                    beatsPerMinute: beatsPerMinute
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .layoutPriority(1)

            GarageMetronomeSoundToolbar(
                profile: selectedProfile,
                controlsEnabled: controlsEnabled,
                onSelect: select
            )
            .padding(.bottom, 10)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            GarageTempoSessionControls(
                state: sessionState,
                reduceMotion: reduceMotion,
                onStart: onStart,
                onStop: onStop
            )
            .padding(.vertical, 10)
            .background(GaragePremiumPalette.emeraldDeep.opacity(0.96))
        }
    }

    private var statusText: String {
        if hasPendingTempo { return "New tempo applying." }
        return isPlaying ? "Metronome running." : ""
    }

    private var pendulumProgress: Double {
        let beatPosition = playbackProgress() * 4
        let twoBeatPosition = beatPosition.truncatingRemainder(dividingBy: 2)
        return twoBeatPosition <= 1 ? twoBeatPosition : 2 - twoBeatPosition
    }

    private func select(_ profile: GarageMetronomeClickProfile) {
        guard controlsEnabled else { return }
        selectedRawValue = profile.rawValue
    }
}

private struct GarageMetronomeBPMControl: View {
    @Binding var beatsPerMinute: Double
    @ScaledMetric(relativeTo: .largeTitle) private var bpmFontSize = 70

    private var range: ClosedRange<Double> { GarageSlowTempoLogic.consumerBPMRange }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 18) {
                stepButton(systemImage: "minus", adjustment: -1, disabled: beatsPerMinute <= range.lowerBound)

                HStack(alignment: .lastTextBaseline, spacing: 7) {
                    Text("\(Int(beatsPerMinute.rounded()))")
                        .font(.system(size: bpmFontSize, weight: .semibold, design: .rounded))
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
                .frame(width: 48, height: 48)
                .background(GaragePremiumPalette.emeraldGlass.opacity(0.72), in: Circle())
                .overlay(Circle().stroke(GaragePremiumPalette.mintText.opacity(0.16), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityLabel(adjustment > 0 ? "Increase tempo by one" : "Decrease tempo by one")
    }
}

private struct GarageMetronomeSoundToolbar: View {
    let profile: GarageMetronomeClickProfile
    let controlsEnabled: Bool
    let onSelect: (GarageMetronomeClickProfile) -> Void

    var body: some View {
        Menu {
            soundSection("Crisp Markers", profiles: GarageMetronomeClickProfile.crispMarkers)
            soundSection("Soft Practice", profiles: GarageMetronomeClickProfile.softPractice)
            soundSection("Signal Accents", profiles: GarageMetronomeClickProfile.signalAccents)
            soundSection("Digital", profiles: GarageMetronomeClickProfile.digitalSynthetic)
        } label: {
            GarageMetronomeSoundLabel(profile: profile)
        }
        .padding(.horizontal, 12)
        .background(GarageProTheme.insetSurface.opacity(0.58), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(GarageProTheme.border, lineWidth: 1))
        .disabled(controlsEnabled == false)
        .opacity(controlsEnabled ? 1 : 0.52)
        .accessibilityLabel("Choose metronome sound")
        .accessibilityValue(profile.title)
    }

    @ViewBuilder
    private func soundSection(_ title: String, profiles: [GarageMetronomeClickProfile]) -> some View {
        Section(title) {
            ForEach(profiles) { candidate in
                Button {
                    onSelect(candidate)
                } label: {
                    Label(candidate.title, systemImage: candidate == profile ? "checkmark" : "waveform")
                }
            }
        }
    }
}

private struct GarageMetronomeSoundLabel: View {
    let profile: GarageMetronomeClickProfile

    var body: some View {
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

            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(GarageProTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 42)
    }
}

private struct GarageGuidedSwingPage: View {
    @Binding var beatsPerMinute: Double
    let appliedBPM: Double
    let recipe: ElasticSlingshotRecipe
    let sessionState: GarageTempoSessionState
    let reduceMotion: Bool
    let countdownValue: Int?
    let restProgress: Double
    let hasPendingTempo: Bool
    let playbackProgress: () -> Double
    let onStart: () -> Void
    let onRestart: () -> Void
    let onStop: () -> Void
    @ScaledMetric(relativeTo: .largeTitle) private var bpmFontSize = 58
    @ScaledMetric(relativeTo: .body) private var timelineHeight = 250

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
                    countdownValue: countdownValue,
                    restProgress: restProgress
                )
            }
            .frame(maxWidth: .infinity)
            .frame(height: min(max(timelineHeight, 210), 310))

            Spacer(minLength: 12)

            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text("\(Int(beatsPerMinute.rounded()))")
                    .font(.system(size: bpmFontSize, weight: .semibold, design: .rounded))
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

            GarageTempoSessionControls(
                state: sessionState,
                reduceMotion: reduceMotion,
                onStart: onStart,
                onRestart: onRestart,
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
        case .ready:
            return "Press Start. Settle into your rhythm."
        }
    }

    private func visualState(progress: Double) -> GarageSlowTempoVisualState {
        let elapsed = max(progress, 0) * recipe.guidedMotionDuration(for: appliedBPM)
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
    let beatsPerMinute: Double

    private var angle: Angle {
        guard isPlaying else { return .degrees(0) }
        guard reduceMotion == false else { return .degrees(0) }

        let normalizedProgress = min(max(progress, 0), 1)
        return .degrees(-31 + (62 * smoothstep(normalizedProgress)))
    }

    var body: some View {
        GeometryReader { proxy in
            let stageWidth = min(proxy.size.width * 0.88, 340)
            let stageHeight = min(proxy.size.height * 0.98, 430)
            let bodyHeight = stageHeight * 0.69
            let bodyWidth = stageWidth * 0.76
            let baseHeight = stageHeight * 0.23
            let armHeight = stageHeight * 0.56
            let arcCenter = CGPoint(x: stageWidth / 2, y: stageHeight * 0.39)
            let arcRadius = stageWidth * 0.43
            let bpmRange = GarageSlowTempoLogic.consumerBPMRange
            let bpmProgress = (beatsPerMinute - bpmRange.lowerBound) / (bpmRange.upperBound - bpmRange.lowerBound)
            let weightPosition = armHeight * (0.28 + (0.48 * min(max(bpmProgress, 0), 1)))

            ZStack {
                ForEach(0..<25, id: \.self) { index in
                    let degrees = -68 + (Double(index) * 136 / 24)
                    let radians = degrees * .pi / 180
                    let isMajor = index.isMultiple(of: 4)

                    Capsule()
                        .fill(isMajor ? GaragePremiumPalette.gold.opacity(0.50) : GaragePremiumPalette.mintText.opacity(0.34))
                        .frame(width: isMajor ? 2 : 1, height: isMajor ? 15 : 9)
                        .rotationEffect(.degrees(degrees))
                        .position(
                            x: arcCenter.x + (sin(radians) * arcRadius),
                            y: arcCenter.y - (cos(radians) * arcRadius)
                        )
                }

                GarageMetronomeBodyShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                GaragePremiumPalette.emeraldGlass.opacity(0.98),
                                GaragePremiumPalette.emeraldDeep,
                                Color.black.opacity(0.88)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        GarageMetronomeBodyShape()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        GaragePremiumPalette.gold.opacity(0.88),
                                        GaragePremiumPalette.mintText.opacity(0.16),
                                        GaragePremiumPalette.goldDeep.opacity(0.86)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .frame(width: bodyWidth, height: bodyHeight)
                    .offset(y: stageHeight * 0.04)
                    .shadow(color: Color.black.opacity(0.42), radius: 22, x: 0, y: 16)

                GarageMetronomeScale(beatsPerMinute: beatsPerMinute)
                    .frame(width: bodyWidth * 0.30, height: bodyHeight * 0.70)
                    .offset(y: stageHeight * 0.02)

                ZStack(alignment: .bottom) {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [GaragePremiumPalette.gold, GaragePremiumPalette.goldDeep],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 5, height: armHeight)
                        .overlay(Capsule().stroke(Color.white.opacity(0.34), lineWidth: 0.6))

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.84),
                                    GaragePremiumPalette.gold,
                                    GaragePremiumPalette.goldDeep
                                ],
                                center: .topLeading,
                                startRadius: 1,
                                endRadius: 30
                            )
                        )
                        .frame(width: 42, height: 42)
                        .overlay(Circle().stroke(GaragePremiumPalette.gold.opacity(0.88), lineWidth: 2))
                        .shadow(color: GaragePremiumPalette.gold.opacity(isPlaying ? 0.30 : 0.14), radius: 12)
                        .offset(y: -weightPosition)
                }
                .frame(width: 60, height: armHeight, alignment: .bottom)
                .rotationEffect(angle, anchor: .bottom)
                .offset(y: -(baseHeight * 0.64))

                GarageMetronomeBaseShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                GaragePremiumPalette.emeraldGlass,
                                GaragePremiumPalette.emeraldDeep,
                                Color.black.opacity(0.94)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        GarageMetronomeBaseShape()
                            .stroke(GaragePremiumPalette.gold.opacity(0.66), lineWidth: 1.5)
                    )
                    .frame(width: stageWidth * 0.88, height: baseHeight)
                    .offset(y: stageHeight * 0.37)
                    .shadow(color: Color.black.opacity(0.48), radius: 18, x: 0, y: 14)

                Text(isPlaying ? "LIVE" : "READY")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(isPlaying ? GaragePremiumPalette.gold : GaragePremiumPalette.mintText)
                    .offset(y: -(stageHeight * 0.40))
            }
            .frame(width: stageWidth, height: stageHeight)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            isPlaying
                ? "Metronome running at \(Int(beatsPerMinute.rounded())) beats per minute"
                : "Metronome ready at \(Int(beatsPerMinute.rounded())) beats per minute"
        )
    }

    private func smoothstep(_ value: Double) -> Double {
        let clamped = min(max(value, 0), 1)
        return clamped * clamped * (3 - (2 * clamped))
    }
}

private struct GarageMetronomeBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX - rect.width * 0.16, y: 0))
        path.addQuadCurve(
            to: CGPoint(x: rect.midX + rect.width * 0.16, y: 0),
            control: CGPoint(x: rect.midX, y: -rect.height * 0.05)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct GarageMetronomeBaseShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.08, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.08, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY * 0.88))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY * 0.88),
            control: CGPoint(x: rect.midX, y: rect.maxY * 1.04)
        )
        path.closeSubpath()
        return path
    }
}

private struct GarageMetronomeScale: View {
    let beatsPerMinute: Double

    private let marks = [40, 60, 80, 100, 120, 140, 160, 180, 200, 220]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Capsule()
                    .fill(Color.black.opacity(0.30))
                    .overlay(Capsule().stroke(GaragePremiumPalette.gold.opacity(0.24), lineWidth: 1))

                ForEach(marks.indices, id: \.self) { index in
                    let mark = marks[index]
                    let y = proxy.size.height * (0.08 + (Double(index) * 0.84 / Double(marks.count - 1)))
                    let isClosest = abs(Double(mark) - beatsPerMinute) < 11

                    HStack(spacing: 5) {
                        Capsule()
                            .fill(isClosest ? GaragePremiumPalette.gold : GaragePremiumPalette.goldDeep.opacity(0.68))
                            .frame(width: isClosest ? 12 : 7, height: 1)

                        Text("\(mark)")
                            .font(.system(size: isClosest ? 10 : 8, weight: isClosest ? .bold : .medium, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(isClosest ? GaragePremiumPalette.gold : GaragePremiumPalette.mintText.opacity(0.56))

                        Capsule()
                            .fill(isClosest ? GaragePremiumPalette.gold : GaragePremiumPalette.goldDeep.opacity(0.68))
                            .frame(width: isClosest ? 12 : 7, height: 1)
                    }
                    .position(x: proxy.size.width / 2, y: y)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

private struct GarageGuidedSwingTimeline: View {
    let state: GarageSlowTempoVisualState
    let isPlaying: Bool
    let isResting: Bool
    let reduceMotion: Bool
    let countdownValue: Int?
    let restProgress: Double

    var body: some View {
        GeometryReader { proxy in
            let progress = visualProgress
            let path = swingPath(in: proxy.size)
            let markerPoint = point(at: progress, in: proxy.size)
            let startPoint = point(at: 0, in: proxy.size)
            let topPoint = point(at: 0.58, in: proxy.size)
            let impactPoint = point(at: 0.90, in: proxy.size)
            let impactActive = isPlaying && state.motionProgress >= 0.90 && state.motionProgress <= 0.94

            ZStack {
                path
                    .stroke(GaragePremiumPalette.mintText.opacity(isResting ? 0.12 : 0.28), style: StrokeStyle(lineWidth: 3, lineCap: .round))

                if isPlaying, isResting == false {
                    path
                        .trimmedPath(from: 0, to: progress)
                        .stroke(
                            LinearGradient(
                                colors: [GaragePremiumPalette.emerald, GaragePremiumPalette.gold],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round)
                        )
                }

                Circle()
                    .fill(isResting ? GaragePremiumPalette.mintText.opacity(0.36) : GaragePremiumPalette.gold)
                    .frame(width: reduceMotion ? 15 : 17, height: reduceMotion ? 15 : 17)
                    .shadow(color: isResting ? .clear : GaragePremiumPalette.gold.opacity(0.42), radius: 16)
                    .position(markerPoint)

                GarageGuidedSwingLandmark(title: "Start", isActive: state.activeBeat == 1 && isResting == false, alignment: .center)
                    .position(x: startPoint.x, y: startPoint.y + 30)
                GarageGuidedSwingLandmark(title: "Top", isActive: state.activeBeat == 2 && isResting == false, alignment: .center)
                    .position(x: topPoint.x, y: topPoint.y - 26)
                GarageGuidedSwingLandmark(title: "Impact", isActive: impactActive, alignment: .center)
                    .position(x: impactPoint.x, y: impactPoint.y + 30)

                Circle()
                    .fill(GaragePremiumPalette.gold.opacity(impactActive ? 0.18 : 0))
                    .frame(width: impactActive && reduceMotion == false ? 72 : 18, height: impactActive && reduceMotion == false ? 72 : 18)
                    .position(impactPoint)

                Circle()
                    .stroke(GaragePremiumPalette.gold.opacity(impactActive ? 0.92 : 0), lineWidth: 4)
                    .frame(width: impactActive && reduceMotion == false ? 58 : 18, height: impactActive && reduceMotion == false ? 58 : 18)
                    .position(impactPoint)
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: impactActive)

                if isResting, countdownValue == nil {
                    Circle()
                        .stroke(GaragePremiumPalette.mintText.opacity(0.12), lineWidth: 4)
                        .frame(width: 66, height: 66)
                    Circle()
                        .trim(from: 0, to: min(max(restProgress, 0), 1))
                        .stroke(GaragePremiumPalette.gold.opacity(0.72), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 66, height: 66)
                        .rotationEffect(.degrees(-90))
                }

                if let countdownValue {
                    Text("\(countdownValue)")
                        .font(.system(size: 46, weight: .semibold, design: .rounded))
                        .foregroundStyle(GaragePremiumPalette.gold)
                }
            }
            .opacity(isResting ? 0.72 : 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            countdownValue.map { "Guided swing countdown, \($0)" }
                ?? (isResting ? "Guided swing resting" : (isPlaying ? "Guided swing running, \(state.phaseLabel)" : "Guided swing ready"))
        )
    }

    private var visualProgress: Double {
        if isResting { return 0 }
        guard reduceMotion else { return min(max(state.motionProgress, 0), 1) }
        switch state.activeBeat {
        case 1: return 0
        case 2: return 0.58
        default: return 0.90
        }
    }

    private func swingPath(in size: CGSize) -> Path {
        let start = point(at: 0, in: size)
        let impact = point(at: 0.90, in: size)
        let finish = point(at: 1, in: size)
        var path = Path()
        path.move(to: start)
        path.addQuadCurve(
            to: impact,
            control: CGPoint(x: size.width * 0.52, y: size.height * 0.02)
        )
        path.addQuadCurve(
            to: finish,
            control: CGPoint(x: size.width * 0.93, y: size.height * 0.80)
        )
        return path
    }

    private func point(at progress: Double, in size: CGSize) -> CGPoint {
        let progress = min(max(progress, 0), 1)
        let start = CGPoint(x: size.width * 0.09, y: size.height * 0.72)
        let control = CGPoint(x: size.width * 0.52, y: size.height * 0.02)
        let impact = CGPoint(x: size.width * 0.86, y: size.height * 0.66)
        let followThroughControl = CGPoint(x: size.width * 0.93, y: size.height * 0.80)
        let finish = CGPoint(x: size.width * 0.95, y: size.height * 0.88)

        if progress <= 0.90 {
            let t = progress / 0.90
            let inverse = 1 - t
            return CGPoint(
                x: (inverse * inverse * start.x) + (2 * inverse * t * control.x) + (t * t * impact.x),
                y: (inverse * inverse * start.y) + (2 * inverse * t * control.y) + (t * t * impact.y)
            )
        }

        let t = (progress - 0.90) / 0.10
        let inverse = 1 - t
        return CGPoint(
            x: (inverse * inverse * impact.x) + (2 * inverse * t * followThroughControl.x) + (t * t * finish.x),
            y: (inverse * inverse * impact.y) + (2 * inverse * t * followThroughControl.y) + (t * t * finish.y)
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
    var onRestart: (() -> Void)?
    let onStop: () -> Void
    @Namespace private var controlNamespace

    private var isActive: Bool { state != .ready }
    private var supportsRestart: Bool { onRestart != nil }

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
            .accessibilityIdentifier(primaryAccessibilityIdentifier)

            if supportsRestart, isActive {
                Button(action: onStop) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(width: 56, height: 56)
                        .background(Color(red: 0.11, green: 0.11, blue: 0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Stop")
                .accessibilityIdentifier("tempo-builder-stop")
            }
        }
        .frame(height: 56)
        .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.84), value: isActive)
    }

    private var primaryTitle: String {
        if supportsRestart, isActive { return "Restart Swing" }
        return isActive ? "Stop" : "Start"
    }

    private var primarySystemImage: String {
        if supportsRestart, isActive { return "arrow.counterclockwise" }
        return isActive ? "stop.fill" : "play.fill"
    }

    private var primaryAccessibilityIdentifier: String {
        if supportsRestart, isActive { return "tempo-builder-restart-swing" }
        return isActive ? "tempo-builder-stop" : "tempo-builder-start"
    }

    private func primaryAction() {
        if supportsRestart, isActive {
            onRestart?()
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

private struct GarageTempoIconButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(GarageProTheme.textPrimary.opacity(0.86))
                .frame(width: 44, height: 44)
                .background(GaragePremiumPalette.emeraldGlass.opacity(0.52), in: Circle())
                .overlay(Circle().stroke(GaragePremiumPalette.mintText.opacity(0.14), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
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
    @State private var showsSoundChoices = false

    private var selectedStartSound: GarageMetronomeClickProfile {
        GarageMetronomeClickProfile.migrated(from: selectedStartRawValue)
    }

    private var selectedImpactSound: GarageMetronomeClickProfile {
        GarageMetronomeClickProfile.migrated(from: selectedImpactRawValue)
    }

    private var selectedGuidedSound: GarageGuidedSwingProfile {
        GarageGuidedSwingProfile(rawValue: selectedGuidedRawValue) ?? .tension
    }

    private let soundGroups: [(title: String, profiles: [GarageGuidedSwingProfile])] = [
        ("Clean & Precise", GarageGuidedSwingProfile.cleanAndPrecise),
        ("Weight & Air", GarageGuidedSwingProfile.weightAndAir)
    ]

    var body: some View {
        ZStack {
            GarageTempoBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Control Room")
                                .font(.title.weight(.semibold))
                                .foregroundStyle(GarageProTheme.textPrimary)
                            Text("Guided Swing")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(GaragePremiumPalette.gold)
                        }

                        Spacer()

                        Button("Done") { dismiss() }
                            .font(.body.weight(.semibold))
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
                            withAnimation(.easeInOut(duration: 0.22)) {
                                showsSoundChoices.toggle()
                            }
                        }
                        if showsSoundChoices {
                            GarageTempoSettingsDivider()
                            VStack(spacing: 0) {
                                ForEach(soundGroups, id: \.title) { group in
                                    Text(group.title.uppercased())
                                        .font(.caption2.weight(.bold))
                                        .tracking(1.1)
                                        .foregroundStyle(GarageProTheme.textSecondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 16)
                                        .padding(.top, 14)
                                        .padding(.bottom, 6)
                                        .accessibilityIdentifier("guided-sound-group-\(group.title)")

                                    ForEach(group.profiles) { profile in
                                        GarageTempoSoundRow(
                                            title: profile.title,
                                            subtitle: profile.character,
                                            isSelected: selectedGuidedRawValue == profile.rawValue
                                        ) {
                                            selectAndPreview(profile)
                                        }
                                    }
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
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

                    GarageTempoSettingsGroup {
                        Stepper(value: $restInterval, in: 1...20, step: 1) {
                            HStack {
                                Text("Rest Between Swings")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(GarageProTheme.textPrimary)
                                Spacer()
                                Text("\(Int(restInterval.rounded()))s")
                                    .font(.body.weight(.bold))
                                    .monospacedDigit()
                                    .foregroundStyle(GaragePremiumPalette.gold)
                            }
                        }
                        .padding(16)
                        .accessibilityLabel("Rest between swings")
                        .accessibilityValue("\(Int(restInterval.rounded())) seconds")
                    }

                    GarageTempoSettingsGroup {
                        GarageTempoReadbackRow(title: "Countdown", value: "Spoken 3 - 2 - 1")
                    }

                    GarageTempoSettingsGroup {
                        Toggle("Haptics", isOn: $hapticsEnabled)
                            .font(.body.weight(.semibold))
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
    }

    private func selectAndPreview(_ profile: GarageGuidedSwingProfile) {
        selectedGuidedRawValue = profile.rawValue
        previewEngine.playOneCycle(
            beatsPerMinute: beatsPerMinute,
            recipe: recipe,
            soundProfile: profile.engineProfile,
            metronomeStartProfile: selectedStartSound,
            metronomeImpactProfile: selectedImpactSound,
            guidedClicksEnabled: false,
            instrumentMode: .build
        )
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
                .font(.body.weight(.semibold))
                .foregroundStyle(GarageProTheme.textPrimary)
            Spacer()
            Text(value)
                .font(.body.weight(.bold))
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
                    .font(.body.weight(.semibold))
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
                    .font(.body.weight(.semibold))
                    .foregroundStyle(GarageProTheme.textPrimary)
                Spacer()
                Text(value)
                    .font(.body.weight(.bold))
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

private struct GarageTempoSoundRow: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "waveform")
                    .font(.body.weight(.bold))
                    .foregroundStyle(GaragePremiumPalette.gold)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(GarageProTheme.textPrimary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(GarageProTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isSelected ? GaragePremiumPalette.gold : GarageProTheme.textSecondary.opacity(0.45))
            }
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? GaragePremiumPalette.gold.opacity(0.08) : Color.clear)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            Divider()
                .overlay(GarageProTheme.border)
                .padding(.leading, 50)
        }
        .accessibilityLabel(title)
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
