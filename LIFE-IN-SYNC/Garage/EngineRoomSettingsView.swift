import SwiftUI

@MainActor
struct EngineRoomSettingsView: View {
    @Binding var recipe: ElasticSlingshotRecipe
    @Binding var soundProfile: ElasticSlingshotSoundProfile

    private let neonGreen = Color(red: 0, green: 1, blue: 0.67)
    private let deepGreen = Color(red: 0.02, green: 0.04, blue: 0.024)

    var body: some View {
        ZStack {
            EngineRoomBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    header

                    ratioMatrix

                    soundLibrary

                    loopDelayControl

                    testToneButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
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

                Text("\(Int(totalPercent.rounded()))%")
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

    private var ratioMatrix: some View {
        EngineRoomPanel {
            VStack(alignment: .leading, spacing: 18) {
                EngineRoomSectionHeader(title: "Ratio % Matrix", value: recipe.displayText)

                RatioSliderRow(
                    title: "Takeback",
                    value: recipe.takeawayPercent,
                    tint: neonGreen
                ) { nextValue in
                    recipe.rebalance(changedPhase: .takeaway, value: nextValue.rounded())
                }

                RatioSliderRow(
                    title: "Pause",
                    value: recipe.pausePercent,
                    tint: Color(red: 1, green: 0.93, blue: 0.1)
                ) { nextValue in
                    recipe.rebalance(changedPhase: .pause, value: nextValue.rounded())
                }

                RatioSliderRow(
                    title: "Downswing",
                    value: recipe.downswingPercent,
                    tint: Color(red: 0.53, green: 0.9, blue: 1)
                ) { nextValue in
                    recipe.rebalance(changedPhase: .downswing, value: nextValue.rounded())
                }
            }
        }
    }

    private var soundLibrary: some View {
        EngineRoomPanel {
            VStack(alignment: .leading, spacing: 14) {
                EngineRoomSectionHeader(title: "Sound Profile", value: soundProfile.title)

                Picker("Sound Profile", selection: $soundProfile) {
                    ForEach(ElasticSlingshotSoundProfile.allCases) { profile in
                        Text(profile.title).tag(profile)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 128)
                .clipped()
                .tint(neonGreen)
            }
        }
    }

    private var loopDelayControl: some View {
        EngineRoomPanel {
            VStack(alignment: .leading, spacing: 14) {
                EngineRoomSectionHeader(title: "Loop Delay", value: loopDelayText)

                Slider(
                    value: Binding(
                        get: { recipe.restInterval },
                        set: { recipe.restInterval = min(max($0, 1), 10) }
                    ),
                    in: 1...10,
                    step: 0.5
                )
                .tint(neonGreen)
            }
        }
    }

    private var testToneButton: some View {
        Button {
            print("Test Tones: recipe=\(recipe.displayText), delay=\(recipe.restInterval), soundProfile=\(soundProfile.rawValue)")
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

    private var totalPercent: Double {
        recipe.takeawayPercent + recipe.pausePercent + recipe.downswingPercent
    }

    private var loopDelayText: String {
        String(format: "%.1fs", recipe.restInterval)
    }
}

private struct RatioSliderRow: View {
    let title: String
    let value: Double
    let tint: Color
    let onChange: (Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                Text("\(Int(value.rounded()))%")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(tint)
            }

            Slider(
                value: Binding(
                    get: { value },
                    set: onChange
                ),
                in: 0...100,
                step: 1
            )
            .tint(tint)
        }
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
    @Previewable @State var soundProfile = ElasticSlingshotSoundProfile.analogBand

    EngineRoomSettingsView(recipe: $recipe, soundProfile: $soundProfile)
}
