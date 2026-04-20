import SwiftUI

enum GarageStep2MetricCardLayout {
    case standard
    case capstone
}

struct GarageStep2MetricGrid: View {
    let metrics: [GarageStep2MetricPresentation]
    @State private var visibleMetricIDs: Set<String> = []
    @State private var lastAnimatedMetricKey = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if gridMetrics.isEmpty == false {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                    ForEach(gridMetrics) { metric in
                        GarageStep2MetricCard(metric: metric, layout: .standard)
                            .opacity(visibleMetricIDs.contains(metric.id) ? 1 : 0)
                            .scaleEffect(visibleMetricIDs.contains(metric.id) ? 1 : 0.985)
                            .offset(y: visibleMetricIDs.contains(metric.id) ? 0 : 10)
                    }
                }
            }

            if let capstoneMetric {
                GarageStep2MetricCard(metric: capstoneMetric, layout: .capstone)
                    .opacity(visibleMetricIDs.contains(capstoneMetric.id) ? 1 : 0)
                    .scaleEffect(visibleMetricIDs.contains(capstoneMetric.id) ? 1 : 0.985)
                    .offset(y: visibleMetricIDs.contains(capstoneMetric.id) ? 0 : 12)
            }
        }
        .task(id: metricIdentityKey) {
            await animateEntranceIfNeeded()
        }
    }

    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]
    }

    private var capstoneMetric: GarageStep2MetricPresentation? {
        guard metrics.count.isMultiple(of: 2) == false else { return nil }
        return metrics.last
    }

    private var gridMetrics: [GarageStep2MetricPresentation] {
        guard capstoneMetric != nil else { return metrics }
        return Array(metrics.dropLast())
    }

    private var metricIdentityKey: String {
        metrics.map(\.id).joined(separator: "::")
    }

    private var entranceOrderedIDs: [String] {
        gridMetrics.map(\.id) + (capstoneMetric.map { [$0.id] } ?? [])
    }

    @MainActor
    private func animateEntranceIfNeeded() async {
        guard metricIdentityKey.isEmpty == false else { return }
        guard lastAnimatedMetricKey != metricIdentityKey else { return }

        lastAnimatedMetricKey = metricIdentityKey
        visibleMetricIDs = []

        for (index, metricID) in entranceOrderedIDs.enumerated() {
            if index > 0 {
                try? await Task.sleep(nanoseconds: 58_000_000)
            }

            let _ = withAnimation(.spring(response: 0.36, dampingFraction: 0.84)) {
                visibleMetricIDs.insert(metricID)
            }
        }
    }
}

struct GarageStep2MetricCard: View {
    let metric: GarageStep2MetricPresentation
    let layout: GarageStep2MetricCardLayout

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
        .frame(maxWidth: .infinity, minHeight: layout == .capstone ? 94 : 0, alignment: .leading)
        .background(
            GarageInsetPanelBackground(
                shape: RoundedRectangle(cornerRadius: ModuleCornerRadius.row, style: .continuous),
                fill: garageReviewInsetSurface,
                stroke: metric.grade.tint.opacity(0.2)
            )
        )
    }

    private var standardCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            metricHeader(alignment: .top)

            Text(metric.value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(garageReviewReadableText)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
    }

    private var capstoneCard: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                metricHeader(alignment: .center)

                Text(metric.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(garageReviewMutedText.opacity(0.94))
                    .lineLimit(1)
                    .minimumScaleFactor(0.88)
            }

            Spacer(minLength: 0)

            Text(metric.value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(garageReviewReadableText)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
        }
    }

    private func metricHeader(alignment: VerticalAlignment) -> some View {
        HStack(alignment: alignment, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(metric.grade.tint)
                    .frame(width: 7, height: 7)

                if layout == .standard {
                    Text(metric.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(garageReviewMutedText)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            Text(metric.grade.label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(metric.grade.tint.opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(metric.grade.tint.opacity(0.10))
                        .overlay(
                            Capsule()
                                .stroke(metric.grade.tint.opacity(0.18), lineWidth: 1)
                        )
                )
        }
    }
}

private enum GarageMetricGridPreviewFixture {
    static let evenMetrics: [GarageStep2MetricPresentation] = [
        GarageStep2MetricPresentation(id: "tempo", title: "Tempo", value: "3.1 : 1", grade: .excellent),
        GarageStep2MetricPresentation(id: "spine", title: "Spine Delta", value: "7.2°", grade: .good),
        GarageStep2MetricPresentation(id: "pelvis", title: "Pelvic Depth", value: "1.4 in", grade: .good),
        GarageStep2MetricPresentation(id: "knee", title: "Knee Flex", value: "Left 18° / Right 21°", grade: .fair)
    ]

    static let oddMetrics: [GarageStep2MetricPresentation] = evenMetrics + [
        GarageStep2MetricPresentation(id: "head", title: "Head Stability", value: "Sway 0.8 in · Dip 0.4 in", grade: .excellent)
    ]
}

private struct GarageMetricGridPreviewSurface: View {
    let title: String
    let metrics: [GarageStep2MetricPresentation]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(garageReviewReadableText)

            GarageStep2MetricGrid(metrics: metrics)
        }
        .padding()
        .background(garageReviewBackground.ignoresSafeArea())
    }
}

#Preview("Garage Metric Grid · Even") {
    PreviewScreenContainer {
        GarageMetricGridPreviewSurface(
            title: "Even Metric Set",
            metrics: GarageMetricGridPreviewFixture.evenMetrics
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Garage Metric Grid · Capstone") {
    PreviewScreenContainer {
        GarageMetricGridPreviewSurface(
            title: "Odd Metric Set",
            metrics: GarageMetricGridPreviewFixture.oddMetrics
        )
    }
    .preferredColorScheme(.dark)
}
