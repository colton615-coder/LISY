import Charts
import SwiftUI

@MainActor
struct GarageCoachingDashboardView: View {
    let records: [PracticeSessionRecord]
    let templateName: String

    private var points: [GarageCoachingTrendPoint] {
        records.coachingEfficacyTrendPoints(for: templateName)
    }

    private var baselineScore: Double {
        guard points.isEmpty == false else {
            return 0
        }

        let totalScore = points.reduce(0) { $0 + $1.scorePercentagePoints }
        return totalScore / Double(points.count)
    }

    private var latestPoint: GarageCoachingTrendPoint? {
        points.last
    }

    private var trendDelta: Double {
        guard let first = points.first,
              let last = points.last else {
            return 0
        }

        return last.score - first.score
    }

    private var trendTint: Color {
        if trendDelta > 0 {
            return GarageVaultPalette.emerald
        }

        if trendDelta < 0 {
            return garageReviewPending
        }

        return GarageProTheme.accent
    }

    private var trendLabel: String {
        if trendDelta > 0 {
            return "Trending Up"
        }

        if trendDelta < 0 {
            return "Trending Down"
        }

        return "Holding"
    }

    private var baselineText: String {
        "\(Int(baselineScore.rounded()))% avg baseline"
    }

    private var yDomain: ClosedRange<Double> {
        let values = points.map(\.scorePercentagePoints) + [baselineScore]
        let lowestValue = values.min() ?? 0
        let highestValue = values.max() ?? 0
        let lowerBound = Swift.min(lowestValue - 5, 0)
        let upperBound = Swift.max(highestValue + 5, 5)

        if lowerBound == upperBound {
            return (lowerBound - 5)...(upperBound + 5)
        }

        return lowerBound...upperBound
    }

    var body: some View {
        GarageProCard(isActive: points.count > 1, cornerRadius: 24, padding: 18) {
            header

            if points.isEmpty {
                emptyState
            } else {
                efficacyChart
                footer
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("EFFICACY TRENDS")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .textCase(.uppercase)
                    .tracking(2.2)
                    .foregroundStyle(GarageProTheme.accent)

                Text(templateName)
                    .font(.system(.title3, design: .rounded).weight(.black))
                    .foregroundStyle(GarageProTheme.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Text(trendLabel)
                .font(.caption.weight(.bold))
                .foregroundStyle(trendTint)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    Capsule(style: .continuous)
                        .fill(GarageProTheme.insetSurface)
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(trendTint.opacity(0.42), lineWidth: 1)
                        )
                )
        }
    }

    private var efficacyChart: some View {
        Chart {
            ForEach(points) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Coaching Efficacy", point.scorePercentagePoints)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(GarageProTheme.accent)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Coaching Efficacy", point.scorePercentagePoints)
                )
                .foregroundStyle(trendTint)
                .symbolSize(point.id == latestPoint?.id ? 72 : 36)
            }

            RuleMark(y: .value("Average Baseline", baselineScore))
                .foregroundStyle(trendTint)
                .lineStyle(StrokeStyle(lineWidth: 1.4, lineCap: .round, dash: [6, 5]))
        }
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) {
                AxisGridLine()
                    .foregroundStyle(GarageProTheme.border.opacity(0.5))
                AxisTick()
                    .foregroundStyle(GarageProTheme.border.opacity(0.8))
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .foregroundStyle(GarageProTheme.textSecondary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine()
                    .foregroundStyle(GarageProTheme.border.opacity(0.45))
                AxisTick()
                    .foregroundStyle(GarageProTheme.border.opacity(0.8))
                AxisValueLabel {
                    if let score = value.as(Double.self) {
                        Text("\(Int(score.rounded()))%")
                            .foregroundStyle(GarageProTheme.textSecondary)
                    }
                }
            }
        }
        .frame(height: 190)
        .padding(.top, 2)
    }

    private var footer: some View {
        HStack(alignment: .center, spacing: 12) {
            GarageCoachingDashboardMetric(
                title: "Latest",
                value: latestPoint?.scoreText ?? "--",
                tint: trendTint
            )

            GarageCoachingDashboardMetric(
                title: "Baseline",
                value: baselineText,
                tint: GarageProTheme.accent
            )
        }
    }

    private var emptyState: some View {
        Text("Finish another coached session in this routine to draw the efficacy trend.")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(GarageProTheme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

@MainActor
struct GarageCoachingTipOfDayCard: View {
    let snapshot: GarageCoachingAuditSnapshot

    private var tint: Color {
        snapshot.coachingTrend.tint
    }

    var body: some View {
        GarageProCard(isActive: snapshot.coachingTrend != .holding, cornerRadius: 24, padding: 18) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: snapshot.coachingTrend.systemImage)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 46, height: 46)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(tint.opacity(0.14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(tint.opacity(0.34), lineWidth: 1)
                            )
                    )

                VStack(alignment: .leading, spacing: 7) {
                    Text("TIP OF THE DAY")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .textCase(.uppercase)
                        .tracking(2.2)
                        .foregroundStyle(tint)

                    Text(snapshot.actionableInsightText)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(GarageProTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("\(snapshot.templateName) • \(snapshot.deltaBadgeText) coaching efficacy")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(GarageProTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

@MainActor
private struct GarageCoachingDashboardMetric: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(GarageProTheme.textSecondary)

            Text(value)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(GarageProTheme.insetSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(GarageProTheme.border, lineWidth: 1)
                )
        )
    }
}

private extension GarageCoachingAuditSnapshot.CoachingTrend {
    var tint: Color {
        switch self {
        case .improving:
            return GarageVaultPalette.emerald
        case .dropping:
            return garageReviewPending
        case .holding:
            return GarageProTheme.accent
        }
    }

    var systemImage: String {
        switch self {
        case .improving:
            return "arrow.up.right.circle.fill"
        case .dropping:
            return "arrow.down.right.circle.fill"
        case .holding:
            return "equal.circle.fill"
        }
    }
}

#Preview("Garage Coaching Dashboard") {
    GarageProScaffold(bottomPadding: 48) {
        GarageCoachingTipOfDayCard(
            snapshot: GarageCoachingAuditSnapshot(
                currentRecordID: UUID(),
                previousRecordID: UUID(),
                templateName: "Impact Ladder",
                previousCue: "Own the finish.",
                drillDeltas: [
                    GarageDrillDelta(name: "Start Line", previousRatio: 0.52, currentRatio: 0.64),
                    GarageDrillDelta(name: "Contact", previousRatio: 0.58, currentRatio: 0.68)
                ],
                isPersonalRecord: false
            )
        )

        GarageCoachingDashboardView(
            records: [
                PracticeSessionRecord(
                    date: .now.addingTimeInterval(-259_200),
                    templateName: "Impact Ladder",
                    environment: PracticeEnvironment.range.rawValue,
                    completedDrills: 3,
                    totalDrills: 3,
                    coachingEfficacyScore: 0.02
                ),
                PracticeSessionRecord(
                    date: .now.addingTimeInterval(-172_800),
                    templateName: "Impact Ladder",
                    environment: PracticeEnvironment.range.rawValue,
                    completedDrills: 3,
                    totalDrills: 3,
                    coachingEfficacyScore: 0.06
                ),
                PracticeSessionRecord(
                    date: .now.addingTimeInterval(-86_400),
                    templateName: "Impact Ladder",
                    environment: PracticeEnvironment.range.rawValue,
                    completedDrills: 3,
                    totalDrills: 3,
                    coachingEfficacyScore: 0.11
                )
            ],
            templateName: "Impact Ladder"
        )
    }
}
