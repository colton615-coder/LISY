import SwiftUI

struct GarageCoachingReportView: View {
    let presentation: GarageCoachingPresentation

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        GarageTelemetrySurface(isActive: true, cornerRadius: 24, padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                header
                sessionScroller
                metricGrid
                footer
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Session Analysis")
                    .font(.caption.weight(.bold))
                    .tracking(1.4)
                    .foregroundStyle(AppModule.garage.theme.textMuted)

                Text(presentation.headline)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppModule.garage.theme.textPrimary)

                Text(presentation.body)
                    .font(.subheadline)
                    .foregroundStyle(AppModule.garage.theme.textSecondary)
                    .lineLimit(3)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 8) {
                GarageCoachingBadge(
                    title: presentation.confidenceLabel.uppercased(),
                    tint: badgeTint(for: presentation.confidenceLabel)
                )
                GarageCoachingBadge(
                    title: presentation.phaseLabel.uppercased(),
                    tint: ModuleTheme.electricCyan
                )
            }
        }
    }

    private var sessionScroller: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(presentation.snapshots) { snapshot in
                    SessionAnalysisMiniCard(snapshot: snapshot)
                }
            }
        }
    }

    private var metricGrid: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(presentation.metrics) { metric in
                GolfMetricCard(metric: metric)
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let supportingLine = presentation.supportingLine {
                Text(supportingLine)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppModule.garage.theme.textMuted)
            }

            Text(presentation.nextBestAction)
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppModule.garage.theme.textPrimary)

            if presentation.notes.isEmpty == false {
                ForEach(presentation.notes, id: \.self) { note in
                    HStack(alignment: .top, spacing: 8) {
                        Rectangle()
                            .fill(Color(hex: "#FFCE52"))
                            .frame(width: 14, height: 2)
                            .padding(.top, 8)

                        Text(note)
                            .font(.caption)
                            .foregroundStyle(AppModule.garage.theme.textSecondary)
                    }
                }
            }
        }
    }

    private func badgeTint(for confidenceLabel: String) -> Color {
        switch confidenceLabel {
        case GarageReliabilityStatus.trusted.rawValue:
            Color(hex: "#4DDE8E")
        case GarageReliabilityStatus.review.rawValue:
            Color(hex: "#FFCE52")
        default:
            Color(hex: "#FF5F63")
        }
    }
}

private struct SessionAnalysisMiniCard: View {
    let snapshot: GarageCoachingPresentation.SessionSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: snapshot.systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(ModuleTheme.electricCyan)

                Spacer(minLength: 0)
            }

            Text(snapshot.title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppModule.garage.theme.textMuted)

            Text(snapshot.value)
                .font(.headline.weight(.bold))
                .foregroundStyle(AppModule.garage.theme.textPrimary)
                .lineLimit(1)

            Text(snapshot.caption)
                .font(.caption2)
                .foregroundStyle(AppModule.garage.theme.textSecondary)
                .lineLimit(1)
        }
        .frame(width: 118, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(ModuleTheme.garageSurfaceInset.opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
        )
    }
}

private struct GolfMetricCard: View {
    let metric: GarageCoachingPresentation.MetricTile

    private var isPrimaryMetric: Bool {
        metric.id == "reliability" || metric.id == "score"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: metric.systemImage)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(metric.status.tint)

                    Text(metric.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppModule.garage.theme.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                GarageCoachingBadge(
                    title: metric.status.label,
                    tint: metric.status.tint
                )
            }

            Spacer(minLength: 0)

            Text(metric.value)
                .font(.system(size: isPrimaryMetric ? 28 : 22, weight: .bold, design: .rounded))
                .foregroundStyle(isPrimaryMetric ? ModuleTheme.electricCyan : AppModule.garage.theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .shadow(color: isPrimaryMetric ? ModuleTheme.electricCyan.opacity(0.24) : .clear, radius: 10, x: 0, y: 0)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(ModuleTheme.garageTrack)

                    Capsule()
                        .fill(metric.status.tint)
                        .frame(width: max(proxy.size.width * metric.progress, 10))
                }
            }
            .frame(height: 3)
        }
        .frame(maxWidth: .infinity, minHeight: 126, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(ModuleTheme.garageSurfaceInset.opacity(0.98))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(metric.status.tint.opacity(0.36), lineWidth: 0.5)
                )
        )
    }
}

private struct GarageCoachingBadge: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.caption2.weight(.bold))
            .tracking(0.8)
            .foregroundStyle(AppModule.garage.theme.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(tint.opacity(0.10))
                    .overlay(
                        Capsule()
                            .stroke(tint.opacity(0.38), lineWidth: 0.5)
                    )
            )
    }
}

private extension GarageCoachingMetricStatus {
    var label: String {
        switch self {
        case .great:
            "GREAT"
        case .good:
            "GOOD"
        case .watch:
            "WATCH"
        case .bad:
            "BAD"
        }
    }

    var tint: Color {
        switch self {
        case .great:
            Color(hex: "#4DDE8E")
        case .good:
            Color(hex: "#1AD0C8")
        case .watch:
            Color(hex: "#FFCE52")
        case .bad:
            Color(hex: "#FF5F63")
        }
    }
}
