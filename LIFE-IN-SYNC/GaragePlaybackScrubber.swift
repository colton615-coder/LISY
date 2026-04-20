import SwiftUI

struct GaragePlaybackScrubber: View {
    let duration: Double
    @Binding var scrubTime: Double
    let onScrub: (Double) -> Void
    let onScrubEditingChanged: (Bool) -> Void

    @State private var isDragging = false

    private let trackInset: CGFloat = 18
    private let touchInset: CGFloat = 8
    private let thumbSize: CGFloat = 14
    private let visibleTrackHeight: CGFloat = 6

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text(garageFormattedPlaybackTime(displayTime))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(garageReviewReadableText)
                    .monospacedDigit()

                Spacer(minLength: 0)

                Text(garageFormattedPlaybackTime(safeDuration))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(garageReviewMutedText)
                    .monospacedDigit()
            }

            GeometryReader { proxy in
                let trackWidth = max(proxy.size.width - (trackInset * 2), 1)

                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(garageReviewSurfaceDark)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(garageReviewStroke.opacity(0.95), lineWidth: 0.9)
                        )

                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(garageReviewTrackFill)
                            .frame(height: visibleTrackHeight)
                            .overlay(
                                Capsule()
                                    .stroke(garageReviewStroke.opacity(0.8), lineWidth: 0.8)
                            )

                        HStack(spacing: 0) {
                            ForEach(0...20, id: \.self) { index in
                                Rectangle()
                                    .fill(index.isMultiple(of: 2) ? garageReviewReadableText.opacity(0.05) : .clear)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .overlay(alignment: .trailing) {
                                        Rectangle()
                                            .fill(garageReviewReadableText.opacity(0.08))
                                            .frame(width: 1)
                                    }
                            }
                        }
                        .frame(height: visibleTrackHeight)
                        .clipShape(Capsule())

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [garageReviewAccent.opacity(0.72), garageReviewAccent],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(trackWidth * progress, thumbSize), height: visibleTrackHeight)
                            .shadow(color: garageReviewAccent.opacity(0.32), radius: 8, x: 0, y: 0)

                        Circle()
                            .fill(garageReviewAccent)
                            .frame(width: thumbSize, height: thumbSize)
                            .overlay(
                                Circle()
                                    .stroke(garageReviewReadableText.opacity(0.28), lineWidth: 1)
                            )
                            .shadow(color: garageReviewAccent.opacity(0.55), radius: 8, x: 0, y: 0)
                            .offset(x: max(0, (trackWidth * progress) - (thumbSize / 2)))
                    }
                    .padding(.horizontal, trackInset)
                }
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard abs(value.translation.width) >= abs(value.translation.height) || abs(value.translation.height) < 6 else {
                                return
                            }

                            if isDragging == false {
                                isDragging = true
                                onScrubEditingChanged(true)
                            }

                            let updatedTime = time(for: value.location.x, width: proxy.size.width)
                            scrubTime = updatedTime
                            onScrub(updatedTime)
                        }
                        .onEnded { value in
                            guard isDragging else { return }
                            let updatedTime = time(for: value.location.x, width: proxy.size.width)
                            scrubTime = updatedTime
                            onScrub(updatedTime)
                            isDragging = false
                            onScrubEditingChanged(false)
                        }
                )
            }
            .frame(height: 52)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Playback scrubber")
            .accessibilityValue("\(garageFormattedPlaybackTime(displayTime)) of \(garageFormattedPlaybackTime(safeDuration))")
            .accessibilityAdjustableAction { direction in
                let step = max(safeDuration / 20, 0.1)
                switch direction {
                case .increment:
                    adjustScrubTime(by: step)
                case .decrement:
                    adjustScrubTime(by: -step)
                @unknown default:
                    break
                }
            }
        }
    }

    private var safeDuration: Double {
        guard duration.isFinite, duration > 0 else { return 0 }
        return duration
    }

    private var displayTime: Double {
        min(max(scrubTime, 0), max(safeDuration, 0))
    }

    private var progress: CGFloat {
        guard safeDuration > 0 else { return 0 }
        return CGFloat(displayTime / safeDuration)
    }

    private func time(for locationX: CGFloat, width: CGFloat) -> Double {
        guard safeDuration > 0 else { return 0 }
        let clampedX = min(max(locationX - touchInset, 0), max(width - (touchInset * 2), 1))
        let progress = clampedX / max(width - (touchInset * 2), 1)
        return safeDuration * progress
    }

    private func adjustScrubTime(by delta: Double) {
        let updatedTime = min(max(displayTime + delta, 0), safeDuration)
        scrubTime = updatedTime
        onScrub(updatedTime)
    }
}

private struct GaragePlaybackScrubberPreviewHarness: View {
    @State private var scrubTime: Double
    private let duration: Double

    init(duration: Double, initialTime: Double) {
        self.duration = duration
        _scrubTime = State(initialValue: initialTime)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Playback Rail")
                .font(.headline.weight(.semibold))
                .foregroundStyle(garageReviewReadableText)

            GaragePlaybackScrubber(
                duration: duration,
                scrubTime: $scrubTime,
                onScrub: { scrubTime = $0 },
                onScrubEditingChanged: { _ in }
            )
        }
        .padding()
        .background(garageReviewBackground.ignoresSafeArea())
    }
}

#Preview("Garage Playback Scrubber · Mid Clip") {
    PreviewScreenContainer {
        GaragePlaybackScrubberPreviewHarness(duration: 42, initialTime: 13.5)
    }
    .preferredColorScheme(.dark)
}

#Preview("Garage Playback Scrubber · Long Clip") {
    PreviewScreenContainer {
        GaragePlaybackScrubberPreviewHarness(duration: 3725, initialTime: 641)
    }
    .preferredColorScheme(.dark)
}
