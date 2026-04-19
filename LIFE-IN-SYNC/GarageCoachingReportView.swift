import SwiftUI

struct GarageCoachingReportView: View {
    let presentation: GarageCoachingPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            heroCard

            if presentation.snapshots.isEmpty == false {
                sessionScroller
            }

            if presentation.metrics.isEmpty == false {
                metricsSection
            }

            actionCard
        }
        .padding(18)
        .background(
            GarageCoachingRaisedBackground(
                cornerRadius: 24,
                fill: ModuleTheme.garageSurface,
                stroke: Color.white.opacity(0.05)
            )
        )
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Focused Analysis")
                        .font(.caption.weight(.bold))
                        .tracking(1.3)
                        .foregroundStyle(AppModule.garage.theme.textMuted)

                    Text(presentation.headline)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppModule.garage.theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
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

            Text(presentation.body)
                .font(.subheadline)
                .foregroundStyle(AppModule.garage.theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let supportingLine = presentation.supportingLine {
                HStack(spacing: 8) {
                    Circle()
                        .fill(ModuleTheme.electricCyan.opacity(0.9))
                        .frame(width: 7, height: 7)

                    Text(supportingLine)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppModule.garage.theme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .background(
            GarageCoachingRaisedBackground(
                cornerRadius: 22,
                fill: ModuleTheme.garageSurfaceRaised,
                stroke: Color.white.opacity(0.05)
            )
        )
    }

    private var sessionScroller: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Session Readout")
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(AppModule.garage.theme.textMuted)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(presentation.snapshots) { snapshot in
                        GarageCoachingSnapshotCard(snapshot: snapshot)
                    }
                }
                .padding(.vertical, 1)
            }
        }
    }

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Text("Signal Mix")
                    .font(.caption.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(AppModule.garage.theme.textMuted)

                Spacer(minLength: 0)

                Text("Deep-dive coaching cues")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppModule.garage.theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            GarageCoachingMetricGrid(metrics: presentation.metrics)
        }
    }

    private var actionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Next Best Action")
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(ModuleTheme.electricCyan)

            Text(presentation.nextBestAction)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppModule.garage.theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if presentation.notes.isEmpty == false {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(presentation.notes, id: \.self) { note in
                        HStack(alignment: .top, spacing: 10) {
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(Color(hex: "#FFCE52"))
                                .frame(width: 14, height: 3)
                                .padding(.top, 7)

                            Text(note)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(AppModule.garage.theme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(14)
                .background(
                    GarageCoachingInsetBackground(
                        cornerRadius: 18,
                        fill: ModuleTheme.garageSurfaceInset
                    )
                )
            }
        }
        .padding(16)
        .background(
            GarageCoachingRaisedBackground(
                cornerRadius: 22,
                fill: ModuleTheme.garageSurfaceRaised,
                stroke: ModuleTheme.electricCyan.opacity(0.18)
            )
        )
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

private enum GarageCoachingMetricCardLayout {
    case standard
    case capstone
}

private struct GarageCoachingSnapshotCard: View {
    let snapshot: GarageCoachingPresentation.SessionSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    Circle()
                        .fill(ModuleTheme.electricCyan.opacity(0.14))
                        .frame(width: 30, height: 30)

                    Image(systemName: snapshot.systemImage)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(ModuleTheme.electricCyan)
                }

                Spacer(minLength: 0)
            }

            Text(snapshot.title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppModule.garage.theme.textMuted)
                .lineLimit(1)

            Text(snapshot.value)
                .font(.title3.weight(.bold))
                .foregroundStyle(AppModule.garage.theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Text(snapshot.caption)
                .font(.caption2)
                .foregroundStyle(AppModule.garage.theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(width: 132, alignment: .leading)
        .padding(14)
        .background(
            GarageCoachingInsetBackground(
                cornerRadius: 18,
                fill: ModuleTheme.garageSurfaceInset
            )
        )
    }
}

private struct GarageCoachingMetricGrid: View {
    let metrics: [GarageCoachingPresentation.MetricTile]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if gridMetrics.isEmpty == false {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                    ForEach(gridMetrics) { metric in
                        GarageCoachingMetricCard(metric: metric, layout: .standard)
                    }
                }
            }

            if let capstoneMetric {
                GarageCoachingMetricCard(metric: capstoneMetric, layout: .capstone)
            }
        }
    }

    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]
    }

    private var capstoneMetric: GarageCoachingPresentation.MetricTile? {
        guard metrics.count.isMultiple(of: 2) == false else { return nil }
        return metrics.last
    }

    private var gridMetrics: [GarageCoachingPresentation.MetricTile] {
        guard capstoneMetric != nil else { return metrics }
        return Array(metrics.dropLast())
    }
}

private struct GarageCoachingMetricCard: View {
    let metric: GarageCoachingPresentation.MetricTile
    let layout: GarageCoachingMetricCardLayout

    private var isPrimaryMetric: Bool {
        metric.id == "reliability" || metric.id == "score"
    }

    var body: some View {
        Group {
            switch layout {
            case .standard:
                standardCard
            case .capstone:
                capstoneCard
            }
        }
        .padding(layout == .capstone ? 14 : 12)
        .frame(maxWidth: .infinity, minHeight: layout == .capstone ? 104 : 132, alignment: .leading)
        .background(
            GarageCoachingInsetBackground(
                cornerRadius: 18,
                fill: ModuleTheme.garageSurfaceInset
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(metric.status.tint.opacity(0.26), lineWidth: 0.9)
            )
        )
    }

    private var standardCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                metricLeadingTitle

                Spacer(minLength: 0)

                GarageCoachingBadge(
                    title: metric.status.label,
                    tint: metric.status.tint
                )
            }

            Spacer(minLength: 0)

            Text(metric.value)
                .font(.system(size: isPrimaryMetric ? 26 : 20, weight: .bold, design: .rounded))
                .foregroundStyle(isPrimaryMetric ? ModuleTheme.electricCyan : AppModule.garage.theme.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.76)

            metricProgressBar
        }
    }

    private var capstoneCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        metricIcon

                        Text(metric.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppModule.garage.theme.textSecondary)
                            .lineLimit(1)
                    }

                    GarageCoachingBadge(
                        title: metric.status.label,
                        tint: metric.status.tint
                    )
                }

                Spacer(minLength: 0)

                Text(metric.value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(isPrimaryMetric ? ModuleTheme.electricCyan : AppModule.garage.theme.textPrimary)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }

            metricProgressBar
        }
    }

    private var metricLeadingTitle: some View {
        HStack(spacing: 8) {
            metricIcon

            Text(metric.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppModule.garage.theme.textSecondary)
                .lineLimit(1)
        }
    }

    private var metricIcon: some View {
        Image(systemName: metric.systemImage)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(metric.status.tint)
    }

    private var metricProgressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(ModuleTheme.garageTrack)

                Capsule()
                    .fill(metric.status.tint)
                    .frame(width: max(proxy.size.width * metric.progress, 12))
            }
        }
        .frame(height: 4)
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
                            .stroke(tint.opacity(0.38), lineWidth: 0.6)
                    )
            )
    }
}

private struct GarageCoachingRaisedBackground: View {
    let cornerRadius: CGFloat
    let fill: Color
    let stroke: Color

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(fill)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(stroke, lineWidth: 0.9)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.04), lineWidth: 0.5)
            )
            .shadow(color: AppModule.garage.theme.shadowDark.opacity(0.28), radius: 18, x: 0, y: 12)
            .shadow(color: AppModule.garage.theme.shadowLight.opacity(0.1), radius: 10, x: -3, y: -3)
    }
}

private struct GarageCoachingInsetBackground: View {
    let cornerRadius: CGFloat
    let fill: Color

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(fill)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 0.8)
            )
            .shadow(color: AppModule.garage.theme.shadowDark.opacity(0.2), radius: 10, x: 0, y: 6)
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
