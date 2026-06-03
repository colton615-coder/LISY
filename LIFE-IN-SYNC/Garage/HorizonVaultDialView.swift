import SwiftUI

@MainActor
struct GarageTempoBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var audioEngine = ElasticSlingshotAudioEngine()
    @State private var beatsPerMinute: Double = GarageSlowTempoLogic.defaultAnchorBPM
    @State private var recipe = ElasticSlingshotRecipe()
    @State private var soundProfile: ElasticSlingshotSoundProfile = .elastic
    @State private var showsEngineRoom = false
    @State private var showsSwingCapture = false
    @State private var lastSwingCaptureURL: URL?
    @State private var playbackStartDate: Date?

    private var slowTempoLogic: GarageSlowTempoLogic {
        GarageSlowTempoLogic(anchorBPM: beatsPerMinute)
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

                Spacer(minLength: 12)

                GarageTempoBuilderHeader(
                    logic: slowTempoLogic,
                    recipe: recipe,
                    isPlaying: isPlaying,
                    soundProfile: soundProfile
                )

                Spacer(minLength: 16)

                TimelineView(.animation(minimumInterval: reduceMotion ? 0.25 : 1 / 30, paused: isPlaying == false)) { timeline in
                    let elapsedTime = playbackStartDate.map { timeline.date.timeIntervalSince($0) } ?? 0
                    let visualState = slowTempoLogic.visualState(elapsedTime: elapsedTime, isPlaying: isPlaying, recipe: recipe)

                    GarageTempoCockpitInstrument(
                        logic: slowTempoLogic,
                        recipe: recipe,
                        visualState: visualState,
                        isPlaying: isPlaying,
                        reduceMotion: reduceMotion
                    )
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: visualState.activeBeat)
                }

                Spacer(minLength: 16)

                GarageTempoBuilderControlDeck(
                    beatsPerMinute: $beatsPerMinute,
                    isPlaying: isPlaying,
                    soundProfile: soundProfile,
                    onPlayToggle: togglePlayback,
                    onOpenSettings: { showsEngineRoom = true }
                )
                .onChange(of: beatsPerMinute) { _, newValue in
                    updateAudioEngine(beatsPerMinute: newValue)
                }

                Spacer(minLength: 12)

                GarageTempoMicroMap(logic: slowTempoLogic)
                    .padding(.bottom, 12)
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: audioEngine.playbackState)
        .sheet(isPresented: $showsEngineRoom) {
            EngineRoomSettingsView(
                recipe: $recipe,
                soundProfile: $soundProfile,
                beatsPerMinute: beatsPerMinute
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .onDisappear {
                updateAudioEngine()
            }
        }
        .onChange(of: recipe) { _, _ in
            updateAudioEngine()
        }
        .onChange(of: soundProfile) { _, _ in
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
        .onDisappear {
            audioEngine.stop()
            playbackStartDate = nil
        }
        .navigationBarBackButtonHidden(true)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var isPlaying: Bool {
        audioEngine.playbackState == .playing
    }

    private func togglePlayback() {
        switch audioEngine.playbackState {
        case .stopped:
            playbackStartDate = Date()
            audioEngine.start(
                beatsPerMinute: beatsPerMinute,
                recipe: recipe,
                soundProfile: soundProfile
            )
        case .playing:
            audioEngine.stop()
            playbackStartDate = nil
        }
    }

    private func updateAudioEngine(beatsPerMinute updatedBeatsPerMinute: Double? = nil) {
        audioEngine.update(
            beatsPerMinute: updatedBeatsPerMinute ?? beatsPerMinute,
            recipe: recipe,
            soundProfile: soundProfile
        )
    }

    private func close() {
        audioEngine.stop()
        playbackStartDate = nil
        dismiss()
    }
}

private struct GarageTempoBuilderHeader: View {
    let logic: GarageSlowTempoLogic
    let recipe: ElasticSlingshotRecipe
    let isPlaying: Bool
    let soundProfile: ElasticSlingshotSoundProfile

    private let neonGreen = Color(red: 0, green: 1, blue: 0.67)
    private let neonYellow = Color(red: 1, green: 0.93, blue: 0.1)

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                Text("\(recipe.displayText) Swing Shape")
                    .font(.system(size: 27, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)

                Text("\(logic.tempoTitle) • \(logic.trainingMapText)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.70))
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
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

                Text(soundProfile.title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct GarageTempoCockpitInstrument: View {
    let logic: GarageSlowTempoLogic
    let recipe: ElasticSlingshotRecipe
    let visualState: GarageSlowTempoVisualState
    let isPlaying: Bool
    let reduceMotion: Bool

    private let neonGreen = Color(red: 0, green: 1, blue: 0.67)
    private let neonYellow = Color(red: 1, green: 0.93, blue: 0.1)

    var body: some View {
        GeometryReader { proxy in
            let ringSize = min(min(proxy.size.width, proxy.size.height), 318)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                neonGreen.opacity(isPlaying ? 0.20 : 0.12),
                                Color.white.opacity(0.045),
                                Color.white.opacity(0.018)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: ringSize * 0.56
                        )
                    )
                    .frame(width: ringSize, height: ringSize)
                    .shadow(color: neonGreen.opacity(isPlaying ? 0.18 : 0.08), radius: 34, x: 0, y: 18)

                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    .frame(width: ringSize, height: ringSize)

                Circle()
                    .trim(from: 0, to: max(visualState.cycleProgress, 0.012))
                    .stroke(
                        AngularGradient(
                            colors: [neonGreen.opacity(0.55), neonYellow, neonGreen.opacity(0.85)],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .frame(width: ringSize - 10, height: ringSize - 10)
                    .rotationEffect(.degrees(-90))
                    .opacity(isPlaying ? 1 : 0.40)

                GarageTempoSubdivisionTicks(
                    tickCount: logic.subdivisionMultiplier * 2,
                    activeProgress: visualState.cycleProgress,
                    isPlaying: isPlaying
                )
                .frame(width: ringSize - 40, height: ringSize - 40)

                ForEach(logic.landmarks) { landmark in
                    GarageTempoOrbitLandmark(
                        landmark: landmark,
                        isActive: visualState.activeBeat == landmark.beat && isPlaying && visualState.isResting == false,
                        isPlaying: isPlaying
                    )
                    .position(position(for: landmark.beat, center: center, radius: (ringSize / 2) - 20))
                }

                GarageTempoCenterReadout(
                    logic: logic,
                    recipe: recipe,
                    visualState: visualState,
                    isPlaying: isPlaying
                )
                .frame(width: ringSize * 0.64)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scaleEffect(isPlaying && reduceMotion == false ? 1.01 : 1)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(recipe.displayText) swing shape. \(logic.tempoTitle). \(visualState.phaseLabel). \(isPlaying ? visualState.phaseCue : logic.primaryCue)")
        }
        .frame(maxWidth: .infinity)
        .frame(height: 360)
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

private struct GarageTempoCenterReadout: View {
    let logic: GarageSlowTempoLogic
    let recipe: ElasticSlingshotRecipe
    let visualState: GarageSlowTempoVisualState
    let isPlaying: Bool

    private let neonGreen = Color(red: 0, green: 1, blue: 0.67)
    private let neonYellow = Color(red: 1, green: 0.93, blue: 0.1)

    var body: some View {
        VStack(spacing: 8) {
            Text(isPlaying ? visualState.phaseLabel.uppercased() : recipe.displayText.uppercased())
                .font(.system(size: isPlaying ? 44 : 38, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: neonGreen.opacity(0.16), radius: 16, x: 0, y: 8)
                .lineLimit(1)
                .minimumScaleFactor(0.58)

            Text(isPlaying ? phaseCaption : logic.trainingMapText.uppercased())
                .font(.system(size: 13, weight: .black, design: .rounded))
                .tracking(1.3)
                .foregroundStyle(visualState.activeLandmark.isTransition ? neonYellow : neonGreen)
                .lineLimit(1)
                .minimumScaleFactor(0.74)

            Text(isPlaying ? visualState.phaseCue : logic.primaryCue)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.74))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: 176)

            Text(logic.subdivisionText)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(neonGreen.opacity(0.66))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .padding(.top, 2)
        }
    }

    private var phaseCaption: String {
        visualState.isResting ? "RESET" : "PHASE \(visualState.activeBeat)"
    }
}

private struct GarageTempoOrbitLandmark: View {
    let landmark: GarageSlowTempoLandmark
    let isActive: Bool
    let isPlaying: Bool

    private let neonGreen = Color(red: 0, green: 1, blue: 0.67)
    private let neonYellow = Color(red: 1, green: 0.93, blue: 0.1)
    private let deepGreen = Color(red: 0.02, green: 0.04, blue: 0.024)

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(fillColor)
                    .frame(width: isActive ? 56 : 48, height: isActive ? 56 : 48)
                    .shadow(color: activeColor.opacity(isActive ? 0.40 : 0.16), radius: isActive ? 20 : 10, x: 0, y: 8)

                Circle()
                    .stroke(activeColor.opacity(isActive ? 0.95 : 0.38), lineWidth: isActive ? 2 : 1)
                    .frame(width: isActive ? 56 : 48, height: isActive ? 56 : 48)

                Text("\(landmark.beat)")
                    .font(.system(size: isActive ? 22 : 18, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(isActive ? deepGreen : .white)
            }

            Text(landmark.title)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(isActive ? 0.92 : 0.58))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.68)
                .frame(width: 82, height: 24)
        }
        .scaleEffect(isActive ? 1.07 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Beat \(landmark.beat), \(landmark.title), \(landmark.cue)")
    }

    private var activeColor: Color {
        landmark.isTransition ? neonYellow : neonGreen
    }

    private var fillColor: Color {
        if isActive {
            return activeColor
        }

        return neonGreen.opacity(isPlaying ? 0.14 : 0.09)
    }
}

private struct GarageTempoSubdivisionTicks: View {
    let tickCount: Int
    let activeProgress: Double
    let isPlaying: Bool

    private let neonGreen = Color(red: 0, green: 1, blue: 0.67)

    var body: some View {
        ZStack {
            ForEach(0..<max(tickCount, 1), id: \.self) { index in
                let angle = Angle.degrees(Double(index) / Double(max(tickCount, 1)) * 360 - 90)
                let tickProgress = Double(index) / Double(max(tickCount, 1))
                let isPassed = isPlaying && tickProgress <= activeProgress

                Capsule()
                    .fill(neonGreen.opacity(isPassed ? 0.68 : 0.20))
                    .frame(width: 3, height: isPassed ? 18 : 11)
                    .offset(y: -132)
                    .rotationEffect(angle)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct GarageTempoBuilderControlDeck: View {
    @Binding var beatsPerMinute: Double
    let isPlaying: Bool
    let soundProfile: ElasticSlingshotSoundProfile
    let onPlayToggle: () -> Void
    let onOpenSettings: () -> Void

    private let minimumBPM = 50.0
    private let maximumBPM = 90.0
    private let neonGreen = Color(red: 0, green: 1, blue: 0.67)
    private let neonYellow = Color(red: 1, green: 0.93, blue: 0.1)
    private let deepGreen = Color(red: 0.02, green: 0.04, blue: 0.024)

    var body: some View {
        HStack(spacing: 12) {
            if isPlaying == false {
                GarageTempoIconButton(systemImage: "minus") {
                    beatsPerMinute = max(beatsPerMinute - 1, minimumBPM)
                }
            }

            Button(action: onPlayToggle) {
                HStack(spacing: 10) {
                    Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                        .font(.system(size: 15, weight: .black))

                    Text(isPlaying ? "Stop" : "Start Tempo")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                }
                .foregroundStyle(deepGreen)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(isPlaying ? neonYellow : neonGreen)
                        .shadow(color: (isPlaying ? neonYellow : neonGreen).opacity(0.32), radius: 18, x: 0, y: 10)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPlaying ? "Stop tempo loop" : "Start tempo loop")

            if isPlaying == false {
                GarageTempoIconButton(systemImage: "plus") {
                    beatsPerMinute = min(beatsPerMinute + 1, maximumBPM)
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            Button(action: onOpenSettings) {
                Text(soundProfile.title)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.80))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.07))
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
            .offset(y: -34)
            .accessibilityLabel("Open Engine Room")
        }
    }
}

private struct GarageTempoIconButton: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(.white.opacity(0.88))
                .frame(width: 50, height: 58)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
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
                        .foregroundStyle(.white.opacity(0.46))
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                }
                .frame(maxWidth: .infinity)

                if landmark.id != logic.landmarks.last?.id {
                    Rectangle()
                        .fill(Color.white.opacity(0.09))
                        .frame(width: 1, height: 12)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.024))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.055), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(logic.trainingMapText)
    }
}

private struct GarageHorizonVaultBackground: View {
    var body: some View {
        ZStack {
            Color(red: 0.02, green: 0.04, blue: 0.024)

            LinearGradient(
                colors: [
                    Color(red: 0.035, green: 0.09, blue: 0.052),
                    Color(red: 0.015, green: 0.036, blue: 0.023),
                    Color(red: 0.01, green: 0.018, blue: 0.014)
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
            .foregroundStyle(.white.opacity(0.86))
            .accessibilityLabel("Back")

            Spacer()

            Button(action: onCapture) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.86))
            .accessibilityLabel("Record swing")

            Button(action: onSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.86))
            .accessibilityLabel("Engine room")
        }
    }
}

#Preview("Horizon Vault Dial") {
    NavigationStack {
        GarageTempoBuilderView()
    }
}
