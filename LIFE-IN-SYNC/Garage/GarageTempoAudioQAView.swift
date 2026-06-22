#if DEBUG
import SwiftUI

@MainActor
struct GarageTempoAudioQAView: View {
    @StateObject private var audioEngine = ElasticSlingshotAudioEngine()
    @StateObject private var samplePreviewPlayer = GuidedSwingSamplePreviewPlayer()
    @State private var mode = GarageTempoInstrumentMode.metronome
    @State private var clickProfile = GarageMetronomeClickProfile.woodblock
    @State private var guidedProfile = GarageGuidedSwingProfile.cleanAscendingRailWarm
    @State private var beatsPerMinute = 60.0
    @State private var restInterval = 5.0
    @State private var showsSwingCapture = false

    private var recipe: ElasticSlingshotRecipe {
        var recipe = ElasticSlingshotRecipe()
        recipe.restInterval = restInterval
        recipe.subdivisionMultiplier = 1
        return recipe
    }

    var body: some View {
        ZStack {
            GarageProTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    statusCard
                    modeControl
                    quickTempoChecks
                    tempoControl

                    if mode == .metronome {
                        clickProfileGrid
                    } else {
                        guidedControls
                        GuidedSwingSamplePreviewSection(
                            player: samplePreviewPlayer,
                            onPreviewStart: { audioEngine.stop() }
                        )
                    }

                    transportControls
                    captureControl
                }
                .padding(20)
                .padding(.bottom, 24)
            }
        }
        .onChange(of: mode) { _, _ in
            samplePreviewPlayer.stop()
            updateRunningAudio()
        }
        .onChange(of: clickProfile) { _, _ in updateRunningAudio() }
        .onChange(of: guidedProfile) { _, _ in updateRunningAudio() }
        .onChange(of: beatsPerMinute) { _, _ in updateRunningAudio() }
        .onChange(of: restInterval) { _, _ in updateRunningAudio() }
        .fullScreenCover(isPresented: $showsSwingCapture) {
            SwingCaptureView { _ in
                showsSwingCapture = false
            } onCancel: {
                showsSwingCapture = false
            }
        }
        .onDisappear {
            samplePreviewPlayer.stop()
            audioEngine.stop()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Tempo Audio QA")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(GarageProTheme.textPrimary)

            Text("DEBUG-only real-device listening path")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(GarageProTheme.textSecondary)
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(audioEngine.statusText)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(GaragePremiumPalette.gold)

            Text("\(mode == .metronome ? clickProfile.title : guidedProfile.audioProfile.displayName) · \(Int(beatsPerMinute)) BPM · \(audioEngine.outputRouteText)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(GarageProTheme.textPrimary)

            Text("Guided Swing: fresh 3-2-1 after every restart · Rest: \(Int(restInterval))s silent · Capture continuity: open camera while running")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(GarageProTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(GarageProTheme.elevatedSurface.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(GarageProTheme.border, lineWidth: 1))
    }

    private var modeControl: some View {
        Picker("Instrument", selection: $mode) {
            Text("Metronome").tag(GarageTempoInstrumentMode.metronome)
            Text("Guided Swing").tag(GarageTempoInstrumentMode.build)
        }
        .pickerStyle(.segmented)
    }

    private var quickTempoChecks: some View {
        HStack(spacing: 8) {
            ForEach([(title: "Low", bpm: 48.0), (title: "Mid", bpm: 72.0), (title: "High", bpm: 108.0)], id: \.title) { check in
                Button {
                    beatsPerMinute = check.bpm
                } label: {
                    VStack(spacing: 2) {
                        Text(check.title)
                        Text("\(Int(check.bpm))")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                    }
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(beatsPerMinute == check.bpm ? GaragePremiumPalette.emeraldDeep : GarageProTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(beatsPerMinute == check.bpm ? GaragePremiumPalette.gold : GarageProTheme.insetSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var tempoControl: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("BPM")
                Spacer()
                Text("\(Int(beatsPerMinute))")
                    .monospacedDigit()
            }
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(GarageProTheme.textPrimary)

            Slider(value: $beatsPerMinute, in: 40...120, step: 1)
                .tint(GaragePremiumPalette.gold)
        }
    }

    private var clickProfileGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(GarageMetronomeClickProfile.allCases) { profile in
                qaChoice(title: profile.title, selected: clickProfile == profile) {
                    clickProfile = profile
                    preview(profile)
                }
            }
        }
    }

    private var guidedControls: some View {
        VStack(spacing: 12) {
            ForEach(GarageGuidedSwingProfile.qaListeningOrder) { profile in
                qaChoice(title: profile.audioProfile.displayName, selected: guidedProfile == profile) {
                    guidedProfile = profile
                    previewGuided(profile)
                }
            }

            Picker("Silent rest", selection: $restInterval) {
                ForEach([3.0, 5.0, 8.0, 10.0], id: \.self) { interval in
                    Text("\(Int(interval))s").tag(interval)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var transportControls: some View {
        HStack(spacing: 10) {
            Button(audioEngine.playbackState == .playing ? "Stop Loop" : "Loop Selected") {
                if audioEngine.playbackState == .playing {
                    audioEngine.stop()
                } else {
                    start()
                }
            }
            .buttonStyle(GarageTempoQAButtonStyle(primary: true))

            Button("Preview") {
                mode == .metronome ? preview(clickProfile) : previewGuided(guidedProfile)
            }
            .buttonStyle(GarageTempoQAButtonStyle(primary: false))
        }
    }

    private var captureControl: some View {
        Button("Open Swing Capture While Audio Runs") {
            showsSwingCapture = true
        }
        .buttonStyle(GarageTempoQAButtonStyle(primary: false))
    }

    private func qaChoice(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(selected ? GaragePremiumPalette.emeraldDeep : GarageProTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(selected ? GaragePremiumPalette.gold : GarageProTheme.insetSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func start() {
        samplePreviewPlayer.stop()
        audioEngine.start(
            beatsPerMinute: beatsPerMinute,
            recipe: recipe,
            soundProfile: guidedProfile.engineProfile,
            metronomeStartProfile: clickProfile,
            metronomeImpactProfile: clickProfile,
            guidedClicksEnabled: false,
            instrumentMode: mode
        )
    }

    private func updateRunningAudio() {
        guard audioEngine.playbackState == .playing else { return }
        audioEngine.update(
            beatsPerMinute: beatsPerMinute,
            recipe: recipe,
            soundProfile: guidedProfile.engineProfile,
            metronomeStartProfile: clickProfile,
            metronomeImpactProfile: clickProfile,
            guidedClicksEnabled: false,
            instrumentMode: mode
        )
    }

    private func preview(_ profile: GarageMetronomeClickProfile) {
        samplePreviewPlayer.stop()
        audioEngine.playOneCycle(
            beatsPerMinute: beatsPerMinute,
            recipe: recipe,
            soundProfile: guidedProfile.engineProfile,
            metronomeStartProfile: profile,
            metronomeImpactProfile: profile,
            guidedClicksEnabled: false,
            instrumentMode: .metronome
        )
    }

    private func previewGuided(_ profile: GarageGuidedSwingProfile) {
        samplePreviewPlayer.stop()
        audioEngine.playOneCycle(
            beatsPerMinute: beatsPerMinute,
            recipe: recipe,
            soundProfile: profile.engineProfile,
            metronomeStartProfile: clickProfile,
            metronomeImpactProfile: clickProfile,
            guidedClicksEnabled: false,
            instrumentMode: .build
        )
    }
}

private struct GarageTempoQAButtonStyle: ButtonStyle {
    let primary: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(primary ? GaragePremiumPalette.emeraldDeep : GarageProTheme.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(primary ? GaragePremiumPalette.gold : GarageProTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(GarageProTheme.border, lineWidth: primary ? 0 : 1))
            .opacity(configuration.isPressed ? 0.76 : 1)
    }
}
#endif
