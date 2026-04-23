import SwiftUI
import UIKit

struct GarageCoachingReportView: View {
    let presentation: GarageCoachingPresentation
    var isExportingReport: Bool = false
    var onDownloadFullReport: () -> Void = {}
    var onNavigateToEvidence: (GarageEvidenceTarget) -> Void = { _ in }

    @State private var isShellVisible = false
    @State private var visibleSections: Set<GarageCoachingSection> = []
    @State private var lastAnimatedEntranceKey = ""
    @State private var detailTarget: GarageCoachingDetailTarget?
    @State private var selectedRedesignOption: GarageCoachingRedesignOption = .minimalist

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

            sectionCard(.redesignStudio, stroke: garageReviewAccent.opacity(0.18)) {
                redesignStudioSection
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
        .overlay {
            GarageCoachingDetailModal(detailTarget: $detailTarget)
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
        sections.append(.redesignStudio)
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
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    heroTitleBlock

                    Spacer(minLength: 0)

                    heroDownloadButton
                }

                VStack(alignment: .leading, spacing: 12) {
                    heroTitleBlock
                    heroDownloadButton
                }
            }

            HStack(spacing: 8) {
                GarageCoachingBadge(
                    title: presentation.reliabilityStatus.rawValue.uppercased(),
                    tint: presentation.reliabilityStatus.tint
                )
                GarageCoachingBadge(
                    title: presentation.phase.reviewTitle.uppercased(),
                    tint: garageReviewAccent
                )
            }

            if let evidenceTarget = presentation.hero.evidenceTarget {
                evidenceActionButton(for: evidenceTarget)
            }

            Text(presentation.hero.body)
                .font(.subheadline)
                .foregroundStyle(garageReviewMutedText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "doc.richtext.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(garageReviewAccent)
                    .padding(.top, 2)

                Text(downloadSupportCopy)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(garageReviewMutedText.opacity(0.96))
                    .fixedSize(horizontal: false, vertical: true)
            }

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

    private var heroTitleBlock: some View {
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
    }

    private var heroDownloadButton: some View {
        Button {
            garageTriggerImpact(.medium)
            onDownloadFullReport()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isExportingReport ? "hourglass" : "arrow.down.doc.fill")
                    .font(.caption.weight(.bold))

                Text(isExportingReport ? "Preparing PDF" : "Download Full Report")
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .foregroundStyle(garageReviewCanvasFill)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(garageReviewAccent)
                    .overlay(
                        Capsule()
                            .stroke(garageReviewAccent.opacity(0.42), lineWidth: 0.8)
                    )
                    .shadow(color: garageReviewAccent.opacity(0.26), radius: 10, x: 0, y: 6)
            )
        }
        .buttonStyle(.plain)
        .disabled(isExportingReport)
    }

    private var downloadSupportCopy: String {
        "Compiles the critique, the metrics, and all 3 redesigned UI assets into a crisp, shareable PDF."
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
                            if let evidenceTarget = snapshot.evidenceTarget {
                                onNavigateToEvidence(evidenceTarget)
                            } else {
                                detailTarget = .snapshot(snapshot)
                            }
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
                if let evidenceTarget = metric.evidenceTarget {
                    onNavigateToEvidence(evidenceTarget)
                } else {
                    detailTarget = .metric(metric)
                }
            }
        }
    }

    private func evidenceActionButton(for target: GarageEvidenceTarget) -> some View {
        Button {
            garageTriggerImpact(.light)
            onNavigateToEvidence(target)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "scope")
                    .font(.caption.weight(.bold))

                Text(target.actionLabel)
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .foregroundStyle(garageReviewAccent)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(garageReviewAccent.opacity(0.12))
                    .overlay(
                        Capsule()
                            .stroke(garageReviewAccent.opacity(0.28), lineWidth: 0.8)
                    )
                    .shadow(color: garageReviewAccent.opacity(0.16), radius: 8, x: 0, y: 4)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(target.accessibilityLabel)
    }

    private var redesignStudioSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Redesign Carousel")
                        .font(.caption.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(garageReviewMutedText)

                    Text("Three distinct directions for the same report")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(garageReviewReadableText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Text("Swipe or tap")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(garageReviewAccent.opacity(0.92))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(garageReviewAccent.opacity(0.10))
                            .overlay(
                                Capsule()
                                    .stroke(garageReviewAccent.opacity(0.22), lineWidth: 0.8)
                            )
                    )
            }

            HStack(spacing: 8) {
                ForEach(GarageCoachingRedesignOption.allCases) { option in
                    Button {
                        garageTriggerImpact(.light)
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                            selectedRedesignOption = option
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(option.optionLabel)
                                .font(.caption2.weight(.bold))
                                .tracking(0.9)
                            Text(option.title)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .foregroundStyle(
                            selectedRedesignOption == option
                                ? garageReviewReadableText
                                : garageReviewMutedText
                        )
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(
                                    selectedRedesignOption == option
                                        ? option.tint.opacity(0.18)
                                        : garageReviewInsetSurface
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(
                                            selectedRedesignOption == option
                                                ? option.tint.opacity(0.36)
                                                : garageReviewStroke.opacity(0.9),
                                            lineWidth: 0.8
                                        )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            TabView(selection: $selectedRedesignOption) {
                ForEach(GarageCoachingRedesignOption.allCases) { option in
                    GarageCoachingRedesignOptionCard(
                        option: option,
                        presentation: presentation
                    )
                    .tag(option)
                    .padding(.vertical, 2)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 438)
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
    case redesignStudio
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

                    Image(systemName: snapshot.evidenceTarget == nil ? "arrow.up.forward.circle.fill" : "scope")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(snapshot.evidenceTarget == nil ? garageReviewMutedText.opacity(0.72) : garageReviewAccent)
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

                if let evidenceTarget = snapshot.evidenceTarget {
                    GarageEvidenceAffordance(label: evidenceTarget.actionLabel)
                }
            }
            .frame(width: 138, alignment: .leading)
            .padding(14)
                    .background(
                        GarageInsetPanelBackground(
                            shape: RoundedRectangle(cornerRadius: 18, style: .continuous),
                            fill: garageReviewInsetSurface,
                            stroke: snapshot.evidenceTarget == nil
                                ? snapshot.accentStyle.tint.opacity(snapshot.valueState == .available ? 0.18 : 0.08)
                                : garageReviewAccent.opacity(0.3)
                        )
                    )
        }
        .buttonStyle(.plain)
    }
}

private struct GarageEvidenceAffordance: View {
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "scope")
                .font(.system(size: 9, weight: .bold))

            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(0.7)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .foregroundStyle(garageReviewAccent.opacity(0.96))
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(garageReviewAccent.opacity(0.1))
                .overlay(
                    Capsule()
                        .stroke(garageReviewAccent.opacity(0.22), lineWidth: 0.7)
                )
        )
        .accessibilityHidden(true)
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
        if metric.evidenceTarget != nil {
            return garageReviewAccent.opacity(0.32)
        }

        return (metric.badgeStyle?.tint ?? garageReviewMutedText.opacity(0.42))
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

                if let evidenceTarget = metric.evidenceTarget {
                    GarageEvidenceAffordance(label: evidenceTarget.actionLabel)
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

                    if let evidenceTarget = metric.evidenceTarget {
                        GarageEvidenceAffordance(label: evidenceTarget.actionLabel)
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

private struct GarageCoachingDetailModal: View {
    @Binding var detailTarget: GarageCoachingDetailTarget?

    private var isPresented: Binding<Bool> {
        Binding(
            get: { detailTarget != nil },
            set: { newValue in
                if newValue == false {
                    detailTarget = nil
                }
            }
        )
    }

    private var modalTitle: String {
        detailTarget?.title ?? "Analysis Detail"
    }

    var body: some View {
        Color.clear
            .garageModal(
                isPresented: isPresented,
                title: modalTitle
            ) {
                if let detailTarget {
                    GarageCoachingDetailSheet(target: detailTarget)
                }
            }
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
                                fill: .vibeSurface
                            )
                        )
                    }
                }
            }
            .padding(20)
        }
        .background(Color.vibeBackground.ignoresSafeArea())
    }
}

enum GarageCoachingRedesignOption: String, CaseIterable, Identifiable {
    case minimalist
    case powerUser
    case vibe

    var id: String { rawValue }

    var optionLabel: String {
        switch self {
        case .minimalist:
            "OPTION A"
        case .powerUser:
            "OPTION B"
        case .vibe:
            "OPTION C"
        }
    }

    var title: String {
        switch self {
        case .minimalist:
            "The Minimalist"
        case .powerUser:
            "The Power User"
        case .vibe:
            "The Vibe"
        }
    }

    var descriptor: String {
        switch self {
        case .minimalist:
            "Black-and-white dominant, quiet spacing, and typography-first clarity."
        case .powerUser:
            "Dense signal layout with tighter spacing, fast scanning, and all-core metrics upfront."
        case .vibe:
            "Softer corners, subtle gradients, and warmer emotional feedback without losing clarity."
        }
    }

    var psychology: String {
        switch self {
        case .minimalist:
            "Best for users who want the report to lower cognitive load and let a few important coaching cues land with zero visual noise."
        case .powerUser:
            "Best for users who feel more in control when every metric, status, and trend is visible at once with minimal navigation friction."
        case .vibe:
            "Best for users who stay engaged longer when the interface feels friendly, expressive, and emotionally rewarding instead of clinical."
        }
    }

    var tint: Color {
        switch self {
        case .minimalist:
            garageReviewReadableText
        case .powerUser:
            garageReviewAccent
        case .vibe:
            AppModule.garage.theme.secondary
        }
    }
}

struct GarageShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

enum GarageCoachingReportPDFExporter {
    private static let pageSize = CGSize(width: 612, height: 792)

    @MainActor
    static func export(presentation: GarageCoachingPresentation) throws -> URL {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("garage-coaching-report-\(UUID().uuidString)")
            .appendingPathExtension("pdf")

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        let exportDate = Date()
        let pages: [GarageCoachingReportPDFPage] = [
            .summary,
            .metrics,
            .redesign(.minimalist),
            .redesign(.powerUser),
            .redesign(.vibe)
        ]

        try renderer.writePDF(to: fileURL) { context in
            for page in pages {
                context.beginPage()

                let pageView = GarageCoachingReportPDFPageView(
                    page: page,
                    presentation: presentation,
                    exportDate: exportDate
                )
                .frame(width: pageSize.width, height: pageSize.height)

                let imageRenderer = ImageRenderer(content: pageView)
                imageRenderer.scale = 2

                if let pageImage = imageRenderer.uiImage {
                    pageImage.draw(in: CGRect(origin: .zero, size: pageSize))
                }
            }
        }

        return fileURL
    }
}

private enum GarageCoachingReportPDFPage: Identifiable {
    case summary
    case metrics
    case redesign(GarageCoachingRedesignOption)

    var id: String {
        switch self {
        case .summary:
            "summary"
        case .metrics:
            "metrics"
        case let .redesign(option):
            "redesign-\(option.rawValue)"
        }
    }
}

private struct GarageCoachingRedesignOptionCard: View {
    let option: GarageCoachingRedesignOption
    let presentation: GarageCoachingPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 10) {
                    Text(option.optionLabel)
                        .font(.caption2.weight(.bold))
                        .tracking(1.0)
                        .foregroundStyle(option.tint)

                    Text(option.title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(garageReviewReadableText)

                    Spacer(minLength: 0)
                }

                Text(option.descriptor)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(garageReviewMutedText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            GarageCoachingRedesignAsset(option: option, presentation: presentation)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 6) {
                Text("UX Psychology")
                    .font(.caption.weight(.bold))
                    .tracking(1.0)
                    .foregroundStyle(garageReviewMutedText)

                Text(option.psychology)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(garageReviewReadableText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            GarageInsetPanelBackground(
                shape: RoundedRectangle(cornerRadius: 22, style: .continuous),
                fill: garageReviewInsetSurface,
                stroke: option.tint.opacity(0.16)
            )
        )
    }
}

private struct GarageCoachingRedesignAsset: View {
    let option: GarageCoachingRedesignOption
    let presentation: GarageCoachingPresentation

    var body: some View {
        Group {
            switch option {
            case .minimalist:
                GarageMinimalistRedesignAsset(presentation: presentation)
            case .powerUser:
                GaragePowerUserRedesignAsset(presentation: presentation)
            case .vibe:
                GarageVibeRedesignAsset(presentation: presentation)
            }
        }
        .frame(height: 270)
    }
}

private struct GarageMinimalistRedesignAsset: View {
    let presentation: GarageCoachingPresentation

    private var leadMetric: GarageCoachingMetricModel? {
        presentation.metrics.first
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [garageReviewSurfaceDark, Color.black.opacity(0.96)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.7)
            )
            .overlay {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("FOCUSED REPORT")
                            .font(.caption2.weight(.bold))
                            .tracking(1.6)
                            .foregroundStyle(Color.white.opacity(0.62))

                        Spacer(minLength: 0)

                        Circle()
                            .fill(Color.white.opacity(0.86))
                            .frame(width: 6, height: 6)
                    }

                    Spacer(minLength: 0)

                    VStack(alignment: .leading, spacing: 20) {
                        Text(presentation.hero.headline.uppercased())
                            .font(.system(size: 27, weight: .bold, design: .default))
                            .foregroundStyle(Color.white)
                            .lineLimit(3)
                            .minimumScaleFactor(0.78)

                        Text(presentation.hero.body)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Color.white.opacity(0.70))
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    HStack(alignment: .lastTextBaseline, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("PRIMARY SIGNAL")
                                .font(.caption2.weight(.bold))
                                .tracking(1.4)
                                .foregroundStyle(Color.white.opacity(0.48))

                            Text(leadMetric?.value ?? presentation.reliabilityStatus.rawValue)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.white)
                        }

                        Spacer(minLength: 0)

                        Text(leadMetric?.title.uppercased() ?? "TRUST")
                            .font(.caption.weight(.semibold))
                            .tracking(1.0)
                            .foregroundStyle(Color.white.opacity(0.54))
                    }
                }
                .padding(26)
            }
    }
}

private struct GaragePowerUserRedesignAsset: View {
    let presentation: GarageCoachingPresentation

    private var denseMetrics: [GarageCoachingMetricModel] {
        Array(presentation.metrics.prefix(6))
    }

    private var chartMetrics: [GarageCoachingMetricModel] {
        Array(presentation.metrics.prefix(4))
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [garageReviewSurfaceDark, garageReviewSurface, garageReviewSurfaceRaised],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(garageReviewAccent.opacity(0.22), lineWidth: 0.8)
            )
            .overlay {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("POWER DASHBOARD")
                                .font(.caption2.weight(.bold))
                                .tracking(1.4)
                                .foregroundStyle(garageReviewAccent)

                            Text("Everything visible without scrolling")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(garageReviewMutedText.opacity(0.92))
                        }

                        Spacer(minLength: 0)

                        Text(presentation.reliabilityStatus.rawValue.uppercased())
                            .font(.caption2.weight(.bold))
                            .tracking(0.8)
                            .foregroundStyle(garageReviewReadableText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(garageReviewAccent.opacity(0.12))
                                    .overlay(
                                        Capsule()
                                            .stroke(garageReviewAccent.opacity(0.24), lineWidth: 0.8)
                                    )
                            )
                    }

                    HStack(alignment: .top, spacing: 10) {
                        GaragePowerUserTrendChart(metrics: chartMetrics)

                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(presentation.snapshots.prefix(3))) { snapshot in
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(snapshot.accentStyle.tint.opacity(0.92))
                                        .frame(width: 6, height: 6)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(snapshot.title)
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(garageReviewMutedText)
                                            .lineLimit(1)

                                        Text(snapshot.value)
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(garageReviewReadableText)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.82)
                                    }

                                    Spacer(minLength: 0)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8)
                        ],
                        spacing: 8
                    ) {
                        ForEach(denseMetrics) { metric in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(metric.title)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(garageReviewMutedText)
                                    .lineLimit(2)

                                Text(metric.value)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(garageReviewReadableText)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.72)

                                Capsule()
                                    .fill((metric.badgeStyle?.tint ?? garageReviewAccent).opacity(0.9))
                                    .frame(height: 3)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(garageReviewInsetSurface.opacity(0.96))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(garageReviewStroke.opacity(0.92), lineWidth: 0.7)
                                    )
                            )
                        }
                    }
                }
                .padding(18)
            }
    }
}

private struct GaragePowerUserTrendChart: View {
    let metrics: [GarageCoachingMetricModel]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TREND STACK")
                .font(.caption2.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(garageReviewMutedText)

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(metrics.enumerated()), id: \.offset) { index, metric in
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(metric.badgeStyle?.tint ?? garageReviewAccent)
                            .frame(height: chartHeight(for: metric, index: index))

                        Text(metric.title.prefix(3).uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(garageReviewMutedText.opacity(0.94))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 104, alignment: .bottom)
        }
        .padding(12)
        .frame(width: 168, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(garageReviewInsetSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(garageReviewStroke.opacity(0.9), lineWidth: 0.7)
                )
        )
    }

    private func chartHeight(for metric: GarageCoachingMetricModel, index: Int) -> CGFloat {
        if let progress = metric.progress {
            return max(CGFloat(progress) * 74, 18)
        }

        return CGFloat(40 + (index * 12))
    }
}

private struct GarageVibeRedesignAsset: View {
    let presentation: GarageCoachingPresentation

    private var leadMetric: GarageCoachingMetricModel? {
        presentation.metrics.first
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            garageReviewSurfaceRaised,
                            AppModule.garage.theme.secondary.opacity(0.22),
                            garageReviewSurface
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(garageReviewAccent.opacity(0.16))
                .frame(width: 150, height: 150)
                .blur(radius: 10)
                .offset(x: 128, y: -94)

            Circle()
                .fill(AppModule.garage.theme.secondary.opacity(0.14))
                .frame(width: 120, height: 120)
                .blur(radius: 8)
                .offset(x: -116, y: 88)

            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 0.8)

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("COACHING STORY")
                            .font(.caption2.weight(.bold))
                            .tracking(1.4)
                            .foregroundStyle(AppModule.garage.theme.secondary)

                        Text("Approachable and emotionally sticky")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(garageReviewMutedText.opacity(0.94))
                    }

                    Spacer(minLength: 0)

                    Text(presentation.phase.reviewTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(garageReviewReadableText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.10))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                                )
                        )
                }

                Text(presentation.hero.headline)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(garageReviewReadableText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                Text(presentation.hero.body)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(garageReviewMutedText.opacity(0.96))
                    .lineLimit(3)

                HStack(spacing: 10) {
                    GarageVibeBadge(
                        title: presentation.reliabilityStatus.rawValue.capitalized,
                        tint: garageReviewAccent
                    )

                    if let snapshot = presentation.snapshots.first {
                        GarageVibeBadge(
                            title: snapshot.title,
                            tint: AppModule.garage.theme.secondary
                        )
                    }
                }

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Main Cue")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(garageReviewMutedText)

                        Text(leadMetric?.value ?? presentation.hero.headline)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(garageReviewReadableText)
                            .lineLimit(2)
                            .minimumScaleFactor(0.78)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(garageReviewSurfaceDark.opacity(0.54))
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                            )
                    )

                    VStack(spacing: 10) {
                        ForEach(Array(presentation.metrics.prefix(2))) { metric in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(metric.badgeStyle?.tint ?? garageReviewAccent)
                                    .frame(width: 8, height: 8)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(metric.title)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(garageReviewMutedText)
                                        .lineLimit(1)

                                    Text(metric.value)
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(garageReviewReadableText)
                                        .lineLimit(1)
                                }

                                Spacer(minLength: 0)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                                    )
                            )
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(20)
        }
    }
}

private struct GarageVibeBadge: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(garageReviewReadableText)
            .lineLimit(1)
            .minimumScaleFactor(0.84)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(tint.opacity(0.12))
                    .overlay(
                        Capsule()
                            .stroke(tint.opacity(0.18), lineWidth: 0.8)
                    )
            )
    }
}

private struct GarageCoachingReportPDFPageView: View {
    let page: GarageCoachingReportPDFPage
    let presentation: GarageCoachingPresentation
    let exportDate: Date

    private let pagePadding: CGFloat = 28

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [garageReviewBackground, garageReviewSurfaceDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            switch page {
            case .summary:
                summaryPage
            case .metrics:
                metricsPage
            case let .redesign(option):
                redesignPage(option: option)
            }
        }
    }

    private var summaryPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            pdfHeader(
                eyebrow: "GARAGE UI/UX REPORT",
                title: "Focused Analysis + Redesign Direction",
                subtitle: "Exported \(exportDate.formatted(date: .abbreviated, time: .shortened))"
            )

            GaragePDFCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Critique")
                        .font(.caption.weight(.bold))
                        .tracking(1.0)
                        .foregroundStyle(garageReviewMutedText)

                    Text(presentation.hero.headline)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(garageReviewReadableText)

                    Text(presentation.hero.body)
                        .font(.body)
                        .foregroundStyle(garageReviewMutedText)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
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
            }

            GaragePDFCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Next Best Action")
                        .font(.caption.weight(.bold))
                        .tracking(1.0)
                        .foregroundStyle(garageReviewMutedText)

                    Text(presentation.action.body)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(garageReviewReadableText)
                        .fixedSize(horizontal: false, vertical: true)

                    if presentation.action.notes.isEmpty == false {
                        ForEach(presentation.action.notes, id: \.self) { note in
                            HStack(alignment: .top, spacing: 8) {
                                Circle()
                                    .fill(garageReviewAccent.opacity(0.92))
                                    .frame(width: 6, height: 6)
                                    .padding(.top, 6)

                                Text(note)
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(garageReviewMutedText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }

            GaragePDFCard {
                Text("This PDF bundles the critique, the metrics, and all 3 redesigned UI assets into one shareable handoff.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(garageReviewReadableText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 0)
        }
        .padding(pagePadding)
    }

    private var metricsPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            pdfHeader(
                eyebrow: "EVIDENCE",
                title: "Metrics + Session Readout",
                subtitle: "The measurable layer behind the critique."
            )

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ],
                spacing: 12
            ) {
                ForEach(presentation.metrics) { metric in
                    GaragePDFCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: metric.systemImage)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(metric.badgeStyle?.tint ?? garageReviewAccent)

                                Text(metric.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(garageReviewMutedText)
                                    .lineLimit(1)

                                Spacer(minLength: 0)
                            }

                            Text(metric.value)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(garageReviewReadableText)
                                .lineLimit(2)
                                .minimumScaleFactor(0.78)

                            if let badgeStyle = metric.badgeStyle {
                                Text(badgeStyle.title)
                                    .font(.caption2.weight(.bold))
                                    .tracking(0.8)
                                    .foregroundStyle(badgeStyle.tint)
                            }
                        }
                    }
                }
            }

            if presentation.snapshots.isEmpty == false {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Session Readout")
                        .font(.caption.weight(.bold))
                        .tracking(1.0)
                        .foregroundStyle(garageReviewMutedText)

                    HStack(spacing: 12) {
                        ForEach(Array(presentation.snapshots.prefix(3))) { snapshot in
                            GaragePDFCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(snapshot.title)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(garageReviewMutedText)

                                    Text(snapshot.value)
                                        .font(.headline.weight(.bold))
                                        .foregroundStyle(garageReviewReadableText)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.8)

                                    Text(snapshot.caption)
                                        .font(.caption2)
                                        .foregroundStyle(garageReviewMutedText.opacity(0.94))
                                        .lineLimit(2)
                                }
                            }
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(pagePadding)
    }

    private func redesignPage(option: GarageCoachingRedesignOption) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            pdfHeader(
                eyebrow: option.optionLabel,
                title: option.title,
                subtitle: option.psychology
            )

            GarageCoachingRedesignOptionCard(option: option, presentation: presentation)

            Spacer(minLength: 0)
        }
        .padding(pagePadding)
    }

    private func pdfHeader(eyebrow: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow)
                .font(.caption.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(garageReviewAccent)

            Text(title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(garageReviewReadableText)

            Text(subtitle)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(garageReviewMutedText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct GaragePDFCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            GarageRaisedPanelBackground(
                shape: RoundedRectangle(cornerRadius: 24, style: .continuous),
                fill: garageReviewSurfaceRaised,
                stroke: garageReviewStroke.opacity(0.92)
            )
        )
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
