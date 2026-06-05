import SwiftUI

@MainActor
struct EngineRoomSettingsView: View {
    @Binding var recipe: ElasticSlingshotRecipe
    @Binding var soundProfile: ElasticSlingshotSoundProfile
    @Binding var instrumentMode: GarageTempoInstrumentMode
    let beatsPerMinute: Double
    let allowsInstrumentChange: Bool

    @StateObject private var previewEngine = ElasticSlingshotAudioEngine()

    private let neonGreen = Color(red: 0, green: 1, blue: 0.67)
    private let deepGreen = Color(red: 0.02, green: 0.04, blue: 0.024)

    var body: some View {
        ZStack {
            EngineRoomBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    header

                    instrumentModeControl

                    swingShapeControl

                    soundSkinSelector

                    breakBetweenSwingsControl

                    previewSelectedSkinButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            setDefaultSoundForMode()
        }
        .onChange(of: instrumentMode) { _, _ in
            setDefaultSoundForMode()
        }
        .onDisappear {
            previewEngine.stop()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Engine Room")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            HStack(spacing: 8) {
                Image(systemName: "link")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(neonGreen)

                Text("Instrument setup")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(neonGreen)

                Spacer()

                Text(instrumentMode.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.82))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                Capsule()
                    .fill(neonGreen.opacity(0.08))
                    .overlay(
                        Capsule()
                            .stroke(neonGreen.opacity(0.24), lineWidth: 1)
                    )
            )
        }
    }

    private var instrumentModeControl: some View {
        EngineRoomPanel {
            VStack(alignment: .leading, spacing: 18) {
                EngineRoomSectionHeader(title: "Instrument", value: instrumentMode.title)

                HStack(spacing: 8) {
                    ForEach(GarageTempoInstrumentMode.allCases) { mode in
                        Button {
                            guard allowsInstrumentChange else { return }
                            instrumentMode = mode
                        } label: {
                            VStack(spacing: 3) {
                                Text(mode.title)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(instrumentMode == mode ? deepGreen : .white.opacity(0.88))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.72)

                                Text(mode.shortTitle)
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(instrumentMode == mode ? deepGreen.opacity(0.72) : .white.opacity(0.46))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.70)
                            }
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(instrumentMode == mode ? neonGreen : Color.white.opacity(0.055))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(instrumentMode == mode ? neonGreen.opacity(0.72) : Color.white.opacity(0.09), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(allowsInstrumentChange == false)
                        .accessibilityLabel(mode.title)
                        .accessibilityHint(mode.subtitle)
                    }
                }

                if allowsInstrumentChange == false {
                    Text("Stop playback to switch instruments.")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.46))
                }
            }
        }
    }

    private var soundSkinSelector: some View {
        EngineRoomPanel {
            VStack(alignment: .leading, spacing: 14) {
                EngineRoomSectionHeader(title: instrumentMode == .metronome ? "Click Voice" : "Build Voice", value: soundProfile.title)

                VStack(spacing: 8) {
                    ForEach(soundChoices) { choice in
                        Button {
                            soundProfile = choice.profile
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(choice.title)
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white)

                                    Text(choice.description)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.58))
                                }

                                Spacer()

                                Circle()
                                    .fill(soundProfile == choice.profile ? neonGreen : Color.white.opacity(0.18))
                                    .frame(width: 10, height: 10)
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 58)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(soundProfile == choice.profile ? neonGreen.opacity(0.12) : Color.white.opacity(0.045))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(soundProfile == choice.profile ? neonGreen.opacity(0.36) : Color.white.opacity(0.08), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(choice.title)
                        .accessibilityValue(soundProfile == choice.profile ? "Selected" : "Not selected")
                    }
                }
            }
        }
    }

    private var swingShapeControl: some View {
        EngineRoomPanel {
            VStack(alignment: .leading, spacing: 14) {
                EngineRoomSectionHeader(title: "Swing Shape", value: recipe.tempoRatio.displayTitle)

                Text("Controls how long the load feels before release.")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.50))

                VStack(spacing: 8) {
                    ForEach(ElasticSlingshotTempoRatio.allCases) { ratio in
                        Button {
                            var updatedRecipe = recipe
                            updatedRecipe.tempoRatio = ratio
                            recipe = updatedRecipe
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                                        Text(ratio.displayTitle)
                                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                                            .foregroundStyle(.white)

                                        Text(ratio.title)
                                            .font(.system(size: 11, weight: .black, design: .rounded))
                                            .monospacedDigit()
                                            .foregroundStyle(.white.opacity(0.46))
                                    }

                                    Text(ratio.feelLine)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.58))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.78)
                                }

                                Spacer()

                                Circle()
                                    .fill(recipe.tempoRatio == ratio ? neonGreen : Color.white.opacity(0.18))
                                    .frame(width: 10, height: 10)
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 62)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(recipe.tempoRatio == ratio ? neonGreen.opacity(0.12) : Color.white.opacity(0.045))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(recipe.tempoRatio == ratio ? neonGreen.opacity(0.36) : Color.white.opacity(0.08), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(ratio.displayTitle)
                        .accessibilityValue(recipe.tempoRatio == ratio ? "Selected" : ratio.title)
                        .accessibilityHint(ratio.feelLine)
                    }
                }
            }
        }
    }

    private var breakBetweenSwingsControl: some View {
        EngineRoomPanel {
            VStack(alignment: .leading, spacing: 16) {
                EngineRoomSectionHeader(title: "Break Between Swings", value: breakBetweenSwingsText)

                HStack(spacing: 12) {
                    EngineRoomStepButton(systemImage: "minus") {
                        var updatedRecipe = recipe
                        updatedRecipe.restInterval = max(updatedRecipe.restInterval - 1, 2)
                        recipe = updatedRecipe
                    }

                    Text(breakBetweenSwingsText)
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)

                    EngineRoomStepButton(systemImage: "plus") {
                        var updatedRecipe = recipe
                        updatedRecipe.restInterval = min(updatedRecipe.restInterval + 1, 8)
                        recipe = updatedRecipe
                    }
                }
            }
        }
    }

    private var previewSelectedSkinButton: some View {
        Button {
            previewEngine.playOneCycle(
                beatsPerMinute: beatsPerMinute,
                recipe: recipe,
                soundProfile: soundProfile,
                instrumentMode: instrumentMode
            )
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "waveform")
                    .font(.system(size: 18, weight: .bold))

                Text("Preview \(instrumentMode.title)")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(deepGreen)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(neonGreen)
                    .shadow(color: neonGreen.opacity(0.32), radius: 18, x: 0, y: 10)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Preview selected sound skin")
    }

    private var breakBetweenSwingsText: String {
        "\(Int(recipe.restInterval.rounded()))s"
    }

    private var soundChoices: [EngineRoomSoundChoice] {
        switch instrumentMode {
        case .metronome:
            return [
                EngineRoomSoundChoice(profile: .elastic, title: "Medium Wood", description: "Warm strict click with practice-room weight."),
                EngineRoomSoundChoice(profile: .pulse, title: "Clean Digital", description: "Crisp exact click with less body.")
            ]
        case .build:
            return [
                EngineRoomSoundChoice(profile: .elastic, title: "Pressure Swell", description: "Controlled rise, smooth power, precise strike."),
                EngineRoomSoundChoice(profile: .rubber, title: "Elastic Tension", description: "Tactile resistance without toy energy."),
                EngineRoomSoundChoice(profile: .airframe, title: "Air Build", description: "Subtle lift, clean shape, lighter snap."),
                EngineRoomSoundChoice(profile: .gravity, title: "Low Charge", description: "Deeper build with restrained power.")
            ]
        }
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

}

private struct EngineRoomSoundChoice: Identifiable {
    var id: ElasticSlingshotSoundProfile { profile }
    let profile: ElasticSlingshotSoundProfile
    let title: String
    let description: String
}

private struct EngineRoomStepButton: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 50, height: 46)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.07))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct EngineRoomSectionHeader: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white.opacity(0.68))
                .tracking(0.8)

            Spacer()

            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color(red: 0, green: 1, blue: 0.67))
        }
    }
}

private struct EngineRoomPanel<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.055))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.09), lineWidth: 1)
                    )
            )
    }
}

private struct EngineRoomBackground: View {
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

#Preview("Engine Room Settings") {
    @Previewable @State var recipe = ElasticSlingshotRecipe()
    @Previewable @State var soundProfile = ElasticSlingshotSoundProfile.elastic
    @Previewable @State var instrumentMode = GarageTempoInstrumentMode.build

    EngineRoomSettingsView(
        recipe: $recipe,
        soundProfile: $soundProfile,
        instrumentMode: $instrumentMode,
        beatsPerMinute: 75,
        allowsInstrumentChange: true
    )
}
