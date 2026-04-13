import SwiftUI

struct GarageCoachingReportView: View {
    let presentation: GarageCoachingPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(presentation.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppModule.garage.theme.textMuted)

                    Text(presentation.headline)
                        .font(.headline)
                        .foregroundStyle(AppModule.garage.theme.textPrimary)

                    Text(presentation.body)
                        .font(.subheadline)
                        .foregroundStyle(AppModule.garage.theme.textSecondary)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                GarageCoachingBadge(
                    title: presentation.confidenceLabel,
                    tint: badgeTint(for: presentation.confidenceLabel)
                )
                GarageCoachingBadge(
                    title: presentation.phaseLabel,
                    tint: ModuleTheme.electricCyan.opacity(0.42)
                )
            }

            if let supportingLine = presentation.supportingLine {
                Text(supportingLine)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppModule.garage.theme.textMuted)
            }

            if presentation.notes.isEmpty == false {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(presentation.notes, id: \.self) { note in
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(Color.orange.opacity(0.72))
                                .frame(width: 7, height: 7)
                                .padding(.top, 5)

                            Text(note)
                                .font(.subheadline)
                                .foregroundStyle(AppModule.garage.theme.textSecondary)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            GarageCoachingCardBackground(
                shape: RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous),
                fill: ModuleTheme.garageSurfaceRaised,
                stroke: Color.white.opacity(0.05)
            )
        )
    }

    private func badgeTint(for confidenceLabel: String) -> Color {
        switch confidenceLabel {
        case GarageReliabilityStatus.trusted.rawValue:
            Color(red: 0.33, green: 0.79, blue: 0.53)
        case GarageReliabilityStatus.review.rawValue:
            .orange
        default:
            Color(red: 0.94, green: 0.38, blue: 0.40)
        }
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
            .frame(minHeight: 32)
            .background(
                Capsule()
                    .fill(tint.opacity(0.10))
                    .overlay(
                        Capsule()
                            .stroke(tint.opacity(0.22), lineWidth: 1)
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
            .shadow(color: AppModule.garage.theme.shadowDark.opacity(0.4), radius: 14, x: 8, y: 8)
            .shadow(color: AppModule.garage.theme.shadowLight.opacity(0.35), radius: 8, x: -4, y: -4)
    }
}
