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
    @AppStorage("garage.tempoBuilder.guidedSound") private var guidedRawValue = GarageGuidedSwingProfile.tourWhip.rawValue
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
        GarageGuidedSwingProfile.migrated(from: guidedRawValue)
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
                migrateSavedSounds()
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
                    page: selectedPage,
                    beatsPerMinute: activeSavedBPM,
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
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
        }
    }

    private var tempoPages: some View {
        ZStack {
            if selectedPage == .metronome {
                metronomePage
                    .transition(.opacity)
            } else {
                guidedSwingPage
                    .transition(.opacity)
            }
        }
        .clipped()
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: selectedPage)
    }

    private var metronomePage: some View {
        GarageMetronomePage(
            beatsPerMinute: $metronomeBPM,
            sessionState: selectedPage == .metronome ? session.state : .ready,
            reduceMotion: reduceMotion,
            hasPendingTempo: session.hasPendingTempo,
            playbackProgress: session.currentPlaybackProgress,
            onStart: { session.start(sessionConfiguration) },
            onStop: session.stop
        )
    }

    private var guidedSwingPage: some View {
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
    }

    private var settingsPresentation: Binding<Bool> {
        Binding(
            get: { presentedSheet == .settings },
            set: { if $0 == false { presentedSheet = nil } }
        )
    }

    private func clampSavedTempos() {
        metronomeBPM = GarageSlowTempoLogic.clampedConsumerBPM(metronomeBPM)
        guidedSwingBPM = GarageSlowTempoLogic.clampedConsumerBPM(guidedSwingBPM)
        session.synchronizeReadyBPM(activeSavedBPM)
    }

    private func migrateSavedSounds() {
        startClickRawValue = GarageMetronomeClickProfile.migrated(from: startClickRawValue).rawValue
        guidedRawValue = GarageGuidedSwingProfile.migrated(from: guidedRawValue).rawValue
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

                GarageTempoIconButton(
                    systemImage: "slider.horizontal.3",
                    label: "Open Control Room",
                    action: onControlRoom
                )
                .disabled(controlsEnabled == false)
                .opacity(controlsEnabled ? 1 : 0.65)
                .accessibilityIdentifier("tempo-builder-control-room")

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
    let sessionState: GarageTempoSessionState
    let reduceMotion: Bool
    let hasPendingTempo: Bool
    let playbackProgress: () -> Double
    let onStart: () -> Void
    let onStop: () -> Void
    private var isPlaying: Bool { sessionState == .playing }

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

            GarageGuidedSwingTimeline(
                state: visualState(progress: playbackProgress()),
                isPlaying: isPlaying,
                isResting: sessionState == .resting || sessionState == .countingIn,
                reduceMotion: reduceMotion,
                countdownValue: countdownValue,
                restProgress: restProgress,
                appliedBPM: appliedBPM,
                recipe: recipe
            )
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
    let appliedBPM: Double
    let recipe: ElasticSlingshotRecipe

    var body: some View {
        GeometryReader { proxy in
            let startPoint = point(at: 0, in: proxy.size)
            let topPoint = point(at: 0.58, in: proxy.size)
            let impactPoint = point(at: 1, in: proxy.size)
            let impactActive = isPlaying && state.motionProgress >= 0.90 && state.motionProgress <= 0.94

            ZStack {
                GarageGuidedSwingArc(
                    isPlaying: isPlaying,
                    isResting: isResting,
                    reduceMotion: reduceMotion,
                    appliedBPM: appliedBPM,
                    recipe: recipe
                )

                GarageGuidedSwingLandmark(title: "Start", isActive: state.activeBeat == 1 && isResting == false, alignment: .center)
                    .position(x: startPoint.x, y: startPoint.y + 30)
                GarageGuidedSwingLandmark(title: "Top", isActive: state.activeBeat == 2 && isResting == false, alignment: .center)
                    .position(x: topPoint.x, y: topPoint.y - 26)
                GarageGuidedSwingLandmark(title: "Impact", isActive: impactActive, alignment: .center)
                    .position(x: impactPoint.x, y: impactPoint.y + 30)

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

    private func point(at progress: Double, in size: CGSize) -> CGPoint {
        let progress = min(max(progress, 0), 1)
        let start = CGPoint(x: size.width * 0.09, y: size.height * 0.72)
        let top = CGPoint(x: size.width * 0.52, y: size.height * 0.18)
        let backswingControl = CGPoint(x: size.width * 0.24, y: size.height * 0.18)
        let downswingControl = CGPoint(x: size.width * 0.78, y: size.height * 0.18)
        let impact = CGPoint(x: size.width * 0.91, y: size.height * 0.72)

        if progress <= 0.58 {
            let t = progress / 0.58
            let inverse = 1 - t
            return CGPoint(
                x: (inverse * inverse * start.x) + (2 * inverse * t * backswingControl.x) + (t * t * top.x),
                y: (inverse * inverse * start.y) + (2 * inverse * t * backswingControl.y) + (t * t * top.y)
            )
        }

        let t = (progress - 0.58) / 0.42
        let inverse = 1 - t
        return CGPoint(
            x: (inverse * inverse * top.x) + (2 * inverse * t * downswingControl.x) + (t * t * impact.x),
            y: (inverse * inverse * top.y) + (2 * inverse * t * downswingControl.y) + (t * t * impact.y)
        )
    }
}

private struct GarageGuidedSwingArc: UIViewRepresentable {
    let isPlaying: Bool
    let isResting: Bool
    let reduceMotion: Bool
    let appliedBPM: Double
    let recipe: ElasticSlingshotRecipe

    func makeUIView(context: Context) -> GarageGuidedSwingArcView {
        GarageGuidedSwingArcView()
    }

    func updateUIView(_ uiView: GarageGuidedSwingArcView, context: Context) {
        uiView.update(
            isPlaying: isPlaying,
            isResting: isResting,
            reduceMotion: reduceMotion,
            appliedBPM: appliedBPM,
            recipe: recipe
        )
    }
}

private final class GarageGuidedSwingArcView: UIView {
    private let ambientArcLayer = CAShapeLayer()
    private let baseArcLayer = CAShapeLayer()
    private let readyArcGradient = CAGradientLayer()
    private let readyArcLayer = CAShapeLayer()
    private let deliveryArcGradient = CAGradientLayer()
    private let deliveryArcLayer = CAShapeLayer()
    private let activeArcGradient = CAGradientLayer()
    private let activeArcLayer = CAShapeLayer()
    private let impactTargetLayer = CAShapeLayer()
    private let impactPulseLayer = CAShapeLayer()
    private let trackingNode = CALayer()
    private var configuration: Configuration?
    private let goldColor = UIColor(red: 0.98, green: 0.75, blue: 0.18, alpha: 1)
    private let emeraldColor = UIColor(red: 0.09, green: 0.35, blue: 0.22, alpha: 1)
    private let mintTextColor = UIColor(red: 0.66, green: 0.84, blue: 0.70, alpha: 1)

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear

        ambientArcLayer.fillColor = UIColor.clear.cgColor
        ambientArcLayer.strokeColor = emeraldColor.withAlphaComponent(0.22).cgColor
        ambientArcLayer.lineCap = .round
        ambientArcLayer.lineWidth = 18
        ambientArcLayer.shadowColor = emeraldColor.cgColor
        ambientArcLayer.shadowOpacity = 0.30
        ambientArcLayer.shadowRadius = 14
        layer.addSublayer(ambientArcLayer)

        baseArcLayer.fillColor = UIColor.clear.cgColor
        baseArcLayer.lineCap = .round
        baseArcLayer.lineWidth = 5
        layer.addSublayer(baseArcLayer)

        readyArcLayer.fillColor = UIColor.clear.cgColor
        readyArcLayer.strokeColor = UIColor.white.cgColor
        readyArcLayer.lineCap = .round
        readyArcLayer.lineWidth = 9
        readyArcGradient.colors = [
            emeraldColor.withAlphaComponent(0.78).cgColor,
            mintTextColor.withAlphaComponent(0.72).cgColor,
            goldColor.withAlphaComponent(0.88).cgColor
        ]
        readyArcGradient.locations = [0, 0.58, 1]
        readyArcGradient.startPoint = CGPoint(x: 0, y: 0.5)
        readyArcGradient.endPoint = CGPoint(x: 1, y: 0.5)
        readyArcGradient.mask = readyArcLayer
        layer.addSublayer(readyArcGradient)

        deliveryArcLayer.fillColor = UIColor.clear.cgColor
        deliveryArcLayer.strokeColor = UIColor.white.cgColor
        deliveryArcLayer.lineCap = .round
        deliveryArcLayer.lineWidth = 15
        deliveryArcLayer.strokeStart = 0.58
        deliveryArcGradient.colors = [
            mintTextColor.withAlphaComponent(0.34).cgColor,
            goldColor.withAlphaComponent(0.92).cgColor
        ]
        deliveryArcGradient.locations = [0.58, 1]
        deliveryArcGradient.startPoint = CGPoint(x: 0, y: 0.5)
        deliveryArcGradient.endPoint = CGPoint(x: 1, y: 0.5)
        deliveryArcGradient.mask = deliveryArcLayer
        layer.addSublayer(deliveryArcGradient)

        activeArcLayer.fillColor = UIColor.clear.cgColor
        activeArcLayer.lineCap = .round
        activeArcLayer.lineWidth = 12
        activeArcLayer.strokeEnd = 0
        activeArcGradient.colors = [
            emeraldColor.cgColor,
            mintTextColor.cgColor,
            goldColor.cgColor
        ]
        activeArcGradient.locations = [0, 0.58, 1]
        activeArcGradient.startPoint = CGPoint(x: 0, y: 0.5)
        activeArcGradient.endPoint = CGPoint(x: 1, y: 0.5)
        activeArcGradient.mask = activeArcLayer
        layer.addSublayer(activeArcGradient)

        impactTargetLayer.fillColor = UIColor.clear.cgColor
        impactTargetLayer.strokeColor = goldColor.withAlphaComponent(0.46).cgColor
        impactTargetLayer.lineWidth = 2
        impactTargetLayer.shadowColor = goldColor.cgColor
        impactTargetLayer.shadowOpacity = 0.24
        impactTargetLayer.shadowRadius = 12
        layer.addSublayer(impactTargetLayer)

        impactPulseLayer.fillColor = UIColor.clear.cgColor
        impactPulseLayer.strokeColor = goldColor.cgColor
        impactPulseLayer.lineWidth = 5
        impactPulseLayer.opacity = 0
        layer.addSublayer(impactPulseLayer)

        trackingNode.bounds = CGRect(x: 0, y: 0, width: 17, height: 17)
        trackingNode.cornerRadius = 8.5
        trackingNode.backgroundColor = goldColor.cgColor
        trackingNode.shadowColor = goldColor.cgColor
        trackingNode.shadowOpacity = 0.42
        trackingNode.shadowRadius = 16
        layer.addSublayer(trackingNode)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        applyPath()
    }

    func update(
        isPlaying: Bool,
        isResting: Bool,
        reduceMotion: Bool,
        appliedBPM: Double,
        recipe: ElasticSlingshotRecipe
    ) {
        let newConfiguration = Configuration(
            isPlaying: isPlaying,
            isResting: isResting,
            reduceMotion: reduceMotion,
            appliedBPM: appliedBPM,
            recipe: recipe
        )
        let shouldStartCycle = configuration?.isPlaying != true && isPlaying
        configuration = newConfiguration
        applyAppearance()

        if shouldStartCycle {
            startMotionCycle()
        } else if isPlaying == false {
            stopMotion(at: 0)
        }
    }

    private func applyPath() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let path = kineticPath(in: bounds.size)
        ambientArcLayer.frame = bounds
        ambientArcLayer.path = path.cgPath
        baseArcLayer.frame = bounds
        baseArcLayer.path = path.cgPath
        readyArcGradient.frame = bounds
        readyArcLayer.frame = bounds
        readyArcLayer.path = path.cgPath
        deliveryArcGradient.frame = bounds
        deliveryArcLayer.frame = bounds
        deliveryArcLayer.path = path.cgPath
        activeArcGradient.frame = bounds
        activeArcLayer.frame = bounds
        activeArcLayer.path = path.cgPath
        impactTargetLayer.bounds = CGRect(x: 0, y: 0, width: 38, height: 38)
        impactTargetLayer.path = UIBezierPath(ovalIn: impactTargetLayer.bounds).cgPath
        impactTargetLayer.position = point(at: 1, in: bounds.size)
        impactPulseLayer.bounds = CGRect(x: 0, y: 0, width: 72, height: 72)
        impactPulseLayer.path = UIBezierPath(ovalIn: impactPulseLayer.bounds).cgPath
        impactPulseLayer.position = point(at: 1, in: bounds.size)

        if trackingNode.animation(forKey: "garageGuidedSwingPosition") == nil {
            trackingNode.position = point(at: 0, in: bounds.size)
            if configuration?.isPlaying == true {
                startMotionCycle()
            }
        }
    }

    private func applyAppearance() {
        guard let configuration else { return }
        let restingAlpha: CGFloat = configuration.isResting ? 0.12 : 0.24
        ambientArcLayer.opacity = configuration.isResting ? 0.38 : 0.72
        baseArcLayer.strokeColor = mintTextColor.withAlphaComponent(restingAlpha).cgColor
        activeArcLayer.strokeColor = UIColor.white.cgColor
        readyArcGradient.opacity = configuration.isResting ? 0.16 : (configuration.isPlaying ? 0.24 : 0.48)
        deliveryArcGradient.opacity = configuration.isResting ? 0.10 : (configuration.isPlaying ? 0.34 : 0.58)
        activeArcGradient.opacity = configuration.isPlaying && configuration.isResting == false ? 1 : 0
        impactTargetLayer.opacity = configuration.isResting ? 0.18 : (configuration.isPlaying ? 0.72 : 0.46)
        trackingNode.opacity = configuration.isPlaying && configuration.isResting == false ? 1 : 0
        trackingNode.backgroundColor = (
            configuration.isResting
                ? mintTextColor.withAlphaComponent(0.36)
                : goldColor
        ).cgColor
        trackingNode.shadowOpacity = configuration.isResting ? 0 : 0.58
        trackingNode.shadowRadius = 20
        trackingNode.bounds.size = configuration.reduceMotion ? CGSize(width: 17, height: 17) : CGSize(width: 20, height: 20)
        trackingNode.cornerRadius = trackingNode.bounds.width / 2
    }

    private func startMotionCycle() {
        guard let configuration, bounds.width > 0, bounds.height > 0 else { return }
        stopMotion(at: 0)
        let duration = configuration.recipe.guidedMotionDuration(for: configuration.appliedBPM)

        guard configuration.reduceMotion == false else {
            startReducedMotionCycle(configuration: configuration, duration: duration)
            return
        }

        let positionAnimation = CAKeyframeAnimation(keyPath: "position")
        positionAnimation.values = sampledMotionPoints(configuration: configuration, duration: duration)
        positionAnimation.duration = duration
        positionAnimation.calculationMode = .linear
        positionAnimation.isRemovedOnCompletion = false
        positionAnimation.fillMode = .forwards
        trackingNode.add(positionAnimation, forKey: "garageGuidedSwingPosition")

        let trailAnimation = CAKeyframeAnimation(keyPath: "strokeEnd")
        trailAnimation.values = sampledMotionProgress(configuration: configuration, duration: duration)
        trailAnimation.duration = duration
        trailAnimation.calculationMode = .linear
        trailAnimation.isRemovedOnCompletion = false
        trailAnimation.fillMode = .forwards
        activeArcLayer.add(trailAnimation, forKey: "garageGuidedSwingTrail")
        startImpactPulse(after: configuration.recipe.swingDuration(for: configuration.appliedBPM))
    }

    private func startImpactPulse(after delay: TimeInterval) {
        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [0, 0.92, 0]
        opacity.keyTimes = [0, 0.22, 1]

        let scale = CAKeyframeAnimation(keyPath: "transform.scale")
        scale.values = [0.3, 1, 1.35]
        scale.keyTimes = [0, 0.35, 1]

        let group = CAAnimationGroup()
        group.animations = [opacity, scale]
        group.beginTime = impactPulseLayer.convertTime(CACurrentMediaTime(), from: nil) + delay
        group.duration = 0.28
        impactPulseLayer.add(group, forKey: "garageGuidedSwingImpact")
    }

    private func startReducedMotionCycle(configuration: Configuration, duration: TimeInterval) {
        let animation = CAKeyframeAnimation(keyPath: "position")
        animation.values = [
            NSValue(cgPoint: point(at: 0, in: bounds.size)),
            NSValue(cgPoint: point(at: 0.58, in: bounds.size)),
            NSValue(cgPoint: point(at: 0.62, in: bounds.size)),
            NSValue(cgPoint: point(at: 1, in: bounds.size)),
            NSValue(cgPoint: point(at: 1, in: bounds.size)),
            NSValue(cgPoint: point(at: 1, in: bounds.size))
        ]
        animation.keyTimes = motionKeyTimes(configuration: configuration, duration: duration)
        animation.duration = duration
        animation.calculationMode = .discrete
        animation.isRemovedOnCompletion = false
        animation.fillMode = .forwards
        trackingNode.add(animation, forKey: "garageGuidedSwingPosition")

        let trailAnimation = CAKeyframeAnimation(keyPath: "strokeEnd")
        trailAnimation.values = [0.0, 0.58, 0.62, 1.0, 1.0, 1.0]
        trailAnimation.keyTimes = animation.keyTimes
        trailAnimation.duration = duration
        trailAnimation.calculationMode = .discrete
        trailAnimation.isRemovedOnCompletion = false
        trailAnimation.fillMode = .forwards
        activeArcLayer.add(trailAnimation, forKey: "garageGuidedSwingTrail")
    }

    private func stopMotion(at progress: CGFloat) {
        trackingNode.removeAnimation(forKey: "garageGuidedSwingPosition")
        activeArcLayer.removeAnimation(forKey: "garageGuidedSwingTrail")
        impactPulseLayer.removeAnimation(forKey: "garageGuidedSwingImpact")
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        trackingNode.position = point(at: progress, in: bounds.size)
        activeArcLayer.strokeEnd = progress
        CATransaction.commit()
    }

    private func motionKeyTimes(configuration: Configuration, duration: TimeInterval) -> [NSNumber] {
        let recipe = configuration.recipe
        let bpm = configuration.appliedBPM
        let takeawayEnd = recipe.takeawayDuration(for: bpm)
        let pauseEnd = takeawayEnd + recipe.pauseDuration(for: bpm)
        let impactStart = recipe.swingDuration(for: bpm)
        let impactEnd = recipe.swingDuration(for: bpm) + recipe.impactDuration
        return [0, takeawayEnd, pauseEnd, impactStart, impactEnd, duration].map {
            NSNumber(value: min(max($0 / max(duration, 0.01), 0), 1))
        }
    }

    private func kineticPath(in size: CGSize) -> UIBezierPath {
        let path = UIBezierPath()
        path.move(to: point(at: 0, in: size))
        path.addQuadCurve(to: point(at: 0.58, in: size), controlPoint: CGPoint(x: size.width * 0.24, y: size.height * 0.18))
        path.addQuadCurve(to: point(at: 1, in: size), controlPoint: CGPoint(x: size.width * 0.78, y: size.height * 0.18))
        return path
    }

    private func sampledMotionPoints(configuration: Configuration, duration: TimeInterval) -> [NSValue] {
        sampledMotionProgress(configuration: configuration, duration: duration).map {
            NSValue(cgPoint: point(at: CGFloat(truncating: $0), in: bounds.size))
        }
    }

    private func sampledMotionProgress(configuration: Configuration, duration: TimeInterval) -> [NSNumber] {
        let sampleCount = 120
        return (0...sampleCount).map { sample in
            let elapsed = duration * Double(sample) / Double(sampleCount)
            return NSNumber(value: visualProgress(at: elapsed, configuration: configuration))
        }
    }

    private func visualProgress(at elapsed: TimeInterval, configuration: Configuration) -> Double {
        let recipe = configuration.recipe
        let bpm = configuration.appliedBPM
        let takeawayEnd = recipe.takeawayDuration(for: bpm)
        let pauseEnd = takeawayEnd + recipe.pauseDuration(for: bpm)
        let impactStart = recipe.swingDuration(for: bpm)
        let followThroughEnd = impactStart + recipe.impactDuration + recipe.followThroughDuration

        if elapsed < takeawayEnd {
            return 0.58 * smoothstep(elapsed / max(takeawayEnd, 0.01))
        }
        if elapsed < pauseEnd {
            let progress = (elapsed - takeawayEnd) / max(pauseEnd - takeawayEnd, 0.01)
            return 0.58 + (0.02 * smoothstep(progress))
        }
        if elapsed < impactStart {
            let progress = (elapsed - pauseEnd) / max(impactStart - pauseEnd, 0.01)
            return 0.60 + (0.40 * pow(min(max(progress, 0), 1), 2.75))
        }
        if elapsed < followThroughEnd {
            return 1
        }
        return 1
    }

    private func smoothstep(_ value: Double) -> Double {
        let value = min(max(value, 0), 1)
        return value * value * (3 - (2 * value))
    }

    private func point(at progress: CGFloat, in size: CGSize) -> CGPoint {
        let progress = min(max(progress, 0), 1)
        let start = CGPoint(x: size.width * 0.09, y: size.height * 0.72)
        let top = CGPoint(x: size.width * 0.52, y: size.height * 0.18)
        let backswingControl = CGPoint(x: size.width * 0.24, y: size.height * 0.18)
        let downswingControl = CGPoint(x: size.width * 0.82, y: size.height * 0.22)
        let impact = CGPoint(x: size.width * 0.91, y: size.height * 0.72)

        if progress <= 0.58 {
            let t = progress / 0.58
            let inverse = 1 - t
            return CGPoint(
                x: (inverse * inverse * start.x) + (2 * inverse * t * backswingControl.x) + (t * t * top.x),
                y: (inverse * inverse * start.y) + (2 * inverse * t * backswingControl.y) + (t * t * top.y)
            )
        }

        let t = (progress - 0.58) / 0.42
        let inverse = 1 - t
        return CGPoint(
            x: (inverse * inverse * top.x) + (2 * inverse * t * downswingControl.x) + (t * t * impact.x),
            y: (inverse * inverse * top.y) + (2 * inverse * t * downswingControl.y) + (t * t * impact.y)
        )
    }

    private struct Configuration: Equatable {
        let isPlaying: Bool
        let isResting: Bool
        let reduceMotion: Bool
        let appliedBPM: Double
        let recipe: ElasticSlingshotRecipe
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
                .transaction { transaction in
                    transaction.animation = nil
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isActive ? Color(red: 0.11, green: 0.11, blue: 0.12) : GaragePremiumPalette.gold)
                        .shadow(color: isActive ? .clear : GaragePremiumPalette.gold.opacity(0.24), radius: 14, x: 0, y: 8)
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
                .transition(.opacity.combined(with: .scale(scale: 0.94)))
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
    let page: GarageTempoPage
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
        GarageGuidedSwingProfile.migrated(from: selectedGuidedRawValue)
    }

    private let metronomeSoundGroups: [(title: String, profiles: [GarageMetronomeClickProfile])] = [
        ("Crisp Markers", GarageMetronomeClickProfile.crispMarkers),
        ("Soft Practice", GarageMetronomeClickProfile.softPractice),
        ("Signal Accents", GarageMetronomeClickProfile.signalAccents),
        ("Digital", GarageMetronomeClickProfile.digitalSynthetic)
    ]

    private let guidedSoundGroups: [(title: String, profiles: [GarageGuidedSwingProfile])] = [
        ("Prototype Identities", GarageGuidedSwingProfile.prototypeIdentities)
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
                            Text(page.title)
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

                    modeSettings

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

    @ViewBuilder
    private var modeSettings: some View {
        if page == .metronome {
            GarageTempoSettingsGroup {
                GarageTempoActionValueRow(title: "Click Sound", value: selectedStartSound.title) {
                    toggleSoundChoices()
                }
                if showsSoundChoices {
                    GarageTempoSettingsDivider()
                    VStack(spacing: 0) {
                        ForEach(metronomeSoundGroups, id: \.title) { group in
                            soundGroupHeader(group.title, identifierPrefix: "metronome")

                            ForEach(group.profiles) { profile in
                                GarageTempoSoundRow(
                                    title: profile.title,
                                    subtitle: profile.character,
                                    isSelected: selectedStartRawValue == profile.rawValue,
                                    accessibilityHint: "Selects the metronome click sound"
                                ) {
                                    selectedStartRawValue = profile.rawValue
                                }
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        } else {
            GarageTempoSettingsGroup {
                GarageTempoActionValueRow(title: "Sound Style", value: selectedGuidedSound.title) {
                    toggleSoundChoices()
                }
                if showsSoundChoices {
                    GarageTempoSettingsDivider()
                    VStack(spacing: 0) {
                        ForEach(guidedSoundGroups, id: \.title) { group in
                            soundGroupHeader(group.title, identifierPrefix: "guided")

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
        }
    }

    private func soundGroupHeader(_ title: String, identifierPrefix: String) -> some View {
        Text(title.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(1.1)
            .foregroundStyle(GarageProTheme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 6)
            .accessibilityIdentifier("\(identifierPrefix)-sound-group-\(title)")
    }

    private func toggleSoundChoices() {
        withAnimation(.easeInOut(duration: 0.22)) {
            showsSoundChoices.toggle()
        }
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
    var accessibilityHint = "Plays a preview"
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
        .accessibilityHint(accessibilityHint)
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
