import SwiftUI

struct GarageCoachingReportView: View {
    let presentation: GarageCoachingPresentation

    @State private var isShellVisible = false
    @State private var visibleSections: Set<GarageCoachingSection> = []
    @State private var lastAnimatedEntranceKey = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionCard(.hero, glow: presentation.isUnavailable ? nil : garageReviewAccent.opacity(0.35)) {
                heroCard
            }

            if presentation.snapshots.isEmpty == false {
                sectionCard(.sessionReadout) {
                    sessionScroller
                }
            }

            if presentation.metrics.isEmpty == false {
                sectionCard(.signalMix) {
                    metricsSection
                }
            }

            sectionCard(.nextBestAction, stroke: garageReviewAccent.opacity(0.18)) {
                actionCard
            }
        }
        .padding(18)
        .background(containerBackground)
        .opacity(isShellVisible ? 1 : 0)
        .scaleEffect(isShellVisible ? 1 : 0.985, anchor: .top)
        .offset(y: isShellVisible ? 0 : 16)
        .task(id: entranceIdentityKey) {
            await animateEntranceIfNeeded()
        }
    }

    private var containerBackground: some View {
        GarageRaisedPanelBackground(
            shape: RoundedRectangle(cornerRadius: 24, style: .continuous),
            fill: garageReviewSurface,
            stroke: garageReviewStroke.opacity(0.96)
        )
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [garageReviewShadowLight.opacity(0.2), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 26)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

    private var entranceIdentityKey: String {
        [
            presentation.headline,
            presentation.body,
            presentation.confidenceLabel,
            presentation.phaseLabel,
            presentation.nextBestAction,
            presentation.snapshots.map(\.id).joined(separator: "::"),
            presentation.metrics.map(\.id).joined(separator: "::"),
            presentation.notes.joined(separator: "::")
        ].joined(separator: "|")
    }

    private var sectionOrder: [GarageCoachingSection] {
        var sections: [GarageCoachingSection] = [.hero]
        if presentation.snapshots.isEmpty == false {
            sections.append(.sessionReadout)
        }
        if presentation.metrics.isEmpty == false {
            sections.append(.signalMix)
        }
        sections.append(.nextBestAction)
        return sections
    }

    @ViewBuilder
    private func sectionCard<Content: View>(
        _ section: GarageCoachingSection,
        stroke: Color = garageReviewStroke.opacity(0.92),
        glow: Color? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(16)
        .background(
            GarageRaisedPanelBackground(
                shape: RoundedRectangle(cornerRadius: 22, style: .continuous),
                fill: garageReviewSurfaceRaised,
                stroke: stroke,
                glow: glow
            )
        )
        .opacity(visibleSections.contains(section) ? 1 : 0)
        .scaleEffect(visibleSections.contains(section) ? 1 : 0.986, anchor: .top)
        .offset(y: visibleSections.contains(section) ? 0 : 12)
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Focused Analysis")
                        .font(.caption.weight(.bold))
                        .tracking(1.3)
                        .foregroundStyle(garageReviewMutedText)

                    Text(presentation.headline)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(garageReviewReadableText)
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
                        tint: garageReviewAccent
                    )
                }
            }

            Text(presentation.body)
                .font(.subheadline)
                .foregroundStyle(garageReviewMutedText)
                .fixedSize(horizontal: false, vertical: true)

            if let supportingLine = presentation.supportingLine {
                HStack(spacing: 8) {
                    Circle()
                        .fill(garageReviewAccent.opacity(0.92))
                        .frame(width: 7, height: 7)

                    Text(supportingLine)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(garageReviewMutedText.opacity(0.96))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var sessionScroller: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Session Readout")
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(garageReviewMutedText)

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
                    .foregroundStyle(garageReviewMutedText)

                Spacer(minLength: 0)

                Text("Deep-dive coaching cues")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(garageReviewMutedText.opacity(0.94))
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
                .foregroundStyle(garageReviewAccent)

            Text(presentation.nextBestAction)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(garageReviewReadableText)
                .fixedSize(horizontal: false, vertical: true)

            if presentation.notes.isEmpty == false {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(presentation.notes, id: \.self) { note in
                        HStack(alignment: .top, spacing: 10) {
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(garageReviewPending)
                                .frame(width: 14, height: 3)
                                .padding(.top, 7)

                            Text(note)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(garageReviewMutedText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(14)
                .background(
                    GarageInsetPanelBackground(
                        shape: RoundedRectangle(cornerRadius: 18, style: .continuous),
                        fill: garageReviewInsetSurface
                    )
                )
            }
        }
    }

    private func badgeTint(for confidenceLabel: String) -> Color {
        switch confidenceLabel {
        case GarageReliabilityStatus.trusted.rawValue:
            garageReviewApproved
        case GarageReliabilityStatus.review.rawValue:
            garageReviewPending
        default:
            garageReviewFlagged
        }
    }

    @MainActor
    private func animateEntranceIfNeeded() async {
        guard entranceIdentityKey.isEmpty == false else { return }
        guard lastAnimatedEntranceKey != entranceIdentityKey else { return }

        lastAnimatedEntranceKey = entranceIdentityKey
        isShellVisible = false
        visibleSections = []

        let _ = withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
            isShellVisible = true
        }

        try? await Task.sleep(nanoseconds: 95_000_000)

        for (index, section) in sectionOrder.enumerated() {
            if index > 0 {
                try? await Task.sleep(nanoseconds: 58_000_000)
            }

            let _ = withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                visibleSections.insert(section)
            }
        }
    }
}

private enum GarageCoachingSection: String, Hashable {
    case hero
    case sessionReadout
    case signalMix
    case nextBestAction
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
                        .fill(garageReviewAccent.opacity(0.14))
                        .frame(width: 30, height: 30)

                    Image(systemName: snapshot.systemImage)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(garageReviewAccent)
                }

                Spacer(minLength: 0)
            }

            Text(snapshot.title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(garageReviewMutedText)
                .lineLimit(1)

            Text(snapshot.value)
                .font(.title3.weight(.bold))
                .foregroundStyle(garageReviewReadableText)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Text(snapshot.caption)
                .font(.caption2)
                .foregroundStyle(garageReviewMutedText.opacity(0.94))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(width: 132, alignment: .leading)
        .padding(14)
        .background(
            GarageInsetPanelBackground(
                shape: RoundedRectangle(cornerRadius: 18, style: .continuous),
                fill: garageReviewInsetSurface
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
            GarageInsetPanelBackground(
                shape: RoundedRectangle(cornerRadius: 18, style: .continuous),
                fill: garageReviewInsetSurface,
                stroke: metric.status.tint.opacity(0.22)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(metric.status.tint.opacity(0.16), lineWidth: 0.8)
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
                .foregroundStyle(isPrimaryMetric ? garageReviewAccent : garageReviewReadableText)
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
                            .foregroundStyle(garageReviewMutedText.opacity(0.95))
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
                    .foregroundStyle(isPrimaryMetric ? garageReviewAccent : garageReviewReadableText)
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
                .foregroundStyle(garageReviewMutedText.opacity(0.95))
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
                    .fill(garageReviewTrackFill)
                    .overlay(
                        Capsule()
                            .stroke(garageReviewStroke.opacity(0.72), lineWidth: 0.8)
                    )

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [metric.status.tint.opacity(0.7), metric.status.tint],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(proxy.size.width * metric.progress, 12))
                    .shadow(color: metric.status.tint.opacity(0.22), radius: 6, x: 0, y: 0)
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
            .foregroundStyle(garageReviewReadableText)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(tint.opacity(0.10))
                    .overlay(
                        Capsule()
                            .stroke(tint.opacity(0.38), lineWidth: 0.7)
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
            garageReviewApproved
        case .good:
            garageReviewAccent
        case .watch:
            garageReviewPending
        case .bad:
            garageReviewFlagged
        }
    }
}

private enum GarageCoachingReportPreviewFixture {
    static let full = GarageCoachingPresentation(
        title: "Coaching Notes",
        headline: "Transition appears faster than this swing's baseline",
        body: "The top-to-delivery handoff is outracing the lower-body sequence, so the club arrives with less time to shallow and stabilize.",
        supportingLine: "Use this as a cue, not a final judgment",
        confidenceLabel: GarageReliabilityStatus.trusted.rawValue,
        phaseLabel: "Transition",
        nextBestAction: "Rehearse two slow reps feeling your lead side clear before the hands fire, then compare that pattern against the current transition frame.",
        notes: [
            "The club is winning the race into the slot.",
            "Keep the chest quieter through the first move down."
        ],
        snapshots: [
            GarageCoachingPresentation.SessionSnapshot(
                id: "score",
                title: "Session Analysis",
                value: "87",
                caption: "swing score",
                systemImage: "waveform.path.ecg.rectangle"
            ),
            GarageCoachingPresentation.SessionSnapshot(
                id: "reliability",
                title: "Reliability",
                value: "TRUSTED",
                caption: "signal confidence",
                systemImage: "checkmark.shield"
            ),
            GarageCoachingPresentation.SessionSnapshot(
                id: "phase",
                title: "Focus Phase",
                value: "Transition",
                caption: "stability 82",
                systemImage: "figure.golf"
            )
        ],
        metrics: [
            GarageCoachingPresentation.MetricTile(
                id: "tempo",
                title: "Tempo",
                value: "3.0 : 1",
                systemImage: "metronome",
                status: .great,
                progress: 0.9
            ),
            GarageCoachingPresentation.MetricTile(
                id: "spine",
                title: "Spine",
                value: "6.8°",
                systemImage: "angle",
                status: .good,
                progress: 0.76
            ),
            GarageCoachingPresentation.MetricTile(
                id: "pelvis",
                title: "Pelvis",
                value: "1.9 in",
                systemImage: "arrow.left.and.right",
                status: .watch,
                progress: 0.58
            ),
            GarageCoachingPresentation.MetricTile(
                id: "reliability",
                title: "Reliability",
                value: "TRUSTED",
                systemImage: "checkmark.shield",
                status: .great,
                progress: 0.92
            ),
            GarageCoachingPresentation.MetricTile(
                id: "head",
                title: "Head",
                value: "Stable through delivery",
                systemImage: "viewfinder.circle",
                status: .good,
                progress: 0.73
            )
        ],
        isUnavailable: false
    )

    static let unavailable = GarageCoachingPresentation(
        title: "Coaching Notes",
        headline: "Coaching unavailable",
        body: "Review the motion and stability metric while coaching catches up.",
        supportingLine: nil,
        confidenceLabel: GarageReliabilityStatus.review.rawValue,
        phaseLabel: "Impact",
        nextBestAction: "Re-run the review after confirming the most stable impact frame and compare the hand path against the existing marker set.",
        notes: [],
        snapshots: [],
        metrics: [
            GarageCoachingPresentation.MetricTile(
                id: "score",
                title: "Swing Score",
                value: "82",
                systemImage: "scope",
                status: .good,
                progress: 0.82
            ),
            GarageCoachingPresentation.MetricTile(
                id: "reliability",
                title: "Reliability",
                value: "REVIEW",
                systemImage: "checkmark.shield",
                status: .watch,
                progress: 0.58
            )
        ],
        isUnavailable: true
    )
}

private struct GarageCoachingReportPreviewSurface: View {
    let presentation: GarageCoachingPresentation

    var body: some View {
        ScrollView {
            GarageCoachingReportView(presentation: presentation)
                .padding()
        }
        .background(garageReviewBackground.ignoresSafeArea())
    }
}

#Preview("Garage Coaching Report · Full") {
    PreviewScreenContainer {
        GarageCoachingReportPreviewSurface(presentation: GarageCoachingReportPreviewFixture.full)
    }
    .preferredColorScheme(.dark)
}

#Preview("Garage Coaching Report · Unavailable") {
    PreviewScreenContainer {
        GarageCoachingReportPreviewSurface(presentation: GarageCoachingReportPreviewFixture.unavailable)
    }
    .preferredColorScheme(.dark)
}
