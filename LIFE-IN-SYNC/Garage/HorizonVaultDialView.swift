import SwiftUI

@MainActor
struct GarageTempoBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var audioEngine = ElasticSlingshotAudioEngine()
    @State private var beatsPerMinute: Double = GarageSlowTempoLogic.defaultAnchorBPM
    @State private var recipe = ElasticSlingshotRecipe()
    @State private var soundProfile: ElasticSlingshotSoundProfile = .elastic
    @State private var instrumentMode: GarageTempoInstrumentMode = .build
    @State private var showsEngineRoom = false
    @State private var showsSwingCapture = false
    @State private var lastSwingCaptureURL: URL?
    @State private var playbackStartDate: Date?

    private var slowTempoLogic: GarageSlowTempoLogic {
        recipe.slowTempoLogic(for: beatsPerMinute)
    }

    private var isPlaying: Bool {
        audioEngine.playbackState == .playing
    }

    var body: some View {
        ZStack {
            GarageHorizonVaultBackground()

            VStack(spacing: 0) {
                GarageHorizonVaultTopBar(
                    onBack: close,
                    onCapture: { showsSwingCapture = true },
                    onSettings: { showsEngineRoom = true }
                )

                GarageTempoBuilderHeader(
                    logic: slowTempoLogic,
                    instrumentMode: instrumentMode,
                    isPlaying: isPlaying
                )
                .padding(.top, 14)

                Spacer(minLength: 12)

                TimelineView(.animation(minimumInterval: reduceMotion ? 0.25 : 1 / 30, paused: isPlaying == false)) { timeline in
                    let elapsedTime = playbackStartDate.map { timeline.date.timeIntervalSince($0) } ?? 0
                    let visualState = slowTempoLogic.visualState(elapsedTime: elapsedTime, isPlaying: isPlaying, recipe: recipe)

                    if isPlaying {
                        GarageTempoRunningInstrument(
                            mode: instrumentMode,
                            logic: slowTempoLogic,
                            visualState: visualState,
                            reduceMotion: reduceMotion
                        )
                        .transition(.scale(scale: 0.94).combined(with: .opacity))
                    } else {
                        GarageTempoInstrumentCarousel(
                            selectedMode: $instrumentMode,
                            logic: slowTempoLogic
                        )
                        .transition(.opacity)
                    }
                }

                Spacer(minLength: 16)

                GarageTempoBuilderControlDeck(
                    isPlaying: isPlaying,
                    instrumentMode: instrumentMode,
                    onPlayToggle: togglePlayback
                )

                if isPlaying == false {
                    GarageTempoMicroMap(logic: slowTempoLogic)
                        .padding(.top, 12)
                        .padding(.bottom, 12)
                        .transition(.opacity)
                } else {
                    Spacer(minLength: 12)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: audioEngine.playbackState)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: instrumentMode)
        .sheet(isPresented: $showsEngineRoom) {
            EngineRoomSettingsView(
                recipe: $recipe,
                soundProfile: $soundProfile,
                instrumentMode: $instrumentMode,
                beatsPerMinute: beatsPerMinute,
                allowsInstrumentChange: isPlaying == false
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .onDisappear {
                lockBalancedTiming()
                updateAudioEngine()
            }
        }
        .onChange(of: recipe) { _, _ in
            lockBalancedTiming()
            updateAudioEngine()
        }
        .onChange(of: soundProfile) { _, _ in
            updateAudioEngine()
        }
        .onChange(of: instrumentMode) { _, _ in
            setDefaultSoundForMode()
            updateAudioEngine()
        }
        .fullScreenCover(isPresented: $showsSwingCapture) {
            SwingCaptureView { url in
                lastSwingCaptureURL = url
                showsSwingCapture = false
            } onCancel: {
                showsSwingCapture = false
            }
        }
        .onAppear {
            lockBalancedTiming()
            setDefaultSoundForMode()
        }
        .onDisappear {
            audioEngine.stop()
            playbackStartDate = nil
        }
        .navigationBarBackButtonHidden(true)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func togglePlayback() {
        switch audioEngine.playbackState {
        case .stopped:
            lockBalancedTiming()
            playbackStartDate = Date()
            audioEngine.start(
                beatsPerMinute: beatsPerMinute,
                recipe: recipe,
                soundProfile: soundProfile,
                instrumentMode: instrumentMode
            )
        case .playing:
            audioEngine.stop()
            playbackStartDate = nil
        }
    }

    private func updateAudioEngine() {
        audioEngine.update(
            beatsPerMinute: beatsPerMinute,
            recipe: recipe,
            soundProfile: soundProfile,
            instrumentMode: instrumentMode
        )
    }

    private func lockBalancedTiming() {
        guard recipe.tempoRatio != .tour else { return }
        recipe.tempoRatio = .tour
    }

    private func setDefaultSoundForMode() {
        switch instrumentMode {
        case .metronome:
            if soundProfile != .elastic && soundProfile != .pulse {
                soundProfile = .elastic
            }
        case .build:
            if soundProfile == .pulse || soundProfile == .glass || soundProfile == .reed || soundProfile == .storm {
                soundProfile = .elastic
            }
        }
    }

    private func close() {
        audioEngine.stop()
        playbackStartDate = nil
        dismiss()
    }
}

private struct GarageTempoBuilderHeader: View {
    let logic: GarageSlowTempoLogic
    let instrumentMode: GarageTempoInstrumentMode
    let isPlaying: Bool

    private let neonGreen = Color(red: 0, green: 1, blue: 0.67)
    private let neonYellow = Color(red: 1, green: 0.93, blue: 0.1)

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                Text(logic.trainingMapText)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text("\(logic.tempoTitle) • \(instrumentMode.shortTitle)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.68))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 7) {
                Text(isPlaying ? "LIVE" : "READY")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(isPlaying ? .black : neonGreen)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(isPlaying ? neonYellow : neonGreen.opacity(0.12))
                    )
                    .overlay(
                        Capsule()
                            .stroke(isPlaying ? neonYellow.opacity(0.70) : neonGreen.opacity(0.28), lineWidth: 1)
                    )

                Text(instrumentMode.title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.56))
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct GarageTempoInstrumentCarousel: View {
    @Binding var selectedMode: GarageTempoInstrumentMode
    let logic: GarageSlowTempoLogic

    var body: some View {
        TabView(selection: $selectedMode) {
            ForEach(GarageTempoInstrumentMode.allCases) { mode in
                GarageTempoInstrumentPreviewCard(
                    mode: mode,
                    isSelected: selectedMode == mode,
                    logic: logic
                )
                .padding(.horizontal, 2)
                .tag(mode)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .frame(height: 392)
        .accessibilityLabel("Tempo instrument selector")
    }
}

private struct GarageTempoInstrumentPreviewCard: View {
    let mode: GarageTempoInstrumentMode
    let isSelected: Bool
    let logic: GarageSlowTempoLogic

    private let neonGreen = Color(red: 0, green: 1, blue: 0.67)
    private let neonYellow = Color(red: 1, green: 0.93, blue: 0.1)

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(mode.title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.82))

                    Text(mode.subtitle)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.44))
                }

                Spacer()

                Text(logic.trainingMapText)
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(mode == .build ? neonYellow.opacity(0.78) : neonGreen.opacity(0.72))
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }

            ZStack {
                if mode == .metronome {
                    GarageTempoPendulumInstrument(
                        logic: logic,
                        visualState: .preview,
                        isPreview: true
                    )
                } else {
                    GarageTempoBuildDialInstrument(
                        logic: logic,
                        visualState: .preview,
                        reduceMotion: false,
                        isPreview: true
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 286)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(isSelected ? 0.075 : 0.045),
                            Color.white.opacity(0.028)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(isSelected ? 0.16 : 0.075), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.30), radius: 22, x: 0, y: 18)
        )
        .padding(.vertical, 8)
    }
}

private struct GarageTempoRunningInstrument: View {
    let mode: GarageTempoInstrumentMode
    let logic: GarageSlowTempoLogic
    let visualState: GarageSlowTempoVisualState
    let reduceMotion: Bool

    var body: some View {
        Group {
            if mode == .metronome {
                GarageTempoPendulumInstrument(
                    logic: logic,
                    visualState: visualState,
                    isPreview: false
                )
            } else {
                GarageTempoBuildDialInstrument(
                    logic: logic,
                    visualState: visualState,
                    reduceMotion: reduceMotion,
                    isPreview: false
                )
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 410)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(logic.trainingMapText). \(visualState.phaseLabel). \(visualState.phaseCue)")
    }
}

private struct GarageTempoBuildDialInstrument: View {
    let logic: GarageSlowTempoLogic
    let visualState: GarageSlowTempoVisualState
    let reduceMotion: Bool
    let isPreview: Bool

    private let neonGreen = Color(red: 0, green: 1, blue: 0.67)
    private let neonYellow = Color(red: 1, green: 0.93, blue: 0.1)
    private let deepCeramic = Color(red: 0.018, green: 0.027, blue: 0.023)

    var body: some View {
        GeometryReader { proxy in
            let ringSize = min(min(proxy.size.width, proxy.size.height), isPreview ? 248 : 332)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let progress = isPreview ? 0.34 : visualState.cycleProgress

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.055),
                                deepCeramic,
                                Color.black.opacity(0.26)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: ringSize * 0.58
                        )
                    )
                    .frame(width: ringSize, height: ringSize)
                    .shadow(color: Color.black.opacity(0.42), radius: 30, x: 0, y: 18)

                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    .frame(width: ringSize, height: ringSize)

                Circle()
                    .trim(from: 0, to: max(progress, 0.018))
                    .stroke(
                        AngularGradient(
                            colors: [neonGreen.opacity(0.35), neonGreen.opacity(0.82), neonYellow.opacity(0.92)],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: isPreview ? 6 : 8, lineCap: .round)
                    )
                    .frame(width: ringSize - 12, height: ringSize - 12)
                    .rotationEffect(.degrees(-118))
                    .shadow(color: activeColor.opacity(isPreview ? 0.18 : 0.28), radius: isPreview ? 10 : 18)

                GarageTempoDialTicks(
                    count: 36,
                    activeProgress: progress,
                    isPreview: isPreview
                )
                .frame(width: ringSize - 36, height: ringSize - 36)

                ForEach(logic.landmarks) { landmark in
                    GarageTempoLandmarkNode(
                        landmark: landmark,
                        isActive: visualState.activeBeat == landmark.beat && visualState.isResting == false && isPreview == false,
                        isPreview: isPreview
                    )
                    .position(position(for: landmark.beat, center: center, radius: (ringSize / 2) - 20))
                }

                GarageTempoBuildCore(
                    visualState: visualState,
                    isPreview: isPreview
                )
                .frame(width: ringSize * 0.58, height: ringSize * 0.58)
                .scaleEffect(visualState.activeBeat == 3 && reduceMotion == false && isPreview == false ? 1.06 : 1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var activeColor: Color {
        visualState.activeLandmark.isTransition ? neonYellow : neonGreen
    }

    private func position(for beat: Int, center: CGPoint, radius: CGFloat) -> CGPoint {
        let degrees: Double
        switch beat {
        case 1:
            degrees = 220
        case 2:
            degrees = 270
        default:
            degrees = 320
        }

        let radians = degrees * Double.pi / 180
        return CGPoint(
            x: center.x + cos(radians) * radius,
            y: center.y + sin(radians) * radius
        )
    }
}

private struct GarageTempoBuildCore: View {
    let visualState: GarageSlowTempoVisualState
    let isPreview: Bool

    private let neonGreen = Color(red: 0, green: 1, blue: 0.67)
    private let neonYellow = Color(red: 1, green: 0.93, blue: 0.1)

    var body: some View {
        VStack(spacing: 9) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.045))
                    .frame(width: isPreview ? 62 : 76, height: isPreview ? 62 : 76)
                    .overlay(
                        Circle()
                            .stroke(activeColor.opacity(0.62), lineWidth: 1)
                    )

                Circle()
                    .fill(activeColor)
                    .frame(width: isPreview ? 10 : 14, height: isPreview ? 10 : 14)
                    .shadow(color: activeColor.opacity(0.50), radius: 14)
            }

            Text(isPreview ? "SMOOTH" : visualState.phaseLabel.uppercased())
                .font(.system(size: isPreview ? 18 : 24, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.68)

            Text(isPreview ? "controlled pressure" : visualState.phaseCue)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.74)
        }
    }

    private var activeColor: Color {
        visualState.activeLandmark.isTransition ? neonYellow : neonGreen
    }
}

private struct GarageTempoPendulumInstrument: View {
    let logic: GarageSlowTempoLogic
    let visualState: GarageSlowTempoVisualState
    let isPreview: Bool

    private let neonGreen = Color(red: 0, green: 1, blue: 0.67)
    private let neonYellow = Color(red: 1, green: 0.93, blue: 0.1)

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let pivot = CGPoint(x: width / 2, y: isPreview ? 44 : 58)
            let length = min(width * 0.34, height * 0.58)
            let angle = pendulumAngle
            let bob = CGPoint(
                x: pivot.x + sin(angle) * length,
                y: pivot.y + cos(angle) * length
            )

            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color.white.opacity(isPreview ? 0.025 : 0.035))
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .frame(width: width * 0.88, height: height * 0.86)
                    .position(x: width / 2, y: height / 2)

                Path { path in
                    path.move(to: CGPoint(x: width * 0.22, y: pivot.y + 4))
                    path.addQuadCurve(
                        to: CGPoint(x: width * 0.78, y: pivot.y + 4),
                        control: CGPoint(x: width / 2, y: pivot.y + length * 0.24)
                    )
                }
                .stroke(Color.white.opacity(0.16), style: StrokeStyle(lineWidth: 1, lineCap: .round))

                Path { path in
                    path.move(to: pivot)
                    path.addLine(to: bob)
                }
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.50), activeColor.opacity(0.92)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: isPreview ? 4 : 5, lineCap: .round)
                )
                .shadow(color: activeColor.opacity(isPreview ? 0.16 : 0.26), radius: 16)

                Circle()
                    .fill(Color.white.opacity(0.72))
                    .frame(width: 10, height: 10)
                    .position(pivot)

                Circle()
                    .fill(activeColor)
                    .frame(width: isPreview ? 42 : 54, height: isPreview ? 42 : 54)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.42), lineWidth: 1)
                    )
                    .shadow(color: activeColor.opacity(0.34), radius: 18, x: 0, y: 10)
                    .position(bob)

                VStack(spacing: 8) {
                    Spacer()

                    Text(isPreview ? "SET  SMOOTH  STRIKE" : visualState.phaseLabel.uppercased())
                        .font(.system(size: isPreview ? 14 : 23, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.70)

                    Text(isPreview ? "strict click count" : visualState.phaseCue)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                }
                .padding(.bottom, isPreview ? 18 : 26)
                .frame(width: width)
            }
        }
    }

    private var pendulumAngle: Double {
        let progress = isPreview ? 0.62 : visualState.cycleProgress
        return sin(progress * Double.pi * 2) * 0.52
    }

    private var activeColor: Color {
        visualState.activeLandmark.isTransition ? neonYellow : neonGreen
    }
}

private struct GarageTempoDialTicks: View {
    let count: Int
    let activeProgress: Double
    let isPreview: Bool

    private let neonGreen = Color(red: 0, green: 1, blue: 0.67)

    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { index in
                let angle = Angle.degrees(Double(index) / Double(count) * 360 - 90)
                let tickProgress = Double(index) / Double(count)
                let isPassed = tickProgress <= activeProgress

                Capsule()
                    .fill(isPassed ? neonGreen.opacity(isPreview ? 0.36 : 0.56) : Color.white.opacity(0.14))
                    .frame(width: 2, height: index % 3 == 0 ? 14 : 8)
                    .offset(y: -126)
                    .rotationEffect(angle)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct GarageTempoLandmarkNode: View {
    let landmark: GarageSlowTempoLandmark
    let isActive: Bool
    let isPreview: Bool

    private let neonGreen = Color(red: 0, green: 1, blue: 0.67)
    private let neonYellow = Color(red: 1, green: 0.93, blue: 0.1)
    private let deepGreen = Color(red: 0.02, green: 0.04, blue: 0.024)

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(isActive ? activeColor : Color.white.opacity(isPreview ? 0.07 : 0.05))
                    .frame(width: isActive ? 54 : 46, height: isActive ? 54 : 46)
                    .shadow(color: activeColor.opacity(isActive ? 0.34 : 0.10), radius: isActive ? 18 : 8, x: 0, y: 8)

                Circle()
                    .stroke(activeColor.opacity(isActive ? 0.90 : 0.34), lineWidth: isActive ? 2 : 1)
                    .frame(width: isActive ? 54 : 46, height: isActive ? 54 : 46)

                Text("\(landmark.beat)")
                    .font(.system(size: isActive ? 21 : 16, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(isActive ? deepGreen : .white.opacity(0.86))
            }

            Text(landmark.title)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(isActive ? 0.90 : 0.52))
                .lineLimit(1)
                .minimumScaleFactor(0.70)
        }
        .scaleEffect(isActive ? 1.06 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Beat \(landmark.beat), \(landmark.title), \(landmark.cue)")
    }

    private var activeColor: Color {
        landmark.isTransition ? neonYellow : neonGreen
    }
}

private struct GarageTempoBuilderControlDeck: View {
    let isPlaying: Bool
    let instrumentMode: GarageTempoInstrumentMode
    let onPlayToggle: () -> Void

    private let neonGreen = Color(red: 0, green: 1, blue: 0.67)
    private let neonYellow = Color(red: 1, green: 0.93, blue: 0.1)
    private let deepGreen = Color(red: 0.02, green: 0.04, blue: 0.024)

    var body: some View {
        Button(action: onPlayToggle) {
            HStack(spacing: 10) {
                Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                    .font(.system(size: 15, weight: .black))

                Text(isPlaying ? "Stop" : "Start \(instrumentMode.title)")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
            }
            .foregroundStyle(deepGreen)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isPlaying ? neonYellow : neonGreen)
                    .shadow(color: (isPlaying ? neonYellow : neonGreen).opacity(0.30), radius: 18, x: 0, y: 10)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPlaying ? "Stop tempo loop" : "Start \(instrumentMode.title)")
    }
}

private struct GarageTempoMicroMap: View {
    let logic: GarageSlowTempoLogic

    private let neonGreen = Color(red: 0, green: 1, blue: 0.67)

    var body: some View {
        HStack(spacing: 8) {
            ForEach(logic.landmarks) { landmark in
                HStack(spacing: 5) {
                    Text("\(landmark.beat)")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(landmark.isTransition ? Color(red: 1, green: 0.93, blue: 0.1) : neonGreen)

                    Text(landmark.title)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.42))
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                }
                .frame(maxWidth: .infinity)

                if landmark.id != logic.landmarks.last?.id {
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 1, height: 12)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.022))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.050), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(logic.trainingMapText)
    }
}

private struct GarageHorizonVaultBackground: View {
    var body: some View {
        ZStack {
            Color(red: 0.015, green: 0.021, blue: 0.019)

            LinearGradient(
                colors: [
                    Color(red: 0.045, green: 0.060, blue: 0.052),
                    Color(red: 0.018, green: 0.026, blue: 0.024),
                    Color(red: 0.008, green: 0.012, blue: 0.011)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

private struct GarageHorizonVaultTopBar: View {
    let onBack: () -> Void
    let onCapture: () -> Void
    let onSettings: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.84))
            .accessibilityLabel("Back")

            Spacer()

            Button(action: onCapture) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.84))
            .accessibilityLabel("Record swing")

            Button(action: onSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.84))
            .accessibilityLabel("Engine room")
        }
    }
}

private extension GarageSlowTempoVisualState {
    static var preview: GarageSlowTempoVisualState {
        let logic = GarageSlowTempoLogic()
        return GarageSlowTempoVisualState(
            elapsedInCycle: 0,
            cycleProgress: 0.34,
            activeBeat: 2,
            activeLandmark: logic.landmarks[1],
            nextLandmark: logic.landmarks[2],
            phaseLabel: "Smooth",
            phaseCue: "Stay smooth.",
            isResting: false
        )
    }
}

#Preview("Horizon Vault Dial") {
    NavigationStack {
        GarageTempoBuilderView()
    }
}
