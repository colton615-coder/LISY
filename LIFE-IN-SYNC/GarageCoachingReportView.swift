import SwiftUI

struct GarageCoachingReportView: View {
    let presentation: GarageCoachingPresentation

    @State private var isShellVisible = false
    @State private var visibleSections: Set<GarageCoachingSection> = []
    @State private var lastAnimatedEntranceKey = ""
    @State private var detailTarget: GarageCoachingDetailTarget?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionCard(.hero, stroke: heroStroke, glow: heroGlow) {
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

            sectionCard(.nextBestAction, stroke: actionStroke) {
                actionCard
            }
        }
        .padding(18)
        .background(containerBackground)
        .opacity(isShellVisible ? 1 : 0)
        .scaleEffect(isShellVisible ? 1 : 0.985, anchor: .top)
        .offset(y: isShellVisible ? 0 : 16)
        .task(id: presentation.animationIdentityKey) {
            await animateEntranceIfNeeded()
        }
        .sheet(item: $detailTarget) { target in
            GarageCoachingDetailSheet(target: target)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
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

    private var heroGlow: Color? {
        switch presentation.mode {
        case .ready:
            garageReviewAccent.opacity(0.4)
        case .review:
            garageReviewPending.opacity(0.36)
        case .unavailable:
            nil
        case .provisional:
            garageReviewFlagged.opacity(0.28)
        }
    }

    private var heroStroke: Color {
        switch presentation.mode {
        case .ready:
            garageReviewAccent.opacity(0.24)
        case .review:
            garageReviewPending.opacity(0.24)
        case .unavailable:
            garageReviewStroke.opacity(0.9)
        case .provisional:
            garageReviewFlagged.opacity(0.24)
        }
    }

    private var actionStroke: Color {
        switch presentation.mode {
        case .ready:
            garageReviewAccent.opacity(0.2)
        case .review:
            garageReviewPending.opacity(0.22)
        case .unavailable:
            garageReviewStroke.opacity(0.9)
        case .provisional:
            garageReviewFlagged.opacity(0.22)
        }
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
                        .tracking(1.25)
                        .foregroundStyle(garageReviewMutedText)

                    Text(presentation.hero.headline)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(garageReviewReadableText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 8) {
                    GarageCoachingBadge(
                        title: presentation.reliabilityStatus.rawValue.uppercased(),
                        tint: presentation.reliabilityStatus.tint
                    )
                    GarageCoachingBadge(
                        title: presentation.phase.reviewTitle.uppercased(),
                        tint: garageReviewAccent
                    )
                }
            }

            Text(presentation.hero.body)
                .font(.subheadline)
                .foregroundStyle(garageReviewMutedText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Circle()
                    .fill(disclaimerTint)
                    .frame(width: 7, height: 7)

                Text(presentation.hero.disclaimer)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(garageReviewMutedText.opacity(0.96))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var disclaimerTint: Color {
        switch presentation.mode {
        case .ready:
            garageReviewAccent.opacity(0.92)
        case .review:
            garageReviewPending.opacity(0.92)
        case .unavailable:
            garageReviewMutedText.opacity(0.84)
        case .provisional:
            garageReviewFlagged.opacity(0.92)
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
                        GarageCoachingSnapshotCard(snapshot: snapshot) {
                            garageTriggerImpact(.light)
                            detailTarget = .snapshot(snapshot)
                        }
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

                Text(presentation.mode.signalMixHelperText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(garageReviewMutedText.opacity(0.94))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            GarageCoachingMetricGrid(metrics: presentation.metrics) { metric in
                garageTriggerImpact(.light)
                detailTarget = .metric(metric)
            }
        }
    }

    private var actionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(presentation.action.title)
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(actionAccent)

            Text(presentation.action.body)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(garageReviewReadableText)
                .fixedSize(horizontal: false, vertical: true)

            if presentation.action.notes.isEmpty == false {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(presentation.action.notes, id: \.self) { note in
                        HStack(alignment: .top, spacing: 10) {
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(actionAccent)
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

    private var actionAccent: Color {
        switch presentation.mode {
        case .ready:
            garageReviewAccent
        case .review, .unavailable:
            garageReviewPending
        case .provisional:
            garageReviewFlagged
        }
    }

    @MainActor
    private func animateEntranceIfNeeded() async {
        guard presentation.animationIdentityKey.isEmpty == false else { return }
        guard lastAnimatedEntranceKey != presentation.animationIdentityKey else { return }

        lastAnimatedEntranceKey = presentation.animationIdentityKey
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
    let snapshot: GarageCoachingSnapshotModel
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(snapshot.accentStyle.tint.opacity(snapshot.valueState == .available ? 0.14 : 0.08))
                            .frame(width: 30, height: 30)

                        Image(systemName: snapshot.systemImage)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(snapshot.accentStyle.tint)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "arrow.up.forward.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(garageReviewMutedText.opacity(0.72))
                }

                Text(snapshot.title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(garageReviewMutedText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(snapshot.value)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(snapshot.valueState == .available ? garageReviewReadableText : garageReviewMutedText.opacity(0.84))
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)

                Text(snapshot.caption)
                    .font(.caption2)
                    .foregroundStyle(garageReviewMutedText.opacity(0.94))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(width: 138, alignment: .leading)
            .padding(14)
                    .background(
                        GarageInsetPanelBackground(
                            shape: RoundedRectangle(cornerRadius: 18, style: .continuous),
                            fill: garageReviewInsetSurface,
                            stroke: snapshot.accentStyle.tint.opacity(snapshot.valueState == .available ? 0.18 : 0.08)
                        )
                    )
        }
        .buttonStyle(.plain)
    }
}

private struct GarageCoachingMetricGrid: View {
    let metrics: [GarageCoachingMetricModel]
    let onSelectMetric: (GarageCoachingMetricModel) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if gridMetrics.isEmpty == false {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                    ForEach(gridMetrics) { metric in
                        GarageCoachingMetricCard(
                            metric: metric,
                            layout: .standard,
                            action: { onSelectMetric(metric) }
                        )
                    }
                }
            }

            if let capstoneMetric {
                GarageCoachingMetricCard(
                    metric: capstoneMetric,
                    layout: .capstone,
                    action: { onSelectMetric(capstoneMetric) }
                )
            }
        }
    }

    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]
    }

    private var capstoneMetric: GarageCoachingMetricModel? {
        guard metrics.count.isMultiple(of: 2) == false else { return nil }
        return metrics.last
    }

    private var gridMetrics: [GarageCoachingMetricModel] {
        guard capstoneMetric != nil else { return metrics }
        return Array(metrics.dropLast())
    }
}

private struct GarageCoachingMetricCard: View {
    let metric: GarageCoachingMetricModel
    let layout: GarageCoachingMetricCardLayout
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                switch layout {
                case .standard:
                    standardCard
                case .capstone:
                    capstoneCard
                }
            }
            .padding(layout == .capstone ? 14 : 12)
            .frame(maxWidth: .infinity, minHeight: layout == .capstone ? 108 : 134, alignment: .leading)
            .background(
                GarageInsetPanelBackground(
                    shape: RoundedRectangle(cornerRadius: 18, style: .continuous),
                    fill: garageReviewInsetSurface,
                    stroke: metricStroke
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(metricStroke.opacity(0.82), lineWidth: 0.8)
                )
            )
        }
        .buttonStyle(.plain)
    }

    private var metricStroke: Color {
        (metric.badgeStyle?.tint ?? garageReviewMutedText.opacity(0.42))
            .opacity(metric.valueState == .available ? 0.2 : 0.08)
    }

    private var standardCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                metricLeadingTitle

                Spacer(minLength: 0)

                if let badgeStyle = metric.badgeStyle {
                    GarageCoachingBadge(
                        title: badgeStyle.title,
                        tint: badgeStyle.tint
                    )
                }
            }

            Spacer(minLength: 0)

            metricValueText(fontSize: metric.isPrimaryMetric ? 26 : 20)

            metricFooter
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
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let badgeStyle = metric.badgeStyle {
                        GarageCoachingBadge(
                            title: badgeStyle.title,
                            tint: badgeStyle.tint
                        )
                    }
                }

                Spacer(minLength: 0)

                metricValueText(fontSize: 22)
                    .multilineTextAlignment(.trailing)
            }

            metricFooter
        }
    }

    private var metricLeadingTitle: some View {
        HStack(spacing: 8) {
            metricIcon

            Text(metric.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(garageReviewMutedText.opacity(0.95))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var metricIcon: some View {
        Image(systemName: metric.systemImage)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(metric.badgeStyle?.tint ?? garageReviewMutedText.opacity(0.72))
    }

    @ViewBuilder
    private func metricValueText(fontSize: CGFloat) -> some View {
        Text(metric.value)
            .font(.system(size: metric.valueState == .available ? fontSize : max(fontSize - 6, 16), weight: .bold, design: .rounded))
            .foregroundStyle(metricValueTint)
            .lineLimit(2)
            .minimumScaleFactor(0.76)
    }

    private var metricValueTint: Color {
        if metric.valueState == .unavailable {
            return garageReviewMutedText.opacity(0.82)
        }
        if metric.isPrimaryMetric {
            return metric.badgeStyle?.tint ?? garageReviewAccent
        }
        return garageReviewReadableText
    }

    @ViewBuilder
    private var metricFooter: some View {
        if let progress = metric.progress {
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
                                colors: [(metric.badgeStyle?.tint ?? garageReviewAccent).opacity(0.7), metric.badgeStyle?.tint ?? garageReviewAccent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(proxy.size.width * progress, 0))
                        .shadow(color: (metric.badgeStyle?.tint ?? garageReviewAccent).opacity(0.22), radius: 6, x: 0, y: 0)
                }
            }
            .frame(height: 4)
        } else {
            Text("Awaiting data")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(garageReviewMutedText.opacity(0.84))
        }
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

private struct GarageCoachingDetailSheet: View {
    let target: GarageCoachingDetailTarget

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(target.accentTint.opacity(0.14))
                            .frame(width: 42, height: 42)

                        Image(systemName: target.systemImage)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(target.accentTint)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(target.title)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(garageReviewReadableText)

                        Text(target.caption)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(garageReviewMutedText)
                    }

                    Spacer(minLength: 0)
                }

                Text(target.value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(target.accentTint)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(target.detailSections) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.title)
                                .font(.caption.weight(.bold))
                                .tracking(1.1)
                                .foregroundStyle(garageReviewMutedText)

                            Text(section.body)
                                .font(.subheadline)
                                .foregroundStyle(garageReviewReadableText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            GarageInsetPanelBackground(
                                shape: RoundedRectangle(cornerRadius: 18, style: .continuous),
                                fill: garageReviewInsetSurface
                            )
                        )
                    }
                }
            }
            .padding(20)
        }
        .background(garageReviewBackground.ignoresSafeArea())
    }
}

private enum GarageCoachingReportPreviewFixture {
    static let trusted = GarageCoachingPresentation.make(
        report: GarageCoachingReport(
            headline: "Transition Looks Rushed",
            confidenceLabel: GarageReliabilityStatus.trusted.rawValue,
            cues: [
                GarageCoachingCue(
                    title: "Transition Looks Rushed",
                    message: "The top-to-delivery handoff is outracing the lower-body sequence, so the club arrives with less time to shallow and stabilize.",
                    severity: .caution
                )
            ],
            blockers: [],
            nextBestAction: "Rehearse two slow reps feeling your lead side clear before the hands fire, then compare that pattern against the current transition frame."
        ),
        selectedPhase: .transition,
        reliabilityReport: GarageReliabilityReport(
            score: 92,
            status: .trusted,
            summary: "This swing has strong coverage across video, checkpoints, anchors, and path generation.",
            checks: [
                GarageReliabilityCheck(title: "Video Source", passed: true, detail: "The original swing video is linked and readable."),
                GarageReliabilityCheck(title: "Grip Coverage", passed: true, detail: "All 8 grip anchors are saved and the path is generated.")
            ]
        ),
        scorecard: previewScorecard(),
        stabilityScore: 82
    )

    static let review = GarageCoachingPresentation.make(
        report: GarageCoachingReport(
            headline: "Hand Path Needs Monitoring",
            confidenceLabel: GarageReliabilityStatus.review.rawValue,
            cues: [
                GarageCoachingCue(
                    title: "Hand Path Needs Monitoring",
                    message: "The current path shape is readable, but keep comparing it against future swings before making a bigger change from this alone.",
                    severity: .info
                )
            ],
            blockers: [
                "Average pose confidence is only 62%, so detections may be noisy.",
                "Two checkpoints were manually adjusted, which lowers trust in the automatic pass."
            ],
            nextBestAction: "Use the cues directionally, but resolve the review notes before treating them as final."
        ),
        selectedPhase: .impact,
        reliabilityReport: GarageReliabilityReport(
            score: 68,
            status: .review,
            summary: "This swing is usable, but one or more checks still need review before you trust the output fully.",
            checks: [
                GarageReliabilityCheck(title: "Pose Confidence", passed: false, detail: "Average pose confidence is only 62%, so detections may be noisy."),
                GarageReliabilityCheck(title: "Manual Adjustments", passed: false, detail: "Two checkpoints were manually adjusted, which lowers trust in the automatic pass.")
            ]
        ),
        scorecard: previewScorecard(),
        stabilityScore: 74
    )

    static let unavailable = GarageCoachingPresentation.make(
        report: GarageCoachingReport(
            headline: "Coaching unavailable",
            confidenceLabel: GarageReliabilityStatus.review.rawValue,
            cues: [],
            blockers: [
                "Review the motion and stability metric while coaching catches up."
            ],
            nextBestAction: "Re-run the review after confirming the most stable impact frame and compare the hand path against the existing marker set."
        ),
        selectedPhase: .impact,
        reliabilityReport: GarageReliabilityReport(
            score: 66,
            status: .review,
            summary: "This swing is usable, but one or more checks still need review before you trust the output fully.",
            checks: [
                GarageReliabilityCheck(title: "Video Source", passed: true, detail: "The original swing video is linked and readable."),
                GarageReliabilityCheck(title: "Grip Coverage", passed: false, detail: "Anchor coverage or path generation is incomplete.")
            ]
        ),
        scorecard: nil,
        stabilityScore: nil
    )

    static let provisional = GarageCoachingPresentation.make(
        report: GarageCoachingReport(
            headline: "Hold interpretation until the swing is more complete.",
            confidenceLabel: GarageReliabilityStatus.provisional.rawValue,
            cues: [],
            blockers: [
                "Anchor coverage or path generation is incomplete.",
                "Average pose confidence is only 41%, so detections may be noisy."
            ],
            nextBestAction: "Fix the failed reliability checks before using coaching cues."
        ),
        selectedPhase: .takeaway,
        reliabilityReport: GarageReliabilityReport(
            score: 34,
            status: .provisional,
            summary: "This swing is still provisional. Fix the failed checks before relying on the analysis.",
            checks: [
                GarageReliabilityCheck(title: "Grip Coverage", passed: false, detail: "Anchor coverage or path generation is incomplete."),
                GarageReliabilityCheck(title: "Pose Confidence", passed: false, detail: "Average pose confidence is only 41%, so detections may be noisy.")
            ]
        ),
        scorecard: nil,
        stabilityScore: nil
    )

    static let oddCountCapstone = GarageCoachingPresentation.make(
        report: GarageCoachingReport(
            headline: "Transition Looks Rushed",
            confidenceLabel: GarageReliabilityStatus.trusted.rawValue,
            cues: [
                GarageCoachingCue(
                    title: "Transition Looks Rushed",
                    message: "The current transition is still outracing the baseline, so the delivery window tightens too early.",
                    severity: .caution
                )
            ],
            blockers: [],
            nextBestAction: "Keep rehearsing a quieter first move down before adding more speed."
        ),
        selectedPhase: .transition,
        reliabilityReport: GarageReliabilityReport(
            score: 88,
            status: .trusted,
            summary: "This swing has strong coverage across video, checkpoints, anchors, and path generation.",
            checks: [
                GarageReliabilityCheck(title: "Video Source", passed: true, detail: "The original swing video is linked and readable.")
            ]
        ),
        scorecard: previewScorecard(includeHeadDomain: false),
        stabilityScore: 79
    )

    private static func previewScorecard(includeHeadDomain: Bool = true) -> GarageSwingScorecard {
        let domains: [GarageSwingDomainScore] = [
            GarageSwingDomainScore(
                id: GarageSwingDomain.tempo.rawValue,
                title: GarageSwingDomain.tempo.title,
                score: 91,
                grade: .excellent,
                displayValue: "3.0:1"
            ),
            GarageSwingDomainScore(
                id: GarageSwingDomain.spine.rawValue,
                title: GarageSwingDomain.spine.title,
                score: 76,
                grade: .good,
                displayValue: "6.8°"
            ),
            GarageSwingDomainScore(
                id: GarageSwingDomain.pelvis.rawValue,
                title: GarageSwingDomain.pelvis.title,
                score: 58,
                grade: .fair,
                displayValue: "1.9 in"
            ),
            GarageSwingDomainScore(
                id: GarageSwingDomain.knee.rawValue,
                title: GarageSwingDomain.knee.title,
                score: 72,
                grade: .good,
                displayValue: "Left 12° / Right 9°"
            ),
            GarageSwingDomainScore(
                id: GarageSwingDomain.head.rawValue,
                title: GarageSwingDomain.head.title,
                score: 73,
                grade: .good,
                displayValue: "0.8 in"
            )
        ]

        return GarageSwingScorecard(
            timestamps: GarageSwingTimestamps(
                perspective: .dtl,
                start: 0.0,
                top: 0.8,
                impact: 1.1
            ),
            metrics: GarageSwingMetrics(
                tempo: GarageTempoMetric(ratio: 3.0),
                spine: GarageSpineAngleMetric(deltaDegrees: 6.8),
                pelvicDepth: GaragePelvicDepthMetric(driftInches: 1.9),
                kneeFlex: GarageKneeFlexMetric(leftDeltaDegrees: 12, rightDeltaDegrees: 9),
                headStability: GarageHeadStabilityMetric(swayInches: 0.8, dipInches: 0.4)
            ),
            domainScores: includeHeadDomain ? domains : Array(domains.dropLast()),
            totalScore: 87
        )
    }
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

#Preview("Garage Coaching Report · Trusted") {
    PreviewScreenContainer {
        GarageCoachingReportPreviewSurface(presentation: GarageCoachingReportPreviewFixture.trusted)
    }
    .preferredColorScheme(.dark)
}

#Preview("Garage Coaching Report · Review") {
    PreviewScreenContainer {
        GarageCoachingReportPreviewSurface(presentation: GarageCoachingReportPreviewFixture.review)
    }
    .preferredColorScheme(.dark)
}

#Preview("Garage Coaching Report · Unavailable") {
    PreviewScreenContainer {
        GarageCoachingReportPreviewSurface(presentation: GarageCoachingReportPreviewFixture.unavailable)
    }
    .preferredColorScheme(.dark)
}

#Preview("Garage Coaching Report · Provisional") {
    PreviewScreenContainer {
        GarageCoachingReportPreviewSurface(presentation: GarageCoachingReportPreviewFixture.provisional)
    }
    .preferredColorScheme(.dark)
}

#Preview("Garage Coaching Report · Odd Count Capstone") {
    PreviewScreenContainer {
        GarageCoachingReportPreviewSurface(presentation: GarageCoachingReportPreviewFixture.oddCountCapstone)
    }
    .preferredColorScheme(.dark)
}
