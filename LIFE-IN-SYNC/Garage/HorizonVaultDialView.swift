import SwiftUI

@MainActor
struct GarageTempoBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var audioEngine = ElasticSlingshotAudioEngine()

    @AppStorage("garage.tempoBuilder.bpm") private var beatsPerMinute = 60.0
    @AppStorage("garage.tempoBuilder.click") private var clickRawValue = GarageMetronomeClickProfile.hardwood.rawValue
    @AppStorage("garage.tempoBuilder.guidedSound") private var guidedRawValue = GarageGuidedSwingProfile.tension.rawValue
    @AppStorage("garage.tempoBuilder.guidedClicks") private var guidedClicksEnabled = false
    @AppStorage("garage.tempoBuilder.restInterval") private var restInterval = 5.0

    @State private var selectedPage: GarageTempoPage = .metronome
    @State private var presentedSheet: GarageTempoSheet?
    @State private var showsSwingCapture = false
    @State private var playbackStartDate: Date?

    private var isPlaying: Bool {
        audioEngine.playbackState == .playing
    }

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
                    controlsEnabled: isPlaying == false,
                    onBack: close,
                    onCapture: { showsSwingCapture = true },
                    onSettings: { presentedSheet = .settings }
                )

                TabView(selection: $selectedPage) {
                    GarageMetronomePage(
                        beatsPerMinute: $beatsPerMinute,
                        selectedClick: selectedClick,
                        isPlaying: isPlaying && selectedPage == .metronome,
                        playbackStartDate: playbackStartDate,
                        reduceMotion: reduceMotion,
                        onOpenSounds: { presentedSheet = .metronomeSounds },
                        onPlayToggle: togglePlayback
                    )
                    .tag(GarageTempoPage.metronome)

                    GarageGuidedSwingPage(
                        selectedSound: selectedGuidedSound,
                        clicksEnabled: $guidedClicksEnabled,
                        beatsPerMinute: beatsPerMinute,
                        recipe: recipe,
                        isPlaying: isPlaying && selectedPage == .guidedSwing,
                        playbackStartDate: playbackStartDate,
                        reduceMotion: reduceMotion,
                        onOpenSounds: { presentedSheet = .guidedSounds },
                        onPlayToggle: togglePlayback
                    )
                    .tag(GarageTempoPage.guidedSwing)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .scrollDisabled(isPlaying)

                GarageTempoPageIndicator(selectedPage: selectedPage)
                    .padding(.bottom, 14)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedPage)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: audioEngine.playbackState)
        .onChange(of: selectedPage) { _, _ in
            stopPlayback()
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .metronomeSounds:
                GarageMetronomeSoundLibrary(
                    selectedRawValue: $clickRawValue,
                    beatsPerMinute: beatsPerMinute,
                    recipe: recipe
                )
            case .guidedSounds:
                GarageGuidedSoundLibrary(
                    selectedRawValue: $guidedRawValue,
                    beatsPerMinute: beatsPerMinute,
                    recipe: recipe
                )
            case .settings:
                GarageTempoSettingsSheet(restInterval: $restInterval)
            }
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

    private func togglePlayback() {
        if isPlaying {
            stopPlayback()
            return
        }

        playbackStartDate = Date()
        audioEngine.start(
            beatsPerMinute: beatsPerMinute,
            recipe: recipe,
            soundProfile: selectedGuidedSound.engineProfile,
            metronomeClickProfile: selectedClick,
            guidedClicksEnabled: selectedPage == .guidedSwing && guidedClicksEnabled,
            instrumentMode: selectedPage.instrumentMode
        )
    }

    private func stopPlayback() {
        guard isPlaying else { return }
        audioEngine.stop()
        playbackStartDate = nil
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
    case metronomeSounds
    case guidedSounds
    case settings

    var id: String { rawValue }
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
                GarageTempoIconButton(systemImage: "gearshape.fill", label: "Settings", action: onSettings)
            }
            .disabled(controlsEnabled == false)
            .opacity(controlsEnabled ? 1 : 0.34)
        }
        .frame(height: 46)
    }
}

private struct GarageMetronomePage: View {
    @Binding var beatsPerMinute: Double
    let selectedClick: GarageMetronomeClickProfile
    let isPlaying: Bool
    let playbackStartDate: Date?
    let reduceMotion: Bool
    let onOpenSounds: () -> Void
    let onPlayToggle: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            GarageTempoPageTitle(title: "Metronome", subtitle: "Set the pace. Let it repeat.")
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

            Slider(value: $beatsPerMinute, in: 40...120, step: 1)
                .tint(GaragePremiumPalette.gold)
                .disabled(isPlaying)
                .padding(.horizontal, 8)
                .accessibilityLabel("Tempo")

            GarageTempoSoundButton(
                title: selectedClick.title,
                subtitle: "Metronome sound",
                systemImage: "waveform",
                action: onOpenSounds
            )
            .disabled(isPlaying)
            .opacity(isPlaying ? 0.38 : 1)
            .padding(.top, 18)

            GarageTempoPrimaryButton(isPlaying: isPlaying, action: onPlayToggle)
                .padding(.top, 14)
                .padding(.bottom, 10)
        }
    }

    private func progress(at date: Date) -> Double {
        guard isPlaying, let playbackStartDate else { return 0.25 }
        let interval = 60 / max(beatsPerMinute, 1)
        return date.timeIntervalSince(playbackStartDate).truncatingRemainder(dividingBy: interval) / interval
    }
}

private struct GarageGuidedSwingPage: View {
    let selectedSound: GarageGuidedSwingProfile
    @Binding var clicksEnabled: Bool
    let beatsPerMinute: Double
    let recipe: ElasticSlingshotRecipe
    let isPlaying: Bool
    let playbackStartDate: Date?
    let reduceMotion: Bool
    let onOpenSounds: () -> Void
    let onPlayToggle: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            GarageTempoPageTitle(title: "Guided Swing", subtitle: "Hear the motion. Repeat the rhythm.")
                .padding(.top, 18)

            Spacer(minLength: 16)

            TimelineView(.animation(minimumInterval: reduceMotion ? 0.15 : 1 / 60, paused: isPlaying == false)) { timeline in
                GarageGuidedSwingArc(
                    state: visualState(at: timeline.date),
                    isPlaying: isPlaying,
                    reduceMotion: reduceMotion
                )
            }
            .frame(maxWidth: .infinity)
            .frame(height: 360)

            Spacer(minLength: 8)

            GarageTempoSoundButton(
                title: selectedSound.title,
                subtitle: "Guided sound",
                systemImage: "waveform.path",
                action: onOpenSounds
            )
            .disabled(isPlaying)
            .opacity(isPlaying ? 0.38 : 1)

            GarageTempoPrimaryButton(isPlaying: isPlaying, action: onPlayToggle)
                .padding(.top, 14)

            Toggle(isOn: $clicksEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Clicks")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(GarageProTheme.textPrimary)

                    Text("Layer the selected metronome sound")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(GarageProTheme.textSecondary)
                }
            }
            .tint(GaragePremiumPalette.gold)
            .disabled(isPlaying)
            .opacity(isPlaying ? 0.52 : 1)
            .padding(.horizontal, 4)
            .padding(.top, 16)
            .padding(.bottom, 10)
        }
    }

    private func visualState(at date: Date) -> GarageSlowTempoVisualState {
        let elapsed = playbackStartDate.map { date.timeIntervalSince($0) } ?? 0
        return recipe.slowTempoLogic(for: beatsPerMinute).visualState(
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
        guard isPlaying, reduceMotion == false else { return .degrees(0) }
        return .degrees(cos(progress * Double.pi * 2) * 29)
    }

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(GarageProTheme.elevatedSurface.opacity(0.72))
                .overlay(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(GarageProTheme.border, lineWidth: 1)
                )
                .shadow(color: GarageProTheme.darkShadow, radius: 24, x: 0, y: 18)

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
        }
        .accessibilityHidden(true)
    }
}

private struct GarageGuidedSwingArc: View {
    let state: GarageSlowTempoVisualState
    let isPlaying: Bool
    let reduceMotion: Bool

    var body: some View {
        GeometryReader { proxy in
            let rect = proxy.frame(in: .local).insetBy(dx: 28, dy: 34)
            let path = guidedPath(in: rect)
            let point = guidedPoint(progress: state.cycleProgress, in: rect)

            ZStack {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(GarageProTheme.elevatedSurface.opacity(0.68))
                    .overlay(
                        RoundedRectangle(cornerRadius: 34, style: .continuous)
                            .stroke(GarageProTheme.border, lineWidth: 1)
                    )
                    .shadow(color: GarageProTheme.darkShadow, radius: 24, x: 0, y: 18)

                path
                    .stroke(GaragePremiumPalette.mintText.opacity(0.13), style: StrokeStyle(lineWidth: 3, lineCap: .round))

                if isPlaying, state.isResting == false {
                    path
                        .trim(from: 0, to: state.cycleProgress)
                        .stroke(
                            LinearGradient(
                                colors: [GaragePremiumPalette.emerald, GaragePremiumPalette.gold],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round)
                        )

                    Circle()
                        .fill(GaragePremiumPalette.gold)
                        .frame(width: reduceMotion ? 18 : 24, height: reduceMotion ? 18 : 24)
                        .shadow(color: GaragePremiumPalette.gold.opacity(0.46), radius: 18)
                        .position(point)
                } else if isPlaying == false {
                    Circle()
                        .fill(GaragePremiumPalette.gold.opacity(0.82))
                        .frame(width: 18, height: 18)
                        .shadow(color: GaragePremiumPalette.gold.opacity(0.24), radius: 12)
                        .position(x: rect.minX, y: rect.maxY)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isPlaying ? "Guided swing running" : "Guided swing ready")
    }

    private func guidedPath(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addCurve(
                to: CGPoint(x: rect.midX + 24, y: rect.minY),
                control1: CGPoint(x: rect.minX + rect.width * 0.06, y: rect.midY),
                control2: CGPoint(x: rect.midX - 36, y: rect.minY)
            )
            path.addCurve(
                to: CGPoint(x: rect.maxX, y: rect.maxY - 24),
                control1: CGPoint(x: rect.maxX - 14, y: rect.minY + 10),
                control2: CGPoint(x: rect.maxX - 10, y: rect.midY)
            )
        }
    }

    private func guidedPoint(progress: Double, in rect: CGRect) -> CGPoint {
        let progress = min(max(progress, 0), 1)

        if progress <= 0.55 {
            let local = progress / 0.55
            return quadraticPoint(
                from: CGPoint(x: rect.minX, y: rect.maxY),
                control: CGPoint(x: rect.minX + rect.width * 0.16, y: rect.minY),
                to: CGPoint(x: rect.midX + 24, y: rect.minY),
                progress: local
            )
        }

        let local = (progress - 0.55) / 0.45
        return quadraticPoint(
            from: CGPoint(x: rect.midX + 24, y: rect.minY),
            control: CGPoint(x: rect.maxX, y: rect.minY + 20),
            to: CGPoint(x: rect.maxX, y: rect.maxY - 24),
            progress: local
        )
    }

    private func quadraticPoint(from start: CGPoint, control: CGPoint, to end: CGPoint, progress: Double) -> CGPoint {
        let inverse = 1 - progress
        return CGPoint(
            x: (inverse * inverse * start.x) + (2 * inverse * progress * control.x) + (progress * progress * end.x),
            y: (inverse * inverse * start.y) + (2 * inverse * progress * control.y) + (progress * progress * end.y)
        )
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

private struct GarageTempoSoundButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(GaragePremiumPalette.gold)
                    .frame(width: 38, height: 38)
                    .background(GaragePremiumPalette.gold.opacity(0.10), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(GarageProTheme.textPrimary)

                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(GarageProTheme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(GarageProTheme.textSecondary)
            }
            .padding(.horizontal, 14)
            .frame(height: 58)
            .background(GarageProTheme.insetSurface.opacity(0.78), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(GarageProTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct GarageTempoPrimaryButton: View {
    let isPlaying: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                    .font(.system(size: 15, weight: .black))

                Text(isPlaying ? "Stop" : "Start")
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
        .accessibilityLabel(isPlaying ? "Stop" : "Start")
    }
}

private struct GarageTempoPageIndicator: View {
    let selectedPage: GarageTempoPage

    var body: some View {
        HStack(spacing: 7) {
            ForEach(GarageTempoPage.allCases) { page in
                Capsule()
                    .fill(page == selectedPage ? GaragePremiumPalette.gold : GarageProTheme.textSecondary.opacity(0.28))
                    .frame(width: page == selectedPage ? 18 : 6, height: 6)
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

private struct GarageMetronomeSoundLibrary: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedRawValue: String
    let beatsPerMinute: Double
    let recipe: ElasticSlingshotRecipe
    @StateObject private var previewEngine = ElasticSlingshotAudioEngine()

    var body: some View {
        GarageTempoSheetScaffold(title: "Metronome Sounds", onDone: { dismiss() }) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(GarageMetronomeClickProfile.allCases) { profile in
                    GarageTempoSoundTile(
                        title: profile.title,
                        subtitle: profile.character,
                        isSelected: selectedRawValue == profile.rawValue
                    ) {
                        selectedRawValue = profile.rawValue
                        previewEngine.playOneCycle(
                            beatsPerMinute: beatsPerMinute,
                            recipe: recipe,
                            soundProfile: .elastic,
                            metronomeClickProfile: profile,
                            guidedClicksEnabled: false,
                            instrumentMode: .metronome
                        )
                    }
                }
            }
        }
        .onDisappear { previewEngine.stop() }
    }
}

private struct GarageGuidedSoundLibrary: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedRawValue: String
    let beatsPerMinute: Double
    let recipe: ElasticSlingshotRecipe
    @StateObject private var previewEngine = ElasticSlingshotAudioEngine()

    var body: some View {
        GarageTempoSheetScaffold(title: "Guided Sounds", onDone: { dismiss() }) {
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

private struct GarageTempoSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var restInterval: Double

    var body: some View {
        GarageTempoSheetScaffold(title: "Settings", onDone: { dismiss() }) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Rest Between Swings")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
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
                                .background(
                                    restInterval == interval ? GaragePremiumPalette.gold : GarageProTheme.insetSurface,
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
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
