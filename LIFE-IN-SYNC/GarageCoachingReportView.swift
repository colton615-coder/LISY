import SwiftUI

struct GarageCoachingReportView: View {
    let report: GarageCoachingReport
    let stabilityScore: Int?
    let selectedPhase: SwingPhase
    let reliabilityStatus: GarageReliabilityStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Advisory Coaching")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppModule.garage.theme.accentText)

                    Text(report.headline)
                        .font(.headline)
                        .foregroundStyle(AppModule.garage.theme.textPrimary)

                    Text("\(selectedPhase.reviewTitle) review")
                        .font(.caption)
                        .foregroundStyle(AppModule.garage.theme.textSecondary)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Stability")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppModule.garage.theme.textMuted)
                    Text(stabilityScore.map(String.init) ?? "N/A")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppModule.garage.theme.accentText)
                }
            }

            HStack(spacing: 8) {
                GarageCoachingBadge(title: report.confidenceLabel, tint: badgeTint(for: reliabilityStatus))
                GarageCoachingBadge(title: selectedPhase.reviewTitle, tint: ModuleTheme.electricCyan.opacity(0.7))
            }

            if report.cues.isEmpty {
                GarageCoachingFallbackCard(
                    title: "Coaching unavailable",
                    message: "Keep reviewing the deterministic skeleton overlay and stability score while coaching catches up."
                )
            } else {
                ForEach(report.cues) { cue in
                    GarageCoachingCueCard(cue: cue)
                }
            }

            if report.blockers.isEmpty == false {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Review notes")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppModule.garage.theme.textMuted)

                    ForEach(report.blockers, id: \.self) { blocker in
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(Color.orange.opacity(0.85))
                                .frame(width: 7, height: 7)
                                .padding(.top, 5)

                            Text(blocker)
                                .font(.subheadline)
                                .foregroundStyle(AppModule.garage.theme.textSecondary)
                        }
                    }
                }
                .padding(.top, 2)
            }

            Text(report.nextBestAction)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppModule.garage.theme.textPrimary)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    GarageCoachingInsetBackground(
                        shape: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                )
        }
        .padding(16)
        .background(
            GarageCoachingCardBackground(
                shape: RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous)
            )
        )
    }

    private func badgeTint(for status: GarageReliabilityStatus) -> Color {
        switch status {
        case .trusted:
            Color(red: 0.33, green: 0.79, blue: 0.53)
        case .review:
            .orange
        case .provisional:
            Color(red: 0.94, green: 0.38, blue: 0.40)
        }
    }
}

private struct GarageCoachingCueCard: View {
    let cue: GarageCoachingCue

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(cue.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppModule.garage.theme.textPrimary)

            Text(cue.message)
                .font(.subheadline)
                .foregroundStyle(AppModule.garage.theme.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            GarageCoachingCardBackground(
                shape: RoundedRectangle(cornerRadius: 16, style: .continuous),
                fill: ModuleTheme.garageSurfaceRaised,
                stroke: cueTint.opacity(0.18)
            )
        )
    }

    private var cueTint: Color {
        switch cue.severity {
        case .positive:
            Color(red: 0.33, green: 0.79, blue: 0.53)
        case .info:
            ModuleTheme.electricCyan
        case .caution:
            .orange
        }
    }
}

private struct GarageCoachingFallbackCard: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppModule.garage.theme.textPrimary)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppModule.garage.theme.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            GarageCoachingInsetBackground(
                shape: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
        )
    }
}

private struct GarageCoachingBadge: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppModule.garage.theme.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(tint.opacity(0.12))
                    .overlay(
                        Capsule()
                            .stroke(tint.opacity(0.28), lineWidth: 1)
                    )
            )
    }
}

private struct GarageCoachingCardBackground<S: Shape>: View {
    let shape: S
    var fill: Color = ModuleTheme.garageSurface
    var stroke: Color = Color.white.opacity(0.07)

    var body: some View {
        shape
            .fill(fill)
            .overlay(shape.stroke(stroke, lineWidth: 1))
            .shadow(color: AppModule.garage.theme.shadowDark, radius: 16, x: 10, y: 10)
            .shadow(color: AppModule.garage.theme.shadowLight, radius: 12, x: -6, y: -6)
    }
}

private struct GarageCoachingInsetBackground<S: Shape>: View {
    let shape: S

    var body: some View {
        shape
            .fill(ModuleTheme.garageSurfaceInset)
            .overlay(shape.stroke(Color.white.opacity(0.07), lineWidth: 1))
            .overlay(
                shape
                    .stroke(AppModule.garage.theme.shadowLight.opacity(0.6), lineWidth: 1)
                    .blur(radius: 1)
                    .mask(shape.fill(LinearGradient(colors: [.white, .clear], startPoint: .topLeading, endPoint: .bottomTrailing)))
            )
            .shadow(color: AppModule.garage.theme.shadowDark.opacity(0.55), radius: 10, x: 6, y: 6)
    }
}
