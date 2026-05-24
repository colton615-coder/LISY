import SwiftUI

@MainActor
struct EngineRoomSettingsView: View {
    @Binding var recipe: ElasticSlingshotRecipe
    @Binding var soundProfile: ElasticSlingshotSoundProfile
    @Binding var impactTone: ToneProfile
    @Binding var impactModifier: ShapeModifier
    let beatsPerMinute: Double

    @StateObject private var previewEngine = ElasticSlingshotAudioEngine()

    private let neonGreen = Color(red: 0, green: 1, blue: 0.67)
    private let deepGreen = Color(red: 0.02, green: 0.04, blue: 0.024)

    var body: some View {
        ZStack {
            EngineRoomBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    header

                    ratioTuner

                    loadProfileSelector

                    toneVault

                    breakBetweenSwingsControl

                    testToneButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
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

                Text("Linked recipe")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(neonGreen)

                Spacer()

                Text(recipe.displayText)
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

    private var ratioTuner: some View {
        EngineRoomPanel {
            VStack(alignment: .leading, spacing: 18) {
                EngineRoomSectionHeader(title: "Ratio Tuner", value: recipe.displayText)

                HStack(spacing: 8) {
                    ForEach(ElasticSlingshotTempoRatio.allCases) { ratio in
                        Button {
                            var updatedRecipe = recipe
                            updatedRecipe.tempoRatio = ratio
                            recipe = updatedRecipe
                            previewEngine.playOneCycle(
                                beatsPerMinute: beatsPerMinute,
                                recipe: updatedRecipe,
                                soundProfile: soundProfile,
                                impactTone: impactTone,
                                impactModifier: impactModifier
                            )
                        } label: {
                            Text(ratio.title)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(recipe.tempoRatio == ratio ? deepGreen : .white.opacity(0.84))
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(recipe.tempoRatio == ratio ? neonGreen : Color.white.opacity(0.055))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(recipe.tempoRatio == ratio ? neonGreen.opacity(0.72) : Color.white.opacity(0.09), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var loadProfileSelector: some View {
        EngineRoomPanel {
            VStack(alignment: .leading, spacing: 14) {
                EngineRoomSectionHeader(title: "Load Profile", value: soundProfile.title)

                VStack(spacing: 8) {
                    ForEach(ElasticSlingshotSoundProfile.allCases) { profile in
                        Button {
                            soundProfile = profile
                            previewEngine.playOneCycle(
                                beatsPerMinute: beatsPerMinute,
                                recipe: recipe,
                                soundProfile: profile,
                                impactTone: impactTone,
                                impactModifier: impactModifier
                            )
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(profile.title)
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white)

                                    Text(profile.description)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.58))
                                }

                                Spacer()

                                Circle()
                                    .fill(soundProfile == profile ? neonGreen : Color.white.opacity(0.18))
                                    .frame(width: 10, height: 10)
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 58)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(soundProfile == profile ? neonGreen.opacity(0.12) : Color.white.opacity(0.045))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(soundProfile == profile ? neonGreen.opacity(0.36) : Color.white.opacity(0.08), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(profile.title)
                        .accessibilityValue(soundProfile == profile ? "Selected" : "Not selected")
                    }
                }
            }
        }
    }

    private var toneVault: some View {
        EngineRoomPanel {
            VStack(alignment: .leading, spacing: 18) {
                EngineRoomSectionHeader(title: "Tone Vault", value: impactTone.name)

                ForEach(ToneCategory.allCases) { category in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(category.rawValue)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white.opacity(0.58))
                            .tracking(0.7)

                        LazyVGrid(
                            columns: [
                                GridItem(.adaptive(minimum: 132), spacing: 8)
                            ],
                            alignment: .leading,
                            spacing: 8
                        ) {
                            ForEach(ToneLibrary.profiles(in: category)) { tone in
                                toneProfileButton(tone)
                            }
                        }
                    }
                }

                shapeModifierSelector
            }
        }
    }

    private var shapeModifierSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            EngineRoomSectionHeader(title: "Shape", value: impactModifier.rawValue)

            HStack(spacing: 8) {
                ForEach(ShapeModifier.allCases) { modifier in
                    Button {
                        impactModifier = modifier
                        previewImpactTone(modifier: modifier)
                    } label: {
                        Text(modifier.shortTitle)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .foregroundStyle(impactModifier == modifier ? deepGreen : .white.opacity(0.78))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(impactModifier == modifier ? neonGreen : Color.white.opacity(0.055))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(impactModifier == modifier ? neonGreen.opacity(0.72) : Color.white.opacity(0.09), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(modifier.rawValue)
                    .accessibilityValue(impactModifier == modifier ? "Selected" : "Not selected")
                }
            }
        }
    }

    private func toneProfileButton(_ tone: ToneProfile) -> some View {
        let isSelected = impactTone == tone

        return Button {
            impactTone = tone
            previewImpactTone(tone: tone)
        } label: {
            HStack(spacing: 9) {
                Circle()
                    .fill(isSelected ? neonGreen : Color.white.opacity(0.16))
                    .frame(width: 8, height: 8)

                Text(tone.name)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .foregroundStyle(.white.opacity(isSelected ? 0.96 : 0.74))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .frame(minHeight: 48)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? neonGreen.opacity(0.12) : Color.white.opacity(0.045))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? neonGreen.opacity(0.38) : Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tone.name)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
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

    private var testToneButton: some View {
        Button {
            previewEngine.playOneCycle(
                beatsPerMinute: beatsPerMinute,
                recipe: recipe,
                soundProfile: soundProfile,
                impactTone: impactTone,
                impactModifier: impactModifier
            )
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "waveform")
                    .font(.system(size: 18, weight: .bold))

                Text("Test Tones")
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
        .accessibilityLabel("Test Tones")
    }

    private var breakBetweenSwingsText: String {
        "\(Int(recipe.restInterval.rounded()))s"
    }

    private func previewImpactTone(
        tone: ToneProfile? = nil,
        modifier: ShapeModifier? = nil
    ) {
        previewEngine.playOneCycle(
            beatsPerMinute: beatsPerMinute,
            recipe: recipe,
            soundProfile: soundProfile,
            impactTone: tone ?? impactTone,
            impactModifier: modifier ?? impactModifier
        )
    }
}

private extension ShapeModifier {
    var shortTitle: String {
        switch self {
        case .raw:
            return "Raw"
        case .snappy:
            return "Snap"
        case .lingering:
            return "Sustain"
        case .reversed:
            return "Reverse"
        }
    }
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
    @Previewable @State var soundProfile = ElasticSlingshotSoundProfile.power
    @Previewable @State var impactTone = ToneLibrary.defaultImpactTone
    @Previewable @State var impactModifier = ShapeModifier.raw

    EngineRoomSettingsView(
        recipe: $recipe,
        soundProfile: $soundProfile,
        impactTone: $impactTone,
        impactModifier: $impactModifier,
        beatsPerMinute: 75
    )
}
