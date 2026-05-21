import SwiftUI

@MainActor
struct GarageTempoBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var audioEngine = ElasticSlingshotAudioEngine()
    @State private var beatsPerMinute: Double = 72
    @State private var recipe = ElasticSlingshotRecipe()
    @State private var showsEngineRoom = false

    var body: some View {
        ZStack {
            GarageHorizonVaultBackground()

            VStack(spacing: 0) {
                GarageHorizonVaultTopBar(
                    onBack: close,
                    onSettings: { showsEngineRoom = true }
                )

                Spacer(minLength: 18)

                HorizonVaultDialView(beatsPerMinute: $beatsPerMinute)
                    .frame(height: 196)
                    .onChange(of: beatsPerMinute) { _, newValue in
                        audioEngine.update(beatsPerMinute: newValue, recipe: recipe)
                    }

                Spacer(minLength: 26)

                GarageHorizonVaultPlayToggle(
                    isPlaying: audioEngine.playbackState == .playing,
                    action: togglePlayback
                )
                .padding(.bottom, 26)
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
        }
        .sheet(isPresented: $showsEngineRoom) {
            GarageElasticSlingshotEngineRoom(
                recipe: $recipe,
                beatsPerMinute: beatsPerMinute,
                isLocked: audioEngine.playbackState == .playing
            )
            .presentationDetents([.height(460), .medium])
            .presentationDragIndicator(.visible)
            .onDisappear {
                audioEngine.update(beatsPerMinute: beatsPerMinute, recipe: recipe)
            }
        }
        .onDisappear {
            audioEngine.stop()
        }
        .navigationBarBackButtonHidden(true)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func togglePlayback() {
        garageTriggerImpact(.medium)

        switch audioEngine.playbackState {
        case .stopped:
            audioEngine.start(beatsPerMinute: beatsPerMinute, recipe: recipe)
        case .playing:
            audioEngine.stop()
        }
    }

    private func close() {
        audioEngine.stop()
        dismiss()
    }
}

struct HorizonVaultDialView: View {
    @Binding var beatsPerMinute: Double
    @State private var dragStartBPM: Double?

    private let minimumBPM = 40.0
    private let maximumBPM = 140.0
    private let pointsPerBeat: CGFloat = 11
    private let neonGreen = Color(red: 0, green: 1, blue: 0.67)
    private let neonYellow = Color(red: 1, green: 0.93, blue: 0.1)

    var body: some View {
        GeometryReader { proxy in
            let centerX = proxy.size.width / 2
            let trackY = proxy.size.height * 0.56
            let drag = DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if dragStartBPM == nil {
                        dragStartBPM = beatsPerMinute
                    }

                    let delta = -Double(value.translation.width / pointsPerBeat)
                    let nextValue = (dragStartBPM ?? beatsPerMinute) + delta
                    beatsPerMinute = min(max(nextValue.rounded(), minimumBPM), maximumBPM)
                }
                .onEnded { _ in
                    dragStartBPM = nil
                }

            ZStack {
                VStack(spacing: 6) {
                    Text("\(Int(beatsPerMinute.rounded()))")
                        .font(.system(size: 72, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)

                    Text("MASTER BPM")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(neonGreen.opacity(0.72))
                        .tracking(1.6)
                }
                .offset(y: -56)

                Canvas { context, size in
                    let visibleBeats = Int(ceil(size.width / pointsPerBeat)) + 16
                    let centerBeat = Int(beatsPerMinute.rounded())
                    let startBeat = max(Int(minimumBPM), centerBeat - visibleBeats / 2)
                    let endBeat = min(Int(maximumBPM), centerBeat + visibleBeats / 2)

                    for beat in startBeat...endBeat {
                        let offset = CGFloat(beat) - CGFloat(beatsPerMinute)
                        let x = centerX + offset * pointsPerBeat
                        guard x >= -24, x <= size.width + 24 else { continue }

                        let isBenchmark = beat.isMultiple(of: 10)
                        let isMedium = beat.isMultiple(of: 5)
                        let height: CGFloat = isBenchmark ? 34 : isMedium ? 22 : 11
                        let width: CGFloat = isBenchmark ? 1.4 : isMedium ? 1 : 0.7
                        let color = isBenchmark ? neonGreen : isMedium ? neonGreen.opacity(0.46) : Color.white.opacity(0.22)
                        let tickRect = CGRect(x: x - width / 2, y: trackY - height / 2, width: width, height: height)

                        context.fill(Path(roundedRect: tickRect, cornerRadius: width), with: .color(color))

                        if isBenchmark {
                            let label = Text("\(beat)")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(neonGreen.opacity(0.86))
                            context.draw(label, at: CGPoint(x: x, y: trackY + 33), anchor: .top)
                        }
                    }
                }
                .gesture(drag)
                .contentShape(Rectangle())

                VStack(spacing: 0) {
                    Rectangle()
                        .fill(neonYellow)
                        .frame(width: 2, height: 82)
                        .shadow(color: neonYellow.opacity(0.55), radius: 10, x: 0, y: 0)

                    Triangle()
                        .fill(neonYellow)
                        .frame(width: 15, height: 9)
                }
                .position(x: centerX, y: trackY - 50)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, neonGreen.opacity(0.22), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
                    .position(x: centerX, y: trackY)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Master BPM")
            .accessibilityValue("\(Int(beatsPerMinute.rounded())) beats per minute")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    beatsPerMinute = min(beatsPerMinute + 1, maximumBPM)
                case .decrement:
                    beatsPerMinute = max(beatsPerMinute - 1, minimumBPM)
                @unknown default:
                    break
                }
            }
        }
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

            Button(action: onSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.86))
            .accessibilityLabel("Engine room")
        }
    }
}

private struct GarageHorizonVaultPlayToggle: View {
    let isPlaying: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 86, height: 86)
                .background(
                    Circle()
                        .fill(isPlaying ? Color(red: 1, green: 0.93, blue: 0.1) : Color(red: 0, green: 1, blue: 0.67))
                )
                .shadow(color: (isPlaying ? Color(red: 1, green: 0.93, blue: 0.1) : Color(red: 0, green: 1, blue: 0.67)).opacity(0.36), radius: 24, x: 0, y: 14)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPlaying ? "Stop tempo loop" : "Play tempo loop")
    }
}

private struct GarageElasticSlingshotEngineRoom: View {
    @Binding var recipe: ElasticSlingshotRecipe
    let beatsPerMinute: Double
    let isLocked: Bool

    var body: some View {
        ZStack {
            GarageHorizonVaultBackground()

            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Engine Room")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Recipe split stays locked while the master BPM scales total duration.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.58))
                }

                VStack(spacing: 18) {
                    GarageRecipeSlider(
                        title: "Takeaway",
                        value: recipe.takeawayPercent,
                        duration: recipe.takeawayDuration(for: beatsPerMinute),
                        tint: Color(red: 0, green: 1, blue: 0.67),
                        isLocked: isLocked
                    ) { nextValue in
                        recipe.rebalance(changedPhase: .takeaway, value: nextValue)
                    }

                    GarageRecipeSlider(
                        title: "Pause",
                        value: recipe.pausePercent,
                        duration: recipe.pauseDuration(for: beatsPerMinute),
                        tint: Color(red: 1, green: 0.93, blue: 0.1),
                        isLocked: isLocked
                    ) { nextValue in
                        recipe.rebalance(changedPhase: .pause, value: nextValue)
                    }

                    GarageRecipeSlider(
                        title: "Downswing",
                        value: recipe.downswingPercent,
                        duration: recipe.downswingDuration(for: beatsPerMinute),
                        tint: Color(red: 0.53, green: 0.9, blue: 1),
                        isLocked: isLocked
                    ) { nextValue in
                        recipe.rebalance(changedPhase: .downswing, value: nextValue)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(22)
        }
    }
}

private struct GarageRecipeSlider: View {
    let title: String
    let value: Double
    let duration: TimeInterval
    let tint: Color
    let isLocked: Bool
    let onChange: (Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                Text("\(Int(value.rounded()))%  \(duration, specifier: "%.2f")s")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(tint)
            }

            Slider(
                value: Binding(
                    get: { value },
                    set: onChange
                ),
                in: 0...100
            )
            .tint(tint)
            .disabled(isLocked)
            .opacity(isLocked ? 0.45 : 1)
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

#Preview("Horizon Vault Dial") {
    NavigationStack {
        GarageTempoBuilderView()
    }
}
